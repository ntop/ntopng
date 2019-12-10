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
import * as nls from '../../../nls.js';
import * as dom from '../../../base/browser/dom.js';
import { Action } from '../../../base/common/actions.js';
import { Disposable } from '../../../base/common/lifecycle.js';
import { Range } from '../../common/core/range.js';
var InlineDiffMargin = /** @class */ (function (_super) {
    __extends(InlineDiffMargin, _super);
    function InlineDiffMargin(_viewZoneId, _marginDomNode, editor, diff, _contextMenuService, _clipboardService) {
        var _this = _super.call(this) || this;
        _this._viewZoneId = _viewZoneId;
        _this._marginDomNode = _marginDomNode;
        _this.editor = editor;
        _this.diff = diff;
        _this._contextMenuService = _contextMenuService;
        _this._clipboardService = _clipboardService;
        _this._visibility = false;
        // make sure the diff margin shows above overlay.
        _this._marginDomNode.style.zIndex = '10';
        _this._diffActions = document.createElement('div');
        _this._diffActions.className = 'lightbulb-glyph';
        _this._diffActions.style.position = 'absolute';
        var lineHeight = editor.getConfiguration().lineHeight;
        var lineFeed = editor.getModel().getEOL();
        _this._diffActions.style.right = '0px';
        _this._diffActions.style.visibility = 'hidden';
        _this._diffActions.style.height = lineHeight + "px";
        _this._diffActions.style.lineHeight = lineHeight + "px";
        _this._marginDomNode.appendChild(_this._diffActions);
        var actions = [];
        // default action
        actions.push(new Action('diff.clipboard.copyDeletedContent', diff.originalEndLineNumber > diff.modifiedStartLineNumber
            ? nls.localize('diff.clipboard.copyDeletedLinesContent.label', "Copy deleted lines")
            : nls.localize('diff.clipboard.copyDeletedLinesContent.single.label', "Copy deleted line"), undefined, true, function () { return __awaiter(_this, void 0, void 0, function () {
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0: return [4 /*yield*/, this._clipboardService.writeText(diff.originalContent.join(lineFeed) + lineFeed)];
                    case 1:
                        _a.sent();
                        return [2 /*return*/];
                }
            });
        }); }));
        var currentLineNumberOffset = 0;
        var copyLineAction = undefined;
        if (diff.originalEndLineNumber > diff.modifiedStartLineNumber) {
            copyLineAction = new Action('diff.clipboard.copyDeletedLineContent', nls.localize('diff.clipboard.copyDeletedLineContent.label', "Copy deleted line ({0})", diff.originalStartLineNumber), undefined, true, function () { return __awaiter(_this, void 0, void 0, function () {
                return __generator(this, function (_a) {
                    switch (_a.label) {
                        case 0: return [4 /*yield*/, this._clipboardService.writeText(diff.originalContent[currentLineNumberOffset])];
                        case 1:
                            _a.sent();
                            return [2 /*return*/];
                    }
                });
            }); });
            actions.push(copyLineAction);
        }
        var readOnly = editor.getConfiguration().readOnly;
        if (!readOnly) {
            actions.push(new Action('diff.inline.revertChange', nls.localize('diff.inline.revertChange.label', "Revert this change"), undefined, true, function () { return __awaiter(_this, void 0, void 0, function () {
                var column, column;
                return __generator(this, function (_a) {
                    if (diff.modifiedEndLineNumber === 0) {
                        column = editor.getModel().getLineMaxColumn(diff.modifiedStartLineNumber);
                        editor.executeEdits('diffEditor', [
                            {
                                range: new Range(diff.modifiedStartLineNumber, column, diff.modifiedStartLineNumber, column),
                                text: lineFeed + diff.originalContent.join(lineFeed)
                            }
                        ]);
                    }
                    else {
                        column = editor.getModel().getLineMaxColumn(diff.modifiedEndLineNumber);
                        editor.executeEdits('diffEditor', [
                            {
                                range: new Range(diff.modifiedStartLineNumber, 1, diff.modifiedEndLineNumber, column),
                                text: diff.originalContent.join(lineFeed)
                            }
                        ]);
                    }
                    return [2 /*return*/];
                });
            }); }));
        }
        _this._register(dom.addStandardDisposableListener(_this._diffActions, 'mousedown', function (e) {
            var _a = dom.getDomNodePagePosition(_this._diffActions), top = _a.top, height = _a.height;
            var pad = Math.floor(lineHeight / 3);
            e.preventDefault();
            _this._contextMenuService.showContextMenu({
                getAnchor: function () {
                    return {
                        x: e.posx,
                        y: top + height + pad
                    };
                },
                getActions: function () {
                    if (copyLineAction) {
                        copyLineAction.label = nls.localize('diff.clipboard.copyDeletedLineContent.label', "Copy deleted line ({0})", diff.originalStartLineNumber + currentLineNumberOffset);
                    }
                    return actions;
                },
                autoSelectFirstItem: true
            });
        }));
        _this._register(editor.onMouseMove(function (e) {
            if (e.target.type === 8 /* CONTENT_VIEW_ZONE */ || e.target.type === 5 /* GUTTER_VIEW_ZONE */) {
                var viewZoneId = e.target.detail.viewZoneId;
                if (viewZoneId === _this._viewZoneId) {
                    _this.visibility = true;
                    currentLineNumberOffset = _this._updateLightBulbPosition(_this._marginDomNode, e.event.browserEvent.y, lineHeight);
                }
                else {
                    _this.visibility = false;
                }
            }
            else {
                _this.visibility = false;
            }
        }));
        return _this;
    }
    Object.defineProperty(InlineDiffMargin.prototype, "visibility", {
        get: function () {
            return this._visibility;
        },
        set: function (_visibility) {
            if (this._visibility !== _visibility) {
                this._visibility = _visibility;
                if (_visibility) {
                    this._diffActions.style.visibility = 'visible';
                }
                else {
                    this._diffActions.style.visibility = 'hidden';
                }
            }
        },
        enumerable: true,
        configurable: true
    });
    InlineDiffMargin.prototype._updateLightBulbPosition = function (marginDomNode, y, lineHeight) {
        var top = dom.getDomNodePagePosition(marginDomNode).top;
        var offset = y - top;
        var lineNumberOffset = Math.floor(offset / lineHeight);
        var newTop = lineNumberOffset * lineHeight;
        this._diffActions.style.top = newTop + "px";
        return lineNumberOffset;
    };
    return InlineDiffMargin;
}(Disposable));
export { InlineDiffMargin };
