if vim.g.loaded_jujutsu then
  return
end
vim.g.loaded_jujutsu = 1

vim.api.nvim_create_user_command("Jj", function(args)
  local subcmd = args.args
  if subcmd == "log" then
    require("jujutsu").log()
  else
    vim.notify("jujutsu: unknown command '" .. subcmd .. "'", vim.log.levels.ERROR)
  end
end, {
  nargs = 1,
  desc = "Jujutsu commands",
  complete = function()
    return { "log" }
  end,
})
