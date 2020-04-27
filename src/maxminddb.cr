require "crystal/datum"
require "socket/address"

require "immutable"

require "./maxminddb/reader.cr"
require "./maxminddb/version.cr"

module MaxMindDB
  class DatabaseError < Exception
  end

  class IPAddressError < Exception
  end

  def self.open(input : String | Bytes | IO::Memory, capacity : Int32? = nil)
    Reader.new input, capacity
  end
end
