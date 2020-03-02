module MaxMindDB
  struct Buffer
    property bytes : Bytes
    getter size : Int32
    property position : Int32

    def initialize(@bytes : Bytes)
      @size = @bytes.size
      @position = 0_i32
    end

    # Reads *size* bytes from this bytes buffer.
    # Returns empty `Bytes` if and only if there is no
    # more data to read.
    def read(size : Int32) : Bytes
      new_position = position + size
      return Bytes.new 0_i32 unless self.size >= new_position

      value = bytes[position, size]
      self.position = new_position

      value
    end

    # Read one byte from bytes buffer
    # Returns 0 if and only if there is no
    # more data to read.
    def read_byte : UInt8
      return 0_u8 unless size >= position

      value = bytes[position]
      self.position += 1_i32

      value
    end

    # Returns the index of the _last_ appearance of *search*
    # in the bytes buffer
    #
    # ```
    # Buffer.new(Bytes[1, 2, 3, 4, 5]).rindex(Bytes[3, 4]) # => 2
    # ```
    def rindex(search : Bytes) : Int32?
      (size - search.size - 1_i32).downto 0_i32 do |item|
        return item if search == bytes[item, search.size]
      end
    end

    macro method_missing(call)
      bytes.{{call.name}} {{*call.args}}
    end
  end
end
