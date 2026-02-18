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

  it("does not error when called with no args", function()
    assert.has_no.errors(function()
      reload().setup()
    end)
  end)
end)
