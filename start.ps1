<#
.SYNOPSIS
  OpenCode Academic Enhanced - One-Click Launcher (PowerShell)
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2026 realsjpeng
  This program is free software under the GPLv3.
#>

$Host.UI.RawUI.WindowTitle = "OpenCode Academic Enhanced Launcher"

# --- Language detection ---
$isChinese = [System.Globalization.CultureInfo]::CurrentCulture.Name -like "zh*"

function T($en, $zh) { if ($isChinese) { $zh } else { $en } }

$Blue   = [ConsoleColor]::Blue
$Green  = [ConsoleColor]::Green
$Yellow = [ConsoleColor]::Yellow
$Red    = [ConsoleColor]::Red
$Cyan   = [ConsoleColor]::Cyan

function Write-Color($Color, $Text) { Write-Host $Text -ForegroundColor $Color }

# --- Header ---
Write-Color $Blue "========================================================"
Write-Color $Blue "  $(T 'OpenCode Academic Enhanced - One-Click Launcher' 'OpenCode Academic Enhanced - 一键启动')"
Write-Color $Blue "========================================================"

# --- Docker check ---
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  $install = Read-Host "`n$(T 'Docker is not installed. Install now? (Y/N)' 'Docker 未安装，是否自动安装？(Y/N)')"
  if ($install -match '^[Yy]') {
    Write-Color $Yellow "$(T 'Installing Docker Desktop...' '正在安装 Docker Desktop...')"
    $url = 'https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe'
    $out = "$env:TEMP\DockerDesktopInstaller.exe"
    Invoke-WebRequest -Uri $url -OutFile $out
    Start-Process -Wait -FilePath $out -ArgumentList 'install', '--accept-license'
    Write-Color $Green "$(T 'Docker installed. Please restart your terminal and re-run this script.' 'Docker 安装完成。请重启终端后重新运行本脚本。')"
    exit
  } else {
    Write-Color $Red "$(T 'Please install Docker manually:' '请手动安装 Docker:') https://docker.com/get-started"
    exit 1
  }
}

# --- Network detection ---
Write-Color $Yellow "`n$(T 'Detecting network...' '检测网络环境...')"
try {
  $req = [System.Net.WebRequest]::Create("https://www.google.com")
  $req.Timeout = 3000
  $req.GetResponse().Close()
  Write-Color $Green "$(T 'Direct access available' '外网正常，使用直连')"
  $Image = "ghcr.io/realsjpeng/opencode-academic-enhanced:latest"
} catch {
  Write-Color $Yellow "$(T 'Restricted network detected, using proxy' '检测到网络限制，使用代理镜像拉取')"
  $Image = "ghcr.nju.edu.cn/realsjpeng/opencode-academic-enhanced:latest"
}

# --- Existing container check (upgrade or reinstall) ---
$existingContainer = docker inspect opencode-academic 2>$null
if ($existingContainer) {
  Write-Host ""
  Write-Color $Yellow "$(T 'Container opencode-academic already exists.' '容器 opencode-academic 已存在。')"
  Write-Host "  1) $(T 'Upgrade - pull new image, keep config' '升级 - 拉取新镜像，保留配置')"
  Write-Host "  2) $(T 'Reinstall - reconfigure' '重新安装 - 重新配置')"
  Write-Host "  3) $(T 'Cancel' '取消')"
  $action = Read-Host "$(T 'Choose (1/2/3)' '请选择 (1/2/3)') [1]"
  if (-not $action) { $action = "1" }
  switch ($action) {
    "1" {
      Write-Color $Yellow "`n$(T 'Reading existing config...' '读取现有配置...')"
      $Port      = docker inspect opencode-academic --format='{{(index (index .NetworkSettings.Ports "4096/tcp") 0).HostPort}}'
      $DataDirFull = docker inspect opencode-academic --format='{{range .Mounts}}{{if eq .Destination "/home/user/.local/share/opencode"}}{{.Source}}{{end}}{{end}}'
      $WorkspaceFull = docker inspect opencode-academic --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}'
      Write-Color $Cyan "   $(T 'Port' '端口'):       $Port"
      Write-Color $Cyan "   $(T 'Data dir' '数据目录'): $DataDirFull"
      Write-Color $Cyan "   $(T 'Workspace' '工作目录'): $WorkspaceFull"
      Write-Color $Yellow "`n$(T 'Pulling latest image...' '拉取最新镜像...')"
      docker pull $Image
      Write-Color $Green "`n$(T 'Upgrading container...' '升级容器...')"
      docker rm -f opencode-academic 2>$null | Out-Null
      docker run -d --name opencode-academic `
        -p ${Port}:4096 `
        -v "${DataDirFull}:/home/user/.local/share/opencode" `
        -v "${WorkspaceFull}:/workspace" `
        --restart unless-stopped `
        $Image
      Write-Color $Green "`n$(T 'Upgrade complete!' '升级完成！')"
      Write-Color $Cyan "   $(T 'Open' '访问地址'): http://127.0.0.1:${Port}"
      Start-Process "http://127.0.0.1:${Port}"
      exit
    }
    "2" {
      Write-Color $Yellow "$(T 'Removing old container...' '删除旧容器...')"
      docker rm -f opencode-academic 2>$null | Out-Null
    }
    default { exit }
  }
}

