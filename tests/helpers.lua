local M = {}

package.loaded["jujutsu"] = nil
local jujutsu = require("jujutsu")
jujutsu.setup()
M.default_keymaps = vim.deepcopy(jujutsu.config.keymaps)

return M
