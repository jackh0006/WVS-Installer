#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 jackh0006
# https://github.com/jackh0006/WVS-Installer
#
# =============================================================================
#  vps-setup.sh  -  one-word Windows VPS launcher for Linux
#
#  What it does, in order:
#    1. asks three short questions (address, user, password)
#    2. installs Remmina + FreeRDP + Python if they are missing
#    3. stores the password in the GNOME keyring (never in clear text)
#    4. writes the Remmina profile, the `vps` command and its helper
#    5. adds ~/.local/bin to PATH and installs the root fallback copy
#    6. tests the connection and tells you to type:  vps
#
#  Safe to run again at any time: it backs up every file it replaces.
#
#  Usage:
#      bash vps-setup.sh                normal install / update
#      bash vps-setup.sh --advanced     also asks for port / tunnel mode
#      bash vps-setup.sh --reconfigure  same as normal (keeps old answers)
#      bash vps-setup.sh --uninstall    remove everything it installed
#      bash vps-setup.sh --help         this text
#
#  The script never prints, logs or puts the password on a command line.
# =============================================================================
set -Eeuo pipefail
umask 077

VERSION="2.0.0"
SELF="${BASH_SOURCE[0]:-}"
if [[ -n $SELF && -f $SELF ]]; then
    SELF=$(readlink -f -- "$SELF" 2>/dev/null || printf '%s' "$SELF")
fi

# ----------------------------------------------------------------- locations
KIT_DIR="$HOME/vps-connect"
HELPER_DIR="$KIT_DIR/linux-macos"
HELPER="$HELPER_DIR/vps"
WRAPPER="$HOME/.local/bin/vps"
PROFILE_DIR="$HOME/.local/share/remmina"
PROFILE="$PROFILE_DIR/windows-vps-stable.remmina"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vps-connect"
CONF="$CONF_DIR/vps.conf"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/vps-connect"
LOG="$STATE_DIR/install.log"
BACKUP_DIR="$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
FALLBACK="/usr/local/bin/vps"
PROFILE_NAME="Windows VPS - stable input"

# ------------------------------------------------------------------- options
MODE=install
ADVANCED=0
NOSUDO=0
ASSUME_YES=0
NO_TERM=0
for _arg in "$@"; do
    case "$_arg" in
        --no-term) NO_TERM=1 ;;
    esac
done

# ----------------------------------------------------------- terminal relaunch
# If the file was double-clicked (no terminal), open one and run ourselves.
if [[ $NO_TERM -eq 0 && -z ${VPS_SETUP_IN_TERM:-} && ( ! -t 0 || ! -t 1 ) && -n $SELF && -f $SELF ]]; then
    if [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
        for _term in x-terminal-emulator gnome-terminal konsole xfce4-terminal mate-terminal lxterminal xterm; do
            command -v "$_term" >/dev/null 2>&1 || continue
            export VPS_SETUP_IN_TERM=1
            case "$_term" in
                gnome-terminal) exec "$_term" -- bash "$SELF" "$@" ;;
                *)              exec "$_term" -e bash "$SELF" "$@" ;;
            esac
        done
    fi
fi

# ---------------------------------------------------------------- arg parsing
# (parsed at the end of this file, after all functions are defined)

# --------------------------------------------------------------------- basics
if [[ $EUID -eq 0 ]]; then
    printf 'Please run this as your normal user, not as root/sudo.\n' >&2
    printf 'It will ask for the administrator password by itself when needed.\n' >&2
    exit 1
fi

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null || true
: >>"$LOG"
chmod 600 "$LOG" 2>/dev/null || true

say()  { printf '%s\n' "$*"; printf '[%s] %s\n' "$(date -Is 2>/dev/null || date)" "$*" >>"$LOG" 2>/dev/null || true; }
warn() { printf '  ! %s\n' "$*" >&2; printf '[%s] WARN %s\n' "$(date -Is 2>/dev/null || date)" "$*" >>"$LOG" 2>/dev/null || true; }
err()  { printf '  x %s\n' "$*" >&2; printf '[%s] ERROR %s\n' "$(date -Is 2>/dev/null || date)" "$*" >>"$LOG" 2>/dev/null || true; }
die()  { err "$*"; printf '\nNothing was deleted. Full log: %s\n' "$LOG" >&2; exit 1; }

SUDO=()
KEEPALIVE_PID=""
TMP_PY=""
cleanup() {
    if [[ -n $KEEPALIVE_PID ]]; then
        kill "$KEEPALIVE_PID" 2>/dev/null || true
    fi
    if [[ -n $TMP_PY && -f $TMP_PY ]]; then
        rm -f -- "$TMP_PY" || true
    fi
}
trap cleanup EXIT
trap 'rc=$?; [[ $rc -ne 0 ]] && err "Stopped (line $LINENO). Your old files are in $STATE_DIR."; exit $rc' ERR
trap 'exit 130' INT TERM

# ------------------------------------------------------------- small helpers
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
cat <<'EOF'
vps-setup.sh - one-word Windows VPS launcher for Linux

Usage:
  bash vps-setup.sh                install or update (asks 3 questions)
  bash vps-setup.sh --advanced     also ask for the RDP port
  bash vps-setup.sh --reconfigure  change the saved details
  bash vps-setup.sh --uninstall    remove everything it installed
  bash vps-setup.sh --help         this text
  bash vps-setup.sh --version      print the version

