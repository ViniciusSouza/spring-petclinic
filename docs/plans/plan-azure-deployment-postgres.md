---
goal: "Deploy Spring PetClinic to Azure with PostgreSQL"
status: in-progress
created: 2025-10-22
started: 2025-10-22
estimated_effort: medium
sprint: 1
delegate_to_agent: true
agent_tasks: 3
tasks_total: 14
tasks_completed: 0
agent_tasks_completed: 0
agent_issues: []
---

# Implementation Plan: Deploy Spring PetClinic to Azure with PostgreSQL

## 🎯 Objective

Deploy the Spring PetClinic application to Azure cloud infrastructure using Azure App Service for hosting and Azure Database for PostgreSQL Flexible Server as the database. This plan focuses on getting the application running in Azure with minimal code changes, establishing a foundation for future cloud-native enhancements.

**Success Criteria**: Application accessible via Azure URL with full functionality using PostgreSQL database.

## 📋 Prerequisites

- [ ] Azure subscription with appropriate permissions
- [ ] Azure CLI installed and configured locally
- [ ] Docker installed (for container image building)
- [ ] Git repository access
- [ ] Understanding of current PostgreSQL configuration in the app

## 🔧 Implementation Tasks

### Phase 1: Azure Infrastructure Setup (IaC)

1. [ ] **Task 1.1**: Create Azure resource provisioning scripts
   - Files: `infrastructure/azure/main.bicep`, `infrastructure/azure/parameters.json`
   - Details: 
     - Define Resource Group
     - Define App Service Plan (Linux, B1 or P1V2)
     - Define App Service with Java 17+ runtime
     - Define Azure Database for PostgreSQL Flexible Server
     - Configure networking (VNet integration if needed)
     - Set up Managed Identity for App Service
   - Agent: No

2. [ ] **Task 1.2**: Create infrastructure deployment scripts
   - Files: `infrastructure/azure/deploy.sh`, `infrastructure/azure/deploy.ps1`
   - Details:
     - Azure CLI commands to deploy Bicep templates
     - Parameter validation
     - Output connection strings and URLs
   - Agent: No

3. [ ] **Task 1.3**: Deploy Azure infrastructure
   - Details: Execute deployment scripts, verify resources created
   - Estimated time: 15-20 minutes for resource provisioning
   - Agent: No

### Phase 2: Application Configuration for Azure

4. [ ] **Task 2.1**: Create Azure-specific application profile
   - Files: `src/main/resources/application-azure.properties`
   - Details:
     - Configure PostgreSQL connection using Azure environment variables
     - Use Managed Identity for authentication (if applicable)
     - Configure Application Insights connection string
     - Set logging levels appropriate for cloud
   - Agent: No

5. [ ] **Task 2.2**: Externalize configuration to Azure App Configuration (Optional)
   - Files: `pom.xml`, `build.gradle`, configuration classes
   - Details:
     - Add Azure App Configuration dependency
     - Configure feature flags and remote configuration
     - Set up connection via Managed Identity
   - Agent: No
   - Note: Can be deferred to Sprint 2

6. [ ] **Task 2.3**: Add Azure Key Vault integration for secrets
   - Files: `pom.xml`, `build.gradle`, `application-azure.properties`
   - Details:
     - Add Azure Key Vault dependency
     - Configure Key Vault reference for database credentials
     - Use Managed Identity for access
   - Agent: No

### Phase 3: Containerization & Build

7. [ ] **Task 3.1**: Create production-ready container image
   - Files: `Dockerfile` (optional, can use buildpacks)
   - Details:
     - Use Spring Boot buildpack integration (`./mvnw spring-boot:build-image`)
     - Or create multi-stage Dockerfile for Azure
     - Optimize image size and startup time
   - Agent: No

8. [ ] **Task 3.2**: Configure Azure Container Registry (ACR)
   - Details:
     - Create ACR instance via Bicep
     - Configure authentication
     - Push container image to ACR
   - Agent: No

### Phase 4: Database Migration & Setup

