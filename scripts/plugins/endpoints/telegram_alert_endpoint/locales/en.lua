--
-- (C) 2020 - ntop.org
--

return {
   telegram_token = "Token",
   telegram_channel = "Channel Id",
   validation = {
      invalid_token = "Invalid Telegram Token.",
      invalid_channel_name = "Invalid Telegram Channel Name.",
   },
   telegram_send_error = "Error sending message to Telegram.",

   webhook_description = {
      token_description = "Instructions:<ul><li>Start a new chat with @BotFather<li>Type and send '/newbot'<li>Give a name to your bot<li>Give a username to your bot<li>Copy here the token the @BotFather gave to you</ul>",
      channel_id_description = "Instructions if you want to use the bot in a chat:<ul><li>Start a conversation with the bot in Telegram (a bot can't initiate conversation with a user!)<li>Start a new conversation with @getidsbot<li>Copy here the id the @getidsbot gave to you</ul>Instructions if you want to use the bot in a group:<ul><li>Add to your group the bot you created<li>Add to your group @getidsbot<li>Copy here the id the @getidsbot gave to you</ul>",
   }

}
