require './lib/finders'

# An album on Spotify, maybe with related artists
class Album
  extend Finders

  table_name :albums

  attr_reader \
    :id,
    :name,
    :release_date,
    :artist_ids,
    :artists,
    :type

  def initialize(attributes)
    @id = attributes[:id]
    @name = attributes[:name]
    @release_date = attributes[:release_date]
    @type = attributes[:type]
  end

  # Used to determine uniqueness for different versions of the same album (e.g.
  # edited and explicit)
  def identifier
    return name unless artists.present?
    [name, artists.map(&:id)].flatten.join(' ')
  end

  def popularity
    return unless artists.present?
    artists.map(&:popularity).max
  end

  def save_artists(artist_ids, artists_collection)
    @artists = artist_ids.map { |id| artists_collection.find id }.compact.to_a
  end

  def as_json(*)
    {
      id: id,
      name: name,
      popularity: popularity,
      release_date: release_date,
      type: type
    }
  end

  def self.popular_recent_query
    model
      .where { release_date > 7.days.ago.to_date.to_s }
      .exclude(popularity: nil)
      .order(Sequel.desc :popularity)
  end

  def self.popular
    with_artists \
      Collection.from_array \
        self, popular_recent_query.limit(20)
  end

  def self.with_artists(albums)
    album_artists =
      DB[:album_artists].where(album_id: albums.map(&:id))
      .to_hash_groups(:album_id, :artist_id)

    artists = Artist.find album_artists.values.flatten.uniq

    albums.map do |album|
      album.save_artists album_artists[album.id], artists
      album
    end
  end
end
