local status = require("jj-fugitive.status")

describe("jj-fugitive status", function()
  it("can be required", function()
    assert.is_not_nil(status)
  end)

  it("has show_status function", function()
    assert.is_function(status.show_status)
  end)
  
  -- Note: Testing the full status functionality would require
  -- a jj repository and mocking vim APIs, which is complex
  -- for this basic test setup. Integration tests would be
  -- better handled in a separate test environment.
end)