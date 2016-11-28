require 'sinatra/base'
require 'json'

class Web < Sinatra::Base
  get "/" do
    "<pre>" + `ps aux | grep worker.s[h]` + "</pre>"
  end

  get "/trump" do
    quotes = [
      "my fingers are long and beautiful",
      "it will be a great, great wall",
      "i have the best words"
    ]
    quotes.sample
  end

  post "/" do
    request.body.rewind
    request_payload = JSON.parse(request.body.read)

    halt unless request_payload['name']
    halt unless request_payload['site']

    pid = Process.fork {
      puts system("./worker.rb #{request_payload['name']} #{request_payload['site']}")
    }

    "Started scanning #{request_payload['site']} with PID #{pid}"
  end
end
