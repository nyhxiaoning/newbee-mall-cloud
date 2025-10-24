package ltd.goods.cloud.newbee.config;

import com.alibaba.druid.pool.DruidDataSource;
import io.seata.rm.datasource.DataSourceProxy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;

/**
 * Seata 配置类
 * 优雅地处理 Seata 分布式事务配置
 * 
 * @author 程序员十三
 */
@Configuration
@ConditionalOnProperty(name = "seata.enabled", havingValue = "true", matchIfMissing = false)
public class SeataConfiguration {

    private static final Logger logger = LoggerFactory.getLogger(SeataConfiguration.class);

    /**
     * 创建 Druid 数据源
     */
    @Bean
    @ConfigurationProperties(prefix = "spring.datasource")
    public DataSource druidDataSource() {
        DruidDataSource druidDataSource = new DruidDataSource();
        logger.info("[Seata Configuration] 创建 Druid 数据源");
        return druidDataSource;
    }

    /**
     * 创建 Seata 数据源代理
     * 用于分布式事务管理
     */
    @Bean
    @Primary
    public DataSourceProxy dataSourceProxy(DataSource druidDataSource) {
        DataSourceProxy dataSourceProxy = new DataSourceProxy(druidDataSource);
        logger.info("[Seata Configuration] 创建 Seata 数据源代理，启用分布式事务支持");
        return dataSourceProxy;
    }
}