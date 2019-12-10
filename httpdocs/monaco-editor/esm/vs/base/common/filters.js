/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { LRUCache } from './map.js';
import * as strings from './strings.js';
// Combined filters
/**
 * @returns A filter which combines the provided set
 * of filters with an or. The *first* filters that
 * matches defined the return value of the returned
 * filter.
 */
export function or() {
    var filter = [];
    for (var _i = 0; _i < arguments.length; _i++) {
        filter[_i] = arguments[_i];
    }
    return function (word, wordToMatchAgainst) {
        for (var i = 0, len = filter.length; i < len; i++) {
            var match = filter[i](word, wordToMatchAgainst);
            if (match) {
                return match;
            }
        }
        return null;
    };
}
export var matchesPrefix = _matchesPrefix.bind(undefined, true);
function _matchesPrefix(ignoreCase, word, wordToMatchAgainst) {
    if (!wordToMatchAgainst || wordToMatchAgainst.length < word.length) {
        return null;
    }
    var matches;
    if (ignoreCase) {
        matches = strings.startsWithIgnoreCase(wordToMatchAgainst, word);
    }
    else {
        matches = wordToMatchAgainst.indexOf(word) === 0;
    }
    if (!matches) {
        return null;
    }
    return word.length > 0 ? [{ start: 0, end: word.length }] : [];
}
// Contiguous Substring
export function matchesContiguousSubString(word, wordToMatchAgainst) {
    var index = wordToMatchAgainst.toLowerCase().indexOf(word.toLowerCase());
    if (index === -1) {
        return null;
    }
    return [{ start: index, end: index + word.length }];
}
// Substring
export function matchesSubString(word, wordToMatchAgainst) {
    return _matchesSubString(word.toLowerCase(), wordToMatchAgainst.toLowerCase(), 0, 0);
}
function _matchesSubString(word, wordToMatchAgainst, i, j) {
    if (i === word.length) {
        return [];
    }
    else if (j === wordToMatchAgainst.length) {
        return null;
    }
    else {
        if (word[i] === wordToMatchAgainst[j]) {
            var result = null;
            if (result = _matchesSubString(word, wordToMatchAgainst, i + 1, j + 1)) {
                return join({ start: j, end: j + 1 }, result);
            }
            return null;
        }
        return _matchesSubString(word, wordToMatchAgainst, i, j + 1);
    }
}
// CamelCase
function isLower(code) {
    return 97 /* a */ <= code && code <= 122 /* z */;
}
export function isUpper(code) {
    return 65 /* A */ <= code && code <= 90 /* Z */;
}
function isNumber(code) {
    return 48 /* Digit0 */ <= code && code <= 57 /* Digit9 */;
}
function isWhitespace(code) {
    return (code === 32 /* Space */
        || code === 9 /* Tab */
        || code === 10 /* LineFeed */
        || code === 13 /* CarriageReturn */);
}
var wordSeparators = new Set();
'`~!@#$%^&*()-=+[{]}\\|;:\'",.<>/?'
    .split('')
    .forEach(function (s) { return wordSeparators.add(s.charCodeAt(0)); });
