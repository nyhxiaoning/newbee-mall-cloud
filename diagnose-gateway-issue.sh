#!/bin/bash

echo "🔍 网关路由问题诊断脚本"
echo "========================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置信息
GATEWAY_PORT=29110
USER_SERVICE_PORT=29000
GATEWAY_URL="http://localhost:${GATEWAY_PORT}"
USER_SERVICE_URL="http://localhost:${USER_SERVICE_PORT}"

echo -e "\n${BLUE}1. 检查服务状态${NC}"

# 检查网关服务
if curl -s "${GATEWAY_URL}/gateway/health" > /dev/null; then
    echo -e "${GREEN}✓ 网关服务运行正常 (端口: ${GATEWAY_PORT})${NC}"
else
    echo -e "${RED}✗ 网关服务未运行或无响应${NC}"
    echo "请检查网关服务是否启动："
    echo "  cd newbee-mall-cloud-gateway-mall"
    echo "  mvn spring-boot:run"
    exit 1
fi

# 检查用户服务
if curl -s "${USER_SERVICE_URL}/users/mall/login" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 用户服务运行正常 (端口: ${USER_SERVICE_PORT})${NC}"
else
    echo -e "${RED}✗ 用户服务未运行或无响应${NC}"
    echo "请检查用户服务是否启动"
    exit 1
fi

echo -e "\n${BLUE}2. 检查服务注册状态${NC}"

# 检查 Nacos 中的服务注册
echo "检查 Nacos 服务注册..."
NACOS_SERVICES=$(curl -s "http://127.0.0.1:8848/nacos/v1/ns/service/list?pageNo=1&pageSize=100" | grep -o '"name":"[^"]*"' | grep newbee-mall-cloud)

if echo "$NACOS_SERVICES" | grep -q "newbee-mall-cloud-user-service"; then
    echo -e "${GREEN}✓ 用户服务已注册到 Nacos${NC}"
else
    echo -e "${RED}✗ 用户服务未注册到 Nacos${NC}"
fi

if echo "$NACOS_SERVICES" | grep -q "newbee-mall-cloud-gateway-mall"; then
    echo -e "${GREEN}✓ 网关服务已注册到 Nacos${NC}"
else
    echo -e "${RED}✗ 网关服务未注册到 Nacos${NC}"
fi

# 通过网关检查服务发现
echo -e "\n检查网关服务发现..."
GATEWAY_SERVICES=$(curl -s "${GATEWAY_URL}/gateway/services" 2>/dev/null)
if echo "$GATEWAY_SERVICES" | grep -q "newbee-mall-cloud-user-service"; then
    echo -e "${GREEN}✓ 网关可以发现用户服务${NC}"
else
    echo -e "${RED}✗ 网关无法发现用户服务${NC}"
    echo "网关发现的服务列表："
    echo "$GATEWAY_SERVICES"
fi

echo -e "\n${BLUE}3. 测试网关路由${NC}"

# 测试直接访问用户服务
echo "测试直接访问用户服务注册接口..."
DIRECT_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${USER_SERVICE_URL}/users/mall/register" \
  -H "Content-Type: application/json" \
  -d '{
    "loginName": "test_direct_'$(date +%s)'",
    "password": "123456"
  }' -o /tmp/direct_response.json)

if [ "$DIRECT_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ 直接访问用户服务注册成功${NC}"
else
    echo -e "${RED}✗ 直接访问用户服务注册失败 (HTTP: $DIRECT_RESPONSE)${NC}"
    cat /tmp/direct_response.json
fi

# 测试通过网关访问
echo -e "\n测试通过网关访问用户服务注册接口..."
GATEWAY_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${GATEWAY_URL}/users/mall/register" \
  -H "Content-Type: application/json" \
  -d '{
    "loginName": "test_gateway_'$(date +%s)'",
    "password": "123456"
  }' -o /tmp/gateway_response.json)

if [ "$GATEWAY_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ 通过网关访问用户服务注册成功${NC}"
else
    echo -e "${RED}✗ 通过网关访问用户服务注册失败 (HTTP: $GATEWAY_RESPONSE)${NC}"
    echo "响应内容："
    cat /tmp/gateway_response.json
    echo ""
fi

echo -e "\n${BLUE}4. 检查网关路由配置${NC}"

# 检查路由配置
ROUTES=$(curl -s "${GATEWAY_URL}/gateway/routes" 2>/dev/null)
echo "网关路由信息："
echo "$ROUTES"

echo -e "\n${BLUE}5. 网络连通性测试${NC}"

# 测试网关到用户服务的连通性
echo "测试网关内部路由..."
INTERNAL_TEST=$(curl -s -w "%{http_code}" "${GATEWAY_URL}/users/mall/login" \
  -H "Content-Type: application/json" \
  -d '{"loginName": "test", "password": "test"}' -o /tmp/internal_test.json)

echo "网关内部路由测试结果: HTTP $INTERNAL_TEST"
if [ "$INTERNAL_TEST" != "000" ]; then
    echo -e "${GREEN}✓ 网关路由连通性正常${NC}"
else
    echo -e "${RED}✗ 网关路由连通性异常${NC}"
fi

echo -e "\n${BLUE}6. 问题分析和解决方案${NC}"

if [ "$GATEWAY_RESPONSE" != "200" ]; then
    echo -e "${YELLOW}检测到网关路由问题，可能的原因：${NC}"
    echo ""
    echo "1. 服务发现问题："
    echo "   - 检查 Nacos 连接: curl http://127.0.0.1:8848/nacos/"
    echo "   - 重启服务注册: 重启用户服务和网关服务"
    echo ""
    echo "2. 网关配置问题："
    echo "   - 检查路由路径匹配: /users/mall/**"
    echo "   - 检查负载均衡配置: lb://newbee-mall-cloud-user-service"
    echo ""
    echo "3. 网络问题："
    echo "   - 检查端口冲突: lsof -i :29110 和 lsof -i :29000"
    echo "   - 检查防火墙设置"
    echo ""
    echo "4. 超时问题："
    echo "   - 增加网关超时配置"
    echo "   - 检查服务响应时间"
    echo ""
    
    echo -e "${BLUE}建议的修复步骤：${NC}"
    echo "1. 重启 Nacos: 确保服务注册中心正常"
    echo "2. 重启用户服务: cd newbee-mall-cloud-user-service/newbee-mall-cloud-user-web && mvn spring-boot:run"
    echo "3. 重启网关服务: cd newbee-mall-cloud-gateway-mall && mvn spring-boot:run"
    echo "4. 等待 30 秒让服务完全注册"
    echo "5. 重新测试网关接口"
else
    echo -e "${GREEN}✓ 网关路由工作正常！${NC}"
fi

echo -e "\n${GREEN}诊断完成！${NC}"

# 清理临时文件
rm -f /tmp/direct_response.json /tmp/gateway_response.json /tmp/internal_test.json