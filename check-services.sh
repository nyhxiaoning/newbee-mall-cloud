#!/bin/bash

echo "=== 微服务系统状态检查 ==="

# 检查基础服务
echo "1. 检查基础服务状态："
echo "   Nacos (8848):"
curl -s http://localhost:8848/nacos/v1/ns/operator/metrics > /dev/null && echo "   ✅ Nacos 运行正常" || echo "   ❌ Nacos 未启动"

echo "   Redis (6379):"
redis-cli ping > /dev/null 2>&1 && echo "   ✅ Redis 运行正常" || echo "   ❌ Redis 未启动"

echo "   MySQL (3306):"
mysqladmin ping -h localhost -P 3306 > /dev/null 2>&1 && echo "   ✅ MySQL 运行正常" || echo "   ❌ MySQL 未启动"

echo ""
echo "2. 检查微服务注册状态："

# 检查服务注册
services=("newbee-mall-cloud-user-service" "newbee-mall-cloud-goods-service" "newbee-mall-cloud-shop-cart-service" "newbee-mall-cloud-order-service" "newbee-mall-cloud-recommend-service" "newbee-mall-cloud-gateway-mall")

for service in "${services[@]}"; do
    result=$(curl -s "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=$service" | grep -o '"instanceId"' | wc -l)
    if [ "$result" -gt 0 ]; then
        echo "   ✅ $service 已注册"
    else
        echo "   ❌ $service 未注册"
    fi
done

echo ""
echo "3. 检查服务端口状态："
ports=(28080 28081 28082 29040 29050 29110)
port_names=("用户服务" "商品服务" "购物车服务" "订单服务" "推荐服务" "商城网关")

for i in "${!ports[@]}"; do
    port=${ports[$i]}
    name=${port_names[$i]}
    if lsof -i :$port > /dev/null 2>&1; then
        echo "   ✅ $name ($port) 运行中"
    else
        echo "   ❌ $name ($port) 未启动"
    fi
done

echo ""
echo "4. 网关健康检查："
curl -s http://localhost:29110/actuator/health > /dev/null && echo "   ✅ 网关健康检查通过" || echo "   ❌ 网关健康检查失败"