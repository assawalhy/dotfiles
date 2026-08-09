return {
  'mfussenegger/nvim-dap',
  event = 'VeryLazy',
  dependencies = {
    -- Creates a beautiful debugger UI
    'nvim-telescope/telescope-dap.nvim',
    {
      'rcarriga/nvim-dap-ui',
      dependencies = { 'nvim-neotest/nvim-nio' },
      opts = {},
    },
    {
      'theHamsta/nvim-dap-virtual-text',
      dependencies = { 'nvim-treesitter/nvim-treesitter' },
      opts = {},
    },

    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    -- 'leoluz/nvim-dap-go',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('telescope').load_extension 'dap'

    vim.fn.sign_define('DapBreakpoint', { text = '⬤', texthl = 'ErrorMsg', linehl = '', numhl = 'ErrorMsg' })
    vim.fn.sign_define('DapBreakpointCondition', { text = '⬤', texthl = 'ErrorMsg', linehl = '', numhl = 'SpellBad' })

    require('mason-nvim-dap').setup {
      automatic_setup = true,

      handlers = {
        -- NOTE: you should make sure that gdb is installed
        cppdbg = function(config)
          config.configurations = {
            {
              name = 'Compile and launch file',
              type = 'cppdbg',
              request = 'launch',
              program = function()
                local file = vim.fn.expand('%:p')
                local exefile = vim.fn.expand('%:p:r')
                print("compiling: " .. file)
                os.execute(string.format([[g++ -g -DSAWALHY "%s" -o "%s"]], file, exefile))
                return exefile
              end,
              cwd = '${fileDirname}',
              stopAtEntry = true,
              setupCommands = {
                {
                  text = '-enable-pretty-printing',
                  description = 'enable pretty printing',
                  ignoreFailures = false,
                },
              },
            },
            {
              name = 'Launch file',
              type = 'cppdbg',
              request = 'launch',
              program = function()
                local exefile = vim.fn.expand '%:p:r'
                if not vim.fn.filereadable(exefile) then
                  exefile = vim.fn.getcwd() .. '/'
                end
                return vim.fn.input('Path to executable: ', exefile, 'file')
              end,
              cwd = '${fileDirname}',
              stopAtEntry = true,
              setupCommands = {
                {
                  text = '-enable-pretty-printing',
                  description = 'enable pretty printing',
                  ignoreFailures = false,
                },
              },
            },
          }

          require('mason-nvim-dap').default_setup(config) -- don't forget this!
        end,
      },
    }

    local nvmap = function(keys, func, desc)
      if desc then
        desc = 'Dap: ' .. desc
      end
      vim.keymap.set({ 'n', 'v' }, keys, func, { desc = desc })
    end

    -- Basic debugging keymaps, feel free to change to your liking!
    nvmap('<F5>', dap.continue, 'Start/Continue')
    nvmap('<F6>', dap.close, 'Close session')
    -- Toggle to see last session result. Without this,
    -- you can't see session output in case of unhandled exception.
    nvmap('<F7>', dapui.toggle, 'See last session result.')
    nvmap('<F10>', dap.step_over, 'Step over')
    nvmap('<F11>', dap.step_into, 'Step into')
    nvmap('<F23>', dap.step_out, 'Step out') -- shift + f11

    nvmap('<leader>db', dap.toggle_breakpoint, 'toggle Breakpoint')
    nvmap('<leader>dB', function()
      dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
    end, 'Set conditional breakpoint')
    nvmap('<leader>dl', function()
      require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: '))
    end, 'Set log point')

    nvmap('<leader>dh', dap.run_to_cursor, 'come (h)ere')
    nvmap('<leader>dc', ':Telescope dap commands<CR>', 'telescope dap commands')
    nvmap('<leader>du', dapui.toggle, 'toggle dap UI')
    nvmap('<leader>de', dapui.eval, 'evaluate under cursor')
    nvmap('<leader>dE', function()
      dapui.eval(vim.fn.input('Expression: '))
    end, 'input an expression to evaluate')

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Install golang specific config
    -- require('dap-go').setup()
  end,
}
