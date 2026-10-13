#!/bin/bash
# sourced, never run: the read-only test every bash gate shares. a session edits
# through bash as readily as through Edit or Write — sed -i, a heredoc, git
# apply — so a gate on writes has to gate bash too, and a command that only
# *reads* passes. every verb has to read, or the command counts as a write;
# anything unparsed counts as one, because a miss is a silent write and a false
# refusal costs one message.

# kru_segments <command> — the command's simple commands in KRU_S, split on the
# | ; & and newlines bash splits on, and not on one a quote or a backslash
# holds, so sed -n '/x/{p;q}' or awk '{print $1; print $2}' stays one segment.
# non-zero on an unclosed quote
kru_segments() {
  local s=$1 i=0 c seg="" part
  KRU_S=()
  while [ "$i" -lt "${#s}" ]; do
    c=${s:i:1}; i=$((i + 1))
    case $c in
      [\|\;\&$'\n']) KRU_S+=("$seg"); seg=""; continue ;;
      \\) c+=${s:i:1}; i=$((i + 1)) ;;
      \') part=${s:i}; [[ $part == *\'* ]] || return 1; part=${part%%\'*}; c+="$part'"; i=$((i + ${#part} + 1)) ;;
      \"|\$)
        # "…" and $'…' end at their first unescaped closing quote
        if [ "$c" = \$ ]; then [ "${s:i:1}" = "'" ] || { seg+=$c; continue; }; c+="'"; i=$((i + 1)); part="'"; else part=\"; fi
        while :; do
          [ "$i" -lt "${#s}" ] || return 1
          c+=${s:i:1}; i=$((i + 1))
          case ${c: -1} in
            "$part") break ;;
            \\) c+=${s:i:1}; i=$((i + 1)) ;;
          esac
        done ;;
    esac
    seg+=$c
  done
  KRU_S+=("$seg")
  return 0
}

