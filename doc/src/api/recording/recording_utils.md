---
title: "recording_utils API"
description: "recording_utils API in the ntopng User's Guide."
outline: [2, 3]
lastUpdated: 2019-02-28T09:35:47+01:00
---
# recording_utils API {#recording-utils-api}

`Extraction params`:
: - *time_from*: epoch
  - *time_to*: epoch
  - *filter*: nBPF filter

`Recording configuration params`:
: - *buffer_size*: Buffer size (MB)
  - *max_file_size*: Max file length (MB)
  - *max_file_duration*: Max file duration (sec)
  - *max_disk_space*: Max disk space (MB)
  - *snaplen*: Capture length
  - *writer_core*: Writer thread affinity
  - *reader_core*: Reader thread affinity
  - *indexer_cores*: Indexer threads affinity
  - *zmq_endpoint*: ZMQ endpoint (optional)

### `recording_utils.isSupportedZMQInterface(ifid)` {#recording-utils-issupportedzmqinterface}

Check if an interface is a ZMQ interface that can be used with external interfaces for traffic recording and flow import

**Parameters**

- `ifid`: the interface identifier 

**Returns**: true if supported, false otherwise

### `recording_utils.getZMQProbeAddr(ifid)` {#recording-utils-getzmqprobeaddr}

Return the ZMQ endpoint that should be used by an external process (n2disk) to deliver flows to ntopng

**Parameters**

- `ifid`: the interface identifier 

**Returns**: the endpoint

### `recording_utils.isSupportedInterface(ifid)` {#recording-utils-issupportedinterface}

Check if an interface is supported for recording (packet interface, or ZMQ interface that can be used with external interfaces for traffic dump and flow import)

**Parameters**

- `ifid`: the interface identifier 

**Returns**: true if supported, false otherwise

### `recording_utils.isExternalProvidersReminderDismissed(ifid)` {#recording-utils-isexternalprovidersreminderdismissed}

Check if a reminder that warns the user about available external traffic rec. providers has to be shown

**Returns**: true if the reminder has to be shown, false otherwise

### `recording_utils.dismissExternalProvidersReminder(ifid)` {#recording-utils-dismissexternalprovidersreminder}

Dismiss the reminder for external traffic recording providers

**Returns**: nil

### `recording_utils.isExtractionAvailable()` {#recording-utils-isextractionavailable}

Check if traffic recording and extraction is allowed for the current user on an interface

**Returns**: true if extraction is available, false otherwise

### `recording_utils.getN2diskInfo()` {#recording-utils-getn2diskinfo}

Return information about the recording service (n2disk) including systemid and version

**Returns**: a table with the information

### `recording_utils.setLicense(key)` {#recording-utils-setlicense}

Install a license for n2disk

**Parameters**

- `key`: The license key

**Returns**: true if the license is installed, false in case it is not possible

### `recording_utils.getExtInterfaces(ifid, show_all)` {#recording-utils-getextinterfaces}

Return external interfaces, not in use by ntopng, that can be used through ZMQ interface for traffic recording and flow import

**Parameters**

- `ifid`: the interface identifier 

**Returns**: a table with external interfaces information

### `recording_utils.getPcapPath(ifid)` {#recording-utils-getpcappath}

Return the root path for recorded pcap data

**Parameters**

- `ifid`: the interface identifier 

**Returns**: the path

### `recording_utils.volumeInfo(path)` {#recording-utils-volumeinfo}

Read information about a volume, including storage size and available space

**Parameters**

- `path`: the volume path (or a folder inside the volume)

### `recording_utils.storageInfo(ifid, timeout)` {#recording-utils-storageinfo}

Read information about the storage, including storage size and available space

**Parameters**

- `ifid`: the interface identifier
- `timeout`: the maxium time to compute the size

**Returns**: a table containing storage information (size is in bytes)

### `recording_utils.createConfig(ifid, params)` {#recording-utils-createconfig}

Generate a configuration for the traffic recording service (n2disk)

**Parameters**

- `ifid`: the interface identifier
- `params`: the traffic recording settings

### `recording_utils.isEnabled(ifid)` {#recording-utils-isenabled}

Check if traffic recording is available and enabled on an interface

**Parameters**

- `ifid`: the interface identifier 

**Returns**: true if recording is enabled, false otherwise

### `recording_utils.getViewedInterfacesWithRecording(view_ifid)` {#recording-utils-getviewedinterfaceswithrecording}

Return the list of viewed interfaces that have traffic recording enabled.

**Returns**: array of { ifid, ifname }

### `recording_utils.isExtractionEnabled(ifid)` {#recording-utils-isextractionenabled}

Check if traffic extraction is available and recording is enabled on an interface

### `recording_utils.isActive(ifid)` {#recording-utils-isactive}

