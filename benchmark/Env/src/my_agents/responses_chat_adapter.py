from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


def log_event(event: str, **fields: Any) -> None:
    print(json.dumps({"event": event, **fields}, ensure_ascii=False), file=sys.stderr, flush=True)


def content_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts: list[str] = []
    for part in content:
        if not isinstance(part, dict):
            continue
        if part.get("type") in {"input_text", "output_text", "text"}:
            text = part.get("text")
            if isinstance(text, str):
                parts.append(text)
    return "\n".join(parts)


def responses_input_to_messages(payload: dict[str, Any]) -> list[dict[str, Any]]:
    messages: list[dict[str, Any]] = []
    instructions = payload.get("instructions")
    if isinstance(instructions, str) and instructions:
        messages.append({"role": "system", "content": instructions})

    pending_tool_calls: list[dict[str, Any]] = []

    def flush_tool_calls() -> None:
        nonlocal pending_tool_calls
        if pending_tool_calls:
            messages.append(
                {"role": "assistant", "content": None, "tool_calls": pending_tool_calls}
            )
            pending_tool_calls = []

    source = payload.get("input", [])
    if isinstance(source, str):
        source = [{"type": "message", "role": "user", "content": source}]

    for item in source if isinstance(source, list) else []:
        if not isinstance(item, dict):
            continue
        item_type = item.get("type")
        if item_type == "function_call":
            pending_tool_calls.append(
                {
                    "id": item.get("call_id")
                    or item.get("id")
                    or f"call_{uuid.uuid4().hex}",
                    "type": "function",
                    "function": {
                        "name": item.get("name", ""),
                        "arguments": item.get("arguments", "{}"),
                    },
                }
            )
            continue

        flush_tool_calls()
        if item_type == "function_call_output":
            output = item.get("output", "")
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": item.get("call_id") or item.get("id", ""),
                    "content": content_text(output) or str(output),
                }
            )
        elif item_type == "message" or "role" in item:
            role = item.get("role", "user")
            if role == "developer":
                role = "system"
            messages.append({"role": role, "content": content_text(item.get("content"))})

    flush_tool_calls()
    return messages


def responses_tools_to_chat(payload: dict[str, Any]) -> list[dict[str, Any]]:
    tools: list[dict[str, Any]] = []
    for tool in payload.get("tools", []):
        if not isinstance(tool, dict) or tool.get("type") != "function":
            continue
        tools.append(
            {
                "type": "function",
                "function": {
                    "name": tool.get("name", ""),
                    "description": tool.get("description", ""),
                    "parameters": tool.get(
                        "parameters", {"type": "object", "properties": {}}
                    ),
                },
            }
        )
    return tools


