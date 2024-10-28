return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  ---@module "ibl"
  ---@type ibl.config
  setup = function()
    require("ibl").setup{}
  end,
  opts = {},
}
