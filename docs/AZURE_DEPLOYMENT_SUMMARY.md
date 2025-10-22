# Azure Deployment Summary - Spring PetClinic

## 🎯 Deployment Overview

This document summarizes the Azure deployment setup for Spring PetClinic, including all created resources, configuration, and deployment workflow.

## 📦 Created Resources

### Infrastructure (via Bicep)

| Resource | Type | Purpose |
|----------|------|---------|
| App Service Plan | `Microsoft.Web/serverfarms` | B1 Linux plan for hosting |
| Web App | `Microsoft.Web/sites` | Container-based Java app hosting |
| PostgreSQL Server | `Microsoft.DBforPostgreSQL/flexibleServers` | Managed database (Standard_B1ms) |
| PostgreSQL Database | `Microsoft.DBforPostgreSQL/flexibleServers/databases` | `petclinic` database |
| Container Registry | `Microsoft.ContainerRegistry/registries` | Docker image storage (Basic SKU) |
| Application Insights | `Microsoft.Insights/components` | APM and monitoring |
| Log Analytics | `Microsoft.OperationalInsights/workspaces` | Centralized logging |

**Estimated Monthly Cost**: ~$30-50 USD (Dev environment)
- App Service B1: ~$13/month
- PostgreSQL B1ms: ~$12/month
- ACR Basic: ~$5/month
- Application Insights: Free tier (first 5GB)

### Application Files

| File | Purpose |
|------|---------|
| `infrastructure/azure/main.bicep` | Infrastructure as Code template |
| `infrastructure/azure/parameters.json` | Environment-specific parameters |
| `infrastructure/azure/deploy.sh` | Bash deployment script |
| `infrastructure/azure/deploy.ps1` | PowerShell deployment script |
| `src/main/resources/application-azure.properties` | Azure profile configuration |
| `Dockerfile` | Multi-stage container build |
| `.dockerignore` | Docker build optimization |
| `.github/workflows/azure-deploy.yml` | CI/CD pipeline |
| `docs/APPLICATION_INSIGHTS.md` | Monitoring setup guide |

## 🚀 Deployment Workflow

### Option 1: Manual Deployment

**Prerequisites**:
- Azure CLI installed and authenticated
- Docker installed
- Java 17+ and Maven

**Steps**:

1. **Deploy Infrastructure**:
   ```powershell
   cd infrastructure/azure
   ./deploy.ps1 -Environment dev -AdminPassword "SecurePass123!"
   ```

2. **Build and Push Docker Image**:
   ```powershell
   # Login to ACR
   $ACR_NAME = "petclinic-dev-acr"
   az acr login --name $ACR_NAME
   
   # Build and push
   docker build -t $ACR_NAME.azurecr.io/petclinic:latest .
   docker push $ACR_NAME.azurecr.io/petclinic:latest
   ```

3. **Configure App Service**:
   ```powershell
   $APP_NAME = "petclinic-dev-app"
   $RG_NAME = "petclinic-dev-rg"
   
   # Restart to pull latest image
   az webapp restart --name $APP_NAME --resource-group $RG_NAME
   ```

4. **Verify Deployment**:
   ```powershell
   # Get app URL
   $APP_URL = az webapp show --name $APP_NAME --resource-group $RG_NAME --query defaultHostName -o tsv
   
   # Test health endpoint
   curl "https://$APP_URL/actuator/health"
   
   # Open in browser
   Start-Process "https://$APP_URL"
   ```

### Option 2: GitHub Actions CI/CD

**Prerequisites**:
- GitHub repository
- Azure service principal with OIDC configured
- Secrets configured in GitHub

