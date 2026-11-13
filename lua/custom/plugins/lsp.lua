return {
  -- nvim-lspconfig supplies the default `lsp/*.lua` configs (cmd, filetypes, root
  -- markers) for each server; everything else here uses Neovim's built-in client.
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Installs language servers and tools into stdpath('data')/mason
    { 'williamboman/mason.nvim', config = true },
    -- Maps lspconfig server names to Mason package names (used by mason-tool-installer)
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- LSP progress messages in the corner
    { 'j-hui/fidget.nvim', opts = {} },

    -- Extra client capabilities advertised when nvim-cmp is the completion engine
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    -- [[ Diagnostics display ]]
    -- Neovim 0.11+ disables inline (virtual text) diagnostics by default; turn them back on.
    vim.diagnostic.config {
      severity_sort = true,
      float = { source = 'if_many' },
      virtual_text = { source = 'if_many', spacing = 2 },
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN] = '󰀪 ',
          [vim.diagnostic.severity.INFO] = '󰋽 ',
          [vim.diagnostic.severity.HINT] = '󰌶 ',
        },
      } or {},
    }

    -- [[ Per-buffer setup when a server attaches ]]
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -- Telescope pickers for navigation. `grr` replaces Neovim's built-in
        -- quickfix version (and avoids the `gr`-prefix timeout).
        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
        map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
        -- Declaration, not definition (e.g. the header in C)
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- Highlight other references to the symbol under the cursor while it rests there
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
          local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- Inlay hints are off by default; toggle them per buffer
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -- [[ Servers ]]
    -- Every server listed here is installed by Mason (if missing) and enabled, so a
    -- fresh machine gets the same set. Keys are lspconfig names; values are overrides
    -- merged over the lspconfig defaults (`cmd`, `filetypes`, `root_markers`,
    -- `settings`, `capabilities`, ...).
    local servers = {
      clangd = {},
      gopls = {
        settings = {
          gopls = {
            buildFlags = {
              '-tags=experimental',
              '-tags=test',
            },
          },
        },
      },
      html = {},
      lua_ls = {
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            -- Plugin `setup` tables are always partial; this warning is pure noise here.
            diagnostics = { disable = { 'missing-fields' } },
          },
        },
      },
      marksman = {
        settings = {
          marksman = {},
        },
      },
      pbls = {},
      pyright = {},
      solargraph = {},
      terraformls = {},
    }

    -- Install the servers above plus standalone tools. `:Mason` to inspect.
    local ensure_installed = vim.tbl_keys(servers)
    vim.list_extend(ensure_installed, {
      'stylua', -- Lua formatter, run by conform.nvim
    })
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    -- Servers in the table above are always enabled. On top of that, anything
    -- installed by hand via :Mason is enabled too, so trying a new server doesn't
    -- require a config change (add it to `servers` once you want to keep it).
    require('mason-lspconfig').setup {
      -- stylua is a formatter here (run by conform.nvim), not a language server.
      -- rust_analyzer comes from rustup and is managed by rustaceanvim
      -- (lua/custom/plugins/rustaceanvim.lua); never let a Mason copy start a second client.
      automatic_enable = { exclude = { 'stylua', 'rust_analyzer' } },
    }

    -- nvim-cmp supports more completion features than the built-in client advertises
    local capabilities = vim.tbl_deep_extend(
      'force',
      vim.lsp.protocol.make_client_capabilities(),
      require('cmp_nvim_lsp').default_capabilities()
    )
    vim.lsp.config('*', { capabilities = capabilities })
    for server_name, server in pairs(servers) do
      vim.lsp.config(server_name, server)
    end
    vim.lsp.enable(vim.tbl_keys(servers))
  end,
}
