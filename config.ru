# config.ru
require 'sinatra'
require_relative './app' # Assuming app.rb is in the same directory

# Configure Rack::Protection::HostAuthorization middleware
use Rack::Protection::HostAuthorization, {
  permitted_hosts: [
    "localhost",
    "127.0.0.1",
    "frontend.mytesting.co.in",
    "api.mytesting.co.in",
    # Add any other specific IP addresses if needed, e.g., "65.2.6.38"
  ]
}

# Run the Sinatra application
run Sinatra::Application
