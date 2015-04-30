/**
 * This code is released under the
 * Apache License Version 2.0 http://www.apache.org/licenses/.
 *
 * (c) Daniel Lemire, http://lemire.me/en/
 */

#include <algorithm>
#include <vector>
#include <set>
#ifdef _MSC_VER
#include <winsock2.h>
#else
#include <sys/time.h>
#endif
#include "ewah.h"
using namespace std;

/**
 *  Mersenne twister - random number generator.
 *  Generate uniform distribution of 32 bit integers with the MT19937 algorithm.
 * source: http://bannister.us/weblog/?s=Mersenne
 */
class ZRandom {

private:
    enum {
        N = 624, M = 397
    };
    unsigned int MT[N + 1];
    unsigned int* map[N];
    int nValues;

public:
    ZRandom(unsigned int iSeed = 20070102);
    void seed(unsigned iSeed);
    unsigned int getValue();
    unsigned int getValue(const uint32_t MaxValue);
    double getDouble();
    bool test(const double p);

};

ZRandom::ZRandom(unsigned iSeed) :
    nValues(0) {
    seed(iSeed);
}

void ZRandom::seed(unsigned iSeed) {
    nValues = 0;
    // Seed the array used in random number generation.
    MT[0] = iSeed;
    for (int i = 1; i < N; ++i) {
        MT[i] = 1 + (69069 * MT[i - 1]);
    }
    // Compute map once to avoid % in inner loop.
    for (int i = 0; i < N; ++i) {
        map[i] = MT + ((i + M) % N);
    }
}

inline bool ZRandom::test(const double p) {
    return getDouble() <= p;
}
inline double ZRandom::getDouble() {
    return double(getValue()) * (1.0 / 4294967296.0);
}

unsigned int ZRandom::getValue(const uint32_t MaxValue) {
    unsigned int used = MaxValue;
    used |= used >> 1;
    used |= used >> 2;
    used |= used >> 4;
    used |= used >> 8;
    used |= used >> 16;

    // Draw numbers until one is found in [0,n]
    unsigned int i;
    do
        i = getValue() & used; // toss unused bits to shorten search
    while (i > MaxValue);
    return i;
}

unsigned int ZRandom::getValue() {
    if (0 == nValues) {
        MT[N] = MT[0];
        for (int i = 0; i < N; ++i) {
            register unsigned y = (0x80000000 & MT[i]) | (0x7FFFFFFF
                    & MT[i + 1]);
            register unsigned v = *(map[i]) ^ (y >> 1);
            if (1 & y)
                v ^= 2567483615;
            MT[i] = v;
        }
        nValues = N;
    }
    unsigned int y = MT[N - nValues--];
    y ^= y >> 11;
    y ^= (y << 7) & 2636928640U;
    y ^= (y << 15) & 4022730752U;
    y ^= y >> 18;
    return y;
}

class UniformDataGenerator {
public:
    UniformDataGenerator(unsigned int seed = static_cast<unsigned int>(time(NULL))) :
        rand(seed) {
    }

    vector<uint32_t> generateDenseUniform(uint32_t N, uint32_t Max) {
        return generateUniform(N, Max);
    }
    vector<uint32_t> generateSparseUniform(uint32_t N, uint32_t Max) {
        return generateUniform(N, Max);
    }

    vector<uint32_t> generateUniform(uint32_t N, uint32_t Max) {
        vector<uint32_t> ans;
        if (N > Max)
            throw runtime_error("not possible");
        if (N == Max) {
            for (uint32_t k = 0; k < Max; ++k)
                ans.push_back(k);
            assert(ans.back() < Max);
            return ans;
        }
        if (N > Max / 2) {
            set<uint32_t> s;
            while (s.size() < N)
                s.insert(rand.getValue(Max - 1));
            ans.assign(s.begin(), s.end());
            return ans;
        }
        while (ans.size() < N) {
            while (ans.size() < N) {
                ans.push_back(rand.getValue(Max - 1));
            }
            sort(ans.begin(), ans.end());
            vector<uint32_t>::iterator it = unique(ans.begin(), ans.end());
            ans.resize(static_cast<uint32_t>(it - ans.begin()));
        }
        return ans;
    }

    ZRandom rand;

};

class ClusteredDataGenerator {
public:
    UniformDataGenerator unidg;
    ClusteredDataGenerator(
            unsigned int seed = static_cast<unsigned int> (time(NULL))) :
        unidg(seed) {
    }

    vector<uint32_t> generateDenseClustered(uint32_t N, uint32_t Max) {
        return generateClustered(N, Max);
    }
    vector<uint32_t> generateSparseClustered(uint32_t N, uint32_t Max) {
        return generateClustered(N, Max);
    }

