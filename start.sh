#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Copyright (C) 2026 realsjpeng
# This program is free software under the GPLv3.
set -e

# --- Registry prefixes (used by uninstall and mirror test) ---
IMAGE_REGISTRIES=(
  "ghcr.nju.edu.cn"
  "ghcr.io"
  "ghcr.registry.cyou"
)

# --- Language detection ---
if [[ "${LANG:-}${LC_ALL:-}" =~ ^zh ]]; then
  _() { echo -e "$2"; }
else
  _() { echo -e "$1"; }
fi

# --- Color codes ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- Helper functions ---
write_color() { echo -e "$2" | sed 's/^/  /'; }

start_docker_with_retry() {
  local max=${1:-12} interval=${2:-5}
  local launched=false docker_exe
  case "$(uname -s)" in
    Linux*)
      docker_exe=""
      for p in /usr/bin/docker /usr/local/bin/docker /snap/bin/docker; do
        [ -x "$p" ] && docker_exe="$p" && break
      done
      if command -v systemctl &>/dev/null && ! docker info &>/dev/null 2>&1; then
        echo -e "  ${YELLOW}$(_ "Starting Docker daemon..." "正在启动 Docker 守护进程...")${NC}"
        sudo systemctl start docker 2>/dev/null || true
        launched=true
      fi
      ;;
    Darwin*)
      docker_exe=""
      for p in /Applications/Docker.app/Contents/MacOS/Docker; do
        [ -x "$p" ] && docker_exe="$p" && break
      done
      if [ -n "$docker_exe" ] && ! docker info &>/dev/null 2>&1; then
        echo -e "  ${YELLOW}$(_ "Starting Docker Desktop..." "正在启动 Docker Desktop...")${NC}"
        open -a Docker
        launched=true
      fi
      ;;
  esac
  for i in $(seq 1 "$max"); do
    if docker info &>/dev/null 2>&1; then return 0; fi
    if ! $launched && [ -n "$docker_exe" ]; then
      echo -e "  ${YELLOW}$(_ "Starting Docker..." "正在启动 Docker...")${NC}"
      launched=true
    fi
    echo -e "  ${CYAN}$(_ "Waiting..." "等待中...") (${i}/${max})${NC}"
    sleep "$interval"
  done
  return 1
}

# --- Read-Host equivalent with flush ---
prompt() {
  printf "%s " "$1"
  read -r "$2"
}

# --- Header ---
echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE}  $(_ "OpenCode Academic Enhanced - One-Click Launcher" "OpenCode Academic Enhanced - 一键启动")${NC}"
echo -e "${BLUE}========================================================${NC}"

