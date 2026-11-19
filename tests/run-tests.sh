#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 jackh0006
#
# WVS Installer test suite.
# Runs the real installer inside a throw-away HOME, without sudo, against a
# closed local port. No GUI, no network and no keyring are required.
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/vps-setup.sh"
TEST_PASS='S3cret-Test-Pass!42'
PASSED=0
FAILED=0
TMP=""

forget_keys_for() { # remove keyring entries created for a test home
    [[ -n ${1:-} ]] || return 0
    python3 - "$1" <<'PY' 2>/dev/null || true
import sys
try:
    import secretstorage
    col = secretstorage.get_default_collection(secretstorage.dbus_init())
    prefix = sys.argv[1]
    for item in col.get_all_items():
        if item.get_attributes().get("filename", "").startswith(prefix):
            item.delete()
except Exception:
    pass
PY
}

cleanup() {
    forget_keys_for "$TMP"
    [[ -n $TMP && -d $TMP ]] && rm -rf -- "$TMP"
}
trap cleanup EXIT

ok()   { PASSED=$((PASSED + 1)); printf '  ok   %s\n' "$*"; }
bad()  { FAILED=$((FAILED + 1)); printf '  FAIL %s\n' "$*"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

new_home() {
    forget_keys_for "$TMP"
    [[ -n $TMP && -d $TMP ]] && rm -rf -- "$TMP"
    TMP=$(mktemp -d)
    export HOME="$TMP/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_STATE_HOME="$HOME/.local/state"
    mkdir -p "$HOME"
    W="$HOME/.local/bin/vps"
    P="$HOME/.local/share/remmina/windows-vps-stable.remmina"
    C="$HOME/.config/vps-connect/vps.conf"
    H="$HOME/vps-connect/linux-macos/vps"
}

install_plain() {
    printf '127.0.0.1\nTestUser\n%s\n%s\n' "$TEST_PASS" "$TEST_PASS" |
        bash "$SCRIPT" --no-sudo --yes --no-term
}

echo "== syntax =="
check "vps-setup.sh parses"    "bash -n '$SCRIPT'"
check "tests parse"            "bash -n '$ROOT/tests/run-tests.sh'"
check "install.sh parses"      "bash -n '$ROOT/install.sh'"
check "version exits 0"        "VPS_SETUP_IN_TERM=1 bash '$SCRIPT' --version >/dev/null"
check "help exits 0"           "VPS_SETUP_IN_TERM=1 bash '$SCRIPT' --help | grep -q 'Usage:'"
check "unknown option exits 2" "! VPS_SETUP_IN_TERM=1 bash '$SCRIPT' --nope >/dev/null 2>&1"

echo "== install =="
new_home
if install_plain >"$TMP/out" 2>&1; then ok "installer exits 0"; else bad "installer exits 0"; cat "$TMP/out"; fi

check "wrapper exists"            "[[ -f '$W' ]]"
check "wrapper mode 700"          "[[ \$(stat -c %a '$W') == 700 ]]"
check "helper exists"             "[[ -f '$H' ]]"
check "helper mode 755"           "[[ \$(stat -c %a '$H') == 755 ]]"
check "profile exists"            "[[ -f '$P' ]]"
check "profile mode 600"          "[[ \$(stat -c %a '$P') == 600 ]]"
check "conf exists"               "[[ -f '$C' ]]"
check "conf mode 600"             "[[ \$(stat -c %a '$C') == 600 ]]"
check "conf host"                 "grep -qx 'HOST=127.0.0.1' '$C'"
check "conf user"                 "grep -qx 'USER=TestUser' '$C'"
check "conf is not plaintext"     "! grep -q '$TEST_PASS' '$C'"
check "base64 round-trips"        "[[ \$(sed -n 's/^PASS_B64=//p' '$C' | base64 -d) == '$TEST_PASS' ]]"
check "profile server"            "grep -qx 'server=127.0.0.1:3389' '$P'"
check "profile cert_ignore"       "grep -qx 'cert_ignore=1' '$P'"
check "profile has screen size"   "grep -qE '^window_width=[0-9]+$' '$P'"
check "profile password field"    "grep -qx 'password=.' '$P' || grep -qxF 'password=$TEST_PASS' '$P'"
check "plaintext fallback mode 600" "! grep -qF 'password=$TEST_PASS' '$P' || [[ \$(stat -c %a '$P') == 600 ]]"
check "password not in log"       "! grep -q '$TEST_PASS' '$HOME/.local/state/vps-connect/install.log'"
check "readme written"            "[[ -f '$HOME/vps-connect/README.md' ]]"
check "installer self-copied"     "[[ -x '$HOME/vps-connect/vps-setup.sh' ]]"

echo "== commands =="
check "login shell finds vps"     "[[ \$(HOME='$HOME' bash -lc 'command -v vps' 2>/dev/null) == '$W' ]]"
check "vps status works"          "'$W' status | grep -q '127.0.0.1:3389'"
check "vps status user"           "'$W' status | grep -q 'TestUser'"
check "vps help works"            "'$W' help | grep -q 'vps setup'"
check "vps test fails closed port" "! '$W' test >/dev/null 2>&1"

echo "== re-run is idempotent =="
if printf '\n\n\n' | bash "$SCRIPT" --no-sudo --yes --no-term >"$TMP/out2" 2>&1; then
    ok "second install exits 0"
else
    bad "second install exits 0"; cat "$TMP/out2"
fi
check "password still there"      "[[ \$(sed -n 's/^PASS_B64=//p' '$C' | base64 -d) == '$TEST_PASS' ]]"
check "backup created"            "find '$HOME/.local/state/vps-connect' -maxdepth 1 -type d -name 'backup-*' | grep -q ."

echo "== input handling =="
new_home
if printf 'not a host!\n127.0.0.1\nTestUser\n%s\n%s\n' "$TEST_PASS" "$TEST_PASS" |
    bash "$SCRIPT" --no-sudo --yes --no-term >"$TMP/invalid" 2>&1; then
    ok "invalid host is rejected then retried"
else
    bad "invalid host retry"; tail -5 "$TMP/invalid"
fi
check "recovered host"            "grep -qx 'HOST=127.0.0.1' '$C'"

new_home
if printf '127.0.0.1\nTestUser\n' | bash "$SCRIPT" --no-sudo --yes --no-term >/dev/null 2>&1; then
    bad "EOF in password is handled (should not succeed silently)"
else
    ok "EOF in password is handled"
fi

echo "== uninstall =="
new_home
install_plain >/dev/null 2>&1
if printf 'y\n' | bash "$SCRIPT" --uninstall --no-sudo --yes >"$TMP/un" 2>&1; then
    ok "uninstall exits 0"
else
    bad "uninstall exits 0"; tail -5 "$TMP/un"
fi
check "wrapper removed"           "[[ ! -e '$W' ]]"
check "profile removed"           "[[ ! -e '$P' ]]"
check "kit removed"               "[[ ! -d '$HOME/vps-connect' ]]"
check "conf removed"              "[[ ! -d '$HOME/.config/vps-connect' ]]"
check "PATH marker removed"       "! grep -q 'vps-setup: PATH' '$HOME/.profile' 2>/dev/null"

echo
printf 'Passed: %d   Failed: %d\n' "$PASSED" "$FAILED"
((FAILED == 0))
