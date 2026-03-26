"""
Unit tests for the ntopng Python SDK.

These tests use unittest.mock to avoid requiring a live ntopng instance,
making them suitable for offline/CI environments.
"""

import sys
import os
import unittest
from unittest.mock import MagicMock, patch, call

# Add the python directory to the path so we can import ntopng modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pandas as pd
from ntopng.ntopng import Ntopng
from ntopng.interface import Interface
from ntopng.host import Host
from ntopng.historical import Historical


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_mock_response(json_data=None, status_code=200, content_type="application/json"):
    """Return a mock requests.Response with the given attributes."""
    mock_resp = MagicMock()
    mock_resp.status_code = status_code
    mock_resp.headers = {"Content-Type": content_type}
    mock_resp.json.return_value = json_data if json_data is not None else {"rc": 0, "rsp": {}}
    return mock_resp


def _make_ntopng(username="admin", password="admin", auth_token=None,
                 url="http://localhost:3000"):
    """
    Construct an Ntopng instance with a mocked connection-test request so
    the constructor does not require a live server.
    """
    connect_response = _make_mock_response({"rc": 0, "rsp": {}})
    with patch("requests.get", return_value=connect_response):
        return Ntopng(username, password, auth_token, url)


# ---------------------------------------------------------------------------
# Ntopng tests
# ---------------------------------------------------------------------------

class TestNtopngInit(unittest.TestCase):
    """Tests for Ntopng.__init__"""

    def test_init_with_username_password(self):
        """Constructor stores username/password and clears auth_token."""
        n = _make_ntopng(username="user", password="pass")
        self.assertEqual(n.username, "user")
        self.assertEqual(n.password, "pass")
        self.assertIsNone(n.auth_token)

    def test_init_with_auth_token(self):
        """Constructor stores auth_token and clears username/password."""
        n = _make_ntopng(auth_token="mytoken123")
        self.assertEqual(n.auth_token, "mytoken123")
        self.assertIsNone(n.username)
        self.assertIsNone(n.password)

    def test_init_stores_url(self):
        """Constructor stores the base URL."""
        n = _make_ntopng(url="http://192.168.1.1:3000")
        self.assertEqual(n.url, "http://192.168.1.1:3000")

    def test_init_raises_on_non_json_content_type(self):
        """Constructor raises ValueError when server returns non-JSON content."""
        bad_response = _make_mock_response(content_type="text/html")
        with patch("requests.get", return_value=bad_response):
            with self.assertRaises(ValueError):
                Ntopng("user", "pass", None, "http://localhost:3000")

    def test_init_raises_on_connection_error(self):
        """Constructor raises ValueError when the server is unreachable."""
        with patch("requests.get", side_effect=Exception("connection refused")):
            with self.assertRaises(ValueError):
                Ntopng("user", "pass", None, "http://localhost:3000")

    def test_debug_default_false(self):
        """debug flag is False by default."""
        n = _make_ntopng()
        self.assertFalse(n.debug)

    def test_enable_debug(self):
        """enable_debug() sets the debug flag."""
        n = _make_ntopng()
        n.enable_debug()
        self.assertTrue(n.debug)


class TestNtopngIssueRequest(unittest.TestCase):
    """Tests for Ntopng.issue_request"""

    def test_uses_token_auth_when_auth_token_set(self):
        """issue_request sends Authorization header when auth_token is configured."""
        n = _make_ntopng(auth_token="tok123")
        resp = _make_mock_response()
        with patch("requests.get", return_value=resp) as mock_get:
            n.issue_request("http://localhost:3000/some/url", {"p": "v"})
            _, kwargs = mock_get.call_args
            self.assertIn("Authorization", kwargs.get("headers", {}))
            self.assertIn("tok123", kwargs["headers"]["Authorization"])
            self.assertIsNone(kwargs.get("auth"))

    def test_uses_basic_auth_when_no_token(self):
        """issue_request uses HTTPBasicAuth when no auth_token is configured."""
        from requests.auth import HTTPBasicAuth
        n = _make_ntopng(username="u", password="p")
        resp = _make_mock_response()
        with patch("requests.get", return_value=resp) as mock_get:
            n.issue_request("http://localhost:3000/some/url", None)
            _, kwargs = mock_get.call_args
            self.assertIsInstance(kwargs.get("auth"), HTTPBasicAuth)

    def test_passes_params(self):
        """issue_request forwards query params to requests.get."""
        n = _make_ntopng()
        resp = _make_mock_response()
        with patch("requests.get", return_value=resp) as mock_get:
            n.issue_request("http://localhost:3000/url", {"key": "val"})
            _, kwargs = mock_get.call_args
            self.assertEqual(kwargs.get("params"), {"key": "val"})


