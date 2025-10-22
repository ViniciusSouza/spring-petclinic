# Spring PetClinic AI Coding Agent Instructions

**This file references modular instructions for better reusability**:
- **Base instructions**: [`copilot-instructions-base.md`](copilot-instructions-base.md) - Language-agnostic development patterns
- **Java/Spring Boot specifics**: [`copilot-instructions-java.md`](copilot-instructions-java.md) - Project-specific architecture and conventions

AI coding assistants should read both files for complete context.

---

## Quick Reference

### Project Type
- **Language**: Java 17+ (built with Java 25 toolchain)
- **Framework**: Spring Boot 4.0.0-M3 (Milestone/Pre-release)
- **Architecture**: Package-by-feature, no service layer
- **Build Tools**: Maven (preferred) and Gradle
- **Template Engine**: Thymeleaf
- **Databases**: H2 (default), MySQL, PostgreSQL

### Key Commands
```bash
# Build & Run
./mvnw spring-boot:run                 # Run with H2 (default)
./mvnw spring-boot:run -Dspring-boot.run.profiles=mysql     # Run with MySQL
./mvnw spring-boot:run -Dspring-boot.run.profiles=postgres  # Run with PostgreSQL

# Code Quality
./mvnw spring-javaformat:apply         # Auto-format code (REQUIRED before commit)
./mvnw verify                          # Build + tests + validation

# CSS Compilation
./mvnw package -P css                  # Rebuild CSS from SCSS sources
```

### Development Workflow
1. Read [`copilot-instructions-base.md`](copilot-instructions-base.md) for general patterns
2. Read [`copilot-instructions-java.md`](copilot-instructions-java.md) for project specifics
3. Use `/create-goal-plan` for structured feature development
4. Use `/implement-plan` for step-by-step implementation with atomic commits
5. Run `spring-javaformat:apply` before committing
6. Include `Signed-off-by` trailer in commits (DCO required)

### Important Project Conventions
- **No service layer** - Controllers inject repositories directly
- **Package-private classes** - Use `class` not `public class` for controllers
- **Null safety** - Package-level `@NullMarked` with `@Nullable` for optional fields
- **Spring Data** - Use method naming conventions, avoid `@Query` when possible
- **Test main() methods** - Use for development (e.g., `PetClinicIntegrationTests.main()`)
- **Dual build system** - Update both `pom.xml` AND `build.gradle` when adding dependencies

### Structured Workflows
See [`docs/PROMPTS.md`](../docs/PROMPTS.md) for detailed guides on:
- Creating goal-oriented implementation plans
- Executing plans with atomic commits
- Delegating tasks to GitHub Copilot Agent
- Tracking progress across multiple plans

---

**For complete details**, refer to the modular instruction files linked above.