def call_chat_completions(payload: dict[str, Any]) -> dict[str, Any]:
    base_url = os.environ.get("DMX_ADAPTER_UPSTREAM_BASE_URL", "").rstrip("/")
    api_key = os.environ.get("DMX_ADAPTER_API_KEY", "")
    if not base_url or not api_key:
        raise RuntimeError(
            "DMX_ADAPTER_UPSTREAM_BASE_URL and DMX_ADAPTER_API_KEY are required"
        )

    tools = responses_tools_to_chat(payload)
    chat_payload: dict[str, Any] = {
        "model": payload["model"],
        "messages": responses_input_to_messages(payload),
        "temperature": 0,
    }
    if tools:
        chat_payload["tools"] = tools
        chat_payload["tool_choice"] = "auto"

    request = urllib.request.Request(
        base_url + "/chat/completions",
        data=json.dumps(chat_payload).encode(),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    log_event(
        "upstream_request",
        model=payload["model"],
        message_count=len(chat_payload["messages"]),
        tool_count=len(tools),
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            result = json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        log_event("upstream_error", status=exc.code, body=detail)
        raise RuntimeError(f"Upstream HTTP {exc.code}: {detail}") from exc
    log_event(
        "upstream_response",
        finish_reason=(result.get("choices") or [{}])[0].get("finish_reason"),
        model=result.get("model"),
    )
    return result


def response_base(
    response_id: str,
    model: str,
    output: list[dict[str, Any]],
    status: str,
) -> dict[str, Any]:
    return {
        "id": response_id,
        "object": "response",
        "created_at": int(time.time()),
        "status": status,
        "error": None,
        "incomplete_details": None,
        "instructions": None,
        "max_output_tokens": None,
        "model": model,
        "output": output,
        "parallel_tool_calls": True,
        "previous_response_id": None,
        "reasoning": {"effort": None, "summary": None},
        "store": False,
        "temperature": 0,
        "text": {"format": {"type": "text"}},
        "tool_choice": "auto",
        "tools": [],
        "top_p": 1,
        "truncation": "disabled",
        "usage": {
            "input_tokens": 0,
            "input_tokens_details": {"cached_tokens": 0},
            "output_tokens": 0,
            "output_tokens_details": {"reasoning_tokens": 0},
            "total_tokens": 0,
        },
        "user": None,
        "metadata": {},
    }


def make_events(
    payload: dict[str, Any], chat_result: dict[str, Any]
) -> list[dict[str, Any]]:
    response_id = f"resp_{uuid.uuid4().hex}"
    model = payload["model"]
    message = chat_result["choices"][0]["message"]
    output: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = [
        {
            "type": "response.created",
            "sequence_number": 0,
            "response": response_base(response_id, model, [], "in_progress"),
        }
    ]
    sequence = 1

    text = message.get("content")
    if isinstance(text, str) and text:
        item_id = f"msg_{uuid.uuid4().hex}"
        part = {
            "type": "output_text",
            "annotations": [],
            "logprobs": [],
            "text": text,
        }
        item = {
            "id": item_id,
            "type": "message",
            "status": "completed",
            "role": "assistant",
            "content": [part],
        }
        output_index = len(output)
        events.extend(
            [
                {
                    "type": "response.output_item.added",
                    "sequence_number": sequence,
                    "output_index": output_index,
                    "item": {**item, "status": "in_progress", "content": []},
                },
                {
                    "type": "response.content_part.added",
                    "sequence_number": sequence + 1,
                    "item_id": item_id,
                    "output_index": output_index,
                    "content_index": 0,
                    "part": {
                        "type": "output_text",
                        "annotations": [],
                        "logprobs": [],
                        "text": "",
                    },
                },
                {
                    "type": "response.output_text.delta",
                    "sequence_number": sequence + 2,
                    "item_id": item_id,
                    "output_index": output_index,
                    "content_index": 0,
                    "delta": text,
                    "logprobs": [],
                },
                {
                    "type": "response.output_text.done",
                    "sequence_number": sequence + 3,
                    "item_id": item_id,
                    "output_index": output_index,
                    "content_index": 0,
                    "text": text,
                    "logprobs": [],
                },
                {
                    "type": "response.content_part.done",
                    "sequence_number": sequence + 4,
                    "item_id": item_id,
                    "output_index": output_index,
                    "content_index": 0,
                    "part": part,
                },
                {
                    "type": "response.output_item.done",
                    "sequence_number": sequence + 5,
                    "output_index": output_index,
                    "item": item,
                },
            ]
        )
        sequence += 6
        output.append(item)

    for tool_call in message.get("tool_calls") or []:
        function = tool_call.get("function", {})
        arguments = function.get("arguments", "{}")
        item_id = f"fc_{uuid.uuid4().hex}"
        item = {
            "id": item_id,
            "type": "function_call",
            "status": "completed",
            "arguments": arguments,
            "call_id": tool_call.get("id") or f"call_{uuid.uuid4().hex}",
            "name": function.get("name", ""),
        }
        output_index = len(output)
        events.extend(
            [
                {
                    "type": "response.output_item.added",
                    "sequence_number": sequence,
                    "output_index": output_index,
                    "item": {**item, "status": "in_progress", "arguments": ""},
                },
                {
                    "type": "response.function_call_arguments.delta",
                    "sequence_number": sequence + 1,
                    "item_id": item_id,
                    "output_index": output_index,
                    "delta": arguments,
                },
                {
                    "type": "response.function_call_arguments.done",
                    "sequence_number": sequence + 2,
                    "item_id": item_id,
                    "output_index": output_index,
                    "arguments": arguments,
                },
                {
                    "type": "response.output_item.done",
                    "sequence_number": sequence + 3,
                    "output_index": output_index,
                    "item": item,
                },
            ]
        )
        sequence += 4
        output.append(item)

    completed = response_base(response_id, model, output, "completed")
    usage = chat_result.get("usage") or {}
    completed["usage"] = {
        "input_tokens": usage.get("prompt_tokens", 0),
        "input_tokens_details": {
            "cached_tokens": (usage.get("prompt_tokens_details") or {}).get(
                "cached_tokens", 0
            )
        },
        "output_tokens": usage.get("completion_tokens", 0),
        "output_tokens_details": {"reasoning_tokens": 0},
        "total_tokens": usage.get("total_tokens", 0),
    }
    events.append(
        {
            "type": "response.completed",
            "sequence_number": sequence,
            "response": completed,
        }
    )
    return events


class AdapterHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        body = b'{"status":"ok"}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        if not self.path.rstrip("/").endswith("/responses"):
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length))
        try:
            events = make_events(payload, call_chat_completions(payload))
        except Exception as exc:
            body = json.dumps(
                {
                    "error": {
                        "message": str(exc),
                        "type": "adapter_error",
                        "code": "adapter_error",
                    }
                }
            ).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        for event in events:
            self.wfile.write(
                f"data: {json.dumps(event, ensure_ascii=False)}\n\n".encode()
            )
            self.wfile.flush()
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()
        self.close_connection = True

    def log_message(self, format: str, *args: object) -> None:
        return


def main() -> None:
    port = int(os.environ.get("DMX_ADAPTER_PORT", "18766"))
    ThreadingHTTPServer(("127.0.0.1", port), AdapterHandler).serve_forever()


if __name__ == "__main__":
    main()
