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
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import * as dom from '../../../base/browser/dom.js';
import { GlobalMouseMoveMonitor, standardMouseMoveMerger } from '../../../base/browser/globalMouseMoveMonitor.js';
import { Emitter } from '../../../base/common/event.js';
import { Disposable } from '../../../base/common/lifecycle.js';
import './lightBulbWidget.css';
import { TextModel } from '../../common/model/textModel.js';
import * as nls from '../../../nls.js';
import { IKeybindingService } from '../../../platform/keybinding/common/keybinding.js';
var LightBulbState;
(function (LightBulbState) {
    LightBulbState.Hidden = new /** @class */ (function () {
        function class_1() {
            this.type = 0 /* Hidden */;
        }
        return class_1;
    }());
    var Showing = /** @class */ (function () {
        function Showing(actions, editorPosition, widgetPosition) {
            this.actions = actions;
            this.editorPosition = editorPosition;
            this.widgetPosition = widgetPosition;
            this.type = 1 /* Showing */;
        }
        return Showing;
    }());
    LightBulbState.Showing = Showing;
})(LightBulbState || (LightBulbState = {}));
var LightBulbWidget = /** @class */ (function (_super) {
    __extends(LightBulbWidget, _super);
    function LightBulbWidget(_editor, _quickFixActionId, _keybindingService) {
        var _this = _super.call(this) || this;
        _this._editor = _editor;
        _this._quickFixActionId = _quickFixActionId;
        _this._keybindingService = _keybindingService;
        _this._onClick = _this._register(new Emitter());
        _this.onClick = _this._onClick.event;
        _this._state = LightBulbState.Hidden;
        _this._domNode = document.createElement('div');
        _this._domNode.className = 'lightbulb-glyph';
        _this._editor.addContentWidget(_this);
        _this._register(_this._editor.onDidChangeModelContent(function (_) {
            // cancel when the line in question has been removed
            var editorModel = _this._editor.getModel();
            if (_this._state.type !== 1 /* Showing */ || !editorModel || _this._state.editorPosition.lineNumber >= editorModel.getLineCount()) {
                _this.hide();
            }
        }));
        _this._register(dom.addStandardDisposableListener(_this._domNode, 'mousedown', function (e) {
            if (_this._state.type !== 1 /* Showing */) {
                return;
            }
            // Make sure that focus / cursor location is not lost when clicking widget icon
            _this._editor.focus();
            e.preventDefault();
            // a bit of extra work to make sure the menu
            // doesn't cover the line-text
            var _a = dom.getDomNodePagePosition(_this._domNode), top = _a.top, height = _a.height;
            var lineHeight = _this._editor.getConfiguration().lineHeight;
            var pad = Math.floor(lineHeight / 3);
            if (_this._state.widgetPosition.position !== null && _this._state.widgetPosition.position.lineNumber < _this._state.editorPosition.lineNumber) {
                pad += lineHeight;
            }
            _this._onClick.fire({
                x: e.posx,
                y: top + height + pad,
                actions: _this._state.actions
            });
        }));
        _this._register(dom.addDisposableListener(_this._domNode, 'mouseenter', function (e) {
            if ((e.buttons & 1) !== 1) {
                return;
            }
            // mouse enters lightbulb while the primary/left button
            // is being pressed -> hide the lightbulb and block future
            // showings until mouse is released
            _this.hide();
            var monitor = new GlobalMouseMoveMonitor();
            monitor.startMonitoring(standardMouseMoveMerger, function () { }, function () {
                monitor.dispose();
            });
        }));
        _this._register(_this._editor.onDidChangeConfiguration(function (e) {
            // hide when told to do so
            if (e.contribInfo && !_this._editor.getConfiguration().contribInfo.lightbulbEnabled) {
                _this.hide();
            }
        }));
        _this._updateLightBulbTitle();
        _this._register(_this._keybindingService.onDidUpdateKeybindings(_this._updateLightBulbTitle, _this));
        return _this;
    }
    LightBulbWidget.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
        this._editor.removeContentWidget(this);
    };
    LightBulbWidget.prototype.getId = function () {
        return 'LightBulbWidget';
    };
    LightBulbWidget.prototype.getDomNode = function () {
        return this._domNode;
    };
    LightBulbWidget.prototype.getPosition = function () {
        return this._state.type === 1 /* Showing */ ? this._state.widgetPosition : null;
    };
    LightBulbWidget.prototype.update = function (actions, atPosition) {
        var _this = this;
        if (actions.actions.length <= 0) {
            return this.hide();
        }
        var config = this._editor.getConfiguration();
        if (!config.contribInfo.lightbulbEnabled) {
            return this.hide();
        }
        var lineNumber = atPosition.lineNumber, column = atPosition.column;
        var model = this._editor.getModel();
        if (!model) {
            return this.hide();
        }
        var tabSize = model.getOptions().tabSize;
        var lineContent = model.getLineContent(lineNumber);
        var indent = TextModel.computeIndentLevel(lineContent, tabSize);
        var lineHasSpace = config.fontInfo.spaceWidth * indent > 22;
        var isFolded = function (lineNumber) {
            return lineNumber > 2 && _this._editor.getTopForLineNumber(lineNumber) === _this._editor.getTopForLineNumber(lineNumber - 1);
        };
        var effectiveLineNumber = lineNumber;
        if (!lineHasSpace) {
            if (lineNumber > 1 && !isFolded(lineNumber - 1)) {
                effectiveLineNumber -= 1;
            }
            else if (!isFolded(lineNumber + 1)) {
                effectiveLineNumber += 1;
            }
            else if (column * config.fontInfo.spaceWidth < 22) {
                // cannot show lightbulb above/below and showing
                // it inline would overlay the cursor...
                return this.hide();
            }
        }
        this._state = new LightBulbState.Showing(actions, atPosition, {
            position: { lineNumber: effectiveLineNumber, column: 1 },
            preference: LightBulbWidget._posPref
        });
        dom.toggleClass(this._domNode, 'autofixable', actions.hasAutoFix);
        this._editor.layoutContentWidget(this);
    };
    Object.defineProperty(LightBulbWidget.prototype, "title", {
        set: function (value) {
            this._domNode.title = value;
        },
        enumerable: true,
        configurable: true
    });
    LightBulbWidget.prototype.hide = function () {
        this._state = LightBulbState.Hidden;
        this._editor.layoutContentWidget(this);
    };
    LightBulbWidget.prototype._updateLightBulbTitle = function () {
        var kb = this._keybindingService.lookupKeybinding(this._quickFixActionId);
        var title;
        if (kb) {
            title = nls.localize('quickFixWithKb', "Show Fixes ({0})", kb.getLabel());
        }
        else {
            title = nls.localize('quickFix', "Show Fixes");
        }
        this.title = title;
    };
    LightBulbWidget._posPref = [0 /* EXACT */];
    LightBulbWidget = __decorate([
        __param(2, IKeybindingService)
    ], LightBulbWidget);
    return LightBulbWidget;
}(Disposable));
export { LightBulbWidget };
