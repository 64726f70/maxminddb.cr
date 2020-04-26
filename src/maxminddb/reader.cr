require "./ip_address.cr"
require "./buffer.cr"
require "./decoder.cr"
require "./metadata.cr"

class MaxMindDB::Reader
  DATA_SEPARATOR_SIZE = 16_i32

  getter metadata : Metadata
  getter decoder : Decoder
  getter buffer : Buffer

  def self.new(database_path : String, capacity : Int32? = nil)
    raise DatabaseError.new "Database not found" unless File.exists? database_path

    new read_file(database_path), capacity
  end

  def initialize(database : Bytes | IO::Memory, capacity : Int32? = nil)
    @buffer = Buffer.new database.to_slice
    @metadata = Metadata.new @buffer

    pointer_base = @metadata.searchTreeSize + DATA_SEPARATOR_SIZE
    @decoder = Decoder.new @buffer, pointer_base, capacity
  end

  def ipv4_start_node=(value : Int32)
    @ipv4StartNode = value
  end

  def ipv4_start_node
    @ipv4StartNode
  end

  def get(address : String | Socket::IPAddress)
    get IPAddress.new address
  end

  def check_address_type!(address : IPAddress)
    case {metadata.ipVersion, address.ipAddress.family}
    when {4_i32, Socket::Family::INET6}
      message = String.build do |io|
        io << "Error looking up " << "'" << address.to_s << "'" << ". "
        io << "You attempted to look up an IPv6 address in an IPv4-only database."
      end

      raise ArgumentError.new message
    end
  end

  def get(address : IPAddress) : Any
    check_address_type! address

    pointer = find_address_in_tree address
    return resolve_data_pointer pointer if 0_i32 < pointer

    Any.new Hash(String, Any).new
  end

  def inspect(io : IO)
    metadata.inspect io
  end

  private def self.read_file(file_name : String) : Bytes
    file = File.new file_name, "rb"
    bytes = Bytes.new file.size

    file.read_fully bytes rescue nil
    file.close

    bytes
  end

  private def find_address_in_tree(address : IPAddress) : Int32
    raise IPAddressError.new unless raw_address = address.to_bytes

    # raw_address = address.data
    bit_size = raw_address.size * 8_i32
    node_number = start_node bit_size

    bit_size.times do |time|
      break if node_number >= metadata.nodeCount

      index = raw_address[time >> 3_i32]
      bit = 1_i32 & (index >> 7_i32 - (time % 8_i32))

      node_number = read_node node_number, bit
    end

    return 0_i32 if node_number == metadata.nodeCount
    return node_number if node_number > metadata.nodeCount

    raise DatabaseError.new "Something bad happened"
  end

  private def start_node(bit_size) : Int32
    return 0_i32 unless 6_i32 == metadata.ipVersion && 32_i32 == bit_size

    _ipv4_start_node = ipv4_start_node
    return _ipv4_start_node if _ipv4_start_node

    node_number = 0_i32

    96_i32.times do
      break if node_number >= metadata.nodeCount
      node_number = read_node node_number, 0_i32
    end

    self.ipv4_start_node = node_number
  end

  private def read_node(node_number : Int, index : Int) : Int32
    base_offset = node_number * metadata.nodeByteSize

    case metadata.recordSize
    when 24_i32
      decoder.decode_int base_offset + index * 3_i32, 3_i32, 0_i32
    when 28_i32
      middle_byte = buffer[base_offset + 3_i32].to_i32

      middle = if index.zero?
                 (0xf0_i32 & middle_byte) >> 4_i32
               else
                 middle_byte & 0x0f_i32
               end

      decoder.decode_int base_offset + index * 4_i32, 3_i32, middle
    when 32_i32
      decoder.decode_int base_offset + index * 4_i32, 4_i32, 0_i32
    else
      message = String.build { |io| io << "Unknown record size: " << metadata.recordSize.to_s }

      raise DatabaseError.new message
    end
  end

  private def resolve_data_pointer(pointer : Int) : Any
    offset = pointer - metadata.nodeCount + metadata.searchTreeSize

    if offset > buffer.size
      message = String.build do |io|
        io << "The MaxMind DB file's search tree is corrupt: "
        io << "contains pointer larger than the database."
      end

      raise DatabaseError.new message
    end

    decoder.decode(offset).as_any
  end
end
