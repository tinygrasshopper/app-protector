require 'json'
require 'date'
require 'open-uri'
require 'httparty'

class App
  attr_reader :name, :url, :org_name, :space_name

  def initialize(name:, url:, org_name:, space_name:)
    @name, @url, @org_name, @space_name = name, url, org_name, space_name
  end
end

def login_to_cf
  %x(./cf api #{ENV.fetch('API_URL')} --skip-ssl-validation)
  %x(./cf auth #{ENV.fetch('USERNAME')} #{ENV.fetch('PASSWORD')})
end

def target_space
  %x(./cf target -o system -s system)
end

def result(timestamp)
  path = "/v2/events?q=type:audit.app.create&q=timestamp>#{timestamp}"
  encoded_path = URI::encode(path)
  puts encoded_path
  raw = %x(./cf curl \"#{encoded_path}\")
  body = JSON.parse(raw)
  results = body.fetch('resources')
  filtered_results = results.select { |result| result.fetch('entity').fetch('space_guid') == ENV.fetch('SPACE_GUID') }
end

def results_since(time)
  timestamp = time.strftime('%FT%TZ')
  result(timestamp)
end

def apps_from(app_results)
  app_results.map do |app|
    app_guid = app.fetch("entity").fetch("actee")
    app_name = app.fetch("entity").fetch("actee_name")
    org_name = "system"
    space_name = "system"
    raw_routes_results = %x(cf curl /v2/apps/#{app_guid}/routes)

    routes_results = JSON.parse(raw_routes_results)
    host = routes_results.fetch("resources").first.fetch("entity").fetch("host")
    domain_path = routes_results.fetch("resources").first.fetch("entity").fetch("domain_url")
    raw_domain_result = %x(cf curl #{domain_path})

    domain_result = JSON.parse(raw_domain_result)
    domain = domain_result.fetch("entity").fetch("name")
    url = "http://#{host}.#{domain}"
    App.new(name: app_name, url: url, org_name: org_name, space_name: space_name)
  end
end

def trigger_pen_test_with app
  body = {
    site: app.url,
    app_name: app.name,
    org_name: app.org_name,
    space_name: app.space_name
  }
  # HTTParty.post(ENV.fetch('PEN_TEST_URL'), body: body)
  puts body
end

login_to_cf
target_space

last_poll_at = Time.now.utc - 300
# loop do
  newly_created_app_results = results_since(last_poll_at)
  apps = apps_from(newly_created_app_results)
  apps.each do |app|
    trigger_pen_test_with(app)
  end


  # sleep 5
# end
