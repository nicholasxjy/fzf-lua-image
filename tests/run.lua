vim.opt.runtimepath:prepend(vim.fn.getcwd())
if vim.env.FZF_LUA_PATH then
  vim.opt.runtimepath:append(vim.env.FZF_LUA_PATH)
end

local H = require("tests.helpers")
local suites = { "util", "terminal", "convert", "image", "integration" }
local failed, passed = 0, 0
for _, suite in ipairs(suites) do
  local ok, tests = pcall(require, "tests." .. suite)
  if not ok then
    failed = failed + 1
    print("FAIL " .. suite .. ": " .. tostring(tests))
  else
    for _, test in ipairs(tests) do
      H.reset()
      local success, err = xpcall(test[2], debug.traceback)
      if success then
        passed = passed + 1
        print("PASS " .. suite .. ": " .. test[1])
      else
        failed = failed + 1
        print("FAIL " .. suite .. ": " .. test[1] .. "\n" .. tostring(err))
      end
      H.cleanup()
    end
  end
end
print(("%d passed, %d failed"):format(passed, failed))
vim.cmd(failed == 0 and "qa!" or "cquit 1")
