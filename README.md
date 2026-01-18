# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs [Claude Code](https://claude.ai/code) repeatedly until all PRD items are complete. Each iteration is a fresh Claude Code instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Setup

### Option 1: Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/
cp /path/to/ralph/prompt-plan.md scripts/ralph/
cp /path/to/ralph/prompt-build.md scripts/ralph/
chmod +x scripts/ralph/ralph.sh
```

### Option 2: Install skills globally

Copy the skills to your Claude Code config for use across all projects:

```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

This allows you to use the PRD and Ralph skills across all your projects.

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
/prd create a PRD for @prd.md
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to JSON:

```
/ralph convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
# Build mode (default) - implement stories
./scripts/ralph/ralph.sh [max_iterations] [prd_path]

# Plan mode - gap analysis only, no code
./scripts/ralph/ralph.sh plan [max_iterations] [prd_path]
```

Default is 10 iterations. Default PRD path is `prd.json` in the ralph directory.

**Plan mode** (optional): Analyzes codebase against PRD, marks existing functionality as done, updates stories with implementation notes. Use when starting a PRD on an existing codebase.

**Build mode**: Implements stories one at a time.

Ralph will:
1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

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

Check current state:

```bash
# See which stories are done
jq '.userStories[] | {id, title, passes}' prd.json

# See incomplete stories only
jq '.userStories[] | select(.passes == false) | {id, title}' prd.json

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
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

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
