libgeohash
==========

Derek Smith 
-----------
derek@simplegeo.com
-------------------

A static library used for encoding/decoding geohashes.


To use libgeohash just run make. Link libgeohash.a and include geohash.h into your project.

### Encode

char* geohash_encode(double lat, double lng, int precision);

Takes in latitude and longitude with a desired precision and returns the correct hash value. If
precision < 0 or precision > 20, a default value of 6 will be used.

### Decode

GeoCoord geohash_decode(char* hash);


Produces an allocated GeoCoord structure which contains the latitude and longitude that was decoded from
the geohash. A GeoCoord also provides the bounding box for the geohash (north, east, south, west).

### Neighbors

char** geohash_neighbors(char* hash);

Uses the bounding box declared at hash and calculates the 8 neighboring boxes. An example is show below.

+ ezefx ezs48 ezs49
+ ezefr ezs42 ezs43
+ ezefp ezs40 ezs41

The value returned is an array of char* with length of 8. The neighboring positions of values are shown 
below with each box representing the index of the array.

+ 7 0 1
+ 6 * 2
+ 5 4 3
