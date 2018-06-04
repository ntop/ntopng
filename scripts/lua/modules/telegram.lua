--
-- (C) 2018 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local telegram = {}

-- ########################################################

local char_to_hex = function(c)
   return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
   if url == nil then
      return
   end
   url = url:gsub("\n", "\r\n")
   url = url:gsub("([^%w ])", char_to_hex)
   url = url:gsub(" ", "+")
   return url
end

-- ########################################################
-- #
-- # Steps
-- #
-- # 1. Create a new bot
-- #    - connect to @BotFather
-- #    - type /newbot
-- #    - Write down the bot_token_id
-- #    - Optional "turn on privacy"
-- #
-- # 2. Get the chat_id
-- #    - Do curl -s -X POST https://api.telegram.org/bot<bot_token_id>/getUpdates
-- #      and you will the chat id in the JSON response code
-- #      as ..."chat":{"id":XXXXXXXX,
-- #
-- ########################################################

function telegram.sendMessage(bot_token_id, chat_id, message)
   local url = "https://api.telegram.org/bot"..bot_token_id.."/sendMessage"
   local postfields = "chat_id="..chat_id.."&text="..urlencode(message)

   ntop.postHTTPform("", "", url, postfields)
end

-- ########################################################

return telegram
