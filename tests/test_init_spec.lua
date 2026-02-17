local function reload()
  package.loaded["jujutsu"] = nil
  package.loaded["jujutsu.log_buffer"] = nil
  return require("jujutsu")
end

describe("setup", function()
  before_each(reload)

  it("applies default config when called with no args", function()
    local jujutsu = reload()
    jujutsu.setup()
    assert.equal("value", jujutsu.config.field)
  end)

  it("merges user opts with defaults", function()
    local jujutsu = reload()
    jujutsu.setup({ field = "custom" })
    assert.equal("custom", jujutsu.config.field)
  end)

  it("updates config on repeated calls", function()
    local jujutsu = reload()
    jujutsu.setup({ field = "first" })
    jujutsu.setup({ field = "second" })
    assert.equal("second", jujutsu.config.field)
  end)

  it("does not error when called with no args", function()
    assert.has_no.errors(function()
      reload().setup()
    end)
  end)
end)