function isAlphanumeric(code) {
    return isLower(code) || isUpper(code) || isNumber(code);
}
function join(head, tail) {
    if (tail.length === 0) {
        tail = [head];
    }
    else if (head.end === tail[0].start) {
        tail[0].start = head.start;
    }
    else {
        tail.unshift(head);
    }
    return tail;
}
function nextAnchor(camelCaseWord, start) {
    for (var i = start; i < camelCaseWord.length; i++) {
        var c = camelCaseWord.charCodeAt(i);
        if (isUpper(c) || isNumber(c) || (i > 0 && !isAlphanumeric(camelCaseWord.charCodeAt(i - 1)))) {
            return i;
        }
    }
    return camelCaseWord.length;
}
function _matchesCamelCase(word, camelCaseWord, i, j) {
    if (i === word.length) {
        return [];
    }
    else if (j === camelCaseWord.length) {
        return null;
    }
    else if (word[i] !== camelCaseWord[j].toLowerCase()) {
        return null;
    }
    else {
        var result = null;
        var nextUpperIndex = j + 1;
        result = _matchesCamelCase(word, camelCaseWord, i + 1, j + 1);
        while (!result && (nextUpperIndex = nextAnchor(camelCaseWord, nextUpperIndex)) < camelCaseWord.length) {
            result = _matchesCamelCase(word, camelCaseWord, i + 1, nextUpperIndex);
            nextUpperIndex++;
        }
        return result === null ? null : join({ start: j, end: j + 1 }, result);
    }
}
// Heuristic to avoid computing camel case matcher for words that don't
// look like camelCaseWords.
function analyzeCamelCaseWord(word) {
    var upper = 0, lower = 0, alpha = 0, numeric = 0, code = 0;
    for (var i = 0; i < word.length; i++) {
        code = word.charCodeAt(i);
        if (isUpper(code)) {
            upper++;
        }
        if (isLower(code)) {
            lower++;
        }
        if (isAlphanumeric(code)) {
            alpha++;
        }
        if (isNumber(code)) {
            numeric++;
        }
    }
    var upperPercent = upper / word.length;
    var lowerPercent = lower / word.length;
    var alphaPercent = alpha / word.length;
    var numericPercent = numeric / word.length;
    return { upperPercent: upperPercent, lowerPercent: lowerPercent, alphaPercent: alphaPercent, numericPercent: numericPercent };
}
function isUpperCaseWord(analysis) {
    var upperPercent = analysis.upperPercent, lowerPercent = analysis.lowerPercent;
    return lowerPercent === 0 && upperPercent > 0.6;
}
function isCamelCaseWord(analysis) {
    var upperPercent = analysis.upperPercent, lowerPercent = analysis.lowerPercent, alphaPercent = analysis.alphaPercent, numericPercent = analysis.numericPercent;
    return lowerPercent > 0.2 && upperPercent < 0.8 && alphaPercent > 0.6 && numericPercent < 0.2;
}
// Heuristic to avoid computing camel case matcher for words that don't
// look like camel case patterns.
function isCamelCasePattern(word) {
    var upper = 0, lower = 0, code = 0, whitespace = 0;
    for (var i = 0; i < word.length; i++) {
        code = word.charCodeAt(i);
        if (isUpper(code)) {
            upper++;
        }
        if (isLower(code)) {
            lower++;
        }
        if (isWhitespace(code)) {
            whitespace++;
        }
    }
    if ((upper === 0 || lower === 0) && whitespace === 0) {
        return word.length <= 30;
    }
    else {
        return upper <= 5;
    }
}
export function matchesCamelCase(word, camelCaseWord) {
    if (!camelCaseWord) {
        return null;
    }
    camelCaseWord = camelCaseWord.trim();
    if (camelCaseWord.length === 0) {
        return null;
    }
    if (!isCamelCasePattern(word)) {
        return null;
    }
    if (camelCaseWord.length > 60) {
        return null;
    }
    var analysis = analyzeCamelCaseWord(camelCaseWord);
    if (!isCamelCaseWord(analysis)) {
        if (!isUpperCaseWord(analysis)) {
            return null;
        }
        camelCaseWord = camelCaseWord.toLowerCase();
    }
    var result = null;
    var i = 0;
    word = word.toLowerCase();
    while (i < camelCaseWord.length && (result = _matchesCamelCase(word, camelCaseWord, 0, i)) === null) {
        i = nextAnchor(camelCaseWord, i + 1);
    }
    return result;
}
// Fuzzy
var fuzzyContiguousFilter = or(matchesPrefix, matchesCamelCase, matchesContiguousSubString);
var fuzzySeparateFilter = or(matchesPrefix, matchesCamelCase, matchesSubString);
var fuzzyRegExpCache = new LRUCache(10000); // bounded to 10000 elements
export function matchesFuzzy(word, wordToMatchAgainst, enableSeparateSubstringMatching) {
    if (enableSeparateSubstringMatching === void 0) { enableSeparateSubstringMatching = false; }
    if (typeof word !== 'string' || typeof wordToMatchAgainst !== 'string') {
        return null; // return early for invalid input
    }
    // Form RegExp for wildcard matches
    var regexp = fuzzyRegExpCache.get(word);
    if (!regexp) {
        regexp = new RegExp(strings.convertSimple2RegExpPattern(word), 'i');
        fuzzyRegExpCache.set(word, regexp);
    }
    // RegExp Filter
    var match = regexp.exec(wordToMatchAgainst);
    if (match) {
        return [{ start: match.index, end: match.index + match[0].length }];
    }
    // Default Filter
    return enableSeparateSubstringMatching ? fuzzySeparateFilter(word, wordToMatchAgainst) : fuzzyContiguousFilter(word, wordToMatchAgainst);
}
export function anyScore(pattern, lowPattern, _patternPos, word, lowWord, _wordPos) {
    var result = fuzzyScore(pattern, lowPattern, 0, word, lowWord, 0, true);
    if (result) {
        return result;
    }
    var matches = 0;
    var score = 0;
    var idx = _wordPos;
    for (var patternPos = 0; patternPos < lowPattern.length && patternPos < _maxLen; ++patternPos) {
        var wordPos = lowWord.indexOf(lowPattern.charAt(patternPos), idx);
        if (wordPos >= 0) {
            score += 1;
            matches += Math.pow(2, wordPos);
            idx = wordPos + 1;
        }
        else if (matches !== 0) {
            // once we have started matching things
            // we need to match the remaining pattern
            // characters
            break;
        }
    }
    return [score, matches, _wordPos];
}
//#region --- fuzzyScore ---
export function createMatches(score) {
    if (typeof score === 'undefined') {
        return [];
    }
    var matches = score[1].toString(2);
    var wordStart = score[2];
    var res = [];
    for (var pos = wordStart; pos < _maxLen; pos++) {
        if (matches[matches.length - (pos + 1)] === '1') {
            var last = res[res.length - 1];
            if (last && last.end === pos) {
                last.end = pos + 1;
            }
            else {
                res.push({ start: pos, end: pos + 1 });
            }
        }
    }
    return res;
}
var _maxLen = 128;
function initTable() {
    var table = [];
    var row = [0];
    for (var i = 1; i <= _maxLen; i++) {
        row.push(-i);
    }
    for (var i = 0; i <= _maxLen; i++) {
        var thisRow = row.slice(0);
        thisRow[0] = -i;
        table.push(thisRow);
    }
    return table;
}
var _table = initTable();
var _scores = initTable();
var _arrows = initTable();
var _debug = false;
function printTable(table, pattern, patternLen, word, wordLen) {
    function pad(s, n, pad) {
        if (pad === void 0) { pad = ' '; }
        while (s.length < n) {
            s = pad + s;
        }
        return s;
    }
    var ret = " |   |" + word.split('').map(function (c) { return pad(c, 3); }).join('|') + "\n";
    for (var i = 0; i <= patternLen; i++) {
        if (i === 0) {
            ret += ' |';
        }
        else {
            ret += pattern[i - 1] + "|";
        }
        ret += table[i].slice(0, wordLen + 1).map(function (n) { return pad(n.toString(), 3); }).join('|') + '\n';
    }
    return ret;
}
function printTables(pattern, patternStart, word, wordStart) {
    pattern = pattern.substr(patternStart);
    word = word.substr(wordStart);
    console.log(printTable(_table, pattern, pattern.length, word, word.length));
    console.log(printTable(_arrows, pattern, pattern.length, word, word.length));
    console.log(printTable(_scores, pattern, pattern.length, word, word.length));
}
function isSeparatorAtPos(value, index) {
    if (index < 0 || index >= value.length) {
        return false;
    }
    var code = value.charCodeAt(index);
    switch (code) {
        case 95 /* Underline */:
        case 45 /* Dash */:
        case 46 /* Period */:
        case 32 /* Space */:
        case 47 /* Slash */:
        case 92 /* Backslash */:
        case 39 /* SingleQuote */:
        case 34 /* DoubleQuote */:
        case 58 /* Colon */:
        case 36 /* DollarSign */:
            return true;
        default:
            return false;
    }
}
function isWhitespaceAtPos(value, index) {
    if (index < 0 || index >= value.length) {
        return false;
    }
    var code = value.charCodeAt(index);
    switch (code) {
        case 32 /* Space */:
        case 9 /* Tab */:
            return true;
        default:
            return false;
    }
}
function isUpperCaseAtPos(pos, word, wordLow) {
    return word[pos] !== wordLow[pos];
}
export function isPatternInWord(patternLow, patternPos, patternLen, wordLow, wordPos, wordLen) {
    while (patternPos < patternLen && wordPos < wordLen) {
        if (patternLow[patternPos] === wordLow[wordPos]) {
            patternPos += 1;
        }
        wordPos += 1;
    }
    return patternPos === patternLen; // pattern must be exhausted
}
export var FuzzyScore;
(function (FuzzyScore) {
    /**
     * No matches and value `-100`
     */
    FuzzyScore.Default = Object.freeze([-100, 0, 0]);
    function isDefault(score) {
        return !score || (score[0] === -100 && score[1] === 0 && score[2] === 0);
    }
    FuzzyScore.isDefault = isDefault;
})(FuzzyScore || (FuzzyScore = {}));
export function fuzzyScore(pattern, patternLow, patternStart, word, wordLow, wordStart, firstMatchCanBeWeak) {
    var patternLen = pattern.length > _maxLen ? _maxLen : pattern.length;
    var wordLen = word.length > _maxLen ? _maxLen : word.length;
    if (patternStart >= patternLen || wordStart >= wordLen || patternLen > wordLen) {
        return undefined;
    }
    // Run a simple check if the characters of pattern occur
    // (in order) at all in word. If that isn't the case we
    // stop because no match will be possible
    if (!isPatternInWord(patternLow, patternStart, patternLen, wordLow, wordStart, wordLen)) {
        return undefined;
    }
    var row = 1;
    var column = 1;
    var patternPos = patternStart;
    var wordPos = wordStart;
    // There will be a match, fill in tables
    for (row = 1, patternPos = patternStart; patternPos < patternLen; row++, patternPos++) {
        for (column = 1, wordPos = wordStart; wordPos < wordLen; column++, wordPos++) {
            var score = _doScore(pattern, patternLow, patternPos, patternStart, word, wordLow, wordPos);
            _scores[row][column] = score;
            var diag = _table[row - 1][column - 1] + (score > 1 ? 1 : score);
            var top_1 = _table[row - 1][column] + -1;
            var left = _table[row][column - 1] + -1;
            if (left >= top_1) {
                // left or diag
                if (left > diag) {
                    _table[row][column] = left;
                    _arrows[row][column] = 4 /* Left */;
                }
                else if (left === diag) {
                    _table[row][column] = left;
                    _arrows[row][column] = 4 /* Left */ | 2 /* Diag */;
                }
                else {
                    _table[row][column] = diag;
                    _arrows[row][column] = 2 /* Diag */;
                }
            }
            else {
                // top or diag
                if (top_1 > diag) {
                    _table[row][column] = top_1;
                    _arrows[row][column] = 1 /* Top */;
                }
                else if (top_1 === diag) {
                    _table[row][column] = top_1;
                    _arrows[row][column] = 1 /* Top */ | 2 /* Diag */;
                }
                else {
                    _table[row][column] = diag;
                    _arrows[row][column] = 2 /* Diag */;
                }
            }
        }
    }
    if (_debug) {
        printTables(pattern, patternStart, word, wordStart);
    }
    _matchesCount = 0;
    _topScore = -100;
    _wordStart = wordStart;
    _firstMatchCanBeWeak = firstMatchCanBeWeak;
    _findAllMatches2(row - 1, column - 1, patternLen === wordLen ? 1 : 0, 0, false);
    if (_matchesCount === 0) {
        return undefined;
    }
    return [_topScore, _topMatch2, wordStart];
}
function _doScore(pattern, patternLow, patternPos, patternStart, word, wordLow, wordPos) {
    if (patternLow[patternPos] !== wordLow[wordPos]) {
        return -1;
    }
    if (wordPos === (patternPos - patternStart)) {
        // common prefix: `foobar <-> foobaz`
        //                            ^^^^^
        if (pattern[patternPos] === word[wordPos]) {
            return 7;
        }
        else {
            return 5;
        }
    }
    else if (isUpperCaseAtPos(wordPos, word, wordLow) && (wordPos === 0 || !isUpperCaseAtPos(wordPos - 1, word, wordLow))) {
        // hitting upper-case: `foo <-> forOthers`
        //                              ^^ ^
        if (pattern[patternPos] === word[wordPos]) {
            return 7;
        }
        else {
            return 5;
        }
    }
    else if (isSeparatorAtPos(wordLow, wordPos) && (wordPos === 0 || !isSeparatorAtPos(wordLow, wordPos - 1))) {
        // hitting a separator: `. <-> foo.bar`
        //                                ^
        return 5;
    }
    else if (isSeparatorAtPos(wordLow, wordPos - 1) || isWhitespaceAtPos(wordLow, wordPos - 1)) {
        // post separator: `foo <-> bar_foo`
        //                              ^^^
        return 5;
    }
    else {
        return 1;
    }
}
var _matchesCount = 0;
var _topMatch2 = 0;
var _topScore = 0;
var _wordStart = 0;
var _firstMatchCanBeWeak = false;
function _findAllMatches2(row, column, total, matches, lastMatched) {
    if (_matchesCount >= 10 || total < -25) {
        // stop when having already 10 results, or
        // when a potential alignment as already 5 gaps
        return;
    }
    var simpleMatchCount = 0;
    while (row > 0 && column > 0) {
        var score = _scores[row][column];
        var arrow = _arrows[row][column];
        if (arrow === 4 /* Left */) {
            // left -> no match, skip a word character
            column -= 1;
            if (lastMatched) {
                total -= 5; // new gap penalty
            }
            else if (matches !== 0) {
                total -= 1; // gap penalty after first match
            }
            lastMatched = false;
            simpleMatchCount = 0;
        }
        else if (arrow & 2 /* Diag */) {
            if (arrow & 4 /* Left */) {
                // left
                _findAllMatches2(row, column - 1, matches !== 0 ? total - 1 : total, // gap penalty after first match
                matches, lastMatched);
            }
            // diag
            total += score;
            row -= 1;
            column -= 1;
            lastMatched = true;
            // match -> set a 1 at the word pos
            matches += Math.pow(2, (column + _wordStart));
            // count simple matches and boost a row of
            // simple matches when they yield in a
            // strong match.
            if (score === 1) {
                simpleMatchCount += 1;
                if (row === 0 && !_firstMatchCanBeWeak) {
                    // when the first match is a weak
                    // match we discard it
                    return undefined;
                }
            }
            else {
                // boost
                total += 1 + (simpleMatchCount * (score - 1));
                simpleMatchCount = 0;
            }
        }
        else {
            return undefined;
        }
    }
    total -= column >= 3 ? 9 : column * 3; // late start penalty
    // dynamically keep track of the current top score
    // and insert the current best score at head, the rest at tail
    _matchesCount += 1;
    if (total > _topScore) {
        _topScore = total;
        _topMatch2 = matches;
    }
}
//#endregion
//#region --- graceful ---
export function fuzzyScoreGracefulAggressive(pattern, lowPattern, patternPos, word, lowWord, wordPos, firstMatchCanBeWeak) {
    return fuzzyScoreWithPermutations(pattern, lowPattern, patternPos, word, lowWord, wordPos, true, firstMatchCanBeWeak);
}
function fuzzyScoreWithPermutations(pattern, lowPattern, patternPos, word, lowWord, wordPos, aggressive, firstMatchCanBeWeak) {
    var top = fuzzyScore(pattern, lowPattern, patternPos, word, lowWord, wordPos, firstMatchCanBeWeak);
    if (top && !aggressive) {
        // when using the original pattern yield a result we`
        // return it unless we are aggressive and try to find
        // a better alignment, e.g. `cno` -> `^co^ns^ole` or `^c^o^nsole`.
        return top;
    }
    if (pattern.length >= 3) {
        // When the pattern is long enough then try a few (max 7)
        // permutations of the pattern to find a better match. The
        // permutations only swap neighbouring characters, e.g
        // `cnoso` becomes `conso`, `cnsoo`, `cnoos`.
        var tries = Math.min(7, pattern.length - 1);
        for (var movingPatternPos = patternPos + 1; movingPatternPos < tries; movingPatternPos++) {
            var newPattern = nextTypoPermutation(pattern, movingPatternPos);
            if (newPattern) {
                var candidate = fuzzyScore(newPattern, newPattern.toLowerCase(), patternPos, word, lowWord, wordPos, firstMatchCanBeWeak);
                if (candidate) {
                    candidate[0] -= 3; // permutation penalty
                    if (!top || candidate[0] > top[0]) {
                        top = candidate;
                    }
                }
            }
        }
    }
    return top;
}
function nextTypoPermutation(pattern, patternPos) {
    if (patternPos + 1 >= pattern.length) {
        return undefined;
    }
    var swap1 = pattern[patternPos];
    var swap2 = pattern[patternPos + 1];
    if (swap1 === swap2) {
        return undefined;
    }
    return pattern.slice(0, patternPos)
        + swap2
        + swap1
        + pattern.slice(patternPos + 2);
}
//#endregion
