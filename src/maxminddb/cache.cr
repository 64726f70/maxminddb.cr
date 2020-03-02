require "./any.cr"

module MaxMindDB
  struct Cache(K, V)
    property capacity : Int32
    property storage : Hash(K, V)

    def initialize(@capacity : Int32)
      @storage = Hash(K, V).new
    end

    def fetch(key : K, &block : K -> V) : V
      value = storage[key]?

      unless value
        value = yield key
        self.storage[key] = value unless full?
      end

      value
    end

    def full?
      storage.size >= capacity
    end
  end
end
