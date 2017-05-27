require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'pry'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

root = File.expand_path('..', __FILE__)

configure do
  enable :sessions
  set :session_secret, 'secret'
  # use Rack::Session::Cookie, :key => 'rack.session',
  #                            :path => '/',
  #                            :secret => 'your_secret'
  # set :erb, :escape_html => true
end

def data_path
  # using cms.rb as a starting point it gets the full path content
  # for the file. if the rack env is 'test' it will look at the parent
  #   of __FILE__(cms.rb) and then in /test/data instead of /data
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def history_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/history', __FILE__)
  else
    File.expand_path('../history', __FILE__)
  end
end

# def load_accounts
#   if ENV['RACK_ENV'] == 'test'
#     File.expand_path('../test', __FILE__)
#   else
#     File.expand_path('..', __FILE__)
#   end
# end

# def valid_user?(username, password)
#   accounts_path = File.join(load_accounts, 'users.yml')
#   accounts = Psych.load_file(accounts_path)
#   accounts[username.to_sym] == password
# end

VALID_EXTENSIONS = ['.md', '.txt'].freeze
VALID_IMAGE_TYPES = ['.jpg', '.jpeg', '.png', '.gif', '.tif', '.tiff'].freeze

def valid_filetype?(file_path)
  (VALID_EXTENSIONS + VALID_IMAGE_TYPES).each do |ext|
    return true if File.extname(file_path).include?(ext)
  end
  false
end

def load_user_credentials
  credentials_path = if ENV['RACK_ENV'] == 'test'
                       File.expand_path('../test/users.yml', __FILE__)
                     else
                       File.expand_path('../users.yml', __FILE__)
                     end
  Psych.load_file(credentials_path)
end

def check_credentials?(password, username)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

# Running the same password through bcrypt will not give you the same
# hash every time

def signed_in?
  # session[:username] ? true : false
  session.key?(:username)
end

def user_authorization
  return if signed_in?
  session[:message] = 'You must be signed in to do that.'
  redirect '/'
end

def validate_user_information(username, password, credentials)
  if username.size.zero?
    'A username is required.'
  elsif credentials.key?(username)
    'The username is already taken. Please select another.'
  elsif password.size.zero?
    'A password is required.'
  end
end

def credentials_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/users.yml', __FILE__)
  else
    File.expand_path('../users.yml', __FILE__)
  end
end

get '/users/signup' do
  erb :signup, layout: :layout
end

post '/users/signup' do
  username = params[:username]
  password = params[:password]

  credentials = load_user_credentials

  error = validate_user_information(username, password, credentials)
  if error
    session[:message] = error
    status 422
    erb :signup, layout: :layout
  else
    encrypted_password = BCrypt::Password.create(password)
    credentials[username] = encrypted_password.to_s
    File.open(credentials_path, 'w') do |f|
      f.write credentials.to_yaml
      session[:message] = 'Your account was created successfully.'
    end
    redirect '/'
  end
end

get '/users/signin' do
  erb :signin, layout: :layout
end

post '/users/signin' do
  # if params[:username] == 'admin' and params[:password] == 'secret'
  # if valid_user?(params[:username], params[:password])
  # credentials = load_user_credentials
  username = params[:username]

  if check_credentials?(params[:password], username)
    session[:username] = params[:username]
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid credentials.'
    status 422
    erb :signin, layout: :layout
  end
end

get '/' do
  pattern = File.join(data_path, '*')
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index, layout: :layout
end

def render_markdown(input)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  # markdown.render(Rack::Utils.escape_html(input))
  markdown.render(input)
end

def format_correction!(path)
  case File.extname(path)
  when '.jpeg'
    path.gsub!('.jpg', '.jpeg')
  when '.tif'
    path.gsub!('.tif', '.tiff')
  else
    path
  end
end

# thought about doing this earlier;
# essentially combines two methods together
# instead of having two paths
def load_file_content(path)
  content = File.read(path)

  format_correction!(path)

  case File.extname(path.downcase)
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  when '.md'
    erb render_markdown(content)
  when *VALID_IMAGE_TYPES
    headers['Content-Type'] = "image/#{File.extname(path).delete('.')}"
    content
  else
    headers["Content-Type"] = "text/plain"
    content
  end
end

get "/view" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