Options:
  --no-sudo    do not install packages or the /usr/local fallback (testing)
  --yes        do not ask for the final confirmation
  --no-term    never reopen this script in a terminal window
EOF
}

ask() { # ask <prompt> <default> ; result in $ANSWER
    local prompt=$1 def=${2:-}
    if [[ -n $def ]]; then
        printf '%s [%s]: ' "$prompt" "$def"
    else
        printf '%s: ' "$prompt"
    fi
    local rc=0
    IFS= read -r ANSWER || rc=$?
    if ((rc != 0)) && [[ ! -t 0 ]]; then
        err "Input ended before all questions were answered."
        exit 1
    fi
    if [[ -z $ANSWER && -n $def ]]; then
        ANSWER=$def
    fi
    return 0
}

read_secret() { # read_secret <variable-name>
    local rc=0
    IFS= read -rs "$1" || rc=$?
    if ((rc != 0)) && [[ ! -t 0 ]]; then
        err "Input ended before the password was entered."
        exit 1
    fi
    return 0
}

valid_host() {
    [[ -n $1 && $1 != -* ]] || return 1
    [[ $1 =~ ^[A-Za-z0-9._:-]+$ ]]
}

valid_port() {
    [[ $1 =~ ^[0-9]{1,5}$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535))
}

valid_user() {
    [[ -n $1 && $1 != -* ]] || return 1
    [[ $1 =~ ^[A-Za-z0-9._-]+$ ]]
}

atomic_write() { # atomic_write <path> <mode>   (content on stdin)
    local path=$1 mode=$2 dir tmp
    dir=$(dirname -- "$path")
    mkdir -p -- "$dir"
    tmp=$(mktemp "$dir/.vps-setup.XXXXXX") || die "Cannot write in $dir"
    cat >"$tmp"
    chmod "$mode" "$tmp"
    mv -f -- "$tmp" "$path"
}

backup_path() { # backup_path <path>
    [[ -e $1 || -L $1 ]] || return 0
    mkdir -p -- "$BACKUP_DIR" 2>/dev/null || return 0
    chmod 700 "$BACKUP_DIR" 2>/dev/null || true
    local name
    name=$(printf '%s' "$1" | sed 's|/|_|g')
    cp -a -- "$1" "$BACKUP_DIR/$name" 2>/dev/null || true
}

# --------------------------------------------------------------- sudo access
ensure_sudo() {
    [[ $NOSUDO -eq 1 ]] && return 0
    if sudo -n true 2>/dev/null; then
        SUDO=(sudo -n)
        return 0
    fi
    have sudo || die "sudo is not installed. Install packages yourself and re-run with --no-sudo."
    local pw=""
    printf 'Type your computer password once (needed for installation, not saved): ' >&2
    IFS= read -rs pw || die "No password given."
    printf '\n' >&2
    if ! printf '%s\n' "$pw" | sudo -S -p '' -v 2>/dev/null; then
        pw=""
        die "That password was not accepted."
    fi
    pw=""
    SUDO=(sudo)
    ( while sleep 30; do sudo -n -v 2>/dev/null || exit 0; done ) >/dev/null 2>&1 &
    KEEPALIVE_PID=$!
}

# ------------------------------------------------------------- package setup
PM=""
detect_pm() {
    if have apt-get; then PM=apt
    elif have dnf;     then PM=dnf
    elif have pacman;  then PM=pacman
    elif have zypper;  then PM=zypper
    else PM=none
    fi
}

