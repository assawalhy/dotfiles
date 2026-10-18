-- Non-text files (office, archives, audio, fonts, binaries) open with a
-- `file-preview --text` preview in the buffer, plus a prompt offering xdg-open
-- (through the real application) or a normal reload. Known extensions are
-- intercepted before the read (BufReadCmd); anything else whose first 8 KiB
-- contain a NUL byte gets the same treatment after loading (BufReadPost).
-- Images, pdf and video are excluded: snacks.image previews those as floating
-- windows (see plugins/images.lua).
--
-- "Keep in Neovim" reloads normally by removing this group's BufReadCmd for
-- the reload and registering it again afterwards. To bypass the prompt for a
-- single file: `:noautocmd edit ++bin <file>`.

local group = vim.api.nvim_create_augroup('open_nontext', { clear = true })

local image_exts = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  webp = true,
  bmp = true,
  tiff = true,
  tif = true,
  avif = true,
  heic = true,
  ico = true,
  svg = true,
}

local nontext_exts = {
  -- documents
  ps = true,
  eps = true,
  epub = true,
  mobi = true,
  doc = true,
  docx = true,
  xls = true,
  xlsx = true,
  ppt = true,
  pptx = true,
  odt = true,
  ods = true,
  odp = true,
  -- audio
  mp3 = true,
  wav = true,
  flac = true,
  ogg = true,
  oga = true,
  opus = true,
  m4a = true,
  aac = true,
  wma = true,
  -- archives and packages
  zip = true,
  tar = true,
  gz = true,
  tgz = true,
  bz2 = true,
  xz = true,
  zst = true,
  ['7z'] = true,
  rar = true,
  jar = true,
  war = true,
  deb = true,
  rpm = true,
  apk = true,
  -- disk images and executables
  iso = true,
  img = true,
  dmg = true,
  exe = true,
  dll = true,
  so = true,
  dylib = true,
  bin = true,
  appimage = true,
  -- databases and objects
  db = true,
  sqlite = true,
  sqlite3 = true,
  class = true,
  o = true,
  a = true,
  wasm = true,
  -- fonts
  ttf = true,
  otf = true,
  woff = true,
  woff2 = true,
}

local register -- forward declaration: keep_nvim re-registers after a reload

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

local function open_external(buf, file)
  local name = vim.fn.fnamemodify(file, ':t')
  local system, err = vim.ui.open(file)
  if not system then
    notify(('xdg-open failed for %s: %s'):format(name, err or 'unknown error'), vim.log.levels.ERROR)
    return
  end
  notify(('Opened %s with xdg-open'):format(name))
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end)
end

local function keep_nvim(buf, file)
  vim.api.nvim_clear_autocmds { group = group, event = 'BufReadCmd' }
  vim.bo[buf].buftype = ''
  vim.bo[buf].modifiable = true
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd 'silent! edit!'
  end)
  register()
  if not ok then
    notify(('Could not load %s: %s'):format(file, err), vim.log.levels.ERROR)
  end
end

-- Fill the buffer with `file-preview --text` output: extracted office text, an
-- archive listing, media metadata or the typed placeholder. The buffer is
-- scratch (nofile, no swap, wiped when left) so the real file is never written.
local function preview_into(buf, file, done)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  if vim.fn.executable 'file-preview' ~= 1 then
    done()
    return
  end
  vim.system({ 'file-preview', '--text', file }, { text = true }, function(res)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      local out = (res.stdout or ''):gsub('\n+$', '')
      local lines = vim.split(out, '\n', { plain = true })
      if out == '' then
        lines = { ('[file-preview produced no output for %s]'):format(vim.fn.fnamemodify(file, ':t')) }
      end
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].modifiable = false
      vim.bo[buf].modified = false
      done()
    end)
  end)
end

local function ask(buf, file, on_keep)
  local name = vim.fn.fnamemodify(file, ':t')
  preview_into(buf, file, function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.ui.select({ 'Open externally (xdg-open)', 'Keep in Neovim' }, {
      prompt = ('%s is not a text file'):format(name),
    }, function(choice)
      if choice == 'Open externally (xdg-open)' then
        open_external(buf, file)
      elseif choice == 'Keep in Neovim' then
        on_keep()
      else
        -- Cancelled: the preview stays, read-only, so nothing can overwrite
        -- the file through this buffer.
        if vim.api.nvim_buf_is_valid(buf) then
          vim.bo[buf].modifiable = false
        end
        notify(('%s: preview only'):format(name))
      end
    end)
  end)
end

local function patterns()
  local out = {}
  for ext in pairs(nontext_exts) do
    out[#out + 1] = '*.' .. ext
    local upper = ext:upper()
    if upper ~= ext then
      out[#out + 1] = '*.' .. upper
    end
  end
  return out
end

register = function()
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    pattern = patterns(),
    callback = function(args)
      local buf = args.buf
      local file = vim.fn.fnamemodify(args.file or '', ':p')
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        ask(buf, file, function()
          keep_nvim(buf, file)
        end)
      end)
    end,
  })
end

-- Fallback for unlisted binaries: a NUL byte in the first 8 KiB means the
-- file is not text (the same heuristic file(1) and git use).
vim.api.nvim_create_autocmd('BufReadPost', {
  group = group,
  callback = function(args)
    local buf = args.buf
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return end
    local file = vim.api.nvim_buf_get_name(buf)
    if file == '' or vim.fn.filereadable(file) ~= 1 then return end
    if vim.b[buf].large_file or vim.bo[buf].filetype == 'image' then return end
    local ext = vim.fn.fnamemodify(file, ':e'):lower()
    if image_exts[ext] or nontext_exts[ext] then return end

    local fd = vim.uv.fs_open(file, 'r', 438)
    if not fd then return end
    local data = vim.uv.fs_read(fd, 8192, 0)
    vim.uv.fs_close(fd)
    if type(data) ~= 'string' or not data:find('\0', 1, true) then return end

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      ask(buf, file, function() end)
    end)
  end,
})

register()
