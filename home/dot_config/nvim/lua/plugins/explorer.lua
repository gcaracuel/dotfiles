-- Snacks File Explorer (LazyVim default)
-- Override position to right side
return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>fe",
      function()
        Snacks.explorer({ cwd = LazyVim.root(), layout = "right" })
      end,
      desc = "Explorer Snacks (root dir)",
    },
    {
      "<leader>fE",
      function()
        Snacks.explorer({ layout = "right" })
      end,
      desc = "Explorer Snacks (cwd)",
    },
    { "<leader>e", "<leader>fe", desc = "Explorer Snacks (root dir)", remap = true },
    { "<leader>E", "<leader>fE", desc = "Explorer Snacks (cwd)", remap = true },
  },
}
