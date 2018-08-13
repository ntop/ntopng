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

--! @brief Send an HTTP POST request with a file contents.
--! @param username for HTTP authentication. Pass empty string to disable authentication.
--! @param password for HTTP authentication. Pass empty string to disable authentication.
--! @param url the target URL.
--! @param path the source file path.
--! @param delete_file_after_post if true, source file is deleted after a successful POST.
--! @param timeout maximum connection timeout in seconds.
--! @return true on success, nil otherwise.
--! @note HTTP header "Content-Type: text/plain; charset=utf-8" is sent.
function ntop.postHTTPTextFile(string username, string password, string url, string path, bool delete_file_after_post=false, int timeout=nil)

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

--! @brief A wrapper for C getservbyport.
--! @param port service port.
--! @param proto service protocol, e.g. "tcp".
--! @return getservbyport result on success, the port value on failure.
function ntop.getservbyport(int port, string proto)
