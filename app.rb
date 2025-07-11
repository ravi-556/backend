require 'sinatra'
require 'sequel'
require 'json'
require 'sinatra/cross_origin'
require 'sinatra/json'


configure do
  enable :cross_origin
end

before do
  content_type :json
end

DB = Sequel.connect('postgres://backend:securepass@localhost:5432/backend_db')

# POST /users - Create user
post '/users' do
  data = JSON.parse(request.body.read)
  user = DB[:users].insert(user_name: data['user_name'], email: data['email'])
  json message: "User created", id: user
end

# POST /posts - Create post
post '/posts' do
  data = JSON.parse(request.body.read)
  post = DB[:posts].insert(
    post_title: data['post_title'],
    post_content: data['post_content'],
    author_name: data['author_name'],
    published_id: data['published_id'],
    user_id: data['user_id']
  )
  json message: "Post created", id: post
end

# GET /posts - List all posts (summary)
get '/posts' do
  posts = DB[:posts].select(:id, :post_title, :author_name).all
  json posts
end

# GET /posts/:id - View post details
get '/posts/:id' do
  post = DB[:posts][id: params[:id].to_i]
  halt 404, json({ error: 'Post not found' }) unless post
  json post
end