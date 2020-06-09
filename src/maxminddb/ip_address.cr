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
      Socket::IPAddress.ipv6_to_bytes ipAddress
    else
      Socket::IPAddress.ipv4_to_bytes ipAddress
    end
  end
end
