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
import './findInput.css';
import * as nls from '../../../../nls.js';
import * as dom from '../../dom.js';
import { HistoryInputBox } from '../inputbox/inputBox.js';
import { Widget } from '../widget.js';
import { Emitter } from '../../../common/event.js';
import { CaseSensitiveCheckbox, WholeWordsCheckbox, RegexCheckbox } from './findInputCheckboxes.js';
var NLS_DEFAULT_LABEL = nls.localize('defaultLabel', "input");
var FindInput = /** @class */ (function (_super) {
    __extends(FindInput, _super);
    function FindInput(parent, contextViewProvider, _showOptionButtons, options) {
        var _this = _super.call(this) || this;
        _this._showOptionButtons = _showOptionButtons;
        _this.fixFocusOnOptionClickEnabled = true;
        _this._onDidOptionChange = _this._register(new Emitter());
        _this.onDidOptionChange = _this._onDidOptionChange.event;
        _this._onKeyDown = _this._register(new Emitter());
        _this.onKeyDown = _this._onKeyDown.event;
        _this._onMouseDown = _this._register(new Emitter());
        _this.onMouseDown = _this._onMouseDown.event;
        _this._onInput = _this._register(new Emitter());
        _this._onKeyUp = _this._register(new Emitter());
        _this._onCaseSensitiveKeyDown = _this._register(new Emitter());
        _this.onCaseSensitiveKeyDown = _this._onCaseSensitiveKeyDown.event;
        _this._onRegexKeyDown = _this._register(new Emitter());
        _this.onRegexKeyDown = _this._onRegexKeyDown.event;
        _this._lastHighlightFindOptions = 0;
        _this.contextViewProvider = contextViewProvider;
        _this.placeholder = options.placeholder || '';
        _this.validation = options.validation;
        _this.label = options.label || NLS_DEFAULT_LABEL;
        _this.inputActiveOptionBorder = options.inputActiveOptionBorder;
        _this.inputActiveOptionBackground = options.inputActiveOptionBackground;
        _this.inputBackground = options.inputBackground;
        _this.inputForeground = options.inputForeground;
        _this.inputBorder = options.inputBorder;
        _this.inputValidationInfoBorder = options.inputValidationInfoBorder;
        _this.inputValidationInfoBackground = options.inputValidationInfoBackground;
        _this.inputValidationInfoForeground = options.inputValidationInfoForeground;
        _this.inputValidationWarningBorder = options.inputValidationWarningBorder;
        _this.inputValidationWarningBackground = options.inputValidationWarningBackground;
        _this.inputValidationWarningForeground = options.inputValidationWarningForeground;
        _this.inputValidationErrorBorder = options.inputValidationErrorBorder;
        _this.inputValidationErrorBackground = options.inputValidationErrorBackground;
        _this.inputValidationErrorForeground = options.inputValidationErrorForeground;
        var appendCaseSensitiveLabel = options.appendCaseSensitiveLabel || '';
        var appendWholeWordsLabel = options.appendWholeWordsLabel || '';
        var appendRegexLabel = options.appendRegexLabel || '';
        var history = options.history || [];
        var flexibleHeight = !!options.flexibleHeight;
        var flexibleWidth = !!options.flexibleWidth;
        var flexibleMaxHeight = options.flexibleMaxHeight;
        _this.domNode = document.createElement('div');
        dom.addClass(_this.domNode, 'monaco-findInput');
        _this.inputBox = _this._register(new HistoryInputBox(_this.domNode, _this.contextViewProvider, {
            placeholder: _this.placeholder || '',
            ariaLabel: _this.label || '',
            validationOptions: {
                validation: _this.validation
            },
            inputBackground: _this.inputBackground,
            inputForeground: _this.inputForeground,
            inputBorder: _this.inputBorder,
            inputValidationInfoBackground: _this.inputValidationInfoBackground,
            inputValidationInfoForeground: _this.inputValidationInfoForeground,
            inputValidationInfoBorder: _this.inputValidationInfoBorder,
            inputValidationWarningBackground: _this.inputValidationWarningBackground,
            inputValidationWarningForeground: _this.inputValidationWarningForeground,
            inputValidationWarningBorder: _this.inputValidationWarningBorder,
            inputValidationErrorBackground: _this.inputValidationErrorBackground,
            inputValidationErrorForeground: _this.inputValidationErrorForeground,
            inputValidationErrorBorder: _this.inputValidationErrorBorder,
            history: history,
            flexibleHeight: flexibleHeight,
            flexibleWidth: flexibleWidth,
            flexibleMaxHeight: flexibleMaxHeight
        }));
        _this.regex = _this._register(new RegexCheckbox({
            appendTitle: appendRegexLabel,
            isChecked: false,
            inputActiveOptionBorder: _this.inputActiveOptionBorder,
            inputActiveOptionBackground: _this.inputActiveOptionBackground
        }));
        _this._register(_this.regex.onChange(function (viaKeyboard) {
            _this._onDidOptionChange.fire(viaKeyboard);
            if (!viaKeyboard && _this.fixFocusOnOptionClickEnabled) {
                _this.inputBox.focus();
            }
            _this.validate();
        }));
        _this._register(_this.regex.onKeyDown(function (e) {
            _this._onRegexKeyDown.fire(e);
        }));
        _this.wholeWords = _this._register(new WholeWordsCheckbox({
            appendTitle: appendWholeWordsLabel,
            isChecked: false,
            inputActiveOptionBorder: _this.inputActiveOptionBorder,
            inputActiveOptionBackground: _this.inputActiveOptionBackground
        }));
        _this._register(_this.wholeWords.onChange(function (viaKeyboard) {
            _this._onDidOptionChange.fire(viaKeyboard);
            if (!viaKeyboard && _this.fixFocusOnOptionClickEnabled) {
                _this.inputBox.focus();
            }
            _this.validate();
        }));
        _this.caseSensitive = _this._register(new CaseSensitiveCheckbox({
            appendTitle: appendCaseSensitiveLabel,
            isChecked: false,
            inputActiveOptionBorder: _this.inputActiveOptionBorder,
            inputActiveOptionBackground: _this.inputActiveOptionBackground
        }));
        _this._register(_this.caseSensitive.onChange(function (viaKeyboard) {
            _this._onDidOptionChange.fire(viaKeyboard);
            if (!viaKeyboard && _this.fixFocusOnOptionClickEnabled) {
                _this.inputBox.focus();
            }
            _this.validate();
        }));
        _this._register(_this.caseSensitive.onKeyDown(function (e) {
            _this._onCaseSensitiveKeyDown.fire(e);
        }));
        if (_this._showOptionButtons) {
            _this.inputBox.paddingRight = _this.caseSensitive.width() + _this.wholeWords.width() + _this.regex.width();
        }
        // Arrow-Key support to navigate between options
        var indexes = [_this.caseSensitive.domNode, _this.wholeWords.domNode, _this.regex.domNode];
        _this.onkeydown(_this.domNode, function (event) {
            if (event.equals(15 /* LeftArrow */) || event.equals(17 /* RightArrow */) || event.equals(9 /* Escape */)) {
                var index = indexes.indexOf(document.activeElement);
                if (index >= 0) {
                    var newIndex = -1;
                    if (event.equals(17 /* RightArrow */)) {
                        newIndex = (index + 1) % indexes.length;
                    }
                    else if (event.equals(15 /* LeftArrow */)) {
                        if (index === 0) {
                            newIndex = indexes.length - 1;
                        }
                        else {
                            newIndex = index - 1;
                        }
                    }
                    if (event.equals(9 /* Escape */)) {
                        indexes[index].blur();
                    }
                    else if (newIndex >= 0) {
                        indexes[newIndex].focus();
                    }
                    dom.EventHelper.stop(event, true);
                }
            }
        });
        var controls = document.createElement('div');
        controls.className = 'controls';
        controls.style.display = _this._showOptionButtons ? 'block' : 'none';
        controls.appendChild(_this.caseSensitive.domNode);
        controls.appendChild(_this.wholeWords.domNode);
        controls.appendChild(_this.regex.domNode);
        _this.domNode.appendChild(controls);
        if (parent) {
            parent.appendChild(_this.domNode);
        }
        _this.onkeydown(_this.inputBox.inputElement, function (e) { return _this._onKeyDown.fire(e); });
        _this.onkeyup(_this.inputBox.inputElement, function (e) { return _this._onKeyUp.fire(e); });
        _this.oninput(_this.inputBox.inputElement, function (e) { return _this._onInput.fire(); });
        _this.onmousedown(_this.inputBox.inputElement, function (e) { return _this._onMouseDown.fire(e); });
        return _this;
    }
    FindInput.prototype.enable = function () {
        dom.removeClass(this.domNode, 'disabled');
        this.inputBox.enable();
        this.regex.enable();
        this.wholeWords.enable();
        this.caseSensitive.enable();
    };
    FindInput.prototype.disable = function () {
        dom.addClass(this.domNode, 'disabled');
        this.inputBox.disable();
        this.regex.disable();
        this.wholeWords.disable();
        this.caseSensitive.disable();
    };
    FindInput.prototype.setFocusInputOnOptionClick = function (value) {
        this.fixFocusOnOptionClickEnabled = value;
    };
    FindInput.prototype.setEnabled = function (enabled) {
        if (enabled) {
            this.enable();
        }
        else {
            this.disable();
        }
    };
    FindInput.prototype.getValue = function () {
        return this.inputBox.value;
    };
    FindInput.prototype.setValue = function (value) {
        if (this.inputBox.value !== value) {
            this.inputBox.value = value;
        }
    };
    FindInput.prototype.style = function (styles) {
        this.inputActiveOptionBorder = styles.inputActiveOptionBorder;
        this.inputActiveOptionBackground = styles.inputActiveOptionBackground;
        this.inputBackground = styles.inputBackground;
        this.inputForeground = styles.inputForeground;
        this.inputBorder = styles.inputBorder;
        this.inputValidationInfoBackground = styles.inputValidationInfoBackground;
        this.inputValidationInfoForeground = styles.inputValidationInfoForeground;
        this.inputValidationInfoBorder = styles.inputValidationInfoBorder;
        this.inputValidationWarningBackground = styles.inputValidationWarningBackground;
        this.inputValidationWarningForeground = styles.inputValidationWarningForeground;
        this.inputValidationWarningBorder = styles.inputValidationWarningBorder;
        this.inputValidationErrorBackground = styles.inputValidationErrorBackground;
        this.inputValidationErrorForeground = styles.inputValidationErrorForeground;
        this.inputValidationErrorBorder = styles.inputValidationErrorBorder;
        this.applyStyles();
    };
    FindInput.prototype.applyStyles = function () {
        if (this.domNode) {
            var checkBoxStyles = {
                inputActiveOptionBorder: this.inputActiveOptionBorder,
                inputActiveOptionBackground: this.inputActiveOptionBackground,
            };
            this.regex.style(checkBoxStyles);
            this.wholeWords.style(checkBoxStyles);
            this.caseSensitive.style(checkBoxStyles);
            var inputBoxStyles = {
                inputBackground: this.inputBackground,
                inputForeground: this.inputForeground,
                inputBorder: this.inputBorder,
                inputValidationInfoBackground: this.inputValidationInfoBackground,
                inputValidationInfoForeground: this.inputValidationInfoForeground,
                inputValidationInfoBorder: this.inputValidationInfoBorder,
                inputValidationWarningBackground: this.inputValidationWarningBackground,
                inputValidationWarningForeground: this.inputValidationWarningForeground,
                inputValidationWarningBorder: this.inputValidationWarningBorder,
                inputValidationErrorBackground: this.inputValidationErrorBackground,
                inputValidationErrorForeground: this.inputValidationErrorForeground,
                inputValidationErrorBorder: this.inputValidationErrorBorder
            };
            this.inputBox.style(inputBoxStyles);
        }
    };
    FindInput.prototype.select = function () {
        this.inputBox.select();
    };
    FindInput.prototype.focus = function () {
        this.inputBox.focus();
    };
    FindInput.prototype.getCaseSensitive = function () {
        return this.caseSensitive.checked;
    };
    FindInput.prototype.setCaseSensitive = function (value) {
        this.caseSensitive.checked = value;
    };
    FindInput.prototype.getWholeWords = function () {
        return this.wholeWords.checked;
    };
    FindInput.prototype.setWholeWords = function (value) {
        this.wholeWords.checked = value;
    };
    FindInput.prototype.getRegex = function () {
        return this.regex.checked;
    };
    FindInput.prototype.setRegex = function (value) {
        this.regex.checked = value;
        this.validate();
    };
    FindInput.prototype.focusOnCaseSensitive = function () {
        this.caseSensitive.focus();
    };
    FindInput.prototype.highlightFindOptions = function () {
        dom.removeClass(this.domNode, 'highlight-' + (this._lastHighlightFindOptions));
        this._lastHighlightFindOptions = 1 - this._lastHighlightFindOptions;
        dom.addClass(this.domNode, 'highlight-' + (this._lastHighlightFindOptions));
    };
    FindInput.prototype.validate = function () {
        if (this.inputBox) {
            this.inputBox.validate();
        }
    };
    FindInput.prototype.clearMessage = function () {
        if (this.inputBox) {
            this.inputBox.hideMessage();
        }
    };
    FindInput.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
    };
    return FindInput;
}(Widget));
export { FindInput };
