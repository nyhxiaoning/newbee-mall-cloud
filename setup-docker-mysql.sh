#!/bin/bash

echo "🐳 Docker MySQL 环境设置脚本"
echo "============================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# MySQL 配置
MYSQL_CONTAINER_NAME="newbee-mysql"
MYSQL_ROOT_PASSWORD="nyh123"
MYSQL_PORT="3306"

echo -e "\n${BLUE}1. 检查 Docker 环境${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker 未安装${NC}"
    echo "请安装 Docker Desktop for macOS"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker 服务未运行${NC}"
    echo "请启动 Docker Desktop"
    exit 1
fi

echo -e "${GREEN}✓ Docker 环境正常${NC}"

echo -e "\n${BLUE}2. 检查现有 MySQL 容器${NC}"
if docker ps -a --format "{{.Names}}" | grep -q "^${MYSQL_CONTAINER_NAME}$"; then
    echo -e "${YELLOW}⚠ 容器 ${MYSQL_CONTAINER_NAME} 已存在${NC}"
    
    if docker ps --format "{{.Names}}" | grep -q "^${MYSQL_CONTAINER_NAME}$"; then
        echo -e "${GREEN}✓ 容器正在运行${NC}"
    else
        echo "启动现有容器..."
        docker start ${MYSQL_CONTAINER_NAME}
        sleep 5
    fi
else
    echo -e "${BLUE}创建新的 MySQL 容器...${NC}"
    docker run --name ${MYSQL_CONTAINER_NAME} \
        -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
        -p ${MYSQL_PORT}:3306 \
        -d mysql:8.0 \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_unicode_ci
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ MySQL 容器创建成功${NC}"
        echo "等待 MySQL 初始化完成..."
        sleep 30
    else
        echo -e "${RED}✗ MySQL 容器创建失败${NC}"
        exit 1
    fi
fi

echo -e "\n${BLUE}3. 等待 MySQL 服务就绪${NC}"
for i in {1..30}; do
    if docker exec ${MYSQL_CONTAINER_NAME} mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} ping &>/dev/null; then
        echo -e "${GREEN}✓ MySQL 服务就绪${NC}"
        break
    fi
    echo "等待 MySQL 启动... ($i/30)"
    sleep 2
done

echo -e "\n${BLUE}4. 初始化所有数据库${NC}"
for db_file in static-files/*.sql; do
    if [ -f "$db_file" ]; then
        db_name=$(basename "$db_file" .sql)
        echo "初始化数据库: $db_name"
        
        docker cp "$db_file" ${MYSQL_CONTAINER_NAME}:/tmp/
        docker exec ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "source /tmp/$(basename "$db_file")"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $db_name 初始化成功${NC}"
        else
            echo -e "${RED}✗ $db_name 初始化失败${NC}"
        fi
    fi
done

echo -e "\n${BLUE}5. 验证数据库${NC}"
echo "检查已创建的数据库:"
docker exec ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;" | grep newbee_mall_cloud

echo -e "\n${GREEN}🎉 Docker MySQL 环境设置完成！${NC}"
echo ""
echo "连接信息:"
echo "  容器名称: ${MYSQL_CONTAINER_NAME}"
echo "  端口: ${MYSQL_PORT}"
echo "  用户名: root"
echo "  密码: ${MYSQL_ROOT_PASSWORD}"
echo ""
echo "常用命令:"
echo "  连接数据库: docker exec -it ${MYSQL_CONTAINER_NAME} mysql -uroot -p${MYSQL_ROOT_PASSWORD}"
echo "  查看日志: docker logs ${MYSQL_CONTAINER_NAME}"
echo "  停止容器: docker stop ${MYSQL_CONTAINER_NAME}"
echo "  启动容器: docker start ${MYSQL_CONTAINER_NAME}"
echo ""
echo "现在可以启动微服务了！"