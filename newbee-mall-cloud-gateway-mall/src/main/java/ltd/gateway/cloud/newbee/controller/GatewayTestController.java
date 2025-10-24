package ltd.gateway.cloud.newbee.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 网关测试控制器
 * 用于检查网关状态和服务注册情况
 */
@RestController
@RequestMapping("/gateway")
public class GatewayTestController {

    @Autowired
    private DiscoveryClient discoveryClient;

    @Autowired
    private RouteLocator routeLocator;

    /**
     * 网关健康检查
     */
    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> result = new HashMap<>();
        result.put("status", "UP");
        result.put("gateway", "newbee-mall-cloud-gateway-mall");
        result.put("timestamp", System.currentTimeMillis());
        return result;
    }

    /**
     * 获取已注册的服务列表
     */
    @GetMapping("/services")
    public Map<String, Object> getServices() {
        Map<String, Object> result = new HashMap<>();
        List<String> services = discoveryClient.getServices();
        result.put("services", services);
        result.put("count", services.size());
        
        // 检查关键服务
        Map<String, Boolean> serviceStatus = new HashMap<>();
        serviceStatus.put("user-service", services.contains("newbee-mall-cloud-user-service"));
        serviceStatus.put("goods-service", services.contains("newbee-mall-cloud-goods-service"));
        serviceStatus.put("shop-cart-service", services.contains("newbee-mall-cloud-shop-cart-service"));
        serviceStatus.put("order-service", services.contains("newbee-mall-cloud-order-service"));
        serviceStatus.put("recommend-service", services.contains("newbee-mall-cloud-recommend-service"));
        
        result.put("serviceStatus", serviceStatus);
        return result;
    }

    /**
     * 获取网关路由信息
     */
    @GetMapping("/routes")
    public Map<String, Object> getRoutes() {
        Map<String, Object> result = new HashMap<>();
        
        routeLocator.getRoutes().collectList().subscribe(routes -> {
            result.put("routes", routes);
            result.put("count", routes.size());
        });
        
        return result;
    }

    /**
     * 测试各个服务的连通性
     */
    @GetMapping("/test-connectivity")
    public Map<String, Object> testConnectivity() {
        Map<String, Object> result = new HashMap<>();
        Map<String, String> testResults = new HashMap<>();
        
        // 这里可以添加对各个服务的简单连通性测试
        testResults.put("user-service", "需要实现具体测试逻辑");
        testResults.put("goods-service", "需要实现具体测试逻辑");
        testResults.put("shop-cart-service", "需要实现具体测试逻辑");
        testResults.put("order-service", "需要实现具体测试逻辑");
        testResults.put("recommend-service", "需要实现具体测试逻辑");
        
        result.put("testResults", testResults);
        result.put("timestamp", System.currentTimeMillis());
        
        return result;
    }
}