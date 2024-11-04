# List of supported xcode schemes for testing
SCHEMES = ['SalesforceSDKCommon', 'SalesforceAnalytics', 'SmartStore']
# SCHEMES = ['SalesforceSDKCommon', 'SalesforceAnalytics', 'SalesforceSDKCore', 'SmartStore', 'MobileSync']

modifed_libs = Set[]
for file in (git.modified_files + git.added_files);
    scheme = file.split("libs/").last.split("/").first
    print "lib: #{scheme}\n"
    if scheme == '.github'
        # If CI files are modified, run all tests
        modifed_libs.merge(SCHEMES)
    elsif SCHEMES.include?(scheme) 
        modifed_libs.add(scheme)
    end
end

# TODO: REMOVE THIS
modifed_libs.delete(".github")
print "modifed libs: #{modifed_libs}\n"
print "modifed libs as list: [#{modifed_libs.join(", ")}]\n"

# Set Github Job output so we know which tests to run
json_libs = modifed_libs.map { |l| "'#{l}'"}.join(", ")
`echo "libs=[#{json_libs}]" >> $GITHUB_OUTPUT`
