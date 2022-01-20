require "./any.cr"
require "./decoder.cr"

struct MaxMindDB::Metadata
  #
  METADATA_START_MARKER = "\xAB\xCD\xEFMaxMind.com".to_slice

  # The number of nodes in the search tree.
  getter nodeCount : Int32

  # The bit size of a record in the search tree.
  getter recordSize : Int32

  # The size of a node in bytes.
  getter nodeByteSize : Int32

  # The size of the search tree in bytes.
  getter searchTreeSize : Int32

  # The IP version of the data in a database.
  #
  # A value of `4` means the database only supports IPv4.
  # A database with a value of `6` may support both IPv4 and IPv6 lookups.
  getter ipVersion : Int32

  # A string identifying the database type.
  #
  # ```
  # metadata.database_type # => "GeoIP2-City"
  # ```
  getter databaseType : String

  # An array of locale codes supported by the database.
  #
  # ```
  # metadata.languages # => ["en", "de", "ru"]
  # ```
  getter languages : Array(String)

  # The Unix epoch for the build time of the database.
  getter buildEpoch : Time

  # A hash from locales to text descriptions of the database.
  getter description : Hash(String, String)

  # The major version number for the database's binary format.
  getter binaryFormatMajorVersion : Int32

  # The minor version number for the database's binary format.
  getter binaryFormatMinorVersion : Int32

  # MaxMind DB binary format version.
  #
  # ```
  # metadata.version # => "2.0"
  # ```
  getter version : String

  # :nodoc:
  def initialize(buffer : Buffer)
    marker_index = buffer.rindex METADATA_START_MARKER

    if marker_index.nil?
      raise DatabaseError.new "Metadata section not found. Is this a valid MaxMind DB file?"
    end

    start_offset = marker_index + METADATA_START_MARKER.size
    decoder = Decoder.new buffer, start_offset
    metadata = decoder.decode(start_offset).as_any
    raise DatabaseError.new "Metadata is empty" if metadata.empty?

    @nodeCount = metadata["node_count"].as_i
    @recordSize = metadata["record_size"].as_i
    @nodeByteSize = @recordSize // 4_i32
    @searchTreeSize = @nodeCount * @nodeByteSize
    @ipVersion = metadata["ip_version"].as_i
    raise DatabaseError.new "Unsupported record size" unless [24_i32, 28_i32, 32_i32].includes? @recordSize

    @databaseType = metadata["database_type"].as_s
    @description = metadata["description"].as_h.transform_values &.as_s
    @languages = metadata["languages"].as_a.map &.as_s
    @buildEpoch = Time.unix metadata["build_epoch"].as_i

    @binaryFormatMajorVersion = metadata["binary_format_major_version"].as_i
    @binaryFormatMinorVersion = metadata["binary_format_minor_version"].as_i

    @version = String.build { |io| io << @binaryFormatMajorVersion << '.' << @binaryFormatMinorVersion }
  end
end