class TestNtopngIssuePostRequest(unittest.TestCase):
    """Tests for Ntopng.issue_post_request"""

    def test_uses_token_auth_when_auth_token_set(self):
        """issue_post_request sends Authorization header when auth_token is set."""
        n = _make_ntopng(auth_token="tok456")
        resp = _make_mock_response()
        with patch("requests.post", return_value=resp) as mock_post:
            n.issue_post_request("http://localhost:3000/some/url", {"data": 1})
            _, kwargs = mock_post.call_args
            self.assertIn("Authorization", kwargs.get("headers", {}))
            self.assertIsNone(kwargs.get("auth"))

    def test_uses_basic_auth_when_no_token(self):
        """issue_post_request uses HTTPBasicAuth when no auth_token is set."""
        from requests.auth import HTTPBasicAuth
        n = _make_ntopng(username="u", password="p")
        resp = _make_mock_response()
        with patch("requests.post", return_value=resp) as mock_post:
            n.issue_post_request("http://localhost:3000/url", {"data": 1})
            _, kwargs = mock_post.call_args
            self.assertIsInstance(kwargs.get("auth"), HTTPBasicAuth)

    def test_sends_json_content_type(self):
        """issue_post_request always includes Content-Type: application/json."""
        n = _make_ntopng()
        resp = _make_mock_response()
        with patch("requests.post", return_value=resp) as mock_post:
            n.issue_post_request("http://localhost:3000/url", {})
            _, kwargs = mock_post.call_args
            self.assertEqual(kwargs["headers"].get("Content-Type"), "application/json")


class TestNtopngRequest(unittest.TestCase):
    """Tests for the high-level Ntopng.request wrapper."""

    def test_returns_rsp_on_success(self):
        """request() extracts and returns response['rsp']."""
        n = _make_ntopng()
        payload = {"rc": 0, "rsp": {"key": "value"}}
        resp = _make_mock_response(json_data=payload)
        with patch("requests.get", return_value=resp):
            result = n.request("/lua/rest/v2/some/endpoint.lua", None)
        self.assertEqual(result, {"key": "value"})

    def test_raises_on_non_200_status(self):
        """request() raises an Exception when the HTTP status is not 200."""
        n = _make_ntopng()
        resp = _make_mock_response(status_code=403)
        with patch("requests.get", return_value=resp):
            with self.assertRaises(Exception):
                n.request("/lua/rest/v2/some/endpoint.lua", None)

    def test_prepends_base_url(self):
        """request() prepends the configured base URL to the path."""
        n = _make_ntopng(url="http://myhost:3000")
        payload = {"rc": 0, "rsp": []}
        resp = _make_mock_response(json_data=payload)
        with patch("requests.get", return_value=resp) as mock_get:
            n.request("/lua/rest/v2/get/ntopng/interfaces.lua", None)
            positional_args, _ = mock_get.call_args
            self.assertTrue(positional_args[0].startswith("http://myhost:3000"))


