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

  filename = {
    max_length = 25, -- Maximum filename length before cropping
    crop_strategy = "smart", -- "smart" keeps extension, "simple" just truncates
  },
}

-- Plugin configuration
M.config = {}

-- Function to crop long filenames
local function crop_filename(filename, max_length, strategy)
  strategy = strategy or "smart"

  if #filename <= max_length then
    return filename
  end

  if strategy == "smart" then
    -- Try to keep extension
    local name, ext = filename:match("^(.+)%.(.+)$")
    if name and ext and #ext <= 4 then -- Only for reasonable extensions
      local available = max_length - #ext - 2 -- -2 for "…" and "."
      if available > 3 then
        return name:sub(1, available) .. "…." .. ext
      end
    end
  end

  -- Fallback: just truncate with ellipsis
  return filename:sub(1, max_length - 1) .. "…"
end

-- Function to display the argument list with visual indicators and colors
function M.print_args()
  local argc = vim.fn.argc()
  if argc == 0 then
    vim.notify("No files in argument list", vim.log.levels.INFO)
    return
  end

  -- For many files or auto-display, use simple notification to avoid "Press ENTER"
  if argc > 8 or M.config.auto_display.enable then
    M.show_args_minimal()
    return
  end

  -- For few files, use the original echo method
  local current_idx = vim.fn.argidx() + 1
  local output = { { "Args (" .. argc .. "): ", M.config.display.title_hl } }

  for i = 1, argc do
    local arg = vim.fn.argv(i - 1)
    local filename = arg:match("^.+/(.+)$") or arg
    local cropped_name = crop_filename(filename, M.config.filename.max_length, M.config.filename.crop_strategy)

    local is_current = (arg == vim.fn.bufname())
    local file_text = cropped_name
    local hl_group = is_current and M.config.display.current_hl or M.config.display.other_hl

    table.insert(output, { file_text, hl_group })

    if i < argc then
      table.insert(output, { "  ", "Normal" })
    end
  end

  vim.api.nvim_echo(output, false, {})
end

-- Minimal display to avoid "Press ENTER" prompt
function M.show_args_minimal()
  local argc = vim.fn.argc()
  local current_idx = vim.fn.argidx() + 1
  local editor_width = vim.api.nvim_get_option("columns")
  local editor_height = vim.api.nvim_get_option("lines")

  -- Use full width minus small margins
  local available_width = editor_width - 4
  local prefix = "Args(" .. argc .. "): "
  local content_width = available_width - #prefix

  -- Calculate how many characters we can give to each filename
  local estimated_files_visible = math.min(argc, math.max(5, math.floor(content_width / 15))) -- At least 5 files, ~15 chars each
  local max_filename_length = math.max(12, math.floor(content_width / estimated_files_visible) - 3) -- -3 for separators

  -- Build display with more generous spacing
  local display_parts = {}
  local total_length = #prefix
  local files_added = 0

  -- Start from current and expand outward
  local before_idx = current_idx - 1
  local after_idx = current_idx + 1

  -- Always add current file first
  local current_arg = vim.fn.argv(current_idx - 1)
  local current_file = current_arg:match("^.+/(.+)$") or current_arg
  local current_cropped = crop_filename(current_file, max_filename_length, M.config.filename.crop_strategy)
  local current_display = current_cropped

  table.insert(display_parts, { text = current_display, idx = current_idx, is_current = true })
  total_length = total_length + #current_display
  files_added = 1

  -- Add files before and after alternately while there's space
  while (before_idx >= 1 or after_idx <= argc) and files_added < estimated_files_visible do
    local added = false

    -- Try adding before
    if before_idx >= 1 then
      local arg = vim.fn.argv(before_idx - 1)
      local filename = arg:match("^.+/(.+)$") or arg
      local cropped = crop_filename(filename, max_filename_length, M.config.filename.crop_strategy)
      local needed_space = #cropped + 3 -- +3 for "  " separator

      if total_length + needed_space < available_width then
        table.insert(display_parts, 1, { text = cropped, idx = before_idx, is_current = false })
        total_length = total_length + needed_space
        before_idx = before_idx - 1
        files_added = files_added + 1
        added = true
      else
        before_idx = 0 -- Stop trying before
      end
    end

    -- Try adding after
    if after_idx <= argc and files_added < estimated_files_visible then
      local arg = vim.fn.argv(after_idx - 1)
      local filename = arg:match("^.+/(.+)$") or arg
      local cropped = crop_filename(filename, max_filename_length, M.config.filename.crop_strategy)
      local needed_space = #cropped + 3 -- +3 for "  " separator

      if total_length + needed_space < available_width then
        table.insert(display_parts, { text = cropped, idx = after_idx, is_current = false })
        total_length = total_length + needed_space
        after_idx = after_idx + 1
        files_added = files_added + 1
        added = true
      else
        after_idx = argc + 1 -- Stop trying after
      end
    end

    if not added then
      break
    end
  end

  -- Build final display line
  local final_parts = { prefix }
  local first_idx = display_parts[1].idx
  local last_idx = display_parts[#display_parts].idx

  if first_idx > 1 then
    table.insert(final_parts, "… ")
  end

  for i, part in ipairs(display_parts) do
    table.insert(final_parts, part.text)
    if i < #display_parts then
      table.insert(final_parts, "  ")
    end
  end

  if last_idx < argc then
    table.insert(final_parts, " …")
  end

  local display_line = table.concat(final_parts)

  -- Create full-width floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { display_line })

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = editor_width,
    height = 1,
    col = 0,
    row = editor_height - 3,
    style = "minimal",
    border = "none",
  })

  -- Apply highlighting for current file
  local ns = vim.api.nvim_create_namespace("args_workflow")
  local highlight_start = string.find(display_line, current_display, 1, true)
  if highlight_start then
    vim.api.nvim_buf_add_highlight(
      buf,
      ns,
      M.config.display.current_hl,
      0,
      highlight_start - 1,
      highlight_start - 1 + #current_display
    )
  end

  -- Auto-close window
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, 1500)
end

