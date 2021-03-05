require "crystal/datum"
require "socket/address"

require "./maxminddb/extra/socket/*"
require "./maxminddb/*"

module MaxMindDB
  class DatabaseError < Exception
  end

  class IPAddressError < Exception
  end

  def self.new(path : String, capacity : Int32? = nil)
    Reader.new path: path, capacity: capacity
  end

  def self.new(slice : Bytes, capacity : Int32? = nil)
    Reader.new slice: slice, capacity: capacity
  end

  def self.new(io : IO::Memory, capacity : Int32? = nil)
    Reader.new io: io, capacity: capacity
  end
end
