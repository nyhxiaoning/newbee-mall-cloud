#!/bin/bash

# 推荐服务测试脚本
# 功能: 测试推荐服务的各项功能和健康状态

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVICE_NAME="推荐服务"
SERVICE_PORT="29020"
NACOS_SERVICE_NAME="newbee-mall-cloud-recommend-service"
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
    echo -e "${YELLOW}💡 请先启动推荐服务${NC}"
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

# 4. 测试首页推荐信息接口
echo -e "${YELLOW}🔍 4. 测试首页推荐信息接口...${NC}"
recommend_response=$(curl -s -w "%{http_code}" -o /tmp/recommend_response.json "$BASE_URL/mall/index/recommondInfos" 2>/dev/null)

if [ "$recommend_response" = "200" ]; then
    result_code=$(cat /tmp/recommend_response.json | grep -o '"resultCode":[0-9]*' | cut -d':' -f2)
    if [ "$result_code" = "200" ]; then
        echo -e "${GREEN}✅ 首页推荐信息接口正常${NC}"
        # 检查返回数据结构
        if grep -q '"carousels":\|"hotGoodses":\|"newGoodses":\|"recommendGoodses":' /tmp/recommend_response.json; then
            echo -e "${GREEN}✅ 推荐数据结构完整${NC}"
        else
            echo -e "${YELLOW}⚠️  推荐数据结构可能不完整${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  首页推荐信息接口返回错误码: $result_code${NC}"
        echo -e "${BLUE}响应内容: $(cat /tmp/recommend_response.json)${NC}"
    fi
else
    echo -e "${RED}❌ 首页推荐信息接口失败 (HTTP状态码: $recommend_response)${NC}"
fi

# 5. 测试Feign调用依赖服务
echo -e "${YELLOW}🔍 5. 测试Feign调用依赖服务...${NC}"
if [ -f "logs/推荐服务.log" ]; then
    if grep -q "FeignException\|Connection refused\|Timeout" logs/推荐服务.log; then
        echo -e "${RED}❌ Feign调用依赖服务异常${NC}"
        echo -e "${YELLOW}💡 检查用户服务和商品服务是否正常运行${NC}"
    else
        echo -e "${GREEN}✅ 未发现Feign调用异常${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  日志文件不存在，无法检查Feign状态${NC}"
fi

# 清理临时文件
rm -f /tmp/health_response.json /tmp/recommend_response.json

echo ""
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                              测试完成                                      ${NC}"
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${BLUE}💡 如果发现问题，请查看详细日志: tail -f logs/推荐服务.log${NC}"
echo ""