**Secrets Required**:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_USERNAME`
- `ACR_PASSWORD`

**Trigger**: Push to `main` branch or manual workflow dispatch

**Workflow Steps**:
1. Build application with Maven
2. Build Docker image
3. Push to Azure Container Registry
4. Deploy to Azure App Service
5. Run smoke tests

## 🔧 Configuration

### Environment Variables (App Service)

Set automatically by Bicep template:

| Variable | Source | Purpose |
|----------|--------|---------|
| `SPRING_PROFILES_ACTIVE` | Static: `azure` | Activate Azure profile |
| `SPRING_DATASOURCE_URL` | PostgreSQL FQDN | Database connection |
| `SPRING_DATASOURCE_USERNAME` | Parameter | Database username |
| `SPRING_DATASOURCE_PASSWORD` | Parameter | Database password (use Key Vault in prod) |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights resource | Monitoring connection |
| `DOCKER_REGISTRY_SERVER_URL` | ACR login server | Container pull auth |
| `DOCKER_REGISTRY_SERVER_USERNAME` | ACR admin | Container pull auth |
| `DOCKER_REGISTRY_SERVER_PASSWORD` | ACR admin password | Container pull auth |
| `WEBSITES_PORT` | Static: `8080` | Container port |

### Database Configuration

**Connection**:
- Host: `{servername}.postgres.database.azure.com`
- Port: `5432`
- Database: `petclinic`
- SSL Mode: Required

**Schema Initialization**:
Automatically run on startup via Spring Boot:
- `src/main/resources/db/postgres/schema.sql`
- `src/main/resources/db/postgres/data.sql`

Controlled by:
```properties
spring.sql.init.mode=always
spring.sql.init.platform=postgres
```

### Firewall Rules

Configured in Bicep:
- **Azure Services**: `0.0.0.0` (allows Azure internal connections)
- **Development Access**: `0.0.0.0/0` (⚠️ **Restrict in production!**)

**Production recommendation**: Use VNet integration and private endpoints.

## 📊 Monitoring

### Application Insights

**Automatic Collection**:
- HTTP requests (URL, duration, status code)
- Database dependencies (SQL queries, duration)
- Exceptions and stack traces
- JVM metrics (memory, GC, threads)
- Custom metrics via Micrometer

**Access**:
1. Navigate to Application Insights resource in Azure Portal
2. View **Application Map** for dependency visualization
3. Query logs with **Kusto (KQL)**
4. Create custom **Dashboards**

**Sample Queries**:

Slowest database queries:
```kusto
dependencies
| where type == "SQL"
| summarize avg(duration), count() by name
| top 10 by avg_duration desc
```

Error rate by page:
```kusto
requests
| where success == false
| summarize count() by name
| order by count_ desc
```

### Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/actuator/health` | Overall health status |
| `/actuator/health/liveness` | Container liveness probe |
| `/actuator/health/readiness` | Container readiness probe |
| `/actuator/metrics` | Prometheus-compatible metrics |
| `/actuator/info` | Application information |

## 🔐 Security Considerations

### Current Setup (Development)

✅ **Implemented**:
- HTTPS only (App Service enforced)
- PostgreSQL SSL required
- Managed Identity for App Service
- Container security (non-root user)
- ACR admin credentials (for simple setup)

⚠️ **Development-Only Settings**:
- PostgreSQL firewall allows all IPs (`0.0.0.0/0`)
- Database credentials in environment variables
- No network isolation

### Production Recommendations

1. **Secrets Management**:
   ```bicep
   // Use Key Vault for database password
   @secure()
   param databasePassword string
   
   resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
     // Configure Key Vault
   }
   
   // Reference in App Service
   {
     name: 'SPRING_DATASOURCE_PASSWORD'
     value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecret.properties.secretUri})'
   }
   ```

2. **Network Security**:
   - Enable VNet integration
   - Use private endpoints for PostgreSQL
   - Configure Network Security Groups (NSGs)
   - Remove public database access

3. **Access Control**:
   - Use ACR with Managed Identity (not admin credentials)
   - Implement Azure AD authentication
   - Enable audit logging

4. **High Availability**:
   - Upgrade to Standard/Premium App Service plan
   - Enable PostgreSQL high availability
   - Configure backup and disaster recovery

## 🧪 Testing

### Local Testing (with Docker)

