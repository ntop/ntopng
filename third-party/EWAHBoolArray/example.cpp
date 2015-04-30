/**
 * This code is released under the
 * Apache License Version 2.0 http://www.apache.org/licenses/.
 *
 * (c) Daniel Lemire, http://lemire.me/en/
 */
#include <stdlib.h>
#include "ewah.h"

template<class bitmap>
void demo() {
	bitmap bitset1 = bitmap::bitmapOf(9   , 1, 2, 1000, 1001, 1002, 1003, 1007, 1009,
			100000);
	cout << "first bitset : " << bitset1 << endl;
	bitmap bitset2 = bitmap::bitmapOf(5   , 1, 3, 1000, 1007, 100000);
	cout << "second bitset : " << bitset2 << endl;
	bitmap orbitset;
	bitmap andbitset;
	bitmap xorbitset;
	bitset1.logicalor(bitset2, orbitset);
	bitset1.logicaland(bitset2, andbitset);
	bitset1.logicalxor(bitset2, xorbitset);
	// we will display the or
	cout << "logical and: " << andbitset << endl;
	cout << "memory usage of compressed bitset = " << andbitset.sizeInBytes()
			<< " bytes" << endl;
	// we will display the and
	cout << "logical or: " << orbitset << endl;
	cout << "memory usage of compressed bitset = " << orbitset.sizeInBytes()
			<< " bytes" << endl;
	// we will display the xor
	cout << "logical xor: " << xorbitset << endl;
	cout << "memory usage of compressed bitset = " << xorbitset.sizeInBytes()
			<< " bytes" << endl;
	cout << endl;
}


template<class bitmap>
void demoSerialization() {
    stringstream ss;
    bitmap myarray;
    myarray.add(234321);// this is not the same as "set(234321)"!!!
    myarray.add(0);
    myarray.add(0);
    myarray.add(999999);
    //
    cout<<"Writing: "<<myarray<<endl;
    myarray.write(ss);
    //
    bitmap lmyarray;
    lmyarray.read(ss);
    cout<<"Read back: "<<lmyarray<<endl;
    //
    if (lmyarray == myarray)
        cout << "serialization works" << endl;
    else
        cout << "serialization does not works" << endl;
}


int main(void) {
	cout<<endl;
	cout<<"====uncompressed example===="<<endl;
	cout<<endl;
	demo<BoolArray<uint32_t> >();
	demoSerialization<BoolArray<uint32_t> >();

	cout<<endl;
	cout<<"====compressed example===="<<endl;
	cout<<endl;
	demo<EWAHBoolArray<uint32_t> >();
	demoSerialization<EWAHBoolArray<uint32_t> >();
    return EXIT_SUCCESS;
}
