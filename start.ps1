<#
.SYNOPSIS
  OpenCode Academic Enhanced - One-Click Launcher (PowerShell)
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2026 realsjpeng
  This program is free software under the GPLv3.
#>

$Host.UI.RawUI.WindowTitle = "OpenCode Academic Enhanced Launcher"

# --- Registry prefixes (used by uninstall and mirror test) ---
$script:ImageRegistries = @(
  "ghcr.nju.edu.cn",
  "ghcr.io",
  "ghcr.registry.cyou"
)

# --- Language detection ---
$isChinese = [System.Globalization.CultureInfo]::CurrentCulture.Name -like "zh*"

function T($en, $zh) { if ($isChinese) { $zh } else { $en } }

$Blue   = [ConsoleColor]::Blue
$Green  = [ConsoleColor]::Green
$Yellow = [ConsoleColor]::Yellow
$Red    = [ConsoleColor]::Red
$Cyan   = [ConsoleColor]::Cyan

function Write-Color($Color, $Text) { Write-Host $Text -ForegroundColor $Color }

# Override Read-Host to flush console buffer before prompting (fixes "stuck" issue)
function Read-Host {
  param([string]$Prompt)
  [Console]::Out.Flush()
  $host.UI.RawUI.FlushInputBuffer()
  if ($PSBoundParameters.ContainsKey('Prompt')) {
    return Microsoft.PowerShell.Utility\Read-Host -Prompt $Prompt
  }
  return Microsoft.PowerShell.Utility\Read-Host
}

function Start-DockerWithRetry {
  param([int]$MaxRetries = 12, [int]$IntervalSec = 5)
  $dockerExe = @(
    "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
    "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  $launched = $false
  for ($i = 1; $i -le $MaxRetries; $i++) {
    $null = docker info 2>$null
    if ($LASTEXITCODE -eq 0) { return $true }
    if (-not $launched -and $dockerExe) {
      Write-Color $Yellow "$(T 'Starting Docker Desktop...' '正在启动 Docker Desktop...')"
      Start-Process -FilePath $dockerExe
      $launched = $true
    }
    Start-Sleep $IntervalSec
    Write-Color $Cyan "  $(T 'Waiting...' '等待中...') ($i/$MaxRetries)"
  }
  return $false
}

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
  $containerExists = docker inspect opencode-academic-enhanced 2>$null
  if ($containerExists) {
    Write-Color $Yellow "$(T 'Stopping and removing container...' '停止并删除容器...')"
    docker rm -f opencode-academic-enhanced 2>$null | Out-Null
    Write-Color $Green "  ✔ $(T 'Container removed' '容器已删除')"
  } else {
    Write-Color $Cyan "  - $(T 'Container not found' '容器不存在')"
  }

  # 2. Remove Docker image (check all known registries)
  $imageList = @()
  foreach ($reg in $script:ImageRegistries) {
    $img = docker images "$reg/realsjpeng/opencode-academic-enhanced" --format "{{.Repository}}:{{.Tag}}" 2>$null
    if ($img) { $imageList += $img }
  }
  if ($imageList.Count -gt 0) {
    Write-Color $Yellow "$(T 'Removing Docker image...' '删除 Docker 镜像...')"
    $imageList | ForEach-Object { docker rmi -f $_ 2>$null | Out-Null }
    Write-Color $Green "  ✔ $(T 'Image removed' '镜像已删除')"
  } else {
    Write-Color $Cyan "  - $(T 'Image not found' '镜像不存在')"
  }

  # 3. OpenCode Desktop (optional, default No to avoid accidental data loss)
  $desktopCandidates = @(
    "$env:LOCALAPPDATA\Programs\@opencode-aidesktop",
    "$env:LOCALAPPDATA\Programs\opencode-desktop",
    "$env:LOCALAPPDATA\Programs\OpenCode Desktop",
    "$env:LOCALAPPDATA\opencode-desktop",
    "$env:APPDATA\opencode-desktop",
    "${env:ProgramFiles}\opencode-desktop",
    "${env:ProgramFiles(x86)}\opencode-desktop"
  )
  $desktopDir = $desktopCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($desktopDir) {
    Write-Host ""
    Write-Color $Red "$(T 'CAUTION: You are likely using OpenCode Desktop right now.' '注意：您当前很可能正在使用 OpenCode Desktop。')"
    Write-Color $Yellow "$(T 'Also remove OpenCode Desktop? (y/N)' '是否同时卸载 OpenCode Desktop？(y/N)')"
    $removeDesktop = Read-Host
    if ($removeDesktop -match '^[Yy]') {
      Write-Color $Yellow "$(T 'Removing OpenCode Desktop...' '移除 OpenCode Desktop...')"
      $uninstaller = @(
        "$desktopDir\Uninstall OpenCode.exe",
        "$desktopDir\uninstall.exe"
      ) | Where-Object { Test-Path $_ } | Select-Object -First 1
      if ($uninstaller) {
        Start-Process -Wait -FilePath $uninstaller -ArgumentList '/S' -ErrorAction SilentlyContinue
        Start-Sleep 2
      }
      Remove-Item -Recurse -Force $desktopDir -ErrorAction SilentlyContinue
      Remove-Item -Force "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OpenCode Desktop.lnk" -ErrorAction SilentlyContinue
      Remove-Item -Force "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OpenCode.lnk" -ErrorAction SilentlyContinue
      Write-Color $Green "  ✔ $(T 'OpenCode Desktop removed' 'OpenCode Desktop 已移除')"
    } else {
      Write-Color $Cyan "  - $(T 'OpenCode Desktop kept' '保留 OpenCode Desktop')"
    }
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
    curl.exe -L --progress-bar -o "$out" "$url"
    Start-Process -Wait -FilePath $out -ArgumentList 'install', '--accept-license'
    Write-Color $Yellow "$(T 'Docker Desktop installed, waiting for Docker daemon to start...' 'Docker Desktop 已安装，等待 Docker 守护进程启动...')"
    $dockerReady = Start-DockerWithRetry -MaxRetries 30 -IntervalSec 5
    if (-not $dockerReady) {
      Write-Color $Red "$(T 'Docker did not start in time. Please start Docker Desktop manually.' 'Docker 未能及时启动，请手动启动 Docker Desktop。')"
      exit 1
    }
    Write-Color $Green "$(T 'Docker is ready! Continuing setup...' 'Docker 已就绪！继续安装...')"
  } else {
    Write-Color $Red "$(T 'Please install Docker manually:' '请手动安装 Docker:') https://docker.com/get-started"
    exit 1
  }
}