# --- Uninstall option ---
echo ""
echo -e "  ${YELLOW}[U] $(_ "Uninstall all components" "卸载全部组件")${NC}"
echo -e "  ${GREEN}[Enter]$(_ " to continue setup" "继续安装")${NC}"
prompt "$(_ "Choose" "请选择") (U/Enter):" UNINSTALL_CHOICE
if [[ "$UNINSTALL_CHOICE" =~ ^[Uu]$ ]]; then
  echo -e "\n${RED}$(_ "=== Uninstalling OpenCode Academic Enhanced ===" "=== 卸载 OpenCode Academic Enhanced ===")${NC}"
  # 1. Stop & remove container
  if docker inspect opencode-academic-enhanced &>/dev/null 2>&1; then
    echo -e "${YELLOW}$(_ "Stopping and removing container..." "停止并删除容器...")${NC}"
    docker rm -f opencode-academic-enhanced 2>/dev/null || true
    echo -e "  ${GREEN}✔$(_ " Container removed" " 容器已删除")${NC}"
  else
    echo -e "  ${CYAN}-$(_ " Container not found" " 容器不存在")${NC}"
  fi
  # 2. Remove Docker image (check all known registries)
  IMAGE_LIST=""
  for REG in "${IMAGE_REGISTRIES[@]}"; do
    IMG=$(docker images "$REG/realsjpeng/opencode-academic-enhanced" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)
    [ -n "$IMG" ] && IMAGE_LIST="$IMAGE_LIST $IMG"
  done
  if [ -n "$IMAGE_LIST" ]; then
    echo -e "${YELLOW}$(_ "Removing Docker image..." "删除 Docker 镜像...")${NC}"
    # shellcheck disable=SC2086
    docker rmi -f $IMAGE_LIST 2>/dev/null || true
    echo -e "  ${GREEN}✔$(_ " Image removed" " 镜像已删除")${NC}"
  else
    echo -e "  ${CYAN}-$(_ " Image not found" " 镜像不存在")${NC}"
  fi
  # 3. OpenCode Desktop (optional, default No to avoid accidental data loss)
  DESKTOP_DIR=""
  case "$(uname -s)" in
    Linux*)
      for d in ~/opencode-desktop ~/.local/share/opencode-desktop /opt/opencode-desktop; do
        [ -d "$d" ] && { DESKTOP_DIR="$d"; break; }
      done
      if [ -z "$DESKTOP_DIR" ] && command -v opencode-desktop &>/dev/null; then
        DESKTOP_DIR=$(command -v opencode-desktop)
      fi
      ;;
    Darwin*)
      for d in /Applications/OpenCode.app "$HOME/Applications/OpenCode.app"; do
        [ -d "$d" ] && { DESKTOP_DIR="$d"; break; }
      done
      ;;
  esac
  if [ -n "$DESKTOP_DIR" ]; then
    echo ""
    echo -e "${RED}$(_ "CAUTION: You are likely using OpenCode Desktop right now." "注意：您当前很可能正在使用 OpenCode Desktop。")${NC}"
    echo -e "${YELLOW}$(_ "Also remove OpenCode Desktop? (y/N)" "是否同时卸载 OpenCode Desktop？(y/N)")${NC}"
    prompt "" REMOVE_DESKTOP
    if [[ "$REMOVE_DESKTOP" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}$(_ "Removing OpenCode Desktop..." "移除 OpenCode Desktop...")${NC}"
      case "$(uname -s)" in
        Linux*)
          if command -v dpkg &>/dev/null && dpkg -l opencode-desktop &>/dev/null 2>&1; then
            sudo dpkg -r opencode-desktop 2>/dev/null || true
          fi
          rm -rf "$DESKTOP_DIR" 2>/dev/null || true
          rm -f ~/.local/share/applications/opencode-desktop.desktop 2>/dev/null || true
          ;;
        Darwin*)
          rm -rf "$DESKTOP_DIR" 2>/dev/null || true
          ;;
      esac
      echo -e "  ${GREEN}✔$(_ " OpenCode Desktop removed" " OpenCode Desktop 已移除")${NC}"
    else
      echo -e "  ${CYAN}-$(_ " OpenCode Desktop kept" "保留 OpenCode Desktop")${NC}"
    fi
  else
    echo -e "  ${CYAN}-$(_ " OpenCode Desktop not found" "未安装 OpenCode Desktop")${NC}"
  fi
  # 4. Docker Desktop (optional)
  echo ""
  echo -e "${YELLOW}$(_ "Remove Docker Desktop as well?" "是否同时卸载 Docker Desktop？") (y/N)${NC}"
  prompt "" REMOVE_DOCKER
  if [[ "$REMOVE_DOCKER" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}$(_ "Uninstalling Docker Desktop..." "卸载 Docker Desktop...")${NC}"
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
  prompt "" REMOVE_DATA
  if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
    rm -rf ./opencode-data 2>/dev/null || true
    echo -e "  ${GREEN}✔$(_ " Data directories removed" " 数据目录已删除")${NC}"
  fi
  echo -e "\n${GREEN}$(_ "Uninstall complete!" "卸载完成！")${NC}"
  exit
fi

# --- Docker check ---
if ! command -v docker &>/dev/null; then
  echo ""
  prompt "$(_ "Docker is not installed. Install now? (Y/N)" "Docker 未安装，是否自动安装？(Y/N)")" INSTALL_DOCKER
  if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}$(_ "Installing Docker..." "正在安装 Docker...")${NC}"
    case "$(uname -s)" in
      Linux*)
        curl -fsSL https://get.docker.com | sh
        ;;
      Darwin*)
        URL='https://desktop.docker.com/mac/stable/Docker.dmg'
        TMP_DMG=$(mktemp /tmp/docker-XXXXXX.dmg)
        curl -L --progress-bar -o "$TMP_DMG" "$URL"
        hdiutil attach "$TMP_DMG" -quiet
        cp -R "/Volumes/Docker/Docker.app" /Applications/
        hdiutil detach "/Volumes/Docker" -quiet
        rm -f "$TMP_DMG"
        ;;
    esac
    echo -e "${YELLOW}$(_ "Docker installed, waiting for Docker daemon to start..." "Docker 已安装，等待 Docker 守护进程启动...")${NC}"
    if start_docker_with_retry 30 5; then
      echo -e "  ${GREEN}✔$(_ " Docker is ready! Continuing setup..." " Docker 已就绪！继续安装...")${NC}"
    else
      echo -e "${RED}$(_ "Docker did not start in time. Please start Docker manually and retry." "Docker 未能及时启动，请手动启动 Docker 后重试。")${NC}"
      exit 1
    fi
  else
    echo -e "${RED}$(_ "Please install Docker manually:" "请手动安装 Docker:") https://docker.com/get-started${NC}"
    exit 1
  fi
