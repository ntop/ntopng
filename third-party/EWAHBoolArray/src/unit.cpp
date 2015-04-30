/**
 * This code is released under the
 * Apache License Version 2.0 http://www.apache.org/licenses/.
 *
 * (c) Daniel Lemire, http://lemire.me/en/
 */
#include <stdio.h>
#include <fstream>
#include <string>
#include <vector>
#include "ewah.h"
#include "boolarray.h"

using namespace std;

static string testfailed = "---\ntest failed.\n\n\n\n\n\n";

// for Microsoft compilers
#if _MSC_VER >= 1400
#define unlink _unlink
#endif


template<class uword>
bool testGet() {
    cout << "[testing Get] sizeof(uword)=" << sizeof(uword) << endl;
    bool isOk = true;

    for (size_t gap = 29; gap < 10000; gap *= 10) {
        EWAHBoolArray<uword> x;
        for (uint32_t k = 0; k < 100; ++k)
            x.set(k * gap);
        for (size_t k = 0; k < 100 * gap; ++k)
            if (x.get(k)) {
                if (k % gap != 0) {
                    cout << "spotted an extra set bit at " << k << " gap = "
                            << gap << endl;
                    return false;
            }
        } else if (k % gap == 0) {
            cout<<
            "missed a set bit " << k
            << " gap = " << gap<<endl;
            return false;
        }
    }
    return isOk;
}


template<class uword>
bool testLucaDeri() {
    cout << "[testing LucaDeri] sizeof(uword)="<<sizeof(uword)<<endl;
    bool isOk = true;
    EWAHBoolArray<uword> bitset1;
    bitset1.set(1);
    bitset1.set(2);
    bitset1.set(2);
    bitset1.set(1000);
    bitset1.set(1001);
    if(bitset1.numberOfOnes() != 4) {
        cout << "Failed LucaDeri test"<<endl;
        isOk = false;
    }
    return isOk;
}

template<class uword>
bool testSetGet() {
    cout << "[testing EWAH set/get] sizeof(uword)="<<sizeof(uword)<<endl;
    EWAHBoolArray<uword> ewcb;
    uint32_t val[] = { 5, 4400, 44600, 55400, 1000000 };
    for (int k = 0; k < 5; ++k) {
      ewcb.set(val[k]);
    }
    size_t counter = 0;
    bool isOk = true;
    for (typename EWAHBoolArray<uword>::const_iterator i = ewcb.begin(); i
            != ewcb.end(); ++i) {
        if(val[counter++]!=*i) {
            cout<<"Failed test set/get"<<endl;
            isOk = false;
        }
    }
    return isOk;
}

template<class uword>
bool testRunningLengthWord() {
    cout << "[testing RunningLengthWord]" << endl;
    bool isOk(true);
    uword somenumber(0xABCD);
    RunningLengthWord<uword> rlw(somenumber);
    rlw.setRunningBit(true);
    if (rlw.getRunningBit() != true) {
        cout << "failed to set the running bit " << sizeof(uword) << endl;
        isOk = false;
    }
    for (uword myrl = 0; myrl
            <= RunningLengthWord<uword>::largestrunninglengthcount; myrl
            = static_cast<uword> (myrl
                    + RunningLengthWord<uword>::largestrunninglengthcount / 10)) {
        rlw.setRunningLength(myrl);
        if (rlw.getRunningBit() != true) {
            cout << "failed to set the running bit (2) " << sizeof(uword)
                    << endl;
            isOk = false;
        }
        if (rlw.getRunningLength() != myrl) {
            cout << "failed to set the running length " << sizeof(uword)
                    << endl;
            isOk = false;
        }
    }
    rlw.setRunningLength(12);
    for (uword mylw = 0; mylw <= RunningLengthWord<uword>::largestliteralcount; mylw
            = static_cast<uword> (mylw
                    + RunningLengthWord<uword>::largestliteralcount / 10)) {
        rlw.setNumberOfLiteralWords(mylw);
        if (rlw.getRunningBit() != true) {
            cout << "failed to set the running bit (3) " << sizeof(uword)
                    << endl;
            isOk = false;
        }
        if (rlw.getRunningLength() != 12) {
            cout << "failed to set the running length (2) " << sizeof(uword)
                    << endl;
            isOk = false;
        }
        if (rlw.getNumberOfLiteralWords() != mylw) {
            cout << "failed to set the LiteralWords " << mylw << " "
                    << sizeof(uword) << " " << rlw.getNumberOfLiteralWords()
                    << endl;
            isOk = false;
        }
    }
    rlw.setNumberOfLiteralWords(43);
    rlw.setRunningBit(false);
    if (rlw.getRunningBit() != false) {
        cout << "failed to set the running bit (4) " << sizeof(uword) << endl;
        isOk = false;
    }
    if (rlw.getRunningLength() != 12) {
        cout << "failed to set the running length (3) " << sizeof(uword)
                << endl;
        isOk = false;
    }
    if (rlw.getNumberOfLiteralWords() != 43) {
        cout << "failed to set the LiteralWords (2) " << sizeof(uword) << endl;
        isOk = false;
    }
    if (!isOk)
        cout << testfailed << endl;
    return isOk;
}

