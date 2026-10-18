return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    -- Only the image module is configured; every other snacks module stays
    -- off. WezTerm implements the kitty graphics protocol but not its unicode
    -- placeholders, so snacks shows images in a floating window (opening an
    -- image, pdf or video file previews it) instead of inline. Snacks converts
    -- a pdf page or a video frame through magick; its defaults already carry the
    -- magick args for both, and the pdf page defaults to the first one. Office
    -- files, archives, audio and binaries go through config/nontext.lua, which
    -- fills the buffer from `file-preview --text`.
    opts = {
      image = {
        formats = {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
          'tiff',
          'tif',
          'avif',
          'heic',
          'ico',
          'svg',
          'pdf',
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
          'm4v',
          'wmv',
          'flv',
        },
      },
    },
    keys = {
      {
        '<leader>ip',
        function()
          require('snacks').image.hover()
        end,
        desc = 'Preview image at cursor',
      },
    },
  },
}
