#!/bin/bash

echo "=== 修复网关配置并重启服务 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 停止网关服务
echo -e "${YELLOW}1. 停止网关服务...${NC}"
pkill -f "newbee-mall-cloud-gateway-mall" || echo "网关服务未运行"
sleep 2

# 2. 检查配置文件
echo -e "${YELLOW}2. 检查配置文件修复情况...${NC}"
CONFIG_FILE="./newbee-mall-cloud-gateway-mall/src/main/resources/application.properties"

if grep -q "spring.cloud.gateway.default-filters\[1\].args.retries=3" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ 重试配置已修复${NC}"
else
    echo -e "${RED}✗ 重试配置未修复${NC}"
fi

# 3. 启动网关服务
echo -e "${YELLOW}3. 启动网关服务...${NC}"
cd ./newbee-mall-cloud-gateway-mall

# 后台启动网关服务
nohup mvn spring-boot:run > gateway.log 2>&1 &
GATEWAY_PID=$!

echo "网关服务启动中，PID: $GATEWAY_PID"

# 4. 等待服务启动
echo -e "${YELLOW}4. 等待网关服务启动...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:29110/actuator/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 网关服务启动成功${NC}"
        break
    fi
    echo "等待中... ($i/30)"
    sleep 2
done

# 5. 检查服务状态
echo -e "${YELLOW}5. 检查服务状态...${NC}"
if curl -s http://localhost:29110/actuator/health | grep -q "UP"; then
    echo -e "${GREEN}✓ 网关健康检查通过${NC}"
else
    echo -e "${RED}✗ 网关健康检查失败${NC}"
    echo "查看日志："
    tail -20 gateway.log
    exit 1
fi

# 6. 测试用户注册接口
echo -e "${YELLOW}6. 测试用户注册接口...${NC}"

# 测试直接调用用户服务
echo "测试直接调用用户服务..."
DIRECT_RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:29000/users/mall/register" \
  -H "Content-Type: application/json" \
  -d '{
    "loginName": "test_direct_'$(date +%s)'",
    "password": "123456"
  }')

DIRECT_CODE="${DIRECT_RESPONSE: -3}"
echo "直接调用响应码: $DIRECT_CODE"

# 测试通过网关调用
echo "测试通过网关调用..."
GATEWAY_RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:29110/users/mall/register" \
  -H "Content-Type: application/json" \
  -d '{
    "loginName": "test_gateway_'$(date +%s)'",
    "password": "123456"
  }')

GATEWAY_CODE="${GATEWAY_RESPONSE: -3}"
echo "网关调用响应码: $GATEWAY_CODE"

# 7. 结果分析
echo -e "${YELLOW}7. 测试结果分析...${NC}"

if [ "$DIRECT_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 直接调用用户服务成功${NC}"
else
    echo -e "${RED}✗ 直接调用用户服务失败 (状态码: $DIRECT_CODE)${NC}"
fi

if [ "$GATEWAY_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 通过网关调用成功 - 问题已解决！${NC}"
elif [ "$GATEWAY_CODE" = "500" ]; then
    echo -e "${RED}✗ 网关仍返回500错误${NC}"
    echo "查看最新的网关日志："
    tail -50 gateway.log | grep -E "(ERROR|Exception|Failed)"
else
    echo -e "${YELLOW}⚠ 网关返回状态码: $GATEWAY_CODE${NC}"
    echo "响应内容: ${GATEWAY_RESPONSE%???}"
fi

# 8. 提供调试信息
echo -e "${YELLOW}8. 调试信息...${NC}"
echo "网关进程: $(ps aux | grep newbee-mall-cloud-gateway-mall | grep -v grep || echo '未找到')"
echo "用户服务进程: $(ps aux | grep newbee-mall-cloud-user-service | grep -v grep || echo '未找到')"

# 检查Nacos注册情况
echo "检查Nacos服务注册..."
if curl -s "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=newbee-mall-cloud-user-service" | grep -q "newbee-mall-cloud-user-service"; then
    echo -e "${GREEN}✓ 用户服务已在Nacos注册${NC}"
else
    echo -e "${RED}✗ 用户服务未在Nacos注册${NC}"
fi

echo -e "${YELLOW}=== 修复完成 ===${NC}"
echo "如果问题仍然存在，请查看详细日志："
echo "  网关日志: tail -f gateway.log"
echo "  用户服务日志: 检查用户服务的日志文件"