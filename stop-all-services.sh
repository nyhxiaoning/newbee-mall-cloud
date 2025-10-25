#!/bin/bash

echo "=== 停止新蜂商城微服务系统 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 从文件读取 PID
if [ -f .service_pids ]; then
    read -r USER_PID GOODS_PID CART_PID ORDER_PID RECOMMEND_PID GATEWAY_PID < .service_pids
    
    echo "停止服务进程..."
    
    services=("用户服务:$USER_PID" "商品服务:$GOODS_PID" "购物车服务:$CART_PID" "订单服务:$ORDER_PID" "推荐服务:$RECOMMEND_PID" "商城网关:$GATEWAY_PID")
    
    for service in "${services[@]}"; do
        IFS=':' read -r name pid <<< "$service"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo -e "${GREEN}✅ $name ($pid) 已停止${NC}"
        else
            echo -e "${YELLOW}⚠️  $name 进程不存在${NC}"
        fi
    done
    
    rm -f .service_pids
else
    echo -e "${YELLOW}未找到服务 PID 文件，尝试按端口停止...${NC}"
    
    ports=(28080 28081 28082 29040 29050 29110)
    names=("用户服务" "商品服务" "购物车服务" "订单服务" "推荐服务" "商城网关")
    
    for i in "${!ports[@]}"; do
        port=${ports[$i]}
        name=${names[$i]}
        pid=$(lsof -ti :$port)
        if [ -n "$pid" ]; then
            kill "$pid"
            echo -e "${GREEN}✅ $name (端口 $port) 已停止${NC}"
        else
            echo -e "${YELLOW}⚠️  $name (端口 $port) 未运行${NC}"
        fi
    done
fi

echo -e "${GREEN}=== 所有服务已停止 ===${NC}"