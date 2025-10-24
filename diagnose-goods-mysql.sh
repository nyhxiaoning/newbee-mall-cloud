#!/bin/bash

echo "🔍 商品服务 MySQL 连接诊断脚本 (Docker 环境)"
echo "=============================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. 检查 Docker 服务状态
echo -e "\n${BLUE}1. 检查 Docker 服务状态${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker 未安装或未在 PATH 中${NC}"
    echo "请安装 Docker Desktop for macOS"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker 服务未运行${NC}"
    echo "请启动 Docker Desktop"
    exit 1
fi

echo -e "${GREEN}✓ Docker 服务正在运行${NC}"

# 2. 检查 MySQL Docker 容器
echo -e "\n${BLUE}2. 检查 MySQL Docker 容器${NC}"
MYSQL_CONTAINERS=$(docker ps -a --filter "name=mysql" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)

if [ -z "$MYSQL_CONTAINERS" ]; then
    # 尝试查找其他可能的 MySQL 容器
    MYSQL_CONTAINERS=$(docker ps -a --filter "ancestor=mysql" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
fi

if [ -n "$MYSQL_CONTAINERS" ]; then
    echo -e "${GREEN}✓ 找到 MySQL 容器:${NC}"
    echo "$MYSQL_CONTAINERS"
    
    # 获取运行中的 MySQL 容器名称
    RUNNING_MYSQL=$(docker ps --filter "name=mysql" --filter "status=running" --format "{{.Names}}" | head -1)
    if [ -z "$RUNNING_MYSQL" ]; then
        RUNNING_MYSQL=$(docker ps --filter "ancestor=mysql" --filter "status=running" --format "{{.Names}}" | head -1)
    fi
    
    if [ -n "$RUNNING_MYSQL" ]; then
        echo -e "${GREEN}✓ MySQL 容器正在运行: $RUNNING_MYSQL${NC}"
        MYSQL_CONTAINER_NAME="$RUNNING_MYSQL"
    else
        echo -e "${YELLOW}⚠ MySQL 容器未运行${NC}"
        # 尝试启动第一个找到的 MySQL 容器
        STOPPED_MYSQL=$(docker ps -a --filter "name=mysql" --filter "status=exited" --format "{{.Names}}" | head -1)
        if [ -z "$STOPPED_MYSQL" ]; then
            STOPPED_MYSQL=$(docker ps -a --filter "ancestor=mysql" --filter "status=exited" --format "{{.Names}}" | head -1)
        fi
        
        if [ -n "$STOPPED_MYSQL" ]; then
            echo "尝试启动 MySQL 容器: $STOPPED_MYSQL"
            docker start "$STOPPED_MYSQL"
            sleep 5
            MYSQL_CONTAINER_NAME="$STOPPED_MYSQL"
        else
            echo -e "${RED}✗ 未找到可启动的 MySQL 容器${NC}"
            echo "请创建并启动 MySQL 容器："
            echo "  docker run --name mysql-server -e MYSQL_ROOT_PASSWORD=nyh123 -p 3306:3306 -d mysql:8.0"
            exit 1
        fi
    fi
else
    echo -e "${RED}✗ 未找到 MySQL 容器${NC}"
    echo "请创建并启动 MySQL 容器："
    echo "  docker run --name mysql-server -e MYSQL_ROOT_PASSWORD=nyh123 -p 3306:3306 -d mysql:8.0"
    echo "或者检查现有容器："
    echo "  docker ps -a"
    exit 1
fi

# 3. 检查 MySQL 连接
echo -e "\n${BLUE}3. 检查 MySQL 连接${NC}"

# 等待 MySQL 容器完全启动
echo "等待 MySQL 容器启动完成..."
sleep 10

# 方法1: 通过 Docker exec 连接（容器内连接）
echo "测试容器内 MySQL 连接..."
if docker exec "$MYSQL_CONTAINER_NAME" mysql -uroot -pnyh123 -e "SELECT 1;" 2>/dev/null; then
    echo -e "${GREEN}✓ Docker 容器内 MySQL 连接成功${NC}"
    MYSQL_CONNECTION_OK=true
else
    echo -e "${YELLOW}⚠ Docker 容器内 MySQL 连接失败${NC}"
    MYSQL_CONNECTION_OK=false
fi

# 方法2: 通过宿主机端口连接（如果本地安装了 mysql 客户端）
if command -v mysql &> /dev/null; then
    echo "测试宿主机到 MySQL 容器的连接..."
    if mysql -h127.0.0.1 -P3306 -uroot -pnyh123 -e "SELECT 1;" 2>/dev/null; then
        echo -e "${GREEN}✓ 宿主机 MySQL 连接成功${NC}"
        MYSQL_CONNECTION_OK=true
    else
        echo -e "${YELLOW}⚠ 宿主机 MySQL 连接失败${NC}"
        echo "可能的原因："
        echo "  1. 容器端口映射问题"
        echo "  2. MySQL 容器还在初始化中"
        echo "  3. 密码不匹配"
    fi
else
    echo -e "${YELLOW}⚠ 本地未安装 mysql 客户端，跳过宿主机连接测试${NC}"
fi

# 方法3: 使用 Docker 网络连接测试
echo "测试 Docker 网络连接..."
if docker exec "$MYSQL_CONTAINER_NAME" mysqladmin -uroot -pnyh123 ping 2>/dev/null | grep -q "mysqld is alive"; then
    echo -e "${GREEN}✓ MySQL 服务响应正常${NC}"
    MYSQL_CONNECTION_OK=true
else
    echo -e "${RED}✗ MySQL 服务无响应${NC}"
fi

if [ "$MYSQL_CONNECTION_OK" != "true" ]; then
    echo -e "\n${RED}MySQL 连接失败，请检查：${NC}"
    echo "1. 容器是否正常运行: docker ps"
    echo "2. 容器日志: docker logs $MYSQL_CONTAINER_NAME"
    echo "3. 重启容器: docker restart $MYSQL_CONTAINER_NAME"
    echo "4. 检查端口映射: docker port $MYSQL_CONTAINER_NAME"
    exit 1
fi

# 4. 检查商品数据库是否存在
echo -e "\n${BLUE}4. 检查商品数据库${NC}"

# 使用 Docker exec 检查数据库
DB_EXISTS=$(docker exec "$MYSQL_CONTAINER_NAME" mysql -uroot -pnyh123 -e "SHOW DATABASES LIKE 'newbee_mall_cloud_goods_db';" 2>/dev/null | grep newbee_mall_cloud_goods_db)

if [ -n "$DB_EXISTS" ]; then
    echo -e "${GREEN}✓ 数据库 newbee_mall_cloud_goods_db 存在${NC}"
else
    echo -e "${YELLOW}⚠ 数据库 newbee_mall_cloud_goods_db 不存在${NC}"
    echo "正在创建数据库..."
    
    if [ -f "static-files/newbee_mall_cloud_goods_db.sql" ]; then
        # 将 SQL 文件复制到容器中并执行
        docker cp static-files/newbee_mall_cloud_goods_db.sql "$MYSQL_CONTAINER_NAME":/tmp/
        docker exec "$MYSQL_CONTAINER_NAME" mysql -uroot -pnyh123 -e "source /tmp/newbee_mall_cloud_goods_db.sql"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 数据库创建成功${NC}"
        else
            echo -e "${RED}✗ 数据库创建失败${NC}"
            echo "尝试查看容器日志："
            docker logs --tail 20 "$MYSQL_CONTAINER_NAME"
            exit 1
        fi
    else
        echo -e "${RED}✗ 找不到数据库初始化文件: static-files/newbee_mall_cloud_goods_db.sql${NC}"
        exit 1
    fi
fi

# 5. 检查数据库表结构
echo -e "\n${BLUE}5. 检查数据库表结构${NC}"
TABLES=$(docker exec "$MYSQL_CONTAINER_NAME" mysql -uroot -pnyh123 -D newbee_mall_cloud_goods_db -e "SHOW TABLES;" 2>/dev/null | grep -v Tables_in)

if [ -n "$TABLES" ]; then
    echo -e "${GREEN}✓ 数据库表存在:${NC}"
    echo "$TABLES" | while read table; do
        echo "  - $table"
    done
    
    # 检查关键表的记录数
    echo -e "\n${BLUE}检查关键表数据:${NC}"
    GOODS_COUNT=$(docker exec "$MYSQL_CONTAINER_NAME" mysql -uroot -pnyh123 -D newbee_mall_cloud_goods_db -e "SELECT COUNT(*) FROM tb_newbee_mall_goods_info;" 2>/dev/null | tail -1)
    CATEGORY_COUNT=$(docker exec "$MYSQL_CONTAINER_NAME" mysql -uroot -pnyh123 -D newbee_mall_cloud_goods_db -e "SELECT COUNT(*) FROM tb_newbee_mall_goods_category;" 2>/dev/null | tail -1)
    
    echo "  - 商品数量: $GOODS_COUNT"
    echo "  - 分类数量: $CATEGORY_COUNT"
else
    echo -e "${RED}✗ 数据库表不存在${NC}"
    echo "重新初始化数据库..."
    docker cp static-files/newbee_mall_cloud_goods_db.sql "$MYSQL_CONTAINER_NAME":/tmp/
    docker exec "$MYSQL_CONTAINER_NAME" mysql -uroot -pnyh123 -e "source /tmp/newbee_mall_cloud_goods_db.sql"
fi

# 5. 测试数据库连接字符串
echo -e "\n${BLUE}5. 测试完整连接字符串${NC}"
CONNECTION_URL="jdbc:mysql://localhost:3306/newbee_mall_cloud_goods_db?useUnicode=true&serverTimezone=Asia/Shanghai&characterEncoding=utf8&autoReconnect=true&useSSL=false&allowMultiQueries=true"
echo "连接字符串: $CONNECTION_URL"

# 6. 检查商品服务配置文件
echo -e "\n${BLUE}6. 检查商品服务配置${NC}"
CONFIG_FILE="newbee-mall-cloud-goods-service/newbee-mall-cloud-goods-web/src/main/resources/application.properties"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ 配置文件存在${NC}"
    echo "数据库配置:"
    grep -E "spring.datasource" "$CONFIG_FILE" | while read line; do
        echo "  $line"
    done
else
    echo -e "${RED}✗ 配置文件不存在: $CONFIG_FILE${NC}"
fi

# 7. 检查商品服务是否运行
echo -e "\n${BLUE}7. 检查商品服务状态${NC}"
GOODS_SERVICE_PID=$(ps aux | grep "newbee-mall-cloud-goods" | grep -v grep | awk '{print $2}')

if [ -n "$GOODS_SERVICE_PID" ]; then
    echo -e "${GREEN}✓ 商品服务正在运行 (PID: $GOODS_SERVICE_PID)${NC}"
    
    # 检查服务端口
    if lsof -i :28002 &> /dev/null; then
        echo -e "${GREEN}✓ 商品服务端口 28002 正常监听${NC}"
    else
        echo -e "${YELLOW}⚠ 商品服务端口 28002 未监听${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 商品服务未运行${NC}"
    echo "启动商品服务:"
    echo "  cd newbee-mall-cloud-goods-service/newbee-mall-cloud-goods-web"
    echo "  mvn spring-boot:run"
fi

# 8. Docker 环境解决方案
echo -e "\n${BLUE}8. Docker 环境常见解决方案${NC}"
echo "如果仍然连接失败，请尝试:"
echo ""
echo "方案1: 检查和重启 MySQL 容器"
echo "  docker ps -a | grep mysql"
echo "  docker restart $MYSQL_CONTAINER_NAME"
echo "  docker logs $MYSQL_CONTAINER_NAME"
echo ""
echo "方案2: 重置 MySQL root 密码 (在容器内)"
echo "  docker exec -it $MYSQL_CONTAINER_NAME mysql -u root -p"
echo "  ALTER USER 'root'@'%' IDENTIFIED BY 'nyh123';"
echo "  FLUSH PRIVILEGES;"
echo ""
echo "方案3: 重新创建 MySQL 容器"
echo "  docker stop $MYSQL_CONTAINER_NAME"
echo "  docker rm $MYSQL_CONTAINER_NAME"
echo "  docker run --name mysql-server -e MYSQL_ROOT_PASSWORD=nyh123 -p 3306:3306 -d mysql:8.0"
echo ""
echo "方案4: 检查端口映射"
echo "  docker port $MYSQL_CONTAINER_NAME"
echo "  lsof -i :3306"
echo ""
echo "方案5: 重新初始化数据库 (Docker 环境)"
echo "  docker exec $MYSQL_CONTAINER_NAME mysql -uroot -pnyh123 -e \"DROP DATABASE IF EXISTS newbee_mall_cloud_goods_db;\""
echo "  docker cp static-files/newbee_mall_cloud_goods_db.sql $MYSQL_CONTAINER_NAME:/tmp/"
echo "  docker exec $MYSQL_CONTAINER_NAME mysql -uroot -pnyh123 -e \"source /tmp/newbee_mall_cloud_goods_db.sql\""
echo ""
echo "方案6: 查看容器详细信息"
echo "  docker inspect $MYSQL_CONTAINER_NAME"
echo "  docker exec $MYSQL_CONTAINER_NAME ps aux"
echo ""

echo -e "\n${GREEN}诊断完成！${NC}"