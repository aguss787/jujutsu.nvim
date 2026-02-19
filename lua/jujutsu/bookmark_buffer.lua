local M = {}

local jj = require("jujutsu.jj")

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
  local cmd = { "bookmark", "list" }
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
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return true
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

  map(keymaps.goto_log, function()
    require("jujutsu").log()
  end, "Switch to log buffer")

  map(keymaps.goto_bookmark, function()
    require("jujutsu").bookmark()
  end, "Switch to bookmark buffer")

  local function track_action(subcmd)
    local name = cursor_bookmark()
    if not name then
      return
    end
    if jj.run({ "bookmark", subcmd, name .. "@origin" }) then
      M.refresh(buf)
    end
  end

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

  map(keymaps.undo, function()
    if jj.run({ "undo" }) then
      M.refresh(buf)
    end
  end, "jj undo")

  if keymaps.refresh and keymaps.refresh ~= false then
    vim.keymap.set("n", keymaps.refresh, function()
      if M.refresh(buf) then
        vim.notify("jj bookmark list: refreshed", vim.log.levels.INFO)
      end
    end, { buffer = buf, desc = "Refresh the bookmark list buffer" })
  end
end

return M