# --- Multi-mirror speed test ---
Write-Host ""
Write-Color $Yellow "$(T 'Test mirror speeds for fallback? (Y = yes / n = skip, default ghcr.io)' '是否测试备用镜像速度？(Y = 测试 / n = 跳过，默认 ghcr.io)') (Y/n)"
$skipMirrorTest = Read-Host
$mirrorList = $script:ImageRegistries
if ($skipMirrorTest -match '^[Nn]') {
  Write-Color $Green "$(T 'Will try mirrors if ghcr.io fails' 'ghcr.io 失败后将自动尝试备用镜像')"
  $sortedMirrors = $script:ImageRegistries | Where-Object { $_ -ne "ghcr.io" }
} else {
  Write-Color $Yellow "`n$(T 'Testing mirror speeds...' '测试镜像速度...')"
  $mirrorTimes = @{}
  foreach ($name in $mirrorList) {
    $url = "https://$name/v2/"
    try {
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $null = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
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
  $sortedMirrors = $mirrorTimes.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key } | Where-Object { $_ -ne "ghcr.io" }
  Write-Color $Green "$(T 'Mirror ranking' '镜像排名'):"
  for ($i = 0; $i -lt $sortedMirrors.Count; $i++) {
    $name = $sortedMirrors[$i]
    Write-Color $Cyan "  $($i+1). $name ($($mirrorTimes[$name])ms)"
  }
}
# --- Docker daemon health check ---
Write-Color $Yellow "$(T 'Waiting for Docker daemon to start...' '等待 Docker 守护进程启动...')"
$dockerReady = Start-DockerWithRetry -MaxRetries 12 -IntervalSec 5
if (-not $dockerReady) {
  Write-Color $Red "$(T 'Docker daemon is not running. Please start Docker Desktop manually and retry.' 'Docker 守护进程未运行，请手动启动 Docker Desktop 后重试。')"
  exit 1
}

$global:Image = $null  # Will be set during pull

# --- Existing container check (upgrade or reinstall) ---
$null = docker inspect opencode-academic-enhanced 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host ""
  Write-Color $Yellow "$(T 'Container opencode-academic-enhanced already exists.' '容器 opencode-academic-enhanced 已存在。')"
  Write-Host "  1) $(T 'Upgrade - pull new image, keep config' '升级 - 拉取新镜像，保留配置')"
  Write-Host "  2) $(T 'Reinstall - reconfigure' '重新安装 - 重新配置')"
  Write-Host "  3) $(T 'Cancel' '取消')"
  $action = Read-Host "$(T 'Choose (1/2/3)' '请选择 (1/2/3)') [1]"
  if (-not $action) { $action = "1" }
  switch ($action) {
    "1" {
      Write-Color $Yellow "`n$(T 'Reading existing config...' '读取现有配置...')"
      $Port      = docker inspect opencode-academic-enhanced --format='{{(index (index .NetworkSettings.Ports "4096/tcp") 0).HostPort}}'
      $DataDirFull = docker inspect opencode-academic-enhanced --format='{{range .Mounts}}{{if eq .Destination "/home/user/.local/share/opencode"}}{{.Source}}{{end}}{{end}}'
      $WorkspaceFull = docker inspect opencode-academic-enhanced --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}'
      Write-Color $Cyan "   $(T 'Port' '端口'):       $Port"
      Write-Color $Cyan "   $(T 'Data dir' '数据目录'): $DataDirFull"
      Write-Color $Cyan "   $(T 'Workspace' '工作目录'): $WorkspaceFull"
      Write-Color $Yellow "`n$(T 'Checking latest image...' '检查最新镜像...')"
      $pullOk = $false
      $img = "ghcr.io/realsjpeng/opencode-academic-enhanced:latest"
      $localDigests = docker image inspect $img --format '{{range .RepoDigests}}{{.}}{{"\n"}}{{end}}' 2>$null
      if ($localDigests) {
        try {
          $resp = Invoke-WebRequest -Uri "https://ghcr.io/v2/realsjpeng/opencode-academic-enhanced/manifests/latest" `
            -Headers @{"Accept"="application/vnd.docker.distribution.manifest.v2+json"} `
            -UseBasicParsing -Method GET -TimeoutSec 10
          $remoteDigest = $resp.Headers["Docker-Content-Digest"]
          if ($remoteDigest -and ($localDigests -match [regex]::Escape($remoteDigest))) {
            Write-Color $Green "  ✔ $(T 'Image is up-to-date, skipping pull' '镜像已是最新，跳过下载')"
            $global:Image = $img
            $pullOk = $true
          }
        } catch {
          # Registry API check failed, proceed with normal pull
        }
      }
      if (-not $pullOk) {
        Write-Color $Yellow "$(T 'Trying primary registry' '尝试主仓库'): $img"
        docker pull $img
        if ($LASTEXITCODE -eq 0) {
          $global:Image = $img
          $pullOk = $true
        }
      }
      if (-not $pullOk) {
        foreach ($name in $sortedMirrors) {
          $img = "$name/realsjpeng/opencode-academic-enhanced:latest"
          Write-Color $Yellow "$(T 'Trying mirror' '尝试镜像'): $img"
          for ($retry = 0; $retry -le 1; $retry++) {
            if ($retry -gt 0) {
              Write-Color $Yellow "$(T 'Retrying' '重试') ($retry/1)..."
              docker system prune -f --all --filter "label=org.opencontainers.image.source=ghcr.io" 2>$null | Out-Null
            }
            docker pull $img
            if ($LASTEXITCODE -eq 0) {
              $global:Image = $img
              $pullOk = $true
              break
            }
          }
          if ($pullOk) { break }
        }
      }
      if (-not $pullOk) {
        Write-Color $Red "$(T 'All mirrors failed. Check your network.' '所有镜像都拉取失败，请检查网络。')"
        exit 1
      }
      Write-Color $Green "`n$(T 'Upgrading container...' '升级容器...')"
      docker rm -f opencode-academic-enhanced 2>$null | Out-Null
      $runOutput = docker run -d --name opencode-academic-enhanced `
        -p ${Port}:4096 `
        -v "${DataDirFull}:/home/user/.local/share/opencode" `
        -v "${WorkspaceFull}:/workspace" `
        --restart unless-stopped `
        $Image 2>&1
      if ($LASTEXITCODE -ne 0) {
        Write-Color $Red "$(T 'Failed to start container:' '容器启动失败:') $runOutput"
        exit 1
      }
      Start-Sleep 3
      $status = docker inspect opencode-academic-enhanced --format='{{.State.Status}}' 2>$null
      if ($status -ne 'running') {
        Write-Color $Yellow "$(T 'Container exited. Logs:' '容器已退出，日志:')"
        docker logs opencode-academic-enhanced 2>$null | Out-Host
      }
      Write-Color $Green "`n$(T 'Upgrade complete!' '升级完成！')"
      Write-Color $Cyan "   $(T 'Open' '访问地址'): http://127.0.0.1:${Port}"
      Start-Process "http://127.0.0.1:${Port}"
      exit
    }
    "2" {
      Write-Color $Yellow "$(T 'Removing old container...' '删除旧容器...')"
      docker rm -f opencode-academic-enhanced 2>$null | Out-Null
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
function Test-PortInUse($p) {
  try {
    return [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction Stop)
  } catch {
    return [bool](netstat -ano | Select-String ":$p\s")
  }
}
while ($Port -le 65535 -and (Test-PortInUse $Port)) {
  $Port = [int]$Port + 1
}
if ($Port -gt 65535) {
  Write-Color $Red "$(T 'No available port found (exhausted).' '找不到可用端口。')"
  exit 1
}

# --- Docker daemon tuning ---
Write-Host ""
Write-Color $Yellow "$(T 'Large images may stall on mirrors. Limit concurrent downloads to 1 layer?' '大镜像通过中转站可能断流，是否限制单层下载（更稳定）？') (y/N)"
$limitConcurrent = Read-Host
if ($limitConcurrent -match '^[Yy]') {
  $daemonPaths = @("$env:USERPROFILE\.docker\daemon.json")
  # Docker Desktop for Windows: daemon.json location
  $daemonPath = $null
  foreach ($p in $daemonPaths) {
    if (Test-Path $p) { $daemonPath = $p; break }
  }
  if (-not $daemonPath) {
    $daemonDir = "$env:USERPROFILE\.docker"
    New-Item -ItemType Directory -Force -Path $daemonDir | Out-Null
    $daemonPath = "$daemonDir\daemon.json"
  }
  try {
    $cfg = @{}
    if (Test-Path $daemonPath) {
      $cfg = Get-Content $daemonPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
      if (-not $cfg) { $cfg = @{} }
    }
    $cfg | Add-Member -NotePropertyName "max-concurrent-downloads" -NotePropertyValue 1 -Force
    $cfg | ConvertTo-Json -Depth 10 | Set-Content $daemonPath -Encoding UTF8
    Write-Color $Green "  ✔ $(T 'Set max-concurrent-downloads=1' '已配置单层下载')"
    Write-Color $Cyan "$(T 'Restarting Docker Desktop...' '正在重启 Docker Desktop...')"
    Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
    $dockerRestarted = Start-DockerWithRetry -MaxRetries 24 -IntervalSec 5
    if ($dockerRestarted) {
      Write-Color $Green "  ✔ $(T 'Docker Desktop restarted' 'Docker Desktop 已重启')"
    } else {
      Write-Color $Yellow "$(T 'Docker Desktop may need manual restart.' 'Docker Desktop 可能需要手动重启。')"
    }
  } catch {
    Write-Color $Red "$(T 'Failed to write daemon.json. Set it manually:' '无法写入 daemon.json，请手动配置：')"
    Write-Color $Cyan '{"max-concurrent-downloads": 1}'
    Write-Color $Cyan "$(T 'Add to daemon.json and restart Docker' '添加到 daemon.json 后重启 Docker')"
  }
}

# --- Preview ---
Write-Host ""
Write-Color $Yellow "$(T 'Configuration preview:' '配置预览:')"
Write-Color $Cyan  "   $(T 'Image' '镜像'):      $(T 'auto (mirror test)' '自动选择（镜像测速）')"
Write-Color $Cyan  "   $(T 'Port' '端口'):       $Port"
Write-Color $Cyan  "   $(T 'Data dir' '数据目录'): $DataDirFull"
Write-Color $Cyan  "   $(T 'Workspace' '工作目录'): $WorkspaceFull"

# --- Pull with mirror fallback + retry ---
Write-Host ""
$pullOk = $false
# Try ghcr.io first
$img = "ghcr.io/realsjpeng/opencode-academic-enhanced:latest"
Write-Color $Yellow "$(T 'Trying primary registry' '尝试主仓库'): $img"
docker pull $img
if ($LASTEXITCODE -eq 0) {
  $global:Image = $img
  $pullOk = $true
}
# Fallback to mirrors
if (-not $pullOk) {
  foreach ($name in $sortedMirrors) {
    $img = "$name/realsjpeng/opencode-academic-enhanced:latest"
    Write-Color $Yellow "$(T 'Trying mirror' '尝试镜像'): $img"
    for ($retry = 0; $retry -le 1; $retry++) {
      if ($retry -gt 0) {
        Write-Color $Yellow "$(T 'Retrying' '重试') ($retry/1)..."
        docker system prune -f --all --filter "label=org.opencontainers.image.source=ghcr.io" 2>$null | Out-Null
      }
      docker pull $img
      if ($LASTEXITCODE -eq 0) {
        $global:Image = $img
        $pullOk = $true
        break
      }
    }
    if ($pullOk) { break }
    Write-Color $Yellow "$(T 'Mirror failed, trying next...' '镜像失败，尝试下一个...')"
  }
}
if (-not $pullOk) {
  Write-Color $Red "$(T 'All mirrors failed. Check your network.' '所有镜像都拉取失败，请检查网络。')"
  exit 1
}

# --- Run ---
Write-Host ""
Write-Color $Green "$(T 'Starting container...' '启动容器...')"
docker rm -f opencode-academic-enhanced 2>$null | Out-Null
$runOutput = docker run -d --name opencode-academic-enhanced `
  -p ${Port}:4096 `
  -v "${DataDirFull}:/home/user/.local/share/opencode" `
  -v "${WorkspaceFull}:/workspace" `
  --restart unless-stopped `
  $Image 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Color $Red "$(T 'Failed to start container:' '容器启动失败:') $runOutput"
  exit 1
}
Start-Sleep 3
$status = docker inspect opencode-academic-enhanced --format='{{.State.Status}}' 2>$null
if ($status -ne 'running') {
  Write-Color $Yellow "$(T 'Container exited. Logs:' '容器已退出，日志:')"
  docker logs opencode-academic-enhanced 2>$null | Out-Host
}

# --- Success ---
Write-Host ""
Write-Color $Green "$(T 'Success!' '启动成功！')"
Write-Color $Cyan "   $(T 'Open' '访问地址'): http://127.0.0.1:${Port}"

# --- OpenCode Desktop auto-install ---
Write-Host ""
Write-Color $Yellow "$(T 'Checking OpenCode Desktop...' '检查 OpenCode Desktop...')"
$desktopCandidates = @(
  "$env:LOCALAPPDATA\Programs\@opencode-aidesktop",
  "$env:LOCALAPPDATA\Programs\opencode-desktop",
  "$env:LOCALAPPDATA\Programs\OpenCode Desktop",
  "$env:LOCALAPPDATA\opencode-desktop",
  "$env:APPDATA\opencode-desktop",
  "${env:ProgramFiles}\opencode-desktop",
  "${env:ProgramFiles(x86)}\opencode-desktop"
)
$desktopExeNames = @("OpenCode.exe", "opencode-desktop.exe")
$desktopDir = $null
foreach ($d in $desktopCandidates) {
  foreach ($exe in $desktopExeNames) {
    if (Test-Path "$d\$exe") {
      $desktopDir = $d
      break
    }
  }
  if ($desktopDir) { break }
}
$desktopInstalled = $desktopDir -ne $null

  if (-not $desktopInstalled) {
    Write-Color $Yellow "$(T 'OpenCode Desktop not found, installing...' '未检测到 OpenCode Desktop，正在安装...')"
    $exe = "$env:TEMP\opencode-desktop-windows-x64.exe"
    $downloadUrl = 'https://opencode.ai/download/stable/windows-x64-nsis'
    $downloadOk = $false
    for ($attempt = 0; $attempt -le 2; $attempt++) {
      try {
        Write-Color $Cyan "  $(T 'Downloading' '下载中'): $downloadUrl"
        curl.exe -L --progress-bar -o "$exe" "$downloadUrl"
        $size = (Get-Item $exe -ErrorAction SilentlyContinue).Length
        if ($size -gt 1MB) {
          $downloadOk = $true
          break
        }
      } catch {
        Write-Color $Yellow "  $(T 'Attempt' '尝试') $($attempt+1) $(T 'failed' '失败'): $($_.Exception.Message)"
      }
    }
    if (-not $downloadOk) {
      Write-Color $Red "$(T 'Failed to download OpenCode Desktop.' 'OpenCode Desktop 下载失败。')"
      Write-Color $Cyan "  $(T 'Opening browser as fallback.' '已为您打开浏览器。')"
      Start-Process "http://127.0.0.1:${Port}"
    } else {
      Write-Color $Green "  ✔ $(T 'Downloaded' '下载完成')"
      Start-Process -Wait -FilePath $exe -ArgumentList '/S'
      $desktopDir = $null
      foreach ($d in $desktopCandidates) {
        foreach ($e in $desktopExeNames) {
          if (Test-Path "$d\$e") { $desktopDir = $d; break }
        }
        if ($desktopDir) { break }
      }
      $desktopInstalled = $desktopDir -ne $null
    }
  }

# --- Write/update desktop config ---
$confDir = "$env:APPDATA\opencode"
New-Item -ItemType Directory -Force -Path $confDir | Out-Null
$confPath = "$confDir\opencode.json"
@"
{
  "`$schema": "https://opencode.ai/config.json",
  "server": {
    "hostname": "127.0.0.1",
    "port": $Port
  }
}
"@ | Out-File -Encoding UTF8 $confPath
Write-Color $Green "  ✔ $(T 'Desktop configured to connect to' '已配置 Desktop 连接至') http://127.0.0.1:${Port}"

# --- Launch desktop ---
if ($desktopDir) {
  $desktopExe = @("$desktopDir\OpenCode.exe", "$desktopDir\opencode-desktop.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($desktopExe) {
    Start-Process $desktopExe
    Write-Color $Green "  ✔ $(T 'OpenCode Desktop launched' 'OpenCode Desktop 已启动')"
  } else {
    Write-Color $Cyan "  $(T 'Opening browser instead.' '启动桌面端失败，打开浏览器。')"
    Start-Process "http://127.0.0.1:${Port}"
  }
} else {
  Write-Color $Cyan "  $(T 'Opening browser instead.' '启动桌面端失败，打开浏览器。')"
  Start-Process "http://127.0.0.1:${Port}"
}

# --- Tips ---
Write-Host ""
Write-Color $Yellow "$(T 'Useful commands:' '后续管理命令:')"
Write-Color $Cyan "   $(T 'View logs' '查看日志'):   docker logs -f opencode-academic-enhanced"
Write-Color $Cyan "   $(T 'Stop' '停止容器'):        docker stop opencode-academic-enhanced"
Write-Color $Cyan "   $(T 'Start' '启动容器'):       docker start opencode-academic-enhanced"
Write-Color $Cyan "   $(T 'Configure API' '配置 API'): docker exec -it opencode-academic-enhanced opencode providers"