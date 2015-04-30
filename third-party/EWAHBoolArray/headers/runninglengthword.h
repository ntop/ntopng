/**
 * This code is released under the
 * Apache License Version 2.0 http://www.apache.org/licenses/.
 *
 * (c) Daniel Lemire, http://lemire.me/en/
 */
#ifndef RUNNINGLENGTHWORD_H_
#define RUNNINGLENGTHWORD_H_

/**
 * For expert users.
 * This class is used to represent a special type of word storing
 * a run length. It is defined by the Enhanced Word Aligned  Hybrid (EWAH)
 * format. You don't normally need to access this class.
 */
template<class uword>
class RunningLengthWord {
public:
    RunningLengthWord(uword & data) :
        mydata(data) {
    }

    RunningLengthWord(const RunningLengthWord & rlw) :
        mydata(rlw.mydata) {
    }

    RunningLengthWord& operator=(const RunningLengthWord & rlw) {
        mydata = rlw.mydata;
        return *this;
    }

    /**
     * Which bit is being repeated?
     */
    bool getRunningBit() const {
        return mydata & static_cast<uword> (1);
    }

    /**
     * how many words should be filled by the running bit
     */
    static inline bool getRunningBit(uword data)  {
        return data & static_cast<uword> (1);
    }

    /**
     * how many words should be filled by the running bit
     */
    uword getRunningLength() const {
        return static_cast<uword>((mydata >> 1) & largestrunninglengthcount);
    }

    /**
     * followed by how many literal words?
     */
    static inline uword getRunningLength(uword data) {
        return static_cast<uword>((data >> 1) & largestrunninglengthcount);
    }

    /**
     * followed by how many literal words?
     */
    uword getNumberOfLiteralWords() const {
        return static_cast<uword> (mydata >> (1 + runninglengthbits));
    }

    /**
     * Total of getRunningLength() and getNumberOfLiteralWords()
     */
    uword size() const {
        return static_cast<uword>(getRunningLength() + getNumberOfLiteralWords());
    }



    /**
     * Total of getRunningLength() and getNumberOfLiteralWords()
     */
    static inline uword size(uword data) {
        return static_cast<uword>(getRunningLength(data) + getNumberOfLiteralWords(data));
    }

    /**
     * followed by how many literal words?
     */
    static inline uword getNumberOfLiteralWords(uword data) {
        return static_cast<uword> (data >> (1 + runninglengthbits));
    }

    /**
     * running length of which type of bits
     */
    void setRunningBit(bool b) {
        if (b)
            mydata |= static_cast<uword> (1);
        else
            mydata &= static_cast<uword> (~1);
    }

    /**
     * running length of which type of bits
     */
    static inline void setRunningBit(uword & data, bool b) {
        if (b)
            data |= static_cast<uword> (1);
        else
            data &= static_cast<uword> (~1);
    }

    /**
     * running length of which type of bits
     */
    void discardFirstWords(uword x) {
        assert(x <= size());
        const uword rl(getRunningLength());
        if (rl >= x) {
            setRunningLength(rl - x);
            return;
        }
        x -= rl;
        setRunningLength(0);
        setNumberOfLiteralWords(getNumberOfLiteralWords() - x);
    }

    void setRunningLength(uword l) {
        mydata |= shiftedlargestrunninglengthcount;
        mydata &= static_cast<uword> ((l << 1)
                | notshiftedlargestrunninglengthcount);
    }

    // static call for people who hate objects
    static inline void setRunningLength(uword & data, uword l) {
        data |= shiftedlargestrunninglengthcount;
        data &= static_cast<uword> ((l << 1)
                | notshiftedlargestrunninglengthcount);
    }