class TestNtopngPostRequest(unittest.TestCase):
    """Tests for the high-level Ntopng.post_request wrapper."""

    def test_returns_rsp_on_success(self):
        """post_request() extracts and returns response['rsp']."""
        n = _make_ntopng()
        payload = {"rc": 0, "rsp": {"result": 42}}
        resp = _make_mock_response(json_data=payload)
        with patch("requests.post", return_value=resp):
            result = n.post_request("/lua/rest/v2/some/endpoint.lua", {})
        self.assertEqual(result, {"result": 42})

    def test_raises_on_non_200_status(self):
        """post_request() raises an Exception when the HTTP status is not 200."""
        n = _make_ntopng()
        resp = _make_mock_response(status_code=500)
        with patch("requests.post", return_value=resp):
            with self.assertRaises(Exception):
                n.post_request("/lua/rest/v2/some/endpoint.lua", {})


class TestNtopngGetters(unittest.TestCase):
    """Tests for Ntopng data-retrieval methods."""

    def setUp(self):
        self.ntopng = _make_ntopng()

    def _patch_request(self, return_value):
        return patch.object(self.ntopng, "request", return_value=return_value)

    def test_get_alert_types(self):
        """get_alert_types() calls the correct endpoint."""
        with self._patch_request([]) as mock_req:
            result = self.ntopng.get_alert_types()
            mock_req.assert_called_once()
            url_arg = mock_req.call_args[0][0]
            self.assertIn("alert/type/consts", url_arg)
        self.assertEqual(result, [])

    def test_get_alert_severities(self):
        """get_alert_severities() calls the correct endpoint."""
        with self._patch_request([]) as mock_req:
            result = self.ntopng.get_alert_severities()
            url_arg = mock_req.call_args[0][0]
            self.assertIn("alert/severity/consts", url_arg)
        self.assertEqual(result, [])

    def test_get_interfaces_list(self):
        """get_interfaces_list() calls the correct endpoint."""
        expected = [{"id": 0, "name": "eth0"}]
        with self._patch_request(expected) as mock_req:
            result = self.ntopng.get_interfaces_list()
            url_arg = mock_req.call_args[0][0]
            self.assertIn("ntopng/interfaces", url_arg)
        self.assertEqual(result, expected)

    def test_get_host_interfaces_list(self):
        """get_host_interfaces_list() passes host parameter."""
        with self._patch_request([]) as mock_req:
            self.ntopng.get_host_interfaces_list("192.168.1.1")
            _, params = mock_req.call_args[0]
            self.assertEqual(params.get("host"), "192.168.1.1")

    def test_get_interface_returns_interface_instance(self):
        """get_interface() returns an Interface object with the correct ifid."""
        iface = self.ntopng.get_interface(3)
        self.assertIsInstance(iface, Interface)
        self.assertEqual(iface.ifid, 3)

    def test_get_historical_interface_returns_historical_instance(self):
        """get_historical_interface() returns a Historical object with the correct ifid."""
        hist = self.ntopng.get_historical_interface(2)
        self.assertIsInstance(hist, Historical)
        self.assertEqual(hist.ifid, 2)

    def test_get_url(self):
        """get_url() returns the configured base URL."""
        n = _make_ntopng(url="http://example.com:3000")
        self.assertEqual(n.get_url(), "http://example.com:3000")


# ---------------------------------------------------------------------------
# Interface tests
# ---------------------------------------------------------------------------

