# Custom AI Prompts Guide

This project includes custom prompts to help structure AI-assisted development workflows.

## Available Prompts

### 📋 `/create-goal-plan`
Creates a structured, goal-oriented implementation plan.

**Usage**: `/create-goal-plan`

**What it does**:
- Asks for your sprint goal
- Assesses complexity and suggests breaking down large goals
- Creates a detailed implementation plan in `docs/plans/`
- Includes tasks, files to modify, testing strategy, and acceptance criteria

**Example**:
```
You: /create-goal-plan
AI: What goal do you want to achieve for this sprint?
You: Make the application Azure-ready
AI: ⚠️ This is a very ambitious goal! [suggests breaking it down...]
```

### 🚀 `/implement-plan <plan-name>`
Executes an implementation plan with structured workflow.

**Usage**: 
- `/implement-plan <plan-name>` - Implement specific plan
- `/implement-plan` - Lists available plans and asks you to choose

**What it does**:
- Updates plan status to `in-progress`
- Implements each task following best practices
- Creates atomic commits for each step
- Runs validation after changes
- Updates plan progress
- Marks plan as `completed` when done

**Example**:
```
You: /implement-plan azure-deployment
AI: Found plan: docs/plans/plan-azure-deployment.md
    Starting Phase 1: Containerization...
    ✅ Task 1 complete
    🚧 Moving to Task 2...
```

### 📊 `/list-plans [status]`
Shows all implementation plans and their status.

**Usage**:
- `/list-plans` - Show all plans
- `/list-plans pending` - Show only pending plans
- `/list-plans in-progress` - Show in-progress plans
- `/list-plans completed` - Show completed plans

### 🔍 Code Assessment
Analyzes the codebase for dependencies, patterns, and recommendations.

See `docs/initial-code-assessment.md` for an example output.

## Workflow Example

### Complete Sprint Workflow

1. **Create a goal plan**:
   ```
   /create-goal-plan
   ```
   AI asks for goal, creates `docs/plans/plan-{goal}.md`

2. **Review the plan**:
   Open `docs/plans/plan-{goal}.md` and review
   Provide feedback to AI if adjustments needed

3. **Implement the plan**:
   ```
   /implement-plan {goal}
   ```
   AI executes plan step-by-step with atomic commits
   
   If plan includes agent tasks, AI will:
   - Create GitHub issues for agent tasks
   - Assign them to @copilot
   - Continue implementation while agent works in parallel

4. **Track progress**:
   ```
   /list-plans in-progress
   ```
   See current status of all active plans

5. **Complete**:
   Plan automatically marked as `completed`
   Ready for PR/review

## Plan Structure

Each plan includes:

```markdown
---
goal: "Goal title"
status: pending
created: 2025-10-22
estimated_effort: medium
delegate_to_agent: true
agent_tasks: 3
---

# Implementation Plan: {Goal}

## 🎯 Objective
## 📋 Prerequisites  
## 🔧 Implementation Tasks
## 🤖 GitHub Copilot Agent Tasks
## 📁 Files to Modify/Create
## 🧪 Testing Strategy
## ⚠️ Risks & Considerations
## ✅ Acceptance Criteria
```

### Agent Task Delegation

Plans can include tasks specifically designed for GitHub Copilot Agent to handle in parallel:

**Common agent tasks**:
- 🧪 Creating unit tests
- 🔗 Creating integration tests  
- 📚 Generating documentation/JavaDoc
- ♻️ Repetitive refactoring across files

**Benefits**:
- **Parallel execution**: Agent works on tests while you implement features
- **Faster completion**: Don't wait for test creation
- **Focused work**: You focus on core logic, agent handles repetitive tasks

## Best Practices

### When Creating Plans
- Be specific about the goal
- Accept AI suggestions to break down large goals
- Review the plan before implementation
- Ensure acceptance criteria are clear

### During Implementation
- Let AI create atomic commits
- Review each change as it happens
- Run tests frequently
- Update plan if priorities change

### After Completion
- Review all commits
- Ensure tests pass
- Verify acceptance criteria met
- Keep completed plans as documentation

## Azure Migration Context

For Azure-related goals, plans will consider:
- **Deployment**: App Service, Container Apps, AKS
- **Database**: Azure SQL, PostgreSQL Flexible Server
- **Configuration**: App Configuration, Key Vault
- **Monitoring**: Application Insights
- **Identity**: Managed Identity, Azure AD
- **CI/CD**: GitHub Actions, Azure DevOps

## Tips

1. **Start small**: Begin with `small` effort plans to get familiar
2. **Iterate**: Plans can be updated based on discoveries during implementation
3. **Track blockers**: Document issues in the plan for transparency
4. **Maintain both builds**: Always update both Maven and Gradle when adding dependencies
5. **Follow conventions**: AI will apply project-specific patterns from `copilot-instructions.md`

## Files Location

- **Prompts**: `.github/prompts/`
- **Plans**: `docs/plans/`
- **Code Instructions**: `.github/copilot-instructions.md`
- **This Guide**: `docs/PROMPTS.md`
