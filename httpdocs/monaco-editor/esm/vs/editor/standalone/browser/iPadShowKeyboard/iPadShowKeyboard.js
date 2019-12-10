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
import './iPadShowKeyboard.css';
import * as browser from '../../../../base/browser/browser.js';
import * as dom from '../../../../base/browser/dom.js';
import { Disposable } from '../../../../base/common/lifecycle.js';
import { registerEditorContribution } from '../../../browser/editorExtensions.js';
var IPadShowKeyboard = /** @class */ (function (_super) {
    __extends(IPadShowKeyboard, _super);
    function IPadShowKeyboard(editor) {
        var _this = _super.call(this) || this;
        _this.editor = editor;
        _this.widget = null;
        if (browser.isIPad) {
            _this._register(editor.onDidChangeConfiguration(function () { return _this.update(); }));
            _this.update();
        }
        return _this;
    }
    IPadShowKeyboard.prototype.update = function () {
        var shouldHaveWidget = (!this.editor.getConfiguration().readOnly);
        if (!this.widget && shouldHaveWidget) {
            this.widget = new ShowKeyboardWidget(this.editor);
        }
        else if (this.widget && !shouldHaveWidget) {
            this.widget.dispose();
            this.widget = null;
        }
    };
    IPadShowKeyboard.prototype.getId = function () {
        return IPadShowKeyboard.ID;
    };
    IPadShowKeyboard.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
        if (this.widget) {
            this.widget.dispose();
            this.widget = null;
        }
    };
    IPadShowKeyboard.ID = 'editor.contrib.iPadShowKeyboard';
    return IPadShowKeyboard;
}(Disposable));
export { IPadShowKeyboard };
var ShowKeyboardWidget = /** @class */ (function (_super) {
    __extends(ShowKeyboardWidget, _super);
    function ShowKeyboardWidget(editor) {
        var _this = _super.call(this) || this;
        _this.editor = editor;
        _this._domNode = document.createElement('textarea');
        _this._domNode.className = 'iPadShowKeyboard';
        _this._register(dom.addDisposableListener(_this._domNode, 'touchstart', function (e) {
            _this.editor.focus();
        }));
        _this._register(dom.addDisposableListener(_this._domNode, 'focus', function (e) {
            _this.editor.focus();
        }));
        _this.editor.addOverlayWidget(_this);
        return _this;
    }
    ShowKeyboardWidget.prototype.dispose = function () {
        this.editor.removeOverlayWidget(this);
        _super.prototype.dispose.call(this);
    };
    // ----- IOverlayWidget API
    ShowKeyboardWidget.prototype.getId = function () {
        return ShowKeyboardWidget.ID;
    };
    ShowKeyboardWidget.prototype.getDomNode = function () {
        return this._domNode;
    };
    ShowKeyboardWidget.prototype.getPosition = function () {
        return {
            preference: 1 /* BOTTOM_RIGHT_CORNER */
        };
    };
    ShowKeyboardWidget.ID = 'editor.contrib.ShowKeyboardWidget';
    return ShowKeyboardWidget;
}(Disposable));
registerEditorContribution(IPadShowKeyboard);
