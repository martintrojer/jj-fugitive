local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["log"] = new_set()

T["log"]["module loads"] = function()
  local m = require("jj-fugitive.log")
  eq(type(m.show), "function")
  eq(type(m.refresh), "function")
  eq(type(m.is_open), "function")
  eq(type(m.setup_detail_keymaps), "function")
end

return T
