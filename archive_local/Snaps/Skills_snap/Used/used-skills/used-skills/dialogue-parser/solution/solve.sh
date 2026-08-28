#!/bin/bash
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"
SOLUTION_DIR="${SOLUTION_DIR:-/solution}"
BUILD_DIR="${APP_DIR}/.dialogue_native"

mkdir -p "${APP_DIR}" "${SOLUTION_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

if ! command -v g++ >/dev/null 2>&1 && ! command -v c++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends g++
    rm -rf /var/lib/apt/lists/*
fi

PYTHON_BIN="$(command -v python3)"

cat > "${SOLUTION_DIR}/solution.py" <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
Ahead-of-time dialogue compiler.

The implementation deliberately uses a native two-stage toolchain:

    script text
      -> C++ frontend
      -> length-prefixed binary IR
      -> C++ backend
      -> validated JSON graph and DOT visualization
      -> independent Python post-validation

parse_script(text) uses exactly the same frontend/backend pipeline.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, List


CPP_SOURCE = r"""
#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <queue>
#include <regex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace fs = std::filesystem;

namespace {

constexpr char IR_MAGIC[] = "DLGIR001";
constexpr std::size_t IR_MAGIC_SIZE = 8;
constexpr std::uint32_t MAX_COLLECTION_ITEMS = 1'000'000;
constexpr std::uint32_t MAX_STRING_BYTES = 64U * 1024U * 1024U;

enum class StatementKind : std::uint8_t {
    Choice = 1,
    Line = 2,
    Plain = 3,
};

struct Statement {
    StatementKind kind = StatementKind::Plain;
    std::uint32_t source_line = 0;
    std::int32_t choice_number = -1;
    std::string raw;
    std::string speaker;
    std::string text;
    std::string edge_text;
    std::optional<std::string> target;
};

struct Section {
    std::string id;
    std::uint32_t source_line = 0;
    std::vector<Statement> statements;
};

struct Node {
    std::string id;
    std::string text;
    std::string speaker;
    std::string type;
};

struct Edge {
    std::string from;
    std::string to;
    std::string text;
    std::uint32_t source_line = 0;
};

struct Graph {
    std::vector<Node> nodes;
    std::vector<Edge> edges;
};

[[noreturn]] void fail(const std::string& message) {
    throw std::runtime_error(message);
}

std::string trim(const std::string& input) {
    const auto first = input.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) {
        return "";
    }
    const auto last = input.find_last_not_of(" \t\r\n");
    return input.substr(first, last - first + 1);
}

bool starts_with(const std::string& value, const std::string& prefix) {
    return value.size() >= prefix.size()
        && value.compare(0, prefix.size(), prefix) == 0;
}

void ensure_parent(const fs::path& path) {
    const fs::path parent = path.parent_path();
    if (!parent.empty()) {
        fs::create_directories(parent);
    }
}

void atomic_write(const fs::path& destination, const std::string& content) {
    ensure_parent(destination);
    const fs::path temporary = destination.string() + ".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) {
            fail("Cannot open temporary output: " + temporary.string());
        }
        output.write(content.data(), static_cast<std::streamsize>(content.size()));
        output.flush();
        if (!output) {
            fail("Failed while writing: " + temporary.string());
        }
    }
    std::error_code error;
    fs::remove(destination, error);
    error.clear();
    fs::rename(temporary, destination, error);
    if (error) {
        fail("Cannot replace output " + destination.string() + ": " + error.message());
    }
}

void write_u8(std::ostream& output, std::uint8_t value) {
    output.put(static_cast<char>(value));
    if (!output) {
        fail("Failed to write binary IR byte");
    }
}

void write_u32(std::ostream& output, std::uint32_t value) {
    for (int shift = 0; shift < 32; shift += 8) {
        write_u8(output, static_cast<std::uint8_t>((value >> shift) & 0xffU));
    }
}

void write_i32(std::ostream& output, std::int32_t value) {
    write_u32(output, static_cast<std::uint32_t>(value));
}

void write_string(std::ostream& output, const std::string& value) {
    if (value.size() > MAX_STRING_BYTES) {
        fail("String is too large for binary IR");
    }
    write_u32(output, static_cast<std::uint32_t>(value.size()));
    output.write(value.data(), static_cast<std::streamsize>(value.size()));
    if (!output) {
        fail("Failed to write binary IR string");
    }
}

std::uint8_t read_u8(std::istream& input) {
    const int value = input.get();
    if (value == std::char_traits<char>::eof()) {
        fail("Unexpected end of binary IR");
    }
    return static_cast<std::uint8_t>(value);
}

std::uint32_t read_u32(std::istream& input) {
    std::uint32_t value = 0;
    for (int shift = 0; shift < 32; shift += 8) {
        value |= static_cast<std::uint32_t>(read_u8(input)) << shift;
    }
    return value;
}

std::int32_t read_i32(std::istream& input) {
    return static_cast<std::int32_t>(read_u32(input));
}

std::string read_string(std::istream& input) {
    const std::uint32_t length = read_u32(input);
    if (length > MAX_STRING_BYTES) {
        fail("Binary IR string length exceeds safety limit");
    }
    std::string value(length, '\0');
    input.read(value.data(), static_cast<std::streamsize>(length));
    if (!input) {
        fail("Unexpected end of binary IR string");
    }
    return value;
}

std::pair<std::string, std::optional<std::string>>
split_transition(const std::string& statement, std::uint32_t source_line) {
    const std::size_t arrow = statement.rfind("->");
    if (arrow == std::string::npos) {
        return {trim(statement), std::nullopt};
    }

    const std::string left = trim(statement.substr(0, arrow));
    const std::string target = trim(statement.substr(arrow + 2));
    if (target.empty()) {
        fail(
            "Transition has an empty target at source line "
            + std::to_string(source_line)
        );
    }
    return {left, target};
}

Statement classify_statement(
    const std::string& raw,
    std::uint32_t source_line
) {
    const auto [text_part, target] = split_transition(raw, source_line);

    static const std::regex choice_pattern(R"(^([0-9]+)\.\s*(.*)$)");
    std::smatch choice_match;
    if (std::regex_match(text_part, choice_match, choice_pattern)) {
        Statement result;
        result.kind = StatementKind::Choice;
        result.source_line = source_line;
        result.raw = raw;
        result.choice_number = std::stoi(choice_match[1].str());
        result.text = trim(choice_match[2].str());
        result.edge_text = text_part;
        result.target = target;
        return result;
    }

    const std::size_t colon = text_part.find(':');
    if (colon != std::string::npos) {
        const std::string speaker = trim(text_part.substr(0, colon));
        if (!speaker.empty()) {
            Statement result;
            result.kind = StatementKind::Line;
            result.source_line = source_line;
            result.raw = raw;
            result.speaker = speaker;
            result.text = trim(text_part.substr(colon + 1));
            result.target = target;
            return result;
        }
    }

    Statement result;
    result.kind = StatementKind::Plain;
    result.source_line = source_line;
    result.raw = raw;
    result.text = text_part;
    result.target = target;
    return result;
}

std::vector<Section> parse_source(const fs::path& input_path) {
    std::ifstream input(input_path, std::ios::binary);
    if (!input) {
        fail("Cannot open input script: " + input_path.string());
    }

    static const std::regex header_pattern(R"(^\[([^\[\]\r\n]+)\]$)");

    std::vector<Section> sections;
    std::unordered_map<std::string, std::uint32_t> declaration_lines;
    Section* current = nullptr;
    std::string line;
    std::uint32_t line_number = 0;

    while (std::getline(input, line)) {
        ++line_number;
        if (line_number == 1 && starts_with(line, "\xEF\xBB\xBF")) {
            line.erase(0, 3);
        }

        const std::string stripped = trim(line);
        if (stripped.empty() || starts_with(stripped, "//")) {
            continue;
        }

        std::smatch header_match;
        if (std::regex_match(stripped, header_match, header_pattern)) {
            const std::string node_id = trim(header_match[1].str());
            if (node_id.empty()) {
                fail("Empty node id at source line " + std::to_string(line_number));
            }
            const auto duplicate = declaration_lines.find(node_id);
            if (duplicate != declaration_lines.end()) {
                fail(
                    "Duplicate node [" + node_id + "] at source line "
                    + std::to_string(line_number)
                    + "; first declared at line "
                    + std::to_string(duplicate->second)
                );
            }

            declaration_lines.emplace(node_id, line_number);
            sections.push_back(Section{node_id, line_number, {}});
            current = &sections.back();
            continue;
        }

        if (current == nullptr) {
            fail(
                "Content appears before the first [Node] header at source line "
                + std::to_string(line_number)
            );
        }

        current->statements.push_back(
            classify_statement(stripped, line_number)
        );
    }

    if (sections.empty()) {
        fail("The script does not contain any [Node] headers");
    }

    return sections;
}

void write_ir(
    const fs::path& ir_path,
    const std::vector<Section>& sections
) {
    ensure_parent(ir_path);
    const fs::path temporary = ir_path.string() + ".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) {
            fail("Cannot open binary IR output: " + temporary.string());
        }

        output.write(IR_MAGIC, static_cast<std::streamsize>(IR_MAGIC_SIZE));
        write_u32(output, static_cast<std::uint32_t>(sections.size()));

        for (const Section& section : sections) {
            write_string(output, section.id);
            write_u32(output, section.source_line);
            write_u32(
                output,
                static_cast<std::uint32_t>(section.statements.size())
            );

            for (const Statement& statement : section.statements) {
                write_u8(output, static_cast<std::uint8_t>(statement.kind));
                write_u32(output, statement.source_line);
                write_i32(output, statement.choice_number);
                write_string(output, statement.raw);
                write_string(output, statement.speaker);
                write_string(output, statement.text);
                write_string(output, statement.edge_text);
                write_u8(output, statement.target.has_value() ? 1U : 0U);
                if (statement.target.has_value()) {
                    write_string(output, *statement.target);
                }
            }
        }

        output.flush();
        if (!output) {
            fail("Failed while writing binary IR");
        }
    }

    std::error_code error;
    fs::remove(ir_path, error);
    error.clear();
    fs::rename(temporary, ir_path, error);
    if (error) {
        fail("Cannot replace binary IR: " + error.message());
    }
}

std::vector<Section> read_ir(const fs::path& ir_path) {
    std::ifstream input(ir_path, std::ios::binary);
    if (!input) {
        fail("Cannot open binary IR: " + ir_path.string());
    }

    char magic[IR_MAGIC_SIZE] = {};
    input.read(magic, static_cast<std::streamsize>(IR_MAGIC_SIZE));
    if (!input || !std::equal(magic, magic + IR_MAGIC_SIZE, IR_MAGIC)) {
        fail("Invalid binary IR header");
    }

    const std::uint32_t section_count = read_u32(input);
    if (section_count == 0 || section_count > MAX_COLLECTION_ITEMS) {
        fail("Invalid section count in binary IR");
    }

    std::vector<Section> sections;
    sections.reserve(section_count);

    for (std::uint32_t section_index = 0;
         section_index < section_count;
         ++section_index) {
        Section section;
        section.id = read_string(input);
        section.source_line = read_u32(input);

        const std::uint32_t statement_count = read_u32(input);
        if (statement_count > MAX_COLLECTION_ITEMS) {
            fail("Invalid statement count in binary IR");
        }
        section.statements.reserve(statement_count);

        for (std::uint32_t statement_index = 0;
             statement_index < statement_count;
             ++statement_index) {
            Statement statement;
            const std::uint8_t raw_kind = read_u8(input);
            if (raw_kind < static_cast<std::uint8_t>(StatementKind::Choice)
                || raw_kind > static_cast<std::uint8_t>(StatementKind::Plain)) {
                fail("Unknown statement kind in binary IR");
            }
            statement.kind = static_cast<StatementKind>(raw_kind);
            statement.source_line = read_u32(input);
            statement.choice_number = read_i32(input);
            statement.raw = read_string(input);
            statement.speaker = read_string(input);
            statement.text = read_string(input);
            statement.edge_text = read_string(input);

            const std::uint8_t has_target = read_u8(input);
            if (has_target > 1U) {
                fail("Invalid target flag in binary IR");
            }
            if (has_target == 1U) {
                statement.target = read_string(input);
            }

            section.statements.push_back(std::move(statement));
        }

        sections.push_back(std::move(section));
    }

    if (input.peek() != std::char_traits<char>::eof()) {
        fail("Binary IR contains trailing data");
    }

    return sections;
}

Graph build_graph(const std::vector<Section>& sections) {
    Graph graph;
    graph.nodes.reserve(sections.size());

    for (const Section& section : sections) {
        bool has_choice = false;
        bool has_non_choice = false;
        for (const Statement& statement : section.statements) {
            if (statement.kind == StatementKind::Choice) {
                has_choice = true;
            } else {
                has_non_choice = true;
            }
        }

        if (has_choice && has_non_choice) {
            fail(
                "Node [" + section.id
                + "] mixes choice and non-choice statements"
            );
        }

        Node node;
        node.id = section.id;

        if (has_choice) {
            node.type = "choice";
            node.text = "";
            node.speaker = "";
        } else {
            node.type = "line";

            std::set<std::string> speakers;
            std::ostringstream combined_text;
            bool first_text = true;

            for (const Statement& statement : section.statements) {
                if (!statement.speaker.empty()) {
                    speakers.insert(statement.speaker);
                }
                if (!first_text) {
                    combined_text << '\n';
                }
                combined_text << statement.text;
                first_text = false;
            }

            node.text = combined_text.str();
            node.speaker = speakers.size() == 1 ? *speakers.begin() : "";
        }

        graph.nodes.push_back(std::move(node));
    }

    for (const Section& section : sections) {
        for (const Statement& statement : section.statements) {
            if (!statement.target.has_value()) {
                continue;
            }
            Edge edge;
            edge.from = section.id;
            edge.to = *statement.target;
            edge.text = statement.kind == StatementKind::Choice
                ? statement.edge_text
                : "";
            edge.source_line = statement.source_line;
            graph.edges.push_back(std::move(edge));
        }
    }

    return graph;
}

void validate_graph(const Graph& graph) {
    if (graph.nodes.empty()) {
        fail("Graph has no nodes");
    }

    std::unordered_map<std::string, std::size_t> node_index;
    node_index.reserve(graph.nodes.size());
    for (std::size_t index = 0; index < graph.nodes.size(); ++index) {
        const auto [position, inserted] = node_index.emplace(
            graph.nodes[index].id,
            index
        );
        if (!inserted) {
            fail("Duplicate node id after IR reconstruction: " + position->first);
        }
    }

    std::vector<std::vector<std::size_t>> adjacency(graph.nodes.size());
    for (const Edge& edge : graph.edges) {
        const auto source = node_index.find(edge.from);
        if (source == node_index.end()) {
            fail("Edge source does not exist: " + edge.from);
        }

        const auto target = node_index.find(edge.to);
        if (target == node_index.end()) {
            if (edge.to != "End") {
                fail(
                    "Edge target [" + edge.to + "] from [" + edge.from
                    + "] at source line " + std::to_string(edge.source_line)
                    + " does not exist"
                );
            }
            continue;
        }

        adjacency[source->second].push_back(target->second);
    }

    std::vector<bool> reachable(graph.nodes.size(), false);
    std::queue<std::size_t> pending;
    reachable[0] = true;
    pending.push(0);

    while (!pending.empty()) {
        const std::size_t current = pending.front();
        pending.pop();

        for (const std::size_t target : adjacency[current]) {
            if (!reachable[target]) {
                reachable[target] = true;
                pending.push(target);
            }
        }
    }

    for (std::size_t index = 0; index < graph.nodes.size(); ++index) {
        if (!reachable[index]) {
            fail(
                "Node [" + graph.nodes[index].id
                + "] is unreachable from first node ["
                + graph.nodes.front().id + "]"
            );
        }
    }
}

std::string json_quote(const std::string& value) {
    static const char hex[] = "0123456789abcdef";
    std::ostringstream output;
    output << '"';

    for (const unsigned char byte : value) {
        switch (byte) {
            case '"':
                output << "\\\"";
                break;
            case '\\':
                output << "\\\\";
                break;
            case '\b':
                output << "\\b";
                break;
            case '\f':
                output << "\\f";
                break;
            case '\n':
                output << "\\n";
                break;
            case '\r':
                output << "\\r";
                break;
            case '\t':
                output << "\\t";
                break;
            default:
                if (byte < 0x20U) {
                    output << "\\u00"
                           << hex[(byte >> 4U) & 0x0fU]
                           << hex[byte & 0x0fU];
                } else {
                    output << static_cast<char>(byte);
                }
        }
    }

    output << '"';
    return output.str();
}

std::string graph_to_json(const Graph& graph) {
    std::ostringstream output;
    output << "{\n  \"nodes\": [\n";

    for (std::size_t index = 0; index < graph.nodes.size(); ++index) {
        const Node& node = graph.nodes[index];
        output << "    {"
               << "\"id\": " << json_quote(node.id)
               << ", \"text\": " << json_quote(node.text)
               << ", \"speaker\": " << json_quote(node.speaker)
               << ", \"type\": " << json_quote(node.type)
               << "}";
        if (index + 1 != graph.nodes.size()) {
            output << ',';
        }
        output << '\n';
    }

    output << "  ],\n  \"edges\": [\n";

    for (std::size_t index = 0; index < graph.edges.size(); ++index) {
        const Edge& edge = graph.edges[index];
        output << "    {"
               << "\"from\": " << json_quote(edge.from)
               << ", \"to\": " << json_quote(edge.to)
               << ", \"text\": " << json_quote(edge.text)
               << "}";
        if (index + 1 != graph.edges.size()) {
            output << ',';
        }
        output << '\n';
    }

    output << "  ]\n}\n";
    return output.str();
}

std::string graph_to_dot(const Graph& graph) {
    std::ostringstream output;
    output << "digraph DialogueGraph {\n"
           << "  graph [rankdir=TB, splines=ortho, nodesep=0.5, ranksep=0.8];\n"
           << "  node [fontname=\"Arial\", fontsize=10];\n"
           << "  edge [fontname=\"Arial\", fontsize=8];\n";

    std::unordered_set<std::string> explicit_ids;
    explicit_ids.reserve(graph.nodes.size());

    for (const Node& node : graph.nodes) {
        explicit_ids.insert(node.id);

        std::string label = node.id;
        if (node.type == "line") {
            if (!node.speaker.empty() && !node.text.empty()) {
                label += "\n" + node.speaker + ": " + node.text;
            } else if (!node.text.empty()) {
                label += "\n" + node.text;
            }

            output << "  " << json_quote(node.id)
                   << " [label=" << json_quote(label)
                   << ", shape=box, style=\"filled,rounded\","
                   << " fillcolor=\"white\"];\n";
        } else {
            output << "  " << json_quote(node.id)
                   << " [label=" << json_quote(label)
                   << ", shape=diamond, style=filled,"
                   << " fillcolor=\"lightblue\"];\n";
        }
    }

    bool implicit_end = false;
    for (const Edge& edge : graph.edges) {
        if (edge.to == "End" && explicit_ids.find("End") == explicit_ids.end()) {
            implicit_end = true;
            break;
        }
    }
    if (implicit_end) {
        output << "  \"End\" [label=\"END\", shape=doublecircle,"
               << " style=filled, fillcolor=\"lightgray\"];\n";
    }

    for (const Edge& edge : graph.edges) {
        output << "  " << json_quote(edge.from)
               << " -> " << json_quote(edge.to);
        if (!edge.text.empty()) {
            output << " [label=" << json_quote(edge.text) << "]";
        }
        output << ";\n";
    }

    output << "}\n";
    return output.str();
}

std::string require_option(
    const std::unordered_map<std::string, std::string>& options,
    const std::string& name
) {
    const auto found = options.find(name);
    if (found == options.end() || found->second.empty()) {
        fail("Missing required option --" + name);
    }
    return found->second;
}

std::unordered_map<std::string, std::string>
parse_options(int argc, char** argv, int start_index) {
    std::unordered_map<std::string, std::string> options;
    for (int index = start_index; index < argc; index += 2) {
        const std::string key = argv[index];
        if (!starts_with(key, "--") || index + 1 >= argc) {
            fail("Options must be supplied as --name value pairs");
        }
        options[key.substr(2)] = argv[index + 1];
    }
    return options;
}

void run_frontend(const std::unordered_map<std::string, std::string>& options) {
    const fs::path input_path = require_option(options, "input");
    const fs::path ir_path = require_option(options, "ir");
    const std::vector<Section> sections = parse_source(input_path);
    write_ir(ir_path, sections);
}

void run_backend(const std::unordered_map<std::string, std::string>& options) {
    const fs::path ir_path = require_option(options, "ir");
    const fs::path json_path = require_option(options, "json");
    const fs::path dot_path = require_option(options, "dot");

    const std::vector<Section> sections = read_ir(ir_path);
    const Graph graph = build_graph(sections);
    validate_graph(graph);

    atomic_write(json_path, graph_to_json(graph));
    atomic_write(dot_path, graph_to_dot(graph));
}

}  // namespace

int main(int argc, char** argv) {
    try {
        if (argc < 2) {
            fail("Expected command: frontend or backend");
        }

        const std::string command = argv[1];
        const auto options = parse_options(argc, argv, 2);

        if (command == "frontend") {
            run_frontend(options);
        } else if (command == "backend") {
            run_backend(options);
        } else {
            fail("Unknown command: " + command);
        }

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "dialogue compiler error: " << error.what() << '\n';
        return 2;
    }
}
"""


APP_DIR = Path(os.environ.get("APP_DIR", "/app"))
BUILD_DIR = APP_DIR / ".dialogue_native"
CPP_PATH = BUILD_DIR / "dialogue_compiler.cpp"
BINARY_PATH = BUILD_DIR / "dialogue_compiler"
SOURCE_HASH_PATH = BUILD_DIR / "source.sha256"


class DialogueCompileError(ValueError):
    pass


def _compiler_path() -> str:
    configured = os.environ.get("CXX")
    candidates = [configured] if configured else []
    candidates.extend(["g++", "c++", "clang++"])
    for candidate in candidates:
        if candidate:
            resolved = shutil.which(candidate)
            if resolved:
                return resolved
    raise DialogueCompileError(
        "No C++ compiler found. Install the distribution package 'g++'."
    )


def _write_if_changed(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = content.encode("utf-8")
    if path.exists() and path.read_bytes() == encoded:
        return
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(encoded)
    os.replace(temporary, path)


def ensure_native_compiler(force: bool = False) -> Path:
    source_hash = hashlib.sha256(CPP_SOURCE.encode("utf-8")).hexdigest()
    current_hash = (
        SOURCE_HASH_PATH.read_text(encoding="ascii").strip()
        if SOURCE_HASH_PATH.exists()
        else ""
    )

    if (
        not force
        and BINARY_PATH.is_file()
        and os.access(BINARY_PATH, os.X_OK)
        and current_hash == source_hash
    ):
        return BINARY_PATH

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    _write_if_changed(CPP_PATH, CPP_SOURCE)

    compiler = _compiler_path()
    command = [
        compiler,
        "-std=c++17",
        "-O2",
        "-DNDEBUG",
        "-Wall",
        "-Wextra",
        "-pedantic",
        str(CPP_PATH),
        "-o",
        str(BINARY_PATH),
    ]
    completed = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise DialogueCompileError(
            "Native compiler build failed:\n" + completed.stderr.strip()
        )

    SOURCE_HASH_PATH.write_text(source_hash + "\n", encoding="ascii")
    return BINARY_PATH


def _run_native(arguments: List[str]) -> None:
    binary = ensure_native_compiler()
    completed = subprocess.run(
        [str(binary), *arguments],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        message = completed.stderr.strip() or completed.stdout.strip()
        raise DialogueCompileError(message or "Native dialogue compiler failed")


def validate_graph_object(graph: Dict[str, Any]) -> None:
    if not isinstance(graph, dict) or set(graph) != {"nodes", "edges"}:
        raise DialogueCompileError(
            "Graph must be an object containing exactly nodes and edges"
        )
    if not isinstance(graph["nodes"], list) or not isinstance(graph["edges"], list):
        raise DialogueCompileError("nodes and edges must be arrays")
    if not graph["nodes"]:
        raise DialogueCompileError("Graph has no nodes")

    node_ids: List[str] = []
    node_id_set = set()
    for node in graph["nodes"]:
        if not isinstance(node, dict) or set(node) != {
            "id",
            "text",
            "speaker",
            "type",
        }:
            raise DialogueCompileError("Invalid node schema")
        if not all(
            isinstance(node[field], str)
            for field in ("id", "text", "speaker", "type")
        ):
            raise DialogueCompileError("Every node field must be a string")
        if node["type"] not in {"line", "choice"}:
            raise DialogueCompileError("Node type must be line or choice")
        if not node["id"] or node["id"] in node_id_set:
            raise DialogueCompileError("Node ids must be non-empty and unique")
        node_ids.append(node["id"])
        node_id_set.add(node["id"])

    adjacency = {node_id: [] for node_id in node_ids}
    for edge in graph["edges"]:
        if not isinstance(edge, dict) or set(edge) != {"from", "to", "text"}:
            raise DialogueCompileError("Invalid edge schema")
        if not all(isinstance(edge[field], str) for field in ("from", "to", "text")):
            raise DialogueCompileError("Every edge field must be a string")
        if edge["from"] not in node_id_set:
            raise DialogueCompileError(
                f"Edge source [{edge['from']}] does not exist"
            )
        if edge["to"] not in node_id_set and edge["to"] != "End":
            raise DialogueCompileError(
                f"Edge target [{edge['to']}] does not exist"
            )
        if edge["to"] in node_id_set:
            adjacency[edge["from"]].append(edge["to"])

    reachable = {node_ids[0]}
    pending = [node_ids[0]]
    while pending:
        source = pending.pop()
        for target in adjacency[source]:
            if target not in reachable:
                reachable.add(target)
                pending.append(target)

    unreachable = [node_id for node_id in node_ids if node_id not in reachable]
    if unreachable:
        raise DialogueCompileError(
            "Unreachable nodes: " + ", ".join(unreachable)
        )


def parse_script(text: str) -> Dict[str, Any]:
    """Compile script content through the native frontend/backend pipeline."""
    if not isinstance(text, str):
        raise TypeError("parse_script(text) expects script content as str")

    with tempfile.TemporaryDirectory(prefix="dialogue-native-") as temporary_dir:
        work = Path(temporary_dir)
        input_path = work / "script.txt"
        ir_path = work / "dialogue.ir"
        json_path = work / "dialogue.json"
        dot_path = work / "dialogue.dot"

        input_path.write_text(text, encoding="utf-8")
        _run_native(
            [
                "frontend",
                "--input",
                str(input_path),
                "--ir",
                str(ir_path),
            ]
        )
        _run_native(
            [
                "backend",
                "--ir",
                str(ir_path),
                "--json",
                str(json_path),
                "--dot",
                str(dot_path),
            ]
        )

        graph = json.loads(json_path.read_text(encoding="utf-8"))
        validate_graph_object(graph)
        return graph


def compile_files(
    input_path: Path,
    ir_path: Path,
    json_path: Path,
    dot_path: Path,
) -> Dict[str, Any]:
    _run_native(
        [
            "frontend",
            "--input",
            str(input_path),
            "--ir",
            str(ir_path),
        ]
    )
    _run_native(
        [
            "backend",
            "--ir",
            str(ir_path),
            "--json",
            str(json_path),
            "--dot",
            str(dot_path),
        ]
    )
    graph = json.loads(json_path.read_text(encoding="utf-8"))
    validate_graph_object(graph)

    dot = dot_path.read_text(encoding="utf-8")
    if not dot.startswith("digraph DialogueGraph") or not dot.rstrip().endswith("}"):
        raise DialogueCompileError("DOT output is malformed")
    return graph


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-native", action="store_true")
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--input", type=Path, default=APP_DIR / "script.txt")
    parser.add_argument("--ir", type=Path, default=BUILD_DIR / "dialogue.ir")
    parser.add_argument("--json", type=Path, default=APP_DIR / "dialogue.json")
    parser.add_argument("--dot", type=Path, default=APP_DIR / "dialogue.dot")
    args = parser.parse_args()

    if args.build_native:
        ensure_native_compiler(force=True)
        return

    if args.verify_only:
        graph = json.loads(args.json.read_text(encoding="utf-8"))
        validate_graph_object(graph)
        dot = args.dot.read_text(encoding="utf-8")
        if not dot.startswith("digraph DialogueGraph") or not dot.rstrip().endswith("}"):
            raise DialogueCompileError("DOT output is malformed")
        print(
            f"verified outputs: {len(graph['nodes'])} nodes, "
            f"{len(graph['edges'])} edges"
        )
        return

    graph = compile_files(args.input, args.ir, args.json, args.dot)
    print(
        f"generated {args.json} and {args.dot}: "
        f"{len(graph['nodes'])} nodes, {len(graph['edges'])} edges"
    )


if __name__ == "__main__":
    main()
PYTHON_EOF

chmod 0755 "${SOLUTION_DIR}/solution.py"

APP_DIR="${APP_DIR}" "${PYTHON_BIN}" "${SOLUTION_DIR}/solution.py" --build-native

APP_DIR="${APP_DIR}" "${PYTHON_BIN}" "${SOLUTION_DIR}/solution.py" \
    --input "${APP_DIR}/script.txt" \
    --ir "${BUILD_DIR}/dialogue.ir" \
    --json "${APP_DIR}/dialogue.json" \
    --dot "${APP_DIR}/dialogue.dot"

APP_DIR="${APP_DIR}" "${PYTHON_BIN}" "${SOLUTION_DIR}/solution.py" \
    --verify-only \
    --json "${APP_DIR}/dialogue.json" \
    --dot "${APP_DIR}/dialogue.dot"