    template<class iterator>
    void fillUniform(iterator begin, iterator end, uint32_t Min, uint32_t Max) {
        vector<uint32_t> v = unidg.generateUniform(
                static_cast<uint32_t> (end - begin), Max - Min);
        for (uint32_t k = 0; k < v.size(); ++k)
            begin[k] = Min + v[k];
    }

    template<class iterator>
    void fillClustered(iterator begin, iterator end, uint32_t Min, uint32_t Max) {
        const uint32_t N = static_cast<uint32_t> (end - begin);
        const uint32_t range = Max - Min;
        if ((range == N) or (N <= 10)) {
            fillUniform(begin, end, Min, Max);
            return;
        }
        const uint32_t cut = N / 2 + unidg.rand.getValue(range - N - 1);
        const double p = unidg.rand.getDouble();
        if (p < 0.25) {
            fillUniform(begin, begin + N / 2, Min, Min + cut);
            fillClustered(begin + N / 2, end, Min + cut, Max);
        } else if (p < 0.5) {
            fillClustered(begin, begin + N / 2, Min, Min + cut);
            fillUniform(begin + N / 2, end, Min + cut, Max);
        } else {
            fillClustered(begin, begin + N / 2, Min, Min + cut);
            fillClustered(begin + N / 2, end, Min + cut, Max);
        }
    }

    vector<uint32_t> generateClustered(uint32_t N, uint32_t Max) {
        vector<uint32_t> ans(N);
        fillClustered(ans.begin(), ans.end(), 0, Max);
        return ans;
    }

};

/**
 *  author: Preston Bannister
 */
class WallClockTimer {
public:
    struct timeval t1, t2;
    WallClockTimer() :
        t1(), t2() {
        gettimeofday(&t1, 0);
        t2 = t1;
    }
    void reset() {
        gettimeofday(&t1, 0);
        t2 = t1;
    }
    int elapsed() {
        return (static_cast<int> (t2.tv_sec - t1.tv_sec) * 1000)
                + static_cast<int> (t2.tv_usec - t1. tv_usec) / 1000;
    }
    int split() {
        gettimeofday(&t2, 0);
        return elapsed();
    }
};

template<class uword>
void test(vector<vector<uint32_t> > & data, int repeat) {
    WallClockTimer timer;
    long bogus = 0;
    // building
    timer.reset();
    vector<EWAHBoolArray<uword> > ewah(data.size());
    size_t size = 0;
    for (int r = 0; r < repeat; ++r) {
        size = 0;
        for (size_t k = 0; k < data.size(); ++k) {

            ewah[k].reset();

            for (uint32_t x = 0; x < data.at(k).size(); ++x) {
                ewah[k].set(data.at(k).at(x));
            }

            size += ewah[k].sizeInBytes();
        }
    }
    cout << size << "\t";
    cout << timer.split() << "\t";
    timer.reset();
    for (int r = 0; r < repeat; ++r)
        for (size_t k = 0; k < data.size(); ++k) {
            vector < size_t > vals = ewah[k].toArray();
            bogus += vals.size();
            assert(vals.size() == data[k].size());
        }
    cout << timer.split() << "\t";
    timer.reset();
    for (int r = 0; r < repeat; ++r)
        for (size_t k = 0; k < data.size(); ++k) {
            EWAHBoolArray<uword> ewahor(ewah[0]);
            for (size_t j = 1; j < k; ++j) {
                EWAHBoolArray<uword> container;
                ewahor.logicalor(ewah[j], container);
                ewahor.swap(container);
            }
            bogus += ewahor.sizeInBits();
        }
    cout << timer.split() << "\t";
    timer.reset();
    for (int r = 0; r < repeat; ++r)
        for (size_t k = 0; k < data.size(); ++k) {
            EWAHBoolArray<uword> ewahand(ewah[0]);
            for (size_t j = 1; j < k; ++j) {
                EWAHBoolArray<uword> container;
                ewahand.logicaland(ewah[j], container);
                ewahand.swap(container);
            }
            bogus += ewahand.sizeInBits();

        }
    cout << timer.split() << "\t" << bogus << endl;

}
void test(size_t N, int nbr, int repeat) {
    for (int sparsity = 1; sparsity < 31 - nbr; sparsity += 1) {
        ClusteredDataGenerator cdg;
        cout << "# sparsity=" << sparsity << "\t";
        vector < vector<uint32_t> > data(N);
        uint32_t Max = (1 << (nbr + sparsity));
        cout << "# generating data..." << endl;
        for (size_t k = 0; k < N; ++k) {
            data[k] = cdg.generateClustered(1 << nbr, Max);
        }
        cout << "# generating data...ok" << endl;
        cout << "#64 bits" << endl;
        test<uint64_t> (data, repeat);
        cout << "#32 bits" << endl;
        test<uint32_t> (data, repeat);
    }
}

int main(void) {
    test(10, 18, 1);
}

