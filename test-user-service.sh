#!/bin/bash

# 用户服务测试脚本
# 功能: 测试用户服务的启动状态、API接口和数据库连接

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVICE_NAME="用户服务"
SERVICE_PORT=29000
NACOS_SERVICE_NAME="newbee-mall-cloud-user-service"
SERVICE_PATH="newbee-mall-cloud-user-service/newbee-mall-cloud-user-web"

echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                           $SERVICE_NAME 测试脚本                            ${NC}"
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${BLUE}测试时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# 1. 检查端口状态
echo -e "${YELLOW}🔍 1. 检查服务端口状态...${NC}"
# 检查端口是否被监听（包括所有网络接口）
PORT_CHECK=$(netstat -an | grep ":$SERVICE_PORT" | grep LISTEN)
if [ -n "$PORT_CHECK" ]; then
    echo -e "${GREEN}✅ 端口 $SERVICE_PORT 正在监听${NC}"
    echo -e "${BLUE}   监听详情: $PORT_CHECK${NC}"
    # 获取进程ID
    if command -v lsof >/dev/null 2>&1; then
        PID=$(lsof -ti :$SERVICE_PORT 2>/dev/null)
        if [ -n "$PID" ]; then
            echo -e "${BLUE}   进程ID: $PID${NC}"
        fi
    fi
else
    echo -e "${RED}❌ 端口 $SERVICE_PORT 未被监听${NC}"
    echo -e "${YELLOW}💡 启动建议: cd $SERVICE_PATH && mvn spring-boot:run${NC}"
    exit 1
fi

# 2. 检查Nacos注册状态
echo -e "${YELLOW}🔍 2. 检查Nacos注册状态...${NC}"
NACOS_RESPONSE=$(curl -s "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=$NACOS_SERVICE_NAME" 2>/dev/null)
if echo "$NACOS_RESPONSE" | grep -q '"hosts":\[' && ! echo "$NACOS_RESPONSE" | grep -q '"hosts":\[\]'; then
    echo -e "${GREEN}✅ 服务已注册到Nacos${NC}"
    INSTANCE_COUNT=$(echo "$NACOS_RESPONSE" | grep -o '"hosts":\[[^]]*\]' | grep -o '{[^}]*}' | wc -l)
    echo -e "${BLUE}   实例数量: $INSTANCE_COUNT${NC}"
else
    echo -e "${RED}❌ 服务未注册到Nacos${NC}"
fi

# 3. 健康检查
echo -e "${YELLOW}🔍 3. 健康检查...${NC}"
# 尝试多个地址进行健康检查
HEALTH_RESPONSE=""
for HOST in "localhost" "127.0.0.1" "0.0.0.0"; do
    HEALTH_RESPONSE=$(curl -s --connect-timeout 3 "http://$HOST:$SERVICE_PORT/actuator/health" 2>/dev/null)
    if [ -n "$HEALTH_RESPONSE" ]; then
        echo -e "${BLUE}   通过 $HOST 连接成功${NC}"
        break
    fi
done

if echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✅ 服务健康状态正常${NC}"
elif [ -n "$HEALTH_RESPONSE" ]; then
    echo -e "${YELLOW}⚠️  服务响应但状态未知${NC}"
    echo -e "${YELLOW}   响应: $HEALTH_RESPONSE${NC}"
else
    echo -e "${RED}❌ 服务健康检查失败 - 无法连接${NC}"
    # 尝试简单的TCP连接测试
    if nc -z localhost $SERVICE_PORT 2>/dev/null; then
        echo -e "${YELLOW}   但端口可达，可能是健康检查端点未配置${NC}"
    fi
fi

# 4. 测试用户管理API
echo -e "${YELLOW}🔍 4. 测试用户管理API...${NC}"

# 确定可用的主机地址
API_HOST="localhost"
for HOST in "localhost" "127.0.0.1"; do
    if nc -z $HOST $SERVICE_PORT 2>/dev/null; then
        API_HOST=$HOST
        break
    fi
done

# 测试管理员登录接口
echo -e "${BLUE}   测试管理员登录接口...${NC}"
LOGIN_RESPONSE=$(curl -s --connect-timeout 5 -X POST "http://$API_HOST:$SERVICE_PORT/users/admin/login" \
    -H "Content-Type: application/json" \
    -d '{
        "userName": "admin",
        "passwordMd5": "e10adc3949ba59abbe56e057f20f883e"
    }' 2>/dev/null)

if echo "$LOGIN_RESPONSE" | grep -q '"resultCode":200'; then
    echo -e "${GREEN}   ✅ 管理员登录接口正常${NC}"
    # 提取token用于后续测试
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"data":"[^"]*"' | cut -d'"' -f4)
    echo -e "${BLUE}   Token: ${TOKEN:0:20}...${NC}"
else
    echo -e "${RED}   ❌ 管理员登录接口异常${NC}"
    echo -e "${YELLOW}   响应: $LOGIN_RESPONSE${NC}"
