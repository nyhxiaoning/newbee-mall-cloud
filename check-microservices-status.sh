#!/bin/bash

# ============================================================================
# 新蜂商城微服务系统 - 状态检查脚本（优化版）
# 功能：全面检查微服务运行状态、Nacos注册状态、健康状态和进程信息
# 作者：Java后端开发工程师
# 版本：v2.0
# ============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# 配置参数
NACOS_URL="http://127.0.0.1:8848"
HEALTH_CHECK_TIMEOUT=5
LOG_DIR="./logs"

# 服务配置数组（按启动顺序排列）
declare -A SERVICES=(
    ["user-service"]="29000:newbee-mall-cloud-user-service:用户服务:./newbee-mall-cloud-user-service/newbee-mall-cloud-user-web"
    ["goods-service"]="29010:newbee-mall-cloud-goods-service:商品服务:./newbee-mall-cloud-goods-service/newbee-mall-cloud-goods-web"
    ["recommend-service"]="29020:newbee-mall-cloud-recommend-service:推荐服务:./newbee-mall-cloud-recommend-service/newbee-mall-cloud-recommend-web"
    ["cart-service"]="29030:newbee-mall-cloud-shop-cart-service:购物车服务:./newbee-mall-cloud-shop-cart-service/newbee-mall-cloud-shop-cart-web"
    ["order-service"]="29040:newbee-mall-cloud-order-service:订单服务:./newbee-mall-cloud-order-service/newbee-mall-cloud-order-web"
    ["admin-gateway"]="29100:newbee-mall-cloud-gateway-admin:管理网关:./newbee-mall-cloud-gateway-admin"
    ["mall-gateway"]="29110:newbee-mall-cloud-gateway-mall:商城网关:./newbee-mall-cloud-gateway-mall"
)

# 启动顺序数组
SERVICE_ORDER=("user-service" "goods-service" "recommend-service" "cart-service" "order-service" "admin-gateway" "mall-gateway")