template<class uword>
bool testEWAHBoolArrayAppend() {
    cout << "[testing EWAHBoolArrayAppend]" << endl;
    bool isOk(true);
    uword zero = 0;
    uword specialval = 1UL + (1UL << 4) + (static_cast<uword> (1)
            << (sizeof(uword) * 8 - 1));
    uword notzero = static_cast<uword> (~zero);
    EWAHBoolArray<uword> myarray1;
    BoolArray<uword> ba1;
    myarray1.add(zero);
    ba1.add(zero);
    myarray1.add(zero);
    ba1.add(zero);
    myarray1.add(zero);
    ba1.add(zero);
    myarray1.add(specialval);
    ba1.add(specialval);
    myarray1.add(specialval);
    ba1.add(specialval);
    myarray1.add(notzero);
    ba1.add(notzero);
    myarray1.add(zero);
    ba1.add(zero);
    EWAHBoolArray<uword> myarray2;
    BoolArray<uword> ba2;
    myarray2.add(notzero);
    ba2.add(notzero);
    myarray2.add(zero);
    ba2.add(zero);
    myarray2.add(notzero);
    ba2.add(notzero);
    myarray2.add(specialval);
    ba2.add(specialval);
    myarray2.add(specialval);
    ba2.add(specialval);
    myarray2.add(notzero);
    ba2.add(notzero);
    BoolArray<uword> aggregate1(ba1);
    BoolArray<uword> aggregate2(ba2);
    aggregate1.append(ba2);
    aggregate2.append(ba1);
    EWAHBoolArray<uword> caggregate1;
    caggregate1.append(myarray1);
    EWAHBoolArray<uword> caggregate2;
    caggregate2.append(myarray2);
    caggregate1.append(myarray2);
    caggregate2.append(myarray1);
    if (caggregate1 != aggregate1) {
        cout << "aggregate 1 failed" << endl;
        isOk = false;
    }
    if (caggregate2 != aggregate2) {
        cout << "aggregate 2 failed" << endl;
        isOk = false;
    }
    if (!isOk)
        cout << testfailed << endl;
    return isOk;
}

// unit test contributed by Joerg Bukowski ✆
template<class uword>
bool testJoergBukowski() {
    cout << "[testing JoergBukowski]" << endl;
    bool isOk(true);
    vector<uint32_t> positions;
    positions.push_back(0);
    positions.push_back(36778);
    positions.push_back(51863);
    positions.push_back(134946);
    positions.push_back(137330);
    positions.push_back(147726);
    positions.push_back(147990);
    positions.push_back(151884);
    positions.push_back(156404);
    positions.push_back(158486);
    positions.push_back(159622);
    positions.push_back(163159);
    positions.push_back(164599);
    string indexfile("testingewahboolarray.bin");
    ::remove(indexfile.c_str());
    EWAHBoolArray<uword> myarray;
    for (vector<uint32_t>::const_iterator i = positions.begin(); i
            != positions.end(); ++i) {
        myarray.set(*i);
        ofstream out(indexfile.c_str(), ios::out | ios::binary);
        myarray.write(out);
        out.close();
        EWAHBoolArray<uword> recovered;
        ifstream in(indexfile.c_str(), ios::binary);
        recovered.read(in);
        in.close();
        vector < size_t > vals;
        recovered.appendSetBits(vals);
        if (vals.size() != static_cast<size_t> (i - positions.begin() + 1)) {
            cout << "failed to recover right number" << endl;
            isOk = false;
        }
        if (!equal(vals.begin(), vals.end(), positions.begin())) {
            cout << "failed to recover" << endl;
            isOk = false;
        }
        vals.clear();
        for (typename EWAHBoolArray<uword>::const_iterator j =
                recovered.begin(); j != recovered.end(); ++j)
            vals.push_back(static_cast<uint32_t> (*j));
        if (vals.size() != static_cast<size_t> (i - positions.begin() + 1)) {
            cout << "failed to recover right number -- iterator" << endl;
            isOk = false;
        }
        if (!equal(vals.begin(), vals.end(), positions.begin())) {
            cout << "failed to recover -- iterator" << endl;
            isOk = false;
        }
    }
    if (isOk)
        ::remove(indexfile.c_str());
    if (!isOk)
        cout << testfailed << endl;
    return isOk;
}