9. [ ] **Task 4.1**: Configure Azure PostgreSQL Flexible Server
   - Details:
     - Enable public access or configure VNet integration
     - Create database: `petclinic`
     - Create user and grant permissions
     - Configure firewall rules
   - Agent: No

10. [ ] **Task 4.2**: Initialize database schema
    - Files: Existing `src/main/resources/db/postgres/schema.sql` and `data.sql`
    - Details:
      - Schema and data will auto-initialize via Spring Boot
      - Verify `spring.sql.init.mode=always` in azure profile
    - Agent: No

### Phase 5: Monitoring & Observability

11. [ ] **Task 5.1**: Integrate Application Insights
    - Files: `pom.xml`, `build.gradle`, `application-azure.properties`
    - Details:
      - Add Application Insights Java agent
      - Configure connection string via environment variable
      - Enable distributed tracing
    - Agent: No

12. [ ] **Task 5.2**: Configure health checks and metrics
    - Files: `application-azure.properties`
    - Details:
      - Ensure actuator endpoints are accessible
      - Configure App Service health check endpoint
      - Set up custom metrics if needed
   - Agent: No

### Phase 6: CI/CD Pipeline

13. [ ] **Task 6.1**: Create GitHub Actions workflow
    - Files: `.github/workflows/azure-deploy.yml`
    - Details:
      - Build application (Maven/Gradle)
      - Build and push container image
      - Deploy to Azure App Service
      - Run smoke tests
      - Use OIDC for authentication (no secrets)
    - Agent: No

14. [ ] **Task 6.2**: Configure deployment slots (Optional)
    - Details:
      - Create staging slot
      - Configure slot swap for zero-downtime deployment
    - Agent: No
    - Note: Can be deferred

## 🤖 GitHub Copilot Agent Tasks

1. [ ] **Agent Task 1**: Create comprehensive Azure deployment documentation
   - Type: documentation
   - Files: `docs/AZURE_DEPLOYMENT.md`
   - Instructions:
     - Document infrastructure architecture
     - Step-by-step deployment guide
     - Troubleshooting common issues
     - Environment variables reference
     - Cost estimation guide
   - Dependencies: Task 1.3 (Infrastructure deployed)

2. [ ] **Agent Task 2**: Create infrastructure testing scripts
   - Type: integration-tests
   - Files: `infrastructure/azure/test-deployment.sh`
   - Instructions:
     - Verify all Azure resources are created
     - Test connectivity to PostgreSQL
     - Verify App Service is running
     - Check Application Insights integration
     - Validate Managed Identity permissions
   - Dependencies: Task 1.3 (Infrastructure deployed)

3. [ ] **Agent Task 3**: Generate Bicep template documentation
   - Type: documentation
   - Files: `infrastructure/azure/README.md`
   - Instructions:
     - Document all Bicep parameters
     - Explain resource relationships
     - Provide examples for different environments
     - Document naming conventions
   - Dependencies: Task 1.1 (Bicep templates created)

## 📁 Files to Modify/Create

### New Files
- `infrastructure/azure/main.bicep` - Azure infrastructure as code
- `infrastructure/azure/parameters.json` - Environment-specific parameters
- `infrastructure/azure/deploy.sh` - Deployment script (Bash)
- `infrastructure/azure/deploy.ps1` - Deployment script (PowerShell)
- `src/main/resources/application-azure.properties` - Azure-specific config
- `.github/workflows/azure-deploy.yml` - CI/CD pipeline
- `docs/AZURE_DEPLOYMENT.md` - Deployment documentation (Agent)
- `infrastructure/azure/README.md` - Infrastructure docs (Agent)

### Modified Files
- `pom.xml` - Add Azure dependencies (App Insights, Key Vault, App Config)
- `build.gradle` - Add Azure dependencies (keep in sync with Maven)
- `README.md` - Add Azure deployment instructions link

### Configuration Files
- Environment variables in Azure App Service configuration

## 🧪 Testing Strategy

### Local Testing
1. **Test with local PostgreSQL**: Verify app works with PostgreSQL profile
2. **Test environment variables**: Simulate Azure configuration locally
3. **Container testing**: Run containerized app locally

