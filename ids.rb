require 'rubygems'
require 'bundler'
require 'csv'

Bundler.require
Dotenv.load

DB = Sequel.connect ENV['DATABASE_URL']

puts DB[:album_artists].map(&:values).flatten.uniq.sort
