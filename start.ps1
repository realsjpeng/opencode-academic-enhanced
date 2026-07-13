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

# --- Uninstall option ---
Write-Host ""
Write-Color $Yellow "  [U] $(T 'Uninstall all components' '卸载全部组件')"
Write-Color $Green "  [Enter] $(T 'to continue setup' '继续安装')"
$uninstallChoice = Read-Host "$(T 'Choose' '请选择') (U/Enter)"
if ($uninstallChoice -match '^[Uu]') {
  Write-Color $Red "=== $(T 'Uninstalling OpenCode Academic Enhanced' '卸载 OpenCode Academic Enhanced') ==="

  # 1. Stop & remove container
  $containerExists = docker inspect opencode-academic 2>$null
  if ($containerExists) {
    Write-Color $Yellow "$(T 'Stopping and removing container...' '停止并删除容器...')"
    docker rm -f opencode-academic 2>$null | Out-Null
    Write-Color $Green "  ✔ $(T 'Container removed' '容器已删除')"
  } else {
    Write-Color $Cyan "  - $(T 'Container not found' '容器不存在')"
  }

  # 2. Remove Docker image
  $imageList = docker images ghcr.io/realsjpeng/opencode-academic-enhanced --format "{{.Repository}}:{{.Tag}}" 2>$null
  if ($imageList) {
    Write-Color $Yellow "$(T 'Removing Docker image...' '删除 Docker 镜像...')"
    $imageList | ForEach-Object { docker rmi -f $_ 2>$null | Out-Null }
    Write-Color $Green "  ✔ $(T 'Image removed' '镜像已删除')"
  } else {
    Write-Color $Cyan "  - $(T 'Image not found' '镜像不存在')"
  }

  # 3. Remove OpenCode Desktop
  $desktopPaths = @(
    "$env:LOCALAPPDATA\Programs\opencode-desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OpenCode Desktop.lnk"
  )
  $desktopFound = $false
  foreach ($p in $desktopPaths) { if (Test-Path $p) { $desktopFound = $true; break } }
  if ($desktopFound) {
    Write-Color $Yellow "$(T 'Removing OpenCode Desktop...' '移除 OpenCode Desktop...')"
    if (Test-Path "$env:LOCALAPPDATA\Programs\opencode-desktop") {
      Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Programs\opencode-desktop" -ErrorAction SilentlyContinue
    }
    Write-Color $Green "  ✔ $(T 'OpenCode Desktop removed' 'OpenCode Desktop 已移除')"
  } else {
    Write-Color $Cyan "  - $(T 'OpenCode Desktop not found' '未安装 OpenCode Desktop')"
  }

  # 4. Docker Desktop (optional)
  Write-Host ""
  Write-Color $Yellow "$(T 'Remove Docker Desktop as well?' '是否同时卸载 Docker Desktop？') (y/N)"
  $removeDocker = Read-Host
  if ($removeDocker -match '^[Yy]') {
    Write-Color $Yellow "$(T 'Uninstalling Docker Desktop...' '卸载 Docker Desktop...')"
    # Docker Desktop for Windows stores its uninstaller
    $uninstallers = @(
      "$env:PROGRAMFILES\Docker\Docker\Docker Desktop Installer.exe",
      "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop Installer.exe"
    )
    $found = $false
    foreach ($u in $uninstallers) {
      if (Test-Path $u) {
        Start-Process -Wait -FilePath $u -ArgumentList 'uninstall', '-y'
        $found = $true
        break
      }
    }
    if (-not $found) {
      # Fallback: try via winget
      winget uninstall "Docker Desktop" -h 2>$null | Out-Null
    }
    Write-Color $Green "  ✔ $(T 'Docker Desktop removed' 'Docker Desktop 已卸载')"
  }

  # 5. Data directories (optional)
  Write-Host ""
  Write-Color $Yellow "$(T 'Remove data/config directories (chat history, API keys)?' '是否删除数据/配置目录（聊天记录、API Key）？') (y/N)"
  $removeData = Read-Host
  if ($removeData -match '^[Yy]') {
    if (Test-Path "./opencode-data") {
      Remove-Item -Recurse -Force "./opencode-data" -ErrorAction SilentlyContinue
    }
    Write-Color $Green "  ✔ $(T 'Data directories removed' '数据目录已删除')"
  }

  Write-Color $Green "`n$(T 'Uninstall complete!' '卸载完成！')"
  exit
}

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