class TestInterface(unittest.TestCase):
    """Tests for the Interface class."""

    def setUp(self):
        self.ntopng = _make_ntopng()
        self.iface = Interface(self.ntopng, ifid=1)

    def _patch_request(self, return_value):
        return patch.object(self.ntopng, "request", return_value=return_value)

    def test_init_stores_ifid(self):
        self.assertEqual(self.iface.ifid, 1)

    def test_get_data(self):
        """get_data() calls the interface data endpoint with the correct ifid."""
        expected = {"name": "eth0"}
        with self._patch_request(expected) as mock_req:
            result = self.iface.get_data()
            url, params = mock_req.call_args[0]
            self.assertIn("interface/data", url)
            self.assertEqual(params["ifid"], 1)
        self.assertEqual(result, expected)

    def test_get_broadcast_domains(self):
        """get_broadcast_domains() calls the correct endpoint."""
        with self._patch_request({}) as mock_req:
            self.iface.get_broadcast_domains()
            url, _ = mock_req.call_args[0]
            self.assertIn("bcast_domains", url)

    def test_get_address(self):
        """get_address() calls the correct endpoint."""
        with self._patch_request([]) as mock_req:
            self.iface.get_address()
            url, _ = mock_req.call_args[0]
            self.assertIn("interface/address", url)

    def test_get_l7_stats(self):
        """get_l7_stats() calls the correct endpoint with expected parameters."""
        with self._patch_request({}) as mock_req:
            self.iface.get_l7_stats(50)
            url, params = mock_req.call_args[0]
            self.assertIn("l7/stats", url)
            self.assertEqual(params["max_values"], 50)
            self.assertEqual(params["ifid"], 1)

    def test_get_dscp_stats(self):
        """get_dscp_stats() calls the correct endpoint."""
        with self._patch_request({}) as mock_req:
            self.iface.get_dscp_stats()
            url, _ = mock_req.call_args[0]
            self.assertIn("dscp/stats", url)

    def test_get_host_returns_host_instance(self):
        """get_host() returns a Host object with the correct attributes."""
        host = self.iface.get_host("10.0.0.1")
        self.assertIsInstance(host, Host)
        self.assertEqual(host.ip, "10.0.0.1")
        self.assertEqual(host.ifid, 1)

    def test_get_host_with_vlan(self):
        """get_host() passes VLAN ID to the Host instance."""
        host = self.iface.get_host("10.0.0.1", vlan=100)
        self.assertEqual(host.vlan, 100)

    def test_get_active_hosts_paginated(self):
        """get_active_hosts_paginated() passes page parameters."""
        with self._patch_request({"data": []}) as mock_req:
            self.iface.get_active_hosts_paginated(2, 25)
            _, params = mock_req.call_args[0]
            self.assertEqual(params["currentPage"], 2)
            self.assertEqual(params["perPage"], 25)

    def test_get_active_flows_paginated(self):
        """get_active_flows_paginated() calls the flow active endpoint."""
        with self._patch_request({}) as mock_req:
            self.iface.get_active_flows_paginated(1, 100)
            url, params = mock_req.call_args[0]
            self.assertIn("flow/active", url)
            self.assertEqual(params["currentPage"], 1)
            self.assertEqual(params["perPage"], 100)

    def test_get_active_l4_proto_flow_counters(self):
        """get_active_l4_proto_flow_counters() calls the L4 counters endpoint."""
        with self._patch_request({}) as mock_req:
            self.iface.get_active_l4_proto_flow_counters()
            url, _ = mock_req.call_args[0]
            self.assertIn("l4/counters", url)

    def test_get_active_l7_proto_flow_counters(self):
        """get_active_l7_proto_flow_counters() calls the L7 counters endpoint."""
        with self._patch_request({}) as mock_req:
            self.iface.get_active_l7_proto_flow_counters()
            url, _ = mock_req.call_args[0]
            self.assertIn("l7/counters", url)

    def test_get_alert_types_enum(self):
        """get_alert_types_enum() calls the alert type consts endpoint."""
        with self._patch_request([]) as mock_req:
            self.iface.get_alert_types_enum()
            url, _ = mock_req.call_args[0]
            self.assertIn("alert/type/consts", url)

    def test_get_alert_severities_enum(self):
        """get_alert_severities_enum() calls the alert severity consts endpoint."""
        with self._patch_request([]) as mock_req:
            self.iface.get_alert_severities_enum()
            url, _ = mock_req.call_args[0]
            self.assertIn("alert/severity/consts", url)

    def test_get_alerts_counter_per_type(self):
        """get_alerts_counter_per_type() passes the ifid parameter."""
        with self._patch_request({}) as mock_req:
            self.iface.get_alerts_counter_per_type(1)
            url, params = mock_req.call_args[0]
            self.assertIn("alert/type/counters", url)
            self.assertEqual(params["ifid"], 1)

    def test_get_alerts_counter_per_severity(self):
        """get_alerts_counter_per_severity() passes the ifid parameter."""
        with self._patch_request({}) as mock_req:
            self.iface.get_alerts_counter_per_severity(1)
            url, params = mock_req.call_args[0]
            self.assertIn("alert/severity/counters", url)
            self.assertEqual(params["ifid"], 1)

    def test_get_l7_application_proto_enum(self):
        """get_l7_application_proto_enum() calls the L7 application consts endpoint."""
        with self._patch_request([]) as mock_req:
            self.iface.get_l7_application_proto_enum()
            url, _ = mock_req.call_args[0]
            self.assertIn("l7/application/consts", url)

    def test_get_l7_application_category_enum(self):
        """get_l7_application_category_enum() calls the L7 category consts endpoint."""
        with self._patch_request([]) as mock_req:
            self.iface.get_l7_application_category_enum()
            url, _ = mock_req.call_args[0]
            self.assertIn("l7/category/consts", url)

    def test_get_l4_protocols_enum(self):
        """get_l4_protocols_enum() calls the L4 protocol consts endpoint."""
        with self._patch_request([]) as mock_req:
            self.iface.get_l4_protocols_enum()
            url, _ = mock_req.call_args[0]
            self.assertIn("l4/protocol/consts", url)

    def test_get_host_data(self):
        """get_host_data() passes ifid and host_ip parameters."""
        with self._patch_request({}) as mock_req:
            self.iface.get_host_data(1, "10.0.0.5")
            _, params = mock_req.call_args[0]
            self.assertEqual(params["ifid"], 1)
            self.assertEqual(params["host"], "10.0.0.5")

    def test_get_historical_returns_historical_instance(self):
        """get_historical() returns a Historical object linked to the same ifid."""
        hist = self.iface.get_historical()
        self.assertIsInstance(hist, Historical)
        self.assertEqual(hist.ifid, 1)

    def test_get_all_alerts_without_ip(self):
        """get_all_alerts() without IP does not include cli_ip in params."""
        with self._patch_request([]) as mock_req:
            self.iface.get_all_alerts(1, 1000, 2000)
            _, params = mock_req.call_args[0]
            self.assertNotIn("cli_ip", params)
            self.assertEqual(params["epoch_begin"], 1000)
            self.assertEqual(params["epoch_end"], 2000)

    def test_get_all_alerts_with_ip(self):
        """get_all_alerts() with IP includes cli_ip filter in params."""
        with self._patch_request([]) as mock_req:
            self.iface.get_all_alerts(1, 1000, 2000, ip="192.168.1.100")
            _, params = mock_req.call_args[0]
            self.assertIn("192.168.1.100", params["cli_ip"])