fi

# --- Multi-mirror speed test ---
echo ""
prompt "$(_ "Test mirror speeds for fallback? (Y = yes / n = skip, default ghcr.io)" "是否测试备用镜像速度？(Y = 测试 / n = 跳过，默认 ghcr.io)") (Y/n)" SKIP_MIRROR_TEST
if [[ "$SKIP_MIRROR_TEST" =~ ^[Nn]$ ]]; then
  echo -e "  ${GREEN}$(_ "Will try mirrors if ghcr.io fails" "ghcr.io 失败后将自动尝试备用镜像")${NC}"
  SORTED_MIRRORS=()
  for NAME in "${IMAGE_REGISTRIES[@]}"; do
    [ "$NAME" != "ghcr.io" ] && SORTED_MIRRORS+=("$NAME")
  done
else
  echo -e "\n${YELLOW}$(_ "Testing mirror speeds..." "测试镜像速度...")${NC}"
  declare -A MIRROR_TIMES
  for NAME in "${IMAGE_REGISTRIES[@]}"; do
    TIME=$(curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
      -w "%{time_connect}" "https://$NAME/v2/" 2>/dev/null || echo "999")
    TIME_MS=$(echo "$TIME * 1000 / 1" | bc 2>/dev/null || printf "%.0f" "$(echo "$TIME * 1000" | bc 2>/dev/null)" 2>/dev/null || echo "99999")
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
  # Sort by time (fastest first), exclude ghcr.io for mirror list
  SORTED_MIRRORS=()
  for NAME in "${IMAGE_REGISTRIES[@]}"; do
    [ "$NAME" = "ghcr.io" ] && continue
    [ -n "${MIRROR_TIMES[$NAME]}" ] && SORTED_MIRRORS+=("$NAME:${MIRROR_TIMES[$NAME]}")
  done
  IFS=$'\n' SORTED_MIRRORS=($(for M in "${SORTED_MIRRORS[@]}"; do echo "$M"; done | sort -t: -k2 -n))
  echo -e "${GREEN}$(_ "Mirror ranking" "镜像排名")${NC}:"
  for i in "${!SORTED_MIRRORS[@]}"; do
    M=${SORTED_MIRRORS[$i]}
    NAME="${M%%:*}"
    MS="${M##*:}"
    echo -e "  ${CYAN}$((i+1)). $NAME (${MS}ms)${NC}"
  done
  # Extract just the names for later use
  MIRROR_NAMES=()
  for M in "${SORTED_MIRRORS[@]}"; do
    MIRROR_NAMES+=("${M%%:*}")
  done
  SORTED_MIRRORS=("${MIRROR_NAMES[@]}")
fi

# --- Docker daemon health check ---
echo -e "${YELLOW}$(_ "Waiting for Docker daemon to start..." "等待 Docker 守护进程启动...")${NC}"
if ! start_docker_with_retry 12 5; then
  echo -e "${RED}$(_ "Docker daemon is not running. Please start Docker Desktop manually and retry." "Docker 守护进程未运行，请手动启动 Docker Desktop 后重试。")${NC}"
  exit 1
fi

IMAGE=""  # Will be set during pull

