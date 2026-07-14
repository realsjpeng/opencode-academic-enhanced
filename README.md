# OpenCode Academic Enhanced Docker Image

<div align="right">
  <a href="README-CN.md">中文版本</a>
</div>

[![Docker Build](https://github.com/realsjpeng/opencode-academic-enhanced/actions/workflows/build.yml/badge.svg)](https://github.com/realsjpeng/opencode-academic-enhanced/actions/workflows/build.yml)

> 🎯 **Prefer a visual overview?** Check out the [feature slide deck →](https://realsjpeng.github.io/opencode-academic-enhanced/) (English / 中文)

This Docker image is built from **Ubuntu 24.04**, with [OpenCode](https://opencode.ai/) and academic-oriented skill collections pre-installed — covering literature search, paper reproduction, writing, and submission, all in one conversation. Note that the official OpenCode Docker image has usability issues on Ubuntu, so this image provides a fully self-contained, ready-to-use environment.

> **Target users**: Students and researchers who want AI-assisted academic work without needing Python or Docker expertise.

---

## What is OpenCode?

[OpenCode](https://opencode.ai/) is an open-source AI coding assistant (CLI tool) that extends capabilities through **Skills**. You describe your needs in natural language, and AI automatically invokes the appropriate skills to complete tasks.

This enhanced image adds:

- **Document Skills**: [docx / pdf / xlsx / pptx](https://github.com/anthropics/skills) (file I/O via LibreOffice + Python)
- **Search Tools**: `websearch` (built-in, uses Exa AI + Parallel search), `webfetch` (fetch any URL), [agent-browser](https://github.com/vercel-labs/agent-browser) (browser automation)
- **Academic Writing Skills**: [academic-writing / latex-paper-en / typst-paper / paper-audit / bib-search-citation / cover-letter](https://github.com/bahayonghang/academic-writing-skills) (LaTeX / Typst templates, paper audit, citation management, cover letter generation)

---

## Quick Start

### Option A: One-Click Run (Recommended)

```bash
# Linux / macOS / WSL
bash <(curl -fsSL https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.sh)

# Windows (PowerShell)
powershell -c "iex ((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.ps1').Content)"
```

> **Script not downloading?** If `raw.githubusercontent.com` is inaccessible, use a proxy:
> ```bash
> bash <(curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.sh)
> ```
> ```powershell
> powershell -c "iex ((Invoke-WebRequest -Uri 'https://ghfast.top/https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.ps1').Content)"
> ```
> Or clone the repo instead:
> ```bash
> git clone https://github.com/realsjpeng/opencode-academic-enhanced.git && cd opencode-academic-enhanced && bash start.sh
> ```
> ```powershell
> git clone https://github.com/realsjpeng/opencode-academic-enhanced.git; cd opencode-academic-enhanced; .\start.ps1
> ```

The script handles everything automatically:

- **Port** — prompts you (default `4096`), auto-increments if busy
- **Data dir** — prompts you (default `./opencode-data`) — stores chat history, API keys, config; mounted to `/home/user/.local/share/opencode` inside the container
- **Workspace** — prompts you (default current directory `.`) — your project files; mounted to `/workspace` inside the container so AI can read/write them
- **Upgrade** — detects an existing container and offers to pull a newer image while preserving all config and data
- **Desktop** — auto-installs the native OpenCode Desktop app, configures it to connect to this container, and launches it

### Option B: Docker Compose

```bash
curl -fsSL https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/.env.example -o .env.example
cp .env.example .env   # edit PORT, DATA_DIR, WORKSPACE
docker compose up -d
```

Same defaults as the script: port `4096`, data dir `./data`, workspace `.`. Edit `.env` to customize.

### Option C: Manual Docker Run

```bash
docker pull ghcr.io/realsjpeng/opencode-academic-enhanced:latest
docker run -d --name opencode-academic-enhanced -p 4096:4096 \
  -v "${PWD}/data:/home/user/.local/share/opencode" \
  -v "${PWD}:/workspace" \
  --restart unless-stopped \
  ghcr.io/realsjpeng/opencode-academic-enhanced:latest
```

### 4. Start Using

Open http://127.0.0.1:4096 in your browser, then describe your needs in natural language, for example:

> *"Search arXiv for the latest AI agent papers, create a PPT report, pick a promising idea, save citations to bib. Then write an academic paper based on the research, citing the bib data."*

AI will automatically invoke search → analysis → writing skills to complete the full workflow.

---

## Typical Workflow

```
Step 1: Literature Search & Idea Mining
  ↓  websearch → analyze → bib
Step 2: Paper Reproduction
  ↓  get code → run experiments → record results
Step 3: Paper Writing
  ↓  academic-writing → paper-audit
Output: .tex/.typ paper + Cover Letter
```

**Step 1** — AI searches academic articles, filters high-value literature, extracts key ideas, and saves citations to BibTeX.

**Step 2** — AI fetches official code or open-source implementations, configures the environment, runs experiments, verifies key results, and saves a reproduction report.

**Step 3** — AI generates a paper draft (title, abstract, introduction, method, experiment framework) based on citations from Step 1 & 2, waits for you to fill in core data (tables, figures), then runs paper-audit for pre-submission checks.

---

## Pre-installed Skills

| Skill | Source | Purpose |
|---|---|---|
| docx / pdf / xlsx / pptx | [anthropics/skills](https://github.com/anthropics/skills) | Read/write Office documents and PDFs |
| `websearch` | built-in | Web search (Exa AI + Parallel), no API key needed |
| `webfetch` | built-in | URL content retrieval |
| agent-browser | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | Browser automation (navigation, click, form fill, screenshots) |
| academic-writing / latex-paper-en / typst-paper / paper-audit / bib-search-citation / cover-letter | [bahayonghang/academic-writing-skills](https://github.com/bahayonghang/academic-writing-skills) | Academic writing, paper audit, citation management, cover letter |
| customize-opencode | built-in | OpenCode configuration management |

---

## Environment Variables

| Variable | Description |
|---|---|
| `OPENCODE_DATA_DIR` | Data persistence directory (default: `~/.opencode`) |
| `OPENCODE_ALLOWED_DIRS` | Directories AI is allowed to access (default: current dir only) |

---

## Data Persistence

Chat history, API keys, and configuration are persisted via Docker volumes. The key paths inside the container:

| Content | Container Path |
|---|---|
| Chat history (SQLite) | `/home/user/.local/share/opencode/` |
| User config & API keys | `/home/user/.config/opencode/` |

### Persistence by Startup Method

| Method | Data Directory | How to Configure |
|---|---|---|
| **A: One-Click Script** | `./opencode-data` (default) | The script prompts for `DATA_DIR`, mounts it automatically |
| **B: Docker Compose** | `./data` (default) | Edit `DATA_DIR` in `.env` file |
| **C: Manual Docker** | any path | Pass `-v /your/data/dir:/home/user/.local/share/opencode` |

Configure API keys after first start:

```bash
docker exec -it opencode-academic-enhanced opencode providers
```

Keys are saved to the persistent data directory and survive container deletion.

### Upgrading

| Method | Upgrade Command |
|---|---|
| **A: One-Click Script** | Re-run the script — it detects the existing container and offers to upgrade with preserved config |
| **B: Docker Compose** | `docker compose pull && docker compose up -d` |
| **C: Manual Docker** | `docker pull ghcr.io/realsjpeng/opencode-academic-enhanced:latest && docker stop opencode-academic-enhanced && docker rm opencode-academic-enhanced && docker run -d --name opencode-academic-enhanced -p 4096:4096 -v /your/data/dir:/home/user/.local/share/opencode -v "${PWD}:/workspace" --restart unless-stopped ghcr.io/realsjpeng/opencode-academic-enhanced:latest` |

---

## Build from Source

```bash
git clone https://github.com/realsjpeng/opencode-academic-enhanced.git
cd opencode-academic-enhanced
docker build -t ghcr.io/realsjpeng/opencode-academic-enhanced:latest .
```

---

## Resources

- [OpenCode Documentation](https://opencode.ai)
- [GitHub Repository](https://github.com/anomalyco/opencode)
- [Skill Marketplace](https://agensi.io/skills)

---

## License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](./LICENSE) file for details.

Third-party tools bundled in the Docker image (TeX Live, Chrome, LibreOffice, etc.) are subject to their respective open-source licenses.