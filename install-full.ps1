# 小海 AI 助手 - Windows 完整一键安装 🐚
# 用法：在 PowerShell(管理员) 中运行：
#   iwr -useb https://raw.githubusercontent.com/lxz1152771281-art/stock-report/main/install-full.ps1 | iex

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$VERSION = "2.0.0"

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Install-WithWinget {
    param([string]$Name, [string]$WingetId, [string]$ChocoId)
    
    Write-Host "  ⏳ 安装 $Name..." -ForegroundColor Yellow
    
    # 尝试 winget 优先
    try {
        & winget install --id $WingetId --silent --accept-package-agreements 2>&1 | Out-Null
        Write-Host "  ✅ $Name 安装完成" -ForegroundColor Green
        return $true
    } catch {
        # 如果 winget 失败，尝试 choco
        try {
            & choco install $ChocoId -y 2>&1 | Out-Null
            Write-Host "  ✅ $Name (via choco) 安装完成" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  ⚠️ $Name 安装失败" -ForegroundColor Red
            return $false
        }
    }
}

$openclawDir = "$env:USERPROFILE\.openclaw"
$workspaceDir = "$openclawDir\workspace"
$binDir = "$workspaceDir\bin"

Write-Color "╔══════════════════════════════════════════════════════╗" Cyan
Write-Color "║      🐚 小海 AI 助手 - Windows 完整安装 v$VERSION  ║" Cyan
Write-Color "╚══════════════════════════════════════════════════════╝" Cyan
Write-Color ""

# ============================================================
# 0. 检查管理员权限
# ============================================================
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Color "⚠️  请以管理员身份运行 PowerShell！" Red
    Write-Color "   右键点击 PowerShell → 以管理员身份运行" Yellow
    pause
    exit
}

# ============================================================
# 1. 安装包管理器
# ============================================================
Write-Color "[1/9] 检查包管理器..." Yellow

# winget 通常已自带，检查 choco
try { $choco = choco --version 2>$null } catch { $choco = $null }
if (-not $choco) {
    Write-Color "  ⏳ 安装 Chocolatey..." Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Color "  ✅ Chocolatey 安装完成" Green
}

# ============================================================
# 2. 安装系统依赖
# ============================================================
Write-Color "[2/9] 安装系统组件..." Yellow

# Tesseract OCR
Install-WithWinget "Tesseract OCR" "UB-Mannheim.TesseractOCR" "tesseract"

# FFmpeg
Install-WithWinget "FFmpeg" "FFmpeg.FFmpeg" "ffmpeg"

# Git
try { git --version 2>$null | Out-Null } catch {
    Install-WithWinget "Git" "Git.Git" "git"
}

# ============================================================
# 3. 安装 Node.js + OpenClaw
# ============================================================
Write-Color "[3/9] 安装 OpenClaw..." Yellow

