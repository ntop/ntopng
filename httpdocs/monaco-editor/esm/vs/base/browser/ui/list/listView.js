/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
import { getOrDefault } from '../../../common/objects.js';
import { dispose, Disposable, toDisposable } from '../../../common/lifecycle.js';
import { Gesture, EventType as TouchEventType } from '../../touch.js';
import * as DOM from '../../dom.js';
import { Event, Emitter } from '../../../common/event.js';
import { domEvent } from '../../event.js';
import { ScrollableElement } from '../scrollbar/scrollableElement.js';
import { RangeMap, shift } from './rangeMap.js';
import { RowCache } from './rowCache.js';
import { isWindows } from '../../../common/platform.js';
import * as browser from '../../browser.js';
import { memoize } from '../../../common/decorators.js';
import { Range } from '../../../common/range.js';
import { equals, distinct } from '../../../common/arrays.js';
import { DataTransfers, StaticDND } from '../../dnd.js';
import { disposableTimeout, Delayer } from '../../../common/async.js';
var DefaultOptions = {
    useShadows: true,
    verticalScrollMode: 1 /* Auto */,
    setRowLineHeight: true,
    supportDynamicHeights: false,
    dnd: {
        getDragElements: function (e) { return [e]; },
        getDragURI: function () { return null; },
        onDragStart: function () { },
        onDragOver: function () { return false; },
        drop: function () { }
    },
    horizontalScrolling: false
};
var ElementsDragAndDropData = /** @class */ (function () {
    function ElementsDragAndDropData(elements) {
        this.elements = elements;
    }
    ElementsDragAndDropData.prototype.update = function () { };
    ElementsDragAndDropData.prototype.getData = function () {
        return this.elements;
    };
    return ElementsDragAndDropData;
}());
export { ElementsDragAndDropData };
var ExternalElementsDragAndDropData = /** @class */ (function () {
    function ExternalElementsDragAndDropData(elements) {
        this.elements = elements;
    }
    ExternalElementsDragAndDropData.prototype.update = function () { };
    ExternalElementsDragAndDropData.prototype.getData = function () {
        return this.elements;
    };
    return ExternalElementsDragAndDropData;
}());
export { ExternalElementsDragAndDropData };
var DesktopDragAndDropData = /** @class */ (function () {
    function DesktopDragAndDropData() {
        this.types = [];
        this.files = [];
    }
    DesktopDragAndDropData.prototype.update = function (dataTransfer) {
        var _a;
        if (dataTransfer.types) {
            (_a = this.types).splice.apply(_a, [0, this.types.length].concat(dataTransfer.types));
        }
        if (dataTransfer.files) {
            this.files.splice(0, this.files.length);
            for (var i = 0; i < dataTransfer.files.length; i++) {
                var file = dataTransfer.files.item(i);
                if (file && (file.size || file.type)) {
                    this.files.push(file);
                }
            }
        }
    };
    DesktopDragAndDropData.prototype.getData = function () {
        return {
            types: this.types,
            files: this.files
        };
    };
    return DesktopDragAndDropData;
}());
export { DesktopDragAndDropData };
function equalsDragFeedback(f1, f2) {
    if (Array.isArray(f1) && Array.isArray(f2)) {
        return equals(f1, f2);
    }
    return f1 === f2;
}
var ListView = /** @class */ (function () {
    function ListView(container, virtualDelegate, renderers, options) {
        var _this = this;
        if (options === void 0) { options = DefaultOptions; }
        this.virtualDelegate = virtualDelegate;
        this.domId = "list_id_" + ++ListView.InstanceCount;
        this.renderers = new Map();
        this.renderWidth = 0;
        this._scrollHeight = 0;
        this.scrollableElementUpdateDisposable = null;
        this.scrollableElementWidthDelayer = new Delayer(50);
        this.splicing = false;
        this.dragOverAnimationStopDisposable = Disposable.None;
        this.dragOverMouseY = 0;
        this.canUseTranslate3d = undefined;
        this.canDrop = false;
        this.currentDragFeedbackDisposable = Disposable.None;
        this.onDragLeaveTimeout = Disposable.None;
        this._onDidChangeContentHeight = new Emitter();
        if (options.horizontalScrolling && options.supportDynamicHeights) {
            throw new Error('Horizontal scrolling and dynamic heights not supported simultaneously');
        }
        this.items = [];
        this.itemId = 0;
        this.rangeMap = new RangeMap();
        for (var _i = 0, renderers_1 = renderers; _i < renderers_1.length; _i++) {
            var renderer = renderers_1[_i];
            this.renderers.set(renderer.templateId, renderer);
        }
        this.cache = new RowCache(this.renderers);
        this.lastRenderTop = 0;
        this.lastRenderHeight = 0;
        this.domNode = document.createElement('div');
        this.domNode.className = 'monaco-list';
        DOM.addClass(this.domNode, this.domId);
        this.domNode.tabIndex = 0;
        DOM.toggleClass(this.domNode, 'mouse-support', typeof options.mouseSupport === 'boolean' ? options.mouseSupport : true);
        this.horizontalScrolling = getOrDefault(options, function (o) { return o.horizontalScrolling; }, DefaultOptions.horizontalScrolling);
        DOM.toggleClass(this.domNode, 'horizontal-scrolling', this.horizontalScrolling);
        this.additionalScrollHeight = typeof options.additionalScrollHeight === 'undefined' ? 0 : options.additionalScrollHeight;
        this.ariaProvider = options.ariaProvider || { getSetSize: function (e, i, length) { return length; }, getPosInSet: function (_, index) { return index + 1; } };
        this.rowsContainer = document.createElement('div');
        this.rowsContainer.className = 'monaco-list-rows';
        Gesture.addTarget(this.rowsContainer);
        this.scrollableElement = new ScrollableElement(this.rowsContainer, {
            alwaysConsumeMouseWheel: true,
            horizontal: this.horizontalScrolling ? 1 /* Auto */ : 2 /* Hidden */,
            vertical: getOrDefault(options, function (o) { return o.verticalScrollMode; }, DefaultOptions.verticalScrollMode),
            useShadows: getOrDefault(options, function (o) { return o.useShadows; }, DefaultOptions.useShadows)
        });
        this.domNode.appendChild(this.scrollableElement.getDomNode());
        container.appendChild(this.domNode);
        this.disposables = [this.rangeMap, this.scrollableElement, this.cache];
        this.scrollableElement.onScroll(this.onScroll, this, this.disposables);
        domEvent(this.rowsContainer, TouchEventType.Change)(this.onTouchChange, this, this.disposables);
        // Prevent the monaco-scrollable-element from scrolling
        // https://github.com/Microsoft/vscode/issues/44181
        domEvent(this.scrollableElement.getDomNode(), 'scroll')(function (e) { return e.target.scrollTop = 0; }, null, this.disposables);
        Event.map(domEvent(this.domNode, 'dragover'), function (e) { return _this.toDragEvent(e); })(this.onDragOver, this, this.disposables);
        Event.map(domEvent(this.domNode, 'drop'), function (e) { return _this.toDragEvent(e); })(this.onDrop, this, this.disposables);
        domEvent(this.domNode, 'dragleave')(this.onDragLeave, this, this.disposables);
        domEvent(window, 'dragend')(this.onDragEnd, this, this.disposables);
        this.setRowLineHeight = getOrDefault(options, function (o) { return o.setRowLineHeight; }, DefaultOptions.setRowLineHeight);
        this.supportDynamicHeights = getOrDefault(options, function (o) { return o.supportDynamicHeights; }, DefaultOptions.supportDynamicHeights);
        this.dnd = getOrDefault(options, function (o) { return o.dnd; }, DefaultOptions.dnd);
        this.layout();
    }
    Object.defineProperty(ListView.prototype, "contentHeight", {
        get: function () { return this.rangeMap.size; },
        enumerable: true,
        configurable: true
    });
    ListView.prototype.splice = function (start, deleteCount, elements) {
        if (elements === void 0) { elements = []; }
        if (this.splicing) {
            throw new Error('Can\'t run recursive splices.');
        }
        this.splicing = true;
        try {
            return this._splice(start, deleteCount, elements);
        }
        finally {
            this.splicing = false;
            this._onDidChangeContentHeight.fire(this.contentHeight);
        }
    };
    ListView.prototype._splice = function (start, deleteCount, elements) {
        var _a;
        var _this = this;
        if (elements === void 0) { elements = []; }
        var previousRenderRange = this.getRenderRange(this.lastRenderTop, this.lastRenderHeight);
        var deleteRange = { start: start, end: start + deleteCount };
        var removeRange = Range.intersect(previousRenderRange, deleteRange);
        for (var i = removeRange.start; i < removeRange.end; i++) {
            this.removeItemFromDOM(i);
        }
        var previousRestRange = { start: start + deleteCount, end: this.items.length };
        var previousRenderedRestRange = Range.intersect(previousRestRange, previousRenderRange);
        var previousUnrenderedRestRanges = Range.relativeComplement(previousRestRange, previousRenderRange);
        var inserted = elements.map(function (element) { return ({
            id: String(_this.itemId++),
            element: element,
            templateId: _this.virtualDelegate.getTemplateId(element),
            size: _this.virtualDelegate.getHeight(element),
            width: undefined,
            hasDynamicHeight: !!_this.virtualDelegate.hasDynamicHeight && _this.virtualDelegate.hasDynamicHeight(element),
            lastDynamicHeightWidth: undefined,
            row: null,
            uri: undefined,
            dropTarget: false,
            dragStartDisposable: Disposable.None
        }); });
        var deleted;
        // TODO@joao: improve this optimization to catch even more cases
        if (start === 0 && deleteCount >= this.items.length) {
            this.rangeMap = new RangeMap();
            this.rangeMap.splice(0, 0, inserted);
            this.items = inserted;
            deleted = [];
        }
        else {
            this.rangeMap.splice(start, deleteCount, inserted);
            deleted = (_a = this.items).splice.apply(_a, [start, deleteCount].concat(inserted));
        }
        var delta = elements.length - deleteCount;
        var renderRange = this.getRenderRange(this.lastRenderTop, this.lastRenderHeight);
        var renderedRestRange = shift(previousRenderedRestRange, delta);
        var updateRange = Range.intersect(renderRange, renderedRestRange);
        for (var i = updateRange.start; i < updateRange.end; i++) {
            this.updateItemInDOM(this.items[i], i);
        }
        var removeRanges = Range.relativeComplement(renderedRestRange, renderRange);
        for (var _i = 0, removeRanges_1 = removeRanges; _i < removeRanges_1.length; _i++) {
            var range = removeRanges_1[_i];
            for (var i = range.start; i < range.end; i++) {
                this.removeItemFromDOM(i);
            }
        }
        var unrenderedRestRanges = previousUnrenderedRestRanges.map(function (r) { return shift(r, delta); });
        var elementsRange = { start: start, end: start + elements.length };
        var insertRanges = [elementsRange].concat(unrenderedRestRanges).map(function (r) { return Range.intersect(renderRange, r); });
        var beforeElement = this.getNextToLastElement(insertRanges);
        for (var _b = 0, insertRanges_1 = insertRanges; _b < insertRanges_1.length; _b++) {
            var range = insertRanges_1[_b];
            for (var i = range.start; i < range.end; i++) {
                this.insertItemInDOM(i, beforeElement);
            }
        }
        this.eventuallyUpdateScrollDimensions();
        if (this.supportDynamicHeights) {
            this._rerender(this.scrollTop, this.renderHeight);
        }
        return deleted.map(function (i) { return i.element; });
    };
    ListView.prototype.eventuallyUpdateScrollDimensions = function () {
        var _this = this;
        this._scrollHeight = this.contentHeight;
        this.rowsContainer.style.height = this._scrollHeight + "px";
        if (!this.scrollableElementUpdateDisposable) {
            this.scrollableElementUpdateDisposable = DOM.scheduleAtNextAnimationFrame(function () {
                _this.scrollableElement.setScrollDimensions({ scrollHeight: _this.scrollHeight });
                _this.updateScrollWidth();
                _this.scrollableElementUpdateDisposable = null;
            });
        }
    };
    ListView.prototype.eventuallyUpdateScrollWidth = function () {
        var _this = this;
        if (!this.horizontalScrolling) {
            return;
        }
        this.scrollableElementWidthDelayer.trigger(function () { return _this.updateScrollWidth(); });
    };
    ListView.prototype.updateScrollWidth = function () {
        if (!this.horizontalScrolling) {
            return;
        }
        if (this.items.length === 0) {
            this.scrollableElement.setScrollDimensions({ scrollWidth: 0 });
        }
        var scrollWidth = 0;
        for (var _i = 0, _a = this.items; _i < _a.length; _i++) {
            var item = _a[_i];
            if (typeof item.width !== 'undefined') {
                scrollWidth = Math.max(scrollWidth, item.width);
            }
        }
        this.scrollWidth = scrollWidth;
        this.scrollableElement.setScrollDimensions({ scrollWidth: scrollWidth + 10 });
    };
    ListView.prototype.rerender = function () {
        if (!this.supportDynamicHeights) {
            return;
        }
        for (var _i = 0, _a = this.items; _i < _a.length; _i++) {
            var item = _a[_i];
            item.lastDynamicHeightWidth = undefined;
        }
        this._rerender(this.lastRenderTop, this.lastRenderHeight);
    };
    Object.defineProperty(ListView.prototype, "length", {
        get: function () {
            return this.items.length;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "renderHeight", {
        get: function () {
            var scrollDimensions = this.scrollableElement.getScrollDimensions();
            return scrollDimensions.height;
        },
        enumerable: true,
        configurable: true
    });
    ListView.prototype.element = function (index) {
        return this.items[index].element;
    };
    ListView.prototype.domElement = function (index) {
        var row = this.items[index].row;
        return row && row.domNode;
    };
    ListView.prototype.elementHeight = function (index) {
        return this.items[index].size;
    };
    ListView.prototype.elementTop = function (index) {
        return this.rangeMap.positionAt(index);
    };
    ListView.prototype.indexAt = function (position) {
        return this.rangeMap.indexAt(position);
    };
    ListView.prototype.indexAfter = function (position) {
        return this.rangeMap.indexAfter(position);
    };
    ListView.prototype.layout = function (height, width) {
        var scrollDimensions = {
            height: typeof height === 'number' ? height : DOM.getContentHeight(this.domNode)
        };
        if (this.scrollableElementUpdateDisposable) {
            this.scrollableElementUpdateDisposable.dispose();
            this.scrollableElementUpdateDisposable = null;
            scrollDimensions.scrollHeight = this.scrollHeight;
        }
        this.scrollableElement.setScrollDimensions(scrollDimensions);
        if (typeof width !== 'undefined') {
            this.renderWidth = width;
            if (this.supportDynamicHeights) {
                this._rerender(this.scrollTop, this.renderHeight);
            }
            if (this.horizontalScrolling) {
                this.scrollableElement.setScrollDimensions({
                    width: typeof width === 'number' ? width : DOM.getContentWidth(this.domNode)
                });
            }
        }
    };
    // Render
    ListView.prototype.render = function (renderTop, renderHeight, renderLeft, scrollWidth) {
        var previousRenderRange = this.getRenderRange(this.lastRenderTop, this.lastRenderHeight);
        var renderRange = this.getRenderRange(renderTop, renderHeight);
        var rangesToInsert = Range.relativeComplement(renderRange, previousRenderRange);
        var rangesToRemove = Range.relativeComplement(previousRenderRange, renderRange);
        var beforeElement = this.getNextToLastElement(rangesToInsert);
        for (var _i = 0, rangesToInsert_1 = rangesToInsert; _i < rangesToInsert_1.length; _i++) {
            var range = rangesToInsert_1[_i];
            for (var i = range.start; i < range.end; i++) {
                this.insertItemInDOM(i, beforeElement);
            }
        }
        for (var _a = 0, rangesToRemove_1 = rangesToRemove; _a < rangesToRemove_1.length; _a++) {
            var range = rangesToRemove_1[_a];
            for (var i = range.start; i < range.end; i++) {
                this.removeItemFromDOM(i);
            }
        }
        var canUseTranslate3d = !isWindows && !browser.isFirefox && browser.getZoomLevel() === 0;
        if (canUseTranslate3d) {
            var transform = "translate3d(-" + renderLeft + "px, -" + renderTop + "px, 0px)";
            this.rowsContainer.style.transform = transform;
            this.rowsContainer.style.webkitTransform = transform;
            if (canUseTranslate3d !== this.canUseTranslate3d) {
                this.rowsContainer.style.left = '0';
                this.rowsContainer.style.top = '0';
            }
        }
        else {
            this.rowsContainer.style.left = "-" + renderLeft + "px";
            this.rowsContainer.style.top = "-" + renderTop + "px";
            if (canUseTranslate3d !== this.canUseTranslate3d) {
                this.rowsContainer.style.transform = '';
                this.rowsContainer.style.webkitTransform = '';
            }
        }
        if (this.horizontalScrolling) {
            this.rowsContainer.style.width = Math.max(scrollWidth, this.renderWidth) + "px";
        }
        this.canUseTranslate3d = canUseTranslate3d;
        this.lastRenderTop = renderTop;
        this.lastRenderHeight = renderHeight;
    };
    // DOM operations
    ListView.prototype.insertItemInDOM = function (index, beforeElement) {
        var _this = this;
        var item = this.items[index];
        if (!item.row) {
            item.row = this.cache.alloc(item.templateId);
            var role = this.ariaProvider.getRole ? this.ariaProvider.getRole(item.element) : 'treeitem';
            item.row.domNode.setAttribute('role', role);
            var checked = this.ariaProvider.isChecked ? this.ariaProvider.isChecked(item.element) : undefined;
            if (typeof checked !== 'undefined') {
                item.row.domNode.setAttribute('aria-checked', String(checked));
            }
        }
        if (!item.row.domNode.parentElement) {
            if (beforeElement) {
                this.rowsContainer.insertBefore(item.row.domNode, beforeElement);
            }
            else {
                this.rowsContainer.appendChild(item.row.domNode);
            }
        }
        this.updateItemInDOM(item, index);
        var renderer = this.renderers.get(item.templateId);
        if (!renderer) {
            throw new Error("No renderer found for template id " + item.templateId);
        }
        if (renderer) {
            renderer.renderElement(item.element, index, item.row.templateData, item.size);
        }
        var uri = this.dnd.getDragURI(item.element);
        item.dragStartDisposable.dispose();
        item.row.domNode.draggable = !!uri;
        if (uri) {
            var onDragStart = domEvent(item.row.domNode, 'dragstart');
            item.dragStartDisposable = onDragStart(function (event) { return _this.onDragStart(item.element, uri, event); });
        }
        if (this.horizontalScrolling) {
            this.measureItemWidth(item);
            this.eventuallyUpdateScrollWidth();
        }
    };
    ListView.prototype.measureItemWidth = function (item) {
        if (!item.row || !item.row.domNode) {
            return;
        }
        item.row.domNode.style.width = 'fit-content';
        item.width = DOM.getContentWidth(item.row.domNode);
        var style = window.getComputedStyle(item.row.domNode);
        if (style.paddingLeft) {
            item.width += parseFloat(style.paddingLeft);
        }
        if (style.paddingRight) {
            item.width += parseFloat(style.paddingRight);
        }
        item.row.domNode.style.width = '';
    };
    ListView.prototype.updateItemInDOM = function (item, index) {
        item.row.domNode.style.top = this.elementTop(index) + "px";
        item.row.domNode.style.height = item.size + "px";
        if (this.setRowLineHeight) {
            item.row.domNode.style.lineHeight = item.size + "px";
        }
        item.row.domNode.setAttribute('data-index', "" + index);
        item.row.domNode.setAttribute('data-last-element', index === this.length - 1 ? 'true' : 'false');
        item.row.domNode.setAttribute('aria-setsize', String(this.ariaProvider.getSetSize(item.element, index, this.length)));
        item.row.domNode.setAttribute('aria-posinset', String(this.ariaProvider.getPosInSet(item.element, index)));
        item.row.domNode.setAttribute('id', this.getElementDomId(index));
        DOM.toggleClass(item.row.domNode, 'drop-target', item.dropTarget);
    };
    ListView.prototype.removeItemFromDOM = function (index) {
        var item = this.items[index];
        item.dragStartDisposable.dispose();
        var renderer = this.renderers.get(item.templateId);
        if (renderer && renderer.disposeElement) {
            renderer.disposeElement(item.element, index, item.row.templateData, item.size);
        }
        this.cache.release(item.row);
        item.row = null;
        if (this.horizontalScrolling) {
            this.eventuallyUpdateScrollWidth();
        }
    };
    ListView.prototype.getScrollTop = function () {
        var scrollPosition = this.scrollableElement.getScrollPosition();
        return scrollPosition.scrollTop;
    };
    ListView.prototype.setScrollTop = function (scrollTop) {
        if (this.scrollableElementUpdateDisposable) {
            this.scrollableElementUpdateDisposable.dispose();
            this.scrollableElementUpdateDisposable = null;
            this.scrollableElement.setScrollDimensions({ scrollHeight: this.scrollHeight });
        }
        this.scrollableElement.setScrollPosition({ scrollTop: scrollTop });
    };
    Object.defineProperty(ListView.prototype, "scrollTop", {
        get: function () {
            return this.getScrollTop();
        },
        set: function (scrollTop) {
            this.setScrollTop(scrollTop);
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "scrollHeight", {
        get: function () {
            return this._scrollHeight + (this.horizontalScrolling ? 10 : 0) + this.additionalScrollHeight;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "onMouseClick", {
        // Events
        get: function () {
            var _this = this;
            return Event.map(domEvent(this.domNode, 'click'), function (e) { return _this.toMouseEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "onMouseDblClick", {
        get: function () {
            var _this = this;
            return Event.map(domEvent(this.domNode, 'dblclick'), function (e) { return _this.toMouseEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "onMouseMiddleClick", {
        get: function () {
            var _this = this;
            return Event.filter(Event.map(domEvent(this.domNode, 'auxclick'), function (e) { return _this.toMouseEvent(e); }), function (e) { return e.browserEvent.button === 1; });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "onMouseDown", {
        get: function () {
            var _this = this;
            return Event.map(domEvent(this.domNode, 'mousedown'), function (e) { return _this.toMouseEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "onContextMenu", {
        get: function () {
            var _this = this;
            return Event.map(domEvent(this.domNode, 'contextmenu'), function (e) { return _this.toMouseEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "onTouchStart", {
        get: function () {
            var _this = this;
            return Event.map(domEvent(this.domNode, 'touchstart'), function (e) { return _this.toTouchEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ListView.prototype, "onTap", {
        get: function () {
            var _this = this;
            return Event.map(domEvent(this.rowsContainer, TouchEventType.Tap), function (e) { return _this.toGestureEvent(e); });
        },
        enumerable: true,
        configurable: true
    });
    ListView.prototype.toMouseEvent = function (browserEvent) {
        var index = this.getItemIndexFromEventTarget(browserEvent.target || null);
        var item = typeof index === 'undefined' ? undefined : this.items[index];
        var element = item && item.element;
        return { browserEvent: browserEvent, index: index, element: element };
    };
    ListView.prototype.toTouchEvent = function (browserEvent) {
        var index = this.getItemIndexFromEventTarget(browserEvent.target || null);
        var item = typeof index === 'undefined' ? undefined : this.items[index];
        var element = item && item.element;
        return { browserEvent: browserEvent, index: index, element: element };
    };
    ListView.prototype.toGestureEvent = function (browserEvent) {
        var index = this.getItemIndexFromEventTarget(browserEvent.initialTarget || null);
        var item = typeof index === 'undefined' ? undefined : this.items[index];
        var element = item && item.element;
        return { browserEvent: browserEvent, index: index, element: element };
    };
    ListView.prototype.toDragEvent = function (browserEvent) {
        var index = this.getItemIndexFromEventTarget(browserEvent.target || null);
        var item = typeof index === 'undefined' ? undefined : this.items[index];
        var element = item && item.element;
        return { browserEvent: browserEvent, index: index, element: element };
    };
    ListView.prototype.onScroll = function (e) {
        try {
            this.render(e.scrollTop, e.height, e.scrollLeft, e.scrollWidth);
            if (this.supportDynamicHeights) {
                this._rerender(e.scrollTop, e.height);
            }
        }
        catch (err) {
            console.error('Got bad scroll event:', e);
            throw err;
        }
    };
    ListView.prototype.onTouchChange = function (event) {
        event.preventDefault();
        event.stopPropagation();
        this.scrollTop -= event.translationY;
    };
    // DND
    ListView.prototype.onDragStart = function (element, uri, event) {
        if (!event.dataTransfer) {
            return;
        }
        var elements = this.dnd.getDragElements(element);
        event.dataTransfer.effectAllowed = 'copyMove';
        event.dataTransfer.setData(DataTransfers.RESOURCES, JSON.stringify([uri]));
        if (event.dataTransfer.setDragImage) {
            var label = void 0;
            if (this.dnd.getDragLabel) {
                label = this.dnd.getDragLabel(elements);
            }
            if (typeof label === 'undefined') {
                label = String(elements.length);
            }
            var dragImage_1 = DOM.$('.monaco-drag-image');
            dragImage_1.textContent = label;
            document.body.appendChild(dragImage_1);
            event.dataTransfer.setDragImage(dragImage_1, -10, -10);
            setTimeout(function () { return document.body.removeChild(dragImage_1); }, 0);
        }
        this.currentDragData = new ElementsDragAndDropData(elements);
        StaticDND.CurrentDragAndDropData = new ExternalElementsDragAndDropData(elements);
        if (this.dnd.onDragStart) {
            this.dnd.onDragStart(this.currentDragData, event);
        }
    };
    ListView.prototype.onDragOver = function (event) {
        var _this = this;
        event.browserEvent.preventDefault(); // needed so that the drop event fires (https://stackoverflow.com/questions/21339924/drop-event-not-firing-in-chrome)
        this.onDragLeaveTimeout.dispose();
        if (StaticDND.CurrentDragAndDropData && StaticDND.CurrentDragAndDropData.getData() === 'vscode-ui') {
            return false;
        }
        this.setupDragAndDropScrollTopAnimation(event.browserEvent);
        if (!event.browserEvent.dataTransfer) {
            return false;
        }
        // Drag over from outside
        if (!this.currentDragData) {
            if (StaticDND.CurrentDragAndDropData) {
                // Drag over from another list
                this.currentDragData = StaticDND.CurrentDragAndDropData;
            }
            else {
                // Drag over from the desktop
                if (!event.browserEvent.dataTransfer.types) {
                    return false;
                }
                this.currentDragData = new DesktopDragAndDropData();
            }
        }
        var result = this.dnd.onDragOver(this.currentDragData, event.element, event.index, event.browserEvent);
        this.canDrop = typeof result === 'boolean' ? result : result.accept;
        if (!this.canDrop) {
            this.currentDragFeedback = undefined;
            this.currentDragFeedbackDisposable.dispose();
            return false;
        }
        event.browserEvent.dataTransfer.dropEffect = (typeof result !== 'boolean' && result.effect === 0 /* Copy */) ? 'copy' : 'move';
        var feedback;
        if (typeof result !== 'boolean' && result.feedback) {
            feedback = result.feedback;
        }
        else {
            if (typeof event.index === 'undefined') {
                feedback = [-1];
            }
            else {
                feedback = [event.index];
            }
        }
        // sanitize feedback list
        feedback = distinct(feedback).filter(function (i) { return i >= -1 && i < _this.length; }).sort();
        feedback = feedback[0] === -1 ? [-1] : feedback;
        if (feedback.length === 0) {
            throw new Error('Invalid empty feedback list');
        }
        if (equalsDragFeedback(this.currentDragFeedback, feedback)) {
            return true;
        }
        this.currentDragFeedback = feedback;
        this.currentDragFeedbackDisposable.dispose();
        if (feedback[0] === -1) { // entire list feedback
            DOM.addClass(this.domNode, 'drop-target');
            this.currentDragFeedbackDisposable = toDisposable(function () { return DOM.removeClass(_this.domNode, 'drop-target'); });
        }
        else {
            for (var _i = 0, feedback_1 = feedback; _i < feedback_1.length; _i++) {
                var index = feedback_1[_i];
                var item = this.items[index];
                item.dropTarget = true;
                if (item.row && item.row.domNode) {
                    DOM.addClass(item.row.domNode, 'drop-target');
                }
            }
            this.currentDragFeedbackDisposable = toDisposable(function () {
                for (var _i = 0, feedback_2 = feedback; _i < feedback_2.length; _i++) {
                    var index = feedback_2[_i];
                    var item = _this.items[index];
                    item.dropTarget = false;
                    if (item.row && item.row.domNode) {
                        DOM.removeClass(item.row.domNode, 'drop-target');
                    }
                }
            });
        }
        return true;
    };
    ListView.prototype.onDragLeave = function () {
        var _this = this;
        this.onDragLeaveTimeout.dispose();
        this.onDragLeaveTimeout = disposableTimeout(function () { return _this.clearDragOverFeedback(); }, 100);
    };
    ListView.prototype.onDrop = function (event) {
        if (!this.canDrop) {
            return;
        }
        var dragData = this.currentDragData;
        this.teardownDragAndDropScrollTopAnimation();
        this.clearDragOverFeedback();
        this.currentDragData = undefined;
        StaticDND.CurrentDragAndDropData = undefined;
        if (!dragData || !event.browserEvent.dataTransfer) {
            return;
        }
        event.browserEvent.preventDefault();
        dragData.update(event.browserEvent.dataTransfer);
        this.dnd.drop(dragData, event.element, event.index, event.browserEvent);
    };
    ListView.prototype.onDragEnd = function () {
        this.canDrop = false;
        this.teardownDragAndDropScrollTopAnimation();
        this.clearDragOverFeedback();
        this.currentDragData = undefined;
        StaticDND.CurrentDragAndDropData = undefined;
    };
    ListView.prototype.clearDragOverFeedback = function () {
        this.currentDragFeedback = undefined;
        this.currentDragFeedbackDisposable.dispose();
        this.currentDragFeedbackDisposable = Disposable.None;
    };
    // DND scroll top animation
    ListView.prototype.setupDragAndDropScrollTopAnimation = function (event) {
        var _this = this;
        if (!this.dragOverAnimationDisposable) {
            var viewTop = DOM.getTopLeftOffset(this.domNode).top;
            this.dragOverAnimationDisposable = DOM.animate(this.animateDragAndDropScrollTop.bind(this, viewTop));
        }
        this.dragOverAnimationStopDisposable.dispose();
        this.dragOverAnimationStopDisposable = disposableTimeout(function () {
            if (_this.dragOverAnimationDisposable) {
                _this.dragOverAnimationDisposable.dispose();
                _this.dragOverAnimationDisposable = undefined;
            }
        }, 1000);
        this.dragOverMouseY = event.pageY;
    };
    ListView.prototype.animateDragAndDropScrollTop = function (viewTop) {
        if (this.dragOverMouseY === undefined) {
            return;
        }
        var diff = this.dragOverMouseY - viewTop;
        var upperLimit = this.renderHeight - 35;
        if (diff < 35) {
            this.scrollTop += Math.max(-14, Math.floor(0.3 * (diff - 35)));
        }
        else if (diff > upperLimit) {
            this.scrollTop += Math.min(14, Math.floor(0.3 * (diff - upperLimit)));
        }
    };
    ListView.prototype.teardownDragAndDropScrollTopAnimation = function () {
        this.dragOverAnimationStopDisposable.dispose();
        if (this.dragOverAnimationDisposable) {
            this.dragOverAnimationDisposable.dispose();
            this.dragOverAnimationDisposable = undefined;
        }
    };
    // Util
    ListView.prototype.getItemIndexFromEventTarget = function (target) {
        var element = target;
        while (element instanceof HTMLElement && element !== this.rowsContainer) {
            var rawIndex = element.getAttribute('data-index');
            if (rawIndex) {
                var index = Number(rawIndex);
                if (!isNaN(index)) {
                    return index;
                }
            }
            element = element.parentElement;
        }
        return undefined;
    };
    ListView.prototype.getRenderRange = function (renderTop, renderHeight) {
        return {
            start: this.rangeMap.indexAt(renderTop),
            end: this.rangeMap.indexAfter(renderTop + renderHeight - 1)
        };
    };
    /**
     * Given a stable rendered state, checks every rendered element whether it needs
     * to be probed for dynamic height. Adjusts scroll height and top if necessary.
     */
    ListView.prototype._rerender = function (renderTop, renderHeight) {
        var previousRenderRange = this.getRenderRange(renderTop, renderHeight);
        // Let's remember the second element's position, this helps in scrolling up
        // and preserving a linear upwards scroll movement
        var anchorElementIndex;
        var anchorElementTopDelta;
        if (renderTop === this.elementTop(previousRenderRange.start)) {
            anchorElementIndex = previousRenderRange.start;
            anchorElementTopDelta = 0;
        }
        else if (previousRenderRange.end - previousRenderRange.start > 1) {
            anchorElementIndex = previousRenderRange.start + 1;
            anchorElementTopDelta = this.elementTop(anchorElementIndex) - renderTop;
        }
        var heightDiff = 0;
        while (true) {
            var renderRange = this.getRenderRange(renderTop, renderHeight);
            var didChange = false;
            for (var i = renderRange.start; i < renderRange.end; i++) {
                var diff = this.probeDynamicHeight(i);
                if (diff !== 0) {
                    this.rangeMap.splice(i, 1, [this.items[i]]);
                }
                heightDiff += diff;
                didChange = didChange || diff !== 0;
            }
            if (!didChange) {
                if (heightDiff !== 0) {
                    this.eventuallyUpdateScrollDimensions();
                }
                var unrenderRanges = Range.relativeComplement(previousRenderRange, renderRange);
                for (var _i = 0, unrenderRanges_1 = unrenderRanges; _i < unrenderRanges_1.length; _i++) {
                    var range = unrenderRanges_1[_i];
                    for (var i = range.start; i < range.end; i++) {
                        if (this.items[i].row) {
                            this.removeItemFromDOM(i);
                        }
                    }
                }
                var renderRanges = Range.relativeComplement(renderRange, previousRenderRange);
                for (var _a = 0, renderRanges_1 = renderRanges; _a < renderRanges_1.length; _a++) {
                    var range = renderRanges_1[_a];
                    for (var i = range.start; i < range.end; i++) {
                        var afterIndex = i + 1;
                        var beforeRow = afterIndex < this.items.length ? this.items[afterIndex].row : null;
                        var beforeElement = beforeRow ? beforeRow.domNode : null;
                        this.insertItemInDOM(i, beforeElement);
                    }
                }
                for (var i = renderRange.start; i < renderRange.end; i++) {
                    if (this.items[i].row) {
                        this.updateItemInDOM(this.items[i], i);
                    }
                }
                if (typeof anchorElementIndex === 'number') {
                    this.scrollTop = this.elementTop(anchorElementIndex) - anchorElementTopDelta;
                }
                this._onDidChangeContentHeight.fire(this.contentHeight);
                return;
            }
        }
    };
    ListView.prototype.probeDynamicHeight = function (index) {
        var item = this.items[index];
        if (!item.hasDynamicHeight || item.lastDynamicHeightWidth === this.renderWidth) {
            return 0;
        }
        var size = item.size;
        var row = this.cache.alloc(item.templateId);
        row.domNode.style.height = '';
        this.rowsContainer.appendChild(row.domNode);
        var renderer = this.renderers.get(item.templateId);
        if (renderer) {
            renderer.renderElement(item.element, index, row.templateData, undefined);
            if (renderer.disposeElement) {
                renderer.disposeElement(item.element, index, row.templateData, undefined);
            }
        }
        item.size = row.domNode.offsetHeight;
        if (this.virtualDelegate.setDynamicHeight) {
            this.virtualDelegate.setDynamicHeight(item.element, item.size);
        }
        item.lastDynamicHeightWidth = this.renderWidth;
        this.rowsContainer.removeChild(row.domNode);
        this.cache.release(row);
        return item.size - size;
    };
    ListView.prototype.getNextToLastElement = function (ranges) {
        var lastRange = ranges[ranges.length - 1];
        if (!lastRange) {
            return null;
        }
        var nextToLastItem = this.items[lastRange.end];
        if (!nextToLastItem) {
            return null;
        }
        if (!nextToLastItem.row) {
            return null;
        }
        return nextToLastItem.row.domNode;
    };
    ListView.prototype.getElementDomId = function (index) {
        return this.domId + "_" + index;
    };
    // Dispose
    ListView.prototype.dispose = function () {
        if (this.items) {
            for (var _i = 0, _a = this.items; _i < _a.length; _i++) {
                var item = _a[_i];
                if (item.row) {
                    var renderer = this.renderers.get(item.row.templateId);
                    if (renderer) {
                        renderer.disposeTemplate(item.row.templateData);
                    }
                }
            }
            this.items = [];
        }
        if (this.domNode && this.domNode.parentNode) {
            this.domNode.parentNode.removeChild(this.domNode);
        }
        this.disposables = dispose(this.disposables);
    };
    ListView.InstanceCount = 0;
    __decorate([
        memoize
    ], ListView.prototype, "onMouseClick", null);
    __decorate([
        memoize
    ], ListView.prototype, "onMouseDblClick", null);
    __decorate([
        memoize
    ], ListView.prototype, "onMouseMiddleClick", null);
    __decorate([
        memoize
    ], ListView.prototype, "onMouseDown", null);
    __decorate([
        memoize
    ], ListView.prototype, "onContextMenu", null);
    __decorate([
        memoize
    ], ListView.prototype, "onTouchStart", null);
    __decorate([
        memoize
    ], ListView.prototype, "onTap", null);
    return ListView;
}());
export { ListView };
