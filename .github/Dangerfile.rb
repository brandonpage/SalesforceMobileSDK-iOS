require 'plist'

# xcode_summary.inline_mode = true
# xcode_summary.report '../test.xcresult'

# Markdown table character length without any issues
MAKRDOWN_LENGTH = 138
lib = danger.env.danger_id

message = "### Clang Static Analysis Issues\n\n"
message << "File | Type | Category | Description | Line | Col |\n"
message << " --- | ---- | -------- | ----------- | ---- | --- |\n"

# print "Modified files:"
# for m in git.modified_files;
#     print "\n#{m}"
# end
# print "\nAdded files:"
# for a in git.added_files;
#     print "\n#{a}"
# end
# print "\n\n"

# print "\nlib: #{lib}\n"
print "\npwd: #{system('pwd')}\n"
print "\nls: #{system('ls')}\n"
print "\nls (../): #{system('ls ../')}\n"
print "\nls (SA): #{system("ls ./libs/SalesforceAnalytics/clangReport/StaticAnalyzer/#{lib}/#{lib}/normal/")}\n"

# Parse Clang Plist files and report issues associated with files modified in this PR.
files = Dir["../libs/SalesforceAnalytics/clangReport/StaticAnalyzer/#{lib}/#{lib}/normal/**/*.plist"]
for file in files;
    print "\nfile: #{file}"
    report = Plist.parse_xml(file)

    if git.modified_files.include?(file) || git.added_files.include?(file)
        issues = report['diagnostics']
        for i in 0..issues.count-1
            unless issues[i].nil?
            message << "#{file_path.split('/').last} | #{issues[i]['type']} | #{issues[i]['category']} | #{issues[i]['description']} | #{issues[i]['location']['line']} | #{issues[i]['location']['col']}\n"
            end
        end
    end
end

# Only print Static Analysis table if there are issues
if message.length > MAKRDOWN_LENGTH
  warn('Static Analysis found an issue with one or more files you modified.  Please fix the issue(s).')
  markdown message
end