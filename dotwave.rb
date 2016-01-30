require 'rspotify/oauth'

DB = Sequel.connect ENV['DATABASE_URL']

Dir.glob('lib/*.rb').map { |f| require_relative f }

SPOTIFY_CLIENT_ID = ENV['SPOTIFY_CLIENT_ID']
SPOTIFY_CLIENT_SECRET = ENV['SPOTIFY_CLIENT_SECRET']
SPOTIFY_SCOPES = %w(user-follow-read)

RSpotify.authenticate \
  SPOTIFY_CLIENT_ID,
  SPOTIFY_CLIENT_SECRET

# Dotwave: personalized new releases on Spotify
class Dotwave < Sinatra::Base
  use \
    OmniAuth::Strategies::Spotify,
    SPOTIFY_CLIENT_ID,
    SPOTIFY_CLIENT_SECRET,
    scope: SPOTIFY_SCOPES.join(' ')

  set :root, File.dirname(__FILE__)
  set :views, 'views'
  layout :layout

  before do
    redirect request.path[0, -2] if request.path =~ %r{./$}
  end

  get('/') { index }
  get('/about') { about }
  get('/for/:user_id') { |user_id| show_user user_id }
  get('/auth/spotify/callback') { auth_callback }
  get('*') { not_found }

  def index
    haml :index, locals: {
      user: nil,
      albums: Album.popular
    }
  end

  def about
    haml :about
  end

  def show_user(user_id)
    user = User.find user_id
    return not_found(:user) unless user

    haml :index, locals: {
      user: user,
      albums: user.recommendations
    }
  end

  def auth_callback
    existing_user = User.find omniauth_user.id
    omniauth_user.send existing_user ? :save : :create
    omniauth_user.save_follows unless existing_user.try(:fetched_recently?)
    redirect "/for/#{omniauth_user.id}"
  end

  def not_found(context = :page)
    status 404
    haml :not_found, locals: {
      context: context
    }
  end

  private

  def omniauth_user
    @omniauth_user ||=
      User.from_client RSpotify::User.new(request.env['omniauth.auth'])
  end
end
