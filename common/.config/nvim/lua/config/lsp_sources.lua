-- Library sources for the JVM language servers.
--
-- Go-to-definition into a dependency or the JDK returns virtual URIs:
-- kotlin-lsp uses `jar://`/`jrt://`, jdtls uses `jdt://`. No file exists on
-- disk and Neovim keeps the name verbatim (`uri_from_bufnr` returns it
-- unchanged), so without a reader the buffer stays empty and show_document()
-- then fails to place the cursor ("Invalid cursor line: out of range").
-- Both servers can hand the source over the LSP channel instead (the
-- mechanism their official clients use):
--   jar/jrt -> workspace/executeCommand `decompile` -> { code, language }
--   jdt     -> `java/classFileContents` request      -> source text
-- Filling the buffer has to block until the answer arrives: show_document()
-- sets the cursor right after displaying the buffer, so returning early would
-- leave it out of range again.

local api = vim.api

-- Decompiling on first access can take a few seconds.
local TIMEOUT_MS = 20000

-- Which server serves which scheme (the pair configured in config/java.lua).
local SERVERS = { jar = 'kotlin_lsp', jrt = 'kotlin_lsp', jdt = 'jdtls' }

local M = {}

--- BufReadCmd handler: fill `buf` with the source behind its virtual URI.
---@param buf integer
function M.read(buf)
  local uri = api.nvim_buf_get_name(buf)
  local scheme = uri:match '^(%w+)://'
  local server = SERVERS[scheme]
  local client = server and vim.lsp.get_clients({ name = server })[1]

  local code, language, err
  if not client then
    err = ('no %s client'):format(server or 'matching LSP')
  elseif scheme == 'jdt' then
    local resp = client:request_sync('java/classFileContents', { uri = uri }, TIMEOUT_MS)
    if resp == nil then
      err = 'request timed out'
    elseif resp.err then
      err = vim.inspect(resp.err)
    elseif type(resp.result) == 'string' then
      code, language = resp.result, 'java'
    else
      err = 'empty response'
    end
  else
    local resp = client:request_sync('workspace/executeCommand', { command = 'decompile', arguments = { uri } }, TIMEOUT_MS)
    if resp == nil then
      err = 'request timed out'
    elseif resp.err then
      err = vim.inspect(resp.err)
    elseif type(resp.result) == 'table' and type(resp.result.code) == 'string' then
      code, language = resp.result.code, resp.result.language
    else
      err = 'empty response'
    end
  end

  local ok = code ~= nil
  if not ok then
    vim.notify(('lsp_sources: cannot load %s: %s'):format(uri, err), vim.log.levels.WARN)
    code = ('// Failed to load %s: %s'):format(uri, err)
  end
  if not language or language == '' then
    language = uri:match '%.kt$' and 'kotlin' or 'java'
  end

  api.nvim_buf_set_lines(buf, 0, -1, false, vim.split((code:gsub('\r\n', '\n')), '\n', { plain = true }))
  -- buftype first: a non-empty buftype keeps vim.lsp.enable from auto-starting
  -- a second client on this buffer (vim/lsp.lua skips non-file buffers); the
  -- serving client is attached explicitly below with the URI kept intact.
  vim.bo[buf].buftype = 'nowrite'
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = true
  vim.bo[buf].filetype = language
  vim.bo[buf].readonly = true
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  pcall(vim.treesitter.start, buf, language)

  if ok and client and not vim.lsp.buf_is_attached(buf, client.id) then
    pcall(vim.lsp.buf_attach_client, buf, client.id)
  end
end

function M.setup()
  api.nvim_create_autocmd('BufReadCmd', {
    group = api.nvim_create_augroup('lsp_sources', { clear = true }),
    pattern = { 'jar://*', 'jrt://*', 'jdt://*' },
    desc = 'load JVM library sources through kotlin-lsp/jdtls',
    callback = function(args)
      api.nvim_buf_call(args.buf, function()
        M.read(args.buf)
      end)
    end,
  })
end

return M
