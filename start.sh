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

# --- Uninstall option ---
echo ""
  echo -e "  ${YELLOW}[U] $(_ "Uninstall all components" "卸载全部组件")${NC}"
echo -e "  ${GREEN}[Enter]$(_ " to continue setup" "继续安装")${NC}"
read -p "$(_ "Choose" "请选择") (U/Enter): " UNINSTALL_CHOICE
if [[ "$UNINSTALL_CHOICE" =~ ^[Uu]$ ]]; then
  echo -e "\n${RED}$(_ "=== Uninstalling OpenCode Academic Enhanced ===" "=== 卸载 OpenCode Academic Enhanced ===")${NC}"

  # 1. Stop & remove container
  if docker inspect opencode-academic &>/dev/null 2>&1; then
    echo -e "${YELLOW}$(_ "Stopping and removing container..." "停止并删除容器...")${NC}"
    docker rm -f opencode-academic 2>/dev/null || true
    echo -e "  ${GREEN}✔$(_ " Container removed" " 容器已删除")${NC}"
  else
    echo -e "  ${CYAN}-$(_ " Container not found" " 容器不存在")${NC}"
  fi

  # 2. Remove Docker image
  if docker images ghcr.io/realsjpeng/opencode-academic-enhanced --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}$(_ "Removing Docker image..." "删除 Docker 镜像...")${NC}"
    docker images ghcr.io/realsjpeng/opencode-academic-enhanced --format "{{.Repository}}:{{.Tag}}" 2>/dev/null \
      | xargs -r docker rmi -f 2>/dev/null || true
    echo -e "  ${GREEN}✔$(_ " Image removed" " 镜像已删除")${NC}"
  else
    echo -e "  ${CYAN}-$(_ " Image not found" " 镜像不存在")${NC}"
  fi

  # 3. Remove OpenCode Desktop
  case "$(uname -s)" in
    Linux*)
      if command -v opencode-desktop &>/dev/null || [ -f ~/opencode-desktop.AppImage ]; then
        echo -e "${YELLOW}$(_ "Removing OpenCode Desktop..." "移除 OpenCode Desktop...")${NC}"
        if command -v dpkg &>/dev/null && dpkg -l opencode-desktop &>/dev/null 2>&1; then
          sudo dpkg -r opencode-desktop 2>/dev/null || true
        fi
        rm -f ~/opencode-desktop.AppImage 2>/dev/null || true
        echo -e "  ${GREEN}✔$(_ " OpenCode Desktop removed" " OpenCode Desktop 已移除")${NC}"
      fi
      ;;
    Darwin*)
      if [ -d /Applications/OpenCode.app ]; then
        echo -e "${YELLOW}$(_ "Removing OpenCode Desktop..." "移除 OpenCode Desktop...")${NC}"
        rm -rf /Applications/OpenCode.app 2>/dev/null || true
        echo -e "  ${GREEN}✔$(_ " OpenCode Desktop removed" " OpenCode Desktop 已移除")${NC}"
      fi
      ;;
    *)
      echo -e "  ${CYAN}-$(_ " Skipping Desktop removal on this OS" " 跳过 Desktop 卸载")${NC}"
      ;;
  esac

  # 4. Docker Desktop (optional)
  echo ""
  echo -e "${YELLOW}$(_ "Remove Docker Desktop as well?" "是否同时卸载 Docker Desktop？") (y/N)${NC}"
  read -r REMOVE_DOCKER
  if [[ "$REMOVE_DOCKER" =~ ^[Yy]$ ]]; then
    case "$(uname -s)" in
      Linux*)
        if command -v docker &>/dev/null; then
          sudo apt-get remove -y docker-desktop docker-ce docker-ce-cli containerd.io 2>/dev/null || true
          sudo rm -f /usr/local/bin/docker 2>/dev/null || true
        fi
        ;;
      Darwin*)
        if [ -d /Applications/Docker.app ]; then
          rm -rf /Applications/Docker.app 2>/dev/null || true
        fi
        ;;
    esac
    echo -e "  ${GREEN}✔$(_ " Docker Desktop removed" " Docker Desktop 已卸载")${NC}"
  fi

  # 5. Data directories (optional)
  echo ""
  echo -e "${YELLOW}$(_ "Remove data/config directories (chat history, API keys)?" "是否删除数据/配置目录（聊天记录、API Key）？") (y/N)${NC}"
  read -r REMOVE_DATA
  if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
    rm -rf ./opencode-data 2>/dev/null || true
    echo -e "  ${GREEN}✔$(_ " Data directories removed" " 数据目录已删除")${NC}"
  fi

  echo -e "\n${GREEN}$(_ "Uninstall complete!" "卸载完成！")${NC}"
  exit 0
fi

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

