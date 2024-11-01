require 'plist'

# xcode_summary.inline_mode = true
# xcode_summary.report '../test.xcresult'

# Markdown table character length without any issues
MAKRDOWN_LENGTH = 138
lib = danger.env.danger_id

message = "### Clang Static Analysis Issues\n\n"
message << "File | Type | Category | Description | Line | Col |\n"
message << " --- | ---- | -------- | ----------- | ---- | --- |\n"

print "Modified files:\n"
modified_files = git.modified_files.map { |file| File.basename(file, File.extname(file)) }
for m in modified_files;
    print "#{m}\n"
end

added_files = git.added_files.map { |file| File.basename(file, File.extname(file)) }

# Parse Clang Plist files and report issues associated with files modified in this PR.
files = Dir["../libs/SalesforceAnalytics/clangReport/StaticAnalyzer/#{lib}/#{lib}/normal/**/*.plist"]
for file in files;
    report = Plist.parse_xml(file)
    print "report: #{report}"

    file_name = File.basename(file, File.extname(file))
    print "File: #{file_name}\n"

    if modified_files.include?(file_name) || added_files.include?(file_name)
        print "file match! #{file}"
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