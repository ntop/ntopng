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
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
import './list.css';
import { localize } from '../../../../nls.js';
import { dispose, DisposableStore } from '../../../common/lifecycle.js';
import { isNumber } from '../../../common/types.js';
import { range, firstIndex, binarySearch } from '../../../common/arrays.js';
import { memoize } from '../../../common/decorators.js';
import * as DOM from '../../dom.js';
import * as platform from '../../../common/platform.js';
import { Gesture } from '../../touch.js';
import { StandardKeyboardEvent } from '../../keyboardEvent.js';
import { Event, Emitter, EventBufferer } from '../../../common/event.js';
import { domEvent } from '../../event.js';
import { ListAriaRootRole } from './list.js';
import { ListView } from './listView.js';
import { Color } from '../../../common/color.js';
import { mixin } from '../../../common/objects.js';
import { CombinedSpliceable } from './splice.js';
import { clamp } from '../../../common/numbers.js';
import { matchesPrefix } from '../../../common/filters.js';
var TraitRenderer = /** @class */ (function () {
    function TraitRenderer(trait) {
        this.trait = trait;
        this.renderedElements = [];
    }
    Object.defineProperty(TraitRenderer.prototype, "templateId", {
        get: function () {
            return "template:" + this.trait.trait;
        },
        enumerable: true,
        configurable: true
    });
    TraitRenderer.prototype.renderTemplate = function (container) {
        return container;
    };
    TraitRenderer.prototype.renderElement = function (element, index, templateData) {
        var renderedElementIndex = firstIndex(this.renderedElements, function (el) { return el.templateData === templateData; });
        if (renderedElementIndex >= 0) {
            var rendered = this.renderedElements[renderedElementIndex];
            this.trait.unrender(templateData);
            rendered.index = index;
        }
        else {
            var rendered = { index: index, templateData: templateData };
            this.renderedElements.push(rendered);
        }
        this.trait.renderIndex(index, templateData);
    };
    TraitRenderer.prototype.splice = function (start, deleteCount, insertCount) {
        var rendered = [];
        for (var _i = 0, _a = this.renderedElements; _i < _a.length; _i++) {
            var renderedElement = _a[_i];
            if (renderedElement.index < start) {
                rendered.push(renderedElement);
            }
            else if (renderedElement.index >= start + deleteCount) {
                rendered.push({
                    index: renderedElement.index + insertCount - deleteCount,
                    templateData: renderedElement.templateData
                });
            }
        }
        this.renderedElements = rendered;
    };
    TraitRenderer.prototype.renderIndexes = function (indexes) {
        for (var _i = 0, _a = this.renderedElements; _i < _a.length; _i++) {
            var _b = _a[_i], index = _b.index, templateData = _b.templateData;
            if (indexes.indexOf(index) > -1) {
                this.trait.renderIndex(index, templateData);
            }
        }
    };
    TraitRenderer.prototype.disposeTemplate = function (templateData) {
        var index = firstIndex(this.renderedElements, function (el) { return el.templateData === templateData; });
        if (index < 0) {
            return;
        }
        this.renderedElements.splice(index, 1);
    };
    return TraitRenderer;
}());
var Trait = /** @class */ (function () {
    function Trait(_trait) {
        this._trait = _trait;
        this.indexes = [];
        this.sortedIndexes = [];
        this._onChange = new Emitter();
        this.onChange = this._onChange.event;
    }
    Object.defineProperty(Trait.prototype, "trait", {
        get: function () { return this._trait; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Trait.prototype, "renderer", {
        get: function () {
            return new TraitRenderer(this);
        },
        enumerable: true,
        configurable: true
    });
    Trait.prototype.splice = function (start, deleteCount, elements) {
        var diff = elements.length - deleteCount;
        var end = start + deleteCount;
        var indexes = this.sortedIndexes.filter(function (i) { return i < start; }).concat(elements.map(function (hasTrait, i) { return hasTrait ? i + start : -1; }).filter(function (i) { return i !== -1; }), this.sortedIndexes.filter(function (i) { return i >= end; }).map(function (i) { return i + diff; }));
        this.renderer.splice(start, deleteCount, elements.length);
        this._set(indexes, indexes);
    };
    Trait.prototype.renderIndex = function (index, container) {
        DOM.toggleClass(container, this._trait, this.contains(index));
    };
    Trait.prototype.unrender = function (container) {
        DOM.removeClass(container, this._trait);
    };
    /**
     * Sets the indexes which should have this trait.
     *
     * @param indexes Indexes which should have this trait.
     * @return The old indexes which had this trait.
     */
    Trait.prototype.set = function (indexes, browserEvent) {
        return this._set(indexes, indexes.slice().sort(numericSort), browserEvent);
    };
    Trait.prototype._set = function (indexes, sortedIndexes, browserEvent) {
        var result = this.indexes;
        var sortedResult = this.sortedIndexes;
        this.indexes = indexes;
        this.sortedIndexes = sortedIndexes;
        var toRender = disjunction(sortedResult, indexes);
        this.renderer.renderIndexes(toRender);
        this._onChange.fire({ indexes: indexes, browserEvent: browserEvent });
        return result;
    };
    Trait.prototype.get = function () {
        return this.indexes;
    };
    Trait.prototype.contains = function (index) {
        return binarySearch(this.sortedIndexes, index, numericSort) >= 0;
    };
    Trait.prototype.dispose = function () {
        this._onChange = dispose(this._onChange);
    };
    __decorate([
        memoize
    ], Trait.prototype, "renderer", null);
    return Trait;
}());
var FocusTrait = /** @class */ (function (_super) {
    __extends(FocusTrait, _super);
    function FocusTrait() {
        return _super.call(this, 'focused') || this;
    }
    FocusTrait.prototype.renderIndex = function (index, container) {
        _super.prototype.renderIndex.call(this, index, container);
        if (this.contains(index)) {
            container.setAttribute('aria-selected', 'true');
        }
        else {
            container.removeAttribute('aria-selected');
        }
    };
    return FocusTrait;
}(Trait));
/**
 * The TraitSpliceable is used as a util class to be able
 * to preserve traits across splice calls, given an identity
 * provider.
 */
var TraitSpliceable = /** @class */ (function () {
    function TraitSpliceable(trait, view, identityProvider) {
        this.trait = trait;
        this.view = view;
        this.identityProvider = identityProvider;
    }
    TraitSpliceable.prototype.splice = function (start, deleteCount, elements) {
        var _this = this;
        if (!this.identityProvider) {
            return this.trait.splice(start, deleteCount, elements.map(function () { return false; }));
        }
        var pastElementsWithTrait = this.trait.get().map(function (i) { return _this.identityProvider.getId(_this.view.element(i)).toString(); });
        var elementsWithTrait = elements.map(function (e) { return pastElementsWithTrait.indexOf(_this.identityProvider.getId(e).toString()) > -1; });
        this.trait.splice(start, deleteCount, elementsWithTrait);
    };
    return TraitSpliceable;
}());
function isInputElement(e) {
    return e.tagName === 'INPUT' || e.tagName === 'TEXTAREA';
}
var KeyboardController = /** @class */ (function () {
    function KeyboardController(list, view, options) {
        this.list = list;
        this.view = view;
        this.disposables = new DisposableStore();
        var multipleSelectionSupport = options.multipleSelectionSupport !== false;
        this.openController = options.openController || DefaultOpenController;
        var onKeyDown = Event.chain(domEvent(view.domNode, 'keydown'))
            .filter(function (e) { return !isInputElement(e.target); })
            .map(function (e) { return new StandardKeyboardEvent(e); });
        onKeyDown.filter(function (e) { return e.keyCode === 3 /* Enter */; }).on(this.onEnter, this, this.disposables);
        onKeyDown.filter(function (e) { return e.keyCode === 16 /* UpArrow */; }).on(this.onUpArrow, this, this.disposables);
        onKeyDown.filter(function (e) { return e.keyCode === 18 /* DownArrow */; }).on(this.onDownArrow, this, this.disposables);
        onKeyDown.filter(function (e) { return e.keyCode === 11 /* PageUp */; }).on(this.onPageUpArrow, this, this.disposables);
        onKeyDown.filter(function (e) { return e.keyCode === 12 /* PageDown */; }).on(this.onPageDownArrow, this, this.disposables);
        onKeyDown.filter(function (e) { return e.keyCode === 9 /* Escape */; }).on(this.onEscape, this, this.disposables);
        if (multipleSelectionSupport) {
            onKeyDown.filter(function (e) { return (platform.isMacintosh ? e.metaKey : e.ctrlKey) && e.keyCode === 31 /* KEY_A */; }).on(this.onCtrlA, this, this.disposables);
        }
    }
    KeyboardController.prototype.onEnter = function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.list.setSelection(this.list.getFocus(), e.browserEvent);
        if (this.openController.shouldOpen(e.browserEvent)) {
            this.list.open(this.list.getFocus(), e.browserEvent);
        }
    };
    KeyboardController.prototype.onUpArrow = function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.list.focusPrevious(1, false, e.browserEvent);
        this.list.reveal(this.list.getFocus()[0]);
        this.view.domNode.focus();
    };
    KeyboardController.prototype.onDownArrow = function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.list.focusNext(1, false, e.browserEvent);
        this.list.reveal(this.list.getFocus()[0]);
        this.view.domNode.focus();
    };
    KeyboardController.prototype.onPageUpArrow = function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.list.focusPreviousPage(e.browserEvent);
        this.list.reveal(this.list.getFocus()[0]);
        this.view.domNode.focus();
    };
    KeyboardController.prototype.onPageDownArrow = function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.list.focusNextPage(e.browserEvent);
        this.list.reveal(this.list.getFocus()[0]);
        this.view.domNode.focus();
    };
    KeyboardController.prototype.onCtrlA = function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.list.setSelection(range(this.list.length), e.browserEvent);
        this.view.domNode.focus();
    };
    KeyboardController.prototype.onEscape = function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.list.setSelection([], e.browserEvent);
        this.view.domNode.focus();
    };
    KeyboardController.prototype.dispose = function () {
        this.disposables.dispose();
    };
    return KeyboardController;
}());
var TypeLabelControllerState;
(function (TypeLabelControllerState) {
    TypeLabelControllerState[TypeLabelControllerState["Idle"] = 0] = "Idle";
    TypeLabelControllerState[TypeLabelControllerState["Typing"] = 1] = "Typing";
})(TypeLabelControllerState || (TypeLabelControllerState = {}));
export function mightProducePrintableCharacter(event) {
    if (event.ctrlKey || event.metaKey || event.altKey) {
        return false;
    }
    return (event.keyCode >= 31 /* KEY_A */ && event.keyCode <= 56 /* KEY_Z */)
        || (event.keyCode >= 21 /* KEY_0 */ && event.keyCode <= 30 /* KEY_9 */)
        || (event.keyCode >= 93 /* NUMPAD_0 */ && event.keyCode <= 102 /* NUMPAD_9 */)
        || (event.keyCode >= 80 /* US_SEMICOLON */ && event.keyCode <= 90 /* US_QUOTE */);
}
var TypeLabelController = /** @class */ (function () {
    function TypeLabelController(list, view, keyboardNavigationLabelProvider) {
        this.list = list;
        this.view = view;
        this.keyboardNavigationLabelProvider = keyboardNavigationLabelProvider;
        this.enabled = false;
        this.state = TypeLabelControllerState.Idle;
        this.automaticKeyboardNavigation = true;
        this.triggered = false;
        this.enabledDisposables = new DisposableStore();
        this.disposables = new DisposableStore();
        this.updateOptions(list.options);
    }
    TypeLabelController.prototype.updateOptions = function (options) {
        var enableKeyboardNavigation = typeof options.enableKeyboardNavigation === 'undefined' ? true : !!options.enableKeyboardNavigation;
        if (enableKeyboardNavigation) {
            this.enable();
        }
        else {
            this.disable();
        }
        if (typeof options.automaticKeyboardNavigation !== 'undefined') {
            this.automaticKeyboardNavigation = options.automaticKeyboardNavigation;
        }
    };
    TypeLabelController.prototype.enable = function () {
        var _this = this;
        if (this.enabled) {
            return;
        }
        var onChar = Event.chain(domEvent(this.view.domNode, 'keydown'))
            .filter(function (e) { return !isInputElement(e.target); })
            .filter(function () { return _this.automaticKeyboardNavigation || _this.triggered; })
            .map(function (event) { return new StandardKeyboardEvent(event); })
            .filter(this.keyboardNavigationLabelProvider.mightProducePrintableCharacter ? function (e) { return _this.keyboardNavigationLabelProvider.mightProducePrintableCharacter(e); } : function (e) { return mightProducePrintableCharacter(e); })
            .forEach(function (e) { e.stopPropagation(); e.preventDefault(); })
            .map(function (event) { return event.browserEvent.key; })
            .event;
        var onClear = Event.debounce(onChar, function () { return null; }, 800);
        var onInput = Event.reduce(Event.any(onChar, onClear), function (r, i) { return i === null ? null : ((r || '') + i); });
        onInput(this.onInput, this, this.enabledDisposables);
        this.enabled = true;
        this.triggered = false;
    };
    TypeLabelController.prototype.disable = function () {
        if (!this.enabled) {
            return;
        }
        this.enabledDisposables.clear();
        this.enabled = false;
        this.triggered = false;
    };
    TypeLabelController.prototype.onInput = function (word) {
        if (!word) {
            this.state = TypeLabelControllerState.Idle;
            this.triggered = false;
            return;
        }
        var focus = this.list.getFocus();
        var start = focus.length > 0 ? focus[0] : 0;
        var delta = this.state === TypeLabelControllerState.Idle ? 1 : 0;
        this.state = TypeLabelControllerState.Typing;
        for (var i = 0; i < this.list.length; i++) {
            var index = (start + i + delta) % this.list.length;
            var label = this.keyboardNavigationLabelProvider.getKeyboardNavigationLabel(this.view.element(index));
            var labelStr = label && label.toString();
            if (typeof labelStr === 'undefined' || matchesPrefix(word, labelStr)) {
                this.list.setFocus([index]);
                this.list.reveal(index);
                return;
            }
        }
    };
    TypeLabelController.prototype.dispose = function () {
        this.disable();
        this.enabledDisposables.dispose();
        this.disposables.dispose();
    };
    return TypeLabelController;
}());
var DOMFocusController = /** @class */ (function () {
    function DOMFocusController(list, view) {
        this.list = list;
        this.view = view;
        this.disposables = new DisposableStore();
        var onKeyDown = Event.chain(domEvent(view.domNode, 'keydown'))
            .filter(function (e) { return !isInputElement(e.target); })
            .map(function (e) { return new StandardKeyboardEvent(e); });
        onKeyDown.filter(function (e) { return e.keyCode === 2 /* Tab */ && !e.ctrlKey && !e.metaKey && !e.shiftKey && !e.altKey; })
            .on(this.onTab, this, this.disposables);
    }
    DOMFocusController.prototype.onTab = function (e) {
        if (e.target !== this.view.domNode) {
            return;
        }
        var focus = this.list.getFocus();
        if (focus.length === 0) {
            return;
        }
        var focusedDomElement = this.view.domElement(focus[0]);
        if (!focusedDomElement) {
            return;
        }
        var tabIndexElement = focusedDomElement.querySelector('[tabIndex]');
        if (!tabIndexElement || !(tabIndexElement instanceof HTMLElement) || tabIndexElement.tabIndex === -1) {
            return;
        }
        var style = window.getComputedStyle(tabIndexElement);
        if (style.visibility === 'hidden' || style.display === 'none') {
            return;
        }
        e.preventDefault();
        e.stopPropagation();
        tabIndexElement.focus();
    };
    DOMFocusController.prototype.dispose = function () {
        this.disposables.dispose();
    };
    return DOMFocusController;
}());
export function isSelectionSingleChangeEvent(event) {
    return platform.isMacintosh ? event.browserEvent.metaKey : event.browserEvent.ctrlKey;
}
export function isSelectionRangeChangeEvent(event) {
    return event.browserEvent.shiftKey;
}
function isMouseRightClick(event) {
    return event instanceof MouseEvent && event.button === 2;
}
var DefaultMultipleSelectionController = {
    isSelectionSingleChangeEvent: isSelectionSingleChangeEvent,
    isSelectionRangeChangeEvent: isSelectionRangeChangeEvent
};
var DefaultOpenController = {
    shouldOpen: function (event) {
        if (event instanceof MouseEvent) {
            return !isMouseRightClick(event);
        }
        return true;
    }
};
var MouseController = /** @class */ (function () {
    function MouseController(list) {
        this.list = list;
        this.disposables = new DisposableStore();
        this.multipleSelectionSupport = !(list.options.multipleSelectionSupport === false);
        if (this.multipleSelectionSupport) {
            this.multipleSelectionController = list.options.multipleSelectionController || DefaultMultipleSelectionController;
        }
        this.openController = list.options.openController || DefaultOpenController;
        this.mouseSupport = typeof list.options.mouseSupport === 'undefined' || !!list.options.mouseSupport;
        if (this.mouseSupport) {
            list.onMouseDown(this.onMouseDown, this, this.disposables);
            list.onContextMenu(this.onContextMenu, this, this.disposables);
            list.onMouseDblClick(this.onDoubleClick, this, this.disposables);
            list.onTouchStart(this.onMouseDown, this, this.disposables);
            Gesture.addTarget(list.getHTMLElement());
        }
        list.onMouseClick(this.onPointer, this, this.disposables);
        list.onMouseMiddleClick(this.onPointer, this, this.disposables);
        list.onTap(this.onPointer, this, this.disposables);
    }
    MouseController.prototype.isSelectionSingleChangeEvent = function (event) {
        if (this.multipleSelectionController) {
            return this.multipleSelectionController.isSelectionSingleChangeEvent(event);
        }
        return platform.isMacintosh ? event.browserEvent.metaKey : event.browserEvent.ctrlKey;
    };
    MouseController.prototype.isSelectionRangeChangeEvent = function (event) {
        if (this.multipleSelectionController) {
            return this.multipleSelectionController.isSelectionRangeChangeEvent(event);
        }
        return event.browserEvent.shiftKey;
    };
    MouseController.prototype.isSelectionChangeEvent = function (event) {
        return this.isSelectionSingleChangeEvent(event) || this.isSelectionRangeChangeEvent(event);
    };
    MouseController.prototype.onMouseDown = function (e) {
        if (document.activeElement !== e.browserEvent.target) {
            this.list.domFocus();
        }
    };
    MouseController.prototype.onContextMenu = function (e) {
        var focus = typeof e.index === 'undefined' ? [] : [e.index];
        this.list.setFocus(focus, e.browserEvent);
    };
    MouseController.prototype.onPointer = function (e) {
        if (!this.mouseSupport) {
            return;
        }
        if (isInputElement(e.browserEvent.target)) {
            return;
        }
        var reference = this.list.getFocus()[0];
        var selection = this.list.getSelection();
        reference = reference === undefined ? selection[0] : reference;
        var focus = e.index;
        if (typeof focus === 'undefined') {
            this.list.setFocus([], e.browserEvent);
            this.list.setSelection([], e.browserEvent);
            return;
        }
        if (this.multipleSelectionSupport && this.isSelectionRangeChangeEvent(e)) {
            return this.changeSelection(e, reference);
        }
        if (this.multipleSelectionSupport && this.isSelectionChangeEvent(e)) {
            return this.changeSelection(e, reference);
        }
        this.list.setFocus([focus], e.browserEvent);
        if (!isMouseRightClick(e.browserEvent)) {
            this.list.setSelection([focus], e.browserEvent);
            if (this.openController.shouldOpen(e.browserEvent)) {
                this.list.open([focus], e.browserEvent);
            }
        }
    };
    MouseController.prototype.onDoubleClick = function (e) {
        if (isInputElement(e.browserEvent.target)) {
            return;
        }
        if (this.multipleSelectionSupport && this.isSelectionChangeEvent(e)) {
            return;
        }
        var focus = this.list.getFocus();
        this.list.setSelection(focus, e.browserEvent);
        this.list.pin(focus);
    };
    MouseController.prototype.changeSelection = function (e, reference) {
        var focus = e.index;
        if (this.isSelectionRangeChangeEvent(e) && reference !== undefined) {
            var min = Math.min(reference, focus);
            var max = Math.max(reference, focus);
            var rangeSelection = range(min, max + 1);
            var selection = this.list.getSelection();
            var contiguousRange = getContiguousRangeContaining(disjunction(selection, [reference]), reference);
            if (contiguousRange.length === 0) {
                return;
            }
            var newSelection = disjunction(rangeSelection, relativeComplement(selection, contiguousRange));
            this.list.setSelection(newSelection, e.browserEvent);
        }
        else if (this.isSelectionSingleChangeEvent(e)) {
            var selection = this.list.getSelection();
            var newSelection = selection.filter(function (i) { return i !== focus; });
            this.list.setFocus([focus]);
            if (selection.length === newSelection.length) {
                this.list.setSelection(newSelection.concat([focus]), e.browserEvent);
            }
            else {
                this.list.setSelection(newSelection, e.browserEvent);
            }
        }
    };
    MouseController.prototype.dispose = function () {
        this.disposables.dispose();
    };
    return MouseController;
}());
export { MouseController };
var DefaultStyleController = /** @class */ (function () {
    function DefaultStyleController(styleElement, selectorSuffix) {
        this.styleElement = styleElement;
        this.selectorSuffix = selectorSuffix;
    }
    DefaultStyleController.prototype.style = function (styles) {
        var suffix = this.selectorSuffix ? "." + this.selectorSuffix : '';
        var content = [];
        if (styles.listFocusBackground) {
            content.push(".monaco-list" + suffix + ":focus .monaco-list-row.focused { background-color: " + styles.listFocusBackground + "; }");
            content.push(".monaco-list" + suffix + ":focus .monaco-list-row.focused:hover { background-color: " + styles.listFocusBackground + "; }"); // overwrite :hover style in this case!
        }
        if (styles.listFocusForeground) {
            content.push(".monaco-list" + suffix + ":focus .monaco-list-row.focused { color: " + styles.listFocusForeground + "; }");
        }
        if (styles.listActiveSelectionBackground) {
            content.push(".monaco-list" + suffix + ":focus .monaco-list-row.selected { background-color: " + styles.listActiveSelectionBackground + "; }");
            content.push(".monaco-list" + suffix + ":focus .monaco-list-row.selected:hover { background-color: " + styles.listActiveSelectionBackground + "; }"); // overwrite :hover style in this case!
        }
        if (styles.listActiveSelectionForeground) {
            content.push(".monaco-list" + suffix + ":focus .monaco-list-row.selected { color: " + styles.listActiveSelectionForeground + "; }");
        }
        if (styles.listFocusAndSelectionBackground) {
            content.push("\n\t\t\t\t.monaco-drag-image,\n\t\t\t\t.monaco-list" + suffix + ":focus .monaco-list-row.selected.focused { background-color: " + styles.listFocusAndSelectionBackground + "; }\n\t\t\t");
        }
        if (styles.listFocusAndSelectionForeground) {
            content.push("\n\t\t\t\t.monaco-drag-image,\n\t\t\t\t.monaco-list" + suffix + ":focus .monaco-list-row.selected.focused { color: " + styles.listFocusAndSelectionForeground + "; }\n\t\t\t");
        }
        if (styles.listInactiveFocusBackground) {
            content.push(".monaco-list" + suffix + " .monaco-list-row.focused { background-color:  " + styles.listInactiveFocusBackground + "; }");
            content.push(".monaco-list" + suffix + " .monaco-list-row.focused:hover { background-color:  " + styles.listInactiveFocusBackground + "; }"); // overwrite :hover style in this case!
        }
        if (styles.listInactiveSelectionBackground) {
            content.push(".monaco-list" + suffix + " .monaco-list-row.selected { background-color:  " + styles.listInactiveSelectionBackground + "; }");
            content.push(".monaco-list" + suffix + " .monaco-list-row.selected:hover { background-color:  " + styles.listInactiveSelectionBackground + "; }"); // overwrite :hover style in this case!
        }
        if (styles.listInactiveSelectionForeground) {
            content.push(".monaco-list" + suffix + " .monaco-list-row.selected { color: " + styles.listInactiveSelectionForeground + "; }");
        }
        if (styles.listHoverBackground) {
            content.push(".monaco-list" + suffix + ":not(.drop-target) .monaco-list-row:hover:not(.selected):not(.focused) { background-color:  " + styles.listHoverBackground + "; }");
        }
        if (styles.listHoverForeground) {
            content.push(".monaco-list" + suffix + " .monaco-list-row:hover:not(.selected):not(.focused) { color:  " + styles.listHoverForeground + "; }");
        }
        if (styles.listSelectionOutline) {
            content.push(".monaco-list" + suffix + " .monaco-list-row.selected { outline: 1px dotted " + styles.listSelectionOutline + "; outline-offset: -1px; }");
        }
        if (styles.listFocusOutline) {
            content.push("\n\t\t\t\t.monaco-drag-image,\n\t\t\t\t.monaco-list" + suffix + ":focus .monaco-list-row.focused { outline: 1px solid " + styles.listFocusOutline + "; outline-offset: -1px; }\n\t\t\t");
        }
        if (styles.listInactiveFocusOutline) {
            content.push(".monaco-list" + suffix + " .monaco-list-row.focused { outline: 1px dotted " + styles.listInactiveFocusOutline + "; outline-offset: -1px; }");
        }
        if (styles.listHoverOutline) {
            content.push(".monaco-list" + suffix + " .monaco-list-row:hover { outline: 1px dashed " + styles.listHoverOutline + "; outline-offset: -1px; }");
        }
        if (styles.listDropBackground) {
            content.push("\n\t\t\t\t.monaco-list" + suffix + ".drop-target,\n\t\t\t\t.monaco-list" + suffix + " .monaco-list-row.drop-target { background-color: " + styles.listDropBackground + " !important; color: inherit !important; }\n\t\t\t");
        }
        if (styles.listFilterWidgetBackground) {
            content.push(".monaco-list-type-filter { background-color: " + styles.listFilterWidgetBackground + " }");
        }
        if (styles.listFilterWidgetOutline) {
            content.push(".monaco-list-type-filter { border: 1px solid " + styles.listFilterWidgetOutline + "; }");
        }
        if (styles.listFilterWidgetNoMatchesOutline) {
            content.push(".monaco-list-type-filter.no-matches { border: 1px solid " + styles.listFilterWidgetNoMatchesOutline + "; }");
        }
        if (styles.listMatchesShadow) {
            content.push(".monaco-list-type-filter { box-shadow: 1px 1px 1px " + styles.listMatchesShadow + "; }");
        }
        var newStyles = content.join('\n');
        if (newStyles !== this.styleElement.innerHTML) {
            this.styleElement.innerHTML = newStyles;
        }
    };
    return DefaultStyleController;
}());
export { DefaultStyleController };
var defaultStyles = {
    listFocusBackground: Color.fromHex('#073655'),
    listActiveSelectionBackground: Color.fromHex('#0E639C'),
    listActiveSelectionForeground: Color.fromHex('#FFFFFF'),
    listFocusAndSelectionBackground: Color.fromHex('#094771'),
    listFocusAndSelectionForeground: Color.fromHex('#FFFFFF'),
    listInactiveSelectionBackground: Color.fromHex('#3F3F46'),
    listHoverBackground: Color.fromHex('#2A2D2E'),
    listDropBackground: Color.fromHex('#383B3D'),
    treeIndentGuidesStroke: Color.fromHex('#a9a9a9')
};
var DefaultOptions = {
    keyboardSupport: true,
    mouseSupport: true,
    multipleSelectionSupport: true,
    dnd: {
        getDragURI: function () { return null; },
        onDragStart: function () { },
        onDragOver: function () { return false; },
        drop: function () { }
    },
    ariaRootRole: ListAriaRootRole.TREE
};
// TODO@Joao: move these utils into a SortedArray class
function getContiguousRangeContaining(range, value) {
    var index = range.indexOf(value);
    if (index === -1) {
        return [];
    }
    var result = [];
    var i = index - 1;
    while (i >= 0 && range[i] === value - (index - i)) {
        result.push(range[i--]);
    }
    result.reverse();
    i = index;
    while (i < range.length && range[i] === value + (i - index)) {
        result.push(range[i++]);
    }
    return result;
}
/**
 * Given two sorted collections of numbers, returns the intersection
 * between them (OR).
 */
