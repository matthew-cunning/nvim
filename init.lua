-- Neovim configuration.
-- Plugins are managed by lazy.nvim, one spec per file in lua/custom/plugins/.
-- This file holds options, keymaps, autocommands, commands and the plugin bootstrap.

-- <space> as leader. Must be set before plugins load.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- A Nerd Font is selected in the terminal; plugins check this before using icons.
vim.g.have_nerd_font = true

-- [[ Options ]] See `:help option-list`
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.showmode = false -- the statusline already shows the mode
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true -- case-insensitive search...
vim.opt.smartcase = true -- ...unless the pattern has capitals or \C
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250 -- faster CursorHold: diagnostics, gitsigns, document highlight
vim.opt.timeoutlen = 300 -- show the which-key popup sooner
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true -- show tabs, trailing spaces and non-breaking spaces
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand = 'split' -- live preview of :substitute
vim.opt.cursorline = true
-- Keep the cursor line vertically centred on every motion (typewriter mode).
-- Replaces per-motion `zz` mappings, which also leaked into Select mode.
vim.opt.scrolloff = 999

-- Sync the clipboard with the OS. Deferred because it can slow startup.
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- [[ Keymaps ]]
-- Clear search highlight
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
-- Leave terminal mode without the awkward default <C-\><C-n>
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
-- Move between windows with CTRL+hjkl
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Autocommands ]]
-- Briefly highlight yanked text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Terraform uses `#` comments
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'terraform',
  callback = function()
    vim.bo.commentstring = '# %s'
  end,
})

-- [[ Commands ]]
-- Copy the current file's absolute path to the system clipboard
local function copy_filename_to_clipboard()
  vim.fn.setreg('+', vim.fn.expand '%:p')
  print('Filename copied to clipboard: ' .. vim.fn.expand '%:p')
end
vim.api.nvim_create_user_command('CopyFilename', copy_filename_to_clipboard, {})

-- Remove all trailing whitespace in the buffer
vim.api.nvim_create_user_command('RemoveTrailingWhitespace', '%s/\\s\\+$//e', {})

-- [[ Plugins ]] See https://github.com/folke/lazy.nvim
-- Bootstrap lazy.nvim on first run
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- Load every spec in lua/custom/plugins/. `:Lazy` to inspect, update or restore.
require('lazy').setup({
  { import = 'custom.plugins' },
}, {
  ui = {
    -- Nerd Font icons when available, otherwise unicode fallbacks
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- [[ Appearance ]] (after plugins, so the colorscheme is available)
-- Highlight trailing whitespace
vim.cmd 'match errorMsg /\\s\\+$/'
-- gruvbox is configured in lua/custom/plugins/gruvbox.lua
vim.o.background = 'dark'
vim.cmd [[colorscheme gruvbox]]

-- [[ go-split: tree-sitter-gosplit + go-split-lsp ]]
-- Parser: ~/.local/share/nvim/site/parser/gosplit.so, queries: ~/.config/nvim/queries/gosplit
-- (see tools/tree-sitter-gosplit/editors/nvim.lua step 0). Server: `task install` in tools/go-split-lsp.

-- 1. Filetype. *.gosplit.yaml -> yaml.gosplit; the yaml ftplugin/indent still load.
vim.filetype.add {
  pattern = {
    ['.*%.gosplit%.yaml'] = 'yaml.gosplit',
    -- Optional, local choice: the provider's current file name as well, so the
    -- real specs/ tree gets diagnostics today. spec.yaml is deliberately not matched.
    ['.*/specs/resources/[^/]+/config%.yaml'] = 'yaml.gosplit',
    ['.*/specs/datasources/[^/]+/config%.yaml'] = 'yaml.gosplit',
  },
}

-- 2. Parser. yaml.gosplit buffers use gosplit, not yaml. With gosplit.so on the
--    runtimepath, the treesitter FileType autocmd (lua/custom/plugins/treesitter.lua) starts it.
vim.treesitter.language.register('gosplit', 'yaml.gosplit')

-- 3. Server. Not in the LSP `servers` table: it is neither a Mason package nor an lspconfig server.
vim.lsp.config('go_split_lsp', {
  cmd = { 'go-split-lsp' },
  filetypes = { 'yaml.gosplit' },
  root_markers = { 'specs', '.git' },
  on_attach = function(client, _)
    -- Tree-sitter already colours the buffer; the semantic tokens exist for VS Code.
    client.server_capabilities.semanticTokensProvider = nil
    -- Hints (traceability comments) in the sign column only, for this server only.
    vim.diagnostic.config(
      { virtual_text = { severity = { min = vim.diagnostic.severity.WARN } } },
      vim.lsp.diagnostic.get_namespace(client.id)
    )
  end,
})
vim.lsp.enable 'go_split_lsp'

-- vim: ts=2 sts=2 sw=2 et
