require 'forwardable'
require './lib/finders'

# A User really only exists to save or load followed artist IDs
class User
  extend Forwardable
  extend Finders

  EXPIRATION = 1.hour.to_i

  table_name :users

  attr_reader \
    :id,
    :fetched_at,
    :name,
    :playlist_id,
    :access_token

  def initialize(attributes)
    @id = attributes[:id]
    @fetched_at = attributes[:fetched_at]
    @name = attributes[:name]
    @playlist_id = attributes[:playlist_id]
    @access_token = attributes[:access_token]
  end

  def save
    self.class.model.where(id: id).update \
      name: name,
      playlist_id: playlist_id,
      access_token: access_token
  end

  def create
    self.class.model.insert(id: id, name: name, fetched_at: fetched_at)
  end

  def followed_artists
    @followed_artists ||=
      DB[:artists].where(id: DB[:follows].where(user_id: id).select(:artist_id))
  end

  def recommendations
    album_artists =
      DB[:album_artists].where(artist_id: followed_artists.map(:id))

    Album.with_artists \
      Collection.from_array \
        Album,
        Album.popular_recent_query.where(id: album_artists.map(:album_id))
  end

  def save_follows(force = false)
    return if fetched_recently? && !force

    DB.transaction do
      DB[:follows].filter(user_id: id).delete

      fetch_follows.each do |artist_id|
        DB[:follows].insert user_id: id, artist_id: artist_id
      end

      update_fetched_at
    end
  end

  def fetched_recently?
    Time.now.to_i <= fetched_at.to_i + EXPIRATION
  end

  def self.from_client(client)
    instance = find client.id
    instance ||= new(id: client.id, name: client.display_name).tap(&:create)
    instance.tap { |u| u.client = client }
  end

  def save_album(album_id)
    # just make sure we've instantiated a client, for credentials. this is debt.
    client
    # playlist.remove_tracks! playlist.tracks
    tracks = RSpotify::Album.new('id' => album_id).tracks
    tracks.size if playlist.add_tracks! tracks
  end

  def client=(new_client)
    self.access_token = new_client.credentials.token
    save
    @client = new_client
  end

  def playlist
    @playlist ||= RSpotify::Playlist.find(id, playlist_id) if playlist_id
    return @playlist if @playlist
    @playlist = client.create_playlist! 'Dotwave: New Releases', public: false
    self.class.model.where(id: id).update playlist_id: @playlist.id
    @playlist
  end

  private

  attr_writer :access_token

  def client
    return @client if defined?(@client)

    @client =
      RSpotify::User.new \
        'id' => id,
        'credentials' => {
          'token' => access_token
        }

    credentials =
      (RSpotify::User.class_variable_get(:@@users_credentials) rescue nil) || {}
    credentials[id] = @client.credentials
    RSpotify::User.class_variable_set :@@users_credentials, credentials

    @client
  end

  def fetch_follows
    @follows ||= []
    result = client.following type: 'artist', after: @follows.last
    return @follows unless result.present?
    @follows += result.map(&:id)
    fetch_follows
  end

  def lastfm_username
    'narration'
  end

  def fetch_artists
    result = []
    page = 1
    loop do
      url = "http://ws.audioscrobbler.com/2.0/?method=library.getartists&api_key=#{ENV['LASTFM_API_KEY']}&user=#{lastfm_username}&format=json&page=#{page}"
      data = JSON.parse(open(url).read, symbolize_names: true)
      result += data[:artists][:artist].map { |a| [a[:name], a[:playcount]] }
      total_pages = 10 # data[:artists][:'@attr'][:totalPages].to_i
      page += 1
      break if page > total_pages
    end
    result
  end

  def fetch_top_yearly_artists
    result = []
    page = 1
    loop do
      url = "http://ws.audioscrobbler.com/2.0/?method=user.gettopartists&api_key=#{ENV['LASTFM_API_KEY']}&user=#{lastfm_username}&format=json&page=#{page}&period=12month"
      data = JSON.parse(open(url).read, symbolize_names: true)
      result += data[:topartists][:artist].map { |a| [a[:name], a[:playcount]] }
      total_pages = [20, data[:topartists][:'@attr'][:totalPages].to_i].min
      break if page > total_pages
      page += 1
    end
    result
  end

  def update_fetched_at
    self.class.model.where(id: id).update fetched_at: Time.now.to_i
  end
end
