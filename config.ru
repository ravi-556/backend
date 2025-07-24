# config.ru
require 'sinatra'
require_relative './app' # Assuming app.rb is in the same directory

# Configure Rack::Protection::HostAuthorization middleware
use Rack::Protection::HostAuthorization, {
    permitted_hosts: lambda do |host|
        allowed = [
        "localhost",
        "127.0.0.1",
        "frontend.mytesting.co.in",
        "api.mytesting.co.in"
        ]

        # Allow ALB health check IP-based hosts
        allowed.include?(host) || host =~ /ec2\.internal/ || host =~ /\A\d+\.\d+\.\d+\.\d+\z/
    end
}

# Run the Sinatra application
run Sinatra::Application
