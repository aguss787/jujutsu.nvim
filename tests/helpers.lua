local M = {}

package.loaded["jujutsu"] = nil
local jujutsu = require("jujutsu")
jujutsu.setup()
M.default_keymaps = vim.deepcopy(jujutsu.config.keymaps)
M.default_log_keymaps = M.default_keymaps.log
M.default_bookmark_keymaps = M.default_keymaps.bookmark

return M
