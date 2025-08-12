#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Browse Pure Function Tests")

local browse = runner.load_module("jj-fugitive.browse")

runner.section("Parse remote URL formats")
local cases = {
  { "git@github.com:user/repo.git", "github.com", "user", "repo", "https://github.com/user/repo" },
  {
    "ssh://git@github.com/user/repo.git",
    "github.com",
    "user",
    "repo",
    "https://github.com/user/repo",
  },
  { "https://github.com/user/repo", "github.com", "user", "repo", "https://github.com/user/repo" },
  {
    "https://github.com/user/repo.git",
    "github.com",
    "user",
    "repo",
    "https://github.com/user/repo",
  },
}

for i, c in ipairs(cases) do
  local info, err = browse.parse_remote_url(c[1])
  runner.assert_test("Case " .. i .. ": parsed", info ~= nil, err or "should parse")
  if info then
    runner.assert_test("host ok", info.host == c[2], "host mismatch")
    runner.assert_test("owner ok", info.owner == c[3], "owner mismatch")
    runner.assert_test("repo ok", info.repo == c[4], "repo mismatch")
    runner.assert_test("web url ok", info.web_base == c[5], "web url mismatch")
  end
end

runner.section("Build GitHub file URL")
do
  local url = browse.build_file_url(
    "https://github.com/user/repo",
    "github.com",
    "path/to/file.txt",
    "main",
    10,
    20
  )
  runner.assert_test(
    "GH url with range",
    url == "https://github.com/user/repo/blob/main/path/to/file.txt#L10-L20",
    url or ""
  )
  local url2 = browse.build_file_url(
    "https://github.com/user/repo",
    "github.com",
    "path/to/file.txt",
    "main",
    5,
    5
  )
  runner.assert_test(
    "GH url single line",
    url2 == "https://github.com/user/repo/blob/main/path/to/file.txt#L5",
    url2 or ""
  )
end

runner.finish()