```bash
# Build image
docker build -t petclinic:test .

# Run with environment variables
docker run -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=azure \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/petclinic \
  -e SPRING_DATASOURCE_USERNAME=petclinic \
  -e SPRING_DATASOURCE_PASSWORD=petclinic \
  petclinic:test
```

### Integration Testing

```bash
# Run integration tests
./mvnw verify

# Run with PostgreSQL via Testcontainers
./mvnw test -Dtest=PostgresIntegrationTests
```

### Smoke Testing (Post-Deployment)

```powershell
$APP_URL = "https://petclinic-dev-app.azurewebsites.net"

# Health check
Invoke-RestMethod "$APP_URL/actuator/health"

# Test main pages
Invoke-WebRequest "$APP_URL/" -UseBasicParsing
Invoke-WebRequest "$APP_URL/vets.html" -UseBasicParsing
Invoke-WebRequest "$APP_URL/owners/find" -UseBasicParsing
```

## 📝 Operational Tasks

### View Logs

```powershell
# Stream logs
az webapp log tail --name petclinic-dev-app --resource-group petclinic-dev-rg

# Download logs
az webapp log download --name petclinic-dev-app --resource-group petclinic-dev-rg
```

### Scale Application

```powershell
# Scale out (add instances)
az appservice plan update --name petclinic-dev-plan --resource-group petclinic-dev-rg --number-of-workers 2

# Scale up (change tier)
az appservice plan update --name petclinic-dev-plan --resource-group petclinic-dev-rg --sku S1
```

### Update Application

```powershell
# Option 1: Push new image with same tag
docker build -t $ACR_NAME.azurecr.io/petclinic:latest .
docker push $ACR_NAME.azurecr.io/petclinic:latest
az webapp restart --name petclinic-dev-app --resource-group petclinic-dev-rg

# Option 2: Deploy different image tag
az webapp config container set --name petclinic-dev-app --resource-group petclinic-dev-rg \
  --docker-custom-image-name $ACR_NAME.azurecr.io/petclinic:v2.0
```

### Database Maintenance

```powershell
# Backup
az postgres flexible-server backup create --name petclinic-dev-pgsql --resource-group petclinic-dev-rg

# List backups
az postgres flexible-server backup list --name petclinic-dev-pgsql --resource-group petclinic-dev-rg

# Restore
az postgres flexible-server restore --resource-group petclinic-dev-rg \
  --name petclinic-dev-pgsql-restored \
  --source-server petclinic-dev-pgsql \
  --restore-time "2025-10-22T12:00:00Z"
```

## 🗑️ Cleanup

### Delete All Resources

```powershell
# Delete resource group (removes all resources)
az group delete --name petclinic-dev-rg --yes --no-wait
```

### Cost Control

To minimize costs during development:

1. **Stop App Service** (keeps configuration):
   ```powershell
   az webapp stop --name petclinic-dev-app --resource-group petclinic-dev-rg
   ```

2. **Stop PostgreSQL** (keeps data):
   ```powershell
   az postgres flexible-server stop --name petclinic-dev-pgsql --resource-group petclinic-dev-rg
   ```

3. **Use Azure Dev/Test pricing** (if eligible)

## 📚 Additional Resources

- [Azure App Service Documentation](https://learn.microsoft.com/azure/app-service/)
- [Azure PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/)
- [Application Insights Guide](docs/APPLICATION_INSIGHTS.md)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Implementation Plan](docs/plans/plan-azure-deployment-postgres.md)

## ✅ Next Steps

After successful deployment:

1. **Configure Production Settings**:
   - Move secrets to Key Vault
   - Implement VNet integration
   - Restrict database firewall

2. **Set Up Monitoring**:
   - Create Application Insights dashboards
   - Configure alerts for errors/performance
   - Set up log queries

3. **Optimize Performance**:
   - Review Application Insights recommendations
   - Tune database queries
   - Configure caching strategies

4. **Implement CI/CD**:
   - Configure GitHub Actions
   - Set up deployment slots for staging
   - Implement automated testing

5. **Document Runbooks**:
   - Incident response procedures
   - Deployment procedures
   - Backup/restore procedures
