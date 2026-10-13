#!/bin/bash
# sourced, never run: the read-only test every bash gate shares. a session edits
# through bash as readily as through Edit or Write — sed -i, a heredoc, git
# apply — so a gate on writes has to gate bash too, and a command that only
# *reads* passes. every verb has to read, or the command counts as a write;
# anything unparsed counts as one, because a miss is a silent write and a false
# refusal costs one message.

# kru_readonly_bash <command> — 0 when every segment only reads
kru_readonly_bash() {
  # awk's system() runs a command, with any space before its paren
  [[ $1 =~ system[[:space:]]*\( ]] && return 1
  case "$1" in
    # a redirect, a substitution or an in-place edit writes whatever the verb is
    *'>'*|*'$('*|*'`'*|*'sed -i'*|*'perl -i'*|*'--in-place'*|*'-exec'*|*'-delete'*|*'-fprint'*|*'-fls'*|*'xargs'*|*'getline'*|*'--output'*) return 1 ;;
    *)
      # every segment of a chain or pipe answers for itself — a read-only head
      # says nothing about what follows it
      while IFS= read -r seg; do
        seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$seg" ] && continue
        verb=${seg%% *}
        case "${verb##*/}" in
          ls|cat|head|tail|wc|grep|egrep|fgrep|find|file|stat|pwd|realpath|basename|dirname) continue ;;
          which|command|type|echo|printf|jq|uniq|cut|tr|column|test|true|diff) continue ;;
          sort) local re="[[:space:]]['\"]?(-[^-[:space:]]*o|--o|--co)"; [[ " $seg" =~ $re ]] && return 1; continue ;;
          rg) [[ " $seg " =~ [[:space:]]--pre([[:space:]=]) ]] && return 1; continue ;;
          sed) local re="[/;{}[:space:]'\"0-9\$!,][gpIiMm0-9]*[wWe]([[:space:]'\";}]|\$)"; [[ " $seg" =~ $re ]] && return 1; continue ;;
          yq) local re="[[:space:]]['\"]?(-[a-zA-Z]*[is]|--inplace|--split-exp)"; [[ " $seg" =~ $re ]] && return 1; continue ;;
          date) [ "$seg" = date ] && continue; return 1 ;;
          # safe only because the write-tell case above already took sed -i and any redirect
          sed|awk|nl|tac|comm|xxd|base64) continue ;;
        esac
        # the read-only subcommands of the tools a triage turn actually reaches for.
        # env runs whatever follows it, so only the bare listing is a read.
        case "$seg" in
          env) continue ;;
          'git status'|'git status '*|'git log'|'git log '*|'git diff'|'git diff '*|'git show'|'git show '*|'git remote -v') continue ;;
          # listing flags only — -d/-D/-m/-c and a bare name all write
          'git branch'|'git branch '-[arv]|'git branch -vv'|'git branch -av'|'git branch --all'|'git branch --remotes'|'git branch --show-current'|'git branch --list'*) continue ;;
          'agent mcp list'*|'agent status'*|'agent models'*|'cursor-agent mcp list'*|'cursor-agent status'*) continue ;;
        esac
        return 1
      done < <(printf '%s\n' "$1" | tr '|;&' '\n')
      return 0 ;;
  esac
}
