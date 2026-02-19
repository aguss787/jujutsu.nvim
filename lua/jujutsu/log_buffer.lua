local M = {}

---@type table<string, boolean>
local marked_revs = {}

local marks_ns = vim.api.nvim_create_namespace("jjlog_marks")
local jj = require("jujutsu.jj")

local REV_PATTERN = "[@◉○◆]%s+(%w+)"

---Extract the revision ID from the current line, or nil if none
---@return string?
local function cursor_rev()
  return vim.api.nvim_get_current_line():match(REV_PATTERN)
end

---Re-apply mark highlights to buf based on marked_revs
---@param buf integer
local function apply_mark_highlights(buf)
  vim.api.nvim_buf_clear_namespace(buf, marks_ns, 0, -1)
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local rev = line:match(REV_PATTERN)
    if rev and marked_revs[rev] then
      vim.api.nvim_buf_set_extmark(buf, marks_ns, i - 1, 0, { line_hl_group = "Visual" })
    end
  end
end

---Return marked revisions if any, otherwise the revision on the current line
---@return string[]?
local function resolve_revs()
  local revs = vim.tbl_keys(marked_revs)
  if #revs > 0 then
    return revs
  end
  local rev = cursor_rev()
  if rev then
    return { rev }
  end
end

---Resolve revisions, run a jj subcommand with them, clear marks and refresh
---@param buf integer
---@param subcmd string
local function revs_action(buf, subcmd)
  local revs = resolve_revs()
  if not revs then
    return
  end
  if jj.run(vim.list_extend({ subcmd }, revs)) then
    marked_revs = {}
    M.refresh(buf)
  end
end

local source_modes = {
  { flag = "-s", label = "-s   rebase revision and all descendants" },
  { flag = "-r", label = "-r   rebase single revision only" },
  { flag = "-b", label = "-b   rebase entire branch" },
}
local dest_modes = {
  { flag = "-d", label = "-d       rebase onto destination" },
  { flag = "--before", label = "--before insert before destination" },
  { flag = "--after", label = "--after  insert after destination" },
}

local dup_dest_modes = {
  { flag = "--onto", label = "--onto          duplicate onto destination" },
  { flag = "--insert-after", label = "--insert-after  insert after destination" },
  { flag = "--insert-before", label = "--insert-before insert before destination" },
}

---Run jj rebase with the given source and destination flags
---@param buf integer
---@param rev string
---@param source_flag string
---@param dest_flag string
local function run_rebase(buf, rev, source_flag, dest_flag)
  local dests = vim.tbl_keys(marked_revs)
  if #dests == 0 then
    vim.notify("jj rebase: no marked revision to rebase onto", vim.log.levels.ERROR)
    return
  end
  local cmd = { "rebase", source_flag, rev }
  for _, dest in ipairs(dests) do
    vim.list_extend(cmd, { dest_flag, dest })
  end
  if jj.run(cmd) then
    marked_revs = {}
    M.refresh(buf)
  end
end

---Fetch `jj log` output and replace the contents of buf
---@param buf integer
---@return boolean success
function M.refresh(buf)
  local result = jj.run({ "log" })
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
  apply_mark_highlights(buf)
  return true
end

