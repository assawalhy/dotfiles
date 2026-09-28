vim.o.hlsearch = false
vim.o.incsearch = false

vim.wo.number = true

vim.o.mouse = 'a'
vim.opt.mousescroll = "ver:1,hor:2"

-- Sync clipboard between OS and Neovim.
-- vim.o.clipboard = 'unnamedplus'

vim.o.wrap = false

vim.o.breakindent = true

vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4

vim.o.undofile = true

-- Searches are case-insensitive unless the pattern contains \C or an uppercase letter.
vim.o.ignorecase = true
vim.o.smartcase = true

vim.wo.signcolumn = 'yes'

vim.o.updatetime = 250
vim.o.timeoutlen = 300

vim.o.completeopt = 'menuone,noselect'

-- NOTE: the terminal must support true color for this setting to render correctly
vim.o.termguicolors = true

vim.o.scrolloff = 10

vim.o.list = true
vim.opt.listchars:append 'eol:↴'
