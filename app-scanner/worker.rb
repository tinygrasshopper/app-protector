#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'json'
require "net/http"
require "uri"

name = ARGV[0]
url = ARGV[1]

def response_code_404(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  puts "Pooling #{url} response.code #{response.code}"

  response.code == 404
end

counter = 0

while response_code_404(url)
  break if counter > 5000
  sleep 1
  counter = counter.next
end

puts `bundle exec arachni --report-save-path="#{name}" "#{url}"`
puts `bundle exec arachni_reporter "#{name}" --reporter=json:outfile=#{name}.json`
puts `bundle exec arachni_reporter "#{name}" --reporter=html:outfile=#{name}.zip`

report = `cat #{name}.json`
report = JSON.parse report

severe_issues = report.fetch("issues").select do |i|
  i.fetch("severity") == "high"
end

if severe_issues != 0
  issue_names = []
  severe_issues.each { |i| issue_names << i["name"] }
  body = "Your app has the following severe issues: #{issue_names.join(", ")}.

Attached is a report detailing these vulnerabilities and how they can be resolved.

Hugs,

The App Protector Team"

  puts "Will send email: #{body}"
  puts `./notify.rb "#{name}" "#{body}"`
end

`rm #{name}.json`
`rm #{name}.zip`
