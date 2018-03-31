DB = Sequel.connect(ENV['DATABASE_URL'])

Dir.glob('lib/*.rb').map { |f| require_relative(f) }

# Dotwave: New releases from Spotify
class Dotwave < Sinatra::Base
  set(:views, 'views')

  TIMEFRAME_OFFSETS =
    {
      'this-week' => 0,
      'last-week' => 7,
      'two-weeks-ago' => 14
    }.freeze

  DEFAULT_LIMIT = 20
  MAX_LIMIT = 100

  get('/api/albums') do
    filter = params[:filter] || {}
    timeframe = filter[:timeframe]

    if timeframe.nil?
      timeframe = TIMEFRAME_OFFSETS.keys.first
    elsif !TIMEFRAME_OFFSETS.key?(timeframe)
      content_type(:json)
      status(400)
      data = {
        errors: [
          "Bad timeframe #{timeframe}. Must be one of #{TIMEFRAME_OFFSETS.keys.join(', ')}"
        ]
      }
      return data.to_json
    end

    release_week =
      Friday.for(Date.today) - TIMEFRAME_OFFSETS[timeframe]

    page_params = params[:page] || {}
    offset = page_params[:offset].to_i
    limit = page_params[:limit].to_i
    limit = DEFAULT_LIMIT if limit == 0
    limit = [limit, MAX_LIMIT].min

    albums =
      DB[:albums]
      .order(Sequel.desc(:popularity))
      .where(Sequel.lit('popularity is not null'))
      .where(Sequel.lit('popularity > 0'))
      .where(release_week: release_week)

    if %w(album single).include?(filter[:subType])
      albums = albums.where(type: filter[:subType])
    end

    # Pagination after all filters are applied, *just* in case
    albums = albums.limit(limit).offset(offset)

    content_type(:json)

    response = {
      data: albums.map do |album|
        {
          type: 'albums',
          id: album[:id],
          title: album[:title],
          releaseWeek: album[:release_week],
          artists: album[:artists],
          popularity: album[:popularity],
          releaseDate: album[:release_date],
          subType: album[:type],
          image: album[:image_url]
        }
      end
    }

    response.to_json
  end

  get('/') do
    haml(:layout)
  end

  get('*') do
    status(404)
    haml(:layout)
  end
end
