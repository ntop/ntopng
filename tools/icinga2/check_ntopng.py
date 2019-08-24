#!/usr/bin/env python3

# (C) 2013-19 - ntop.org
# Author: Simone Mainardi <mainardi@ntop.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

import argparse
import signal
import sys
from functools import partial
import ssl
import urllib.request
import base64
import json

__version__ = '1.0.0'

def output(label, state = 0, lines = None, perfdata = None, name = 'ntopng'):
    if lines is None:
        lines = []
    if perfdata is None:
        perfdata = {}

    pluginoutput = ""

    if state == 0:
        pluginoutput += "OK"
    elif state == 1:
        pluginoutput += "WARNING"
    elif state == 2:
        pluginoutput += "CRITICAL"
    elif state == 3:
        pluginoutput += "UNKNOWN"
    else:
        raise RuntimeError("ERROR: State programming error.")

    pluginoutput += " - "

    pluginoutput += name + ': ' + str(label)

    if len(lines):
        pluginoutput += ' - '
        pluginoutput += ' '.join(lines)

    if perfdata:
        pluginoutput += '|'
        pluginoutput += ' '.join(["'" + key + "'" + '=' + str(value) for key, value in perfdata.items()])

    print(pluginoutput)
    sys.exit(state)


def handle_sigalrm(signum, frame, timeout=None):
    output('Plugin timed out after %d seconds' % timeout, 3)

