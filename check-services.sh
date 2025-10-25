#!/bin/bash

# =============================================================================
# 微服务系统状态检查脚本 (优化版)
# 检查所有微服务的运行状态，忽略MySQL检测
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 服务配置
declare -A SERVICES=(
    ["用户服务"]="29000:newbee-mall-cloud-user-service"
    ["商品服务"]="29010:newbee-mall-cloud-goods-service"
    ["购物车服务"]="29030:newbee-mall-cloud-shop-cart-service"
    ["订单服务"]="29040:newbee-mall-cloud-order-service"
    ["推荐服务"]="29020:newbee-mall-cloud-recommend-service"
    ["商城网关"]="29110:newbee-mall-cloud-gateway-mall"
    ["管理网关"]="29120:newbee-mall-cloud-gateway-admin"
)

# 基础服务配置
NACOS_PORT=8848
REDIS_PORT=6379

print_header() {
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}                        微服务系统状态检查${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_section() {
    echo -e "${BLUE}📋 $1${NC}"
    echo ""
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :$port > /dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an | grep ":$port " > /dev/null 2>&1
    else
        # 使用nc作为备选方案
        nc -z localhost $port > /dev/null 2>&1
    fi
}

# 检查HTTP服务响应
check_http_service() {
    local url=$1
    local timeout=${2:-5}
    curl -s --connect-timeout $timeout --max-time $timeout "$url" > /dev/null 2>&1
}

# 检查Nacos服务
check_nacos() {
    print_section "1. 基础服务状态检查"
    
    echo -n "   Nacos (端口 $NACOS_PORT): "
    if check_port $NACOS_PORT; then
        if check_http_service "http://localhost:$NACOS_PORT/nacos/v1/ns/operator/metrics"; then
            print_success "运行正常"
            return 0
        else
            print_warning "端口开放但服务异常"
            return 1
        fi
    else
        print_error "未启动"
        return 1
    fi
}

# 检查Redis服务
check_redis() {
    echo -n "   Redis (端口 $REDIS_PORT): "
    if check_port $REDIS_PORT; then
        if command -v redis-cli >/dev/null 2>&1; then
            if redis-cli ping > /dev/null 2>&1; then
                print_success "运行正常"
                return 0
            else
                print_warning "端口开放但连接失败"
                return 1
            fi
        else
            print_warning "端口开放 (无redis-cli工具验证)"
            return 0
        fi
    else
        print_error "未启动"
        return 1
    fi
}

# 检查服务注册状态
check_service_registration() {
    print_section "2. 微服务注册状态检查"
    
    local nacos_available=false
    if check_http_service "http://localhost:$NACOS_PORT/nacos/v1/ns/operator/metrics"; then
        nacos_available=true
    fi
    
    if [ "$nacos_available" = false ]; then
        print_error "Nacos 不可用，无法检查服务注册状态"
        return 1
    fi
    
    local registered_count=0
    local total_count=0
    
    for service_name in "${!SERVICES[@]}"; do
        local service_info=${SERVICES[$service_name]}
        local nacos_name=${service_info#*:}
        
        echo -n "   $service_name: "
        
        local result=$(curl -s "http://localhost:$NACOS_PORT/nacos/v1/ns/instance/list?serviceName=$nacos_name" 2>/dev/null)
        if echo "$result" | grep -q '"instanceId"'; then
            local instance_count=$(echo "$result" | grep -o '"instanceId"' | wc -l | tr -d ' ')
            print_success "已注册 ($instance_count 个实例)"
            ((registered_count++))
        else
            print_error "未注册"
        fi
        ((total_count++))
    done
    
    echo ""
    echo -e "   ${CYAN}注册统计: $registered_count/$total_count 个服务已注册${NC}"
}

# 检查服务端口状态
check_service_ports() {
    print_section "3. 微服务端口状态检查"
    
    local running_count=0
    local total_count=0
    
    for service_name in "${!SERVICES[@]}"; do
        local service_info=${SERVICES[$service_name]}
        local port=${service_info%:*}
        
        echo -n "   $service_name (端口 $port): "
        
        if check_port $port; then
            print_success "运行中"
            ((running_count++))
        else
            print_error "未启动"
        fi
        ((total_count++))
    done
    
    echo ""
    echo -e "   ${CYAN}端口统计: $running_count/$total_count 个服务端口开放${NC}"
}

# 检查服务健康状态
check_service_health() {
    print_section "4. 微服务健康状态检查"
    
    local healthy_count=0
    local total_count=0
    
    # 检查网关健康状态
    for service_name in "${!SERVICES[@]}"; do
        if [[ $service_name == *"网关"* ]]; then
            local service_info=${SERVICES[$service_name]}
            local port=${service_info%:*}
            
            echo -n "   $service_name 健康检查: "
            
            if check_http_service "http://localhost:$port/actuator/health"; then
                print_success "通过"
                ((healthy_count++))
            else
                print_error "失败"
            fi
            ((total_count++))
        fi
    done
    
    # 检查其他服务的基本响应
    for service_name in "${!SERVICES[@]}"; do
        if [[ $service_name != *"网关"* ]]; then
            local service_info=${SERVICES[$service_name]}
            local port=${service_info%:*}
            
            echo -n "   $service_name 响应检查: "
            
            # 尝试检查actuator/health端点
            if check_http_service "http://localhost:$port/actuator/health"; then
                print_success "响应正常"
                ((healthy_count++))
            else
                # 如果health端点不可用，检查基本连接
                if check_port $port; then
                    print_warning "端口开放但健康检查失败"
                else
                    print_error "服务不可达"
                fi
            fi
            ((total_count++))
        fi
    done
    
    echo ""
    echo -e "   ${CYAN}健康统计: $healthy_count/$total_count 个服务健康检查通过${NC}"
}

# 显示系统概览
show_system_overview() {
    print_section "5. 系统概览"
    
    local total_services=${#SERVICES[@]}
    local running_services=0
    local registered_services=0
    
    # 统计运行中的服务
    for service_name in "${!SERVICES[@]}"; do
        local service_info=${SERVICES[$service_name]}
        local port=${service_info%:*}
        
        if check_port $port; then
            ((running_services++))
        fi
    done
    
    # 统计注册的服务
    if check_http_service "http://localhost:$NACOS_PORT/nacos/v1/ns/operator/metrics"; then
        for service_name in "${!SERVICES[@]}"; do
            local service_info=${SERVICES[$service_name]}
            local nacos_name=${service_info#*:}
            
            local result=$(curl -s "http://localhost:$NACOS_PORT/nacos/v1/ns/instance/list?serviceName=$nacos_name" 2>/dev/null)
            if echo "$result" | grep -q '"instanceId"'; then
                ((registered_services++))
            fi
        done
    fi
    
    echo "   📊 服务统计:"
    echo "      - 总服务数: $total_services"
    echo "      - 运行中: $running_services"
    echo "      - 已注册: $registered_services"
    echo ""
    
    # 系统状态评估
    if [ $running_services -eq $total_services ] && [ $registered_services -eq $total_services ]; then
        echo -e "   ${GREEN}🎉 系统状态: 优秀 (所有服务正常运行)${NC}"
    elif [ $running_services -gt $((total_services * 2 / 3)) ]; then
        echo -e "   ${YELLOW}⚠️  系统状态: 良好 (大部分服务正常)${NC}"
    else
        echo -e "   ${RED}❌ 系统状态: 异常 (多个服务未启动)${NC}"
    fi
    
    echo ""
    echo -e "   ${CYAN}🔗 访问地址:${NC}"
    echo "      - 商城前端: http://localhost:29110"
    echo "      - 管理后台: http://localhost:29120"
    echo "      - Nacos控制台: http://localhost:8848/nacos"
}

# 显示帮助信息
show_help() {
    echo ""
    echo -e "${YELLOW}💡 使用提示:${NC}"
    echo "   - 如果服务未启动，请使用 ./start-services-ordered.sh 启动"
    echo "   - 如果服务注册失败，请检查 Nacos 配置"
    echo "   - 如果健康检查失败，请查看服务日志"
    echo "   - 使用 ./service-manager.sh 进行服务管理"
}

# 主函数
main() {
    print_header
    
    # 检查基础服务
    check_nacos
    check_redis
    echo ""
    
    # 检查微服务
    check_service_registration
    echo ""
    check_service_ports
    echo ""
    check_service_health
    echo ""
    
    # 显示系统概览
    show_system_overview
    
    # 显示帮助信息
    show_help
    
    echo ""
    echo -e "${CYAN}=============================================================================${NC}"
}

# 执行主函数
main "$@"