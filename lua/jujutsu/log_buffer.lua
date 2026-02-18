local M = {}

---@type table<string, boolean>
local marked_revs = {}

local marks_ns = vim.api.nvim_create_namespace("jjlog_marks")

---Run a jj subcommand, notify on failure, return the result on success or nil on failure
---@param args string[]
---@return vim.SystemCompleted?
local function jj_run(args)
  local result = vim.system(vim.list_extend({ "jj" }, args), { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("jj " .. args[1] .. ": " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    return nil
  end
  return result
end

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

---Fetch `jj log` output and replace the contents of buf
---@param buf integer
---@return boolean success
function M.refresh(buf)
  local result = jj_run({ "log" })
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
    local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
    if not rev then
      return
    end
    if jj_run({ "edit", rev }) then
      M.refresh(buf)
    end
  end, "jj edit revision under cursor")

  map(keymaps.mark, function()
    local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
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
    local revs = resolve_revs()
    if not revs then
      return
    end
    if jj_run(vim.list_extend({ "new" }, revs)) then
      marked_revs = {}
      M.refresh(buf)
    end
  end, "jj new from revision(s)")

  map(keymaps.abandon, function()
    local revs = resolve_revs()
    if not revs then
      return
    end
    if jj_run(vim.list_extend({ "abandon" }, revs)) then
      marked_revs = {}
      M.refresh(buf)
    end
  end, "jj abandon revision(s)")

  map(keymaps.squash, function()
    local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
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
    if jj_run(cmd) then
      marked_revs = {}
      M.refresh(buf)
    end
  end, "jj squash revision into parent or marked revision")

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

  local function run_rebase(rev, source_flag, dest_flag)
    local dests = vim.tbl_keys(marked_revs)
    if #dests == 0 then
      vim.notify("jj rebase: no marked revision to rebase onto", vim.log.levels.ERROR)
      return
    end
    local cmd = { "rebase", source_flag, rev }
    for _, dest in ipairs(dests) do
      vim.list_extend(cmd, { dest_flag, dest })
    end
    if jj_run(cmd) then
      marked_revs = {}
      M.refresh(buf)
    end
  end

  map(keymaps.rebase, function()
    local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
    if not rev then
      return
    end
    run_rebase(rev, "-s", "-d")
  end, "jj rebase -s revision onto marked destination(s)")

  map(keymaps.rebase_pick, function()
    local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
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
        run_rebase(rev, source.flag, dest.flag)
      end)
    end)
  end, "jj rebase with source/destination mode picker")

  map(keymaps.undo, function()
    if jj_run({ "undo" }) then
      M.refresh(buf)
    end
  end, "jj undo")

  map(keymaps.refresh, function()
    if M.refresh(buf) then
      vim.notify("jj log: refreshed", vim.log.levels.INFO)
    end
  end, "Refresh the log buffer")

  map(keymaps.describe, function()
    local rev = vim.api.nvim_get_current_line():match("[@◉○]%s+(%w+)")
    if not rev then
      return
    end

    local result = jj_run({ "log", "-r", rev, "-T", "description", "--no-graph" })
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
        if jj_run({ "describe", "-r", rev, "-m", desc }) then
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
