To test all the ntopng pages and check for crashes it is possible to recursively visit all pages automatically

ntopng can be started as follows
- ntopng -i ethX -l 0

This disables login check (-l 0) for automatic testing.

After start, you can programmatically visit all pages as follows:
- wget --recursive --no-parent http://localhost:3000

that in essence will navigate all the pages and save them to disk.
