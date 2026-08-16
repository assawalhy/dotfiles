-- copy to clipboard
-- ~/bin/clip comes from the dotfiles repo and picks pbcopy / wl-copy / xclip /
-- xsel at runtime, so this needs no platform branch.
-- NOTE: vim.fn.executable() returns a number, and 0 is truthy in Lua -- it must
-- be compared against 1, never used as a bare condition.
function CopyBuffer()
  if vim.fn.executable('clip') ~= 1 then
    vim.notify("Can't find `clip` -- is ~/bin on your PATH?", vim.log.levels.ERROR)
    return
  end
  vim.cmd('silent write !clip')
  print('Buffer is copied')
end

vim.keymap.set('x', ';y', '"+y', { desc = "Copy selection to sys clipboard" })
vim.keymap.set('n', ';wc', CopyBuffer, { desc = "Copy current buffer to sys clipboard" })
vim.keymap.set('x', 'gsw', "'<,'> ! awk '{ print length(), $0 } | sort -n | cut -d\\  -f2-'<CR><ESC>",
  { desc = "Sort selected lines by line width" })

-- easily move in wrapped lines
vim.keymap.set('n', 'j', "v:count ? 'j' : 'gj'", { silent = true, expr = true })
vim.keymap.set('n', 'k', "v:count ? 'k' : 'gk'", { silent = true, expr = true })

-- navigate tabs done by bufferline plugin
vim.keymap.set('n', '<tab>n', '<CMD>tabnew<CR>', {})
vim.keymap.set('n', '<tab>l', '<CMD>BufferLineCycleNext<CR>', {})
vim.keymap.set('n', '<tab>h', '<CMD>BufferLineCyclePrev<CR>', {})
vim.keymap.set('n', '<tab>x', '<CMD>BufferLineCloseOthers<CR>', {})
vim.keymap.set('n', '<tab>p', '<CMD>BufferLinePick<CR>', {})
vim.keymap.set('n', '<tab>P', '<CMD>BufferLineTogglePin<CR>', {})

-- navigate windows
vim.keymap.set('n', '<C-w><C-q>', '<CMD>bd<cr>', { desc = 'Delete buffer' })
vim.keymap.set('n', '<C-w>q', '<CMD>bd<cr>', { desc = 'Delete buffer' })
vim.keymap.set('n', '<C-l>', '<C-w>l', {})
vim.keymap.set('n', '<C-h>', '<C-w>h', {})
vim.keymap.set('n', '<C-j>', '<C-w>j', {})
vim.keymap.set('n', '<C-k>', '<C-w>k', {})

-- vim.keymap.set("n", "<C-d>", "<C-d>zz")
-- vim.keymap.set("n", "<C-u>", "<C-u>zz")
-- vim.keymap.set("n", "n", "nzzzv")
-- vim.keymap.set("n", "N", "Nzzzv")

-- delete without yanking
vim.keymap.set('n', ';d', '"_d', {})
vim.keymap.set('n', ';c', '"_c', {})
vim.keymap.set('n', ';D', '"_D', {})
vim.keymap.set('v', ';d', '"_d', {})
vim.keymap.set('v', ';c', '"_c', {})
vim.keymap.set('v', ';D', '"_D', {})
vim.keymap.set('v', ';p', '"_dP', {})

vim.cmd [[
command! LocalTerm let s:term_dir=expand('%:p:h') | below new | call termopen([&shell], {'cwd': s:term_dir })
]]

vim.keymap.set('n', '<space>t', ':LocalTerm<cr>', { desc = 'Open a terminal in the current file\'s directory' })

-- Comment plugin <C-_> maps
vim.cmd([[nmap <C-_> gcc]])
vim.cmd([[xmap <C-_> gc]])