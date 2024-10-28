return {
  'nvim-treesitter/nvim-treesitter',
  enabled = true,
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local configs = require("nvim-treesitter.configs")

    configs.setup({
      highlight = { enable = true },
      indent = { enable = true }, 
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "diff",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "jsonc",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "printf",
        "python",
        "query",
        "regex",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
      },
    })
  end,
}
