#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Copyright (C) 2026 realsjpeng
# This program is free software under the GPLv3.
set -e

# --- Language detection ---
if [[ "${LANG:-}" =~ ^zh ]] || [[ "${LC_ALL:-}" =~ ^zh ]]; then
  _() { echo -e "$2"; }
else
  _() { echo -e "$1"; }
fi

# --- Color codes ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- Header ---
echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE}  $(_ "OpenCode Academic Enhanced - One-Click Launcher" "OpenCode Academic Enhanced - 一键启动")${NC}"
echo -e "${BLUE}========================================================${NC}"

# --- Docker check ---
if ! command -v docker &> /dev/null; then
  echo -e "${YELLOW}$(_ "Docker is not installed. Install now?" "Docker 未安装，是否自动安装？") (Y/N)${NC}"
  read -r INSTALL_DOCKER
  if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}$(_ "Installing Docker..." "正在安装 Docker...")${NC}"
    case "$(uname -s)" in
      Linux*)
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER" || true
        echo -e "${GREEN}$(_ "Docker installed. Please log out and back in, then re-run this script." "Docker 安装完成。请注销后重新登录，再运行本脚本。")${NC}"
        exit 0
        ;;
      Darwin*)
        if command -v brew &>/dev/null; then
          brew install --cask docker
        else
          curl -fsSL https://desktop.docker.com/mac/stable/Docker.dmg -o /tmp/Docker.dmg
          hdiutil attach /tmp/Docker.dmg
          cp -R /Volumes/Docker/Docker.app /Applications
          hdiutil detach /Volumes/Docker
        fi
        open /Applications/Docker.app
        echo -e "${GREEN}$(_ "Docker Desktop is being installed. Launch it, then re-run this script." "Docker Desktop 正在安装。请启动后重新运行本脚本。")${NC}"
        exit 0
        ;;
    esac
  else
    echo -e "${RED}$(_ "Please install Docker manually:" "请手动安装 Docker:") https://docker.com/get-started${NC}"
    exit 1
  fi
fi

# --- Network detection ---
echo -e "\n${YELLOW}$(_ "Detecting network..." "检测网络环境...")${NC}"
if curl -s -o /dev/null --connect-timeout 3 https://www.google.com; then
  echo -e "${GREEN}$(_ "Direct access available" "外网正常，使用直连")${NC}"
  IMAGE="ghcr.io/realsjpeng/opencode-academic-enhanced:latest"
else
  echo -e "${YELLOW}$(_ "Restricted network detected, using proxy" "检测到网络限制，使用代理镜像拉取")${NC}"
  IMAGE="ghcr.nju.edu.cn/realsjpeng/opencode-academic-enhanced:latest"
fi

