require "./any.cr"
require "./cache.cr"

module MaxMindDB
  class Decoder
    property buffer : Buffer
    property pointerBase : Int32
    property capacity : Int32?
    property pointerTest : Bool
    property cache : Cache(Int32, Node)

    private MAX_CACHE_CAPACITY    = 4096_i32
    private SIZE_BASE_VALUES      = [0_i32, 29_i32, 285_i32, 65_821_i32]
    private POINTER_VALUE_OFFSETS = [0_i32, 0_i32, 1_i32 << 11_i32, (1_i32 << 19_i32) + ((1_i32) << 11_i32), 0_i32]

    private enum DataType
      Extended
      Pointer
      Utf8
      Double
      Bytes
      Uint16
      Uint32
      Map
      Int32
      Uint64
      Uint128
      Array
      Container
      EndMarker
      Boolean
      Float
    end

    private struct Node
      getter value : Any::Type

      def initialize(@value : Any::Type)
      end

      def as_any
        Any.new value
      end
    end

    def initialize(@buffer : Buffer, @pointerBase : Int32, capacity : Int32? = nil, @pointerTest : Bool = false)
      @cache = Cache(Int32, Node).new capacity || MAX_CACHE_CAPACITY
    end

    def decode(offset : Int32) : Node
      if offset >= buffer.size
        message = String.build do |io|
          io << "The MaxMind DB file's data section contains bad data: "
          io << "pointer larger than the database."
        end

        raise DatabaseError.new message
      end

      buffer.position = offset
      decode
    end

    def decode : Node
      ctrl_byte = buffer.read_byte.to_i32
      data_type = DataType.new ctrl_byte >> 5_i32
      data_type = read_extended if data_type.extended?

      size = size_from_ctrl_byte ctrl_byte, data_type
      decode_by_type data_type, size
    end

    # Each output data field has an associated type,
    # and that type is encoded as a number that begins the data field.
    # Some types are variable length.
    #
    # In those cases, the type indicator is also followed by a length.
    # The data payload always comes at the end of the field.
    private def decode_by_type(data_type : DataType, size : Int32) : Node
      case data_type
      when .pointer?
        decode_pointer size
      when .utf8?
        decode_string size
      when .double?
        decode_double size
      when .bytes?
        decode_bytes size
      when .uint16?
        decode_uint16 size
      when .uint32?
        decode_uint32 size
      when .uint64?
        decode_uint64 size
      when .uint128?
        decode_uint128 size
      when .map?
        decode_map size
      when .int32?
        decode_int32 size
      when .array?
        decode_array size
      when .container?
        raise DatabaseError.new "Сontainers are not currently supported"
      when .end_marker?
        Node.new nil
      when .boolean?
        Node.new !size.zero?
      when .float?
        decode_float size
      else
        message = String.build { |io| io << "Unknown or unexpected type: " << data_type.to_i.to_s }
        raise DatabaseError.new message
      end
    end

    # Control byte provides information about
    # the field’s data type and payload size.
    private def size_from_ctrl_byte(ctrl_byte : Int32, data_type : DataType) : Int32
      size = ctrl_byte & 0x1f_i32

      return size if data_type.pointer? || size < 29_i32

      bytes_size = size - 28_i32
      SIZE_BASE_VALUES[bytes_size] + decode_int bytes_size
    end

    # With an extended type, the type number in the second byte is
    # the number minus 7.
    # In other words, an array (type 11) will be stored with a 0
    # for the type in the first byte and a 4 in the second.
    private def read_extended : DataType
      type_number = 7_i32 + buffer.read_byte

      if type_number < 8_i32
        message = String.build do |io|
          io << "Something went horribly wrong in the decoder. "
          io << "An extended type resolved to a type number < 8"
          io << type_number.to_s
        end

        raise DatabaseError.new message
      end

      DataType.new type_number
    end

    # Pointers are a special case, we don't read the next 'size' bytes, we
    # use the size to determine the length of the pointer and then follow it.
    private def decode_pointer(ctrl_byte : Int32) : Node
      pointer_size = ((ctrl_byte >> 3_i32) & 0x3_i32) + 1_i32
      base = pointer_size == 4_i32 ? 0_i32 : ctrl_byte & 0x7_i32
      packed = decode_int pointer_size, base
      pointer = pointerBase + packed + POINTER_VALUE_OFFSETS[pointer_size]

      return Node.new pointer if pointerTest

      position = buffer.position
      node = cache.fetch(pointer) { |offset| decode offset }
      buffer.position = position

      node
    end

    # A variable length byte sequence that contains valid utf8.
    # If the length is zero then this is an empty string.
    private def decode_string(size : Int32) : Node
      Node.new String.new buffer.read(size)
    end

    # Decode integer for external use
    def decode_int(offset : Int32, size : Int32, base : Int) : Int
      buffer[offset, size].reduce(base) { |r, v| (r << 8) | v }
    end

    # Decode integer
    private def decode_int(size : Int32, base : Int = 0_i32) : Int
      buffer.read(size).reduce(base) { |r, v| (r << 8_i32) | v }
    end

    private def decode_uint16(size : Int32) : Node
      Node.new decode_int size, 0_u16
    end

    private def decode_uint32(size : Int32) : Node
      Node.new decode_int size, 0_u32
    end

    private def decode_uint64(size : Int32) : Node
      Node.new decode_int size, 0_u64
    end

    private def decode_uint128(size : Int32) : Node
      Node.new decode_int size, 0_u128
    end

    private def decode_int32(size : Int32) : Node
      Node.new decode_int size, 0_i32
    end

    private def decode_double(size : Int32) : Node
      return Node.new IO::ByteFormat::BigEndian.decode Float64, buffer.read(size) if 8_i32 == size

      message = String.build do |io|
        io << "The MaxMind DB file's data section contains bad data: "
        io << "invalid size of double."
      end

      raise DatabaseError.new message
    end

    private def decode_float(size : Int32) : Node
      return Node.new IO::ByteFormat::BigEndian.decode Float32, buffer.read(size) if 4_i32 == size

      message = String.build do |io|
        io << "The MaxMind DB file's data section contains bad data: "
        io << "invalid size of float."
      end

      raise DatabaseError.new message
    end

    private def decode_bytes(size : Int32) : Node
      Node.new buffer.read(size).to_a.map { |e| Any.new e.to_i }
    end

    private def decode_array(size : Int32) : Node
      Node.new Array(Any).new(size) { decode.as_any }
    end

    private def decode_map(size : Int32) : Node
      map = Hash(String, Any).new
      size.times.each { map[decode.value.as(String)] = decode.as_any }

      Node.new map
    end
  end
end