// unit test contributed by Phong Tran
bool testPhongTran() {
    cout << "[testing PhongTran]" << endl;
    bool isOk(true);
    EWAHBoolArray<uint32_t> myarray;
    for (uint32_t x = 0; x < 10000; x++) {
        myarray.add(x);
    }
    string indexfile("testingewahboolarray.bin");
    ::remove(indexfile.c_str());
    ofstream out(indexfile.c_str(), ios::out | ios::binary);
    myarray.write(out);
    out.close();
    EWAHBoolArray<uint32_t> lmyarray;
    ifstream in(indexfile.c_str(), ios::binary);
    lmyarray.read(in);
    in.close();
    EWAHBoolArrayIterator<uint32_t> i = myarray.uncompress();
    EWAHBoolArrayIterator<uint32_t> j = lmyarray.uncompress();
    while (i.hasNext() or j.hasNext()) {
        if ((!j.hasNext()) or (!i.hasNext())) {
            cout << "the two arrays don't have the same size?" << endl;
            isOk = false;
            break;
        }
        uint32_t val = i.next();
        uint32_t val2 = j.next();
        if (val != val2) {
            cout << "the two arrays differ" << endl;
            isOk = false;
            break;
        }
    }

    if (isOk)
        ::remove(indexfile.c_str());
    if (!isOk)
        cout << testfailed << endl;
    return isOk;
}

// another unit test contributed by Phong Tran
template<class uword>
bool testHemeury() {
    cout << "[testing Hemeury]" << endl;
    bool isOk(true);
    EWAHBoolArray<uword> test, test1, test2;
    for (uint32_t i = 0; i <= 10000; ++i) {
        test.set(i);
        test.logicaland(test1, test2);
        // because test1 is empty, test2 should be empty as well
        vector < size_t > vals;
        test2.appendSetBits(vals);
        if (vals.size() != 0) {
            isOk = false;
            cout << "failed!" << endl;
            break;
        }
    }
    return isOk;
}

// another unit test contributed by Phong Tran
template<class uword>
bool testPhongTran2() {
    cout << "[testing PhongTran2]" << endl;
    bool isOk(true);
    uword iTotal = static_cast<uword> (1000); // when 1000 does not fit in uword, then it will be casted
    EWAHBoolArray<uword> myarray;
    for (uword x = static_cast<uword> (100); x < iTotal; x++) {
        myarray.add(x);
    }
    string indexfile("testingewahboolarray.bin");
    ::remove(indexfile.c_str());
    ofstream out(indexfile.c_str(), ios::out | ios::binary);
    myarray.write(out);
    out.close();
    EWAHBoolArray<uword> lmyarray;
    ifstream in(indexfile.c_str(), ios::binary);
    lmyarray.read(in);
    in.close();
    if (!(myarray == lmyarray)) {
        cout << "bad news, they are not equal" << endl;
        cout << "size in bits: " << myarray.sizeInBits() << " vs. "
                << lmyarray.sizeInBits() << endl;
        isOk = false;
    }
    EWAHBoolArrayIterator<uword> i = myarray.uncompress();
    EWAHBoolArrayIterator<uword> j = lmyarray.uncompress();
    while (i.hasNext()) {
        if (!j.hasNext()) {
            cout << "the two arrays don't have the same size?" << endl;
            isOk = false;
            break;
        }
        uword val = i.next();
        uword val2 = j.next();
        if (val != val2) {
            cout << "the two arrays differ " << endl;
            isOk = false;
        }
    }
    if (isOk)
        ::remove(indexfile.c_str());
    if (!isOk)
        cout << testfailed << endl;
    return isOk;
}

