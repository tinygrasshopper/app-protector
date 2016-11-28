require 'sinatra/base'

class Web < Sinatra::Base
  get "/" do
    erb :index, :locals => {:name => nil}  
  end
  post "/" do
    erb :index, :locals => {:name => params['name']}
  end
end
