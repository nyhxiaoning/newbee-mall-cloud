#!/bin/bash

# 新蜂商城微服务系统 - 串行启动脚本
# 作者: AI助手
# 功能: 按照依赖顺序串行启动所有微服务，确保正确注册到Nacos

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT=$(pwd)
LOG_DIR="$PROJECT_ROOT/logs"
PID_FILE="$PROJECT_ROOT/.service_pids"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 清空PID文件
> "$PID_FILE"

# 服务配置数组
declare -A SERVICES=(
    ["user"]="用户服务:newbee-mall-cloud-user-service/newbee-mall-cloud-user-web:29000:newbee-mall-cloud-user-service"
    ["goods"]="商品服务:newbee-mall-cloud-goods-service/newbee-mall-cloud-goods-web:29010:newbee-mall-cloud-goods-service"
    ["recommend"]="推荐服务:newbee-mall-cloud-recommend-service/newbee-mall-cloud-recommend-web:29020:newbee-mall-cloud-recommend-service"
    ["shop-cart"]="购物车服务:newbee-mall-cloud-shop-cart-service/newbee-mall-cloud-shop-cart-web:29030:newbee-mall-cloud-shop-cart-service"
    ["order"]="订单服务:newbee-mall-cloud-order-service/newbee-mall-cloud-order-web:29040:newbee-mall-cloud-order-service"
    ["gateway-mall"]="商城网关:newbee-mall-cloud-gateway-mall:29110:newbee-mall-cloud-gateway-mall"
)

# 启动顺序
SERVICE_ORDER=("user" "goods" "recommend" "shop-cart" "order" "gateway-mall")

# 打印标题
print_header() {
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}                    新蜂商城微服务系统 - 串行启动脚本                        ${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${BLUE}启动时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}项目路径: $PROJECT_ROOT${NC}"
    echo -e "${BLUE}日志目录: $LOG_DIR${NC}"
    echo ""
}

# 检查基础环境
check_infrastructure() {
    echo -e "${YELLOW}🔍 检查基础环境...${NC}"
    
    # 检查Java环境
    if ! command -v java &> /dev/null; then
        echo -e "${RED}❌ Java未安装或未配置到PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Java环境: $(java -version 2>&1 | head -n 1)${NC}"
    
    # 检查Maven环境
    if ! command -v mvn &> /dev/null; then
        echo -e "${RED}❌ Maven未安装或未配置到PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Maven环境: $(mvn -version | head -n 1)${NC}"
    
    # 检查Nacos服务
    echo -e "${YELLOW}🔍 检查Nacos服务...${NC}"
    if curl -s http://localhost:8848/nacos/v1/ns/operator/metrics > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Nacos服务正常运行 (http://localhost:8848)${NC}"
    else
        echo -e "${RED}❌ Nacos服务未启动或无法访问${NC}"
        echo -e "${YELLOW}💡 请先启动Nacos服务:${NC}"
        echo -e "   docker run -d --name nacos-standalone -e MODE=standalone -p 8848:8848 nacos/nacos-server:v2.3.2"
        exit 1
    fi
    
    # 检查Redis服务
    echo -e "${YELLOW}🔍 检查Redis服务...${NC}"
    if command -v redis-cli &> /dev/null && redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis服务正常运行${NC}"
    else
        echo -e "${YELLOW}⚠️  Redis服务未检测到，某些功能可能受影响${NC}"
    fi
    
    echo ""
}

