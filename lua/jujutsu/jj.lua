local M = {}

---@type boolean
M.cache_gpg = false

local progress = require("jujutsu.progress")

---Ensure the GPG passphrase is cached in gpg-agent, prompting if needed.
---Calls callback() when ready, or does nothing if the user cancels.
---@param callback function
local function ensure_gpg_cached(callback)
  vim.system(
    { "gpg", "--batch", "--no-tty", "--pinentry-mode", "error", "--sign", "--output", "/dev/null", "/dev/null" },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code == 0 then
          callback()
          return
        end
        local passphrase = vim.fn.inputsecret("GPG passphrase: ")
        if not passphrase or passphrase == "" then
          return
        end
        vim.system({
          "gpg",
          "--batch",
          "--no-tty",
          "--passphrase-fd",
          "0",
          "--pinentry-mode",
          "loopback",
          "--sign",
          "--output",
          "/dev/null",
          "/dev/null",
        }, { text = true, stdin = passphrase }, function(cache_result)
          vim.schedule(function()
            if cache_result.code ~= 0 then
              vim.notify(
                "GPG: failed to cache passphrase: " .. (cache_result.stderr or "unknown error"),
                vim.log.levels.ERROR
              )
              return
            end
            callback()
          end)
        end)
      end)
    end
  )
end

---Run a jj subcommand, notify on failure, return the result on success or nil on failure
---@param args string[]
---@return vim.SystemCompleted?
function M.run(args)
  local result = vim.system(vim.list_extend({ "jj" }, args), { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("jj " .. args[1] .. ": " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    return nil
  end
  return result
end

---Run a jj subcommand asynchronously with progress notifications
---@param id string progress ID
---@param msg string progress message
---@param args string[] jj subcommand args (without "jj" prefix)
---@param on_success function callback on success
function M.run_async(id, msg, args, on_success)
  progress.start(id, msg)
  vim.system(vim.list_extend({ "jj" }, args), { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        progress.stop(id, " " .. (result.stderr or "unknown error"))
        return
      end
      on_success()
      progress.stop(id, "done")
    end)
  end)
end

---Run a jj git push asynchronously, pre-caching GPG passphrase if configured.
---@param id string progress ID
---@param msg string progress message
---@param args string[] jj subcommand args (without "jj" prefix)
---@param on_success function callback on success
function M.push_async(id, msg, args, on_success)
  if M.cache_gpg then
    ensure_gpg_cached(function()
      M.run_async(id, msg, args, on_success)
    end)
  else
    M.run_async(id, msg, args, on_success)
  end
end

return M
