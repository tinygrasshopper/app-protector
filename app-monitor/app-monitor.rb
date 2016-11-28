require 'json'
require 'date'
require 'open-uri'
require 'httparty'

class Config
  attr_reader :api_url, :username, :password, :org_name, :space_name, :space_guid, :scanner_url

  def initialize
    @api_url = ENV.fetch('API_URL')
    @username = ENV.fetch('USERNAME')
    @password = ENV.fetch('PASSWORD')
    @org_name = ENV.fetch('ORG_NAME')
    @space_name = ENV.fetch('SPACE_NAME')
    @space_guid = ENV.fetch('SPACE_GUID')
    @scanner_url = URI::encode(ENV.fetch('SCANNER_URL'))
  end
end

class CFClient
  def initialize(api_url:, username:, password:)
    @api_url, @username, @password = api_url, username, password
  end

  def login
    %x(./cf api #{@api_url} --skip-ssl-validation)
    %x(./cf auth #{@username} #{@password})
  end

  def target_space(org:, space:)
    %x(./cf target -o #{org} -s #{space})
  end

  def apps_created_since(time:, space_guid:)
    map_events_to_apps(app_create_events_since(time: time, space_guid: space_guid))
  end

  def apps_updated_since(time:, space_guid:)
    map_events_to_apps(app_update_events_since(time: time, space_guid: space_guid))
  end

  def app_create_events_since(time:, space_guid:)
    app_events_since(type: 'create', time: time, space_guid: space_guid)
  end

  def app_update_events_since(time:, space_guid:)
    app_events_since(type: 'update', time: time, space_guid: space_guid)
  end

  private

  def map_events_to_apps(app_events)
    app_events.map do |event|
      App.new(
        guid: event.actee,
        name: event.actee_name,
        url: app_url(event.actee)
      )
    end.uniq { |app| app.guid }
  end

  def app_events_since(type:, time:, space_guid:)
    timestamp = time.strftime('%FT%TZ')
    path = "/v2/events?q=type:audit.app.#{type}&q=timestamp>#{timestamp}"
    events = curl_resources(path)
    space_events = events.select { |event| event.fetch('entity').fetch('space_guid') == space_guid }
    app_push_events = space_events.select { |event| event.fetch('entity').fetch('metadata').fetch('request').has_key?('name') }
    app_push_events.map do |event|
      AppEvent.new(actee: event.fetch("entity").fetch("actee"), actee_name: event.fetch("entity").fetch("actee_name"))
    end
  end

  def app_url(app_guid)
    routes_results = curl_resources("/v2/apps/#{app_guid}/routes")
    first_route = routes_results.first

    host = first_route.fetch("entity").fetch("host")
    domain = domain_name(first_route.fetch("entity").fetch("domain_url"))

    url = "http://#{host}.#{domain}"
  end

  def domain_name(domain_url)
    domain_result = curl(domain_url)
    domain_result.fetch("entity").fetch("name")
  end

  def curl_resources(path)
    results = curl(path)
    results.fetch('resources')
  end

  def curl(path)
    encoded_path = URI::encode(path)
    response_body = %x(./cf curl \"#{encoded_path}\")
    JSON.parse(response_body)
  end
end

class App
  attr_reader :guid, :name, :url

  def initialize(guid:, name:, url:)
    @guid, @name, @url = guid, name, url
  end
end

class AppEvent
  attr_reader :actee, :actee_name

  def initialize(actee:, actee_name:)
    @actee, @actee_name = actee, actee_name
  end
end

def log(time, message)
  puts "[#{time.to_s}] #{message}"
end

def trigger_pen_test_with app, config
  body = {
    site: app.url,
    name: app.name,
    org_name: config.org_name,
    space_name: config.space_name
  }.to_json
  response = HTTParty.post(config.scanner_url, body: body)
end

config = Config.new
cf_client = CFClient.new(api_url: config.api_url, username: config.username, password: config.password)
cf_client.login
cf_client.target_space(org: config.org_name, space: config.space_name)

puts "Monitoring CF target"
puts "Org: #{config.org_name}"
puts "Space: #{config.space_name}"
last_poll_at = Time.now.utc - 300
loop do
  next_poll_from = Time.now.utc
  log(next_poll_from, "Monitoring... ")
  apps_created = cf_client.apps_created_since(time: last_poll_at, space_guid: config.space_guid)
  log(next_poll_from, "New apps created: [#{apps_created.map(&:name).join(', ')}]")
  apps_updated = cf_client.apps_updated_since(time: last_poll_at, space_guid: config.space_guid)
  log(next_poll_from, "Apps updated: [#{apps_updated.map(&:name).join(', ')}]")
  apps_to_test = (apps_created + apps_updated).uniq { |app| app.guid }
  apps_to_test.each do |app|
    trigger_pen_test_with(app, config)
  end
  sleep 15
  last_poll_at = next_poll_from
end
