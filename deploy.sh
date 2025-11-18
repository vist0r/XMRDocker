#!/bin/bash
# Linux/macOS 一键部署脚本

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== XMR 挖矿程序一键部署 (Linux/macOS) ===${NC}"
echo ""

# 检查参数
WALLET_ADDRESS=""
WORKER_NAME="miner-$(date +%s)"
POOL_URL="pool.supportxmr.com:443"

while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--wallet)
            WALLET_ADDRESS="$2"
            shift 2
            ;;
        -n|--name)
            WORKER_NAME="$2"
            shift 2
            ;;
        -p|--pool)
            POOL_URL="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 -w <钱包地址> [-n <工作者名称>] [-p <矿池地址>]"
            exit 1
            ;;
    esac
done

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker未安装，正在安装...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y docker.io
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            echo -e "${YELLOW}请重新登录以应用Docker组权限，然后重新运行此脚本${NC}"
            exit 0
        # CentOS/RHEL
        elif command -v yum &> /dev/null; then
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            echo -e "${YELLOW}请重新登录以应用Docker组权限，然后重新运行此脚本${NC}"
            exit 0
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo -e "${YELLOW}请手动安装Docker Desktop for Mac: https://www.docker.com/products/docker-desktop${NC}"
        exit 1
    fi
fi

# 检查Docker是否运行
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker未运行！请启动Docker服务${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo systemctl start docker
    fi
    exit 1
fi

echo -e "${GREEN}✅ Docker检查通过${NC}"

# 获取钱包地址
if [ -z "$WALLET_ADDRESS" ]; then
    echo -e "${YELLOW}请输入XMR钱包地址:${NC}"
    read -p "钱包地址: " WALLET_ADDRESS
    
    if [ ${#WALLET_ADDRESS} -lt 50 ]; then
        echo -e "${RED}❌ 钱包地址无效！${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}钱包地址: ${WALLET_ADDRESS:0:10}...✓${NC}"
echo -e "${GREEN}工作者: $WORKER_NAME${NC}"
echo -e "${GREEN}矿池: $POOL_URL${NC}"

# Docker Hub登录
echo ""
echo -e "${YELLOW}登录Docker Hub拉取私有镜像...${NC}"
docker login

# 创建配置文件
echo -e "${YELLOW}创建配置文件...${NC}"
mkdir -p config

cat > config/config.json << EOF
{
    "pools": [
        {
            "url": "$POOL_URL",
            "user": "$WALLET_ADDRESS",
            "pass": "$WORKER_NAME",
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
EOF

# 拉取镜像
echo -e "${YELLOW}拉取镜像...${NC}"
docker pull vist0r/private-cpuminer:latest

# 启动容器
echo -e "${YELLOW}启动挖矿容器...${NC}"
docker rm -f cpu-miner 2>/dev/null || true

docker run --name cpu-miner \
    -v "$(pwd)/config:/app/config" \
    --restart unless-stopped \
    --privileged \
    --memory=8g \
    --shm-size=4g \
    -d \
    vist0r/private-cpuminer:latest \
    cpuminer --config=/app/config/config.json

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 挖矿启动成功！${NC}"
    echo ""
    echo -e "${YELLOW}管理命令:${NC}"
    echo "查看日志: docker logs -f cpu-miner"
    echo "停止挖矿: docker stop cpu-miner"
    echo "重启挖矿: docker restart cpu-miner"
    echo ""
    echo -e "${YELLOW}监控地址: https://supportxmr.com${NC}"
    echo ""
    
    # 显示初始日志
    sleep 3
    echo -e "${YELLOW}--- 启动日志 ---${NC}"
    docker logs cpu-miner
else
    echo -e "${RED}❌ 启动失败！${NC}"
    exit 1
fi