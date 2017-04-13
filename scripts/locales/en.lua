local  en = {
   welcome = "Welcome",
   version = "Your version is %{vers}.",
   error = "Error",
   warning = "Warning",
   host = "Host %{host}",
   hour = "Hour",
   day = "Day",
   week = "Week",
   month = "Month",
   time = "Time",
   sent = "Sent",
   received = "Received",
   difference = "Difference",
   total = "Total",
   today = "Today",
   actions = "Actions",
   delete = "Delete",
   undo = "Undo",
   empty = "Empty",
   clone = "Clone",
   from = "from",
   protocol = "Protocol",
   port = "Port",
   max_rate = "Max Rate",
   duration = "Duration",
   traffic = "Traffic",
   save = "Save",
   close = "Close",
   remove = "Remove",
   save_settings = "Save Settings",
   all = "All",
   define = "Define",
   traffic_policy = "Traffic Policy",
   unlimited = "Unlimited",
   bytes = "Bytes",
   packets = "Packets",
   flow = "Flow",
   flows = "Flows",
   talkers = "Talkers",
   protocols = "Protocols",
   overview = "Overview",
   unknown = "Unknown",
   ssl_certificate = "SSL Certificate",
   tcp_flags = "TCP Flags",
   any = "any",
   interface_ifname = "Interface %{ifname}",
   ip_address = "IP Address",
   info = "Info",

   graphs = {
      arp_requests = "ARP Requests",
      arp_replies = "ARP Replies",
      packet_drops = "Packet Drops",
      active_flows = "Active Flows",
      active_hosts = "Active Hosts",
      active_devices = "Active Devices",
      active_http_servers = "Active HTTP Servers",
      zmq_received_flows = "ZMQ Received Flows",
      tcp_packets_lost = "TCP Packets Lost",
      tcp_packets_ooo = "TCP Packets Out-Of-Order",
      tcp_packets_retr = "TCP Retransmitted Packets",
      tcp_retr_ooo_lost = "TCP Retransmitted Out-Of-Order and Lost",
      tcp_syn_packets = "TCP SYN Packets",
      tcp_synack_packets = "TCP SYN+ACK Packets",
      tcp_finack_packets = "TCP FIN+ACK Packets",
      tcp_rst_packets = "TCP RST Packets",
      average_traffic = "Average Traffic/sec",
      top_senders = "Top Senders",
      top_receivers = "Top Receivers",
      top_profiles = "Top Profiles",
      all_protocols = "All Protocols",
   },

   traffic_report = {
      daily = "Daily",
      weekly = "Weekly",
      monthly = "Monthly",
      header_daily = "Daily report",
      header_weekly = "Weekly report",
      header_monthly = "Monthly report",
      current_day = "Current Day",
      current_week = "Current Week",
      current_month = "Current Month",
      previous_day = "Previous Day",
      previous_week = "Previous Week",
      previous_month = "Previous Month",
   },

   report = {
      period = "Interval",
      begin_date_time = "Begin Date/Time",
      end_date_time = "End Date/Time",
      date = "%{month}-%{day}-%{year}",
      generate = "Generate",
      invalid_begin_date = "Invalid Begin Date",
      please_check_format = "please check its format",
      please_choose_valid = "please choose a valid begin/end date and time",
      invalid_begin_end = "Invalid Begin/End",
      invalid_begin = "Invalid Begin",
      please_choose_valid_date_and_time = "please choose a valid date and time",
      invalid_to = "Invalid To",
      traffic_report = "Traffic Report",
      starting = "Starting",
      network_interface = "Network Interface",
      report_for_subject = "Report - %{num_min} - for %{subject} starting %{dt}",
      filter_report = "Filter Report",
      toggle_all = "Toggle All",
      submit_filter = "Submit Filter",
      application_breakdown = "Application Breakdown",
      local_networks = "Local Networks",
      local_remote = "Local/Remote",
      remote_local = "remote/local",
      total_traffic = "Total Traffic",
      applications = "Applications",
      top_talkers = "Top Talkers",
      top_countries = "Top Countries",
      top_local_hosts = "Top Local Hosts",
      top_remote_hosts = "Top Remote Hosts",
      top_local_os = "Top Local OS",
      top_non_local_os = "Top Non-Local OS",
      top_asn = "Top ASN",
      top_networks = "Top Networks",
      reports_professional_only = "Reports are only available in the Professional version",
      senders = "Senders",
      receivers = "Receivers",
   },

   shaping = {
      protocols = "Protocols",
      manage_policies = "Manage Policies",
      bandwidth_manager = "Bandwidth Manager",
      shaper0_message = "Shaper 0 is the default shaper used for local hosts that have no shaper defined",
      set_max_rate_to = "Set max rate to",
      for_no_shaping = "for no shaping",
      for_dropping_all_traffic = "for dropping all traffic",
      protocols_policies = "Protocols Policies",
      select_to_clone = "Select an existing network to clone the protocol rules from",
      initial_empty_protocols = "Initial protocols rules will be empty",
      initial_clone_protocols = "Initial protocol rules will be cloned",
      shaper_id = "Shaper Id",
      applied_to = "Applied to",
      notes = "NOTES",
      shapers_in_use_message = "Shapers can be deleted only if they are not applied to any network",
      no_shapers_available = "No shapers available",
      protocol_families = "Protocol Families",
      traffic_to = "Traffic to",
      traffic_from = "Traffic from",
      protocol_policy = "Traffic Policy",
      daily_traffic_quota = "Daily Traffic Quota",
      daily_time_quota = "Daily Time Quota",
      daily_traffic = "Daily Traffic (Current / Quota)",
      no_quota_data = "No quota set",
      daily_time = "Daily Time (Current / Quota)",
      delete_policy = "Delete Policy",
      confirm_delete_policy = "Do you really want to delete",
      policy_from_pool = "policy from pool",
      delete_shaper = "Delete Shaper",
      confirm_delete_shaper = "Do you really want to delete shaper ",
      note_drop_core = "Dropping some core protocols can have side effects on other protocols. For instance if you block DNS,<br>symbolic host names are no longer resolved, and thus only communication with numeric IPs work.",
      note_quota_unlimited = "Set Traffic and Time Quota to 0 for unlimited traffic.",
      note_families = "Protocol Families can be used to set the same policy on multiple protocols at once.<br>Use the dropdown below to obtain the list of protocols contained into a Protocol Family:",
      see_quotas_here = "Visit the host pool <a href='%{url}'>quotas page</a> for the full overview of the active host pool quotas."
   },

   alert_messages = {
      open_files_limit_too_small = "Ntopng detected that the maximum number of files MySQL can open is potentially too small. "..
	 "This can result in flow data loss due to errors such as "..
	 "[Out of resources when opening file './ntopng/flowsv6#P#p22.MYD' (Errcode: 24 - Too many open files)][23]. "..
	 "Make sure to increase open_files_limit or, if you just want to ignore this warning, disable the check from the preferences."
   },

   show_alerts = {
      alerts = "Alerts",
      engaged_alerts = "Engaged Alerts",
      past_alerts = "Past Alerts",
      flow_alerts = "Flow Alerts",
      older_5_minutes_ago = "older than 5 minutes ago",
      older_30_minutes_ago = "older than 30 minutes ago",
      older_1_hour_ago = "older than 1 hour ago",
      older_1_day_ago = " older than 1 day ago",
      older_1_week_ago = "older than 1 week ago",
      older_1_month_ago = "older than 1 month ago",
      older_6_months_ago = "older than 6 months ago",
      older_1_year_ago = "older than 1 year ago",
      alert_actions = "Actions",
      alert_severity = "Severity",
      alert_type = "Alert Type",
      alert_datetime = "Date/Time",
      alert_duration = "Duration",
      alert_description = "Description",
      alert_counts = "Counts",
      last_minute = "Last Minute",
      last_hour = "Last Hour",
      last_day = "Last Day",
      iface_delete_config_btn = "Delete All Interface Configured Alerts",
      iface_delete_config_confirm = "Do you really want to delete all configured alerts for interface",
      network_delete_config_btn = "Delete All Network Configured Alerts",
      network_delete_config_confirm = "Do you really want to delete all configured alerts for network",
      host_delete_config_btn = "Delete All Host Configured Alerts",
      host_delete_config_confirm = "Do you really want to delete all configured alerts for host",
   },

   alerts_dashboard = {
      flow_alert_origins  = "Flow Alert Origins",
      flow_alert_targets  = "Flow Alert Targets",
      engaged_for_longest = "Engaged for Longest",
      starting_on = "starting on",
      total_alerts = "Total Alerts",
      no_alerts = "No alerts",
      not_engaged = "Not engaged",

      trailing_msg = "Time Window",
      one_min = "Last Minute",
      five_mins = "Last 5 Minutes",
      one_hour = "Last Hour",
      one_day = "Last Day",

      involving_msg = "Flow Alerts Involving",
      all_hosts = "All Hosts",
      local_only = "Local Hosts Only",
      remote_only = "Remote Hosts Only",
      local_origin_remote_target = "Local Origin - Remote Target",
      remote_origin_local_target = "Remote Origin - Local Target",

      search_criteria = "Dashboard Settings",
      submit = "Update Dashboard",

      alert_severity = "Severity",
      alert_type = "Type",
      alert_duration = "Duration",
      alert_counts = "Counts",
      custom_period = "Custom Period",
      last_minute = "Last Minute",
      last_hour = "Last Hour",
      last_day = "Last Day"
   },

   flow_alerts_explorer = {
      label = "Flow Alerts Explorer",
      flow_alert_origin  = "Alert Origin",
      flow_alert_target  = "Alert Target",

      type_explorer = "Type Explorer",
      type_alerts_by_type = "Flow Alerts By Type",
      by_target_port = "By Target Port",
      origins = "Origins",
      targets = "Targets",

      visual_explorer = "Visual Explorer",
      search = "Search Flow Alerts",

      summary_total = "Total Flow Alerts",
      summary_n_origins = "Total Origins",
      summary_n_targets = "Total Targets",
      summary_cli2srv = "Total Origin to Target Traffic",
      summary_srv2cli = "Total Target to Origin Traffic"
   },

   db_explorer = {
      observation_period = "Observation Period",
      client_server_host = "Client/Server Host",
      application_protocol = "Application Protocol",
      search_flows = "Search Flows",
      pcaps = "Pcaps",
      unable_to_find_flow = "Unable to find the specified flow",
      flow_peers = "Flow Peers",
      vlan_id = "VLAN Id",
      first_last_seen = "First / Last Seen",
      client_server_breakdown = "Client vs Server Traffic Breakdown",
      this_flow_has_been_reset = "This flow has been reset and probably the server application is down",
      this_flow_is_completed = "This flow is completed and will soon expire",
      this_flow_is_active = "This flow is active",
      network_latency_breakdown = "Network Latency Breakdown",
      ms_client = "%{client} ms (client)",
      ms_server = "%{server} ms (server)",
      http_method = "HTTP Method",
      server_name = "Server Name",
      response_code = "Response Code",
      http_host = "HTTP Host",
      dns_query = "DNS Query",
      interface_name = "Instance Name",
      selected_saved = "Select saved",
      extract_pcap = "Extract pcap",
      request_failed = "Request failed",
      ok_request_sent = "OK, request sent",
      nbox_disabled = "nBox integration is disabled",
      enable_it_via = "Enable it via <a href=\"%{url}\">%{icon} preferences</a>",
      all = "all",
      unsave = "Unsave",
      application_flows = "Application flows",
      talkers_with_this_host = "Talkers with this host",
      host_name = "Host Name",
      traffic_sent = "Traffic Sent",
      traffic_received = "Traffic Received",
      total_traffic = "Total Traffic",
      total_packets = "Total Packets",
   },

   traffic_profiles = {
      edit_traffic_profiles = "Edit Traffic Profiles",
      traffic_filter_bpf = "Traffic Filter (BPF Format)",
      profile_name = "Profile Name",
      no_profiles = "No profiles set",
      filter_examples = "Filter Examples",
      note = "Note",
      hint_1_pre = "Hint: use",
      hint_1_after = "to print all nDPI supported protocols",
      note_0 = "Traffic profile names allow alpha-numeric characters, spaces, and underscores",
      note_1 = "Traffic profiles are applied to flows. Each flow can have up to one profile, thus in case of multiple profile matches, only the first one is selected",
      note_2 = "See ntopng -h for a list of nDPI numeric protocol number to be used with term l7proto. Only numeric protocol identifiers are accepted (no symbolic protocol names)",
      enter_profile_name = "Enter a profile name",
      enter_profile_filter = "Enter the profile filter",
      invalid_bpf = "Invalid BPF filter",
      duplicate_profile = "Duplicate profile name",
      delete_profile = "Delete Profile",
      confirm_delete_profile = "Do you really want to delete the profile",
   },

   host_pools = {
      edit_host_pools = "Edit Host Pools",
      pool = "Pool Name",
      manage_pools = "Manage Pool Membership",
      create_pools = "Manage Pools",
      empty_pool = "Empty Pool",
      delete_pool = "Delete Pool",
      remove_member = "Remove Member",
      pool_name = "Pool Name",
      no_pools_defined = "No Host Pools defined.",
      create_pool_hint = "You can create new pools from the Manage Pools tab.",
      member_address = "Member Address",
      specify_pool_name = "Specify a pool name",
      specify_member_address = "Specify an IPv4/IPv6 address or network or a MAC address",
      invalid_member = "Invalid member address format",
      duplicate_member = "Duplicate member address",
      duplicate_pool = "Duplicate pool name",
      confirm_delete_pool = "Do you really want to delete host pool",
      confirm_remove_member = "Do you really want to remove member",
      confirm_empty_pool = "Do you really want to remove all members from the host pool",
      from_pool = "from host pool",
      and_associated_members = "its RRD data and any associated members",
      search_member = "Search Member",
      network_normalized = "network \"%{network}\" has been normalized to \"%{network_normalized}\".",
      member_exists = "member \"%{member_name}\" not added. It is already assigned to pool \"%{member_pool}\".",
   },

   snmp = {
      bound_interface_description = "Binding a network interface to an SNMP interface is useful to compare network traffic monitored by ntopng with that reported by SNMP",
   },

   dashboard = {
      top_local_talkers = "Top Local Talkers",
      actual_traffic = "Actual Traffic",
      realtime_app_traffic = "Realtime Top Application Traffic",
      realtime_traffic = "Network Interfaces: Realtime Traffic",
      top_remote_destinations = "Top Remote Destinations",
      lastday_app_traffic = "Top Application Traffic Last Day View",
      lastday_traffic = "Network Interfaces: Last Day View",
   },

   about = {
      about = "About",
      licence = "License",
      version = "Version",
      licence_generation = "Click on the above URL to generate your professional version license, or <br>purchase a license at <a href=\"%{purchase_url}\">e-shop</a>. If you are no-profit, research or an education<br>institution please read <a href=\"%{universities_url}\">this</a>.",
      specify_licence = "Specify here your ntopng License",
      save_licence = "Save Licence",
      built_on = "Built on",
      maxmind = "This product includes GeoLite data created by <a href=\"%{maxmind_url}\">MaxMind</a>.",
      system_id = "System Id",
      runtime_status = "Runtime Status",
      platform = "Platform",
      startup_line = "Startup Line",
      last_log = "Last Log Trace",
   },

   prefs = {
      expert_view = "Expert View",
      simple_view = "Simple View",
      search_preferences = "Search Preferences",
      authentication = "Authentication",
      multiple_ldap_authentication_title = "Authentication Method",
      multiple_ldap_authentication_description = "Local (Local only), LDAP (LDAP server only), LDAP/Local (Authenticate with LDAP server, if fails it uses local authentication).",
      multiple_ldap_account_type_title = "LDAP Accounts Type",
      multiple_ldap_account_type_description = "Choose your account type",
      ldap_server_address_title = "LDAP Server Address",
      ldap_server_address_description = "IP address and port of LDAP server (e.g. ldaps://localhost:636). Default: \"ldap://localhost:389\".",
      user_authentication = "User Authentication",
      network_interfaces = "Network Interfaces",
      cache_settings = "Cache Settings",
      data_retention = "Data Retention",
      mysql = "MySQL",
      external_alerts = "External Alerts Report",
      protocols = "Protocols",
      flow_database_dump = "Flow Database Dump",
      snmp = "SNMP",
      nbox_integration = "nBox Integration",
      misc = "Misc",
      traffic_bridging = "Traffic Bridging",
      dynamic_network_interfaces = "Dynamic Network Interfaces",
      dynamic_iface_vlan_creation_title = "VLAN Disaggregation",
      dynamic_iface_vlan_creation_description = "Toggle the automatic creation of virtual interfaces based on VLAN tags.",
      dynamic_iface_vlan_creation_note_1 = "Value changes will not be effective for existing interfaces.",
      dynamic_iface_vlan_creation_note_2 = "This setting is valid only for packet-based interfaces (no flow collection).",
      dynamic_flow_collection_title = "Dynamic Flow Collection Interfaces",
      dynamic_flow_collection_description = "When ntopng is used in flow collection mode (e.g. -i tcp://127.0.0.1:1234c), flows can be collected on dynamic sub-interfaces based on the specified criteria",
      dynamic_flow_collection_note_1 = "Value changes will not be effective for existing interfaces.",
      dynamic_flow_collection_note_2 = "This setting is valid only for based-based interfaces (no packet collection).",
      idle_timeout_settings = "Idle Timeout Settings",
      local_host_max_idle_title = "Local Host Idle Timeout",
      local_host_max_idle_description = "Inactivity time after which a local host is considered idle (sec). "..
            "Idle local hosts are dumped to a cache so their counters can be restored in case they become active again. "..
            "Counters include, but are not limited to, packets and bytes total and per Layer-7 application. "..
            "Default: 5 min.",
      non_local_host_max_idle_title = "Remote Host Idle Timeout",
      non_local_host_max_idle_description = "Inactivity time after which a remote host is considered idle. Default: 1 min.",
      flow_max_idle_title = "Flow Idle Timeout",
      flow_max_idle_description = "Inactivity time after which a flow is considered idle. Default: 1 min.",
      housekeeping_frequency_title = "Hosts Statistics Update Frequency",
      housekeeping_frequency_description = "Some host statistics such as throughputs are updated periodically. "..
            "This timeout regulates how often ntopng will update these statistics. "..
            "Larger values are less computationally intensive and tend to average out minor variations. "..
            "Smaller values are more computationally intensive and tend to highlight minor variations. "..
            "Values in the order of few seconds are safe. " ..
            "Default: 5 seconds.",
      timeseries = "Timeseries",
      toggle_local_title = "Traffic",
      toggle_local_description = "Toggle the creation of bytes and packets timeseries for local hosts and defined local networks.<br>"..
            "Turn it off to save storage space.",
      toggle_local_ndpi_title = "Layer-7 Application",
      toggle_local_ndpi_description = "Toggle the creation of application protocols timeseries for local hosts and defined local networks.<br>"..
            "Turn it off to save storage space.",
      toggle_local_activity_title = "Activities",
      toggle_local_activity_description = "Toggle the creation of activities timeseries for local hosts.<br>"..
            "This enables the activity detection heuristics, which try to extract human behaviours from host traffic (e.g. web browsing, chat).<br>"..
            "Creation is only possible if the ntopng instance has been launched with option --enable-flow-activity.",
      toggle_flow_rrds_title = "Flow Devices",
      toggle_flow_rrds_description = "Toggle the creation of bytes timeseries for each port of the remote device as received through ZMQ (e.g. sFlow/NetFlow/SNMP).<br>"..
            "For non sFlow devices, the ZMQ fields INPUT_SNMP and OUTPUT_SNMP are required.",
      toggle_pools_rrds_title = "Host Pools",
      toggle_pools_rrds_description = "Toggle the creation of bytes and application protocols timeseries for defined host pools.",
      toggle_asn_rrds_title = "Autonomous Systems",
      toggle_asn_rrds_description = "Toggle the creation of bytes and application timeseries for autonomous systems.",
      toggle_tcp_flags_rrds_title = "TCP Flags",
      toggle_tcp_flags_rrds_description = "Toggle the creation of TCP flags SYN, SYN+ACK, FIN+ACK and RST timeseries for network interfaces.",
      toggle_tcp_retr_ooo_lost_rrds_title = "TCP Out of Order, Lost and Retransmitted Segments",
      toggle_tcp_retr_ooo_lost_rrds_description = "Toggle the creation of timeseries for out-of-order, lost and retransmitted TCP segments. Timeseries will be created for network interfaces, autonomous systems, local networks and vlans.",
      toggle_local_categorization_title = "Categories",
      toggle_local_categorization_description = "Toggle the creation of categories timeseries for local hosts and defined local networks.<br>"..
            "Enabling their creation allows you "..
            "to keep persistent traffic category statistics (e.g. social networks, news) at the cost of using more disk space.<br>"..
            "Creation is only possible if the ntopng instance has been launched with option ",
      local_hosts_cache_settings = "Local Hosts Cache Settings",
      toggle_local_host_cache_enabled_title = "Idle Local Hosts Cache",
      toggle_local_host_cache_enabled_description = "Toggle the creation of cache entries for idle local hosts. "..
            "Cached local hosts counters are restored automatically to their previous values "..
            " upon detection of additional host traffic.",
      toggle_active_local_host_cache_enabled_title = "Active Local Hosts Cache",
      toggle_active_local_host_cache_enabled_description = "Toggle the creation of cache entries for idle local hosts. "..
            "Toggle the creation of cache entries for active local hosts. "..
            "Caching active local hosts periodically can be useful to protect host counters against "..
            "failures (e.g., power losses). This is particularly important for local hosts that seldomly go idle "..
            "as it guarantees that their counters will be cached after the specified time interval.",
      active_local_host_cache_interval_title = "Active Local Host Cache Interval",
      active_local_host_cache_interval_description = "Interval between consecutive active local hosts cache dumps. Default: 1 hour.",
      local_host_cache_duration_title = "Local Hosts Cache Duration",
      local_host_cache_duration_description = "Time after which a cached local host is deleted from the cache. Default: 1 hour.",
      databases = "Databases",
      minute_top_talkers_retention_title = "Top Talkers Storage",
      minute_top_talkers_retention_description = "Number of days to keep one minute resolution top talkers statistics. Default: 365 days.",
      mysql_retention_title = "MySQL storage",
      mysql_retention_description = "Duration in days of data retention for the MySQL database. Default: 7 days.<br>MySQL is used to store exported flows data.<br>"..
            "Flows dump is only possible if the ntopng instance has been launched with option ",
      toggle_mysql_check_open_files_limit_title = "Enable MySQL alerts",
      toggle_mysql_check_open_files_limit_description = "Enable MySQL alerts generations due to periodic checks of MySQL open_files_limit.<br>"..
            "The open_files_limit check is useful to detect when the number of open MySQL files is high, which could lead to database insertion errors.",
      disable_alerts_generation_title = "Enable Alerts",
      disable_alerts_generation_description = "Toggle the overall generation of alerts.",
      toggle_flow_alerts_iface_title = "Enable Flow Alerts",
      toggle_flow_alerts_iface_description = "Enable flow alert generation when the network interface is alerted.",
      security_alerts = "Security Alerts",
      toggle_alert_probing_title = "Enable Probing Alerts",
      toggle_alert_probing_description = "Enable alerts generated when probing attempts are detected.",
      toggle_malware_probing_title = "Enable Hosts Malware Blacklists",
      toggle_malware_probing_description = "Enable alerts generated by traffic sent/received by "..
            "<a href=\"%{url}\">malware-marked hosts</a>. Overnight new blacklist rules are refreshed.",
      alerts_retention = "Alerts Retention",
      max_num_alerts_per_entity_title = "Maximum Number of Alerts per Entity",
      max_num_alerts_per_entity_description = "The maximum number of alerts per alarmable entity. Alarmable entities are hosts, networks, interfaces and flows. "..
            "Once the maximum number of entity alerts is reached, oldest alerts will be overwritten. Default: 1024.",
      max_num_flow_alerts_title = "Maximum Number of Flow Alerts",
      max_num_flow_alerts_description = "The maximum number of flow alerts. Once the maximum number of alerts is reached, oldest alerts will be overwritten. Default: 16384.",
      internal_log = "Internal Log",
      toggle_alert_syslog_title = "Alerts On Syslog",
      toggle_alert_syslog_description = "Enable alerts logging on system syslog.",
      slack_integration = "Slack Integration",
      toggle_slack_notification_title = "Enable <a href=\"%{url}\">Slack</a> Notification",
      toggle_slack_notification_description = "Toggle the alert notification via slack.",
      sender_username_title = "Notification Sender Username",
      sender_username_description = "Set the username of the sender of slack notifications",
      slack_webhook_title = "Notification Webhook",
      slack_webhook_description = "Send your notification to this slack URL",
      nagios_integration = "Nagios Integration",
      toggle_alert_nagios_title = "Send Alerts To Nagios",
      toggle_alert_nagios_description = "Enable sending ntopng alerts to Nagios NSCA (Nagios Service Check Acceptor).",
      nagios_nsca_host_title = "Nagios NSCA Host",
      nagios_nsca_host_description = "Address of the host where the Nagios NSCA daemon is running. Default: localhost.",
      nagios_nsca_port_title = "Nagios NSCA Port",
      nagios_nsca_port_description = "Port where the Nagios daemon's NSCA is listening. Default: 5667.",
      nagios_send_nsca_executable_title = "Nagios send_nsca executable",
      nagios_send_nsca_executable_description = "Absolute path to the Nagios NSCA send_nsca utility. Default: /usr/local/nagios/bin/send_nsca",
      nagios_send_nsca_config_title = "Nagios send_nsca configuration",
      nagios_send_nsca_config_description = "Absolute path to the Nagios NSCA send_nsca utility configuration file. Default: /usr/local/nagios/etc/send_nsca.cfg",
      nagios_host_name_title = "Nagios host_name",
      nagios_host_name_description = "The host_name exactly as specified in Nagios host definition for the ntopng host. Default: ntopng-host",
      nagios_service_name_title = "Nagios service_description",
      nagios_service_name_description = "The service description exactly as specified in Nagios passive service definition for the ntopng host. Default: NtopngAlert",
      toggle_top_sites_title = "Top HTTP Sites",
      toggle_top_sites_description = "Toggle the creation of top visited web sites for local hosts. Top sites are created using an <a href=\"%{url}\">heuristic</a> that maintain no more than 20 sites per local host. The heuristic fully operates in memory and does not require any interaction with the disk. Top sites are cleared every 5 minutes. An historical archive of top visited web sites can be created, for each local host, by periodically polling the JSON <i class=\"fa fa-download fa-sm\"></i>download link accessible from the host details page.",
      logging = "Logging",
      toggle_logging_level_title = "Log level",
      toggle_logging_level_description = "Choose the runtime logging level.",
      toggle_access_log_title = "Enable HTTP Access Log",
      toggle_access_log_description = "Toggle the creation of HTTP access log in the data dump directory. Settings will have effect at next ntop startup.",
      tiny_flows = "Tiny Flows Dump",
      toggle_flow_db_dump_export_title = "Tiny Flows Export",
      toggle_flow_db_dump_export_description = "Toggle the export of tiny flows, that are flows with few packets or bytes."..
            "Reducing flow cardinality in databases, speeds-up insert and searched. Tuning tiny flows can help to limit flow cardinality while not reducing visibility on dumped information.",
      max_num_packets_per_tiny_flow_title = "Maximum Number of Packets per Tiny Flow",
      max_num_packets_per_tiny_flow_description = "The maximum number of packets a flow must have to be considered a tiny flow. Default: 3.",
      max_num_bytes_per_tiny_flow_title = "Maximum Number of Bytes per Tiny Flow",
      max_num_bytes_per_tiny_flow_description = "The maximum number of bytes a flow must have to be considered a tiny flow. Default: 64.",
      toggle_snmp_rrds_title = "SNMP Devices Timeseries",
      toggle_snmp_rrds_description = "Toggle the creation of bytes timeseries for each port of the SNMP devices. For each device port" ..
	 " will be created an RRD with ingress/egress bytes.",
      default_snmp_community_title = "Default SNMP Community",
      default_snmp_community_description = "The default SNMP community is used when trying to walk the SNMP MIB of a selected local host that has not been configured through the SNMP devices page.",
      nbox_integration = "nBox Integration",
      toggle_nbox_integration_title = "Enable nBox Support",
      toggle_nbox_integration_description = "Enable sending ntopng requests (e.g., to download pcap files) to an nBox. Pcap requests are issued "..
            "from the historical data browser when browsing 'Talkers' and 'Protocols'. Each request carry information on the search criteria "..
            "generated by the user when drilling-down historical data. Requests are queued and pcaps become available for download from a dedicated 'Pcaps' tab once generated.",
      nbox_user_title = "nBox User",
      nbox_user_description = "User that has privileges to access the nBox. Default: nbox",
      nbox_password_title = "nBox Password",
      nbox_password_description = "Password associated to the nBox user. Default: nbox",
      web_user_interface = "Web User Interface",
      toggle_autologout_title = "Auto Logout",
      toggle_autologout_description = "Toggle the automatic logout of web interface users with expired sessions.",
      google_apis_browser_key_title = "Google APIs Browser Key",
      google_apis_browser_key_description = "Graphical hosts geomaps are based on Google Maps APIs. Google recently changed Maps API access policies "..
            "and now requires a browser API key to be submitted for every request. Detailed information on how to obtain an API key "..
            "<a href=\"%{url}\">can be found here</a>. "..
            "Once obtained, the API key can be placed in this field.",
      report_units = "Report Units",
      toggle_thpt_content_title = "Throughput Unit",
      toggle_thpt_content_description = "Select the throughput unit to be displayed in traffic reports.",
      traffic_shaping = "Traffic Shaping",
      toggle_shaping_directions_title = "Split Shaping Directions",
      toggle_shaping_directions_description = "Enable this option to be able to set different shaping policies for ingress and egress traffic.",
      toggle_captive_portal_title = "Captive Portal",
      toggle_captive_portal_description = "Enable the web captive portal for authenticating network users.",
      captive_portal_disabled_message = "This button is <b>disabled</b> as the ntopng web GUI has NOT been started on port 80 that is required by the captive portal (-w command line parameter, e.g. -w 80,3000).",
      bind_dn_title = "LDAP Bind DN",
      bind_dn_description = "Bind Distinguished Name of LDAP server. Example:",
      bind_pwd_title = "LDAP Bind Authentication Password",
      bind_pwd_description = "Bind password used for authenticating with the LDAP server.",
      search_path_title = "LDAP Search Path",
      search_path_description = "Root path used to search the users.",
      user_group_title = "LDAP User Group",
      user_group_description = "Group name to which user has to belong in order to authenticate as unprivileged user.",
      admin_group_title = "LDAP Admin Group",
      admin_group_description = "Group name to which user has to belong in order to authenticate as an administrator.",
      toggle_ldap_anonymous_bind_title = "LDAP Anonymous Binding",
      toggle_ldap_anonymous_bind_description = "Enable anonymous binding.",
      slack_notification_severity_preference_title = "Notification Preference Based On Severity",
      slack_notification_severity_preference_description = "Errors (errors only), Errors and Warnings (errors and warnings, no info), All (every kind of alerts will be notified).",
      ingress_flow_interface = "Ingress Flow Interface",
      probe_ip_address = "Probe IP Address",
      none = "None",
      errors = "Errors",
      errors_and_warnings = "Errors and Warnings",
      all = "All",
      ldap = "LDAP",
      ["local"] = "Local",
      ldap_local = "LDAP/Local",
      posix = "Posix",
      samaccount = "sAMAccount",
      host_mask = "Mask Host IP Addresses",
      toggle_host_mask_title = "Mask Host IP Addresses",
      toggle_host_mask_description = "For privacy reasons it might be necessary to mask hosts IP addresses. For instance if you are an ISP you are not supposed to know what local addresses are accessing rmote hosts.",
      no_host_mask = "Don't Mask Hosts",
      local_host_mask = "Mask Local Hosts",
      remote_host_mask = "Mask Remote Hosts",      
   },

   noTraffic = "No traffic has been reported for the specified date/time selection",
   error_rrd_low_resolution = "You are asking to fetch data at lower resolution than the one available on RRD, which will lead to invalid data."..
      "<br>If you still want data with such granularity, please tune <a href=\"%{prefs}\">Protocol/Networks Timeseries</a> preferences",
   error_no_search_results = "No results found. Please modify your search criteria.";
   enterpriseOnly = "This feature is only available in the ntopng enterprise edition",

   uploaders = "Upload Volume",
   downloaders = "Download Volume",
   unknowers =  "Unknown Traffic Volume",
   incomingflows = "Incoming Flows Count",
   outgoingflows = "Outgoing Flows Count",

   flow_search_criteria = "Flow Search Criteria",
   flow_search_results = "Flow Search Results",
   summary = "Summary",
   date_from = "Begin Date/Time:",
   date_to    = "End Date/Time:"

}

return {en = en}
