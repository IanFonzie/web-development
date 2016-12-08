require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
# Tilt is a thin interface over a bunch of 
# different Ruby template engines in an attempt to make their usage as generic as possible

def each_chapter(&block)
  @toc.each_with_index do |name, index|
    number = index + 1
    contents = File.read("data/chp#{number}.txt").split("\n\n")
    yield number, name, contents
  end
end

def chapters_matching(query)
  results = []

  return results unless query

  each_chapter do |number, name, contents| # for each chapter get the number name and page data
    matches = {} 
    contents.each_with_index do |content, index| # for each page get the paragraph along with its index
      matches[index] = content if content.include?(query) #add the paragraph if the content has the query
      # results << {number: number, name: name, paragraph_number: index, paragraph: content} if content.include?(query)
    end
    results << {number: number, name: name, paragraphs: matches} if matches.any?
  end # add the results if there were any matches so this gives us a name and number along with any
  #matches

  results # .group_by { |hash| hash[:name] }
end

before do
  @toc = File.readlines("data/toc.txt")
end

helpers do
  def in_paragraphs(text)
    text.split("\n\n").each_with_index.map do |line, index|
      "<p id=paragraph#{index}>#{line}</p>"
    end.join # Creates an array of paragraph tag delimited lines and joins them
  end

  def highlight(text, query)
    text.gsub(query, "<strong>#{query}</strong>")
  end
end

get "/" do
  @title = "The Adventures of Sherlock Holmes"
  
  erb :home
end

get "/chapters/:number" do
  number = params[:number].to_i
  chapter_name = @toc[number - 1]
  @title = "Chapter #{number}: #{chapter_name}"

  @chapter = File.read("data/chp#{number}.txt")

  erb :chapter
end

get "/search" do
  @query = params[:query]
  @title = "Search"
  # chapters = Dir.glob("data/chp*.txt")

  # found = chapters.select do |chapter|
  #   chapter = File.read(chapter)
  #   chapter.include?(@query)
  # end.sort_by { |file_name| file_name.slice(/\d+/).to_i }

  # @chapters_info = found.each_with_object({}) do |file_name, hash|
  #   chapter_number = file_name.slice(/\d+/).to_i
  #   hash[chapter_number] = @toc[chapter_number - 1]
  # end
  @results = chapters_matching(@query)

  erb :search
end

not_found do
  redirect "/"
end