    void setNumberOfLiteralWords(uword l) {
        mydata |= notrunninglengthplusrunningbit;
        mydata &= static_cast<uword> ((l << (runninglengthbits + 1))
                | runninglengthplusrunningbit);
    }
    // static call for people who hate objects
    static inline void setNumberOfLiteralWords(uword & data, uword l) {
        data |= notrunninglengthplusrunningbit;
        data &= static_cast<uword> (l << (runninglengthbits + 1))
                | runninglengthplusrunningbit;
    }
    static const uint32_t runninglengthbits = sizeof(uword) * 4;//16;
    static const uint32_t literalbits = sizeof(uword) * 8 - 1 - runninglengthbits;
    static const uword largestliteralcount = (static_cast<uword> (1)
            << literalbits) - 1;
    static const uword largestrunninglengthcount = (static_cast<uword> (1)
            << runninglengthbits) - 1;
    static const uword shiftedlargestrunninglengthcount =
            largestrunninglengthcount << 1;
    static const uword notshiftedlargestrunninglengthcount =
            static_cast<uword> (~shiftedlargestrunninglengthcount);
    static const uword runninglengthplusrunningbit = (static_cast<uword> (1)
            << (runninglengthbits + 1)) - 1;
    static const uword notrunninglengthplusrunningbit =
            static_cast<uword> (~runninglengthplusrunningbit);
    static const uword notlargestrunninglengthcount =
            static_cast<uword> (~largestrunninglengthcount);

    uword & mydata;
};

/**
 * Same as RunningLengthWord, except that the values cannot be modified.
 */
template<class uword = uint32_t>
class ConstRunningLengthWord {
public:

    ConstRunningLengthWord() :
        mydata(0) {
    }

    ConstRunningLengthWord(const uword data) :
        mydata(data) {
    }

    ConstRunningLengthWord(const ConstRunningLengthWord & rlw) :
        mydata(rlw.mydata) {
    }

    /**
     * Which bit is being repeated?
     */
    bool getRunningBit() const {
        return mydata & static_cast<uword> (1);
    }

    /**
     * how many words should be filled by the running bit
     */
    uword getRunningLength() const {
        return static_cast<uword>((mydata >> 1)
                & RunningLengthWord<uword>::largestrunninglengthcount);
    }

    /**
     * followed by how many literal words?
     */
    uword getNumberOfLiteralWords() const {
        return static_cast<uword> (mydata >> (1
                + RunningLengthWord<uword>::runninglengthbits));
    }

    /**
     * Total of getRunningLength() and getNumberOfLiteralWords()
     */
    uword size() const {
        return getRunningLength() + getNumberOfLiteralWords();
    }

    uword mydata;
};

/**
 * Same as RunningLengthWord, except that the values are buffered for quick
 * access.
 */
template<class uword = uint32_t>
class BufferedRunningLengthWord {
public:
    BufferedRunningLengthWord(const uword & data) :
                RunningBit(data & static_cast<uword> (1)),
                RunningLength(
                        static_cast<uword>((data >> 1)
                                & RunningLengthWord<uword>::largestrunninglengthcount)),
                NumberOfLiteralWords(
                        static_cast<uword> (data >> (1 + RunningLengthWord<
                                uword>::runninglengthbits))) {
    }
    BufferedRunningLengthWord(const RunningLengthWord<uword> & p) :
                RunningBit(p.mydata & static_cast<uword> (1)),
                RunningLength(
                        (p.mydata >> 1)
                                & RunningLengthWord<uword>::largestrunninglengthcount),
                NumberOfLiteralWords(
                        p.mydata >> (1
                                + RunningLengthWord<uword>::runninglengthbits)) {
    }

    void read(const uword & data) {
        RunningBit = data & static_cast<uword> (1);
        RunningLength = static_cast<uword>((data >> 1)
                & RunningLengthWord<uword>::largestrunninglengthcount);
        NumberOfLiteralWords = static_cast<uword> (data >> (1
                + RunningLengthWord<uword>::runninglengthbits));
    }

    /**
     * Which bit is being repeated?
     */
    bool getRunningBit() const {
        return RunningBit;
    }

    void discardFirstWords(uword x) {
        assert(x <= size());
        if (RunningLength >= x) {
            RunningLength = static_cast<uword> (RunningLength - x);
            return;
        }
        x = static_cast<uword> (x - RunningLength);
        RunningLength = 0;
        NumberOfLiteralWords = static_cast<uword> (NumberOfLiteralWords - x);
    }

    /**
     * how many words should be filled by the running bit (see previous method)
     */
    uword getRunningLength() const {
        return RunningLength;
    }

    /**
     * followed by how many literal words?
     */
    uword getNumberOfLiteralWords() const {
        return NumberOfLiteralWords;
    }

    /**
     * Total of getRunningLength() and getNumberOfLiteralWords()
     */
    uword size() const {
        return static_cast<uword> (RunningLength + NumberOfLiteralWords);
    }
    bool RunningBit;
    uword RunningLength;
    uword NumberOfLiteralWords;

};



#endif /* RUNNINGLENGTHWORD_H_ */
