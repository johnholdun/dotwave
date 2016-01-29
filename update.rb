require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

DB = Sequel.connect ENV['DATABASE_URL']

Dir.glob('lib/*.rb').map { |f| require_relative f }

RSpotify.authenticate ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET']

updater = Updater.new(RSpotify).tap(&:update!)

DB.transaction do
  existing_ids =
    Hash[
      [
        [Album, updater.albums],
        [Artist, updater.artists]
      ].map do |klass, records|
        ids = klass.model.select(:id).where(id: records.map(&:id)).map :id
        [klass, ids]
      end
    ]

  (updater.artists.all + updater.albums).each do |record|
    existing = existing_ids[record.class].include? record.id
    method = existing ? :update : :insert
    record.class.model.where(id: record.id).send method, record.as_json
    next unless record.is_a?(Album) && !existing
    record.artists.each do |artist|
      DB[:album_artists].insert album_id: record.id, artist_id: artist.id
    end
  end
end
