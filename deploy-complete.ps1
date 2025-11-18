# 完整的一键部署脚本 - 安装和启动私有挖矿镜像
# 适用于Windows系统

param(
    [string]$WalletAddress = "",
    [string]$WorkerName = "auto-miner",
    [string]$PoolUrl = "pool.supportxmr.com:443"
)

Write-Host "=== XMR 挖矿程序一键部署脚本 ===" -ForegroundColor Green
Write-Host "此脚本将自动安装Docker、配置并启动挖矿程序" -ForegroundColor Yellow
Write-Host ""

# 检查是否以管理员身份运行
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "错误：请以管理员身份运行此脚本！" -ForegroundColor Red
    Write-Host "右键点击PowerShell -> '以管理员身份运行'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "✅ 管理员权限确认" -ForegroundColor Green

# 函数：检查命令是否存在
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# 函数：安装Chocolatey
function Install-Chocolatey {
    Write-Host "安装包管理器 Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    if (Test-Command choco) {
        Write-Host "✅ Chocolatey 安装成功" -ForegroundColor Green
    } else {
        Write-Host "❌ Chocolatey 安装失败" -ForegroundColor Red
        exit 1
    }
}

# 函数：安装Docker Desktop
function Install-Docker {
    Write-Host "安装 Docker Desktop..." -ForegroundColor Yellow
    
    if (Test-Command choco) {
        choco install docker-desktop -y
    } else {
        Write-Host "使用直接下载方式安装 Docker Desktop..." -ForegroundColor Yellow
        $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $dockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
        
        Write-Host "下载 Docker Desktop..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerInstaller
        
        Write-Host "运行安装程序..." -ForegroundColor Gray
        Start-Process -FilePath $dockerInstaller -ArgumentList "install", "--quiet" -Wait
        
        Remove-Item $dockerInstaller -Force
    }
    
    Write-Host "✅ Docker Desktop 安装完成" -ForegroundColor Green
    Write-Host "⚠️  请重启计算机并启动 Docker Desktop，然后重新运行此脚本" -ForegroundColor Yellow
}

# 第一步：检查和安装依赖
Write-Host "--- 第1步：检查系统依赖 ---" -ForegroundColor Cyan

# 检查Docker
if (-not (Test-Command docker)) {
    Write-Host "Docker 未安装，开始安装过程..." -ForegroundColor Yellow
    
    # 检查Chocolatey
    if (-not (Test-Command choco)) {
        Install-Chocolatey
    }
    
    Install-Docker
    Write-Host "请重启计算机，启动Docker Desktop后重新运行此脚本" -ForegroundColor Yellow
    pause
    exit 0
}

