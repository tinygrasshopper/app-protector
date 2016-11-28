#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'json'
require 'mailgun'

app_name = ARGV[0]
body = ARGV[1]

to_email = ENV['TO_EMAIL_ADDRESS']

mailgun = Mailgun::Client.new(ENV['MAILGUN_API_KEY'])

message = Mailgun::MessageBuilder.new

message.from("postmaster@sandbox91ce36feff2d4455b2d3d85454ceaed0.mailgun.org", {"first" => "App", "last" => "Protector"})
message.add_recipient(:to, to_email)
message.subject("Vulnerabilites detected in your app #{app_name}")
message.body_text(body)
message.add_attachment("#{app_name}.zip", "report.zip")

result = mailgun.send_message("sandbox91ce36feff2d4455b2d3d85454ceaed0.mailgun.org", message)
puts result.body.to_s
