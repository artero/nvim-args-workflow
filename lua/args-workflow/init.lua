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
    current_hl = "Normal", -- Highlight group for current file
    other_hl = "Comment", -- Highlight group for other files
  },

  telescope = {
    enable = true, -- Enable telescope integration
    keymap = "<C-a>", -- Key to convert selection to args
  },

  auto_display = {
    enable = true, -- Auto-display on args changes
    delay = 50, -- Delay in milliseconds
    timeout = 1000, -- Timeout for auto-close
  },
}

-- Plugin configuration
M.config = {}

local function print_args(output, argc, timeout)
  if not output or #output == 0 then
    return
  end

  -- Calculate the width of the longest line
  local max_width = 0
  for _, line in ipairs(output) do
    local text = line[1] or ""
    local width = vim.fn.strdisplaywidth(text)
    if width > max_width then
      max_width = width
    end
  end

  -- Add some padding
  max_width = max_width + 4

  -- Get screen dimensions
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  -- Calculate window dimensions and position
  local win_width = screen_width -- Use full screen width
  local win_height = 1 -- Single line for concatenated content

  -- Position at bottom of screen
  local row = screen_height - win_height - 3 -- Leave space for cmdline
  local col = 0 -- Start at left edge

  -- Create buffer for the float window
  local buf = vim.api.nvim_create_buf(false, true)

  -- Prepare concatenated content for the buffer
  local content_parts = {}
  for _, line in ipairs(output) do
    table.insert(content_parts, line[1] or "")
  end
  local concatenated_content = table.concat(content_parts, " ")

  -- Calculate how many lines the content will need
  local content_width = vim.fn.strdisplaywidth(concatenated_content)
  local lines_needed = math.max(1, math.ceil(content_width / win_width))
  win_height = math.min(lines_needed, 10) -- Limit to 10 lines max

  -- Update row position based on actual height
  row = screen_height - win_height - 3

  -- Set buffer content as single line (will wrap automatically)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { concatenated_content })

  -- Create float window
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Args (" .. argc .. "): ",
    title_pos = "center",
  })

  -- Apply highlighting to the concatenated content
  local char_offset = 0
  for i, line in ipairs(output) do
    local text = line[1] or ""
    local hl_group = line[2] or "Normal"
    if hl_group ~= "Normal" then
      vim.api.nvim_buf_add_highlight(buf, -1, hl_group, 0, char_offset, char_offset + #text)
    end
    char_offset = char_offset + #text
    if i < #output then
      char_offset = char_offset + 1 -- Add space separator
    end
  end

  -- Auto-close the window after 3 seconds or on any key press
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, timeout)
end

-- Function to display the argument list with visual indicators and colors
function M.update_args()
  local output = {}
  local argc = vim.fn.argc()

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
    print_args(output, argc, M.config.auto_display.timeout)
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
    M.update_args()
  else
    M.safe_last_arg() -- Wrap around to last
    M.update_args()
  end
end

function M.safe_next_arg()
  local current_idx = vim.fn.argidx()
  local total_args = vim.fn.argc()
  if current_idx < total_args - 1 then
    vim.cmd("next")
    M.update_args()
  else
    M.safe_first_arg() -- Wrap around to first
    M.update_args()
  end
end

function M.safe_first_arg()
  if vim.fn.argc() > 0 then
    vim.cmd("first")
    M.update_args()
  else
    vim.notify("No arguments in list", vim.log.levels.WARN)
  end
end

function M.safe_last_arg()
  if vim.fn.argc() > 0 then
    vim.cmd("last")
    M.update_args()
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
  vim.keymap.set("n", keymaps.list, M.update_args, { desc = "[A]rgs [L]ist" })
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
      vim.defer_fn(M.update_args, M.config.auto_display.delay)
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
