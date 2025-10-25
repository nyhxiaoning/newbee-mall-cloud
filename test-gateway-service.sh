#!/bin/bash

# 商城网关测试脚本
# 功能: 测试商城网关的各项功能和健康状态

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVICE_NAME="商城网关"
SERVICE_PORT="29110"
NACOS_SERVICE_NAME="newbee-mall-cloud-gateway-mall"
BASE_URL="http://localhost:${SERVICE_PORT}"

echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                           $SERVICE_NAME 测试脚本                            ${NC}"
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${BLUE}测试时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}服务端口: $SERVICE_PORT${NC}"
echo -e "${BLUE}服务地址: $BASE_URL${NC}"
echo ""

# 1. 检查服务端口
echo -e "${YELLOW}🔍 1. 检查服务端口状态...${NC}"
if lsof -Pi :$SERVICE_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 端口 $SERVICE_PORT 正在监听${NC}"
else
    echo -e "${RED}❌ 端口 $SERVICE_PORT 未启动${NC}"
    echo -e "${YELLOW}💡 请先启动商城网关${NC}"
    exit 1
fi

# 2. 检查Nacos注册状态
echo -e "${YELLOW}🔍 2. 检查Nacos注册状态...${NC}"
nacos_response=$(curl -s "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=$NACOS_SERVICE_NAME" 2>/dev/null)
if echo "$nacos_response" | grep -q '"hosts":\[' && ! echo "$nacos_response" | grep -q '"hosts":\[\]'; then
    echo -e "${GREEN}✅ 服务已注册到Nacos${NC}"
else
    echo -e "${RED}❌ 服务未注册到Nacos${NC}"
fi

# 3. 健康检查
echo -e "${YELLOW}🔍 3. 健康检查...${NC}"
health_response=$(curl -s -w "%{http_code}" -o /tmp/health_response.json "$BASE_URL/actuator/health" 2>/dev/null)
if [ "$health_response" = "200" ]; then
    health_status=$(cat /tmp/health_response.json | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$health_status" = "UP" ]; then
        echo -e "${GREEN}✅ 健康检查通过 (状态: UP)${NC}"
    else
        echo -e "${YELLOW}⚠️  健康检查异常 (状态: $health_status)${NC}"
    fi
else
    echo -e "${RED}❌ 健康检查失败 (HTTP状态码: $health_response)${NC}"
fi

# 4. 测试网关路由 - 用户服务
echo -e "${YELLOW}🔍 4. 测试网关路由 - 用户服务...${NC}"
user_route_response=$(curl -s -w "%{http_code}" -o /tmp/user_route_response.json "$BASE_URL/users/mall/login" 2>/dev/null)
if [ "$user_route_response" = "200" ] || [ "$user_route_response" = "405" ]; then
    echo -e "${GREEN}✅ 用户服务路由正常${NC}"
else
    echo -e "${RED}❌ 用户服务路由失败 (HTTP状态码: $user_route_response)${NC}"
fi

# 5. 测试网关路由 - 商品服务
echo -e "${YELLOW}🔍 5. 测试网关路由 - 商品服务...${NC}"
goods_route_response=$(curl -s -w "%{http_code}" -o /tmp/goods_route_response.json "$BASE_URL/categories/mall/listAll" 2>/dev/null)
if [ "$goods_route_response" = "200" ]; then
    echo -e "${GREEN}✅ 商品服务路由正常${NC}"
else
    echo -e "${RED}❌ 商品服务路由失败 (HTTP状态码: $goods_route_response)${NC}"
fi

# 6. 测试网关路由 - 推荐服务
echo -e "${YELLOW}🔍 6. 测试网关路由 - 推荐服务...${NC}"
recommend_route_response=$(curl -s -w "%{http_code}" -o /tmp/recommend_route_response.json "$BASE_URL/mall/index/recommondInfos" 2>/dev/null)
if [ "$recommend_route_response" = "200" ]; then
    echo -e "${GREEN}✅ 推荐服务路由正常${NC}"
else
    echo -e "${RED}❌ 推荐服务路由失败 (HTTP状态码: $recommend_route_response)${NC}"
fi

# 7. 测试网关路由 - 购物车服务
echo -e "${YELLOW}🔍 7. 测试网关路由 - 购物车服务...${NC}"
cart_route_response=$(curl -s -w "%{http_code}" -o /tmp/cart_route_response.json "$BASE_URL/shop-cart/page?pageNumber=1" 2>/dev/null)
if [ "$cart_route_response" = "200" ]; then
    echo -e "${GREEN}✅ 购物车服务路由正常${NC}"
else
    echo -e "${RED}❌ 购物车服务路由失败 (HTTP状态码: $cart_route_response)${NC}"
fi

# 8. 测试网关路由 - 订单服务
echo -e "${YELLOW}🔍 8. 测试网关路由 - 订单服务...${NC}"
order_route_response=$(curl -s -w "%{http_code}" -o /tmp/order_route_response.json "$BASE_URL/orders/mall?pageNumber=1" 2>/dev/null)
if [ "$order_route_response" = "200" ]; then
    echo -e "${GREEN}✅ 订单服务路由正常${NC}"
else
    echo -e "${RED}❌ 订单服务路由失败 (HTTP状态码: $order_route_response)${NC}"
fi

# 9. 测试网关服务发现
echo -e "${YELLOW}🔍 9. 测试网关服务发现...${NC}"
services_response=$(curl -s -w "%{http_code}" -o /tmp/services_response.json "$BASE_URL/gateway/test/services" 2>/dev/null)
if [ "$services_response" = "200" ]; then
    echo -e "${GREEN}✅ 网关服务发现功能正常${NC}"
    # 检查关键服务是否被发现
    if grep -q '"user-service":true\|"goods-service":true\|"shop-cart-service":true' /tmp/services_response.json; then
        echo -e "${GREEN}✅ 关键服务已被网关发现${NC}"
    else
        echo -e "${YELLOW}⚠️  部分关键服务未被网关发现${NC}"
    fi
else
    echo -e "${RED}❌ 网关服务发现功能失败 (HTTP状态码: $services_response)${NC}"
fi

# 清理临时文件
rm -f /tmp/health_response.json /tmp/user_route_response.json /tmp/goods_route_response.json
rm -f /tmp/recommend_route_response.json /tmp/cart_route_response.json /tmp/order_route_response.json
rm -f /tmp/services_response.json

echo ""
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                              测试完成                                      ${NC}"
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${BLUE}💡 如果发现问题，请查看详细日志: tail -f logs/商城网关.log${NC}"
echo ""