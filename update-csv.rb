require 'rubygems'
require 'bundler'
require 'csv'

Bundler.require
Dotenv.load

DB = Sequel.connect ENV['DATABASE_URL']

Dir.glob('lib/*.rb').map { |f| require_relative f }

RSpotify.authenticate ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET']

puts 'Fetching data...'

updater = Updater.new(RSpotify).tap(&:update!)

# puts 'Comparing existing data...'

# existing_ids = File.read('ids.txt').split("\n")
# existing_ids =
#   Hash[
#     [
#       [Album, updater.albums],
#       [Artist, updater.artists]
#     ].map do |klass, records|
#       ids = [] klass.model.select(:id).where(id: records.map(&:id)).map :id
#       [klass, ids]
#     end
#   ]

puts 'Building rows...'

tables = {
  albums: [%i(id name release_date type)],
  artists: [%i(id name popularity)],
  album_artists: [%i(album_id artist_id)]
}

table_classes = {
  Album => :albums,
  Artist => :artists
}

(updater.artists.all + updater.albums).each do |record|
  # next if existing_ids.include? record.id
  header = tables[table_classes[record.class]].first
  tables[table_classes[record.class]] << header.map { |k| record.send k }
  next unless record.is_a?(Album)
  record.artists.each do |artist|
    tables[:album_artists] << [record.id, artist.id]
  end
end

puts 'Writing tables...'

tables.each do |name, rows|
  File.write "#{name}.csv", rows.map(&:to_csv).join
end
