--
-- (C) 2020 - ntop.org
--

return {
   url = "WebHook URL",
   username = "Username",
   validation = {
      empty_url = "Discord Webook URL cannot be empty.",
      invalid_url = "Invalid Discord Webhook URL. See https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks.",
      invalid_username = "Invalid Discord username.",
   },
   discord_send_error = "Error sending message to Discord.",
   message_sender = "Nickname of the discord message sender (optional). ",

   webhook_description = "Instructions:<ul><li>Open the Discord channel you want to receive ntopng notifications from.<li>From the channel menu, select Edit channel (or click on the wheel icon). <li>Click on Webhooks menu item.<li>Click the Create Webhook button and fill in the name of the bot that will post the messages (note that you can set it on the ntopng recipients page)<li>Note the URL from the WebHook URL field to be copied in the field above. <li>Click the Save button.</ul>"
      
}
