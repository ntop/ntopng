--
-- (C) 2017-21 - ntop.org
--

local ipv4_utils = {}

local function ip_to_bit(ip)
  local x = 0
  local parts = string.split(ip, "%.")

  for i=0,3 do
    x = (x | (tonumber(parts[i+1]) << ((3-i)*8)))
  end

  return x
end

local function bit_to_ip(bits)
  local parts = {}

  for i=0, 3 do
    parts[i+1] = ((bits >> ((3-i)*8)) & 0xFF)
  end

  return table.concat(parts, ".")
end

--
-- Get the number of bits allocated for the network specified by the ip netmask
-- nil is returned on error
function ipv4_utils.netmask(ip)
  if not ipv4_utils.valid(ip) then
    -- bad netmask
    return nil
  end

  local parts = string.split(ip, "%.")
  local netmask = 0

  for i=1,4 do
    local val = tonumber(parts[i])
    local x = nil

    if val == 255 then x = 8
    elseif val == 254 then x = 7
    elseif val == 252 then x = 6
    elseif val == 248 then x = 5
    elseif val == 240 then x = 4
    elseif val == 224 then x = 3
    elseif val == 192 then x = 2
    elseif val == 128 then x = 1
    elseif val == 0 then x = 0
    end

    if x == nil then
      -- bad netmask
      return nil
    end

    netmask = netmask + x

    if val ~= 255 then
      for j=i+1,4 do
        if tonumber(parts[j]) ~= 0 then
          -- bad netmask
          return nil
        end
      end

      break
    end
  end

  return netmask
end

function ipv4_utils.cidr_2_addr(cidr)
  local parts = split(cidr, "/")

  if #parts ~= 2 then
    return nil
  end

  local addr = parts[1]
  local num_netmask = tonumber(parts[2])
  local netmask = 0x100000000 - (1 << (32-num_netmask))

  return addr, bit_to_ip(netmask)
end

--
-- Compares IPv4 addresses
-- Precondition: a and b are valid ipv4 addresses
-- Returns:
--    >0 if a > b
--    <0 if a < b
--    0 if a == b
--
function ipv4_utils.cmp(a, b)
   local a_parts = string.split(a, "%.")
   local b_parts = string.split(b, "%.")

   for i=1,4 do
      local a_part = tonumber(a_parts[i])
      local b_part = tonumber(b_parts[i])

      if a_part > b_part then
         return 1
      elseif a_part < b_part then
         return -1
      end
   end

   return 0
end

-- Assumption: 32bit integer are used. This is already assumed by http://bitop.luajit.org/semantics.html
function ipv4_utils.ipToInt(ip)
  local intrepr = 0

  for byte in string.gmatch(ip, "%d+") do
    intrepr = intrepr * 256 + byte
  end

  return intrepr
end

function ipv4_utils.intToIp(int)
  local parts = {
    ((int >> 24) & 0xFF),
    ((int >> 16) & 0xFF),
    ((int >> 8) & 0xFF),
    (int & 0xFF)
  }

  return table.concat(parts, ".")
end

-- Returns possible DHCP range
function ipv4_utils.get_possible_dhcp_range(ip, network, broadcast_addr)
  local ip_int = ipv4_utils.ipToInt(ip)
  local broadcast_int = ipv4_utils.ipToInt(broadcast_addr)
  local first_ip
  local last_ip

  if ip_int >= broadcast_int - 1 then
    first_ip = ipv4_utils.ipToInt(network) + 1
    last_ip = ip_int - 1
  else
    first_ip = ip_int + 1
    last_ip = broadcast_int - 1
  end

  return {
    first_ip = ipv4_utils.intToIp(first_ip),
    last_ip = ipv4_utils.intToIp(last_ip),
  }
end

function ipv4_utils.includes(network, netmask, ip)
  local lower = network
  local upper = ipv4_utils.broadcast_address(network, netmask)

  return (ipv4_utils.cmp(ip, lower) > 0) and
        (ipv4_utils.cmp(ip, upper) < 0)
end

-- Get the broadcast address for the given netmask
function ipv4_utils.broadcast_address(ip, netmask)
  local ipbit = ip_to_bit(ip)
  local maskbit = ip_to_bit(netmask)

  return bit_to_ip((~(maskbit) | ipbit))
end

-- https://stackoverflow.com/questions/10975935/lua-function-check-if-ipv4-or-ipv6-or-string
function ipv4_utils.valid(address)
   local chunks = {address:match("(%d+)%.(%d+)%.(%d+)%.(%d+)$")}

  if #chunks == 4 then
    for _, v in pairs(chunks) do
      if (tonumber(v) < 0) or (tonumber(v) > 255) then
        return false
      end
    end

    return true
  end
end

function ipv4_utils.addressToNetwork(address, netmask)
  local mask = ipv4_utils.netmask(netmask)
  return ntop.networkPrefix(address, mask) .. "/" .. mask
end

return ipv4_utils
