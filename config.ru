require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

require './dotwave'

use \
  Rack::Session::Cookie,
  key: 'rack.session',
  path: '/',
  secret: ENV['COOKIE_SECRET']

run Dotwave
