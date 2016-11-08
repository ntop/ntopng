local  en = {
   welcome = "Welcome",
   version = "Your version is %{vers}.",
   error = "Error",
   host = "Host %{host}",
   day = "Day",
   week = "Week",
   month = "Month",
   time = "Time",
   sent = "Sent",
   received = "Received",
   difference = "Difference",
   total = "Total",
   today = "Today",
   traffic_report = {
      daily = "Daily",
      weekly = "Weekly",
      monthly = "Monthly",
      header_daily = "Daily report",
      header_weekly = "Weekly report",
      header_monthly = "Monthly report",
      error_rrd_resolution = "You are asking to fetch data at lower resolution than the one available on RRD, which will lead to invalid data."..
         "<br>If you still want data with such granularity, please tune <a href=\"%{prefs}\">Protocol/Networks Timeseries</a> preferences",
      current_day = "Current Day",
      current_week = "Current Week",
      current_month = "Current Month",
      previous_day = "Previous Day",
      previous_week = "Previous Week",
      previous_month = "Previous Month",
   },
   report = {
      period = "Interval",
      date = "%{month}-%{day}-%{year}"}
}

return {en = en}

   
