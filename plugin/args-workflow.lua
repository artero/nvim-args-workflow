-- Args Workflow Plugin Entry Point
-- This file is automatically loaded by Neovim

if vim.g.loaded_args_workflow then
  return
end
vim.g.loaded_args_workflow = 1

-- Create a command to setup the plugin if user hasn't done it manually
vim.api.nvim_create_user_command("ArgsWorkflowSetup", function()
  require("args-workflow").setup()
end, {
  desc = "Setup Args Workflow plugin with default configuration",
})
