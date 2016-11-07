local  en = {
   welcome = "Welcome",
   version = "Your version is %{vers}.",
   error = "Error",
   host = "Host %{host}",
   day = "Day",
   time = "Time",
   sent = "Sent",
   received = "Received",
   difference = "Difference",
   total = "Total",
   today = "Today",
   host_report = {
      daily = "Daily",
      weekly = "Weekly",
      monthly = "Monthly",
      header_daily = "Daily \"%{date}\" report",
      header_weekly = "Weekly #%{week} \"%{date}\" report",
      header_monthly = "Monthly \"%{date}\" report",
      error_rrd_resolution = "You are asking to fetch data at lower resolution than the one available on RRD, which will lead to invalid data."..
         "<br>If you still want data with such granularity, please tune <a href=\"%{prefs}\">Protocol/Networks Timeseries</a> preferences",
      current = "Current",
      previous_day = "Previous day",
      previous_week = "Previous week",
      previous_month = "Previous month",
   },
   report = {
      period = "Interval",
      date = "%{month}-%{day}-%{year}"}
}

return {en = en}

   
