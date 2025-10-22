#!/bin/bash
# Deployment script for Spring PetClinic Azure Infrastructure
# This script deploys the Bicep template to Azure using Azure CLI

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Azure CLI is installed
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_info "Azure CLI is installed: $(az version --query '\"azure-cli\"' -o tsv)"
}

# Function to check if logged in to Azure
check_azure_login() {
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    local account_name=$(az account show --query name -o tsv)
    print_info "Logged in to Azure subscription: $account_name"
}

# Parse command line arguments
ENVIRONMENT="dev"
LOCATION="eastus"
RESOURCE_GROUP=""
BASE_NAME="petclinic"
POSTGRES_PASSWORD=""
PARAMETERS_FILE="parameters.json"
WHAT_IF=false

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Spring PetClinic infrastructure to Azure using Bicep templates.

OPTIONS:
    -e, --environment ENV       Environment (dev, staging, prod). Default: dev
    -l, --location LOCATION     Azure region. Default: eastus
    -g, --resource-group RG     Resource group name (required)
    -n, --name NAME            Base name for resources. Default: petclinic
    -p, --password PASSWORD    PostgreSQL admin password (required, or set POSTGRES_ADMIN_PASSWORD env var)
    -f, --parameters-file FILE Parameters file. Default: parameters.json
    -w, --what-if              Run what-if analysis without deploying
    -h, --help                 Show this help message

EXAMPLES:
    # Deploy to dev environment
    $0 -e dev -g petclinic-dev-rg -p 'MySecurePassword123!'

    # Deploy to production with custom location
    $0 -e prod -g petclinic-prod-rg -l westus2 -p 'MySecurePassword123!'

    # Run what-if analysis
    $0 -e dev -g petclinic-dev-rg -p 'MySecurePassword123!' --what-if

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -n|--name)
            BASE_NAME="$2"
            shift 2
            ;;
        -p|--password)
            POSTGRES_PASSWORD="$2"
            shift 2
            ;;
        -f|--parameters-file)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        -w|--what-if)
            WHAT_IF=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ]; then
    print_error "Resource group is required. Use -g or --resource-group"
    usage
fi

# Check for password in environment variable if not provided
if [ -z "$POSTGRES_PASSWORD" ]; then
    if [ -n "$POSTGRES_ADMIN_PASSWORD" ]; then
        POSTGRES_PASSWORD="$POSTGRES_ADMIN_PASSWORD"
    else
        print_error "PostgreSQL admin password is required. Use -p or set POSTGRES_ADMIN_PASSWORD environment variable"
        exit 1
    fi
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Environment must be one of: dev, staging, prod"
    exit 1
fi

# Validate password complexity
if [ ${#POSTGRES_PASSWORD} -lt 8 ]; then
    print_error "PostgreSQL password must be at least 8 characters long"
    exit 1
fi

print_info "============================================"
print_info "Azure Deployment Configuration"
print_info "============================================"
print_info "Environment: $ENVIRONMENT"
print_info "Location: $LOCATION"
print_info "Resource Group: $RESOURCE_GROUP"
print_info "Base Name: $BASE_NAME"
print_info "Parameters File: $PARAMETERS_FILE"
print_info "What-If Mode: $WHAT_IF"
print_info "============================================"

# Check prerequisites
print_info "Checking prerequisites..."
check_azure_cli
check_azure_login

# Create resource group if it doesn't exist
print_info "Ensuring resource group exists..."
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_info "Creating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
else
    print_info "Resource group already exists: $RESOURCE_GROUP"
fi

# Prepare deployment name
DEPLOYMENT_NAME="petclinic-deployment-$(date +%Y%m%d-%H%M%S)"

# Build deployment command
DEPLOYMENT_ARGS=(
    "group"
    "deployment"
    "name" "$DEPLOYMENT_NAME"
    "resource-group" "$RESOURCE_GROUP"
    "template-file" "main.bicep"
)

# Add parameters
DEPLOYMENT_ARGS+=(
    "parameters" "environment=$ENVIRONMENT"
    "parameters" "location=$LOCATION"
    "parameters" "baseName=$BASE_NAME"
    "parameters" "postgresAdminPassword=$POSTGRES_PASSWORD"
)

# Add parameters file if it exists
if [ -f "$PARAMETERS_FILE" ]; then
    print_info "Using parameters file: $PARAMETERS_FILE"
    DEPLOYMENT_ARGS+=("parameters" "@$PARAMETERS_FILE")
fi

# Run what-if or deploy
if [ "$WHAT_IF" = true ]; then
    print_info "Running what-if analysis..."
    az deployment "${DEPLOYMENT_ARGS[@]}" what-if
    print_info "What-if analysis completed"
else
    print_info "Starting deployment: $DEPLOYMENT_NAME"
    print_warning "This may take 10-15 minutes..."
    
    # Deploy with progress indicator
    az deployment "${DEPLOYMENT_ARGS[@]}" create --verbose
    
    # Get deployment outputs
    print_info "Deployment completed successfully!"
    print_info "============================================"
    print_info "Deployment Outputs:"
    print_info "============================================"
    
    az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query properties.outputs \
        --output table
    
    # Get App Service URL
    APP_SERVICE_URL=$(az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query properties.outputs.appServiceUrl.value \
        --output tsv)
    
    print_info "============================================"
    print_info "Application URL: $APP_SERVICE_URL"
    print_info "============================================"
    print_info "Next steps:"
    print_info "1. Deploy your application to the App Service"
    print_info "2. Configure custom domain and SSL (for production)"
    print_info "3. Review Application Insights for monitoring"
    print_info "============================================"
fi

print_info "Script completed successfully!"
