require 'json'

puts "contents of env var: #{ENV['TEST_CREDENTAILS']}"


file = File.open "./shared/test/test_credentials.json"
data = JSON.load file

puts "redirect from file: #{data['test_redirect_uri']}"