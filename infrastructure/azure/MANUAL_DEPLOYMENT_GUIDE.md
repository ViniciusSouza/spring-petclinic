# Manual Deployment Guide - Step by Step

This guide walks you through deploying Spring PetClinic to Azure manually for testing purposes.

**Estimated time**: 30-45 minutes  
**Estimated cost**: ~$30/month (can stop resources when not in use)

## Prerequisites Check

Before starting, verify you have:

```powershell
# Check Azure CLI
az --version
# Should show version 2.50.0 or higher

# Check login status
az account show
# Should show your subscription

# Check Docker
docker --version
# Should show Docker version

# Check Java
java -version
# Should show Java 17 or higher
```

If not logged in to Azure:
```powershell
az login
az account set --subscription <your-subscription-id>
```

## Step 1: Add Azure Dependencies (5 minutes)

### Maven (pom.xml)

Open `pom.xml` and add inside the `<dependencies>` section:

```xml
<!-- Azure Spring Cloud BOM for version management -->
<dependency>
    <groupId>com.azure.spring</groupId>
    <artifactId>spring-cloud-azure-dependencies</artifactId>
    <version>5.18.0</version>
    <type>pom</type>
    <scope>import</scope>
</dependency>

<!-- Application Insights for monitoring -->
<dependency>
    <groupId>com.azure.spring</groupId>
    <artifactId>spring-cloud-azure-starter-monitor</artifactId>
    <version>5.18.0</version>
</dependency>
```

### Gradle (build.gradle)

Open `build.gradle` and add inside the `dependencies` section:

```gradle
// Azure Spring Cloud BOM
implementation platform('com.azure.spring:spring-cloud-azure-dependencies:5.18.0')

// Application Insights for monitoring
implementation 'com.azure.spring:spring-cloud-azure-starter-monitor'
```

### Validate Build

```powershell
# Test Maven build
./mvnw clean verify

# Test Gradle build (if using Gradle)
./gradlew clean build
```

✅ **Success**: Both builds should complete without errors.

## Step 2: Deploy Azure Infrastructure (10 minutes)

```powershell
# Navigate to infrastructure directory
cd infrastructure/azure

# Set parameters
$env:ENVIRONMENT = "dev"
$env:DB_PASSWORD = "PetClinic2025!"  # Use a strong password

# Run deployment
./deploy.ps1 dev

# The script will:
# 1. Create resource group: petclinic-rg-dev
# 2. Deploy Bicep template
# 3. Output resource names and connection strings

# IMPORTANT: Save the output values!
# You'll need:
# - App Service name
# - PostgreSQL server name
# - Container Registry name
# - Application Insights connection string
```

**Expected output**:
```
✅ Resource group created: petclinic-rg-dev
✅ Deploying Azure resources...
✅ Deployment complete!

Resource Information:
- App Service: petclinic-app-dev-abc123
- PostgreSQL: petclinic-db-dev-abc123
- Container Registry: petclinicacr123
- Application Insights: petclinic-ai-dev-abc123

Connection Strings:
- PostgreSQL: petclinic-db-dev-abc123.postgres.database.azure.com
- App Insights: InstrumentationKey=xxx-xxx-xxx
```

💡 **Tip**: Copy these values to a text file - you'll need them in the next steps.

## Step 3: Initialize PostgreSQL Database (5 minutes)

```powershell
# Return to project root
cd ..\..

# Get database server name from Step 2 output
$dbServer = "petclinic-db-dev-abc123"  # Replace with your value
$dbFQDN = "$dbServer.postgres.database.azure.com"
$dbPassword = "PetClinic2025!"  # Same password from Step 2

# Allow your IP address to access database
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
az postgres flexible-server firewall-rule create `
  --resource-group petclinic-rg-dev `
  --name $dbServer `
  --rule-name AllowMyIP `
  --start-ip-address $myIp `
  --end-ip-address $myIp

# Allow Azure services to access database
az postgres flexible-server firewall-rule create `
  --resource-group petclinic-rg-dev `
  --name $dbServer `
  --rule-name AllowAzureServices `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

# Wait for firewall rules to apply
Start-Sleep -Seconds 10

# Test database connection (requires psql installed)
# If you don't have psql, skip to next step - App Service will initialize DB
$env:PGPASSWORD = $dbPassword
psql -h $dbFQDN -U dbadmin -d petclinic -c "SELECT version();"

