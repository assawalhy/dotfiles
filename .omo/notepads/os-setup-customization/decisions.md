# Notepad: os-setup-customization

## decisions.md
- Tier table: p1 essentials+agents / p2 dev workstation / p3 GUI / p4 occasional.
- Agents: native-installer steps (61-opencode.sh, 62-claude-code.sh), no sudo, no npm.
- Priority token: bare `pN` last token before `#` comment; unlabeled => p4.
- link-files picker: fzf --multi with ctrl-a/ctrl-d; tty check decides fzf-vs-fallback INSIDE picker; gate is `[ -z "$is_dry" ] && [ -z "$is_yes" ] && [ -z "$pattern_given" ]` (NO -t 0 in gate).
- Waves: W1={1,5,6,7} parallel, W2={2,8} parallel, W3={3}, W4={4}, W5={9}.
