return {
  'stevearc/oil.nvim',
  -- Lazy loading is not recommended by oil; `keys` would otherwise make it lazy
  lazy = false,
  keys = {
    { '<leader>oo', '<cmd>Oil<cr>', desc = '[O]il: [O]pen parent directory' },
    {
      '<leader>of',
      function()
        require('oil').toggle_float()
      end,
      desc = '[O]il: toggle [F]loat',
    },
  },

  opts = {
    float = {
      -- integer = absolute cols/lines, 0–1 = fraction of the editor
      max_width = 0.6,
      max_height = 0.6,
      win_options = {
        winblend = 10,
      },
    },
    view_options = {
      -- Show files and directories that start with "."
      show_hidden = true,
    },
  },
  -- mini.icons must be set up before oil resolves its icon provider
  dependencies = { 'echasnovski/mini.nvim' },
}
