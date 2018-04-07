class Updater
  QUERY = 'tag:new'.freeze
  SEARCH_LIMIT = 50
  NEW_RELEASES_LIMIT = 50
  FETCH_LIMIT = 50

  def initialize(client, database)
    @client = client
    @database = database
  end

  def call
    save_results(:fetch_new_releases, 1, NEW_RELEASES_LIMIT)
    save_results(:fetch_search, 1, SEARCH_LIMIT)
    remove_old_albums
  end

  def self.call(*args)
    new(*args).call
  end

  private

  attr_reader :client, :database

  def two_weeks_ago
    @two_weeks_ago ||= Friday.for(Date.today) - 14
  end

  def offset_from_page(page, limit)
    (page - 1) * limit
  end

  def fetch_search(page)
    client::Album.search \
      QUERY,
      limit: SEARCH_LIMIT,
      offset: offset_from_page(page, SEARCH_LIMIT)
  rescue
    log(:warn, "Failed to search for albums page #{page}")
    []
  end

  def fetch_new_releases(page)
    client::Album.new_releases \
      limit: NEW_RELEASES_LIMIT,
      offset: offset_from_page(page, NEW_RELEASES_LIMIT)
  rescue
    log(:warn, "Failed to return new releases page #{page}")
    []
  end

  def save_results(method_name, page, limit)
    log(:info, "Fetch page #{page} of #{method_name}")

    result = send(method_name, page)
    existing_ids = database[:albums].where(id: result.map(&:id)).map(:id)
    new_results =
      result
        .reject { |r| existing_ids.include?(r.id) }
        .reject do |release|
          release.release_date !~ /^\d{4}-\d{2}-\d{2}$/ ||
          release.release_date < two_weeks_ago.to_s
        end

    albums =
      new_results.map do |album|
        release_date = Date.new(*album.release_date.split('-').map(&:to_i))
        release_week = Friday.for(release_date)

        {
          id: album.id,
          title: album.name,
          type: album.album_type,
          release_date: album.release_date,
          release_week: release_week,
          artists: album.artists.map(&:name).join(', ')[0, 100],
          artist_id: album.artists.map(&:id).first,
          popularity: album.popularity.to_i,
          image_url: album.images.first['url']
        }
      end

    artist_ids =
      albums.select { |a| a[:popularity] == 0 }.map { |a| a[:artist_id] }.uniq

    log(:info, "Fetch #{artist_ids.size} artists")

    artists =
      if artist_ids.size > 0
        begin
          client::Artist.find(artist_ids)
        rescue
          log(:warn, "Failed to fetch #{artist_ids.size} artists")
          []
        end
      else
        []
      end

    popularities =
      artists.each_with_object({}) { |a, h| h[a.id] = a.popularity }

    albums
      .select { |a| a[:popularity] == 0 }
      .each { |a| a[:popularity] = popularities[a[:artist_id]].to_i }

    albums.each { |a| database[:albums].insert(a) }

    if result.size == limit
      save_results(method_name, page + 1, limit)
    end
  end

  def remove_old_albums
    log(:info, 'Remove albums older than two weeks ago')

    database[:albums]
      .where(Sequel.lit('release_date < ?', two_weeks_ago))
      .delete
  end

  def log(level, message)
    puts "[#{level.to_s.upcase}] #{Time.now.utc.iso8601} #{message}"
  end
end