# --- Multi-mirror speed test ---
Write-Color $Yellow "`n$(T 'Testing mirror speeds...' '测试镜像速度...')"
$mirrorList = @(
  "ghcr.io",
  "ghcr.nju.edu.cn",
  "ghcr.registry.cyou",
  "ghcr.1ms.run",
  "ghcr.chenby.cn",
  "ghcr.m.daocloud.io"
)
$mirrorTimes = @{}
foreach ($name in $mirrorList) {
  $url = "https://$name/v2/"
  try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $req = [System.Net.WebRequest]::Create($url)
    $req.Timeout = 10000
    $req.GetResponse().Close()
    $sw.Stop()
    $ms = $sw.ElapsedMilliseconds
    Write-Color $Green "  $name : ${ms}ms"
    $mirrorTimes[$name] = $ms
  } catch {
    Write-Color $Red "  $name : unreachable"
  }
}
if ($mirrorTimes.Count -eq 0) {
  Write-Color $Red "$(T 'All mirrors unreachable. Check your network.' '所有镜像都无法访问，请检查网络。')"
  exit 1
}
# Sort by time (fastest first)
$sortedMirrors = $mirrorTimes.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }
Write-Color $Green "$(T 'Mirror ranking' '镜像排名'):"
for ($i = 0; $i -lt $sortedMirrors.Count; $i++) {
  $name = $sortedMirrors[$i]
  Write-Color $Cyan "  $($i+1). $name ($($mirrorTimes[$name])ms)"
}
$global:Image = $null  # Will be set during pull

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
      $pullOk = $false
      foreach ($name in $sortedMirrors) {
        $img = "$name/realsjpeng/opencode-academic-enhanced:latest"
        Write-Color $Yellow "$(T 'Trying mirror' '尝试镜像'): $img"
        docker pull $img
        if ($LASTEXITCODE -eq 0) {
          $global:Image = $img
          $pullOk = $true
          break
        }
        Write-Color $Yellow "$(T 'Mirror failed, trying next...' '镜像失败，尝试下一个...')"
      }
      if (-not $pullOk) {
        Write-Color $Red "$(T 'All mirrors failed. Check your network.' '所有镜像都拉取失败，请检查网络。')"
        exit 1
      }
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
Write-Color $Cyan  "   $(T 'Image' '镜像'):      $(T 'auto (mirror test)' '自动选择（镜像测速）')"
Write-Color $Cyan  "   $(T 'Port' '端口'):       $Port"
Write-Color $Cyan  "   $(T 'Data dir' '数据目录'): $DataDirFull"
Write-Color $Cyan  "   $(T 'Workspace' '工作目录'): $WorkspaceFull"

# --- Pull with mirror fallback ---
Write-Host ""
$pullOk = $false
foreach ($name in $sortedMirrors) {
  $img = "$name/realsjpeng/opencode-academic-enhanced:latest"
  Write-Color $Yellow "$(T 'Trying mirror' '尝试镜像'): $img"
  docker pull $img
  if ($LASTEXITCODE -eq 0) {
    $global:Image = $img
    $pullOk = $true
    break
  }
  Write-Color $Yellow "$(T 'Mirror failed, trying next...' '镜像失败，尝试下一个...')"
}
if (-not $pullOk) {
  Write-Color $Red "$(T 'All mirrors failed. Check your network.' '所有镜像都拉取失败，请检查网络。')"
  exit 1
}

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
