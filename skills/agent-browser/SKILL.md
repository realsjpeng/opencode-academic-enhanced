---
name: agent-browser
description: "Use this skill when the user wants to automate browser interactions including navigating to web pages, clicking elements, filling forms, taking screenshots, extracting data from web pages, or performing any web-based task. This skill provides access to agent-browser CLI for browser automation. Use when the user mentions 'browser', 'web', 'website', 'click', 'form fill', 'screenshot', 'scrape', 'automate browser', or similar web automation tasks."
allowed-tools:
  - Bash(agent-browser:*)
  - Bash(npx agent-browser:*)
---

# agent-browser: Browser automation for AI agents

This is a discovery stub. Before running any agent-browser command, load the actual workflow content from the CLI:

```
agent-browser skills get core
agent-browser skills get core --full
```

The CLI serves skill content that always matches the installed version, so instructions never go stale.

## Quick start

```bash
agent-browser open <url>
agent-browser snapshot -i          # Interactive elements only
agent-browser click @e2            # Click by ref from snapshot
agent-browser fill @e3 "text"      # Fill by ref
agent-browser screenshot page.png
agent-browser close
```

## Available sub-skills

```
agent-browser skills get core             # Main usage guide (start here)
agent-browser skills get electron         # Electron desktop app automation
agent-browser skills get slack            # Slack workspace automation
agent-browser skills get dogfood          # Exploratory testing/QA
agent-browser skills get vercel-sandbox   # Vercel Sandbox microVMs
agent-browser skills get agentcore        # AWS Bedrock AgentCore
```

## Diagnostic

```
agent-browser doctor     # Check installation
agent-browser --version  # Show version
```
