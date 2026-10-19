#!/usr/bin/env ruby
# Run with the same XCODE_XCCONFIG_FILE override as the CI Flutter build.
require 'json'
require 'open3'

project = File.expand_path('../Runner.xcodeproj', __dir__)
output, errors, status = Open3.capture3(
  'xcodebuild', '-project', project, '-alltargets', '-configuration', 'Release',
  '-showBuildSettings', '-json'
)
abort errors unless status.success?

targets = JSON.parse(output).select { |entry| %w[Runner PlannerWidget].include?(entry['target']) }
targets = targets.uniq { |entry| entry['target'] }
abort 'FAIL: missing app/widget signing settings' unless targets.size == 2

failures = targets.map do |entry|
  settings = entry.fetch('buildSettings')
  identity = settings['CODE_SIGN_IDENTITY']
  style = settings['CODE_SIGN_STYLE']
  allowed = settings['CODE_SIGNING_ALLOWED']
  puts "#{entry['target']}: identity=#{identity}, style=#{style}, allowed=#{allowed}"
  next if identity == '-' && style == 'Manual' && allowed == 'YES'

  "#{entry['target']} still requires certificate-based signing or disables signing entirely"
end.compact
abort "FAIL: #{failures.join('; ')}" unless failures.empty?
puts 'PASS: app and widget use certificate-free ad-hoc signing in CI'
