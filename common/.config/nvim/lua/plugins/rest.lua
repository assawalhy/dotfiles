-- REST client for .http files (`:Rest run`).
--
-- NOTE: `build = false` skips lazy's luarocks build for this plugin. The
-- rockspec deps need `luarocks-build-treesitter-parser`, which requires a
-- newer luarocks than Ubuntu ships (3.8). Instead the deps are provided by:
--   nvim-nio, fidget.nvim  -> regular plugins below
--   mimetypes, xml2lua     -> pure-lua, vendored into stdpath('data')/site/lua
--                             (already on the runtimepath)
return {
  {
    'rest-nvim/rest.nvim',
    build = false,
    ft = 'http',
    cmd = 'Rest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      { 'j-hui/fidget.nvim', opts = {} },
    },
  },
}
