#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [max_iterations] [prd_path] [timeout_seconds]

set -e

MAX_ITERATIONS=${1:-10}
ITERATION_TIMEOUT=${3:-1800}  # 30 minutes default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="${2:-$SCRIPT_DIR/prd.json}"

# Resolve to absolute path
if [[ ! "$PRD_FILE" = /* ]]; then
  PRD_FILE="$(pwd)/$PRD_FILE"
fi

if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found: $PRD_FILE"
  exit 1
fi
PRD_DIR="$(dirname "$PRD_FILE")"
PROGRESS_FILE="$PRD_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Max iterations: $MAX_ITERATIONS, Timeout: ${ITERATION_TIMEOUT}s"
echo "PRD: $PRD_FILE"
echo "Progress: $PROGRESS_FILE"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  # Find next incomplete story and set as currentStory in PRD
  NEXT_STORY=$(jq -r '.userStories[] | select(.passes == false) | .id' "$PRD_FILE" | head -1)
  if [ -z "$NEXT_STORY" ]; then
    echo "All stories complete!"
    exit 0
  fi
  echo "Current story: $NEXT_STORY"
  jq --arg id "$NEXT_STORY" '.currentStory = $id' "$PRD_FILE" > "$PRD_FILE.tmp" && mv "$PRD_FILE.tmp" "$PRD_FILE"

  # Run opencode with the ralph prompt (use @ to reference file inline)
  OUTPUT=$(timeout "$ITERATION_TIMEOUT" opencode run --model=google/antigravity-claude-opus-4-5-thinking --variant=max "Execute the instructions in @$SCRIPT_DIR/prompt.md - PRD location: $PRD_FILE - Progress location: $PROGRESS_FILE" 2>&1 | tee /dev/stderr)
  EXIT_CODE=$?

  # Check for timeout
  if [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "WARNING: Iteration $i timed out after ${ITERATION_TIMEOUT}s"
    echo "## TIMEOUT at $(date) - Iteration $i" >> "$PROGRESS_FILE"
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
