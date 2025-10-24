#!/bin/bash

# Goods Service 启动脚本
# 解决 Seata 与 Java 11+ 模块系统的兼容性问题

echo "正在启动 Goods Service..."

# 设置 JVM 参数以解决模块访问问题
export MAVEN_OPTS="--add-opens java.base/java.lang=ALL-UNNAMED \
--add-opens java.base/java.util=ALL-UNNAMED \
--add-opens java.base/java.lang.reflect=ALL-UNNAMED \
--add-opens java.base/java.text=ALL-UNNAMED \
--add-opens java.desktop/java.awt.font=ALL-UNNAMED \
--add-opens java.base/sun.nio.ch=ALL-UNNAMED \
--add-opens java.base/java.nio=ALL-UNNAMED"

echo "JVM 参数已设置: $MAVEN_OPTS"

# 启动服务
mvn spring-boot:run

echo "Goods Service 启动完成"