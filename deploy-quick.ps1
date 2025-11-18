# 简化版部署脚本 - 适用于已有Docker的系统
param(
    [string]$WalletAddress = "",
    [string]$WorkerName = "miner-$(Get-Random)",
    [string]$PoolUrl = "pool.supportxmr.com:443"
)

Write-Host "=== XMR 挖矿快速部署 ===" -ForegroundColor Green
Write-Host ""

# 检查Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker未安装！请先运行完整安装脚本: .\deploy-complete.ps1" -ForegroundColor Red
    exit 1
}

$dockerRunning = docker info 2>$null
if (-not $dockerRunning) {
    Write-Host "❌ Docker未运行！请启动Docker Desktop" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Docker检查通过" -ForegroundColor Green

# 获取钱包地址
if (-not $WalletAddress) {
    Write-Host "请输入XMR钱包地址:" -ForegroundColor Yellow
    $WalletAddress = Read-Host "钱包地址"
    
    if (-not $WalletAddress -or $WalletAddress.Length -lt 50) {
        Write-Host "❌ 钱包地址无效！" -ForegroundColor Red
        exit 1
    }
}

Write-Host "钱包地址: $($WalletAddress.Substring(0,10))...✓" -ForegroundColor Green
Write-Host "工作者: $WorkerName" -ForegroundColor Green

# 创建配置
Write-Host ""
Write-Host "创建配置文件..." -ForegroundColor Yellow
$configDir = "config"
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

@"
{
    "pools": [
        {
            "url": "$PoolUrl",
            "user": "$WalletAddress",
            "pass": "$WorkerName",
            "keepalive": true,
            "tls": true,
            "enabled": true
        }
    ],
    "cpu": {
        "enabled": true,
        "huge-pages": true
    },
    "randomx": {
        "mode": "fast"
    },
    "donate-level": 1,
    "print-time": 60,
    "retries": 5,
    "retry-pause": 5
}
"@ | Out-File -FilePath "$configDir/config.json" -Encoding UTF8

# 拉取并运行
Write-Host "拉取公有镜像..." -ForegroundColor Yellow
docker pull xmrig/xmrig:latest

Write-Host "启动挖矿..." -ForegroundColor Yellow
docker rm -f cpu-miner 2>$null

docker run --name cpu-miner `
    -v "${PWD}/config:/config" `
    --restart unless-stopped `
    --privileged `
    --memory=8g `
    --shm-size=4g `
    -d `
    xmrig/xmrig:latest `
    --config=/config/config.json

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "🎉 挖矿启动成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "管理命令:" -ForegroundColor Cyan
    Write-Host "查看日志: docker logs -f cpu-miner" -ForegroundColor White
    Write-Host "停止挖矿: docker stop cpu-miner" -ForegroundColor White
    Write-Host "重启挖矿: docker restart cpu-miner" -ForegroundColor White
    Write-Host ""
    Write-Host "监控地址: https://supportxmr.com" -ForegroundColor Cyan
    Write-Host ""
    
    # 显示初始日志
    Start-Sleep 3
    Write-Host "--- 启动日志 ---" -ForegroundColor Yellow
    docker logs cpu-miner
} else {
    Write-Host "❌ 启动失败！" -ForegroundColor Red
}