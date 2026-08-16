-- Diagnostic symbols in the sign column (gutter)
local signs = { Error = ' ', Warn = ' ', Hint = ' ', Info = ' ' }
for type, icon in pairs(signs) do
  local hl = 'DiagnosticSign' .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = '' })
end

vim.diagnostic.config {
  virtual_text = true,
  underline = false,
  update_in_insert = false,
  severity_sort = true,
}

local function get_capabilities()
  local ok, blink = pcall(require, 'blink.cmp')
  if ok then
    return blink.get_lsp_capabilities()
  end
  local caps = vim.lsp.protocol.make_client_capabilities()
  caps.textDocument.completion.completionItem.snippetSupport = true
  return caps
end

local augroup = vim.api.nvim_create_augroup('nvim_lsp_attach', { clear = true })
vim.api.nvim_create_autocmd('LspAttach', {
  group = augroup,
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == 'copilot' then
      return
    end

    vim.keymap.set('n', ';rn', vim.lsp.buf.rename, { buffer = bufnr, desc = 'LSP: [R]e[n]ame' })
    vim.keymap.set('n', ';ac', vim.lsp.buf.code_action, { buffer = bufnr, desc = 'LSP: [A]ction [C]ode' })
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = bufnr, desc = 'LSP: [G]oto [D]efinition' })
    vim.keymap.set('n', 'gp', vim.lsp.buf.hover, { buffer = bufnr, desc = 'LSP: [P]eek/hover' })
    vim.keymap.set('n', 'gtd', vim.lsp.buf.type_definition, { buffer = bufnr, desc = 'LSP: [G]oto [T]ype [D]efinition' })
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, { buffer = bufnr, desc = 'LSP: [G]oto [R]eferences' })
    vim.keymap.set('n', '[d', function()
      vim.diagnostic.jump { count = -1, float = true }
    end, { buffer = bufnr, desc = 'LSP: Previous [D]iagnostic' })
    vim.keymap.set('n', ']d', function()
      vim.diagnostic.jump { count = 1, float = true }
    end, { buffer = bufnr, desc = 'LSP: Next [D]iagnostic' })
  end,
})

vim.keymap.set('n', '<leader>dd', vim.diagnostic.setloclist, { desc = 'LSP: Open diagnostics list' })
