-- Java and Kotlin language servers.
--
-- jdtls is started as `java` itself rather than through the `jdtls` wrapper
-- script: the wrapper would be nvim's immediate child and the JVM a
-- grandchild, which nvim never kills, so every crash left a JVM behind
-- (nvim#29475). Direct launch makes the JVM the child, bounds its heap, and
-- puts every project in its own workspace.
local memory = require 'config.memory'
local gate = require 'config.lsp_gate'
local lsp_sources = require 'config.lsp_sources'

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

---@param server string
---@param bufnr integer
---@return string|nil
local function kotlin_blocked(server, bufnr)
  if vim.b[bufnr].large_file then
    return 'buffer over the size limit'
  end
  return memory.block(server)
end

--- The shipped Kotlin specs only list build files, so a bare `.kt` file -
--- the competitive-programming case this config exists for - never resolves
--- a root and the server never starts. Walk build files first, then `.git`
--- as a last resort, mirroring the jdtls spec.
---@param bufnr integer
---@param on_dir fun(dir: string)
local function kotlin_root(bufnr, on_dir)
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
end

--- The official JetBrains Kotlin LSP (setup/steps/67-kotlin-lsp.sh) when it
--- is installed, the mason kotlin_language_server otherwise. kls bundles
--- Kotlin 2.1.0 and cannot read Kotlin 2.3 project metadata, so on modern
--- projects `::class.java` stays unresolved there (fwcd#457) - kotlin-lsp
--- wins whenever present. kls falls back on machines without the step
--- (macOS, non-x86_64), where the settings below still clear its false
--- "cannot inline" diagnostics.
---@return string name, vim.lsp.Config cfg
local function kotlin_server()
  local data = vim.env.XDG_DATA_HOME
  if not data or data == '' then
    data = vim.fn.expand '~/.local/share'
  end
  local intellij = data .. '/kotlin-lsp/current/bin/intellij-server'
  if vim.uv.fs_stat(intellij) then
    return 'kotlin_lsp', { cmd = { intellij, '--stdio' }, root_dir = kotlin_root }
  end

  -- The Gradle-generated shim dies when neither JAVA_HOME nor a `java` on
  -- PATH exists - exactly the launcher-started-nvim case the jdtls fallback
  -- above handles - so hand it the JDK explicitly. It ends in `exec`, so the
  -- JVM stays nvim's direct child. _JAVA_OPTIONS is read by the JVM itself,
  -- which is what caps the heap without touching the shim's own opts.
  local env = { _JAVA_OPTIONS = '-Xmx768m -Xms256m' }
  local _, home = jvm()
  if home then
    env.JAVA_HOME = home
  end

  return 'kotlin_language_server', {
    cmd_env = env,
    init_options = { storagePath = vim.fn.stdpath 'cache' .. '/kotlin-language-server' },
    -- Sent via workspace/didChangeConfiguration (nvim ships config.settings
    -- that way): the bundled compiler otherwise analyzes at jvmTarget 1.8
    -- and flags every dependency built for 9+ with false "cannot inline".
    settings = { kotlin = { compiler = { jvm = { target = '21' } } } },
    root_dir = kotlin_root,
  }
end

function M.setup()
  vim.lsp.config('jdtls', {
    cmd = jdtls_cmd,
    filetypes = { 'java' },
    -- classFileContentsSupport lets jdtls answer `jdt://` locations with the
    -- class source; config/lsp_sources.lua reads them back through the
    -- `java/classFileContents` request.
    init_options = { extendedClientCapabilities = { classFileContentsSupport = true } },
  })
  gate.gate('jdtls', jdtls_blocked)

  local kname, kcfg = kotlin_server()
  vim.lsp.config(kname, kcfg)
  gate.gate(kname, function(bufnr)
    return kotlin_blocked(kname, bufnr)
  end)

  lsp_sources.setup()
  memory.setup()
end

return M