-- Function to display args horizontally with ellipsis at bottom
function M.show_args_horizontal()
  local argc = vim.fn.argc()
  local current_idx = vim.fn.argidx() + 1 -- Convert from 0-based to 1-based
  local current_buf = vim.fn.bufname()

  -- Build display with context around current file
  local items = {}
  local context_size = 2 -- Show 2 files before and after current

  -- Determine range to show
  local start_idx = math.max(1, current_idx - context_size)
  local end_idx = math.min(argc, current_idx + context_size)

  -- Add leading ellipsis if needed
  if start_idx > 1 then
    table.insert(items, "…")
  end

  -- Add files in range
  for i = start_idx, end_idx do
    local arg = vim.fn.argv(i - 1)
    local fileName = arg:match("^.+/(.+)$") or arg

    if i == current_idx then
      table.insert(items, M.config.display.current_indicator .. fileName)
    else
      table.insert(items, fileName)
    end
  end

  -- Add trailing ellipsis if needed
  if end_idx < argc then
    table.insert(items, "...")
  end

  -- Create display line
  local display_line = table.concat(items, "  ")

  -- Calculate window dimensions
  local editor_width = vim.api.nvim_get_option("columns")
  local editor_height = vim.api.nvim_get_option("lines")
  local width = math.min(#display_line + 4, editor_width - 4)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { display_line })

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = 1,
    col = math.floor((editor_width - width) / 2),
    row = editor_height - 3,
    style = "minimal",
    border = "single",
  })

  -- Apply highlights for current file
  local ns = vim.api.nvim_create_namespace("args_workflow")
  local current_arg = vim.fn.argv(current_idx - 1)
  local current_file = current_arg:match("^.+/(.+)$") or current_arg
  local highlighted_text = M.config.display.current_indicator .. current_file
  local highlight_start = string.find(display_line, highlighted_text, 1, true)

  if highlight_start then
    vim.api.nvim_buf_add_highlight(
      buf,
      ns,
      M.config.display.current_hl,
      0,
      highlight_start - 1,
      highlight_start - 1 + #highlighted_text
    )
  end

  -- Auto-close window
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, 1500)
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
