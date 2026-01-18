# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs [Claude Code](https://claude.ai/code) repeatedly until all PRD items are complete. Each iteration is a fresh Claude Code instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Setup

Copy the ralph files into your project:

```bash
mkdir -p .ralph
cp /path/to/ralph/ralph.sh .ralph/
cp /path/to/ralph/prompt-plan.md .ralph/
cp /path/to/ralph/prompt-build.md .ralph/
chmod +x .ralph/ralph.sh
```

## Complete Workflow

```bash
# 1. Convert PRD (using /ralph skill in Claude Code)
/ralph convert prd.md to .ralph/prd.json

# 2. Plan mode - analyze existing code for gaps
./.ralph/ralph.sh plan 10 .ralph/prd.json

# 3. Build mode (sequential)
./.ralph/ralph.sh 150 .ralph/prd.json

# 4. (Optional) Parallel with beads + worktrunk
bd init
# Convert prd.json → tasks.jsonl (see conversion section below)
bd import -i .ralph/tasks.jsonl

# Terminal 1:
wt switch -c ralph/task-1
./.ralph/ralph.sh 50  # Picks unblocked task from bd ready

# Terminal 2:
wt switch -c ralph/task-2
./.ralph/ralph.sh 50  # Picks different unblocked task

# Check status:
wt list   # Worktree status
bd list   # Task dependencies

# Merge when done:
wt merge
```

## prd.json vs Beads

Two separate approaches, not a conversion:

| Aspect | prd.json | Beads |
|--------|----------|-------|
| Use case | Sequential, solo execution | Parallel, multiple agents |
| Task selection | Highest priority with `passes: false` | `bd ready` (respects dependencies) |
| Parallelism | None - one story at a time | Multiple worktrees, multiple Ralphs |
| Dependencies | Implicit via priority ordering | Explicit via `--dep` flags |
| Setup | Single JSON file | `bd init`, create tasks manually |

**Recommendation:**
- Start with prd.json (simpler)
- Graduate to beads when you need parallelism
- One massive prd.json is fine - Ralph only reads it, picks one story per iteration

**Beads mode detection:** Ralph auto-detects when `.beads/` directory exists:
- With `.beads/`: uses `bd ready` for task selection
- Without: falls back to `prd.json`
- Disable: `RALPH_NO_BEADS=1 ./ralph.sh`

## Converting prd.json to Beads

### Option 1: JSONL Import (Recommended)

Beads has native import: `bd import -i issues.jsonl`

```bash
# 1. Initialize beads
bd init

# 2. Convert prd.json to JSONL format
# Each line is a JSON object:
{"id":"bd-us001","title":"US-001: Story Title","description":"As a user...","status":"open","priority":1,"type":"feature","dependencies":[]}
{"id":"bd-us002","title":"US-002: Second Story","description":"...","status":"open","priority":2,"type":"feature","dependencies":["bd-us001"]}

# 3. Import
bd import -i tasks.jsonl --dry-run  # Preview first
bd import -i tasks.jsonl            # Actual import
```

**Import flags:**
- `--dry-run` - preview without creating
- `--skip-existing` - don't overwrite
- `--force` - refresh all from JSONL

### Option 2: Rapid-fire bd create

```bash
bd init
bd create "US-001: Story Title" -p 1
bd create "US-002: Second Story" -p 2 --dep bd-xxx
bd sync  # Flush to disk
```

### Scripted Conversion

Ask Claude:
```
Read my prd.json and generate a beads JSONL file.
Map userStories to beads issues with:
- id: "bd-" + story.id (lowercase)
- title: story.id + ": " + story.title
- description: story.description + "\n\nAcceptance Criteria:\n" + criteria
- priority: story.priority
- dependencies: based on priority ordering
```

## Worktree Tools

| Tool | Use When |
|------|----------|
| `bd worktree` | Using beads - auto-configures DB sharing |
| git-worktree skill | No beads, want .env auto-copy |
| worktrunk (wt) | Need CI hooks, pre-merge gates (recommended) |

**If using beads** - prefer `bd worktree`:
```bash
bd worktree create .worktrees/feature-a --branch feature/a
bd worktree list
bd worktree remove .worktrees/feature-a
```

**Worktrunk** adds CI layer on top:
```bash
# Install
brew install worktrunk/worktrunk/worktrunk

# Setup hooks
mkdir -p .config
cp /path/to/ralph/wt-hooks.toml .config/wt.toml
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new Claude Code instance** with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
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

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

- **Build mode**: When all stories have `passes: true`, outputs `<promise>COMPLETE</promise>`
- **Plan mode**: After analyzing all stories, outputs `<promise>PLAN_COMPLETE</promise>`

## Debugging

```bash
# See which stories are done
jq '.userStories[] | {id, title, passes}' prd.json

# See incomplete stories only
jq '.userStories[] | select(.passes == false) | {id, title}' prd.json

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10

# Beads status
bd list
bd ready
```

## Customizing Prompts

Two mode-specific prompt files:
- `prompt-plan.md` - Gap analysis instructions (no code writing)
- `prompt-build.md` - Implementation instructions

Both contain: Critical guardrail, subagent usage, ultrathink guidance.

Edit to customize for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

### Critical Guardrail

The prompt includes a guardrail to prevent Ralph's Achilles' heel: re-implementing existing code. Ralph is instructed to search the codebase before writing any new code.

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.

## Key Patterns

- **bd sync at session end**: Always run `bd sync` before ending to flush changes (bypasses 30-sec debounce)
- **Per-worktree progress.txt**: Avoids merge conflicts across parallel agents
- **Single orchestrator**: For advanced parallel setups, have one orchestrator assign tasks to workers
