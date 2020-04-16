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

  def self.ipv4_address_to_bytes(ip_address : Socket::IPAddress) : Bytes
    buffer = IO::Memory.new 4_i32

    split = ip_address.address.split "."
    split.each { |part| buffer.write Bytes[part.to_u8] }

    buffer.to_slice
  end

  def self.ipv6_address_to_bytes(ip_address : Socket::IPAddress) : Bytes?
    return unless ip_address.family.inet6?

    pointer = ip_address.to_unsafe.as LibC::SockaddrIn6*
    memory = IO::Memory.new 16_i32

    {% if flag? :darwin %}
      ipv6_address = pointer.value.sin6_addr.__u6_addr.__u6_addr8
      memory.write ipv6_address.to_slice
    {% else %}
      ipv6_address = pointer.value.sin6_addr.__in6_u.__u6_addr8
      memory.write ipv6_address.to_slice
    {% end %}

    memory.to_slice
  end

  def self.ip_address_to_bytes(ip_address : Socket::IPAddress) : Bytes?
    case ip_address.family
    when .inet6?
      ipv6_address_to_bytes ip_address
    else
      ipv4_address_to_bytes ip_address
    end
  end
end