class Checker(object):
    def __init__(self, host, port, ifid, user, secret, use_ssl, unsecure, timeout, verbose):
        self.host = host
        self.port = port
        self.ifid = ifid
        self.user = user
        self.secret = secret
        self.use_ssl = use_ssl
        self.unsecure = unsecure
        self.timeout = timeout
        self.verbose = verbose

        if self.verbose:
            print('[%s:%u][ifid: %u][ntopng auth: %s/%s][ssl: %u][unsecure: %u][timeout: %u]' % (self.host, self.port, self.ifid, self.user, self.secret, self.use_ssl, self.unsecure, self.timeout))

    def check_url(self, ifid, checked_host, check_type):
        """
        Requests
        entity = 1 means "Host" and this must be kept in sync with ntopng sources
        sortColumn=column_key guarantees alerts are ordered by rowid which is meaningful for flow alerts
        @0 forced, currently not supporting hosts with vlans
        """

        return 'http%s://%s:%u/lua/get_alerts_table_data.lua?status=%s&ifid=%u&entity=1&entity_val=%s@0&currentPage=1&perPage=1&sortColumn=column_key&sortOrder=desc'% ('s' if self.use_ssl else '', self.host, self.port, 'engaged' if check_type == 'host-alerts' else 'historical-flows', ifid, checked_host)

    def fetch(self, ifid, checked_host, check_type):
        req = urllib.request.Request(self.check_url(ifid, checked_host, check_type))

        if self.user is not None or self.secret is not None:
            credentials = ('%s:%s' % (self.user, self.secret))
            encoded_credentials = base64.b64encode(credentials.encode('ascii'))
            req.add_header('Authorization', 'Basic %s' % encoded_credentials.decode("ascii"))

        if self.unsecure:
            ssl._create_default_https_context = ssl._create_unverified_context

        try:
            with urllib.request.urlopen(req) as response:
                data = response.read().decode('utf-8')
        except Exception as e:
            output('Failed to fetch data from ntopng [%s: %s]' % (type(e).__name__, str(e)), 3)

        try:
            data = json.loads(data)
        except Exception as e:
            if self.verbose:
                print(data)
            output('Failed to parse fetched data as JSON [%s: %s]' % (type(e).__name__, str(e)), 3)

        return data

    @staticmethod
    def parse_perfdata(perfdata):
        """
        Perfdata is a string containing one or more performance values as
        latest_alert_id=14 latest_alert_date=00:31

        This method creates a dictionary by parsing the string.
        """
        res = {}

        try:
            for perf in perfdata.split(" "):
                label_value = perf.split("=")
                label = label_value[0]
                value = label_value[1]
                res[label] = value
        except:
            res = {}

        return res

    @staticmethod
    def check_host_alerts(fetched):
        if fetched['totalRows'] > 0:
            output("There are %u engaged alerts" % fetched['totalRows'], 2)
        else:
            output("There are no engaged alerts", 0)

    @staticmethod
    def check_flow_alerts(fetched, perfdata):
        status = 0
        curr_perfdata = None
        curr_latest_alert_id = 0
        prev_latest_alert_id = 0

        # Read the highest alert id from the fetched data and also store it as a perf data
        if fetched['totalRows'] > 0:
            curr_latest_alert = fetched['data'][0]
            # Set prev_ and curr_ to the same value, it safe as prev_ could possibly be overridden when parsing perfdata
            curr_latest_alert_id = prev_latest_alert_id = int(curr_latest_alert['column_key'])
            curr_perfdata = {'latest_alert_id': curr_latest_alert_id}

        # Read the previous perfdata and compute the delta to see if in the meanwhile there have been new flow alerts
        if perfdata:
            parsed_perfdata = Checker.parse_perfdata(perfdata)
            if 'latest_alert_id' in parsed_perfdata:
                prev_latest_alert_id = int(parsed_perfdata['latest_alert_id'])

        # If the highest alert id across two consecutive checks has increased, it means there are new flow alerts
        if curr_latest_alert_id > prev_latest_alert_id:
            status = 2 # CRITICAL, new flow alerts detected since last check

        output("There are %snew flow alerts" % ('no ' if status == 0 else ''), status, [], curr_perfdata)

    def check(self, ifid, checked_host, check_type, perfdata):
        res = self.fetch(ifid, checked_host, check_type)

        if check_type == 'host-alerts':
            self.check_host_alerts(res)
        elif check_type == 'flow-alerts':
            self.check_flow_alerts(res, perfdata)
        else:
            output('Unknown check type requested', 3)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--version', action = 'version', version = '%(prog)s v' + sys.modules[__name__].__version__)
    parser.add_argument('-V', '--verbose', action = 'store_true')
    parser.add_argument('-H', '--host', help = 'Address of the host running ntopng', required = True)
    parser.add_argument("-P", "--port", help = "Port on which ntopng is listening for connections [default: 3000]", type = int, default = 3000)
    parser.add_argument("-I", "--ifid", help = "Id of the ntopng monitored interface where alerts will be searched for", type = int, choices = range(0, 256), required = True)
    parser.add_argument("-U", "--user", help = "Name of an ntopng user")
    parser.add_argument("-S", "--secret", help = "Password to authenticate the ntopng user")
    parser.add_argument('-c', '--checked-host', help = 'IP of the host which should be checked for alerts', required = True)
    parser.add_argument("-T", "--check-type", required = True, help = "Which alerts should be checked. Supported: 'host-alerts', 'flow-alerts'", choices = ['host-alerts', 'flow-alerts'])
    parser.add_argument("-s", "--use-ssl", help="Use SSL to connect to ntopng", action = 'store_true')
    parser.add_argument("-u", "--unsecure", help="When SSL is used, ignore SSL certificate verification", action = 'store_true')
    parser.add_argument("-p", "--perfdata", help="Icinga2 perfdata of the previous check")
    parser.add_argument("-t", "--timeout", help="Timeout in seconds after which the scripts exits [default: 10s]", type = int, default = 10)
    args = parser.parse_args()

    signal.signal(signal.SIGALRM, partial(handle_sigalrm, timeout=args.timeout))
    signal.alarm(args.timeout)

    # if args.perfdata:
    #     f = open("/tmp/guru99.txt", "a+")
    #     f.write(args.perfdata+"\n")
    #     f.close()

    checker = Checker(args.host, args.port, args.ifid, args.user, args.secret, args.use_ssl, args.unsecure, args.timeout, args.verbose)

    checker.check(args.ifid, args.checked_host, args.check_type, args.perfdata)
