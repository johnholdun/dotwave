# If I were poorly recreating an ORM I might write a module called "Finders."
# Also, Sequel gives me all this and more already. Why don't I use it?
module Finders
  attr_reader :model

  def table_name(name)
    @model = ::DB[name]
  end

  def find(ids)
    array = ids.is_a?(Array)
    ids = [ids] unless array
    result = Collection.from_array self, model.where(id: ids)
    array ? result : result.first
  end
end
