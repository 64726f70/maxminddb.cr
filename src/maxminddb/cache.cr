require "./any.cr"

module MaxMindDB
  struct Cache(K, V)
    property capacity : Int32
    property storage : Immutable::Map(K, V)

    def initialize(@capacity : Int32)
      @storage = Immutable::Map(K, V).new
    end

    def fetch(key : K, &block : K -> V) : V
      value = storage[key]?
      return value if value

      value = yield key

      if full?
        _storage = storage.clear
        self.storage = _storage
      end

      _storage = storage.set key, value
      self.storage = _storage

      value
    end

    def full?
      storage.size >= capacity
    end
  end
end