template<class uword>
bool testEWAHBoolArray() {
    cout << "[testing EWAHBoolArray]" << endl;
    bool isOk(true);
    EWAHBoolArray<uword> myarray;
    BoolArray<uword> ba(10 * sizeof(uword) * 8);
    uword zero = 0;
    uword notzero = static_cast<uword> (~zero);
    myarray.add(zero);
    ba.setWord(0, zero);
    myarray.add(zero);
    ba.setWord(1, zero);
    myarray.add(zero);
    ba.setWord(2, zero);
    uword specialval = 1UL + (1UL << 4) + (static_cast<uword> (1)
            << (sizeof(uword) * 8 - 1));
    myarray.add(specialval);
    ba.setWord(3, specialval);
    myarray.add(notzero);
    ba.setWord(4, notzero);
    myarray.add(notzero);
    ba.setWord(5, notzero);
    myarray.add(notzero);
    ba.setWord(6, notzero);
    myarray.add(notzero);
    ba.setWord(7, notzero);
    myarray.add(specialval);
    ba.setWord(8, specialval);
    myarray.add(zero);
    ba.setWord(9, zero);
    if (myarray.sizeInBits() != 10 * sizeof(uword) * 8) {
        cout << "expected " << 10 * sizeof(uword) * 8 << " bits but found "
                << myarray.sizeInBits() << endl;
        isOk = false;
    }
    string indexfile("testingewahboolarray.bin");
    ::remove(indexfile.c_str());
    ofstream out(indexfile.c_str(), ios::out | ios::binary);
    myarray.write(out);
    out.close();
    EWAHBoolArray<uword> lmyarray;
    ifstream in(indexfile.c_str(), ios::binary);
    lmyarray.read(in);
    in.close();
    if (!(myarray == lmyarray)) {
        cout << "bad news, they are not equal" << endl;
        cout << "size in bits: " << myarray.sizeInBits() << " vs. "
                << lmyarray.sizeInBits() << endl;
        isOk = false;
    }
    EWAHBoolArrayIterator<uword> i = myarray.uncompress();
    EWAHBoolArrayIterator<uword> j = lmyarray.uncompress();
    uint32_t k = 0;
    while (i.hasNext()) {
        if (!j.hasNext()) {
            cout << "the two arrays don't have the same size?" << endl;
            isOk = false;
            break;
        }
        uword val = i.next();
        uword val2 = j.next();
        uword valref = ba.getWord(k++);
        if (val != valref) {
            cout << "the two arrays differ from uncompressed array at " << k
                    << " " << val << " " << val2 << " " << valref << endl;
            isOk = false;
        }
        if (val != val2) {
            cout << "the two arrays differ at " << k << " " << val << " "
                    << val2 << " " << valref << endl;
            isOk = false;
        }
    }
    if (isOk)
        ::remove(indexfile.c_str());
    if (!isOk)
        cout << testfailed << endl;
    return isOk;
}

template<class uword>
bool testNot() {
    cout << "[testing Not]" << endl;
    bool isOk = true;
    EWAHBoolArray<uword> bitset;
    for (int i = 0; i <= 184; i++) {
        bitset.set(i);
    }
    if (bitset.numberOfOnes() != 185) {
        isOk = false;
    }

    bitset.inplace_logicalnot();
    if (bitset.numberOfOnes() != 0) {
        isOk = false;
    }
    return isOk;
}

template<class uword>
bool testSTLCompatibility() {
    cout << "[testing STL compatibility]" << endl;
    bool isOk = true;
    EWAHBoolArray<uword> bitset1;
    bitset1.set(1);
    bitset1.set(2);
    bitset1.set(1000);
    bitset1.set(1001);
    vector<EWAHBoolArray<uword> > testVec(1);
    testVec[0].set(1);
    testVec[0].set(2);
    testVec[0].set(1000);
    testVec[0].set(1001);
    if (testVec[0] != bitset1) {
        isOk = false;
    }
    return isOk;
}