# --- User input ---
Write-Host ""
$Port      = Read-Host "$(T 'Port number' '端口号') [4096]"
$Port      = if ($Port) { $Port } else { "4096" }

$DataDir   = Read-Host "$(T 'Data persistence directory' '数据持久化目录') [./opencode-data]"
$DataDir   = if ($DataDir) { $DataDir } else { "./opencode-data" }

$Workspace = Read-Host "$(T 'Working directory' '工作目录') [.]"
$Workspace = if ($Workspace) { $Workspace } else { "." }

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
$DataDirFull   = (Resolve-Path $DataDir).Path
$WorkspaceFull = (Resolve-Path $Workspace).Path

# --- Port conflict detection ---
while ($Port -le 65535 -and (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)) {
  $Port = [int]$Port + 1
}
if ($Port -gt 65535) {
  Write-Color $Red "$(T 'No available port found (exhausted).' '找不到可用端口。')"
  exit 1
}

# --- Preview ---
Write-Host ""
Write-Color $Yellow "$(T 'Configuration preview:' '配置预览:')"
Write-Color $Cyan  "   $(T 'Image' '镜像'):      $Image"
Write-Color $Cyan  "   $(T 'Port' '端口'):       $Port"
Write-Color $Cyan  "   $(T 'Data dir' '数据目录'): $DataDirFull"
Write-Color $Cyan  "   $(T 'Workspace' '工作目录'): $WorkspaceFull"

# --- Pull ---
Write-Host ""
Write-Color $Yellow "$(T 'Pulling image...' '拉取镜像中...')"
docker pull $Image

# --- Run ---
Write-Host ""
Write-Color $Green "$(T 'Starting container...' '启动容器...')"
docker rm -f opencode-academic 2>$null | Out-Null
docker run -d --name opencode-academic `
  -p ${Port}:4096 `
  -v "${DataDirFull}:/home/user/.local/share/opencode" `
  -v "${WorkspaceFull}:/workspace" `
  --restart unless-stopped `
  $Image

# --- Success ---
Write-Host ""
Write-Color $Green "$(T 'Success!' '启动成功！')"
Write-Color $Cyan "   $(T 'Open' '访问地址'): http://127.0.0.1:${Port}"

Write-Host ""
Write-Color $Yellow "$(T 'How to use OpenCode?' '如何使用 OpenCode？')"
Write-Host "  1) $(T 'Open in browser' '在浏览器中打开')"
Write-Host "  2) $(T 'Install OpenCode Desktop & connect' '安装 OpenCode Desktop 并连接')"
$launch = Read-Host "$(T 'Choose (1/2)' '请选择 (1/2)') [1]"
if (-not $launch) { $launch = "1" }

switch ($launch) {
  "2" {
    Write-Color $Yellow "$(T 'Installing OpenCode Desktop...' '正在安装 OpenCode Desktop...')"
    $exe = "$env:TEMP\opencode-desktop-windows-x64.exe"
    Invoke-WebRequest -Uri 'https://github.com/anomalyco/opencode/releases/latest/download/opencode-desktop-windows-x64.exe' -OutFile $exe
    Start-Process -Wait -FilePath $exe -ArgumentList '/S'
    $confDir = "$env:APPDATA\opencode"
    New-Item -ItemType Directory -Force -Path $confDir | Out-Null
    @"
{
  "`$schema": "https://opencode.ai/config.json",
  "server": {
    "hostname": "127.0.0.1",
    "port": $Port
  }
}
"@ | Out-File -Encoding UTF8 "$confDir\opencode.json"
    Write-Color $Green "`n$(T 'OpenCode Desktop installed! Launching...' 'OpenCode Desktop 已安装！正在启动...')"
    Start-Process "$env:LOCALAPPDATA\Programs\opencode-desktop\opencode-desktop.exe"
    Write-Color $Cyan "   $(T 'Desktop configured to connect to' '已配置 Desktop 连接至') http://127.0.0.1:${Port}"
  }
  default {
    Start-Process "http://127.0.0.1:${Port}"
  }
}

# --- Tips ---
Write-Host ""
Write-Color $Yellow "$(T 'Useful commands:' '后续管理命令:')"
Write-Color $Cyan "   $(T 'View logs' '查看日志'):   docker logs -f opencode-academic"
Write-Color $Cyan "   $(T 'Stop' '停止容器'):        docker stop opencode-academic"
Write-Color $Cyan "   $(T 'Start' '启动容器'):       docker start opencode-academic"
Write-Color $Cyan "   $(T 'Configure API' '配置 API'): docker exec -it opencode-academic opencode providers"
