require 'plist'

# Markdown table character length without any issues
MAKRDOWN_LENGTH = 138

modifed_libs = Set[]
for file in (git.modified_files + git.added_files);
    l = file.split("libs/").last.split("/").first
    print "lib: #{l}\n"
    modifed_libs.add(l)
end

print "modifed libs: #{modifed_libs}\n"
print "modifed libs as list: [ #{modifed_libs.join(", ")} ]\n"
# TODO: REMOVE THIS
modifed_libs.delete(".github")

# TODO: USE THIS
# If we are modifiing CI run all tests.
# if modifed_libs.inclues?(".github")
#     modifed_libs = ['SalesforceSDKCommon', 'SalesforceAnalytics', 'SalesforceSDKCore', 'SmartStore', 'MobileSync']
# end


# Set Github Job output so we know which tests to run
ENV['GITHUB_OUTPUT'] = "[ #{modifed_libs.join(", ")} ]"

files = Set[]
for lib in modifed_libs;
    files.merge(Dir["../libs/SalesforceAnalytics/clangReport/StaticAnalyzer/#{lib}/#{lib}/normal/**/*.plist"])
end

modified_file_names = git.modified_files.map { |file| File.basename(file, File.extname(file)) }
added_file_names = git.added_files.map { |file| File.basename(file, File.extname(file)) }

# Github PR comment header
message = "### Clang Static Analysis Issues\n\n"
message << "File | Type | Category | Description | Line | Col |\n"
message << " --- | ---- | -------- | ----------- | ---- | --- |\n"

# Parse Clang Plist files and report issues associated with files modified or added in this PR.
for file in files;
    report = Plist.parse_xml(file)
    report_file_name = File.basename(file, File.extname(file))
    print "file name: #{report_file_name}\n"

    if modified_file_names.include?(report_file_name) || added_file_names.include?(report_file_name)
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