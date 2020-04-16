module MaxMindDB
  struct Any
    Crystal.datum types: {nil: Nil, bool: Bool, s: String, i: Int32, u16: UInt16, u32: UInt32, u64: UInt64, u128: UInt128, f: Float32, f64: Float64}, hash_key_type: String, immutable: false

    def initialize(@raw : Type)
    end

    def found?
      size > 0_i32
    end

    def empty?
      !found?
    end

    def to_json(json : ::JSON::Builder)
      raw.to_json json
    end

    def as_i : Int32
      raw.as(Int).to_i
    end
  end
end
