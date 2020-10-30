--
-- (C) 2020 - ntop.org
--

return {
   token = "Token",
   channel_name = "Channel name",
   validation = {
      invalid_token = "Invalid Telegram token.",
      invalid_channel_name = "Invalid Telegram channel name.",
   },
   telegram_send_error = "Error sending message to Telegram.",

   webhook_description = "Instructions:<ul><li>Open the Telegram channel you want to receive ntopng notifications from.<li>From the channel menu, select Edit channel (or click on the wheel icon). <li>Click on Webhooks menu item.<li>Click the Create Webhook button and fill in the name of the bot that will post the messages (note that you can set it on the ntopng recipients page)<li>Note the URL from the WebHook URL field to be copied in the field above. <li>Click the Save button.</ul>"
      
}
