# Azure Infrastructure for Spring PetClinic

This directory contains Infrastructure as Code (IaC) for deploying Spring PetClinic to Azure.

## Architecture

The infrastructure includes:

- **Azure App Service** - Hosts the Spring Boot application (Linux, Java 17)
- **Azure Database for PostgreSQL Flexible Server** - Managed PostgreSQL database
- **Azure Container Registry** - Stores container images
- **Application Insights** - Application monitoring and telemetry
- **Log Analytics Workspace** - Centralized logging
- **Managed Identity** - Secure authentication between services

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

## Resource Naming Convention

Resources are named using this pattern:  
`{applicationName}-{resourceType}-{environment}-{uniqueSuffix}`

Example:
- App Service: `petclinic-app-dev-abc123`
- PostgreSQL: `petclinic-db-dev-abc123`
- ACR: `petclinicacrdevabc123` (alphanumeric only)

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

### Issue: Deployment fails with "InvalidTemplateDeployment"
**Solution**: Check parameter values and ensure they meet Azure naming requirements

### Issue: Cannot connect to PostgreSQL
**Solution**: 
1. Verify firewall rules are configured
2. Check connection string includes `?sslmode=require`
3. Verify credentials are correct

### Issue: App Service shows "Application Error"
**Solution**:
1. Check Application Insights for errors
2. View App Service logs: `az webapp log tail --name <app-name> --resource-group <rg>`
3. Verify all environment variables are set correctly

### Issue: Container image not pulling
**Solution**:
1. Verify Managed Identity has AcrPull role (assigned automatically)
2. Check ACR admin is enabled
3. Verify image tag exists in registry

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