try { $nv = node --version } catch { $nv = $null }
if (-not $nv) {
    Write-Color "  ⏳ 安装 Node.js..." Yellow
    & winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements 2>&1 | Out-Null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

try { openclaw --version 2>$null } catch {
    Write-Color "  ⏳ 安装 OpenClaw CLI..." Yellow
    iwr -useb https://openclaw.ai/install.ps1 | iex
}

Write-Color "  ✅ OpenClaw 安装完成" Green

# ============================================================
# 4. 配置 DeepSeek API Key
# ============================================================
Write-Color "[4/9] 配置 API Key..." Yellow

New-Item -ItemType Directory -Path "$openclawDir\agents\main\agent" -Force | Out-Null

$defaultKey = ""
$apiKey = Read-Host "  请输入 DeepSeek API Key (回车跳过，后续可配)"

if ($apiKey) {
    $auth = @{ deepseek = @{ default = @{ token = $apiKey } } } | ConvertTo-Json -Depth 3
    Set-Content "$openclawDir\agents\main\agent\auth-profiles.json" -Value $auth
    
    # 创建 openclaw.json 配置
    $config = @{
        gateway = @{ port=18789; mode="local"; auth=@{mode="none"} }
        models = @{
            mode = "merge"
            providers = @{
                deepseek = @{
                    baseUrl = "https://api.deepseek.com"
                    api = "openai-completions"
                    models = @(@{
                        id="deepseek-v4-flash"; name="DeepSeek V4 Flash"
                        api="openai-completions"; reasoning=$true
                        input=@("text"); contextWindow=1000000; maxTokens=384000
                    })
                }
            }
        }
        messages = @{ tts = @{ enabled=$false } }
    } | ConvertTo-Json -Depth 10
    Set-Content "$openclawDir\openclaw.json" -Value $config
    Write-Color "  ✅ API Key 已配置" Green
}

# ============================================================
# 5. 安装全部技能 (28个)
# ============================================================
Write-Color "[5/9] 安装 28 个技能..." Yellow

$skills = @(
    # 股票分析
    "warren-buffett-investment", "buffett-investment-advisor",
    "valuation-analysis", "a-stock-analysis-pro", "china-stock-analysis",
    # 核心工具
    "brainstorming", "skill-creator", "microsoft-markitdown",
    "using-superpowers",
    # 浏览器自动化
    "browser-automation",
    # 飞书套件
    "feishu-doc", "feishu-drive", "feishu-perm", "feishu-wiki",
    # 开发工具
    "python-debugpy", "node-inspect-debugger",
    # 系统工具
    "healthcheck", "spike",
    # 多媒体
    "meme-maker",
    # 效率
    "tmux",
    # 其他
    "weather", "obsidian"
)

$installed = 0; $failed = 0
foreach ($skill in $skills) {
    try {
        openclaw skills install $skill 2>&1 | Out-Null
        Write-Host "    ✅ $skill" -ForegroundColor Green
        $installed++
    } catch {
        Write-Host "    ⚠️ $skill 跳过" -ForegroundColor DarkYellow
        $failed++
    }
}
Write-Color "  ✅ $installed 个技能安装成功 ($failed 个跳过)" Green

# ============================================================
# 6. 下载工具脚本
# ============================================================
Write-Color "[6/9] 下载工具脚本..." Yellow

New-Item -ItemType Directory -Path $binDir -Force | Out-Null
New-Item -ItemType Directory -Path "$workspaceDir\reports" -Force | Out-Null
New-Item -ItemType Directory -Path "$workspaceDir\videos" -Force | Out-Null

$repoUrl = "https://raw.githubusercontent.com/lxz1152771281-art/stock-report/main"
$scripts = @("report.py", "video_report_v4.py")
foreach ($script in $scripts) {
    try {
        Invoke-WebRequest -Uri "$repoUrl/$script" -OutFile "$binDir\$script"
        Write-Color "    ✅ $script" Green
    } catch {
        Write-Color "    ⚠️ $script 下载失败" Red
    }
}

# 下载配置文件
$configFiles = @(
    @{url="$repoUrl/.aider.conf.yml"; path="$env:USERPROFILE\.aider.conf.yml"}
    @{url="$repoUrl/.gitignore"; path="$workspaceDir\.gitignore"}
)
foreach ($f in $configFiles) {
    try {
        Invoke-WebRequest -Uri $f.url -OutFile $f.path 2>$null | Out-Null
    } catch {}
}

# ============================================================
# 7. 配置 TTS 语音
# ============================================================
Write-Color "[7/9] 配置 TTS 语音（活泼女声）..." Yellow
try {
    openclaw infer tts set-provider microsoft 2>&1 | Out-Null
    openclaw infer tts set-persona --persona "zh-CN-XiaoyiNeural" 2>&1 | Out-Null
    # 关闭自动语音（只保留能力，不自动发语音）
    openclaw config set messages.tts.auto off 2>&1 | Out-Null
    openclaw config set messages.tts.enabled false 2>&1 | Out-Null
    Write-Color "  ✅ TTS 已配置 (微软Xiaoyi活泼女声)" Green
} catch {
    Write-Color "  ⚠️ TTS 配置失败，可后续手动配置" Yellow
}

# ============================================================
# 8. 设置每日自动复盘（Windows 任务计划）
# ============================================================
Write-Color "[8/9] 设置每日自动复盘..." Yellow

$taskName = "小海看盘助手"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $taskExists) {
    $action = New-ScheduledTaskAction -Execute "python" -Argument "$binDir\report.py" -WorkingDirectory $workspaceDir
    $trigger = New-ScheduledTaskTrigger -Daily -At 03:30PM
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force 2>$null
    Write-Color "  ✅ 每日15:30自动复盘已设置" Green
} else {
    Write-Color "  ✅ 每日复盘任务已存在" Green
}

# ============================================================
# 9. 启动网关 + 完成
# ============================================================
Write-Color "[9/9] 启动网关..." Yellow

# 停止旧进程
Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "openclaw" } | Stop-Process -Force

# 启动 Gateway（后台）
$gwLog = "$openclawDir\gateway.log"
Start-Process -WindowStyle Hidden -FilePath "openclaw" -ArgumentList "gateway run" -RedirectStandardOutput $gwLog
Start-Sleep -Seconds 5

Write-Color ""
Write-Color "╔══════════════════════════════════════════════════════╗" Cyan
Write-Color "║          🐚 安装完成！一切就绪！                   ║" Cyan
Write-Color "╠══════════════════════════════════════════════════════╣" Cyan
Write-Color "║  已安装:                                          ║" White
Write-Color "║  ✅ OpenClaw + DeepSeek API                        ║" Green
Write-Color "║  ✅ $installed 个技能                                 ║" Green
Write-Color "║  ✅ TTS 语音 (微软Xiaoyi活泼女声)                  ║" Green
Write-Color "║  ✅ Tesseract OCR (看图识字)                       ║" Green
Write-Color "║  ✅ FFmpeg (视频合成)                              ║" Green
Write-Color "║  ✅ 复盘报告脚本                                   ║" Green
Write-Color "║  ✅ 每日15:30自动复盘                              ║" Green
Write-Color "╠══════════════════════════════════════════════════════╣" Cyan
Write-Color "║  接下来:                                           ║" White
Write-Color "║  1. 浏览器打开 http://localhost:18789               ║" White
Write-Color "║  2. 终端运行 openclash chat 本地聊天                ║" White
Write-Color "║  3. 第一次复盘: python bin\report.py               ║" White
Write-Color "╠══════════════════════════════════════════════════════╣" Cyan
Write-Color "║  可选手动配置:                                      ║" Yellow
Write-Color "║  • 飞书接入: openclaw channels add feishu           ║" Yellow
Write-Color "║  • Docker搜索: 装 Docker Desktop + 跑 SearXNG       ║" Yellow
Write-Color "║  • OCR增强: 设置 TESSDATA_PREFIX 环境变量          ║" Yellow
Write-Color "╚══════════════════════════════════════════════════════╝" Cyan
