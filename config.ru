require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

require './dotwave'

run Dotwave
