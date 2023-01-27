#!/usr/bin/env python3

#
# Sample script to be used as event handler in /usr/share/ntopng/scripts/shell/
#

import os
import sys
import time
import json

from redmail import EmailSender
from pathlib import Path

from ntopng.ntopng import Ntopng
from ntopng.report import Report

###############################################

### ntopng Connection Settings
ntopng_url = "http://localhost:3000"
auth_token = "532b8dbe1092e591435c7a13d561db71"
username = None
password = None

### SMTP Server Configuration
smtp_host = "mail.example.org"
smtp_port = 25
smtp_username = "sender"
smtp_password = ""

### Email sender/recipient
email_sender = "sender@example.org"
email_recipient = "example@gmail.com"
email_subject = "Automatic Report"

###############################################

# Defines
entity_host = 1
custom_host_lua_script = 24
external_host_script = 27

# Log
logfile = open("/tmp/python-script.log", "a")
def log(line):
    logfile.write(line + "\n")

# Send report by mail
def send_report(my_ntopng, iface_id):
    output_file  = "/tmp/report.pdf"

    generator = Report(my_ntopng, iface_id)

    log("Generating PDF " + output_file + "...")

    generator.generate_interface_report(output_file)

    if email_recipient is None:
        return

    log("Sending report " + output_file + " by email...")

    email = EmailSender(
        host = smtp_host,
        port = smtp_port,
        username = smtp_username,
        password = smtp_password
    )

    email.send(
        sender = email_sender,
        receivers = [email_recipient],
        subject = email_subject,
        attachments = {
            "report.pdf": Path(output_file)
        }
    )

# Debug tracing
"""
for line in sys.stdin:
    log(line)
"""

# Alert JSON decode
lines = sys.stdin.readlines()
alert = json.loads(lines[0])

#log("Processing alert...")

# Filter external host alerts
if alert["entity_id"] == entity_host and alert["alert_id"] == external_host_script:

    alert_info = json.loads(alert["json"])

    log("=> Custom Alert")
    log(alert["ip"])
    log(alert_info["message"])

    log("Connecting to ntopng...")

    # Connect to ntopng to get more data
    my_ntopng = None
    try:
        my_ntopng = Ntopng(username, password, auth_token, ntopng_url)
    except:
        log("Invalid credentials or URL specified")

    if my_ntopng is not None:

        iface_id = 0

        """
        my_historical = my_ntopng.get_historical_interface(iface_id)
    
        epoch_end    = int(time.time())
        epoch_begin  = epoch_end - 3600
        rsp = my_historical.get_alerts_stats(epoch_begin, epoch_end)
    
        for row in rsp:
            print("\n--------------------------\n"+row['label'])
            print(row['value'])
        """

        # Send a report
        send_report(my_ntopng, iface_id)

logfile.close()
os._exit(0)
