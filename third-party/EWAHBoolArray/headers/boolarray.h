/**
 * This code is released under the
 * Apache License Version 2.0 http://www.apache.org/licenses/.
 *
 * (c) Daniel Lemire, http://lemire.me/en/
 */

#ifndef BOOLARRAY_H
#define BOOLARRAY_H
#include <iso646.h> // mostly for Microsoft compilers
#include <stdarg.h>
#include <cassert>
#include <iostream>
#include <vector>
#include <stdexcept>
#include <sstream>

using namespace std;

/**
 * A dynamic bitset implementation. (without compression).
 */
template<class uword = uint32_t>
class BoolArray {
public:
    BoolArray(const size_t n, const uword initval = 0) :
        buffer(n / wordinbits + (n % wordinbits == 0 ? 0 : 1), initval),
                sizeinbits(n) {
    }

    BoolArray() :
        buffer(), sizeinbits(0) {
    }

    BoolArray(const BoolArray & ba) :
        buffer(ba.buffer), sizeinbits(ba.sizeinbits) {
    }
    static BoolArray bitmapOf(size_t n, ...) {
    	BoolArray ans;
		va_list vl;
		va_start(vl, n);
		for (size_t i = 0; i < n; i++) {
			ans.set(static_cast<size_t>(va_arg(vl, int)));
		}
		va_end(vl);
		return ans;
	}
    size_t sizeInBytes() const {
        return buffer.size() * sizeof(uword);
    }

    void read(istream & in) {
        sizeinbits = 0;
        in.read(reinterpret_cast<char *> (&sizeinbits), sizeof(sizeinbits));
        buffer.resize(
                sizeinbits / wordinbits
                        + (sizeinbits % wordinbits == 0 ? 0 : 1));
        if(buffer.size() == 0) return;
        in.read(reinterpret_cast<char *> (&buffer[0]),
                static_cast<streamsize>(buffer.size() * sizeof(uword)));
    }

    void readBuffer(istream & in, const size_t size) {
        buffer.resize(size);
        sizeinbits = size * sizeof(uword) * 8;
        if(buffer.empty()) return;
        in.read(reinterpret_cast<char *> (&buffer[0]),
                buffer.size() * sizeof(uword));
    }

    void setSizeInBits(const size_t sizeib) {
        sizeinbits = sizeib;
    }

    void write(ostream & out) {
        write(out, sizeinbits);
    }

    void write(ostream & out, const size_t numberofbits) const {
        const size_t size = numberofbits / wordinbits + (numberofbits
                % wordinbits == 0 ? 0 : 1);
        out.write(reinterpret_cast<const char *> (&numberofbits),
                sizeof(numberofbits));
        if(numberofbits == 0) return;
        out.write(reinterpret_cast<const char *> (&buffer[0]),
        		static_cast<streamsize>(size * sizeof(uword)));
    }

    void writeBuffer(ostream & out, const size_t numberofbits) const {
        const size_t size = numberofbits / wordinbits + (numberofbits
                % wordinbits == 0 ? 0 : 1);
        if(size == 0) return;
        assert(buffer.size() >= size);
        out.write(reinterpret_cast<const char *> (&buffer[0]),
                size * sizeof(uword));
    }

    size_t sizeOnDisk() const {
        size_t size = sizeinbits / wordinbits
                + (sizeinbits % wordinbits == 0 ? 0 : 1);
        return sizeof(sizeinbits) + size * sizeof(uword);
    }

    BoolArray& operator=(const BoolArray & x) {
        this->buffer = x.buffer;
        this->sizeinbits = x.sizeinbits;
        return *this;
    }

    bool operator==(const BoolArray & x) const {
        if (sizeinbits != x.sizeinbits)
            return false;
        assert(buffer.size() == x.buffer.size());
        for (size_t k = 0; k < buffer.size(); ++k)
            if (buffer[k] != x.buffer[k])
                return false;
        return true;
    }

    bool operator!=(const BoolArray & x) const {
        return !operator==(x);
    }

    void setWord(const size_t pos, const uword val) {
        assert(pos < buffer.size());
        buffer[pos] = val;
    }

    void add(const uword val) {
        if (sizeinbits % wordinbits != 0)
            throw invalid_argument("you probably didn't want to do this");
        sizeinbits += wordinbits;
        buffer.push_back(val);
    }

    uword getWord(const size_t pos) const {
        assert(pos < buffer.size());
        return buffer[pos];
    }

    /**
     * set to true (whether it was already set to true or not)
     *
     * This is an expensive (random access) API, you really ought to
     * prepare a new word and then append it.
     */
    void set(const size_t pos) {
    	if(pos >= sizeinbits) padWithZeroes(pos+1);
        buffer[pos / wordinbits] |= (static_cast<uword> (1) << (pos
                % wordinbits));
    }

    /**
     * set to false (whether it was already set to false or not)
     *
     * This is an expensive (random access) API, you really ought to
     * prepare a new word and then append it.
     */
    void unset(const size_t pos) {
    	if(pos < sizeinbits)
    		buffer[pos / wordinbits] |= ~(static_cast<uword> (1) << (pos
                % wordinbits));
    }

