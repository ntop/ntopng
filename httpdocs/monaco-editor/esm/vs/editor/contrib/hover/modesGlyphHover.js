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
import { $ } from '../../../base/browser/dom.js';
import { isEmptyMarkdownString } from '../../../base/common/htmlContent.js';
import { DisposableStore } from '../../../base/common/lifecycle.js';
import { HoverOperation } from './hoverOperation.js';
import { GlyphHoverWidget } from './hoverWidgets.js';
import { MarkdownRenderer } from '../markdown/markdownRenderer.js';
import { NullOpenerService } from '../../../platform/opener/common/opener.js';
import { asArray } from '../../../base/common/arrays.js';
var MarginComputer = /** @class */ (function () {
    function MarginComputer(editor) {
        this._editor = editor;
        this._lineNumber = -1;
        this._result = [];
    }
    MarginComputer.prototype.setLineNumber = function (lineNumber) {
        this._lineNumber = lineNumber;
        this._result = [];
    };
    MarginComputer.prototype.clearResult = function () {
        this._result = [];
    };
    MarginComputer.prototype.computeSync = function () {
        var toHoverMessage = function (contents) {
            return {
                value: contents
            };
        };
        var lineDecorations = this._editor.getLineDecorations(this._lineNumber);
        var result = [];
        if (!lineDecorations) {
            return result;
        }
        for (var _i = 0, lineDecorations_1 = lineDecorations; _i < lineDecorations_1.length; _i++) {
            var d = lineDecorations_1[_i];
            if (!d.options.glyphMarginClassName) {
                continue;
            }
            var hoverMessage = d.options.glyphMarginHoverMessage;
            if (!hoverMessage || isEmptyMarkdownString(hoverMessage)) {
                continue;
            }
            result.push.apply(result, asArray(hoverMessage).map(toHoverMessage));
        }
        return result;
    };
    MarginComputer.prototype.onResult = function (result, isFromSynchronousComputation) {
        this._result = this._result.concat(result);
    };
    MarginComputer.prototype.getResult = function () {
        return this._result;
    };
    MarginComputer.prototype.getResultWithLoadingMessage = function () {
        return this.getResult();
    };
    return MarginComputer;
}());
var ModesGlyphHoverWidget = /** @class */ (function (_super) {
    __extends(ModesGlyphHoverWidget, _super);
    function ModesGlyphHoverWidget(editor, modeService, openerService) {
        if (openerService === void 0) { openerService = NullOpenerService; }
        var _this = _super.call(this, ModesGlyphHoverWidget.ID, editor) || this;
        _this._renderDisposeables = _this._register(new DisposableStore());
        _this._messages = [];
        _this._lastLineNumber = -1;
        _this._markdownRenderer = _this._register(new MarkdownRenderer(_this._editor, modeService, openerService));
        _this._computer = new MarginComputer(_this._editor);
        _this._hoverOperation = new HoverOperation(_this._computer, function (result) { return _this._withResult(result); }, undefined, function (result) { return _this._withResult(result); }, 300);
        return _this;
    }
    ModesGlyphHoverWidget.prototype.dispose = function () {
        this._hoverOperation.cancel();
        _super.prototype.dispose.call(this);
    };
    ModesGlyphHoverWidget.prototype.onModelDecorationsChanged = function () {
        if (this.isVisible) {
            // The decorations have changed and the hover is visible,
            // we need to recompute the displayed text
            this._hoverOperation.cancel();
            this._computer.clearResult();
            this._hoverOperation.start(0 /* Delayed */);
        }
    };
    ModesGlyphHoverWidget.prototype.startShowingAt = function (lineNumber) {
        if (this._lastLineNumber === lineNumber) {
            // We have to show the widget at the exact same line number as before, so no work is needed
            return;
        }
        this._hoverOperation.cancel();
        this.hide();
        this._lastLineNumber = lineNumber;
        this._computer.setLineNumber(lineNumber);
        this._hoverOperation.start(0 /* Delayed */);
    };
    ModesGlyphHoverWidget.prototype.hide = function () {
        this._lastLineNumber = -1;
        this._hoverOperation.cancel();
        _super.prototype.hide.call(this);
    };
    ModesGlyphHoverWidget.prototype._withResult = function (result) {
        this._messages = result;
        if (this._messages.length > 0) {
            this._renderMessages(this._lastLineNumber, this._messages);
        }
        else {
            this.hide();
        }
    };
    ModesGlyphHoverWidget.prototype._renderMessages = function (lineNumber, messages) {
        this._renderDisposeables.clear();
        var fragment = document.createDocumentFragment();
        for (var _i = 0, messages_1 = messages; _i < messages_1.length; _i++) {
            var msg = messages_1[_i];
            var renderedContents = this._markdownRenderer.render(msg.value);
            this._renderDisposeables.add(renderedContents);
            fragment.appendChild($('div.hover-row', undefined, renderedContents.element));
        }
        this.updateContents(fragment);
        this.showAt(lineNumber);
    };
    ModesGlyphHoverWidget.ID = 'editor.contrib.modesGlyphHoverWidget';
    return ModesGlyphHoverWidget;
}(GlyphHoverWidget));
export { ModesGlyphHoverWidget };
