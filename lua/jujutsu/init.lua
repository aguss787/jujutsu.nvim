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

---@type integer?
local log_buf = nil

---@type table<string, boolean>
local marked_revs = {}

local marks_ns = vim.api.nvim_create_namespace("jjlog_marks")

---Re-apply mark highlights to buf based on marked_revs
---@param buf integer
local function apply_mark_highlights(buf)
  vim.api.nvim_buf_clear_namespace(buf, marks_ns, 0, -1)
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local rev = line:match("[@◉○]%s+(%w+)")
    if rev and marked_revs[rev] then
      vim.api.nvim_buf_set_extmark(buf, marks_ns, i - 1, 0, { line_hl_group = "Visual" })
    end
  end
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
  apply_mark_highlights(buf)
  return true
end

---Return marked revisions if any, otherwise the revision on the current line
---@return string[]?
local function resolve_revs()
  local revs = vim.tbl_keys(marked_revs)
  if #revs > 0 then
    return revs
  end
  local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
  if rev then
    return { rev }
  end
end

---Run `jj log` and show the output in a new scratch buffer, reusing it if it already exists
M.log = function()
  if log_buf and vim.api.nvim_buf_is_valid(log_buf) then
    refresh_log_buf(log_buf)
    -- focus the existing window showing the buffer, or open a new split
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == log_buf then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
    vim.cmd.split()
    vim.api.nvim_win_set_buf(0, log_buf)
    return
  end

  log_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[log_buf].bufhidden = "wipe"

  if not refresh_log_buf(log_buf) then
    log_buf = nil
    return
  end

  vim.bo[log_buf].filetype = "jjlog"

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
      refresh_log_buf(log_buf)
    end
  end, { buffer = log_buf, desc = "jj edit revision under cursor" })

  vim.keymap.set("n", "m", function()
    local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
    if not rev then
      return
    end
    marked_revs[rev] = not marked_revs[rev] or nil
    apply_mark_highlights(log_buf)
  end, { buffer = log_buf, desc = "Toggle mark on revision under cursor" })

  vim.keymap.set("n", "M", function()
    marked_revs = {}
    vim.api.nvim_buf_clear_namespace(log_buf, marks_ns, 0, -1)
  end, { buffer = log_buf, desc = "Clear all marks" })

  vim.keymap.set("n", "n", function()
    local revs = resolve_revs()
    if not revs then
      return
    end
    local result = vim.system(vim.list_extend({ "jj", "new" }, revs), { text = true }):wait()
    if result.code ~= 0 then
      vim.notify("jj new: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    else
      marked_revs = {}
      refresh_log_buf(log_buf)
    end
  end, { buffer = log_buf, desc = "jj new from revision(s)" })

  vim.keymap.set("n", "a", function()
    local revs = resolve_revs()
    if not revs then
      return
    end
    local result = vim.system(vim.list_extend({ "jj", "abandon" }, revs), { text = true }):wait()
    if result.code ~= 0 then
      vim.notify("jj abandon: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    else
      marked_revs = {}
      refresh_log_buf(log_buf)
    end
  end, { buffer = log_buf, desc = "jj abandon revision(s)" })

  vim.keymap.set("n", "u", function()
    local result = vim.system({ "jj", "undo" }, { text = true }):wait()
    if result.code ~= 0 then
      vim.notify("jj undo: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    else
      refresh_log_buf(log_buf)
    end
  end, { buffer = log_buf, desc = "jj undo" })

  vim.keymap.set("n", "d", function()
    local line = vim.api.nvim_get_current_line()
    local rev = line:match("[@◉○]%s+(%w+)")
    if not rev then
      return
    end

    local result = vim.system({ "jj", "log", "-r", rev, "-T", "description", "--no-graph" }, { text = true }):wait()
    local current_desc = (result.code == 0 and result.stdout or ""):gsub("\n$", "")

    local desc_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(desc_buf, "jj://describe/" .. rev)
    vim.api.nvim_buf_set_lines(desc_buf, 0, -1, false, vim.split(current_desc, "\n", { plain = true }))
    vim.bo[desc_buf].buftype = "acwrite"
    vim.bo[desc_buf].bufhidden = "wipe"
    vim.bo[desc_buf].filetype = "gitcommit"

    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer = desc_buf,
      callback = function()
        local desc = table.concat(vim.api.nvim_buf_get_lines(desc_buf, 0, -1, false), "\n")
        local describe_result = vim.system({ "jj", "describe", "-r", rev, "-m", desc }, { text = true }):wait()
        if describe_result.code ~= 0 then
          vim.notify("jj describe: " .. (describe_result.stderr or "unknown error"), vim.log.levels.ERROR)
        else
          vim.bo[desc_buf].modified = false
          refresh_log_buf(log_buf)
        end
      end,
    })

    vim.cmd.split()
    vim.api.nvim_win_set_buf(0, desc_buf)
    vim.cmd.startinsert()
  end, { buffer = log_buf, desc = "Set revision description" })

  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, log_buf)
end

return M
