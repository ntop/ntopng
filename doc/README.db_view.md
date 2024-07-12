Database View Interface
=======================

ntopng 6.1 and later supports a database view interface, which is the
ability to replay flow records from the database to a new interface at
runtime, to let the user analyse historical traffic by using the same
user interface used to analyse live traffic.

This new interface is created at runtime in the Ntop::createRuntimeInterface
method, which is allocating a new instance of ClickHouseInterface (pro).

The ClickHouseInterface class extracts flow records by running a select in
the database (the where clause is provided in the constructor). The 
ClickHouseInterface::processRecords method takes care of running the actual
query.

Then each flow record is provided to ClickHouseInterface::processRecord which
converts it into a ParsedFlow object (the same used when collecting JSON/TLV 
flows from ZMQ/Kafka). The ParsedFlow object is processed by calling 
ParserInterface::processFlow.

Adding a New Column
-------------------

In order to extract an additional column from the flow records and add it
to the flow information reported in the live view, follow the below steps:

1. Add a mapping from the column name to the NetFlow IE identifier in the
   ClickHouseInterface constructor. Example with COMMUNITY_ID:
   ```
   addMapping("COMMUNITY_ID", COMMUNITY_ID);
   ```

2. Add the column name to the select statement in ClickHouseInterface::processRecords:
   ```
   const char *select =
   ...
   "COMMUNITY_ID, "
   ```

3. Convert the column value to the corresponding field of the ParsedFlow
   object in ClickHouseInterface::processRecord:
   ```
   case COMMUNITY_ID:
   flow.setCommunityID(value);
   break;
   ```

