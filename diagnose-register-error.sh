#!/bin/bash

echo "=== 用户注册接口 500 错误诊断 ==="

# 检查基础服务状态
echo "1. 检查基础服务状态..."

# 检查 MySQL
echo "检查 MySQL 连接..."
mysql -h127.0.0.1 -P3306 -uroot -pnyh123 -e "SELECT 1;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ MySQL 连接正常"
else
    echo "❌ MySQL 连接失败"
fi

# 检查 Redis
echo "检查 Redis 连接..."
redis-cli -h 127.0.0.1 -p 6379 -a 123456 ping 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Redis 连接正常"
else
    echo "❌ Redis 连接失败"
fi

# 检查 Nacos
echo "检查 Nacos 状态..."
curl -s http://127.0.0.1:8848/nacos/v1/ns/operator/servers >/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Nacos 服务正常"
else
    echo "❌ Nacos 服务异常"
fi

echo -e "\n2. 检查数据库表结构..."
mysql -h127.0.0.1 -P3306 -uroot -pnyh123 -e "USE newbee_mall_cloud_user_db; DESCRIBE tb_newbee_mall_user;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ 用户表结构正常"
else
    echo "❌ 用户表不存在或结构异常"
fi

echo -e "\n3. 检查用户服务状态..."
USER_SERVICE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:29000/actuator/health 2>/dev/null)
if [ "$USER_SERVICE_STATUS" = "200" ]; then
    echo "✅ 用户服务运行正常"
else
    echo "❌ 用户服务异常，状态码: $USER_SERVICE_STATUS"
fi

echo -e "\n4. 检查网关路由..."
GATEWAY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:29110/actuator/health 2>/dev/null)
if [ "$GATEWAY_STATUS" = "200" ]; then
    echo "✅ 网关服务运行正常"
else
    echo "❌ 网关服务异常，状态码: $GATEWAY_STATUS"
fi

echo -e "\n5. 测试直连用户服务注册接口..."
DIRECT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "http://localhost:29000/users/mall/register" \
  -H "Content-Type: application/json" \
  -d '{
    "loginName": "13800138000",
    "password": "123456"
  }')

echo "直连用户服务响应:"
echo "$DIRECT_RESPONSE"

echo -e "\n6. 测试通过网关注册接口..."
GATEWAY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "http://localhost:29110/api/users/mall/register" \
  -H "Content-Type: application/json" \
  -d '{
    "loginName": "13800138001",
    "password": "123456"
  }')

echo "通过网关响应:"
echo "$GATEWAY_RESPONSE"

echo -e "\n7. 检查用户服务日志（最近 20 行）..."
if [ -f "user-service.log" ]; then
    tail -20 user-service.log
else
    echo "未找到用户服务日志文件"
fi

echo -e "\n=== 诊断完成 ==="