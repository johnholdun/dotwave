require 'rspotify/oauth'
require 'securerandom'

DB = Sequel.connect ENV['DATABASE_URL']

Dir.glob('lib/*.rb').map { |f| require_relative f }

SPOTIFY_CLIENT_ID = ENV['SPOTIFY_CLIENT_ID']
SPOTIFY_CLIENT_SECRET = ENV['SPOTIFY_CLIENT_SECRET']
SPOTIFY_SCOPES = %w(user-follow-read playlist-modify-private)

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
  post('/sign-out') { sign_out }
  post('/queue') { queue_album }
  get('*') { not_found }

  def index
    redirect "/for/#{current_user.id}" if current_user
    haml :index
  end

  def about
    redirect '/'
  end

  def show_user(user_id)
    user = User.find user_id
    return not_found(:user) unless user

    haml :user, locals: {
      user: user,
      albums: user.recommendations
    }
  end

  def auth_callback
    generate_session_key omniauth_user
    omniauth_user.save_follows
    set_flash 'Nice to see you!'
    redirect "/for/#{omniauth_user.id}"
  end

  def sign_out
    session[:session_key] = nil
    set_flash 'See you later!'
    redirect '/'
  end

  def queue_album
    album_id = params[:album_id]
    return 401 unless current_user.present?
    return 400 unless album_id.present?
    result = current_user.save_album album_id
    if result.to_i > 0
      set_flash "Added #{result} track#{'s' unless result == 1} to your queue"
    else
      set_flash 'There was a problem adding this album to your queue :('
    end
    redirect "/for/#{current_user.id}"
  end

  def not_found(context = :page)
    status 404
    haml :not_found, locals: {
      context: context
    }
  end

  private

  def flash
    (@flash ||= session['x-flash']).tap do
      session.delete 'x-flash'
    end
  end

  def set_flash(new_flash)
    session['x-flash'] = new_flash
  end

  def omniauth_user
    @omniauth_user ||=
      User.from_client RSpotify::User.new request.env['omniauth.auth']
  end

  def current_user
    return @current_user if defined?(@current_user)
    return unless session[:session_key]
    record = User.model.where(session_key: session[:session_key]).first
    return unless record
    @current_user = User.new record
  end

  def generate_session_key(user)
    return unless user && user.id
    session_key = find_session_key
    User.model.where(id: user.id).update session_key: session_key
    @current_user = user
    session[:session_key] = session_key
  end

  def find_session_key
    key = SecureRandom.hex 32
    return key unless User.model.where(session_key: key).present?
    find_session_key
  end
end
