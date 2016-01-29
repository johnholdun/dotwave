require './lib/finders'

# An artist, as told by Spotify
class Artist
  extend Finders

  table_name :artists

  attr_reader \
    :id,
    :name,
    :popularity

  def initialize(attributes)
    @id = attributes[:id]
    @name = attributes[:name]
    @popularity = attributes[:popularity]
  end

  def type
    'artist'
  end

  def as_json(*)
    {
      id: id,
      name: name,
      popularity: popularity
    }
  end
end
