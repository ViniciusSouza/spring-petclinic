---
mode: 'agent'
description: 'Create a structured, goal-oriented implementation plan for Spring PetClinic. Analyzes complexity, breaks down large goals, and generates detailed plans with tasks, testing strategy, and agent delegation.'
tools: ['edit/createFile', 'read', 'semantic_search', 'grep_search', 'list_dir']
---

# Create Goal-Oriented Plan

You are helping create a structured implementation plan for the Spring PetClinic application.

## Workflow

1. **Ask for the Goal**:
   - Prompt: "What goal do you want to achieve for this sprint?"
   - Listen carefully to understand the scope

2. **Assess Goal Complexity**:
   - **If the goal is too large** (would take >5 days or >20 files):
     - Respond: "⚠️ This is a very ambitious goal to accomplish in one sprint. It involves [list key areas]. Would you like to:"
       - a) Proceed with this large goal anyway
       - b) Let me suggest breaking it into smaller, manageable goals
       - c) Focus on a specific subset
   
   - **If the goal is reasonable**:
     - Acknowledge it positively and proceed

3. **Create Structured Plan**:
   - Analyze the codebase to understand current architecture
   - Break down the goal into:
     - **Objectives**: What we want to achieve
     - **Prerequisites**: Dependencies, setup, knowledge needed
     - **Tasks**: Ordered list of implementation steps
     - **Files to Modify/Create**: Specific file paths
     - **Testing Strategy**: How to verify success
     - **Risks**: Potential challenges
     - **Acceptance Criteria**: Definition of done
   
4. **Save Plan**:
   - Create file: `docs/plans/plan-{goal-slug}.md`
   - Include metadata header:
     ```yaml
     ---
     goal: "{goal title}"
     status: pending
     created: {date}
     estimated_effort: {small|medium|large}
     sprint: {sprint number if applicable}
     ---
     ```

5. **Identify Agent-Delegatable Tasks**:
   - Analyze the plan for tasks that can be parallelized
   - Common agent tasks:
     - **Unit tests**: Create tests after implementing new classes/methods
     - **Integration tests**: Create end-to-end tests for new features
     - **Documentation**: Generate JavaDoc, update README, create diagrams
     - **Repetitive changes**: Apply same pattern across multiple files
   - Set `delegate_to_agent: true` if agent tasks exist
   - Count agent tasks and set `agent_tasks: {count}`
   
6. **Request Review**:
   - Ask: "I've created the plan at `docs/plans/plan-{goal-slug}.md`. Please review it and let me know if you'd like any adjustments before we proceed with implementation."
   - If agent tasks exist, mention: "This plan includes {count} tasks that can be delegated to GitHub Copilot Agent for parallel execution."

## Plan Template Structure

```markdown
---
goal: "{Goal Title}"
status: pending
created: YYYY-MM-DD
estimated_effort: {small|medium|large}
sprint: {number}
delegate_to_agent: {true|false}
agent_tasks: {number}
---

# Implementation Plan: {Goal Title}

## 🎯 Objective
{Clear description of what we want to achieve}

## 📋 Prerequisites
- [ ] {Prerequisite 1}
- [ ] {Prerequisite 2}

## 🔧 Implementation Tasks

### Phase 1: {Phase Name}
1. [ ] **Task 1**: {Description}
   - Files: `path/to/file.java`
   - Details: {specific implementation notes}
   - Agent: No

2. [ ] **Task 2**: {Description}
   - Files: `path/to/file.java`
   - Details: {specific implementation notes}
   - Agent: No

### Phase 2: {Phase Name}
{...}

## 🤖 GitHub Copilot Agent Tasks

Tasks that can be delegated to GitHub Copilot Agent for parallel execution:

1. [ ] **Agent Task 1**: {Description}
   - Type: {unit-tests|integration-tests|documentation|refactoring}
   - Files: `path/to/file.java`
   - Instructions: {Specific instructions for the agent}
   - Dependencies: {Task IDs this depends on}

2. [ ] **Agent Task 2**: {Description}
   - Type: {unit-tests|integration-tests|documentation|refactoring}
   - Files: `path/to/file.java`
   - Instructions: {Specific instructions for the agent}
   - Dependencies: {Task IDs this depends on}

## 📁 Files to Modify/Create

### New Files
- `src/main/java/.../{NewClass}.java` - {Purpose}

### Modified Files
- `src/main/java/.../{ExistingClass}.java` - {Changes needed}

### Configuration
- `application.properties` - {New properties}
- `pom.xml` / `build.gradle` - {Dependencies}

## 🧪 Testing Strategy
1. **Unit Tests**: {What to test}
2. **Integration Tests**: {What to test}
3. **Manual Testing**: {Steps to verify}

## ⚠️ Risks & Considerations
- {Risk 1}: {Mitigation strategy}
- {Risk 2}: {Mitigation strategy}

## ✅ Acceptance Criteria
- [ ] {Criterion 1}
- [ ] {Criterion 2}
- [ ] All tests pass
- [ ] Code formatted with `./mvnw spring-javaformat:apply`
- [ ] Documentation updated
- [ ] All agent tasks completed

## 🔄 Dependencies
{List any dependencies on other tasks/features}

## 📝 Notes
{Any additional context or considerations}

---

## 🤖 Agent Task Guidelines

**When to delegate to GitHub Copilot Agent**:
- Creating unit tests for new classes/methods
- Creating integration tests
- Generating documentation/JavaDoc
- Repetitive code changes across multiple files
- Refactoring tasks (rename, extract method, etc.)

**When NOT to delegate**:
- Core business logic implementation
- Architecture decisions
- Complex integrations
- Tasks requiring context from multiple unrelated areas

**Agent task format**:
Each agent task should be specific enough to execute independently:
- Clear input/output expectations
- Specific files to modify/create
- Testing criteria
- Dependencies on main implementation tasks
```

## Context Awareness

When creating plans, consider:
- **Current Architecture**: Package-by-feature structure, no service layer
- **Technology Stack**: Spring Boot 4.0.0-M3, Java 17+, JPA, Thymeleaf
- **Code Standards**: Spring Java Format, null safety with `@NullMarked`
- **Testing Approach**: Test main() methods + JUnit integration tests
- **Build System**: Both Maven and Gradle (keep in sync)
- **Azure Cloud Migration Context**: If goal relates to Azure, consider:
  - Azure-specific services (App Service, Container Apps, SQL Database, etc.)
  - Configuration externalization (Azure App Configuration, Key Vault)
  - Monitoring (Application Insights)
  - Authentication (Azure AD, Managed Identity)

## Example Interaction

**User**: "Make the application Azure-ready"

**Response**: 
"⚠️ This is a very ambitious goal! Making the application fully Azure-ready involves multiple areas:
- Containerization and deployment strategy
- Database migration to Azure SQL/PostgreSQL
- Configuration externalization to Azure App Configuration
- Authentication with Azure AD
- Monitoring with Application Insights
- CI/CD pipeline setup

This would be a multi-sprint effort. Would you like to:
a) Proceed with a comprehensive Azure migration plan
b) Let me suggest breaking it into focused sprints (e.g., Sprint 1: Containerization, Sprint 2: Database, etc.)
c) Focus on a specific subset first (e.g., just getting it running on Azure App Service)"
