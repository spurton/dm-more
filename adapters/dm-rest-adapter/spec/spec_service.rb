# Run before specs with:
# ruby spec_service.rb -p 4000

# Sinatra application to provide dm-rest-adapter an end-point:
require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-serializer'

# Note that we cannot wrap this stuff into a 'before' block
# unless we explicitly want to forget about resources created
# on a previous case, (which should be the desirable behavior anyway).
configure do
  DataMapper::Logger.new(STDOUT, :debug)
  DataMapper.setup(:default, 'sqlite3::memory:')
  
  class Book
    include DataMapper::Resource
    property :id, Serial
    property :author, String
    property :title, String
    property :created_at, DateTime
    property :updated_at, DateTime
  end
  
  repository(:default) do |repo|
    Book.auto_migrate!
    Book.new({
      :author => 'Ursula K LeGuin', 
      :title => 'The Dispossed', 
      :created_at => DateTime.parse('2008-06-08T17:02:28Z'), 
      :updated_at => DateTime.parse('2008-06-08T17:02:28Z')
    }).save
    Book.new({
      :author => 'Stephen King', 
      :title => 'The Shining', 
      :created_at => DateTime.parse('2008-06-08T17:03:07Z'), 
      :updated_at => DateTime.parse('2008-06-08T17:03:07Z')
    }).save
  end
end

helpers do

  def protected!
    response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth") and \
    throw(:halt, [401, "Not authorized\n"]) and \
    return unless authorized?
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', 'tot@ls3crit']
  end

end

# Trying to figure out what is required to test connection and the desired behavior...

# This is the CRUD stuff:

# Collection GET - application/xml is the default
# curl -i --url http://localhost:4000/books --header "Accept: application/json"
# curl -i --url http://localhost:4000/books --header "Accept: application/xml"
# curl -i --url http://localhost:4000/books 
get '/books' do
  request.accept.include?('application/json') ? Book.all.to_json : Book.all.to_xml
end

# This should raise "NotImplementedError":
# delete '/books' do
#   
# end


#  curl -i --url http://localhost:4000/books/1 --header "Accept: application/json"
# HTTP/1.1 200 OK
# Content-Type: text/html
# Content-Length: 152
# Connection: keep-alive
# Server: thin 1.0.1 codename ?
# 
# { "id": 1, "author": "Ursula K LeGuin", "title": "The Dispossed", "created_at": "2008-06-08T17:02:28+00:00", "updated_at": "2008-06-08T17:02:28+00:00" }

# curl -i --url http://localhost:4000/books/1 --header "Accept: application/xml"

# HTTP/1.1 200 OK
# Content-Type: text/html
# Content-Length: 248
# Connection: keep-alive
# Server: thin 1.0.1 codename ?
# 
# <book><id type='datamapper::types::serial'>1</id><author>Ursula K LeGuin</author><title>The Dispossed</title><created_at type='datetime'>2008-06-08T17:02:28+00:00</created_at><updated_at type='datetime'>2008-06-08T17:02:28+00:00</updated_at></book>
# Resource READ (GET) - application/xml is the default
get '/books/:book_id' do
  begin
    book = Book.get!(params[:book_id])
    request.accept.include?('application/json') ? book.to_json : book.to_xml
  rescue ::DataMapper::ObjectNotFoundError
    raise Sinatra::NotFound
  end
end

# Resource CREATE (POST)
post '/books' do
  
end

# Resource UPDATE (PUT)
put '/books/:book_id' do
  # This should receive params[:book_id] = '42' with:
  # book_xml = <<-XML
  # <book>
  #   <id type='integer'>42</id>
  #   <title>Starship Troopers</title>
  #   <author>Robert Heinlein</author>
  #   <created-at type='datetime'>2008-06-08T17:02:28Z</created-at>
  # </book>
  # XML
end

# Resource DELETE (DELETE)
delete '/books/:book_id' do

end
