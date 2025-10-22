# Manual Deployment Helper Script
# This script guides you through manual deployment with validation at each step

param(
    [string]$Environment = "dev",
    [string]$DbPassword = ""
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Spring PetClinic - Manual Azure Deployment" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Azure CLI
    try {
        $azVersion = az --version 2>&1 | Select-String "azure-cli" | Select-Object -First 1
        Write-Host "✅ Azure CLI: $azVersion" -ForegroundColor Green
    } catch {
        Write-Host "❌ Azure CLI not found. Install from: https://aka.ms/installazurecliwindows" -ForegroundColor Red
        exit 1
    }
    
    # Check Azure login
    try {
        $account = az account show 2>&1 | ConvertFrom-Json
        Write-Host "✅ Logged in to Azure as: $($account.user.name)" -ForegroundColor Green
        Write-Host "   Subscription: $($account.name)" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Not logged in to Azure. Run: az login" -ForegroundColor Red
        exit 1
    }
    
    # Check Docker
    try {
        $dockerVersion = docker --version
        Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
    } catch {
        Write-Host "❌ Docker not found. Install from: https://www.docker.com/products/docker-desktop" -ForegroundColor Red
        exit 1
    }
    
    # Check Java
    try {
        $javaVersion = java -version 2>&1 | Select-String "version" | Select-Object -First 1
        Write-Host "✅ Java: $javaVersion" -ForegroundColor Green
    } catch {
        Write-Host "❌ Java not found. Install JDK 17+: https://adoptium.net/" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
}

# Function to prompt for password
function Get-DatabasePassword {
    if ([string]::IsNullOrEmpty($DbPassword)) {
        Write-Host "🔐 Database Password Setup" -ForegroundColor Yellow
        Write-Host "Please enter a password for PostgreSQL admin user." -ForegroundColor Gray
        Write-Host "Requirements: 8+ chars, uppercase, lowercase, number, special char" -ForegroundColor Gray
        $securePassword = Read-Host "Password" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        return $password
    }
    return $DbPassword
}

# Main deployment flow
try {
    # Step 0: Prerequisites
    Test-Prerequisites
    
    # Step 1: Get database password
    $dbPassword = Get-DatabasePassword
    Write-Host "✅ Password configured" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: Confirm deployment
    Write-Host "📦 Ready to deploy to Azure" -ForegroundColor Yellow
    Write-Host "Environment: $Environment" -ForegroundColor Gray
    Write-Host "Resource Group: petclinic-rg-$Environment" -ForegroundColor Gray
    Write-Host "Estimated Cost: ~`$30/month" -ForegroundColor Gray
    Write-Host ""
    $confirm = Read-Host "Continue with deployment? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "❌ Deployment cancelled" -ForegroundColor Red
        exit 0
    }
    Write-Host ""
    
    # Step 3: Build application
    Write-Host "🔨 Step 1/6: Building application..." -ForegroundColor Cyan
    Write-Host "This will take 2-3 minutes..." -ForegroundColor Gray
    & ./mvnw clean package -DskipTests
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed. Check errors above." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Application built successfully" -ForegroundColor Green
    Write-Host ""
    
    # Step 4: Deploy infrastructure
    Write-Host "☁️  Step 2/6: Deploying Azure infrastructure..." -ForegroundColor Cyan
    Write-Host "This will take 5-10 minutes..." -ForegroundColor Gray
    
    Set-Location infrastructure/azure
    
    $deployOutput = & ./deploy.ps1 $Environment 2>&1
    Write-Host $deployOutput
    
    # Parse output to get resource names
    $appName = ($deployOutput | Select-String "App Service:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
    $dbServer = ($deployOutput | Select-String "PostgreSQL:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
    $acrName = ($deployOutput | Select-String "Container Registry:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
    $aiName = ($deployOutput | Select-String "Application Insights:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
    
    Set-Location ../..
    
    if ([string]::IsNullOrEmpty($appName)) {
        Write-Host "❌ Infrastructure deployment failed. Check errors above." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Infrastructure deployed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Resource Names (save these):" -ForegroundColor Yellow
    Write-Host "   App Service: $appName" -ForegroundColor Gray
    Write-Host "   PostgreSQL: $dbServer" -ForegroundColor Gray
    Write-Host "   Container Registry: $acrName" -ForegroundColor Gray
    Write-Host "   Application Insights: $aiName" -ForegroundColor Gray
    Write-Host ""
    
    # Step 5: Configure database firewall
    Write-Host "🔒 Step 3/6: Configuring database firewall..." -ForegroundColor Cyan
    
    # Get public IP
    $myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
    Write-Host "Your IP: $myIp" -ForegroundColor Gray
    
    # Allow my IP
    az postgres flexible-server firewall-rule create `
        --resource-group "petclinic-rg-$Environment" `
        --name $dbServer `
        --rule-name "AllowMyIP" `
        --start-ip-address $myIp `
        --end-ip-address $myIp `
        --output none
    
    # Allow Azure services
    az postgres flexible-server firewall-rule create `
        --resource-group "petclinic-rg-$Environment" `
        --name $dbServer `
        --rule-name "AllowAzureServices" `
        --start-ip-address "0.0.0.0" `
        --end-ip-address "0.0.0.0" `
        --output none
    
    Write-Host "✅ Database firewall configured" -ForegroundColor Green
    Write-Host ""
    
    # Step 6: Build and push Docker image
    Write-Host "🐳 Step 4/6: Building and pushing Docker image..." -ForegroundColor Cyan
    Write-Host "This will take 5-8 minutes..." -ForegroundColor Gray
    
    # Login to ACR
    az acr login --name $acrName
    
    # Build image
    docker build -t "${acrName}.azurecr.io/spring-petclinic:latest" .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker build failed" -ForegroundColor Red
        exit 1
    }
    
    # Push image
    docker push "${acrName}.azurecr.io/spring-petclinic:latest"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker push failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Docker image built and pushed" -ForegroundColor Green
    Write-Host ""
    
    # Step 7: Configure App Service
    Write-Host "⚙️  Step 5/6: Configuring App Service..." -ForegroundColor Cyan
    
    # Get Application Insights connection string
    $aiConnString = az monitor app-insights component show `
        --app $aiName `
        --resource-group "petclinic-rg-$Environment" `
        --query "connectionString" -o tsv
    
    # Configure app settings
    az webapp config appsettings set `
        --name $appName `
        --resource-group "petclinic-rg-$Environment" `
        --settings `
            SPRING_PROFILES_ACTIVE=azure `
            POSTGRES_URL="${dbServer}.postgres.database.azure.com:5432/petclinic" `
            POSTGRES_USER=dbadmin `
            POSTGRES_PASS=$dbPassword `
            APPLICATIONINSIGHTS_CONNECTION_STRING=$aiConnString `
            WEBSITES_PORT=8080 `
            JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0" `
        --output none
    
    # Configure container
    az webapp config container set `
        --name $appName `
        --resource-group "petclinic-rg-$Environment" `
        --docker-custom-image-name "${acrName}.azurecr.io/spring-petclinic:latest" `
        --docker-registry-server-url "https://${acrName}.azurecr.io" `
        --output none
    
    # Enable logging
    az webapp log config `
        --name $appName `
        --resource-group "petclinic-rg-$Environment" `
        --docker-container-logging filesystem `
        --level information `
        --output none
    
    Write-Host "✅ App Service configured" -ForegroundColor Green
    Write-Host ""
    
    # Step 8: Deploy and verify
    Write-Host "🚀 Step 6/6: Deploying application..." -ForegroundColor Cyan
    
    # Restart app
    az webapp restart --name $appName --resource-group "petclinic-rg-$Environment" --output none
    
    Write-Host "⏳ Waiting for application to start (90 seconds)..." -ForegroundColor Gray
    Start-Sleep -Seconds 90
    
    # Get app URL
    $appUrl = "https://${appName}.azurewebsites.net"
    
    Write-Host "🔍 Testing deployment..." -ForegroundColor Yellow
    
    # Test health endpoint
    $healthOk = $false
    for ($i = 1; $i -le 5; $i++) {
        try {
            $health = Invoke-RestMethod -Uri "$appUrl/actuator/health" -TimeoutSec 30
            if ($health.status -eq "UP") {
                Write-Host "✅ Health check passed!" -ForegroundColor Green
                $healthOk = $true
                break
            }
        } catch {
            Write-Host "   Attempt $i/5: Waiting for application..." -ForegroundColor Gray
            Start-Sleep -Seconds 20
        }
    }
    
    if (-not $healthOk) {
        Write-Host "⚠️  Health check timed out. Application may still be starting." -ForegroundColor Yellow
        Write-Host "   Check logs: az webapp log tail --name $appName --resource-group petclinic-rg-$Environment" -ForegroundColor Gray
    }
    
    # Test home page
    try {
        $response = Invoke-WebRequest -Uri $appUrl -TimeoutSec 30
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Home page accessible!" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️  Home page test failed" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "🎉 Deployment Complete!" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📱 Application URL:" -ForegroundColor Yellow
    Write-Host "   $appUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔗 Quick Links:" -ForegroundColor Yellow
    Write-Host "   Home Page:        $appUrl/" -ForegroundColor Gray
    Write-Host "   Veterinarians:    $appUrl/vets.html" -ForegroundColor Gray
    Write-Host "   Find Owners:      $appUrl/owners/find" -ForegroundColor Gray
    Write-Host "   Health Check:     $appUrl/actuator/health" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📊 Management:" -ForegroundColor Yellow
    Write-Host "   View logs:        az webapp log tail --name $appName --resource-group petclinic-rg-$Environment" -ForegroundColor Gray
    Write-Host "   Azure Portal:     https://portal.azure.com/#@/resource/subscriptions/.../resourceGroups/petclinic-rg-$Environment" -ForegroundColor Gray
    Write-Host ""
    Write-Host "💰 Cost Management:" -ForegroundColor Yellow
    Write-Host "   Estimated: ~`$30/month" -ForegroundColor Gray
    Write-Host "   Stop app:  az webapp stop --name $appName --resource-group petclinic-rg-$Environment" -ForegroundColor Gray
    Write-Host "   Stop DB:   az postgres flexible-server stop --name $dbServer --resource-group petclinic-rg-$Environment" -ForegroundColor Gray
    Write-Host ""
    
    # Open in browser
    $openBrowser = Read-Host "Open application in browser? (yes/no)"
    if ($openBrowser -eq "yes") {
        Start-Process $appUrl
    }
    
    Write-Host ""
    Write-Host "✅ All done! Happy testing! 🚀" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Check error message above" -ForegroundColor Gray
    Write-Host "   2. Review logs: az webapp log tail --name $appName --resource-group petclinic-rg-$Environment" -ForegroundColor Gray
    Write-Host "   3. See MANUAL_DEPLOYMENT_GUIDE.md for detailed steps" -ForegroundColor Gray
    exit 1
}
