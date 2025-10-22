#!/bin/bash
# Azure Infrastructure Deployment Script for Spring PetClinic
# Usage: ./deploy.sh <environment> <resource-group-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
RESOURCE_GROUP=${2:-petclinic-rg-$ENVIRONMENT}
LOCATION=${3:-eastus}
DB_ADMIN_PASSWORD=${POSTGRES_ADMIN_PASSWORD:-}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Spring PetClinic - Azure Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
echo -e "${YELLOW}Checking Azure login status...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in. Initiating Azure login...${NC}"
    az login
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✓ Using subscription: $SUBSCRIPTION_ID${NC}"
echo ""

# Validate database password
if [ -z "$DB_ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Database admin password not set in environment variable POSTGRES_ADMIN_PASSWORD${NC}"
    read -s -p "Enter PostgreSQL admin password: " DB_ADMIN_PASSWORD
    echo ""
    if [ -z "$DB_ADMIN_PASSWORD" ]; then
        echo -e "${RED}Error: Password cannot be empty${NC}"
        exit 1
    fi
fi

# Create resource group
echo -e "${YELLOW}Creating resource group...${NC}"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

echo -e "${GREEN}✓ Resource group created${NC}"
echo ""

# Deploy infrastructure
echo -e "${YELLOW}Deploying Azure infrastructure...${NC}"
echo "This may take 5-10 minutes..."
echo ""

DEPLOYMENT_NAME="petclinic-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file main.bicep \
  --parameters environmentName="$ENVIRONMENT" \
               dbAdminLogin=petclinicadmin \
               dbAdminPassword="$DB_ADMIN_PASSWORD" \
  --output table

echo -e "${GREEN}✓ Infrastructure deployment complete${NC}"
echo ""

# Get deployment outputs
echo -e "${YELLOW}Retrieving deployment outputs...${NC}"

APP_SERVICE_NAME=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.appServiceName.value -o tsv)

APP_SERVICE_URL=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.appServiceUrl.value -o tsv)

POSTGRES_SERVER=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.postgresServerName.value -o tsv)

ACR_LOGIN_SERVER=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.containerRegistryLoginServer.value -o tsv)

APP_INSIGHTS_KEY=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.appInsightsInstrumentationKey.value -o tsv)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "App Service Name: $APP_SERVICE_NAME"
echo "App Service URL: $APP_SERVICE_URL"
echo "PostgreSQL Server: $POSTGRES_SERVER"
echo "Container Registry: $ACR_LOGIN_SERVER"
echo "Application Insights Key: $APP_INSIGHTS_KEY"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Build and push container image:"
echo "   az acr build --registry $ACR_LOGIN_SERVER --image petclinic:latest ."
echo ""
echo "2. Configure App Service to use the image:"
echo "   az webapp config container set \\"
echo "     --name $APP_SERVICE_NAME \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --docker-custom-image-name $ACR_LOGIN_SERVER/petclinic:latest"
echo ""
echo "3. Access your application at: $APP_SERVICE_URL"
echo ""
echo -e "${GREEN}========================================${NC}"