# If psql is available, initialize schema
psql -h $dbFQDN -U dbadmin -d petclinic -f src/main/resources/db/postgres/schema.sql
psql -h $dbFQDN -U dbadmin -d petclinic -f src/main/resources/db/postgres/data.sql
```

**Don't have psql?** No problem! You can:
1. Skip this step and let Spring Boot initialize the database on first run
2. Or use Azure Cloud Shell (has psql pre-installed)

## Step 4: Build and Push Docker Image (10 minutes)

```powershell
# Get ACR name from Step 2 output
$acrName = "petclinicacr123"  # Replace with your value

# Login to Azure Container Registry
az acr login --name $acrName

# Build Docker image locally
docker build -t ${acrName}.azurecr.io/spring-petclinic:latest .

# This will take 5-8 minutes (multi-stage build)
# You'll see Maven downloading dependencies and building the app

# Push image to ACR
docker push ${acrName}.azurecr.io/spring-petclinic:latest

# Verify image was pushed
az acr repository show `
  --name $acrName `
  --repository spring-petclinic
```

✅ **Success**: You should see image details with tag "latest"

## Step 5: Configure App Service (5 minutes)

```powershell
# Get values from Step 2 output
$appName = "petclinic-app-dev-abc123"  # Replace with your value
$dbServer = "petclinic-db-dev-abc123"  # Replace with your value
$dbPassword = "PetClinic2025!"
$appInsightsKey = "InstrumentationKey=xxx-xxx-xxx"  # Replace with your value

# Configure application settings
az webapp config appsettings set `
  --name $appName `
  --resource-group petclinic-rg-dev `
  --settings `
    SPRING_PROFILES_ACTIVE=azure `
    POSTGRES_URL="${dbServer}.postgres.database.azure.com:5432/petclinic" `
    POSTGRES_USER=dbadmin `
    POSTGRES_PASS=$dbPassword `
    APPLICATIONINSIGHTS_CONNECTION_STRING=$appInsightsKey `
    WEBSITES_PORT=8080 `
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Configure container settings
$acrName = "petclinicacr123"  # Replace with your value
az webapp config container set `
  --name $appName `
  --resource-group petclinic-rg-dev `
  --docker-custom-image-name ${acrName}.azurecr.io/spring-petclinic:latest `
  --docker-registry-server-url https://${acrName}.azurecr.io

# Enable container logging
az webapp log config `
  --name $appName `
  --resource-group petclinic-rg-dev `
  --docker-container-logging filesystem `
  --level information
```

## Step 6: Deploy and Verify (5 minutes)

```powershell
# Restart app to pick up new configuration
az webapp restart `
  --name $appName `
  --resource-group petclinic-rg-dev

Write-Host "⏳ Waiting for application to start (this takes 60-90 seconds)..."
Start-Sleep -Seconds 90

# Get app URL
$appUrl = "https://${appName}.azurewebsites.net"

Write-Host "🔍 Testing deployment at: $appUrl"

# Test health endpoint
try {
    $health = Invoke-RestMethod -Uri "$appUrl/actuator/health" -TimeoutSec 30
    if ($health.status -eq "UP") {
        Write-Host "✅ Application is healthy!"
    } else {
        Write-Host "⚠️  Application status: $($health.status)"
    }
} catch {
    Write-Host "❌ Health check failed. Checking logs..."
    az webapp log tail --name $appName --resource-group petclinic-rg-dev
}

# Test home page
try {
    $response = Invoke-WebRequest -Uri $appUrl -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Home page is accessible!"
    }
} catch {
    Write-Host "❌ Home page test failed: $_"
}

# Open in browser
Write-Host "🌐 Opening application in browser..."
Start-Process $appUrl
```

## Step 7: Verify All Features (5 minutes)

Open the application in your browser and test:

1. **Home Page** → Should show Welcome message ✅
2. **Veterinarians** (`/vets.html`) → Should list vets from database ✅
3. **Find Owners** (`/owners/find`) → Should show search form ✅
4. **Search "Davis"** → Should find owners ✅
5. **View Owner** → Should show pets and visits ✅
6. **Add New Owner** → Should save to database ✅
7. **Health Check** (`/actuator/health`) → Should return `{"status":"UP"}` ✅
8. **Metrics** (`/actuator/metrics`) → Should return metrics list ✅

## Step 8: Monitor with Application Insights (Optional)

```powershell
# Get Application Insights name
$aiName = "petclinic-ai-dev-abc123"  # Replace with your value

