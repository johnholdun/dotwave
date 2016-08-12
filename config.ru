require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

require './dotwave'

use \
  Rack::Session::EncryptedCookie,
  key: 'rack.session',
  path: '/',
  expire_after: 3600,
  secret: ENV['COOKIE_SECRET'],
  httponly: true

run Dotwave
