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
    puts 'Fetch new releases'
    save_results(:fetch_new_releases, 1, NEW_RELEASES_LIMIT)
    puts 'Fetch search'
    save_results(:fetch_search, 1, SEARCH_LIMIT)
    puts 'Remove bad results'
    remove_bad_results
    puts 'Set popularity'
    set_popularity(1)
    puts 'Add release weeks'
    add_release_weeks
  end

  def self.call(*args)
    new(*args).call
  end

  private

  attr_reader :client, :database

  def offset_from_page(page, limit)
    (page - 1) * limit
  end

  def fetch_search(page)
    client::Album.search \
      QUERY,
      limit: SEARCH_LIMIT,
      offset: offset_from_page(page, SEARCH_LIMIT)
  end

  def fetch_new_releases(page)
    client::Album.new_releases \
      limit: NEW_RELEASES_LIMIT,
      offset: offset_from_page(page, NEW_RELEASES_LIMIT)
  end

  def save_results(method_name, page, limit)
    result = send(method_name, page)
    existing_ids = database[:albums].where(id: result.map(&:id)).map(:id)
    new_results = result.reject { |r| existing_ids.include?(r.id) }

    new_results.each do |album|
      params = {
        id: album.id,
        title: album.name,
        type: album.album_type,
        release_date: album.release_date,
        artists: album.artists.map(&:name).join(', ')[0, 100],
        artist_id: album.artists.map(&:id).first,
        popularity: album.popularity.to_i,
        image_url: album.images.first['url']
      }

      database[:albums].insert(params)
    end

    if result.size == limit
      save_results(method_name, page + 1, limit)
    end
  end

  def remove_bad_results
    two_weeks_ago = Friday.for(Date.today) - 14
    database[:albums]
      .where(
        Sequel.lit(
          'release_date < ? or release_date not like ?',
          two_weeks_ago,
          '____-__-__'
        )
      )
      .delete
  end

  def set_popularity(page)
    albums =
      database[:albums]
      .where(popularity: 0)
      .limit(FETCH_LIMIT)
      .offset(offset_from_page(page, FETCH_LIMIT))

    return if albums.count == 0

    artist_ids = albums.map { |a| a[:artist_id] }.uniq

    result = client::Artist.find(artist_ids)
    popularities = result.each_with_object({}) { |a, h| h[a.id] = a.popularity }

    albums.each do |album|
      database[:albums]
        .where(id: album[:id])
        .update(popularity: popularities[album[:artist_id]])
    end

    if result.size == FETCH_LIMIT
      set_popularity(page + 1)
    end
  end

  def add_release_weeks
    this_week = Friday.for(Date.today)

    [0, 7, 14].each do |offset|
      week = this_week - offset

      database[:albums]
        .where(
          Sequel.lit(
            'release_week is null and release_date > ? and release_date <= ?',
            week - 7,
            week
          )
        )
        .update(release_week: week)
    end
  end
end
