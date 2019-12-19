--
-- (C) 2019 - ntop.org
--

-- This file contains extends the "Alert Endpoints" preferences menu with
-- custom entries, with full "Search Preferences" support.

return {
  -- The alert endpoint linked to this preferences. This is required in order
  -- to populate the actual menu via the "printPrefs" callback.
  endpoint_key = "example",

  -- Defines the additional menu entries
  entries = {
    -- The menu entry ID. Will be referenced in the endpoint "printPrefs" callback.
    toggle_example_notification = {
      -- A brief title for the preference
      title       = i18n("example.toggle_example_notification_title"),
      -- The preference description
      description = i18n("example.toggle_example_notification_description"),
    },
  }
}