# --- Existing container check (upgrade or reinstall) ---
if docker inspect opencode-academic &>/dev/null; then
  echo ""
  echo -e "${YELLOW}$(_ "Container 'opencode-academic' already exists." "容器 'opencode-academic' 已存在。")${NC}"
  echo "  1) $(_ "Upgrade - pull new image, keep config" "升级 - 拉取新镜像，保留配置")"
  echo "  2) $(_ "Reinstall - reconfigure" "重新安装 - 重新配置")"
  echo "  3) $(_ "Cancel" "取消")"
  read -p "$(_ "Choose (1/2/3)" "请选择 (1/2/3)") [1]: " ACTION; ACTION=${ACTION:-1}
  case "$ACTION" in
    1)
      echo -e "\n${YELLOW}$(_ "Reading existing config..." "读取现有配置...")${NC}"
      PORT=$(docker inspect opencode-academic --format='{{(index (index .NetworkSettings.Ports "4096/tcp") 0).HostPort}}')
      DATA_DIR_FULL=$(docker inspect opencode-academic --format='{{range .Mounts}}{{if eq .Destination "/home/user/.local/share/opencode"}}{{.Source}}{{end}}{{end}}')
      WORKSPACE_FULL=$(docker inspect opencode-academic --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}')
      echo -e "   $(_ "Port" "端口"):       ${CYAN}${PORT}${NC}"
      echo -e "   $(_ "Data dir" "数据目录"): ${CYAN}${DATA_DIR_FULL:-(none)}${NC}"
      echo -e "   $(_ "Workspace" "工作目录"): ${CYAN}${WORKSPACE_FULL:-(none)}${NC}"
      if [ -z "$PORT" ] || [ -z "$DATA_DIR_FULL" ] || [ -z "$WORKSPACE_FULL" ]; then
        echo -e "${YELLOW}$(_ "Warning: some config missing, falling back to defaults" "某些配置缺失，回退到默认值")${NC}"
        PORT="${PORT:-4096}"
        DATA_DIR_FULL="${DATA_DIR_FULL:-$(pwd)/opencode-data}"
        WORKSPACE_FULL="${WORKSPACE_FULL:-$(pwd)}"
      fi
      mkdir -p "$DATA_DIR_FULL" "$WORKSPACE_FULL" 2>/dev/null || true
      echo -e "\n${YELLOW}$(_ "Pulling latest image..." "拉取最新镜像...")${NC}"
      docker pull "$IMAGE"
      echo -e "\n${GREEN}$(_ "Upgrading container..." "升级容器...")${NC}"
      docker rm -f opencode-academic 2>/dev/null || true
      docker run -d --name opencode-academic \
        -p "${PORT}":4096 \
        -v "${DATA_DIR_FULL}:/home/user/.local/share/opencode" \
        -v "${WORKSPACE_FULL}:/workspace" \
        --restart unless-stopped \
        "$IMAGE"
      echo -e "\n${GREEN}$(_ "Upgrade complete!" "升级完成！")${NC}"
      echo -e "   $(_ "Open" "访问地址"): ${BLUE}http://127.0.0.1:${PORT}${NC}"
      case "$(uname -s)" in
        Linux*)  if command -v xdg-open &>/dev/null; then xdg-open "http://127.0.0.1:${PORT}"; fi ;;
        Darwin*) open "http://127.0.0.1:${PORT}" ;;
      esac
      exit 0
      ;;
    2)
      echo -e "${YELLOW}$(_ "Removing old container..." "删除旧容器...")${NC}"
      docker rm -f opencode-academic 2>/dev/null || true
      ;;
    *)
      exit 0
      ;;
  esac
fi

# --- User input ---
echo ""
read -p "$(_ "Port number" "端口号") [4096]: " PORT; PORT=${PORT:-4096}
read -p "$(_ "Data persistence directory" "数据持久化目录") [./opencode-data]: " DATA_DIR; DATA_DIR=${DATA_DIR:-./opencode-data}
read -p "$(_ "Working directory" "工作目录") [.]: " WORKSPACE; WORKSPACE=${WORKSPACE:-.}

mkdir -p "$DATA_DIR"
DATA_DIR_FULL="$(cd "$DATA_DIR" && pwd)"
WORKSPACE_FULL="$(cd "$WORKSPACE" && pwd)"

# --- Port conflict detection ---
while [ "$PORT" -le 65535 ]; do
  if command -v ss &>/dev/null; then
    ss -tlnp "sport = :$PORT" 2>/dev/null | grep -q . || break
  elif command -v lsof &>/dev/null; then
    lsof -i :"$PORT" &>/dev/null || break
  else
    break
  fi
  PORT=$((PORT + 1))
done
if [ "$PORT" -gt 65535 ]; then
  echo -e "${RED}$(_ "No available port found (exhausted)." "找不到可用端口。")${NC}"
  exit 1
fi

# --- Preview ---
echo ""
echo -e "${YELLOW}$(_ "Configuration preview:" "配置预览:")${NC}"
echo -e "   $(_ "Image" "镜像"):      ${CYAN}${IMAGE}${NC}"
echo -e "   $(_ "Port" "端口"):       ${CYAN}${PORT}${NC}"
echo -e "   $(_ "Data dir" "数据目录"): ${CYAN}${DATA_DIR_FULL}${NC}"
echo -e "   $(_ "Workspace" "工作目录"): ${CYAN}${WORKSPACE_FULL}${NC}"

# --- Pull ---
echo ""
echo -e "${YELLOW}$(_ "Pulling image..." "拉取镜像中...")${NC}"
docker pull "$IMAGE"

# --- Run ---
echo -e "\n${GREEN}$(_ "Starting container..." "启动容器...")${NC}"
docker rm -f opencode-academic 2>/dev/null || true
docker run -d --name opencode-academic \
  -p "${PORT}":4096 \
  -v "${DATA_DIR_FULL}:/home/user/.local/share/opencode" \
  -v "${WORKSPACE_FULL}:/workspace" \
  --restart unless-stopped \
  "$IMAGE"

