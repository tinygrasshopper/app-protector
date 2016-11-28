require 'json'
require 'date'
require 'open-uri'
require 'httparty'

class Config
  attr_reader :api_url, :username, :password, :org_name, :space_name, :space_guid

  def initialize
    @api_url = ENV.fetch('API_URL')
    @username = ENV.fetch('USERNAME')
    @password = ENV.fetch('PASSWORD')
    @org_name = "system"
    @space_name = "system"
    @space_guid = ENV.fetch('SPACE_GUID')
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
    new_app_create_events = app_create_events_since(time: time, space_guid: space_guid)

    new_app_create_events.map do |event|
      url = app_url(event.actee)
      App.new(
        name: event.actee_name,
        url: url
      )
    end
  end

  def app_create_events_since(time:, space_guid:)
    timestamp = time.strftime('%FT%TZ')
    path = "/v2/events?q=type:audit.app.create&q=timestamp>#{timestamp}"
    events = curl_resources(path)
    filtered_events = events.select { |event| event.fetch('entity').fetch('space_guid') == space_guid }
    filtered_events.map do |event|
      puts event
      AppEvent.new(actee: event.fetch("entity").fetch("actee"), actee_name: event.fetch("entity").fetch("actee_name"))
    end
  end

  private

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
  attr_reader :name, :url

  def initialize(name:, url:)
    @name, @url = name, url
  end
end

class AppEvent
  attr_reader :actee, :actee_name

  def initialize(actee:, actee_name:)
    @actee, @actee_name = actee, actee_name
  end

  def app
    App.new(guid: actee_name)
  end
end

def trigger_pen_test_with app, config
  body = {
    site: app.url,
    app_name: app.name,
    org_name: config.org_name,
    space_name: config.space_name
  }
  # HTTParty.post(ENV.fetch('PEN_TEST_URL'), body: body)
  puts body
end

config = Config.new
cf_client = CFClient.new(api_url: config.api_url, username: config.username, password: config.password)
cf_client.login
cf_client.target_space(org: config.org_name, space: config.space_name)

last_poll_at = Time.now.utc - 1000
# loop do
  apps = cf_client.apps_created_since(time: last_poll_at, space_guid: config.space_guid)
  apps.each do |app|
    trigger_pen_test_with(app, config)
  end
  # sleep 5
# end
