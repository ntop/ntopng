/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (_) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
import { Position } from '../../common/core/position.js';
import { Range } from '../../common/core/range.js';
import { LinkedList } from '../../../base/common/linkedList.js';
var BracketSelectionRangeProvider = /** @class */ (function () {
    function BracketSelectionRangeProvider() {
    }
    BracketSelectionRangeProvider.prototype.provideSelectionRanges = function (model, positions) {
        return __awaiter(this, void 0, void 0, function () {
            var result, _loop_1, _i, positions_1, position;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        result = [];
                        _loop_1 = function (position) {
                            var bucket, ranges;
                            return __generator(this, function (_a) {
                                switch (_a.label) {
                                    case 0:
                                        bucket = [];
                                        result.push(bucket);
                                        ranges = new Map();
                                        return [4 /*yield*/, new Promise(function (resolve) { return BracketSelectionRangeProvider._bracketsRightYield(resolve, 0, model, position, ranges); })];
                                    case 1:
                                        _a.sent();
                                        return [4 /*yield*/, new Promise(function (resolve) { return BracketSelectionRangeProvider._bracketsLeftYield(resolve, 0, model, position, ranges, bucket); })];
                                    case 2:
                                        _a.sent();
                                        return [2 /*return*/];
                                }
                            });
                        };
                        _i = 0, positions_1 = positions;
                        _a.label = 1;
                    case 1:
                        if (!(_i < positions_1.length)) return [3 /*break*/, 4];
                        position = positions_1[_i];
                        return [5 /*yield**/, _loop_1(position)];
                    case 2:
                        _a.sent();
                        _a.label = 3;
                    case 3:
                        _i++;
                        return [3 /*break*/, 1];
                    case 4: return [2 /*return*/, result];
                }
            });
        });
    };
    BracketSelectionRangeProvider._bracketsRightYield = function (resolve, round, model, pos, ranges) {
        var counts = new Map();
        var t1 = Date.now();
        while (true) {
            if (round >= BracketSelectionRangeProvider._maxRounds) {
                resolve();
                break;
            }
            if (!pos) {
                resolve();
                break;
            }
            var bracket = model.findNextBracket(pos);
            if (!bracket) {
                resolve();
                break;
            }
            var d = Date.now() - t1;
            if (d > BracketSelectionRangeProvider._maxDuration) {
                setTimeout(function () { return BracketSelectionRangeProvider._bracketsRightYield(resolve, round + 1, model, pos, ranges); });
                break;
            }
            var key = bracket.close;
            if (bracket.isOpen) {
                // wait for closing
                var val = counts.has(key) ? counts.get(key) : 0;
                counts.set(key, val + 1);
            }
            else {
                // process closing
                var val = counts.has(key) ? counts.get(key) : 0;
                val -= 1;
                counts.set(key, Math.max(0, val));
                if (val < 0) {
                    var list = ranges.get(key);
                    if (!list) {
                        list = new LinkedList();
                        ranges.set(key, list);
                    }
                    list.push(bracket.range);
                }
            }
            pos = bracket.range.getEndPosition();
        }
    };
    BracketSelectionRangeProvider._bracketsLeftYield = function (resolve, round, model, pos, ranges, bucket) {
        var counts = new Map();
        var t1 = Date.now();
        while (true) {
            if (round >= BracketSelectionRangeProvider._maxRounds && ranges.size === 0) {
                resolve();
                break;
            }
            if (!pos) {
                resolve();
                break;
            }
            var bracket = model.findPrevBracket(pos);
            if (!bracket) {
                resolve();
                break;
            }
            var d = Date.now() - t1;
            if (d > BracketSelectionRangeProvider._maxDuration) {
                setTimeout(function () { return BracketSelectionRangeProvider._bracketsLeftYield(resolve, round + 1, model, pos, ranges, bucket); });
                break;
            }
            var key = bracket.close;
            if (!bracket.isOpen) {
                // wait for opening
                var val = counts.has(key) ? counts.get(key) : 0;
                counts.set(key, val + 1);
            }
            else {
                // opening
                var val = counts.has(key) ? counts.get(key) : 0;
                val -= 1;
                counts.set(key, Math.max(0, val));
                if (val < 0) {
                    var list = ranges.get(key);
                    if (list) {
                        var closing = list.shift();
                        if (list.size === 0) {
                            ranges.delete(key);
                        }
                        var innerBracket = Range.fromPositions(bracket.range.getEndPosition(), closing.getStartPosition());
                        var outerBracket = Range.fromPositions(bracket.range.getStartPosition(), closing.getEndPosition());
                        bucket.push({ range: innerBracket });
                        bucket.push({ range: outerBracket });
                        BracketSelectionRangeProvider._addBracketLeading(model, outerBracket, bucket);
                    }
                }
            }
            pos = bracket.range.getStartPosition();
        }
    };
    BracketSelectionRangeProvider._addBracketLeading = function (model, bracket, bucket) {
        if (bracket.startLineNumber === bracket.endLineNumber) {
            return;
        }
        // xxxxxxxx {
        //
        // }
        var startLine = bracket.startLineNumber;
        var column = model.getLineFirstNonWhitespaceColumn(startLine);
        if (column !== 0 && column !== bracket.startColumn) {
            bucket.push({ range: Range.fromPositions(new Position(startLine, column), bracket.getEndPosition()) });
            bucket.push({ range: Range.fromPositions(new Position(startLine, 1), bracket.getEndPosition()) });
        }
        // xxxxxxxx
        // {
        //
        // }
        var aboveLine = startLine - 1;
        if (aboveLine > 0) {
            var column_1 = model.getLineFirstNonWhitespaceColumn(aboveLine);
            if (column_1 === bracket.startColumn && column_1 !== model.getLineLastNonWhitespaceColumn(aboveLine)) {
                bucket.push({ range: Range.fromPositions(new Position(aboveLine, column_1), bracket.getEndPosition()) });
                bucket.push({ range: Range.fromPositions(new Position(aboveLine, 1), bracket.getEndPosition()) });
            }
        }
    };
    BracketSelectionRangeProvider._maxDuration = 30;
    BracketSelectionRangeProvider._maxRounds = 2;
    return BracketSelectionRangeProvider;
}());
export { BracketSelectionRangeProvider };
