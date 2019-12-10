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
import './findWidget.css';
import * as nls from '../../../nls.js';
import * as dom from '../../../base/browser/dom.js';
import { alert as alertFn } from '../../../base/browser/ui/aria/aria.js';
import { Sash } from '../../../base/browser/ui/sash/sash.js';
import { Widget } from '../../../base/browser/ui/widget.js';
import { Delayer } from '../../../base/common/async.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { toDisposable } from '../../../base/common/lifecycle.js';
import * as platform from '../../../base/common/platform.js';
import * as strings from '../../../base/common/strings.js';
import { Range } from '../../common/core/range.js';
import { CONTEXT_FIND_INPUT_FOCUSED, CONTEXT_REPLACE_INPUT_FOCUSED, FIND_IDS, MATCHES_LIMIT } from './findModel.js';
import { contrastBorder, editorFindMatch, editorFindMatchBorder, editorFindMatchHighlight, editorFindMatchHighlightBorder, editorFindRangeHighlight, editorFindRangeHighlightBorder, editorWidgetBackground, editorWidgetBorder, editorWidgetResizeBorder, errorForeground, inputActiveOptionBorder, inputActiveOptionBackground, inputBackground, inputBorder, inputForeground, inputValidationErrorBackground, inputValidationErrorBorder, inputValidationErrorForeground, inputValidationInfoBackground, inputValidationInfoBorder, inputValidationInfoForeground, inputValidationWarningBackground, inputValidationWarningBorder, inputValidationWarningForeground, widgetShadow, editorWidgetForeground, focusBorder } from '../../../platform/theme/common/colorRegistry.js';
import { registerThemingParticipant } from '../../../platform/theme/common/themeService.js';
import { ContextScopedFindInput, ContextScopedReplaceInput } from '../../../platform/browser/contextScopedHistoryWidget.js';
var NLS_FIND_INPUT_LABEL = nls.localize('label.find', "Find");
var NLS_FIND_INPUT_PLACEHOLDER = nls.localize('placeholder.find', "Find");
var NLS_PREVIOUS_MATCH_BTN_LABEL = nls.localize('label.previousMatchButton', "Previous match");
var NLS_NEXT_MATCH_BTN_LABEL = nls.localize('label.nextMatchButton', "Next match");
var NLS_TOGGLE_SELECTION_FIND_TITLE = nls.localize('label.toggleSelectionFind', "Find in selection");
var NLS_CLOSE_BTN_LABEL = nls.localize('label.closeButton', "Close");
var NLS_REPLACE_INPUT_LABEL = nls.localize('label.replace', "Replace");
var NLS_REPLACE_INPUT_PLACEHOLDER = nls.localize('placeholder.replace', "Replace");
var NLS_REPLACE_BTN_LABEL = nls.localize('label.replaceButton', "Replace");
var NLS_REPLACE_ALL_BTN_LABEL = nls.localize('label.replaceAllButton', "Replace All");
var NLS_TOGGLE_REPLACE_MODE_BTN_LABEL = nls.localize('label.toggleReplaceButton', "Toggle Replace mode");
var NLS_MATCHES_COUNT_LIMIT_TITLE = nls.localize('title.matchesCountLimit', "Only the first {0} results are highlighted, but all find operations work on the entire text.", MATCHES_LIMIT);
var NLS_MATCHES_LOCATION = nls.localize('label.matchesLocation', "{0} of {1}");
var NLS_NO_RESULTS = nls.localize('label.noResults', "No Results");
var FIND_WIDGET_INITIAL_WIDTH = 419;
var PART_WIDTH = 275;
var FIND_INPUT_AREA_WIDTH = PART_WIDTH - 54;
var MAX_MATCHES_COUNT_WIDTH = 69;
var FIND_ALL_CONTROLS_WIDTH = 17 /** Find Input margin-left */ + (MAX_MATCHES_COUNT_WIDTH + 3 + 1) /** Match Results */ + 23 /** Button */ * 4 + 2 /** sash */;
var FIND_INPUT_AREA_HEIGHT = 33; // The height of Find Widget when Replace Input is not visible.
var ctrlEnterReplaceAllWarningPromptedKey = 'ctrlEnterReplaceAll.windows.donotask';
var ctrlKeyMod = (platform.isMacintosh ? 256 /* WinCtrl */ : 2048 /* CtrlCmd */);
var FindWidgetViewZone = /** @class */ (function () {
    function FindWidgetViewZone(afterLineNumber) {
        this.afterLineNumber = afterLineNumber;
        this.heightInPx = FIND_INPUT_AREA_HEIGHT;
        this.suppressMouseDown = false;
        this.domNode = document.createElement('div');
        this.domNode.className = 'dock-find-viewzone';
    }
    return FindWidgetViewZone;
}());
export { FindWidgetViewZone };
function stopPropagationForMultiLineUpwards(event, value, textarea) {
    var isMultiline = !!value.match(/\n/);
    if (textarea && isMultiline && textarea.selectionStart > 0) {
        event.stopPropagation();
        return;
    }
}
function stopPropagationForMultiLineDownwards(event, value, textarea) {
    var isMultiline = !!value.match(/\n/);
    if (textarea && isMultiline && textarea.selectionEnd < textarea.value.length) {
        event.stopPropagation();
        return;
    }
}
var FindWidget = /** @class */ (function (_super) {
    __extends(FindWidget, _super);
    function FindWidget(codeEditor, controller, state, contextViewProvider, keybindingService, contextKeyService, themeService, storageService, notificationService) {
        var _this = _super.call(this) || this;
        _this._codeEditor = codeEditor;
        _this._controller = controller;
        _this._state = state;
        _this._contextViewProvider = contextViewProvider;
        _this._keybindingService = keybindingService;
        _this._contextKeyService = contextKeyService;
        _this._storageService = storageService;
        _this._notificationService = notificationService;
        _this._ctrlEnterReplaceAllWarningPrompted = !!storageService.getBoolean(ctrlEnterReplaceAllWarningPromptedKey, 0 /* GLOBAL */);
        _this._isVisible = false;
        _this._isReplaceVisible = false;
        _this._ignoreChangeEvent = false;
        _this._updateHistoryDelayer = new Delayer(500);
        _this._register(toDisposable(function () { return _this._updateHistoryDelayer.cancel(); }));
        _this._register(_this._state.onFindReplaceStateChange(function (e) { return _this._onStateChanged(e); }));
        _this._buildDomNode();
        _this._updateButtons();
        _this._tryUpdateWidgetWidth();
        _this._findInput.inputBox.layout();
        _this._register(_this._codeEditor.onDidChangeConfiguration(function (e) {
            if (e.readOnly) {
                if (_this._codeEditor.getConfiguration().readOnly) {
                    // Hide replace part if editor becomes read only
                    _this._state.change({ isReplaceRevealed: false }, false);
                }
                _this._updateButtons();
            }
            if (e.layoutInfo) {
                _this._tryUpdateWidgetWidth();
            }
            if (e.accessibilitySupport) {
                _this.updateAccessibilitySupport();
            }
            if (e.contribInfo) {
                var addExtraSpaceOnTop = _this._codeEditor.getConfiguration().contribInfo.find.addExtraSpaceOnTop;
                if (addExtraSpaceOnTop && !_this._viewZone) {
                    _this._viewZone = new FindWidgetViewZone(0);
                    _this._showViewZone();
                }
                if (!addExtraSpaceOnTop && _this._viewZone) {
                    _this._removeViewZone();
                }
            }
        }));
        _this.updateAccessibilitySupport();
        _this._register(_this._codeEditor.onDidChangeCursorSelection(function () {
            if (_this._isVisible) {
                _this._updateToggleSelectionFindButton();
            }
        }));
        _this._register(_this._codeEditor.onDidFocusEditorWidget(function () {
            if (_this._isVisible) {
                var globalBufferTerm = _this._controller.getGlobalBufferTerm();
                if (globalBufferTerm && globalBufferTerm !== _this._state.searchString) {
                    _this._state.change({ searchString: globalBufferTerm }, true);
                    _this._findInput.select();
                }
            }
        }));
        _this._findInputFocused = CONTEXT_FIND_INPUT_FOCUSED.bindTo(contextKeyService);
        _this._findFocusTracker = _this._register(dom.trackFocus(_this._findInput.inputBox.inputElement));
        _this._register(_this._findFocusTracker.onDidFocus(function () {
            _this._findInputFocused.set(true);
            _this._updateSearchScope();
        }));
        _this._register(_this._findFocusTracker.onDidBlur(function () {
            _this._findInputFocused.set(false);
        }));
        _this._replaceInputFocused = CONTEXT_REPLACE_INPUT_FOCUSED.bindTo(contextKeyService);
        _this._replaceFocusTracker = _this._register(dom.trackFocus(_this._replaceInput.inputBox.inputElement));
        _this._register(_this._replaceFocusTracker.onDidFocus(function () {
            _this._replaceInputFocused.set(true);
            _this._updateSearchScope();
        }));
        _this._register(_this._replaceFocusTracker.onDidBlur(function () {
            _this._replaceInputFocused.set(false);
        }));
        _this._codeEditor.addOverlayWidget(_this);
        if (_this._codeEditor.getConfiguration().contribInfo.find.addExtraSpaceOnTop) {
            _this._viewZone = new FindWidgetViewZone(0); // Put it before the first line then users can scroll beyond the first line.
        }
        _this._applyTheme(themeService.getTheme());
        _this._register(themeService.onThemeChange(_this._applyTheme.bind(_this)));
        _this._register(_this._codeEditor.onDidChangeModel(function () {
            if (!_this._isVisible) {
                return;
            }
            _this._viewZoneId = undefined;
        }));
        _this._register(_this._codeEditor.onDidScrollChange(function (e) {
            if (e.scrollTopChanged) {
                _this._layoutViewZone();
                return;
            }
            // for other scroll changes, layout the viewzone in next tick to avoid ruining current rendering.
            setTimeout(function () {
                _this._layoutViewZone();
            }, 0);
        }));
        return _this;
    }
    // ----- IOverlayWidget API
    FindWidget.prototype.getId = function () {
        return FindWidget.ID;
    };
    FindWidget.prototype.getDomNode = function () {
        return this._domNode;
    };
    FindWidget.prototype.getPosition = function () {
        if (this._isVisible) {
            return {
                preference: 0 /* TOP_RIGHT_CORNER */
            };
        }
        return null;
    };
    // ----- React to state changes
    FindWidget.prototype._onStateChanged = function (e) {
        if (e.searchString) {
            if (this._state.searchString.indexOf('\n') >= 0) {
                dom.addClass(this._domNode, 'multipleline');
            }
            else {
                dom.removeClass(this._domNode, 'multipleline');
            }
            try {
                this._ignoreChangeEvent = true;
                this._findInput.setValue(this._state.searchString);
            }
            finally {
                this._ignoreChangeEvent = false;
            }
            this._updateButtons();
        }
        if (e.replaceString) {
            this._replaceInput.inputBox.value = this._state.replaceString;
        }
        if (e.isRevealed) {
            if (this._state.isRevealed) {
                this._reveal();
            }
            else {
                this._hide(true);
            }
        }
        if (e.isReplaceRevealed) {
            if (this._state.isReplaceRevealed) {
                if (!this._codeEditor.getConfiguration().readOnly && !this._isReplaceVisible) {
                    this._isReplaceVisible = true;
                    this._replaceInput.width = dom.getTotalWidth(this._findInput.domNode);
                    this._updateButtons();
                    this._replaceInput.inputBox.layout();
                }
            }
            else {
                if (this._isReplaceVisible) {
                    this._isReplaceVisible = false;
                    this._updateButtons();
                }
            }
        }
        if ((e.isRevealed || e.isReplaceRevealed) && (this._state.isRevealed || this._state.isReplaceRevealed)) {
            if (this._tryUpdateHeight()) {
                this._showViewZone();
            }
        }
        if (e.isRegex) {
            this._findInput.setRegex(this._state.isRegex);
        }
        if (e.wholeWord) {
            this._findInput.setWholeWords(this._state.wholeWord);
        }
        if (e.matchCase) {
            this._findInput.setCaseSensitive(this._state.matchCase);
        }
        if (e.searchScope) {
            if (this._state.searchScope) {
                this._toggleSelectionFind.checked = true;
            }
            else {
                this._toggleSelectionFind.checked = false;
            }
            this._updateToggleSelectionFindButton();
        }
        if (e.searchString || e.matchesCount || e.matchesPosition) {
            var showRedOutline = (this._state.searchString.length > 0 && this._state.matchesCount === 0);
            dom.toggleClass(this._domNode, 'no-results', showRedOutline);
            this._updateMatchesCount();
            this._updateButtons();
        }
        if (e.searchString || e.currentMatch) {
            this._layoutViewZone();
        }
        if (e.updateHistory) {
            this._delayedUpdateHistory();
        }
    };
    FindWidget.prototype._delayedUpdateHistory = function () {
        this._updateHistoryDelayer.trigger(this._updateHistory.bind(this));
    };
    FindWidget.prototype._updateHistory = function () {
        if (this._state.searchString) {
            this._findInput.inputBox.addToHistory();
        }
        if (this._state.replaceString) {
            this._replaceInput.inputBox.addToHistory();
        }
    };
    FindWidget.prototype._updateMatchesCount = function () {
        this._matchesCount.style.minWidth = MAX_MATCHES_COUNT_WIDTH + 'px';
        if (this._state.matchesCount >= MATCHES_LIMIT) {
            this._matchesCount.title = NLS_MATCHES_COUNT_LIMIT_TITLE;
        }
        else {
            this._matchesCount.title = '';
        }
        // remove previous content
        if (this._matchesCount.firstChild) {
            this._matchesCount.removeChild(this._matchesCount.firstChild);
        }
        var label;
        if (this._state.matchesCount > 0) {
            var matchesCount = String(this._state.matchesCount);
            if (this._state.matchesCount >= MATCHES_LIMIT) {
                matchesCount += '+';
            }
            var matchesPosition = String(this._state.matchesPosition);
            if (matchesPosition === '0') {
                matchesPosition = '?';
            }
            label = strings.format(NLS_MATCHES_LOCATION, matchesPosition, matchesCount);
        }
        else {
            label = NLS_NO_RESULTS;
        }
        this._matchesCount.appendChild(document.createTextNode(label));
        alertFn(this._getAriaLabel(label, this._state.currentMatch, this._state.searchString), true);
        MAX_MATCHES_COUNT_WIDTH = Math.max(MAX_MATCHES_COUNT_WIDTH, this._matchesCount.clientWidth);
    };
    // ----- actions
    FindWidget.prototype._getAriaLabel = function (label, currentMatch, searchString) {
        if (label === NLS_NO_RESULTS) {
            return searchString === ''
                ? nls.localize('ariaSearchNoResultEmpty', "{0} found", label)
                : nls.localize('ariaSearchNoResult', "{0} found for {1}", label, searchString);
        }
        return currentMatch
            ? nls.localize('ariaSearchNoResultWithLineNum', "{0} found for {1} at {2}", label, searchString, currentMatch.startLineNumber + ':' + currentMatch.startColumn)
            : nls.localize('ariaSearchNoResultWithLineNumNoCurrentMatch', "{0} found for {1}", label, searchString);
    };
    /**
     * If 'selection find' is ON we should not disable the button (its function is to cancel 'selection find').
     * If 'selection find' is OFF we enable the button only if there is a selection.
     */
    FindWidget.prototype._updateToggleSelectionFindButton = function () {
        var selection = this._codeEditor.getSelection();
        var isSelection = selection ? (selection.startLineNumber !== selection.endLineNumber || selection.startColumn !== selection.endColumn) : false;
        var isChecked = this._toggleSelectionFind.checked;
        this._toggleSelectionFind.setEnabled(this._isVisible && (isChecked || isSelection));
    };
    FindWidget.prototype._updateButtons = function () {
        this._findInput.setEnabled(this._isVisible);
        this._replaceInput.setEnabled(this._isVisible && this._isReplaceVisible);
        this._updateToggleSelectionFindButton();
        this._closeBtn.setEnabled(this._isVisible);
        var findInputIsNonEmpty = (this._state.searchString.length > 0);
        var matchesCount = this._state.matchesCount ? true : false;
        this._prevBtn.setEnabled(this._isVisible && findInputIsNonEmpty && matchesCount);
        this._nextBtn.setEnabled(this._isVisible && findInputIsNonEmpty && matchesCount);
        this._replaceBtn.setEnabled(this._isVisible && this._isReplaceVisible && findInputIsNonEmpty);
        this._replaceAllBtn.setEnabled(this._isVisible && this._isReplaceVisible && findInputIsNonEmpty);
        dom.toggleClass(this._domNode, 'replaceToggled', this._isReplaceVisible);
        this._toggleReplaceBtn.toggleClass('collapse', !this._isReplaceVisible);
        this._toggleReplaceBtn.toggleClass('expand', this._isReplaceVisible);
        this._toggleReplaceBtn.setExpanded(this._isReplaceVisible);
        var canReplace = !this._codeEditor.getConfiguration().readOnly;
        this._toggleReplaceBtn.setEnabled(this._isVisible && canReplace);
    };
    FindWidget.prototype._reveal = function () {
        var _this = this;
        if (!this._isVisible) {
            this._isVisible = true;
            var selection = this._codeEditor.getSelection();
            var isSelection = selection ? (selection.startLineNumber !== selection.endLineNumber || selection.startColumn !== selection.endColumn) : false;
            if (isSelection && this._codeEditor.getConfiguration().contribInfo.find.autoFindInSelection) {
                this._toggleSelectionFind.checked = true;
            }
            else {
                this._toggleSelectionFind.checked = false;
            }
            this._tryUpdateWidgetWidth();
            this._updateButtons();
            setTimeout(function () {
                dom.addClass(_this._domNode, 'visible');
                _this._domNode.setAttribute('aria-hidden', 'false');
            }, 0);
            // validate query again as it's being dismissed when we hide the find widget.
            setTimeout(function () {
                _this._findInput.validate();
            }, 200);
            this._codeEditor.layoutOverlayWidget(this);
            var adjustEditorScrollTop = true;
            if (this._codeEditor.getConfiguration().contribInfo.find.seedSearchStringFromSelection && selection) {
                var domNode = this._codeEditor.getDomNode();
                if (domNode) {
                    var editorCoords = dom.getDomNodePagePosition(domNode);
                    var startCoords = this._codeEditor.getScrolledVisiblePosition(selection.getStartPosition());
                    var startLeft = editorCoords.left + (startCoords ? startCoords.left : 0);
                    var startTop = startCoords ? startCoords.top : 0;
                    if (this._viewZone && startTop < this._viewZone.heightInPx) {
                        if (selection.endLineNumber > selection.startLineNumber) {
                            adjustEditorScrollTop = false;
                        }
                        var leftOfFindWidget = dom.getTopLeftOffset(this._domNode).left;
                        if (startLeft > leftOfFindWidget) {
                            adjustEditorScrollTop = false;
                        }
                        var endCoords = this._codeEditor.getScrolledVisiblePosition(selection.getEndPosition());
                        var endLeft = editorCoords.left + (endCoords ? endCoords.left : 0);
                        if (endLeft > leftOfFindWidget) {
                            adjustEditorScrollTop = false;
                        }
                    }
                }
            }
            this._showViewZone(adjustEditorScrollTop);
        }
    };
    FindWidget.prototype._hide = function (focusTheEditor) {
        if (this._isVisible) {
            this._isVisible = false;
            this._updateButtons();
            dom.removeClass(this._domNode, 'visible');
            this._domNode.setAttribute('aria-hidden', 'true');
            this._findInput.clearMessage();
            if (focusTheEditor) {
                this._codeEditor.focus();
            }
            this._codeEditor.layoutOverlayWidget(this);
            this._removeViewZone();
        }
    };
    FindWidget.prototype._layoutViewZone = function () {
        var _this = this;
        var addExtraSpaceOnTop = this._codeEditor.getConfiguration().contribInfo.find.addExtraSpaceOnTop;
        if (!addExtraSpaceOnTop) {
            this._removeViewZone();
            return;
        }
        if (!this._isVisible) {
            return;
        }
        var viewZone = this._viewZone;
        if (this._viewZoneId !== undefined || !viewZone) {
            return;
        }
        this._codeEditor.changeViewZones(function (accessor) {
            viewZone.heightInPx = _this._getHeight();
            _this._viewZoneId = accessor.addZone(viewZone);
            // scroll top adjust to make sure the editor doesn't scroll when adding viewzone at the beginning.
            _this._codeEditor.setScrollTop(_this._codeEditor.getScrollTop() + viewZone.heightInPx);
        });
    };
    FindWidget.prototype._showViewZone = function (adjustScroll) {
        var _this = this;
        if (adjustScroll === void 0) { adjustScroll = true; }
        if (!this._isVisible) {
            return;
        }
        var addExtraSpaceOnTop = this._codeEditor.getConfiguration().contribInfo.find.addExtraSpaceOnTop;
        if (!addExtraSpaceOnTop) {
            return;
        }
        if (this._viewZone === undefined) {
            this._viewZone = new FindWidgetViewZone(0);
        }
        var viewZone = this._viewZone;
        this._codeEditor.changeViewZones(function (accessor) {
            if (_this._viewZoneId !== undefined) {
                // the view zone already exists, we need to update the height
                var newHeight = _this._getHeight();
                if (newHeight === viewZone.heightInPx) {
                    return;
                }
                var scrollAdjustment = newHeight - viewZone.heightInPx;
                viewZone.heightInPx = newHeight;
                accessor.layoutZone(_this._viewZoneId);
                if (adjustScroll) {
                    _this._codeEditor.setScrollTop(_this._codeEditor.getScrollTop() + scrollAdjustment);
                }
                return;
            }
            else {
                var scrollAdjustment = _this._getHeight();
                viewZone.heightInPx = scrollAdjustment;
                _this._viewZoneId = accessor.addZone(viewZone);
                if (adjustScroll) {
                    _this._codeEditor.setScrollTop(_this._codeEditor.getScrollTop() + scrollAdjustment);
                }
            }
        });
    };
    FindWidget.prototype._removeViewZone = function () {
        var _this = this;
        this._codeEditor.changeViewZones(function (accessor) {
            if (_this._viewZoneId !== undefined) {
                accessor.removeZone(_this._viewZoneId);
                _this._viewZoneId = undefined;
                if (_this._viewZone) {
                    _this._codeEditor.setScrollTop(_this._codeEditor.getScrollTop() - _this._viewZone.heightInPx);
                    _this._viewZone = undefined;
                }
            }
        });
    };
    FindWidget.prototype._applyTheme = function (theme) {
        var inputStyles = {
            inputActiveOptionBorder: theme.getColor(inputActiveOptionBorder),
            inputActiveOptionBackground: theme.getColor(inputActiveOptionBackground),
            inputBackground: theme.getColor(inputBackground),
            inputForeground: theme.getColor(inputForeground),
            inputBorder: theme.getColor(inputBorder),
            inputValidationInfoBackground: theme.getColor(inputValidationInfoBackground),
            inputValidationInfoForeground: theme.getColor(inputValidationInfoForeground),
            inputValidationInfoBorder: theme.getColor(inputValidationInfoBorder),
            inputValidationWarningBackground: theme.getColor(inputValidationWarningBackground),
            inputValidationWarningForeground: theme.getColor(inputValidationWarningForeground),
            inputValidationWarningBorder: theme.getColor(inputValidationWarningBorder),
            inputValidationErrorBackground: theme.getColor(inputValidationErrorBackground),
            inputValidationErrorForeground: theme.getColor(inputValidationErrorForeground),
            inputValidationErrorBorder: theme.getColor(inputValidationErrorBorder),
        };
        this._findInput.style(inputStyles);
        this._replaceInput.style(inputStyles);
    };
    FindWidget.prototype._tryUpdateWidgetWidth = function () {
        if (!this._isVisible) {
            return;
        }
        var editorContentWidth = this._codeEditor.getConfiguration().layoutInfo.contentWidth;
        if (editorContentWidth <= 0) {
            // for example, diff view original editor
            dom.addClass(this._domNode, 'hiddenEditor');
            return;
        }
        else if (dom.hasClass(this._domNode, 'hiddenEditor')) {
            dom.removeClass(this._domNode, 'hiddenEditor');
        }
        var editorWidth = this._codeEditor.getConfiguration().layoutInfo.width;
        var minimapWidth = this._codeEditor.getConfiguration().layoutInfo.minimapWidth;
        var collapsedFindWidget = false;
        var reducedFindWidget = false;
        var narrowFindWidget = false;
        if (this._resized) {
            var widgetWidth = dom.getTotalWidth(this._domNode);
            if (widgetWidth > FIND_WIDGET_INITIAL_WIDTH) {
                // as the widget is resized by users, we may need to change the max width of the widget as the editor width changes.
                this._domNode.style.maxWidth = editorWidth - 28 - minimapWidth - 15 + "px";
                this._replaceInput.width = dom.getTotalWidth(this._findInput.domNode);
                return;
            }
        }
        if (FIND_WIDGET_INITIAL_WIDTH + 28 + minimapWidth >= editorWidth) {
            reducedFindWidget = true;
        }
        if (FIND_WIDGET_INITIAL_WIDTH + 28 + minimapWidth - MAX_MATCHES_COUNT_WIDTH >= editorWidth) {
            narrowFindWidget = true;
        }
        if (FIND_WIDGET_INITIAL_WIDTH + 28 + minimapWidth - MAX_MATCHES_COUNT_WIDTH >= editorWidth + 50) {
            collapsedFindWidget = true;
        }
        dom.toggleClass(this._domNode, 'collapsed-find-widget', collapsedFindWidget);
        dom.toggleClass(this._domNode, 'narrow-find-widget', narrowFindWidget);
        dom.toggleClass(this._domNode, 'reduced-find-widget', reducedFindWidget);
        if (!narrowFindWidget && !collapsedFindWidget) {
            // the minimal left offset of findwidget is 15px.
            this._domNode.style.maxWidth = editorWidth - 28 - minimapWidth - 15 + "px";
        }
        if (this._resized) {
            this._findInput.inputBox.layout();
            var findInputWidth = this._findInput.inputBox.width;
            if (findInputWidth > 0) {
                this._replaceInput.width = findInputWidth;
            }
        }
    };
    FindWidget.prototype._getHeight = function () {
        var totalheight = 0;
        // find input margin top
        totalheight += 4;
        // find input height
        totalheight += this._findInput.inputBox.height + 2 /** input box border */;
        if (this._isReplaceVisible) {
            // replace input margin
            totalheight += 4;
            totalheight += this._replaceInput.inputBox.height + 2 /** input box border */;
        }
        // margin bottom
        totalheight += 4;
        return totalheight;
    };
    FindWidget.prototype._tryUpdateHeight = function () {
        var totalHeight = this._getHeight();
        if (this._cachedHeight !== null && this._cachedHeight === totalHeight) {
            return false;
        }
        this._cachedHeight = totalHeight;
        this._domNode.style.height = totalHeight + "px";
        return true;
    };
    // ----- Public
    FindWidget.prototype.focusFindInput = function () {
        this._findInput.select();
        // Edge browser requires focus() in addition to select()
        this._findInput.focus();
    };
    FindWidget.prototype.focusReplaceInput = function () {
        this._replaceInput.select();
        // Edge browser requires focus() in addition to select()
        this._replaceInput.focus();
    };
    FindWidget.prototype.highlightFindOptions = function () {
        this._findInput.highlightFindOptions();
    };
    FindWidget.prototype._updateSearchScope = function () {
        if (!this._codeEditor.hasModel()) {
            return;
        }
        if (this._toggleSelectionFind.checked) {
            var selection = this._codeEditor.getSelection();
            if (selection.endColumn === 1 && selection.endLineNumber > selection.startLineNumber) {
                selection = selection.setEndPosition(selection.endLineNumber - 1, this._codeEditor.getModel().getLineMaxColumn(selection.endLineNumber - 1));
            }
            var currentMatch = this._state.currentMatch;
            if (selection.startLineNumber !== selection.endLineNumber) {
                if (!Range.equalsRange(selection, currentMatch)) {
                    // Reseed find scope
                    this._state.change({ searchScope: selection }, true);
                }
            }
        }
    };
    FindWidget.prototype._onFindInputMouseDown = function (e) {
        // on linux, middle key does pasting.
        if (e.middleButton) {
            e.stopPropagation();
        }
    };
    FindWidget.prototype._onFindInputKeyDown = function (e) {
        if (e.equals(ctrlKeyMod | 3 /* Enter */)) {
            var inputElement = this._findInput.inputBox.inputElement;
            var start = inputElement.selectionStart;
            var end = inputElement.selectionEnd;
            var content = inputElement.value;
            if (start !== null && end !== null) {
                var value = content.substr(0, start) + '\n' + content.substr(end);
                this._findInput.inputBox.value = value;
                inputElement.setSelectionRange(start + 1, start + 1);
                this._findInput.inputBox.layout();
                e.preventDefault();
                return;
            }
        }
        if (e.equals(2 /* Tab */)) {
            if (this._isReplaceVisible) {
                this._replaceInput.focus();
            }
            else {
                this._findInput.focusOnCaseSensitive();
            }
            e.preventDefault();
            return;
        }
        if (e.equals(2048 /* CtrlCmd */ | 18 /* DownArrow */)) {
            this._codeEditor.focus();
            e.preventDefault();
            return;
        }
        if (e.equals(16 /* UpArrow */)) {
            return stopPropagationForMultiLineUpwards(e, this._findInput.getValue(), this._findInput.domNode.querySelector('textarea'));
        }
        if (e.equals(18 /* DownArrow */)) {
            return stopPropagationForMultiLineDownwards(e, this._findInput.getValue(), this._findInput.domNode.querySelector('textarea'));
        }
    };
    FindWidget.prototype._onReplaceInputKeyDown = function (e) {
        if (e.equals(ctrlKeyMod | 3 /* Enter */)) {
            if (platform.isWindows && platform.isNative && !this._ctrlEnterReplaceAllWarningPrompted) {
                // this is the first time when users press Ctrl + Enter to replace all
                this._notificationService.info(nls.localize('ctrlEnter.keybindingChanged', 'Ctrl+Enter now inserts line break instead of replacing all. You can modify the keybinding for editor.action.replaceAll to override this behavior.'));
                this._ctrlEnterReplaceAllWarningPrompted = true;
                this._storageService.store(ctrlEnterReplaceAllWarningPromptedKey, true, 0 /* GLOBAL */);
            }
            var inputElement = this._replaceInput.inputBox.inputElement;
            var start = inputElement.selectionStart;
            var end = inputElement.selectionEnd;
            var content = inputElement.value;
            if (start !== null && end !== null) {
                var value = content.substr(0, start) + '\n' + content.substr(end);
                this._replaceInput.inputBox.value = value;
                inputElement.setSelectionRange(start + 1, start + 1);
                this._replaceInput.inputBox.layout();
                e.preventDefault();
                return;
            }
        }
        if (e.equals(2 /* Tab */)) {
            this._findInput.focusOnCaseSensitive();
            e.preventDefault();
            return;
        }
        if (e.equals(1024 /* Shift */ | 2 /* Tab */)) {
            this._findInput.focus();
            e.preventDefault();
            return;
        }
        if (e.equals(2048 /* CtrlCmd */ | 18 /* DownArrow */)) {
            this._codeEditor.focus();
            e.preventDefault();
            return;
        }
        if (e.equals(16 /* UpArrow */)) {
            return stopPropagationForMultiLineUpwards(e, this._replaceInput.inputBox.value, this._replaceInput.inputBox.element.querySelector('textarea'));
        }
        if (e.equals(18 /* DownArrow */)) {
            return stopPropagationForMultiLineDownwards(e, this._replaceInput.inputBox.value, this._replaceInput.inputBox.element.querySelector('textarea'));
        }
    };
    // ----- sash
    FindWidget.prototype.getHorizontalSashTop = function (_sash) {
        return 0;
    };
    FindWidget.prototype.getHorizontalSashLeft = function (_sash) {
        return 0;
    };
    FindWidget.prototype.getHorizontalSashWidth = function (_sash) {
        return 500;
    };
    // ----- initialization
    FindWidget.prototype._keybindingLabelFor = function (actionId) {
        var kb = this._keybindingService.lookupKeybinding(actionId);
        if (!kb) {
            return '';
        }
        return " (" + kb.getLabel() + ")";
    };
    FindWidget.prototype._buildDomNode = function () {
        var _this = this;
        var flexibleHeight = true;
        var flexibleWidth = true;
        // Find input
        this._findInput = this._register(new ContextScopedFindInput(null, this._contextViewProvider, {
            width: FIND_INPUT_AREA_WIDTH,
            label: NLS_FIND_INPUT_LABEL,
            placeholder: NLS_FIND_INPUT_PLACEHOLDER,
            appendCaseSensitiveLabel: this._keybindingLabelFor(FIND_IDS.ToggleCaseSensitiveCommand),
            appendWholeWordsLabel: this._keybindingLabelFor(FIND_IDS.ToggleWholeWordCommand),
            appendRegexLabel: this._keybindingLabelFor(FIND_IDS.ToggleRegexCommand),
            validation: function (value) {
                if (value.length === 0 || !_this._findInput.getRegex()) {
                    return null;
                }
                try {
                    /* tslint:disable-next-line:no-unused-expression */
                    new RegExp(value);
                    return null;
                }
                catch (e) {
                    return { content: e.message };
                }
            },
            flexibleHeight: flexibleHeight,
            flexibleWidth: flexibleWidth,
            flexibleMaxHeight: 118
        }, this._contextKeyService, true));
        this._findInput.setRegex(!!this._state.isRegex);
        this._findInput.setCaseSensitive(!!this._state.matchCase);
        this._findInput.setWholeWords(!!this._state.wholeWord);
        this._register(this._findInput.onKeyDown(function (e) { return _this._onFindInputKeyDown(e); }));
        this._register(this._findInput.inputBox.onDidChange(function () {
            if (_this._ignoreChangeEvent) {
                return;
            }
            _this._state.change({ searchString: _this._findInput.getValue() }, true);
        }));
        this._register(this._findInput.onDidOptionChange(function () {
            _this._state.change({
                isRegex: _this._findInput.getRegex(),
                wholeWord: _this._findInput.getWholeWords(),
                matchCase: _this._findInput.getCaseSensitive()
            }, true);
        }));
        this._register(this._findInput.onCaseSensitiveKeyDown(function (e) {
            if (e.equals(1024 /* Shift */ | 2 /* Tab */)) {
                if (_this._isReplaceVisible) {
                    _this._replaceInput.focus();
                    e.preventDefault();
                }
            }
        }));
        this._register(this._findInput.onRegexKeyDown(function (e) {
            if (e.equals(2 /* Tab */)) {
                if (_this._isReplaceVisible) {
                    _this._replaceInput.focusOnPreserve();
                    e.preventDefault();
                }
            }
        }));
        this._register(this._findInput.inputBox.onDidHeightChange(function (e) {
            if (_this._tryUpdateHeight()) {
                _this._showViewZone();
            }
        }));
        if (platform.isLinux) {
            this._register(this._findInput.onMouseDown(function (e) { return _this._onFindInputMouseDown(e); }));
        }
        this._matchesCount = document.createElement('div');
        this._matchesCount.className = 'matchesCount';
        this._updateMatchesCount();
        // Previous button
        this._prevBtn = this._register(new SimpleButton({
            label: NLS_PREVIOUS_MATCH_BTN_LABEL + this._keybindingLabelFor(FIND_IDS.PreviousMatchFindAction),
            className: 'previous',
            onTrigger: function () {
                _this._codeEditor.getAction(FIND_IDS.PreviousMatchFindAction).run().then(undefined, onUnexpectedError);
            }
        }));
        // Next button
        this._nextBtn = this._register(new SimpleButton({
            label: NLS_NEXT_MATCH_BTN_LABEL + this._keybindingLabelFor(FIND_IDS.NextMatchFindAction),
            className: 'next',
            onTrigger: function () {
                _this._codeEditor.getAction(FIND_IDS.NextMatchFindAction).run().then(undefined, onUnexpectedError);
            }
        }));
        var findPart = document.createElement('div');
        findPart.className = 'find-part';
        findPart.appendChild(this._findInput.domNode);
        var actionsContainer = document.createElement('div');
        actionsContainer.className = 'find-actions';
        findPart.appendChild(actionsContainer);
        actionsContainer.appendChild(this._matchesCount);
        actionsContainer.appendChild(this._prevBtn.domNode);
        actionsContainer.appendChild(this._nextBtn.domNode);
        // Toggle selection button
        this._toggleSelectionFind = this._register(new SimpleCheckbox({
            parent: actionsContainer,
            title: NLS_TOGGLE_SELECTION_FIND_TITLE + this._keybindingLabelFor(FIND_IDS.ToggleSearchScopeCommand),
            onChange: function () {
                if (_this._toggleSelectionFind.checked) {
                    if (_this._codeEditor.hasModel()) {
                        var selection = _this._codeEditor.getSelection();
                        if (selection.endColumn === 1 && selection.endLineNumber > selection.startLineNumber) {
                            selection = selection.setEndPosition(selection.endLineNumber - 1, _this._codeEditor.getModel().getLineMaxColumn(selection.endLineNumber - 1));
                        }
                        if (!selection.isEmpty()) {
                            _this._state.change({ searchScope: selection }, true);
                        }
                    }
                }
                else {
                    _this._state.change({ searchScope: null }, true);
                }
            }
        }));
        // Close button
        this._closeBtn = this._register(new SimpleButton({
            label: NLS_CLOSE_BTN_LABEL + this._keybindingLabelFor(FIND_IDS.CloseFindWidgetCommand),
            className: 'close-fw',
            onTrigger: function () {
                _this._state.change({ isRevealed: false, searchScope: null }, false);
            },
            onKeyDown: function (e) {
                if (e.equals(2 /* Tab */)) {
                    if (_this._isReplaceVisible) {
                        if (_this._replaceBtn.isEnabled()) {
                            _this._replaceBtn.focus();
                        }
                        else {
                            _this._codeEditor.focus();
                        }
                        e.preventDefault();
                    }
                }
            }
        }));
        actionsContainer.appendChild(this._closeBtn.domNode);
        // Replace input
        this._replaceInput = this._register(new ContextScopedReplaceInput(null, undefined, {
            label: NLS_REPLACE_INPUT_LABEL,
            placeholder: NLS_REPLACE_INPUT_PLACEHOLDER,
            history: [],
            flexibleHeight: flexibleHeight,
            flexibleWidth: flexibleWidth,
            flexibleMaxHeight: 118
        }, this._contextKeyService, true));
        this._replaceInput.setPreserveCase(!!this._state.preserveCase);
        this._register(this._replaceInput.onKeyDown(function (e) { return _this._onReplaceInputKeyDown(e); }));
        this._register(this._replaceInput.inputBox.onDidChange(function () {
            _this._state.change({ replaceString: _this._replaceInput.inputBox.value }, false);
        }));
        this._register(this._replaceInput.inputBox.onDidHeightChange(function (e) {
            if (_this._isReplaceVisible && _this._tryUpdateHeight()) {
                _this._showViewZone();
            }
        }));
        this._register(this._replaceInput.onDidOptionChange(function () {
            _this._state.change({
                preserveCase: _this._replaceInput.getPreserveCase()
            }, true);
        }));
        this._register(this._replaceInput.onPreserveCaseKeyDown(function (e) {
            if (e.equals(2 /* Tab */)) {
                if (_this._prevBtn.isEnabled()) {
                    _this._prevBtn.focus();
                }
                else if (_this._nextBtn.isEnabled()) {
                    _this._nextBtn.focus();
                }
                else if (_this._toggleSelectionFind.isEnabled()) {
                    _this._toggleSelectionFind.focus();
                }
                else if (_this._closeBtn.isEnabled()) {
                    _this._closeBtn.focus();
                }
                e.preventDefault();
            }
        }));
        // Replace one button
        this._replaceBtn = this._register(new SimpleButton({
            label: NLS_REPLACE_BTN_LABEL + this._keybindingLabelFor(FIND_IDS.ReplaceOneAction),
            className: 'replace',
            onTrigger: function () {
                _this._controller.replace();
            },
            onKeyDown: function (e) {
                if (e.equals(1024 /* Shift */ | 2 /* Tab */)) {
                    _this._closeBtn.focus();
                    e.preventDefault();
                }
            }
        }));
        // Replace all button
        this._replaceAllBtn = this._register(new SimpleButton({
            label: NLS_REPLACE_ALL_BTN_LABEL + this._keybindingLabelFor(FIND_IDS.ReplaceAllAction),
            className: 'replace-all',
            onTrigger: function () {
                _this._controller.replaceAll();
            }
        }));
        var replacePart = document.createElement('div');
        replacePart.className = 'replace-part';
        replacePart.appendChild(this._replaceInput.domNode);
        var replaceActionsContainer = document.createElement('div');
        replaceActionsContainer.className = 'replace-actions';
        replacePart.appendChild(replaceActionsContainer);
        replaceActionsContainer.appendChild(this._replaceBtn.domNode);
        replaceActionsContainer.appendChild(this._replaceAllBtn.domNode);
        // Toggle replace button
        this._toggleReplaceBtn = this._register(new SimpleButton({
            label: NLS_TOGGLE_REPLACE_MODE_BTN_LABEL,
            className: 'toggle left',
            onTrigger: function () {
                _this._state.change({ isReplaceRevealed: !_this._isReplaceVisible }, false);
                if (_this._isReplaceVisible) {
                    _this._replaceInput.width = dom.getTotalWidth(_this._findInput.domNode);
                    _this._replaceInput.inputBox.layout();
                }
                _this._showViewZone();
            }
        }));
        this._toggleReplaceBtn.toggleClass('expand', this._isReplaceVisible);
        this._toggleReplaceBtn.toggleClass('collapse', !this._isReplaceVisible);
        this._toggleReplaceBtn.setExpanded(this._isReplaceVisible);
        // Widget
        this._domNode = document.createElement('div');
        this._domNode.className = 'editor-widget find-widget';
        this._domNode.setAttribute('aria-hidden', 'true');
        // We need to set this explicitly, otherwise on IE11, the width inheritence of flex doesn't work.
        this._domNode.style.width = FIND_WIDGET_INITIAL_WIDTH + "px";
        this._domNode.appendChild(this._toggleReplaceBtn.domNode);
        this._domNode.appendChild(findPart);
        this._domNode.appendChild(replacePart);
        this._resizeSash = new Sash(this._domNode, this, { orientation: 0 /* VERTICAL */ });
        this._resized = false;
        var originalWidth = FIND_WIDGET_INITIAL_WIDTH;
        this._register(this._resizeSash.onDidStart(function () {
            originalWidth = dom.getTotalWidth(_this._domNode);
        }));
        this._register(this._resizeSash.onDidChange(function (evt) {
            _this._resized = true;
            var width = originalWidth + evt.startX - evt.currentX;
            if (width < FIND_WIDGET_INITIAL_WIDTH) {
                // narrow down the find widget should be handled by CSS.
                return;
            }
            var inputBoxWidth = width - FIND_ALL_CONTROLS_WIDTH;
            var maxWidth = parseFloat(dom.getComputedStyle(_this._domNode).maxWidth) || 0;
            if (width > maxWidth) {
                return;
            }
            _this._domNode.style.width = width + "px";
            _this._findInput.inputBox.width = inputBoxWidth;
            if (_this._isReplaceVisible) {
                _this._replaceInput.width = dom.getTotalWidth(_this._findInput.domNode);
            }
            _this._findInput.inputBox.layout();
            _this._tryUpdateHeight();
        }));
        this._register(this._resizeSash.onDidReset(function () {
            // users double click on the sash
            var currentWidth = dom.getTotalWidth(_this._domNode);
            if (currentWidth < FIND_WIDGET_INITIAL_WIDTH) {
                // The editor is narrow and the width of the find widget is controlled fully by CSS.
                return;
            }
            var width = FIND_WIDGET_INITIAL_WIDTH;
            if (!_this._resized || currentWidth === FIND_WIDGET_INITIAL_WIDTH) {
                // 1. never resized before, double click should maximizes it
                // 2. users resized it already but its width is the same as default
                width = _this._codeEditor.getConfiguration().layoutInfo.width - 28 - _this._codeEditor.getConfiguration().layoutInfo.minimapWidth - 15;
                _this._resized = true;
            }
            else {
                /**
                 * no op, the find widget should be shrinked to its default size.
                 */
            }
            var inputBoxWidth = width - FIND_ALL_CONTROLS_WIDTH;
            _this._domNode.style.width = width + "px";
            _this._findInput.inputBox.width = inputBoxWidth;
            if (_this._isReplaceVisible) {
                _this._replaceInput.width = dom.getTotalWidth(_this._findInput.domNode);
            }
            _this._findInput.inputBox.layout();
        }));
    };
    FindWidget.prototype.updateAccessibilitySupport = function () {
        var value = this._codeEditor.getConfiguration().accessibilitySupport;
        this._findInput.setFocusInputOnOptionClick(value !== 2 /* Enabled */);
    };
    FindWidget.ID = 'editor.contrib.findWidget';
    return FindWidget;
}(Widget));
export { FindWidget };
var SimpleCheckbox = /** @class */ (function (_super) {
    __extends(SimpleCheckbox, _super);
    function SimpleCheckbox(opts) {
        var _this = _super.call(this) || this;
        _this._opts = opts;
        _this._domNode = document.createElement('div');
        _this._domNode.className = 'monaco-checkbox';
        _this._domNode.title = _this._opts.title;
        _this._domNode.tabIndex = 0;
        _this._checkbox = document.createElement('input');
        _this._checkbox.type = 'checkbox';
        _this._checkbox.className = 'checkbox';
        _this._checkbox.id = 'checkbox-' + SimpleCheckbox._COUNTER++;
        _this._checkbox.tabIndex = -1;
        _this._label = document.createElement('label');
        _this._label.className = 'label';
        // Connect the label and the checkbox. Checkbox will get checked when the label receives a click.
        _this._label.htmlFor = _this._checkbox.id;
        _this._label.tabIndex = -1;
        _this._domNode.appendChild(_this._checkbox);
        _this._domNode.appendChild(_this._label);
        _this._opts.parent.appendChild(_this._domNode);
        _this.onchange(_this._checkbox, function () {
            _this._opts.onChange();
        });
        return _this;
    }
    Object.defineProperty(SimpleCheckbox.prototype, "domNode", {
        get: function () {
            return this._domNode;
        },
        enumerable: true,
        configurable: true
    });
    SimpleCheckbox.prototype.isEnabled = function () {
        return (this._domNode.tabIndex >= 0);
    };
    Object.defineProperty(SimpleCheckbox.prototype, "checked", {
        get: function () {
            return this._checkbox.checked;
        },
        set: function (newValue) {
            this._checkbox.checked = newValue;
        },
        enumerable: true,
        configurable: true
    });
    SimpleCheckbox.prototype.focus = function () {
        this._domNode.focus();
    };
    SimpleCheckbox.prototype.enable = function () {
        this._checkbox.removeAttribute('disabled');
    };
    SimpleCheckbox.prototype.disable = function () {
        this._checkbox.disabled = true;
    };
    SimpleCheckbox.prototype.setEnabled = function (enabled) {
        if (enabled) {
            this.enable();
            this.domNode.tabIndex = 0;
        }
        else {
            this.disable();
            this.domNode.tabIndex = -1;
        }
    };
    SimpleCheckbox._COUNTER = 0;
    return SimpleCheckbox;
}(Widget));
var SimpleButton = /** @class */ (function (_super) {
    __extends(SimpleButton, _super);
    function SimpleButton(opts) {
        var _this = _super.call(this) || this;
        _this._opts = opts;
        _this._domNode = document.createElement('div');
        _this._domNode.title = _this._opts.label;
        _this._domNode.tabIndex = 0;
        _this._domNode.className = 'button ' + _this._opts.className;
        _this._domNode.setAttribute('role', 'button');
        _this._domNode.setAttribute('aria-label', _this._opts.label);
        _this.onclick(_this._domNode, function (e) {
            _this._opts.onTrigger();
            e.preventDefault();
        });
        _this.onkeydown(_this._domNode, function (e) {
            if (e.equals(10 /* Space */) || e.equals(3 /* Enter */)) {
                _this._opts.onTrigger();
                e.preventDefault();
                return;
            }
            if (_this._opts.onKeyDown) {
                _this._opts.onKeyDown(e);
            }
        });
        return _this;
    }
    Object.defineProperty(SimpleButton.prototype, "domNode", {
        get: function () {
            return this._domNode;
        },
        enumerable: true,
        configurable: true
    });
    SimpleButton.prototype.isEnabled = function () {
        return (this._domNode.tabIndex >= 0);
    };
    SimpleButton.prototype.focus = function () {
        this._domNode.focus();
    };
    SimpleButton.prototype.setEnabled = function (enabled) {
        dom.toggleClass(this._domNode, 'disabled', !enabled);
        this._domNode.setAttribute('aria-disabled', String(!enabled));
        this._domNode.tabIndex = enabled ? 0 : -1;
    };
    SimpleButton.prototype.setExpanded = function (expanded) {
        this._domNode.setAttribute('aria-expanded', String(!!expanded));
    };
    SimpleButton.prototype.toggleClass = function (className, shouldHaveIt) {
        dom.toggleClass(this._domNode, className, shouldHaveIt);
    };
    return SimpleButton;
}(Widget));
export { SimpleButton };
// theming
registerThemingParticipant(function (theme, collector) {
    var addBackgroundColorRule = function (selector, color) {
        if (color) {
            collector.addRule(".monaco-editor " + selector + " { background-color: " + color + "; }");
        }
    };
    addBackgroundColorRule('.findMatch', theme.getColor(editorFindMatchHighlight));
    addBackgroundColorRule('.currentFindMatch', theme.getColor(editorFindMatch));
    addBackgroundColorRule('.findScope', theme.getColor(editorFindRangeHighlight));
    var widgetBackground = theme.getColor(editorWidgetBackground);
    addBackgroundColorRule('.find-widget', widgetBackground);
    var widgetShadowColor = theme.getColor(widgetShadow);
    if (widgetShadowColor) {
        collector.addRule(".monaco-editor .find-widget { box-shadow: 0 2px 8px " + widgetShadowColor + "; }");
    }
    var findMatchHighlightBorder = theme.getColor(editorFindMatchHighlightBorder);
    if (findMatchHighlightBorder) {
        collector.addRule(".monaco-editor .findMatch { border: 1px " + (theme.type === 'hc' ? 'dotted' : 'solid') + " " + findMatchHighlightBorder + "; box-sizing: border-box; }");
    }
    var findMatchBorder = theme.getColor(editorFindMatchBorder);
    if (findMatchBorder) {
        collector.addRule(".monaco-editor .currentFindMatch { border: 2px solid " + findMatchBorder + "; padding: 1px; box-sizing: border-box; }");
    }
    var findRangeHighlightBorder = theme.getColor(editorFindRangeHighlightBorder);
    if (findRangeHighlightBorder) {
        collector.addRule(".monaco-editor .findScope { border: 1px " + (theme.type === 'hc' ? 'dashed' : 'solid') + " " + findRangeHighlightBorder + "; }");
    }
    var hcBorder = theme.getColor(contrastBorder);
    if (hcBorder) {
        collector.addRule(".monaco-editor .find-widget { border: 2px solid " + hcBorder + "; }");
    }
    var foreground = theme.getColor(editorWidgetForeground);
    if (foreground) {
        collector.addRule(".monaco-editor .find-widget { color: " + foreground + "; }");
    }
    var error = theme.getColor(errorForeground);
    if (error) {
        collector.addRule(".monaco-editor .find-widget.no-results .matchesCount { color: " + error + "; }");
    }
    var resizeBorderBackground = theme.getColor(editorWidgetResizeBorder);
    if (resizeBorderBackground) {
        collector.addRule(".monaco-editor .find-widget .monaco-sash { background-color: " + resizeBorderBackground + "; width: 3px !important; margin-left: -4px;}");
    }
    else {
        var border = theme.getColor(editorWidgetBorder);
        if (border) {
            collector.addRule(".monaco-editor .find-widget .monaco-sash { background-color: " + border + "; width: 3px !important; margin-left: -4px;}");
        }
    }
    var inputActiveBorder = theme.getColor(inputActiveOptionBorder);
    if (inputActiveBorder) {
        collector.addRule(".monaco-editor .find-widget .monaco-checkbox .checkbox:checked + .label { border: 1px solid " + inputActiveBorder.toString() + "; }");
    }
    var inputActiveBackground = theme.getColor(inputActiveOptionBackground);
    if (inputActiveBackground) {
        collector.addRule(".monaco-editor .find-widget .monaco-checkbox .checkbox:checked + .label { background-color: " + inputActiveBackground.toString() + "; }");
    }
    // This rule is used to override the outline color for synthetic-focus find input.
    var focusOutline = theme.getColor(focusBorder);
    if (focusOutline) {
        collector.addRule(".monaco-workbench .monaco-editor .find-widget .monaco-inputbox.synthetic-focus { outline-color: " + focusOutline + "; }");
    }
});
