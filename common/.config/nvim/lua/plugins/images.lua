return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    -- Only the image module is configured; every other snacks module stays
    -- off. WezTerm implements the kitty graphics protocol but not its unicode
    -- placeholders, so snacks shows images in a floating window (opening an
    -- image file previews it) instead of inline. Formats are limited to
    -- raster images and svg: pdf/video/audio go through config/nontext.lua.
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
