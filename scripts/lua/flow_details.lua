--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local shaper_utils
require "lua_utils"
local alert_utils = require "alert_utils"
local format_utils = require "format_utils"
local have_nedge = ntop.isnEdge()
local nf_config = nil
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local dscp_consts = require "dscp_consts"
local tag_utils = require "tag_utils"
require "flow_utils"

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")

   if ntop.isnEdge() then
      package.path = dirs.installdir .. "/scripts/lua/pro/nedge/modules/system_config/?.lua;" .. package.path
      nf_config = require("nf_config")
   end
end

function formatASN(v)
   local asn
   
   if(v == 0) then
      asn = "&nbsp;"
   else
      asn = "<A HREF=\"".. ntop.getHttpPrefix() .."/lua/hosts_stats.lua?asn=" .. v .. "\">".. v .."</A>"
   end

   print("<td>"..asn.."</td>\n")
end

require "historical_utils"
require "flow_utils"
require "voip_utils"

local template = require "template_utils"
local categories_utils = require "categories_utils"
local protos_utils = require("protos_utils")
local discover = require("discover_utils")
local json = require ("dkjson")
local page_utils = require("page_utils")
local checks = require("checks")

local tls_cipher_suites = {
   TLS_NULL_WITH_NULL_NULL=0x000000,
   TLS_RSA_WITH_NULL_MD5=0x000001,
   TLS_RSA_WITH_NULL_SHA=0x000002,
   TLS_RSA_EXPORT_WITH_RC4_40_MD5=0x000003,
   TLS_RSA_WITH_RC4_128_MD5=0x000004,
   TLS_RSA_WITH_RC4_128_SHA=0x000005,
   TLS_RSA_EXPORT_WITH_RC2_CBC_40_MD5=0x000006,
   TLS_RSA_WITH_IDEA_CBC_SHA=0x000007,
   TLS_RSA_EXPORT_WITH_DES40_CBC_SHA=0x000008,
   TLS_RSA_WITH_DES_CBC_SHA=0x000009,
   TLS_RSA_WITH_3DES_EDE_CBC_SHA=0x00000a,
   TLS_DH_DSS_EXPORT_WITH_DES40_CBC_SHA=0x00000b,
   TLS_DH_DSS_WITH_DES_CBC_SHA=0x00000c,
   TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA=0x00000d,
   TLS_DH_RSA_EXPORT_WITH_DES40_CBC_SHA=0x00000e,
   TLS_DH_RSA_WITH_DES_CBC_SHA=0x00000f,
   TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA=0x000010,
   TLS_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA=0x000011,
   TLS_DHE_DSS_WITH_DES_CBC_SHA=0x000012,
   TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA=0x000013,
   TLS_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA=0x000014,
   TLS_DHE_RSA_WITH_DES_CBC_SHA=0x000015,
   TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA=0x000016,
   TLS_DH_anon_EXPORT_WITH_RC4_40_MD5=0x000017,
   TLS_DH_anon_WITH_RC4_128_MD5=0x000018,
   TLS_DH_anon_EXPORT_WITH_DES40_CBC_SHA=0x000019,
   TLS_DH_anon_WITH_DES_CBC_SHA=0x00001a,
   TLS_DH_anon_WITH_3DES_EDE_CBC_SHA=0x00001b,
   SSL_FORTEZZA_KEA_WITH_NULL_SHA=0x00001c,
   SSL_FORTEZZA_KEA_WITH_FORTEZZA_CBC_SHA=0x00001d,
   SSL_FORTEZZA_KEA_WITH_RC4_128_SHA=0x00001e,
   TLS_KRB5_WITH_DES_CBC_SHA=0x00001E,
   TLS_KRB5_WITH_3DES_EDE_CBC_SHA=0x00001F,
   TLS_KRB5_WITH_RC4_128_SHA=0x000020,
   TLS_KRB5_WITH_IDEA_CBC_SHA=0x000021,
   TLS_KRB5_WITH_DES_CBC_MD5=0x000022,
   TLS_KRB5_WITH_3DES_EDE_CBC_MD5=0x000023,
   TLS_KRB5_WITH_RC4_128_MD5=0x000024,
   TLS_KRB5_WITH_IDEA_CBC_MD5=0x000025,
   TLS_KRB5_EXPORT_WITH_DES_CBC_40_SHA=0x000026,
   TLS_KRB5_EXPORT_WITH_RC2_CBC_40_SHA=0x000027,
   TLS_KRB5_EXPORT_WITH_RC4_40_SHA=0x000028,
   TLS_KRB5_EXPORT_WITH_DES_CBC_40_MD5=0x000029,
   TLS_KRB5_EXPORT_WITH_RC2_CBC_40_MD5=0x00002A,
   TLS_KRB5_EXPORT_WITH_RC4_40_MD5=0x00002B,
   TLS_PSK_WITH_NULL_SHA=0x00002C,
   TLS_DHE_PSK_WITH_NULL_SHA=0x00002D,
   TLS_RSA_PSK_WITH_NULL_SHA=0x00002E,
   TLS_RSA_WITH_AES_128_CBC_SHA=0x00002f,
   TLS_DH_DSS_WITH_AES_128_CBC_SHA=0x000030,
   TLS_DH_RSA_WITH_AES_128_CBC_SHA=0x000031,
   TLS_DHE_DSS_WITH_AES_128_CBC_SHA=0x000032,
   TLS_DHE_RSA_WITH_AES_128_CBC_SHA=0x000033,
   TLS_DH_anon_WITH_AES_128_CBC_SHA=0x000034,
   TLS_RSA_WITH_AES_256_CBC_SHA=0x000035,
   TLS_DH_DSS_WITH_AES_256_CBC_SHA=0x000036,
   TLS_DH_RSA_WITH_AES_256_CBC_SHA=0x000037,
   TLS_DHE_DSS_WITH_AES_256_CBC_SHA=0x000038,
   TLS_DHE_RSA_WITH_AES_256_CBC_SHA=0x000039,
   TLS_DH_anon_WITH_AES_256_CBC_SHA=0x00003A,
   TLS_RSA_WITH_NULL_SHA256=0x00003B,
   TLS_RSA_WITH_AES_128_CBC_SHA256=0x00003C,
   TLS_RSA_WITH_AES_256_CBC_SHA256=0x00003D,
   TLS_DH_DSS_WITH_AES_128_CBC_SHA256=0x00003E,
   TLS_DH_RSA_WITH_AES_128_CBC_SHA256=0x00003F,
   TLS_DHE_DSS_WITH_AES_128_CBC_SHA256=0x000040,
   TLS_RSA_WITH_CAMELLIA_128_CBC_SHA=0x000041,
   TLS_DH_DSS_WITH_CAMELLIA_128_CBC_SHA=0x000042,
   TLS_DH_RSA_WITH_CAMELLIA_128_CBC_SHA=0x000043,
   TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA=0x000044,
   TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA=0x000045,
   TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA=0x000046,
   TLS_ECDH_ECDSA_WITH_NULL_SHA=0x000047,
   TLS_ECDH_ECDSA_WITH_RC4_128_SHA=0x000048,
   TLS_ECDH_ECDSA_WITH_DES_CBC_SHA=0x000049,
   TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA=0x00004A,
   TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA=0x00004B,
   TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA=0x00004C,
   TLS_RSA_EXPORT1024_WITH_RC4_56_MD5=0x000060,
   TLS_RSA_EXPORT1024_WITH_RC2_CBC_56_MD5=0x000061,
   TLS_RSA_EXPORT1024_WITH_DES_CBC_SHA=0x000062,
   TLS_DHE_DSS_EXPORT1024_WITH_DES_CBC_SHA=0x000063,
   TLS_RSA_EXPORT1024_WITH_RC4_56_SHA=0x000064,
   TLS_DHE_DSS_EXPORT1024_WITH_RC4_56_SHA=0x000065,
   TLS_DHE_DSS_WITH_RC4_128_SHA=0x000066,
   TLS_DHE_RSA_WITH_AES_128_CBC_SHA256=0x000067,
   TLS_DH_DSS_WITH_AES_256_CBC_SHA256=0x000068,
   TLS_DH_RSA_WITH_AES_256_CBC_SHA256=0x000069,
   TLS_DHE_DSS_WITH_AES_256_CBC_SHA256=0x00006A,
   TLS_DHE_RSA_WITH_AES_256_CBC_SHA256=0x00006B,
   TLS_DH_anon_WITH_AES_128_CBC_SHA256=0x00006C,
   TLS_DH_anon_WITH_AES_256_CBC_SHA256=0x00006D,
   TLS_RSA_WITH_CAMELLIA_256_CBC_SHA=0x000084,
   TLS_DH_DSS_WITH_CAMELLIA_256_CBC_SHA=0x000085,
   TLS_DH_RSA_WITH_CAMELLIA_256_CBC_SHA=0x000086,
   TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA=0x000087,
   TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA=0x000088,
   TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA=0x000089,
   TLS_PSK_WITH_RC4_128_SHA=0x00008A,
   TLS_PSK_WITH_3DES_EDE_CBC_SHA=0x00008B,
   TLS_PSK_WITH_AES_128_CBC_SHA=0x00008C,
   TLS_PSK_WITH_AES_256_CBC_SHA=0x00008D,
   TLS_DHE_PSK_WITH_RC4_128_SHA=0x00008E,
   TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA=0x00008F,
   TLS_DHE_PSK_WITH_AES_128_CBC_SHA=0x000090,
   TLS_DHE_PSK_WITH_AES_256_CBC_SHA=0x000091,
   TLS_RSA_PSK_WITH_RC4_128_SHA=0x000092,
   TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA=0x000093,
   TLS_RSA_PSK_WITH_AES_128_CBC_SHA=0x000094,
   TLS_RSA_PSK_WITH_AES_256_CBC_SHA=0x000095,
   TLS_RSA_WITH_SEED_CBC_SHA=0x000096,
   TLS_DH_DSS_WITH_SEED_CBC_SHA=0x000097,
   TLS_DH_RSA_WITH_SEED_CBC_SHA=0x000098,
   TLS_DHE_DSS_WITH_SEED_CBC_SHA=0x000099,
   TLS_DHE_RSA_WITH_SEED_CBC_SHA=0x00009A,
   TLS_DH_anon_WITH_SEED_CBC_SHA=0x00009B,
   TLS_RSA_WITH_AES_128_GCM_SHA256=0x00009C,
   TLS_RSA_WITH_AES_256_GCM_SHA384=0x00009D,
   TLS_DHE_RSA_WITH_AES_128_GCM_SHA256=0x00009E,
   TLS_DHE_RSA_WITH_AES_256_GCM_SHA384=0x00009F,
   TLS_DH_RSA_WITH_AES_128_GCM_SHA256=0x0000A0,
   TLS_DH_RSA_WITH_AES_256_GCM_SHA384=0x0000A1,
   TLS_DHE_DSS_WITH_AES_128_GCM_SHA256=0x0000A2,
   TLS_DHE_DSS_WITH_AES_256_GCM_SHA384=0x0000A3,
   TLS_DH_DSS_WITH_AES_128_GCM_SHA256=0x0000A4,
   TLS_DH_DSS_WITH_AES_256_GCM_SHA384=0x0000A5,
   TLS_DH_anon_WITH_AES_128_GCM_SHA256=0x0000A6,
   TLS_DH_anon_WITH_AES_256_GCM_SHA384=0x0000A7,
   TLS_PSK_WITH_AES_128_GCM_SHA256=0x0000A8,
   TLS_PSK_WITH_AES_256_GCM_SHA384=0x0000A9,
   TLS_DHE_PSK_WITH_AES_128_GCM_SHA256=0x0000AA,
   TLS_DHE_PSK_WITH_AES_256_GCM_SHA384=0x0000AB,
   TLS_RSA_PSK_WITH_AES_128_GCM_SHA256=0x0000AC,
   TLS_RSA_PSK_WITH_AES_256_GCM_SHA384=0x0000AD,
   TLS_PSK_WITH_AES_128_CBC_SHA256=0x0000AE,
   TLS_PSK_WITH_AES_256_CBC_SHA384=0x0000AF,
   TLS_PSK_WITH_NULL_SHA256=0x0000B0,
   TLS_PSK_WITH_NULL_SHA384=0x0000B1,
   TLS_DHE_PSK_WITH_AES_128_CBC_SHA256=0x0000B2,
   TLS_DHE_PSK_WITH_AES_256_CBC_SHA384=0x0000B3,
   TLS_DHE_PSK_WITH_NULL_SHA256=0x0000B4,
   TLS_DHE_PSK_WITH_NULL_SHA384=0x0000B5,
   TLS_RSA_PSK_WITH_AES_128_CBC_SHA256=0x0000B6,
   TLS_RSA_PSK_WITH_AES_256_CBC_SHA384=0x0000B7,
   TLS_RSA_PSK_WITH_NULL_SHA256=0x0000B8,
   TLS_RSA_PSK_WITH_NULL_SHA384=0x0000B9,
   TLS_RSA_WITH_CAMELLIA_128_CBC_SHA256=0x0000BA,
   TLS_DH_DSS_WITH_CAMELLIA_128_CBC_SHA256=0x0000BB,
   TLS_DH_RSA_WITH_CAMELLIA_128_CBC_SHA256=0x0000BC,
   TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA256=0x0000BD,
   TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA256=0x0000BE,
   TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA256=0x0000BF,
   TLS_RSA_WITH_CAMELLIA_256_CBC_SHA256=0x0000C0,
   TLS_DH_DSS_WITH_CAMELLIA_256_CBC_SHA256=0x0000C1,
   TLS_DH_RSA_WITH_CAMELLIA_256_CBC_SHA256=0x0000C2,
   TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA256=0x0000C3,
   TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA256=0x0000C4,
   TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA256=0x0000C5,
   TLS_EMPTY_RENEGOTIATION_INFO_SCSV=0x0000FF,
   TLS_ECDH_ECDSA_WITH_NULL_SHA=0x00c001,
   TLS_ECDH_ECDSA_WITH_RC4_128_SHA=0x00c002,
   TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA=0x00c003,
   TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA=0x00c004,
   TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA=0x00c005,
   TLS_ECDHE_ECDSA_WITH_NULL_SHA=0x00c006,
   TLS_ECDHE_ECDSA_WITH_RC4_128_SHA=0x00c007,
   TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA=0x00c008,
   TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA=0x00c009,
   TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA=0x00c00a,
   TLS_ECDH_RSA_WITH_NULL_SHA=0x00c00b,
   TLS_ECDH_RSA_WITH_RC4_128_SHA=0x00c00c,
   TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA=0x00c00d,
   TLS_ECDH_RSA_WITH_AES_128_CBC_SHA=0x00c00e,
   TLS_ECDH_RSA_WITH_AES_256_CBC_SHA=0x00c00f,
   TLS_ECDHE_RSA_WITH_NULL_SHA=0x00c010,
   TLS_ECDHE_RSA_WITH_RC4_128_SHA=0x00c011,
   TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA=0x00c012,
   TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA=0x00c013,
   TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA=0x00c014,
   TLS_ECDH_anon_WITH_NULL_SHA=0x00c015,
   TLS_ECDH_anon_WITH_RC4_128_SHA=0x00c016,
   TLS_ECDH_anon_WITH_3DES_EDE_CBC_SHA=0x00c017,
   TLS_ECDH_anon_WITH_AES_128_CBC_SHA=0x00c018,
   TLS_ECDH_anon_WITH_AES_256_CBC_SHA=0x00c019,
   TLS_SRP_SHA_WITH_3DES_EDE_CBC_SHA=0x00C01A,
   TLS_SRP_SHA_RSA_WITH_3DES_EDE_CBC_SHA=0x00C01B,
   TLS_SRP_SHA_DSS_WITH_3DES_EDE_CBC_SHA=0x00C01C,
   TLS_SRP_SHA_WITH_AES_128_CBC_SHA=0x00C01D,
   TLS_SRP_SHA_RSA_WITH_AES_128_CBC_SHA=0x00C01E,
   TLS_SRP_SHA_DSS_WITH_AES_128_CBC_SHA=0x00C01F,
   TLS_SRP_SHA_WITH_AES_256_CBC_SHA=0x00C020,
   TLS_SRP_SHA_RSA_WITH_AES_256_CBC_SHA=0x00C021,
   TLS_SRP_SHA_DSS_WITH_AES_256_CBC_SHA=0x00C022,
   TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256=0x00C023,
   TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384=0x00C024,
   TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256=0x00C025,
   TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384=0x00C026,
   TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256=0x00C027,
   TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384=0x00C028,
   TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256=0x00C029,
   TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384=0x00C02A,
   TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256=0x00C02B,
   TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384=0x00C02C,
   TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256=0x00C02D,
   TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384=0x00C02E,
   TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256=0x00C02F,
   TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384=0x00C030,
   TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256=0x00C031,
   TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384=0x00C032,
   TLS_ECDHE_PSK_WITH_RC4_128_SHA=0x00C033,
   TLS_ECDHE_PSK_WITH_3DES_EDE_CBC_SHA=0x00C034,
   TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA=0x00C035,
   TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA=0x00C036,
   TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256=0x00C037,
   TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384=0x00C038,
   TLS_ECDHE_PSK_WITH_NULL_SHA=0x00C039,
   TLS_ECDHE_PSK_WITH_NULL_SHA256=0x00C03A,
   TLS_ECDHE_PSK_WITH_NULL_SHA384=0x00C03B,
   TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256=0x00CC13,
   TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256=0x00CC14,
   TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256=0x00CC15,
   TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256=0x00CCA8,
   TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256=0x00CCA9,
   TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256=0x00CCAA,
   TLS_PSK_WITH_CHACHA20_POLY1305_SHA256=0x00CCAB,
   TLS_ECDHE_PSK_WITH_CHACHA20_POLY1305_SHA256=0x00CCAC,
   TLS_DHE_PSK_WITH_CHACHA20_POLY1305_SHA256=0x00CCAD,
   TLS_RSA_PSK_WITH_CHACHA20_POLY1305_SHA256=0x00CCAE,
   TLS_RSA_WITH_ESTREAM_SALSA20_SHA1=0x00E410,
   TLS_RSA_WITH_SALSA20_SHA1=0x00E411,
   TLS_ECDHE_RSA_WITH_ESTREAM_SALSA20_SHA1=0x00E412,
   TLS_ECDHE_RSA_WITH_SALSA20_SHA1=0x00E413,
   TLS_ECDHE_ECDSA_WITH_ESTREAM_SALSA20_SHA1=0x00E414,
   TLS_ECDHE_ECDSA_WITH_SALSA20_SHA1=0x00E415,
   TLS_PSK_WITH_ESTREAM_SALSA20_SHA1=0x00E416,
   TLS_PSK_WITH_SALSA20_SHA1=0x00E417,
   TLS_ECDHE_PSK_WITH_ESTREAM_SALSA20_SHA1=0x00E418,
   TLS_ECDHE_PSK_WITH_SALSA20_SHA1=0x00E419,
   TLS_RSA_PSK_WITH_ESTREAM_SALSA20_SHA1=0x00E41A,
   TLS_RSA_PSK_WITH_SALSA20_SHA1=0x00E41B,
   TLS_DHE_PSK_WITH_ESTREAM_SALSA20_SHA1=0x00E41C,
   TLS_DHE_PSK_WITH_SALSA20_SHA1=0x00E41D,
   TLS_DHE_RSA_WITH_ESTREAM_SALSA20_SHA1=0x00E41E,
   TLS_DHE_RSA_WITH_SALSA20_SHA1=0x00E41F,
   SSL_RSA_FIPS_WITH_DES_CBC_SHA=0x00fefe,
   SSL_RSA_FIPS_WITH_3DES_EDE_CBC_SHA=0x00feff,
   SSL_RSA_FIPS_WITH_3DES_EDE_CBC_SHA=0x00ffe0,
   SSL_RSA_FIPS_WITH_DES_CBC_SHA=0x00ffe1,
   SSL2_RC4_128_WITH_MD5=0x010080,
   SSL2_RC4_128_EXPORT40_WITH_MD5=0x020080,
   SSL2_RC2_128_CBC_WITH_MD5=0x030080,
   SSL2_RC2_128_CBC_EXPORT40_WITH_MD5=0x040080,
   SSL2_IDEA_128_CBC_WITH_MD5=0x050080,
   SSL2_DES_64_CBC_WITH_MD5=0x060040,
   SSL2_DES_192_EDE3_CBC_WITH_MD5=0x0700c0,
   SSL2_RC4_64_WITH_MD5=0x080080,
}

