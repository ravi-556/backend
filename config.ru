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
    /ec2\.internal$/,                   # optional: for ALB internal DNS
    /\A\d{1,3}(\.\d{1,3}){3}\z/           # optional: for IP-based Host headers
    # Add any other specific IP addresses if needed, e.g., "65.2.6.38"
  ]
}

# Run the Sinatra application
run Sinatra::Application
