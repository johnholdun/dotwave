require './lib/artist'
require './lib/album'

# Fetches new releases and their artists from Spotify
class Updater
  attr_reader \
    :albums,
    :artists

  def initialize(client)
    @client = client
    @album_ids = []
    @album_hashes = []
    @artist_ids = []
    @artist_hashes = []
  end

  def update!
    fetch_and_save
    minimum_timestamp = 7.days.ago.to_date.to_s

    @albums =
      @albums
      .select { |a| a.release_date >= minimum_timestamp }
      .sort_by { |a| a.artists.map(&:popularity).max }
      .reverse
      .uniq(&:identifier)
  end

  private

  attr_reader :client

  def fetch_and_save
    fetch_ids
    fetch_albums
    save_albums
    save_album_artists
    save_artists
  end

  def fetch_ids
    fetch_tagged_album_ids
    fetch_new_releases_ids
    @album_ids.uniq!
  end

  def fetch_tagged_album_ids(page = 0, limit = 50)
    result =
      client::Album.search \
        'tag:new', limit: limit, offset: limit * page, market: 'US'
    return unless result.present?
    @album_ids += result.map(&:id)
    fetch_tagged_album_ids page + 1, limit
  end

  def fetch_new_releases_ids(page = 0, limit = 50)
    result = client::Album.new_releases limit: limit, offset: (limit * page)
    return unless result.present?
    @album_ids += result.map(&:id)
    fetch_new_releases_ids page + 1, limit
  end

  def fetch_albums(page = 0, limit = 20)
    result = client::Album.find @album_ids[page * limit, limit]
    return unless result.present?
    @album_hashes += result.map { |album| album_hash(album) }
    fetch_albums page + 1, limit
  end

  def save_albums
    @album_artist_ids =
      Hash[@album_hashes.map { |a| [a[:id], a.delete(:artist_ids)] }]
    @albums = Collection.from_array(Album, @album_hashes).all
    @artist_ids = @album_artist_ids.values.flatten.uniq
  end

  def save_album_artists(page = 0, limit = 50)
    result = client::Artist.find @artist_ids[page * limit, limit]
    return unless result.present?
    @artist_hashes += result.compact.map { |artist| artist.as_json.symbolize_keys }
    save_album_artists page + 1, limit
  end

  def save_artists
    @artists = Collection.from_array(Artist, @artist_hashes)
    @albums.each { |a| a.save_artists @album_artist_ids[a.id], artists }
  end

  def album_hash(album)
    album
      .as_json
      .symbolize_keys
      .merge \
        type: album.album_type,
        artist_ids: album.artists.map(&:id)
  end
end