### Azure Testing
1. **Smoke tests**: Verify app responds on Azure URL
2. **Database connectivity**: Test CRUD operations
3. **Health checks**: Verify actuator endpoints
4. **Application Insights**: Confirm telemetry is flowing
5. **Load testing**: Basic performance validation

### Manual Testing Checklist
- [ ] Access application via Azure URL
- [ ] Create, read, update, delete owners
- [ ] Create pets and visits
- [ ] View veterinarians list
- [ ] Check Application Insights for requests
- [ ] Verify database persistence across app restarts

## ⚠️ Risks & Considerations

### Technical Risks
- **PostgreSQL version compatibility**: Azure Flexible Server uses specific PostgreSQL versions
  - Mitigation: Use PostgreSQL 14+ which is well-supported
  
- **Connection string format**: Azure PostgreSQL requires SSL
  - Mitigation: Configure `sslmode=require` in connection string

- **Cold start performance**: App Service may have slow initial startup
  - Mitigation: Use "Always On" setting or Premium tier

- **Cost overrun**: Azure resources incur ongoing costs
  - Mitigation: Start with B1/B2 tier, monitor costs, implement auto-shutdown for dev

### Operational Risks
- **Database migration**: Schema initialization must succeed on first run
  - Mitigation: Test schema scripts locally, use `spring.sql.init.mode=always`

- **Secrets management**: Database passwords must be secure
  - Mitigation: Use Key Vault or Managed Identity

- **Network access**: Firewall rules may block connections
  - Mitigation: Configure IP allowlisting or VNet integration

## ✅ Acceptance Criteria

### Infrastructure
- [ ] All Azure resources provisioned successfully
- [ ] Resource naming follows conventions
- [ ] Managed Identity configured and working
- [ ] Network security configured appropriately

### Application
- [ ] Application deploys successfully to App Service
- [ ] Application accessible via public Azure URL
- [ ] All features work correctly (owners, pets, vets, visits)
- [ ] Database persists data correctly
- [ ] Application Insights collecting telemetry

### Code Quality
- [ ] All tests pass locally and in CI/CD
- [ ] Code formatted with `./mvnw spring-javaformat:apply`
- [ ] Both Maven and Gradle builds succeed
- [ ] No hardcoded credentials or secrets

### Documentation
- [ ] Deployment guide complete
- [ ] Infrastructure documentation clear
- [ ] Environment variables documented
- [ ] Troubleshooting section included

### CI/CD
- [ ] GitHub Actions workflow runs successfully
- [ ] Automated deployment works end-to-end
- [ ] Smoke tests pass after deployment

## 🔄 Dependencies

### External Dependencies
- Azure subscription with necessary quotas
- GitHub repository with Actions enabled
- Docker registry access (ACR)

### Internal Dependencies
- Existing PostgreSQL profile (already implemented ✅)
- Existing database scripts (already implemented ✅)
- Spring Boot buildpack support (already available ✅)

## 📝 Notes

### Future Enhancements (Sprint 2+)
- **Cosmos DB migration**: Separate sprint for data model redesign
- **Multi-region deployment**: Geographic redundancy
- **Azure Front Door**: CDN and global load balancing
- **Azure AD authentication**: User identity integration
- **Scaling rules**: Auto-scale based on metrics
- **Deployment slots**: Blue-green deployment

### Cost Optimization
- Use B1 tier for development (~$13/month)
- Use free tier PostgreSQL for dev/test
- Implement auto-shutdown for non-production environments
- Monitor costs with Azure Cost Management

### Security Considerations
- Use Managed Identity (no connection strings)
- Enable Key Vault for secrets
- Configure network security groups
- Enable Azure Defender if budget allows
- Regular security scanning in CI/CD

### Performance Tuning
- Enable connection pooling
- Configure JVM heap size appropriately
- Use Azure CDN for static assets
- Implement caching where beneficial

---

**Estimated Timeline**: 3-5 days for experienced Azure developers, 1-2 weeks for learning curve

**Next Steps After Completion**: Review sprint retrospective, plan Sprint 2 features (monitoring, scaling, or optionally Cosmos DB exploration)
