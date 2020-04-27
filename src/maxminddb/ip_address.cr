require "socket/address"

class MaxMindDB::IPAddress
  property ipAddress : Socket::IPAddress

  def initialize(@ipAddress : Socket::IPAddress)
  end

  def self.new(address : String)
    new Socket::IPAddress.new address, 0_i32
  end

  def to_bytes : Bytes?
    case ipAddress.family
    when .inet6?
      ipv6_to_bytes
    else
      ipv4_to_bytes
    end
  end

  private def ipv4_to_bytes : Bytes
    buffer = IO::Memory.new 4_i32

    split = ipAddress.address.split "."
    split.each { |part| buffer.write Bytes[part.to_u8] }

    buffer.to_slice
  end

  private def ipv6_to_bytes : Bytes?
    return unless ipAddress.family.inet6?

    pointer = ipAddress.to_unsafe.as LibC::SockaddrIn6*
    memory = IO::Memory.new 16_i32

    {% if flag?(:darwin) || flag?(:openbsd) || flag?(:freebsd) %}
      ipv6_address = pointer.value.sin6_addr.__u6_addr.__u6_addr8
      memory.write ipv6_address.to_slice
    {% elsif flag?(:linux) && flag?(:musl) %}
      ipv6_address = pointer.value.sin6_addr.__in6_union.__s6_addr
      memory.write ipv6_address.to_slice
    {% elsif flag?(:linux) %}
      ipv6_address = pointer.value.sin6_addr.__in6_u.__u6_addr8
      memory.write ipv6_address.to_slice
    {% else %}
      return
    {% end %}

    memory.to_slice
  end
end
