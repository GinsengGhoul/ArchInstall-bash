vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt
local api = vim.api

opt.relativenumber = false
opt.number = true
opt.syntax = on
opt.cc = "80"
opt.mouse = ''

-- background
api.nvim_set_hl(0, 'Normal', { bg = 'none', ctermbg = 'none' })
api.nvim_set_hl(0, 'NonText', { bg = 'none', ctermbg = 'none' })

-- tabs & indentation
opt.tabstop = 2 -- 2 spaces for tabs (prettier default)
opt.softtabstop = 2 -- 2 spaces for tabs (prettier default)
opt.shiftwidth = 2 -- 2 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one
opt.smartindent = true -- copy indent from current file

opt.wrap = true

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

opt.cursorline = true

-- turn on termguicolors for tokyonight colorscheme to work
-- (have to use iterm2 or any other true color terminal)
opt.termguicolors = true
opt.background = "dark" -- colorschemes that can be light or dark will be made dark
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- backspace
opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- clipboard
opt.clipboard:append("unnamedplus") -- use system clipboard as default register

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

-- turn off swapfile
opt.swapfile = false
