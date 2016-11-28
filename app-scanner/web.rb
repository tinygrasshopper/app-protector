require 'sinatra/base'
require 'json'

class Web < Sinatra::Base
  get "/" do
    "<pre>" + `ps aux | grep worker.s[h]` + "</pre>"
  end

  get "/trump" do
    quotes = [
      "my fingers are long and beautiful",
      "it will be a great, great wall"
    ]
    quotes.sample
  end

  post "/" do
    request.body.rewind
    request_payload = JSON.parse(request.body.read)

    # `./worker.sh #{request_payload['site']} &`

    pid = Process.fork {
      system("./worker.sh #{request_payload['site']}")
    }

    "Started scanning #{request_payload['site']} with PID #{pid}"
  end
end
