require 'rubygems'
require 'bundler'
require 'csv'

Bundler.require
Dotenv.load

DB = Sequel.connect ENV['DATABASE_URL']

tables = {
  artists: %i(id name popularity),
  album_artists: %i(album_id artist_id),
  albums: %i(id name release_date type)
}

STEP = ARGV.first.to_sym.freeze if ARGV.first

%i(artists album_artists albums).each do |table|
  next if STEP && table != STEP

  columns, *rows =
    File
      .read("#{table}.csv")
      .split("\n")
      .map(&:parse_csv)

  columns.map!(&:to_sym)

  records = rows.map { |r| Hash[columns.zip r] }

  existing_id_key = table == :album_artists ? :album_id : :id

  existing_ids =
    DB[table]
      .select(existing_id_key)
      .where(existing_id_key => records.map { |r| r[existing_id_key] })
      .map(existing_id_key)

  puts "Loading #{table}..."

  DB.transaction do
    records.each do |record|
      if existing_ids.include?(record[existing_id_key])
        next if table == :album_artists
        DB[table].where(id: record[existing_id_key]).update record
      else
        DB[table].insert record
      end
    end
  end
end

exit if STEP && STEP != :popularity

puts 'Updating album popularities...'

DB[:artists].where(name: 'Various Artists').update popularity: 0

DB.transaction do
  albums_by_artist =
    Hash[
      DB[:album_artists]
        .all
        .group_by { |a| a[:artist_id] }
        .map { |artist_id, rows| [artist_id, rows.map { |r| r[:album_id] }] }
    ]

  DB[:artists].each do |artist|
    album_ids = albums_by_artist[artist[:id]]
    DB[:albums].where(id: album_ids).update popularity: artist[:popularity]
  end
end