post '/create' do
  user_authorization

  file_name = params[:document_name].strip

  if file_name.size.zero?
    session[:message] = 'A name is required.'
    status 422
    erb :new, layout: :layout
  else
    file_path = File.join(data_path, file_name)

    if valid_filetype?(file_path)
      File.write(file_path, '')
      session[:message] = "#{file_name} was created successfully."
      FileUtils.mkdir(File.join(history_path, file_name))

      redirect '/'
    else
      session[:message] = 'A valid file type is required '\
      "(#{VALID_EXTENSIONS.join(', ')})."
      status 422
      erb :new, layout: :layout
    end
  end
end

get '/new_image' do
  user_authorization

  erb :new_image, layout: :layout
end

post '/create/image' do
  user_authorization

  if params[:image].nil?
    session[:message] = 'Please select a file.'
    status 422
    erb :new_image, layout: :layout
  else
    content = params[:image][:tempfile]
    file_name = params[:image][:filename].strip
    file_path = File.join(data_path, file_name)
    
    if valid_filetype?(file_path.downcase)
      File.write(file_path, content.read)
      session[:message] = "#{file_name} was uploaded successfully."

      redirect '/'
    else
      session[:message] = 'A valid file type is required '\
      "(#{VALID_IMAGE_TYPES.join(', ')})."
      status 422
      erb :new_image, layout: :layout
    end
  end
end

get '/new' do
  user_authorization

  erb :new, layout: :layout
end

get '/:file' do
  file_name = File.join(data_path, params[:file])

  if File.file?(file_name)
    load_file_content(file_name)
  else
    session[:message] = "#{params[:file]} does not exist."
    redirect '/'
  end
  # if headers['Content-Type'] == 'text/plain'
  #   erb :file, layout: false
  # else
  #   erb :file, layout: :layout
  # end
end

get '/:file/edit' do
  user_authorization

  @name = params[:file]
  file_name = File.join(data_path, params[:file])

  if File.file?(file_name)
    @content = File.read(file_name)
  else
    session[:message] = "#{params[:file]} does not exist."
    redirect '/'
  end

  erb :edit, layout: :layout
end

def timestamp_file_name(file_name)
  file_name_array = File.basename(file_name).split('.')
  file_name_array.first << '_' + Time.now.to_s
  file_name_array.join('.')
end

def create_archive(file_name, content)
  archive_path = File.join(history_path, File.basename(file_name))
  File.open(File.join(archive_path, timestamp_file_name(file_name)), 'w') do |f|
    f.write(content)
  end
end

get '/:file/history' do
  file_name = params[:file]

  pattern = File.join(File.join(history_path, file_name), '*')
  @versions = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :document_history, layout: :layout
end

get '/:file/history/:version' do
  file_name = File.join(File.join(history_path, params[:file]), params[:version])

  if File.file?(file_name)
    load_file_content(file_name)
  else
    session[:message] = "#{params[:file]} does not exist."
    redirect '/'
  end
end

post '/:file' do
  user_authorization

  content = params[:file_content]
  file_name = File.join(data_path, params[:file])

  File.open(file_name, 'w') do |f|
    f.write(content)
    session[:message] = "#{params[:file]} has been updated."
    create_archive(file_name, content)
  end

  redirect '/'
end

def construct_multi_copy(file, file_number, ext)
  file_name_array = file.split

  if file_name_array[-1] == 'copy'
    file_name_array << file_number
  else
    file_name_array[-1] = file_number
  end

  file_name_array.join(' ').to_s + ext
end

def document_name(file_name, files, file_number = 0)
  file = File.basename(file_name, '.*')
  ext = File.extname(file_name)

  return file_name unless files.include? file_name
  file_number += 1
  file_name = if file_number == 1
                "#{file} copy" + ext
              else
                construct_multi_copy(file, file_number, ext)
              end
  document_name(file_name, files, file_number)
end

post '/:file/duplicate' do
  user_authorization

  pattern = File.join(data_path, '*')
  files = Dir.glob(pattern).map { |path| File.basename(path) }

  file_name = File.join(data_path, params[:file])

  content = File.read(file_name)

  duplicate_file = File.join(data_path, document_name(params[:file], files))

  File.open(duplicate_file, 'w') do |f|
    f.write(content)
    session[:message] = "#{params[:file]} has been duplicated."
  end

  redirect '/'
end

post '/:file/delete' do
  user_authorization

  file_name = File.join(data_path, params[:file])

  File.delete(file_name)
  FileUtils.rm_rf(File.join(history_path, File.basename(file_name)))

  session[:message] = "#{params[:file]} was deleted."
  redirect '/'
end

post '/users/signout' do
  session.delete(:username)
  session[:message] = 'You have been signed out.'
  redirect '/'
end
