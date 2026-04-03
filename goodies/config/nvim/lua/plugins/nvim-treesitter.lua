return {
  "nvim-treesitter/nvim-treesitter",
  branch = 'main',
  lazy = false,
  build = ":TSUpdate",
  config = function ()
    local treesitter = require("nvim-treesitter")
    treesitter.setup()
    treesitter.install { "c", "cpp", "rust", "python", "json", "yaml", "toml", "bash", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "gitignore" }

    vim.api.nvim_create_autocmd('FileType', {
      pattern = { "c", "cpp", "rust", "python", "json", "yaml", "toml", "bash", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "gitignore" },
      callback = function()
        -- syntax highlighting, provided by Neovim
        vim.treesitter.start()
        -- folds, provided by Neovim
        -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        -- vim.wo.foldmethod = 'expr'
        -- indentation, provided by nvim-treesitter
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })

  end
}