# 工具函数
print_header() {
    clear
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${WHITE}                    新蜂商城微服务系统 - 状态检查（优化版）                    ${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${YELLOW}检查时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${GRAY}脚本版本: v2.0 | 系统: $(uname -s) | 用户: $(whoami)${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_debug() {
    echo -e "${GRAY}🔍 $1${NC}"
}

# 获取进程信息
get_process_info() {
    local port=$1
    local pid=$(lsof -ti :$port 2>/dev/null)
    if [ -n "$pid" ]; then
        local process_info=$(ps -p $pid -o pid,ppid,etime,cmd --no-headers 2>/dev/null)
        echo "$process_info"
    else
        echo ""
    fi
}

# 检查服务健康状态
check_service_health() {
    local port=$1
    local health_url="http://localhost:$port/actuator/health"
    
    local response=$(curl -s --connect-timeout $HEALTH_CHECK_TIMEOUT "$health_url" 2>/dev/null)
    if echo "$response" | grep -q '"status":"UP"'; then
        return 0  # 健康
    else
        return 1  # 不健康
    fi
}

# 检查日志文件
check_log_file() {
    local service_key=$1
    local log_file="$LOG_DIR/${service_key}.log"
    
    if [ -f "$log_file" ]; then
        local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
        local last_modified=$(stat -f%m "$log_file" 2>/dev/null || stat -c%Y "$log_file" 2>/dev/null)
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_modified))
        
        echo "${file_size}:${time_diff}"
    else
        echo "0:999999"
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口未被占用
    fi
}

# 检查服务是否已注册到Nacos
check_nacos_registration() {
    local service_name=$1
    local response=$(curl -s "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=$service_name" 2>/dev/null)
    
    if echo "$response" | grep -q '"hosts":\[' && ! echo "$response" | grep -q '"hosts":\[\]'; then
        return 0  # 服务已注册
    else
        return 1  # 服务未注册
    fi
}

# 检查基础服务
check_infrastructure() {
    echo -e "${PURPLE}🔧 基础服务状态检查${NC}"
    echo "----------------------------------------"
    
    local infrastructure_ok=true
    
    # 检查Nacos
    echo -n "Nacos服务 (8848): "
    if curl -s --connect-timeout 3 "$NACOS_URL/nacos/v1/console/health/readiness" >/dev/null 2>&1; then
        print_success "运行正常"
        
        # 检查Nacos版本和服务数量
        local nacos_info=$(curl -s "$NACOS_URL/nacos/v1/ns/operator/servers" 2>/dev/null)
        if [ -n "$nacos_info" ]; then
            print_debug "Nacos集群状态正常"
        fi
    else
        print_error "未启动或不可访问"
        print_warning "请检查: 1) Nacos是否启动 2) 端口8848是否被占用 3) 防火墙设置"
        infrastructure_ok=false
    fi
    
    # 检查Redis
    echo -n "Redis服务 (6379): "
    if redis-cli ping >/dev/null 2>&1; then
        print_success "运行正常"
        
        # 检查Redis信息
        local redis_info=$(redis-cli info server 2>/dev/null | grep "redis_version" | cut -d: -f2 | tr -d '\r')
        if [ -n "$redis_info" ]; then
            print_debug "Redis版本: $redis_info"
        fi
    else
        print_error "未启动或不可访问"
        print_warning "请检查: 1) Redis是否启动 2) 端口6379是否被占用 3) 密码配置是否正确"
        infrastructure_ok=false
    fi
    
    # 检查MySQL
    echo -n "MySQL服务 (3306): "
    if nc -z localhost 3306 2>/dev/null; then
        print_success "端口可访问"
        print_debug "MySQL连接端口正常"
    else
        print_error "端口不可访问"
        print_warning "请检查: 1) MySQL是否启动 2) 端口3306是否被占用"
        infrastructure_ok=false
    fi
    
    # 检查日志目录
    echo -n "日志目录: "
    if [ -d "$LOG_DIR" ]; then
        print_success "存在 ($LOG_DIR)"
    else
        print_warning "不存在，将创建目录"
        mkdir -p "$LOG_DIR"
    fi
    
    if [ "$infrastructure_ok" = false ]; then
        echo ""
        print_error "基础服务存在问题，建议先解决基础服务问题再启动微服务"
    fi
    
    echo ""
}

# 检查微服务状态
check_microservices() {
    echo -e "${PURPLE}🚀 微服务状态检查${NC}"
    echo "----------------------------------------"
    
    local running_count=0
    local registered_count=0
    local healthy_count=0
    local total_count=${#SERVICES[@]}
    
    printf "%-12s %-6s %-8s %-8s %-8s %-10s %-15s\n" "服务名称" "端口" "进程" "健康" "注册" "日志状态" "进程信息"
    echo "--------------------------------------------------------------------------------"
    
    for service_key in "${SERVICE_ORDER[@]}"; do
        local service_info=${SERVICES[$service_key]}
        IFS=':' read -r port nacos_name display_name service_path <<< "$service_info"
        
        # 检查端口状态
        local port_status=""
        local process_info=""
        if check_port $port; then
            port_status="${GREEN}运行${NC}"
            ((running_count++))
            
            # 获取进程信息
            process_info=$(get_process_info $port)
            if [ -n "$process_info" ]; then
                local pid=$(echo "$process_info" | awk '{print $1}')
                local etime=$(echo "$process_info" | awk '{print $3}')
                process_info="PID:$pid 运行:$etime"
            fi
        else
            port_status="${RED}停止${NC}"
            process_info="无进程"
        fi
        
        # 检查健康状态
        local health_status=""
        if check_port $port; then
            if check_service_health $port; then
                health_status="${GREEN}健康${NC}"
                ((healthy_count++))
            else
                health_status="${YELLOW}异常${NC}"
            fi
        else
            health_status="${GRAY}未知${NC}"
        fi
        
        # 检查Nacos注册状态
        local nacos_status=""
        if check_nacos_registration "$nacos_name"; then
            nacos_status="${GREEN}已注册${NC}"
            ((registered_count++))
        else
            nacos_status="${RED}未注册${NC}"
        fi
        
        # 检查日志状态
        local log_status=""
        local log_info=$(check_log_file $service_key)
        IFS=':' read -r file_size time_diff <<< "$log_info"
        
        if [ "$file_size" -gt 0 ]; then
            if [ "$time_diff" -lt 300 ]; then  # 5分钟内有更新
                log_status="${GREEN}活跃${NC}"
            else
                log_status="${YELLOW}静默${NC}"
            fi
        else
            log_status="${RED}无日志${NC}"
        fi
        
        printf "%-20s %-6s %-15s %-15s %-15s %-18s %-30s\n" \
            "$display_name" "$port" "$port_status" "$health_status" "$nacos_status" "$log_status" "$process_info"
    done
    
    echo ""
    echo -e "${CYAN}📊 统计信息:${NC}"
    echo -e "   🟢 运行中的服务: ${running_count}/${total_count}"
    echo -e "   💚 健康的服务: ${healthy_count}/${total_count}"
    echo -e "   📝 已注册的服务: ${registered_count}/${total_count}"
    
    # 状态评估
    if [ $running_count -eq $total_count ] && [ $registered_count -eq $total_count ] && [ $healthy_count -eq $total_count ]; then
        print_success "🎉 所有服务运行正常、健康且已注册到Nacos"
    elif [ $running_count -eq $total_count ] && [ $registered_count -eq $total_count ]; then
        print_warning "⚠️ 所有服务已启动并注册，但部分服务健康检查异常"
    elif [ $running_count -eq $total_count ]; then
        print_warning "⚠️ 所有服务已启动，但部分服务未注册到Nacos"
    elif [ $running_count -gt 0 ]; then
        print_error "❌ 部分服务未启动 (${running_count}/${total_count})"
    else
        print_error "❌ 所有服务都未启动"
    fi
    
    echo ""
}

# 故障诊断和建议
show_diagnosis_and_suggestions() {
    echo -e "${PURPLE}🔍 故障诊断和启动建议${NC}"
    echo "----------------------------------------"
    
    local stopped_services=()
    local unregistered_services=()
    local unhealthy_services=()
    
    # 收集问题服务
    for service_key in "${SERVICE_ORDER[@]}"; do
        local service_info=${SERVICES[$service_key]}
        IFS=':' read -r port nacos_name display_name service_path <<< "$service_info"
        
        if ! check_port $port; then
            stopped_services+=("$service_key:$display_name:$port")
        elif ! check_nacos_registration "$nacos_name"; then
            unregistered_services+=("$service_key:$display_name:$nacos_name")
        elif ! check_service_health $port; then
            unhealthy_services+=("$service_key:$display_name:$port")
        fi
    done
    
    # 显示具体建议
    if [ ${#stopped_services[@]} -gt 0 ]; then
        echo -e "${RED}🚫 未启动的服务:${NC}"
        for service in "${stopped_services[@]}"; do
            IFS=':' read -r key name port <<< "$service"
            echo -e "   • $name (端口:$port)"
            # 正确解析服务路径
            local service_info=${SERVICES[$key]}
            IFS=':' read -r _ _ _ service_path <<< "$service_info"
            echo -e "     ${GRAY}启动命令: cd $service_path && mvn spring-boot:run${NC}"
        done
        echo ""
    fi
    
    if [ ${#unregistered_services[@]} -gt 0 ]; then
        echo -e "${YELLOW}📝 未注册到Nacos的服务:${NC}"
        for service in "${unregistered_services[@]}"; do
            IFS=':' read -r key name nacos_name <<< "$service"
            echo -e "   • $name (Nacos名称:$nacos_name)"
            echo -e "     ${GRAY}检查: 1) Nacos连接配置 2) 服务启动日志${NC}"
        done
        echo ""
    fi
    
    if [ ${#unhealthy_services[@]} -gt 0 ]; then
        echo -e "${YELLOW}🏥 健康检查异常的服务:${NC}"
        for service in "${unhealthy_services[@]}"; do
            IFS=':' read -r key name port <<< "$service"
            echo -e "   • $name (端口:$port)"
            echo -e "     ${GRAY}检查: curl http://localhost:$port/actuator/health${NC}"
        done
        echo ""
    fi
    
    # 启动建议
    if [ ${#stopped_services[@]} -gt 0 ]; then
        echo -e "${CYAN}💡 启动建议:${NC}"
        echo -e "   1. ${YELLOW}自动启动所有服务:${NC} ./start-microservices-ordered.sh"
        echo -e "   2. ${YELLOW}手动启动单个服务:${NC}"
        for service in "${stopped_services[@]}"; do
            IFS=':' read -r key name port <<< "$service"
            # 正确解析服务路径
            local service_info=${SERVICES[$key]}
            IFS=':' read -r _ _ _ service_path <<< "$service_info"
            echo -e "      cd $service_path && mvn spring-boot:run &"
        done
        echo -e "   3. ${YELLOW}检查端口占用:${NC} lsof -i :端口号"
        echo -e "   4. ${YELLOW}查看服务日志:${NC} tail -f logs/服务名.log"
        echo ""
    fi
}

# 显示服务访问信息
show_access_info() {
    echo -e "${PURPLE}🌐 服务访问地址${NC}"
    echo "----------------------------------------"
    echo -e "• ${CYAN}Nacos控制台:${NC} http://localhost:8848/nacos (nacos/nacos)"
    echo -e "• ${CYAN}管理网关:${NC} http://localhost:29100"
    echo -e "• ${CYAN}商城网关:${NC} http://localhost:29110"
    echo ""
    echo -e "${GRAY}微服务直接访问地址:${NC}"
    for service_key in "${SERVICE_ORDER[@]}"; do
        local service_info=${SERVICES[$service_key]}
        IFS=':' read -r port nacos_name display_name service_path <<< "$service_info"
        
        local status_icon="🔴"
        if check_port $port; then
            status_icon="🟢"
        fi
        
        echo -e "• $status_icon ${CYAN}$display_name:${NC} http://localhost:$port"
    done
    echo ""
}

# 显示管理命令
show_management_commands() {
    echo -e "${PURPLE}📋 管理命令${NC}"
    echo "----------------------------------------"
    echo -e "${YELLOW}服务管理:${NC}"
    echo -e "• 启动所有服务: ${CYAN}./start-microservices-ordered.sh${NC}"
    echo -e "• 停止所有服务: ${CYAN}./stop-all-services.sh${NC}"
    echo -e "• 重新检查状态: ${CYAN}./check-microservices-status.sh${NC}"
    echo ""
    echo -e "${YELLOW}日志查看:${NC}"
    echo -e "• 查看所有日志: ${CYAN}tail -f logs/*.log${NC}"
    echo -e "• 查看特定服务: ${CYAN}tail -f logs/服务名.log${NC}"
    echo ""
    echo -e "${YELLOW}故障排除:${NC}"
    echo -e "• 检查端口占用: ${CYAN}lsof -i :端口号${NC}"
    echo -e "• 杀死端口进程: ${CYAN}kill -9 \$(lsof -ti :端口号)${NC}"
    echo -e "• 查看进程信息: ${CYAN}ps aux | grep java${NC}"
    echo -e "• 清理日志文件: ${CYAN}rm -f logs/*.log${NC}"
    echo ""
}

# 主函数
main() {
    print_header
    check_infrastructure
    check_microservices
    show_diagnosis_and_suggestions
    show_access_info
    show_management_commands
    
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${WHITE}检查完成! 如需实时监控，可运行: ${YELLOW}watch -n 5 ./check-microservices-status.sh${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
}

# 支持命令行参数
case "${1:-}" in
    --help|-h)
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  --help, -h     显示帮助信息"
        echo "  --quiet, -q    静默模式，只显示错误"
        echo "  --watch, -w    监控模式，每5秒刷新一次"
        exit 0
        ;;
    --quiet|-q)
        # 静默模式实现
        exec > /dev/null 2>&1
        ;;
    --watch|-w)
        # 监控模式
        while true; do
            main
            sleep 5
        done
        ;;
    *)
        # 默认执行
        main "$@"
        ;;
esac