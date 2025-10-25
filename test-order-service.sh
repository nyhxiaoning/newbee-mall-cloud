#!/bin/bash

# 订单服务测试脚本
# 功能: 测试订单服务的各项功能和健康状态

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVICE_NAME="订单服务"
SERVICE_PORT="29040"
NACOS_SERVICE_NAME="newbee-mall-cloud-order-service"
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
    echo -e "${YELLOW}💡 请先启动订单服务${NC}"
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

# 4. 测试收货地址接口
echo -e "${YELLOW}🔍 4. 测试收货地址接口可访问性...${NC}"
address_response=$(curl -s -w "%{http_code}" -o /tmp/address_response.json "$BASE_URL/mall/address" 2>/dev/null)

if [ "$address_response" = "200" ]; then
    result_code=$(cat /tmp/address_response.json | grep -o '"resultCode":[0-9]*' | cut -d':' -f2)
    echo -e "${GREEN}✅ 收货地址接口可访问 (返回码: $result_code)${NC}"
    if [ "$result_code" = "416" ]; then
        echo -e "${BLUE}ℹ️  返回416是正常的，表示需要用户认证${NC}"
    fi
else
    echo -e "${RED}❌ 收货地址接口失败 (HTTP状态码: $address_response)${NC}"
fi

# 5. 测试订单接口
echo -e "${YELLOW}🔍 5. 测试订单接口可访问性...${NC}"
order_response=$(curl -s -w "%{http_code}" -o /tmp/order_response.json "$BASE_URL/orders/mall?pageNumber=1" 2>/dev/null)

if [ "$order_response" = "200" ]; then
    result_code=$(cat /tmp/order_response.json | grep -o '"resultCode":[0-9]*' | cut -d':' -f2)
    echo -e "${GREEN}✅ 订单接口可访问 (返回码: $result_code)${NC}"
    if [ "$result_code" = "416" ]; then
        echo -e "${BLUE}ℹ️  返回416是正常的，表示需要用户认证${NC}"
    fi
else
    echo -e "${RED}❌ 订单接口失败 (HTTP状态码: $order_response)${NC}"
fi

# 6. 测试Feign调用依赖服务
echo -e "${YELLOW}🔍 6. 测试Feign调用依赖服务...${NC}"
if [ -f "logs/订单服务.log" ]; then
    if grep -q "FeignException\|Connection refused\|Timeout" logs/订单服务.log; then
        echo -e "${RED}❌ Feign调用依赖服务异常${NC}"
        echo -e "${YELLOW}💡 检查用户服务、商品服务和购物车服务是否正常运行${NC}"
    else
        echo -e "${GREEN}✅ 未发现Feign调用异常${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  日志文件不存在，无法检查Feign状态${NC}"
fi

# 清理临时文件
rm -f /tmp/health_response.json /tmp/address_response.json /tmp/order_response.json

echo ""
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                              测试完成                                      ${NC}"
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${BLUE}💡 如果发现问题，请查看详细日志: tail -f logs/订单服务.log${NC}"
echo ""