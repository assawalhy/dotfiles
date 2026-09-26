-- Highlight on yank
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

-- Large-file guard. Treesitter and the LSP parse the whole buffer, so a
-- multi-megabyte file freezes the editor. Mark files above the threshold with
-- `vim.b.large_file`; `plugins/treesitter.lua` and `plugins/lsp.lua` opt out
-- on that flag, and the per-buffer features below are pure overhead at this
-- size. Threshold is bytes, read from `fs_stat` before the file is loaded.
local MAX_FILE_BYTES = 1024 * 1024 -- 1 MiB

vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
  callback = function(args)
    if vim.b[args.buf].large_file then return end

    local name = vim.api.nvim_buf_get_name(args.buf)
    if name == '' then return end

    local stat = vim.uv.fs_stat(name)
    if not stat or stat.type ~= 'file' or stat.size <= MAX_FILE_BYTES then return end

    vim.b[args.buf].large_file = true

    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.spell = false
    vim.opt_local.swapfile = false -- don't write a huge swap file
    vim.opt_local.undofile = false -- don't persist a huge undo history
    vim.diagnostic.enable(false, { bufnr = args.buf })
  end,
})