fi

# 测试用户列表接口（需要token）
if [ ! -z "$TOKEN" ]; then
    echo -e "${BLUE}   测试用户列表接口...${NC}"
    USER_LIST_RESPONSE=$(curl -s "http://localhost:$SERVICE_PORT/users/admin/list?page=1&limit=10" \
        -H "token: $TOKEN" 2>/dev/null)
    
    if echo "$USER_LIST_RESPONSE" | grep -q '"resultCode":200'; then
        echo -e "${GREEN}   ✅ 用户列表接口正常${NC}"
        TOTAL_COUNT=$(echo "$USER_LIST_RESPONSE" | grep -o '"totalCount":[0-9]*' | cut -d':' -f2)
        echo -e "${BLUE}   用户总数: $TOTAL_COUNT${NC}"
    else
        echo -e "${RED}   ❌ 用户列表接口异常${NC}"
        echo -e "${YELLOW}   响应: $USER_LIST_RESPONSE${NC}"
    fi
fi

# 5. 测试商城用户API
echo -e "${YELLOW}🔍 5. 测试商城用户API...${NC}"

# 测试用户注册接口
echo -e "${BLUE}   测试用户注册接口...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "http://localhost:$SERVICE_PORT/users/mall/register" \
    -H "Content-Type: application/json" \
    -d '{
        "loginName": "test_user_'$(date +%s)'",
        "password": "123456"
    }' 2>/dev/null)

if echo "$REGISTER_RESPONSE" | grep -q '"resultCode":200'; then
    echo -e "${GREEN}   ✅ 用户注册接口正常${NC}"
elif echo "$REGISTER_RESPONSE" | grep -q '"resultCode":500' && echo "$REGISTER_RESPONSE" | grep -q "已存在"; then
    echo -e "${GREEN}   ✅ 用户注册接口正常（用户已存在）${NC}"
else
    echo -e "${RED}   ❌ 用户注册接口异常${NC}"
    echo -e "${YELLOW}   响应: $REGISTER_RESPONSE${NC}"
fi

# 6. 数据库连接测试
echo -e "${YELLOW}🔍 6. 数据库连接测试...${NC}"
DB_TEST_RESPONSE=$(curl -s "http://localhost:$SERVICE_PORT/actuator/health/db" 2>/dev/null)
if echo "$DB_TEST_RESPONSE" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✅ 数据库连接正常${NC}"
else
    echo -e "${RED}❌ 数据库连接异常${NC}"
    echo -e "${YELLOW}   响应: $DB_TEST_RESPONSE${NC}"
fi

# 7. 检查日志文件
echo -e "${YELLOW}🔍 7. 检查服务日志...${NC}"
LOG_FILE="logs/用户服务.log"
if [ -f "$LOG_FILE" ]; then
    echo -e "${GREEN}✅ 日志文件存在${NC}"
    ERROR_COUNT=$(grep -c "ERROR" "$LOG_FILE" 2>/dev/null || echo "0")
    WARN_COUNT=$(grep -c "WARN" "$LOG_FILE" 2>/dev/null || echo "0")
    echo -e "${BLUE}   错误数量: $ERROR_COUNT${NC}"
    echo -e "${BLUE}   警告数量: $WARN_COUNT${NC}"
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}   最近的错误:${NC}"
        tail -n 20 "$LOG_FILE" | grep "ERROR" | tail -n 3
    fi
else
    echo -e "${YELLOW}⚠️  日志文件不存在: $LOG_FILE${NC}"
fi

# 8. 性能测试
echo -e "${YELLOW}🔍 8. 简单性能测试...${NC}"
echo -e "${BLUE}   测试响应时间...${NC}"
START_TIME=$(date +%s%N)
curl -s "http://localhost:$SERVICE_PORT/actuator/health" > /dev/null
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo -e "${BLUE}   响应时间: ${RESPONSE_TIME}ms${NC}"

if [ $RESPONSE_TIME -lt 1000 ]; then
    echo -e "${GREEN}   ✅ 响应时间良好${NC}"
else
    echo -e "${YELLOW}   ⚠️  响应时间较慢${NC}"
fi

# 总结
echo ""
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                              测试总结                                       ${NC}"
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${GREEN}🎯 $SERVICE_NAME 测试完成${NC}"
echo -e "${BLUE}📊 服务端口: $SERVICE_PORT${NC}"
echo -e "${BLUE}📊 Nacos服务名: $NACOS_SERVICE_NAME${NC}"
echo -e "${BLUE}📊 响应时间: ${RESPONSE_TIME}ms${NC}"
echo ""
echo -e "${YELLOW}💡 如果发现问题，请检查:${NC}"
echo -e "   1. 服务日志: tail -f $LOG_FILE"
echo -e "   2. 数据库连接配置"
echo -e "   3. Nacos连接配置"
echo -e "   4. 端口占用情况: lsof -i :$SERVICE_PORT"
echo ""