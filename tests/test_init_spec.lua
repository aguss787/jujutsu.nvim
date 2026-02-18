---@diagnostic disable: inject-field

local function reload()
  package.loaded["jujutsu"] = nil
  package.loaded["jujutsu.log_buffer"] = nil
  return require("jujutsu")
end

describe("setup", function()
  before_each(reload)

  it("applies default keymaps when called with no args", function()
    local jujutsu = reload()
    jujutsu.setup()
    assert.equal("<CR>", jujutsu.config.keymaps.edit)
    assert.equal("m", jujutsu.config.keymaps.mark)
    assert.equal("u", jujutsu.config.keymaps.undo)
  end)

  it("merges user keymaps with defaults", function()
    local jujutsu = reload()
    jujutsu.setup({ keymaps = { edit = "e" } })
    assert.equal("e", jujutsu.config.keymaps.edit)
    assert.equal("m", jujutsu.config.keymaps.mark)
  end)

  it("updates config on repeated calls", function()
    local jujutsu = reload()
    jujutsu.setup({ keymaps = { edit = "e" } })
    jujutsu.setup({ keymaps = { edit = "E" } })
    assert.equal("E", jujutsu.config.keymaps.edit)
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
    vim.system = function(_cmd, _opts)
      return {
        wait = function()
          return { code = 0, stdout = "○  abc123 a@b.com 2024-01-01 test\n", stderr = "" }
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
end)
