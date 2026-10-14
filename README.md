# figma-comments
**Figma's official MCP** server **reads the design but not its comments**, so this skill calls the
Figma REST API directly with your own personal access token.

This is a Claude Code skill that lists the **unresolved comment threads** on a Figma file, with their
replies and a link to each commented node. Ask Claude things like:

- "What's still open in this Figma file?" + a figma.com link
- "Figma comments that mention me"
- "Did anyone reply to my comments in Figma?"



## Install

```
/plugin marketplace add rocioDEV/claude-figma-comments
/plugin install figma-comments@claude-figma-comments
```

It needs `curl` and `jq` on your machine.

## Your Figma token

1. In Figma: avatar → **Settings** → **Security** → **Personal access tokens** →
   **Generate new token**, with the **Comments: Read** scope only.
2. Save it in your own terminal (not through Claude, so it never lands in a chat transcript):

   ```bash
   mkdir -p ~/.config/figma && read -rs t && printf '%s' "$t" > ~/.config/figma/token && chmod 600 ~/.config/figma/token
   ```

   Paste the token at the silent prompt and press Enter. `FIGMA_TOKEN` in the environment
   works too and takes precedence.

A 403 means the token is wrong or expired, lacks the comments scope, or the file's
organisation does not allow personal access tokens.

## Running the script by hand

```bash
plugins/figma-comments/skills/figma-comments/scripts/unresolved.sh '<figma url or file key>' \
  [--mention '<name>'] [--author '<figma handle>']
```

- `--mention` keeps threads where any comment contains the name. Figma mentions reach the API
  as plain text.
- `--author` keeps threads where that person wrote the first comment or a reply.
- Both together keep a thread when either matches.

## License

MIT
