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
---@field duplicate string|false Key to duplicate revision(s)
---@field duplicate_pick string|false Key to duplicate with destination mode picker
---@field refresh string|false Key to refresh the log buffer
---@field bookmark_set string|false Key to set a bookmark on the revision under cursor
---@field bookmark_delete string|false Key to delete a bookmark on the revision under cursor
---@field bookmark_move string|false Key to move bookmarks from marked revision(s) to cursor revision
---@field bookmark_move_backwards string|false Key to move bookmarks backwards from marked revision(s) to cursor revision
---@field bookmark_track string|false Key to track a remote bookmark
---@field bookmark_untrack string|false Key to untrack a remote bookmark
---@field git_fetch string|false Key to run jj git fetch
---@field git_push string|false Key to run jj git push -r on revision(s)
---@field git_push_all string|false Key to run jj git push --all --deleted

---@class JujutsuConfig
---@field keymaps JujutsuKeymaps
---@field split "vertical"|"horizontal" How to split the window when opening the log buffer

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
    duplicate = "p",
    duplicate_pick = "P",
    refresh = "<C-r>",
    bookmark_set = "bs",
    bookmark_delete = "bd",
    bookmark_move = "bm",
    bookmark_move_backwards = "bM",
    bookmark_track = "bt",
    bookmark_untrack = "bT",
    git_fetch = "gf",
    git_push = "gp",
    git_push_all = "gP",
  },
  split = "vertical",
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

local function open_split()
  local cmd = M.config.split == "vertical" and "vsplit" or "split"
  vim.cmd(cmd)
end

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
    open_split()
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

  open_split()
  vim.api.nvim_win_set_buf(0, log_buf)
end

return M
