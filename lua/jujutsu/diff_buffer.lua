local M = {}

local jj = require("jujutsu.jj")

local FILE_PATTERN = "^(%a)%s+(.+)$"

local list_ns = vim.api.nvim_create_namespace("jjdiff_list")
local select_ns = vim.api.nvim_create_namespace("jjdiff_select")

local STATUS_HL = {
  A = "DiffAdd",
  D = "DiffDelete",
  M = "DiffChange",
}

---@type { rev: string, left_buf: integer, right_buf: integer, list_buf: integer, left_win: integer, right_win: integer, list_win: integer, files: { status: string, path: string }[] }?
local state = nil

---@param name string
---@return integer
local function create_scratch_buf(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  return buf
end

---@param buf integer
---@param rev_expr string
---@param path string
local function load_file_content(buf, rev_expr, path)
  local result = jj.run({ "file", "show", "-r", rev_expr, path })
  local lines = {}
  if result then
    lines = vim.split(result.stdout, "\n", { plain = true })
    if #lines > 0 and lines[#lines] == "" then
      table.remove(lines)
    end
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local ft = vim.filetype.match({ filename = path })
  if ft then
    vim.bo[buf].filetype = ft
  end
end

---@param path string
---@param status string
local function show_diff(path, status)
  if not state then
    return
  end

  -- Turn off diff mode before loading new content
  vim.api.nvim_win_call(state.left_win, function()
    vim.cmd("diffoff")
  end)
  vim.api.nvim_win_call(state.right_win, function()
    vim.cmd("diffoff")
  end)

  -- Load left (before) content
  vim.bo[state.left_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.left_buf, 0, -1, false, {})
  vim.bo[state.left_buf].modifiable = false
  if status ~= "A" then
    load_file_content(state.left_buf, state.rev .. "-", path)
  else
    local ft = vim.filetype.match({ filename = path })
    if ft then
      vim.bo[state.left_buf].filetype = ft
    end
  end

  -- Load right (after) content
  vim.bo[state.right_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.right_buf, 0, -1, false, {})
  vim.bo[state.right_buf].modifiable = false
  if status ~= "D" then
    load_file_content(state.right_buf, state.rev, path)
  else
    local ft = vim.filetype.match({ filename = path })
    if ft then
      vim.bo[state.right_buf].filetype = ft
    end
  end

  -- Enable diff mode on both windows
  vim.api.nvim_win_call(state.left_win, function()
    vim.cmd("diffthis")
  end)
  vim.api.nvim_win_call(state.right_win, function()
    vim.cmd("diffthis")
  end)

  -- Highlight currently shown file in the file list
  vim.api.nvim_buf_clear_namespace(state.list_buf, select_ns, 0, -1)
  for i, f in ipairs(state.files) do
    if f.path == path then
      vim.api.nvim_buf_set_extmark(state.list_buf, select_ns, i - 1, 0, {
        line_hl_group = "Visual",
        priority = 4097,
      })
      break
    end
  end
end

---@return string? status, string? path
local function cursor_file()
  local line = vim.api.nvim_get_current_line()
  local status, path = line:match(FILE_PATTERN)
  return status, path
end

local function close_tab()
  state = nil
  vim.cmd("tabclose")
end

---@param buf integer
---@param keymaps table<string, string|false>
local function setup_list_keymaps(buf, keymaps)
  local function map(key, fn, desc)
    if key ~= false then
      vim.keymap.set("n", key, fn, { buffer = buf, desc = desc })
    end
  end

  map(keymaps.select, function()
    local status, path = cursor_file()
    if status and path then
      show_diff(path, status)
    end
  end, "Show diff for file under cursor")

  map(keymaps.quit, close_tab, "Close diff tab")
end

---@param buf integer
---@param keymaps table<string, string|false>
local function setup_diff_keymaps(buf, keymaps)
  local function map(key, fn, desc)
    if key ~= false then
      vim.keymap.set("n", key, fn, { buffer = buf, desc = desc })
    end
  end

  map(keymaps.quit, close_tab, "Close diff tab")
end

---@param buf integer
---@param files { status: string, path: string }[]
local function apply_list_highlights(buf, files)
  for i, f in ipairs(files) do
    local hl = STATUS_HL[f.status]
    if hl then
      vim.api.nvim_buf_set_extmark(buf, list_ns, i - 1, 0, { line_hl_group = hl })
    end
  end
end

---Open a diff viewer tab for the given revision
---@param rev string
---@param keymaps table<string, string|false>
function M.open(rev, keymaps)
  local result = jj.run({ "diff", "-r", rev, "--summary" })
  if not result then
    return
  end
  local raw_lines = vim.split(result.stdout, "\n", { plain = true, trimempty = true })
  local files = {}
  for _, line in ipairs(raw_lines) do
    local status, path = line:match(FILE_PATTERN)
    if status and path then
      table.insert(files, { status = status, path = path })
    end
  end
  if #files == 0 then
    vim.notify("jj diff: no changes in revision " .. rev, vim.log.levels.INFO)
    return
  end

  -- Create buffers
  local left_buf = create_scratch_buf("jj://diff/" .. rev .. "/before")
  local right_buf = create_scratch_buf("jj://diff/" .. rev .. "/after")
  local list_buf = create_scratch_buf("jj://diff/" .. rev .. "/files")

  -- Populate file list
  local list_lines = {}
  for _, f in ipairs(files) do
    table.insert(list_lines, f.status .. " " .. f.path)
  end
  vim.bo[list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, list_lines)
  vim.bo[list_buf].modifiable = false
  apply_list_highlights(list_buf, files)

  -- Create tab and layout
  vim.cmd("tabnew")
  local left_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(left_win, left_buf)

  vim.cmd("vsplit")
  local right_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_win, right_buf)

  vim.api.nvim_set_current_win(left_win)
  vim.cmd("botright split")
  local list_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(list_win, list_buf)

  local list_height = math.max(math.floor(vim.o.lines * 0.25), 5)
  vim.api.nvim_win_set_height(list_win, list_height)

  -- Store state
  state = {
    rev = rev,
    left_buf = left_buf,
    right_buf = right_buf,
    list_buf = list_buf,
    left_win = left_win,
    right_win = right_win,
    list_win = list_win,
    files = files,
  }

  -- Set up keymaps
  setup_list_keymaps(list_buf, keymaps)
  setup_diff_keymaps(left_buf, keymaps)
  setup_diff_keymaps(right_buf, keymaps)

  -- Show first file's diff
  show_diff(files[1].path, files[1].status)

  -- Focus the file list
  vim.api.nvim_set_current_win(list_win)
  vim.api.nvim_win_set_cursor(list_win, { 1, 0 })
end

return M
