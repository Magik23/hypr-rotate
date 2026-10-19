#!/usr/bin/env bash
set -euo pipefail

# Self-contained integration tests; only Bash and jq are required.
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    monitors)
        [[ "$#" -eq 2 && "$2" == '-j' ]] || exit 10
        cat "$TEST_MONITORS_FILE"
        ;;
    eval)
        [[ "$#" -eq 2 ]] || exit 11
        printf '%s\n' "$2" >> "$TEST_EVAL_LOG"
        if [[ "${TEST_FAIL_EVAL:-0}" == 1 ]]; then
            echo 'Hyprland IPC unavailable' >&2
            exit 12
        fi
        echo 'Hyprland replied OK'
        ;;
    *) echo "unexpected hyprctl call: $*" >&2; exit 13 ;;
esac
MOCK
chmod +x "$tmp/bin/hyprctl"

cat > "$tmp/bin/notify-send" <<'MOCK'
#!/usr/bin/env bash
echo 'unexpected notify-send' >> "$TEST_NOTIFY_LOG"
exit 99
MOCK
chmod +x "$tmp/bin/notify-send"

export PATH="$tmp/bin:$PATH"
export TEST_MONITORS_FILE="$tmp/monitors.json"
export TEST_EVAL_LOG="$tmp/eval.log"
export TEST_NOTIFY_LOG="$tmp/notifications.log"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "missing '$2' in $1"; }

write_monitors() {
    local name="$1" transform="$2"
    jq -nc --arg name "$name" --argjson transform "$transform" \
        '[{name: $name, focused: true, transform: $transform}]' > "$TEST_MONITORS_FILE"
}

run_success() {
    local output
    : > "$TEST_EVAL_LOG"
    output="$("$repo/hypr-rotate" 2>&1)" || fail "unexpected failure: $output"
    [[ -z "$output" ]] || fail "successful rotation must be silent: $output"
    [[ $(wc -l < "$TEST_EVAL_LOG") -eq 1 ]] || fail 'expected exactly one eval call'
    [[ ! -e "$TEST_NOTIFY_LOG" ]] || fail 'notify-send must never be called'
}

run_failure() {
    local needle="$1" output
    : > "$TEST_EVAL_LOG"
    if output="$("$repo/hypr-rotate" 2>&1)"; then
        fail "expected failure: $needle"
    fi
    [[ "$output" == *"$needle"* ]] || fail "expected '$needle' but got '$output'"
    [[ ! -s "$TEST_EVAL_LOG" ]] || fail 'rotation must not run when validation fails'
}

for orientation in 0 1 2 3; do
    write_monitors 'HDMI-A-2' "$orientation"
    run_success
    expected=$(((orientation + 1) % 4))
    assert_contains "$TEST_EVAL_LOG" "hl.monitor({ output = \"HDMI-A-2\", transform = $expected })"
done

# On multi-monitor setups, only the focused output is rotated.
jq -nc '[{name: "DP-1", focused: false, transform: 0},
         {name: "eDP-1", focused: true, transform: 2}]' > "$TEST_MONITORS_FILE"
run_success
assert_contains "$TEST_EVAL_LOG" 'output = "eDP-1", transform = 3'

write_monitors 'HDMI-A-1' 4
run_failure 'mirrored transform 4'
write_monitors 'HDMI-A-1' 7
run_failure 'mirrored transform 7'
write_monitors 'HDMI-A-1' 9
run_failure 'invalid monitor transform: 9'
write_monitors 'HDMI-A-1' 1.5
run_failure 'invalid monitor transform: 1.5'

# Invalid/missing monitor information must not run an arbitrary Lua expression.
echo '{}' > "$TEST_MONITORS_FILE"
run_failure 'unable to read exactly one valid focused monitor'
echo 'not JSON' > "$TEST_MONITORS_FILE"
run_failure 'unable to read exactly one valid focused monitor'
echo '[]' > "$TEST_MONITORS_FILE"
run_failure 'unable to read exactly one valid focused monitor'
jq -nc '[{name:"DP-1", focused: true, transform: 0},
         {name:"HDMI-A-1", focused: true, transform: 2}]' > "$TEST_MONITORS_FILE"
run_failure 'unable to read exactly one valid focused monitor'
jq -nc '[{name:"DP-1", focused: true, transform: "1"}]' > "$TEST_MONITORS_FILE"
run_failure 'unable to read exactly one valid focused monitor'
write_monitors 'DP-1" }); error("injected") --' 0
run_failure 'invalid monitor name'
write_monitors $'HDMI\nA-1' 0
run_failure 'invalid monitor name'

write_monitors 'DP-1' 0
: > "$TEST_EVAL_LOG"
export TEST_FAIL_EVAL=1
if output="$("$repo/hypr-rotate" 2>&1)"; then
    fail 'expected failed eval to fail the command'
fi
[[ "$output" == *'Hyprland IPC unavailable'* ]] || fail 'missing Hyprland diagnostic'
[[ "$output" == *'failed to rotate monitor DP-1'* ]] || fail 'missing wrapper diagnostic'
unset TEST_FAIL_EVAL

[[ ! -e "$TEST_NOTIFY_LOG" ]] || fail 'notification invoked during tests'
printf 'OK: 4 orientations, multi-monitor focus, error handling, input safety, no notifications\n'
