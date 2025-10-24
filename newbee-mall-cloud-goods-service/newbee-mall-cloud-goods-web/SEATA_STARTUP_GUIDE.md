# Seata 分布式事务启动指南

## 概述

本指南提供了一个优雅的解决方案来启用 Seata 分布式事务功能，解决了 Seata 与 Java 11+ 模块系统的兼容性问题。

## 解决方案特点

✅ **条件化配置**: 通过 `seata.enabled` 属性控制 Seata 功能的启用/禁用  
✅ **优雅降级**: 当 Seata 不可用时，服务仍可正常运行  
✅ **模块兼容**: 解决了 Java 11+ 模块系统访问限制问题  
✅ **配置分离**: Seata 配置独立管理，便于维护  

## 启动方式

### 方式一：使用 Maven 插件启动（推荐）

```bash
# 直接启动，已配置 JVM 参数
mvn spring-boot:run
```

### 方式二：使用启动脚本

```bash
# 使用提供的启动脚本
chmod +x start-goods-service.sh
./start-goods-service.sh
```

### 方式三：激活 Seata 配置文件

```bash
# 使用 Seata 专用配置文件
mvn spring-boot:run -Dspring.profiles.active=seata
```

## 配置说明

### 1. 主配置文件 (application.properties)
```properties
# 启用/禁用 Seata
seata.enabled=true
```

### 2. Seata 专用配置 (application-seata.yml)
包含完整的 Seata 注册中心、配置中心等设置。

### 3. 条件化组件
- `SeataConfiguration`: 条件化数据源代理配置
- `GoodsServiceWebMvcConfigurer`: 条件化拦截器注册
- `NewBeeAdminGoodsInfoController`: 安全的事务 ID 获取

## 故障排除

### 问题：InaccessibleObjectException
**解决方案**: 已在 `pom.xml` 中配置 JVM 参数，无需手动设置。

### 问题：Seata 服务器连接失败
**解决方案**: 
1. 确保 Seata 服务器已启动
2. 检查 Nacos 注册中心配置
3. 验证网络连接

### 问题：数据源代理创建失败
**解决方案**: 
1. 检查数据库连接配置
2. 确保 `undo_log` 表已创建
3. 验证数据库权限

## 监控与日志

### 查看 Seata 状态
```bash
# 查看应用日志中的 Seata 相关信息
tail -f logs/application.log | grep -i seata
```

### 事务监控
- 全局事务 ID 会在日志中输出
- 可通过 Seata 控制台查看事务状态

## 最佳实践

1. **开发环境**: 可设置 `seata.enabled=false` 进行本地开发
2. **测试环境**: 启用 Seata 进行集成测试
3. **生产环境**: 确保 Seata 服务器高可用部署

## 相关文件

- `SeataConfiguration.java`: 主要配置类
- `application-seata.yml`: Seata 专用配置
- `start-goods-service.sh`: 启动脚本
- `pom.xml`: Maven 构建配置（包含 JVM 参数）