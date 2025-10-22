# Application Insights Integration for Spring PetClinic on Azure

This guide explains how to integrate Azure Application Insights for monitoring and observability when running Spring PetClinic on Azure App Service.

## Overview

Application Insights provides:
- **Application Performance Monitoring (APM)** - Track response times, dependencies, exceptions
- **Distributed Tracing** - Follow requests across microservices
- **Live Metrics** - Real-time performance monitoring
- **Custom Metrics** - Track business-specific metrics
- **Log Analytics** - Centralized log management

## Integration Approach

We use the **Application Insights Java Agent** (auto-instrumentation) rather than SDK dependencies to avoid compatibility issues with Spring Boot 4.0.0-M3.

### Why Java Agent?

- ✅ **Zero code changes** - No dependencies to add
- ✅ **Automatic instrumentation** - Captures HTTP requests, database calls, exceptions
- ✅ **Spring Boot 4.0 compatible** - Works with milestone releases
- ✅ **Simpler configuration** - Environment variable based

## Setup for Azure App Service

Application Insights is **already configured** in the Azure infrastructure:

### 1. Infrastructure (Bicep)

The `main.bicep` template creates:
- Application Insights resource
- Log Analytics workspace
- Automatic connection string injection into App Service

### 2. Application Configuration

The `application-azure.properties` includes:
```properties
# Application Insights connection string from environment
# APPLICATIONINSIGHTS_CONNECTION_STRING is set by App Service
```

### 3. App Service Configuration

The Bicep template sets the environment variable:
```bicep
{
  name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
  value: appInsights.properties.ConnectionString
}
```

## Using Application Insights Java Agent

### Method 1: Azure App Service (Recommended)

**Already enabled!** Azure App Service has built-in Application Insights support:

1. The agent is pre-installed on App Service
2. Activated via `APPLICATIONINSIGHTS_CONNECTION_STRING` environment variable
3. No additional configuration needed

### Method 2: Local Development with Agent

For local testing with Application Insights:

1. **Download the agent**:
   ```bash
   wget https://github.com/microsoft/ApplicationInsights-Java/releases/download/3.5.0/applicationinsights-agent-3.5.0.jar
   ```

2. **Set connection string**:
   ```bash
   export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=xxx;IngestionEndpoint=https://..."
   ```

3. **Run with agent**:
   ```bash
   java -javaagent:applicationinsights-agent-3.5.0.jar -jar target/*.jar --spring.profiles.active=azure
   ```

### Method 3: Docker with Agent (For Kubernetes/ACI)

If deploying to Kubernetes or Azure Container Instances, add agent to Dockerfile:

```dockerfile
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Download Application Insights agent
ADD https://github.com/microsoft/ApplicationInsights-Java/releases/download/3.5.0/applicationinsights-agent-3.5.0.jar /app/applicationinsights-agent.jar

COPY --from=build /app/target/*.jar app.jar

# Run with agent
ENTRYPOINT ["java", "-javaagent:/app/applicationinsights-agent.jar", "-jar", "app.jar"]
```

## Configuration Options

Create `applicationinsights.json` in the project root for advanced configuration:

```json
{
  "connectionString": "${APPLICATIONINSIGHTS_CONNECTION_STRING}",
  "role": {
    "name": "spring-petclinic"
  },
  "instrumentation": {
    "logging": {
      "level": "INFO"
    },
    "micrometer": {
      "enabled": true
    }
  },
  "preview": {
    "sampling": {
      "percentage": 100
    }
  }
}
```

## Monitoring in Azure Portal

Once deployed, view telemetry in Azure Portal:

1. **Application Insights resource** → Overview
2. **Application Map** - Visualize dependencies
3. **Performance** - Track response times
4. **Failures** - View exceptions and failed requests
5. **Metrics** - Custom and standard metrics
6. **Logs** - Query with KQL (Kusto Query Language)

### Sample Queries

**Top 10 slowest requests**:
```kusto
requests
| where timestamp > ago(1h)
| summarize avg(duration) by name
| top 10 by avg_duration desc
```

**Exception count by type**:
```kusto
exceptions
| where timestamp > ago(24h)
| summarize count() by type
| order by count_ desc
```

**Database dependency performance**:
```kusto
dependencies
| where type == "SQL"
| summarize avg(duration), count() by name
| order by avg_duration desc
```

## Health Checks Integration

The application exposes Spring Boot Actuator health endpoints that App Service uses:

- **Liveness probe**: `/actuator/health/liveness`
- **Readiness probe**: `/actuator/health/readiness`
- **Overall health**: `/actuator/health`

These are automatically monitored by Application Insights and appear in the availability metrics.

## Custom Metrics (Optional)

To add custom metrics to Application Insights:

```java
import io.micrometer.core.instrument.MeterRegistry;

@RestController
public class OwnerController {
    private final MeterRegistry meterRegistry;
    
    public OwnerController(OwnerRepository owners, MeterRegistry meterRegistry) {
        this.owners = owners;
        this.meterRegistry = meterRegistry;
    }
    
    @GetMapping("/owners/find")
    public String initFindForm(Map<String, Object> model) {
        meterRegistry.counter("petclinic.owner.search").increment();
        // ... rest of method
    }
}
```

The metrics automatically flow to Application Insights via Micrometer integration.

## Troubleshooting

### Agent Not Starting

**Check logs** for Application Insights startup:
```bash
az webapp log tail --name <app-name> --resource-group <rg-name>
```

Look for:
```
[ApplicationInsights] Application Insights Java Agent 3.5.0
[ApplicationInsights] Connection string: InstrumentationKey=...
```

### No Telemetry in Portal

1. **Verify connection string** is set:
   ```bash
   az webapp config appsettings list --name <app-name> --resource-group <rg-name> | grep APPLICATIONINSIGHTS
   ```

2. **Check sampling** - Reduce if set too low in `applicationinsights.json`

3. **Wait 2-5 minutes** - Telemetry has slight delay

### Performance Impact

The Java agent has minimal overhead (~2-3% CPU):
- Uses async processing
- Batches telemetry
- Configurable sampling

To reduce further, lower sampling percentage in config.

## Cost Optimization

Application Insights pricing based on data ingestion:

- **First 5 GB/month**: Free
- **After 5 GB**: ~$2.30 per GB

**Typical PetClinic usage**: 100-500 MB/month (well within free tier)

**Optimization tips**:
1. Use sampling (default 100% is fine for dev)
2. Filter verbose logs
3. Exclude health check endpoints from telemetry (if very frequent)

## References

- [Application Insights Java Agent Documentation](https://learn.microsoft.com/azure/azure-monitor/app/java-in-process-agent)
- [Spring Boot Integration](https://learn.microsoft.com/azure/azure-monitor/app/java-spring-boot)
- [App Service Application Insights](https://learn.microsoft.com/azure/app-service/overview-monitoring)

## Next Steps

After deployment:
1. ✅ Telemetry automatically flows to Application Insights
2. 🔍 Explore Application Map to see dependencies
3. 📊 Create custom dashboards for key metrics
4. 🚨 Set up alerts for failures or performance issues
5. 📈 Use Live Metrics during deployments
