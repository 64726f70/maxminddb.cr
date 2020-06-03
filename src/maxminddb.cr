require "crystal/datum"
require "socket/address"

require "./maxminddb/*"

module MaxMindDB
  class DatabaseError < Exception
  end

  class IPAddressError < Exception
  end

  def self.new(input : String | Bytes | IO::Memory, capacity : Int32? = nil)
    Reader.new input, capacity
  end
end