apt_proxy_off_args() {
    local p hp host port
    p=$(apt-config dump 2>/dev/null | sed -n 's/^Acquire::http::Proxy "\(.*\)";/\1/p' | head -n1 || true)
    [[ -n $p ]] || return 0
    hp=${p#*://}; hp=${hp%%/*}
    host=${hp%:*}; port=${hp##*:}
    [[ $host == "$hp" ]] && port=80
    if ! (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
        printf '%s\n' -o Acquire::http::Proxy=false -o Acquire::https::Proxy=false
    else
        exec 3>&- 2>/dev/null || true
    fi
}

install_apt() { # install_apt <required|optional> pkg...
    local kind=$1; shift
    local extra=()
    mapfile -t extra < <(apt_proxy_off_args)
    local logstart
    logstart=$(wc -l <"$LOG" 2>/dev/null || echo 0)
    if "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get "${extra[@]}" install -y "$@" >>"$LOG" 2>&1; then
        return 0
    fi
    if ((${#extra[@]} == 0)); then
        # Retry once with any configured apt proxy disabled.
        if "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
            apt-get -o Acquire::http::Proxy=false -o Acquire::https::Proxy=false \
            install -y "$@" >>"$LOG" 2>&1; then
            return 0
        fi
    fi
    tail -n +"$((logstart + 1))" "$LOG" 2>/dev/null | tail -n 6 >&2 || true
    [[ $kind == optional ]] && return 0
    return 1
}

install_packages() {
    detect_pm
    [[ $NOSUDO -eq 1 ]] && { warn "Skipping package installation (--no-sudo)."; return 0; }

    case "$PM" in
        apt)
            local need=() want=() opt=()
            dpkg -s remmina          >/dev/null 2>&1 || need+=(remmina)
            dpkg -s remmina-plugin-rdp >/dev/null 2>&1 || need+=(remmina-plugin-rdp)
            dpkg -s python3          >/dev/null 2>&1 || need+=(python3)
            have xfreerdp3 || have xfreerdp || want+=(freerdp3-x11)
            python3 -c 'import secretstorage' 2>/dev/null || want+=(python3-secretstorage)
            have xfreerdp || opt+=(freerdp2-x11)

            if ((${#need[@]})); then
                say "  installing: ${need[*]}"
                install_apt required "${need[@]}" || die "Could not install ${need[*]}."
            fi
            if ((${#want[@]})); then
                say "  installing: ${want[*]}"
                install_apt optional "${want[@]}"
            fi
            if ((${#opt[@]})); then
                say "  installing (optional): ${opt[*]}"
                install_apt optional "${opt[@]}"
            fi
            ;;
        dnf)
            local pkgs=(remmina freerdp python3) extra=(python3-secretstorage)
            "${SUDO[@]}" dnf install -y "${pkgs[@]}" >>"$LOG" 2>&1 \
                || die "Could not install packages with dnf."
            "${SUDO[@]}" dnf install -y "${extra[@]}" >>"$LOG" 2>&1 || true
            ;;
        pacman)
            "${SUDO[@]}" pacman -S --needed --noconfirm remmina freerdp python >>"$LOG" 2>&1 \
                || die "Could not install packages with pacman."
            "${SUDO[@]}" pacman -S --needed --noconfirm python-secretstorage >>"$LOG" 2>&1 || true
            ;;
        zypper)
            "${SUDO[@]}" zypper --non-interactive install remmina freerdp python3 >>"$LOG" 2>&1 \
                || die "Could not install packages with zypper."
            "${SUDO[@]}" zypper --non-interactive install python3-secretstorage >>"$LOG" 2>&1 || true
            ;;
        *)
            warn "Unknown package manager. Install Remmina, FreeRDP and Python yourself."
            ;;
    esac

    have remmina  || die "Remmina is still missing. Install it from your software centre and run again."
    have python3  || die "Python 3 is still missing."
    have xfreerdp3 || have xfreerdp \
        || warn "FreeRDP is missing; the maintenance commands will not work (Remmina still will)."
}

# ------------------------------------------------------------- display size
SCREEN_W=1366
SCREEN_H=768
detect_screen() {
    local res=""
    if have xrandr && [[ -n ${DISPLAY:-} ]]; then
        res=$(xrandr 2>/dev/null | awk '/ connected/{c=1} c && /\*/{print $1; exit}' || true)
    fi
    if [[ -z $res ]] && have xdpyinfo && [[ -n ${DISPLAY:-} ]]; then
        res=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2; exit}' || true)
    fi
    if [[ $res =~ ^([0-9]{3,5})x([0-9]{3,5})$ ]]; then
        SCREEN_W=${BASH_REMATCH[1]}
        SCREEN_H=${BASH_REMATCH[2]}
    fi
}

# ------------------------------------------------------------------ keyring
keyring_store() { # keyring_store <profile-path>   password on stdin
    TMP_PY=$(mktemp "${TMPDIR:-/tmp}/vps-setup-keyring.XXXXXX") || return 1
    chmod 600 "$TMP_PY"
    cat >"$TMP_PY" <<'PY'
import sys
try:
    import secretstorage
except Exception:
    sys.exit(3)
path = sys.argv[1]
pw = sys.stdin.buffer.read()
try:
    bus = secretstorage.dbus_init()
    col = secretstorage.get_default_collection(bus)
    if col.is_locked():
        col.unlock()
    if col.is_locked():
        sys.exit(4)
    for it in list(col.search_items({"filename": path})):
        it.delete()
    attrs = {
        "filename": path,
        "key": "password",
        "xdg:schema": "org.remmina.Password",
    }
    col.create_item("Remmina: Windows VPS - password", attrs, pw)
except Exception as exc:
    print("keyring: %s" % exc, file=sys.stderr)
    sys.exit(4)
PY
    local rc=0
    printf '%s' "$VPS_PASS" | python3 "$TMP_PY" "$PROFILE" 2>>"$LOG" || rc=$?
    rm -f -- "$TMP_PY"; TMP_PY=""
    return "$rc"
}

keyring_verify() { # password on stdin
    TMP_PY=$(mktemp "${TMPDIR:-/tmp}/vps-setup-verify.XXXXXX") || return 1
    chmod 600 "$TMP_PY"
    cat >"$TMP_PY" <<'PY'
import sys
try:
    import secretstorage
except Exception:
    sys.exit(3)
path = sys.argv[1]
want = sys.stdin.buffer.read()
try:
    col = secretstorage.get_default_collection(secretstorage.dbus_init())
    for it in col.search_items({"filename": path, "key": "password"}):
        if bytes(it.get_secret()) == want:
            sys.exit(0)
except Exception:
    pass
sys.exit(5)
PY
    local rc=0
    printf '%s' "$VPS_PASS" | python3 "$TMP_PY" "$PROFILE" 2>>"$LOG" || rc=$?
    rm -f -- "$TMP_PY"; TMP_PY=""
    return "$rc"
}

keyring_forget() {
    python3 - "$PROFILE" <<'PY' 2>>"$LOG" || true
import sys
try:
    import secretstorage
except Exception:
    sys.exit(0)
path = sys.argv[1]
try:
    col = secretstorage.get_default_collection(secretstorage.dbus_init())
    for it in list(col.search_items({"filename": path})):
        it.delete()
except Exception:
    pass
PY
}

# ------------------------------------------------------------------ profiles
write_conf() {
    backup_path "$CONF"
    atomic_write "$CONF" 600 <<EOF
HOST=$VPS_HOST
PORT=$VPS_PORT
USER=$VPS_USER
PASS_B64=$PASS_B64
MODE=$CONN_MODE
SNI=$SNI
AUDIO=$AUDIO
MIC=$MIC
EOF
}

write_profile() { # write_profile <password-field>
    local passfield=$1 sound=local mic=1 server="$VPS_HOST:$VPS_PORT"
    [[ $AUDIO == off ]] && sound=none
    [[ $MIC == off ]] && mic=0
    [[ $CONN_MODE == tunnel ]] && server="127.0.0.1:13389"
    backup_path "$PROFILE"
    atomic_write "$PROFILE" 600 <<EOF
[remmina]
name=$PROFILE_NAME
protocol=RDP
server=$server
username=$VPS_USER
password=$passfield
resolution_mode=2
colordepth=16
multitransport=0
rdp_mouse_jitter=0
disableclipboard=0
sound=$sound
microphone=$mic
quality=0
viewmode=1
disableautoreconnect=0
cert_ignore=1
window_width=$SCREEN_W
window_height=$SCREEN_H
window_maximize=1
scale=0
EOF
}

write_wrapper() {
    backup_path "$WRAPPER"
    atomic_write "$WRAPPER" 700 <<'WRAPPER_EOF'
#!/usr/bin/env bash
# One-word launcher: `vps` opens the saved Windows VPS in fullscreen Remmina.
# Remmina's own input layer plus this profile (UDP off, jitter off) avoids
# duplicated pointer events on Wayland / touch screens.
if [[ $# -eq 0 ]]; then
  exec env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
    -u ALL_PROXY -u all_proxy -u ftp_proxy -u FTP_PROXY \
    remmina -c "$HOME/.local/share/remmina/windows-vps-stable.remmina" \
            --enable-fullscreen --no-tray-icon
fi

# Any argument is a maintenance command (status, test, setup, ...).
exec "$HOME/vps-connect/linux-macos/vps" "$@"
WRAPPER_EOF
}

write_helper() {
    backup_path "$HELPER"
    atomic_write "$HELPER" 755 <<'HELPER_EOF'
#!/usr/bin/env bash
# =============================================================================
#  vps-connect helper - maintenance side of the one-word `vps` launcher
#  status | test | setup | audio | mic | mode | import | stop | help
# =============================================================================
set -uo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vps-connect"
CONF="$CONF_DIR/vps.conf"
TUNNEL_KEY="$CONF_DIR/tunnel.key"
TUNNEL_CFG="$CONF_DIR/xray-client.json"
TUNNEL_PID="$CONF_DIR/tunnel.pid"
LOCAL_PORT=13389
PROFILE="${XDG_DATA_HOME:-$HOME/.local/share}/remmina/windows-vps-stable.remmina"
KIT_DIR="$HOME/vps-connect"

HOST=""; PORT=3389; VUSER=""; PASS_B64=""; MODE=direct; SNI=""; AUDIO=on; MIC=on

load_conf() {
    [ -r "$CONF" ] || return 0
    local line key val
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|\#*) continue ;; esac
        key=${line%%=*}; val=${line#*=}
        case "$key" in
            HOST) HOST=$val ;; PORT) PORT=$val ;; USER) VUSER=$val ;;
            PASS_B64) PASS_B64=$val ;; MODE) MODE=$val ;;
            SNI) SNI=$val ;; AUDIO) AUDIO=$val ;; MIC) MIC=$val ;;
        esac
    done <"$CONF"
}

save_conf() {
    umask 077
    mkdir -p "$CONF_DIR"
    {
        printf 'HOST=%s\nPORT=%s\nUSER=%s\n' "$HOST" "$PORT" "$VUSER"
        printf 'PASS_B64=%s\n' "$PASS_B64"
        printf 'MODE=%s\nSNI=%s\nAUDIO=%s\nMIC=%s\n' "$MODE" "$SNI" "$AUDIO" "$MIC"
    } >"$CONF"
    chmod 600 "$CONF"
}

pass_plain() { printf '%s' "$PASS_B64" | base64 -d 2>/dev/null; }
have() { command -v "$1" >/dev/null 2>&1; }
need_setup() {
    if [ -z "$HOST" ] || [ -z "$VUSER" ]; then
        echo "No saved VPS settings yet.  Run:  vps setup" >&2
        return 1
    fi
}
clear_proxies() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy \
          ftp_proxy FTP_PROXY no_proxy NO_PROXY 2>/dev/null || true
}

print_status() {
    local state="not configured (run: vps import)"
    if [ "$MODE" = tunnel ]; then
        if [ -r "$TUNNEL_KEY" ]; then
            state="configured (sni=${SNI:-n/a})"
            if [ -r "$TUNNEL_PID" ] && kill -0 "$(cat "$TUNNEL_PID" 2>/dev/null)" 2>/dev/null; then
                state="$state, running pid $(cat "$TUNNEL_PID")"
            else
                state="$state, not running"
            fi
        else
            state="mode=tunnel but no key (run: vps import)"
        fi
    fi
    printf 'host  : %s:%s\n' "${HOST:-<unset>}" "$PORT"
    printf 'user  : %s\n' "${VUSER:-<unset>}"
    printf 'mode  : %s\n' "$MODE"
    printf 'audio : speakers=%s  mic=%s\n' "$AUDIO" "$MIC"
    printf 'tunnel: %s\n' "$state"
}

stop_tunnel() {
    if [ -r "$TUNNEL_PID" ]; then
        local pid; pid=$(cat "$TUNNEL_PID" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null && echo "tunnel stopped (pid $pid)"
        else
            echo "tunnel was not running"
        fi
        rm -f "$TUNNEL_PID"
    else
        echo "no tunnel pid file - nothing to stop"
    fi
}

start_tunnel() {
    [ -r "$TUNNEL_KEY" ] || { echo "No tunnel key.  Run: vps import" >&2; return 1; }
    if [ -r "$TUNNEL_CFG" ] && have xray; then
        if [ -r "$TUNNEL_PID" ] && kill -0 "$(cat "$TUNNEL_PID" 2>/dev/null)" 2>/dev/null; then
            echo "tunnel already running (pid $(cat "$TUNNEL_PID"))"; return 0
        fi
        clear_proxies
        nohup xray run -c "$TUNNEL_CFG" >"$CONF_DIR/tunnel.log" 2>&1 &
        echo $! >"$TUNNEL_PID"
        sleep 1
        if kill -0 "$(cat "$TUNNEL_PID")" 2>/dev/null; then
            echo "tunnel started on 127.0.0.1:$LOCAL_PORT"; return 0
        fi
        rm -f "$TUNNEL_PID"
        echo "tunnel failed to start - see $CONF_DIR/tunnel.log" >&2
        return 1
    fi
    echo "Tunnel key saved, but no xray client config at $TUNNEL_CFG." >&2
    echo "Use: vps mode direct" >&2
    return 1
}

tcp_probe() {
    python3 - "$1" "$2" <<'PY'
import socket, sys
try:
    socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=6).close()
except Exception as e:
    print("TCPFAIL: %s" % e); sys.exit(1)
print("TCPOK")
PY
}

rdp_probe() {
    python3 - "$1" "$2" <<'PY'
import socket, sys
cr = bytes.fromhex("030000130ee000000000000100080003000000")
try:
    s = socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=8)
    s.sendall(cr); data = s.recv(1024); s.close()
except Exception as e:
    print("RDPFAIL: %s" % e); sys.exit(1)
if len(data) >= 6 and data[0] == 3 and data[1] == 0:
    if data[5] == 0xd0:
        print("RDPOK")
    else:
        print("RDPBADCODE: %02x" % data[5]); sys.exit(1)
else:
    print("RDPGARBAGE"); sys.exit(1)
PY
}

do_test() {
    need_setup || return 1
    local th=$HOST tp=$PORT out
    if [ "$MODE" = tunnel ]; then start_tunnel || true; th=127.0.0.1; tp=$LOCAL_PORT; fi
    out=$(tcp_probe "$th" "$tp") || {
        case "$out" in
            *"Connection refused"*) echo "Nothing is listening on $th:$tp - is the tunnel running?" ;;
            *) echo "TCP $tp does not answer on $th - firewall or VPS offline." ;;
        esac
        return 1
    }
    echo "TCP $tp answers on $th"
    out=$(rdp_probe "$th" "$tp") || {
        case "$out" in
            *RDPBADCODE*) echo "TCP connects but the reply is not RDP - a proxy/firewall is rewriting the path." ;;
            *) echo "TCP connects but nothing comes back - path blocked (DPI/VPN), not a wrong password." ;;
        esac
        return 1
    }
    echo "a real RDP server answered - the path is healthy.  Run: vps"
    if [ "$MODE" = tunnel ]; then
        echo "tunnel works end to end"
    fi
    return 0
}