    /**
     * true of false? (set or unset)
     */
    bool get(const size_t pos) const {
        assert(pos / wordinbits < buffer.size());
        return (buffer[pos / wordinbits] & (static_cast<uword> (1) << (pos
                % wordinbits))) != 0;
    }



    /**
     * set all bits to 0
     */
    void reset() {
    	if(buffer.size() > 0)  memset(&buffer[0], 0, sizeof(uword) * buffer.size());
        sizeinbits = 0;
    }

    size_t sizeInBits() const {
        return sizeinbits;
    }

    ~BoolArray() {
    }

    void logicaland(BoolArray & ba, BoolArray & out) {
		makeSameSize(ba);
		makeSameSize(out);
		for (size_t i = 0; i < buffer.size(); ++i)
			out.buffer[i] = buffer[i] & ba.buffer[i];
	}

	void inplace_logicaland(BoolArray & ba) {
		makeSameSize(ba);
		for (size_t i = 0; i < buffer.size(); ++i)
			buffer[i] = buffer[i] & ba.buffer[i];
	}

	void logicalor(BoolArray & ba, BoolArray & out) {
		makeSameSize(ba);
		makeSameSize(out);
		for (size_t i = 0; i < buffer.size(); ++i)
			out.buffer[i] = buffer[i] | ba.buffer[i];
	}

	void inplace_logicalor(const BoolArray & ba) {
		makeSameSize(ba);
		for (size_t i = 0; i < buffer.size(); ++i)
			buffer[i] = buffer[i] | ba.buffer[i];
	}

	void logicalxor(BoolArray & ba, BoolArray & out) {
		makeSameSize(ba);
		makeSameSize(out);
		for (size_t i = 0; i < buffer.size(); ++i)
			out.buffer[i] = buffer[i] ^ ba.buffer[i];
	}

	void inplace_logicalxor(const BoolArray & ba) {
		makeSameSize(ba);
		for (size_t i = 0; i < buffer.size(); ++i)
			buffer[i] = buffer[i] ^ ba.buffer[i];
	}

	void logicalnot(BoolArray & out) {
		makeSameSize(out);
		for (size_t i = 0; i < buffer.size(); ++i)
			out.buffer[i] = ~buffer[i];
	}
	void inplace_logicalnot() {
		for (size_t i = 0; i < buffer.size(); ++i)
			buffer[i] = ~buffer[i];
	}

    inline void printout(ostream &o = cout) {
        for (size_t k = 0; k < sizeinbits; ++k)
            o << get(k) << " ";
        o << endl;
    }

    /**
	 * Make sure the two bitmaps have the same size (padding with zeroes
	 * if necessary). It has constant running time complexity.
	 */
	void makeSameSize(BoolArray & a) {
		if (a.sizeinbits < sizeinbits)
			a.padWithZeroes(sizeinbits);
		else if (sizeinbits < a.sizeinbits)
			padWithZeroes(a.sizeinbits);
	}


    /**
     * make sure the size of the array is totalbits bits by padding with zeroes.
     * returns the number of words added (storage cost increase)
     */
    size_t padWithZeroes(const size_t totalbits) {
    	size_t currentwordsize = (sizeinbits + sizeof(uword) - 1) / sizeof(uword);
    	size_t neededwordsize = (totalbits + sizeof(uword) - 1) / sizeof(uword);
    	assert(neededwordsize >= currentwordsize);
    	buffer.resize(neededwordsize);
    	sizeinbits = totalbits;
    	return static_cast<size_t>(neededwordsize - currentwordsize);

    }

    void append(const BoolArray & a);

    enum {
        wordinbits = sizeof(uword) * 8
    };

    vector<size_t> toArray() const {
		vector<size_t> ans;
		for (size_t k = 0; k < buffer.size(); ++k) {
			const uword myword = buffer[k];
			for (size_t offset = 0; offset < sizeof(uword) * 8; ++offset) {
				if ((myword >> offset) == 0)
					break;
				offset += numberOfTrailingZeros((myword >> offset));
				ans.push_back(sizeof(uword) * 8 * k + offset);
			}
		}
		return ans;
	}

    /**
     * Transform into a string that presents a list of set bits.
     * The running time is linear in the size of the bitmap.
     */
    operator string() const {
		stringstream ss;
		ss << *this;
		return ss.str();

	}

    friend ostream& operator<< (ostream &out, const BoolArray &a) {
    	vector<size_t> v = a.toArray();
		out <<"{";
		for (vector<size_t>::const_iterator i = v.begin(); i != v.end(); ) {
			out << *i;
			++i;
			if( i != v.end())
				out << ",";
		}
		out <<"}";
		return out;

    	return (out << static_cast<string>(a));
    }
private:
    vector<uword> buffer;
    size_t sizeinbits;

};

template<class uword>
void BoolArray<uword>::append(const BoolArray & a) {
    if (sizeinbits % wordinbits == 0) {
        buffer.insert(buffer.end(), a.buffer.begin(), a.buffer.end());
    } else {
        throw invalid_argument("Cannot append if parent does not meet boundary");
    }
    sizeinbits += a.sizeinbits;
}

#endif
