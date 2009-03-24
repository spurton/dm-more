# Run before specs with:
# ruby spec_service.rb -p 4000

# Sinatra application to provide dm-rest-adapter an end-point:
require 'rubygems'
require 'sinatra'
require 'extlib'
require 'dm-core'
require 'dm-serializer'
require 'dm-validations'

# Probably a good idea to move into its own file

# When providing Content-Type headers of 'application/json', 'application/xml' or 'text/xml'
# Rack is not processing that as parameters.
# This is adapted from Rack::PostBodyContentTypeParser to include XML bits.
 
module Rack
 
  # A Rack middleware for parsing POST/PUT body data when Content-Type is
  # not one of the standard supported types, like <tt>application/json</tt>.
  #
  class RestContentTypesBodyParse
 
    # Constants
    #
    CONTENT_TYPE = 'CONTENT_TYPE'.freeze
    POST_BODY = 'rack.input'.freeze
    FORM_INPUT = 'rack.request.form_input'.freeze
    FORM_HASH = 'rack.request.form_hash'.freeze
 
    # Supported Content-Types
    #
    APPLICATION_JSON = 'application/json'.freeze
    APPLICATION_XML = 'application/xml'.freeze
    TEXT_XML = 'text/xml'.freeze
 
    def initialize(app)
      @app = app
    end
 
    def call(env)
      case env[CONTENT_TYPE]
      when APPLICATION_JSON
        env.update(FORM_HASH => JSON.parse(env[POST_BODY].read), FORM_INPUT => env[POST_BODY])
      when APPLICATION_XML || TEXT_XML
        env.update(FORM_HASH => Hash.from_xml(env[POST_BODY].read), FORM_INPUT => env[POST_BODY])
      end
      @app.call(env)
    end
 
  end
end

use Rack::RestContentTypesBodyParse
set :environment, :development

class Book
  include DataMapper::Resource
  property :id, Serial
  property :author, String
  property :title, String
  property :created_at, DateTime
  property :updated_at, DateTime
  
  validates_is_unique :title
end

# Note that we cannot wrap this stuff into a 'before' block
# unless we explicitly want to forget about resources created
# on a previous case, (which should be the desirable behavior anyway).
configure do
  DataMapper::Logger.new(STDOUT, :debug)
  DataMapper.setup(:default, 'sqlite3::memory:')
  
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

before do
  
  accepts_xml = request.accept.index('application/xml') || request.accept.index('text/xml')
  accepts_json = request.accept.index('application/json')

  # If the Request Content-type is 'application/json' 
  # or Request Accept header has 'application/json' before 'application/xml' and the Request Content-type is not 'application/xml' or 'text/xml'
  # set the Response Content-type to 'application/json', otherwise, set it to 'application/xml':
  if is_json ||
    (!accepts_json.nil? && accepts_xml.nil? && !is_xml) ||
    (!accepts_json.nil? && !accepts_xml.nil? && (accepts_json < accepts_xml) && !is_xml)
    content_type :json
  else
    content_type :xml
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
  
  def is_xml
    request.env['CONTENT_TYPE'] == ('application/xml' || 'text/xml')
  end
  
  def is_json
    request.env['CONTENT_TYPE'] == 'application/json'
  end

end

# Trying to figure out what is required to test connection and the desired behavior...

# This is the CRUD stuff:

# Collection GET - application/xml is the default
# curl -i --url http://localhost:4000/books --header "Accept: application/json"
# curl -i --url http://localhost:4000/books --header "Accept: application/xml"
# curl -i --url http://localhost:4000/books 
get '/books' do
  (response['Content-Type'] == 'application/json') ? Book.all.to_json : Book.all.to_xml
end

# This should raise "NotImplementedError", but just to pass tests.
# It should be 405, Method not allowed:
delete '/books' do
  throw :halt, [501, 'Not Implemented']
end