rdp_connect() {
    local host=$1 port=$2 user=$3 pass=$4 bin
    if have xfreerdp3; then bin=xfreerdp3
    elif have xfreerdp; then bin=xfreerdp
    else echo "FreeRDP is not installed." >&2; return 1; fi
    clear_proxies
    local args=("/v:$host:$port" "/u:$user" "/cert:ignore" "+f" "+clipboard" "+dynamic-resolution")
    [ "$AUDIO" = on ] && args+=("/sound:sys:alsa") || args+=("/sound:off")
    [ "$MIC" = on ] && args+=("/microphone:sys:alsa")
    [ -n "$pass" ] && args+=("/p:$pass")
    echo "Connecting to $host:$port as $user ..."
    printf '%s\n' "${args[@]}" | exec "$bin" /args-from:fd:0
}

do_import() {
    echo "Paste the VPS1: line from the Windows tunnel kit, then press Ctrl-D:"
    local line key
    line=$(cat)
    key=$(printf '%s\n' "$line" | grep -o 'VPS1:[^[:space:]]*' | head -n1)
    [ -z "$key" ] && { echo "No VPS1: key found - nothing imported." >&2; return 1; }
    umask 077
    mkdir -p "$CONF_DIR"
    printf '%s\n' "$key" >"$TUNNEL_KEY"
    chmod 600 "$TUNNEL_KEY"
    echo "Tunnel key saved to $TUNNEL_KEY"
}

