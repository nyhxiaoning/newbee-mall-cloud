package ltd.gateway.cloud.newbee.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * 网关降级处理控制器
 */
@RestController
public class FallbackController {

    @RequestMapping("/fallback")
    public Map<String, Object> fallback() {
        Map<String, Object> result = new HashMap<>();
        result.put("resultCode", 500);
        result.put("message", "服务暂时不可用，请稍后重试");
        result.put("data", null);
        return result;
    }

    @RequestMapping("/user-service-fallback")
    public Map<String, Object> userServiceFallback() {
        Map<String, Object> result = new HashMap<>();
        result.put("resultCode", 500);
        result.put("message", "用户服务暂时不可用，请稍后重试");
        result.put("data", null);
        return result;
    }
}