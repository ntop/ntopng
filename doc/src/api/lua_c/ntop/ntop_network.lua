--! @brief Performs an HTTP GET request to the specified URL.
--! @param url the URL to fetch.
--! @param username for HTTP authentication.
--! @param password the password for HTTP authentication.
--! @param timeout maximum connection timeout in seconds.
--! @param return_content enable sending response content back to the caller.
--! @param cookie_auth Use basic (default) or cookie (used by ntopng) authentication
--! @return table (RESPONSE_CODE, CONTENT_TYPE, EFFECTIVE_URL), with additional CONTENT and CONTENT_LEN if return_content is enabled on success, nil otherwise.
function ntop.httpGet(string url, string username=nil, string password=nil, int timeout=nil, bool return_content=false, bool cookie_auth=false)

--! @brief Send an HTTP POST request with url encoded data.
--! @param url the target URL.
--! @param data the url encoded data to send.
--! @param username for HTTP authentication.
--! @param password for HTTP authentication.
--! @param timeout maximum connection timeout in seconds.
--! @param return_content enable sending response content back to the caller.
--! @param cookie_auth Use basic (default) or cookie (used by ntopng) authentication
--! @return table (RESPONSE_CODE, CONTENT_TYPE, EFFECTIVE_URL), with additional CONTENT and CONTENT_LEN if return_content is enabled on success, nil otherwise.
function ntop.httpPost(string url, string data, string username=nil, string password=nil, int timeout=nil, bool return_content=false, bool cookie_auth=false)

--! @brief Send an HTTP POST request with json content.
--! @param username for HTTP authentication. Pass empty string to disable authentication.
--! @param password for HTTP authentication. Pass empty string to disable authentication.
--! @param url the target URL.
--! @param json the data to post.
--! @return true on success, false otherwise.
--! @note HTTP header "Content-Type: application/json" is sent.
function ntop.postHTTPJsonData(string username, string password, string url, string json)

--! @brief Send raw UDP data to a given host and port.
--! @param host the host IP address.
--! @param port the host port.
--! @param data the data to send.
function ntop.send_udp_data(string host, int port, string data)

--! @brief This is the equivalent C inet_ntoa for Lua.
--! @param numeric_ip the numeric IP address to convert.
--! @return the symbolic IP address.
function ntop.inet_ntoa(int numeric_ip)

--! @brief Apply a netmask to the specified IP address.
--! @param address the IP address.
--! @param netmask the network mask to apply.
--! @return the masked IP address.
function ntop.networkPrefix(string address, int netmask)

--! @brief Send an HTTP redirection header to the specified URL.
--! @param url the URL to redirect to.
--! @note this must be called before sending any other HTTP data.
function ntop.httpRedirect(string url)

--! @brief Purify a string from the HTTP standpoint. Used to purify HTTP params
--! @param str the string to purify
--! @note The ourigied inout string with _ that replaced chars not allowed
function ntop.httpPurifyParam(string str)

--! @brief A wrapper for C getservbyport.
--! @param port service port.
--! @param proto service protocol, e.g. "tcp".
--! @return getservbyport result on success, the port value on failure.
function ntop.getservbyport(int port, string proto)

--! @brief Send an ICMP request to the given host.
--! @param host the host name/IP address.
--! @param is_v6 true for IPv6 connections, false for IPv4.
--! @note this can be called multiple times on different hosts and then ntop.collectPingResults() can be used to collect the results.
function ntop.pingHost(string host, bool is_v6)

--! @brief Collect the ICMP replies after ntop.pingHost() calles.
--! @return a table with IP address -> RTT mappings
function ntop.collectPingResults()

--! @brief Send an email to the specified address.
--! @param from sender email and name
--! @param to recipient email and name
--! @param msg the message to send
--! @param smtp_server the SMTP server address (e.g. smtp://myserver.com)
--! @param username an optional username for the SMTP authentication
--! @param password an optional password for the SMTP authentication
--! @return true on success, false otherwise
function ntop.sendMail(string from, string to, string msg, string smtp_server, string username=nil, string password=nil)

--! @brief Resolve the given IP into an host name
--! @param ip the host IP
--! @return the resolved host on success, nil otherwise.
--! @note this call is blocking. Use getResolvedAddress() for a non blocking approach.
function ntop.resolveHost(string ip)

--! @brief Perform an SNMP GET request.
--! @param agent_host the target SNMP host
--! @param community the SNMP community
--! @param oid the OID to query
--! @param timeout maximum seconds before aborting the request
--! @param version the SNMP version to use
--! @param oids additional OIDs to query
--! @return a table with the results on success, nil otherwise
function ntop.snmpget(string agent_host, string community, string oid, int timeout=5, int version=1, string oids)

--! @brief Perform an SNMP GETNEXT request.
--! @param agent_host the target SNMP host
--! @param community the SNMP community
--! @param oid the OID to query
--! @param timeout maximum seconds before aborting the request
--! @param version the SNMP version to use
--! @param oids additional OIDs to query
--! @return a table with the results on success, nil otherwise
function ntop.snmpgetnext(string agent_host, string community, string oid, int timeout=5, int version=1, string oids)

--! @brief Send a TCP probe and get the returned banner string.
--! @param server_ip the server IP address
--! @param server_port the TCP service port
--! @param timeout maximum timeout for the operation
--! @return the banner string on success, nil otherwise.
function ntop.tcpProbe(string server_ip, int server_port=5, int timeout=3)

--! @brief Check if the given address is an IPv6 address
--! @param addr the IP address to check
--! @return true if the addtess is a valid IPv6 address, false otherwise.
function ntop.isIPv6(string addr)
