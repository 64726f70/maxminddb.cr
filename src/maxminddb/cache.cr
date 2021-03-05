require "./any.cr"

class MaxMindDB::Caching(K, V)
  property capacity : Int32
  property entries : Hash(K, V)
  property mutex : Mutex

  def initialize(@capacity : Int32)
    @entries = Hash(K, V).new
    @mutex = Mutex.new :unchecked
  end

  def get?(key : K) : V?
    @mutex.synchronize { entries[key]? }
  end

  def fetch(key : K, &block : K -> V) : V
    value = get? key: key
    return value if value

    value = yield key
    return value if capacity.zero?

    @mutex.synchronize do
      @entries.shift if capacity == entries.size
      @entries[key] = value
    end

    value
  end

  def full?
    capacity == entries.size
  end
end
