local helpers = require("tests.helpers")
local default_keymaps = helpers.default_bookmark_keymaps
local get_cb = helpers.get_cb
local was_called = helpers.was_called

local function reload()
  package.loaded["jujutsu.bookmark_buffer"] = nil
  return require("jujutsu.bookmark_buffer")
end

-- refresh ---------------------------------------------------------------------

describe("bookmark refresh", function()
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].modifiable = false
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("returns false outside a jj repo", function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local orig = vim.fn.getcwd()
    vim.cmd("cd " .. tmp)

    local ok = reload().refresh(buf)

    vim.cmd("cd " .. orig)
    vim.fn.delete(tmp, "rf")

    assert.is_false(ok)
  end)

  it("registers track and untrack keymaps", function()
    reload().setup_keymaps(buf, default_keymaps)
    local lhs_set = {}
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      lhs_set[km.lhs] = true
    end
    assert.truthy(lhs_set["q"])
    assert.truthy(lhs_set["m"])
    assert.truthy(lhs_set["M"])
    assert.truthy(lhs_set["t"])
    assert.truthy(lhs_set["T"])
  end)

  if vim.fn.executable("jj") == 1 then
    it("populates buffer with jj bookmark list output", function()
      local ok = reload().refresh(buf)
      assert.is_true(ok)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.is_true(#lines > 0)
    end)

    it("leaves buffer unmodifiable after a successful refresh", function()
      reload().refresh(buf)
      assert.is_false(vim.bo[buf].modifiable)
    end)
  end
end)

-- track / untrack ---------------------------------------------------------------

local BOOKMARK_LINE1 = "master: abc12345 some commit"
local BOOKMARK_LINE2 = "feature: def67890 another commit"

describe("bookmark buffer operations", function()
  local buf, calls, orig_system

  before_each(function()
    calls = {}
    orig_system = vim.system
    vim.system = function(cmd, _opts, on_exit)
      table.insert(calls, vim.deepcopy(cmd))
      local stdout = ""
      if cmd[2] == "bookmark" and cmd[3] == "list" then
        stdout = BOOKMARK_LINE1 .. "\n" .. BOOKMARK_LINE2 .. "\n"
      end
      local result = { code = 0, stdout = stdout, stderr = "" }
      if on_exit then
        on_exit(result)
        return
      end
      return { wait = function() return result end }
    end

    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { BOOKMARK_LINE1, BOOKMARK_LINE2 })
    vim.bo[buf].modifiable = false
    reload().setup_keymaps(buf, default_keymaps)
  end)

  after_each(function()
    vim.system = orig_system
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("edit calls jj edit and switches to log buffer", function()
    local log_called = false
    local jujutsu = require("jujutsu")
    local orig_log = jujutsu.log
    jujutsu.log = function() log_called = true end
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "<CR>")()
    end)
    jujutsu.log = orig_log
    assert.is_true(was_called(calls, { "jj", "edit", "master" }))
    assert.is_true(log_called)
  end)

  it("new calls jj new and switches to log buffer", function()
    local log_called = false
    local jujutsu = require("jujutsu")
    local orig_log = jujutsu.log
    jujutsu.log = function() log_called = true end
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "n")()
    end)
    jujutsu.log = orig_log
    assert.is_true(was_called(calls, { "jj", "new", "master" }))
    assert.is_true(log_called)
  end)

  it("delete calls jj bookmark delete on cursor bookmark", function()
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "d")()
    end)
    assert.is_true(was_called(calls, { "jj", "bookmark", "delete", "master" }))
  end)

  it("track calls jj bookmark track with @origin on cursor bookmark", function()
    local notified
    local orig_notify = vim.notify
    vim.notify = function(msg, level) notified = { msg = msg, level = level } end
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "t")()
    end)
    vim.notify = orig_notify
    assert.is_true(was_called(calls, { "jj", "bookmark", "track", "master@origin" }))
    assert.equal("jj bookmark track: master@origin", notified.msg)
  end)

  it("untrack calls jj bookmark untrack with @origin on cursor bookmark", function()
    local notified
    local orig_notify = vim.notify
    vim.notify = function(msg, level) notified = { msg = msg, level = level } end
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      get_cb(buf, "T")()
    end)
    vim.notify = orig_notify
    assert.is_true(was_called(calls, { "jj", "bookmark", "untrack", "feature@origin" }))
    assert.equal("jj bookmark untrack: feature@origin", notified.msg)
  end)

  it("track preserves existing @remote in bookmark name", function()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "my-branch@origin: abc12345 some commit" })
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "t")()
    end)
    assert.is_true(was_called(calls, { "jj", "bookmark", "track", "my-branch@origin" }))
  end)

  it("toggle_all refreshes with --all-remotes then back to local", function()
    get_cb(buf, "r")()
    assert.is_true(was_called(calls, { "jj", "bookmark", "list", "--color=always", "--all-remotes" }))

    calls = {}
    get_cb(buf, "r")()
    assert.is_true(was_called(calls, { "jj", "bookmark", "list", "--color=always" }))
  end)

  it("git_fetch calls jj git fetch", function()
    get_cb(buf, "gf")()
    assert.is_true(was_called(calls, { "jj", "git", "fetch" }))
  end)

  it("git_push calls jj git push -b with cursor bookmark", function()
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "gp")()
    end)
    assert.is_true(was_called(calls, { "jj", "git", "push", "-b", "master" }))
  end)

  it("git_push_all calls jj git push --all --deleted", function()
    get_cb(buf, "gP")()
    assert.is_true(was_called(calls, { "jj", "git", "push", "--all", "--deleted" }))
  end)

  it("undo calls jj undo", function()
    get_cb(buf, "u")()
    assert.is_true(was_called(calls, { "jj", "undo" }))
  end)

  it("delete acts on marked bookmark instead of cursor", function()
    -- cursor on line 1 (master), mark line 2 (feature)
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      get_cb(buf, "m")() -- mark feature
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "d")()
    end)
    assert.is_true(was_called(calls, { "jj", "bookmark", "delete", "feature" }))
  end)

  it("track acts on marked bookmark instead of cursor", function()
    local orig_notify = vim.notify
    vim.notify = function() end
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      get_cb(buf, "m")() -- mark feature
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "t")()
    end)
    vim.notify = orig_notify
    assert.is_true(was_called(calls, { "jj", "bookmark", "track", "feature@origin" }))
  end)

  it("clear_marks causes next operation to use cursor bookmark", function()
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      get_cb(buf, "m")() -- mark feature
      get_cb(buf, "M")() -- clear marks
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      get_cb(buf, "d")()
    end)
    assert.is_true(was_called(calls, { "jj", "bookmark", "delete", "master" }))
  end)
end)