---Set up buffer-local keymaps for the log buffer
---@param buf integer
---@param keymaps table<string, string|false>
function M.setup_keymaps(buf, keymaps)
  local function map(key, fn, desc)
    if key ~= false then
      vim.keymap.set("n", key, fn, { buffer = buf, desc = desc })
    end
  end

  map(keymaps.edit, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    if jj.run({ "edit", rev }) then
      M.refresh(buf)
    end
  end, "jj edit revision under cursor")

  map(keymaps.mark, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    marked_revs[rev] = not marked_revs[rev] or nil
    apply_mark_highlights(buf)
  end, "Toggle mark on revision under cursor")

  map(keymaps.clear_marks, function()
    marked_revs = {}
    vim.api.nvim_buf_clear_namespace(buf, marks_ns, 0, -1)
  end, "Clear all marks")

  map(keymaps.new, function()
    revs_action(buf, "new")
  end, "jj new from revision(s)")

  map(keymaps.abandon, function()
    revs_action(buf, "abandon")
  end, "jj abandon revision(s)")

  map(keymaps.squash, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    local dests = vim.tbl_keys(marked_revs)
    local cmd
    if #dests == 0 then
      cmd = { "squash", "-r", rev }
    elseif #dests == 1 then
      cmd = { "squash", "--from", rev, "--into", dests[1] }
    else
      vim.notify("jj squash: mark a single destination revision", vim.log.levels.ERROR)
      return
    end
    if jj.run(cmd) then
      marked_revs = {}
      M.refresh(buf)
    end
  end, "jj squash revision into parent or marked revision")

  map(keymaps.rebase, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    run_rebase(buf, rev, "-s", "-d")
  end, "jj rebase -s revision onto marked destination(s)")

  map(keymaps.rebase_pick, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    vim.ui.select(source_modes, {
      prompt = "Source mode:",
      format_item = function(item)
        return item.label
      end,
    }, function(source)
      if not source then
        return
      end
      vim.ui.select(dest_modes, {
        prompt = "Destination mode:",
        format_item = function(item)
          return item.label
        end,
      }, function(dest)
        if not dest then
          return
        end
        run_rebase(buf, rev, source.flag, dest.flag)
      end)
    end)
  end, "jj rebase with source/destination mode picker")

  map(keymaps.undo, function()
    if jj.run({ "undo" }) then
      M.refresh(buf)
    end
  end, "jj undo")

  map(keymaps.git_fetch, function()
    jj.run_async("git_fetch", "fetching...", { "git", "fetch" }, function()
      M.refresh(buf)
    end)
  end, "jj git fetch")

  map(keymaps.git_push, function()
    local revs = resolve_revs()
    if not revs then
      return
    end
    local args = { "git", "push" }
    for _, rev in ipairs(revs) do
      vim.list_extend(args, { "-r", rev })
    end
    jj.run_async("git_push", "pushing...", args, function()
      marked_revs = {}
      M.refresh(buf)
    end)
  end, "jj git push revision(s)")

  map(keymaps.git_push_all, function()
    jj.run_async("git_push_all", "pushing all...", { "git", "push", "--all", "--deleted" }, function()
      M.refresh(buf)
    end)
  end, "jj git push --all --deleted")

  map(keymaps.refresh, function()
    if M.refresh(buf) then
      vim.notify("jj log: refreshed", vim.log.levels.INFO)
    end
  end, "Refresh the log buffer")

  map(keymaps.bookmark_set, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    vim.ui.input({ prompt = "Bookmark name: " }, function(name)
      if not name or name == "" then
        return
      end
      if jj.run({ "bookmark", "set", name, "-r", rev }) then
        M.refresh(buf)
      end
    end)
  end, "jj bookmark set on revision under cursor")

  map(keymaps.bookmark_delete, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    local result = jj.run({ "bookmark", "list", "-r", rev, "-T", 'name ++ "\\n"' })
    if not result then
      return
    end
    local names = vim.split(result.stdout, "\n", { plain = true, trimempty = true })
    if #names == 0 then
      vim.notify("jj bookmark delete: no bookmarks on this revision", vim.log.levels.ERROR)
      return
    end
    local function delete(name)
      if jj.run({ "bookmark", "delete", name }) then
        M.refresh(buf)
      end
    end
    if #names == 1 then
      delete(names[1])
    else
      vim.ui.select(names, { prompt = "Delete bookmark:" }, function(name)
        if name then
          delete(name)
        end
      end)
    end
  end, "jj bookmark delete on revision under cursor")

  local function bookmark_move(allow_backwards)
    local rev = cursor_rev()
    if not rev then
      return
    end
    local sources = vim.tbl_keys(marked_revs)
    if #sources == 0 then
      vim.notify("jj bookmark move: mark the source revision(s) first", vim.log.levels.ERROR)
      return
    end
    local cmd = { "bookmark", "move", "--to", rev }
    if allow_backwards then
      table.insert(cmd, "-B")
    end
    for _, source in ipairs(sources) do
      vim.list_extend(cmd, { "--from", source })
    end
    if jj.run(cmd) then
      marked_revs = {}
      M.refresh(buf)
    end
  end

  map(keymaps.bookmark_move, function()
    bookmark_move(false)
  end, "jj bookmark move from marked revision(s) to cursor revision")

  map(keymaps.bookmark_move_backwards, function()
    bookmark_move(true)
  end, "jj bookmark move --allow-backwards from marked revision(s) to cursor revision")

  local function bookmark_track_action(subcmd, prompt)
    vim.ui.input({ prompt = prompt }, function(name)
      if not name or name == "" then
        return
      end
      if not name:find("@") then
        name = name .. "@origin"
      end
      if jj.run({ "bookmark", subcmd, name }) then
        M.refresh(buf)
      end
    end)
  end

  map(keymaps.bookmark_track, function()
    bookmark_track_action("track", "Track bookmark (name or name@remote): ")
  end, "jj bookmark track")

  map(keymaps.bookmark_untrack, function()
    bookmark_track_action("untrack", "Untrack bookmark (name or name@remote): ")
  end, "jj bookmark untrack")

  local function run_duplicate(rev, dest_flag)
    local dests = vim.tbl_keys(marked_revs)
    if #dests == 0 then
      vim.notify("jj duplicate: mark the destination revision(s) first", vim.log.levels.ERROR)
      return
    end
    local cmd = { "duplicate", rev }
    for _, dest in ipairs(dests) do
      vim.list_extend(cmd, { dest_flag, dest })
    end
    if jj.run(cmd) then
      marked_revs = {}
      M.refresh(buf)
    end
  end

  map(keymaps.duplicate, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    run_duplicate(rev, "--onto")
  end, "jj duplicate revision onto marked destination(s)")

  map(keymaps.duplicate_pick, function()
    local rev = cursor_rev()
    if not rev then
      return
    end
    vim.ui.select(dup_dest_modes, {
      prompt = "Destination mode:",
      format_item = function(item)
        return item.label
      end,
    }, function(mode)
      if not mode then
        return
      end
      run_duplicate(rev, mode.flag)
    end)
  end, "jj duplicate with destination mode picker")

  map(keymaps.quit, function()
    vim.cmd("close")
  end, "Close the buffer")

  map(keymaps.goto_log, function()
    require("jujutsu").log()
  end, "Switch to log buffer")

  map(keymaps.goto_bookmark, function()
    require("jujutsu").bookmark()
  end, "Switch to bookmark buffer")

  map(keymaps.describe, function()
    local rev = cursor_rev()
    if not rev then
      return
    end

    local result = jj.run({ "log", "-r", rev, "-T", "description", "--no-graph" })
    local current_desc = result and result.stdout:gsub("\n$", "") or ""

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
        if jj.run({ "describe", "-r", rev, "-m", desc }) then
          vim.bo[desc_buf].modified = false
          M.refresh(buf)
          vim.api.nvim_buf_delete(desc_buf, { force = false })
        end
      end,
    })

    vim.cmd.split()
    vim.api.nvim_win_set_buf(0, desc_buf)
    vim.cmd.startinsert()
  end, "Set revision description")
end

return M
