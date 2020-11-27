require "./any.cr"

class MaxMindDB::Cache(K, V)
  property capacity : Int32
  property storage : Hash(K, V)
  property mutex : Mutex

  def initialize(@capacity : Int32)
    @storage = Hash(K, V).new
    @mutex = Mutex.new :unchecked
  end

  def get?(key : K) : V?
    @mutex.synchronize { storage[key]? }
  end

  def fetch(key : K, &block : K -> V) : V
    value = get? key
    return value if value

    value = yield key
    return value if capacity.zero?

    @mutex.synchronize do
      self.storage.clear if full?
      self.storage[key] = value
    end

    value
  end

  def full?
    capacity <= storage.size
  end
end
