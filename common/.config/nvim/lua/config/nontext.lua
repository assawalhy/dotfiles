-- Non-text files (pdf, video, archives, binaries) open with xdg-open instead
-- of loading binary data into a buffer. Known extensions are intercepted
-- before the read (BufReadCmd); anything else whose first 8 KiB contain a NUL
-- byte gets the same prompt after loading (BufReadPost). Images are excluded:
-- snacks.image previews those (see plugins/images.lua).
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
  pdf = true,
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
  -- video
  mp4 = true,
  mkv = true,
  webm = true,
  avi = true,
  mov = true,
  m4v = true,
  wmv = true,
  flv = true,
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
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd 'silent! edit!'
  end)
  register()
  if not ok then
    notify(('Could not load %s: %s'):format(file, err), vim.log.levels.ERROR)
  end
end

local function ask(buf, file, on_keep)
  local name = vim.fn.fnamemodify(file, ':t')
  vim.ui.select({ 'Open externally (xdg-open)', 'Keep in Neovim' }, {
    prompt = ('%s is not a text file'):format(name),
  }, function(choice)
    if choice == 'Open externally (xdg-open)' then
      open_external(buf, file)
    elseif choice == 'Keep in Neovim' then
      on_keep()
    else
      -- Cancelled: leave an empty, non-writable placeholder rather than a
      -- buffer that could silently overwrite the file.
      if vim.api.nvim_buf_is_valid(buf) then
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].modifiable = false
      end
      notify(('%s not opened'):format(name))
    end
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
