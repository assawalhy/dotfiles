-- Java and Kotlin language servers.
--
-- jdtls is started as `java` itself rather than through the `jdtls` wrapper
-- script: the wrapper would be nvim's immediate child and the JVM a
-- grandchild, which nvim never kills, so every crash left a JVM behind
-- (nvim#29475). Direct launch makes the JVM the child, bounds its heap, and
-- puts every project in its own workspace.
local memory = require 'config.memory'
local gate = require 'config.lsp_gate'

local mason = vim.fn.stdpath 'data' .. '/mason/packages'
local jdtls_pkg = mason .. '/jdtls'

local M = {}

--- The JVM to launch. mise owns the JDK on Linux (common/.config/mise/config.toml),
--- but nvim is not always started from a shell that ran `mise activate`.
--- Resolution order mirrors `_jdk_home` in ~/.config/shell/os.sh: ask mise
--- first, then whatever `java` is on PATH (brew on macOS).
---@return string|nil exe, string|nil home JDK home, nil when PATH's `java` is not under `<home>/bin`
local function jvm()
  if vim.fn.exepath 'mise' ~= '' then
    local out = vim.fn.system { 'mise', 'where', 'java' }
    if vim.v.shell_error == 0 then
      local home = vim.trim((vim.split(out, '\n', { plain = true })[1] or ''))
      if home ~= '' and vim.uv.fs_stat(home .. '/bin/java') then
        return home .. '/bin/java', home
      end
    end
  end

  local exe = vim.fn.exepath 'java'
  if exe ~= '' then
    local home = vim.fs.dirname(vim.fs.dirname(exe)) -- <home>/bin/java
    if vim.uv.fs_stat(home .. '/bin/java') then
      return exe, home
    end
    return exe, nil -- e.g. a mise shim on PATH: not a JDK home
  end
  return nil, nil
end

--- One workspace per project, under the cache dir. The short hash keeps two
--- checkouts that share a directory name (two `api/` repos) from sharing a
--- workspace.
---@param root_dir string|nil
---@return string
local function workspace_dir(root_dir)
  local base = vim.fn.stdpath 'cache' .. '/jdtls'
  if not root_dir or root_dir == '' then
    return base .. '/no-root'
  end
  return ('%s/%s-%s'):format(base, vim.fs.basename(root_dir), vim.fn.sha256(root_dir):sub(1, 8))
end

---@param dispatchers vim.lsp.rpc.Dispatchers
---@param config vim.lsp.ClientConfig
local function jdtls_cmd(dispatchers, config)
  local java = jvm()
  local launcher = vim.fn.glob(jdtls_pkg .. '/plugins/org.eclipse.equinox.launcher_*.jar')
  local conf_dir = jdtls_pkg .. (vim.fn.has 'mac' == 1 and '/config_mac' or '/config_linux')

  if java == nil or launcher == '' or vim.fn.isdirectory(conf_dir) == 0 then
    error 'jdtls is not installed yet - run :MasonInstall jdtls and restart'
  end

  local args = {
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=false',
    '-Dlog.level=NONE',
    '-Xmx768m',
    '-Xms256m',
    '--add-modules=ALL-SYSTEM',
    '--add-opens=java.base/java.util=ALL-UNNAMED',
    '--add-opens=java.base/java.lang=ALL-UNNAMED',
  }

  -- mason downloads lombok.jar into the jdtls package, so Lombok is wired up
  -- out of the box; LOMBOK_JAR overrides it. A set-but-missing LOMBOK_JAR is
  -- an error the user should see rather than a silent fallback; the mason
  -- default is only added when the file is actually there (fresh install).
  local lombok = vim.env.LOMBOK_JAR
  if lombok and lombok ~= '' then
    if not vim.uv.fs_stat(lombok) then
      error(('LOMBOK_JAR points at a missing file: %s'):format(lombok))
    end
    args[#args + 1] = '-javaagent:' .. lombok
  elseif vim.uv.fs_stat(jdtls_pkg .. '/lombok.jar') then
    args[#args + 1] = '-javaagent:' .. jdtls_pkg .. '/lombok.jar'
  end

  vim.list_extend(args, { '-jar', launcher, '-configuration', conf_dir, '-data', workspace_dir(config.root_dir) })

  -- `vim.lsp.rpc.start` takes the whole command as one list: (cmd, dispatchers, params).
  local cmd = { java }
  vim.list_extend(cmd, args)

  return vim.lsp.rpc.start(cmd, dispatchers, {
    cwd = config.cmd_cwd,
    env = config.cmd_env,
    detached = config.detached,
  })
end

--- jdtls needs a JVM; the rest of the guard is shared with kotlin.
---@param bufnr integer
---@return string|nil
local function jdtls_blocked(bufnr)
  if vim.b[bufnr].large_file then
    return 'buffer over the size limit'
  end
  return memory.block 'jdtls'
end

---@param bufnr integer
---@return string|nil
local function kotlin_blocked(bufnr)
  if vim.b[bufnr].large_file then
    return 'buffer over the size limit'
  end
  return memory.block 'kotlin_language_server'
end

function M.setup()
  vim.lsp.config('jdtls', {
    cmd = jdtls_cmd,
    filetypes = { 'java' },
    init_options = {},
  })
  gate.gate('jdtls', jdtls_blocked)

  -- The Gradle-generated shim dies when neither JAVA_HOME nor a `java` on
  -- PATH exists - exactly the launcher-started-nvim case the jdtls fallback
  -- above handles - so hand it the JDK explicitly. It ends in `exec`, so the
  -- JVM stays nvim's direct child. _JAVA_OPTIONS is read by the JVM itself,
  -- which is what caps the heap without touching the shim's own opts.
  local kotlin_env = { _JAVA_OPTIONS = '-Xmx768m -Xms256m' }
  local _, home = jvm()
  if home then
    kotlin_env.JAVA_HOME = home
  end

  vim.lsp.config('kotlin_language_server', {
    cmd_env = kotlin_env,
    init_options = { storagePath = vim.fn.stdpath 'cache' .. '/kotlin-language-server' },
    -- The shipped spec's markers are build files only, so a bare `.kt` file
    -- - the competitive-programming case this config exists for - never
    -- resolves a root and the server never starts. Walk build files first,
    -- then `.git` as a last resort, mirroring the jdtls spec.
    root_dir = function(bufnr, on_dir)
      local root = vim.fs.root(bufnr, {
        'settings.gradle',
        'settings.gradle.kts',
        'build.xml',
        'pom.xml',
        'build.gradle',
        'build.gradle.kts',
      }) or vim.fs.root(bufnr, { '.git' })
      if root then
        on_dir(root)
      end
    end,
  })
  gate.gate('kotlin_language_server', kotlin_blocked)

  memory.setup()
end

return M
