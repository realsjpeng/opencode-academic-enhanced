# syntax=docker/dockerfile:1
# SPDX-License-Identifier: GPL-3.0-only
#
# opencode-academic-enhanced
# Copyright (C) 2026 realsjpeng
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Build: docker build -t opencode-academic-enhanced .

FROM ubuntu:24.04

LABEL org.opencontainers.image.title="opencode-academic-enhanced"
LABEL org.opencontainers.image.description="opencode with pre-installed skills: docx/pdf/xlsx/pptx, agent-browser, academic-writing"
LABEL org.opencontainers.image.source="https://github.com/realsjpeng/opencode-academic-enhanced"
LABEL org.opencontainers.image.license="GPL-3.0-only"

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENCODE_DATA_DIR=/home/user/.local/share/opencode

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git \
    python3 python3-pip python3-venv \
    pandoc \
    libreoffice-core-nogui libreoffice-writer-nogui libreoffice-calc-nogui libreoffice-impress-nogui \
    poppler-utils \
    qpdf \
    tesseract-ocr \
    build-essential \
    ripgrep \
    fonts-liberation \
    libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 \
    libcups2t64 libdrm2 libgbm1 libnspr4 libnss3 \
    libu2f-udev libvulkan1 libxcomposite1 libxdamage1 libxfixes3 \
    libxkbcommon0 libxrandr2 xdg-utils \
    texlive-latex-base texlive-latex-recommended texlive-latex-extra \
    texlive-xetex texlive-bibtex-extra texlive-fonts-recommended \
    texlive-lang-chinese biber chktex \
    fonts-noto-cjk \
    tini \
    && rm -rf /var/lib/apt/lists/*

# ---- opencode binary (glibc build) ----
ARG OPENCODE_VERSION=latest
RUN set -eux; \
    if [ "$OPENCODE_VERSION" = "latest" ]; then \
      url="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz"; \
    else \
      url="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64.tar.gz"; \
    fi; \
    curl -fsSL "$url" -o /tmp/opencode.tar.gz; \
    mkdir -p /tmp/opencode-extract; \
    tar xzf /tmp/opencode.tar.gz -C /tmp/opencode-extract; \
    find /tmp/opencode-extract -type f -name 'opencode' -exec mv {} /usr/local/bin/opencode \; ; \
    chmod +x /usr/local/bin/opencode; \
    rm -rf /tmp/opencode.tar.gz /tmp/opencode-extract; \
    opencode --version

# Node.js 24.x (needed for agent-browser build, docx, pptxgenjs)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Python packages for document skills
RUN pip3 install --break-system-packages --no-cache-dir \
    pypdf pdfplumber reportlab \
    pytesseract pdf2image pypdfium2 \
    pandas openpyxl \
    Pillow "markitdown[pptx]" \
    PyYAML Jinja2

# npm packages for document creation (docx, pptxgenjs)
RUN npm install -g docx pptxgenjs

# agent-browser + Chrome
RUN npm install -g agent-browser \
    && agent-browser install

# Typst CLI (for academic-writing typst skill)
RUN curl -fsSL https://github.com/typst/typst/releases/download/v0.14.1/typst-x86_64-unknown-linux-musl.tar.xz \
    | tar xJ -C /tmp \
    && mv /tmp/typst-x86_64-unknown-linux-musl/typst /usr/local/bin/typst \
    && rm -rf /tmp/typst-x86_64-unknown-linux-musl

# Create user and prepare directories
# Docker Desktop for Windows maps host UID to 1000 inside the container.
# Ubuntu 24.04 base image may have 'ubuntu' user (UID 1000) or not — handle both.
# We ensure 'user' ends up with UID 1000 for correct volume mount permissions.
RUN if id ubuntu 2>/dev/null; then \
        usermod -l user ubuntu && \
        groupmod -n user ubuntu && \
        usermod -d /home/user -m user; \
    else \
        useradd -m -s /bin/bash -u 1000 user; \
    fi \
    && mkdir -p /home/user/.claude/skills \
    /home/user/.config/opencode \
    /home/user/.local/share \
    /home/user/.local/state \
    /workspace

# ---- Anthropic document skills (docx, pdf, xlsx, pptx) ----
# These are already available in the workspace for this build, but for a standalone
# build we clone from the anthropics/skills repo.
# The document skills share a common scripts/office/ directory.
RUN git clone --depth 1 --single-branch https://github.com/anthropics/skills.git /tmp/anthropic-skills \
    && for skill in docx pdf xlsx pptx; do \
        cp -r /tmp/anthropic-skills/skills/$skill /home/user/.claude/skills/$skill; \
    done \
    && rm -rf /tmp/anthropic-skills

# ---- agent-browser skill (discovery stub) ----
# The actual skill content is served dynamically by `agent-browser skills get core`
RUN mkdir -p /home/user/.claude/skills/agent-browser
COPY skills/agent-browser/SKILL.md /home/user/.claude/skills/agent-browser/SKILL.md

# ---- academic-writing-skills (latex-paper-en, latex-thesis-zh, typst-paper, bib-search-citation, paper-audit, cover-letter) ----
RUN git clone --depth 1 --single-branch https://github.com/bahayonghang/academic-writing-skills.git /tmp/academic-skills \
    && for skill in latex-paper-en latex-thesis-zh typst-paper bib-search-citation paper-audit cover-letter; do \
        cp -r /tmp/academic-skills/academic-writing-skills/$skill /home/user/.claude/skills/$skill; \
    done \
    && rm -rf /tmp/academic-skills

# Copy global opencode config
COPY opencode.json /home/user/.config/opencode/opencode.json

# Copy workspace opencode config (as project-level default)
COPY opencode.json /workspace/opencode.json

RUN chown -R user:user /home/user

# Entrypoint runs as root, fixes mount permissions, then drops to user
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

EXPOSE 4096
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/entrypoint.sh"]
CMD ["web", "--hostname", "0.0.0.0"]
