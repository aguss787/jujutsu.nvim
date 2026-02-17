local M = {}

---@class JujutsuConfig
---@field field string Example config field

---@type JujutsuConfig
local defaults = {
  field = "value",
}

---@type JujutsuConfig
M.config = {}

---Setup the plugin
---@param opts? JujutsuConfig
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
end

---Fetch `jj log` output and replace the contents of buf
---@param buf integer
---@return boolean success
local function refresh_log_buf(buf)
  local result = vim.system({ "jj", "log" }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("jj log: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
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

---Run `jj log` and show the output in a new scratch buffer
M.log = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  if not refresh_log_buf(buf) then
    return
  end

  vim.bo[buf].filetype = "jjlog"

  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    -- revision lines start with a graph node character (@, ◉, ○) followed by the change ID
    local rev = line:match("[@◉○]%s+(%w+)")
    if not rev then
      return
    end
    local edit_result = vim.system({ "jj", "edit", rev }, { text = true }):wait()
    if edit_result.code ~= 0 then
      vim.notify("jj edit: " .. (edit_result.stderr or "unknown error"), vim.log.levels.ERROR)
    else
      refresh_log_buf(buf)
    end
  end, { buffer = buf, desc = "jj edit revision under cursor" })

  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, buf)
end

return M
