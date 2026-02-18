---@diagnostic disable: inject-field

local function reload()
  package.loaded["jujutsu"] = nil
  package.loaded["jujutsu.log_buffer"] = nil
  package.loaded["jujutsu.bookmark_buffer"] = nil
  return require("jujutsu")
end

describe("setup", function()
  before_each(reload)

  it("applies default keymaps when called with no args", function()
    local jujutsu = reload()
    jujutsu.setup()
    assert.equal("<CR>", jujutsu.config.keymaps.log.edit)
    assert.equal("m", jujutsu.config.keymaps.log.mark)
    assert.equal("u", jujutsu.config.keymaps.log.undo)
    assert.equal("t", jujutsu.config.keymaps.bookmark.track)
  end)

  it("merges user keymaps with defaults", function()
    local jujutsu = reload()
    jujutsu.setup({ keymaps = { log = { edit = "e" } } })
    assert.equal("e", jujutsu.config.keymaps.log.edit)
    assert.equal("m", jujutsu.config.keymaps.log.mark)
  end)

  it("updates config on repeated calls", function()
    local jujutsu = reload()
    jujutsu.setup({ keymaps = { log = { edit = "e" } } })
    jujutsu.setup({ keymaps = { log = { edit = "E" } } })
    assert.equal("E", jujutsu.config.keymaps.log.edit)
  end)

  it("defaults split to vertical", function()
    local jujutsu = reload()
    jujutsu.setup()
    assert.equal("vertical", jujutsu.config.split)
  end)

  it("allows overriding split to horizontal", function()
    local jujutsu = reload()
    jujutsu.setup({ split = "horizontal" })
    assert.equal("horizontal", jujutsu.config.split)
  end)

  it("does not error when called with no args", function()
    assert.has_no.errors(function()
      reload().setup()
    end)
  end)
end)

describe("log", function()
  local orig_system

  before_each(function()
    orig_system = vim.system
    vim.system = function(cmd, _opts)
      local stdout = "○  abc123 a@b.com 2024-01-01 test\n"
      if cmd[2] == "bookmark" and cmd[3] == "list" then
        stdout = "master: abc123 test\n"
      end
      return {
        wait = function()
          return { code = 0, stdout = stdout, stderr = "" }
        end,
      }
    end
  end)

  after_each(function()
    vim.system = orig_system
    vim.cmd("only")
  end)

  it("opens a vertical split by default", function()
    local jujutsu = reload()
    jujutsu.setup()
    jujutsu.log()
    -- winlayout returns "row" for side-by-side (vsplit), "col" for stacked (split)
    assert.equal("row", vim.fn.winlayout()[1])
  end)

  it("opens a horizontal split when configured", function()
    local jujutsu = reload()
    jujutsu.setup({ split = "horizontal" })
    jujutsu.log()
    assert.equal("col", vim.fn.winlayout()[1])
  end)

  it("bookmark replaces log in the same window", function()
    local jujutsu = reload()
    jujutsu.setup()
    jujutsu.log()
    local win_count_after_log = #vim.api.nvim_list_wins()
    jujutsu.bookmark()
    assert.equal(win_count_after_log, #vim.api.nvim_list_wins())
    -- current buffer should be the bookmark buffer
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.truthy(lines[1]:find("master"))
  end)

  it("log replaces bookmark in the same window", function()
    local jujutsu = reload()
    jujutsu.setup()
    jujutsu.bookmark()
    local win_count_after_bookmark = #vim.api.nvim_list_wins()
    jujutsu.log()
    assert.equal(win_count_after_bookmark, #vim.api.nvim_list_wins())
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.truthy(lines[1]:find("abc123"))
  end)
end)
