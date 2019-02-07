recording_utils API
###################

`Extraction params`:
  - *time_from*: epoch
  - *time_to*: epoch
  - *filter*: nBPF filter

`Recording configuration params`:
  - *buffer_size*: Buffer size (MB)
  - *max_file_size*: Max file length (MB)
  - *max_file_duration*: Max file duration (sec) 
  - *max_disk_space*: Max disk space (MB)                                        
  - *snaplen*: Capture length
  - *writer_core*: Writer thread affinity                                                                
  - *reader_core*: Reader thread affinity
  - *indexer_cores*: Indexer threads affinity                                                              
  - *zmq_endpoint*: ZMQ endpoint (optional)

.. doxygenfile:: recording_utils.lua.cpp

