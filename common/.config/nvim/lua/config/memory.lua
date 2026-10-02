-- RAM budget for JVM language servers.
--
-- jdtls and the Kotlin servers (kotlin_lsp, or kotlin_language_server as
-- its fallback) are 0.7-1.5 GiB processes, so the decision to start one
-- and the decision to keep one live here instead of in each server's
-- config. Servers are gated through config.lsp_gate, which is also what
-- keeps oversized buffers LSP-free.
local M = {}

local START_BYTES = 2 * 1024 ^ 3 -- need this much to spawn a JVM
local STOP_BYTES = 1536 * 1024 ^ 2 -- this little and running ones are stopped
-- kotlin_lsp is the IntelliJ backend: a larger heap ceiling plus a Gradle
-- import daemon, so dips below STOP_BYTES are routine on a busy box and
-- stopping there killed the server mid-session on a 16 GiB machine.
local STOP_FLOORS = { kotlin_lsp = 768 * 1024 ^ 2 }
local WATCH_INTERVAL_MS = 20000

local watched = { jdtls = true, kotlin_language_server = true, kotlin_lsp = true }
local warned = {}
local timer

--- RAM that can actually be handed out. On Linux `vim.uv.get_free_memory()`
--- is MemFree, which ignores reclaimable page cache: this box reads 2.7 GiB
--- free against 16.4 GiB available, so gating on it would refuse to start any
--- JVM on a healthy machine. MemAvailable is the number that matters, and
--- macOS has no /proc, where uv already accounts for reclaimable pages.
---@return integer
function M.free()
  local f = io.open('/proc/meminfo', 'r')
  if f then
    local text = f:read '*a' or ''
    f:close()
    local kb = text:match 'MemAvailable:%s+(%d+)'
    if kb then
      return tonumber(kb) * 1024
    end
  end
  return vim.uv.get_free_memory()
end

local function notify(msg)
  vim.notify('memory guard: ' .. msg, vim.log.levels.WARN, { title = 'memory guard' })
end

--- Blocker for |lsp_gate|: the reason `name` must not start, nil when it may.
---@param name string
---@return string|nil
function M.block(name)
  if M.free() >= START_BYTES then
    return nil
  end
  if not warned[name] then
    warned[name] = true
    notify(('%s not started: %.1f GiB available, %.0f GiB required'):format(name, M.free() / 1024 ^ 3, START_BYTES / 1024 ^ 3))
  end
  return 'not enough free memory'
end

---@param reason string
---@param silent boolean|nil
---@param floors table<string, integer>|nil per-server RAM floors; nil stops every watched client
local function stop_watched(reason, silent, floors)
  local free = M.free()
  local stopped = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    local limit = floors and (floors[client.name] or STOP_BYTES) or math.huge
    if watched[client.name] and free < limit then
      stopped[#stopped + 1] = client.name
      client:stop(true)
    end
  end
  if #stopped > 0 and not silent then
    notify(('%s, stopped %s'):format(reason, table.concat(stopped, ', ')))
  end
  return #stopped
end

local function start_watch()
  if timer then
    return
  end
  timer = vim.uv.new_timer()
  timer:start(WATCH_INTERVAL_MS, WATCH_INTERVAL_MS, vim.schedule_wrap(function()
    stop_watched('low RAM', nil, STOP_FLOORS)
  end))
end

-- A JVM started by the `jdtls` wrapper (or one whose launcher script did not
-- exec) survives a crashed nvim: nothing ever reaps it, because nvim only
-- kills its own immediate children. The next nvim sweeps the leftovers.
-- Who adopts the orphan depends on the session: ssh/tty reparent straight to
-- pid 1, graphical sessions to `systemd --user`, which is a subreaper - so
-- match the adopter's comm as well as pid 1. A live server is never adopted:
-- its parent is a live nvim or launcher script.
local REAP_NEEDLES = {
  'mason/packages/jdtls/',
  'mason/packages/kotlin-language-server/',
  'kotlin-lsp/', -- official server; survives as jbr `java` under its install dir
}
local ADOPTERS = { systemd = true } -- both init and `systemd --user` report comm "systemd"

local function reap_orphans()
  vim.system({ 'ps', '-eo', 'pid=,ppid=,comm=,args=' }, { text = true }, vim.schedule_wrap(function(out)
    if out.code ~= 0 then
      return
    end
    local rows, comm_of = {}, {}
    for line in (out.stdout or ''):gmatch '[^\r\n]+' do
      local pid, ppid, comm, args = line:match '^%s*(%d+)%s+(%d+)%s+(%S+)%s+(.*)$'
      if pid then
        comm_of[pid] = comm
        rows[#rows + 1] = { pid = pid, ppid = ppid, args = args }
      end
    end

    local reap = {}
    for _, row in ipairs(rows) do
      local adopted = row.ppid == '1' or ADOPTERS[comm_of[row.ppid]] == true
      if adopted and tonumber(row.pid) ~= vim.fn.getpid() then
        for _, needle in ipairs(REAP_NEEDLES) do
          if row.args:find(needle, 1, true) then
            reap[#reap + 1] = { pid = tonumber(row.pid), args = row.args }
            break
          end
        end
      end
    end
    if #reap == 0 then
      return
    end
    local names = {}
    for _, proc in ipairs(reap) do
      names[#names + 1] = tostring(proc.pid)
      vim.uv.kill(proc.pid, 'sigterm')
    end
    notify(('reaped orphaned JVM servers (pid %s)'):format(table.concat(names, ', ')))
  end))
end

--- Wires the watchdog, the exit hook and the orphan sweep.
--- Called once, from config.java.
function M.setup()
  vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'Watch RAM while a JVM language server runs',
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and watched[client.name] then
        start_watch()
      end
    end,
  })

  vim.api.nvim_create_autocmd('ExitPre', {
    desc = 'Stop JVM language servers before nvim exits',
    callback = function()
      stop_watched('exiting', true)
    end,
  })

  reap_orphans()
end

return M
