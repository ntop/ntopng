"""
Report
====================================
The Report class can be used to generate and send a report (e.g. PDF) with information about traffic on an interface or a host
"""

import os
import sys
import time
import uuid
import getopt
import base64
import pandas as pd
from fpdf import FPDF
import plotly.figure_factory as ff
import plotly.graph_objects as go

from ntopng.logo import *
from ntopng.host import Host
from ntopng.historical import Historical

class Report:
    """
    Report provides utility functions to generate reports
    
    :param ntopng_obj: The ntopng handle
    """

    def __init__(self, ntopng_obj, ifid):
        """
        Construct a new Report object
        
        :param ntopng_obj: The ntopng handle
        :type ntopng_obj: Ntopng
        :param ifid: The interface ID
        :type ifid: int
        """ 

        self.created_files = []

        self.ntopng_obj = ntopng_obj

        try:
            self.ifid = ifid
            self.interface = self.ntopng_obj.get_interface(ifid)
            self.historical = self.ntopng_obj.get_historical_interface(ifid)
    
        except ValueError as e:
            print(e)
            os._exit(-1)
  
    def gen_tmp_file_name(self, ext):
        filename = str(uuid.uuid4())
        path = "/tmp/" + filename + "." + ext
        self.created_files.append(path)
        return path

    def clear_cache(self):
        for file in self.created_files:
            self.delete_file(file)
        self.created_files = []
 
    def get_alerts_by_severity(self, epoch_begin, epoch_end):
        """
        Return a dataframe with alerts by severity
        """
        alerts_stats = self.historical.get_alerts_stats(epoch_begin, epoch_end)
        for stats in alerts_stats:
            # by severity
            if stats['name'] == 'top_alerts_by_severity':
                alerts_stats_df = pd.DataFrame(stats["value"])
                alerts_stats_df.drop(["key", "title"], axis= 1, inplace=True)
                alerts_stats_df = alerts_stats_df[["label", "severity_label"]]
                alerts_stats_df.rename(columns={"label": "Alert type", "severity_label": "Severity"}, inplace=True)

        if alerts_stats_df is None:
            alerts_stats_df = pd.DataFrame([])

        return alerts_stats_df

    def get_alerts_by_count(self, epoch_begin, epoch_end):
        """
        Return a dataframe with alerts by count
        """
        alerts_stats = self.historical.get_alerts_stats(epoch_begin, epoch_end)
        for stats in alerts_stats:
            # by count
            if stats['name'] == 'top_alerts_by_count':
                alerts_stats_df = pd.DataFrame(stats["value"])
                alerts_stats_df.drop(["key", "title"], axis= 1, inplace=True)
                alerts_stats_df['count'] = alerts_stats_df['count'].round(1)
                alerts_stats_df['count'] = alerts_stats_df['count'].astype(str) + " %"
                alerts_stats_df = alerts_stats_df[["label", "count"]]
                alerts_stats_df.rename(columns={"label": "Alert type", "count": "Occurrence %"}, inplace=True)

        if alerts_stats_df is None:
            alerts_stats_df = pd.DataFrame([])

        return alerts_stats_df
    
    def get_top_client_server(self, epoch_begin, epoch_end):
        """
        Return a dataframe with top clients and servers seen on the interface specified in the above script init data
        """
        
        try:
            top_client_server = self.historical.get_flow_alerts_stats(epoch_begin, epoch_end) 
            top_client_server_df = pd.DataFrame(top_client_server[0]["value"])
            top_client_server_df.drop(["key", "value"], axis= 1, inplace=True)
            top_client_server_df['count'] = top_client_server_df['count'].round(1)
            top_client_server_df['count'] = top_client_server_df['count'].astype(str) + " %"
            #reorder top_client_server_df columns
            top_client_server_df = top_client_server_df[["label", "ip", "count"]]
            #rename top_client_server_df columns
            top_client_server_df.rename(columns={"label": "Host name", "ip": "IP", "count": "Occurrence %"}, inplace=True)
        except:
            print("Top Client/Server report not available in community mode")
            top_client_server_df = pd.DataFrame([])

        return top_client_server_df
   
    def get_upload_download(self, epoch_begin, epoch_end):
        """
        Return a list where => data[0] = uploaded MB, data[1] = downloaded MB for the interface specified in the above script init data
        """

        up_down = self.historical.get_interface_timeseries("iface:traffic_rxtx", epoch_begin, epoch_end)
        data = [(up_down["bytes_sent"].sum()/1000000)*8, (up_down["bytes_rcvd"].sum()/1000000)*8] 
        
        return data
    
    def get_interface_data(self):
        """
        Return a dict with info about the interface specified in the above script init data
        """
    
        host_data = self.interface.get_data()
    
        host_info = {"flow_count": host_data["num_flows"], "local_hosts": host_data["num_local_hosts"], "hosts_count": host_data["num_hosts"], "local_hosts_anomalies": host_data["num_local_hosts_anomalies"], "alerted_flows": host_data["alerted_flows"], "num_flows": host_data["num_flows"],
                    "flows_warning": host_data["alerted_flows_warning"], "flows_error": host_data["alerted_flows_error"]}
        
        return host_info
    
    def get_interfaces_count(self):
        """
        Return number of interfaces
        """
        interfaces = self.ntopng_obj.get_interfaces_list()
        return len(interfaces)
    
    def delete_file(self, fname):
        """
        Deletes the table png from the current path
        :param fname: name of png to delete
        """
        # Relative path
        #current_dir = os.getcwd()
        #path = current_dir + "/" + fname

        # Absolute path
        path = fname
    
        try:
            os.path.exists(path)
            os.remove(path)
    
        except Exception as e:
            print(f"{path} does not exist")
            os._exit(-1)
    
    def df_to_table_png(self, df, fname, width, height):
        """
        Creates a png of the df specified with name
        :param df: dataframe to save to png
        :param fname: name of the file to save
        """
        fig = ff.create_table(df, colorscale=[[0, "#f3a114"], [.5, "#d9d9d9"], [1, "#ffffff"]])
        fig.update_layout(autosize=False, width=width, height=height)
        fig.write_image(str(fname), scale=2)
    
    def plot_traffic_chart(self, output_series_fname, epoch_begin, epoch_end):
        """
        Plots a png of the timeseries
        """
        up_down = self.historical.get_interface_timeseries("iface:traffic_rxtx", epoch_begin, epoch_end)
        up_down.reset_index(inplace=True)
        up_down['bytes_rcvd'] = up_down['bytes_rcvd'].mul(8)
        up_down['bytes_sent'] = up_down['bytes_sent'].mul(8)
        up_down['ts'] = up_down['index'].apply(lambda x: x.left)
        up_down['ts'] = pd.to_datetime(up_down['ts'], unit='s')
        
        layout = dict(plot_bgcolor='rgba(255,255,255, 0.3)')
        fig = go.Figure(layout=layout)
        fig.add_trace(go.Scatter(x=up_down["ts"], y=up_down["bytes_rcvd"],
                            mode='lines',
                            name='Received (bps)',
                            line_color='#f3a114'))
        fig.add_trace(go.Scatter(x=up_down["ts"], y=up_down["bytes_sent"],
                            mode='lines',
                            name='Sent (bps)',
                            line_color='#000000'))
    
        fig.write_image(output_series_fname, width=1280, height=720)
   
    def generate_interface_report(self, output_file): 
     
        actual_ts = int(time.time())
        yesterday = (actual_ts - 86400)

        epoch_begin = yesterday
        epoch_end = actual_ts
  
        # Data collection
     
        interfaces_count = self.get_interfaces_count()
        data_sent_rcvd = self.get_upload_download(epoch_begin, epoch_end)
        interface_data = self.get_interface_data()
        
        # alerts table (severity)
        alerts_by_severity_df = self.get_alerts_by_severity(epoch_begin, epoch_end)
        alerts_by_severity_df_fname = self.gen_tmp_file_name("png")
        self.df_to_table_png(alerts_by_severity_df, alerts_by_severity_df_fname, 450, 325)

        # alerts table (count)
        alerts_by_count_df = self.get_alerts_by_count(epoch_begin, epoch_end)
        alerts_by_count_df_fname = self.gen_tmp_file_name("png")
        self.df_to_table_png(alerts_by_count_df, alerts_by_count_df_fname, 450, 325)
        
        # client/server table
        hosts_df = self.get_top_client_server(epoch_begin, epoch_end, )
        hosts_df_fname = self.gen_tmp_file_name("png")
        self.df_to_table_png(hosts_df, hosts_df_fname, 950, 325)
        
        # Sent/Received
        sent = data_sent_rcvd[0]
        received = data_sent_rcvd[1]
        
        # Interface info
        flows = interface_data["num_flows"]
        host_num = interface_data["hosts_count"]
        local_hosts_num = interface_data["local_hosts"]
        flows_errors = interface_data["flows_error"]
        flows_warnings = interface_data["flows_warning"]
        
        # PDF creation
        
        margin = 10
        pw = 25 - 2*margin
        ch = 50

        pdf = FPDF()
        pdf.add_page()
        
        # Logo
        ntop_logo_fname = self.gen_tmp_file_name("png")
        with open(ntop_logo_fname, "wb") as fh:
            fh.write(base64.b64decode(ntop_logo_b64))
        pdf.image(ntop_logo_fname, x=140, y=15, w=68.2, h=17.8)
        
        # ntopng host info
        pdf.ln(9)
        pdf.set_font("Helvetica", "B", 18)
        pdf.set_text_color(r=0, g=0, b=0)
        pdf.cell(w=0, h=10, txt="24h Interface Report", ln=1)

        pdf.set_font("Helvetica", "", 11)
        ntopng_url = self.ntopng_obj.get_url()
        pdf.cell(w=0, h=5, txt=f"ntopng URL: {ntopng_url}")
        pdf.ln(5)

        pdf.cell(w=0, h=5, txt=f"Date: {time.strftime('%d-%m-%Y %H:%M:%S', time.localtime(epoch_end))}")
        pdf.ln(5)

        pdf.cell(w=0, h=5, txt=f"Interface: {self.ifid} (of {interfaces_count} interfaces)")
        pdf.ln(5)
        
        # Alerts
        pdf.set_font("Helvetica", "B", 14)
        pdf.cell(w=0, h=10, txt="Top Alerts")

        pdf.image(alerts_by_severity_df_fname, x=10, y=55, w=90, h=65)
        pdf.image(alerts_by_count_df_fname, x=110, y=55, w=90, h=65)

        # Hosts
        pdf.ln(75)
        pdf.set_font("Helvetica", "B", 14)
        pdf.cell(w=0, h=10, txt="Top Hosts")

        pdf.image(hosts_df_fname, x=10, y=130, w=190, h=65)
        
        #  Traffic stats
        pdf.ln(77)
        pdf.set_font("Helvetica", "B", 14)
        pdf.cell(w=0, h=10, txt="Traffic Summary")
        pdf.ln(5)
        pdf.set_font("Helvetica", "", 11)
        """
        pdf.cell(w=(pw/2), h=(ch/4), txt=f"{flows} Active Flows")
        pdf.ln(5)
        pdf.cell(w=(pw/2), h=(ch/4), txt=f"{host_num} Hosts")
        pdf.ln(5)
        pdf.cell(w=(pw/2), h=(ch/4), txt=f"{local_hosts_num} Local Hosts")
        pdf.ln(5)
        """
        pdf.cell(w=(pw/2), h=(ch/4), txt=f"Total Sent/Received: {sent:.2f} / {received:.2f} MB")

        series_fname = self.gen_tmp_file_name("png")
        self.plot_traffic_chart(series_fname, epoch_begin, epoch_end)
        pdf.image(series_fname, x=10, y=210, w=190, h=85)
        
        pdf.output(f"{output_file}", "F")
        
        self.clear_cache()
