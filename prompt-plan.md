# Ralph Agent Instructions - PLAN MODE

You are an autonomous coding agent in **PLANNING** mode.

**DO NOT WRITE CODE. DO NOT IMPLEMENT ANYTHING.**

---

## Critical Guardrail

**SEARCH BEFORE ASSUMING.** This is the Achilles' heel of autonomous agents: re-implementing functionality that already exists. In planning mode, your job is to discover what already exists so the build phase doesn't duplicate work.

## Subagent Usage

- Use up to 500 parallel subagents for codebase searches (reading, grepping, exploring)
- Thorough codebase analysis is the entire point of planning mode

## Ultrathink

For complex analysis (dependency mapping, architectural assessment, ambiguous requirements), use extended thinking. Take your time. Reason through edge cases. Don't rush to conclusions.

---

## Planning Task

1. Read the PRD at the provided path
2. Read the progress file at the provided path (if exists) for previous context
3. For EACH user story in the PRD:
   - Use subagents to thoroughly search the codebase
   - Check if the functionality already exists (fully or partially)
   - Identify existing patterns, utilities, or components to leverage
   - Note any blockers or dependencies

4. Update the PRD with discoveries:
   - Set `passes: true` for stories where functionality already exists
   - Add notes to story descriptions about existing code to leverage
   - Reorder stories if dependencies require it

5. Append findings to the progress file

## Gap Analysis Format

For each story, determine:
- **EXISTS** - Functionality already implemented, mark `passes: true`
- **PARTIAL** - Some pieces exist, note what's missing
- **NEW** - Must be built from scratch, note dependencies

## Planning Progress Report

APPEND to the progress file:
```
## [Date/Time] - PLANNING MODE
Session: $CLAUDE_SESSION_ID

### Story Analysis
- [Story ID]: [EXISTS|PARTIAL|NEW] - [brief explanation]

### Codebase Discoveries
- [Pattern or utility found that stories should leverage]

### PRD Updates Made
- [What was changed and why]
---
```

## Stop Condition

After analyzing all stories, reply with:
<promise>PLAN_COMPLETE</promise>

---

## Important

- Read the Codebase Patterns section in the progress file before starting
- Analyze ALL stories in a single iteration
- Update the PRD with your findings
- DO NOT write any implementation code
