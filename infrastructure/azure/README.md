# Azure Infrastructure for Spring PetClinic

This directory contains Infrastructure as Code (IaC) for deploying Spring PetClinic to Azure.

## Table of Contents

- [Architecture](#architecture)
- [Resource Relationships and Dependencies](#resource-relationships-and-dependencies)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Parameters](#parameters)
- [Environment-Specific Examples](#environment-specific-examples)
- [Outputs](#outputs)
- [Resource Naming Convention](#resource-naming-convention)
- [Estimated Costs](#estimated-costs)
- [Security Considerations](#security-considerations)
- [Firewall Rules](#firewall-rules)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)
- [Clean Up](#clean-up)

## Architecture

The infrastructure includes:

- **Azure App Service** - Hosts the Spring Boot application (Linux, Java 17)
- **Azure Database for PostgreSQL Flexible Server** - Managed PostgreSQL database
- **Azure Container Registry** - Stores container images
- **Application Insights** - Application monitoring and telemetry
- **Log Analytics Workspace** - Centralized logging
- **Managed Identity** - Secure authentication between services

## Resource Relationships and Dependencies

### Dependency Graph

```
┌─────────────────────────┐
│ Log Analytics Workspace │ (Created first)
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Application Insights   │ (Depends on Log Analytics)
└─────────────────────────┘

┌─────────────────────────┐
│   App Service Plan      │ (Independent)
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│     App Service         │ (Depends on App Service Plan)
│  (System Assigned MI)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Container Registry ACR  │ (Independent, but MI needs role)
└───────────┬─────────────┘
            │
            ▼ (Role Assignment)
      [AcrPull Permission]

┌─────────────────────────┐
│  PostgreSQL Server      │ (Independent)
└───────────┬─────────────┘
            │
            ├─► Database (petclinic)
            ├─► Firewall Rule (Azure Services)
            └─► Firewall Rule (All IPs - dev only)
```

### Resource Details

#### 1. Log Analytics Workspace
- **Purpose**: Centralized logging and analytics platform
- **Dependencies**: None
- **Used by**: Application Insights
- **Configuration**: 
  - SKU: PerGB2018 (pay-as-you-go)
  - Retention: 30 days

#### 2. Application Insights
- **Purpose**: Application Performance Monitoring (APM)
- **Dependencies**: Log Analytics Workspace
- **Used by**: App Service (via environment variables)
- **Configuration**: 
  - Type: Web application
  - Connection string automatically injected into App Service

#### 3. App Service Plan
- **Purpose**: Defines compute resources for App Service
- **Dependencies**: None
- **Used by**: App Service
- **Configuration**: 
  - OS: Linux
  - SKU: B1 (dev), B2 (staging), P1V2 (prod)
  - Reserved: true (Linux required)

#### 4. App Service
- **Purpose**: Hosts the Spring PetClinic application
- **Dependencies**: App Service Plan, PostgreSQL Server, Application Insights
- **Key Features**:
  - **Runtime**: Java 17
  - **Managed Identity**: System-assigned (automatically created)
  - **HTTPS Only**: Enforced
  - **Health Check**: `/actuator/health`
  - **Always On**: Enabled for P1V2+ (disabled for B1)
- **Environment Variables**:
  - `SPRING_PROFILES_ACTIVE=azure`
  - `POSTGRES_URL` - Generated from PostgreSQL FQDN
  - `POSTGRES_USER` - From parameter `dbAdminLogin`
  - `POSTGRES_PASS` - From parameter `dbAdminPassword`
  - `APPLICATIONINSIGHTS_CONNECTION_STRING` - From Application Insights
  - `WEBSITES_PORT=8080`
  - `JAVA_OPTS=-Xms512m -Xmx1024m`

#### 5. PostgreSQL Flexible Server
- **Purpose**: Managed PostgreSQL database for application data
- **Dependencies**: None
- **Child Resources**:
  - **Database**: `petclinic` (UTF8, en_US.utf8)
  - **Firewall Rules**:
    - Azure Services (0.0.0.0 - required for App Service)
    - All IPs (0.0.0.0-255.255.255.255 - dev only)
- **Configuration**:
  - Version: 14 (default)
  - SKU: Standard_B1ms (Burstable tier)
  - Storage: 32GB
  - Backup retention: 7 days
  - Geo-redundant backup: Disabled
  - High availability: Disabled

#### 6. Azure Container Registry (ACR)
- **Purpose**: Stores Docker container images
- **Dependencies**: None
- **Access Control**: 
  - Admin user: Enabled
  - App Service Managed Identity: AcrPull role assigned
- **Configuration**:
  - SKU: Basic
  - Admin access: Enabled (for CI/CD)

### Security Architecture

```
App Service (Managed Identity)
      │
      │ (AcrPull Role)
      ▼
Container Registry ────► Pull Images
      

App Service
      │
      │ (Connection String with SSL)
      ▼
PostgreSQL Server
      │
      └─► Firewall Rules Control Access
```

## Prerequisites

- Azure CLI installed ([Install guide](https://docs.microsoft.com/cli/azure/install-azure-cli))
- Azure subscription with appropriate permissions
- Logged in to Azure CLI: `az login`

## Quick Start

### Option 1: Bash Script (Linux/Mac/WSL)

```bash
cd infrastructure/azure
chmod +x deploy.sh
./deploy.sh dev petclinic-rg-dev eastus
```

### Option 2: PowerShell Script (Windows)

```powershell
cd infrastructure\azure
.\deploy.ps1 -Environment dev -ResourceGroup petclinic-rg-dev -Location eastus
```

### Option 3: Manual Deployment

```bash
# Set variables
ENVIRONMENT=dev
RESOURCE_GROUP=petclinic-rg-dev
LOCATION=eastus

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy infrastructure
az deployment group create \
  --name petclinic-deployment \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters environmentName=$ENVIRONMENT \
               dbAdminLogin=petclinicadmin \
               dbAdminPassword='YourSecurePassword123!'
```

## Parameters

### Complete Parameter Reference

| Parameter | Type | Required | Default | Description | Allowed Values |
|-----------|------|----------|---------|-------------|----------------|
| `location` | string | No | Resource group location | Azure region for all resources | Any valid Azure region |
| `applicationName` | string | No | `petclinic` | Application name prefix for resources | 2-20 alphanumeric characters |
| `environmentName` | string | No | `dev` | Environment identifier | `dev`, `staging`, `prod` (or custom) |
| `appServicePlanSku` | string | No | `B1` | App Service compute tier | `B1`, `B2`, `P1V2`, `P2V2` |
| `postgresSku` | string | No | `Standard_B1ms` | PostgreSQL compute tier | `Standard_B1ms`, `Standard_B2s`, `Standard_D2s_v3` |
| `postgresVersion` | string | No | `14` | PostgreSQL major version | `11`, `12`, `13`, `14`, `15` |
| `dbAdminLogin` | string | **Yes** | - | PostgreSQL admin username | 1-63 alphanumeric, start with letter |
| `dbAdminPassword` | securestring | **Yes** | - | PostgreSQL admin password | Min 8 chars: uppercase, lowercase, numbers |
| `appInsightsConnectionString` | string | No | *(auto-created)* | External App Insights connection | Valid connection string or empty |

### Parameter Details

#### location
- **Purpose**: Determines where all resources are deployed
- **Recommendation**: 
  - Use `eastus` or `westus2` for US-based workloads
  - Use `westeurope` or `northeurope` for EU-based workloads
  - Choose regions close to your users for better latency
- **Example**: `eastus`, `westeurope`, `southeastasia`

#### applicationName
- **Purpose**: Prefix for all resource names
- **Impact**: Changes this value creates entirely new resources
- **Constraints**: Lowercase letters and numbers only (for ACR compatibility)
- **Example**: `petclinic`, `mypetapp`

#### environmentName
- **Purpose**: Distinguishes environments and affects resource naming
- **Special behavior**: 
  - `dev` environment enables open firewall (0.0.0.0-255.255.255.255)
  - Non-dev environments restrict firewall to Azure services only
- **Example**: `dev`, `staging`, `prod`, `qa`

#### appServicePlanSku
- **Purpose**: Defines compute power for App Service
- **SKU Comparison**:

| SKU | Cores | RAM | Price/month | Always On | Use Case |
|-----|-------|-----|-------------|-----------|----------|
| B1 | 1 | 1.75 GB | ~$13 | ❌ | Development |
| B2 | 2 | 3.5 GB | ~$26 | ❌ | Staging/Small prod |
| P1V2 | 1 | 3.5 GB | ~$96 | ✅ | Production |
| P2V2 | 2 | 7 GB | ~$192 | ✅ | High traffic prod |

- **Recommendation**: 
  - Dev: `B1`
  - Staging: `B2`
  - Production: `P1V2` or higher

#### postgresSku
- **Purpose**: Defines database compute power
- **SKU Comparison**:

| SKU | vCores | RAM | Storage IOPS | Price/month | Use Case |
|-----|--------|-----|--------------|-------------|----------|
| Standard_B1ms | 1 | 2 GB | 640 | ~$12 | Development |
| Standard_B2s | 2 | 4 GB | 1280 | ~$24 | Staging |
| Standard_D2s_v3 | 2 | 8 GB | 3200 | ~$100 | Production |

- **Recommendation**:
  - Dev: `Standard_B1ms`
  - Staging: `Standard_B2s`
  - Production: `Standard_D2s_v3`

#### postgresVersion
- **Purpose**: PostgreSQL major version
- **Recommendation**: Use version `14` (good balance of features and stability)
- **Migration**: Changing version requires data migration
- **Support**: Check Azure docs for version support lifecycle

#### dbAdminLogin
- **Purpose**: PostgreSQL superuser account name
- **Constraints**:
  - Cannot be: `azure_superuser`, `admin`, `administrator`, `root`, `guest`, `public`
  - Must start with a letter
  - 1-63 characters
- **Security**: Don't use predictable names like `admin` or `postgres`
- **Example**: `petclinicadmin`, `dbadmin`, `pgadmin`

#### dbAdminPassword
- **Purpose**: PostgreSQL superuser password
- **Security requirements**:
  - Minimum 8 characters
  - Must contain uppercase letters
  - Must contain lowercase letters
  - Must contain numbers
  - Recommended: Include special characters
- **Best practice**: Use Azure Key Vault reference instead of plain text
- **Example**: Use environment variable or secure parameter

#### appInsightsConnectionString
- **Purpose**: Optional external Application Insights instance
- **Default behavior**: Template creates new App Insights automatically
- **Use case**: Consolidate multiple apps into one App Insights instance
- **Format**: `InstrumentationKey=...;IngestionEndpoint=...`

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `dbAdminLogin` | PostgreSQL administrator username | `petclinicadmin` |
| `dbAdminPassword` | PostgreSQL administrator password | Set via environment variable or prompt |

### Optional Parameters

| Parameter | Default | Description | Options |
|-----------|---------|-------------|---------|
| `location` | `eastus` | Azure region | Any valid Azure region |
| `applicationName` | `petclinic` | Application name prefix | alphanumeric |
| `environmentName` | `dev` | Environment name | `dev`, `staging`, `prod` |
| `appServicePlanSku` | `B1` | App Service tier | `B1`, `B2`, `P1V2`, `P2V2` |
| `postgresSku` | `Standard_B1ms` | PostgreSQL tier | `Standard_B1ms`, `Standard_B2s`, `Standard_D2s_v3` |
| `postgresVersion` | `14` | PostgreSQL version | `11`, `12`, `13`, `14`, `15` |

### Passing Parameters Securely

#### Option 1: Environment Variable (Bash)
```bash
export POSTGRES_ADMIN_PASSWORD='YourSecurePassword123!'
./deploy.sh dev
```

#### Option 2: Interactive Prompt
```bash
# Script will prompt for password if not set
./deploy.sh dev
```

#### Option 3: Azure Key Vault Reference (Recommended for CI/CD)
```json
{
  "dbAdminPassword": {
    "reference": {
      "keyVault": {
        "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault-name}"
      },
      "secretName": "postgres-admin-password"
    }
  }
}
```

#### Option 4: Command Line (Less secure)
```bash
az deployment group create \
  --template-file main.bicep \
  --parameters dbAdminPassword='YourPassword123!'
```

**⚠️ Security Warning**: Avoid committing passwords to git or CI/CD logs!

## Outputs

After deployment, the following values are available:

| Output | Description |
|--------|-------------|
| `appServiceName` | Name of the App Service |
| `appServiceUrl` | Public URL of the application |
| `postgresServerName` | PostgreSQL server name |
| `postgresFqdn` | PostgreSQL fully qualified domain name |
| `databaseName` | Database name (always `petclinic`) |
| `containerRegistryName` | Azure Container Registry name |
| `containerRegistryLoginServer` | ACR login server URL |
| `appInsightsConnectionString` | Application Insights connection string |
| `appServicePrincipalId` | Managed Identity principal ID |

## Environment-Specific Examples

### Development Environment

Suitable for individual developers and testing.

```bash
az deployment group create \
  --name petclinic-dev-deployment \
  --resource-group petclinic-rg-dev \
  --template-file main.bicep \
  --parameters \
    location=eastus \
    applicationName=petclinic \
    environmentName=dev \
    appServicePlanSku=B1 \
    postgresSku=Standard_B1ms \
    postgresVersion=14 \
    dbAdminLogin=petclinicadmin \
    dbAdminPassword='<your-secure-password>'
```

**Characteristics**:
- Minimal cost (~$30/month)
- Single instance, no high availability
- Open firewall for development access
- 32GB PostgreSQL storage
- 7-day backup retention

### Staging Environment

Pre-production environment for testing before production release.

```bash
az deployment group create \
  --name petclinic-staging-deployment \
  --resource-group petclinic-rg-staging \
  --template-file main.bicep \
  --parameters \
    location=eastus \
    applicationName=petclinic \
    environmentName=staging \
    appServicePlanSku=B2 \
    postgresSku=Standard_B2s \
    postgresVersion=14 \
    dbAdminLogin=petclinicadmin \
    dbAdminPassword='<your-secure-password>'
```

**Characteristics**:
- Moderate cost (~$50-70/month)
- Better performance than dev
- Restricted firewall (Azure services only)
- 32GB PostgreSQL storage
- 7-day backup retention
- Suitable for load testing

### Production Environment

Production-ready configuration with better performance and reliability.

```bash
az deployment group create \
  --name petclinic-prod-deployment \
  --resource-group petclinic-rg-prod \
  --template-file main.bicep \
  --parameters \
    location=eastus \
    applicationName=petclinic \
    environmentName=prod \
    appServicePlanSku=P1V2 \
    postgresSku=Standard_D2s_v3 \
    postgresVersion=14 \
    dbAdminLogin=petclinicadmin \
    dbAdminPassword='<your-secure-password>'
```

**Characteristics**:
- Higher cost (~$220+/month)
- Premium tier with better performance
- Always On enabled (no cold starts)
- Restricted firewall (Azure services only)
- Consider increasing storage and backup retention
- Recommended: Enable VNet integration

### Using Parameters File

You can also create environment-specific parameter files:

**parameters-dev.json**:
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": { "value": "eastus" },
    "applicationName": { "value": "petclinic" },
    "environmentName": { "value": "dev" },
    "appServicePlanSku": { "value": "B1" },
    "postgresSku": { "value": "Standard_B1ms" },
    "postgresVersion": { "value": "14" },
    "dbAdminLogin": { "value": "petclinicadmin" },
    "dbAdminPassword": { "value": "<your-password>" }
  }
}
```

Deploy using:
```bash
az deployment group create \
  --resource-group petclinic-rg-dev \
  --template-file main.bicep \
  --parameters @parameters-dev.json
```

## Resource Naming Convention

Resources are named using this pattern:  
`{applicationName}-{resourceType}-{environment}-{uniqueSuffix}`

Example:
- App Service: `petclinic-app-dev-abc123`
- PostgreSQL: `petclinic-db-dev-abc123`
- ACR: `petclinicacrdevabc123` (alphanumeric only)

The `uniqueSuffix` is generated using `uniqueString(resourceGroup().id)` to ensure globally unique names while remaining deterministic for the same resource group.

## Estimated Costs

### Development Environment (B1 tier)
- App Service (B1): ~$13/month
- PostgreSQL (B1ms): ~$12/month
- Container Registry (Basic): ~$5/month
- Application Insights: Free tier (limited)
- **Total**: ~$30/month

### Production Environment (P1V2 tier)
- App Service (P1V2): ~$96/month
- PostgreSQL (D2s_v3): ~$100/month
- Container Registry (Standard): ~$20/month
- Application Insights: Pay-as-you-go
- **Total**: ~$220+/month

## Security Considerations

### Implemented
- ✅ HTTPS only (enforced on App Service)
- ✅ TLS 1.2 minimum
- ✅ Managed Identity for ACR access
- ✅ PostgreSQL SSL required
- ✅ Secure password via parameter

### Recommended for Production
- 🔐 Use Azure Key Vault for secrets
- 🔐 Enable VNet integration
- 🔐 Restrict PostgreSQL to private endpoint
- 🔐 Enable Azure Defender
- 🔐 Configure Azure AD authentication
- 🔐 Enable diagnostic logging

## Firewall Rules

### Development Environment
- **Azure Services**: ✅ Allowed (0.0.0.0)
- **All IPs**: ✅ Allowed (for development access)

### Production Environment
- **Azure Services**: ✅ Allowed
- **All IPs**: ❌ Remove this rule
- **Specific IPs**: Add your organization's IP ranges

## Troubleshooting

### Deployment Issues

#### Issue: Deployment fails with "InvalidTemplateDeployment"
**Symptoms**: Template validation fails during deployment

**Solutions**: 
1. Check parameter values meet Azure naming requirements
2. Verify SKU values are from allowed list
3. Ensure PostgreSQL version is supported (11, 12, 13, 14, 15)
4. Check Azure CLI is up to date: `az upgrade`

**Debug command**:
```bash
az deployment group validate \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters @parameters.json
```

#### Issue: Resource name conflicts (409 Conflict)
**Symptoms**: "The resource name is already taken" or similar error

**Solutions**:
1. Choose a different resource group (generates different uniqueSuffix)
2. Change `applicationName` parameter
3. Delete existing resources if they're no longer needed

#### Issue: Quota exceeded errors
**Symptoms**: Deployment fails with "QuotaExceeded" or "SkuNotAvailable"

**Solutions**:
1. Check your subscription quotas: `az vm list-usage --location eastus -o table`
2. Try a different Azure region
3. Request quota increase in Azure Portal
4. Use a smaller SKU tier

### Database Connection Issues

#### Issue: Cannot connect to PostgreSQL
**Symptoms**: Application shows database connection errors

**Solutions**: 
1. **Verify firewall rules**:
   ```bash
   az postgres flexible-server firewall-rule list \
     --resource-group <rg-name> \
     --name <server-name>
   ```
2. **Check connection string** includes `?sslmode=require`
3. **Verify credentials** are correct in App Service configuration
4. **Test connection** from Azure Cloud Shell:
   ```bash
   psql "host=<server-name>.postgres.database.azure.com port=5432 dbname=petclinic user=<admin-user> password=<password> sslmode=require"
   ```

#### Issue: "SSL connection is required"
**Symptoms**: Connection fails with SSL error

**Solution**: Ensure connection string includes `sslmode=require` parameter:
```
jdbc:postgresql://<server>.postgres.database.azure.com:5432/petclinic?sslmode=require
```

#### Issue: Password authentication failed
**Symptoms**: Login fails with authentication error

**Solutions**:
1. Verify `dbAdminPassword` parameter was set correctly during deployment
2. Check App Service environment variable `POSTGRES_PASS` is set
3. Reset PostgreSQL admin password if needed:
   ```bash
   az postgres flexible-server update \
     --resource-group <rg-name> \
     --name <server-name> \
     --admin-password <new-password>
   ```

### Application Issues

#### Issue: App Service shows "Application Error"
**Symptoms**: Browser shows generic error page

**Solutions**:
1. **Check Application Insights** for detailed errors:
   - Navigate to Application Insights in Portal
   - View Failures tab
2. **View App Service logs**:
   ```bash
   az webapp log tail \
     --name <app-name> \
     --resource-group <rg-name>
   ```
3. **Check log stream** in Azure Portal:
   - Navigate to App Service → Monitoring → Log stream
4. **Verify environment variables** are set:
   ```bash
   az webapp config appsettings list \
     --name <app-name> \
     --resource-group <rg-name>
   ```

#### Issue: Application takes long to start (cold start)
**Symptoms**: First request takes 60+ seconds, timeout errors

**Solutions**:
1. **Enable Always On** (requires P1V2 or higher tier):
   ```bash
   az webapp config set \
     --name <app-name> \
     --resource-group <rg-name> \
     --always-on true
   ```
2. **Increase instance size**: Upgrade to B2 or P1V2
3. **Optimize application**: Review Spring Boot startup optimizations

#### Issue: Application crashes or restarts frequently
**Symptoms**: Intermittent 503 errors, application unavailable

**Solutions**:
1. **Check memory usage** in Application Insights → Performance
2. **Increase JAVA_OPTS heap size**:
   ```bash
   az webapp config appsettings set \
     --name <app-name> \
     --resource-group <rg-name> \
     --settings JAVA_OPTS="-Xms1024m -Xmx2048m"
   ```
3. **Upgrade to larger SKU** (B2 or P1V2)
4. **Review application logs** for OutOfMemoryError

### Container Registry Issues

#### Issue: Container image not pulling
**Symptoms**: App Service fails to pull container image from ACR

**Solutions**:
1. **Verify Managed Identity has AcrPull role** (assigned automatically):
   ```bash
   az role assignment list \
     --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>
   ```
2. **Check ACR admin is enabled**:
   ```bash
   az acr update \
     --name <acr-name> \
     --admin-enabled true
   ```
3. **Verify image exists** in registry:
   ```bash
   az acr repository list --name <acr-name>
   az acr repository show-tags --name <acr-name> --repository petclinic
   ```
4. **Check App Service container settings**:
   ```bash
   az webapp config container show \
     --name <app-name> \
     --resource-group <rg-name>
   ```

#### Issue: ACR build fails
**Symptoms**: `az acr build` command fails

**Solutions**:
1. **Check Dockerfile** exists and is valid
2. **Verify you're in project root** directory
3. **Check ACR SKU** supports builds (Basic or higher)
4. **Review build logs**:
   ```bash
   az acr task logs --registry <acr-name>
   ```

### Monitoring Issues

#### Issue: No telemetry in Application Insights
**Symptoms**: Application Insights shows no data

**Solutions**:
1. **Verify connection string** is set in App Service:
   ```bash
   az webapp config appsettings show \
     --name <app-name> \
     --resource-group <rg-name> \
     --setting-names APPLICATIONINSIGHTS_CONNECTION_STRING
   ```
2. **Check Java agent** is enabled (automatically included in Java 17+ App Service)
3. **Wait 2-5 minutes** for data to appear
4. **Check sampling settings** if using high-traffic application

#### Issue: High Application Insights costs
**Symptoms**: Unexpected charges from Application Insights

**Solutions**:
1. **Enable sampling** to reduce data volume
2. **Set daily cap** in Application Insights → Usage and estimated costs
3. **Review retention settings** (default 90 days)
4. **Filter unnecessary telemetry** in application code

### Performance Issues

#### Issue: Slow database queries
**Symptoms**: Application responds slowly, database is bottleneck

**Solutions**:
1. **Review query performance** in PostgreSQL logs
2. **Add database indexes** for frequently queried fields
3. **Upgrade PostgreSQL SKU** to Standard_B2s or Standard_D2s_v3
4. **Enable connection pooling** (already configured in Spring Boot)
5. **Increase storage IOPS** by upgrading PostgreSQL tier

#### Issue: High CPU or memory usage
**Symptoms**: App Service Plan CPU/memory near 100%

**Solutions**:
1. **Scale up** to larger SKU (B2, P1V2, P2V2)
2. **Scale out** by increasing instance count:
   ```bash
   az appservice plan update \
     --name <plan-name> \
     --resource-group <rg-name> \
     --number-of-workers 2
   ```
3. **Enable auto-scaling** (requires Premium tier)
4. **Optimize application code** for resource usage

### Common Error Messages

| Error Message | Likely Cause | Solution |
|---------------|--------------|----------|
| "The subscription is not registered to use namespace 'Microsoft.Web'" | Required resource provider not registered | Run: `az provider register --namespace Microsoft.Web` |
| "Location 'xyz' is not available for resource type" | Region doesn't support the resource | Choose different region or resource type |
| "Insufficient permissions" | Account lacks required role | Contact subscription administrator |
| "Name not available" | Resource name already exists globally | Change applicationName parameter |
| "Password does not meet requirements" | Weak PostgreSQL password | Use 8+ chars with uppercase, lowercase, numbers |

### Getting Help

1. **View deployment operations**:
   ```bash
   az deployment group show \
     --name <deployment-name> \
     --resource-group <rg-name> \
     --query properties.error
   ```

2. **Check Azure Activity Log** in Portal for detailed error messages

3. **Enable debug logging**:
   ```bash
   az config set logging.enable_log_file=true
   ```

4. **Review Azure service health**: https://status.azure.com/

5. **Consult Azure documentation**: https://docs.microsoft.com/azure/

## Next Steps

After infrastructure deployment:

1. **Build and deploy application** - See main README.md
2. **Configure CI/CD** - Use GitHub Actions workflow
3. **Set up monitoring** - Configure Application Insights alerts
4. **Enable auto-scaling** - Configure scale rules
5. **Implement deployment slots** - For blue-green deployments

## Clean Up

To delete all resources:

```bash
az group delete --name <resource-group-name> --yes --no-wait
```

**Warning**: This permanently deletes all resources and data!

## Support

For issues specific to this infrastructure:
1. Check Application Insights for application errors
2. Review Azure Activity Log for deployment issues
3. Consult Azure documentation for service-specific problems
