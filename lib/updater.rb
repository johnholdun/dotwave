require './lib/artist'
require './lib/album'

# Fetches new releases and their artists from Spotify
class Updater
  FETCH_METHODS = [
    :fetch_tagged_album_ids,
    :fetch_new_releases_ids,
    :uniq_albums,
    :fetch_albums,
    :save_albums,
    :save_album_artists,
    :save_artists,
    :clean_albums
  ].freeze

  PAGINATED_METHODS = [
    :fetch_tagged_album_ids,
    :fetch_new_releases_ids,
    :fetch_albums,
    :save_album_artists,
  ].freeze

  TAGGED_QUERY = 'tag:new'.freeze
  # TAGGED_QUERY = 'year:2016'.freeze

  attr_reader \
    :albums,
    :artists

  def initialize(client)
    @client = client
    @album_ids = []
    @album_hashes = []
    @artist_ids = []
    @artist_hashes = []
    @current_status = [FETCH_METHODS.first]
  end

  def update!
    loop do
      puts current_status.inspect.gsub(/^\[|\]$/, '')
      send(*current_status)
      break unless current_status.present?
    end
  end

  private

  attr_reader :client
  attr_accessor :current_status

  def fetch_tagged_album_ids(page = 0, limit = 50)
    result =
      client::Album.search \
        TAGGED_QUERY, limit: limit, offset: limit * page, market: 'US'
    @album_ids += result.map(&:id)
    next_status!(result.present?)
  end

  def fetch_new_releases_ids(page = 0, limit = 50)
    result = client::Album.new_releases limit: limit, offset: (limit * page)
    @album_ids += result.map(&:id)
    next_status!(result.present?)
  end

  def uniq_albums
    @album_ids.uniq!
    next_status!
  end

  def fetch_albums(page = 0, limit = 20)
    result = client::Album.find @album_ids[page * limit, limit]
    @album_hashes += result.map { |album| album_hash(album) } if result
    next_status!(result.present?)
  end

  def save_albums
    @album_artist_ids =
      Hash[@album_hashes.map { |a| [a[:id], a.delete(:artist_ids)] }]
    @albums = Collection.from_array(Album, @album_hashes).all
    @artist_ids = @album_artist_ids.values.flatten.uniq
    next_status!
  end

  def save_album_artists(page = 0, limit = 50)
    result = client::Artist.find @artist_ids[page * limit, limit]
    @artist_hashes +=
      (result || []).compact.map { |artist| artist.as_json.symbolize_keys }
    next_status!(result.present?)
  end

  def save_artists
    @artists = Collection.from_array(Artist, @artist_hashes)
    @albums.each { |a| a.save_artists @album_artist_ids[a.id], artists }
    next_status!
  end

  def clean_albums
    minimum_timestamp = 7.days.ago.to_date.to_s

    print "--- Starting with #{@albums.size} albums..."

    @albums.select! { |a| a.release_date >= minimum_timestamp }

    puts "ending with #{@albums.size} albums"

    next_status!
  end

  def album_hash(album)
    album
      .as_json
      .symbolize_keys
      .merge \
        type: album.album_type,
        artist_ids: album.artists.map(&:id)
  end

  def next_status!(paginated = false)
    if paginated && PAGINATED_METHODS.include?(current_status[0])
      new_current_status = current_status
      new_current_status[1] ||= 0
      new_current_status[1] += 1
      self.current_status = new_current_status
      return
    end

    current_index = FETCH_METHODS.index(current_status.first)
    next_method = FETCH_METHODS[current_index + 1]
    self.current_status = if next_method
      [next_method]
    else
      # Being very explicit here because we want to clear out the status
      nil
    end
  end
end
