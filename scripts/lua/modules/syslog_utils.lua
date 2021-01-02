--
-- (C) 2019-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local syslog_utils = {}

------------------------------------------------------------------------

local function getProducersMapKey(ifid)
  return string.format("ntopng.syslog.ifid_%d.producers_map", ifid)
end

------------------------------------------------------------------------

function syslog_utils.getProducers(ifid)
  local key = getProducersMapKey(ifid)
  local providers = ntop.getHashAllCache(key) or {}

  local res = {}
  for host, producer in pairs(providers) do
    res[#res + 1] = {
      host = host,
      producer = producer,
      producer_title = i18n(producer.."_collector.title"),
    }
  end

  return res
end

------------------------------------------------------------------------

function syslog_utils.hasProducer(ifid, host)
  local key = getProducersMapKey(ifid)
  local producer_type = ntop.getHashCache(key, host)
  return not isEmptyString(producer_type) 
end

------------------------------------------------------------------------

function syslog_utils.addProducer(ifid, host, producer_type)
  local key = getProducersMapKey(ifid)
  ntop.setHashCache(key, host, producer_type) 
end

------------------------------------------------------------------------

function syslog_utils.deleteProducer(ifid, host)
  local key = getProducersMapKey(ifid)
  ntop.delHashCache(key, host)
end

------------------------------------------------------------------------

return syslog_utils
