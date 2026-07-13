-- Minimal config for testing the plugin
vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"), "bootstrap.lua")()

require("lazy.minit").setup({
  spec = {
    { dir = vim.uv.cwd(), opts = {} },
  },
})

-- Add any test keymaps here
vim.keymap.set("n", "<leader>ap", function()
  require("agent-panel").toggle()
end, { desc = "Toggle Agent Panel" })