Check if the traffic recording service is running

**Parameters**

- `ifid`: the interface identifier 

**Returns**: true if the service is running, false otherwise

### `recording_utils.isExtractionActive(ifid)` {#recording-utils-isextractionactive}

Check if traffic recording is running and extraction is allowed for the current user on an interface

**Parameters**

- `ifid`: the interface identifier 

**Returns**: true if the service is running and extraction available, false otherwise

### `parse_proc_stats(proc_stats)` {#parse-proc-stats}

Return statistics from the traffic recording service (n2disk)

**Parameters**

- `ifid`: the interface identifier

**Returns**: the statistics

### `recording_utils.stats(ifid)` {#recording-utils-stats}

Return statistics from the traffic recording service (n2disk)

**Parameters**

- `ifid`: the interface identifier

**Returns**: the statistics

### `recording_utils.getStats(ifid)` {#recording-utils-getstats}

Return dump window stats using recording_utils.stats() In case of View interface stats are aggregated from all virwed interfaces In case of View interface stats are aggregated from all virwed interfaces

**Returns**: stats with FirstDumpedEpoch/LastDumpedEpoch, is_active boolean

### `recording_utils.smartStats(ifid)` {#recording-utils-smartstats}

Return statistics from the traffic recording service (n2disk)

**Parameters**

- `ifid`: the interface identifier

**Returns**: the statistics

### `recording_utils.getCurrentTrafficRecordingProviderTimelinePath(ifid)` {#recording-utils-getcurrenttrafficrecordingprovidertimelinepath}

Returns the path to the timeline of the selected traffic recorder

**Parameters**

- `ifid`: the interface identifier 

**Returns**: the timeline, if found, or nil

### `recording_utils.getTimelineByInterval(ifid, epoch_begin, epoch_end)` {#recording-utils-gettimelinebyinterval}

Return the current n2disk timeline, or the "Smart" timeline if active, based on the time interval

### `recording_utils.checkExtraction(ifid, use_smart)` {#recording-utils-checkextraction}

Parse the configuration file of a manually-started n2disk and returns the timeline if found

**Parameters**

- `ifid`: the interface identifier 

**Returns**: true if extraction is possible and false otherwise, along with a check message

### `recording_utils.restart(ifid, config)` {#recording-utils-restart}

Start (or restart) the traffic recording service

**Parameters**

- `ifid`: the interface identifier 

### `recording_utils.stop(ifid)` {#recording-utils-stop}

Stop the traffic recording service

**Parameters**

- `ifid`: the interface identifier 

### `recording_utils.log(ifid, rows)` {#recording-utils-log}

**Returns**: the log trace

### `recording_utils.isDataAvailable(ifid, epoch_begin, epoch_end)` {#recording-utils-isdataavailable}

Check if there is pcap data for a specified time interval (fully included in the dump window)

**Parameters**

- `ifid`: the interface identifier
- `epoch_begin`: the begin time (epoch)
- `epoch_end`: the end time (epoch)

**Returns**: a table with 'available' = true if the specified interval is included in the dump window, 'epoch_begin'/'epoch_end' are also returned with the actual available window.

### `recording_utils.getJobFiles(id)` {#recording-utils-getjobfiles}

Return the list of pcap files extracted for a job

**Parameters**

- `job_id`: the job identifier 

**Returns**: the list of pcap files (paths)

### `recording_utils.deleteJob(job_id)` {#recording-utils-deletejob}

Delete an extraction job and its pcap data on disk, if any

**Parameters**

- `job_id`: the job identifier 

### `recording_utils.deleteAndStopAllJobs(ifid)` {#recording-utils-deleteandstopalljobs}

Delete and stop all the extraction jobs for the specified interface.

**Parameters**

- `ifid`: the interface identifier

### `recording_utils.extractionJobsInfo(ifid)` {#recording-utils-extractionjobsinfo}

Return statistics about the extraction jobs.

**Parameters**

- `ifid`: the interface identifier 

**Returns**: the jobs statistics (ready, total)

### `recording_utils.getExtractionJobs(ifid)` {#recording-utils-getextractionjobs}

Return the list of scheduled extraction jobs.

**Parameters**

- `ifid`: the interface identifier

**Returns**: the list of jobs

### `recording_utils.stopJob(job_id)` {#recording-utils-stopjob}

Stop a running extraction job.

**Parameters**

- `job_id`: the job identifier 

### `recording_utils.scheduleExtraction(ifid, params)` {#recording-utils-scheduleextraction}

Schedule a new extraction job.

**Parameters**

- `ifid`: the interface identifier 
- `params`: the extraction parameters. time_from/time_to (epoch) are mandatory. filter (nBPF format) is optional.

**Returns**: the newly created job 