local function colorNotZero(v)
   if(v == 0) then
      return("0")
   else
      return('<span style="color: red">'..formatValue(v).."</span>")
   end
end

local function cipher2str(c)
   if(c == nil) then return end

   for s,v in pairs(tls_cipher_suites) do
      if(v == c) then
	 return('<A HREF="https://ciphersuite.info/cs/'..s..'">'..s..'</A>')
      end
   end

   return(c)
end

local function drawiecgraph(iec, total)
   local nodes = {}
   local nodes_id = {}
   
   -- tprint(iec)

   for k,v in pairs(iec) do
      local keys = split(k, ",")

      nodes[keys[1]] = true
      nodes[keys[2]] = true
   end
      
   print [[ <script type="text/javascript" src="/js/vis-network.min.js?]] print(ntop.getStaticFileEpoch()) print[["></script>

      <div style="width:100%; height:30vh; " id="myiecflow"></div>

  <script type="text/javascript">
      var nodes = null;
      var edges = null;
      var network = null;

      function draw() {
        // create people.
        // value corresponds with the age of the person
        nodes = [
]]
      local i = 1
   for k,_ in pairs(nodes) do
      local label = iec104_typeids2str(tonumber(k))

      print("{ id: "..i..", label: \""..label.."\" },\n")
      nodes_id[k] = i
      i = i + 1
   end

print [[
   ];

        // create connections between people
        // value corresponds with the amount of contact between two people
        edges = [
]]

local uni = {}
local bi = {}

   for k,v in pairs(iec) do
      local keys = split(k, ",")

      if(iec[keys[2]..","..keys[1]] == nil) then
	 uni[k] = v
      else
	 if(keys[2] < keys[1]) then
	    bi[keys[2]..","..keys[1]] = v
	 else
	    bi[keys[1]..","..keys[2]] = v
	 end
      end
   end

   for k,v in pairs(uni) do
      local keys = split(k, ",")
      local label = string.format("%.3f %%", (v*100)/total)
      
      nodes[keys[1]] = true
      nodes[keys[2]] = true

      print("{ from: "..nodes_id[keys[1]]..", to: "..nodes_id[keys[2]]..", value: "..v..", title: \""..label.."\", arrows: \"to\" },\n")
   end

   for k,v in pairs(bi) do
      local keys = split(k, ",")
      local label = string.format("%.3f %%", (v*100)/total)
      
      nodes[keys[1]] = true
      nodes[keys[2]] = true

      print("{ from: "..nodes_id[keys[1]]..", to: "..nodes_id[keys[2]]..", value: "..v..", title: \""..label.."\", arrows: \"to,from\" },\n")
   end

print [[
        ];

        // Instantiate our network object.
        var container = document.getElementById("myiecflow");
        var data = {
          nodes: nodes,
          edges: edges,
        };
        var options = {
autoResize: true,
          nodes: {
            shape: "dot",
            scaling: {
              label: {
                min: 2,
                max: 80,
              },
             shadow: true,
             smooth: true,
            },
          },
        };
        network = new vis.Network(container, data, options);
      }

draw();


    </script>
       ]]
