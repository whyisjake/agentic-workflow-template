#!/usr/bin/env bash
# Parses every workflow file under .github/workflows/ and fails if any of them
# is not valid YAML.
#
# Usage:
#   bash scripts/validate-workflows.sh [directory]
#
# Why this exists:
#   A workflow file that does not parse does not fail loudly. GitHub cannot
#   schedule a job it could not read, so the run ends in seconds with no jobs
#   and no log — which reads as a broken command rather than a broken file.
#
#   The usual cause is an unquoted ": " inside a run: line, because a plain YAML
#   scalar containing a colon followed by a space is a mapping, not a string:
#
#     run: echo $(( x > 0 ? 1 : 0 ))      # breaks
#     run: git commit -m "fix: thing"     # breaks too — quotes do not help,
#                                         # the outer scalar is still plain
#
#   Both are lines an agent could reasonably write. A block scalar makes the
#   colon just a character:
#
#     run: |
#       git commit -m "fix: thing"
#
# Exits 0 when every file parses, 1 otherwise.

set -euo pipefail

WORKFLOW_DIR="${1:-.github/workflows}"

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }

if [[ ! -d "$WORKFLOW_DIR" ]]; then
  dim "No $WORKFLOW_DIR directory — nothing to validate."
  exit 0
fi

# Pick a YAML parser. Both are stdlib-or-common: PyYAML on the GitHub runners,
# Psych with every Ruby. Checked by actually importing, because "python3 exists"
# and "python3 can parse YAML" are different claims.
PARSER=""
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  PARSER="python"
elif command -v ruby >/dev/null 2>&1 && ruby -ryaml -e '' >/dev/null 2>&1; then
  PARSER="ruby"
else
  red "Error: no YAML parser available."
  red "       Install PyYAML (pip install pyyaml) or make ruby available."
  exit 1
fi

parse_file() {
  local file="$1"
  if [[ "$PARSER" == "python" ]]; then
    python3 -c '
import sys, yaml
try:
    with open(sys.argv[1]) as handle:
        yaml.safe_load(handle)
except Exception as err:
    print(err, file=sys.stderr)
    sys.exit(1)
' "$file"
  else
    # Psych 4 refuses aliases unless asked; Psych 3 does not know the keyword.
    # Workflows may legitimately use anchors, so try the permissive call first.
    ruby -ryaml -e '
begin
  begin
    YAML.load_file(ARGV[0], aliases: true)
  rescue ArgumentError
    YAML.load_file(ARGV[0])
  end
rescue => err
  warn err.message
  exit 1
end
' "$file"
  fi
}

failed=0
checked=0

while IFS= read -r file; do
  checked=$((checked + 1))
  if error="$(parse_file "$file" 2>&1)"; then
    green "  ok: $file"
  else
    failed=$((failed + 1))
    red   "  FAILED TO PARSE: $file"
    printf '%s\n' "$error" | sed 's/^/      /'
  fi
done < <(find "$WORKFLOW_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

echo ""

if [[ "$checked" -eq 0 ]]; then
  dim "No workflow files found in $WORKFLOW_DIR."
  exit 0
fi

if [[ "$failed" -gt 0 ]]; then
  red "$failed of $checked workflow file(s) do not parse."
  red "A workflow that does not parse produces a run with no jobs and no log."
  red "If the problem is a colon in a run: line, use a block scalar:"
  red ""
  red "    run: |"
  red "      your command here"
  exit 1
fi

green "All $checked workflow file(s) parse."
