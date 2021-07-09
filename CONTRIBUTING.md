How to Contribute
=================

Anyone is welcome to contribute through the official repository
on github:

```
git clone -b dev https://github.com/ntop/ntopng.git
```

If you want to contribute with a patch, the first step to get it
in the main tree is to run the regression tests included in the 
ntopng source code. 

Run the Tests
=============

An automated test suite is available under ntopng/tests, in order
to run it:

1. Compile ntopng. Please read the 'Memory Leak Detection' section in order to also enable the runtime memory leak detector.

2. Make sure you have all the prerequisites installed: 

- redis-cli
- curl
- jq
- shyaml (pip install shyaml)

3. Run the run.sh script:

```
cd ntopng/tests
./run.sh
```
Please check that all the tests complete successfully before moving
to the next step, sending the Pull Request.

Note: in case of failures, the output of the tests is stored in the
*ntopng/tests/rest/conflicts/* folder, in order to be able to compare
it with the expected output in the *ntopng/tests/rest/result* folder. 
In case of test failures due to errors or warnings in the ntopng trace,
the full ntopng log is stored in the *ntopng/tests/rest/logs/* folder.

Create a PR
===========

Please check the official GitHub documentation for instructions
for sending Pull Requests:

https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request

After the submission the ntop core team will review the patches to
make sure they are well written and do the right things. If everything
goes well, patches are applied to the dev branch and will be included
in the nightly builds.

Add a Test
==========

When implementing a new feature, it is recommended to write a new
regression test to test the feature. This is based on the Rest API:
the first time the test is executed, the output (this should be in
json format) is stored in the 'result' folder, subsequent executions
will compare the output of the test with the old one to make sure it
is still the same.

Creating a new test is as simple as creating a small .yaml file, with
the test name as name of the file, under ntopng/tests/rest/tests/<API version>
(where *API version* should be at least the latest API, e.g. v2) containing
the below sections:

- input: the name of a pcap in the 'ntopng/tests/rest/pcap' folder containing some traffic to be provided to ntopng as input
- localnet: the local network(s) as usually specified with the -m option in ntopng
- pre: a bash script with commands to be executed before processing the pcap in ntopng (initialization)
- post: a bash script with commands to be executed after the pcap has been processed by ntopng and generating some json output (using the Rest API)
- ignore: fields from the output to be ignored when comparing the output with the old JSON (this is usually used to ignore time, date or other fields that can change over time)

Example:

```
input: traffic.pcap

localnet: 192.168.1.0/24

pre: |
  curl -s -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "action": "enable"}' http://localhost:3333/lua/toggle_all_user_scripts.lua

post: |
  sleep 10
  curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"ifid": 0, "status": "historical-flows"}' http://localhost:3333/lua/rest/v2/get/alert/data.lua

ignore:
  - date
```

In order to run a specific test and avoid running all the suite, it is possible to specify -y=<API version>/<test name> when running the run.sh script under ntopng/tests/rest:

```
cd ntopng/tests/rest
./run.sh -y=v2/get_alert_data_01
```

Memory Leak Detection
=====================

It is recommended to also enable the runtime memory leak detector
based on the clang sanitizer when running the tests. This would
check both memory errors and leaks (with no performance overhead). 

In order to enable the sanitizer, please compile ntopng as below.

```
cd ntopng
./autogen.sh
./configure --with-sanitizer
make
```

This will report at the end of each test any memory leak or bad
memory access, if any.
