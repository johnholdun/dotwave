require 'rubygems'
require 'bundler'
require 'csv'
require 'pry'

Bundler.require
Dotenv.load

DB = Sequel.connect ENV['DATABASE_URL']

tables = {
  artists: %i(id name popularity),
  album_artists: %i(album_id artist_id),
  albums: %i(id name release_date type)
}

tables.each do |table, columns|
  records =
    File
      .read("#{table}.csv")
      .split("\n")
      .map(&:parse_csv)
      .map { |r| Hash[columns.zip r] }

  existing_id_key = table == :album_artists ? :album_id : :id

  existing_ids =
    DB[table]
      .select(existing_id_key)
      .where(existing_id_key => records.map { |r| r[existing_id_key] })
      .map(existing_id_key)

  DB.transaction do
    records.each do |record|
      next if existing_ids.include?(record[existing_id_key])
      puts "#{table.inspect} #{record.inspect}"
      DB[table].insert record
    end
  end
end
