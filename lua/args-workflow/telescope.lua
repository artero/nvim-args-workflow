-- Telescope integration for args-workflow
local M = {}

function M.setup(args_workflow)
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    return
  end

  -- Custom action to convert Telescope selection to args
  local function selection_to_args(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local actions = require("telescope.actions")
    local picker = action_state.get_current_picker(prompt_bufnr)
    local multi_selection = picker:get_multi_selection()

    -- Clear current args first
    vim.cmd("%argd")

    if #multi_selection > 0 then
      -- Add selected files to args
      for _, entry in ipairs(multi_selection) do
        vim.cmd("argadd " .. (entry.path or entry.value))
      end
      vim.notify("Set " .. #multi_selection .. " files as args", vim.log.levels.INFO)
      actions.close(prompt_bufnr)
    else
      vim.notify("No files selected. Use <Tab> to select files first.", vim.log.levels.WARN)
    end
  end

  -- Setup telescope mappings after telescope loads
  vim.defer_fn(function()
    local telescope_config = require("telescope.config")
    local mappings = telescope_config.values.mappings

    -- Add our custom mapping to both insert and normal mode
    mappings.i = mappings.i or {}
    mappings.n = mappings.n or {}
    mappings.i[args_workflow.config.telescope.keymap] = selection_to_args
    mappings.n[args_workflow.config.telescope.keymap] = selection_to_args
  end, 100) -- Small delay to ensure telescope is loaded
end

return M
