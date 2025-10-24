#!/bin/bash

echo "🔧 网关路由问题快速修复脚本"
echo "============================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n${BLUE}1. 检查并重启必要服务${NC}"

# 检查 Nacos
if ! curl -s "http://127.0.0.1:8848/nacos/" > /dev/null; then
    echo -e "${RED}✗ Nacos 未运行，请先启动 Nacos${NC}"
    echo "启动命令: sh nacos/bin/startup.sh -m standalone"
    exit 1
fi
echo -e "${GREEN}✓ Nacos 运行正常${NC}"

# 停止现有服务
echo -e "\n${BLUE}2. 停止现有服务${NC}"
pkill -f "newbee-mall-cloud-user"
pkill -f "newbee-mall-cloud-gateway-mall"
sleep 5

echo -e "\n${BLUE}3. 重新启动用户服务${NC}"
cd newbee-mall-cloud-user-service/newbee-mall-cloud-user-web
nohup mvn spring-boot:run > user-service.log 2>&1 &
USER_PID=$!
echo "用户服务启动中... PID: $USER_PID"

# 等待用户服务启动
echo "等待用户服务启动完成..."
for i in {1..30}; do
    if curl -s "http://localhost:29000/users/mall/login" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 用户服务启动成功${NC}"
        break
    fi
    echo "等待用户服务启动... ($i/30)"
    sleep 2
done

echo -e "\n${BLUE}4. 重新启动网关服务${NC}"
cd ../../newbee-mall-cloud-gateway-mall
nohup mvn spring-boot:run > gateway.log 2>&1 &
GATEWAY_PID=$!
echo "网关服务启动中... PID: $GATEWAY_PID"

# 等待网关服务启动
echo "等待网关服务启动完成..."
for i in {1..30}; do
    if curl -s "http://localhost:29110/gateway/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 网关服务启动成功${NC}"
        break
    fi
    echo "等待网关服务启动... ($i/30)"
    sleep 2
done

echo -e "\n${BLUE}5. 等待服务注册完成${NC}"
echo "等待服务注册到 Nacos..."
sleep 15

echo -e "\n${BLUE}6. 测试网关路由${NC}"

# 测试用户注册接口
echo "测试用户注册接口..."
TEST_USER="test_$(date +%s)"
RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:29110/users/mall/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"loginName\": \"$TEST_USER\",
    \"password\": \"123456\"
  }" -o /tmp/test_response.json)

if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ 网关路由修复成功！${NC}"
    echo "测试用户: $TEST_USER"
    echo "响应内容:"
    cat /tmp/test_response.json
    echo ""
else
    echo -e "${RED}✗ 网关路由仍有问题 (HTTP: $RESPONSE)${NC}"
    echo "响应内容:"
    cat /tmp/test_response.json
    echo ""
    echo -e "\n${YELLOW}请检查服务日志:${NC}"
    echo "用户服务日志: tail -f newbee-mall-cloud-user-service/newbee-mall-cloud-user-web/user-service.log"
    echo "网关服务日志: tail -f newbee-mall-cloud-gateway-mall/gateway.log"
fi

echo -e "\n${BLUE}7. 服务信息${NC}"
echo "用户服务 PID: $USER_PID"
echo "网关服务 PID: $GATEWAY_PID"
echo ""
echo "测试命令:"
echo "curl -X POST \"http://localhost:29110/users/mall/register\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"loginName\": \"13800138003\","
echo "    \"password\": \"123456\""
echo "  }' -v"

# 清理临时文件
rm -f /tmp/test_response.json

echo -e "\n${GREEN}修复脚本执行完成！${NC}"