# 编译公共模块
build_common_module() {
    echo -e "${YELLOW}🔨 编译公共模块...${NC}"
    
    cd "$PROJECT_ROOT"
    
    # 安装父项目
    echo -e "${BLUE}📦 安装父项目到本地Maven仓库...${NC}"
    if mvn clean install -N > "$LOG_DIR/parent-install.log" 2>&1; then
        echo -e "${GREEN}✅ 父项目安装成功${NC}"
    else
        echo -e "${RED}❌ 父项目安装失败${NC}"
        echo -e "${YELLOW}💡 查看日志: tail -f $LOG_DIR/parent-install.log${NC}"
        exit 1
    fi
    
    # 编译公共模块
    echo -e "${BLUE}📦 编译公共模块...${NC}"
    cd "$PROJECT_ROOT/newbee-mall-cloud-common"
    if mvn clean install > "$LOG_DIR/common-build.log" 2>&1; then
        echo -e "${GREEN}✅ 公共模块编译成功${NC}"
    else
        echo -e "${RED}❌ 公共模块编译失败${NC}"
        echo -e "${YELLOW}💡 查看日志: tail -f $LOG_DIR/common-build.log${NC}"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    echo ""
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 等待服务启动
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_wait=120  # 最大等待时间（秒）
    local wait_time=0
    
    echo -e "${YELLOW}⏳ 等待 $service_name 启动 (端口:$port)...${NC}"
    
    while [ $wait_time -lt $max_wait ]; do
        if check_port $port; then
            echo -e "${GREEN}✅ $service_name 启动成功 (用时:${wait_time}秒)${NC}"
            return 0
        fi
        sleep 2
        wait_time=$((wait_time + 2))
        echo -ne "${BLUE}⏳ 等待中... ${wait_time}/${max_wait}秒\r${NC}"
    done
    
    echo -e "\n${RED}❌ $service_name 启动超时${NC}"
    return 1
}

# 检查Nacos注册状态
check_nacos_registration() {
    local nacos_name=$1
    local service_name=$2
    local max_wait=60
    local wait_time=0
    
    echo -e "${YELLOW}🔍 检查 $service_name 在Nacos中的注册状态...${NC}"
    
    while [ $wait_time -lt $max_wait ]; do
        local response=$(curl -s "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=$nacos_name" 2>/dev/null)
        if echo "$response" | grep -q '"hosts":\[' && ! echo "$response" | grep -q '"hosts":\[\]'; then
            echo -e "${GREEN}✅ $service_name 已成功注册到Nacos${NC}"
            return 0
        fi
        sleep 3
        wait_time=$((wait_time + 3))
        echo -ne "${BLUE}🔍 检查注册状态... ${wait_time}/${max_wait}秒\r${NC}"
    done
    
    echo -e "\n${YELLOW}⚠️  $service_name 注册到Nacos超时，但服务可能正在注册中${NC}"
    return 1
}

# 启动单个服务
start_service() {
    local service_key=$1
    local service_info=${SERVICES[$service_key]}
    
    IFS=':' read -r service_name service_path service_port nacos_name <<< "$service_info"
    
    echo -e "${CYAN}🚀 启动 $service_name...${NC}"
    echo -e "${BLUE}   路径: $service_path${NC}"
    echo -e "${BLUE}   端口: $service_port${NC}"
    echo -e "${BLUE}   Nacos名称: $nacos_name${NC}"
    
    # 检查端口是否被占用
    if check_port $service_port; then
        echo -e "${YELLOW}⚠️  端口 $service_port 已被占用，尝试停止现有进程...${NC}"
        local pid=$(lsof -ti :$service_port)
        if [ ! -z "$pid" ]; then
            kill -9 $pid 2>/dev/null
            sleep 2
        fi
    fi
    
    # 进入服务目录
    local full_path="$PROJECT_ROOT/$service_path"
    if [ ! -d "$full_path" ]; then
        echo -e "${RED}❌ 服务目录不存在: $full_path${NC}"
        return 1
    fi
    
    cd "$full_path"
    
    # 创建日志文件
    local log_file="$LOG_DIR/${service_name}.log"
    touch "$log_file"
    
    # 启动服务
    echo -e "${BLUE}📦 启动命令: mvn spring-boot:run${NC}"
    nohup mvn spring-boot:run > "$log_file" 2>&1 &
    local service_pid=$!
    
    # 记录PID
    echo "$service_key:$service_pid:$service_name:$service_port" >> "$PID_FILE"
    
    # 返回项目根目录
    cd "$PROJECT_ROOT"
    
    # 等待服务启动
    if wait_for_service $service_port "$service_name"; then
        # 检查Nacos注册
        check_nacos_registration "$nacos_name" "$service_name"
        echo -e "${GREEN}✅ $service_name 启动完成${NC}"
        echo -e "${BLUE}💡 日志文件: tail -f $log_file${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ $service_name 启动失败${NC}"
        echo -e "${YELLOW}💡 故障排除建议:${NC}"
        echo -e "   1. 查看日志: tail -f $log_file"
        echo -e "   2. 检查端口占用: lsof -i :$service_port"
        echo -e "   3. 检查数据库连接配置"
        echo -e "   4. 检查Nacos连接配置"
        echo ""
        return 1
    fi
}

