# Azure Infrastructure Deployment Script for Spring PetClinic (PowerShell)
# Usage: .\deploy.ps1 -Environment dev -ResourceGroup petclinic-rg-dev

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "petclinic-rg-$Environment",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [SecureString]$DbAdminPassword
)

# Color output functions
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

Write-Success "========================================"
Write-Success "Spring PetClinic - Azure Deployment"
Write-Success "========================================"
Write-Host ""
Write-Host "Environment: $Environment"
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Location: $Location"
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = az version | ConvertFrom-Json
    Write-Success "✓ Azure CLI version: $($azVersion.'azure-cli')"
} catch {
    Write-Error "Error: Azure CLI is not installed"
    Write-Host "Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
Write-Info "Checking Azure login status..."
try {
    $account = az account show | ConvertFrom-Json
    $subscriptionId = $account.id
    Write-Success "✓ Using subscription: $subscriptionId"
} catch {
    Write-Info "Not logged in. Initiating Azure login..."
    az login
    $account = az account show | ConvertFrom-Json
    $subscriptionId = $account.id
    Write-Success "✓ Logged in to subscription: $subscriptionId"
}
Write-Host ""

# Get database password
if (-not $DbAdminPassword) {
    $DbAdminPassword = Read-Host "Enter PostgreSQL admin password" -AsSecureString
    if ($DbAdminPassword.Length -eq 0) {
        Write-Error "Error: Password cannot be empty"
        exit 1
    }
}

# Convert SecureString to plain text for az cli (will be passed securely)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DbAdminPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Create resource group
Write-Info "Creating resource group..."
az group create `
    --name $ResourceGroup `
    --location $Location `
    --output table

Write-Success "✓ Resource group created"
Write-Host ""

# Deploy infrastructure
Write-Info "Deploying Azure infrastructure..."
Write-Host "This may take 5-10 minutes..."
Write-Host ""

$deploymentName = "petclinic-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --name $deploymentName `
    --resource-group $ResourceGroup `
    --template-file main.bicep `
    --parameters environmentName=$Environment `
                 dbAdminLogin=petclinicadmin `
                 dbAdminPassword=$PlainPassword `
    --output table

Write-Success "✓ Infrastructure deployment complete"
Write-Host ""

# Get deployment outputs
Write-Info "Retrieving deployment outputs..."

$deployment = az deployment group show `
    --name $deploymentName `
    --resource-group $ResourceGroup | ConvertFrom-Json

$appServiceName = $deployment.properties.outputs.appServiceName.value
$appServiceUrl = $deployment.properties.outputs.appServiceUrl.value
$postgresServer = $deployment.properties.outputs.postgresServerName.value
$acrLoginServer = $deployment.properties.outputs.containerRegistryLoginServer.value
$appInsightsKey = $deployment.properties.outputs.appInsightsInstrumentationKey.value

Write-Host ""
Write-Success "========================================"
Write-Success "Deployment Summary"
Write-Success "========================================"
Write-Host ""
Write-Host "App Service Name: $appServiceName"
Write-Host "App Service URL: $appServiceUrl"
Write-Host "PostgreSQL Server: $postgresServer"
Write-Host "Container Registry: $acrLoginServer"
Write-Host "Application Insights Key: $appInsightsKey"
Write-Host ""
Write-Success "Next Steps:"
Write-Host "1. Build and push container image:"
Write-Host "   az acr build --registry $acrLoginServer --image petclinic:latest ."
Write-Host ""
Write-Host "2. Configure App Service to use the image:"
Write-Host "   az webapp config container set \"
Write-Host "     --name $appServiceName \"
Write-Host "     --resource-group $ResourceGroup \"
Write-Host "     --docker-custom-image-name $acrLoginServer/petclinic:latest"
Write-Host ""
Write-Host "3. Access your application at: $appServiceUrl"
Write-Host ""
Write-Success "========================================"

# Clear password from memory
$PlainPassword = $null
[System.GC]::Collect()
