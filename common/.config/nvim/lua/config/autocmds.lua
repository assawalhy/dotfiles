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
-- `vim.b.large_file`; `plugins/lsp.lua` opts out on that flag, and the
-- per-buffer features below are pure overhead at this size. Threshold is
-- bytes, read from `fs_stat` before the file is loaded.
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

-- The flag above alone is not enough: treesitter is reached from several
-- directions, not just `plugins/treesitter.lua`. nvim's own
-- `ftplugin/lua.lua` calls `vim.treesitter.start()` unconditionally, and
-- rainbow-delimiters, indent-blankline and nvim-ts-context-commentstring all
-- pull `get_parser()` out on their own autocmds - each of which parses the
-- whole buffer, which is what wedged a 3 MB dump of garbage at 100% CPU.
-- Guard the two entry points instead of every caller. Returning nil from
-- `get_parser` is nvim 0.12's documented "no parser" result, which all of the
-- callers above already handle.
local function blocked(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].large_file == true
end

local treesitter_start = vim.treesitter.start
vim.treesitter.start = function(bufnr, ...)
  if blocked(bufnr) then return end
  return treesitter_start(bufnr, ...)
end

local treesitter_get_parser = vim.treesitter.get_parser
vim.treesitter.get_parser = function(bufnr, ...)
  if blocked(bufnr) then return end
  return treesitter_get_parser(bufnr, ...)
end
