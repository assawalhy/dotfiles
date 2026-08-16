-- copy to clipboard
-- ~/bin/clip comes from the dotfiles repo and picks pbcopy / wl-copy / xclip /
-- xsel at runtime, so this needs no platform branch.
-- NOTE: vim.fn.executable() returns a number, and 0 is truthy in Lua -- it must
-- be compared against 1, never used as a bare condition.
function CopyBuffer()
  if vim.fn.executable 'clip' ~= 1 then
    vim.notify("Can't find `clip` -- is ~/bin on your PATH?", vim.log.levels.ERROR)
    return
  end
  vim.cmd 'silent write !clip'
  print 'Buffer is copied'
end

vim.keymap.set('x', ';y', '"+y', { desc = 'Copy selection to sys clipboard' })
vim.keymap.set('n', ';wc', CopyBuffer, { desc = 'Copy current buffer to sys clipboard' })
vim.keymap.set('x', 'gsw', "'<,'> ! awk '{ print length(), $0 } | sort -n | cut -d\\  -f2-'<CR><ESC>", { desc = 'Sort selected lines by line width' })

-- easily move in wrapped lines
vim.keymap.set('n', 'j', "v:count ? 'j' : 'gj'", { silent = true, expr = true, desc = 'Move down in wrapped lines' })
vim.keymap.set('n', 'k', "v:count ? 'k' : 'gk'", { silent = true, expr = true, desc = 'Move up in wrapped lines' })

-- navigate tabs done by bufferline plugin
vim.keymap.set('n', '<tab>n', '<CMD>tabnew<CR>', { desc = 'New tab' })
vim.keymap.set('n', '<tab>l', '<CMD>BufferLineCycleNext<CR>', { desc = 'Next buffer tab' })
vim.keymap.set('n', '<tab>h', '<CMD>BufferLineCyclePrev<CR>', { desc = 'Previous buffer tab' })
vim.keymap.set('n', '<tab>x', '<CMD>BufferLineCloseOthers<CR>', { desc = 'Close other buffer tabs' })
vim.keymap.set('n', '<tab>p', '<CMD>BufferLinePick<CR>', { desc = 'Pick buffer tab' })
vim.keymap.set('n', '<tab>P', '<CMD>BufferLineTogglePin<CR>', { desc = 'Toggle buffer tab pin' })

-- navigate windows
vim.keymap.set('n', '<C-w><C-q>', '<CMD>bd<cr>', { desc = 'Delete buffer' })
vim.keymap.set('n', '<C-w>q', '<CMD>bd<cr>', { desc = 'Delete buffer' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Focus window right' })
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Focus window left' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Focus window below' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Focus window above' })

-- delete without yanking
vim.keymap.set('n', ';d', '"_d', { desc = 'Delete without yanking' })
vim.keymap.set('n', ';c', '"_c', { desc = 'Change without yanking' })
vim.keymap.set('n', ';D', '"_D', { desc = 'Delete to end of line without yanking' })
vim.keymap.set('v', ';d', '"_d', { desc = 'Delete selection without yanking' })
vim.keymap.set('v', ';c', '"_c', { desc = 'Change selection without yanking' })
vim.keymap.set('v', ';D', '"_D', { desc = 'Delete selection to end of line without yanking' })
vim.keymap.set('v', ';p', '"_dP', { desc = 'Paste over selection without yanking' })

vim.cmd [[
command! LocalTerm let s:term_dir=expand('%:p:h') | below new | call termopen([&shell], {'cwd': s:term_dir })
]]

vim.keymap.set('n', '<space>t', ':LocalTerm<cr>', { desc = "Open a terminal in the current file's directory" })

-- Comment plugin <C-_> maps
vim.cmd [[nmap <C-_> gcc]]
vim.cmd [[xmap <C-_> gc]]
