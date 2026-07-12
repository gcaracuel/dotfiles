-- Neo-tree file explorer (secondary, bound to <leader>nt)
return {
  "nvim-neo-tree/neo-tree.nvim",
  cmd = "Neotree",
  keys = {
    {
      "<leader>nt",
      function()
        require("neo-tree.command").execute({ toggle = true, dir = LazyVim.root() })
      end,
      desc = "Neo-tree (Root Dir)",
    },
    {
      "<leader>nE",
      function()
        require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
      end,
      desc = "Neo-tree (cwd)",
    },
    {
      "<leader>ng",
      function()
        require("neo-tree.command").execute({ source = "git_status", toggle = true })
      end,
      desc = "Neo-tree Git Status",
    },
    {
      "<leader>nb",
      function()
        require("neo-tree.command").execute({ source = "buffers", toggle = true })
      end,
      desc = "Neo-tree Buffers",
    },
  },
  opts = {
    sources = { "filesystem", "buffers", "git_status" },
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
    },
    window = {
      position = "right",
      mappings = {
        ["l"] = "open",
        ["h"] = "close_node",
      },
    },
    default_component_configs = {
      indent = {
        with_expanders = true,
      },
    },
  },
}