show_help() {
cat <<'EOF'
vps - connect to the saved Windows VPS

  vps                        connect (Remmina, fullscreen)
  vps status                 show saved settings
  vps test                   TCP + real RDP handshake test
  vps setup                  change the VPS details
  vps audio on|off           speakers
  vps mic on|off             microphone
  vps mode direct|tunnel     connection mode
  vps import                 install an HTTPS tunnel key
  vps stop                   stop the background tunnel
  vps user@host              one-shot connection, nothing saved
  vps help                   this text

Inside the session:
  Ctrl+Alt+Enter   toggle fullscreen
  Ctrl+Alt+End     send Ctrl+Alt+Del
  Ctrl+Alt+Home    show/hide the connection bar
EOF
}

load_conf
cmd=${1:-}
case "$cmd" in
    ""|connect)
        need_setup || exit 1
        if [ "$MODE" = tunnel ]; then
            start_tunnel || exit 1
            rdp_connect 127.0.0.1 "$LOCAL_PORT" "$VUSER" "$(pass_plain)"
        else
            rdp_connect "$HOST" "$PORT" "$VUSER" "$(pass_plain)"
        fi
        ;;
    status) print_status ;;
    test)   do_test ;;
    setup)
        if [ -x "$KIT_DIR/vps-setup.sh" ]; then
            exec bash "$KIT_DIR/vps-setup.sh" --reconfigure
        fi
        echo "Installer not found at $KIT_DIR/vps-setup.sh" >&2
        echo "Run vps-setup.sh again to change the settings." >&2
        exit 1
        ;;
    import) do_import ;;
    stop)   stop_tunnel ;;
    help|-h|--help) show_help ;;
    audio)
        case "${2:-}" in
            on)  AUDIO=on;  save_conf; sed -i 's/^sound=.*/sound=local/' "$PROFILE" 2>/dev/null; echo "speakers on" ;;
            off) AUDIO=off; save_conf; sed -i 's/^sound=.*/sound=none/'  "$PROFILE" 2>/dev/null; echo "speakers muted" ;;
            *) echo "usage: vps audio on|off" >&2; exit 2 ;;
        esac
        ;;
    mic)
        case "${2:-}" in
            on)  MIC=on;  save_conf; sed -i 's/^microphone=.*/microphone=1/' "$PROFILE" 2>/dev/null; echo "microphone forwarded" ;;
            off) MIC=off; save_conf; sed -i 's/^microphone=.*/microphone=0/' "$PROFILE" 2>/dev/null; echo "microphone disabled" ;;
            *) echo "usage: vps mic on|off" >&2; exit 2 ;;
        esac
        ;;
    mode)
        case "${2:-}" in
            direct) MODE=direct; save_conf; sed -i "s|^server=.*|server=${HOST}:${PORT}|" "$PROFILE" 2>/dev/null; echo "mode: direct" ;;
            tunnel) MODE=tunnel; save_conf; sed -i "s|^server=.*|server=127.0.0.1:${LOCAL_PORT}|" "$PROFILE" 2>/dev/null; echo "mode: tunnel"; start_tunnel || true ;;
            *) echo "usage: vps mode direct|tunnel" >&2; exit 2 ;;
        esac
        ;;
    *@*)
        u=${cmd%@*}; h=${cmd#*@}
        printf 'Password for %s (blank = prompt): ' "$u"; IFS= read -rs p; echo
        rdp_connect "$h" 3389 "$u" "$p"
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        echo "Run: vps help" >&2
        exit 2
        ;;
esac
HELPER_EOF
}

