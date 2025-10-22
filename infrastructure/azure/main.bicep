// Main Bicep template for deploying Spring PetClinic to Azure
// This template provisions Azure App Service, PostgreSQL Flexible Server, and supporting resources

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name for all resources (will be combined with environment)')
@minLength(3)
@maxLength(20)
param baseName string = 'petclinic'

@description('PostgreSQL administrator login')
@minLength(1)
param postgresAdminLogin string = 'petclinicadmin'

@description('PostgreSQL administrator password')
@secure()
@minLength(8)
param postgresAdminPassword string

@description('PostgreSQL database name')
param postgresDatabaseName string = 'petclinic'

@description('PostgreSQL server SKU')
@allowed([
  'Standard_B1ms'  // Burstable, 1 vCore, 2 GiB RAM - for dev
  'Standard_B2s'   // Burstable, 2 vCore, 4 GiB RAM - for staging
  'Standard_D2ds_v4' // General Purpose, 2 vCore, 8 GiB RAM - for prod
  'Standard_D4ds_v4' // General Purpose, 4 vCore, 16 GiB RAM - for large prod
])
param postgresSku string = 'Standard_B1ms'

@description('PostgreSQL storage size in GB')
@minValue(32)
@maxValue(16384)
param postgresStorageSizeGB int = 32

@description('App Service Plan SKU')
@allowed([
  'B1'  // Basic, 1 core, 1.75 GB RAM - for dev
  'B2'  // Basic, 2 cores, 3.5 GB RAM - for staging
  'P1V2' // Premium V2, 1 core, 3.5 GB RAM - for prod
  'P2V2' // Premium V2, 2 cores, 7 GB RAM - for large prod
])
param appServiceSku string = 'B1'

@description('Application Insights retention in days')
@minValue(30)
@maxValue(730)
param appInsightsRetentionDays int = 30

@description('Enable public access to PostgreSQL')
param enablePostgresPublicAccess bool = false

@description('Tags to apply to all resources')
param tags object = {
  application: 'spring-petclinic'
  environment: environment
}

// Variables for resource naming
var resourceSuffix = '${baseName}-${environment}-${uniqueString(resourceGroup().id)}'
var appServicePlanName = 'asp-${resourceSuffix}'
var appServiceName = 'app-${resourceSuffix}'
var postgresServerName = 'psql-${resourceSuffix}'
var appInsightsName = 'appi-${resourceSuffix}'
var logAnalyticsName = 'log-${resourceSuffix}'
var keyVaultName = 'kv-${take(resourceSuffix, 24)}' // Key Vault names max 24 chars

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: appInsightsRetentionDays
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: appInsightsRetentionDays
  }
}

// Key Vault for storing secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: postgresServerName
  location: location
  tags: tags
  sku: {
    name: postgresSku
    tier: startsWith(postgresSku, 'Standard_B') ? 'Burstable' : 'GeneralPurpose'
  }
  properties: {
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    version: '16'
    storage: {
      storageSizeGB: postgresStorageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: environment == 'prod' ? 35 : 7
      geoRedundantBackup: environment == 'prod' ? 'Enabled' : 'Disabled'
    }
    highAvailability: {
      mode: environment == 'prod' ? 'ZoneRedundant' : 'Disabled'
    }
  }
}

// PostgreSQL Database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgresServer
  name: postgresDatabaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL Firewall Rule (if public access is enabled)
resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = if (enablePostgresPublicAccess) {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServiceSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'JAVA|17-java17'
      alwaysOn: environment != 'dev'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'SPRING_PROFILES_ACTIVE'
          value: 'postgres,azure'
        }
        {
          name: 'POSTGRES_HOST'
          value: postgresServer.properties.fullyQualifiedDomainName
        }
        {
          name: 'POSTGRES_PORT'
          value: '5432'
        }
        {
          name: 'POSTGRES_DATABASE'
          value: postgresDatabaseName
        }
        {
          name: 'POSTGRES_USER'
          value: postgresAdminLogin
        }
        {
          name: 'POSTGRES_PASSWORD'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/postgres-password/)'
        }
        {
          name: 'JAVA_OPTS'
          value: '-Xms512m -Xmx1024m'
        }
      ]
    }
  }
}

// Store PostgreSQL password in Key Vault
resource postgresPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'postgres-password'
  properties: {
    value: postgresAdminPassword
  }
}

// Grant App Service access to Key Vault
resource keyVaultAccessPolicy 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appService.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output postgresServerName string = postgresServer.name
output postgresFqdn string = postgresServer.properties.fullyQualifiedDomainName
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output keyVaultName string = keyVault.name
output resourceGroupName string = resourceGroup().name
