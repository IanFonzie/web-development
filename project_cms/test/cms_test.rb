ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'
require 'uri'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    FileUtils.mkdir_p(history_path)
    File.open(credentials_path, 'w') do |file|
      file.write({}.to_yaml)
    end
  end

  def teardown
    FileUtils.rm_rf(data_path)
    FileUtils.rm_rf(history_path)
    FileUtils.rm(credentials_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      if VALID_IMAGE_TYPES.include?(File.extname(file))
        file.write(content.read)
      else
        file.write(content)
      end
    end
  end

  def create_users(content = '')
    File.open(credentials_path, 'w') do |file|
      file.write(content)
    end
  end

  def create_document_history(file_name)
    FileUtils.mkdir_p(File.join(history_path, file_name))
  end

  def admin_session
    { "rack.session" => { username: 'admin' } }
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_viewing_text_document
    create_document 'history.txt', '1993 - Yukihiro Matsumoto dreams up Ruby.'

    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, '1993 - Yukihiro Matsumoto dreams up Ruby.'
  end

  def test_request_nonexistent_document
    get '/wallawalla.txt'

    assert_equal 302, last_response.status

    assert_equal 'wallawalla.txt does not exist.', session[:message] 

    # get last_response['Location']

    # assert_equal 200, last_response.status
    # assert_equal 'text/html;charset=utf-8', last_response['Content-Type']

    get '/'

    # assert_equal 200, last_response.status
    # assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_nil session[:message] # last_response.body, 'wallawalla.txt does not exist.'
  end

  def test_viewing_markdown_files
    create_document 'about.md', '# H1'
    
    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>H1</h1>'
  end

  def test_editing_document_content
    create_document 'changes.txt'
    
    get '/', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<a href="/changes.txt/edit">Edit</a>)

    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<button type="submit")
    assert_includes last_response.body, '<textarea'
  end

  def test_editing_document_content_signed_out
    create_document 'changes.txt'
    
    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<a href="/changes.txt/edit">Edit</a>)

    get '/changes.txt/edit'

    assert_equal 302, last_response.status
    assert_equal session[:message], 'You must be signed in to do that.'
  end

  def test_updating_document_content
    create_document_history('changes.txt')
    post '/changes.txt', { file_content: 'new content' }, admin_session
    assert_equal 302, last_response.status
    
    assert_equal 'changes.txt has been updated.', session[:message] 
    # get last_response['Location']
    
    # assert_includes last_response.body, %q(<p class="message">changes.txt has been updated.</p>)

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content' 
  end

  def test_updating_document_content_signed_out
    post '/changes.txt', file_content: 'new content'
    
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message] 
    # get last_response['Location']
  end

  def test_creating_screen
    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<input type="text" name="document_name">)
    assert_includes last_response.body, %q(<button type="submit">)
  end

  def test_creating_screen_signed_out
    get '/new'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message] 
  end

  def test_document_creation
    post '/create', { document_name: 'blork.txt' }, admin_session
    assert_equal 302, last_response.status

    assert_equal 'blork.txt was created successfully.', session[:message]
    # get last_response['Location']
    # assert_includes last_response.body, %q(<p class="message">blork.txt was created successfully.</p>)

    get '/'
    assert_includes last_response.body, 'blork.txt'
  end

  def test_document_creation_signed_out
    post '/create', document_name: 'blork.txt'
    assert_equal 302, last_response.status

    assert_equal 'You must be signed in to do that.', session[:message]
    # get last_response['Location']
    # assert_includes last_response.body, %q(<p class="message">blork.txt was created successfully.</p>)

    get '/'
    refute_includes last_response.body, 'blork.txt'
  end

  def test_empty_document_creation
    post '/create', { document_name: '' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, %q(<p class="message">A name is required.</p>)
  end

  def test_invalid_file_extension_creation
    post '/create', { document_name: 'derp.wtf' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, %q(<p class="message">A valid file type is required)
  end

  def test_empty_document_creation_signed_out
    post '/create', document_name: ''

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_document_history_creation
    post '/create', { document_name: 'test.txt' }, admin_session
    assert_equal 302, last_response.status

    get '/'
    assert_includes last_response.body, %q(<a href="/test.txt/history">History</a>)
  end

  def test_document_history_creation_signed_out
    post '/create', { document_name: 'test.txt' }
    
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_document_edit_history
    create_document_history('test.txt')

    post '/test.txt', { file_content: 'This is a test' }, admin_session
    assert_equal 302, last_response.status

    get '/test.txt/history'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %Q(<a href="/test.txt/history/test_#{Time.now}.txt">test_#{Time.now}.txt</a>)
  end

  def test_document_edit_history_signed_out
    create_document_history('test.txt')

    post '/test.txt', { file_content: 'This is a test' }
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_view_archived_version
    create_document_history('test.txt')

    post '/test.txt', { file_content: 'This is a test' }, admin_session
    assert_equal 302, last_response.status

    get "/test.txt/history/test_#{URI.encode(Time.now.to_s)}.txt"
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'This is a test'
  end

  def test_image_upload
    post '/create/image', { image: Rack::Test::UploadedFile.new(File.join(FileUtils.pwd, "public/images/capybara.jpeg"), "image/jpeg") }, admin_session
    
    assert_equal 302, last_response.status
    assert_equal 'capybara.jpeg was uploaded successfully.', session[:message]

    get '/'
    assert_includes last_response.body, %q(href="/capybara.jpeg")
  end

  def test_image_upload_signed_out
    post '/create', { image: Rack::Test::UploadedFile.new(File.join(FileUtils.pwd, "public/images/capybara.jpeg"))}

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_image_view
    create_document 'capybara.jpeg', Rack::Test::UploadedFile.new(File.join(FileUtils.pwd, "public/images/capybara.jpeg"), "image/jpeg")

    get '/capybara.jpeg'
    assert_equal 200, last_response.status
    assert_equal 'image/jpeg', last_response['Content-Type']
  end

  def test_image_view_in_markdown
    create_document 'capybara.jpeg', Rack::Test::UploadedFile.new(File.join(FileUtils.pwd, "public/images/capybara.jpeg"), "image/jpeg")
    create_document 'about.md', '![Capybara](capybara.jpeg)'

    get '/about.md'
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<img src="capybara.jpeg" alt="Capybara">)

    get '/capybara.jpeg'
    assert_equal 200, last_response.status
    assert_equal 'image/jpeg', last_response['Content-Type']
  end

  def test_deletion
    create_document 'blahuey.txt'

    post '/blahuey.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'blahuey.txt was deleted.', session[:message]
    # get last_response['Location']
    # assert_includes last_response.body, %q(<p class="message">blahuey.txt was deleted.</p>)

    get '/'
    refute_includes last_response.body, %q(href="/blahuey.txt")
  end

  def test_deletion_signed_out
    create_document 'blahuey.txt'

    post '/blahuey.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
    # get last_response['Location']
    # assert_includes last_response.body, %q(<p class="message">blahuey.txt was deleted.</p>)

    get '/'
    assert_includes last_response.body, 'blahuey.txt'
  end

  def test_document_duplication
    create_document 'about.md', '# H1'

    post 'about.md/duplicate', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'about.md has been duplicated.', session[:message]

    get '/'
    assert_includes last_response.body, 'about copy.md'

    get '/about%20copy.md'
    assert_includes last_response.body, '<h1>H1</h1>'
  end

  def test_document_duplication_signed_out
    create_document 'about.md', '# H1'

    post 'about.md/duplicate'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]

    get '/'
    refute_includes last_response.body, 'about copy.md'
  end

  def test_signed_out
    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end

  def test_signin_view_page
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<input type="text" name="username" value="">)
    assert_includes last_response.body, %q(<input type="text" name="password" value="">)
    assert_includes last_response.body, %q(<button type="submit">Sign In</button>)
  end

  def test_signin
    create_users({"admin" => "$2a$10$hQNvTB1vuBXbbzfcjf9GjuowZAvCBNXtFogUs.cPk16.u.WCgen5a"}.to_yaml)
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status

    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:username]
    get last_response['Location']
    # assert_includes last_response.body, %q(<p class="message">Welcome!</p>)
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_invalid_signin
    post '/users/signin', username: 'admin', password: ''
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, %q(<p class="message">Invalid credentials.</p>)
  end

  def test_signup_view_page
    get '/users/signup'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<input type="text" name="username" value="">)
    assert_includes last_response.body, %q(<input type="text" name="password" value="">)
    assert_includes last_response.body, %q(<button type="submit">Create Account</button>)
  end

  def test_signup
    post '/users/signup', username: 'Edgar Allen Poe', password: 'theraven'
    assert_equal 302, last_response.status
    assert_equal 'Your account was created successfully.', session[:message]
    
    post 'users/signin', username: 'Edgar Allen Poe', password: 'theraven'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'Edgar Allen Poe', session[:username]
  end

  def test_signup_no_username
    post '/users/signup', username: '', password: 'fart'
    assert_equal 422, last_response.status
    assert_includes last_response.body, %q(<p class="message">A username is required.</p>)
  end

  def test_signup_username_taken
    create_users({"admin" => "$2a$10$hQNvTB1vuBXbbzfcjf9GjuowZAvCBNXtFogUs.cPk16.u.WCgen5a"}.to_yaml)

    post '/users/signup', username: 'admin', password: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, %q(<p class="message">The username is already taken. Please select another.</p>)
  end

  def test_signup_no_password
    post '/users/signup', username: 'Edgar Allen Poe', password: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, %q(<p class="message">A password is required.</p>)
  end

  def test_signout
    # post '/users/signin', username: 'admin', password: 'secret'

    # get last_response['Location']
    # assert_includes last_response.body, %q(<p class="message">Welcome!</p>)
    get '/', {}, admin_session
    assert_includes last_response.body, 'Signed in as admin'

    post '/users/signout'
    assert_equal 'You have been signed out.', session[:message]

    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)

    # get last_response['Location']
    # assert_includes last_response.body, %q(<p class="message">You have been signed out.</p>)
  end
end