# --- Multi-mirror speed test ---
# Test all available mirrors, rank by response time, then use the fastest.
# If docker pull fails on the chosen mirror, fall back to the next one.
#
# Known GHCR mirrors (2026-07):
#   ghcr.nju.edu.cn     - 南京大学 (HTTP 200, confirmed working)
#   ghcr.registry.cyou  - registry.cyou (HTTP 200, confirmed working)
#   ghcr.1ms.run        - 毫秒镜像 (HTTP 401, standard Docker auth flow)
#   ghcr.chenby.cn      - ChenBy proxy (HTTP 401, standard Docker auth flow)
#   ghcr.m.daocloud.io  - DaoCloud (HTTP 401, standard Docker auth flow)
echo -e "\n${YELLOW}$(_ "Testing mirror speeds..." "测试镜像速度...")${NC}"
MIRROR_LIST=(
  "ghcr.io"
  "ghcr.nju.edu.cn"
  "ghcr.registry.cyou"
  "ghcr.1ms.run"
  "ghcr.chenby.cn"
  "ghcr.m.daocloud.io"
)
declare -A MIRROR_TIMES
for NAME in "${MIRROR_LIST[@]}"; do
  TIME=$(curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
    -w "%{time_connect}" "https://$NAME/v2/" 2>/dev/null || echo "999")
  TIME_MS=$(echo "$TIME * 1000 / 1" | bc 2>/dev/null || echo "$TIME" | awk '{printf "%.0f", $1*1000}' 2>/dev/null || echo "99999")
  if [ "$TIME_MS" -lt 90000 ] 2>/dev/null; then
    echo -e "  ${GREEN}$NAME${NC}: ${TIME_MS}ms"
    MIRROR_TIMES[$NAME]=$TIME_MS
  else
    echo -e "  ${RED}$NAME${NC}: unreachable"
  fi
done
if [ ${#MIRROR_TIMES[@]} -eq 0 ]; then
  echo -e "${RED}$(_ "All mirrors unreachable. Check your network." "所有镜像都无法访问，请检查网络。")${NC}"
  exit 1
fi
# Sort mirrors by time (fastest first)
SORTED_MIRRORS=()
for NAME in "${MIRROR_LIST[@]}"; do
  if [ -n "${MIRROR_TIMES[$NAME]}" ]; then
    SORTED_MIRRORS+=("$NAME:${MIRROR_TIMES[$NAME]}")
  fi
done
SORTED_MIRRORS=($(printf '%s\n' "${SORTED_MIRRORS[@]}" | sort -t: -k2 -n))
echo -e "${GREEN}$(_ "Mirror ranking" "镜像排名")${NC}:"
for i in "${!SORTED_MIRRORS[@]}"; do
  NAME="${SORTED_MIRRORS[$i]%%:*}"
  echo -e "  $((i+1)). $NAME (${MIRROR_TIMES[$NAME]}ms)"
done

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
      PULL_OK=0
      for MIRROR_ENTRY in "${SORTED_MIRRORS[@]}"; do
        MIRROR="${MIRROR_ENTRY%%:*}"
        IMAGE="$MIRROR/realsjpeng/opencode-academic-enhanced:latest"
        echo -e "  ${YELLOW}$(_ "Trying mirror" "尝试镜像")${NC}: $IMAGE"
        if docker pull "$IMAGE"; then
          PULL_OK=1
          break
        fi
      done
      if [ "$PULL_OK" -eq 0 ]; then
        echo -e "${RED}$(_ "All mirrors failed. Check your network." "所有镜像都拉取失败，请检查网络。")${NC}"
        exit 1
      fi
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
echo -e "   $(_ "Port" "端口"):       ${CYAN}${PORT}${NC}"
echo -e "   $(_ "Data dir" "数据目录"): ${CYAN}${DATA_DIR_FULL}${NC}"
echo -e "   $(_ "Workspace" "工作目录"): ${CYAN}${WORKSPACE_FULL}${NC}"

# --- Pull with mirror fallback ---
PULL_OK=0
for MIRROR_ENTRY in "${SORTED_MIRRORS[@]}"; do
  MIRROR="${MIRROR_ENTRY%%:*}"
  IMAGE="$MIRROR/realsjpeng/opencode-academic-enhanced:latest"
  echo ""
  echo -e "${YELLOW}$(_ "Trying mirror" "尝试镜像")${NC}: $IMAGE"
  if docker pull "$IMAGE"; then
    PULL_OK=1
    break
  fi
  echo -e "${YELLOW}$(_ "Mirror failed, trying next..." "镜像失败，尝试下一个...")${NC}"
done
if [ "$PULL_OK" -eq 0 ]; then
  echo -e "${RED}$(_ "All mirrors failed. Check your network." "所有镜像都拉取失败，请检查网络。")${NC}"
  exit 1
fi

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
