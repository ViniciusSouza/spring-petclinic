# Java/Spring Boot Specific Instructions

**Extends**: `copilot-instructions-base.md`

## Project Overview
Spring PetClinic is a reference Spring Boot application demonstrating modern Java development practices. This is a **cutting-edge implementation** using Spring Boot 4.0.0-M3 (pre-release milestone) with Java 25 toolchain targeting Java 17+ runtime.

## Architecture & Domain Model

### Package-by-Feature Structure
Code is organized by domain feature (owner, vet, system) rather than layer (controllers, services, repositories):
- `owner/` - Owner and Pet management (Owner, Pet, Visit, PetType)
- `vet/` - Veterinarian information (Vet, Specialty)
- `system/` - Cross-cutting concerns (caching, error handling, welcome page)
- `model/` - Shared base entities (Person, BaseEntity)

### Data Access Pattern
**Spring Data JPA repositories WITHOUT service layer** - Controllers interact directly with repositories:
```java
// OwnerRepository.java - Interface-only, no implementation needed
public interface OwnerRepository extends JpaRepository<Owner, Integer> {
    Page<Owner> findByLastNameStartingWith(String lastName, Pageable pageable);
}

// OwnerController.java - Direct repository injection
@Controller
class OwnerController {
    private final OwnerRepository owners;
    
    public OwnerController(OwnerRepository owners) {
        this.owners = owners;
    }
}
```
**When modifying data access**: Use Spring Data method naming conventions for queries. No `@Query` annotations needed for simple queries.

### JPA Entity Patterns
- Base entity inheritance: `Owner` and `Vet` extend `Person`, which extends `BaseEntity`
- JPA validation with Jakarta annotations: `@NotBlank`, `@Pattern`
- **Nullability annotations**: Package-level `@NullMarked` with `@Nullable` for optional fields
- Cascade operations on relationships: `@OneToMany(cascade = CascadeType.ALL)`

## Build & Test Workflows

### Dual Build System
Both Maven and Gradle are supported - keep them in sync when adding dependencies:
```bash
# Maven (preferred by project)
./mvnw clean package                    # Build only
./mvnw spring-boot:run                  # Run with hot reload
./mvnw package -P css                   # Rebuild CSS from SCSS

# Gradle
./gradlew build                         # Build
./gradlew bootRun                       # Run
```

### Database Profiles
Default is H2 in-memory. Switch with Spring profiles:
```bash
# MySQL
docker compose up mysql
./mvnw spring-boot:run -Dspring-boot.run.profiles=mysql

# PostgreSQL
docker compose up postgres
./mvnw spring-boot:run -Dspring-boot.run.profiles=postgres
```
Profile-specific properties in `application-{profile}.properties`.

### Test Strategy
**Use test main() methods for development** - Not traditional @Test methods:
- `PetClinicIntegrationTests.main()` - H2 database with devtools hot reload
- `MySqlTestApplication.main()` - MySQL via Testcontainers (auto-starts Docker)
- `PostgresIntegrationTests.main()` - PostgreSQL via Docker Compose

These run as both runnable applications AND integration tests, providing fast feedback during development.

## Code Quality & Formatting

### Automatic Code Formatting
**Spring Java Format is enforced** - Code must match Spring's style guide:
```bash
./mvnw spring-javaformat:apply         # Auto-format all Java files
./mvnw verify                          # Includes format validation
```
**Before committing**: Run `spring-javaformat:apply` or builds will fail validation.

### Static Analysis Tools
Multiple analyzers run during build (in pom.xml and build.gradle):
- **Spring Java Format** - Code style enforcement
- **Checkstyle** - Additional code standards
- **NoHttp Checkstyle** - Prevents http:// URLs (must use https://)
- **Error Prone** - Google's bug detection (disabled by default, enabled for NullAway)
- **NullAway** - Null safety validation (only on main source, respects `@NullMarked`)

### Null Safety Convention
Package-level null safety with JSpecify:
```java
// package-info.java
@NullMarked
package org.springframework.samples.petclinic.owner;

// Nullable fields must be annotated
private @Nullable String firstName;
```

## Web Layer & Templates

### Thymeleaf Template Organization
Templates in `src/main/resources/templates/`:
- `fragments/layout.html` - Master layout with Bootstrap
- `fragments/inputField.html`, `selectField.html` - Reusable form components
- Domain-specific: `owners/`, `pets/`, `vets/`

