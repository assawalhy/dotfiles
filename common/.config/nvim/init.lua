-- Set <space> as the leader key
-- NOTE: should be before loading plugins
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require 'config.lazy'
require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
