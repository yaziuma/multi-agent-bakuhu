#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <markdown-file> <heading-text>" >&2
  exit 2
fi

file=$1
target=$2

# Require that heading has at least one # and a space after them
case "$target" in
  \#*" "*) ;;
  *)
    echo "Error: heading text must include '#' and a space (e.g. '## Section')" >&2
    exit 2
    ;;
esac

awk -v target="$target" '
BEGIN {
  found = 0
  printing = 0
  target_level = 0
}

# Return heading level if line is a valid heading, else 0
function heading_level(line,   n, i, ch) {
  n = 0
  for (i = 1; i <= length(line); i++) {
    ch = substr(line, i, 1)
    if (ch == "#") n++
    else break
  }
  if (n == 0) return 0
  if (substr(line, n+1, 1) != " ") return 0
  return n
}

{
  line = $0
  gsub(/\r$/, "", line)
  lvl = heading_level(line)

  if (lvl > 0) {
    if (!found && line == target) {
      found = 1
      printing = 1
      target_level = lvl
      print line
      next
    }

    if (printing && lvl <= target_level) {
      exit
    }
  }

  if (printing) print line
}

END {
  if (!found) exit 1
}
' "$file"
