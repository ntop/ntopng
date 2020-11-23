--
-- (C) 2020 - ntop.org
--

local page_utils = require("page_utils")
local predicates = require("predicates_defined_toasts")

-- Placeholder for pages/excluded, subpages/excluded tables
local EMPTY_PAGES = {}
local pages = page_utils.menu_entries

--- Define a new toast is easy, here is 3 steps to follow:
--- 1) choose a new toast id that must be unique
--- 2) define the dismissability of the toast with `dismissable` field
--- 3) define a predicate function that generate the ui for the toast
--- Following there is a structure of a toast:
--[[
    {
        id: string,
        dismissable: boolean,
        has_priority: boolean,
        pages: array of page keys,
        subpages: table of arrays of subpages,
        excluded_pages: array of page keys
        excluded_subpages: table of arrays of subpages
    }
]]--

--- id: The id field defines an unique toast to be displayed. This field is used
--- to make the Redis Key for the toast status (the dimiss status)

--- dismissable: as the name suggest, this field indicates if a notifican can be dismissed by the user
--- has_priority: the toasts with this flag enabled won't be count when rendering,
--- so they will alway be displayed

--- pages: this is an array of page keys that are used to show the toast to the right page
--- subpages: this is a table containing key/value pairs where key='page entry key' and the
--- value is an array of subpages string, for example ({['if_stats'] = {'DHCP', 'config', ...}})
--- Be aware that the subpage is obtained by the _GET 'page' param.

--- excluded_pages: is the opposite of pages
--- excluded_subpages: is the opposite of subpages

--- It's a good convention to put the predicate functions inside the module: `predicates_defined_toasts`

local defined_toats = {
    {
        id = 0,
        dismissable = false,
        has_priority = false,
        predicate = predicates.contribute,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = {pages.preferences.key},
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 1,
        dismissable = false,
        has_priority = true,
        predicate = predicates.about_page,
        pages = {pages.about.key},
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 2,
        dismissable = true,
        has_priority = false,
        predicate = predicates.hosts_geomap,
        pages = {pages.geo_map.key},
        subpages = { [pages.hosts.key] = {'geomap'} },
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 3,
        dismissable = false,
        has_priority = true,
        predicate = predicates.restart_required,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 4,
        dismissable = false,
        has_priority = true,
        predicate = predicates.flow_dump,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 5,
        dismissable = false,
        has_priority = true,
        predicate = predicates.remote_probe_clock_drift,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 6,
        dismissable = false,
        has_priority = false,
        predicate = predicates.temp_working_dir,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 7,
        dismissable = true,
        has_priority = false,
        predicate = predicates.geo_ip,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 8,
        dismissable = true,
        has_priority = false,
        predicate = predicates.update_ntopng,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 9,
        dismissable = false,
        has_priority = true,
        predicate = predicates.too_many_hosts,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 10,
        dismissable = false,
        has_priority = true,
        predicate = predicates.too_many_flows,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        -- The same predicate is used with the toast with id 12
        -- because thery are mutually exclusive
        id = 11,
        dismissable = true,
        has_priority = false,
        predicate = predicates.DHCP,
        pages = {pages.interfaces_status.key},
        subpages = EMPTY_PAGES,
        excluded_pages = {pages.preferences.key},
        excluded_subpages = {[pages.interfaces_status.key] = {'dhcp', 'config'}}
    },
    {
        id = 12,
        dismissable = true,
        has_priority = false,
        predicate = predicates.DHCP,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = {pages.preferences.key},
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 13,
        dismissable = true,
        has_priority = false,
        predicate = predicates.exporters_SNMP_ratio_column,
        pages = {pages.flow_exporters.key},
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 14,
        dismissable = false,
        has_priority = true,
        predicate = predicates.forced_community,
        pages = {},
        subpages = EMPTY_PAGES,
        excluded_pages = EMPTY_PAGES,
        excluded_subpages = EMPTY_PAGES
    },
    {
        -- Hint to invite the user to create endpoints to send alert
        id = 15,
        dismissable = true,
        has_priority = false,
        predicate = predicates.create_endpoint,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = {pages.endpoint_notifications.key, pages.preferences.key},
        excluded_subpages = EMPTY_PAGES
    },
    {
        -- Hint to invite the user to create recipients for the endpoints
        id = 16,
        dismissable = true,
        has_priority = false,
        predicate = predicates.create_recipients_for_endpoint,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = {pages.endpoint_recipients.key},
        excluded_subpages = EMPTY_PAGES
    },
    {
        -- Hint to invite the user to bind the recipients to some pools
        id = 17,
        dismissable = true,
        has_priority = false,
        predicate = predicates.bind_recipient_to_pools,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = {pages.manage_pools.key},
        excluded_subpages = EMPTY_PAGES
    },
    {
        id = 18,
        dismissable = true,
        has_priority = false,
        predicate = predicates.unexpected_plugins,
        pages = EMPTY_PAGES,
        subpages = EMPTY_PAGES,
        excluded_pages = {pages.scripts_config.key},
        excluded_subpages = EMPTY_PAGES
    },
}

return defined_toats