# --- Existing container check (upgrade or reinstall) ---
if docker inspect opencode-academic-enhanced &>/dev/null 2>&1; then
  echo ""
  echo -e "${YELLOW}$(_ "Container opencode-academic-enhanced already exists." "容器 opencode-academic-enhanced 已存在。")${NC}"
  echo "  1) $(_ "Upgrade - pull new image, keep config" "升级 - 拉取新镜像，保留配置")"
  echo "  2) $(_ "Reinstall - reconfigure" "重新安装 - 重新配置")"
  echo "  3) $(_ "Cancel" "取消")"
  prompt "$(_ "Choose (1/2/3)" "请选择 (1/2/3)") [1]" ACTION
  if [ -z "$ACTION" ]; then ACTION="1"; fi
  case "$ACTION" in
    "1")
      echo -e "\n${YELLOW}$(_ "Reading existing config..." "读取现有配置...")${NC}"
      PORT=$(docker inspect opencode-academic-enhanced --format='{{(index (index .NetworkSettings.Ports "4096/tcp") 0).HostPort}}')
      DATA_DIR_FULL=$(docker inspect opencode-academic-enhanced --format='{{range .Mounts}}{{if eq .Destination "/home/user/.local/share/opencode"}}{{.Source}}{{end}}{{end}}')
      WORKSPACE_FULL=$(docker inspect opencode-academic-enhanced --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}')
      [ -z "$PORT" ] && PORT=4096
      [ -z "$DATA_DIR_FULL" ] && DATA_DIR_FULL="$(pwd)/opencode-data"
      [ -z "$WORKSPACE_FULL" ] && WORKSPACE_FULL="$(pwd)"
      echo -e "  ${CYAN}$(_ "Port" "端口"):       $PORT${NC}"
      echo -e "  ${CYAN}$(_ "Data dir" "数据目录"): $DATA_DIR_FULL${NC}"
      echo -e "  ${CYAN}$(_ "Workspace" "工作目录"): $WORKSPACE_FULL${NC}"
      echo -e "\n${YELLOW}$(_ "Checking latest image..." "检查最新镜像...")${NC}"
      PULL_OK=false
      IMG="ghcr.io/realsjpeng/opencode-academic-enhanced:latest"
      LOCAL_DIGESTS=$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{"\n"}}{{end}}' 2>/dev/null)
      if [ -n "$LOCAL_DIGESTS" ]; then
        REMOTE_DIGEST=$(curl -s -D - -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
          "https://ghcr.io/v2/realsjpeng/opencode-academic-enhanced/manifests/latest" \
          -o /dev/null 2>/dev/null | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')
        if [ -n "$REMOTE_DIGEST" ] && echo "$LOCAL_DIGESTS" | grep -q "$REMOTE_DIGEST"; then
          echo -e "  ${GREEN}✔$(_ " Image is up-to-date, skipping pull" "镜像已是最新，跳过下载")${NC}"
          IMAGE="$IMG"
          PULL_OK=true
        fi
      fi
      if ! $PULL_OK; then
        echo -e "${YELLOW}$(_ "Trying primary registry" "尝试主仓库"): $IMG${NC}"
        if docker pull "$IMG"; then
          IMAGE="$IMG"
          PULL_OK=true
        fi
      fi
      if ! $PULL_OK; then
        for NAME in "${SORTED_MIRRORS[@]}"; do
          IMG="$NAME/realsjpeng/opencode-academic-enhanced:latest"
          echo -e "${YELLOW}$(_ "Trying mirror" "尝试镜像"): $IMG${NC}"
          for RETRY in 0 1; do
            [ "$RETRY" -gt 0 ] && echo -e "  ${YELLOW}$(_ "Retrying" "重试") (${RETRY}/1)...${NC}" && \
              docker system prune -f --all --filter "label=org.opencontainers.image.source=ghcr.io" 2>/dev/null || true
            if docker pull "$IMG"; then
              IMAGE="$IMG"
              PULL_OK=true
              break
            fi
          done
          $PULL_OK && break
        done
      fi
      if ! $PULL_OK; then
        echo -e "${RED}$(_ "All mirrors failed. Check your network." "所有镜像都拉取失败，请检查网络。")${NC}"
        exit 1
      fi
      echo -e "\n${GREEN}$(_ "Upgrading container..." "升级容器...")${NC}"
      docker rm -f opencode-academic-enhanced 2>/dev/null || true
      RUN_OUTPUT=$(docker run -d --name opencode-academic-enhanced \
        -p "${PORT}":4096 \
        -v "${DATA_DIR_FULL}:/home/user/.local/share/opencode" \
        -v "${WORKSPACE_FULL}:/workspace" \
        --restart unless-stopped \
        "$IMAGE" 2>&1)
      if [ $? -ne 0 ]; then
        echo -e "${RED}$(_ "Failed to start container:" "容器启动失败:") $RUN_OUTPUT${NC}"
        exit 1
      fi
      sleep 3
      STATUS=$(docker inspect opencode-academic-enhanced --format='{{.State.Status}}' 2>/dev/null)
      if [ "$STATUS" != "running" ]; then
        echo -e "${YELLOW}$(_ "Container exited. Logs:" "容器已退出，日志:")${NC}"
        docker logs opencode-academic-enhanced 2>/dev/null
      fi
      echo -e "\n${GREEN}$(_ "Upgrade complete!" "升级完成！")${NC}"
      echo -e "   ${CYAN}$(_ "Open" "访问地址"): http://127.0.0.1:${PORT}${NC}"
      case "$(uname -s)" in
        Linux*)  command -v xdg-open &>/dev/null && xdg-open "http://127.0.0.1:${PORT}" ;;
        Darwin*) open "http://127.0.0.1:${PORT}" ;;
      esac
      exit
      ;;
    "2")
      echo -e "${YELLOW}$(_ "Removing old container..." "删除旧容器...")${NC}"
      docker rm -f opencode-academic-enhanced 2>/dev/null || true
      ;;
    *) exit ;;
  esac
