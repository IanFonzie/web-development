require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

get "/" do
  @title = "Dynamic Directory Index"
  @files = Dir.glob("public/*").map { |file| file.split('/').last }.sort
  # @files = Dir.glob("public/*").map { |file| File.basename(file) }.sort
  @files.reverse! if params[:sort] == "desc"

  erb :directory
end

