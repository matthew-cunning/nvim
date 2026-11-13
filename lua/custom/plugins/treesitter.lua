return { -- Treesitter parsers and queries: highlighting, indentation, injections
  'nvim-treesitter/nvim-treesitter',
  branch = 'main', -- `master` is frozen and its queries break on Neovim 0.12
  lazy = false, -- the plugin does not support lazy-loading
  build = ':TSUpdate',
  config = function()
    local ts = require 'nvim-treesitter'

    -- Parsers to keep installed (under stdpath('data')/site). Installing is a
    -- no-op for parsers that are already present; `:TSInstall <lang>` for one-offs.
    -- (jsonc files use the json parser; tmux has no parser on the main branch.)
    ts.install {
      'asm', 'bash', 'c', 'cpp', 'csv', 'diff', 'dockerfile',
      'git_config', 'git_rebase', 'gitcommit', 'gitignore',
      'go', 'gomod', 'gosum', 'gowork', 'groovy', 'hcl', 'html', 'ini',
      'java', 'javascript', 'json', 'lua', 'luadoc', 'make',
      'markdown', 'markdown_inline', 'nginx', 'proto', 'python', 'query',
      'requirements', 'rst', 'ruby', 'rust', 'sql', 'ssh_config',
      'terraform', 'toml', 'tsx', 'typescript', 'typst',
      'vim', 'vimdoc', 'xml', 'yaml',
    }

    -- Highlighting and indentation are enabled per buffer. A language that has no
    -- parser yet is installed on first encounter; reopen the file once it finishes.
    local requested = {}
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if not lang then
          return
        end

        if not vim.treesitter.language.add(lang) then
          if not requested[lang] and vim.list_contains(ts.get_available(), lang) then
            requested[lang] = true
            vim.notify(('Installing treesitter parser for %s; reopen the file to highlight it'):format(lang))
            ts.install { lang }
          end
          return
        end

        vim.treesitter.start(args.buf, lang)
        if ft == 'ruby' then
          -- Ruby keeps Vim's regex highlighting and indent rules
          vim.bo[args.buf].syntax = 'ruby'
        elseif vim.treesitter.query.get(lang, 'indents') then
          -- Only languages with an indents query; the others keep their Vim indent plugin
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
