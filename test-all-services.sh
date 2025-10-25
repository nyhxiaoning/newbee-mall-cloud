#!/bin/bash

# 全服务测试脚本
# 功能: 依次测试所有微服务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                        新蜂商城微服务系统 - 全服务测试                        ${NC}"
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${BLUE}测试时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# 测试脚本列表
TEST_SCRIPTS=(
    "test-user-service.sh:用户服务"
    "test-goods-service.sh:商品服务"
    "test-recommend-service.sh:推荐服务"
    "test-shop-cart-service.sh:购物车服务"
    "test-order-service.sh:订单服务"
    "test-gateway-service.sh:商城网关"
)

# 给所有测试脚本执行权限
echo -e "${YELLOW}🔧 设置测试脚本执行权限...${NC}"
for script_info in "${TEST_SCRIPTS[@]}"; do
    IFS=':' read -r script_name service_name <<< "$script_info"
    chmod +x "$script_name" 2>/dev/null
done
echo -e "${GREEN}✅ 权限设置完成${NC}"
echo ""

# 执行所有测试
failed_tests=()
for script_info in "${TEST_SCRIPTS[@]}"; do
    IFS=':' read -r script_name service_name <<< "$script_info"
    
    echo -e "${CYAN}🚀 开始测试: $service_name${NC}"
    echo "----------------------------------------"
    
    if [ -f "$script_name" ]; then
        if ./"$script_name"; then
            echo -e "${GREEN}✅ $service_name 测试通过${NC}"
        else
            echo -e "${RED}❌ $service_name 测试失败${NC}"
            failed_tests+=("$service_name")
        fi
    else
        echo -e "${RED}❌ 测试脚本 $script_name 不存在${NC}"
        failed_tests+=("$service_name")
    fi
    
    echo ""
    echo -e "${BLUE}⏳ 等待3秒后继续下一个测试...${NC}"
    sleep 3
    echo ""
done

# 测试结果汇总
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${CYAN}                              测试结果汇总                                   ${NC}"
echo -e "${CYAN}=============================================================================${NC}"

total_tests=${#TEST_SCRIPTS[@]}
failed_count=${#failed_tests[@]}
passed_count=$((total_tests - failed_count))

echo -e "${BLUE}📊 测试统计:${NC}"
echo -e "   • 总测试数: $total_tests"
echo -e "   • 通过数: ${GREEN}$passed_count${NC}"
echo -e "   • 失败数: ${RED}$failed_count${NC}"
echo ""

if [ $failed_count -eq 0 ]; then
    echo -e "${GREEN}🎉 所有服务测试通过！${NC}"
    echo -e "${GREEN}✅ 微服务系统运行正常${NC}"
else
    echo -e "${YELLOW}⚠️  以下服务测试失败:${NC}"
    for failed_service in "${failed_tests[@]}"; do
        echo -e "${RED}   ❌ $failed_service${NC}"
    done
    echo ""
    echo -e "${YELLOW}💡 建议:${NC}"
    echo -e "   1. 检查失败服务的日志文件"
    echo -e "   2. 确认所有依赖服务已正常启动"
    echo -e "   3. 检查Nacos注册状态"
    echo -e "   4. 验证数据库和Redis连接"
fi

echo ""
echo -e "${CYAN}=============================================================================${NC}"