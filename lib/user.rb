require 'forwardable'
require './lib/finders'

# A User really only exists to save or load followed artist IDs
class User
  extend Forwardable
  extend Finders

  EXPIRATION = 1.hour.to_i

  table_name :users

  attr_accessor :client

  attr_reader \
    :id,
    :fetched_at

  def initialize(attributes)
    @id = attributes[:id]
    @fetched_at = attributes[:fetched_at]
  end

  def create
    self.class.model.insert(id: id, fetched_at: fetched_at)
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

  def save_follows
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
    new(id: client.id).tap { |u| u.client = client }
  end

  private

  def fetch_follows
    @follows ||= []
    result = client.following type: 'artist', after: @follows.last
    return @follows unless result.present?
    @follows += result.map(&:id)
    fetch_follows
  end

  def update_fetched_at
    self.class.model.where(id: id).update fetched_at: Time.now.to_i
  end

  attr_reader :client
end