# 启动所有服务
start_all_services() {
    echo -e "${YELLOW}🚀 开始串行启动所有微服务...${NC}"
    echo ""
    
    local failed_services=()
    
    for service_key in "${SERVICE_ORDER[@]}"; do
        if ! start_service "$service_key"; then
            failed_services+=("$service_key")
        fi
        
        # 服务间启动间隔
        if [ "$service_key" != "${SERVICE_ORDER[-1]}" ]; then
            echo -e "${BLUE}⏳ 等待5秒后启动下一个服务...${NC}"
            sleep 5
        fi
    done
    
    # 报告启动结果
    if [ ${#failed_services[@]} -eq 0 ]; then
        echo -e "${GREEN}🎉 所有微服务启动成功！${NC}"
    else
        echo -e "${YELLOW}⚠️  部分服务启动失败:${NC}"
        for service_key in "${failed_services[@]}"; do
            local service_info=${SERVICES[$service_key]}
            IFS=':' read -r service_name service_path service_port nacos_name <<< "$service_info"
            echo -e "${RED}   ❌ $service_name${NC}"
        done
    fi
    echo ""
}

# 验证所有服务注册状态
verify_all_registrations() {
    echo -e "${YELLOW}🔍 验证所有服务的Nacos注册状态...${NC}"
    echo ""
    
    local registered_count=0
    local total_count=${#SERVICES[@]}
    
    for service_key in "${!SERVICES[@]}"; do
        local service_info=${SERVICES[$service_key]}
        IFS=':' read -r service_name service_path service_port nacos_name <<< "$service_info"
        
        local response=$(curl -s "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=$nacos_name" 2>/dev/null)
        if echo "$response" | grep -q '"hosts":\[' && ! echo "$response" | grep -q '"hosts":\[\]'; then
            echo -e "${GREEN}✅ $service_name - 已注册${NC}"
            registered_count=$((registered_count + 1))
        else
            echo -e "${RED}❌ $service_name - 未注册${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}📊 注册统计: $registered_count/$total_count 个服务已注册到Nacos${NC}"
    echo ""
}

# 显示访问信息
show_access_info() {
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}                              🌐 访问信息                                   ${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo ""
    echo -e "${GREEN}🎯 主要访问地址:${NC}"
    echo -e "   • Nacos控制台: ${BLUE}http://localhost:8848/nacos${NC} (nacos/nacos)"
    echo -e "   • 商城网关:    ${BLUE}http://localhost:29110${NC}"
    echo ""
    echo -e "${GREEN}🔧 服务管理:${NC}"
    echo -e "   • 查看服务状态: ${YELLOW}./check-microservices-status.sh${NC}"
    echo -e "   • 停止所有服务: ${YELLOW}./stop-all-services.sh${NC}"
    echo -e "   • 查看服务日志: ${YELLOW}tail -f logs/服务名.log${NC}"
    echo ""
    echo -e "${GREEN}📋 服务端口列表:${NC}"
    for service_key in "${SERVICE_ORDER[@]}"; do
        local service_info=${SERVICES[$service_key]}
        IFS=':' read -r service_name service_path service_port nacos_name <<< "$service_info"
        echo -e "   • $service_name: ${BLUE}http://localhost:$service_port${NC}"
    done
    echo ""
    echo -e "${CYAN}=============================================================================${NC}"
}

# 主函数
main() {
    # 检查是否在项目根目录
    if [ ! -f "pom.xml" ]; then
        echo -e "${RED}❌ 请在项目根目录运行此脚本${NC}"
        exit 1
    fi
    
    print_header
    check_infrastructure
    build_common_module
    start_all_services
    verify_all_registrations
    show_access_info
}

# 执行主函数
main "$@"