fi

# --- User input ---
echo ""
prompt "$(_ "Port number" "端口号") [4096]" PORT_INPUT
PORT="${PORT_INPUT:-4096}"

prompt "$(_ "Data persistence directory" "数据持久化目录") [./opencode-data]" DATA_DIR_INPUT
DATA_DIR="${DATA_DIR_INPUT:-./opencode-data}"

prompt "$(_ "Working directory" "工作目录") [.]" WORKSPACE_INPUT
WORKSPACE="${WORKSPACE_INPUT:-.}"

mkdir -p "$DATA_DIR" 2>/dev/null || true
# Cross-platform realpath
realpath_f() {
  case "$(uname -s)" in
    Darwin*) perl -e 'use Cwd qw(abs_path); print abs_path($ARGV[0])' "$1" 2>/dev/null || echo "$(cd "$1" && pwd)" ;;
    *) realpath "$1" 2>/dev/null || readlink -f "$1" 2>/dev/null || echo "$(cd "$1" && pwd)" ;;
  esac
}
DATA_DIR_FULL=$(realpath_f "$DATA_DIR")
WORKSPACE_FULL=$(realpath_f "$WORKSPACE")

# --- Port conflict detection ---
port_in_use() {
  if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -q ":$1\b" && return 0 || return 1
  elif command -v netstat &>/dev/null; then
    netstat -tlnp 2>/dev/null | grep -q ":$1\b" && return 0 || return 1
  fi
  return 1
}
while [ "$PORT" -le 65535 ] && port_in_use "$PORT"; do
  PORT=$((PORT + 1))
done
if [ "$PORT" -gt 65535 ]; then
  echo -e "${RED}$(_ "No available port found (exhausted)." "找不到可用端口。")${NC}"
  exit 1
fi

# --- Docker daemon tuning ---
# Check if max-concurrent-downloads is already set to 1
ALREADY_LIMITED=false
for _D in /etc/docker/daemon.json "$HOME/.docker/daemon.json"; do
  if [ -f "$_D" ] && command -v python3 &>/dev/null; then
    if python3 -c "
import json
try:
    with open('$_D') as f: cfg = json.load(f)
    print(cfg.get('max-concurrent-downloads', 0))
except: print(0)
" 2>/dev/null | grep -q '^1$'; then
      ALREADY_LIMITED=true
      break
    fi
  fi
done
if $ALREADY_LIMITED; then
  echo -e "\n  ${GREEN}✔$(_ "max-concurrent-downloads already set to 1, skipping" "单层下载已配置，跳过")${NC}"
else
  echo ""
  echo -e "${YELLOW}$(_ "Large images may stall on mirrors. Limit concurrent downloads to 1 layer?" "大镜像通过中转站可能断流，是否限制单层下载（更稳定）？") (y/N)${NC}"
  prompt "" LIMIT_CONCURRENT
  if [[ "$LIMIT_CONCURRENT" =~ ^[Yy]$ ]]; then
    DAEMON_PATH=""
    if [ -f /etc/docker/daemon.json ]; then
      DAEMON_PATH="/etc/docker/daemon.json"
    elif [ -f "$HOME/.docker/daemon.json" ]; then
      DAEMON_PATH="$HOME/.docker/daemon.json"
    else
      if [ -d /etc/docker ] && [ -w /etc/docker ] 2>/dev/null; then
        DAEMON_PATH="/etc/docker/daemon.json"
      elif command -v sudo &>/dev/null; then
        echo -e "  ${YELLOW}$(_ "Need sudo to create /etc/docker/daemon.json" "需要 sudo 权限创建 /etc/docker/daemon.json")${NC}"
        if sudo sh -c 'mkdir -p /etc/docker && echo "{}" > /etc/docker/daemon.json' 2>/dev/null; then
          DAEMON_PATH="/etc/docker/daemon.json"
        fi
      fi
    fi
    if [ -n "$DAEMON_PATH" ]; then
      TMP_CONFIG=$(mktemp)
      if command -v python3 &>/dev/null; then
        python3 -c "
