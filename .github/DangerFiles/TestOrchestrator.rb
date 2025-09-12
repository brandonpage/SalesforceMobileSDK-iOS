#!/usr/bin/env ruby

# List of supported xcode schemes for testing
SCHEMES = ['SalesforceSDKCommon', 'SalesforceAnalytics', 'SalesforceSDKCore', 'SmartStore', 'MobileSync']

# Set Github Job output so we know which tests to run
json_libs = SCHEMES.map { |l| "'#{l}'"}.join(", ")
`echo "libs=[#{json_libs}]" >> $GITHUB_OUTPUT`