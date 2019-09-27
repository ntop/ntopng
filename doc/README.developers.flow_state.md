# Flow States

Although no state machine is implemented into the Flow class, we can assign it some logical states:

 - *undetected*: nDPI protocol detection is still in progress.
   Flow::isDetectionCompleted() returns *false* and Flow::get_detected_protocol() will return *Unkwnown*.

 - *detection_completed*: The nDPI protocol detection is complete.
   Flow::isDetectionCompleted() returns *true* and Flow::get_detected_protocol() returns the
   detected protocol. Flow::processDetectedProtocol() is called. However, the nDPI memory is not deallocated
   yet as the nDPI detection callback may still may be called (for example to extract the SSL server certificate).

 - *fully_dissected*: nDPI will not be called anymore for the flow. All the flow information has been
   extracted. Flow::processFullyDissectedProtocol() is called. The nDPI memory is deallocated.

# Processing Detected Protocols

As explained above, there are two callbacks which are used to process the protocol
information previously detected on a Flow:

 - Flow::processDetectedProtocol(): will be called as soon as a protocol is detected
   on the flow. This is an initial hook for protocol specific logic.

 - Flow::processFullyDissectedProtocol(): will be called after additional dissection
   has been performed on the flow (or immediately if such dissection won't occurr).
   This hook is suitable to process the additional metadata (e.g. the SSH/TLS fingerprints)