template<class uword>
bool testEWAHBoolArrayLogical() {
    cout << "[testing EWAHBoolArrayLogical] word size = "<< sizeof(uword) << endl;
    bool isOk(true);
    EWAHBoolArray<uword> myarray1;
    EWAHBoolArray<uword> myarray2;
    const uint32_t N = 16;
    uword allones =  static_cast<uword> (~0LL);
    uword x1[N] = { 1, 0, 54, 24, 145, 0, 0, 0, allones, allones, allones, 43, 0, 0, 0, 1 };
    uword x2[N] = { allones, 1, 0, 0, 0, 0, 0, 0, 0, allones, allones, allones, 0,4, 0, 0 };
    uword xand[N];
    uword xxor[N];

    for (uint32_t k = 0; k < N; ++k) {
        myarray1.add(x1[k]);
        myarray2.add(x2[k]);
        xand[k] = static_cast<uword>(x1[k] & x2[k]);
        xxor[k] = static_cast<uword>(x1[k] | x2[k]);
    }
    EWAHBoolArray<uword> myand;
    EWAHBoolArray<uword> myor;
    EWAHBoolArray<uword> myxor;
    EWAHBoolArray<uword> myxoralt;

    myarray1.logicaland(myarray2, myand);
    myarray1.logicalor(myarray2, myor);
    myarray1.logicalxor(myarray2, myxor);
    EWAHBoolArray<uword> tmp(myand);
    tmp.inplace_logicalnot();
    myor.logicaland(tmp, myxoralt);
    if(myxoralt != myxor) {
        isOk = false;
        if (!isOk)
            cout << testfailed << endl;
        return isOk;
    }

    EWAHBoolArrayIterator<uword> i = myand.uncompress();
    EWAHBoolArrayIterator<uword> j = myor.uncompress();
    EWAHBoolArrayIterator<uword> it1 = myarray1.uncompress();
    EWAHBoolArrayIterator<uword> it2 = myarray2.uncompress();
    for (uint32_t k = 0; k < N; ++k) {
        const uword m1 = it1.next();
        const uword m2 = it2.next();
        if (!i.hasNext()) {
            cout << "type 1 error" << endl;
            isOk = false;
            break;
        }
        if (!j.hasNext()) {
            cout << "type 3 error" << endl;
            isOk = false;
            break;
        }

        if (i.next() != xand[k]) {
            cout << "type 4 error" << endl;
            isOk = false;
            break;
        }
        const uword jor = j.next();
        if (jor != xxor[k]) {
            cout << m1 << " or " << m2 << " = " << xxor[k] << " but got "
                    << jor << endl;
            cout << "type 6 error OR" << endl;
            isOk = false;
            break;
        }
    }
    if (!isOk)
        cout << testfailed << endl;
    return isOk;
}

#define N_ENTRIES(arr) (sizeof(arr) / sizeof((arr)[0]))

template<class uword>
void init( EWAHBoolArray<uword>& ba, size_t N, size_t x[] )
{
    for ( size_t ix= 0; ix < N; ++ix )
        ba.set( x[ix] );
}


template<class uword>
std::ostream& operator << ( std::ostream& os, const EWAHBoolArray<uword>& ba )
{
    os << " (" << ba.sizeInBits() << ") ";
    typename EWAHBoolArray<uword>::const_iterator it = ba.begin(), last = ba.end();
    for ( int ix = 0; it != last; ++it, ++ix ) {
        if ( ix > 0 )
            os << ", ";
        os << *it;
    }
    os << endl;

    size_t ixBit = 0;
    const uword wordInBits = EWAHBoolArray<uword>::wordinbits;

    EWAHBoolArrayRawIterator<uword> ir = ba.raw_iterator();
    for ( int jx = 0; ir.hasNext(); ++jx )
    {
        BufferedRunningLengthWord<uword> &brlw( ir.next() );
        string tf = ( brlw.getRunningBit() ? "true" : "false" );
        size_t runBits = static_cast<size_t>( brlw.getRunningLength() * wordInBits );
        size_t litBits = static_cast<size_t>( brlw.getNumberOfLiteralWords() * wordInBits );
        os << jx << ", " << ixBit << ": "
            << tf << " for " << brlw.getRunningLength() << " words(" << runBits << " bits), "
            << brlw.getNumberOfLiteralWords() << " literals (" << litBits << " bits)" << endl;
        ixBit += (runBits + litBits);
    }
    string eq = ( ixBit == ba.sizeInBits() ? "==" : "!=" );
    os << "[" << ixBit << eq << ba.sizeInBits() << "]" << endl;
    return os;
}


