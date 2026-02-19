local M = {}

local jj = require("jujutsu.jj")
local ansi = require("jujutsu.ansi")

local show_all = false

---Extract the bookmark name from the current line, or nil if none
---@return string?
local function cursor_bookmark()
  return vim.api.nvim_get_current_line():match("^(%S+):")
end

---Fetch `jj bookmark list` output and replace the contents of buf
---@param buf integer
---@return boolean success
function M.refresh(buf)
  local cmd = { "bookmark", "list", "--color=always" }
  if show_all then
    table.insert(cmd, "--all-remotes")
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

---Reset toggle state to local-only (called when a new buffer is created)
function M.reset()
  show_all = false
end

---Set up buffer-local keymaps for the bookmark buffer
---@param buf integer
---@param keymaps table<string, string|false>
function M.setup_keymaps(buf, keymaps)
  local function map(key, fn, desc)
    if key ~= false then
      vim.keymap.set("n", key, fn, { buffer = buf, desc = desc })
    end
  end

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

  local function track_action(subcmd)
    local name = cursor_bookmark()
    if not name then
      return
    end
    if jj.run({ "bookmark", subcmd, jj.with_remote(name) }) then
      M.refresh(buf)
    end
  end

  map(keymaps.edit, function()
    local name = cursor_bookmark()
    if not name then
      return
    end
    if jj.run({ "edit", name }) then
      require("jujutsu").log()
    end
  end, "jj edit bookmark and switch to log")

  map(keymaps.new, function()
    local name = cursor_bookmark()
    if not name then
      return
    end
    if jj.run({ "new", name }) then
      require("jujutsu").log()
    end
  end, "jj new from bookmark and switch to log")

  map(keymaps.delete, function()
    local name = cursor_bookmark()
    if not name then
      return
    end
    if jj.run({ "bookmark", "delete", name }) then
      M.refresh(buf)
    end
  end, "jj bookmark delete")

  map(keymaps.track, function()
    track_action("track")
  end, "jj bookmark track")

  map(keymaps.untrack, function()
    track_action("untrack")
  end, "jj bookmark untrack")

  map(keymaps.toggle_all, function()
    show_all = not show_all
    M.refresh(buf)
    local mode = show_all and "all remotes" or "local only"
    vim.notify("jj bookmark list: " .. mode, vim.log.levels.INFO)
  end, "Toggle between local and all remote bookmarks")

  map(keymaps.git_push, function()
    local name = cursor_bookmark()
    if not name then
      return
    end
    jj.push_async("git_push", "pushing...", { "git", "push", "-b", name }, function()
      M.refresh(buf)
    end)
  end, "jj git push -b bookmark under cursor")

  map(keymaps.git_fetch, function()
    jj.run_async("git_fetch", "fetching...", { "git", "fetch" }, function()
      M.refresh(buf)
    end)
  end, "jj git fetch")

  map(keymaps.git_push_all, function()
    jj.push_async("git_push_all", "pushing all...", { "git", "push", "--all", "--deleted" }, function()
      M.refresh(buf)
    end)
  end, "jj git push --all --deleted")

  map(keymaps.undo, function()
    if jj.run({ "undo" }) then
      M.refresh(buf)
    end
  end, "jj undo")

  map(keymaps.refresh, function()
    if M.refresh(buf) then
      vim.notify("jj bookmark list: refreshed", vim.log.levels.INFO)
    end
  end, "Refresh the bookmark list buffer")
end

return M
