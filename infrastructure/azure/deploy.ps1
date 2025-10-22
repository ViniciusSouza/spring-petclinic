# Deployment script for Spring PetClinic Azure Infrastructure
# This script deploys the Bicep template to Azure using Azure PowerShell

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$BaseName = "petclinic",

    [Parameter(Mandatory=$false)]
    [SecureString]$PostgresPassword,

    [Parameter(Mandatory=$false)]
    [string]$ParametersFile = "parameters.json",

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Function to write colored messages
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if Azure PowerShell is installed
function Test-AzurePowerShell {
    try {
        $azModule = Get-Module -Name Az -ListAvailable
        if ($null -eq $azModule) {
            Write-ErrorMessage "Azure PowerShell (Az module) is not installed."
            Write-ErrorMessage "Please install it: Install-Module -Name Az -Repository PSGallery -Force"
            exit 1
        }
        Write-Info "Azure PowerShell is installed: $($azModule[0].Version)"
    }
    catch {
        Write-ErrorMessage "Error checking Azure PowerShell installation: $_"
        exit 1
    }
}

# Function to check if logged in to Azure
function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if ($null -eq $context) {
            Write-ErrorMessage "Not logged in to Azure. Please run 'Connect-AzAccount' first."
            exit 1
        }
        Write-Info "Logged in to Azure subscription: $($context.Subscription.Name)"
    }
    catch {
        Write-ErrorMessage "Not logged in to Azure. Please run 'Connect-AzAccount' first."
        exit 1
    }
}

# Main script
Write-Info "============================================"
Write-Info "Azure Deployment Configuration"
Write-Info "============================================"
Write-Info "Environment: $Environment"
Write-Info "Location: $Location"
Write-Info "Resource Group: $ResourceGroup"
Write-Info "Base Name: $BaseName"
Write-Info "Parameters File: $ParametersFile"
Write-Info "What-If Mode: $($WhatIf.IsPresent)"
Write-Info "============================================"

# Check prerequisites
Write-Info "Checking prerequisites..."
Test-AzurePowerShell
Test-AzureLogin

# Get or prompt for PostgreSQL password
if (-not $PostgresPassword) {
    if ($env:POSTGRES_ADMIN_PASSWORD) {
        $PostgresPassword = ConvertTo-SecureString $env:POSTGRES_ADMIN_PASSWORD -AsPlainText -Force
        Write-Info "Using password from POSTGRES_ADMIN_PASSWORD environment variable"
    }
    else {
        $PostgresPassword = Read-Host "Enter PostgreSQL admin password" -AsSecureString
    }
}

# Validate password length
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PostgresPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
if ($PlainPassword.Length -lt 8) {
    Write-ErrorMessage "PostgreSQL password must be at least 8 characters long"
    exit 1
}
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Create resource group if it doesn't exist
Write-Info "Ensuring resource group exists..."
$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if ($null -eq $rg) {
    Write-Info "Creating resource group: $ResourceGroup"
    New-AzResourceGroup -Name $ResourceGroup -Location $Location | Out-Null
}
else {
    Write-Info "Resource group already exists: $ResourceGroup"
}

# Prepare deployment name
$deploymentName = "petclinic-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Build deployment parameters
$deploymentParams = @{
    Name = $deploymentName
    ResourceGroupName = $ResourceGroup
    TemplateFile = "main.bicep"
    environment = $Environment
    location = $Location
    baseName = $BaseName
    postgresAdminPassword = $PostgresPassword
}

# Add parameters file if it exists
if (Test-Path $ParametersFile) {
    Write-Info "Using parameters file: $ParametersFile"
    $deploymentParams.TemplateParameterFile = $ParametersFile
}

# Run what-if or deploy
try {
    if ($WhatIf) {
        Write-Info "Running what-if analysis..."
        $whatIfResult = New-AzResourceGroupDeployment @deploymentParams -WhatIf
        Write-Info "What-if analysis completed"
    }
    else {
        Write-Info "Starting deployment: $deploymentName"
        Write-Warning "This may take 10-15 minutes..."
        
        # Deploy
        $deployment = New-AzResourceGroupDeployment @deploymentParams -Verbose
        
        # Display outputs
        Write-Info "Deployment completed successfully!"
        Write-Info "============================================"
        Write-Info "Deployment Outputs:"
        Write-Info "============================================"
        
        $deployment.Outputs | Format-Table -Property @{
            Label = "Output Name"
            Expression = { $_.Key }
        }, @{
            Label = "Value"
            Expression = { $_.Value.Value }
        }
        
        # Get App Service URL
        $appServiceUrl = $deployment.Outputs["appServiceUrl"].Value
        
        Write-Info "============================================"
        Write-Info "Application URL: $appServiceUrl"
        Write-Info "============================================"
        Write-Info "Next steps:"
        Write-Info "1. Deploy your application to the App Service"
        Write-Info "2. Configure custom domain and SSL (for production)"
        Write-Info "3. Review Application Insights for monitoring"
        Write-Info "============================================"
    }
}
catch {
    Write-ErrorMessage "Deployment failed: $_"
    Write-ErrorMessage $_.Exception.Message
    exit 1
}

Write-Info "Script completed successfully!"
