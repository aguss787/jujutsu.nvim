local M = {}

local jj = require("jujutsu.jj")
local ansi = require("jujutsu.ansi")

---Fetch `jj op log` output and replace the contents of buf
---@param buf integer
---@return boolean success
function M.refresh(buf)
  local result = jj.run({ "op", "log", "--color=always" })
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