import json
try:
    with open('$DAEMON_PATH') as f: cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError): cfg = {}
cfg['max-concurrent-downloads'] = 1
with open('$TMP_CONFIG', 'w') as f: json.dump(cfg, f, indent=2)
"
        sudo cp "$TMP_CONFIG" "$DAEMON_PATH" 2>/dev/null || cp "$TMP_CONFIG" "$DAEMON_PATH" 2>/dev/null
        rm -f "$TMP_CONFIG"
        echo -e "  ${GREEN}✔$(_ " Set max-concurrent-downloads=1" " 已配置单层下载")${NC}"
        echo -e "${YELLOW}$(_ "Restarting Docker to apply..." "正在重启 Docker 使配置生效...")${NC}"
        case "$(uname -s)" in
          Linux*)
            command -v systemctl &>/dev/null && sudo systemctl restart docker 2>/dev/null || true
            ;;
          Darwin*)
            osascript -e 'quit app "Docker"' 2>/dev/null || true
            sleep 2
            open -a Docker 2>/dev/null || true
            ;;
        esac
        if start_docker_with_retry 30 5; then
          echo -e "  ${GREEN}✔$(_ " Docker is ready" " Docker 已就绪")${NC}"
        else
          echo -e "${YELLOW}$(_ "Docker may need manual restart." "Docker 可能需要手动重启。")${NC}"
        fi
      else
        echo -e "  ${RED}$(_ "Python3 required to modify daemon.json. Skipping." "需要 Python3 来修改配置，已跳过。")${NC}"
      fi
    else
      echo -e "  ${YELLOW}$(_ "Cannot write to daemon.json. Set it manually:" "无法写入 daemon.json，请手动配置：")${NC}"
      echo -e "  ${CYAN}{\"max-concurrent-downloads\": 1}${NC}"
      echo -e "  ${CYAN}$(_ "Add to /etc/docker/daemon.json and restart Docker" "添加到 /etc/docker/daemon.json 后重启 Docker")${NC}"
    fi
  fi
fi

# --- Preview ---
echo ""
echo -e "${YELLOW}$(_ "Configuration preview:" "配置预览:")${NC}"
echo -e "  ${CYAN}$(_ "Image" "镜像"):      $(_ "auto (mirror test)" "自动选择（镜像测速）")${NC}"
echo -e "  ${CYAN}$(_ "Port" "端口"):       $PORT${NC}"
echo -e "  ${CYAN}$(_ "Data dir" "数据目录"): $DATA_DIR_FULL${NC}"
echo -e "  ${CYAN}$(_ "Workspace" "工作目录"): $WORKSPACE_FULL${NC}"

# --- Pull with mirror fallback + retry ---
echo ""
PULL_OK=false
# Try ghcr.io first
IMG="ghcr.io/realsjpeng/opencode-academic-enhanced:latest"
echo -e "${YELLOW}$(_ "Trying primary registry" "尝试主仓库"): $IMG${NC}"
if docker pull "$IMG"; then
  IMAGE="$IMG"
  PULL_OK=true
fi
# Fallback to mirrors
if ! $PULL_OK; then
  for NAME in "${SORTED_MIRRORS[@]}"; do
    IMG="$NAME/realsjpeng/opencode-academic-enhanced:latest"
    echo -e "${YELLOW}$(_ "Trying mirror" "尝试镜像"): $IMG${NC}"
    for RETRY in 0 1; do
      [ "$RETRY" -gt 0 ] && echo -e "  ${YELLOW}$(_ "Retrying" "重试") (${RETRY}/1)...${NC}" && \
        docker system prune -f --all --filter "label=org.opencontainers.image.source=ghcr.io" 2>/dev/null || true
      if docker pull "$IMG"; then
        IMAGE="$IMG"
        PULL_OK=true
        break
      fi
    done
    $PULL_OK && break
    echo -e "${YELLOW}$(_ "Mirror failed, trying next..." "镜像失败，尝试下一个...")${NC}"
  done
fi
if ! $PULL_OK; then
  echo -e "${RED}$(_ "All mirrors failed. Check your network." "所有镜像都拉取失败，请检查网络。")${NC}"
  exit 1
fi

