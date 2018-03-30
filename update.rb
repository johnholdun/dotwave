require 'rubygems'
require 'bundler'
require 'pry'

Bundler.require
Dotenv.load

DB = Sequel.connect(ENV['DATABASE_URL'])

Dir.glob('lib/*.rb').map { |f| require_relative f }

puts 'Fetching data...'

RSpotify.authenticate(ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'])

begin
  Updater.call(RSpotify, DB)
rescue => e
  puts e.message
  binding.pry
end
