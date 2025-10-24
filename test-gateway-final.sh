#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 网关最终测试 ===${NC}"

# 1. 检查网关进程
echo -e "\n${YELLOW}1. 检查网关进程状态...${NC}"
GATEWAY_PID=$(ps aux | grep "NewBeeMallCloudMallGatewayApplication" | grep -v grep | awk '{print $2}')
if [ -n "$GATEWAY_PID" ]; then
    echo -e "${GREEN}✓ 网关进程正在运行 (PID: $GATEWAY_PID)${NC}"
else
    echo -e "${RED}✗ 网关进程未运行${NC}"
    exit 1
fi

# 2. 检查端口监听
echo -e "\n${YELLOW}2. 检查端口29110监听状态...${NC}"
if lsof -i :29110 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 端口29110正在监听${NC}"
    lsof -i :29110
else
    echo -e "${RED}✗ 端口29110未监听${NC}"
    exit 1
fi

# 3. 检查网关健康状态
echo -e "\n${YELLOW}3. 检查网关健康状态...${NC}"
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:29110/actuator/health -o /tmp/health_response.txt)
HEALTH_CODE="${HEALTH_RESPONSE: -3}"
HEALTH_BODY=$(cat /tmp/health_response.txt)

echo "健康检查响应码: $HEALTH_CODE"
echo "健康检查响应体: $HEALTH_BODY"

if [ "$HEALTH_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 网关健康检查通过${NC}"
else
    echo -e "${RED}✗ 网关健康检查失败 (状态码: $HEALTH_CODE)${NC}"
fi

# 4. 测试用户注册API（通过网关）
echo -e "\n${YELLOW}4. 测试用户注册API（通过网关）...${NC}"

# 生成随机用户名
RANDOM_USER="testuser$(date +%s)"

echo "测试用户: $RANDOM_USER"
echo "请求URL: http://localhost:29110/users/mall/register"

REGISTER_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "http://localhost:29110/users/mall/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"loginName\": \"$RANDOM_USER\",
    \"password\": \"123456\",
    \"passwordConfirm\": \"123456\"
  }")

echo -e "\n${BLUE}网关注册响应:${NC}"
echo "$REGISTER_RESPONSE"

# 提取HTTP状态码
HTTP_CODE=$(echo "$REGISTER_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "\n${GREEN}🎉 网关测试成功！用户注册通过网关正常工作${NC}"
elif [ "$HTTP_CODE" = "500" ]; then
    echo -e "\n${RED}❌ 网关仍然返回500错误${NC}"
    echo -e "${YELLOW}建议检查：${NC}"
    echo "1. 用户服务是否正常运行"
    echo "2. 网关路由配置是否正确"
    echo "3. 服务发现是否正常"
else
    echo -e "\n${YELLOW}⚠️  网关返回状态码: $HTTP_CODE${NC}"
fi

# 5. 检查最新的网关日志
echo -e "\n${YELLOW}5. 检查最新的网关日志...${NC}"
echo "最后10行网关日志："
tail -10 /Users/henryning/Documents/code/personCode/newbee-mall-cloud/newbee-mall-cloud-gateway-mall/gateway.log

echo -e "\n${BLUE}=== 测试完成 ===${NC}"