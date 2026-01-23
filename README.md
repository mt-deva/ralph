# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs [Claude Code](https://claude.ai/code) repeatedly until all tasks are complete. Each iteration is a fresh Claude Code instance with clean context. Memory persists via git history (with learnings in commit messages) and Claude Code Tasks.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

## Why Ralph Works Now

As model capabilities grow with Opus 4.5, Claude can run autonomously for longer and track its state better. Ralph leverages Claude Code's new **Tasks** primitive - an evolution from the simpler TodoWrite tool that enables:

- **Cross-session coordination**: Tasks persist to `~/.claude/tasks/` and sync across all sessions with the same task list ID
- **Dependency management**: Tasks can block each other, mirroring how real projects work
- **Multi-agent collaboration**: Multiple Ralph instances or subagents can work on the same task list in parallel

This is why Ralph's architecture works: each iteration is a fresh session, but Tasks provide the coordination layer that persists across context windows.

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Setup

Copy the ralph files into your project:

```bash
mkdir -p .ralph
cp /path/to/ralph/ralph.sh .ralph/
cp /path/to/ralph/prompt-plan.md .ralph/
cp /path/to/ralph/prompt-build.md .ralph/
cp /path/to/ralph/wt-hooks.toml .ralph/
chmod +x .ralph/ralph.sh
```

## Complete Workflow

```bash
# 1. Plan mode - create tasks
./.ralph/ralph.sh plan 10

# 2. Build mode - execute tasks
./.ralph/ralph.sh 150

# 3. (Optional) Parallel with worktrunk
# Terminal 1:
wt switch -c ralph/task-1
CLAUDE_CODE_TASK_LIST_ID=my-feature ./.ralph/ralph.sh 50

# Terminal 2:
wt switch -c ralph/task-2
CLAUDE_CODE_TASK_LIST_ID=my-feature ./.ralph/ralph.sh 50

# Check status:
wt list   # Worktree status

# Merge when done:
wt merge
```

**Specification context:** Ralph reads `docs/*.md` files for project specifications, architecture decisions, and requirements. This context helps Claude understand what to build. PRDs and requirements get converted to Tasks during planning mode.

## Task Management

Ralph uses Claude Code Tasks - a coordination primitive designed for complex projects. Unlike the previous TodoWrite tool, Tasks are:

- **Persistent**: Stored in `~/.claude/tasks/<task-list-id>/` on the filesystem
- **Shared**: All sessions with the same `CLAUDE_CODE_TASK_LIST_ID` see real-time updates
- **Structured**: Support dependencies, blockers, status tracking, and ownership
- **Collaborative**: Enable multiple agents or sessions to work on the same project

| Feature | How It Works |
|---------|--------------|
| Task storage | `~/.claude/tasks/<task-list-id>/` |
| Cross-session sync | All sessions with same `CLAUDE_CODE_TASK_LIST_ID` see updates |
| Task creation | Via TaskCreate tool in planning mode |
| Task updates | Via TaskUpdate tool in build mode |
| Task viewing | Via TaskList and TaskGet tools |
| Dependencies | Tasks can block each other via `blocks`/`blockedBy` metadata |

**Task list ID** is auto-generated from `<directory>-<branch>` or set manually:
```bash
CLAUDE_CODE_TASK_LIST_ID=my-feature ./ralph.sh 50
```

### Task API

Ralph uses these Claude Code tools to manage tasks:

**TaskCreate** - Create new tasks (plan mode):
```json
{
  "subject": "Add status column to tasks table",
  "description": "Add status enum column with values: pending, in_progress, done. Default to pending.",
  "activeForm": "Adding status column to tasks table"
}
```

**TaskUpdate** - Update task status (build mode):
```json
{
  "taskId": "task-123",
  "status": "in_progress"  // or "completed"
}
```

**TaskList** - View all tasks:
Returns list with id, subject, status, owner, blockedBy

**TaskGet** - Get task details:
Returns full task info including description

### Task Lifecycle

1. **Plan mode**: TaskCreate creates tasks with status `pending`
2. **Build mode**:
   - TaskList shows available tasks
   - TaskUpdate sets status to `in_progress` when starting
   - TaskUpdate sets status to `completed` when done
3. **All modes**: Tasks persist to filesystem, sync across all sessions with same task list ID

## Parallel Execution with Worktrunk

For running multiple Ralph agents in parallel:

```bash
# Install worktrunk
brew install worktrunk/worktrunk/worktrunk

# Setup hooks (pre-merge typecheck, lint, test)
mkdir -p .config
cp .ralph/wt-hooks.toml .config/wt.toml

# Terminal 1:
wt switch -c ralph/task-1
CLAUDE_CODE_TASK_LIST_ID=my-feature ./.ralph/ralph.sh 50

# Terminal 2:
wt switch -c ralph/task-2
CLAUDE_CODE_TASK_LIST_ID=my-feature ./.ralph/ralph.sh 50

# Check status
wt list   # Worktree status

# Merge when done
wt merge
```

Key commands:
- `wt switch -c <branch>` - create worktree and switch
- `wt list` - show all worktrees
- `wt merge` - merge current worktree to main
- `wt remove` - clean up worktree

**Critical:** Use the same `CLAUDE_CODE_TASK_LIST_ID` across all terminals so task updates broadcast to all agents.

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new Claude Code instance** with clean context. This prevents context pollution and allows Opus 4.5 to work autonomously without degradation. Memory persists between iterations via:
- **Git history**: Commits with learnings from previous iterations
- **Claude Code Tasks**: Real-time sync via `~/.claude/tasks/` - when one session updates a task, all other sessions see the change immediately

### Small Tasks

Each task should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized tasks:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because Claude Code automatically reads these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Tasks

Frontend tasks must include browser verification. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

- **Build mode**: When all tasks are completed, outputs `<promise>COMPLETE</promise>`
- **Plan mode**: After creating tasks, outputs `<promise>PLAN_COMPLETE</promise>`
- **Empty task list**: Ralph exits when no pending tasks remain

## Debugging

```bash
# See learnings from previous iterations (in commit messages)
git log --oneline -10
git log --grep="Learnings" -5

# Check task list (stored in ~/.claude/tasks/)
ls ~/.claude/tasks/
```

## Customizing Prompts

Two mode-specific prompt files:
- `prompt-plan.md` - Task creation instructions (no code writing)
- `prompt-build.md` - Implementation instructions

Both contain: Critical guardrail, subagent usage, ultrathink guidance.

Edit to customize for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

### Critical Guardrail

The prompt includes a guardrail to prevent Ralph's Achilles' heel: re-implementing existing code. Ralph is instructed to search the codebase before writing any new code.

## Skills

- `/prd` - Generate a PRD from a feature description (saves to docs/)
- `/prd-to-tasks` - Convert a PRD document into Claude Code Tasks (creates Tasks from docs/*.md)
