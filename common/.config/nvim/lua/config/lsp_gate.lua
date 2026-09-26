-- Per-buffer activation gate for language servers.
--
-- `vim.lsp.enable(name, enable)` only takes a boolean, so it cannot decide
-- per buffer. The documented way to keep a config from activating on a given
-- buffer is to leave `root_dir` unresolved: no root, no client. Every enabled
-- server is therefore wrapped here instead of enabled bare.
local M = {}

--- Reason string when `server` must not attach to `bufnr`, nil otherwise.
---@type fun(bufnr: integer): string|nil
local function default_blocked(bufnr)
  if vim.b[bufnr].large_file then
    return 'buffer over the size limit'
  end
end

---@param server string LSP config name (must already be configured).
---@param blocked? fun(bufnr: integer): string|nil Extra blocker, on top of
--- the large-file guard in `config/autocmds.lua`.
function M.gate(server, blocked)
  blocked = blocked or default_blocked

  local cfg = vim.lsp.config[server]
  local root_dir = cfg.root_dir
  local markers = cfg.root_markers

  vim.lsp.config(server, {
    root_dir = function(bufnr, on_dir)
      if blocked(bufnr) then
        return
      end
      if type(root_dir) == 'function' then
        root_dir(bufnr, on_dir)
      elseif root_dir then
        on_dir(root_dir)
      else
        local root = vim.fs.root(bufnr, markers or { '.git' })
        if root then
          on_dir(root)
        end
      end
    end,
  })

  vim.lsp.enable(server)
end

return M