### Controller Conventions
- **Package-private visibility** - Controllers are `class`, not `public class`
- `@ModelAttribute` for entity loading: Fetches entities before handler methods
- `@InitBinder` for security: Disable binding on sensitive fields (e.g., `id`)
- Use `RedirectAttributes` for flash messages after POST-redirect-GET

Example from `OwnerController.java`:
```java
@ModelAttribute("owner")
public Owner findOwner(@PathVariable(name = "ownerId", required = false) @Nullable Integer ownerId) {
    return ownerId == null ? new Owner() 
        : this.owners.findById(ownerId).orElseThrow(...);
}
```

### CSS/SCSS Workflow
**CSS is generated, don't edit directly**:
- Source: `src/main/scss/petclinic.scss`
- Output: `src/main/resources/static/resources/css/petclinic.css`
- Rebuild: `./mvnw package -P css` (Maven only, no Gradle profile)

## Java-Specific Patterns

### Language Best Practices
- **Use Java records** for DTOs and immutable data structures
- **Constructor injection** (not field injection) - enables immutability
- **Package-private classes** unless public access is required
- **Method references** over lambdas when possible: `owners::findAll`
- **Streams API** for collection operations
- **Optional** for nullable return values, `@Nullable` for parameters
- Follow **Spring Boot conventions**: Auto-configuration over manual configuration

### Testing with JUnit 5 & AssertJ
Example test pattern:
```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class OwnerControllerTests {
    @Autowired
    private OwnerRepository owners;
    
    @Test
    void shouldFindOwnersByLastName() {
        Page<Owner> results = owners.findByLastNameStartingWith("Davis", PageRequest.of(0, 5));
        assertThat(results).isNotEmpty();
    }
}
```

## Key Configuration Details

### Caching Setup
JCache API with Caffeine implementation (`system/CacheConfiguration.java`):
- Single cache: `vets` - Caches veterinarian list
- Statistics enabled for JMX monitoring
- See `VetRepository.findAll()` for `@Cacheable` usage

### Actuator Endpoints
All management endpoints exposed (`application.properties`):
```properties
management.endpoints.web.exposure.include=*
```
Available at: http://localhost:8080/actuator/

### Database Initialization
SQL scripts auto-execute at startup:
```properties
spring.sql.init.schema-locations=classpath*:db/${database}/schema.sql
spring.sql.init.data-locations=classpath*:db/${database}/data.sql
```
Scripts in `src/main/resources/db/{h2,mysql,postgres}/`.

## Version-Specific Considerations

### Spring Boot 4.0.0-M3 Status
**This is a MILESTONE (pre-release) version**. Be aware:
- API may change between milestone releases
- Use Spring Boot 4.0 documentation (not 3.x)
- Jakarta EE packages (`jakarta.*`), not `javax.*`
- Consider stability implications for production deployments

### Java Version Requirements
- **Build toolchain**: Java 25 (configured in pom.xml/build.gradle)
- **Runtime bytecode**: Java 17 (`maven.compiler.release=17`)
- **Deployment**: Java 17+ minimum required

## Docker & Kubernetes

### Container Building
**No Dockerfile** - Use Spring Boot buildpack integration:
```bash
./mvnw spring-boot:build-image         # Creates OCI image
```

### K8s Manifests
Deployment configs in `k8s/`:
- `db.yml` - Database service
- `petclinic.yml` - Application deployment

## Maven & Gradle Specifics

### When Adding Dependencies
1. Update both `pom.xml` AND `build.gradle`
2. Keep version properties in sync between files
3. Run `./mvnw verify` and `./gradlew check` to ensure both builds pass

### Build Profiles
- Maven CSS profile: `./mvnw package -P css`
- No Gradle CSS profile available

### Testing Strategy
- Use `PetClinicIntegrationTests.main()` for rapid feedback during development
- Create proper `@Test` methods for CI/CD
- Use AssertJ assertions (`assertThat()`)

### Azure-Specific Considerations
If implementing Azure-related plans:
- Use Azure SDK libraries compatible with Spring Boot 4.0.0-M3
- Externalize configuration (don't hardcode Azure connection strings)
- Support local development (use profiles or environment variables)
- Add proper error handling for Azure service calls
- Document Azure prerequisites in the plan