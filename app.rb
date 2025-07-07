require 'sinatra'
require 'json'
require 'sequel'
require 'pg'
require 'rack/cors'

# Allow CORS for frontend
use Rack::Cors do
  allow do
    origins 'https://mytesting.co.in'  # Replace with your frontend domain
    resource '*',
      headers: :any,
      methods: [:get, :post, :options]
  end
end

set :bind, '0.0.0.0'

# Connect to PostgreSQL
DB = Sequel.connect('postgres://backend:securepass@localhost/user_data')

# Create table if not exists
unless DB.table_exists?(:users)
  DB.create_table :users do
    primary_key :id
    String :name
    String :email
    DateTime :created_at
  end
end

Users = DB[:users]

# Handle preflight OPTIONS (CORS)
options '*' do
  200
end

# Create user
post '/users' do
  begin
    data = JSON.parse(request.body.read)

    halt 400, { error: 'Missing name or email' }.to_json unless data['name'] && data['email']

    Users.insert(
      name: data['name'],
      email: data['email'],
      created_at: Time.now
    )

    content_type :json
    { status: 'ok', message: 'User saved' }.to_json
  rescue JSON::ParserError
    halt 400, { error: 'Invalid JSON' }.to_json
  end
end
