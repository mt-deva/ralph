#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [max_iterations] [prd_path] [timeout_seconds]
#        ./ralph.sh plan [max_iterations] [prd_path] [timeout_seconds]

set -e

# Color support - auto-detect + NO_COLOR support
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
  BLUE='\033[0;34m' CYAN='\033[0;36m' BOLD='\033[1m' DIM='\033[2m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# Log functions
log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

# Detect plan mode
MODE="build"
if [[ "$1" == "plan" ]]; then
  MODE="plan"
  shift  # Remove 'plan' from args so remaining args work normally
fi

# Detect beads mode
USE_BEADS=false
if [ -d ".beads" ] && [ "$RALPH_NO_BEADS" != "1" ]; then
  if command -v bd >/dev/null 2>&1; then
    USE_BEADS=true
  else
    log_warn "Beads directory found but 'bd' command not installed, falling back to PRD"
  fi
fi

MAX_ITERATIONS=${1:-10}
ITERATION_TIMEOUT=${3:-1800}  # 30 minutes default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="${2:-$SCRIPT_DIR/prd.json}"

# Resolve to absolute path
if [[ ! "$PRD_FILE" = /* ]]; then
  PRD_FILE="$(pwd)/$PRD_FILE"
fi

# PRD file required unless using beads
if [ -f "$PRD_FILE" ]; then
  PRD_DIR="$(dirname "$PRD_FILE")"
elif [[ "$USE_BEADS" == "true" ]]; then
  PRD_DIR="$(pwd)"  # beads-only mode, no PRD needed
else
  log_error "PRD file not found: $PRD_FILE"
  exit 1
fi
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

    log_info "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    log_success "Archived to: $ARCHIVE_FOLDER"

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

# Set mode-specific prompt file and completion signal
if [[ "$MODE" == "plan" ]]; then
  PROMPT_FILE="$SCRIPT_DIR/prompt-plan.md"
  COMPLETION_SIGNAL="<promise>PLAN_COMPLETE</promise>"
  MODE_LABEL="PLAN"
else
  PROMPT_FILE="$SCRIPT_DIR/prompt-build.md"
  COMPLETION_SIGNAL="<promise>COMPLETE</promise>"
  MODE_LABEL="BUILD"
fi

# Banner
printf "\n"
printf "${BOLD}============================================${NC}\n"
printf "${BOLD}Ralph${NC} - Autonomous AI Agent Loop\n"
printf "Mode: ${CYAN}%s${NC}\n" "$MODE_LABEL"
if [[ "$USE_BEADS" == "true" ]]; then
  printf "Tasks: ${CYAN}Beads (.beads/)${NC}\n"
else
  printf "PRD: ${CYAN}%s${NC}\n" "$PRD_FILE"
fi
printf "Engine: ${CYAN}OpenCode${NC}\n"
printf "Max: ${YELLOW}%s iterations${NC}, Timeout: ${YELLOW}%ss${NC}\n" "$MAX_ITERATIONS" "$ITERATION_TIMEOUT"
printf "${BOLD}============================================${NC}\n"

for i in $(seq 1 $MAX_ITERATIONS); do
  printf "\n${BOLD}>>> Iteration %d of %d (%s)${NC}\n" "$i" "$MAX_ITERATIONS" "$MODE_LABEL"
  printf "${DIM}────────────────────────────────────────${NC}\n"

  # In build mode, find and set next story/task. In plan mode, skip this.
  if [[ "$MODE" == "build" ]]; then
    if [[ "$USE_BEADS" == "true" ]]; then
      # Beads mode: get next ready task
      NEXT_TASK=$(bd ready --json 2>/dev/null | jq -r '.[0].id // empty')
      if [ -z "$NEXT_TASK" ]; then
        log_success "All tasks complete (bd ready returned empty)"
        printf "\n${BOLD}============================================${NC}\n"
        printf "${GREEN}✓ Ralph completed all tasks!${NC}\n"
        printf "Finished at iteration ${CYAN}%d${NC} of %d\n" "$i" "$MAX_ITERATIONS"
        printf "${BOLD}============================================${NC}\n"
        exit 0
      fi
      export RALPH_CURRENT_TASK="$NEXT_TASK"
      log_info "Current task: $NEXT_TASK (beads)"
    else
      # PRD mode: get next incomplete story
      NEXT_STORY=$(jq -r '.userStories[] | select(.passes == false) | .id' "$PRD_FILE" | head -1)
      if [ -z "$NEXT_STORY" ]; then
        log_success "All stories complete!"
        printf "\n${BOLD}============================================${NC}\n"
        printf "${GREEN}✓ Ralph completed all tasks!${NC}\n"
        printf "Finished at iteration ${CYAN}%d${NC} of %d\n" "$i" "$MAX_ITERATIONS"
        printf "${BOLD}============================================${NC}\n"
        exit 0
      fi
      log_info "Current story: $NEXT_STORY"
    fi
  else
    log_info "Planning mode - analyzing all stories"
  fi

  # Build task context for prompt
  TASK_CONTEXT=""
  if [[ -n "$RALPH_CURRENT_TASK" ]]; then
    TASK_CONTEXT=" - Current task: $RALPH_CURRENT_TASK"
  fi

  # Run opencode with prompt
  OUTPUT=$(timeout "$ITERATION_TIMEOUT" opencode run --model=google/antigravity-claude-opus-4-5-thinking --variant=max "Execute the instructions in @$PROMPT_FILE - PRD location: $PRD_FILE - Progress location: $PROGRESS_FILE$TASK_CONTEXT" 2>&1 | tee /dev/stderr)
  EXIT_CODE=$?

  # Check for timeout
  if [ $EXIT_CODE -eq 124 ]; then
    printf "\n"
    log_warn "Iteration $i timed out after ${ITERATION_TIMEOUT}s"
    echo "## TIMEOUT at $(date) - Iteration $i" >> "$PROGRESS_FILE"
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "$COMPLETION_SIGNAL"; then
    printf "\n${BOLD}============================================${NC}\n"
    printf "${GREEN}✓ Ralph %s complete!${NC}\n" "$MODE_LABEL"
    printf "Finished at iteration ${CYAN}%d${NC} of %d\n" "$i" "$MAX_ITERATIONS"
    printf "${BOLD}============================================${NC}\n"
    exit 0
  fi

  log_success "Iteration $i complete"
  sleep 2
done

printf "\n"
log_warn "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
log_info "Check $PROGRESS_FILE for status."
exit 1
