return {
  "ms-jpq/chadtree",
  enabled = true,
  build = ":CHADdeps",
  init = function()
    vim.g.chadtree_settings = {
      ["theme.icon_glyph_set"] = "devicons",
      ["theme.text_colour_set"] = "nerdtree_syntax_dark",
      ["theme.icon_colour_set"] = "github",
    }
  end,
}