# --- Success ---
echo -e "\n${GREEN}$(_ "Success!" "启动成功！")${NC}"
echo -e "   $(_ "Open" "访问地址"): ${BLUE}http://127.0.0.1:${PORT}${NC}"

echo ""
echo -e "${YELLOW}$(_ "How to use OpenCode?" "如何使用 OpenCode？")${NC}"
echo "  1) $(_ "Open in browser" "在浏览器中打开")"
echo "  2) $(_ "Install OpenCode Desktop & connect" "安装 OpenCode Desktop 并连接")"
read -p "$(_ "Choose (1/2)" "请选择 (1/2)") [1]: " LAUNCH; LAUNCH=${LAUNCH:-1}

case "$LAUNCH" in
  2)
    echo -e "${YELLOW}$(_ "Installing OpenCode Desktop..." "正在安装 OpenCode Desktop...")${NC}"
    case "$(uname -s)" in
      Linux*)
        if command -v dpkg &>/dev/null; then
          curl -fsSL https://github.com/anomalyco/opencode/releases/latest/download/opencode-desktop-linux-x64.deb -o /tmp/opencode-desktop.deb
          sudo dpkg -i /tmp/opencode-desktop.deb 2>/dev/null || sudo apt-get install -f -y /tmp/opencode-desktop.deb
        elif command -v rpm &>/dev/null; then
          curl -fsSL https://github.com/anomalyco/opencode/releases/latest/download/opencode-desktop-linux-x64.rpm -o /tmp/opencode-desktop.rpm
          sudo rpm -i /tmp/opencode-desktop.rpm
        else
          curl -fsSL https://github.com/anomalyco/opencode/releases/latest/download/opencode-desktop-linux-x64.AppImage -o ~/opencode-desktop.AppImage
          chmod +x ~/opencode-desktop.AppImage
        fi
        CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
        ;;
      Darwin*)
        ARCH_FLAG=""
        [ "$(uname -m)" = "arm64" ] && ARCH_FLAG="-aarch64" || ARCH_FLAG="-x64"
        curl -fsSL "https://github.com/anomalyco/opencode/releases/latest/download/opencode-desktop-darwin${ARCH_FLAG}.dmg" -o /tmp/opencode-desktop.dmg
        hdiutil attach /tmp/opencode-desktop.dmg
        cp -R /Volumes/OpenCode/OpenCode.app /Applications
        hdiutil detach /Volumes/OpenCode
        CONF_DIR="$HOME/Library/Application Support/opencode"
        ;;
      *)
        echo -e "${RED}$(_ "Unsupported OS for Desktop install. Open browser instead." "不支持的操作系统，将在浏览器中打开。")${NC}"
        exit 0
        ;;
    esac
    mkdir -p "$CONF_DIR"
    cat > "$CONF_DIR/opencode.json" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "server": {
    "hostname": "127.0.0.1",
    "port": ${PORT}
  }
}
EOF
    echo -e "\n${GREEN}$(_ "OpenCode Desktop installed! Launching..." "OpenCode Desktop 已安装！正在启动...")${NC}"
    if command -v opencode-desktop &>/dev/null; then
      opencode-desktop &
    elif [ -f ~/opencode-desktop.AppImage ]; then
      ~/opencode-desktop.AppImage &
    elif [ -d /Applications/OpenCode.app ]; then
      open /Applications/OpenCode.app
    fi
    echo -e "   $(_ "Desktop configured to connect to" "已配置 Desktop 连接至") http://127.0.0.1:${PORT}"
    ;;
  *)
    case "$(uname -s)" in
      Linux*)  if command -v xdg-open &>/dev/null; then xdg-open "http://127.0.0.1:${PORT}"; fi ;;
      Darwin*) open "http://127.0.0.1:${PORT}" ;;
    esac
    ;;
esac

# --- Tips ---
echo ""
echo -e "${YELLOW}$(_ "Useful commands:" "后续管理命令:")${NC}"
echo -e "   $(_ "View logs" "查看日志"):   ${CYAN}docker logs -f opencode-academic${NC}"
echo -e "   $(_ "Stop" "停止容器"):        ${CYAN}docker stop opencode-academic${NC}"
echo -e "   $(_ "Start" "启动容器"):       ${CYAN}docker start opencode-academic${NC}"
echo -e "   $(_ "Configure API" "配置 API"): ${CYAN}docker exec -it opencode-academic opencode providers${NC}"
