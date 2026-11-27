---
title: "ClickHouse DB Schema"
description: "Here the full list schema available for ClickHouse; Four columns are shown in the below table:"
outline: [2, 3]
lastUpdated: 2026-09-14T17:03:47+02:00
---
# ClickHouse DB Schema {#clickhouse-db-schema}

Here the full list schema available for ClickHouse;
Four columns are shown in the below table:
\- Field: field used when doing queries on the DB
\- Readable Name: Which information the column contains in a human readable format
\- Type: Value data type
\- Description: Description of the data

The list of protocols and alert categories can be found below the table.

Flows table description:

The list of the Layer 7 protocols can be found [here](https://github.com/ntop/nDPI/blob/dev/src/include/ndpi_protocol_ids.h)

The list of the Layer 4 protocols can be found&#32;

An updated list of Application Categories can be found [here](https://github.com/ntop/nDPI/blob/dev/src/include/ndpi_typedefs.h)

| ID  | Category           |
| --- | ------------------ |
| 0   | Unspecified        |
| 1   | Media              |
| 2   | VPN                |
| 3   | Mail               |
| 4   | Data Transfer      |
| 5   | Web                |
| 7   | Social Network     |
| 8   | Download FT        |
| 9   | Game               |
| 10  | Chat               |
| 11  | VoIP               |
| 12  | Database           |
| 13  | Remote Access      |
| 14  | Cloud              |
| 16  | Network            |
| 17  | Collaborative      |
| 18  | RPC                |
| 19  | Streaming          |
| 20  | System OS          |
| 21  | Software Update    |
| 22  | Custom Category 1  |
| 23  | Custom Category 2  |
| 24  | Custom Category 3  |
| 25  | Custom Category 4  |
| 26  | Custom Category 5  |
| 27  | Music              |
| 28  | Video              |
| 29  | Shopping           |
| 30  | Productivity       |
| 31  | File Sharing       |
| 32  | Connectivity Check |
| 33  | IOT SCADA          |
| 34  | Virtual Assistant  |
| 35  | Cybersecurity      |
| 36  | Adult Content      |
| 99  | Mining             |
| 100 | Malware            |
| 101 | Advertisement      |
| 102 | Banned Site        |
| 103 | Site Unavailable   |
| 104 | Allowed Site       |
| 105 | AntiMalware        |
| 106 | Crypt Currency     |
| 107 | Gambling           |
| 108 | Health             |

The list of Alerts Category Available:

| ID  | Alert Category          |
| --- | ----------------------- |
| 0   | Interface Alert         |
| 1   | Host Alert              |
| 2   | Network Alert           |
| 3   | SNMP Alert              |
| 4   | Flow Alert              |
| 5   | MAC Alert               |
| 7   | User Alert              |
| 8   | Active Monitoring Alert |
| 9   | System Alert            |
| 15  | Other Alert             |

The list of Alert Severities:

| ID  | Alert Severity |
| --- | -------------- |
| 0   | None           |
| 1   | Debug          |
| 2   | Info           |
| 3   | Notice         |
| 4   | Warning        |
| 5   | Error          |
| 7   | Critical       |
| 8   | Emergency      |

Active monitoring description:

| Field             | Readable Name        | Type     | Description                                                                               |
| ----------------- | -------------------- | -------- | ----------------------------------------------------------------------------------------- |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                                               |
| alert_id          | Alert ID             | UInt32   | Unique identifier for each alert                                                          |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                                               |
| interface_id      | Interface ID         | UInt16   | Identifier of the network interface associated with the alert (nullable)                  |
| resolved_ip       | Resolved IP          | String   | IP address associated with the alert, if resolved                                         |
| resolved_name     | Resolved Name        | String   | Hostname associated with the alert, if resolved                                           |
| measurement       | Measurement          | String   | Type or name of the measurement that triggered the alert                                  |
| measure_threshold | Measure Threshold    | UInt32   | Threshold value that triggered the alert (nullable)                                       |
| measure_value     | Measure Value        | REAL     | Actual measured value that triggered the alert (nullable)                                 |
| tstamp            | Timestamp            | DateTime | Time when the alert was created or detected                                               |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert was resolved or ended (nullable)                                      |
| severity          | Severity             | UInt8    | Severity level of the alert                                                               |
| score             | Score                | UInt16   | Numerical score associated with the alert, possibly indicating its importance or priority |
| counter           | Counter              | UInt32   | Counter value, possibly indicating the number of times this alert has occurred            |
| description       | Description          | String   | Textual description of the alert                                                          |
| json              | JSON                 | String   | JSON-formatted additional data or full representation of the alert                        |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                                  |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified (nullable)                                |
| alert_category    | Alert Category       | UInt8    | Category of the alert, added in an ALTER TABLE statement                                  |

Flow alerts description:

| Field             | Readable Name          | Type     | Description                                                                        |
| ----------------- | ---------------------- | -------- | ---------------------------------------------------------------------------------- |
| rowid             | Row ID                 | UUID     | Unique identifier for each row in the table                                        |
| alert_id          | Alert ID               | UInt32   | Unique identifier for each alert                                                   |
| alert_status      | Alert Status           | UInt8    | Current status of the alert                                                        |
| interface_id      | Interface ID           | UInt16   | Identifier of the network interface associated with the alert (nullable)           |
| tstamp            | Timestamp              | DateTime | Time when the alert was created                                                    |
| tstamp_end        | End Timestamp          | DateTime | Time when the alert has ended                                                      |
| severity          | Severity               | UInt8    | Severity level of the alert (See the Alert Severities table above)                 |
| score             | Score                  | UInt16   | Numerical score associated with the alert                                          |
| counter           | Counter                | UInt32   | Counter value, indicating the number of times this alert has occurred              |
| json              | JSON                   | String   | JSON-formatted additional data or full representation of the alert                 |
| ip_version        | IP Version             | UInt8    | Version of IP protocol used (4 or 6)                                               |
| cli_ip            | Client IP              | String   | IP address of the client                                                           |
| srv_ip            | Server IP              | String   | IP address of the server                                                           |
| cli_port          | Client Port            | UInt16   | Port number used by the client                                                     |
| srv_port          | Server Port            | UInt16   | Port number used by the server                                                     |
| vlan_id           | VLAN ID                | UInt16   | VLAN identifier                                                                    |
| is_cli_attacker   | Is Client Attacker     | UInt8    | Flag indicating if the client is classified as an attacker                         |
| is_cli_victim     | Is Client Victim       | UInt8    | Flag indicating if the client is classified as a victim                            |
| is_srv_attacker   | Is Server Attacker     | UInt8    | Flag indicating if the server is classified as an attacker                         |
| is_srv_victim     | Is Server Victim       | UInt8    | Flag indicating if the server is classified as a victim                            |
| proto             | Protocol               | UInt8    | IP protocol number (A list of L4 Protocols can be found above)                     |
| l7_proto          | L7 Protocol            | UInt16   | Layer 7 protocol identifier                                                        |
| l7_master_proto   | L7 Master Protocol     | UInt16   | Master Layer 7 protocol identifier                                                 |
| l7_cat            | L7 Category            | UInt16   | Category of Layer 7 protocol (A list of Application Categories can be found above) |
| cli_name          | Client Name            | String   | Name or hostname of the client                                                     |
| srv_name          | Server Name            | String   | Name or hostname of the server                                                     |
| cli_country       | Client Country         | String   | Country of the client                                                              |
| srv_country       | Server Country         | String   | Country of the server                                                              |
| cli_blacklisted   | Client Blacklisted     | UInt8    | Flag indicating if the client is blacklisted                                       |
| srv_blacklisted   | Server Blacklisted     | UInt8    | Flag indicating if the server is blacklisted                                       |
| cli2srv_bytes     | Client to Server Bytes | UInt8    | Number of bytes transferred from client to server                                  |
| srv2cli_bytes     | Server to Client Bytes | UInt8    | Number of bytes transferred from server to client                                  |
| cli2srv_pkts      | Client to Server Pkts  | UInt8    | Number of packets transferred from client to server                                |
| srv2cli_pkts      | Server to Client Pkts  | UInt8    | Number of packets transferred from server to client                                |
| first_seen        | First Seen             | DateTime | Timestamp when the flow was first observed                                         |
| community_id      | Community ID           | String   | Community identifier for the flow                                                  |
| alerts_map        | Alerts Map             | String   | HEX bitmap of all flow statuses                                                    |
| flow_risk_bitmap  | Flow Risk Bitmap       | UInt64   | Bitmap representing risk factors associated with the flow                          |
| user_label        | User Label             | String   | Custom label assigned by a user when silencing the alert                           |
| user_label_tstamp | User Label Timestamp   | DateTime | Timestamp when the user label was last modified                                    |
| cli_host_pool_id  | Client Host Pool ID    | UInt16   | Host pool identifier for the client                                                |
| srv_host_pool_id  | Server Host Pool ID    | UInt16   | Host pool identifier for the server                                                |
| cli_network       | Client Network         | UInt16   | Network identifier for the client                                                  |
| srv_network       | Server Network         | UInt16   | Network identifier for the server                                                  |
| info              | Info                   | String   | Additional information about the flow alert                                        |
| cli_location      | Client Location        | UInt8    | Location identifier for the client                                                 |
| srv_location      | Server Location        | UInt8    | Location identifier for the server                                                 |
| probe_ip          | Probe IP               | String   | IP address of the probe that detected the flow                                     |
| input_snmp        | Input SNMP             | UInt32   | SNMP interface index for input                                                     |
| output_snmp       | Output SNMP            | UInt32   | SNMP interface index for output                                                    |
| alert_category    | Alert Category         | UInt8    | Category of the alert                                                              |

Host alerts description:

| Field             | Readable Name        | Type     | Description                                                                    |
| ----------------- | -------------------- | -------- | ------------------------------------------------------------------------------ |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                                    |
| alert_id          | Alert ID             | UInt32   | Identifier for each alert                                                      |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                                    |
| interface_id      | Interface ID         | UInt16   | Identifier of the network interface associated with the alert (nullable)       |
| ip_version        | IP Version           | UInt8    | Version of IP protocol used (4 or 6)                                           |
| ip                | IP Address           | String   | IP address of the alerted host                                                 |
| vlan_id           | VLAN ID              | UInt16   | VLAN identifier                                                                |
| name              | Host Name            | String   | Name or hostname of the host                                                   |
| is_attacker       | Is Attacker          | UInt8    | Flag indicating if the host is classified as an attacker                       |
| is_victim         | Is Victim            | UInt8    | Flag indicating if the host is classified as a victim                          |
| is_client         | Is Client            | UInt8    | Flag indicating if the host is acting as a client                              |
| is_server         | Is Server            | UInt8    | Flag indicating if the host is acting as a server                              |
| tstamp            | Timestamp            | DateTime | Time when the alert was created                                                |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert has ended                                                  |
| severity          | Severity             | UInt8    | Severity level of the alert                                                    |
| score             | Score                | UInt16   | Numerical score associated with the alert                                      |
| granularity       | Granularity          | UInt8    | Frequency of alert check execution                                             |
| counter           | Counter              | UInt32   | Counter value, possibly indicating the number of times this alert has occurred |
| description       | Description          | String   | Textual description of the alert                                               |
| json              | JSON                 | String   | JSON-formatted additional data or full representation of the alert             |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                       |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified                                |
| host_pool_id      | Host Pool ID         | UInt16   | Identifier for the pool of hosts this host belongs to                          |
| network           | Network ID           | UInt16   | Identifier for the network this host belongs to                                |
| country           | Country              | String   | Country associated with the host's IP address                                  |
| alert_category    | Alert Category       | UInt8    | Category of the alert                                                          |

Mac address alerts description:

| Field             | Readable Name        | Type     | Description                                                                    |
| ----------------- | -------------------- | -------- | ------------------------------------------------------------------------------ |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                                    |
| alert_id          | Alert ID             | UInt32   | Identifier for each alert                                                      |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                                    |
| interface_id      | Interface ID         | UInt16   | Identifier of the network interface associated with the alert (nullable)       |
| address           | MAC Address          | String   | MAC address of the device                                                      |
| device_type       | Device Type          | UInt8    | Type of the device (nullable)                                                  |
| name              | Device Name          | String   | Name or hostname of the device                                                 |
| is_attacker       | Is Attacker          | UInt8    | Flag indicating if the device is classified as an attacker                     |
| is_victim         | Is Victim            | UInt8    | Flag indicating if the device is classified as a victim                        |
| tstamp            | Timestamp            | DateTime | Time when the alert was created or detected                                    |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert was resolved or ended                                      |
| severity          | Severity             | UInt8    | Severity level of the alert                                                    |
| score             | Score                | UInt16   | Numerical score associated with the alert                                      |
| granularity       | Granularity          | UInt8    | Frequency of alert check execution                                             |
| counter           | Counter              | UInt32   | Counter value, possibly indicating the number of times this alert has occurred |
| description       | Description          | String   | Textual description of the alert                                               |
| json              | JSON                 | String   | JSON-formatted additional data or full representation of the alert             |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                       |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified                                |
| alert_category    | Alert Category       | UInt8    | Category of the alert                                                          |

SNMP alerts description:

| Field             | Readable Name        | Type     | Description                                                              |
| ----------------- | -------------------- | -------- | ------------------------------------------------------------------------ |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                              |
| alert_id          | Alert ID             | UInt32   | Identifier for each alert                                                |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                              |
| interface_id      | Interface ID         | UInt16   | Identifier of the network interface associated with the alert (nullable) |
| ip                | IP Address           | String   | IP address of the SNMP device                                            |
| port              | Port                 | UInt32   | Port number of the SNMP device                                           |
| name              | Device Name          | String   | Name or hostname of the SNMP device                                      |
| port_name         | Port Name            | String   | Name of the port on the SNMP device                                      |
| tstamp            | Timestamp            | DateTime | Time when the alert was created or detected                              |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert was resolved or ended                                |
| severity          | Severity             | UInt8    | Severity level of the alert                                              |
| score             | Score                | UInt16   | Numerical score associated with the alert                                |
| granularity       | Granularity          | UInt8    | Frequency of alert check execution                                       |
| counter           | Counter              | UInt32   | Counter value, indicating the number of times this alert has occurred    |
| description       | Description          | String   | Textual description of the alert                                         |
| json              | JSON                 | String   | JSON-formatted additional data for this alert                            |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                 |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified                          |
| alert_category    | Alert Category       | UInt8    | Category of the alert                                                    |

Network alerts description:

| Field             | Readable Name        | Type     | Description                                                                    |
| ----------------- | -------------------- | -------- | ------------------------------------------------------------------------------ |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                                    |
| local_network_id  | Local Network ID     | UInt16   | Identifier for the local network associated with the alert                     |
| alert_id          | Alert ID             | UInt32   | Identifier for each alert                                                      |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                                    |
| interface_id      | Interface ID         | UInt16   | Identifier of the network interface associated with the alert (nullable)       |
| name              | Network Name         | String   | Name of the network                                                            |
| alias             | Network Alias        | String   | Alias or alternative name for the network                                      |
| tstamp            | Timestamp            | DateTime | Time when the alert was created or detected                                    |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert was resolved or ended                                      |
| severity          | Severity             | UInt8    | Severity level of the alert                                                    |
| score             | Score                | UInt16   | Numerical score associated with the alert                                      |
| granularity       | Granularity          | UInt8    | Frequency of alert check execution                                             |
| counter           | Counter              | UInt32   | Counter value, possibly indicating the number of times this alert has occurred |
| description       | Description          | String   | Textual description of the alert                                               |
| json              | JSON                 | String   | JSON-formatted additional data or full representation of the alert             |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                       |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified                                |
| alert_category    | Alert Category       | UInt8    | Category of the alert                                                          |

Interface alerts description:

| Field             | Readable Name        | Type     | Description                                                                         |
| ----------------- | -------------------- | -------- | ----------------------------------------------------------------------------------- |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                                         |
| ifid              | Interface ID         | UInt8    | Identifier for the network interface                                                |
| alert_id          | Alert ID             | UInt32   | Identifier for each alert                                                           |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                                         |
| interface_id      | Interface ID         | UInt16   | Additional identifier of the network interface associated with the alert (nullable) |
| subtype           | Alert Subtype        | String   | Subtype of alert_id                                                                 |
| name              | Interface Name       | String   | Name of the network interface                                                       |
| alias             | Interface Alias      | String   | Alias or alternative name for the interface                                         |
| tstamp            | Timestamp            | DateTime | Time when the alert was created or detected                                         |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert was resolved or ended                                           |
| severity          | Severity             | UInt8    | Severity level of the alert                                                         |
| score             | Score                | UInt16   | Numerical score associated with the alert                                           |
| granularity       | Granularity          | UInt8    | Frequency of alert check execution                                                  |
| counter           | Counter              | UInt32   | Counter value, possibly indicating the number of times this alert has occurred      |
| description       | Description          | String   | Textual description of the alert                                                    |
| json              | JSON                 | String   | JSON-formatted additional data or full representation of the alert                  |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                            |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified                                     |
| alert_category    | Alert Category       | UInt8    | Category of the alert                                                               |

User alerts description:

| Field             | Readable Name        | Type     | Description                                                                    |
| ----------------- | -------------------- | -------- | ------------------------------------------------------------------------------ |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                                    |
| alert_id          | Alert ID             | UInt32   | Identifier for each alert                                                      |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                                    |
| interface_id      | Interface ID         | UInt16   | Identifier of the network interface associated with the alert (nullable)       |
| user              | User                 | String   | Username or identifier of the user associated with the alert                   |
| tstamp            | Timestamp            | DateTime | Time when the alert was created or detected                                    |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert was resolved or ended                                      |
| severity          | Severity             | UInt8    | Severity level of the alert                                                    |
| score             | Score                | UInt16   | Numerical score associated with the alert                                      |
| granularity       | Granularity          | UInt8    | Frequency of alert check execution                                             |
| counter           | Counter              | UInt32   | Counter value, possibly indicating the number of times this alert has occurred |
| description       | Description          | String   | Textual description of the alert                                               |
| json              | JSON                 | String   | JSON-formatted additional data or full representation of the alert             |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                       |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified                                |
| alert_category    | Alert Category       | UInt8    | Category of the alert                                                          |

System alerts description:

| Field             | Readable Name        | Type     | Description                                                              |
| ----------------- | -------------------- | -------- | ------------------------------------------------------------------------ |
| rowid             | Row ID               | UUID     | Unique identifier for each row in the table                              |
| alert_id          | Alert ID             | UInt32   | Identifier for each alert                                                |
| alert_status      | Alert Status         | UInt8    | Current status of the alert                                              |
| interface_id      | Interface ID         | UInt16   | Identifier of the network interface associated with the alert (nullable) |
| name              | System Name          | String   | Name or identifier of the system associated with the alert               |
| tstamp            | Timestamp            | DateTime | Time when the alert was created or detected                              |
| tstamp_end        | End Timestamp        | DateTime | Time when the alert was resolved or ended                                |
| severity          | Severity             | UInt8    | Severity level of the alert                                              |
| score             | Score                | UInt16   | Numerical score associated with the alert                                |
| granularity       | Granularity          | UInt8    | Frequency of alert check execution                                       |
| counter           | Counter              | UInt32   | Counter value, indicating the number of times this alert has occurred    |
| description       | Description          | String   | Textual description of the alert                                         |
| json              | JSON                 | String   | JSON-formatted additional data                                           |
| user_label        | User Label           | String   | Custom label assigned by a user when silencing the alert                 |
| user_label_tstamp | User Label Timestamp | DateTime | Timestamp when the user label was last modified                          |
| alert_category    | Alert Category       | UInt8    | Category of the alert                                                    |

Vulnerability scan data:

| Field          | Readable Name    | Type     | Description                                                         |
| -------------- | ---------------- | -------- | ------------------------------------------------------------------- |
| HOST           | Host             | String   | The hostname or identifier of the scanned host                      |
| SCAN_TYPE      | Scan Type        | String   | The type or method of vulnerability scan performed                  |
| LAST_SCAN      | Last Scan Time   | DateTime | The timestamp of when the last scan was performed                   |
| JSON_INFO      | JSON Information | String   | Additional information about the scan in JSON format                |
| VS_RESULT_FILE | Result File Path | String   | The file path or identifier for the full vulnerability scan results |