# ---------------------------------------------------------------------------
# Host tests
# ---------------------------------------------------------------------------

class TestHost(unittest.TestCase):
    """Tests for the Host class."""

    def setUp(self):
        self.ntopng = _make_ntopng()
        self.host = Host(self.ntopng, ifid=0, ip="10.0.0.1")

    def _patch_request(self, return_value):
        return patch.object(self.ntopng, "request", return_value=return_value)

    def test_init_stores_attributes(self):
        """Constructor stores ntopng_obj, ifid, ip, and vlan."""
        self.assertEqual(self.host.ifid, 0)
        self.assertEqual(self.host.ip, "10.0.0.1")
        self.assertIsNone(self.host.vlan)

    def test_init_with_vlan(self):
        """Constructor stores vlan when provided."""
        host = Host(self.ntopng, ifid=0, ip="10.0.0.1", vlan=200)
        self.assertEqual(host.vlan, 200)

    def test_get_host_data_without_vlan(self):
        """get_host_data() sends ifid and host params; no vlan when None."""
        with self._patch_request({"ip": "10.0.0.1"}) as mock_req:
            result = self.host.get_host_data()
            url, params = mock_req.call_args[0]
            self.assertIn("host/data", url)
            self.assertEqual(params["host"], "10.0.0.1")
            self.assertNotIn("vlan", params)
        self.assertEqual(result, {"ip": "10.0.0.1"})

    def test_get_host_data_with_vlan(self):
        """get_host_data() includes vlan in params when set."""
        host = Host(self.ntopng, ifid=0, ip="10.0.0.1", vlan=100)
        with self._patch_request({}) as mock_req:
            host.get_host_data()
            _, params = mock_req.call_args[0]
            self.assertEqual(params["vlan"], 100)

    def test_get_l7_stats_without_vlan(self):
        """get_l7_stats() sends correct params; no vlan when None."""
        with self._patch_request({}) as mock_req:
            self.host.get_l7_stats()
            url, params = mock_req.call_args[0]
            self.assertIn("l7/stats", url)
            self.assertNotIn("vlan", params)

    def test_get_l7_stats_with_vlan(self):
        """get_l7_stats() includes vlan in params when set."""
        host = Host(self.ntopng, ifid=0, ip="10.0.0.1", vlan=50)
        with self._patch_request({}) as mock_req:
            host.get_l7_stats()
            _, params = mock_req.call_args[0]
            self.assertEqual(params["vlan"], 50)

    def test_get_dscp_stats_received(self):
        """get_dscp_stats(True) sends direction=recvd."""
        with self._patch_request({}) as mock_req:
            self.host.get_dscp_stats(True)
            _, params = mock_req.call_args[0]
            self.assertEqual(params["direction"], "recvd")

    def test_get_dscp_stats_sent(self):
        """get_dscp_stats(False) sends direction=sent."""
        with self._patch_request({}) as mock_req:
            self.host.get_dscp_stats(False)
            _, params = mock_req.call_args[0]
            self.assertEqual(params["direction"], "sent")

    def test_get_dscp_stats_with_vlan(self):
        """get_dscp_stats() includes vlan in params when set."""
        host = Host(self.ntopng, ifid=0, ip="10.0.0.1", vlan=30)
        with self._patch_request({}) as mock_req:
            host.get_dscp_stats(True)
            _, params = mock_req.call_args[0]
            self.assertEqual(params["vlan"], 30)

    def test_get_active_flows_paginated(self):
        """get_active_flows_paginated() passes page and perPage parameters."""
        with self._patch_request({}) as mock_req:
            self.host.get_active_flows_paginated(3, 50)
            url, params = mock_req.call_args[0]
            self.assertIn("flow/active", url)
            self.assertEqual(params["currentPage"], 3)
            self.assertEqual(params["perPage"], 50)
            self.assertEqual(params["host"], "10.0.0.1")


