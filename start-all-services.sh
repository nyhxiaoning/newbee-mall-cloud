#!/bin/bash

echo "=== 新蜂商城微服务系统启动脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查基础服务
check_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    echo -n "等待 $service_name 启动..."
    while [ $attempt -le $max_attempts ]; do
        if lsof -i :$port > /dev/null 2>&1; then
            echo -e " ${GREEN}✅ 启动成功${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    echo -e " ${RED}❌ 启动超时${NC}"
    return 1
}

# 1. 检查并启动基础服务
echo "1. 检查基础服务..."

# 检查 Nacos
if ! lsof -i :8848 > /dev/null 2>&1; then
    echo -e "${YELLOW}启动 Nacos...${NC}"
    # 这里添加启动 Nacos 的命令
    echo "请手动启动 Nacos (端口 8848)"
else
    echo -e "${GREEN}✅ Nacos 已运行${NC}"
fi

# 检查 Redis
if ! redis-cli ping > /dev/null 2>&1; then
    echo -e "${YELLOW}启动 Redis...${NC}"
    redis-server &
    sleep 3
else
    echo -e "${GREEN}✅ Redis 已运行${NC}"
fi

# 检查 MySQL
if ! mysqladmin ping -h localhost -P 3306 > /dev/null 2>&1; then
    echo -e "${RED}❌ MySQL 未启动，请手动启动 MySQL${NC}"
    exit 1
else
    echo -e "${GREEN}✅ MySQL 已运行${NC}"
fi

echo ""
echo "2. 启动微服务..."

# 启动用户服务
echo -e "${YELLOW}启动用户服务...${NC}"
cd newbee-mall-cloud-user-service/newbee-mall-cloud-user-web
mvn spring-boot:run > /dev/null 2>&1 &
USER_PID=$!
cd ../..
check_service "用户服务" 28080

# 启动商品服务
echo -e "${YELLOW}启动商品服务...${NC}"
cd newbee-mall-cloud-goods-service/newbee-mall-cloud-goods-web
mvn spring-boot:run > /dev/null 2>&1 &
GOODS_PID=$!
cd ../..
check_service "商品服务" 28081

# 启动购物车服务
echo -e "${YELLOW}启动购物车服务...${NC}"
cd newbee-mall-cloud-shop-cart-service/newbee-mall-cloud-shop-cart-web
mvn spring-boot:run > /dev/null 2>&1 &
CART_PID=$!
cd ../..
check_service "购物车服务" 28082

# 启动订单服务
echo -e "${YELLOW}启动订单服务...${NC}"
cd newbee-mall-cloud-order-service/newbee-mall-cloud-order-web
mvn spring-boot:run > /dev/null 2>&1 &
ORDER_PID=$!
cd ../..
check_service "订单服务" 29040

# 启动推荐服务
echo -e "${YELLOW}启动推荐服务...${NC}"
cd newbee-mall-cloud-recommend-service/newbee-mall-cloud-recommend-web
mvn spring-boot:run > /dev/null 2>&1 &
RECOMMEND_PID=$!
cd ../..
check_service "推荐服务" 29050

# 等待服务注册
echo ""
echo "3. 等待服务注册到 Nacos..."
sleep 10

# 启动网关
echo -e "${YELLOW}启动商城网关...${NC}"
cd newbee-mall-cloud-gateway-mall
mvn spring-boot:run > /dev/null 2>&1 &
GATEWAY_PID=$!
cd ..
check_service "商城网关" 29110

echo ""
echo -e "${GREEN}=== 所有服务启动完成 ===${NC}"
echo ""
echo "服务访问地址："
echo "  🌐 商城网关: http://localhost:29110"
echo "  📊 网关健康检查: http://localhost:29110/gateway/health"
echo "  📋 服务列表: http://localhost:29110/gateway/services"
echo "  🔗 路由信息: http://localhost:29110/gateway/routes"
echo "  📖 Swagger 文档: http://localhost:29110/swagger-ui.html"
echo ""
echo "进程 ID："
echo "  用户服务: $USER_PID"
echo "  商品服务: $GOODS_PID"
echo "  购物车服务: $CART_PID"
echo "  订单服务: $ORDER_PID"
echo "  推荐服务: $RECOMMEND_PID"
echo "  商城网关: $GATEWAY_PID"

# 保存 PID 到文件
echo "$USER_PID $GOODS_PID $CART_PID $ORDER_PID $RECOMMEND_PID $GATEWAY_PID" > .service_pids

echo ""
echo "使用 './stop-all-services.sh' 停止所有服务"