template<class uword>
bool testSerialization() {
    cout << "[testing Serialization] word size = " << sizeof(uword)<< endl;
    EWAHBoolArray<uword> bitmap;
    for(int i = 0; i < 1<<31; i= 2*i +3) {
        bitmap.set(static_cast<size_t>(i));
    }
    stringstream ss;
    EWAHBoolArray<uword> lmyarray;
    for (int k = 0; k < 10; ++k) {
        bitmap.write(ss);

        lmyarray.read(ss);
        if (lmyarray != bitmap) {
            return false;
        }
        typename EWAHBoolArray<uword>::const_iterator i = bitmap.begin();
        typename EWAHBoolArray<uword>::const_iterator j = lmyarray.begin();
        for (; i != bitmap.end(); ++i, ++j) {
            if (*i != *j)
                return false;
        }
    }
    return true;
}

template<class uword>
bool testEWAHBoolArrayLogical2()
{
    bool ok = true;
    cout << "[testing EWAHBoolArrayLogical2] word size = " << sizeof(uword)<< endl;

    EWAHBoolArray<uword> ba1, ba2, baAND, baOR, baXOR, testAND, testOR, testXOR;

    size_t x1[] = { 1, 3, 24, 54, 145, 3001, 3002, 3004, 10003 };
    size_t x2[] = { 2, 3, 22, 57, 199, 3000, 3002, 10003, 999999 };
    size_t x1_AND_x2[] = { 3, 3002, 10003 };
    size_t x1_OR_x2[] = { 1, 2, 3, 22, 24, 54, 57, 145, 199, 3000, 3001, 3002, 3004, 10003, 999999 };
    size_t x1_XOR_x2[] = { 1, 2,  22, 24, 54, 57, 145, 199, 3000, 3001,  3004,  999999 };

    init( ba1, N_ENTRIES(x1), x1 );
    init( ba2, N_ENTRIES(x2), x2 );
    init( baAND, N_ENTRIES(x1_AND_x2), x1_AND_x2 );
    init( baOR, N_ENTRIES(x1_OR_x2), x1_OR_x2 );
    init( baXOR, N_ENTRIES(x1_XOR_x2), x1_XOR_x2 );

    // Make 'em all the same size in bits, so equality operators should work.
    ba1.makeSameSize( ba2 );
    baAND.makeSameSize( ba2 );
    baOR.makeSameSize( ba2 );
    baXOR.makeSameSize( ba2 );

    ba1.logicaland( ba2, testAND );
    ba1.logicalor( ba2, testOR );
    ba1.logicalxor( ba2, testXOR );

    if ( baAND != testAND ) {
        cout << " AND failed:" << endl;
        cout << "Expected: " << baAND << endl;
        cout << "Encountered: " << testAND << endl;
        ok = false;
    }
    if ( baOR != testOR ) {
        cout << " OR failed: " << endl;
        cout << "Expected: " << baOR << endl;
        cout << "Encountered: " << testOR << endl;
        ok = false;
    }
    if ( baXOR != testXOR ) {
        cout << " XOR failed: " << endl;
        cout << "Expected: " << baXOR << endl;
        cout << "Encountered: " << testXOR << endl;
        ok = false;
    }

    // Verify order of operands has no effect on results
    ba2.logicaland( ba1, testAND );
    ba2.logicalor( ba1, testOR );
    ba2.logicalxor( ba1, testXOR );

    if ( baAND != testAND ) {
        cout << " AND failed (2):" << endl;
        cout << "Expected: " << baAND << endl;
        cout << "Encountered: " << testAND << endl;
        ok = false;
    }
    if ( baOR != testOR ) {
        cout << " OR failed (2): " << endl;
        cout << "Expected: " << baOR << endl;
        cout << "Encountered: " << testOR << endl;
        ok = false;
    }
    if ( baXOR != testXOR ) {
            cout << " XOR failed (2): " << endl;
            cout << "Expected: " << baXOR << endl;
            cout << "Encountered: " << testXOR << endl;
            ok = false;
    }
    if ( !ok )
        cout << testfailed << endl;
    return ok;
}

