# Neovim Config — Shortcuts

Leader key: `<space>`

## Keymaps

| Key          | Mode         | Description                          | Plugin                 |
| ---          | ---          | ---                                  | ---                    |
| `j`          | n            | Move down (soft wrap aware)          | —                      |
| `k`          | n            | Move up (soft wrap aware)            | —                      |
| `gc`         | n, x         | Comment toggle                       | Comment.nvim           |
| `ga`         | n, x         | EasyAlign                            | vim-easy-align         |
| `gsw`        | x            | Sort selected lines by line width    | —                      |
| `s`          | n, o, x      | Flash jump                           | flash.nvim             |
| `S`          | n, o         | Flash treesitter                     | flash.nvim             |
| `r`          | o            | Remote Flash                         | flash.nvim             |
| `R`          | o, x         | Treesitter search                    | flash.nvim             |
| `f`          | —            | Sneak forward                        | vim-sneak              |
| `F`          | —            | Sneak backward                       | vim-sneak              |
| `t`          | —            | Sneak to char (before)               | vim-sneak              |
| `T`          | —            | Sneak to char (before, rev)          | vim-sneak              |
| `K`          | n            | Peek fold / LSP hover                | nvim-ufo               |
| `Y`          | n (neo-tree) | Copy path selector                   | neo-tree               |
| `;y`         | x            | Copy selection to sys clipboard      | —                      |
| `;wc`        | n            | Copy current buffer to sys clipboard | —                      |
| `;d`         | n, v         | Delete without yanking               | —                      |
| `;c`         | n, v         | Change without yanking               | —                      |
| `;D`         | n, v         | Delete to EOL without yanking        | —                      |
| `;p`         | v            | Paste without yanking                | —                      |
| `;aa`        | n            | Swap next parameter                  | treesitter-textobjects |
| `;A`         | n            | Swap previous parameter              | treesitter-textobjects |
| `;s`         | n            | TreeSJ split                         | treesj                 |
| `;j`         | n            | TreeSJ join                          | treesj                 |
| `;m`         | n            | TreeSJ toggle                        | treesj                 |
| `;M`         | n            | TreeSJ toggle recursively            | treesj                 |
| `]m`         | n, x, o      | Next function start                  | treesitter-textobjects |
| `]M`         | n, x, o      | Next function end                    | treesitter-textobjects |
| `]]`         | n, x, o      | Next class start                     | treesitter-textobjects |
| `][`         | n, x, o      | Next class end                       | treesitter-textobjects |
| `[m`         | n, x, o      | Previous function start              | treesitter-textobjects |
| `[M`         | n, x, o      | Previous function end                | treesitter-textobjects |
| `[[`         | n, x, o      | Previous class start                 | treesitter-textobjects |
| `[]`         | n, x, o      | Previous class end                   | treesitter-textobjects |
| `zR`         | n            | Open all folds                       | nvim-ufo               |
| `zM`         | n            | Close all folds                      | nvim-ufo               |
| `zr`         | n            | Open folds except kinds              | nvim-ufo               |
| `<C-l>`      | n            | Move to right window                 | —                      |
| `<C-h>`      | n            | Move to left window                  | —                      |
| `<C-j>`      | n            | Move to window below                 | —                      |
| `<C-k>`      | n            | Move to window above                 | —                      |
| `<C-_>`      | n, x         | Comment toggle (terminal)            | Comment.nvim           |
| `<C-s>`      | c            | Toggle Flash search                  | flash.nvim             |
| `<C-w><C-q>` | n            | Delete buffer                        | —                      |
| `<C-w>q`     | n            | Delete buffer                        | —                      |
| `<A-j>`      | n, v         | Move line/block down                 | move.nvim              |
| `<A-k>`      | n, v         | Move line/block up                   | move.nvim              |
| `<A-l>`      | n, v         | Move right                           | move.nvim              |
| `<A-h>`      | n, v         | Move left                            | move.nvim              |
| `<F5>`       | n, v         | DAP continue                         | nvim-dap               |
| `<F6>`       | n, v         | DAP close session                    | nvim-dap               |
| `<F7>`       | n, v         | DAP toggle UI                        | nvim-dap               |
| `<F10>`      | n, v         | DAP step over                        | nvim-dap               |
| `<F11>`      | n, v         | DAP step into                        | nvim-dap               |
| `<F23>`      | n, v         | DAP step out (S-F11)                 | nvim-dap               |
| `<tab>n`     | n            | New tab                              | bufferline             |
| `<tab>l`     | n            | Buffer next                          | bufferline             |
| `<tab>h`     | n            | Buffer prev                          | bufferline             |
| `<tab>x`     | n            | Close other buffers                  | bufferline             |
| `<tab>p`     | n            | Buffer pick                          | bufferline             |
| `<tab>P`     | n            | Toggle pin                           | bufferline             |

