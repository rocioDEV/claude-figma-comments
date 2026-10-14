#!/usr/bin/env bash
# List the unresolved comment threads on a Figma file, with their replies.
#
#   unresolved.sh <figma-url-or-file-key> [--mention <text>] [--author <handle>]
#
# The token comes from $FIGMA_TOKEN, or from ~/.config/figma/token. It is never printed.
# --mention keeps only threads where some comment contains <text> (case-insensitive),
# which is how Figma mentions arrive through the API: as the person's name in plain text.
# --author keeps only threads where <handle> wrote the root or a reply (exact handle,
# case-insensitive). Given both, a thread is kept when either matches.
set -euo pipefail

usage() { echo "usage: $0 <figma-url-or-file-key> [--mention <text>] [--author <handle>]" >&2; exit 2; }

[ $# -ge 1 ] || usage
target=$1; shift
mention=""
author=""
while [ $# -gt 0 ]; do
  case $1 in
    --mention) [ $# -ge 2 ] || usage; mention=$2; shift 2 ;;
    --author)  [ $# -ge 2 ] || usage; author=$2; shift 2 ;;
    *) usage ;;
  esac
done

# A branch URL points at the branch key, which is the file the comments live on.
if [[ $target =~ figma\.com/(design|file|board)/[^/]+/branch/([0-9A-Za-z]+) ]]; then
  key=${BASH_REMATCH[2]}
elif [[ $target =~ figma\.com/(design|file|board)/([0-9A-Za-z]+) ]]; then
  key=${BASH_REMATCH[2]}
elif [[ $target =~ ^[0-9A-Za-z]{10,}$ ]]; then
  key=$target
else
  echo "error: cannot find a file key in: $target" >&2; exit 2
fi

token=${FIGMA_TOKEN:-}
if [ -z "$token" ] && [ -r "$HOME/.config/figma/token" ]; then
  token=$(tr -d '[:space:]' < "$HOME/.config/figma/token")
fi
if [ -z "$token" ]; then
  echo "error: no Figma token. Set FIGMA_TOKEN or write it to ~/.config/figma/token (chmod 600)." >&2
  exit 3
fi

body=$(mktemp); trap 'rm -f "$body"' EXIT
status=$(curl -sS -o "$body" -w '%{http_code}' \
  -H "X-Figma-Token: $token" \
  "https://api.figma.com/v1/files/$key/comments?as_md=true")

case $status in
  200) ;;
  403) echo "error: 403 — token invalid, expired, missing the comments:read scope, or the org blocks personal tokens." >&2; exit 4 ;;
  404) echo "error: 404 — no file $key, or this token's account cannot open it." >&2; exit 4 ;;
  429) echo "error: 429 — rate limited by Figma; try again in a minute." >&2; exit 4 ;;
  *)   echo "error: HTTP $status from Figma: $(head -c 300 "$body")" >&2; exit 4 ;;
esac

# Resolution lives on the root comment; replies inherit it. So: pick unresolved roots,
# attach their replies, optionally filter by mention or author, newest thread first.
jq -r --arg key "$key" --arg mention "$mention" --arg author "$author" '
  .comments as $all
  | [ $all[] | select((.parent_id // "") == "" and .resolved_at == null) ] as $roots
  | [ $roots[]
      | . as $root
      | { root: $root,
          replies: ([ $all[] | select(.parent_id == $root.id) ] | sort_by(.created_at)) }
      | [.root, .replies[]] as $thread
      | select(($mention == "" and $author == "")
               or ($mention != "" and ($thread | any(.message | ascii_downcase | contains($mention | ascii_downcase))))
               or ($author != "" and ($thread | any(.user.handle | ascii_downcase == ($author | ascii_downcase)))))
    ]
  | sort_by(.root.created_at) | reverse
  | "\(length) unresolved thread(s) on \($key)"
      + ([ (if $mention != "" then "mentioning \"\($mention)\"" else empty end),
           (if $author != "" then "with comments by \"\($author)\"" else empty end) ]
         | if length > 0 then " " + join(" or ") else "" end),
    ( .[]
      | (.root.client_meta.node_id // null) as $node
      | "",
        "## \(.root.created_at[:10]) · \(.root.user.handle)"
          + (if $node then " · https://www.figma.com/design/\($key)/?node-id=\($node | gsub(":"; "-"))" else " · (pinned on canvas, no node)" end),
        "  \(.root.message | gsub("\n"; "\n  "))",
        ( .replies[] | "  ↳ \(.created_at[:10]) \(.user.handle): \(.message | gsub("\n"; "\n    "))" )
    )
' "$body"