#  curl -i --url http://localhost:4000/books/1 --header "Accept: application/json"
# HTTP/1.1 200 OK
# Content-Type: application/json
# Content-Length: 152
# Connection: keep-alive
# Server: thin 1.0.1 codename ?
# 
# { "id": 1, "author": "Ursula K LeGuin", "title": "The Dispossed", "created_at": "2008-06-08T17:02:28+00:00", "updated_at": "2008-06-08T17:02:28+00:00" }

# curl -i --url http://localhost:4000/books/1 --header "Accept: application/xml"

# HTTP/1.1 200 OK
# Content-Type: application/xml
# Content-Length: 248
# Connection: keep-alive
# Server: thin 1.0.1 codename ?
# 
# <book><id type='datamapper::types::serial'>1</id><author>Ursula K LeGuin</author><title>The Dispossed</title><created_at type='datetime'>2008-06-08T17:02:28+00:00</created_at><updated_at type='datetime'>2008-06-08T17:02:28+00:00</updated_at></book>
# Resource READ (GET) - application/xml is the default
get '/books/:book_id' do
  begin
    @book = Book.get!(params[:book_id])
    (response['Content-Type'] == 'application/json') ? @book.to_json : @book.to_xml
  rescue ::DataMapper::ObjectNotFoundError
    raise Sinatra::NotFound
  end
end

# Resource CREATE (POST)
# curl -H "Accept: application/xml" -d '<?xml version="1.0"?><book><title>Hello World</title><author>Anonymous</author></book>' http://localhost:4000/books
# curl -H "Accept: application/json" -d '{"author": "Anonymous", "title": "Hello World"}' http://localhost:4000/books -H "Content-Type: application/json"
post '/books' do
  @book = Book.new
  # If Content-Type header has been provided with request, we already have the request.body parsed
  if is_xml || is_json
    attrs = params
  else
    attrs = (response['Content-Type'] == 'application/xml') ? Hash.from_xml(params.to_s) : JSON.parse(params.to_s)
  end
  # When coming from XML, we have a 'book' key:
  attrs = attrs["book"] if attrs.has_key?('book')
  attrs.delete_if { |k, v| !@book.attributes.has_key?(k.to_sym) }
  @book.attributes = attrs
  
  if @book.save
    status(201)
    (response['Content-Type'] == 'application/json') ? @book.to_json : @book.to_xml
  else
    # TODO: return error messages to_xml/to_json?
    throw :halt, [409, 'Conflict']
  end
  
end

# Resource UPDATE (PUT)
# curl -X PUT -H "Accept: application/json" -d '{"author": "Anonymous", "title": "Hello World"}' http://localhost:4000/books/1 -H "Content-type: application/json"
put '/books/:book_id' do
  begin
    @book = Book.get!(params[:book_id])
  rescue ::DataMapper::ObjectNotFoundError
    raise Sinatra::NotFound
  end

  # If Content-Type header has been provided with request, we already have the request.body parsed
  if is_xml || is_json
    attrs = params
  else
    attrs = (response['Content-Type'] == 'application/xml') ? Hash.from_xml(params.to_s) : JSON.parse(params.to_s)
  end
  # When coming from XML, we have a 'book' key:
  attrs = attrs["book"] if attrs.has_key?('book')
  attrs.delete_if { |k, v| !@book.attributes.has_key?(k.to_sym) }
  @book.attributes = attrs
  
  if @book.save
    status(200)
    (response['Content-Type'] == 'application/json') ? @book.to_json : @book.to_xml
  else
    # TODO: return error messages to_xml/to_json?
    throw :halt, [409, 'Conflict']
  end
  
end

# Resource DELETE (DELETE)
# curl -X DELETE -H "Accept: application/json" http://localhost:4000/books/1
delete '/books/:book_id' do
  begin
    @book = Book.get!(params[:book_id])
  rescue ::DataMapper::ObjectNotFoundError
    raise Sinatra::NotFound
  end
  
  if @book.destroy
    throw :halt, [204, 'Gone!']
  else
    throw :halt, [409, 'Conflict']
  end
end
