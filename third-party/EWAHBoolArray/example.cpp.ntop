/**
 * This code is released under the
 * Apache License Version 2.0 http://www.apache.org/licenses/.
 *
 * (c) Daniel Lemire, http://lemire.me/en/
 */
#include <stdlib.h>
#include <fstream>
#include "ewah.h"

void demoSerialization() {
    stringstream ss;
    EWAHBoolArray<uint64_t> myarray;
    myarray.add(234321);
    myarray.add(0);
    myarray.add(0);
    myarray.add(999999);
    //
    myarray.write(ss);
    //
    EWAHBoolArray<uint64_t> lmyarray;
    lmyarray.read(ss);
    //
    if (lmyarray == myarray)
        cout << "serialization work" << endl;
    else
        cout << "serialization does not work" << endl;

    /* Luca */
    /* test dump */
    ofstream myFile("dump");
    myFile << ss.str();
    myFile.close();

    /* test read */
    EWAHBoolArray<uint64_t> myinarray;
    stringstream sin;
    ifstream myInFile("dump");
    sin << myInFile.rdbuf();
    myinarray.read(sin);
    myInFile.close();

    if (lmyarray == myinarray)
        cout << "file serialization works" << endl;
    else
        cout << "file serialization does not work" << endl;
    
    cout << "Number of ones:  " << myinarray.numberOfOnes() << endl;
    cout << "Disk size:       " << myinarray.sizeOnDisk() << endl;
    cout << "Compressed size: " << myinarray.computeStatistics().getCompressedSize() << endl;

}

int main(void) {
  EWAHBoolArray<uint32_t> bitset1;
    bitset1.set(1);
    bitset1.set(2);
    bitset1.set(1000);
    bitset1.set(1001);
    bitset1.set(1002);
    bitset1.set(1003);
    bitset1.set(1007);
    bitset1.set(1009);
    bitset1.set(100000);
    cout << "first bitset : " << endl;
    for (EWAHBoolArray<uint32_t>::const_iterator i = bitset1.begin(); i
            != bitset1.end(); ++i)
        cout << *i << endl;
    cout << endl;
    EWAHBoolArray<uint32_t> bitset2;
    bitset2.set(1);
    bitset2.set(3);
    bitset2.set(1000);
    bitset2.set(1007);
    bitset2.set(100000);
    cout << "second bitset : " << endl;
    for (EWAHBoolArray<uint32_t>::const_iterator i = bitset2.begin(); i
            != bitset2.end(); ++i)
        cout << *i << endl;
    cout << endl;
    EWAHBoolArray<uint32_t> orbitset;
    EWAHBoolArray<uint32_t> andbitset;
    bitset1.logicalor(bitset2, orbitset);
    bitset1.logicaland(bitset2, andbitset);
    // we will display the or
    cout << "logical and: " << endl;
    for (EWAHBoolArray<uint32_t>::const_iterator i = andbitset.begin(); i
            != andbitset.end(); ++i)
        cout << *i << endl;
    cout << endl;
    cout << "memory usage of compressed bitset = " << andbitset.sizeInBytes()
            << " bytes" << endl;
    cout << endl;
    // we will display the and
    cout << "logical or: " << endl;
    for (EWAHBoolArray<uint32_t>::const_iterator i = orbitset.begin(); i
            != orbitset.end(); ++i)
        cout << *i << endl;
    cout << endl;
    cout << endl;
    cout << "memory usage of compressed bitset = " << orbitset.sizeInBytes()
            << " bytes" << endl;
    cout << endl;
    demoSerialization();
    return EXIT_SUCCESS;
}
