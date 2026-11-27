---
title: "Network API"
description: "The Network API provides utility functions to deal with IP addresses and send HTTP requests."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Network API {#network-api}

The Network API provides utility functions to deal with IP addresses and send HTTP requests.

### `ntop.httpGet(string url, string username=nil, string password=nil, int timeout=nil, bool return_content=false, bool cookie_auth=false)` {#ntop-httpget}

Performs an HTTP GET request to the specified URL.

**Parameters**

- `url`: the URL to fetch.
- `username`: for HTTP authentication.
- `password`: the password for HTTP authentication.
- `timeout`: maximum connection timeout in seconds.
- `return_content`: enable sending response content back to the caller.
- `cookie_auth`: Use basic (default) or cookie (used by ntopng) authentication

**Returns**: table (RESPONSE_CODE, CONTENT_TYPE, EFFECTIVE_URL), with additional CONTENT and CONTENT_LEN if return_content is enabled on success, nil otherwise.

### `ntop.httpPost(string url, string data, table params=nil)` {#ntop-httppost}

Send an HTTP POST request.

**Parameters**

- `url`: the target URL.
- `data`: the request body to send.
- `params`: optional table with the following fields: username (string, optional): HTTP basic auth username.
- `username`: (string, optional): HTTP basic auth username. password (string, optional): HTTP basic auth password.
- `password`: (string, optional): HTTP basic auth password. timeout (number, optional): connection timeout in seconds (default 30).
- `timeout`: (number, optional): connection timeout in seconds (default 30). return_content (boolean, optional): include response body in result (default false).
- `return_content`: (boolean, optional): include response body in result (default false). use_cookie_auth (boolean, optional): use cookie-based auth instead of basic (default false).
- `use_cookie_auth`: (boolean, optional): use cookie-based auth instead of basic (default false). bearer (string, optional): Authorization: Bearer token value.
- `bearer`: (string, optional): Authorization: Bearer token value. x_api_key (string, optional): x-api-key header value.
- `x_api_key`: (string, optional): x-api-key header value. extra_header (string, optional): raw extra header line (e.g. "Foo: bar").
- `extra_header`: (string, optional): raw extra header line (e.g. "Foo: bar").

**Returns**: table (RESPONSE_CODE, CONTENT_TYPE, EFFECTIVE_URL), with additional CONTENT and CONTENT_LEN if return_content is enabled on success, nil otherwise.

### `ntop.postHTTPJsonData(string username, string password, string url, string json)` {#ntop-posthttpjsondata}

Send an HTTP POST request with json content.

**Parameters**

- `username`: for HTTP authentication. Pass empty string to disable authentication.
- `password`: for HTTP authentication. Pass empty string to disable authentication.
- `url`: the target URL.
- `json`: the data to post.

**Returns**: true on success, false otherwise.

::: info
HTTP header "Content-Type: application/json" is sent.
:::

### `ntop.send_udp_data(string host, int port, string data)` {#ntop-send-udp-data}

Send raw UDP data to a given host and port.

**Parameters**

- `host`: the host IP address.
- `port`: the host port.
- `data`: the data to send.

### `ntop.inet_ntoa(int numeric_ip)` {#ntop-inet-ntoa}

This is the equivalent C inet_ntoa for Lua.

**Parameters**

- `numeric_ip`: the numeric IP address to convert.

**Returns**: the symbolic IP address.

### `ntop.networkPrefix(string address, int netmask)` {#ntop-networkprefix}

Apply a netmask to the specified IP address.

**Parameters**

- `address`: the IP address.
- `netmask`: the network mask to apply.

**Returns**: the masked IP address.

### `ntop.httpRedirect(string url)` {#ntop-httpredirect}

Send an HTTP redirection header to the specified URL.

**Parameters**

- `url`: the URL to redirect to.

::: info
this must be called before sending any other HTTP data.
:::

### `ntop.httpPurifyParam(string str)` {#ntop-httppurifyparam}

Purify a string from the HTTP standpoint. Used to purify HTTP params

**Parameters**

- `str`: the string to purify

::: info
The ourigied inout string with _ that replaced chars not allowed
:::

### `ntop.getservbyport(int port, string proto)` {#ntop-getservbyport}

A wrapper for C getservbyport.

**Parameters**

- `port`: service port.
- `proto`: service protocol, e.g. "tcp".

**Returns**: getservbyport result on success, the port value on failure.

### `ntop.pingHost(string host, bool is_v6)` {#ntop-pinghost}

Send an ICMP request to the given host.

**Parameters**

- `host`: the host name/IP address.
- `is_v6`: true for IPv6 connections, false for IPv4.

::: info
this can be called multiple times on different hosts and then ntop.collectPingResults() can be used to collect the results.
:::

### `ntop.collectPingResults()` {#ntop-collectpingresults}

Collect the ICMP replies after ntop.pingHost() calles.

**Returns**: a table with IP address -> RTT mappings

### `ntop.sendMail(string from, string to, string msg, string smtp_server, string username=nil, string password=nil)` {#ntop-sendmail}

Send an email to the specified address.

**Parameters**

- `from`: sender email and name
- `to`: recipient email and name
- `msg`: the message to send
- `smtp_server`: the SMTP server address (e.g. smtp://myserver.com)
- `username`: an optional username for the SMTP authentication
- `password`: an optional password for the SMTP authentication

**Returns**: true on success, false otherwise

### `ntop.resolveHost(string ip)` {#ntop-resolvehost}

Resolve the given IP into an host name

**Parameters**

- `ip`: the host IP

**Returns**: the resolved host on success, nil otherwise.

::: info
this call is blocking. Use getResolvedAddress() for a non blocking approach.
:::

### `ntop.snmpget(string agent_host, string community, string oid, int timeout=5, int version=1, string oids)` {#ntop-snmpget}

Perform an SNMP GET request.

**Parameters**

- `agent_host`: the target SNMP host
- `community`: the SNMP community
- `oid`: the OID to query
- `timeout`: maximum seconds before aborting the request
- `version`: the SNMP version to use
- `oids`: additional OIDs to query

**Returns**: a table with the results on success, nil otherwise

### `ntop.snmpgetnext(string agent_host, string community, string oid, int timeout=5, int version=1, string oids)` {#ntop-snmpgetnext}

Perform an SNMP GETNEXT request.

**Parameters**

- `agent_host`: the target SNMP host
- `community`: the SNMP community
- `oid`: the OID to query
- `timeout`: maximum seconds before aborting the request
- `version`: the SNMP version to use
- `oids`: additional OIDs to query

**Returns**: a table with the results on success, nil otherwise

### `ntop.tcpProbe(string server_ip, int server_port=5, int timeout=3)` {#ntop-tcpprobe}

Send a TCP probe and get the returned banner string.

**Parameters**

- `server_ip`: the server IP address
- `server_port`: the TCP service port
- `timeout`: maximum timeout for the operation

**Returns**: the banner string on success, nil otherwise.

### `ntop.isIPv6(string addr)` {#ntop-isipv6}

Check if the given address is an IPv6 address

**Parameters**

- `addr`: the IP address to check

**Returns**: true if the addtess is a valid IPv6 address, false otherwise.
