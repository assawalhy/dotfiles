# TODO — kulala.nvim backend download

Decide branch A (token) or B (drop plugin) with the user first — see PLAN.md.
No code changes until that answer.

- [ ] 1. Ask: do you have a Kulala license token / account?
- [ ] 2. Branch A only: add `KULALA_CORE_LICENSE_TOKEN` to the shell env
      (uncommitted)
- [ ] 3. Branch A only: `editor.lua:142` → `dont-be-evil-company/kulala.nvim`,
      add explicit `kulala_core.download_url`, then `:Lazy update`
- [ ] 4. Verify: open a `.http` file, `<leader>Rs`, confirm a response renders
      and `~/.local/share/nvim/lazy/kulala.nvim/../kulala.nvim/bin/version.txt`
      holds the new backend version
- [ ] 5. Branch B only: remove the kulala spec + `<leader>R*` maps from `editor.lua`
- [ ] 6. `nvim --headless` smoke check that the plugin spec still loads