end

   
local function ja3url(what, safety)
   if(what == nil) then
      print("&nbsp;")
   else
      ret = '<A HREF="https://sslbl.abuse.ch/ja3-fingerprints/'..what..'/">'..what..'</A> <i class="fas fa-external-link-alt"></i>'
      if((safety ~= nil) and (safety ~= "safe")) then
	 ret = ret .. ' [ <i class="fas fa-exclamation-triangle" aria-hidden=true style="color: orange;"></i> <A HREF=https://en.wikipedia.org/wiki/Cipher_suite>'..capitalize(safety)..' Cipher</A> ]'
      end

      print(ret)
   end
end

sendHTTPContentTypeHeader('text/html')


warn_shown = 0

local alert_banners = {}
local status_icon = "<span class='text-danger'><i class=\"fas fa-lg fa-exclamation-triangle\"></i></span>"

if isAdministrator() then
   if _POST["custom_hosts"] and _POST["l7proto"] then
      local proto_id = tonumber(_POST["l7proto"])
      local proto_name = interface.getnDPIProtoName(proto_id)

      if protos_utils.addAppRule(proto_name, {match="host", value=_POST["custom_hosts"]}) then
	 local info = ntop.getInfo()

	 alert_banners[#alert_banners + 1] = {
          type = "success",
          text = i18n("custom_categories.protos_reboot_necessary", {product=info.product})
        }
      else
	 alert_banners[#alert_banners + 1] = {
	    type="danger",
	    text=i18n("flow_details.could_not_add_host_to_category",
	       {host=_POST["custom_hosts"], category=proto_name})
	 }
      end
   elseif _POST["custom_hosts"] and _POST["category"] then
      local lists_utils = require("lists_utils")
      local category_id = tonumber(split(_POST["category"], "cat_")[2])

      if categories_utils.addCustomCategoryHost(category_id, _POST["custom_hosts"]) then
	 lists_utils.reloadLists()
	 local label = interface.getnDPICategoryName(category_id)

	 alert_banners[#alert_banners + 1] = {
	    type="success",
	    text=i18n("flow_details.host_successfully_added_to_category",
	       {host=_POST["custom_hosts"], category=(i18n("ndpi_categories." .. label) or label),
	       url = ntop.getHttpPrefix() .. "/lua/admin/edit_categories.lua?l7proto=" .. category_id})
	 }
      else
	 local label = interface.getnDPICategoryName(category_id)

	 alert_banners[#alert_banners + 1] = {
	    type="danger",
	    text=i18n("flow_details.could_not_add_host_to_category",
	       {host=_POST["custom_hosts"], category=(i18n("ndpi_categories." .. label) or label)})
	 }
      end
   end
end

local function printAddCustomHostRule(full_url)
   if not isAdministrator() then
      return
   end

   local categories = interface.getnDPICategories()
   local protocols = interface.getnDPIProtocols()
   local short_url = categories_utils.getSuggestedHostName(full_url)

   -- Fill the category dropdown
   local cat_select_dropdown = '<select id="flow_target_category" class="form-select">'

   for cat_name, cat_id in pairsByKeys(categories, asc_insensitive) do
      cat_select_dropdown = cat_select_dropdown .. [[<option value="cat_]] ..cat_id .. [[">]] .. (i18n("ndpi_categories." .. cat_name) or cat_name) .. [[</option>]]
   end
   cat_select_dropdown = cat_select_dropdown .. "</select>"

   -- Fill the application dropdown
   local app_select_dropdown = '<select id="flow_target_app" class="form-select" style="display:none">'

   for proto_name, proto_id in pairsByKeys(protocols, asc_insensitive) do
      app_select_dropdown = app_select_dropdown .. [[<option value="]] ..proto_id .. [[">]] .. proto_name .. [[</option>]]
   end
   app_select_dropdown = app_select_dropdown .. "</select>"

   -- Put a note if the URL is already assigned to another customized category
   local existing_note = ""
   local matched_category = ntop.matchCustomCategory(full_url)

   existing_note = "<br>" ..
      i18n("flow_details.existing_rules_note",
	 {name=i18n("custom_categories.apps_and_categories"), url=ntop.getHttpPrefix().."/lua/admin/edit_categories.lua"})

   if matched_category ~= nil then
      local cat_name = interface.getnDPICategoryName(matched_category)

      existing_note = existing_note .. "<br><br>" .. i18n("details.note") .. ": " ..
	 i18n("custom_categories.similar_host_found", {host=page_utils.safe_html(full_url), category=(i18n("ndpi_categories." .. cat_name) or cat_name)}) ..
	 "<br><br>"
   end

   local rule_type_selection = ""
   if protos_utils.hasProtosFile() then
      rule_type_selection = i18n("flow_details.rule_type")..":"..[[<br><select id="new_rule_type" onchange="new_rule_dropdown_select(this)" class="form-select">
	    <option value="application">]]..i18n("application")..[[</option>
	    <option value="category" selected>]]..i18n("category")..[[</option>
	 </select><br>]]
   end

   print(
     template.gen("modal_confirm_dialog.html", {
       dialog={
	 id      = "add_to_customized_categories",
	 action  = "addToCustomizedCategories()",
	 custom_alert_class = "",
	 custom_dialog_class = "dialog-body-full-height",
	 title   = i18n("custom_categories.custom_host_category"),
	 message = rule_type_selection .. i18n("custom_categories.select_url_category") .. "<br>" ..
	    cat_select_dropdown .. app_select_dropdown .. "<br>" .. i18n("custom_categories.the_following_url_will_be_added") ..
	    '<br><input id="categories_url_add" class="form-control" required value="'.. short_url ..'">' .. existing_note,
	 confirm = i18n("custom_categories.add"),
	 cancel = i18n("cancel"),
       }
     })
   )

   print(' <a href="#" onclick="$(\'#add_to_customized_categories\').modal(\'show\'); return false;"><i title="'.. i18n("custom_categories.add_to_categories") ..'" class="fas fa-plus"></i></a>')

   print[[<script>
   function addToCustomizedCategories() {
      var is_category = ($("#new_rule_type").val() == "category");
      var target_value = is_category ? $("#flow_target_category").val() : $("#flow_target_app").val();;
      var target_url = NtopUtils.cleanCustomHostUrl($("#categories_url_add").val());

      if(!target_value || !target_url)
	 return;

      var params = {};
      params.custom_hosts = target_url;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      if(is_category)
	 params.category = target_value;
      else
	 params.l7proto = target_value;

      NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
   }

   function new_rule_dropdown_select(dropdown) {
      if($(dropdown).val() == "category") {
	 $("#flow_target_category").show();
	 $("#flow_target_app").hide();
      } else {
	 $("#flow_target_category").hide();
	 $("#flow_target_app").show();
      }
   }
</script>]]
end

