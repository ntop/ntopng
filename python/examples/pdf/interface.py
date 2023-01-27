#!/usr/bin/env python3

"""
PDF report creation script using the Report class of the ntopng Python API
"""

import os
import sys
import time
import getopt

from redmail import EmailSender
from pathlib import Path
from getpass import getpass

sys.path.insert(0, '../../')

from ntopng.ntopng import Ntopng
from ntopng.report import Report

### NTOPNG API SETUP
username     = "admin"
password     = "admin"
ntopng_url   = "http://localhost:3000"
iface_id     = 0
auth_token   = None
enable_debug = False
output_file  = "report.pdf"

### SMTP server configuration
smtp_host = "mail.example.org"
smtp_port = 25
smtp_username = "sender"
smtp_password = None

### Email sender/recipient
email_sender = "sender@example.org"
email_recipient = None
email_subject = "New report"

##########

def usage():
    print("test.py [-u <username>] [-p <password>] [-t <auth token>] [-n <ntopng_url>]")
    print("             [-i <interface ID>] [-r <email recipient>] [--debug] [--help]")
    print("")
    print("Example: ./test.py -t ce0e284c774fac5a3e981152d325cfae -i 4")
    print("         ./test.py -u ntop -p mypassword -i 4")
    sys.exit(0)

##########

try:
    opts, args = getopt.getopt(sys.argv[1:],
                               "hdu:p:n:i:r:t:",
                               ["help",
                                "debug",
                                "username=",
                                "password=",
                                "ntopng_url=",
                                "iface_id=",
                                "recipient=",
                                "auth_token="]
                               )
except getopt.GetoptError as err:
    print(err)
    usage()
    sys.exit(2)

for o, v in opts:
    if(o in ("-h", "--help")):
        usage()
    elif(o in ("-d", "--debug")):
        enable_debug = True
    elif(o in ("-u", "--username")):
        username = v
    elif(o in ("-p", "--password")):
        password = v
    elif(o in ("-n", "--ntopng_url")):
        ntopng_url = v
    elif(o in ("-i", "--iface_id")):
        iface_id = v
    elif(o in ("-r", "--recipient")):
        email_recipient = v
    elif(o in ("-t", "--auth_token")):
        auth_token = v

##################################
######### DATA COLLECTOR #########
##################################

print("Connecting to ntopng...")

try:
    my_ntopng = Ntopng(username, password, auth_token, ntopng_url)

    if(enable_debug):
        my_ntopng.enable_debug()        
except ValueError as e:
    print(e)
    os._exit(-1)

generator = Report(my_ntopng, iface_id)

print("Generating PDF " + output_file + "...")

generator.generate_interface_report(output_file)

if email_recipient is not None:

    print("Sending report " + output_file + " by email...")

    if smtp_host is None:
        print("Please set the SMTP server parameters in the settings section")
        os._exit(-1)

    if smtp_password is None:
        print("Please enter the password for " + smtp_username)
        smtp_password = getpass()

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

