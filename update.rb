ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __FILE__)
$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'bundler'
require 'pry'

Bundler.require
Dotenv.load(File.expand_path('../.env', __FILE__))

DB = Sequel.connect(ENV['DATABASE_URL'])

Dir.glob(File.expand_path('../lib/*.rb', __FILE__)).map { |f| require_relative f }

RSpotify.authenticate(ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'])

Updater.call(RSpotify, DB)
