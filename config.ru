# config.ru
require 'sinatra'
require_relative './app' # Assuming app.rb is in the same directory

# Configure Rack::Protection::HostAuthorization middleware
use Rack::HostAuthorization, [
    'localhost',
    '127.0.0.1',
    'api.mytesting.co.in',
    'frontend.mytesting.co.in',
    /ec2\.internal$/,
    /\A\d+\.\d+\.\d+\.\d+\z/
  ]

# Run the Sinatra application
run Sinatra::Application
