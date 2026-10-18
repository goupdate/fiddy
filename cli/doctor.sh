# shellcheck shell=bash
# fiddy doctor — local prerequisite check.

doctor_main() {
  step "fiddy doctor"
  local fail=0
  check() { # cmd, install hint, required(1)/optional(0)
    if command -v "$1" >/dev/null 2>&1; then
      ok "$1 — $(command -v "$1")"
    elif [ "$3" = 1 ]; then
      warn "$1 missing — $2"; fail=1
    else
      warn "$1 missing (optional) — $2"
    fi
  }
  check ssh    "install openssh" 1
  check curl   "install curl" 1
  check pnpm   "https://pnpm.io/installation (need 10.8.1+)" 1
  check node   "https://nodejs.org (need 20.19.5+)" 1
  check aws    "only for: fiddy provision --aws" 0
  check docker "only for: fiddy node up --local" 0

  if command -v node >/dev/null 2>&1; then
    local nv; nv="$(node -v | tr -d v)"
    [ "$(printf '%s\n20.19.5\n' "$nv" | sort -V | head -1)" = "20.19.5" ] \
      && ok "node $nv ≥ 20.19.5" || warn "node $nv too old — need ≥ 20.19.5"
  fi

  echo ""
  if [ -f "$FIDDY_CONFIG" ]; then config_show; else log "no config yet — run: fiddy provision"; fi
  [ "$fail" = 0 ] && ok "ready" || die "fix the missing requirements above"
}
