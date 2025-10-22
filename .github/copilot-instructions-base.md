# Base AI Coding Agent Instructions

## General Development Principles

### Code Implementation Rules

#### Unit Testing Requirements
**Always create unit tests for new features**:
- Use the project's standard testing framework
- Use appropriate assertion libraries
- Test with actual dependencies when appropriate (not just mocks)
- Place tests in matching package/directory structure under test folder
- Aim for meaningful coverage of logic paths, not just line coverage

#### Atomic Commits for Clean History
**One logical change per commit**:
- ✅ "Add validation method to UserRepository"
- ✅ "Implement user search by email feature"
- ✅ "Add unit tests for user email search"
- ❌ "Update user features and fix bugs and add tests"

**Commit message format**:
```
Short summary (50 chars or less)

Detailed explanation if needed. Wrap at 72 characters.
Explain the what and why, not the how.

Signed-off-by: Your Name <your.email@example.com>
```

**Before committing**:
1. Format code according to project standards
2. Run build and tests to validate changes
3. Stage related changes only (use selective staging if needed)
4. Write clear, descriptive commit message
5. Include required trailers (Signed-off-by, Co-authored-by, etc.)

### Language Best Practices
- **Prefer immutability** - Use const/final/readonly where possible
- **Dependency injection** over global state
- **Composition over inheritance** when appropriate
- **Named functions** over complex lambdas for clarity
- **Explicit over implicit** - Clear code beats clever code
- Follow **framework conventions** - Use auto-configuration and defaults

### Code Quality Standards
- **No hardcoded values** - Use configuration, environment variables, or constants
- **Error handling** - Handle expected errors gracefully, let unexpected ones bubble up
- **Logging** - Use appropriate log levels (debug, info, warn, error)
- **Security** - Never commit secrets, use secure defaults
- **Performance** - Don't optimize prematurely, but avoid obvious inefficiencies

## Structured Development Workflow

### Custom AI Prompts
This project may include structured prompts for goal-oriented development in `.github/prompts/`:

**Common workflows**:
- `/create-goal-plan` - Create implementation plans with task breakdown, agent delegation, and acceptance criteria
- `/implement-plan <name>` - Execute plans with atomic commits and parallel agent tasks
- `/list-plans [status]` - View all plans and their progress

**When to use**:
- Starting new features or significant changes
- Cloud migration tasks
- Multi-step implementations requiring coordination
- Work that can be parallelized (core implementation + tests/docs)

**Plan structure** (`docs/plans/plan-*.md`):
- Tasks with clear dependencies
- Files to modify/create
- Testing strategy
- Agent-delegatable work (unit tests, docs, refactoring)
- Acceptance criteria

See `docs/PROMPTS.md` if available for detailed workflow guide.

### GitHub Copilot Agent Delegation
Plans can delegate parallelizable tasks to GitHub Copilot Agent:
- **Unit tests** - Test creation after implementing features
- **Integration tests** - End-to-end test scenarios
- **Documentation** - API docs, README updates, diagrams
- **Refactoring** - Repetitive code improvements across files

Delegated tasks are tracked via GitHub issues with `[Agent]` prefix.

## Build & Development Workflows

### Before Making Changes
1. Understand the project structure and conventions
2. Read relevant existing code
3. Check for similar implementations
4. Identify affected test files

### Development Cycle
1. **Plan** - Break down work into small, testable increments
2. **Implement** - Write minimal code to achieve the goal
3. **Test** - Create/update tests to verify behavior
4. **Validate** - Run build, tests, linters
5. **Commit** - Atomic commit with clear message
6. **Repeat** - Next increment

### Adding Dependencies
1. Update all build configuration files consistently
2. Use version variables/properties for easier management
3. Document why the dependency is needed
4. Verify the dependency doesn't introduce conflicts
5. Run full build to ensure compatibility

## Contributing Standards

### Code Review Checklist
Before considering work complete:
- [ ] Code follows project style/formatting
- [ ] Tests created/updated and passing
- [ ] Documentation updated if needed
- [ ] No linting/analysis warnings introduced
- [ ] Atomic commits with clear messages
- [ ] Required commit trailers included

### Communication
- **Commit messages** - Explain what and why, not how
- **PR descriptions** - Link to issues, explain approach, highlight risks
- **Code comments** - Explain complex logic, not obvious code
- **Documentation** - Keep user-facing docs in sync with code

## Project-Specific Instructions

**Note**: Check for `copilot-instructions-{language}.md` or `copilot-instructions-{framework}.md` files for language and framework-specific patterns, conventions, and requirements specific to this project.

Common supplement files:
- `copilot-instructions-java.md` - Java/Spring Boot specifics
- `copilot-instructions-python.md` - Python specifics
- `copilot-instructions-typescript.md` - TypeScript/Node.js specifics
- `copilot-instructions-dotnet.md` - .NET/C# specifics
