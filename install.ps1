# 小海一键安装脚本 🐚
# Windows PowerShell 安装器
# 用法：在 PowerShell 中运行：
#   iwr -useb https://raw.githubusercontent.com/lxz1152771281-art/stock-report/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$VERSION = "1.0.0"

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    小海 AI 助手 - Windows 一键安装     ║" -ForegroundColor Cyan
Write-Host "║         🐚  v$VERSION                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 第一步：检查 Node.js
# ============================================================
Write-Host "[1/5] 检查 Node.js..." -ForegroundColor Yellow
$nodeInstalled = $false
try {
    $nodeVer = node --version
    Write-Host "  ✅ Node.js $nodeVer 已安装" -ForegroundColor Green
    $nodeInstalled = $true
} catch {
    Write-Host "  ⏳ 正在安装 Node.js..." -ForegroundColor Yellow
    # 下载并安装 Node.js LTS
    $nodeUrl = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
    $msiPath = "$env:TEMP\node-install.msi"
    Invoke-WebRequest -Uri $nodeUrl -OutFile $msiPath
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msiPath`" /quiet /norestart"
    Remove-Item $msiPath
    # 刷新 PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  ✅ Node.js 安装完成" -ForegroundColor Green
}

# ============================================================
# 第二步：安装 OpenClaw
# ============================================================
Write-Host "[2/5] 安装 OpenClaw..." -ForegroundColor Yellow
try {
    $ocVer = openclaw --version 2>$null
    Write-Host "  ✅ OpenClaw $ocVer 已安装" -ForegroundColor Green
} catch {
    Write-Host "  ⏳ 正在安装 OpenClaw..." -ForegroundColor Yellow
    # 官方 Windows 安装命令
    iwr -useb https://openclaw.ai/install.ps1 | iex
    Write-Host "  ✅ OpenClaw 安装完成" -ForegroundColor Green
}

# ============================================================
# 第三步：配置 API Key（DeepSeek）
# ============================================================
Write-Host "[3/5] 配置 DeepSeek API Key..." -ForegroundColor Yellow

# 创建 OpenClaw 配置目录
$openclawDir = "$env:USERPROFILE\.openclaw"
$agentDir = "$openclawDir\agents\main\agent"
New-Item -ItemType Directory -Path $agentDir -Force | Out-Null

# 配置 DeepSeek
Write-Host "  ⏳ 请输入你的 DeepSeek API Key (留空则跳过):" -ForegroundColor Yellow
$apiKey = Read-Host "  DeepSeek API Key"

if ($apiKey) {
    # 保存到 auth-profiles.json
    $authConfig = @{
        deepseek = @{
            default = @{
                token = $apiKey
            }
        }
    } | ConvertTo-Json -Depth 3
    Set-Content -Path "$agentDir\auth-profiles.json" -Value $authConfig
    
    # 配置 openclaw.json
    $configPath = "$openclawDir\openclaw.json"
    if (-not (Test-Path $configPath)) {
        $config = @{
            gateway = @{
                port = 18789
                mode = "local"
                auth = @{ mode = "none" }
            }
            models = @{
                mode = "merge"
                providers = @{
                    deepseek = @{
                        baseUrl = "https://api.deepseek.com"
                        api = "openai-completions"
                        models = @(
                            @{
                                id = "deepseek-v4-flash"
                                name = "DeepSeek V4 Flash"
                                api = "openai-completions"
                                reasoning = $true
                                input = @("text")
                                contextWindow = 1000000
                                maxTokens = 384000
                            }
                        )
                    }
                }
            }
        } | ConvertTo-Json -Depth 10
        Set-Content -Path $configPath -Value $config
    }
    Write-Host "  ✅ API Key 已配置" -ForegroundColor Green
} else {
    Write-Host "  ⏭️ 跳过，后续可手动配置" -ForegroundColor Yellow
}

# ============================================================
# 第四步：下载技能和工具
# ============================================================
Write-Host "[4/5] 下载技能和工作流..." -ForegroundColor Yellow

$workspaceDir = "$openclawDir\workspace"
New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null

# 从 GitHub 克隆技能和脚本
Write-Host "  ⏳ 下载工具脚本..." -ForegroundColor Yellow
$repoUrl = "https://github.com/lxz1152771281-art/stock-report.git"
$repoDir = "$env:TEMP\stock-report"
if (Test-Path $repoDir) { Remove-Item -Recurse -Force $repoDir }
git clone $repoUrl $repoDir 2>$null

if (Test-Path $repoDir) {
    # 复制脚本
    Copy-Item "$repoDir\*.py" "$workspaceDir\" -Force -ErrorAction Ignore
    
    # 创建 bin 目录
    $binDir = "$workspaceDir\bin"
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    
    # 复制报告脚本
    Copy-Item "$repoDir\report.py" "$workspaceDir\bin\" -Force -ErrorAction Ignore
    
    Write-Host "  ✅ 工具脚本已下载" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ 仓库下载失败，请检查网络连接" -ForegroundColor Red
}

# 安装核心技能
Write-Host "  ⏳ 安装技能..." -ForegroundColor Yellow
$skills = @(
    "warren-buffett-investment",
    "buffett-investment-advisor", 
    "valuation-analysis",
    "a-stock-analysis-pro",
    "brainstorming",
    "skill-creator",
    "microsoft-markitdown"
)
foreach ($skill in $skills) {
    try {
        openclaw skills install $skill 2>$null | Out-Null
        Write-Host "    ✅ $skill" -ForegroundColor Green
    } catch {
        Write-Host "    ⚠️ $skill 安装失败" -ForegroundColor Red
    }
}

# ============================================================
# 第五步：启动网关 + 完成
# ============================================================
Write-Host "[5/5] 启动网关并验证..." -ForegroundColor Yellow
try {
    # 启动 Gateway（后台运行）
    Start-Process -WindowStyle Hidden -FilePath "openclaw" -ArgumentList "gateway run"
    Start-Sleep -Seconds 3
    Write-Host "  ✅ 网关已启动" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ 网关启动失败，稍后手动运行 'openclaw gateway run'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        🐚 安装完成！                    ║" -ForegroundColor Cyan
Write-Host "╠════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  浏览器打开:                            ║" -ForegroundColor White
Write-Host "║  http://localhost:18789                 ║" -ForegroundColor White
Write-Host "║                                         ║" -ForegroundColor White
Write-Host "║  终端运行:                              ║" -ForegroundColor White
Write-Host "║  openclaw dashboard   打开控制台        ║" -ForegroundColor White
Write-Host "║  openclaw chat        本地聊天          ║" -ForegroundColor White
Write-Host "║                                         ║" -ForegroundColor White
Write-Host "║  每日复盘报告:                           ║" -ForegroundColor White
Write-Host "║  python bin\report.py                   ║" -ForegroundColor White
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host ""
Write-Host "📌 后续建议手动安装 (可选):" -ForegroundColor Yellow
Write-Host "  1. TTS语音: openclaw infer tts set-provider microsoft"
Write-Host "  2. OCR看图: 安装 tesseract (choco install tesseract)"
Write-Host "  3. 飞书接入: openclaw channels add feishu"
Write-Host "  4. 更多技能: openclaw skills search"
