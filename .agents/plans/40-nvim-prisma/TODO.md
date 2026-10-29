# TODO — Prisma support in the nvim config

- [x] epic files created (this dir)
- [x] `lua/plugins/treesitter.lua`: `prisma = true` in `wanted`
- [x] `lua/config/prisma.lua`: first-use prompt, install, `vim.lsp.enable` after install
- [x] `lua/plugins/lsp.lua`: `prismals` in the gate loop, `require('config.prisma').setup()`
- [x] link the new file: `link-files.bash --fix -y 'config/prisma.lua'`
- [x] verify: headless load of the three files, then a full config start
- [x] verify: `vim.lsp.config['prismals']` resolves, and a schema in a git fixture attaches a prismals client
- [x] verify: prompt path stubbed, accept installs once and attaches, decline and cancel stay quiet
- [x] verify: conform LSP fallback formats a misformatted schema
- [x] verify: bats suites (link-files 99 ok, select 5 ok, montag 16 ok, 0 not ok each)
