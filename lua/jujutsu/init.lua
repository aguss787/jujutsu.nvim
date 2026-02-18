local M = {}
local log_buffer = require("jujutsu.log_buffer")

---@class JujutsuKeymaps
---@field edit string|false Key to edit the revision under cursor
---@field mark string|false Key to toggle mark on the revision under cursor
---@field clear_marks string|false Key to clear all marks
---@field new string|false Key to create a new revision from revision(s)
---@field abandon string|false Key to abandon revision(s)
---@field squash string|false Key to squash revision into parent or marked revision
---@field rebase string|false Key to rebase revision onto marked destination(s)
---@field rebase_pick string|false Key to rebase with source/destination mode picker
---@field undo string|false Key to undo the last operation
---@field describe string|false Key to set the revision description
---@field refresh string|false Key to refresh the log buffer
---@field bookmark_set string|false Key to set a bookmark on the revision under cursor

---@class JujutsuConfig
---@field keymaps JujutsuKeymaps

---@type JujutsuConfig
local defaults = {
  keymaps = {
    edit = "<CR>",
    mark = "m",
    clear_marks = "M",
    new = "n",
    abandon = "a",
    squash = "s",
    rebase = "r",
    rebase_pick = "R",
    undo = "u",
    describe = "d",
    refresh = "<C-r>",
    bookmark_set = "bs",
  },
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

---Run `jj log` and show the output in a new scratch buffer, reusing it if it already exists
M.log = function()
  if log_buf and vim.api.nvim_buf_is_valid(log_buf) then
    log_buffer.refresh(log_buf)
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

  if not log_buffer.refresh(log_buf) then
    log_buf = nil
    return
  end

  vim.bo[log_buf].filetype = "jjlog"
  log_buffer.setup_keymaps(log_buf, M.config.keymaps)

  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, log_buf)
end

return M
