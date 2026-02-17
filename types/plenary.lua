---@meta

---@class LuassertHasNo
---@field errors fun(fn: function)

---@class Luassert
---@field truthy fun(value: any)
---@field falsy fun(value: any)
---@field is_true fun(value: any)
---@field is_false fun(value: any)
---@field equal fun(expected: any, actual: any)
---@field has_no LuassertHasNo

assert = assert --[[@as Luassert]]
