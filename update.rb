require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

DB = Sequel.connect ENV['DATABASE_URL']

Dir.glob('lib/*.rb').map { |f| require_relative f }

step = ARGV.first

puts 'Fetching data...'

RSpotify.authenticate(ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'])

begin
  UpdaterExperiment.call(RSpotify, DB, step)
rescue => e
  puts e.message
  puts 'Retrying in 5...'
  sleep 5
  retry
end
