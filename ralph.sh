#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [max_iterations] [timeout_seconds]
#        ./ralph.sh plan [max_iterations] [timeout_seconds]

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

MAX_ITERATIONS=${1:-10}
ITERATION_TIMEOUT=${2:-1800}  # 30 minutes default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate task list ID from directory + branch
TASK_LIST_ID="${CLAUDE_CODE_TASK_LIST_ID:-$(basename "$(pwd)")-$(git branch --show-current 2>/dev/null || echo main)}"

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
printf "Tasks: ${CYAN}%s${NC}\n" "$TASK_LIST_ID"
printf "Engine: ${CYAN}Claude Code${NC}\n"
printf "Max: ${YELLOW}%s iterations${NC}, Timeout: ${YELLOW}%ss${NC}\n" "$MAX_ITERATIONS" "$ITERATION_TIMEOUT"
printf "${BOLD}============================================${NC}\n"

for i in $(seq 1 $MAX_ITERATIONS); do
  printf "\n${BOLD}>>> Iteration %d of %d (%s)${NC}\n" "$i" "$MAX_ITERATIONS" "$MODE_LABEL"
  printf "${DIM}────────────────────────────────────────${NC}\n"

  # Claude manages its own tasks via CLAUDE_CODE_TASK_LIST_ID
  if [[ "$MODE" == "build" ]]; then
    log_info "Claude managing tasks via $TASK_LIST_ID"
  else
    log_info "Planning mode - creating tasks"
  fi

  # Get recent commit history for context
  GIT_HISTORY=$(git log --oneline --no-decorate -10 2>/dev/null || echo "No git history")

  # Build prompt args with git history for context
  PROMPT_ARGS="Execute the instructions in @$PROMPT_FILE

Recent commits (for context):
$GIT_HISTORY"

  # Run claude with prompt
  OUTPUT=$(timeout "$ITERATION_TIMEOUT" claude -p "CLAUDE_CODE_TASK_LIST_ID=${TASK_LIST_ID}" --model opus "$PROMPT_ARGS" 2>&1 | tee /dev/stderr)
  EXIT_CODE=$?

  # Check for timeout
  if [ $EXIT_CODE -eq 124 ]; then
    printf "\n"
    log_warn "Iteration $i timed out after ${ITERATION_TIMEOUT}s"
  fi

  # Check for completion signal OR empty task list
  if echo "$OUTPUT" | grep -q "$COMPLETION_SIGNAL"; then
    printf "\n${BOLD}============================================${NC}\n"
    printf "${GREEN}✓ Ralph %s complete!${NC}\n" "$MODE_LABEL"
    printf "Finished at iteration ${CYAN}%d${NC} of %d\n" "$i" "$MAX_ITERATIONS"
    printf "${BOLD}============================================${NC}\n"
    exit 0
  elif echo "$OUTPUT" | grep -qiE "(no pending tasks|task list (is )?empty|all tasks completed)"; then
    printf "\n${BOLD}============================================${NC}\n"
    printf "${GREEN}✓ Ralph %s complete (empty task list)!${NC}\n" "$MODE_LABEL"
    printf "Finished at iteration ${CYAN}%d${NC} of %d\n" "$i" "$MAX_ITERATIONS"
    printf "${BOLD}============================================${NC}\n"
    exit 0
  fi

  log_success "Iteration $i complete"
  sleep 2
done

printf "\n"
log_warn "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
log_info "Check git log for progress."
exit 1
