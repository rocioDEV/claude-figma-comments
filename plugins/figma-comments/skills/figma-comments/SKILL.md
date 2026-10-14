---
name: figma-comments
description: List the unresolved comment threads on a Figma file, with replies and a link to each commented node, optionally only those that mention someone. Use whenever the user asks about Figma comments — "what's open in Figma", "comments that mention me", "did the designer reply", "pending feedback on this file" — or shares a figma.com link and asks about comments, feedback or mentions. The Figma MCP server cannot read comments at all, so use this skill instead of trying get_design_context, use_figma or the browser.
---

# Figma comments

The Figma MCP tools only see the design (nodes, variables, screenshots); comments are only
reachable through the REST API, which needs a personal access token. This skill wraps that call.

## Run it

The script lives in `scripts/` next to this file; build its path from this skill's base
directory.

```bash
<skill base dir>/scripts/unresolved.sh '<figma url or file key>'
<skill base dir>/scripts/unresolved.sh '<url>' --mention '<their Figma handle>'
```

- Quote the URL: it contains `&` and `?`.
- For "comments that mention me", pass the user's Figma handle to `--mention`. Mentions reach
  the API as the plain name in the text, not as an id, so filtering by the name is what works.
  If you don't know the handle, the Figma MCP `whoami` tool returns it when that server is
  connected; otherwise ask the user for their name as it appears in Figma.
- For "threads I'm in", "my comments", "did anyone reply to me", pass the handle to `--author`:
  it keeps threads where that person wrote the root or any reply, which catches answers that
  don't repeat their name. For "everything that concerns me", pass both — they combine with OR.
- The script prints one block per unresolved thread, newest first: date, author, node link,
  the message, then its replies. Resolved threads are left out because resolution is set on
  the thread's root comment.

## The token

The script reads `$FIGMA_TOKEN`, or falls back to `~/.config/figma/token`. Never print,
echo or grep for the token, and never ask the user to paste it into the chat: anything pasted
there is kept in the conversation history. Environment variables don't carry over between
Claude Code's shell calls, so the file is the reliable option.

If the script exits 3 (no token), tell the user to:

1. Create one in Figma: avatar → Settings → Security → Personal access tokens → Generate,
   with the **Comments: Read** scope only.
2. Save it **in their own terminal**, not through Claude:
   `mkdir -p ~/.config/figma && read -rs t && printf '%s' "$t" > ~/.config/figma/token && chmod 600 ~/.config/figma/token`
   (paste the token at the silent prompt, then press Enter).

If it exits 4 with a 403, the token is wrong or expired, it lacks the comments scope, or the
file's organisation blocks personal tokens. The error line says which one is likely.

## Answering

Lead with the count, then a short table: date, author, the comment (translated if it isn't in
the user's language), and the node link. Say which threads ask the user something and which
only tell them about a change, because the first kind needs a reply. A thread the user started
whose last reply says it is done is waiting on the user to check it and resolve it; call those
out separately. Don't dump the raw output.