# kru_words <segment> — the segment's words as the shell hands them to the verb,
# quotes and escapes resolved, in KRU_W: every flag check reads these, so a
# quoted flag ('-o', "--pre=x") is the flag. non-zero on an unclosed quote or an
# expansion ($VAR, "$x"), whose value no check can see
kru_words() {
  local s=$1 i=0 c w="" inw=0 j part
  KRU_W=()
  while [ "$i" -lt "${#s}" ]; do
    c=${s:i:1}; i=$((i + 1))
    case $c in
      [[:space:]]) [ "$inw" = 1 ] && KRU_W+=("$w"); w="" inw=0; continue ;;
      # a backslash-newline is a line continuation, gone before the verb sees it
      \\) [ "${s:i:1}" = $'\n' ] || w+=${s:i:1}; i=$((i + 1)); [ -n "$w" ] || continue ;;
      \') part=${s:i}; [[ $part == *\'* ]] || return 1; part=${part%%\'*}; w+=$part; i=$((i + ${#part} + 1)) ;;
      \")
        while :; do
          [ "$i" -lt "${#s}" ] || return 1
          c=${s:i:1}; i=$((i + 1))
          case $c in
            \") break ;;
            \$|\`) return 1 ;;
            \\) case ${s:i:1} in [\$\`\"\\]) w+=${s:i:1}; i=$((i + 1)) ;; $'\n') i=$((i + 1)) ;; *) w+=$c ;; esac ;;
            *) w+=$c ;;
          esac
        done ;;
      \$)
        # $'…' is a literal bash decodes itself; any other $ expands
        [ "${s:i:1}" = "'" ] || return 1
        j=$((i + 1))
        while [ "$j" -lt "${#s}" ] && [ "${s:j:1}" != "'" ]; do [ "${s:j:1}" = \\ ] && j=$((j + 1)); j=$((j + 1)); done
        [ "$j" -lt "${#s}" ] || return 1
        eval "part=\$'${s:i+1:j-i-1}'"; w+=$part; i=$((j + 1)) ;;
      *) w+=$c ;;
    esac
    inw=1
  done
  [ "$inw" = 1 ] && KRU_W+=("$w")
  return 0
}

# kru_any <ere> — 0 when a word after the verb (KRU_W) matches
kru_any() { local w; for w in "${KRU_W[@]:1}"; do [[ $w =~ $1 ]] && return 0; done; return 1; }

# kru_sed_reads <arg>... — an allowlist, since sed's w, W, e and s///w s///e
# need no separator before what they write or run: 0 only for -n -E -r -s -z -u
# (and their long names, any prefix GNU accepts), -e/--expression, and scripts
# of addresses, p d D q = G g h H N P x l y { } and s///[gpIiMm0-9]*
kru_sed_reads() {
  local w o c name hit opts=1 scripts=() ops=()
  while [ $# -gt 0 ]; do
    w=$1; shift
    if [ "$opts" = 1 ] && [ "$w" = -- ]; then opts=0
    elif [ "$opts" = 1 ] && [[ $w == --?* ]]; then
      o=${w#--}; o=${o%%=*} hit=""
      for name in debug expression file follow-symlinks in-place line-length null-data zero-terminated quiet silent posix regexp-extended sandbox separate unbuffered binary help version; do
        [[ $name == "$o"* ]] && hit+=" $name"
      done
      case $hit in
        '') return 1 ;;
        ' expression') if [[ $w == *=* ]]; then scripts+=("${w#*=}"); else [ $# -gt 0 ] || return 1; scripts+=("$1"); shift; fi ;;
        *) [[ $w == *=* ]] && return 1
           for name in $hit; do case $name in debug|null-data|zero-terminated|quiet|silent|posix|regexp-extended|sandbox|separate|unbuffered) ;; *) return 1 ;; esac; done ;;
      esac
    elif [ "$opts" = 1 ] && [[ $w == -?* ]]; then
      o=${w#-}
      while [ -n "$o" ]; do
        c=${o:0:1}; o=${o:1}
        case $c in
          [nErszu]) ;;
          e) if [ -n "$o" ]; then scripts+=("$o"); else [ $# -gt 0 ] || return 1; scripts+=("$1"); shift; fi; o="" ;;
          *) return 1 ;;
        esac
      done
    else ops+=("$w"); fi
  done
  # with no -e the first operand is the script; the rest are files, which it reads
  if [ "${#scripts[@]}" -eq 0 ]; then [ "${#ops[@]}" -gt 0 ] || return 1; scripts=("${ops[0]}"); fi
  local IFS=$'\n'
  kru_sed_script "${scripts[*]}"
}

# kru_sed_script <script> — 0 when every command is on kru_sed_reads' list
kru_sed_script() {
  local s=$1 i=0 c d
  while :; do
    while [[ ${s:i:1} == [[:space:]\;] ]]; do i=$((i + 1)); done
    [ "$i" -ge "${#s}" ] && return 0
    kru_sed_addr first || return 1
    if [ "${s:i:1}" = , ]; then i=$((i + 1)); kru_sed_addr second || return 1; fi
    while [[ ${s:i:1} == [[:blank:]!] ]]; do i=$((i + 1)); done
    c=${s:i:1}; i=$((i + 1))
    case $c in
      \{) continue ;;
      [}pdDq=GghHNPxl]) [[ $c == [ql] ]] && while [[ ${s:i:1} == [[:blank:]0-9] ]]; do i=$((i + 1)); done ;;
      y) d=${s:i:1}; [[ -n $d && $d != [[:space:]\\] ]] || return 1; i=$((i + 1)); kru_sed_part "$d" || return 1; kru_sed_part "$d" || return 1 ;;
      s) d=${s:i:1}; [[ -n $d && $d != [[:space:]\\] ]] || return 1; i=$((i + 1)); kru_sed_part "$d" re || return 1; kru_sed_part "$d" || return 1
         while [[ ${s:i:1} == [gpIiMm0-9] ]]; do i=$((i + 1)); done ;;
      *) return 1 ;;
    esac
    while [[ ${s:i:1} == [[:blank:]] ]]; do i=$((i + 1)); done
    [[ $i -ge ${#s} || ${s:i:1} == [\;$'\n'}] ]] || return 1
  done
}

# kru_sed_addr first|second — steps i (kru_sed_script's) past one address, if any
kru_sed_addr() {
  local d
  case ${s:i:1} in
    [0-9]) while [[ ${s:i:1} == [0-9] ]]; do i=$((i + 1)); done
      if [ "$1" = first ] && [ "${s:i:1}" = '~' ]; then i=$((i + 1)); while [[ ${s:i:1} == [0-9] ]]; do i=$((i + 1)); done; fi ;;
    \$) i=$((i + 1)) ;;
    [+~]) [ "$1" = second ] || return 1; i=$((i + 1)); while [[ ${s:i:1} == [0-9] ]]; do i=$((i + 1)); done ;;
    /|\\) d=/; [ "${s:i:1}" = \\ ] && { i=$((i + 1)); d=${s:i:1}; [[ -n $d && $d != $'\n' ]] || return 1; }
      i=$((i + 1)); kru_sed_part "$d" re || return 1
      while [[ ${s:i:1} == [IM] ]]; do i=$((i + 1)); done ;;
  esac
  return 0
}

# kru_sed_part <delim> [re] — steps i past text ending at an unescaped delim; a
# regex's bracket expression holds the delim literally, as GNU reads it
kru_sed_part() {
  local c
  while [ "$i" -lt "${#s}" ]; do
    c=${s:i:1}; i=$((i + 1))
    if [ "$c" = \\ ]; then i=$((i + 1))
    elif [ "$c" = "$1" ]; then return 0
    elif [ "$c" = '[' ] && [ "${2:-}" = re ]; then
      [ "${s:i:1}" = '^' ] && i=$((i + 1))
      [ "${s:i:1}" = ']' ] && i=$((i + 1))
      while [ "$i" -lt "${#s}" ] && [ "${s:i:1}" != ']' ]; do
        if [[ ${s:i:2} == \[[.:=] ]]; then c=${s:i+1:1}; i=$((i + 2)); while [ "$i" -lt "${#s}" ] && [ "${s:i:2}" != "$c]" ]; do i=$((i + 1)); done; i=$((i + 2))
        else i=$((i + 1)); fi
      done
      i=$((i + 1))
    fi
  done
  return 1
}

# kru_awk_runs — the awk branch matches this against the segment's quote-resolved
# words ("${KRU_W[*]}"). system(), getline, @include, @load and gawk's indirect
# @name() run code, and quoting can hide them (sys''tem, $'\x73ystem', @\x66).
# a | other than || pipes to a command and > writes a file: the quote-aware
# segment split no longer fail-closes those, so they are refused here too
kru_awk_runs='system[[:space:]]*\(|getline|@include|@load|@[[:space:]]*[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\(|>|(^|[^|])[|]([^|]|$)'

# kru_awk_reads <arg>... — -f/--file and every flag but -F and -v load or run a
# program the line can't show. system() and the rest of kru_awk_runs are the
# caller's check, on the quote-resolved words
kru_awk_reads() {
  while [ $# -gt 0 ]; do
    case $1 in
      --) return 0 ;;
      -[Fv]) shift ;;
      -[Fv]?*) ;;
      -*) return 1 ;;
      *) return 0 ;;
    esac
    shift
  done
  return 0
}

# kru_operands <max> <ere> <arg>... — 0 when at most max operands follow; a flag
# matching ere takes the next word as its value
kru_operands() {
  local max=$1 ere=$2 n=0 opts=1; shift 2
  while [ $# -gt 0 ]; do
    if [ "$opts" = 1 ] && [ "$1" = -- ]; then opts=0
    elif [ "$opts" = 1 ] && [[ $1 == -?* ]]; then [[ $1 =~ $ere ]] && shift
    else n=$((n + 1)); fi
    shift
  done
  [ "$n" -le "$max" ]
}

# kru_readonly_bash <command> — 0 when every segment only reads
kru_readonly_bash() {
  # awk's system() and getline run commands, system with any space before its
  # paren, and so does gawk's indirect @name(). quoting can hide them, so the
  # awk branch below checks the quote-resolved words too. the raw line still
  # answers whenever awk is on it, so grep or rg for the words still reads
  case $1 in *awk*) [[ $1 =~ system[[:space:]]*\(|getline|@include|@load|@[[:space:]]*[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\( ]] && return 1 ;; esac
  # any --output writes its file (git diff --output=x); --output-separator and
  # the other --output-* names don't
  [[ $1 =~ --output([=[:space:]\'\"]|$) ]] && return 1
  case "$1" in
    # a redirect, a substitution or an in-place edit writes whatever the verb is
    *'>'*|*'$('*|*'`'*|*'sed -i'*|*'perl -i'*|*'--in-place'*|*'-exec'*|*'-ok'*|*'-delete'*|*'-fprint'*|*'-fls'*|*'xargs'*|*'<('*) return 1 ;;
    *)
      # every segment of a chain or pipe answers for itself — a read-only head
      # says nothing about what follows it
      kru_segments "$1" || return 1
      for seg in "${KRU_S[@]}"; do
        seg=${seg#"${seg%%[![:space:]]*}"}; seg=${seg%"${seg##*[![:space:]]}"}
        [ -z "$seg" ] && continue
        verb=${seg%% *}
        case "${verb##*/}" in
          ls|cat|head|tail|wc|grep|egrep|fgrep|find|stat|pwd|realpath|basename|dirname) continue ;;
          which|type|echo|printf|jq|cut|tr|column|test|true|diff) continue ;;
          # the verbs that read until a flag or an operand says otherwise
          sort) kru_words "$seg" && ! kru_any '^(-[^-]*o|--o|--co)' && continue; return 1 ;;
          rg) kru_words "$seg" && ! kru_any '^--pre(=|$)' && continue; return 1 ;;
          sed) kru_words "$seg" && kru_sed_reads "${KRU_W[@]:1}" && continue; return 1 ;;
          awk) kru_words "$seg" && ! [[ ${KRU_W[*]} =~ $kru_awk_runs ]] && kru_awk_reads "${KRU_W[@]:1}" && continue; return 1 ;;
          yq) kru_words "$seg" && ! kru_any '^(-[a-zA-Z]*[is]|--inplace|--split-exp)' && continue; return 1 ;;
          date) kru_words "$seg" && ! kru_any '^(-[^-dfrI]*s|--s|[0-9.]{4,}$)' && continue; return 1 ;;
          command) kru_words "$seg" && [[ ${KRU_W[1]:-} == -[vV] ]] && continue; return 1 ;;
          uniq) kru_words "$seg" && kru_operands 1 '^-[fsw]$' "${KRU_W[@]:1}" && continue; return 1 ;;
          file) kru_words "$seg" && ! kru_any '^(-[^-]*C|--co)' && continue; return 1 ;;
          base64) kru_words "$seg" && ! kru_any '^(-[^-]*o|--o)' && continue; return 1 ;;
          # safe only because the write-tell case above already took any redirect
          nl|tac|comm) continue ;;
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
      done
      return 0 ;;
  esac
}
