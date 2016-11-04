require 'rubygems'
require 'bundler'
require 'csv'
require 'yaml'

Bundler.require
Dotenv.load

DB = Sequel.connect ENV['DATABASE_URL']

Dir.glob('lib/*.rb').map { |f| require_relative f }

RSpotify.authenticate ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET']

puts 'Fetching data...'

UPDATER_FILENAME = 'updater.dat'.freeze

updater = Marshal.load(File.read(UPDATER_FILENAME)) rescue nil
updater ||= Updater.new(RSpotify)
begin
  updater.update!
rescue => e
  puts "\nException! #{e.inspect}\n#{e.backtrace.join("\n")}"
  puts 'Saving updater to disk...'
  File.write(UPDATER_FILENAME, Marshal.dump(updater))
  exit 1
end

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