local function displayContainer(cont, label)
   print(label)

   if not isEmptyString(cont["id"]) then
      -- short 12-chars UUID as in docker
      print("<tr><th width=30%>"..i18n("containers_stats.container").."</th><td colspan=2><a href='"..ntop.getHttpPrefix().."/lua/flows_stats.lua?container=".. cont["id"] .."'>"..format_utils.formatContainer(cont).."</a></td></tr>\n")
   end

   local k8s_name = cont["k8s.name"]
   local k8s_pod = cont["k8s.pod"]
   local k8s_ns = cont["k8s.ns"]

   local k8s_rows = {}
   if not isEmptyString(k8s_name) then k8s_rows[#k8s_rows + 1] = {i18n("flow_details.k8s_name"), k8s_name} end
   if not isEmptyString(k8s_pod)  then k8s_rows[#k8s_rows + 1] = {i18n("flow_details.k8s_pod"), '<a href="' .. ntop.getHttpPrefix() .. '/lua/containers_stats.lua?pod='.. k8s_pod ..'">' .. k8s_pod .. '</a>'} end
   if not isEmptyString(k8s_ns)   then k8s_rows[#k8s_rows + 1] = {i18n("flow_details.k8s_ns"), k8s_ns} end

   for i, row in ipairs(k8s_rows) do
      local header = ''

      if i == 1 then
	 header = "<th width=30% rowspan="..(#k8s_rows)..">"..i18n("flow_details.k8s").."</th>"
      end

      print("<tr>"..header.."<th>"..row[1].."</th><td>"..row[2].."</td></tr>\n")
   end

   local docker_name = cont["docker.name"]

   local docker_rows = {}
   if not isEmptyString(docker_name) then docker_rows[#docker_rows + 1] = {i18n("flow_details.docker_name"), docker_name} end

   for i, row in ipairs(docker_rows) do
      local header = ''

      if i == 1 then
	 header = "<th width=30% rowspan="..(#docker_rows)..">"..i18n("flow_details.docker").."</th>"
      end

      print("<tr>"..header.."<th>"..row[1].."</th><td>"..row[2].."</td></tr>\n")
   end
end

local function displayProc(proc, label)
   if(proc.pid == 0) then return end

   print(label)

   print("<tr><th width=30%>"..i18n("flow_details.user_name").."</th><td colspan=2><A HREF=\""..ntop.getHttpPrefix().."/lua/username_details.lua?uid=" .. proc.uid .. "&username=".. proc.user_name .."&".. hostinfo2url(flow,"cli").."\">".. proc.user_name .."</A></td></tr>\n")
   print("<tr><th width=30%>"..i18n("flow_details.process_pid_name").."</th><td colspan=2><A HREF=\""..ntop.getHttpPrefix().."/lua/process_details.lua?pid=".. proc.pid .."&pid_name=".. proc.name .. "&" .. hostinfo2url(flow,"srv").. "\">".. proc.name .. " [pid: "..proc.pid.."]</A>")
   if proc.father_pid then
      print(" "..i18n("flow_details.son_of_father_process",{url=ntop.getHttpPrefix().."/lua/process_details.lua?pid="..proc.father_pid .. "&pid_name=".. proc.father_name .. "&" .. hostinfo2url(flow,"srv"), proc_father_pid = proc.father_pid, proc_father_name = proc.father_name}).."</td></tr>\n")
   end

   if((proc.actual_memory ~= nil) and (proc.actual_memory > 0)) then
      print("<tr><th width=30%>"..i18n("graphs.actual_memory").."</th><td colspan=2>".. bytesToSize(proc.actual_memory * 1024) .. "</td></tr>\n")
      print("<tr><th width=30%>"..i18n("graphs.peak_memory").."</th><td colspan=2>".. bytesToSize(proc.peak_memory * 1024) .. "</td></tr>\n")
   end
end

page_utils.set_active_menu_entry(page_utils.menu_entries.flow_details)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

printMessageBanners(alert_banners)

if not table.empty(alert_banners) then
   print("<br>")
end

print('<div style=\"display:none;\" id=\"flow_purged\" class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle fa-lg"></i>&nbsp;'..i18n("flow_details.now_purged")..'</div>')

throughput_type = getThroughputType()

local flow_key = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]

flow = interface.findFlowByKeyAndHashId(tonumber(flow_key), tonumber(flow_hash_id))

local ifid = interface.name2id(ifname)
local label = getFlowLabel(flow)
local title = i18n("flow")..": "..label
local url = ntop.getHttpPrefix().."/lua/flow_details.lua"

page_utils.print_navbar(title, url,
			{
			   {
			      active = true,
			      page_name = "overview",
			      label = i18n("overview"),
			   },
			}
)

if(flow == nil) then
   print('<div class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle fa-lg"></i> '..i18n("flow_details.flow_cannot_be_found_message")..' '.. purgedErrorString()..'</div>')
else
   if isAdministrator() then
      if(_POST["drop_flow_policy"] == "true") then
	 interface.dropFlowTraffic(tonumber(flow_key))
	 flow["verdict.pass"] = false
      end
   end

   ifstats = interface.getStats()
   print("<table class=\"table table-bordered table-striped\">\n")
   if ifstats.vlan and flow["vlan"] > 0 then
      print("<tr><th width=30%>")
      print(i18n("details.vlan_id"))
      print("</th><td colspan=2>" .. getFullVlanName(flow["vlan"]) .. "</td></tr>\n")
   end

   print("<tr><th width=30%>"..i18n("flow_details.flow_peers_client_server").."</th><td colspan=2>"..getFlowLabel(flow, true, not ifstats.isViewed --[[ don't add hyperlinks, viewed interface don't have hosts --]], nil, nil, true --[[ add flags ]]).."</td></tr>\n")

   print("<tr><th width=30%>"..i18n("protocol").." / "..i18n("application").."</th>")
   if((ifstats.inline and flow["verdict.pass"]) or (flow.vrfId ~= nil)) then
      print("<td>")
   else
      print("<td colspan=2>")
   end

   if(flow["verdict.pass"] == false) then print("<strike>") end
   print(flow["proto.l4"].." / ")

   if(flow["proto.ndpi_id"] == -1) then
      print(flow["proto.ndpi"])
   else
      print("<A HREF=\""..ntop.getHttpPrefix().."/lua/")
      if((flow.client_process ~= nil) or (flow.server_process ~= nil))then	print("s") end
      print("flows_stats.lua?application=" .. flow["proto.ndpi"] .. "\">")
      print(getApplicationLabel(flow["proto.ndpi"]).."</A> ")
      print("(<A HREF=\""..ntop.getHttpPrefix().."/lua/")
      print("flows_stats.lua?category=" .. flow["proto.ndpi_cat"] .. "\">")
      print(getCategoryLabel(flow["proto.ndpi_cat"]))
      print("</A>) ".. formatBreed(flow["proto.ndpi_breed"]))
   end
   
   if(flow["verdict.pass"] == false) then print("</strike>") end
   historicalProtoHostHref(ifid, flow["cli.ip"], nil, flow["proto.ndpi_id"], page_utils.safe_html(flow["protos.tls.certificate"] or ''))

   if((flow["protos.tls_version"] ~= nil)
      and (flow["protos.tls_version"] ~= 0)) then
      local tls_version_name = ntop.getTLSVersionName(flow["protos.tls_version"])

      if isEmptyString(tls_version_name) then
	 print(" [ TLS"..flow["protos.tls_version"].." ]")
      else
	 print(" [ "..tls_version_name.." ]")
      end
      if(tonumber(flow["protos.tls_version"]) < 771) then
	 print(' <i class="fas fa-exclamation-triangle" aria-hidden=true style="color: orange;"></i> ')
	 print(i18n("flow_details.tls_old_protocol_version"))
      end
   end

   if(ifstats.inline) then
      if(flow["verdict.pass"]) then
	 print('<form class="form-inline float-right" style="margin-bottom: 0px;" method="post">')
	 print('<input type="hidden" name="drop_flow_policy" value="true">')
	 print('<button type="submit" class="btn btn-secondary btn-xs"><i class="fas fa-ban"></i> '..i18n("flow_details.drop_flow_traffic_btn")..'</button>')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('</form>')
      end
   end
   print('</td>')

   if(flow.vrfId ~= nil) then
      print("<td><b> <A HREF=https://en.wikipedia.org/wiki/Virtual_routing_and_forwarding>VRF</A> Id</b> "..flow.vrfId.."</td>")
   end
   print("</tr>\n")

   if(ntop.isPro() and ifstats.inline and (flow["shaper.cli2srv_ingress"] ~= nil)) then
      local host_pools_nedge = require("host_pools_nedge")
      print("<tr><th width=30% rowspan=2>"..i18n("flow_details.flow_shapers").."</th>")
      c = flowinfo2hostname(flow,"cli")
      s = flowinfo2hostname(flow,"srv")

      if flow["cli.pool_id"] ~= nil then
        c = c .. " (<a href='".. host_pools_nedge.getUserUrl(flow["cli.pool_id"]) .."'>".. host_pools_nedge.poolIdToUsername(flow["cli.pool_id"]) .."</a>)"
      end

      if flow["srv.pool_id"] ~= nil then
        s = s .. " (<a href='".. host_pools_nedge.getUserUrl(flow["srv.pool_id"]) .."'>".. host_pools_nedge.poolIdToUsername(flow["srv.pool_id"]) .."</a>)"
      end

      local shaper = shaper_utils.nedge_shaper_id_to_shaper(flow["shaper.cli2srv_egress"])
      print("<td nowrap>"..c.."</td><td>".. shaper.icon .. " " .. shaper.text .."</td></tr>")

      local shaper = shaper_utils.nedge_shaper_id_to_shaper(flow["shaper.cli2srv_ingress"])
      print("<td nowrap>"..s.."</td><td>".. shaper.icon .. " " .. shaper.text.."</td></tr>")
      print("</tr>")

      if flow["cli.pool_id"] ~= nil and flow["srv.pool_id"] ~= nil then
         print("<tr><th width=30% rowspan=2>"..i18n("flow_details.flow_quota").."</th>")
         print("<td>"..c.."</td>")
         print("<td id='cli2srv_quota'>")
         printFlowQuota(ifstats.id, flow, true --[[ client ]])
         print("</td></tr>")
         print("<td nowrap>"..s.."</td>")
         print("<td id='srv2cli_quota'>")
         printFlowQuota(ifstats.id, flow, false --[[ server ]])
         print("</td>")
         print("</tr>")
      end

      -- ENABLE MARKER DEBUG
      if ntop.isnEdge() and false then
        print("<tr><th width=30%>"..i18n("flow_details.flow_marker").."</th>")
        print("<td colspan=2>".. nf_config.formatMarker(flow["marker"]) .."</td>")
        print("</tr>")
      end

      local alert_info = flow2alertinfo(flow)
      local forbidden_proto = flow["proto.ndpi_id"]
      local forbidden_peer = nil

      if alert_info then
	 forbidden_proto = alert_info["devproto_forbidden_id"] or forbidden_proto
	 forbidden_peer = alert_info["devproto_forbidden_peer"]
      end

      local cli_mac = flow["cli.mac"] and interface.getMacInfo(flow["cli.mac"])
      local srv_mac = flow["srv.mac"] and interface.getMacInfo(flow["srv.mac"])
      local cli_show = (cli_mac and cli_mac.location == "lan" and flow["cli.pool_id"] == 0)
      local srv_show = (srv_mac and srv_mac.location == "lan" and flow["srv.pool_id"] == 0)
      local num_rows = 0

      if cli_show then
	num_rows = num_rows + 1
      end
      if srv_show then
	num_rows = num_rows + 1
      end

      if num_rows > 0 then
	print("<tr><th width=30% rowspan=".. num_rows ..">"..i18n("device_protocols.device_protocol_policy").."</th>")

	if cli_show then
	  print("<td>"..i18n("device_protocols.devtype_as_proto_client", {devtype=discover.devtype2string(flow["cli.devtype"]), proto=interface.getnDPIProtoName(forbidden_proto)}).."</td>")
	  print("<td><a href=\"".. getDeviceProtocolPoliciesUrl("device_type=" .. flow["cli.devtype"]) .."&l7proto=".. forbidden_proto .."\">")
	  print(i18n(ternary(forbidden_peer ~= "cli", "allowed", "forbidden")))
	  print("</a></td></tr><tr>")
	end

	if srv_show then
	  print("<td>"..i18n("device_protocols.devtype_as_proto_server", {devtype=discover.devtype2string(flow["srv.devtype"]), proto=interface.getnDPIProtoName(forbidden_proto)}).."</td>")
	  print("<td><a href=\"".. getDeviceProtocolPoliciesUrl("device_type=" .. flow["srv.devtype"]) .."&l7proto=".. forbidden_proto .."\">")
	  print(i18n(ternary(forbidden_peer ~= "srv", "allowed", "forbidden")))
	  print("</a></td></tr><tr>")
	end
      end
   end

   print("<tr><th width=33%>"..i18n("details.first_last_seen").."</th><td nowrap width=33%><div id=first_seen>"
	    .. formatEpoch(flow["seen.first"]) ..  " [" .. secondsToTime(os.time()-flow["seen.first"]) .. " "..i18n("details.ago").."]" .. "</div></td>\n")
   print("<td nowrap><div id=last_seen>" .. formatEpoch(flow["seen.last"]) .. " [" .. secondsToTime(os.time()-flow["seen.last"]) .. " "..i18n("details.ago").."]" .. "</div></td></tr>\n")

   if flow["bytes"] > 0 then
      print("<tr><th width=30% rowspan=3>"..i18n("details.total_traffic").."</th><td>"..i18n("total")..": <span id=volume>" .. bytesToSize(flow["bytes"]) .. "</span> <span id=volume_trend></span></td>")
      if((ifstats.type ~= "zmq") and ((flow["proto.l4"] == "TCP") or (flow["proto.l4"] == "UDP")) and (flow["goodput_bytes"] > 0)) then
	 print("<td><A HREF=\"https://en.wikipedia.org/wiki/Goodput\">"..i18n("details.goodput").."</A>: <span id=goodput_volume>" .. bytesToSize(flow["goodput_bytes"]) .. "</span> (<span id=goodput_percentage>")
	 pctg = round(((flow["goodput_bytes"]*100)/flow["bytes"]), 2)
	 if(pctg < 50) then
	    pctg = "<font color=red>"..pctg.."</font>"
	 elseif(pctg < 60) then
	    pctg = "<font color=orange>"..pctg.."</font>"
	 end
	 print(pctg.."")

	 print("</span> %) <span id=goodput_volume_trend></span> </td></tr>\n")
      else
	 print("<td>&nbsp;</td></tr>\n")
      end

      print("<tr><td nowrap>" .. i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("server") .. ": <span id=cli2srv>" .. formatPackets(flow["cli2srv.packets"]) .. " / ".. bytesToSize(flow["cli2srv.bytes"]) .. "</span> <span id=sent_trend></span></td><td nowrap>" .. i18n("client") .. " <i class=\"fas fa-long-arrow-alt-left\"></i> " .. i18n("server") .. ": <span id=srv2cli>" .. formatPackets(flow["srv2cli.packets"]) .. " / ".. bytesToSize(flow["srv2cli.bytes"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

      print("<tr><td colspan=2>")
      cli2srv = round((flow["cli2srv.bytes"] * 100) / flow["bytes"], 0)

      local cli_name = shortHostName(flowinfo2hostname(flow, "cli"))
      local srv_name = shortHostName(flowinfo2hostname(flow, "srv"))

      if(flow["cli.port"] > 0) then
	 cli_name = cli_name .. ":" .. flow["cli.port"]
	 srv_name = srv_name .. ":" .. flow["srv.port"]
      end
      print('<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. cli2srv.. '%;">'.. cli_name..'</div><div class="progress-bar bg-success" style="width: ' .. (100-cli2srv) .. '%;">' .. srv_name .. '</div></div>')
      print("</td></tr>\n")
   end

   if(flow.iec104 and (table.len(flow.iec104.typeid) > 0)) then 
      print("<tr><th rowspan=5 width=30%><A HREF='https://en.wikipedia.org/wiki/IEC_60870-5'>IEC 60870-5-104</A> <i class='fas fa-external-link-alt'></i></th><th>"..i18n("flow_details.iec104_mask").."</th><td>")
      
      total = 0
      for k,v in pairsByKeys(flow.iec104.typeid, rev) do
	 total = total + v
      end

      print("<table border width=100%>")
      for k,v in pairsByValues(flow.iec104.typeid, rev) do
	 local pctg = (v*100)/total
	 local key = iec104_typeids2str(tonumber(k))

	 print(string.format("<th>%s</th><td align=right>%.3f %%</td></tr>\n", key, pctg))
      end
      
      print("</table>\n")
      print("</td></tr>\n")
      
      -- #########################

      total = 0
      for k,v in pairsByValues(flow.iec104.typeid_transitions, rev) do
	 total = total+v
      end
      
      print("<tr><th>".. i18n("flow_details.iec104_transitions"))
      drawiecgraph(flow.iec104.typeid_transitions, total)
      print("</th><td>")

      print("<table border width=100%>")
      for k,v in pairsByValues(flow.iec104.typeid_transitions, rev) do
	 local pctg = (v*100)/total
	 local keys = split(k, ",")
	 local key = iec104_typeids2str(tonumber(keys[1]))

	 if(keys[1] == keys[2]) then
	    key = key ..' <i class="fas fa-exchange-alt"></i> '
	 else
	    key = key ..' <i class="fas fa-long-arrow-alt-right"></i> '
	 end

	 key = key .. iec104_typeids2str(tonumber(keys[2]))
	 
	 print(string.format("<tr><th>%s</th><td align=right>%.3f %%</td></tr>\n", key, pctg))
      end
      
      print("</table>\n")
      print("</td></tr>\n")

      -- #########################
	 
      print("<tr><th>"..i18n("flow_details.iec104_latency").."</th><td>")
      if(flow.iec104.ack_time.stddev > flow.iec104.ack_time.average) then
	 on = "<font color=red>"
	 off = "</font>"
      else
	 on = ""
	 off = ""
      end
      if((flow.iec104.ack_time.average > 1000) or (flow.iec104.ack_time.stddev > 1000)) then
	 print(string.format("%.3f sec (%s%.3f sec%s)", flow.iec104.ack_time.average/1000, on, (flow.iec104.ack_time.stddev/1000), off))
      else
	 print(string.format("%.3f ms (%s%.3f msec%s)", flow.iec104.ack_time.average, on, flow.iec104.ack_time.stddev, off))
      end
      print("</td></tr>\n")

      print("<tr><th>"..i18n("flow_details.iec104_msg_breakdown").."</th><td>")
      local total = flow.iec104.stats.forward_msgs + flow.iec104.stats.reverse_msgs
      local pctg = string.format("%.1f", (flow.iec104.stats.forward_msgs * 100) / total)

      if(flow["srv.port"] == 2404) then
	 -- we need to swap directions
	 pctg = 100-pctg	 
      end
      
      print('<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. pctg .. '%;">'..pctg..'% </div>')
      pctg = 100-pctg
      print('<div class="progress-bar bg-success" style="width: ' .. pctg .. '%;">'..pctg..'% </div></div>')
      -- print(formatValue(flow.iec104.stats.forward_msgs).." RX / "..formatValue(flow.iec104.stats.reverse_msgs).." TX")
      print("</td></tr>\n")

      print("<tr><th>"..i18n("flow_details.iec104_msg_loss").."</th><td>")
      print("<i class=\"fas fa-long-arrow-alt-left\"></i> "..colorNotZero(flow.iec104.pkt_lost.rx)..", <i class=\"fas fa-long-arrow-alt-right\"></i> "..colorNotZero(flow.iec104.pkt_lost.tx).." / ")

      if(flow.iec104.stats.retransmitted_msgs == 0) then
	 print("0")
      else
	 print(colorNotZero(flow.iec104.stats.retransmitted_msgs))
      end
      print(" Retransmitted")
      print("</td></tr>\n")
   end

   print("<tr><th width=30%>"..i18n("flow_details.tos").."</th>")
   print("<td>"..(dscp_consts.dscp_descr(flow.tos.client.DSCP)) .." / ".. (dscp_consts.ecn_descr(flow.tos.client.ECN)) .."</td>")
   print("<td>"..(dscp_consts.dscp_descr(flow.tos.server.DSCP)) .." / ".. (dscp_consts.ecn_descr(flow.tos.server.ECN)) .."</td>")
   print("</tr>")

   if(flow["tcp.nw_latency.client"] ~= nil) then
      local rtt = flow["tcp.nw_latency.client"] + flow["tcp.nw_latency.server"]

      if(rtt > 0) then
	 local cli2srv = round(flow["tcp.nw_latency.client"], 3)
	 local srv2cli = round(flow["tcp.nw_latency.server"], 3)

	 print("<tr><th width=30%>"..i18n("flow_details.rtt_breakdown").."</th><td colspan=2>")
	 print('<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. (cli2srv * 100 / rtt) .. '%;">'.. cli2srv ..' ms (client)</div>')
	 print('<div class="progress-bar bg-success" style="width: ' .. (srv2cli * 100 / rtt) .. '%;">' .. srv2cli .. ' ms (server)</div></div>')
	 print("</td></tr>\n")

	 c = interface.getAddressInfo(flow["cli.ip"])
	 s = interface.getAddressInfo(flow["srv.ip"])

	 if(not(c.is_private and s.is_private)) then
-- Inspired by https://gist.github.com/geraldcombs/d38ed62650b1730fb4e90e2462f16125
	 print("<tr><th width=30%><A HREF=\"https://en.wikipedia.org/wiki/Velocity_factor\" target=\"_blank\">"..i18n("flow_details.rtt_distance").."</A> <i class=\"fas fa-external-link-alt\"></i></th><td>")
	 local c_vacuum_km_s = 299792
	 local c_vacuum_mi_s = 186000
	 local fiber_vf      = .67
	 local delta_t       = rtt/1000
	 local dd_fiber_km   = delta_t * c_vacuum_km_s * fiber_vf
	 local dd_fiber_mi   = delta_t * c_vacuum_mi_s * fiber_vf

	 print(formatValue(toint(dd_fiber_km)).." Km</td><td>"..formatValue(toint(dd_fiber_mi)).." Miles")
	 print("</td></tr>\n")
	 end
      end
   end

   if(flow["tcp.appl_latency"] ~= nil and flow["tcp.appl_latency"] > 0) then
      print("<tr><th width=30%>"..i18n("flow_details.application_latency").."</th><td colspan=2>"..msToTime(flow["tcp.appl_latency"]).."</td></tr>\n")
   end

   if not ntop.isnEdge() then
      if flow["cli2srv.packets"] > 1 and flow["interarrival.cli2srv"] and flow["interarrival.cli2srv"]["max"] > 0 then
	 print("<tr><th width=30%")
	 if(flow["flow.idle"] == true) then print(" rowspan=2") end
	 print(">"..i18n("flow_details.packet_inter_arrival_time").."</th><td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ")
	 print(msToTime(flow["interarrival.cli2srv"]["min"]).." / "..msToTime(flow["interarrival.cli2srv"]["avg"]).." / "..msToTime(flow["interarrival.cli2srv"]["max"]))
	 print("</td>\n")
	 if(flow["srv2cli.packets"] < 2) then
	    print("<td>&nbsp;")
	 else
	    print("<td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ")
	    print(msToTime(flow["interarrival.srv2cli"]["min"]).." / "..msToTime(flow["interarrival.srv2cli"]["avg"]).." / "..msToTime(flow["interarrival.srv2cli"]["max"]))
	 end
	 print("</td></tr>\n")
	 if(flow["flow.idle"] == true) then print("<tr><td colspan=2><i class='fas fa-clock-o'></i> <small>"..i18n("flow_details.looks_like_idle_flow_message").."</small></td></tr>") end
      end

      if((flow["cli2srv.fragments"] + flow["srv2cli.fragments"]) > 0) then
	 rowspan = 2
	 print("<tr><th width=30% rowspan="..rowspan..">"..i18n("flow_details.ip_packet_analysis").."</th>")
	 print("<th>&nbsp;</th><th>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server").." / "..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server").."</th></tr>\n")
	 print("<tr><th>"..i18n("details.fragments").."</th><td align=right><span id=c2sFrag>".. formatPackets(flow["cli2srv.fragments"]) .."</span> / <span id=s2cFrag>".. formatPackets(flow["srv2cli.fragments"]) .."</span></td></tr>\n")
      end

      if flow["tcp.seq_problems"] then
	 rowspan = 1
	 if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]) > 0) then rowspan = rowspan + 1 end
	 if((flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]) > 0)       then rowspan = rowspan + 1 end
	 if((flow["cli2srv.lost"] + flow["srv2cli.lost"]) > 0)                       then rowspan = rowspan + 1 end
	 if((flow["cli2srv.keep_alive"] + flow["srv2cli.keep_alive"]) > 0)           then rowspan = rowspan + 1 end

	 if rowspan > 1 then
	    print("<tr><th width=30% rowspan="..rowspan..">"..i18n("flow_details.tcp_packet_analysis").."</th>")
	    print("<th></th><th>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server").." / "..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server").."</th></tr>\n")

	    if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]) > 0) then
	       print("<tr><th>"..i18n("details.retransmissions").."</th><td align=right><span id=c2sretr>".. formatPackets(flow["cli2srv.retransmissions"]) .."</span> / <span id=s2cretr>".. formatPackets(flow["srv2cli.retransmissions"]) .."</span></td></tr>\n")
	    end
	    if((flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]) > 0) then
	       print("<tr><th>"..i18n("details.out_of_order").."</th><td align=right><span id=c2sOOO>".. formatPackets(flow["cli2srv.out_of_order"]) .."</span> / <span id=s2cOOO>".. formatPackets(flow["srv2cli.out_of_order"]) .."</span></td></tr>\n")
	    end
	    if((flow["cli2srv.lost"] + flow["srv2cli.lost"]) > 0) then
	       print("<tr><th>"..i18n("details.lost").."</th><td align=right><span id=c2slost>".. formatPackets(flow["cli2srv.lost"]) .."</span> / <span id=s2clost>".. formatPackets(flow["srv2cli.lost"]) .."</span></td></tr>\n")
	    end
	    if((flow["cli2srv.keep_alive"] + flow["srv2cli.keep_alive"]) > 0) then
	       print("<tr><th>"..i18n("details.keep_alive").."</th><td align=right><span id=c2skeep_alive>".. formatPackets(flow["cli2srv.keep_alive"]) .."</span> / <span id=s2ckeep_alive>".. formatPackets(flow["srv2cli.keep_alive"]) .."</span></td></tr>\n")
	    end
	 end
      end
   end

   if(flow["protos.tls.client_requested_server_name"] ~= nil) then
      print("<tr><th width=30%><i class='fas fa-lock'></i> "..i18n("flow_details.tls_certificate").."</th><td>")
      print(i18n("flow_details.client_requested")..":<br>")
      print("<A HREF=\"http://"..page_utils.safe_html(flow["protos.tls.client_requested_server_name"]).."\">"..page_utils.safe_html(flow["protos.tls.client_requested_server_name"]).."</A> <i class=\"fas fa-external-link-alt\"></i>")
      if(flow["category"] ~= nil) then print(" "..getCategoryIcon(flow["protos.tls.client_requested_server_name"], flow["category"])) end
      historicalProtoHostHref(ifid, nil, nil, nil, page_utils.safe_html(flow["protos.tls.client_requested_server_name"] or ''))
      printAddCustomHostRule(flow["protos.tls.client_requested_server_name"])
      print("</td>")

      print("<td>")
      if(flow["protos.tls.server_names"] ~= nil) then
	 local servers = string.split(flow["protos.tls.server_names"], ",") or {flow["protos.tls.server_names"]}

	 print(i18n("flow_details.tls_server_names")..":<br>")
	 for i, server in ipairs(servers) do
	    if i > 1 then
	       print("<br>")
	    end

	    if starts(server, '*') then
	       print(server)
	    else
	       print("<A HREF=\"http://"..server.."\">"..server.."</A> <i class=\"fas fa-external-link-alt\"></i>")
	    end
	 end
      end
      print("</td>")
      print("</tr>\n")
   end

   if((flow["protos.tls.notBefore"] ~= nil) or (flow["protos.tls.notAfter"] ~= nil)) then
      local now = os.time()
      print('<tr><th width=30%>'..i18n("flow_details.tls_certificate_validity").."</th><td colspan=2>")

      if((flow["protos.tls.notBefore"] > now) or (flow["protos.tls.notAfter"] < now)) then
	 print(" <i class=\"fas fa-exclamation-triangle fa-lg\" style=\"color: #f0ad4e;\"></i>")
      end

      print(formatEpoch(flow["protos.tls.notBefore"]))
      print(" - ")
      print(formatEpoch(flow["protos.tls.notAfter"]))
      print("</td></tr>\n")
   end

   if(flow["protos.tls.issuerDN"] ~= nil) then
      print('<tr><th width=30%>TLS issuerDN</A></th><td colspan=2>'..flow["protos.tls.issuerDN"]..'</td></tr>\n')
   end

   if(flow["protos.tls.subjectDN"] ~= nil) then
      print('<tr><th width=30%>TLS subjectDN</A></th><td colspan=2>'..flow["protos.tls.subjectDN"]..'</td></tr>\n')
   end

   if((flow["protos.tls.ja3.client_hash"] ~= nil) or (flow["protos.tls.ja3.server_hash"] ~= nil)) then
      print('<tr><th width=30%><A HREF="https://github.com/salesforce/ja3">JA3C / JA3S</A></th><td>')
      if(flow["protos.tls.ja3.client_malicious"]) then
	 print('<font color=red><i class="fas fa-ban" title="'.. i18n("alerts_dashboard.malicious_signature_detected") ..'"></i></font> ')
      end

      ja3url(flow["protos.tls.ja3.client_hash"], nil)
      print("</td><td>")
      if(flow["protos.tls.ja3.server_malicious"]) then
        print('<font color=red><i class="fas fa-ban" title="'.. i18n("alerts_dashboard.malicious_signature_detected") ..'"></i></font> ')
      end

      ja3url(flow["protos.tls.ja3.server_hash"], flow["protos.tls.ja3.server_unsafe_cipher"])
      --print(cipher2str(flow["protos.tls.ja3.server_cipher"]))
      print("</td></tr>")
   end

   if(flow["protos.tls.client_alpn"] ~= nil) then
      print('<tr><th width=30%><a href="https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation" data-bs-toggle="tooltip" title="ALPN">TLS ALPN</A></th><td colspan=2>'..page_utils.safe_html(flow["protos.tls.client_alpn"])..'</td></tr>\n')
   end

   if(flow["protos.tls.client_tls_supported_versions"] ~= nil) then
      print('<tr><th width=30%><a href="https://tools.ietf.org/html/rfc7301" data-bs-toggle="tooltip">'.. i18n("flow_details.client_tls_supported_versions") ..'</A></th><td colspan=2>'..page_utils.safe_html(flow["protos.tls.client_tls_supported_versions"])..'</td></tr>\n')
   end

   if((flow["tcp.max_thpt.cli2srv"] ~= nil) and (flow["tcp.max_thpt.cli2srv"] > 0)) then
     print("<tr><th width=30%>"..
     '<a href="https://en.wikipedia.org/wiki/TCP_tuning" data-bs-toggle="tooltip" target=\"_blank\" title="'..i18n("flow_details.computed_as_tcp_window_size_rtt")..'">'..
     i18n("flow_details.max_estimated_tcp_throughput").."</a> <i class=\"fas fa-external-link-alt\"></i><td nowrap> "..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ")
     print(bitsToSize(flow["tcp.max_thpt.cli2srv"]))
     print("</td><td> "..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ")
     print(bitsToSize(flow["tcp.max_thpt.srv2cli"]))
     print("</td></tr>\n")
   end

   if((flow["cli2srv.trend"] ~= nil) and false) then
     print("<tr><th width=30%>"..i18n("flow_details.throughput_trend").."</th><td nowrap>"..flow["cli.ip"].." <i class=\"fas fa-long-arrow-alt-right\"></i> "..flow["srv.ip"]..": ")
     print(flow["cli2srv.trend"])
     print("</td><td>"..flow["cli.ip"].." <i class=\"fas fa-long-arrow-alt-left\"></i> "..flow["srv.ip"]..": ")
     print(flow["srv2cli.trend"])
     print("</td></tr>\n")
    end

   local flags = flow["cli2srv.tcp_flags"] or flow["srv2cli.tcp_flags"]

   if((flags ~= nil) and (flags > 0)) then
      print("<tr><th width=30% rowspan=2>"..i18n("tcp_flags").."</th><td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ")
      printTCPFlags(flow["cli2srv.tcp_flags"])
      print("</td><td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ")
      printTCPFlags(flow["srv2cli.tcp_flags"])
      print("</td></tr>\n")

      print("<tr><td colspan=2>")

      local flow_msg = ""
      if flow["tcp_reset"] then
	 local resetter = ""

	 if(hasbit(flow["cli2srv.tcp_flags"],0x04)) then
	    resetter = "client"
	 else
	    resetter = "server"
	 end

	 flow_msg = flow_msg..i18n("flow_details.flow_reset_by_resetter_msg",{resetter = resetter})
      elseif flow["tcp_closed"] then
	 flow_msg = flow_msg..i18n("flow_details.flow_completed_msg")
      elseif flow["tcp_connecting"] then
	 flow_msg = flow_msg..i18n("flow_details.flow_connecting_msg")
      elseif flow["tcp_established"] then
	 flow_msg = flow_msg..i18n("flow_details.flow_active_msg")
      else
	 flow_msg = flow_msg.." "..i18n("flow_details.flow_peer_roles_inaccurate_msg")
      end

      print(flow_msg)
      print("</td></tr>\n")
   end

   -- ######################################

   local icmp = flow["icmp"]

   if(icmp ~= nil) then
      local icmp_utils = require "icmp_utils"
      local icmp_label = icmp_utils.get_icmp_label(ternary(isIPv4(flow["cli.ip"]), 4, 6), flow["icmp"]["type"], flow["icmp"]["code"])
      icmp_label = icmp_label..string.format(" [%s: %u %s: %u]", i18n("icmp_page.icmp_type"), flow["icmp"]["type"], i18n("icmp_page.icmp_code"), flow["icmp"]["code"])

      print("<tr><th width=30%>"..i18n("flow_details.icmp_info").."</th><td colspan=2>"..icmp_label)

      if icmp["unreach"] then
	 local unreachable_flow = interface.findFlowByTuple(flow["cli.ip"], flow["srv.ip"], flow["vlan"], icmp["unreach"]["dst_port"], icmp["unreach"]["src_port"], icmp["unreach"]["protocol"])

	 print(" ["..i18n("flow")..": ")
	 if unreachable_flow then
	    print(" <a class='btn btn-sm btn-info' HREF='"..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="..unreachable_flow["ntopng.key"].."&flow_hash_id="..unreachable_flow["hash_entry_id"].."'>Info</a>")
	    print(" "..getFlowLabel(unreachable_flow, true, true))
	 else
	    -- The flow hasn't been found so very likely it is no longer active or it hasn't been seen.
	    -- Still print the flow using data found in the original datagram found in the icmp packet
	    print(getFlowLabel({
			["cli.ip"] = icmp["unreach"]["src_ip"], ["srv.ip"] = icmp["unreach"]["dst_ip"],
			["cli.port"] = icmp["unreach"]["src_port"], ["srv.port"] = icmp["unreach"]["dst_port"]},
		     false, true))
	 end
	 print("]")
      end

      print("</td></tr>")
   end

   -- ######################################

   if(isScoreEnabled() and (flow.score.flow_score > 0)) then
      print("\n<tr><th width=30%>"..i18n("flow_details.flow_score").. " / "..i18n("flow_details.flow_score_breakdown").."</th><td>"..format_utils.formatValue(flow.score.flow_score).."</td>\n")

      local score_category_network  = flow.score.host_categories_total["0"]
      local score_category_security = flow.score.host_categories_total["1"]
      local tot                     = score_category_network + score_category_security

      score_category_network  = (score_category_network*100)/tot
      score_category_security = 100 - score_category_network

      print('<td><div class="progress"><div class="progress-bar bg-warning" style="width: '..score_category_network..'%;">'.. i18n("flow_details.score_category_network"))
      print('</div><div class="progress-bar bg-success" style="width: ' .. score_category_security .. '%;">' .. i18n("flow_details.score_category_security") .. '</div></div></td>\n')
      print("</tr>\n")
   end

   -- ######################################

   local alerts_by_score = {} -- Table used to keep messages ordered by score
   local num_statuses = 0
   local first = true

   for id, _ in pairs(flow["alerts_map"] or {}) do
      local is_predominant = id == flow["predominant_alert"]
      local alert_label = alert_consts.alertTypeLabel(id, true, alert_entities.flow.entity_id)
      local message = alert_label
      local alert_score = ntop.getFlowAlertScore(id)

      if alert_score > 0 then
	 message = message .. string.format(" [%s: %s]",
					    i18n("score"),
					    format_utils.formatValue(alert_score))
      end

      if not alerts_by_score[alert_score] then
	 alerts_by_score[alert_score] = {}
      end
      alerts_by_score[alert_score][#alerts_by_score[alert_score] + 1] = {message = message, is_predominant = is_predominant, alert_id = id, alert_label = alert_label}
      num_statuses = num_statuses + 1
   end

   -- ######################################

   -- Unhandled flow risk as 'fake' alerts with a 'fake' score of zero
   if flow["unhandled_flow_risk"] and table.len(flow["unhandled_flow_risk"]) > 0 then
      local unhandled_risk_score = 0
      local risk = flow["unhandled_flow_risk"]

      for risk_str,risk_id in pairs(risk) do
	 if not alerts_by_score[unhandled_risk_score] then
	    alerts_by_score[unhandled_risk_score] = {}
	 end

	 local message =  string.format("%s [%s: %s]",
					risk_str,
					i18n("score"),
					i18n("score_not_accounted"))

	 alerts_by_score[unhandled_risk_score][#alerts_by_score[unhandled_risk_score] + 1] = {message = message, is_predominant = false}
	 num_statuses = num_statuses + 1
      end
   end

   -- ######################################


   -- Print flow alerts (ordered by score and then alphabetically)
   if num_statuses > 0 then
      -- Prepare a mapping between alert id and check
      local alert_id_to_flow_check = {}
      local checks = require "checks"
      local flow_checks = checks.load(ifId, checks.script_types.flow, "flow")
      for flow_check_name, flow_check in pairs(flow_checks.modules) do
	 if flow_check.alert_id then
	    alert_id_to_flow_check[flow_check.alert_id] = flow_check_name
	 end
      end

      for _, score_alerts in pairsByKeys(alerts_by_score, rev) do
	 for _, score_alert in pairsByField(score_alerts, "message", asc) do
	    if first then
	       print("<tr><th width=30% rowspan="..(num_statuses+1)..">"..i18n("flow_details.flow_issues").."</th><th>"..i18n("description").."</th><th>"..i18n("actions").."</th></tr>")
	       first = false
	    end

	    print(string.format('<tr>'))

	    print(string.format('<td>%s %s</td>', score_alert.message, score_alert.is_predominant and status_icon or ''))

	    if score_alert.alert_id then
	       print('<td>')

	       -- Add rules to disable the check
	       print(string.format('<a href="#alerts_filter_dialog" alert_id=%u alert_label="%s" class="btn btn-sm btn-warning" role="button"><i class="fas fa-bell-slash"></i></a>', score_alert.alert_id, score_alert.alert_label))

	       -- If available, add a cog to configure the check
	       if alert_id_to_flow_check[score_alert.alert_id] then
		  print(string.format('&nbsp;<a href="%s" class="btn btn-sm btn-info" role="button"><i class="fas fa-cog"></i></a>', alert_utils.getConfigsetURL(alert_id_to_flow_check[score_alert.alert_id], "flow")))
	       end

	       -- For the predominant alert, add an anchor to the historical alert
	       if not ifstats.isViewed and score_alert.is_predominant then
		  -- Prepare bounds for the historical alert search.
		  local epoch_begin = flow["seen.first"]
		  -- As this is the page of active flows, it is meaningful to use the current time for the epoch end.
		  -- This will also enable multiple flows with the same tuple to be shown.
		  local epoch_end = os.time()
		  local l7_proto = flow["proto.ndpi_id"] .. tag_utils.SEPARATOR .. "eq"
		  local cli_ip = flow["cli.ip"]  .. tag_utils.SEPARATOR .. "eq"
		  local srv_ip = flow["srv.ip"]  .. tag_utils.SEPARATOR .. "eq"
		  local cli_port = flow["cli.port"]  .. tag_utils.SEPARATOR .. "eq"
		  local srv_port = flow["srv.port"]  .. tag_utils.SEPARATOR .. "eq"

		  print(string.format('&nbsp;<a href="%s/lua/alert_stats.lua?status=historical&page=flow&epoch_begin=%u&epoch_end=%u&l7_proto=%s&cli_ip=%s&cli_port=%s&srv_ip=%s&srv_port=%s" class="btn btn-sm btn-info" role="button"><i class="fas fa-exclamation-triangle"></i></a>',
				      ntop.getHttpPrefix(),
				      epoch_begin,
				      epoch_end,
				      l7_proto,
				      cli_ip, cli_port,
				      srv_ip, srv_port))
	       end

	       print('</td>')
	    else -- These are unhandled alerts, e.g., flow risks for which a check doesn't exist
	       print(string.format('<td></td>'))
	    end

	    print('</tr>')
	 end
      end
   end

   -- ######################################

   if(flow.entropy and flow.entropy.client and flow.entropy.server) then
      print("<tr><th width=30%><A HREF=\"https://en.wikipedia.org/wiki/Entropy_(information_theory)\" target=\"_blank\">"..i18n("flow_details.entropy").."</A> <i class=\"fas fa-external-link-alt\"></i></th>")
      print("<td>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ".. string.format("%.3f", flow.entropy.client) .. "</td>")
      print("<td>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ".. string.format("%.3f", flow.entropy.server) .. "</td>")
      print("</tr>\n")
   end

   if((flow.community_id ~= nil) and (flow.community_id ~= "")) then
      print("<tr><th width=30%><A HREF=\"https://github.com/corelight/community-id-spec\" target=\"_blank\">CommunityId</A> <i class=\"fas fa-external-link-alt\"></i></th><td colspan=2>".. flow.community_id .."</td></tr>\n")
   end

   if((flow.client_process == nil) and (flow.server_process == nil)) then
      print("<tr><th width=30%>"..i18n("flow_details.actual_peak_throughput").."</th><td width=20%>")
      if (throughput_type == "bps") then
	 print("<span id=throughput>" .. bitsToSize(8*flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      elseif (throughput_type == "pps") then
	 print("<span id=throughput>" .. pktsToSize(flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      end

      if (throughput_type == "bps") then
	 print(" / <span id=top_throughput>" .. bitsToSize(8*flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      elseif (throughput_type == "pps") then
	 print(" / <span id=top_throughput>" .. pktsToSize(flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      end

      print("</td><td><span id=thpt_load_chart>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>")
      print("</td></tr>\n")
   end

   if((flow.client_process ~= nil) or (flow.server_process ~= nil)) then
      local epbf_utils = require "ebpf_utils"
      print('<tr><th colspan=3><div id="sprobe"></div>')

      local width  = 1024
      local height = 200
      local url = ntop.getHttpPrefix().."/lua/get_flow_process_tree.lua?flow_key="..flow_key.."&flow_hash_id="..flow_hash_id
      epbf_utils.draw_flow_processes_graph(width, height, url)

      print('</th></tr>\n')

      if(flow.client_process ~= nil) then
	 displayProc(flow.client_process,
		     "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.client_process_information").."</th></tr>\n")
      end
      if(flow.client_container ~= nil) then
	 displayContainer(flow.client_container,
			  "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.client_container_information").."</th></tr>\n")
      end
      if(flow.server_process ~= nil) then
	 displayProc(flow.server_process,
                     "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.server_process_information").."</th></tr>\n")
      end
      if(flow.server_container ~= nil) then
	 displayContainer(flow.server_container,
			  "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.server_container_information").."</th></tr>\n")
      end
   end

   if(flow["protos.dns.last_query"] ~= nil) then
      print("<tr><th width=30%>"..i18n("flow_details.dns_query").."</th><td colspan=2>")
      if(string.ends(flow["protos.dns.last_query"], "arpa")) then
	 print(shortHostName(flow["protos.dns.last_query"]))
      else
	 print("<A HREF=\"http://"..page_utils.safe_html(flow["protos.dns.last_query"]).."\">"..page_utils.safe_html(shortHostName(flow["protos.dns.last_query"])).."</A> <i class='fas fa-external-link-alt'></i>")
      end

      if(flow["category"] ~= nil) then
	 print(" "..getCategoryIcon(flow["protos.dns.last_query"], flow["category"]))
      end

      printAddCustomHostRule(flow["protos.dns.last_query"])

      print("</td></tr>\n")
   end

   if not isEmptyString(flow["protos.ssh.hassh.client_hash"]) or not isEmptyString(flow["protos.ssh.hassh.server_hash"]) then
      print("<tr><th><A HREF='https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c'>HASSH</A></th><td>")
      print("<b>"..i18n("client")..":</b> "..hostinfo2detailshref(flow2hostinfo(flow, "cli"), {page = "ssh"}, flow["protos.ssh.hassh.client_hash"]).."</td>")
      print("<td><b>"..i18n("server")..":</b> "..hostinfo2detailshref(flow2hostinfo(flow, "srv"), {page = "ssh"}, flow["protos.ssh.hassh.server_hash"]).."</a></td>")
      print("</td>")
   end

   if(not isEmptyString(flow["protos.ssh.client_signature"])) then
      print("<tr><th>"..i18n("flow_details.ssh_signature").."</th><td><b>"..i18n("client")..":</b> "..(flow["protos.ssh.client_signature"] or '').."</td><td><b>"..i18n("server")..":</b> "..(flow["protos.ssh.server_signature"] or '').."</td></tr>\n")
   end

   if(not isEmptyString(flow["bittorrent_hash"])) then
      print("<tr><th>"..i18n("flow_details.bittorrent_hash").."</th><td colspan=4><A HREF=\"https://www.google.it/search?q="..flow["bittorrent_hash"].."\">".. flow["bittorrent_hash"].."</A></td></tr>\n")
   end

   if(flow["protos.http.last_url"] ~= nil) then
      local rowspan = 2
      if(not isEmptyString(flow["protos.http.last_method"])) then rowspan = rowspan + 1 end
      if not have_nedge and flow["protos.http.last_return_code"] and flow["protos.http.last_return_code"] ~= 0 then rowspan = rowspan + 1 end

      print("<tr><th width=30% rowspan="..rowspan..">"..i18n("http").."</th>")
      if(not isEmptyString(flow["protos.http.last_method"])) then
        print("<th>"..i18n("flow_details.http_method").."</th><td>"..(flow["protos.http.last_method"] or '').."</td>")
        print("</tr>")
        print("<tr>")
      end

      print("<th>"..i18n("flow_details.server_name").."</th><td colspan=2>")
      local s = flowinfo2hostname(flow,"srv")
      if(not isEmptyString(flow["host_server_name"])) then
	 s = flow["host_server_name"]
      end
      print("<A HREF=\"http://"..page_utils.safe_html(s).."\" target=\"_blank\">"..page_utils.safe_html(s).."</A> <i class=\"fas fa-external-link-alt\"></i>")
      if(flow["category"] ~= nil) then print(" "..getCategoryIcon(flow["host_server_name"], flow["category"])) end
      printAddCustomHostRule(s)
      print("</td></tr>\n")

      print("<tr><th>"..i18n("flow_details.url").."</th><td colspan=2>")
      print("<A HREF=\"http://")
      -- if(flow["srv.port"] ~= 80) then print(":"..flow["srv.port"]) end

      local last_url = page_utils.safe_html(flow["protos.http.last_url"])
      local last_url_short = shortenString(last_url, 64)
      print(last_url.."\" target=\"_blank\">"..last_url_short.."</A> <i class=\"fas fa-external-link-alt\">")
      print("</td></tr>\n")

      if not have_nedge and flow["protos.http.last_return_code"] and flow["protos.http.last_return_code"] ~= 0 then
        print("<tr><th>"..i18n("flow_details.response_code").."</th><td colspan=2>"..(flow["protos.http.last_return_code"] or '').."</td></tr>\n")
      end
   else
      if((flow["host_server_name"] ~= nil) and (flow["protos.dns.last_query"] == nil)) then
	 print("<tr><th width=30%>"..i18n("flow_details.server_name").."</th><td colspan=2><A HREF=\"http://"..page_utils.safe_html(flow["host_server_name"]).."\">"..page_utils.safe_html(flow["host_server_name"]).."</A> <i class=\"fas fa-external-link-alt\"></i>")
	 if not isEmptyString(flow["protos.http.server_name"]) then
	    printAddCustomHostRule(flow["protos.http.server_name"])
	 end
	 print("</td></tr>\n")
      end
   end

   if(flow["profile"] ~= nil) then
      print("<tr><th width=30%><A HREF=\"".. ntop.getHttpPrefix() .."/lua/pro/admin/edit_profiles.lua\">"..i18n("flow_details.profile_name").."</A></th><td colspan=2><span class='badge bg-primary'>"..flow["profile"].."</span></td></tr>\n")
   end

   if(flow.src_as and flow.src_as ~= 0) or (flow.dst_as and flow.dst_as ~= 0) then
      local asn
      
      print("<tr>")
      print("<th width=30%>"..i18n("flow_details.as_src_dst").."</th>")

      formatASN(flow.src_as)
      formatASN(flow.dst_as)

      print("</tr>\n")
   end

   if(flow.prev_adjacent_as or flow.next_adjacent_as) then
      print("<tr>")
      print("<th width=30%>"..i18n("flow_details.as_prev_next").."</th>")
      
      formatASN(flow.prev_adjacent_as)
      formatASN(flow.next_adjacent_as)

      print("</tr>\n")
   end

   if (flow["moreinfo.json"] ~= nil) then
      local flow_field_value_maps = require "flow_field_value_maps"
      local info, pos, err = json.decode(flow["moreinfo.json"], 1, nil)
      local isThereSIP = 0
      local isThereRTP = 0

      -- Convert the array to symbolic identifiers if necessary
      local syminfo = {}
      for key, value in pairs(info) do
	 key, value = flow_field_value_maps.map_field_value(ifid, key, value)

	 local k = rtemplate[tonumber(key)]
	 if(k ~= nil) then
	    syminfo[k] = value
	 else
	    syminfo[key] = value
	 end
      end
      info = syminfo

      -- get SIP rows
      if(ntop.isPro() and (flow["proto.ndpi"] == "SIP")) then
        local sip_table_rows = getSIPTableRows(info)
        print(sip_table_rows)

        isThereSIP = isThereProtocol("SIP", info)
        if(isThereSIP == 1) then
	   isThereSIP = isThereSIPCall(info)
        end
      end
      info = removeProtocolFields("SIP",info)

      -- get RTP rows
      if(ntop.isPro() and (flow["proto.ndpi"] == "RTP")) then
        local rtp_table_rows = getRTPTableRows(info)
        print(rtp_table_rows)

	-- io.write(flow["proto.ndpi"].."\n")
	isThereRTP = isThereProtocol("RTP", info)
      end
      info = removeProtocolFields("RTP",info)

      local snmpdevice = nil

      if(ntop.isPro() and not isEmptyString(syminfo["EXPORTER_IPV4_ADDRESS"])) then
	 snmpdevice = syminfo["EXPORTER_IPV4_ADDRESS"]
      elseif(ntop.isPro() and not isEmptyString(syminfo["NPROBE_IPV4_ADDRESS"])) then
	 snmpdevice = syminfo["NPROBE_IPV4_ADDRESS"]
      end

      if((flow["observation_point_id"] ~= nil) and (flow["observation_point_id"] ~= 0)) then
	 print("<tr><th>"..i18n("details.observation_point_id").."</th>")
	 print("<td colspan=\"2\">"..flow["observation_point_id"].."</td></tr>")
      end
      
      if(flow["in_index"] or flow["out_index"]) then
	 if((flow["in_index"] == flow["out_index"]) and (flow["in_index"] == 0)) then
	    -- nothing to do (they are likely to be not initialized)
	 else
	    printFlowSNMPInfo(snmpdevice, flow["in_index"], flow["out_index"])
	 end
      end
      
      local num = 0
      for key,value in pairsByKeys(info) do
	 if(num == 0) then
	    print("<tr><th colspan=3 class=\"info\">"..i18n("flow_details.additional_flow_elements").."</th></tr>\n")
	 end

	 if(value ~= "") then
	    print("<tr><th width=30%>" .. getFlowKey(key) .. "</th><td colspan=2>" .. handleCustomFlowField(key, value, snmpdevice) .. "</td></tr>\n")
	 end

	 num = num + 1
      end
   end
   print("</table>\n")
end

local disable_modal = "pages/modals/modal_alerts_filter_dialog.html"
local alerts_filter_dialog = template.gen(
   disable_modal, {
      dialog = {
	 id = "alerts_filter_dialog",
	 title = i18n("show_alerts.filter_alert"),
	 message	= i18n("show_alerts.confirm_filter_alert"),
	 delete_message = i18n("show_alerts.confirm_delete_filtered_alerts"),
	 delete_alerts = i18n("delete_disabled_alerts"),
	 alert_filter = "default_filter",
	 confirm = i18n("filter"),
	 confirm_button = "btn-warning",
	 custom_alert_class = "alert alert-danger",
	 entity = page
      }
})

print [[
<div class="modals">
]] print(alerts_filter_dialog) print[[
</div>
<script>
/*
      $(document).ready(function() {
	      $('.progress .bar').progressbar({ use_percentage: true, display_text: 1 });
   });
*/
        $(`a[href='#alerts_filter_dialog']`).click( function (e) {
            const alert_id = e.target.closest('a').attributes.alert_id.value;
            const alert_label = e.target.closest('a').attributes.alert_label.value;
            const alert = {alert_id: alert_id, alert_label: alert_label};
            $disableAlert.invokeModalInit(alert);
            $('#alerts_filter_dialog').modal('show');
        });

        const $disableAlert = $('#alerts_filter_dialog form').modalHandler({
            method: 'post',
            csrf: "]] print(ntop.getRandomCSRFValue()) print[[",
            endpoint: `${http_prefix}/lua/rest/v2/edit/check/filter.lua`,
            beforeSumbit: function (alert) {
                const data = {
                    alert_key: alert.alert_id,
                    subdir: "flow",
		    script_key: "",
                    delete_alerts: $(`#delete_alerts_switch`).is(":checked"),
		    alert_addr: $(`[name='alert_addr']:checked`).val(),
                };

                return data;
            },
            onModalInit: function (alert) {
                const $type = $(`<span>${alert.alert_label}</span>`);
                $(`#alerts_filter_dialog .alert_label`).text($type.text().trim());

                const cliLabel = "]]  if(flow ~= nil) then local n = flowinfo2hostname(flow,"cli"); if n ~= flow["cli.ip"] then print(string.format("%s (%s)", n, flow["cli.ip"])) else print(n) end end print[[";
                const srvLabel =  "]] if(flow ~= nil) then local n = flowinfo2hostname(flow,"srv"); if n ~= flow["srv.ip"] then print(string.format("%s (%s)", n, flow["srv.ip"])) else print(n) end end print[[";

                $(`#cli_addr`).text(cliLabel);
                $(`#cli_radio`).val("]] if(flow ~= nil) then print(flow["cli.ip"]) end print[[");
                $(`#srv_addr`).text(srvLabel);
                $(`#srv_radio`).val("]] if(flow ~= nil) then print(flow["srv.ip"]) end print[[");
                $(`#srv_radio`).prop("checked", true),
		$(`#all_radio`).parent().hide();
            },
            onSubmitSuccess: function (response, dataSent) {
              $('a[alert_id=' +  dataSent.alert_key+']').hide();
              return (response.rc == 0);
            }
        });

var thptChart = $("#thpt_load_chart").peity("line", { width: 64 });
]]

if(flow ~= nil) then
   if (flow["cli2srv.packets"] ~= nil ) then
      print("var cli2srv_packets = " .. flow["cli2srv.packets"] .. ";")
   end
   if (flow["srv2cli.packets"] ~= nil) then
      print("var srv2cli_packets = " .. flow["srv2cli.packets"] .. ";")
   end
   if (flow["throughput_"..throughput_type] ~= nil) then
      print("var throughput = " .. flow["throughput_"..throughput_type] .. ";")
   end
   print("var bytes = " .. flow["bytes"] .. ";")
   print("var goodput_bytes = " .. flow["goodput_bytes"] .. ";")
end

print [[
function update () {
	  $.ajax({
		    type: 'GET',
		    url: ']]
print (ntop.getHttpPrefix())
print [[/lua/flow_stats.lua',
		    data: { ifid: "]] print(tostring(ifid)) print [[", ]]
print [[flow_key: "]] print(string.format("%u", flow_key)) print [[", ]]
print [[flow_hash_id: "]] print(string.format("%u", flow_hash_id)) print [[", ]]
print[[ },
		    success: function(content) {
			if(content == "{}") {
   ]]

-- If the flow is already idle, another error message is already shown
if(flow ~= nil) then
   print[[
                          var e = document.getElementById('flow_purged');
                          e.style.display = "block";
   ]]
end

print[[
                        } else {
			var rsp = jQuery.parseJSON(content);
			$('#first_seen').html(rsp["seen.first"]);
			$('#last_seen').html(rsp["seen.last"]);
			$('#volume').html(NtopUtils.bytesToVolume(rsp.bytes));
			$('#goodput_volume').html(NtopUtils.bytesToVolume(rsp["goodput_bytes"]));
			pctg = ((rsp["goodput_bytes"]*100)/rsp["bytes"]).toFixed(1);

			/* 50 is the same threshold specified in FLOW_GOODPUT_THRESHOLD */
			if(pctg < 50) { pctg = "<font color=red>"+pctg+"</font>"; } else if(pctg < 60) { pctg = "<font color=orange>"+pctg+"</font>"; }

			$('#goodput_percentage').html(pctg);
			$('#cli2srv').html(NtopUtils.addCommas(rsp["cli2srv.packets"])+" Pkts / " + NtopUtils.addCommas(NtopUtils.bytesToVolume(rsp["cli2srv.bytes"])));
			$('#srv2cli').html(NtopUtils.addCommas(rsp["srv2cli.packets"])+" Pkts / " + NtopUtils.addCommas(NtopUtils.bytesToVolume(rsp["srv2cli.bytes"])));
			$('#throughput').html(rsp.throughput);

			if(typeof rsp["c2sOOO"] !== "undefined") {
			   $('#c2sOOO').html(NtopUtils.formatPackets(rsp["c2sOOO"]));
			   $('#s2cOOO').html(NtopUtils.formatPackets(rsp["s2cOOO"]));
			   $('#c2slost').html(NtopUtils.formatPackets(rsp["c2slost"]));
			   $('#s2clost').html(NtopUtils.formatPackets(rsp["s2clost"]));
			   $('#c2skeep_alive').html(NtopUtils.formatPackets(rsp["c2skeep_alive"]));
			   $('#s2ckeep_alive').html(NtopUtils.formatPackets(rsp["s2ckeep_alive"]));
			   $('#c2sretr').html(NtopUtils.formatPackets(rsp["c2sretr"]));
			   $('#s2cretr').html(NtopUtils.formatPackets(rsp["s2cretr"]));
			}
			if (rsp["cli2srv_quota"]) $('#cli2srv_quota').html(rsp["cli2srv_quota"]);
			if (rsp["srv2cli_quota"]) $('#srv2cli_quota').html(rsp["srv2cli_quota"]);

			/* **************************************** */

			if(cli2srv_packets == rsp["cli2srv.packets"]) {
			   $('#sent_trend').html("<i class=\"fas fa-minus\"></i>");
			} else {
			   $('#sent_trend').html("<i class=\"fas fa-arrow-up\"></i>");
			}

			if(srv2cli_packets == rsp["srv2cli.packets"]) {
			   $('#rcvd_trend').html("<i class=\"fas fa-minus\"></i>");
			} else {
			   $('#rcvd_trend').html("<i class=\"fas fa-arrow-up\"></i>");
			}

			if(bytes == rsp["bytes"]) {
			   $('#volume_trend').html("<i class=\"fas fa-minus\"></i>");
			} else {
			   $('#volume_trend').html("<i class=\"fas fa-arrow-up\"></i>");
			}

			if(goodput_bytes == rsp["goodput_bytes"]) {
			   $('#goodput_volume_trend').html("<i class=\"fas fa-minus\"></i>");
			} else {
			   $('#goodput_volume_trend').html("<i class=\"fas fa-arrow-up\"></i>");
			}

			if(throughput > rsp["throughput_raw"]) {
			   $('#throughput_trend').html("<i class=\"fas fa-arrow-down\"></i>");
			} else if(throughput < rsp["throughput_raw"]) {
			   $('#throughput_trend').html("<i class=\"fas fa-arrow-up\"></i>");
			   $('#top_throughput').html(rsp["top_throughput_display"]);
			} else {
			   $('#throughput_trend').html("<i class=\"fas fa-minus\"></i>");
			} ]]

      if(isThereSIP == 1) then
	updatePrintSip()
      end
      if(isThereRTP == 1) then
	updatePrintRtp()
      end
print [[			cli2srv_packets = rsp["cli2srv.packets"];
			srv2cli_packets = rsp["srv2cli.packets"];
			throughput = rsp["throughput_raw"];
			bytes = rsp["bytes"];

	 /* **************************************** */
	 // Processes information update, based on the pid

	 for (var pid in rsp["processes"]) {
	    var proc = rsp["processes"][pid]
	    // console.log(pid);
	    // console.log(proc);
	    if (proc["memory"])           $('#memory_'+pid).html(proc["memory"]);
	    if (proc["average_cpu_load"]) $('#average_cpu_load_'+pid).html(proc["average_cpu_load"]);
	    if (proc["percentage_iowait_time"]) $('#percentage_iowait_time_'+pid).html(proc["percentage_iowait_time"]);
	    if (proc["page_faults"])      $('#page_faults_'+pid).html(proc["page_faults"]);
	 }

			/* **************************************** */

			var values = thptChart.text().split(",");
			values.shift();
			values.push(rsp.throughput_raw);
			thptChart.text(values.join(",")).change();
		     } }
		   });
		 }

]]

print ("setInterval(update,3000);\n")

print [[
</script>
 ]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
