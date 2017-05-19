# Fetches new releases and their artists from Spotify
class UpdaterExperiment
  FETCH_METHODS = [
    :fetch_tagged_album_ids,
    :fetch_new_releases_ids,
    :fetch_albums,
    :log_albums,
    :save_album_artists,
    :update_popularities,
    :finish
  ].freeze

  PAGINATED_METHODS = [
    :fetch_tagged_album_ids,
    :fetch_new_releases_ids,
    :fetch_albums,
    :save_album_artists,
  ].freeze

  TAGGED_QUERY = 'tag:new'.freeze
  # TAGGED_QUERY = 'year:2016'.freeze

  attr_reader \
    :albums,
    :artists

  def initialize(client, database, step = nil)
    @client = client
    @database = database

    update = database[:updates].order(:date).last
    if update.nil? || Date.current - Date.parse(update[:date]) > 5
      update_current_status([FETCH_METHODS.first])
    else
      self.current_status = [update[:step].to_sym, update[:page] || 0]
    end

    if step.present? && FETCH_METHODS.include?(step.to_sym)
      self.current_status = [step.to_sym, 0]
    end
  end

  def call
    loop do
      puts current_status.inspect.gsub(/^\[|\]$/, '')
      send(*current_status)
      break unless current_status.present?
    end
  rescue RestClient::Exception => e
    puts e.response
  end

  def self.call(*args)
    new(*args).call
  end

  private

  attr_reader :client, :database
  attr_accessor :current_status

  def fetch_tagged_album_ids(page = 0, limit = 50)
    result =
      client::Album.search \
        TAGGED_QUERY, limit: limit, offset: limit * page, market: 'US'
    result_ids = result.map(&:id)
    existing_ids = database[:albums].where(id: result_ids).map(:id)
    new_ids = result_ids - existing_ids
    database[:albums].import([:id, :release_date], new_ids.map { |id| [id, Date.current] })
    next_status!(result.present?)
  end

  def fetch_new_releases_ids(page = 0, limit = 50)
    result = client::Album.new_releases(limit: limit, offset: (limit * page))
    result_ids = result.map(&:id)
    existing_ids = database[:albums].where(id: result_ids).map(:id)
    new_ids = result_ids - existing_ids
    database[:albums].import([:id, :release_date], new_ids.map { |id| [id, Date.current] })
    next_status!(result.present?)
  end

  def fetch_albums(page = 0, limit = 20)
    album_ids =
      database[:albums]
      .where('name is null and release_date > ?', 7.days.ago.to_date)
      .limit(limit)
      .map(:id)
    result = client::Album.find(album_ids) if album_ids.present?
    if result.present?
      result.compact.each do |album|
        database[:albums]
          .where(id: album.id)
          .update \
            name: album.name,
            type: album.album_type,
            release_date: album.release_date

        artist_ids = album.artists.map(&:id)
        existing_ids = database[:artists].where(id: artist_ids).map(:id)
        new_ids = artist_ids - existing_ids
        database[:artists].import \
          [:id, :latest_release],
          new_ids.map { |id| [id, album.release_date.to_i] }
        database[:artists]
          .where(id: existing_ids)
          .where('latest_release < ?', album.release_date.to_i)
          .update(latest_release: album.release_date.to_i)
        database[:album_artists]
          .import \
            [:album_id, :artist_id],
            artist_ids.map { |id| [album.id, id] }
      end
    end
    next_status!(result.present?)
  end

  def log_albums(_ = nil)
    total_albums = database[:albums].where('release_date > ?', 7.days.ago.to_date).count
    missing_albums = database[:albums].where('release_date > ?', 7.days.ago.to_date).where('name is null').count

    puts "#{total_albums} new albums in the last 7 days"
    puts "#{missing_albums} in the last 7 days with no name yet"

    next_status!
  end

  def save_album_artists(page = 0, limit = 50)
    artist_ids =
      database[:artists]
      .where('latest_release > ?', 7.days.ago.to_date.to_time.to_i)
      .order(:id)
      .limit(limit)
      .offset(page * limit)
      .map(:id)

    result = client::Artist.find(artist_ids) if artist_ids.present?
    if result
      result.each do |artist|
        database[:artists]
          .where(id: artist.id)
          .update(name: artist.name, popularity: artist.popularity)
      end
    end
    next_status!(result.present?)
  end

  def update_popularities(_ = nil)
    database[:artists].where(name: 'Various Artists').update popularity: 0

    database.transaction do
      new_albums = database[:albums].where { release_date > 7.days.ago.to_date.to_s }

      album_artists =
        database[:album_artists]
          .where(album_id: new_albums.select(:id))
          .each_with_object({}) do |album_artist, hash|
            key = album_artist[:album_id]
            hash[key] ||= []
            hash[key] << album_artist[:artist_id]
          end

      artists =
        database[:artists]
          .where(id: album_artists.values.flatten.uniq)
          .each_with_object({}) { |a, h| h[a[:id]] = a[:popularity] }

      album_artists.each do |album_id, artist_ids|
        database[:albums]
          .where(id: album_id)
          .update(popularity: artists.slice(*artist_ids).values.compact.max)
      end
    end

    next_status!
  end

  def finish(_ = nil)
    database[:updates].delete
    next_status!
  end

  def next_status!(paginated = false)
    if paginated && PAGINATED_METHODS.include?(current_status[0])
      new_current_status = current_status
      new_current_status[1] ||= 0
      new_current_status[1] += 1
      update_current_status(new_current_status)
      return
    end

    current_index = FETCH_METHODS.index(current_status.first.to_sym)
    next_method = FETCH_METHODS[current_index + 1]
    # Being very explicit here because we want to clear out the status
    update_current_status(next_method ? [next_method] : nil)
  end

  def update_current_status(new_current_status)
    self.current_status = new_current_status
    database[:updates].delete
    return if new_current_status.nil?
    database[:updates].insert(date: Date.current.to_s, step: current_status.first.to_s, page: current_status[1] || 0)
  end
end
