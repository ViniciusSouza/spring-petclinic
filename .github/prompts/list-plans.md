---
mode: 'agent'
description: 'List all implementation plans with status (pending, in-progress, completed, blocked). Shows progress, effort estimates, and agent task tracking.'
tools: ['read', 'list_dir', 'grep_search']
---

# List Implementation Plans

Display all available implementation plans with their current status.

## Workflow

1. **Scan for Plans**:
   - Look in `docs/plans/` directory for all `plan-*.md` files
   - Parse metadata from each file

2. **Display Plans**:
   
   Group by status and show:
   ```
   📊 Implementation Plans Overview
   
   📋 Pending ({count})
   ────────────────────────────────────────
   1. plan-azure-deployment.md
      Goal: "Deploy to Azure App Service"
      Effort: Medium | Created: 2025-10-22
   
   2. plan-rest-api.md
      Goal: "Add REST API endpoints for mobile app"
      Effort: Large | Created: 2025-10-20
   
   🚧 In Progress ({count})
   ────────────────────────────────────────
   3. plan-email-notifications.md
      Goal: "Email notification system"
      Effort: Small | Started: 2025-10-21
      Progress: 3/5 tasks (60%)
      Agent Tasks: 2/3 complete
   
   ✅ Completed ({count})
   ────────────────────────────────────────
   4. plan-owner-search.md
      Goal: "Enhanced owner search with pagination"
      Effort: Small | Completed: 2025-10-19
   
   🚫 Blocked ({count})
   ────────────────────────────────────────
   5. plan-azure-sql.md
      Goal: "Migrate to Azure SQL Database"
      Effort: Medium | Blocked: 2025-10-18
      Blocker: Waiting for Azure subscription approval
   
   ────────────────────────────────────────
   Total: {total} plans
   
   Use /implement-plan <name> to start implementation
   ```

3. **No Plans Found**:
   - If `docs/plans/` is empty:
     ```
     No implementation plans found.
     
     Create your first plan with /create-goal-plan
     ```

## Additional Commands

- `/list-plans` - Show all plans
- `/list-plans pending` - Show only pending plans
- `/list-plans in-progress` - Show only in-progress plans
- `/list-plans completed` - Show completed plans