# --- Run ---
echo ""
echo -e "${GREEN}$(_ "Starting container..." "启动容器...")${NC}"
docker rm -f opencode-academic-enhanced 2>/dev/null || true
RUN_OUTPUT=$(docker run -d --name opencode-academic-enhanced \
  -p "${PORT}":4096 \
  -v "${DATA_DIR_FULL}:/home/user/.local/share/opencode" \
  -v "${WORKSPACE_FULL}:/workspace" \
  --restart unless-stopped \
  "$IMAGE" 2>&1)
if [ $? -ne 0 ]; then
  echo -e "${RED}$(_ "Failed to start container:" "容器启动失败:") $RUN_OUTPUT${NC}"
  exit 1
fi
sleep 3
STATUS=$(docker inspect opencode-academic-enhanced --format='{{.State.Status}}' 2>/dev/null)
if [ "$STATUS" != "running" ]; then
  echo -e "${YELLOW}$(_ "Container exited. Logs:" "容器已退出，日志:")${NC}"
  docker logs opencode-academic-enhanced 2>/dev/null
fi

# --- Success ---
echo ""
echo -e "${GREEN}$(_ "Success!" "启动成功！")${NC}"
echo -e "   ${CYAN}$(_ "Open" "访问地址"): http://127.0.0.1:${PORT}${NC}"

# --- OpenCode Desktop auto-install ---
echo ""
echo -e "${YELLOW}$(_ "Checking OpenCode Desktop..." "检查 OpenCode Desktop...")${NC}"
DESKTOP_DIR=""
case "$(uname -s)" in
  Linux*)
    for d in ~/opencode-desktop ~/.local/share/opencode-desktop /opt/opencode-desktop; do
      [ -d "$d" ] && { DESKTOP_DIR="$d"; break; }
    done
    if [ -z "$DESKTOP_DIR" ] && command -v opencode-desktop &>/dev/null; then
      DESKTOP_DIR=$(command -v opencode-desktop)
    fi
    # Also check AppImage
    for f in ~/OpenCode-*.AppImage ~/opencode-desktop-*.AppImage; do
      [ -f "$f" ] && { DESKTOP_DIR=$(dirname "$f"); break; }
    done
    ;;
  Darwin*)
    for d in /Applications/OpenCode.app "$HOME/Applications/OpenCode.app"; do
      [ -d "$d" ] && { DESKTOP_DIR="$d"; break; }
    done
    ;;
esac
DESKTOP_INSTALLED=false
[ -n "$DESKTOP_DIR" ] && DESKTOP_INSTALLED=true

if ! $DESKTOP_INSTALLED; then
  echo -e "${YELLOW}$(_ "OpenCode Desktop not found, installing..." "未检测到 OpenCode Desktop，正在安装...")${NC}"
  DOWNLOAD_URL=""
  case "$(uname -s)" in
    Linux*)   DOWNLOAD_PATTERN="linux" ;;
    Darwin*)  DOWNLOAD_PATTERN="darwin\|macos\|dmg" ;;
  esac
  # Scrape download page to find platform-specific link
  if [ -n "$DOWNLOAD_PATTERN" ]; then
    DOWNLOAD_URL=$(curl -sL "https://opencode.ai/zh/download" 2>/dev/null \
      | grep -oP 'href="[^"]*'"$DOWNLOAD_PATTERN"'[^"]*"' \
      | head -1 | sed 's/href="//;s/"//')
    [ -n "$DOWNLOAD_URL" ] && [[ "$DOWNLOAD_URL" != http* ]] && DOWNLOAD_URL="https://opencode.ai${DOWNLOAD_URL}"
  fi
  [ -z "$DOWNLOAD_URL" ] && DOWNLOAD_URL="https://opencode.ai/download"
  EXE=""
  DOWNLOAD_OK=false
  case "$(uname -s)" in
    Linux*)   EXE="/tmp/opencode-desktop-linux.AppImage" ;;
    Darwin*)  EXE="/tmp/opencode-desktop-macos.dmg" ;;
  esac
  for ATTEMPT in 0 1 2; do
    [ "$ATTEMPT" -gt 0 ] && echo -e "  ${YELLOW}$(_ "Attempt" "尝试") $((ATTEMPT+1)) $(_ "failed, retrying" "失败，重试")${NC}"
    echo -e "  ${CYAN}$(_ "Downloading" "下载中"): $DOWNLOAD_URL${NC}"
    if curl -L --progress-bar -o "$EXE" "$DOWNLOAD_URL" 2>/dev/null; then
      SIZE=$(stat -c%s "$EXE" 2>/dev/null || stat -f%z "$EXE" 2>/dev/null || echo 0)
      if [ "$SIZE" -gt 1048576 ]; then  # > 1MB
        DOWNLOAD_OK=true
        break
      fi
    fi
  done
  if ! $DOWNLOAD_OK; then
    echo -e "${RED}$(_ "Failed to download OpenCode Desktop." "OpenCode Desktop 下载失败。")${NC}"
    echo -e "  ${CYAN}$(_ "Opening browser as fallback." "已为您打开浏览器。")${NC}"
    case "$(uname -s)" in
      Linux*)   command -v xdg-open &>/dev/null && xdg-open "http://127.0.0.1:${PORT}" || true ;;
      Darwin*)  open "http://127.0.0.1:${PORT}" ;;
    esac
  else
    echo -e "  ${GREEN}✔$(_ "Downloaded" "下载完成")${NC}"
    case "$(uname -s)" in
      Linux*)
        chmod +x "$EXE"
        "$EXE" --no-sandbox &
        DESKTOP_INSTALLED=true
        ;;
      Darwin*)
        hdiutil attach "$EXE" -quiet 2>/dev/null || true
        cp -R "/Volumes/OpenCode/OpenCode.app" /Applications/ 2>/dev/null || true
        hdiutil detach "/Volumes/OpenCode" -quiet 2>/dev/null || true
        [ -d /Applications/OpenCode.app ] && DESKTOP_INSTALLED=true
        ;;
    esac
  fi
