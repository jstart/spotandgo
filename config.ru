require './app.rb'

set :run, :false
set :environment, :development

run Sinatra::Application
