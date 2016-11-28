#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'json'

name = ARGV[0]
url = ARGV[1]

puts `bundle exec arachni --report-save-path="#{name}" "#{url}"`
puts `bundle exec arachni_reporter "#{name}" --reporter=json:outfile=#{name}.json`
puts `bundle exec arachni_reporter "#{name}" --reporter=html:outfile=#{name}.zip`

report = `cat #{name}.json`
report = JSON.parse report

severe_issues = report.fetch("issues").select do |i|
  i.fetch("severity") == "high"
end

if severe_issues != 0
  issue_names = severe_issues.collect {|i| i["name"]}.join(", ")
  body = "Your app has the following severe issues: #{issue_names}.

Attached is a report detailing these vulnerabilities and how they can be resolved.

Hugs,

The App Protector Team"

  puts `./notify.rb "#{name}" "#{body}"`
end

`rm #{name}.json`
`rm #{name}.zip`
