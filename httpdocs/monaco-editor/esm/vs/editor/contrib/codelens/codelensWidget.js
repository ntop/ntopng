/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import './codelensWidget.css';
import * as dom from '../../../base/browser/dom.js';
import { coalesce, isFalsyOrEmpty } from '../../../base/common/arrays.js';
import { escape } from '../../../base/common/strings.js';
import { Range } from '../../common/core/range.js';
import { ModelDecorationOptions } from '../../common/model/textModel.js';
import { editorCodeLensForeground } from '../../common/view/editorColorRegistry.js';
import { editorActiveLinkForeground } from '../../../platform/theme/common/colorRegistry.js';
import { registerThemingParticipant } from '../../../platform/theme/common/themeService.js';
var CodeLensViewZone = /** @class */ (function () {
    function CodeLensViewZone(afterLineNumber, onHeight) {
        this.afterLineNumber = afterLineNumber;
        this._onHeight = onHeight;
        this.heightInLines = 1;
        this.suppressMouseDown = true;
        this.domNode = document.createElement('div');
    }
    CodeLensViewZone.prototype.onComputedHeight = function (height) {
        if (this._lastHeight === undefined) {
            this._lastHeight = height;
        }
        else if (this._lastHeight !== height) {
            this._lastHeight = height;
            this._onHeight();
        }
    };
    return CodeLensViewZone;
}());
var CodeLensContentWidget = /** @class */ (function () {
    function CodeLensContentWidget(editor, symbolRange, data) {
        // Editor.IContentWidget.allowEditorOverflow
        this.allowEditorOverflow = false;
        this.suppressMouseDown = true;
        this._commands = new Map();
        this._id = 'codeLensWidget' + (++CodeLensContentWidget._idPool);
        this._editor = editor;
        this.setSymbolRange(symbolRange);
        this._domNode = document.createElement('span');
        this._domNode.innerHTML = '&nbsp;';
        dom.addClass(this._domNode, 'codelens-decoration');
        this.updateHeight();
        this.withCommands(data.map(function (data) { return data.symbol; }), false);
    }
    CodeLensContentWidget.prototype.updateHeight = function () {
        var _a = this._editor.getConfiguration(), fontInfo = _a.fontInfo, lineHeight = _a.lineHeight;
        this._domNode.style.height = Math.round(lineHeight * 1.1) + "px";
        this._domNode.style.lineHeight = lineHeight + "px";
        this._domNode.style.fontSize = Math.round(fontInfo.fontSize * 0.9) + "px";
        this._domNode.style.paddingRight = Math.round(fontInfo.fontSize * 0.45) + "px";
        this._domNode.innerHTML = '&nbsp;';
    };
    CodeLensContentWidget.prototype.withCommands = function (inSymbols, animate) {
        this._commands.clear();
        var symbols = coalesce(inSymbols);
        if (isFalsyOrEmpty(symbols)) {
            this._domNode.innerHTML = '<span>no commands</span>';
            return;
        }
        var html = [];
        for (var i = 0; i < symbols.length; i++) {
            var command = symbols[i].command;
            if (command) {
                var title = escape(command.title);
                var part = void 0;
                if (command.id) {
                    part = "<a id=" + i + ">" + title + "</a>";
                    this._commands.set(String(i), command);
                }
                else {
                    part = "<span>" + title + "</span>";
                }
                html.push(part);
            }
        }
        var wasEmpty = this._domNode.innerHTML === '' || this._domNode.innerHTML === '&nbsp;';
        this._domNode.innerHTML = html.join('<span>&nbsp;|&nbsp;</span>');
        this._editor.layoutContentWidget(this);
        if (wasEmpty && animate) {
            dom.addClass(this._domNode, 'fadein');
        }
    };
    CodeLensContentWidget.prototype.getCommand = function (link) {
        return link.parentElement === this._domNode
            ? this._commands.get(link.id)
            : undefined;
    };
    CodeLensContentWidget.prototype.getId = function () {
        return this._id;
    };
    CodeLensContentWidget.prototype.getDomNode = function () {
        return this._domNode;
    };
    CodeLensContentWidget.prototype.setSymbolRange = function (range) {
        if (!this._editor.hasModel()) {
            return;
        }
        var lineNumber = range.startLineNumber;
        var column = this._editor.getModel().getLineFirstNonWhitespaceColumn(lineNumber);
        this._widgetPosition = {
            position: { lineNumber: lineNumber, column: column },
            preference: [1 /* ABOVE */]
        };
    };
    CodeLensContentWidget.prototype.getPosition = function () {
        return this._widgetPosition || null;
    };
    CodeLensContentWidget.prototype.isVisible = function () {
        return this._domNode.hasAttribute('monaco-visible-content-widget');
    };
    CodeLensContentWidget._idPool = 0;
    return CodeLensContentWidget;
}());
var CodeLensHelper = /** @class */ (function () {
    function CodeLensHelper() {
        this._removeDecorations = [];
        this._addDecorations = [];
        this._addDecorationsCallbacks = [];
    }
    CodeLensHelper.prototype.addDecoration = function (decoration, callback) {
        this._addDecorations.push(decoration);
        this._addDecorationsCallbacks.push(callback);
    };
    CodeLensHelper.prototype.removeDecoration = function (decorationId) {
        this._removeDecorations.push(decorationId);
    };
    CodeLensHelper.prototype.commit = function (changeAccessor) {
        var resultingDecorations = changeAccessor.deltaDecorations(this._removeDecorations, this._addDecorations);
        for (var i = 0, len = resultingDecorations.length; i < len; i++) {
            this._addDecorationsCallbacks[i](resultingDecorations[i]);
        }
    };
    return CodeLensHelper;
}());
export { CodeLensHelper };
var CodeLensWidget = /** @class */ (function () {
    function CodeLensWidget(data, editor, helper, viewZoneChangeAccessor, updateCallback) {
        var _this = this;
        this._editor = editor;
        this._data = data;
        this._decorationIds = new Array(this._data.length);
        var range;
        this._data.forEach(function (codeLensData, i) {
            helper.addDecoration({
                range: codeLensData.symbol.range,
                options: ModelDecorationOptions.EMPTY
            }, function (id) { return _this._decorationIds[i] = id; });
            // the range contains all lenses on this line
            if (!range) {
                range = Range.lift(codeLensData.symbol.range);
            }
            else {
                range = Range.plusRange(range, codeLensData.symbol.range);
            }
        });
        if (range) {
            this._contentWidget = new CodeLensContentWidget(editor, range, this._data);
            this._viewZone = new CodeLensViewZone(range.startLineNumber - 1, updateCallback);
            this._viewZoneId = viewZoneChangeAccessor.addZone(this._viewZone);
            this._editor.addContentWidget(this._contentWidget);
        }
    }
    CodeLensWidget.prototype.dispose = function (helper, viewZoneChangeAccessor) {
        while (this._decorationIds.length) {
            helper.removeDecoration(this._decorationIds.pop());
        }
        if (viewZoneChangeAccessor) {
            viewZoneChangeAccessor.removeZone(this._viewZoneId);
        }
        this._editor.removeContentWidget(this._contentWidget);
    };
    CodeLensWidget.prototype.isValid = function () {
        var _this = this;
        if (!this._editor.hasModel()) {
            return false;
        }
        var model = this._editor.getModel();
        return this._decorationIds.some(function (id, i) {
            var range = model.getDecorationRange(id);
            var symbol = _this._data[i].symbol;
            return !!(range && Range.isEmpty(symbol.range) === range.isEmpty());
        });
    };
    CodeLensWidget.prototype.updateCodeLensSymbols = function (data, helper) {
        var _this = this;
        while (this._decorationIds.length) {
            helper.removeDecoration(this._decorationIds.pop());
        }
        this._data = data;
        this._decorationIds = new Array(this._data.length);
        this._data.forEach(function (codeLensData, i) {
            helper.addDecoration({
                range: codeLensData.symbol.range,
                options: ModelDecorationOptions.EMPTY
            }, function (id) { return _this._decorationIds[i] = id; });
        });
    };
    CodeLensWidget.prototype.computeIfNecessary = function (model) {
        if (!this._contentWidget.isVisible()) {
            return null;
        }
        // Read editor current state
        for (var i = 0; i < this._decorationIds.length; i++) {
            var range = model.getDecorationRange(this._decorationIds[i]);
            if (range) {
                this._data[i].symbol.range = range;
            }
        }
        return this._data;
    };
    CodeLensWidget.prototype.updateCommands = function (symbols) {
        this._contentWidget.withCommands(symbols, true);
        for (var i = 0; i < this._data.length; i++) {
            var resolved = symbols[i];
            if (resolved) {
                var symbol = this._data[i].symbol;
                symbol.command = resolved.command || symbol.command;
            }
        }
    };
    CodeLensWidget.prototype.updateHeight = function () {
        this._contentWidget.updateHeight();
    };
    CodeLensWidget.prototype.getCommand = function (link) {
        return this._contentWidget.getCommand(link);
    };
    CodeLensWidget.prototype.getLineNumber = function () {
        if (this._editor.hasModel()) {
            var range = this._editor.getModel().getDecorationRange(this._decorationIds[0]);
            if (range) {
                return range.startLineNumber;
            }
        }
        return -1;
    };
    CodeLensWidget.prototype.update = function (viewZoneChangeAccessor) {
        if (this.isValid() && this._editor.hasModel()) {
            var range = this._editor.getModel().getDecorationRange(this._decorationIds[0]);
            if (range) {
                this._viewZone.afterLineNumber = range.startLineNumber - 1;
                viewZoneChangeAccessor.layoutZone(this._viewZoneId);
                this._contentWidget.setSymbolRange(range);
                this._editor.layoutContentWidget(this._contentWidget);
            }
        }
    };
    return CodeLensWidget;
}());
export { CodeLensWidget };
registerThemingParticipant(function (theme, collector) {
    var codeLensForeground = theme.getColor(editorCodeLensForeground);
    if (codeLensForeground) {
        collector.addRule(".monaco-editor .codelens-decoration { color: " + codeLensForeground + "; }");
    }
    var activeLinkForeground = theme.getColor(editorActiveLinkForeground);
    if (activeLinkForeground) {
        collector.addRule(".monaco-editor .codelens-decoration > a:hover { color: " + activeLinkForeground + " !important; }");
    }
});
