$:.push File.expand_path(File.dirname(__FILE__))

gem 'dm-core', '0.10.0'
require 'dm-core'
require 'extlib'
require 'pathname'
require 'rexml/document'
require 'rubygems'
require 'addressable/uri'
require 'dm-serializer'
require 'rest_adapter/version'
require 'rest_adapter/adapter'
require 'rest_adapter/connection'
require 'rest_adapter/formats'
require 'rest_adapter/exceptions'

DataMapper::Adapters::RestAdapter = DataMapperRest::Adapter