# ---------------------------------------------------------------------------
# Historical tests
# ---------------------------------------------------------------------------

class TestHistorical(unittest.TestCase):
    """Tests for the Historical class."""

    def setUp(self):
        self.ntopng = _make_ntopng()
        self.hist = Historical(self.ntopng, ifid=0)

    def _patch_request(self, return_value):
        return patch.object(self.ntopng, "request", return_value=return_value)

    def _patch_post_request(self, return_value):
        return patch.object(self.ntopng, "post_request", return_value=return_value)

    def test_init_stores_ifid(self):
        self.assertEqual(self.hist.ifid, 0)

    def test_init_without_ifid(self):
        """Historical can be constructed without an ifid."""
        hist = Historical(self.ntopng)
        self.assertIsNone(hist.ifid)

    def test_get_alert_type_counters(self):
        """get_alert_type_counters() passes epoch range to the correct endpoint."""
        with self._patch_request({}) as mock_req:
            self.hist.get_alert_type_counters(1000, 2000)
            url, params = mock_req.call_args[0]
            self.assertIn("alert/type/counters", url)
            self.assertEqual(params["epoch_begin"], 1000)
            self.assertEqual(params["epoch_end"], 2000)

    def test_get_alert_severity_counters(self):
        """get_alert_severity_counters() passes epoch range to the correct endpoint."""
        with self._patch_request({}) as mock_req:
            self.hist.get_alert_severity_counters(1000, 2000)
            url, params = mock_req.call_args[0]
            self.assertIn("alert/severity/counters", url)
            self.assertEqual(params["epoch_begin"], 1000)
            self.assertEqual(params["epoch_end"], 2000)

    def test_get_alerts(self):
        """get_alerts() passes all query parameters."""
        with self._patch_request([]) as mock_req:
            self.hist.get_alerts("flow", 1000, 2000, "*", None, 10, None, "epoch_begin")
            url, params = mock_req.call_args[0]
            self.assertIn("alert/list/alerts", url)
            self.assertEqual(params["alert_family"], "flow")
            self.assertEqual(params["maxhits_clause"], 10)

    def test_get_alerts_stats_without_host(self):
        """get_alerts_stats() without host does not include ip in params."""
        with self._patch_request({}) as mock_req:
            self.hist.get_alerts_stats(1000, 2000)
            _, params = mock_req.call_args[0]
            self.assertNotIn("ip", params)

    def test_get_alerts_stats_with_host(self):
        """get_alerts_stats() with host includes ip filter in params."""
        with self._patch_request({}) as mock_req:
            self.hist.get_alerts_stats(1000, 2000, host="192.168.1.1")
            _, params = mock_req.call_args[0]
            self.assertIn("192.168.1.1", params["ip"])

    def test_get_flow_alerts_stats(self):
        """get_flow_alerts_stats() calls the pro flow alert top endpoint."""
        with self._patch_request({}) as mock_req:
            self.hist.get_flow_alerts_stats(1000, 2000)
            url, _ = mock_req.call_args[0]
            self.assertIn("flow/alert/top", url)

    def test_get_flow_alerts_delegates_to_get_alerts(self):
        """get_flow_alerts() calls get_alerts() with family='flow'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_flow_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            mock_ga.assert_called_once()
            self.assertEqual(mock_ga.call_args[0][0], "flow")

    def test_get_active_monitoring_alerts_delegates_to_get_alerts(self):
        """get_active_monitoring_alerts() calls get_alerts() with family='active_monitoring'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_active_monitoring_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "active_monitoring")

    def test_get_host_alerts_delegates_to_get_alerts(self):
        """get_host_alerts() calls get_alerts() with family='host'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_host_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "host")

    def test_get_interface_alerts_delegates_to_get_alerts(self):
        """get_interface_alerts() calls get_alerts() with family='interface'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_interface_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "interface")

    def test_get_mac_alerts_delegates_to_get_alerts(self):
        """get_mac_alerts() calls get_alerts() with family='mac'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_mac_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "mac")

    def test_get_network_alerts_delegates_to_get_alerts(self):
        """get_network_alerts() calls get_alerts() with family='network'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_network_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "network")

    def test_get_snmp_alerts_delegates_to_get_alerts(self):
        """get_snmp_alerts() calls get_alerts() with family='snmp'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_snmp_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "snmp")

    def test_get_system_alerts_delegates_to_get_alerts(self):
        """get_system_alerts() calls get_alerts() with family='system'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_system_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "system")

    def test_get_user_alerts_delegates_to_get_alerts(self):
        """get_user_alerts() calls get_alerts() with family='user'."""
        with patch.object(self.hist, "get_alerts", return_value=[]) as mock_ga:
            self.hist.get_user_alerts(1000, 2000, "*", None, 5, None, "epoch_begin")
            self.assertEqual(mock_ga.call_args[0][0], "user")

    def test_get_flows(self):
        """get_flows() calls the flows endpoint via post_request."""
        with self._patch_post_request([]) as mock_post:
            self.hist.get_flows(1000, 2000, "*", None, 5, None, "epoch_begin")
            url, params = mock_post.call_args[0]
            self.assertIn("db/flows", url)
            self.assertEqual(params["epoch_begin"], 1000)
            self.assertEqual(params["epoch_end"], 2000)

    def test_get_topk_flows(self):
        """get_topk_flows() calls the topk_flows endpoint."""
        with self._patch_request([]) as mock_req:
            self.hist.get_topk_flows(1000, 2000, 10, None)
            url, params = mock_req.call_args[0]
            self.assertIn("topk_flows", url)
            self.assertEqual(params["maxhits_clause"], 10)

    def test_get_top_conversations_without_host(self):
        """get_top_conversations() without host does not include ip in params."""
        resp = {"records": []}
        with self._patch_request(resp) as mock_req:
            self.hist.get_top_conversations(1000, 2000)
            _, params = mock_req.call_args[0]
            self.assertNotIn("ip", params)

    def test_get_top_conversations_with_host(self):
        """get_top_conversations() with host includes ip filter in params."""
        resp = {"records": [{"cli": "10.0.0.1"}]}
        with self._patch_request(resp) as mock_req:
            result = self.hist.get_top_conversations(1000, 2000, host="10.0.0.1")
            _, params = mock_req.call_args[0]
            self.assertIn("10.0.0.1", params["ip"])
        self.assertEqual(result, [{"cli": "10.0.0.1"}])

    def test_get_host_top_protocols(self):
        """get_host_top_protocols() builds the correct ts_query string."""
        with self._patch_request({}) as mock_req:
            self.hist.get_host_top_protocols("10.0.0.2", 1000, 2000)
            _, params = mock_req.call_args[0]
            self.assertIn("host:10.0.0.2", params["ts_query"])

    def test_timeseries_to_pandas_with_valid_rsp(self):
        """timeseries_to_pandas() returns a DataFrame when response has expected keys."""
        rsp = {
            "start": 1000,
            "count": 3,
            "step": 1,
            "series": [{"label": "bytes_sent", "data": [10, 20, 30]}],
        }
        df = self.hist.timeseries_to_pandas(rsp)
        self.assertIsInstance(df, pd.DataFrame)
        self.assertIn("bytes_sent", df.columns)
        self.assertEqual(len(df), 3)

    def test_timeseries_to_pandas_with_missing_keys(self):
        """timeseries_to_pandas() returns an empty DataFrame when keys are missing."""
        rsp = {"unexpected_key": []}
        df = self.hist.timeseries_to_pandas(rsp)
        self.assertIsInstance(df, pd.DataFrame)
        self.assertEqual(len(df), 0)

    def test_get_timeseries(self):
        """get_timeseries() uses post_request and passes ts_schema/ts_query."""
        rsp = {"start": 0, "count": 0, "step": 1, "series": []}
        with self._patch_post_request(rsp) as mock_post:
            self.hist.get_timeseries("host:traffic", "ifid:0,host:1.2.3.4", 1000, 2000)
            url, params = mock_post.call_args[0]
            self.assertIn("timeseries/ts", url)
            self.assertEqual(params["ts_schema"], "host:traffic")
            self.assertEqual(params["ts_query"], "ifid:0,host:1.2.3.4")

    def test_get_host_timeseries(self):
        """get_host_timeseries() builds ts_query containing the host IP."""
        with patch.object(self.hist, "get_timeseries", return_value=pd.DataFrame()) as mock_ts:
            self.hist.get_host_timeseries("1.2.3.4", "host:traffic", 1000, 2000)
            _, kwargs = mock_ts.call_args
            ts_query = mock_ts.call_args[0][1]
            self.assertIn("host:1.2.3.4", ts_query)

    def test_get_interface_timeseries(self):
        """get_interface_timeseries() builds ts_query with the interface ID."""
        with patch.object(self.hist, "get_timeseries", return_value=pd.DataFrame()) as mock_ts:
            self.hist.get_interface_timeseries("iface:traffic_rxtx", 1000, 2000)
            ts_query = mock_ts.call_args[0][1]
            self.assertIn("ifid:", ts_query)

    def test_get_timeseries_metadata(self):
        """get_timeseries_metadata() calls the timeseries type consts endpoint."""
        with self._patch_request({}) as mock_req:
            self.hist.get_timeseries_metadata()
            url, _ = mock_req.call_args[0]
            self.assertIn("timeseries/type/consts", url)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    unittest.main()
