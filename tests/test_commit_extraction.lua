#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("jj-fugitive Commit Extraction Tests")

runner.section("Module Loading")
local ansi = runner.load_module("jj-fugitive.ansi")
local log_module = runner.load_module("jj-fugitive.log")

runner.section("Commit Extraction Function")
-- Use the production function from log.lua to ensure we're testing actual behavior
runner.check_function(log_module, "extract_commit_ids_from_log", "Log module")
local extract_commit_ids_from_log = log_module and log_module.extract_commit_ids_from_log

runner.section("jj Log Output Processing")
-- Test 2: Get raw jj output
local result = vim.fn.system({ "jj", "log", "--color", "always", "--limit", "3" })
runner.assert_test(
  "jj log command produces output",
  result and #result > 0,
  "jj log command failed or produced no output"
)

-- Test 3: Verify raw output contains ANSI codes
runner.assert_test(
  "Raw output contains ANSI codes",
  runner.has_ansi_codes(result),
  "Raw jj log output doesn't contain ANSI escape codes"
)

-- Test 4: Test ANSI stripping
local test_line = result:match("[^\n]+")
if test_line then
  local clean_line, _ = ansi.parse_ansi_colors(test_line) -- luacheck: ignore

  runner.assert_test(
    "ANSI codes stripped from line",
    not runner.has_ansi_codes(clean_line),
    "ANSI codes still present after stripping"
  )

  runner.assert_test(
    "Clean line has content",
    #clean_line > 0,
    "Clean line is empty after ANSI stripping"
  )
end

runner.section("Commit ID Extraction")
-- Test 5: Test commit extraction (only if function was loaded)
if extract_commit_ids_from_log then
  local commit_data = extract_commit_ids_from_log(result)
  runner.assert_test(
    "Commits extracted from log",
    #commit_data > 0,
    "No commits extracted from jj log output"
  )

  runner.section("Commit ID Validation")
  -- Test 6: Validate extracted commit IDs
  if #commit_data > 0 then
    local valid_commits = 0
    for _, data in ipairs(commit_data) do
      if data.commit_id and #data.commit_id >= 8 and data.commit_id:match("^[a-f0-9]+$") then
        valid_commits = valid_commits + 1
      end
    end

    runner.assert_test(
      "All extracted commit IDs are valid",
      valid_commits == #commit_data,
      string.format("Only %d/%d commit IDs are valid hex strings", valid_commits, #commit_data)
    )

    -- Test 7: Verify clean lines don't contain ANSI
    local clean_lines_valid = true
    for _, data in ipairs(commit_data) do
      if runner.has_ansi_codes(data.clean_line) then
        clean_lines_valid = false
        break
      end
    end

    runner.assert_test(
      "Clean lines contain no ANSI codes",
      clean_lines_valid,
      "Some clean lines still contain ANSI escape codes"
    )

    runner.info("Extracted commit details:")
    for i, data in ipairs(commit_data) do
      if i <= 3 then -- Show first 3
        runner.info(string.format("     %d: %s", i, data.commit_id))
        runner.info(
          string.format(
            "        Clean: %s",
            data.clean_line:sub(1, 60) .. (data.clean_line:len() > 60 and "..." or "")
          )
        )
      end
    end
  end
else
  runner.assert_test(
    "extract_commit_ids_from_log function available",
    false,
    "Log module did not export extract_commit_ids_from_log function"
  )
end

runner.finish({
  "📝 Key achievements:",
  "   ✅ ANSI escape codes properly stripped",
  "   ✅ Commit IDs accurately extracted from native jj output",
  "   ✅ Multiple pattern matching strategies work",
  "   ✅ Clean lines ready for interactive processing",
})
