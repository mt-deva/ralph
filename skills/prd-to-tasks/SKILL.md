---
name: converting-prd-to-tasks
description: "Convert PRDs to Claude Code Tasks via TaskCreate. Use when you have an existing PRD and need to create tasks for Ralph. Triggers on: convert this prd, turn this into tasks, create tasks from this, prd to tasks."
---

# PRD to Tasks Converter

Converts existing PRDs to Claude Code Tasks that Ralph uses for autonomous execution.

---

## Task Namespace Detection

**At the START**, detect both namespaces:

1. **Current namespace** (where tasks will be created): Use Bash `echo "${CLAUDE_CODE_TASK_LIST_ID:-default}"`
2. **Ralph's expected namespace**: Use Bash `echo "$(basename "$(pwd)")-$(git branch --show-current 2>/dev/null || echo main)"`

Proceed with creating tasks in the current namespace.

**At the END**, output a clear summary:

```
✓ Created N tasks in namespace: {current_namespace}

Ralph expects namespace: {ralph_namespace}
{if they match: "✓ Namespaces match - ralph will find these tasks"}
{if they don't: "⚠ Mismatch - Run ralph with: CLAUDE_CODE_TASK_LIST_ID={current_namespace} ./.ralph/ralph.sh plan 10"}
```

---

## The Job

Take a PRD (markdown file or text) and convert it to tasks via TaskCreate. Tasks persist via `CLAUDE_CODE_TASK_LIST_ID` environment variable.

---

## Output Format

Each task requires these fields for TaskCreate:

```json
{
  "subject": "Add status column to tasks table",
  "description": "Add status column to tasks table with enum values: pending, in_progress, completed. Set default to pending.",
  "activeForm": "Adding status column to tasks table"
}
```

| Field | Description | Example |
|-------|-------------|---------|
| `subject` | Brief imperative task title | "Add login API endpoint" |
| `description` | Detailed description of what needs to be done | "Create POST /api/login endpoint that accepts email/password and returns JWT token" |
| `activeForm` | Present participle (-ing) form shown in spinner | "Adding login API endpoint" |

All tasks are created with status `pending`. Use TaskUpdate to change status to `in_progress` or `completed`.

## Task Persistence

Tasks persist to `~/.claude/tasks/<task-list-id>/` and sync across sessions:

- **Set task list:** `CLAUDE_CODE_TASK_LIST_ID=my-feature claude`
- **Multiple sessions:** All sessions with same ID see updates in real-time
- **Subagents:** Task updates broadcast to all agents working on same list

Ralph sets this automatically from directory + branch name.

---

## Task Size: The Number One Rule

**Each task must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh Claude Code instance per iteration with no memory of previous work. If a task is too big, the LLM runs out of context before finishing and produces broken code.

### Right-sized tasks:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" → Split into: schema, queries, UI components, filters
- "Add authentication" → Split into: schema, middleware, login UI, session handling
- "Refactor the API" → Split into one task per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Task Ordering: Dependencies First

Tasks execute in list order. Earlier tasks must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that does not exist yet)
2. Schema change

---

## Search Codebase First

Before creating tasks, search for existing functionality:

1. Use Grep/Glob to find related code
2. Mark already-implemented features as `completed`
3. Note location in task description for partial implementations

**If functionality exists:** Create the task, then immediately mark it as `completed` using TaskUpdate:
```json
// First create with TaskCreate:
{
  "subject": "Add users table migration",
  "description": "Add users table migration (already exists in db/migrations/001_users.sql)",
  "activeForm": "Adding users table migration"
}

// Then mark completed with TaskUpdate:
{
  "taskId": "<task-id>",
  "status": "completed"
}
```

---

## Task Descriptions: Must Be Verifiable

Each task description should be something Ralph can CHECK, not something vague.

### Good descriptions (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Create filter dropdown with options: All, Active, Completed"
- "Add delete button that shows confirmation dialog"
- "Build login form with email/password fields"

### Bad descriptions (vague):
- "Implement the feature correctly"
- "Make it work"
- "Add good UX"
- "Handle edge cases"

---

## Splitting Large PRDs

If a PRD has big features, split them:

**Original:**
> "Add user notification system"

**Split into:**
1. Add notifications table to database
2. Create notification service for sending notifications
3. Add notification bell icon to header
4. Create notification dropdown panel
5. Add mark-as-read functionality
6. Add notification preferences page

Each is one focused change that can be completed and verified independently.

---

## Example

**Input PRD:**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done on task list
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Process:**
1. Search codebase for existing status handling → None found
2. Break into 4 ordered tasks (schema → UI → interaction → filtering)
3. Create tasks via TaskCreate (call TaskCreate 4 times, once per task)

**Output TaskCreate calls:**
```json
// Task 1
{
  "subject": "Add status field to tasks table",
  "description": "Add status field to tasks table with enum: pending, in_progress, done (default pending). Include database migration.",
  "activeForm": "Adding status field to tasks table"
}

// Task 2
{
  "subject": "Display status badge on task cards",
  "description": "Display status badge on task cards with colors: gray=pending, blue=in_progress, green=done",
  "activeForm": "Displaying status badge on task cards"
}

// Task 3
{
  "subject": "Add status dropdown to task rows",
  "description": "Add status dropdown to each task row that saves immediately without page refresh",
  "activeForm": "Adding status dropdown to task rows"
}

// Task 4
{
  "subject": "Add status filter dropdown",
  "description": "Add status filter dropdown (All, Pending, In Progress, Done) that persists in URL params",
  "activeForm": "Adding status filter dropdown"
}
```

**Output summary:**
```
Created 4 tasks from PRD:
- 4 pending (new work)
- 0 completed (already exists)

Task order:
1. Add status field to tasks table - pending
2. Display status badge on task cards - pending
3. Add status dropdown to task rows - pending
4. Add status filter dropdown - pending
```

---

## Checklist Before Creating Tasks

Before calling TaskCreate, verify:

- [ ] Searched codebase for existing functionality
- [ ] Each task is completable in one iteration (small enough)
- [ ] Tasks are ordered by dependency (schema → backend → UI)
- [ ] Task descriptions are verifiable (not vague)
- [ ] No task depends on a later task
- [ ] `subject` uses imperative form ("Add...", "Create...", "Build...")
- [ ] `description` provides detailed context and acceptance criteria
- [ ] `activeForm` uses present participle ("Adding...", "Creating...", "Building...")

Tasks will persist to `~/.claude/tasks/` and sync across all Ralph iterations automatically.
