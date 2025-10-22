---
mode: 'agent'
description: 'Execute a structured implementation plan for Spring PetClinic. Implements tasks step-by-step with atomic commits, delegates parallelizable work to GitHub Copilot Agent via issues, validates code, and tracks progress.'
tools:
  - 'read'
  - 'edit'
  - 'terminal'
  - 'github'
  - 'todos'
  - 'search'
---

# Implement Plan

You are helping implement a structured plan for the Spring PetClinic application.

## Workflow

1. **Identify the Plan**:
   
   **If plan name provided**: `/implement-plan <plan-name>`
   - Look for `docs/plans/plan-{plan-name}.md`
   - If not found, list available plans and ask user to choose
   
   **If no plan name provided**: `/implement-plan`
   - Scan `docs/plans/` directory
   - List all plans with their status:
     ```
     Available implementation plans:
     
     📋 Pending:
     1. plan-azure-deployment.md - "Deploy to Azure App Service"
     2. plan-add-rest-api.md - "Add REST API endpoints"
     
     🚧 In Progress:
     3. plan-email-notifications.md - "Email notification system"
     
     ✅ Completed:
     4. plan-owner-search.md - "Enhanced owner search"
     
     Which plan would you like to implement? (Enter number or name)
     ```

2. **Validate Plan Status**:
   - **If status is `completed`**: 
     - Ask: "This plan is already marked as completed. Do you want to re-implement or modify it?"
   
   - **If status is `in-progress`**:
     - Ask: "This plan is currently in progress. Do you want to continue from where it was left off?"
   
   - **If status is `pending`**:
     - Proceed with implementation

3. **Update Plan Status**:
   - Change status to `in-progress`
   - Add `started: {date}` to metadata
   - Commit this change: "Start implementation of {goal}"

4. **Check for Agent Tasks**:
   - Read plan metadata: `delegate_to_agent` and `agent_tasks`
   - If `delegate_to_agent: true`:
     - Identify which tasks are marked with `Agent: Yes` or in "GitHub Copilot Agent Tasks" section
     - Keep track of agent tasks to delegate later

5. **Implementation Process**:
   
   **For each main implementation task** (where `Agent: No`):
   
   a) **Announce the task**:
      - "Starting: {Task description}"
   
   b) **Implement following best practices**:
      - Follow Spring PetClinic conventions (package-private controllers, direct repository access, etc.)
      - Apply null safety annotations (`@Nullable`, `@NullMarked`)
      - Use constructor injection
      - Create tests for new features
   
   c) **Create atomic commits**:
      - One commit per logical task/subtask
      - Format: "{Action}: {Description}"
      - Examples:
        - "Add: REST endpoint for owner search"
        - "Implement: Owner email validation"
        - "Test: Add integration tests for owner API"
      - Include `Signed-off-by` trailer
   
   d) **Run validation after each commit**:
      ```bash
      ./mvnw spring-javaformat:apply    # Format code
      ./mvnw verify                      # Run tests
      ```
   
   e) **Update plan file**:
      - Mark task as completed: `- [x] Task description`
      - Commit: "Update plan: Mark {task} as completed"
   
   f) **Check for dependent agent tasks**:
      - After completing a task, check if any agent tasks depend on it
      - If dependencies are met, create GitHub issue for the agent task

6. **Delegate to GitHub Copilot Agent**:
   
   **When agent task dependencies are met**:
   
   a) **Create GitHub issue for agent task**:
      - Use issue title format: `[Agent] {Task description}`
      - Include in issue body:
        ```markdown
        ## Task Type
        {unit-tests|integration-tests|documentation|refactoring}
        
        ## Description
        {Detailed instructions from plan}
        
        ## Files to Modify/Create
        - `path/to/file.java`
        
        ## Acceptance Criteria
        - [ ] {Criterion from plan}
        
        ## Related Plan
        Implementation plan: `docs/plans/plan-{goal-slug}.md`
        
        ## Dependencies
        ✅ Task {ID}: {Description} (completed)
        
        ## Instructions for Copilot Agent
        {Specific implementation instructions}
        ```
   
   b) **Assign to Copilot Agent**:
      - Use `@copilot` mention or GitHub's "Assign to Copilot" feature
      - Track issue number in plan file
   
   c) **Update plan**:
      - Add issue link to agent task: `- [ ] **Agent Task 1** - Issue #123`
      - Commit: "Delegate: Create agent task #{issue-number} for {description}"
   
   d) **Continue with other tasks**:
      - Don't wait for agent tasks to complete
      - Agent works in parallel while you continue implementation

7. **Monitor Agent Progress**:
   - Periodically check agent task status
   - When agent completes a task (creates PR):
     - Review the PR
     - Merge if acceptable
     - Mark agent task as complete in plan: `- [x] **Agent Task 1** - Issue #123 (PR #124 merged)`
     - Commit: "Update plan: Agent task #{issue-number} completed"