function disjunction(one, other) {
    var result = [];
    var i = 0, j = 0;
    while (i < one.length || j < other.length) {
        if (i >= one.length) {
            result.push(other[j++]);
        }
        else if (j >= other.length) {
            result.push(one[i++]);
        }
        else if (one[i] === other[j]) {
            result.push(one[i]);
            i++;
            j++;
            continue;
        }
        else if (one[i] < other[j]) {
            result.push(one[i++]);
        }
        else {
            result.push(other[j++]);
        }
    }
    return result;
}
/**
 * Given two sorted collections of numbers, returns the relative
 * complement between them (XOR).
 */
function relativeComplement(one, other) {
    var result = [];
    var i = 0, j = 0;
    while (i < one.length || j < other.length) {
        if (i >= one.length) {
            result.push(other[j++]);
        }
        else if (j >= other.length) {
            result.push(one[i++]);
        }
        else if (one[i] === other[j]) {
            i++;
            j++;
            continue;
        }
        else if (one[i] < other[j]) {
            result.push(one[i++]);
        }
        else {
            j++;
        }
    }
    return result;
}
var numericSort = function (a, b) { return a - b; };
var PipelineRenderer = /** @class */ (function () {
    function PipelineRenderer(_templateId, renderers) {
        this._templateId = _templateId;
        this.renderers = renderers;
    }
    Object.defineProperty(PipelineRenderer.prototype, "templateId", {
        get: function () {
            return this._templateId;
        },
        enumerable: true,
        configurable: true
    });
    PipelineRenderer.prototype.renderTemplate = function (container) {
        return this.renderers.map(function (r) { return r.renderTemplate(container); });
    };
    PipelineRenderer.prototype.renderElement = function (element, index, templateData, height) {
        var i = 0;
        for (var _i = 0, _a = this.renderers; _i < _a.length; _i++) {
            var renderer = _a[_i];
            renderer.renderElement(element, index, templateData[i++], height);
        }
    };
    PipelineRenderer.prototype.disposeElement = function (element, index, templateData, height) {
        var i = 0;
        for (var _i = 0, _a = this.renderers; _i < _a.length; _i++) {
            var renderer = _a[_i];
            if (renderer.disposeElement) {
                renderer.disposeElement(element, index, templateData[i], height);
            }
            i += 1;
        }
    };
    PipelineRenderer.prototype.disposeTemplate = function (templateData) {
        var i = 0;
        for (var _i = 0, _a = this.renderers; _i < _a.length; _i++) {
            var renderer = _a[_i];
            renderer.disposeTemplate(templateData[i++]);
        }
    };
    return PipelineRenderer;
}());
var AccessibiltyRenderer = /** @class */ (function () {
    function AccessibiltyRenderer(accessibilityProvider) {
        this.accessibilityProvider = accessibilityProvider;
        this.templateId = 'a18n';
    }
    AccessibiltyRenderer.prototype.renderTemplate = function (container) {
        return container;
    };
    AccessibiltyRenderer.prototype.renderElement = function (element, index, container) {
        var ariaLabel = this.accessibilityProvider.getAriaLabel(element);
        if (ariaLabel) {
            container.setAttribute('aria-label', ariaLabel);
        }
        else {
            container.removeAttribute('aria-label');
        }
        var ariaLevel = this.accessibilityProvider.getAriaLevel && this.accessibilityProvider.getAriaLevel(element);
        if (typeof ariaLevel === 'number') {
            container.setAttribute('aria-level', "" + ariaLevel);
        }
        else {
            container.removeAttribute('aria-level');
        }
    };
    AccessibiltyRenderer.prototype.disposeTemplate = function (templateData) {
        // noop
    };
    return AccessibiltyRenderer;
}());
var ListViewDragAndDrop = /** @class */ (function () {
    function ListViewDragAndDrop(list, dnd) {
        this.list = list;
        this.dnd = dnd;
    }
    ListViewDragAndDrop.prototype.getDragElements = function (element) {
        var selection = this.list.getSelectedElements();
        var elements = selection.indexOf(element) > -1 ? selection : [element];
        return elements;
    };
    ListViewDragAndDrop.prototype.getDragURI = function (element) {
        return this.dnd.getDragURI(element);
    };
    ListViewDragAndDrop.prototype.getDragLabel = function (elements) {
        if (this.dnd.getDragLabel) {
            return this.dnd.getDragLabel(elements);
        }
        return undefined;
    };
    ListViewDragAndDrop.prototype.onDragStart = function (data, originalEvent) {
        if (this.dnd.onDragStart) {
            this.dnd.onDragStart(data, originalEvent);
        }
    };
    ListViewDragAndDrop.prototype.onDragOver = function (data, targetElement, targetIndex, originalEvent) {
        return this.dnd.onDragOver(data, targetElement, targetIndex, originalEvent);
    };
    ListViewDragAndDrop.prototype.drop = function (data, targetElement, targetIndex, originalEvent) {
        this.dnd.drop(data, targetElement, targetIndex, originalEvent);
    };
    return ListViewDragAndDrop;
}());
var List = /** @class */ (function () {
    function List(container, virtualDelegate, renderers, _options) {
        if (_options === void 0) { _options = DefaultOptions; }
        this._options = _options;
        this.eventBufferer = new EventBufferer();
        this.disposables = new DisposableStore();
        this._onDidOpen = new Emitter();
        this.onDidOpen = this._onDidOpen.event;
        this._onPin = new Emitter();
        this.didJustPressContextMenuKey = false;
        this._onDidDispose = new Emitter();
        this.onDidDispose = this._onDidDispose.event;
        this.focus = new FocusTrait();
        this.selection = new Trait('selected');
        mixin(_options, defaultStyles, false);
        var baseRenderers = [this.focus.renderer, this.selection.renderer];
        if (_options.accessibilityProvider) {
            baseRenderers.push(new AccessibiltyRenderer(_options.accessibilityProvider));
        }
        renderers = renderers.map(function (r) { return new PipelineRenderer(r.templateId, baseRenderers.concat([r])); });
        var viewOptions = __assign({}, _options, { dnd: _options.dnd && new ListViewDragAndDrop(this, _options.dnd) });
        this.view = new ListView(container, virtualDelegate, renderers, viewOptions);
        if (typeof _options.ariaRole !== 'string') {
            this.view.domNode.setAttribute('role', ListAriaRootRole.TREE);
        }
        else {
            this.view.domNode.setAttribute('role', _options.ariaRole);
        }
        this.styleElement = DOM.createStyleSheet(this.view.domNode);
        this.styleController = _options.styleController || new DefaultStyleController(this.styleElement, this.view.domId);
        this.spliceable = new CombinedSpliceable([
            new TraitSpliceable(this.focus, this.view, _options.identityProvider),
            new TraitSpliceable(this.selection, this.view, _options.identityProvider),
            this.view
        ]);
        this.disposables.add(this.focus);
        this.disposables.add(this.selection);
        this.disposables.add(this.view);
        this.disposables.add(this._onDidDispose);
        this.onDidFocus = Event.map(domEvent(this.view.domNode, 'focus', true), function () { return null; });
        this.onDidBlur = Event.map(domEvent(this.view.domNode, 'blur', true), function () { return null; });
        this.disposables.add(new DOMFocusController(this, this.view));
        if (typeof _options.keyboardSupport !== 'boolean' || _options.keyboardSupport) {
            var controller = new KeyboardController(this, this.view, _options);
            this.disposables.add(controller);
        }
        if (_options.keyboardNavigationLabelProvider) {
            this.typeLabelController = new TypeLabelController(this, this.view, _options.keyboardNavigationLabelProvider);
            this.disposables.add(this.typeLabelController);
        }
        this.disposables.add(this.createMouseController(_options));
        this.onFocusChange(this._onFocusChange, this, this.disposables);
        this.onSelectionChange(this._onSelectionChange, this, this.disposables);
        if (_options.ariaLabel) {
            this.view.domNode.setAttribute('aria-label', localize('aria list', "{0}. Use the navigation keys to navigate.", _options.ariaLabel));
        }
        this.style(_options);
    }
    Object.defineProperty(List.prototype, "onFocusChange", {
        get: function () {
            var _this = this;
            return Event.map(this.eventBufferer.wrapEvent(this.focus.onChange), function (e) { return _this.toListEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onSelectionChange", {
        get: function () {
            var _this = this;
            return Event.map(this.eventBufferer.wrapEvent(this.selection.onChange), function (e) { return _this.toListEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "domId", {
        get: function () { return this.view.domId; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onMouseClick", {
        get: function () { return this.view.onMouseClick; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onMouseDblClick", {
        get: function () { return this.view.onMouseDblClick; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onMouseMiddleClick", {
        get: function () { return this.view.onMouseMiddleClick; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onMouseDown", {
        get: function () { return this.view.onMouseDown; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onTouchStart", {
        get: function () { return this.view.onTouchStart; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onTap", {
        get: function () { return this.view.onTap; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onContextMenu", {
        get: function () {
            var _this = this;
            var fromKeydown = Event.chain(domEvent(this.view.domNode, 'keydown'))
                .map(function (e) { return new StandardKeyboardEvent(e); })
                .filter(function (e) { return _this.didJustPressContextMenuKey = e.keyCode === 58 /* ContextMenu */ || (e.shiftKey && e.keyCode === 68 /* F10 */); })
                .filter(function (e) { e.preventDefault(); e.stopPropagation(); return false; })
                .event;
            var fromKeyup = Event.chain(domEvent(this.view.domNode, 'keyup'))
                .filter(function () {
                var didJustPressContextMenuKey = _this.didJustPressContextMenuKey;
                _this.didJustPressContextMenuKey = false;
                return didJustPressContextMenuKey;
            })
                .filter(function () { return _this.getFocus().length > 0 && !!_this.view.domElement(_this.getFocus()[0]); })
                .map(function (browserEvent) {
                var index = _this.getFocus()[0];
                var element = _this.view.element(index);
                var anchor = _this.view.domElement(index);
                return { index: index, element: element, anchor: anchor, browserEvent: browserEvent };
            })
                .event;
            var fromMouse = Event.chain(this.view.onContextMenu)
                .filter(function () { return !_this.didJustPressContextMenuKey; })
                .map(function (_a) {
                var element = _a.element, index = _a.index, browserEvent = _a.browserEvent;
                return ({ element: element, index: index, anchor: { x: browserEvent.clientX + 1, y: browserEvent.clientY }, browserEvent: browserEvent });
            })
                .event;
            return Event.any(fromKeydown, fromKeyup, fromMouse);
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "onKeyDown", {
        get: function () { return domEvent(this.view.domNode, 'keydown'); },
        enumerable: true,
        configurable: true
    });
    List.prototype.createMouseController = function (options) {
        return new MouseController(this);
    };
    List.prototype.updateOptions = function (optionsUpdate) {
        if (optionsUpdate === void 0) { optionsUpdate = {}; }
        this._options = __assign({}, this._options, optionsUpdate);
        if (this.typeLabelController) {
            this.typeLabelController.updateOptions(this._options);
        }
    };
    Object.defineProperty(List.prototype, "options", {
        get: function () {
            return this._options;
        },
        enumerable: true,
        configurable: true
    });
    List.prototype.splice = function (start, deleteCount, elements) {
        var _this = this;
        if (elements === void 0) { elements = []; }
        if (start < 0 || start > this.view.length) {
            throw new Error("Invalid start index: " + start);
        }
        if (deleteCount < 0) {
            throw new Error("Invalid delete count: " + deleteCount);
        }
        if (deleteCount === 0 && elements.length === 0) {
            return;
        }
        this.eventBufferer.bufferEvents(function () { return _this.spliceable.splice(start, deleteCount, elements); });
    };
    List.prototype.rerender = function () {
        this.view.rerender();
    };
    List.prototype.element = function (index) {
        return this.view.element(index);
    };
    Object.defineProperty(List.prototype, "length", {
        get: function () {
            return this.view.length;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "contentHeight", {
        get: function () {
            return this.view.contentHeight;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(List.prototype, "scrollTop", {
        get: function () {
            return this.view.getScrollTop();
        },
        set: function (scrollTop) {
            this.view.setScrollTop(scrollTop);
        },
        enumerable: true,
        configurable: true
    });
    List.prototype.domFocus = function () {
        this.view.domNode.focus();
    };
    List.prototype.layout = function (height, width) {
        this.view.layout(height, width);
    };
    List.prototype.setSelection = function (indexes, browserEvent) {
        for (var _i = 0, indexes_1 = indexes; _i < indexes_1.length; _i++) {
            var index = indexes_1[_i];
            if (index < 0 || index >= this.length) {
                throw new Error("Invalid index " + index);
            }
        }
        this.selection.set(indexes, browserEvent);
    };
    List.prototype.getSelection = function () {
        return this.selection.get();
    };
    List.prototype.getSelectedElements = function () {
        var _this = this;
        return this.getSelection().map(function (i) { return _this.view.element(i); });
    };
    List.prototype.setFocus = function (indexes, browserEvent) {
        for (var _i = 0, indexes_2 = indexes; _i < indexes_2.length; _i++) {
            var index = indexes_2[_i];
            if (index < 0 || index >= this.length) {
                throw new Error("Invalid index " + index);
            }
        }
        this.focus.set(indexes, browserEvent);
    };
    List.prototype.focusNext = function (n, loop, browserEvent, filter) {
        if (n === void 0) { n = 1; }
        if (loop === void 0) { loop = false; }
        if (this.length === 0) {
            return;
        }
        var focus = this.focus.get();
        var index = this.findNextIndex(focus.length > 0 ? focus[0] + n : 0, loop, filter);
        if (index > -1) {
            this.setFocus([index], browserEvent);
        }
    };
    List.prototype.focusPrevious = function (n, loop, browserEvent, filter) {
        if (n === void 0) { n = 1; }
        if (loop === void 0) { loop = false; }
        if (this.length === 0) {
            return;
        }
        var focus = this.focus.get();
        var index = this.findPreviousIndex(focus.length > 0 ? focus[0] - n : 0, loop, filter);
        if (index > -1) {
            this.setFocus([index], browserEvent);
        }
    };
    List.prototype.focusNextPage = function (browserEvent, filter) {
        var _this = this;
        var lastPageIndex = this.view.indexAt(this.view.getScrollTop() + this.view.renderHeight);
        lastPageIndex = lastPageIndex === 0 ? 0 : lastPageIndex - 1;
        var lastPageElement = this.view.element(lastPageIndex);
        var currentlyFocusedElement = this.getFocusedElements()[0];
        if (currentlyFocusedElement !== lastPageElement) {
            var lastGoodPageIndex = this.findPreviousIndex(lastPageIndex, false, filter);
            if (lastGoodPageIndex > -1 && currentlyFocusedElement !== this.view.element(lastGoodPageIndex)) {
                this.setFocus([lastGoodPageIndex], browserEvent);
            }
            else {
                this.setFocus([lastPageIndex], browserEvent);
            }
        }
        else {
            var previousScrollTop = this.view.getScrollTop();
            this.view.setScrollTop(previousScrollTop + this.view.renderHeight - this.view.elementHeight(lastPageIndex));
            if (this.view.getScrollTop() !== previousScrollTop) {
                // Let the scroll event listener run
                setTimeout(function () { return _this.focusNextPage(browserEvent, filter); }, 0);
            }
        }
    };
    List.prototype.focusPreviousPage = function (browserEvent, filter) {
        var _this = this;
        var firstPageIndex;
        var scrollTop = this.view.getScrollTop();
        if (scrollTop === 0) {
            firstPageIndex = this.view.indexAt(scrollTop);
        }
        else {
            firstPageIndex = this.view.indexAfter(scrollTop - 1);
        }
        var firstPageElement = this.view.element(firstPageIndex);
        var currentlyFocusedElement = this.getFocusedElements()[0];
        if (currentlyFocusedElement !== firstPageElement) {
            var firstGoodPageIndex = this.findNextIndex(firstPageIndex, false, filter);
            if (firstGoodPageIndex > -1 && currentlyFocusedElement !== this.view.element(firstGoodPageIndex)) {
                this.setFocus([firstGoodPageIndex], browserEvent);
            }
            else {
                this.setFocus([firstPageIndex], browserEvent);
            }
        }
        else {
            var previousScrollTop = scrollTop;
            this.view.setScrollTop(scrollTop - this.view.renderHeight);
            if (this.view.getScrollTop() !== previousScrollTop) {
                // Let the scroll event listener run
                setTimeout(function () { return _this.focusPreviousPage(browserEvent, filter); }, 0);
            }
        }
    };
    List.prototype.focusLast = function (browserEvent, filter) {
        if (this.length === 0) {
            return;
        }
        var index = this.findPreviousIndex(this.length - 1, false, filter);
        if (index > -1) {
            this.setFocus([index], browserEvent);
        }
    };
    List.prototype.focusFirst = function (browserEvent, filter) {
        if (this.length === 0) {
            return;
        }
        var index = this.findNextIndex(0, false, filter);
        if (index > -1) {
            this.setFocus([index], browserEvent);
        }
    };
    List.prototype.findNextIndex = function (index, loop, filter) {
        if (loop === void 0) { loop = false; }
        for (var i = 0; i < this.length; i++) {
            if (index >= this.length && !loop) {
                return -1;
            }
            index = index % this.length;
            if (!filter || filter(this.element(index))) {
                return index;
            }
            index++;
        }
        return -1;
    };
    List.prototype.findPreviousIndex = function (index, loop, filter) {
        if (loop === void 0) { loop = false; }
        for (var i = 0; i < this.length; i++) {
            if (index < 0 && !loop) {
                return -1;
            }
            index = (this.length + (index % this.length)) % this.length;
            if (!filter || filter(this.element(index))) {
                return index;
            }
            index--;
        }
        return -1;
    };
    List.prototype.getFocus = function () {
        return this.focus.get();
    };
    List.prototype.getFocusedElements = function () {
        var _this = this;
        return this.getFocus().map(function (i) { return _this.view.element(i); });
    };
    List.prototype.reveal = function (index, relativeTop) {
        if (index < 0 || index >= this.length) {
            throw new Error("Invalid index " + index);
        }
        var scrollTop = this.view.getScrollTop();
        var elementTop = this.view.elementTop(index);
        var elementHeight = this.view.elementHeight(index);
        if (isNumber(relativeTop)) {
            // y = mx + b
            var m = elementHeight - this.view.renderHeight;
            this.view.setScrollTop(m * clamp(relativeTop, 0, 1) + elementTop);
        }
        else {
            var viewItemBottom = elementTop + elementHeight;
            var wrapperBottom = scrollTop + this.view.renderHeight;
            if (elementTop < scrollTop) {
                this.view.setScrollTop(elementTop);
            }
            else if (viewItemBottom >= wrapperBottom) {
                this.view.setScrollTop(viewItemBottom - this.view.renderHeight);
            }
        }
    };
    /**
     * Returns the relative position of an element rendered in the list.
     * Returns `null` if the element isn't *entirely* in the visible viewport.
     */
    List.prototype.getRelativeTop = function (index) {
        if (index < 0 || index >= this.length) {
            throw new Error("Invalid index " + index);
        }
        var scrollTop = this.view.getScrollTop();
        var elementTop = this.view.elementTop(index);
        var elementHeight = this.view.elementHeight(index);
        if (elementTop < scrollTop || elementTop + elementHeight > scrollTop + this.view.renderHeight) {
            return null;
        }
        // y = mx + b
        var m = elementHeight - this.view.renderHeight;
        return Math.abs((scrollTop - elementTop) / m);
    };
    List.prototype.getHTMLElement = function () {
        return this.view.domNode;
    };
    List.prototype.open = function (indexes, browserEvent) {
        var _this = this;
        for (var _i = 0, indexes_3 = indexes; _i < indexes_3.length; _i++) {
            var index = indexes_3[_i];
            if (index < 0 || index >= this.length) {
                throw new Error("Invalid index " + index);
            }
        }
        this._onDidOpen.fire({ indexes: indexes, elements: indexes.map(function (i) { return _this.view.element(i); }), browserEvent: browserEvent });
    };
    List.prototype.pin = function (indexes) {
        for (var _i = 0, indexes_4 = indexes; _i < indexes_4.length; _i++) {
            var index = indexes_4[_i];
            if (index < 0 || index >= this.length) {
                throw new Error("Invalid index " + index);
            }
        }
        this._onPin.fire(indexes);
    };
    List.prototype.style = function (styles) {
        this.styleController.style(styles);
    };
    List.prototype.toListEvent = function (_a) {
        var _this = this;
        var indexes = _a.indexes, browserEvent = _a.browserEvent;
        return { indexes: indexes, elements: indexes.map(function (i) { return _this.view.element(i); }), browserEvent: browserEvent };
    };
    List.prototype._onFocusChange = function () {
        var focus = this.focus.get();
        if (focus.length > 0) {
            this.view.domNode.setAttribute('aria-activedescendant', this.view.getElementDomId(focus[0]));
        }
        else {
            this.view.domNode.removeAttribute('aria-activedescendant');
        }
        this.view.domNode.setAttribute('role', 'tree');
        DOM.toggleClass(this.view.domNode, 'element-focused', focus.length > 0);
    };
    List.prototype._onSelectionChange = function () {
        var selection = this.selection.get();
        DOM.toggleClass(this.view.domNode, 'selection-none', selection.length === 0);
        DOM.toggleClass(this.view.domNode, 'selection-single', selection.length === 1);
        DOM.toggleClass(this.view.domNode, 'selection-multiple', selection.length > 1);
    };
    List.prototype.dispose = function () {
        this._onDidDispose.fire();
        this.disposables.dispose();
        this._onDidOpen.dispose();
        this._onPin.dispose();
        this._onDidDispose.dispose();
    };
    __decorate([
        memoize
    ], List.prototype, "onFocusChange", null);
    __decorate([
        memoize
    ], List.prototype, "onSelectionChange", null);
    __decorate([
        memoize
    ], List.prototype, "onContextMenu", null);
    return List;
}());
export { List };