# 检查Docker是否运行
Write-Host "检查 Docker 服务状态..." -ForegroundColor Yellow
$dockerRunning = docker info 2>$null
if (-not $dockerRunning) {
    Write-Host "Docker Desktop 未运行，请启动 Docker Desktop" -ForegroundColor Red
    Write-Host "启动后按任意键继续..." -ForegroundColor Yellow
    pause
    
    # 再次检查
    $dockerRunning = docker info 2>$null
    if (-not $dockerRunning) {
        Write-Host "Docker 仍未运行，退出脚本" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ Docker 运行正常" -ForegroundColor Green

# 第二步：获取用户配置
Write-Host "--- 第2步：配置挖矿参数 ---" -ForegroundColor Cyan

if (-not $WalletAddress) {
    Write-Host "请输入你的 XMR 钱包地址:" -ForegroundColor Yellow
    Write-Host "(以4开头的长字符串，例如: 4AdUnd...)" -ForegroundColor Gray
    $WalletAddress = Read-Host "钱包地址"
    
    if (-not $WalletAddress -or $WalletAddress.Length -lt 95) {
        Write-Host "无效的钱包地址！" -ForegroundColor Red
        exit 1
    }
}

Write-Host "使用钱包地址: $($WalletAddress.Substring(0,20))..." -ForegroundColor Green
Write-Host "工作者名称: $WorkerName" -ForegroundColor Green
Write-Host "矿池地址: $PoolUrl" -ForegroundColor Green

# 第三步：创建配置文件
Write-Host "--- 第3步：创建配置文件 ---" -ForegroundColor Cyan

$configDir = ".\config"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$configFile = "$configDir\config.json"
$configContent = @"
{
    "api": {
        "id": null,
        "worker-id": null
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 8080,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": true,
    "title": true,
    "randomx": {
        "init": -1,
        "mode": "fast",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "numa": true
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "priority": null,
        "memory-pool": false,
        "yield": true,
        "asm": true
    },
    "log-file": "/app/logs/cpuminer.log",
    "donate-level": 1,
    "pools": [
        {
            "algo": null,
            "coin": null,
            "url": "$PoolUrl",
            "user": "$WalletAddress",
            "pass": "$WorkerName",
            "rig-id": null,
            "nicehash": false,
            "keepalive": true,
            "enabled": true,
            "tls": true,
            "daemon": false
        }
    ],
    "retries": 5,
    "retry-pause": 5,
    "print-time": 60,
    "health-print-time": 60,
    "verbose": 0,
    "watch": true,
    "pause-on-battery": false
}
"@

$configContent | Out-File -FilePath $configFile -Encoding UTF8 -Force
Write-Host "✅ 配置文件创建: $configFile" -ForegroundColor Green

# 第四步：拉取镜像
Write-Host "--- 第4步：拉取挖矿镜像 ---" -ForegroundColor Cyan
Write-Host "正在拉取公有镜像..." -ForegroundColor Yellow

docker pull xmrig/xmrig:latest

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 镜像拉取失败！请检查网络连接" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 镜像拉取成功" -ForegroundColor Green

# 第五步：启动容器
Write-Host "--- 第5步：启动挖矿容器 ---" -ForegroundColor Cyan

# 清理旧容器
Write-Host "清理旧容器..." -ForegroundColor Yellow
docker rm -f cpu-miner 2>$null

Write-Host "启动新容器..." -ForegroundColor Yellow
docker run --name cpu-miner `
    -v "${PWD}/config:/config" `
    --restart unless-stopped `
    --privileged `
    --memory=16g `
    --memory-swap=16g `
    --shm-size=8g `
    --ulimit memlock=-1:-1 `
    --cap-add=SYS_RAWIO `
    --cap-add=IPC_LOCK `
    -e "MALLOC_MMAP_THRESHOLD_=131072" `
    -e "MALLOC_TRIM_THRESHOLD_=131072" `
    -e "MALLOC_TOP_PAD_=131072" `
    -d `
    xmrig/xmrig:latest `
    --config=/config/config.json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 挖矿容器启动成功！" -ForegroundColor Green
    
    # 等待几秒钟让容器启动
    Start-Sleep 5
    
    Write-Host "--- 部署完成 ---" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== 挖矿状态监控 ===" -ForegroundColor Cyan
    Write-Host "1. 查看实时日志: docker logs -f cpu-miner" -ForegroundColor White
    Write-Host "2. 查看容器状态: docker ps" -ForegroundColor White
    Write-Host "3. 停止挖矿: docker stop cpu-miner" -ForegroundColor White
    Write-Host "4. 重启挖矿: docker restart cpu-miner" -ForegroundColor White
    Write-Host ""
    Write-Host "=== 收益监控 ===" -ForegroundColor Cyan
    Write-Host "矿池监控页面: https://supportxmr.com" -ForegroundColor White
    Write-Host "搜索你的钱包地址查看统计信息" -ForegroundColor Gray
    Write-Host ""
    Write-Host "正在显示启动日志..." -ForegroundColor Yellow
    docker logs cpu-miner
    
} else {
    Write-Host "❌ 容器启动失败！" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 挖矿程序部署完成！程序正在后台运行..." -ForegroundColor Green
Write-Host "按任意键退出脚本..." -ForegroundColor Yellow
pause