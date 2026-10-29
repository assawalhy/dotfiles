-- The Prisma language server is installed on first use instead of being listed
-- in mason-lspconfig's ensure_installed (lua/plugins/lsp.lua): it is an npm
-- package, the heaviest thing this config would otherwise install unasked.
-- Declining is remembered for the session, and cancelling counts as declining.
local M = {}

local PACKAGE = 'prisma-language-server'
local ACCEPT = 'Install Prisma support'

local declined = false
local installing = false

local function registry()
  local ok, mod = pcall(require, 'mason-registry')
  if ok then
    return mod
  end
end

local function install()
  local reg = registry()
  local ok, pkg = pcall(reg.get_package, PACKAGE)
  if not ok or pkg:is_installing() then
    installing = false
    return
  end

  vim.notify(('prisma: installing %s'):format(PACKAGE))
  pkg:install({}, function(success, err)
    installing = false
    if not success then
      vim.notify(('prisma: %s install failed: %s'):format(PACKAGE, err), vim.log.levels.WARN)
      return
    end
    -- Re-enabling replays the `nvim.lsp.enable` FileType group for the buffers
    -- that already exist, which starts the client now that the binary is
    -- there. Replaying the global FileType event instead would re-enter the
    -- prompt autocmd below.
    vim.lsp.enable('prismals')
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('prisma_lsp', { clear = true }),
    pattern = 'prisma',
    desc = 'offer to install the Prisma language server on first use',
    callback = function()
      if declined or installing then
        return
      end
      local reg = registry()
      if not reg or reg.is_installed(PACKAGE) then
        return
      end
      vim.ui.select({ ACCEPT, 'Not now' }, { prompt = 'The Prisma language server is not installed' }, function(choice)
        if choice == ACCEPT then
          installing = true
          install()
        else
          declined = true
          vim.notify(('prisma: %s not installed, :MasonInstall %s adds it later'):format(PACKAGE, PACKAGE))
        end
      end)
    end,
  })
end

return M
