local jdtls = require('jdtls')

local mason_jdtls = vim.fn.stdpath('data') .. '/mason/packages/jdtls/bin/jdtls'
local jdtls_bin = vim.fn.filereadable(mason_jdtls) == 1 and mason_jdtls or vim.fn.exepath('jdtls')
if jdtls_bin == '' then
  vim.notify('jdtls not found — run :MasonInstall jdtls', vim.log.levels.WARN)
  return
end

local root = vim.fs.root(0, { '.git', 'mvnw', 'pom.xml', 'gradlew', 'settings.gradle', 'settings.gradle.kts', 'build.gradle', 'build.gradle.kts' })
if not root then return end

local workspace = vim.fn.stdpath('cache') .. '/jdtls/workspace/' .. vim.fn.fnamemodify(root, ':t')
vim.fn.mkdir(workspace, 'p')

local function get_capabilities()
  local ok, blink = pcall(require, 'blink.cmp')
  if ok then return blink.get_lsp_capabilities() end
  local caps = vim.lsp.protocol.make_client_capabilities()
  caps.textDocument.completion.completionItem.snippetSupport = true
  return caps
end
local caps = get_capabilities()

local config = {
  cmd = { jdtls_bin, '-data', workspace },
  root_dir = root,
  capabilities = caps,
  settings = {
    java = {
      configuration = {
        runtimes = {
          { name = 'JavaSE-21', path = '/usr/lib/jvm/default-java', default = true },
        },
        updateBuildConfiguration = 'automatic',
        maven = { downloadSources = true },
        gradle = { nestedProjects = true, isAutoRefreshEnabled = true },
      },
      eclipse = { downloadSources = true },
      jdt = {
        ls = {
          vmargs = '-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Dsun.zip.disableMemoryMapping=true -Xmx1G -Xms100m' .. (os.getenv('LOMBOK_JAR') and (' -javaagent:' .. os.getenv('LOMBOK_JAR')) or ''),
        },
      },
    },
  },
  on_attach = function(client, bufnr)
    jdtls.setup_dap({ hotcodereplace = 'auto' })
    vim.keymap.set('n', '<leader>oi', function() jdtls.organize_imports() end, { buffer = bufnr, desc = 'Java: organize imports' })
    vim.keymap.set('n', '<leader>ot', function() jdtls.test_class() end, { buffer = bufnr, desc = 'Java: run test class' })
    vim.keymap.set('n', '<leader>om', function() jdtls.test_nearest_method() end, { buffer = bufnr, desc = 'Java: run nearest test' })
  end,
}

jdtls.start_or_attach(config)