write_readme() {
    atomic_write "$KIT_DIR/README.md" 600 <<EOF
# vps-connect (installed $(date +%F) by vps-setup.sh $VERSION)

Type **vps** in a terminal to open the Windows VPS in fullscreen.

* Address : $VPS_HOST:$VPS_PORT
* User    : $VPS_USER
* Password: stored in the GNOME keyring (entry "Remmina: Windows VPS - password")
* Mode    : direct RDP

Files:

| File | Purpose |
|------|---------|
| ~/.local/bin/vps | one-word launcher |
| ~/.local/share/remmina/windows-vps-stable.remmina | Remmina RDP profile |
| ~/.config/vps-connect/vps.conf | saved settings (mode 600) |
| ~/vps-connect/linux-macos/vps | helper commands |
| /usr/local/bin/vps | root fallback copy |

Notes:

* The profile keeps \`password=.\` (keyring marker), never the password text.
* \`cert_ignore=1\` accepts the VPS self-signed RDP certificate.
* The window size is preset to ${SCREEN_W}x${SCREEN_H} so Remmina starts
  fullscreen with the correct resolution.
* Run \`vps setup\` to change the address, user or password.

Helper commands: status, test, setup, audio on|off, mic on|off,
mode direct|tunnel, import, stop, help.
EOF
}

# shellcheck disable=SC2016  # $HOME must stay literal for the generated file
add_path_block() { # add_path_block <file> <export|plain>
    local file=$1 style=${2:-export}
    if [[ ! -f $file ]]; then
        : >>"$file" 2>/dev/null || return 0
    fi
    grep -q '# vps-setup: PATH' "$file" && return 0
    {
        printf '\n# vps-setup: PATH\n'
        printf 'if [ -d "$HOME/.local/bin" ]; then\n'
        printf '    PATH="$HOME/.local/bin:$PATH"\n'
        [[ $style == export ]] && printf '    export PATH\n'
        printf 'fi\n'
    } >>"$file" 2>/dev/null || true
}

# =============================================================================
#  questionnaire
# =============================================================================
VPS_HOST=""; VPS_PORT=3389; VPS_USER="Admin"; VPS_PASS=""
PASS_B64=""; HAVE_OLD_PASS=0
CONN_MODE=direct; AUDIO=on; MIC=on; SNI=""

if [[ -r $CONF ]]; then
    while IFS='=' read -r k v; do
        case "$k" in
            HOST)     [[ -n $v ]] && VPS_HOST=$v ;;
            PORT)     [[ -n $v ]] && VPS_PORT=$v ;;
            USER)     [[ -n $v ]] && VPS_USER=$v ;;
            PASS_B64) [[ -n $v ]] && { PASS_B64=$v; HAVE_OLD_PASS=1; } ;;
            MODE)     [[ -n $v ]] && CONN_MODE=$v ;;
            SNI)      SNI=$v ;;
            AUDIO)    [[ -n $v ]] && AUDIO=$v ;;
            MIC)      [[ -n $v ]] && MIC=$v ;;
        esac
    done <"$CONF"
fi

ask_details() {
    say ""
    say "=============================================================="
    say "  Windows VPS - easy one-word setup   (version $VERSION)"
    say "=============================================================="
    say ""
    say "Three short questions, then I do everything myself."
    say ""

    while :; do
        ask "1/3  VPS address (IP or hostname)" "$VPS_HOST"
        valid_host "$ANSWER" && { VPS_HOST=$ANSWER; break; }
        warn "That does not look like an IP address or hostname. Try again."
    done

    if [[ $ADVANCED -eq 1 ]]; then
        while :; do
            ask "     RDP port" "$VPS_PORT"
            valid_port "$ANSWER" && { VPS_PORT=$ANSWER; break; }
            warn "Port must be a number from 1 to 65535."
        done
    fi

    while :; do
        ask "2/3  Username" "$VPS_USER"
        valid_user "$ANSWER" && { VPS_USER=$ANSWER; break; }
        warn "Username may contain letters, digits, dot, dash and underscore."
    done

    local first second
    while :; do
        if [[ $HAVE_OLD_PASS -eq 1 ]]; then
            printf '3/3  Password for %s (press Enter to keep the saved one): ' "$VPS_USER"
        else
            printf '3/3  Password for %s (it will not be shown): ' "$VPS_USER"
        fi
        read_secret first
        printf '\n'
        if [[ -z $first && $HAVE_OLD_PASS -eq 1 ]]; then
            VPS_PASS=$(printf '%s' "$PASS_B64" | base64 -d 2>/dev/null || true)
            [[ -n $VPS_PASS ]] && break
            warn "The saved password could not be read. Please type it."
            continue
        fi
        [[ -n $first ]] || { warn "The password cannot be empty."; continue; }
        printf '     Type it again: '
        read_secret second
        printf '\n'
        if [[ $first != "$second" ]]; then
            warn "The two passwords are different. Try again."
            first=""; second=""
            continue
        fi
        VPS_PASS=$first
        first=""; second=""
        break
    done

    say ""
    say "Please check:"
    say "    address : $VPS_HOST:$VPS_PORT"
    say "    user    : $VPS_USER"
    say "    password: (hidden, will be stored securely)"
    say ""
    if [[ $ASSUME_YES -eq 0 ]]; then
        printf 'Press Enter to start, or Ctrl+C to cancel. '
        IFS= read -r _ || true
    fi
}

# =============================================================================
#  uninstall
# =============================================================================
do_uninstall() {
    say "This removes the VPS connection setup from this computer."
    say "Saved settings will be kept in $STATE_DIR if you want them back."
    if [[ $ASSUME_YES -eq 0 ]]; then
        printf 'Continue? [y/N] '
        IFS= read -r a || a=""
        case "$a" in [yY]*) ;; *) say "Cancelled."; exit 0 ;; esac
    fi

    ensure_sudo
    [[ -n $VPS_PASS ]] || true

    backup_path "$CONF"
    backup_path "$PROFILE"
    backup_path "$WRAPPER"
    backup_path "$HELPER"

    keyring_forget

    rm -f -- "$WRAPPER" "$PROFILE" 2>/dev/null || true
    rm -rf -- "$KIT_DIR" 2>/dev/null || true
    rm -rf -- "$CONF_DIR" 2>/dev/null || true

    if [[ $NOSUDO -eq 0 && -e $FALLBACK ]]; then
        "${SUDO[@]}" rm -f -- "$FALLBACK" 2>/dev/null || warn "Could not remove $FALLBACK."
    fi

    # remove our PATH block from shell start-up files
    for f in "$HOME/.profile" "$HOME/.bashrc"; do
        [[ -f $f ]] || continue
        if awk 'BEGIN{skip=0}
             /^# vps-setup: PATH$/ {skip=1; next}
             skip==1 && /^fi$/ {skip=0; next}
             skip==0 {print}' "$f" >"$f.vpstmp" 2>/dev/null; then
            mv -f -- "$f.vpstmp" "$f"
        else
            rm -f -- "$f.vpstmp"
        fi
    done

    say ""
    say "Removed. Backups (if any) are in $STATE_DIR."
}

# =============================================================================
#  install
# =============================================================================
do_install() {
    ask_details

    say ""
    say "Step 1/6  Checking this computer..."
    detect_pm
    detect_screen
    say "          display: ${SCREEN_W}x${SCREEN_H}"

    if [[ $NOSUDO -eq 0 ]]; then
        say "Step 2/6  Administrator rights (asked once)..."
        ensure_sudo
        say "Step 3/6  Installing what is needed (this can take a minute)..."
        install_packages
    else
        say "Step 2/6  Skipping administrator steps (--no-sudo)"
        say "Step 3/6  Checking required programs..."
        have remmina || warn "Remmina is missing (required for the one-word launch)."
        have python3 || die "Python 3 is missing."
    fi

    say "Step 4/6  Saving your settings..."
    PASS_B64=$(printf '%s' "$VPS_PASS" | base64 | tr -d '\n')
    mkdir -p "$CONF_DIR" "$PROFILE_DIR" "$HELPER_DIR" "$HOME/.local/bin" "$KIT_DIR"
    chmod 700 "$CONF_DIR" 2>/dev/null || true

    write_conf

    # Store the password in the keyring. Fall back to a 600 profile only if
    # the keyring is genuinely unavailable.
    local passfield="" keyring_ok=0
    if keyring_store; then
        if keyring_verify; then
            keyring_ok=1
            passfield="."
        fi
    fi
    if [[ $keyring_ok -eq 0 ]]; then
        warn "The keyring is not available; saving the password in the profile file (mode 600)."
        warn "Remmina will move it into the keyring the first time you connect."
        passfield=$VPS_PASS
    fi

    write_profile "$passfield"

    say "Step 5/6  Creating the 'vps' command..."
    write_wrapper
    write_helper
    chmod 755 "$HELPER"
    write_readme
    add_path_block "$HOME/.profile" plain
    add_path_block "$HOME/.bashrc" export

    if [[ $NOSUDO -eq 0 ]]; then
        "${SUDO[@]}" install -m755 -- "$HELPER" "$FALLBACK" 2>>"$LOG" \
            || warn "Could not install the fallback copy at $FALLBACK."
    fi
    if [[ -r $SELF ]]; then
        install -m755 -- "$SELF" "$KIT_DIR/vps-setup.sh" 2>/dev/null || true
    fi

    say "Step 6/6  Checking the result..."
    bash -n "$WRAPPER" || die "The launcher has a syntax error."
    bash -n "$HELPER"  || die "The helper has a syntax error."

    if "$WRAPPER" status >/dev/null 2>&1; then
        say "          settings: OK"
    else
        die "The saved settings could not be read back."
    fi

    if "$WRAPPER" test >>"$LOG" 2>&1; then
        say "          connection test: OK"
    else
        warn "The VPS did not answer the connection test right now."
        warn "That is usually the network or the provider firewall, not this setup."
    fi

    local resolved=""
    resolved=$(bash -lc 'command -v vps' 2>/dev/null || true)
    if [[ $resolved != "$WRAPPER" ]]; then
        warn "PATH not updated in this shell yet; open a new terminal."
    fi

    # Password is no longer needed.
    VPS_PASS=""
    unset VPS_PASS 2>/dev/null || true

    say ""
    say "=============================================================="
    say "  All done!"
    say ""
    say "  Open a terminal and type:   vps"
    say ""
    say "  It will open the Windows desktop in fullscreen."
    say "  To change the address or password later:   vps setup"
    say "=============================================================="
    say ""

    if [[ -t 0 && $ASSUME_YES -eq 0 ]]; then
        printf 'Connect now? [y/N] '
        IFS= read -r a || a=""
        case "$a" in
            [yY]*)
                if [[ -n $KEEPALIVE_PID ]]; then
                    kill "$KEEPALIVE_PID" 2>/dev/null || true
                    KEEPALIVE_PID=""
                fi
                exec "$WRAPPER"
                ;;
        esac
    fi
}

# =============================================================================
#  parse the command line (functions above are now defined)
# =============================================================================
while (($#)); do
    case "$1" in
        --uninstall)      MODE=uninstall ;;
        --reconfigure)    MODE=install ;;
        --advanced)       ADVANCED=1 ;;
        --no-sudo)        NOSUDO=1 ;;
        --no-term)        ;;
        --yes|-y)         ASSUME_YES=1 ;;
        --help|-h)        usage; exit 0 ;;
        --version)        printf 'vps-setup.sh %s\n' "$VERSION"; exit 0 ;;
        *) printf 'Unknown option: %s\nUse --help for help.\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

# =============================================================================
case "$MODE" in
    uninstall) do_uninstall ;;
    install)   do_install ;;
esac
