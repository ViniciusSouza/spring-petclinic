# Azure Infrastructure for Spring PetClinic

This directory contains Azure Bicep templates and deployment scripts for deploying the Spring PetClinic application to Azure with PostgreSQL database.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Parameters](#parameters)
- [Resources Created](#resources-created)
- [Deployment Guide](#deployment-guide)
- [Environment Examples](#environment-examples)
- [Naming Conventions](#naming-conventions)
- [Cost Estimation](#cost-estimation)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Troubleshooting](#troubleshooting)

## Overview

The Bicep templates in this directory deploy a complete Azure infrastructure for running Spring PetClinic, including:

- **Azure App Service**: Hosts the Spring Boot application with Java 17 runtime
- **PostgreSQL Flexible Server**: Managed PostgreSQL database for data persistence
- **Application Insights**: Application performance monitoring and logging
- **Log Analytics Workspace**: Centralized logging and monitoring
- **Key Vault**: Secure storage for secrets and connection strings
- **Managed Identity**: Secure authentication between Azure services

The infrastructure is designed to support multiple environments (dev, staging, production) with appropriate SKUs and configurations for each.

## Prerequisites

Before deploying the infrastructure, ensure you have:

1. **Azure Subscription**: An active Azure subscription with appropriate permissions
   - Minimum required: Contributor role on the resource group
   - For Key Vault RBAC: User Access Administrator or Owner role

2. **Azure CLI** (for bash deployment) or **Azure PowerShell** (for PowerShell deployment)
   - Azure CLI: [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - Azure PowerShell: [Install Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)

3. **Bicep CLI** (included with Azure CLI 2.20.0+)
   - Verify: `az bicep version`
   - Update: `az bicep upgrade`

4. **Permissions**:
   - Permission to create resource groups (if creating new)
   - Permission to create resources in the resource group
   - Permission to assign RBAC roles (for Key Vault access)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Resource Group                     │
│                                                               │
│  ┌──────────────────┐         ┌─────────────────────────┐   │
│  │   App Service    │────────▶│  PostgreSQL Flexible    │   │
│  │  (Java 17)       │         │  Server (v16)           │   │
│  │                  │         │                         │   │
│  │  - Spring Boot   │         │  - petclinic database   │   │
│  │  - Auto-scaling  │         │  - Backup enabled       │   │
│  └────────┬─────────┘         └─────────────────────────┘   │
│           │                                                   │
│           │ Managed Identity                                 │
│           ▼                                                   │
│  ┌──────────────────┐         ┌─────────────────────────┐   │
│  │   Key Vault      │         │  Application Insights   │   │
│  │                  │         │                         │   │
│  │  - DB Password   │◀────────│  - Monitoring           │   │
│  │  - Secrets       │         │  - Logging              │   │
│  └──────────────────┘         └──────────┬──────────────┘   │
│                                           │                   │
│                                           ▼                   │
│                                ┌─────────────────────────┐   │
│                                │  Log Analytics          │   │
│                                │  Workspace              │   │
│                                └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Parameters

The following table describes all parameters available in the Bicep template:

| Parameter | Type | Default | Allowed Values | Description |
|-----------|------|---------|----------------|-------------|
| `environment` | string | `dev` | `dev`, `staging`, `prod` | Environment name that affects resource sizing and configuration |
| `location` | string | Resource Group location | Any Azure region | Azure region where resources will be deployed |
| `baseName` | string | `petclinic` | 3-20 characters | Base name used for all resources (combined with environment and unique suffix) |
| `postgresAdminLogin` | string | `petclinicadmin` | Min 1 character | PostgreSQL administrator username |
| `postgresAdminPassword` | securestring | *(required)* | Min 8 characters | PostgreSQL administrator password (stored in Key Vault) |
| `postgresDatabaseName` | string | `petclinic` | - | Name of the PostgreSQL database to create |
| `postgresSku` | string | `Standard_B1ms` | `Standard_B1ms`, `Standard_B2s`, `Standard_D2ds_v4`, `Standard_D4ds_v4` | PostgreSQL server SKU (see SKU table below) |
| `postgresStorageSizeGB` | int | `32` | 32-16384 | PostgreSQL storage size in GB (can auto-grow) |
| `appServiceSku` | string | `B1` | `B1`, `B2`, `P1V2`, `P2V2` | App Service Plan SKU (see SKU table below) |
| `appInsightsRetentionDays` | int | `30` | 30-730 | Application Insights data retention in days |
| `enablePostgresPublicAccess` | bool | `false` | `true`, `false` | Enable public network access to PostgreSQL (recommended: false) |
| `tags` | object | See below | - | Tags to apply to all resources |

### Default Tags

```json
{
  "application": "spring-petclinic",
  "environment": "<environment-value>"
}
```

### PostgreSQL SKU Details

| SKU Name | Tier | vCores | RAM | Recommended For | Approx. Cost/Month* |
|----------|------|--------|-----|-----------------|---------------------|
| `Standard_B1ms` | Burstable | 1 | 2 GB | Development | ~$12 |
| `Standard_B2s` | Burstable | 2 | 4 GB | Staging/Testing | ~$35 |
| `Standard_D2ds_v4` | General Purpose | 2 | 8 GB | Production (small) | ~$150 |
| `Standard_D4ds_v4` | General Purpose | 4 | 16 GB | Production (large) | ~$300 |

*Approximate costs for East US region with 32 GB storage

### App Service SKU Details

| SKU Name | Tier | Cores | RAM | Features | Approx. Cost/Month* |
|----------|------|-------|-----|----------|---------------------|
| `B1` | Basic | 1 | 1.75 GB | Manual scaling | ~$13 |
| `B2` | Basic | 2 | 3.5 GB | Manual scaling | ~$26 |
| `P1V2` | Premium V2 | 1 | 3.5 GB | Auto-scaling, Slots | ~$96 |
| `P2V2` | Premium V2 | 2 | 7 GB | Auto-scaling, Slots | ~$192 |

*Approximate costs for East US region

## Resources Created

The deployment creates the following Azure resources:

### 1. Log Analytics Workspace
- **Name Pattern**: `log-{baseName}-{environment}-{uniqueId}`
- **Purpose**: Centralized logging and metrics storage
- **Pricing**: Pay-as-you-go (per GB ingested)

### 2. Application Insights
- **Name Pattern**: `appi-{baseName}-{environment}-{uniqueId}`
- **Purpose**: Application performance monitoring, distributed tracing, and telemetry
- **Features**: 
  - Request tracking
  - Dependency tracking
  - Exception tracking
  - Custom metrics and events

### 3. Key Vault
- **Name Pattern**: `kv-{baseName}-{env}-{uid}` (max 24 chars)
- **Purpose**: Secure storage for database passwords and other secrets
- **Features**:
  - RBAC enabled
  - Soft delete enabled (7-day retention)
  - Integrated with App Service via Managed Identity

### 4. PostgreSQL Flexible Server
- **Name Pattern**: `psql-{baseName}-{environment}-{uniqueId}`
- **Version**: PostgreSQL 16
- **Features**:
  - Automatic backups (7 days for dev, 35 days for prod)
  - Geo-redundant backup (prod only)
  - Zone-redundant high availability (prod only)
  - Auto-growing storage
  - Private network access (public access disabled by default)

### 5. PostgreSQL Database
- **Name**: Configured via `postgresDatabaseName` parameter
- **Charset**: UTF8
- **Collation**: en_US.utf8

### 6. App Service Plan
- **Name Pattern**: `asp-{baseName}-{environment}-{uniqueId}`
- **OS**: Linux
- **Features**: Reserved capacity for Linux workloads

### 7. App Service
- **Name Pattern**: `app-{baseName}-{environment}-{uniqueId}`
- **Runtime**: Java 17 (Linux)
- **Identity**: System-assigned managed identity
- **Features**:
  - HTTPS only
  - HTTP/2 enabled
  - TLS 1.2 minimum
  - FTPS disabled (security)
  - Always On (staging/prod only)
  - Integrated with Application Insights
  - Environment variables pre-configured for PostgreSQL connection

### 8. RBAC Role Assignment
- **Purpose**: Grant App Service access to Key Vault secrets
- **Role**: Key Vault Secrets User
- **Scope**: Key Vault resource

## Deployment Guide

### Using Bash Script (Linux/macOS/WSL)

1. **Navigate to the infrastructure directory**:
   ```bash
   cd infrastructure/azure
   ```

2. **Review and customize parameters** (optional):
   Edit `parameters.json` to customize deployment settings.

3. **Run the deployment script**:

   ```bash
   # Basic deployment to dev environment
   ./deploy.sh -g petclinic-dev-rg -p 'YourSecurePassword123!'

   # Deploy to production with custom region
   ./deploy.sh -e prod -g petclinic-prod-rg -l westus2 -p 'YourSecurePassword123!'

   # Run what-if analysis before deploying
   ./deploy.sh -e staging -g petclinic-staging-rg -p 'YourSecurePassword123!' --what-if
   ```

4. **Script options**:
   ```
   -e, --environment ENV       Environment (dev, staging, prod). Default: dev
   -l, --location LOCATION     Azure region. Default: eastus
   -g, --resource-group RG     Resource group name (required)
   -n, --name NAME            Base name for resources. Default: petclinic
   -p, --password PASSWORD    PostgreSQL admin password (required)
   -f, --parameters-file FILE Parameters file. Default: parameters.json
   -w, --what-if              Run what-if analysis without deploying
   -h, --help                 Show help message
   ```

5. **Alternative: Using environment variable for password**:
   ```bash
   export POSTGRES_ADMIN_PASSWORD='YourSecurePassword123!'
   ./deploy.sh -e dev -g petclinic-dev-rg
   ```

### Using PowerShell Script (Windows/PowerShell Core)

1. **Navigate to the infrastructure directory**:
   ```powershell
   cd infrastructure/azure
   ```

2. **Connect to Azure** (if not already connected):
   ```powershell
   Connect-AzAccount
   ```

3. **Run the deployment script**:

   ```powershell
   # Basic deployment to dev environment
   $password = ConvertTo-SecureString 'YourSecurePassword123!' -AsPlainText -Force
   .\deploy.ps1 -ResourceGroup petclinic-dev-rg -PostgresPassword $password

   # Deploy to production with custom region
   .\deploy.ps1 -Environment prod -ResourceGroup petclinic-prod-rg -Location westus2 -PostgresPassword $password

   # Run what-if analysis
   .\deploy.ps1 -Environment staging -ResourceGroup petclinic-staging-rg -PostgresPassword $password -WhatIf
   ```

4. **Script parameters**:
   ```
   -Environment          Environment (dev, staging, prod). Default: dev
   -Location            Azure region. Default: eastus
   -ResourceGroup       Resource group name (required)
   -BaseName            Base name for resources. Default: petclinic
   -PostgresPassword    PostgreSQL admin password (SecureString)
   -ParametersFile      Parameters file. Default: parameters.json
   -WhatIf              Run what-if analysis without deploying
   ```

### Using Azure CLI Directly

```bash
# Create resource group
az group create --name petclinic-dev-rg --location eastus

# Deploy template
az deployment group create \
  --name petclinic-deployment \
  --resource-group petclinic-dev-rg \
  --template-file main.bicep \
  --parameters environment=dev \
  --parameters postgresAdminPassword='YourSecurePassword123!'
```

### Using Azure PowerShell Directly

```powershell
# Create resource group
New-AzResourceGroup -Name petclinic-dev-rg -Location eastus

# Deploy template
$password = ConvertTo-SecureString 'YourSecurePassword123!' -AsPlainText -Force
New-AzResourceGroupDeployment `
  -Name petclinic-deployment `
  -ResourceGroupName petclinic-dev-rg `
  -TemplateFile main.bicep `
  -environment dev `
  -postgresAdminPassword $password
```

## Environment Examples

### Development Environment

**Characteristics**: Cost-optimized, minimal redundancy, suitable for development and testing.

```bash
./deploy.sh \
  -e dev \
  -g petclinic-dev-rg \
  -l eastus \
  -n petclinic \
  -p 'DevPassword123!'
```

**Default Configuration**:
- PostgreSQL: `Standard_B1ms` (1 vCore, 2 GB RAM, 32 GB storage)
- App Service: `B1` (1 core, 1.75 GB RAM)
- Backup retention: 7 days
- High availability: Disabled
- Geo-redundant backup: Disabled
- Estimated cost: ~$25-30/month

**Parameters File** (`parameters.dev.json`):
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "dev" },
    "location": { "value": "eastus" },
    "postgresSku": { "value": "Standard_B1ms" },
    "postgresStorageSizeGB": { "value": 32 },
    "appServiceSku": { "value": "B1" },
    "appInsightsRetentionDays": { "value": 30 },
    "enablePostgresPublicAccess": { "value": false }
  }
}
```

### Staging Environment

**Characteristics**: Production-like configuration, suitable for pre-production testing and QA.

```bash
./deploy.sh \
  -e staging \
  -g petclinic-staging-rg \
  -l eastus \
  -n petclinic \
  -p 'StagingPassword123!'
```

**Default Configuration**:
- PostgreSQL: `Standard_B2s` (2 vCore, 4 GB RAM, 64 GB storage)
- App Service: `B2` (2 cores, 3.5 GB RAM)
- Backup retention: 7 days
- High availability: Disabled
- Geo-redundant backup: Disabled
- Estimated cost: ~$60-70/month

**Parameters File** (`parameters.staging.json`):
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "staging" },
    "location": { "value": "eastus" },
    "postgresSku": { "value": "Standard_B2s" },
    "postgresStorageSizeGB": { "value": 64 },
    "appServiceSku": { "value": "B2" },
    "appInsightsRetentionDays": { "value": 60 },
    "enablePostgresPublicAccess": { "value": false }
  }
}
```

### Production Environment

**Characteristics**: High availability, enhanced monitoring, suitable for production workloads.

```bash
./deploy.sh \
  -e prod \
  -g petclinic-prod-rg \
  -l eastus \
  -n petclinic \
  -p 'ProductionPassword123!'
```

**Default Configuration**:
- PostgreSQL: `Standard_D2ds_v4` (2 vCore, 8 GB RAM, 128 GB storage)
- App Service: `P1V2` (1 core, 3.5 GB RAM) with auto-scaling
- Backup retention: 35 days
- High availability: Zone-redundant
- Geo-redundant backup: Enabled
- Always On: Enabled
- Estimated cost: ~$250-300/month

**Parameters File** (`parameters.prod.json`):
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "prod" },
    "location": { "value": "eastus" },
    "postgresSku": { "value": "Standard_D2ds_v4" },
    "postgresStorageSizeGB": { "value": 128 },
    "appServiceSku": { "value": "P1V2" },
    "appInsightsRetentionDays": { "value": 90 },
    "enablePostgresPublicAccess": { "value": false },
    "tags": {
      "value": {
        "application": "spring-petclinic",
        "environment": "prod",
        "owner": "platform-team",
        "cost-center": "engineering",
        "business-unit": "digital"
      }
    }
  }
}
```

## Naming Conventions

All Azure resources follow a consistent naming pattern for easy identification and management:

### Pattern

```
{resource-type}-{baseName}-{environment}-{uniqueId}
```

### Components

- **resource-type**: Short prefix identifying the Azure resource type
- **baseName**: Base application name (default: `petclinic`)
- **environment**: Environment identifier (`dev`, `staging`, `prod`)
- **uniqueId**: Auto-generated unique suffix from resource group ID (ensures global uniqueness)

### Resource Type Prefixes

| Resource | Prefix | Example |
|----------|--------|---------|
| App Service Plan | `asp-` | `asp-petclinic-dev-abc123` |
| App Service | `app-` | `app-petclinic-dev-abc123` |
| PostgreSQL Server | `psql-` | `psql-petclinic-prod-abc123` |
| Application Insights | `appi-` | `appi-petclinic-staging-abc123` |
| Log Analytics | `log-` | `log-petclinic-dev-abc123` |
| Key Vault | `kv-` | `kv-petclinic-prod-abc12` (max 24 chars) |

### Benefits

1. **Easy Identification**: Quickly identify resource type and purpose
2. **Environment Isolation**: Clear separation between environments
3. **Global Uniqueness**: Unique suffix prevents naming conflicts
4. **Searchability**: Easy to find related resources using tags or name patterns
5. **Compliance**: Follows Azure naming best practices

## Cost Estimation

### Monthly Cost Breakdown by Environment

#### Development Environment (~$25-30/month)

| Resource | SKU/Tier | Estimated Cost |
|----------|----------|----------------|
| App Service Plan | B1 | ~$13 |
| PostgreSQL Flexible Server | Standard_B1ms, 32 GB | ~$12 |
| Application Insights | Pay-as-you-go | ~$0-2 |
| Key Vault | Standard | ~$0.50 |
| Log Analytics | Pay-as-you-go | ~$0-2 |
| **Total** | | **~$25-30** |

#### Staging Environment (~$60-70/month)

| Resource | SKU/Tier | Estimated Cost |
|----------|----------|----------------|
| App Service Plan | B2 | ~$26 |
| PostgreSQL Flexible Server | Standard_B2s, 64 GB | ~$35 |
| Application Insights | Pay-as-you-go | ~$2-5 |
| Key Vault | Standard | ~$0.50 |
| Log Analytics | Pay-as-you-go | ~$2-5 |
| **Total** | | **~$60-70** |

#### Production Environment (~$250-300/month)

| Resource | SKU/Tier | Estimated Cost |
|----------|----------|----------------|
| App Service Plan | P1V2 | ~$96 |
| PostgreSQL Flexible Server | Standard_D2ds_v4, 128 GB | ~$150 |
| PostgreSQL - Geo-redundant backup | Included | ~$10 |
| Application Insights | Pay-as-you-go | ~$5-10 |
| Key Vault | Standard | ~$0.50 |
| Log Analytics | Pay-as-you-go | ~$5-10 |
| **Total** | | **~$250-300** |

### Cost Optimization Tips

1. **Auto-shutdown for Dev/Staging**: Use Azure Automation to stop App Service and PostgreSQL during non-business hours
   - Potential savings: 50-70% for dev/staging environments

2. **Reserved Instances**: For production, consider 1-year or 3-year reserved instances
   - Potential savings: 30-50% on compute costs

3. **Right-sizing**: Monitor Application Insights metrics and adjust SKUs based on actual usage
   - Use `Standard_B1ms` for low-traffic scenarios
   - Scale up only when necessary

4. **Data Retention**: Adjust Application Insights and Log Analytics retention to minimize storage costs
   - Development: 30 days
   - Staging: 60 days
   - Production: 90 days (or as required by compliance)

5. **Storage Management**: Enable auto-grow for PostgreSQL but monitor usage
   - Start with minimum required storage
   - Let it grow based on actual usage

6. **Backup Optimization**: For non-production environments
   - Use minimum backup retention (7 days)
   - Disable geo-redundant backups

### Cost Monitoring

Set up cost alerts in Azure:

```bash
# Create cost alert for resource group
az consumption budget create \
  --resource-group petclinic-dev-rg \
  --budget-name petclinic-dev-budget \
  --amount 50 \
  --time-grain Monthly \
  --category Cost
```

## Post-Deployment Configuration

After successful deployment, complete these steps:

### 1. Deploy Application Code

```bash
# Build the application
./mvnw clean package -DskipTests

# Deploy to App Service
az webapp deployment source config-zip \
  --resource-group petclinic-dev-rg \
  --name app-petclinic-dev-abc123 \
  --src target/spring-petclinic-*.jar
```

### 2. Configure Custom Domain (Production)

```bash
# Add custom domain
az webapp config hostname add \
  --resource-group petclinic-prod-rg \
  --webapp-name app-petclinic-prod-abc123 \
  --hostname www.example.com

# Bind SSL certificate
az webapp config ssl bind \
  --resource-group petclinic-prod-rg \
  --name app-petclinic-prod-abc123 \
  --certificate-thumbprint {thumbprint} \
  --ssl-type SNI
```

### 3. Configure Autoscaling (Production)

```bash
# Create autoscale rule
az monitor autoscale create \
  --resource-group petclinic-prod-rg \
  --resource app-petclinic-prod-abc123 \
  --resource-type Microsoft.Web/serverfarms \
  --name petclinic-autoscale \
  --min-count 2 \
  --max-count 10 \
  --count 2

# Add scale-out rule (CPU > 70%)
az monitor autoscale rule create \
  --resource-group petclinic-prod-rg \
  --autoscale-name petclinic-autoscale \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 1
```

### 4. Configure Monitoring Alerts

Set up alerts for critical metrics:

```bash
# High CPU alert
az monitor metrics alert create \
  --name petclinic-high-cpu \
  --resource-group petclinic-prod-rg \
  --scopes /subscriptions/{sub}/resourceGroups/petclinic-prod-rg/providers/Microsoft.Web/sites/app-petclinic-prod-abc123 \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m

# Application errors alert
az monitor metrics alert create \
  --name petclinic-app-errors \
  --resource-group petclinic-prod-rg \
  --scopes /subscriptions/{sub}/resourceGroups/petclinic-prod-rg/providers/Microsoft.Insights/components/appi-petclinic-prod-abc123 \
  --condition "count exceptions/count > 10" \
  --window-size 5m
```

### 5. Initialize Database Schema

The Spring PetClinic application will automatically initialize the database schema on first startup when the PostgreSQL profile is active. Verify in Application Insights logs.

### 6. Verify Deployment

```bash
# Get the App Service URL
APP_URL=$(az deployment group show \
  --name petclinic-deployment \
  --resource-group petclinic-dev-rg \
  --query properties.outputs.appServiceUrl.value \
  --output tsv)

# Test the application
curl $APP_URL
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Deployment Fails with "Location not supported"

**Error**: `The location 'X' is not accepting resource creation for subscription 'Y'`

**Solution**: 
```bash
# List available locations for your subscription
az account list-locations --query "[?metadata.regionType=='Physical'].name" -o table

# Use a different location
./deploy.sh -e dev -g petclinic-dev-rg -l westus2 -p 'Password123!'
```

#### 2. PostgreSQL Connection Timeout

**Error**: Application logs show database connection timeouts

**Solution**:
1. Check if App Service can reach PostgreSQL:
   ```bash
   # Enable PostgreSQL diagnostics
   az postgres flexible-server parameter set \
     --resource-group petclinic-dev-rg \
     --server-name psql-petclinic-dev-abc123 \
     --name log_connections \
     --value on
   ```

2. Verify network configuration:
   ```bash
   # Check if public access is needed
   az postgres flexible-server update \
     --resource-group petclinic-dev-rg \
     --name psql-petclinic-dev-abc123 \
     --public-access Enabled
   ```

3. Add firewall rule for Azure services:
   ```bash
   az postgres flexible-server firewall-rule create \
     --resource-group petclinic-dev-rg \
     --name psql-petclinic-dev-abc123 \
     --rule-name AllowAzureServices \
     --start-ip-address 0.0.0.0 \
     --end-ip-address 0.0.0.0
   ```

#### 3. Application Not Starting

**Error**: App Service shows "Application Error"

**Solution**:
1. Check application logs:
   ```bash
   az webapp log tail \
     --resource-group petclinic-dev-rg \
     --name app-petclinic-dev-abc123
   ```

2. Verify environment variables:
   ```bash
   az webapp config appsettings list \
     --resource-group petclinic-dev-rg \
     --name app-petclinic-dev-abc123 \
     --output table
   ```

3. Check if the JAR file was deployed correctly:
   ```bash
   az webapp deployment list \
     --resource-group petclinic-dev-rg \
     --name app-petclinic-dev-abc123
   ```

#### 4. Key Vault Access Denied

**Error**: App Service cannot access Key Vault secrets

**Solution**:
1. Verify managed identity is enabled:
   ```bash
   az webapp identity show \
     --resource-group petclinic-dev-rg \
     --name app-petclinic-dev-abc123
   ```

2. Check RBAC assignment:
   ```bash
   az role assignment list \
     --scope /subscriptions/{sub}/resourceGroups/petclinic-dev-rg/providers/Microsoft.KeyVault/vaults/kv-petclinic-dev-abc12 \
     --output table
   ```

3. Manually assign the role if needed:
   ```bash
   PRINCIPAL_ID=$(az webapp identity show \
     --resource-group petclinic-dev-rg \
     --name app-petclinic-dev-abc123 \
     --query principalId \
     --output tsv)

   az role assignment create \
     --role "Key Vault Secrets User" \
     --assignee $PRINCIPAL_ID \
     --scope /subscriptions/{sub}/resourceGroups/petclinic-dev-rg/providers/Microsoft.KeyVault/vaults/kv-petclinic-dev-abc12
   ```

#### 5. Insufficient Permissions

**Error**: `The client 'X' does not have authorization to perform action 'Y'`

**Solution**:
1. Verify your Azure role:
   ```bash
   az role assignment list --assignee $(az account show --query user.name -o tsv)
   ```

2. Required roles:
   - Contributor (minimum) for resource creation
   - User Access Administrator or Owner for RBAC assignments

3. Request appropriate permissions from your Azure administrator

#### 6. Resource Name Already Exists

**Error**: `Resource name 'X' already exists`

**Solution**:
```bash
# Use a different base name
./deploy.sh -e dev -g petclinic-dev-rg -n petclinic2 -p 'Password123!'

# Or delete existing resources
az group delete --name petclinic-dev-rg --yes
```

#### 7. Deployment Takes Too Long

**Symptom**: Deployment script runs for more than 20 minutes

**Solution**:
1. Check deployment status:
   ```bash
   az deployment group list \
     --resource-group petclinic-dev-rg \
     --output table
   ```

2. PostgreSQL server creation is typically the slowest (5-10 minutes)
3. High availability configuration adds additional time
4. Be patient - typical deployment: 10-15 minutes

#### 8. Application Insights Not Receiving Data

**Symptom**: No telemetry in Application Insights

**Solution**:
1. Verify connection string:
   ```bash
   az webapp config appsettings list \
     --resource-group petclinic-dev-rg \
     --name app-petclinic-dev-abc123 \
     --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"
   ```

2. Check if Application Insights agent is loaded:
   ```bash
   # Look for Application Insights in app logs
   az webapp log tail \
     --resource-group petclinic-dev-rg \
     --name app-petclinic-dev-abc123 | grep -i "ApplicationInsights"
   ```

3. Data may take 2-5 minutes to appear after application starts

### Getting Help

If you encounter issues not covered here:

1. **Check Azure Status**: [Azure Status Dashboard](https://status.azure.com/)
2. **Review Deployment Logs**: 
   ```bash
   az deployment group show \
     --name petclinic-deployment \
     --resource-group petclinic-dev-rg \
     --query properties.error
   ```
3. **Azure Support**: Create a support ticket in the Azure Portal
4. **Community**: [Azure Community Support](https://azure.microsoft.com/support/community/)

### Useful Diagnostic Commands

```bash
# View all resources in resource group
az resource list --resource-group petclinic-dev-rg --output table

# Check resource health
az resource list \
  --resource-group petclinic-dev-rg \
  --query "[].{Name:name, Type:type, Location:location}" \
  --output table

# View activity log for recent operations
az monitor activity-log list \
  --resource-group petclinic-dev-rg \
  --start-time 2024-01-01T00:00:00Z \
  --output table

# Check App Service diagnostics
az webapp show \
  --resource-group petclinic-dev-rg \
  --name app-petclinic-dev-abc123 \
  --query "{State:state, Outbound:outboundIpAddresses, Platform:kind}"
```

## Additional Resources

- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure Database for PostgreSQL Documentation](https://docs.microsoft.com/azure/postgresql/)
- [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Spring Boot on Azure](https://docs.microsoft.com/azure/developer/java/spring-framework/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)

## Contributing

To improve these templates:

1. Make changes to the Bicep files
2. Test deployments in a development environment
3. Update this README with any new parameters or resources
4. Submit a pull request with your improvements

## License

This infrastructure code follows the same license as the Spring PetClinic application.
