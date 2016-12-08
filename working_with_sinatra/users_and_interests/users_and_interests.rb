require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "yaml"
require "pry"

before do 
  @users = Psych.load_file("public/users.yaml")
end

def remove_user(user)
  other_users = @users.reject { |user_name, hash| user_name == user }
  other_users.keys.map(&:to_sym)
end

helpers do
  def count_interests(users)
    users.reduce(0) do |sum, (name, info)|
      sum += info[:interests].size
    end
  end
end

get "/" do
  redirect "/users"
end

get "/users" do
  @title = 'Users'

  erb :users
end

get "/users/:user" do
  @user = params[:user].to_sym
  @title = @user.capitalize
  @email = @users[@user][:email]
  @interests = @users[@user][:interests].join(', ')
  @user_list = remove_user(@user)

  erb :profile
end