void tellmeaboutmachine() {
    cout << "number of bytes in ostream::pos_type = "
            << sizeof(ostream::pos_type) << endl;
    cout << "number of bytes in size_t = " << sizeof(size_t) << endl;
    cout << "number of bytes in int = " << sizeof(int) << endl;
    cout << "number of bytes in long = " << sizeof(long) << endl;
#if  __LITTLE_ENDIAN__
    cout << "you have little endian machine" << endl;
#endif
#if  __BIG_ENDIAN__
    cout << "you have a big endian machine" << endl;
#endif
#if __CHAR_BIT__
    if (__CHAR_BIT__ != 8)
    cout << "on your machine, chars don't have 8bits???" << endl;
#endif
#if __GNUG__
    cout << "GNU GCC compiler detected." << endl;
#else
    cout << "Non-GCC compiler." << endl;
#endif

}

int main(void) {
    int failures = 0;
    if (!testSerialization<uint16_t> ())
            ++failures;
    if (!testSerialization<uint32_t> ())
            ++failures;
    if (!testSerialization<uint64_t> ())
            ++failures;

    if (!testGet<uint16_t> ())
        ++failures;
    if (!testGet<uint32_t> ())
        ++failures;
    if (!testGet<uint64_t> ())
        ++failures;

    if (!testLucaDeri<uint16_t> ())
        ++failures;
    if (!testLucaDeri<uint32_t> ())
        ++failures;
    if (!testLucaDeri<uint64_t> ())
        ++failures;

    if (!testSetGet<uint16_t> ())
        ++failures;
    if (!testSetGet<uint32_t> ())
        ++failures;
    if (!testSetGet<uint64_t> ())
        ++failures;


    if (!testPhongTran())
        ++failures;

    if (!testSTLCompatibility<uint16_t> ())
        ++failures;
    if (!testSTLCompatibility<uint32_t> ())
        ++failures;
    if (!testSTLCompatibility<uint64_t> ())
        ++failures;

    if (!testHemeury<uint16_t> ())
        ++failures;
    if (!testHemeury<uint32_t> ())
        ++failures;
    if (!testHemeury<uint64_t> ())
        ++failures;

    if (!testPhongTran2<uint16_t> ())
        ++failures;
    if (!testPhongTran2<uint32_t> ())
        ++failures;
    if (!testPhongTran2<uint64_t> ())
        ++failures;
    if (!testRunningLengthWord<uint16_t> ())
        ++failures;
    if (!testRunningLengthWord<uint32_t> ())
        ++failures;
    if (!testRunningLengthWord<uint64_t> ())
        ++failures;
    if (!testEWAHBoolArray<uint16_t> ())
        ++failures;
    if (!testEWAHBoolArray<uint32_t> ())
        ++failures;
    if (!testEWAHBoolArray<uint64_t> ())
        ++failures;

    if (!testEWAHBoolArrayLogical<uint16_t> ())
        ++failures;
    if (!testEWAHBoolArrayLogical<uint32_t> ())
        ++failures;
    if (!testEWAHBoolArrayLogical<uint64_t> ())
        ++failures;

    if (!testEWAHBoolArrayLogical2<uint16_t> ())
        ++failures;
    if (!testEWAHBoolArrayLogical2<uint32_t> ())
        ++failures;
    if (!testEWAHBoolArrayLogical2<uint64_t> ())
        ++failures;

    if (!testEWAHBoolArrayAppend<uint16_t> ())
        ++failures;
    if (!testEWAHBoolArrayAppend<uint32_t> ())
        ++failures;
    if (!testEWAHBoolArrayAppend<uint64_t> ())
        ++failures;

    if (!testJoergBukowski<uint16_t> ())
        ++failures;
    if (!testJoergBukowski<uint32_t> ())
        ++failures;
    if (!testJoergBukowski<uint64_t> ())
        ++failures;

    tellmeaboutmachine();
    if (failures == 0) {
        cout << "Your code is ok." << endl;
        return EXIT_SUCCESS;
    }
    cout << "Got " << failures << " failed tests!" << endl;
    return EXIT_FAILURE;
}