fi

# --- Write/update desktop config ---
CONF_DIR=""
case "$(uname -s)" in
  Linux*)   CONF_DIR="$HOME/.config/opencode" ;;
  Darwin*)  CONF_DIR="$HOME/Library/Application Support/opencode" ;;
esac
if [ -n "$CONF_DIR" ]; then
  mkdir -p "$CONF_DIR" 2>/dev/null || true
  cat > "$CONF_DIR/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "server": {
    "hostname": "127.0.0.1",
    "port": $PORT
  }
}
EOF
  echo -e "  ${GREEN}✔$(_ " Desktop configured to connect to" "已配置 Desktop 连接至") http://127.0.0.1:${PORT}${NC}"
fi

# --- Launch desktop ---
BROWSER_OPEN=false
case "$(uname -s)" in
  Linux*)
    if $DESKTOP_INSTALLED && [ -f "$EXE" ]; then
      "$EXE" --no-sandbox &
    elif [ -n "$DESKTOP_DIR" ]; then
      "$DESKTOP_DIR/opencode-desktop" 2>/dev/null || "$DESKTOP_DIR/OpenCode" 2>/dev/null || true
    else
      command -v xdg-open &>/dev/null && xdg-open "http://127.0.0.1:${PORT}" && BROWSER_OPEN=true
    fi
    ;;
  Darwin*)
    if $DESKTOP_INSTALLED && [ -d /Applications/OpenCode.app ]; then
      open /Applications/OpenCode.app
    elif [ -n "$DESKTOP_DIR" ]; then
      open "$DESKTOP_DIR"
    else
      open "http://127.0.0.1:${PORT}" && BROWSER_OPEN=true
    fi
    ;;
esac
if $BROWSER_OPEN; then
  echo -e "  ${GREEN}✔$(_ " OpenCode Desktop launched" "OpenCode Desktop 已启动")${NC}"
else
  echo -e "  ${CYAN}$(_ " Opening browser instead." "启动桌面端失败，打开浏览器。")${NC}"
  case "$(uname -s)" in
    Linux*)   command -v xdg-open &>/dev/null && xdg-open "http://127.0.0.1:${PORT}" || true ;;
    Darwin*)  open "http://127.0.0.1:${PORT}" ;;
  esac
fi

# --- Tips ---
echo ""
echo -e "${YELLOW}$(_ "Useful commands:" "后续管理命令:")${NC}"
echo -e "  ${CYAN}$(_ "View logs" "查看日志"):   docker logs -f opencode-academic-enhanced${NC}"
echo -e "  ${CYAN}$(_ "Stop" "停止容器"):        docker stop opencode-academic-enhanced${NC}"
echo -e "  ${CYAN}$(_ "Start" "启动容器"):       docker start opencode-academic-enhanced${NC}"
echo -e "  ${CYAN}$(_ "Configure API" "配置 API"): docker exec -it opencode-academic-enhanced opencode providers${NC}"
