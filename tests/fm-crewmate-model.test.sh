#!/usr/bin/env bash
# Test that spawned crewmates (non-secondmate ship/scout) are pinned to
# deepseek-v4-flash on the pi harness, while secondmates keep the default model.
#
# The launch_template() function in bin/fm-spawn.sh generates the launch command
# per harness. For the pi harness the contract is:
#   non-secondmate (ship/scout): includes --model opencode-go/deepseek-v4-flash
#   secondmate:                   omits --model (uses the pi default)
# Other harnesses (claude, codex, opencode) must be unchanged.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN_SRC="$ROOT/bin/fm-spawn.sh"

# ---------------------------------------------------------------------------
# Test: crewmate (non-secondmate) pi template includes the model flag
# ---------------------------------------------------------------------------

test_crewmate_pi_has_model_flag() {
  local line
  line=$(sed -n '/^    pi)/,/^      ;;$/p' "$SPAWN_SRC" | grep "else" -A1 | grep "printf")
  case "$line" in
    *"--model opencode-go/deepseek-v4-flash"*) pass "crewmate pi template includes --model opencode-go/deepseek-v4-flash" ;;
    *) fail "crewmate pi template missing --model flag: got '$line'" ;;
  esac
}

# ---------------------------------------------------------------------------
# Test: secondmate pi template does NOT include the model flag
# ---------------------------------------------------------------------------

test_secondmate_pi_omits_model_flag() {
  local line
  line=$(sed -n '/^    pi)/,/^      ;;$/p' "$SPAWN_SRC" | grep "secondmate" -A1 | grep "printf")
  case "$line" in
    *"--model"*) fail "secondmate pi template should not have --model flag: got '$line'" ;;
    *) pass "secondmate pi template correctly omits --model flag" ;;
  esac
  # Verify it's the bare pi command
  case "$line" in
    *"pi \"\$"*) : ;;
    *) fail "secondmate pi template format unexpected: got '$line'" ;;
  esac
  pass "secondmate pi template uses bare pi command"
}

# ---------------------------------------------------------------------------
# Test: other harnesses do NOT have --model flags
# ---------------------------------------------------------------------------

test_other_harnesses_unchanged() {
  local harness

  # claude: multiline block
  harness=claude
  line=$(sed -n "/^    $harness)/,/^      ;;$/p" "$SPAWN_SRC" | grep "printf" | head -1)
  case "$line" in
    *"--model"*) fail "$harness harness unexpectedly contains --model flag" ;;
    *) pass "$harness harness is unchanged (no --model flag)" ;;
  esac

  # opencode: one-liner
  harness=opencode
  line=$(grep "^    opencode)" "$SPAWN_SRC")
  case "$line" in
    *"--model"*) fail "$harness harness unexpectedly contains --model flag" ;;
    *) pass "$harness harness is unchanged (no --model flag)" ;;
  esac

  # codex: multiline block (two branches exist)
  harness=codex
  line=$(sed -n "/^    $harness)/,/^      ;;$/p" "$SPAWN_SRC" | grep -c "printf" || true)
  # codex has 2 template lines (ship and secondmate), neither should have --model
  while IFS= read -r l; do
    case "$l" in
      *"--model"*) fail "$harness harness unexpectedly contains --model flag: $l" ;;
    esac
  done < <(sed -n "/^    $harness)/,/^      ;;$/p" "$SPAWN_SRC" | grep "printf")
  pass "$harness harness is unchanged (no --model flag)"
}

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------

test_crewmate_pi_has_model_flag
test_secondmate_pi_omits_model_flag
test_other_harnesses_unchanged
