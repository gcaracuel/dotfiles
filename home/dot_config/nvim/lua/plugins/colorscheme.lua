return {
  -- rose-pine colorscheme
  {
    "rose-pine/neovim",
    name = "rose-pine",
    opts = {
      variant = "moon", -- 'main', 'moon', or 'dawn'
      dark_variant = "moon",
    },
  },

  -- Configure LazyVim to use rose-pine
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine-moon",
    },
  },
}
