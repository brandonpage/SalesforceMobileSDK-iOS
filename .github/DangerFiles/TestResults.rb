require 'json'

xcode_summary.ignores_warnings = true
xcode_summary.inline_mode = true
xcode_summary.report '../../test.xcresult'

# Only print on PR if tests failed.
test_failures = JSON.parse(xcode_summary.warning_error_count)['errors']
xcode_summary.test_summary(test_failures > 0)