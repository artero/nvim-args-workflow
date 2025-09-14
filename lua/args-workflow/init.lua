-- Args Workflow Plugin
-- Enhanced Vim argument list workflow for Neovim
-- Author: Juan Artero (@artero)

local M = {}

-- Default configuration
local default_config = {
  keymaps = {
    list = "<leader>al", -- Show args list
    add = "<leader>aa", -- Add current file
    delete = "<leader>ad", -- Remove current file
    delete_all = "<leader>aD", -- Clear all args
  },

  display = {
    current_indicator = "►", -- Indicator for current file
    title_hl = "Title", -- Highlight group for title
    current_hl = "String", -- Highlight group for current file
    other_hl = "Comment", -- Highlight group for other files
  },

  telescope = {
    enable = true, -- Enable telescope integration
    keymap = "<C-a>", -- Key to convert selection to args
  },

  auto_display = {
    enable = true, -- Auto-display on args changes
    delay = 50, -- Delay in milliseconds
  },
}

-- Plugin configuration
M.config = {}

-- Function to display the argument list with visual indicators and colors
function M.print_args()
  local output = {}
  local argc = vim.fn.argc()

  -- Show count in title
  table.insert(output, { "Args (" .. argc .. "): ", M.config.display.title_hl })

  for i = 1, argc do
    local arg = vim.fn.argv(i - 1)
    local fileName = arg:match("^.+/(.+)$") or arg

    if arg == vim.fn.bufname() then
      -- Current file with highlighted indicator
      table.insert(output, { M.config.display.current_indicator .. " " .. fileName, M.config.display.current_hl })
    else
      -- Other files in muted color
      table.insert(output, { "  " .. fileName, M.config.display.other_hl })
    end

    -- Add separator except for last item
    if i < argc then
      table.insert(output, { "  ", "Normal" })
    end
  end

  -- Use nvim_echo for colored output
  if argc > 0 then
    vim.api.nvim_echo(output, false, {})
  else
    vim.notify("No files in argument list", vim.log.levels.INFO)
  end
end

-- Enhanced function to add current buffer to args with feedback
function M.add_current_to_args()
  local current_file = vim.fn.expand("%")
  if current_file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  vim.cmd("argadd " .. current_file)
  vim.notify("Added: " .. current_file, vim.log.levels.INFO)
end

-- Enhanced navigation functions with error handling
function M.safe_prev_arg()
  local current_idx = vim.fn.argidx()
  if current_idx > 0 then
    vim.cmd("prev")
    M.print_args()
  else
    vim.notify("Already at first argument", vim.log.levels.INFO)
    M.print_args()
  end
end

function M.safe_next_arg()
  local current_idx = vim.fn.argidx()
  local total_args = vim.fn.argc()
  if current_idx < total_args - 1 then
    vim.cmd("next")
    M.print_args()
  else
    vim.notify("Already at last argument", vim.log.levels.INFO)
    M.print_args()
  end
end

function M.safe_first_arg()
  if vim.fn.argc() > 0 then
    vim.cmd("first")
    M.print_args()
  else
    vim.notify("No arguments in list", vim.log.levels.WARN)
  end
end

function M.safe_last_arg()
  if vim.fn.argc() > 0 then
    vim.cmd("last")
    M.print_args()
  else
    vim.notify("No arguments in list", vim.log.levels.WARN)
  end
end

-- Setup keymaps
function M.setup_keymaps()
  local keymaps = M.config.keymaps

  -- Movement keymaps for args navigation (override native Vim commands with error handling)
  vim.keymap.set("n", "[a", M.safe_prev_arg, { desc = "Previous arg file" })
  vim.keymap.set("n", "]a", M.safe_next_arg, { desc = "Next arg file" })
  vim.keymap.set("n", "[A", M.safe_first_arg, { desc = "First arg file" })
  vim.keymap.set("n", "]A", M.safe_last_arg, { desc = "Last arg file" })

  -- Args management keymaps
  vim.keymap.set("n", keymaps.list, M.print_args, { desc = "[A]rgs [L]ist" })
  vim.keymap.set("n", keymaps.add, M.add_current_to_args, { desc = "[A]rgs [A]dd current file" })
  vim.keymap.set("n", keymaps.delete, function()
    vim.cmd("argd")
    vim.notify("Removed current file from args", vim.log.levels.INFO)
  end, { desc = "[A]rgs [D]elete current file" })
  vim.keymap.set("n", keymaps.delete_all, function()
    vim.cmd("%argd")
    vim.notify("Cleared all args", vim.log.levels.INFO)
  end, { desc = "[A]rgs [D]elete all" })
end

-- Setup automatic args list display on changes
function M.setup_autocommands()
  if not M.config.auto_display.enable then
    return
  end

  local args_group = vim.api.nvim_create_augroup("ArgsWorkflow", { clear = true })

  -- Track args changes with a custom event system
  local last_args_count = vim.fn.argc()
  local last_args_list = vim.fn.argv()

  -- Function to check if args have changed
  local function check_args_changed()
    local current_count = vim.fn.argc()
    local current_list = vim.fn.argv()

    -- Check if count changed or list content changed
    if current_count ~= last_args_count or vim.deep_equal(current_list, last_args_list) == false then
      last_args_count = current_count
      last_args_list = current_list
      -- Small delay to ensure arg operations are complete
      vim.defer_fn(M.print_args, M.config.auto_display.delay)
    end
  end

  -- Monitor various events that might change args
  vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufDelete" }, {
    group = args_group,
    callback = check_args_changed,
    desc = "Auto-display args list on changes",
  })

  -- Also monitor when we use :argadd, :argdelete commands
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = args_group,
    callback = function()
      local cmd = vim.fn.getcmdline()
      if cmd:match("^argadd") or cmd:match("^argd") or cmd:match("^%argd") then
        vim.defer_fn(check_args_changed, 100)
      end
    end,
    desc = "Auto-display args on arg commands",
  })
end

-- Setup telescope integration
function M.setup_telescope()
  if not M.config.telescope.enable then
    return
  end

  local telescope_config = require("args-workflow.telescope")
  telescope_config.setup(M)
end

-- Create custom command for displaying args
function M.setup_commands()
  vim.cmd('command! ArgsTab lua require("args-workflow").print_args()')
end

-- Main setup function
function M.setup(user_config)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})

  -- Setup all components
  M.setup_keymaps()
  M.setup_commands()
  M.setup_autocommands()

  -- Setup telescope integration if available
  local ok, _ = pcall(require, "telescope")
  if ok then
    M.setup_telescope()
  end
end

return M
