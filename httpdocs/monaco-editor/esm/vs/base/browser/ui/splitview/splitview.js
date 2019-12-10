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
import './splitview.css';
import { toDisposable, Disposable, combinedDisposable } from '../../../common/lifecycle.js';
import { Event, Emitter } from '../../../common/event.js';
import * as types from '../../../common/types.js';
import * as dom from '../../dom.js';
import { clamp } from '../../../common/numbers.js';
import { range, firstIndex, pushToStart, pushToEnd } from '../../../common/arrays.js';
import { Sash } from '../sash/sash.js';
import { Color } from '../../../common/color.js';
import { domEvent } from '../../event.js';
var defaultStyles = {
    separatorBorder: Color.transparent
};
var ViewItem = /** @class */ (function () {
    function ViewItem(container, view, size, disposable) {
        this.container = container;
        this.view = view;
        this.disposable = disposable;
        this._cachedVisibleSize = undefined;
        if (typeof size === 'number') {
            this._size = size;
            this._cachedVisibleSize = undefined;
            dom.addClass(container, 'visible');
        }
        else {
            this._size = 0;
            this._cachedVisibleSize = size.cachedVisibleSize;
        }
    }
    Object.defineProperty(ViewItem.prototype, "size", {
        get: function () {
            return this._size;
        },
        set: function (size) {
            this._size = size;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ViewItem.prototype, "visible", {
        get: function () {
            return typeof this._cachedVisibleSize === 'undefined';
        },
        enumerable: true,
        configurable: true
    });
    ViewItem.prototype.setVisible = function (visible, size) {
        if (visible === this.visible) {
            return;
        }
        if (visible) {
            this.size = clamp(this._cachedVisibleSize, this.viewMinimumSize, this.viewMaximumSize);
            this._cachedVisibleSize = undefined;
        }
        else {
            this._cachedVisibleSize = typeof size === 'number' ? size : this.size;
            this.size = 0;
        }
        dom.toggleClass(this.container, 'visible', visible);
        if (this.view.setVisible) {
            this.view.setVisible(visible);
        }
    };
    Object.defineProperty(ViewItem.prototype, "minimumSize", {
        get: function () { return this.visible ? this.view.minimumSize : 0; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ViewItem.prototype, "viewMinimumSize", {
        get: function () { return this.view.minimumSize; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ViewItem.prototype, "maximumSize", {
        get: function () { return this.visible ? this.view.maximumSize : 0; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ViewItem.prototype, "viewMaximumSize", {
        get: function () { return this.view.maximumSize; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ViewItem.prototype, "priority", {
        get: function () { return this.view.priority; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(ViewItem.prototype, "snap", {
        get: function () { return !!this.view.snap; },
        enumerable: true,
        configurable: true
    });
    ViewItem.prototype.layout = function (orthogonalSize) {
        this.view.layout(this.size, orthogonalSize);
    };
    ViewItem.prototype.dispose = function () {
        this.disposable.dispose();
        return this.view;
    };
    return ViewItem;
}());
var VerticalViewItem = /** @class */ (function (_super) {
    __extends(VerticalViewItem, _super);
    function VerticalViewItem() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    VerticalViewItem.prototype.layout = function (orthogonalSize) {
        _super.prototype.layout.call(this, orthogonalSize);
        this.container.style.height = this.size + "px";
    };
    return VerticalViewItem;
}(ViewItem));
var HorizontalViewItem = /** @class */ (function (_super) {
    __extends(HorizontalViewItem, _super);
    function HorizontalViewItem() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    HorizontalViewItem.prototype.layout = function (orthogonalSize) {
        _super.prototype.layout.call(this, orthogonalSize);
        this.container.style.width = this.size + "px";
    };
    return HorizontalViewItem;
}(ViewItem));
var State;
(function (State) {
    State[State["Idle"] = 0] = "Idle";
    State[State["Busy"] = 1] = "Busy";
})(State || (State = {}));
export var Sizing;
(function (Sizing) {
    Sizing.Distribute = { type: 'distribute' };
    function Split(index) { return { type: 'split', index: index }; }
    Sizing.Split = Split;
    function Invisible(cachedVisibleSize) { return { type: 'invisible', cachedVisibleSize: cachedVisibleSize }; }
    Sizing.Invisible = Invisible;
})(Sizing || (Sizing = {}));
var SplitView = /** @class */ (function (_super) {
    __extends(SplitView, _super);
    function SplitView(container, options) {
        if (options === void 0) { options = {}; }
        var _this = _super.call(this) || this;
        _this.size = 0;
        _this.contentSize = 0;
        _this.proportions = undefined;
        _this.viewItems = [];
        _this.sashItems = [];
        _this.state = State.Idle;
        _this._onDidSashChange = _this._register(new Emitter());
        _this.onDidSashChange = _this._onDidSashChange.event;
        _this._onDidSashReset = _this._register(new Emitter());
        _this.orientation = types.isUndefined(options.orientation) ? 0 /* VERTICAL */ : options.orientation;
        _this.inverseAltBehavior = !!options.inverseAltBehavior;
        _this.proportionalLayout = types.isUndefined(options.proportionalLayout) ? true : !!options.proportionalLayout;
        _this.el = document.createElement('div');
        dom.addClass(_this.el, 'monaco-split-view2');
        dom.addClass(_this.el, _this.orientation === 0 /* VERTICAL */ ? 'vertical' : 'horizontal');
        container.appendChild(_this.el);
        _this.sashContainer = dom.append(_this.el, dom.$('.sash-container'));
        _this.viewContainer = dom.append(_this.el, dom.$('.split-view-container'));
        _this.style(options.styles || defaultStyles);
        // We have an existing set of view, add them now
        if (options.descriptor) {
            _this.size = options.descriptor.size;
            options.descriptor.views.forEach(function (viewDescriptor, index) {
                var sizing = types.isUndefined(viewDescriptor.visible) || viewDescriptor.visible ? viewDescriptor.size : { type: 'invisible', cachedVisibleSize: viewDescriptor.size };
                var view = viewDescriptor.view;
                _this.doAddView(view, sizing, index, true);
            });
            // Initialize content size and proportions for first layout
            _this.contentSize = _this.viewItems.reduce(function (r, i) { return r + i.size; }, 0);
            _this.saveProportions();
        }
        return _this;
    }
    Object.defineProperty(SplitView.prototype, "orthogonalStartSash", {
        get: function () { return this._orthogonalStartSash; },
        set: function (sash) {
            for (var _i = 0, _a = this.sashItems; _i < _a.length; _i++) {
                var sashItem = _a[_i];
                sashItem.sash.orthogonalStartSash = sash;
            }
            this._orthogonalStartSash = sash;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(SplitView.prototype, "orthogonalEndSash", {
        get: function () { return this._orthogonalEndSash; },
        set: function (sash) {
            for (var _i = 0, _a = this.sashItems; _i < _a.length; _i++) {
                var sashItem = _a[_i];
                sashItem.sash.orthogonalEndSash = sash;
            }
            this._orthogonalEndSash = sash;
        },
        enumerable: true,
        configurable: true
    });
    SplitView.prototype.style = function (styles) {
        if (styles.separatorBorder.isTransparent()) {
            dom.removeClass(this.el, 'separator-border');
            this.el.style.removeProperty('--separator-border');
        }
        else {
            dom.addClass(this.el, 'separator-border');
            this.el.style.setProperty('--separator-border', styles.separatorBorder.toString());
        }
    };
    SplitView.prototype.addView = function (view, size, index) {
        if (index === void 0) { index = this.viewItems.length; }
        this.doAddView(view, size, index, false);
    };
    SplitView.prototype.layout = function (size, orthogonalSize) {
        var _this = this;
        var previousSize = Math.max(this.size, this.contentSize);
        this.size = size;
        this.orthogonalSize = orthogonalSize;
        if (!this.proportions) {
            var indexes = range(this.viewItems.length);
            var lowPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 1 /* Low */; });
            var highPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 2 /* High */; });
            this.resize(this.viewItems.length - 1, size - previousSize, undefined, lowPriorityIndexes, highPriorityIndexes);
        }
        else {
            for (var i = 0; i < this.viewItems.length; i++) {
                var item = this.viewItems[i];
                item.size = clamp(Math.round(this.proportions[i] * size), item.minimumSize, item.maximumSize);
            }
        }
        this.distributeEmptySpace();
        this.layoutViews();
    };
    SplitView.prototype.saveProportions = function () {
        var _this = this;
        if (this.proportionalLayout && this.contentSize > 0) {
            this.proportions = this.viewItems.map(function (i) { return i.size / _this.contentSize; });
        }
    };
    SplitView.prototype.onSashStart = function (_a) {
        var _this = this;
        var sash = _a.sash, start = _a.start, alt = _a.alt;
        var index = firstIndex(this.sashItems, function (item) { return item.sash === sash; });
        // This way, we can press Alt while we resize a sash, macOS style!
        var disposable = combinedDisposable(domEvent(document.body, 'keydown')(function (e) { return resetSashDragState(_this.sashDragState.current, e.altKey); }), domEvent(document.body, 'keyup')(function () { return resetSashDragState(_this.sashDragState.current, false); }));
        var resetSashDragState = function (start, alt) {
            var sizes = _this.viewItems.map(function (i) { return i.size; });
            var minDelta = Number.NEGATIVE_INFINITY;
            var maxDelta = Number.POSITIVE_INFINITY;
            if (_this.inverseAltBehavior) {
                alt = !alt;
            }
            if (alt) {
                // When we're using the last sash with Alt, we're resizing
                // the view to the left/up, instead of right/down as usual
                // Thus, we must do the inverse of the usual
                var isLastSash = index === _this.sashItems.length - 1;
                if (isLastSash) {
                    var viewItem = _this.viewItems[index];
                    minDelta = (viewItem.minimumSize - viewItem.size) / 2;
                    maxDelta = (viewItem.maximumSize - viewItem.size) / 2;
                }
                else {
                    var viewItem = _this.viewItems[index + 1];
                    minDelta = (viewItem.size - viewItem.maximumSize) / 2;
                    maxDelta = (viewItem.size - viewItem.minimumSize) / 2;
                }
            }
            var snapBefore;
            var snapAfter;
            if (!alt) {
                var upIndexes = range(index, -1);
                var downIndexes = range(index + 1, _this.viewItems.length);
                var minDeltaUp = upIndexes.reduce(function (r, i) { return r + (_this.viewItems[i].minimumSize - sizes[i]); }, 0);
                var maxDeltaUp = upIndexes.reduce(function (r, i) { return r + (_this.viewItems[i].viewMaximumSize - sizes[i]); }, 0);
                var maxDeltaDown = downIndexes.length === 0 ? Number.POSITIVE_INFINITY : downIndexes.reduce(function (r, i) { return r + (sizes[i] - _this.viewItems[i].minimumSize); }, 0);
                var minDeltaDown = downIndexes.length === 0 ? Number.NEGATIVE_INFINITY : downIndexes.reduce(function (r, i) { return r + (sizes[i] - _this.viewItems[i].viewMaximumSize); }, 0);
                var minDelta_1 = Math.max(minDeltaUp, minDeltaDown);
                var maxDelta_1 = Math.min(maxDeltaDown, maxDeltaUp);
                var snapBeforeIndex = _this.findFirstSnapIndex(upIndexes);
                var snapAfterIndex = _this.findFirstSnapIndex(downIndexes);
                if (typeof snapBeforeIndex === 'number') {
                    var viewItem = _this.viewItems[snapBeforeIndex];
                    var halfSize = Math.floor(viewItem.viewMinimumSize / 2);
                    snapBefore = {
                        index: snapBeforeIndex,
                        limitDelta: viewItem.visible ? minDelta_1 - halfSize : minDelta_1 + halfSize,
                        size: viewItem.size
                    };
                }
                if (typeof snapAfterIndex === 'number') {
                    var viewItem = _this.viewItems[snapAfterIndex];
                    var halfSize = Math.floor(viewItem.viewMinimumSize / 2);
                    snapAfter = {
                        index: snapAfterIndex,
                        limitDelta: viewItem.visible ? maxDelta_1 + halfSize : maxDelta_1 - halfSize,
                        size: viewItem.size
                    };
                }
            }
            _this.sashDragState = { start: start, current: start, index: index, sizes: sizes, minDelta: minDelta, maxDelta: maxDelta, alt: alt, snapBefore: snapBefore, snapAfter: snapAfter, disposable: disposable };
        };
        resetSashDragState(start, alt);
    };
    SplitView.prototype.onSashChange = function (_a) {
        var current = _a.current;
        var _b = this.sashDragState, index = _b.index, start = _b.start, sizes = _b.sizes, alt = _b.alt, minDelta = _b.minDelta, maxDelta = _b.maxDelta, snapBefore = _b.snapBefore, snapAfter = _b.snapAfter;
        this.sashDragState.current = current;
        var delta = current - start;
        var newDelta = this.resize(index, delta, sizes, undefined, undefined, minDelta, maxDelta, snapBefore, snapAfter);
        if (alt) {
            var isLastSash = index === this.sashItems.length - 1;
            var newSizes = this.viewItems.map(function (i) { return i.size; });
            var viewItemIndex = isLastSash ? index : index + 1;
            var viewItem = this.viewItems[viewItemIndex];
            var newMinDelta = viewItem.size - viewItem.maximumSize;
            var newMaxDelta = viewItem.size - viewItem.minimumSize;
            var resizeIndex = isLastSash ? index - 1 : index + 1;
            this.resize(resizeIndex, -newDelta, newSizes, undefined, undefined, newMinDelta, newMaxDelta);
        }
        this.distributeEmptySpace();
        this.layoutViews();
    };
    SplitView.prototype.onSashEnd = function (index) {
        this._onDidSashChange.fire(index);
        this.sashDragState.disposable.dispose();
        this.saveProportions();
    };
    SplitView.prototype.onViewChange = function (item, size) {
        var index = this.viewItems.indexOf(item);
        if (index < 0 || index >= this.viewItems.length) {
            return;
        }
        size = typeof size === 'number' ? size : item.size;
        size = clamp(size, item.minimumSize, item.maximumSize);
        if (this.inverseAltBehavior && index > 0) {
            // In this case, we want the view to grow or shrink both sides equally
            // so we just resize the "left" side by half and let `resize` do the clamping magic
            this.resize(index - 1, Math.floor((item.size - size) / 2));
            this.distributeEmptySpace();
            this.layoutViews();
        }
        else {
            item.size = size;
            this.relayout([index], undefined);
        }
    };
    SplitView.prototype.resizeView = function (index, size) {
        var _this = this;
        if (this.state !== State.Idle) {
            throw new Error('Cant modify splitview');
        }
        this.state = State.Busy;
        if (index < 0 || index >= this.viewItems.length) {
            return;
        }
        var indexes = range(this.viewItems.length).filter(function (i) { return i !== index; });
        var lowPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 1 /* Low */; }).concat([index]);
        var highPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 2 /* High */; });
        var item = this.viewItems[index];
        size = Math.round(size);
        size = clamp(size, item.minimumSize, Math.min(item.maximumSize, this.size));
        item.size = size;
        this.relayout(lowPriorityIndexes, highPriorityIndexes);
        this.state = State.Idle;
    };
    SplitView.prototype.distributeViewSizes = function () {
        var _this = this;
        var flexibleViewItems = [];
        var flexibleSize = 0;
        for (var _i = 0, _a = this.viewItems; _i < _a.length; _i++) {
            var item = _a[_i];
            if (item.maximumSize - item.minimumSize > 0) {
                flexibleViewItems.push(item);
                flexibleSize += item.size;
            }
        }
        var size = Math.floor(flexibleSize / flexibleViewItems.length);
        for (var _b = 0, flexibleViewItems_1 = flexibleViewItems; _b < flexibleViewItems_1.length; _b++) {
            var item = flexibleViewItems_1[_b];
            item.size = clamp(size, item.minimumSize, item.maximumSize);
        }
        var indexes = range(this.viewItems.length);
        var lowPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 1 /* Low */; });
        var highPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 2 /* High */; });
        this.relayout(lowPriorityIndexes, highPriorityIndexes);
    };
    SplitView.prototype.getViewSize = function (index) {
        if (index < 0 || index >= this.viewItems.length) {
            return -1;
        }
        return this.viewItems[index].size;
    };
    SplitView.prototype.doAddView = function (view, size, index, skipLayout) {
        var _this = this;
        if (index === void 0) { index = this.viewItems.length; }
        if (this.state !== State.Idle) {
            throw new Error('Cant modify splitview');
        }
        this.state = State.Busy;
        // Add view
        var container = dom.$('.split-view-view');
        if (index === this.viewItems.length) {
            this.viewContainer.appendChild(container);
        }
        else {
            this.viewContainer.insertBefore(container, this.viewContainer.children.item(index));
        }
        var onChangeDisposable = view.onDidChange(function (size) { return _this.onViewChange(item, size); });
        var containerDisposable = toDisposable(function () { return _this.viewContainer.removeChild(container); });
        var disposable = combinedDisposable(onChangeDisposable, containerDisposable);
        var viewSize;
        if (typeof size === 'number') {
            viewSize = size;
        }
        else if (size.type === 'split') {
            viewSize = this.getViewSize(size.index) / 2;
        }
        else if (size.type === 'invisible') {
            viewSize = { cachedVisibleSize: size.cachedVisibleSize };
        }
        else {
            viewSize = view.minimumSize;
        }
        var item = this.orientation === 0 /* VERTICAL */
            ? new VerticalViewItem(container, view, viewSize, disposable)
            : new HorizontalViewItem(container, view, viewSize, disposable);
        this.viewItems.splice(index, 0, item);
        // Add sash
        if (this.viewItems.length > 1) {
            var orientation_1 = this.orientation === 0 /* VERTICAL */ ? 1 /* HORIZONTAL */ : 0 /* VERTICAL */;
            var layoutProvider = this.orientation === 0 /* VERTICAL */ ? { getHorizontalSashTop: function (sash) { return _this.getSashPosition(sash); } } : { getVerticalSashLeft: function (sash) { return _this.getSashPosition(sash); } };
            var sash_1 = new Sash(this.sashContainer, layoutProvider, {
                orientation: orientation_1,
                orthogonalStartSash: this.orthogonalStartSash,
                orthogonalEndSash: this.orthogonalEndSash
            });
            var sashEventMapper = this.orientation === 0 /* VERTICAL */
                ? function (e) { return ({ sash: sash_1, start: e.startY, current: e.currentY, alt: e.altKey }); }
                : function (e) { return ({ sash: sash_1, start: e.startX, current: e.currentX, alt: e.altKey }); };
            var onStart = Event.map(sash_1.onDidStart, sashEventMapper);
            var onStartDisposable = onStart(this.onSashStart, this);
            var onChange = Event.map(sash_1.onDidChange, sashEventMapper);
            var onChangeDisposable_1 = onChange(this.onSashChange, this);
            var onEnd = Event.map(sash_1.onDidEnd, function () { return firstIndex(_this.sashItems, function (item) { return item.sash === sash_1; }); });
            var onEndDisposable = onEnd(this.onSashEnd, this);
            var onDidResetDisposable = sash_1.onDidReset(function () {
                var index = firstIndex(_this.sashItems, function (item) { return item.sash === sash_1; });
                var upIndexes = range(index, -1);
                var downIndexes = range(index + 1, _this.viewItems.length);
                var snapBeforeIndex = _this.findFirstSnapIndex(upIndexes);
                var snapAfterIndex = _this.findFirstSnapIndex(downIndexes);
                if (typeof snapBeforeIndex === 'number' && !_this.viewItems[snapBeforeIndex].visible) {
                    return;
                }
                if (typeof snapAfterIndex === 'number' && !_this.viewItems[snapAfterIndex].visible) {
                    return;
                }
                _this._onDidSashReset.fire(index);
            });
            var disposable_1 = combinedDisposable(onStartDisposable, onChangeDisposable_1, onEndDisposable, onDidResetDisposable, sash_1);
            var sashItem = { sash: sash_1, disposable: disposable_1 };
            this.sashItems.splice(index - 1, 0, sashItem);
        }
        container.appendChild(view.element);
        var highPriorityIndexes;
        if (typeof size !== 'number' && size.type === 'split') {
            highPriorityIndexes = [size.index];
        }
        if (!skipLayout) {
            this.relayout([index], highPriorityIndexes);
        }
        this.state = State.Idle;
        if (!skipLayout && typeof size !== 'number' && size.type === 'distribute') {
            this.distributeViewSizes();
        }
    };
    SplitView.prototype.relayout = function (lowPriorityIndexes, highPriorityIndexes) {
        var contentSize = this.viewItems.reduce(function (r, i) { return r + i.size; }, 0);
        this.resize(this.viewItems.length - 1, this.size - contentSize, undefined, lowPriorityIndexes, highPriorityIndexes);
        this.distributeEmptySpace();
        this.layoutViews();
        this.saveProportions();
    };
    SplitView.prototype.resize = function (index, delta, sizes, lowPriorityIndexes, highPriorityIndexes, overloadMinDelta, overloadMaxDelta, snapBefore, snapAfter) {
        var _this = this;
        if (sizes === void 0) { sizes = this.viewItems.map(function (i) { return i.size; }); }
        if (overloadMinDelta === void 0) { overloadMinDelta = Number.NEGATIVE_INFINITY; }
        if (overloadMaxDelta === void 0) { overloadMaxDelta = Number.POSITIVE_INFINITY; }
        if (index < 0 || index >= this.viewItems.length) {
            return 0;
        }
        var upIndexes = range(index, -1);
        var downIndexes = range(index + 1, this.viewItems.length);
        if (highPriorityIndexes) {
            for (var _i = 0, highPriorityIndexes_1 = highPriorityIndexes; _i < highPriorityIndexes_1.length; _i++) {
                var index_1 = highPriorityIndexes_1[_i];
                pushToStart(upIndexes, index_1);
                pushToStart(downIndexes, index_1);
            }
        }
        if (lowPriorityIndexes) {
            for (var _a = 0, lowPriorityIndexes_1 = lowPriorityIndexes; _a < lowPriorityIndexes_1.length; _a++) {
                var index_2 = lowPriorityIndexes_1[_a];
                pushToEnd(upIndexes, index_2);
                pushToEnd(downIndexes, index_2);
            }
        }
        var upItems = upIndexes.map(function (i) { return _this.viewItems[i]; });
        var upSizes = upIndexes.map(function (i) { return sizes[i]; });
        var downItems = downIndexes.map(function (i) { return _this.viewItems[i]; });
        var downSizes = downIndexes.map(function (i) { return sizes[i]; });
        var minDeltaUp = upIndexes.reduce(function (r, i) { return r + (_this.viewItems[i].minimumSize - sizes[i]); }, 0);
        var maxDeltaUp = upIndexes.reduce(function (r, i) { return r + (_this.viewItems[i].maximumSize - sizes[i]); }, 0);
        var maxDeltaDown = downIndexes.length === 0 ? Number.POSITIVE_INFINITY : downIndexes.reduce(function (r, i) { return r + (sizes[i] - _this.viewItems[i].minimumSize); }, 0);
        var minDeltaDown = downIndexes.length === 0 ? Number.NEGATIVE_INFINITY : downIndexes.reduce(function (r, i) { return r + (sizes[i] - _this.viewItems[i].maximumSize); }, 0);
        var minDelta = Math.max(minDeltaUp, minDeltaDown, overloadMinDelta);
        var maxDelta = Math.min(maxDeltaDown, maxDeltaUp, overloadMaxDelta);
        var snapped = false;
        if (snapBefore) {
            var snapView = this.viewItems[snapBefore.index];
            var visible = delta >= snapBefore.limitDelta;
            snapped = visible !== snapView.visible;
            snapView.setVisible(visible, snapBefore.size);
        }
        if (!snapped && snapAfter) {
            var snapView = this.viewItems[snapAfter.index];
            var visible = delta < snapAfter.limitDelta;
            snapped = visible !== snapView.visible;
            snapView.setVisible(visible, snapAfter.size);
        }
        if (snapped) {
            return this.resize(index, delta, sizes, lowPriorityIndexes, highPriorityIndexes, overloadMinDelta, overloadMaxDelta);
        }
        delta = clamp(delta, minDelta, maxDelta);
        for (var i = 0, deltaUp = delta; i < upItems.length; i++) {
            var item = upItems[i];
            var size = clamp(upSizes[i] + deltaUp, item.minimumSize, item.maximumSize);
            var viewDelta = size - upSizes[i];
            deltaUp -= viewDelta;
            item.size = size;
        }
        for (var i = 0, deltaDown = delta; i < downItems.length; i++) {
            var item = downItems[i];
            var size = clamp(downSizes[i] - deltaDown, item.minimumSize, item.maximumSize);
            var viewDelta = size - downSizes[i];
            deltaDown += viewDelta;
            item.size = size;
        }
        return delta;
    };
    SplitView.prototype.distributeEmptySpace = function (lowPriorityIndex) {
        var _this = this;
        var contentSize = this.viewItems.reduce(function (r, i) { return r + i.size; }, 0);
        var emptyDelta = this.size - contentSize;
        var indexes = range(this.viewItems.length - 1, -1);
        var lowPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 1 /* Low */; });
        var highPriorityIndexes = indexes.filter(function (i) { return _this.viewItems[i].priority === 2 /* High */; });
        for (var _i = 0, highPriorityIndexes_2 = highPriorityIndexes; _i < highPriorityIndexes_2.length; _i++) {
            var index = highPriorityIndexes_2[_i];
            pushToStart(indexes, index);
        }
        for (var _a = 0, lowPriorityIndexes_2 = lowPriorityIndexes; _a < lowPriorityIndexes_2.length; _a++) {
            var index = lowPriorityIndexes_2[_a];
            pushToEnd(indexes, index);
        }
        if (typeof lowPriorityIndex === 'number') {
            pushToEnd(indexes, lowPriorityIndex);
        }
        for (var i = 0; emptyDelta !== 0 && i < indexes.length; i++) {
            var item = this.viewItems[indexes[i]];
            var size = clamp(item.size + emptyDelta, item.minimumSize, item.maximumSize);
            var viewDelta = size - item.size;
            emptyDelta -= viewDelta;
            item.size = size;
        }
    };
    SplitView.prototype.layoutViews = function () {
        var _this = this;
        // Save new content size
        this.contentSize = this.viewItems.reduce(function (r, i) { return r + i.size; }, 0);
        // Layout views
        this.viewItems.forEach(function (item) { return item.layout(_this.orthogonalSize); });
        // Layout sashes
        this.sashItems.forEach(function (item) { return item.sash.layout(); });
        // Update sashes enablement
        var previous = false;
        var collapsesDown = this.viewItems.map(function (i) { return previous = (i.size - i.minimumSize > 0) || previous; });
        previous = false;
        var expandsDown = this.viewItems.map(function (i) { return previous = (i.maximumSize - i.size > 0) || previous; });
        var reverseViews = this.viewItems.slice().reverse();
        previous = false;
        var collapsesUp = reverseViews.map(function (i) { return previous = (i.size - i.minimumSize > 0) || previous; }).reverse();
        previous = false;
        var expandsUp = reverseViews.map(function (i) { return previous = (i.maximumSize - i.size > 0) || previous; }).reverse();
        this.sashItems.forEach(function (_a, index) {
            var sash = _a.sash;
            var min = !(collapsesDown[index] && expandsUp[index + 1]);
            var max = !(expandsDown[index] && collapsesUp[index + 1]);
            if (min && max) {
                var upIndexes = range(index, -1);
                var downIndexes = range(index + 1, _this.viewItems.length);
                var snapBeforeIndex = _this.findFirstSnapIndex(upIndexes);
                var snapAfterIndex = _this.findFirstSnapIndex(downIndexes);
                var snappedBefore = typeof snapBeforeIndex === 'number' && !_this.viewItems[snapBeforeIndex].visible;
                var snappedAfter = typeof snapAfterIndex === 'number' && !_this.viewItems[snapAfterIndex].visible;
                if (snappedBefore && collapsesUp[index]) {
                    sash.state = 1 /* Minimum */;
                }
                else if (snappedAfter && collapsesDown[index]) {
                    sash.state = 2 /* Maximum */;
                }
                else {
                    sash.state = 0 /* Disabled */;
                }
            }
            else if (min && !max) {
                sash.state = 1 /* Minimum */;
            }
            else if (!min && max) {
                sash.state = 2 /* Maximum */;
            }
            else {
                sash.state = 3 /* Enabled */;
            }
            // }
        });
    };
    SplitView.prototype.getSashPosition = function (sash) {
        var position = 0;
        for (var i = 0; i < this.sashItems.length; i++) {
            position += this.viewItems[i].size;
            if (this.sashItems[i].sash === sash) {
                return position;
            }
        }
        return 0;
    };
    SplitView.prototype.findFirstSnapIndex = function (indexes) {
        // visible views first
        for (var _i = 0, indexes_1 = indexes; _i < indexes_1.length; _i++) {
            var index = indexes_1[_i];
            var viewItem = this.viewItems[index];
            if (!viewItem.visible) {
                continue;
            }
            if (viewItem.snap) {
                return index;
            }
        }
        // then, hidden views
        for (var _a = 0, indexes_2 = indexes; _a < indexes_2.length; _a++) {
            var index = indexes_2[_a];
            var viewItem = this.viewItems[index];
            if (viewItem.visible && viewItem.maximumSize - viewItem.minimumSize > 0) {
                return undefined;
            }
            if (!viewItem.visible && viewItem.snap) {
                return index;
            }
        }
        return undefined;
    };
    SplitView.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
        this.viewItems.forEach(function (i) { return i.dispose(); });
        this.viewItems = [];
        this.sashItems.forEach(function (i) { return i.disposable.dispose(); });
        this.sashItems = [];
    };
    return SplitView;
}(Disposable));
export { SplitView };