## Leader (`<space>`) Shortcuts

| Key           | Mode | Description                    | Plugin       |
| ---           | ---  | ---                            | ---          |
| `<leader>/`   | n    | Fuzzy search in current buffer | telescope    |
| `<leader>e`   | n    | Toggle NeoTree                 | neo-tree     |
| `<leader>O`   | n    | Find recently opened files     | telescope    |
| `<leader>o`   | n    | Find existing buffers          | telescope    |
| `<leader>p`   | n    | Find files                     | telescope    |
| `<leader>sh`  | n    | Search help tags               | telescope    |
| `<leader>sw`  | n, v | Search current word            | telescope    |
| `<leader>sg`  | n    | Live grep                      | telescope    |
| `<leader>sd`  | n    | Search diagnostics             | telescope    |
| `<leader>t`   | n    | Open terminal in file dir      | —            |
| `<leader>u`   | n    | Toggle undotree                | undotree     |
| `<leader>db`  | n, v | Toggle breakpoint              | nvim-dap     |
| `<leader>dB`  | n, v | Set conditional breakpoint     | nvim-dap     |
| `<leader>dl`  | n, v | Set log point                  | nvim-dap     |
| `<leader>dh`  | n, v | Run to cursor                  | nvim-dap     |
| `<leader>dc`  | n, v | Telescope dap commands         | nvim-dap     |
| `<leader>du`  | n, v | Toggle dap UI                  | nvim-dap     |
| `<leader>de`  | n, v | Evaluate under cursor          | nvim-dap     |
| `<leader>dE`  | n, v | Evaluate expression            | nvim-dap     |
| `<leader>xx`  | n    | Buffer diagnostics (Trouble)   | trouble.nvim |
| `<leader>xX`  | n    | All diagnostics (Trouble)      | trouble.nvim |
| `<leader>xs`  | n    | Symbols (Trouble)              | trouble.nvim |
| `<leader>xL`  | n    | Location list (Trouble)        | trouble.nvim |
| `<leader>xQ`  | n    | Quickfix list (Trouble)        | trouble.nvim |
| `<leader>gs`  | n    | Stage hunk                     | vgit         |
| `<leader>gr`  | n    | Reset hunk                     | vgit         |
| `<leader>gp`  | n    | Preview hunk                   | vgit         |
| `<leader>gb`  | n    | Blame preview                  | vgit         |
| `<leader>gf`  | n    | Diff preview                   | vgit         |
| `<leader>gh`  | n    | Buffer history preview         | vgit         |
| `<leader>gu`  | n    | Reset buffer                   | vgit         |
| `<leader>gg`  | n    | Gutter blame preview           | vgit         |
| `<leader>glu` | n    | Hunks preview                  | vgit         |
| `<leader>gls` | n    | Staged hunks preview           | vgit         |
| `<leader>gd`  | n    | Project diff preview           | vgit         |
| `<leader>gq`  | n    | Project hunks to quickfix      | vgit         |
| `<leader>gx`  | n    | Toggle diff preference         | vgit         |

## CompetiTest (`cp` prefix)

| Key   | Mode | Description              | Plugin           |
| ---   | ---  | ---                      | ---              |
| `cpd` | n    | Compile cpp with -g flag | competitest.nvim |
| `cpt` | n    | Receive test cases       | competitest.nvim |
| `cpp` | n    | Receive a problem        | competitest.nvim |
| `cpc` | n    | Receive a contest        | competitest.nvim |
| `cpr` | n    | Run current file         | competitest.nvim |
| `cpR` | n    | Run without compiling    | competitest.nvim |
| `cpe` | n    | Edit test cases          | competitest.nvim |
| `cpa` | n    | Add new test case        | competitest.nvim |

