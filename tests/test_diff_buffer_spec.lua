local helpers = require("tests.helpers")
local default_keymaps = helpers.default_diff_keymaps
local get_cb = helpers.get_cb
local was_called = helpers.was_called

local function reload()
  package.loaded["jujutsu.diff_buffer"] = nil
  return require("jujutsu.diff_buffer")
end

local DIFF_SUMMARY = "M lua/jujutsu/init.lua\nA lua/jujutsu/new.lua\nD lua/jujutsu/old.lua\n"
local FILE_CONTENT_BEFORE = "line1\nline2\nline3\n"
local FILE_CONTENT_AFTER = "line1\nline2_modified\nline3\nline4\n"

describe("diff_buffer", function()
  local calls, orig_system

  before_each(function()
    calls = {}
    orig_system = vim.system
    vim.system = function(cmd, _opts, on_exit)
      table.insert(calls, vim.deepcopy(cmd))
      local stdout = ""
      if cmd[2] == "diff" then
        stdout = DIFF_SUMMARY
      elseif cmd[2] == "file" and cmd[3] == "show" then
        if cmd[4] == "-r" and cmd[5]:match("%-$") then
          stdout = FILE_CONTENT_BEFORE
        else
          stdout = FILE_CONTENT_AFTER
        end
      end
      local result = { code = 0, stdout = stdout, stderr = "" }
      if on_exit then
        on_exit(result)
        return
      end
      return {
        wait = function()
          return result
        end,
      }
    end
  end)

  after_each(function()
    vim.system = orig_system
    while vim.fn.tabpagenr("$") > 1 do
      vim.cmd("tabclose!")
    end
  end)

  it("open calls jj diff --summary for the revision", function()
    reload().open("abc123", default_keymaps)
    assert.is_true(was_called(calls, { "jj", "diff", "-r", "abc123", "--summary" }))
  end)

  it("creates a tab with 3 windows", function()
    reload().open("abc123", default_keymaps)
    assert.equal(3, #vim.api.nvim_tabpage_list_wins(0))
  end)

  it("populates file list with changed files", function()
    reload().open("abc123", default_keymaps)
    local list_buf = vim.fn.bufnr("jj://diff/abc123/files")
    assert.is_true(list_buf ~= -1)
    local lines = vim.api.nvim_buf_get_lines(list_buf, 0, -1, false)
    assert.equal(3, #lines)
    assert.equal("M lua/jujutsu/init.lua", lines[1])
    assert.equal("A lua/jujutsu/new.lua", lines[2])
    assert.equal("D lua/jujutsu/old.lua", lines[3])
  end)

  it("auto-loads first file diff on open", function()
    reload().open("abc123", default_keymaps)
    assert.is_true(was_called(calls, { "jj", "file", "show", "-r", "abc123-", "lua/jujutsu/init.lua" }))
    assert.is_true(was_called(calls, { "jj", "file", "show", "-r", "abc123", "lua/jujutsu/init.lua" }))
  end)

  it("Enter on file list loads that file diff", function()
    local db = reload()
    db.open("abc123", default_keymaps)
    local list_buf = vim.fn.bufnr("jj://diff/abc123/files")
    calls = {}
    vim.api.nvim_buf_call(list_buf, function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      get_cb(list_buf, "<CR>")()
    end)
    -- Added file: only after content should be fetched
    assert.is_true(was_called(calls, { "jj", "file", "show", "-r", "abc123", "lua/jujutsu/new.lua" }))
    assert.is_false(was_called(calls, { "jj", "file", "show", "-r", "abc123-", "lua/jujutsu/new.lua" }))
  end)

  it("deleted file skips fetching after-content", function()
    local db = reload()
    db.open("abc123", default_keymaps)
    local list_buf = vim.fn.bufnr("jj://diff/abc123/files")
    calls = {}
    vim.api.nvim_buf_call(list_buf, function()
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      get_cb(list_buf, "<CR>")()
    end)
    -- Deleted file: only before content should be fetched
    assert.is_true(was_called(calls, { "jj", "file", "show", "-r", "abc123-", "lua/jujutsu/old.lua" }))
    assert.is_false(was_called(calls, { "jj", "file", "show", "-r", "abc123", "lua/jujutsu/old.lua" }))
  end)

  it("q closes the diff tab", function()
    local db = reload()
    local tab_count_before = vim.fn.tabpagenr("$")
    db.open("abc123", default_keymaps)
    assert.equal(tab_count_before + 1, vim.fn.tabpagenr("$"))
    local list_buf = vim.fn.bufnr("jj://diff/abc123/files")
    get_cb(list_buf, "q")()
    assert.equal(tab_count_before, vim.fn.tabpagenr("$"))
  end)

  it("highlights the currently shown file in the file list", function()
    local db = reload()
    db.open("abc123", default_keymaps)
    local list_buf = vim.fn.bufnr("jj://diff/abc123/files")
    local select_ns = vim.api.nvim_create_namespace("jjdiff_select")

    -- First file should be highlighted on open
    local marks = vim.api.nvim_buf_get_extmarks(list_buf, select_ns, 0, -1, { details = true })
    assert.equal(1, #marks)
    assert.equal(0, marks[1][2]) -- line 0 (first file)
    assert.equal("Visual", marks[1][4].line_hl_group)

    -- Switch to second file
    vim.api.nvim_buf_call(list_buf, function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      get_cb(list_buf, "<CR>")()
    end)
    marks = vim.api.nvim_buf_get_extmarks(list_buf, select_ns, 0, -1, { details = true })
    assert.equal(1, #marks)
    assert.equal(1, marks[1][2]) -- line 1 (second file)
  end)

  it("notifies when no changes in revision", function()
    vim.system = function(cmd, _opts, on_exit)
      table.insert(calls, vim.deepcopy(cmd))
      local result = { code = 0, stdout = "", stderr = "" }
      if on_exit then
        on_exit(result)
        return
      end
      return {
        wait = function()
          return result
        end,
      }
    end
    local notified = false
    local orig_notify = vim.notify
    vim.notify = function()
      notified = true
    end
    reload().open("abc123", default_keymaps)
    vim.notify = orig_notify
    assert.is_true(notified)
  end)
end)
