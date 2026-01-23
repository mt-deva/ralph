---
name: converting-prd-to-tasks
description: "Convert PRDs to Claude Code Tasks via TodoWrite. Use when you have an existing PRD and need to create tasks for Ralph. Triggers on: convert this prd, turn this into tasks, create tasks from this, prd to tasks."
---

# PRD to Tasks Converter

Converts existing PRDs to Claude Code Tasks that Ralph uses for autonomous execution.

---

## The Job

Take a PRD (markdown file or text) and convert it to tasks via TodoWrite. Tasks persist via `CLAUDE_CODE_TASK_LIST_ID` environment variable.

---

## Output Format

Each task requires these fields:

```json
{
  "todos": [
    {
      "content": "Add status column to tasks table",
      "status": "pending",
      "activeForm": "Adding status column to tasks table"
    }
  ]
}
```

| Field | Description | Example |
|-------|-------------|---------|
| `content` | Imperative task description | "Add login API endpoint" |
| `status` | `pending`, `in_progress`, or `completed` | "pending" |
| `activeForm` | Present participle (-ing) form | "Adding login API endpoint" |

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

**If functionality exists:** Mark task as `completed` immediately with note:
```json
{
  "content": "Add users table migration",
  "status": "completed",
  "activeForm": "Adding users table migration"
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
3. Create tasks via TodoWrite

**Output TodoWrite call:**
```json
{
  "todos": [
    {
      "content": "Add status field to tasks table with enum: pending, in_progress, done (default pending)",
      "status": "pending",
      "activeForm": "Adding status field to tasks table"
    },
    {
      "content": "Display status badge on task cards with colors: gray=pending, blue=in_progress, green=done",
      "status": "pending",
      "activeForm": "Displaying status badge on task cards"
    },
    {
      "content": "Add status dropdown to each task row that saves immediately without page refresh",
      "status": "pending",
      "activeForm": "Adding status dropdown to task rows"
    },
    {
      "content": "Add status filter dropdown (All, Pending, In Progress, Done) that persists in URL params",
      "status": "pending",
      "activeForm": "Adding status filter dropdown"
    }
  ]
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

Before calling TodoWrite, verify:

- [ ] Searched codebase for existing functionality
- [ ] Each task is completable in one iteration (small enough)
- [ ] Tasks are ordered by dependency (schema → backend → UI)
- [ ] Task descriptions are verifiable (not vague)
- [ ] No task depends on a later task
- [ ] `content` uses imperative form ("Add...", "Create...", "Build...")
- [ ] `activeForm` uses present participle ("Adding...", "Creating...", "Building...")

Tasks will persist to `~/.claude/tasks/` and sync across all Ralph iterations automatically.
