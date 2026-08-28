FROM python:3.11-slim

RUN sed -i -e 's|http://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' -e 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    numpy==1.24.3 \
    scipy==1.11.1 \
    pytest==7.4.0

# Set working directory
WORKDIR /root

# Copy data files (including input video)
COPY data /root/data

# Copy skills to all agent-specific locations
# Claude Code
COPY skills /root/.claude/skills
# Codex
COPY skills /root/.codex/skills
# OpenCode
COPY skills /root/.opencode/skill
# Goose
COPY skills /root/.goose/skills
# Factory
COPY skills /root/.factory/skills
# Portable agents format (Goose, Amp)
COPY skills /root/.agents/skills
# Qwen
COPY skills /root/.qwen/skills
