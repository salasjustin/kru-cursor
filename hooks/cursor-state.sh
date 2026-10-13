#!/bin/bash
# sourced, never run: the per-conversation state dir the cursor-native hooks
# share — ${TMPDIR:-/tmp}/kru-cursor-<uid>/<conversation id>/. on a shared /tmp
# another user could pre-create either level, or plant a symlink, and turn a
# hook's write into one through the link; so both levels are made 0700 and must
# be real directories this user owns, or the caller gets nothing and fails open.

# kru_cursor_state <conversation id> — prints the dir, 0 when it's safe to use
kru_cursor_state() {
  local id=$1 base
  case "$id" in ''|*/*|*..*|.*) return 1 ;; esac
  base="${TMPDIR:-/tmp}/kru-cursor-$(id -u)"
  kru_cursor_owned_dir "$base" || return 1
  kru_cursor_owned_dir "$base/$id" || return 1
  printf '%s' "$base/$id"
}

# kru_cursor_owned_dir <path> — creates it 0700 when missing; 0 when it is a
# directory, not a symlink, owned by this user
kru_cursor_owned_dir() {
  mkdir -m 700 "$1" 2>/dev/null
  [ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ]
}