# Open Application Insights in portal
az monitor app-insights component show `
  --app $aiName `
  --resource-group petclinic-rg-dev `
  --query "id" -o tsv

# View live metrics in browser
$aiId = az monitor app-insights component show `
  --app $aiName `
  --resource-group petclinic-rg-dev `
  --query "id" -o tsv

$portalUrl = "https://portal.azure.com/#@/resource${aiId}/quickPulse"
Start-Process $portalUrl
```

In Application Insights, you should see:
- ✅ Request count increasing
- ✅ Response times
- ✅ Dependency calls (PostgreSQL)
- ✅ Server metrics (CPU, memory)

## Troubleshooting

### Application won't start

**Check logs**:
```powershell
az webapp log tail --name $appName --resource-group petclinic-rg-dev
```

**Common issues**:
1. **"Connection refused" to PostgreSQL**
   - Check firewall rules (Step 3)
   - Verify `POSTGRES_URL` is correct
   
2. **"Image not found"**
   - Verify ACR name is correct
   - Check image was pushed: `az acr repository list --name $acrName`

3. **"Application Insights connection failed"**
   - This is non-fatal, app will work without it
   - Verify `APPLICATIONINSIGHTS_CONNECTION_STRING` is correct

### Database connection issues

```powershell
# Test database connectivity from App Service
az webapp ssh --name $appName --resource-group petclinic-rg-dev

# Inside SSH session:
nc -zv $dbServer.postgres.database.azure.com 5432
```

### Check App Service status

```powershell
# Get app status
az webapp show `
  --name $appName `
  --resource-group petclinic-rg-dev `
  --query "state" -o tsv

# Should output: "Running"
```

## Cleanup (When Done Testing)

### Stop resources (to save costs)

```powershell
# Stop App Service
az webapp stop --name $appName --resource-group petclinic-rg-dev

# Stop PostgreSQL
az postgres flexible-server stop `
  --name $dbServer `
  --resource-group petclinic-rg-dev

Write-Host "✅ Resources stopped. No charges while stopped."
```

### Start resources again

```powershell
# Start App Service
az webapp start --name $appName --resource-group petclinic-rg-dev

# Start PostgreSQL
az postgres flexible-server start `
  --name $dbServer `
  --resource-group petclinic-rg-dev

Write-Host "✅ Resources started. Wait 60 seconds for app to be ready."
```

### Delete everything

```powershell
# Delete entire resource group (removes all resources)
az group delete --name petclinic-rg-dev --yes --no-wait

Write-Host "✅ Resource group deletion started. Will complete in 5-10 minutes."
```

## Quick Reference Commands

```powershell
# View all resources
az resource list --resource-group petclinic-rg-dev --output table

# View app logs
az webapp log tail --name $appName --resource-group petclinic-rg-dev

# View app URL
az webapp show --name $appName --resource-group petclinic-rg-dev --query "defaultHostName" -o tsv

# Restart app
az webapp restart --name $appName --resource-group petclinic-rg-dev

# View database connection info
az postgres flexible-server show `
  --name $dbServer `
  --resource-group petclinic-rg-dev `
  --query "{FQDN:fullyQualifiedDomainName, State:state}" -o table
```

## Success Criteria

After completing all steps, you should have:

- ✅ Application running at `https://$appName.azurewebsites.net`
- ✅ All pages working (home, vets, owners, pets)
- ✅ Database CRUD operations working
- ✅ Health check returning UP status
- ✅ Application Insights collecting telemetry
- ✅ Logs visible in Azure Portal

## Next Steps

After successful manual deployment:

1. **Test thoroughly** - Exercise all features
2. **Monitor costs** - Check Azure Cost Management
3. **Setup GitHub Actions** - Automate future deployments
4. **Add custom domain** - Configure custom DNS (optional)
5. **Configure SSL** - Use Let's Encrypt or Azure cert (optional)
6. **Setup staging slot** - For blue-green deployments (optional)

## Need Help?

- **Deployment errors**: Check `infrastructure/azure/README.md`
- **Application errors**: Check logs with `az webapp log tail`
- **Database errors**: Check `infrastructure/azure/SCHEMA_VALIDATION.md`
- **Monitoring**: Check `infrastructure/azure/APPLICATION_INSIGHTS.md`

---

**Estimated total time**: 30-45 minutes  
**Estimated monthly cost**: ~$30 (stop resources when not in use to reduce costs)

Good luck with your deployment! 🚀
