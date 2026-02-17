local T = MiniTest.new_set()

local function reload()
  package.loaded["jujutsu"] = nil
  package.loaded["jujutsu.log_buffer"] = nil
  return require("jujutsu")
end

T["setup"] = MiniTest.new_set({
  hooks = { pre_case = reload },
})

T["setup"]["applies default config when called with no args"] = function()
  local jujutsu = reload()
  jujutsu.setup()
  MiniTest.expect.equality(jujutsu.config.field, "value")
end

T["setup"]["merges user opts with defaults"] = function()
  local jujutsu = reload()
  jujutsu.setup({ field = "custom" })
  MiniTest.expect.equality(jujutsu.config.field, "custom")
end

T["setup"]["updates config on repeated calls"] = function()
  local jujutsu = reload()
  jujutsu.setup({ field = "first" })
  jujutsu.setup({ field = "second" })
  MiniTest.expect.equality(jujutsu.config.field, "second")
end

T["setup"]["does not error when called with no args"] = function()
  MiniTest.expect.no_error(function()
    reload().setup()
  end)
end

return T
