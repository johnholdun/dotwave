require 'forwardable'

# A generic homogenous set of records
class Collection
  extend Forwardable

  def_delegators :@all, :map, :each, :first, :last, :[], :find, :select, :reject

  attr_reader :all

  def initialize(records)
    @all = records
    @all_by_id = Hash[records.map { |r| [r.id, r] }.to_a]
  end

  def find(id)
    @all_by_id[id]
  end

  def slice(ids)
    select { |member| ids.include? member.id }
  end

  def self.from_array(klass, hashes)
    new hashes.map { |hash| klass.new hash }
  end
end
