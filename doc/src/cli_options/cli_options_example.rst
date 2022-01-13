.. _CliOptions:

Configuration File Example
--------------------------
.. code:: bash

    #         The  configuration  file is similar to the command line, with the exception that an equal                                                                                                        
    #        sign '=' must be used between key and value. Example:  -i=p1p2  or  --interface=p1p2  For                                                                                                         
    #        options with no value (e.g. -v) the equal is also necessary. Example: "-v=" must be used.                                                                                                         
    #                                                                                                                                                                                                          
    #                                                                                                                                                                                                          
    #       -G|--pid-path                                                                                                                                                                                      
    #        Specifies the path where the PID (process ID) is saved. This option is ignored when                                                                                                               
    #        ntopng is controlled with systemd (e.g., service ntopng start).                                                                                                                                   
    #                                                                                                                                                                                                          
    -G=/var/run/ntopng.pid                                                                                                                                                                                    
    #                                                                                                                                                                                                          
    #       -i|--interface                                                                                                                                                                                     
    #        Specifies  the  network  interface or collector endpoint to be used by ntopng for network                                                                                                         
    #        monitoring. On Unix you can specify both the interface name  (e.g.  lo)  or  the  numeric                                                                                                         
    #        interface id as shown by ntopng -h. On Windows you must use the interface number instead.                                                                                                         
    #        Note that you can specify -i multiple times in order to instruct ntopng to create  multi-                                                                                                         
    #        ple interfaces.                                                                                                                                                                                   
    #                                                                                                                                                                                                          
    # -i=eth1                                                                                                                                                                                                  
    -i=eno1
    -i=eno2
    -i=lo
    -i=tcp://127.0.0.1:5556                                                                                                                                                                                                  
    #                                                                                                                                                                                                          #                                                                                                                                                                                                          
    #       -m|--local-networks                                                                                                                                                                                
    #        ntopng determines the ip addresses and netmasks for each active interface. Any traffic on                                                                                                         
    #        those  networks  is considered local. This parameter allows the user to define additional                                                                                                         
    #        networks and subnetworks whose traffic is also considered local in  ntopng  reports.  All                                                                                                         
    #        other hosts are considered remote. If not specified the default is set to 192.168.1.0/24.                                                                                                         
    #                                                                                                                                                                                                          
    #        Commas  separate  multiple  network  values.  Both netmask and CIDR notation may be used,                                                                                                         
    #        even mixed together, for instance "131.114.21.0/24,10.0.0.0/255.0.0.0".                                                                                                                           
    #                                                                                                                                                                                                          
    -m="10.10.123.0/24=Milan,10.8.124.0/24=Paris,10.7.10.0/24=Rome,10.6.0.0/24=Florence"                                                                                                                                                                                                                                                                                                                                    
    #                                                                                                                                                                                                          
    #       -n|--dns-mode                                                                                                                                                                                      
    #        Sets the DNS address resolution mode: 0 - Decode DNS responses  and  resolve  only  local                                                                                                         
    #        (-m)  numeric  IPs  1  -  Decode DNS responses and resolve all numeric IPs 2 - Decode DNS                                                                                                         
    #        responses and don't resolve numeric IPs 3 - Don't decode DNS responses and don't  resolve                                                                                                         
    #                                                                                                                                                                                                          
    -n=1
    #
    #       -X|--max-num-flows 
    #       Set max number of active flows (default: 131072)
    #
    -X=500000
    #
    #       -x|--max-num-hosts 
    #       Set max number of active hosts (default: 131072)
    #
    -x=500000

