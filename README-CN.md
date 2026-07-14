# OpenCode 学术增强版 Docker 镜像

<div align="right">
  <a href="README.md">English</a>
</div>

[![Docker Build](https://github.com/realsjpeng/opencode-academic-enhanced/actions/workflows/build.yml/badge.svg)](https://github.com/realsjpeng/opencode-academic-enhanced/actions/workflows/build.yml)

> 🎯 **不想读长文档？** 查看 [功能幻灯 →](https://realsjpeng.github.io/opencode-academic-enhanced/)（中文 / English）

本镜像基于 **Ubuntu 24.04** 构建，预装 [OpenCode](https://opencode.ai/) 及学术相关 Skill 集合，覆盖文献检索、论文复现、写作到投稿全流程。由于官方 OpenCode Docker 镜像在 Ubuntu 下无法直接使用，本镜像提供了一个完全自包含的开箱即用环境。

> **面向用户**：希望使用 AI 辅助学术研究的学生、研究人员，无需掌握 Python、Docker 等技术细节即可上手。

---

## 什么是 OpenCode？

[OpenCode](https://opencode.ai/) 是一个开源的 AI 编程助手（CLI 工具），通过 **Skill（技能）** 扩展能力。你只需用自然语言说出需求，AI 自动调用各类 Skill 完成实际任务。

本镜像是 OpenCode 的增强版，额外预装了：

- **文档 Skills**：[docx / pdf / xlsx / pptx](https://github.com/anthropics/skills)（通过 LibreOffice + Python 实现文件读写）
- **搜索工具**：`websearch`（内置，调用 Exa AI + Parallel 搜索）、`webfetch`（按 URL 抓取网页内容）、[agent-browser](https://github.com/vercel-labs/agent-browser)（浏览器自动化）
- **学术写作 Skills**：[academic-writing / latex-paper-en / typst-paper / paper-audit / bib-search-citation / cover-letter](https://github.com/bahayonghang/academic-writing-skills)（LaTeX / Typst 论文模板、审稿检查、文献引用、投稿信）

---

## 快速开始

### 方式 A：一键运行（推荐）

```bash
# Linux / macOS / WSL
bash <(curl -fsSL https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.sh)

# Windows (PowerShell)
powershell -c "iex ((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.ps1').Content)"
```

> **脚本拉不下来？** 如果 `raw.githubusercontent.com` 无法访问，用 `ghfast.top` 代理即可：
> ```bash
> bash <(curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.sh)
> ```
> ```powershell
> powershell -c "iex ((Invoke-WebRequest -Uri 'https://ghfast.top/https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/start.ps1').Content)"
> ```
> 或直接 clone 仓库：
> ```bash
> git clone https://github.com/realsjpeng/opencode-academic-enhanced.git && cd opencode-academic-enhanced && bash start.sh
> ```
> ```powershell
> git clone https://github.com/realsjpeng/opencode-academic-enhanced.git; cd opencode-academic-enhanced; .\start.ps1
> ```

脚本自动处理所有事情：

- **端口** — 询问你（默认 `4096`），如果被占用会自动递增
- **数据目录** — 询问你（默认 `./opencode-data`）—— 保存聊天记录、API Key、配置；容器内挂载到 `/home/user/.local/share/opencode`
- **工作目录** — 询问你（默认当前目录 `.`）—— 你的项目文件；容器内挂载到 `/workspace`，AI 可以直接读写
- **升级** — 检测已有容器，询问是否拉取新版镜像并保留所有配置和数据
- **桌面程序** — 自动安装 OpenCode Desktop 原生应用，配置其连接到此容器并启动

### 方式 B：Docker Compose

```bash
curl -fsSL https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/realsjpeng/opencode-academic-enhanced/main/.env.example -o .env.example
cp .env.example .env   # 编辑 PORT、DATA_DIR、WORKSPACE
docker compose up -d
```

默认值与脚本一致：端口 `4096`、数据目录 `./data`、工作目录 `.`。编辑 `.env` 自定义。

### 方式 C：手动 Docker 命令

```bash
docker pull ghcr.io/realsjpeng/opencode-academic-enhanced:latest
docker run -d --name opencode-academic-enhanced -p 4096:4096 \
  -v "${PWD}/data:/home/user/.local/share/opencode" \
  -v "${PWD}:/workspace" \
  --restart unless-stopped \
  ghcr.io/realsjpeng/opencode-academic-enhanced:latest
```

### 4. 开始使用

打开浏览器访问 http://127.0.0.1:4096，用自然语言描述需求，例如：

> *"帮我调研 arXiv 上最新的 AI agent 论文，做个 PPT 报告选出一个值得做的 idea，把引用存到 bib。然后基于这个调研写一篇学术论文，引用之前的 bib 数据。"*

AI 会自动依次调用搜索 → 分析 → 写作技能完成全流程。

---

## 典型工作流

```
Step 1: 文献检索与 Idea 搜寻
  ↓  websearch → 分析整理 → bib
Step 2: 论文复现
  ↓  代码获取 → 复现运行 → 结果记录
Step 3: 论文写作
  ↓  academic-writing → paper-audit
产出: 论文 .tex/.typ + Cover Letter
```

**Step 1** — AI 检索学术文章，筛选高价值文献，提取关键 Idea，保存引用到 BibTeX。

**Step 2** — AI 获取论文官方代码或开源实现，自动配置环境并运行实验，验证关键结果后保存复现报告。

**Step 3** — AI 基于 Step 1 & 2 的引用数据和复现结果生成论文初稿（标题、摘要、引言、方法、实验框架），等待你填入核心数据（表格、图片），最后用 paper-audit 做投稿前检查。

---

## 预装 Skills 一览

| Skill 名称 | 来源 | 作用 |
|---|---|---|
| docx / pdf / xlsx / pptx | [anthropics/skills](https://github.com/anthropics/skills) | 读写 Office 文档和 PDF |
| `websearch` | 内置 | 网页搜索（Exa AI + Parallel），无需 API Key |
| `webfetch` | 内置 | 按 URL 抓取网页内容 |
| agent-browser | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | 浏览器自动化（导航、点击、填表、截图） |
| academic-writing / latex-paper-en / typst-paper / paper-audit / bib-search-citation / cover-letter | [bahayonghang/academic-writing-skills](https://github.com/bahayonghang/academic-writing-skills) | 学术写作、审稿检查、文献引用、投稿信 |
| customize-opencode | 内置 | OpenCode 配置管理 |

---

## 环境变量

| 变量 | 说明 |
|---|---|
| `OPENCODE_DATA_DIR` | 数据持久化目录（默认为 `~/.opencode`） |
| `OPENCODE_ALLOWED_DIRS` | 允许 AI 访问的目录（默认仅限当前目录） |

---

## 数据持久化

聊天记录、API Key 和配置通过 Docker 卷挂载持久化。容器内关键路径：

| 内容 | 容器内路径 |
|---|---|
| 聊天记录 (SQLite) | `/home/user/.local/share/opencode/` |
| 用户配置 & API Key | `/home/user/.config/opencode/` |

### 各启动方式的数据目录

| 方式 | 数据目录 | 配置方法 |
|---|---|---|
| **A: 一键脚本** | `./opencode-data`（默认） | 脚本会询问 `DATA_DIR`，自动挂载 |
| **B: Docker Compose** | `./data`（默认） | 编辑 `.env` 中的 `DATA_DIR` |
| **C: 手动 Docker** | 任意路径 | 传入 `-v /your/data/dir:/home/user/.local/share/opencode` |

首次启动后配置 API Key：

```bash
docker exec -it opencode-academic-enhanced opencode providers
```

Key 保存在持久化目录中，删除容器后不丢失。

### 升级方式

| 方式 | 升级命令 |
|---|---|
| **A: 一键脚本** | 重新运行脚本，自动检测已有容器并提供保留配置的升级选项 |
| **B: Docker Compose** | `docker compose pull && docker compose up -d` |
| **C: 手动 Docker** | `docker pull ghcr.io/realsjpeng/opencode-academic-enhanced:latest && docker stop opencode-academic-enhanced && docker rm opencode-academic-enhanced && docker run -d --name opencode-academic-enhanced -p 4096:4096 -v /your/data/dir:/home/user/.local/share/opencode -v "${PWD}:/workspace" --restart unless-stopped ghcr.io/realsjpeng/opencode-academic-enhanced:latest` |

---

## 自行构建

```bash
git clone https://github.com/realsjpeng/opencode-academic-enhanced.git
cd opencode-academic-enhanced
docker build -t ghcr.io/realsjpeng/opencode-academic-enhanced:latest .
```

---

## 相关资源

- [OpenCode 官方文档](https://opencode.ai)
- [GitHub 仓库](https://github.com/anomalyco/opencode)
- [Skill 市场](https://agensi.io/skills)

---

## 许可

本项目采用 **GNU General Public License v3.0** 开源协议，详见 [LICENSE](./LICENSE) 文件。

镜像中打包的第三方工具（TeX Live、Chrome、LibreOffice 等）遵循各自的开源许可。