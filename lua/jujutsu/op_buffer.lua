local M = {}

local jj = require("jujutsu.jj")
local ansi = require("jujutsu.ansi")

local OP_PATTERN = "[@○]%s+(%w+)"

---Extract the operation ID from the current line, or nil if none
---@return string?
local function cursor_op()
  return vim.api.nvim_get_current_line():match(OP_PATTERN)
end

---@type integer?
local last_limit = nil

---Fetch `jj op log` output and replace the contents of buf
---@param buf integer
---@param limit? integer
---@return boolean success
function M.refresh(buf, limit)
  if limit then
    last_limit = limit
  end
  local cmd = { "op", "log", "--color=always" }
  if last_limit then
    vim.list_extend(cmd, { "--limit", tostring(last_limit) })
  end
  local result = jj.run(cmd)
  if not result then
    return false
  end
  local lines = vim.split(result.stdout, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  local win = vim.fn.bufwinid(buf)
  local cursor = win ~= -1 and vim.api.nvim_win_get_cursor(win) or nil
  ansi.render(buf, lines)
  if cursor then
    local line_count = vim.api.nvim_buf_line_count(buf)
    pcall(vim.api.nvim_win_set_cursor, win, { math.min(cursor[1], line_count), cursor[2] })
  end
  return true
end

---Set up buffer-local keymaps for the op buffer
---@param buf integer
---@param keymaps table<string, string|false>
function M.setup_keymaps(buf, keymaps)
  local function map(key, fn, desc)
    if key ~= false then
      vim.keymap.set("n", key, fn, { buffer = buf, desc = desc })
    end
  end

  map(keymaps.restore, function()
    local op = cursor_op()
    if not op then
      return
    end
    if jj.run({ "op", "restore", op }) then
      M.refresh(buf)
    end
  end, "jj op restore operation under cursor")

  map(keymaps.undo, function()
    if jj.run({ "undo" }) then
      M.refresh(buf)
    end
  end, "jj undo")

  map(keymaps.quit, function()
    vim.cmd("close")
  end, "Close the buffer")

  map(keymaps.goto_log, function()
    require("jujutsu").log()
  end, "Switch to log buffer")

  map(keymaps.goto_bookmark, function()
    require("jujutsu").bookmark()
  end, "Switch to bookmark buffer")

  map(keymaps.goto_op, function()
    require("jujutsu").op()
  end, "Switch to op buffer")

  map(keymaps.refresh, function()
    if M.refresh(buf) then
      vim.notify("jj op log: refreshed", vim.log.levels.INFO)
    end
  end, "Refresh the op log buffer")
end

return M
