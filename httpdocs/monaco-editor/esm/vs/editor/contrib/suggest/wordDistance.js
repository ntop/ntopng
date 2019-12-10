/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __extends = (this && this.__extends) || (function () {
    var extendStatics = function (d, b) {
        extendStatics = Object.setPrototypeOf ||
            ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
            function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
        return extendStatics(d, b);
    };
    return function (d, b) {
        extendStatics(d, b);
        function __() { this.constructor = d; }
        d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
    };
})();
import { binarySearch, isFalsyOrEmpty } from '../../../base/common/arrays.js';
import { Range } from '../../common/core/range.js';
import { BracketSelectionRangeProvider } from '../smartSelect/bracketSelections.js';
var WordDistance = /** @class */ (function () {
    function WordDistance() {
    }
    WordDistance.create = function (service, editor) {
        if (!editor.getConfiguration().contribInfo.suggest.localityBonus) {
            return Promise.resolve(WordDistance.None);
        }
        if (!editor.hasModel()) {
            return Promise.resolve(WordDistance.None);
        }
        var model = editor.getModel();
        var position = editor.getPosition();
        if (!service.canComputeWordRanges(model.uri)) {
            return Promise.resolve(WordDistance.None);
        }
        return new BracketSelectionRangeProvider().provideSelectionRanges(model, [position]).then(function (ranges) {
            if (!ranges || ranges.length === 0 || ranges[0].length === 0) {
                return WordDistance.None;
            }
            return service.computeWordRanges(model.uri, ranges[0][0].range).then(function (wordRanges) {
                return new /** @class */ (function (_super) {
                    __extends(class_1, _super);
                    function class_1() {
                        return _super !== null && _super.apply(this, arguments) || this;
                    }
                    class_1.prototype.distance = function (anchor, suggestion) {
                        if (!wordRanges || !position.equals(editor.getPosition())) {
                            return 0;
                        }
                        if (suggestion.kind === 17 /* Keyword */) {
                            return 2 << 20;
                        }
                        var word = suggestion.label;
                        var wordLines = wordRanges[word];
                        if (isFalsyOrEmpty(wordLines)) {
                            return 2 << 20;
                        }
                        var idx = binarySearch(wordLines, Range.fromPositions(anchor), Range.compareRangesUsingStarts);
                        var bestWordRange = idx >= 0 ? wordLines[idx] : wordLines[Math.max(0, ~idx - 1)];
                        var blockDistance = ranges.length;
                        for (var _i = 0, _a = ranges[0]; _i < _a.length; _i++) {
                            var range = _a[_i];
                            if (!Range.containsRange(range.range, bestWordRange)) {
                                break;
                            }
                            blockDistance -= 1;
                        }
                        return blockDistance;
                    };
                    return class_1;
                }(WordDistance));
            });
        });
    };
    WordDistance.None = new /** @class */ (function (_super) {
        __extends(class_2, _super);
        function class_2() {
            return _super !== null && _super.apply(this, arguments) || this;
        }
        class_2.prototype.distance = function () { return 0; };
        return class_2;
    }(WordDistance));
    return WordDistance;
}());
export { WordDistance };
