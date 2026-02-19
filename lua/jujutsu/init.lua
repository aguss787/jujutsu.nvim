local M = {}
local log_buffer = require("jujutsu.log_buffer")
local bookmark_buffer = require("jujutsu.bookmark_buffer")

---@class JujutsuLogKeymaps
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
---@field bookmark_set string|false Key to set a bookmark on the revision under cursor
---@field bookmark_delete string|false Key to delete a bookmark on the revision under cursor
---@field bookmark_move string|false Key to move bookmarks from marked revision(s) to cursor revision
---@field bookmark_move_backwards string|false Key to move bookmarks backwards from marked revision(s) to cursor revision
---@field bookmark_track string|false Key to track a remote bookmark
---@field bookmark_untrack string|false Key to untrack a remote bookmark
---@field git_fetch string|false Key to run jj git fetch
---@field git_push string|false Key to run jj git push -r on revision(s)
---@field git_push_all string|false Key to run jj git push --all --deleted
---@field quit string|false Key to close the buffer
---@field goto_log string|false Key to switch to the log buffer
---@field goto_bookmark string|false Key to switch to the bookmark buffer
---@field refresh string|false Key to refresh the buffer

---@class JujutsuBookmarkKeymaps
---@field edit string|false Key to edit the revision of the bookmark under cursor and switch to log
---@field new string|false Key to create a new revision from bookmark under cursor
---@field delete string|false Key to delete a bookmark
---@field track string|false Key to track a bookmark
---@field untrack string|false Key to untrack a bookmark
---@field toggle_all string|false Key to toggle between local and all remote bookmarks
---@field git_fetch string|false Key to run jj git fetch
---@field git_push string|false Key to run jj git push -b on cursor bookmark
---@field git_push_all string|false Key to run jj git push --all --deleted
---@field undo string|false Key to undo the last operation
---@field quit string|false Key to close the buffer
---@field goto_log string|false Key to switch to the log buffer
---@field goto_bookmark string|false Key to switch to the bookmark buffer
---@field refresh string|false Key to refresh the buffer

---@class JujutsuKeymaps
---@field log JujutsuLogKeymaps
---@field bookmark JujutsuBookmarkKeymaps

---@class JujutsuConfig
---@field keymaps JujutsuKeymaps
---@field split "vertical"|"horizontal" How to split the window when opening the log buffer
---@field cache_gpg boolean Whether to pre-cache GPG passphrase before push operations

---@type JujutsuConfig
local defaults = {
  keymaps = {
    log = {
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
      bookmark_set = "bs",
      bookmark_delete = "bd",
      bookmark_move = "bm",
      bookmark_move_backwards = "bM",
      bookmark_track = "bt",
      bookmark_untrack = "bT",
      git_fetch = "gf",
      git_push = "gp",
      git_push_all = "gP",
      quit = "q",
      goto_log = "gl",
      goto_bookmark = "gb",
      refresh = "<C-r>",
    },
    bookmark = {
      edit = "<CR>",
      new = "n",
      delete = "d",
      track = "t",
      untrack = "T",
      toggle_all = "r",
      git_fetch = "gf",
      git_push = "gp",
      git_push_all = "gP",
      undo = "u",
      quit = "q",
      goto_log = "gl",
      goto_bookmark = "gb",
      refresh = "<C-r>",
    },
  },
  split = "vertical",
  cache_gpg = false,
}

---@type JujutsuConfig
M.config = {}

---Setup the plugin
---@param opts? JujutsuConfig
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  require("jujutsu.jj").cache_gpg = M.config.cache_gpg
end

---@type integer?
local log_buf = nil
---@type integer?
local bookmark_buf = nil

local function open_split()
  local cmd = M.config.split == "vertical" and "vsplit" or "split"
  vim.cmd(cmd)
end

---Show target_buf in a window, reusing other_buf's window if visible
---@param target_buf integer
---@param other_buf integer?
local function show_buf(target_buf, other_buf)
  -- If the other buffer is visible, replace it in that window
  if other_buf and vim.api.nvim_buf_is_valid(other_buf) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == other_buf then
        vim.api.nvim_win_set_buf(win, target_buf)
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end
  -- If target buffer is already visible, focus it
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == target_buf then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  -- Otherwise open a new split
  open_split()
  vim.api.nvim_win_set_buf(0, target_buf)
end

---Run `jj log` and show the output in a new scratch buffer, reusing it if it already exists
M.log = function()
  if log_buf and vim.api.nvim_buf_is_valid(log_buf) then
    log_buffer.refresh(log_buf)
    show_buf(log_buf, bookmark_buf)
    return
  end

  log_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[log_buf].bufhidden = "wipe"

  if not log_buffer.refresh(log_buf) then
    log_buf = nil
    return
  end

  vim.bo[log_buf].filetype = "jjlog"
  log_buffer.setup_keymaps(log_buf, M.config.keymaps.log)

  show_buf(log_buf, bookmark_buf)
end

---Run `jj bookmark list` and show the output in a new scratch buffer, reusing it if it already exists
M.bookmark = function()
  if bookmark_buf and vim.api.nvim_buf_is_valid(bookmark_buf) then
    bookmark_buffer.refresh(bookmark_buf)
    show_buf(bookmark_buf, log_buf)
    return
  end

  bookmark_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[bookmark_buf].bufhidden = "wipe"
  bookmark_buffer.reset()

  if not bookmark_buffer.refresh(bookmark_buf) then
    bookmark_buf = nil
    return
  end

  vim.bo[bookmark_buf].filetype = "jjbookmark"
  bookmark_buffer.setup_keymaps(bookmark_buf, M.config.keymaps.bookmark)

  show_buf(bookmark_buf, log_buf)
end

return M
