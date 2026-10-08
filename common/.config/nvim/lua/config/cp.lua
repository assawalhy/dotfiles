-- Competitive programming workspace root.
--
-- Two very different features need this path: the snippets provider and
-- CompetiTest. Both used to hardcode `~/myp/problem-solving`, which no longer
-- exists, so blink's snippet scan resolved to an empty registry (zero snippets
-- loaded, silently) and CompetiTest wrote received problems into a directory
-- that was not there. Keep the path in one place so the two cannot drift apart
-- again.
local M = {}

local home = vim.uv.os_homedir() or vim.env.HOME

---@return string
function M.root()
  local candidates = {
    vim.env.CP_ROOT,
    home .. '/Projects/problem-solving',
    home .. '/myp/problem-solving', -- legacy location, still honoured
  }
  for _, path in ipairs(candidates) do
    if path and path ~= '' and vim.uv.fs_stat(path) then return path end
  end
  return home .. '/Projects/problem-solving'
end

--- Snippet files, one `<filetype>.json` per language. A dedicated leaf
--- directory matters: blink recurses `search_paths`, and the repo root holds
--- hundreds of per-contest directories.
---@return string
function M.snippets_dir()
  return M.root() .. '/snippets'
end

--- Template used when CompetiTest creates a source file for a received problem.
---@param ext string file extension, or a CompetiTest modifier such as `$(FEXT)`
---@return string
function M.template(ext)
  return ('%s/template.%s'):format(M.root(), ext)
end

return M
