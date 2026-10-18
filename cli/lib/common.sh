# shellcheck shell=bash
# fiddy shared helpers: config, logging, ssh.

FIDDY_CONFIG="$FIDDY_HOME/config"
# Snapchain default ports: HTTP API 3381, gRPC 3383, gossip 3382/3384 (udp+tcp).
SNAP_HTTP_PORT="${SNAP_HTTP_PORT:-3381}"
SNAP_GRPC_PORT="${SNAP_GRPC_PORT:-3383}"

c_reset=$'\033[0m'; c_lime=$'\033[38;5;154m'; c_dim=$'\033[2m'; c_red=$'\033[31m'; c_bold=$'\033[1m'
log()  { printf '%s▸%s %s\n' "$c_lime" "$c_reset" "$*"; }
ok()   { printf '%s✓%s %s\n' "$c_lime" "$c_reset" "$*"; }
warn() { printf '%s!%s %s\n' "$c_red" "$c_reset" "$*" >&2; }
die()  { warn "$*"; exit 1; }
step() { printf '\n%s%s%s\n' "$c_bold" "$*" "$c_reset"; }

require() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1 — $2"; }

config_load() {
  [ -f "$FIDDY_CONFIG" ] || return 0
  # shellcheck disable=SC1090
  . "$FIDDY_CONFIG"
}

config_set() { # key value — upsert into $FIDDY_CONFIG (mode 0600)
  mkdir -p "$FIDDY_HOME"
  touch "$FIDDY_CONFIG"; chmod 600 "$FIDDY_CONFIG"
  local key="$1" val="$2" tmp
  tmp="$(mktemp)"
  grep -v "^${key}=" "$FIDDY_CONFIG" > "$tmp" 2>/dev/null || true
  printf '%s=%q\n' "$key" "$val" >> "$tmp"
  mv "$tmp" "$FIDDY_CONFIG"; chmod 600 "$FIDDY_CONFIG"
  config_load
}

config_show() {
  step "fiddy config ($FIDDY_CONFIG)"
  if [ -f "$FIDDY_CONFIG" ]; then cat "$FIDDY_CONFIG"; else echo "(empty — run: fiddy provision)"; fi
}

# --- remote helpers -------------------------------------------------------

require_target() {
  config_load
  [ -n "${FIDDY_TARGET:-}" ] || die "no node target configured. Run: fiddy provision --aws   (or: --ssh user@host)"
}

ssh_opts() {
  local opts=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
  [ -n "${FIDDY_SSH_KEY:-}" ] && opts+=(-i "$FIDDY_SSH_KEY")
  printf '%s\n' "${opts[@]}"
}

ssh_run() { # ssh_run <remote command...>
  require_target
  mapfile -t opts < <(ssh_opts)
  ssh "${opts[@]}" "$FIDDY_TARGET" "$@"
}

scp_to() { # scp_to <local> <remote-path>
  require_target
  mapfile -t opts < <(ssh_opts)
  scp "${opts[@]}" "$1" "$FIDDY_TARGET:$2"
}

# Poll the node's HTTP info endpoint until it answers, printing sync progress.
wait_for_node() { # wait_for_node <base-url>
  local base="$1" tries="${2:-60}" i body
  log "waiting for node at $base (up to $((tries * 5))s)…"
  for ((i = 1; i <= tries; i++)); do
    if body="$(curl -fsS --max-time 5 "$base/v1/info" 2>/dev/null)"; then
      ok "node is up: $base"
      printf '%s\n' "$body" | grep -o '"[a-zA-Z]*":[0-9]*' | head -6 || true
      return 0
    fi
    printf '\r%s…%s attempt %d/%d' "$c_dim" "$c_reset" "$i" "$tries"
    sleep 5
  done
  printf '\n'
  die "node did not come up in time — check: fiddy node logs"
}