8. **Progress Updates**:
   - After each major phase, provide status:
     ```
     ✅ Phase 1 complete: {Phase name}
     - Task 1: ✅ Done
     - Task 2: ✅ Done
     
     🤖 Agent Tasks:
     - Agent Task 1: 🚧 In Progress (Issue #123)
     - Agent Task 2: ⏳ Waiting for dependencies
     
     🚧 Moving to Phase 2: {Phase name}
     ```

9. **Handle Issues**:
   - **If a task fails or blocks**:
     - Document the issue in the plan under a new `## 🚫 Blockers` section
     - Ask: "We've encountered a blocker: {issue}. Would you like to:
       a) Investigate and resolve now
       b) Skip this task for now and continue
       c) Pause implementation"

10. **Completion**:
   - When all main tasks are done:
     - Check agent task status:
       - **All agent tasks complete**: Proceed to completion
       - **Agent tasks still in progress**: 
         - Ask: "Main implementation complete! {count} agent tasks are still in progress:
           - Issue #123: Creating unit tests (80% complete)
           - Issue #124: Generating documentation (pending)
           
           Would you like to:
           a) Wait for agent tasks to complete
           b) Mark plan as complete and track agent tasks separately
           c) Review agent progress and help complete them"
     
     - Update plan status to `completed`
     - Add `completed: {date}` to metadata
     - Update `agent_tasks_completed: {count}` in metadata
     - Run final validation:
       ```bash
       ./mvnw spring-javaformat:apply
       ./mvnw verify
       ./gradlew check  # Verify Gradle build too
       ```
     - Create summary commit: "Complete: {goal title}"
     - Ask: "🎉 Implementation complete! Would you like me to:
       a) Create a summary of changes
       b) Generate documentation
       c) Create a pull request
       d) All done, ready for review"

## Implementation Guidelines

### Code Quality Checklist
Before marking any task complete:
- [ ] Code follows Spring Java Format
- [ ] Null safety annotations applied where needed
- [ ] Unit/integration tests created
- [ ] Both Maven and Gradle dependencies updated (if added)
- [ ] No compilation errors or test failures
- [ ] Atomic commit with clear message

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

## Plan Metadata Format

Plans should maintain this metadata structure:

```yaml
---
goal: "Goal title"
status: pending|in-progress|completed|blocked
created: YYYY-MM-DD
started: YYYY-MM-DD
completed: YYYY-MM-DD
estimated_effort: small|medium|large
sprint: number
tasks_total: number
tasks_completed: number
delegate_to_agent: true|false
agent_tasks: number
agent_tasks_completed: number
agent_issues: [123, 124, 125]  # GitHub issue numbers
---
```

## Agent Task Types

Recommended task types for GitHub Copilot Agent delegation:

1. **unit-tests**: Create unit tests for specific classes/methods
   - Clear input: Class/method to test
   - Clear output: Test class with comprehensive test cases
   - Example: "Create unit tests for OwnerController.processCreationForm()"

2. **integration-tests**: Create end-to-end integration tests
   - Clear input: Feature/endpoint to test
   - Clear output: Integration test with full flow
   - Example: "Create integration tests for owner registration flow"

3. **documentation**: Generate or update documentation
   - Clear input: Files/features to document
   - Clear output: JavaDoc, README sections, or diagrams
   - Example: "Add JavaDoc to all public methods in OwnerRepository"

4. **refactoring**: Repetitive code improvements
   - Clear input: Pattern to apply
   - Clear output: Refactored code
   - Example: "Extract email validation logic into reusable validator"

## Agent Task Issue Template

When creating issues for agent tasks, use this structure:

```markdown
[Agent] {Task description}

## 🤖 Task Type
{unit-tests|integration-tests|documentation|refactoring}

## 📝 Description
{Detailed instructions}

## 📁 Files to Modify/Create
- `src/main/java/.../{Class}.java`
- `src/test/java/.../{TestClass}.java`

## ✅ Acceptance Criteria
- [ ] All tests pass
- [ ] Code follows Spring Java Format
- [ ] Coverage > 80% for new code
- [ ] {Specific criterion}

## 🔗 Related Plan
Implementation plan: `docs/plans/plan-{goal-slug}.md`
Main implementation: Issue #{parent-issue} (if exists)

## ⚙️ Dependencies
✅ Task {ID}: {Description} (completed in commit {sha})

## 📋 Instructions for Copilot Agent
{Step-by-step instructions}

Example test structure:
\```java
@SpringBootTest
class OwnerControllerTests {
    // Test setup
    // Test cases
}
\```

## 🧪 Testing
Run: `./mvnw test -Dtest={TestClass}`

@copilot
```

## Example Interaction

**User**: `/implement-plan azure-deployment`

**Response**:
```
Found plan: docs/plans/plan-azure-deployment.md
Goal: "Deploy to Azure App Service"
Status: pending
Estimated effort: medium

Starting implementation...

✅ Updated plan status to 'in-progress'

Phase 1: Containerization
🚧 Starting: Create Dockerfile for production deployment
   Files: Dockerfile, .dockerignore

[AI implements the task...]

✅ Committed: "Add: Dockerfile for Azure App Service deployment"
✅ Tests passed
✅ Updated plan progress (1/8 tasks complete)

🚧 Starting: Configure Azure-specific application properties
...
```
