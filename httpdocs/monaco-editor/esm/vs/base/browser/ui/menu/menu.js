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
import './menu.css';
import * as nls from '../../../../nls.js';
import * as strings from '../../../common/strings.js';
import { Action } from '../../../common/actions.js';
import { ActionBar, Separator, ActionViewItem, BaseActionViewItem } from '../actionbar/actionbar.js';
import { addClass, EventType, EventHelper, removeTabIndexAndUpdateFocus, isAncestor, hasClass, addDisposableListener, removeClass, append, $, addClasses, removeClasses } from '../../dom.js';
import { StandardKeyboardEvent } from '../../keyboardEvent.js';
import { RunOnceScheduler } from '../../../common/async.js';
import { DisposableStore } from '../../../common/lifecycle.js';
import { DomScrollableElement } from '../scrollbar/scrollableElement.js';
import { Emitter } from '../../../common/event.js';
import { isLinux, isMacintosh } from '../../../common/platform.js';
export var MENU_MNEMONIC_REGEX = /\(&([^\s&])\)|(^|[^&])&([^\s&])/;
export var MENU_ESCAPED_MNEMONIC_REGEX = /(&amp;)?(&amp;)([^\s&])/g;
var SubmenuAction = /** @class */ (function (_super) {
    __extends(SubmenuAction, _super);
    function SubmenuAction(label, entries, cssClass) {
        var _this = _super.call(this, !!cssClass ? cssClass : 'submenu', label, '', true) || this;
        _this.entries = entries;
        return _this;
    }
    return SubmenuAction;
}(Action));
export { SubmenuAction };
var Menu = /** @class */ (function (_super) {
    __extends(Menu, _super);
    function Menu(container, actions, options) {
        if (options === void 0) { options = {}; }
        var _this = this;
        addClass(container, 'monaco-menu-container');
        container.setAttribute('role', 'presentation');
        var menuElement = document.createElement('div');
        addClass(menuElement, 'monaco-menu');
        menuElement.setAttribute('role', 'presentation');
        _this = _super.call(this, menuElement, {
            orientation: 2 /* VERTICAL */,
            actionViewItemProvider: function (action) { return _this.doGetActionViewItem(action, options, parentData); },
            context: options.context,
            actionRunner: options.actionRunner,
            ariaLabel: options.ariaLabel,
            triggerKeys: { keys: [3 /* Enter */].concat((isMacintosh ? [10 /* Space */] : [])), keyDown: true }
        }) || this;
        _this.menuElement = menuElement;
        _this._onScroll = _this._register(new Emitter());
        _this.actionsList.setAttribute('role', 'menu');
        _this.actionsList.tabIndex = 0;
        _this.menuDisposables = _this._register(new DisposableStore());
        addDisposableListener(menuElement, EventType.KEY_DOWN, function (e) {
            var event = new StandardKeyboardEvent(e);
            // Stop tab navigation of menus
            if (event.equals(2 /* Tab */)) {
                e.preventDefault();
            }
        });
        if (options.enableMnemonics) {
            _this.menuDisposables.add(addDisposableListener(menuElement, EventType.KEY_DOWN, function (e) {
                var key = e.key.toLocaleLowerCase();
                if (_this.mnemonics.has(key)) {
                    EventHelper.stop(e, true);
                    var actions_1 = _this.mnemonics.get(key);
                    if (actions_1.length === 1) {
                        if (actions_1[0] instanceof SubmenuMenuActionViewItem) {
                            _this.focusItemByElement(actions_1[0].container);
                        }
                        actions_1[0].onClick(e);
                    }
                    if (actions_1.length > 1) {
                        var action = actions_1.shift();
                        if (action) {
                            _this.focusItemByElement(action.container);
                            actions_1.push(action);
                        }
                        _this.mnemonics.set(key, actions_1);
                    }
                }
            }));
        }
        if (isLinux) {
            _this._register(addDisposableListener(menuElement, EventType.KEY_DOWN, function (e) {
                var event = new StandardKeyboardEvent(e);
                if (event.equals(14 /* Home */) || event.equals(11 /* PageUp */)) {
                    _this.focusedItem = _this.viewItems.length - 1;
                    _this.focusNext();
                    EventHelper.stop(e, true);
                }
                else if (event.equals(13 /* End */) || event.equals(12 /* PageDown */)) {
                    _this.focusedItem = 0;
                    _this.focusPrevious();
                    EventHelper.stop(e, true);
                }
            }));
        }
        _this._register(addDisposableListener(_this.domNode, EventType.MOUSE_OUT, function (e) {
            var relatedTarget = e.relatedTarget;
            if (!isAncestor(relatedTarget, _this.domNode)) {
                _this.focusedItem = undefined;
                _this.scrollTopHold = _this.menuElement.scrollTop;
                _this.updateFocus();
                e.stopPropagation();
            }
        }));
        _this._register(addDisposableListener(_this.domNode, EventType.MOUSE_UP, function (e) {
            // Absorb clicks in menu dead space https://github.com/Microsoft/vscode/issues/63575
            EventHelper.stop(e, true);
        }));
        _this._register(addDisposableListener(_this.actionsList, EventType.MOUSE_OVER, function (e) {
            var target = e.target;
            if (!target || !isAncestor(target, _this.actionsList) || target === _this.actionsList) {
                return;
            }
            while (target.parentElement !== _this.actionsList && target.parentElement !== null) {
                target = target.parentElement;
            }
            if (hasClass(target, 'action-item')) {
                var lastFocusedItem = _this.focusedItem;
                _this.scrollTopHold = _this.menuElement.scrollTop;
                _this.setFocusedItem(target);
                if (lastFocusedItem !== _this.focusedItem) {
                    _this.updateFocus();
                }
            }
        }));
        var parentData = {
            parent: _this
        };
        _this.mnemonics = new Map();
        _this.push(actions, { icon: true, label: true, isMenu: true });
        // Scroll Logic
        _this.scrollableElement = _this._register(new DomScrollableElement(menuElement, {
            alwaysConsumeMouseWheel: true,
            horizontal: 2 /* Hidden */,
            vertical: 3 /* Visible */,
            verticalScrollbarSize: 7,
            handleMouseWheel: true,
            useShadows: true
        }));
        var scrollElement = _this.scrollableElement.getDomNode();
        scrollElement.style.position = null;
        menuElement.style.maxHeight = Math.max(10, window.innerHeight - container.getBoundingClientRect().top - 30) + "px";
        _this.menuDisposables.add(_this.scrollableElement.onScroll(function () {
            _this._onScroll.fire();
        }, _this));
        _this._register(addDisposableListener(_this.menuElement, EventType.SCROLL, function (e) {
            if (_this.scrollTopHold !== undefined) {
                _this.menuElement.scrollTop = _this.scrollTopHold;
                _this.scrollTopHold = undefined;
            }
            _this.scrollableElement.scanDomNode();
        }));
        container.appendChild(_this.scrollableElement.getDomNode());
        _this.scrollableElement.scanDomNode();
        _this.viewItems.filter(function (item) { return !(item instanceof MenuSeparatorActionViewItem); }).forEach(function (item, index, array) {
            item.updatePositionInSet(index + 1, array.length);
        });
        return _this;
    }
    Menu.prototype.style = function (style) {
        var container = this.getContainer();
        var fgColor = style.foregroundColor ? "" + style.foregroundColor : null;
        var bgColor = style.backgroundColor ? "" + style.backgroundColor : null;
        var border = style.borderColor ? "2px solid " + style.borderColor : null;
        var shadow = style.shadowColor ? "0 2px 4px " + style.shadowColor : null;
        container.style.border = border;
        this.domNode.style.color = fgColor;
        this.domNode.style.backgroundColor = bgColor;
        container.style.boxShadow = shadow;
        if (this.viewItems) {
            this.viewItems.forEach(function (item) {
                if (item instanceof BaseMenuActionViewItem || item instanceof MenuSeparatorActionViewItem) {
                    item.style(style);
                }
            });
        }
    };
    Menu.prototype.getContainer = function () {
        return this.scrollableElement.getDomNode();
    };
    Object.defineProperty(Menu.prototype, "onScroll", {
        get: function () {
            return this._onScroll.event;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Menu.prototype, "scrollOffset", {
        get: function () {
            return this.menuElement.scrollTop;
        },
        enumerable: true,
        configurable: true
    });
    Menu.prototype.focusItemByElement = function (element) {
        var lastFocusedItem = this.focusedItem;
        this.setFocusedItem(element);
        if (lastFocusedItem !== this.focusedItem) {
            this.updateFocus();
        }
    };
    Menu.prototype.setFocusedItem = function (element) {
        for (var i = 0; i < this.actionsList.children.length; i++) {
            var elem = this.actionsList.children[i];
            if (element === elem) {
                this.focusedItem = i;
                break;
            }
        }
    };
    Menu.prototype.doGetActionViewItem = function (action, options, parentData) {
        if (action instanceof Separator) {
            return new MenuSeparatorActionViewItem(options.context, action, { icon: true });
        }
        else if (action instanceof SubmenuAction) {
            var menuActionViewItem = new SubmenuMenuActionViewItem(action, action.entries, parentData, options);
            if (options.enableMnemonics) {
                var mnemonic = menuActionViewItem.getMnemonic();
                if (mnemonic && menuActionViewItem.isEnabled()) {
                    var actionViewItems = [];
                    if (this.mnemonics.has(mnemonic)) {
                        actionViewItems = this.mnemonics.get(mnemonic);
                    }
                    actionViewItems.push(menuActionViewItem);
                    this.mnemonics.set(mnemonic, actionViewItems);
                }
            }
            return menuActionViewItem;
        }
        else {
            var menuItemOptions = { enableMnemonics: options.enableMnemonics };
            if (options.getKeyBinding) {
                var keybinding = options.getKeyBinding(action);
                if (keybinding) {
                    var keybindingLabel = keybinding.getLabel();
                    if (keybindingLabel) {
                        menuItemOptions.keybinding = keybindingLabel;
                    }
                }
            }
            var menuActionViewItem = new BaseMenuActionViewItem(options.context, action, menuItemOptions);
            if (options.enableMnemonics) {
                var mnemonic = menuActionViewItem.getMnemonic();
                if (mnemonic && menuActionViewItem.isEnabled()) {
                    var actionViewItems = [];
                    if (this.mnemonics.has(mnemonic)) {
                        actionViewItems = this.mnemonics.get(mnemonic);
                    }
                    actionViewItems.push(menuActionViewItem);
                    this.mnemonics.set(mnemonic, actionViewItems);
                }
            }
            return menuActionViewItem;
        }
    };
    return Menu;
}(ActionBar));
export { Menu };
var BaseMenuActionViewItem = /** @class */ (function (_super) {
    __extends(BaseMenuActionViewItem, _super);
    function BaseMenuActionViewItem(ctx, action, options) {
        if (options === void 0) { options = {}; }
        var _this = this;
        options.isMenu = true;
        _this = _super.call(this, action, action, options) || this;
        _this.options = options;
        _this.options.icon = options.icon !== undefined ? options.icon : false;
        _this.options.label = options.label !== undefined ? options.label : true;
        _this.cssClass = '';
        // Set mnemonic
        if (_this.options.label && options.enableMnemonics) {
            var label = _this.getAction().label;
            if (label) {
                var matches = MENU_MNEMONIC_REGEX.exec(label);
                if (matches) {
                    _this.mnemonic = (!!matches[1] ? matches[1] : matches[3]).toLocaleLowerCase();
                }
            }
        }
        // Add mouse up listener later to avoid accidental clicks
        _this.runOnceToEnableMouseUp = new RunOnceScheduler(function () {
            if (!_this.element) {
                return;
            }
            _this._register(addDisposableListener(_this.element, EventType.MOUSE_UP, function (e) {
                EventHelper.stop(e, true);
                _this.onClick(e);
            }));
        }, 50);
        _this._register(_this.runOnceToEnableMouseUp);
        return _this;
    }
    BaseMenuActionViewItem.prototype.render = function (container) {
        _super.prototype.render.call(this, container);
        if (!this.element) {
            return;
        }
        this.container = container;
        this.item = append(this.element, $('a.action-menu-item'));
        if (this._action.id === Separator.ID) {
            // A separator is a presentation item
            this.item.setAttribute('role', 'presentation');
        }
        else {
            this.item.setAttribute('role', 'menuitem');
            if (this.mnemonic) {
                this.item.setAttribute('aria-keyshortcuts', "" + this.mnemonic);
            }
        }
        this.check = append(this.item, $('span.menu-item-check'));
        this.check.setAttribute('role', 'none');
        this.label = append(this.item, $('span.action-label'));
        if (this.options.label && this.options.keybinding) {
            append(this.item, $('span.keybinding')).textContent = this.options.keybinding;
        }
        // Adds mouse up listener to actually run the action
        this.runOnceToEnableMouseUp.schedule();
        this.updateClass();
        this.updateLabel();
        this.updateTooltip();
        this.updateEnabled();
        this.updateChecked();
    };
    BaseMenuActionViewItem.prototype.blur = function () {
        _super.prototype.blur.call(this);
        this.applyStyle();
    };
    BaseMenuActionViewItem.prototype.focus = function () {
        _super.prototype.focus.call(this);
        this.item.focus();
        this.applyStyle();
    };
    BaseMenuActionViewItem.prototype.updatePositionInSet = function (pos, setSize) {
        this.item.setAttribute('aria-posinset', "" + pos);
        this.item.setAttribute('aria-setsize', "" + setSize);
    };
    BaseMenuActionViewItem.prototype.updateLabel = function () {
        if (this.options.label) {
            var label = this.getAction().label;
            if (label) {
                var cleanLabel = cleanMnemonic(label);
                if (!this.options.enableMnemonics) {
                    label = cleanLabel;
                }
                this.label.setAttribute('aria-label', cleanLabel.replace(/&&/g, '&'));
                var matches = MENU_MNEMONIC_REGEX.exec(label);
                if (matches) {
                    label = strings.escape(label);
                    // This is global, reset it
                    MENU_ESCAPED_MNEMONIC_REGEX.lastIndex = 0;
                    var escMatch = MENU_ESCAPED_MNEMONIC_REGEX.exec(label);
                    // We can't use negative lookbehind so if we match our negative and skip
                    while (escMatch && escMatch[1]) {
                        escMatch = MENU_ESCAPED_MNEMONIC_REGEX.exec(label);
                    }
                    if (escMatch) {
                        label = label.substr(0, escMatch.index) + "<u aria-hidden=\"true\">" + escMatch[3] + "</u>" + label.substr(escMatch.index + escMatch[0].length);
                    }
                    label = label.replace(/&amp;&amp;/g, '&amp;');
                    this.item.setAttribute('aria-keyshortcuts', (!!matches[1] ? matches[1] : matches[3]).toLocaleLowerCase());
                }
                else {
                    label = label.replace(/&&/g, '&');
                }
            }
            this.label.innerHTML = label.trim();
        }
    };
    BaseMenuActionViewItem.prototype.updateTooltip = function () {
        var title = null;
        if (this.getAction().tooltip) {
            title = this.getAction().tooltip;
        }
        else if (!this.options.label && this.getAction().label && this.options.icon) {
            title = this.getAction().label;
            if (this.options.keybinding) {
                title = nls.localize({ key: 'titleLabel', comment: ['action title', 'action keybinding'] }, "{0} ({1})", title, this.options.keybinding);
            }
        }
        if (title) {
            this.item.title = title;
        }
    };
    BaseMenuActionViewItem.prototype.updateClass = function () {
        if (this.cssClass) {
            removeClasses(this.item, this.cssClass);
        }
        if (this.options.icon) {
            this.cssClass = this.getAction().class || '';
            addClass(this.label, 'icon');
            if (this.cssClass) {
                addClasses(this.label, this.cssClass);
            }
            this.updateEnabled();
        }
        else {
            removeClass(this.label, 'icon');
        }
    };
    BaseMenuActionViewItem.prototype.updateEnabled = function () {
        if (this.getAction().enabled) {
            if (this.element) {
                removeClass(this.element, 'disabled');
            }
            removeClass(this.item, 'disabled');
            this.item.tabIndex = 0;
        }
        else {
            if (this.element) {
                addClass(this.element, 'disabled');
            }
            addClass(this.item, 'disabled');
            removeTabIndexAndUpdateFocus(this.item);
        }
    };
    BaseMenuActionViewItem.prototype.updateChecked = function () {
        if (this.getAction().checked) {
            addClass(this.item, 'checked');
            this.item.setAttribute('role', 'menuitemcheckbox');
            this.item.setAttribute('aria-checked', 'true');
        }
        else {
            removeClass(this.item, 'checked');
            this.item.setAttribute('role', 'menuitem');
            this.item.setAttribute('aria-checked', 'false');
        }
    };
    BaseMenuActionViewItem.prototype.getMnemonic = function () {
        return this.mnemonic;
    };
    BaseMenuActionViewItem.prototype.applyStyle = function () {
        if (!this.menuStyle) {
            return;
        }
        var isSelected = this.element && hasClass(this.element, 'focused');
        var fgColor = isSelected && this.menuStyle.selectionForegroundColor ? this.menuStyle.selectionForegroundColor : this.menuStyle.foregroundColor;
        var bgColor = isSelected && this.menuStyle.selectionBackgroundColor ? this.menuStyle.selectionBackgroundColor : this.menuStyle.backgroundColor;
        var border = isSelected && this.menuStyle.selectionBorderColor ? "thin solid " + this.menuStyle.selectionBorderColor : null;
        this.item.style.color = fgColor ? "" + fgColor : null;
        this.check.style.backgroundColor = fgColor ? "" + fgColor : null;
        this.item.style.backgroundColor = bgColor ? "" + bgColor : null;
        this.container.style.border = border;
    };
    BaseMenuActionViewItem.prototype.style = function (style) {
        this.menuStyle = style;
        this.applyStyle();
    };
    return BaseMenuActionViewItem;
}(BaseActionViewItem));
var SubmenuMenuActionViewItem = /** @class */ (function (_super) {
    __extends(SubmenuMenuActionViewItem, _super);
    function SubmenuMenuActionViewItem(action, submenuActions, parentData, submenuOptions) {
        var _this = _super.call(this, action, action, submenuOptions) || this;
        _this.submenuActions = submenuActions;
        _this.parentData = parentData;
        _this.submenuOptions = submenuOptions;
        _this.submenuDisposables = _this._register(new DisposableStore());
        _this.showScheduler = new RunOnceScheduler(function () {
            if (_this.mouseOver) {
                _this.cleanupExistingSubmenu(false);
                _this.createSubmenu(false);
            }
        }, 250);
        _this.hideScheduler = new RunOnceScheduler(function () {
            if (_this.element && (!isAncestor(document.activeElement, _this.element) && _this.parentData.submenu === _this.mysubmenu)) {
                _this.parentData.parent.focus(false);
                _this.cleanupExistingSubmenu(true);
            }
        }, 750);
        return _this;
    }
    SubmenuMenuActionViewItem.prototype.render = function (container) {
        var _this = this;
        _super.prototype.render.call(this, container);
        if (!this.element) {
            return;
        }
        addClass(this.item, 'monaco-submenu-item');
        this.item.setAttribute('aria-haspopup', 'true');
        this.submenuIndicator = append(this.item, $('span.submenu-indicator'));
        this.submenuIndicator.setAttribute('aria-hidden', 'true');
        this._register(addDisposableListener(this.element, EventType.KEY_UP, function (e) {
            var event = new StandardKeyboardEvent(e);
            if (event.equals(17 /* RightArrow */) || event.equals(3 /* Enter */)) {
                EventHelper.stop(e, true);
                _this.createSubmenu(true);
            }
        }));
        this._register(addDisposableListener(this.element, EventType.KEY_DOWN, function (e) {
            var event = new StandardKeyboardEvent(e);
            if (document.activeElement === _this.item) {
                if (event.equals(17 /* RightArrow */) || event.equals(3 /* Enter */)) {
                    EventHelper.stop(e, true);
                }
            }
        }));
        this._register(addDisposableListener(this.element, EventType.MOUSE_OVER, function (e) {
            if (!_this.mouseOver) {
                _this.mouseOver = true;
                _this.showScheduler.schedule();
            }
        }));
        this._register(addDisposableListener(this.element, EventType.MOUSE_LEAVE, function (e) {
            _this.mouseOver = false;
        }));
        this._register(addDisposableListener(this.element, EventType.FOCUS_OUT, function (e) {
            if (_this.element && !isAncestor(document.activeElement, _this.element)) {
                _this.hideScheduler.schedule();
            }
        }));
        this._register(this.parentData.parent.onScroll(function () {
            _this.parentData.parent.focus(false);
            _this.cleanupExistingSubmenu(false);
        }));
    };
    SubmenuMenuActionViewItem.prototype.onClick = function (e) {
        // stop clicking from trying to run an action
        EventHelper.stop(e, true);
        this.cleanupExistingSubmenu(false);
        this.createSubmenu(false);
    };
    SubmenuMenuActionViewItem.prototype.cleanupExistingSubmenu = function (force) {
        if (this.parentData.submenu && (force || (this.parentData.submenu !== this.mysubmenu))) {
            this.parentData.submenu.dispose();
            this.parentData.submenu = undefined;
            if (this.submenuContainer) {
                this.submenuDisposables.clear();
                this.submenuContainer = undefined;
            }
        }
    };
    SubmenuMenuActionViewItem.prototype.createSubmenu = function (selectFirstItem) {
        var _this = this;
        if (selectFirstItem === void 0) { selectFirstItem = true; }
        if (!this.element) {
            return;
        }
        if (!this.parentData.submenu) {
            this.submenuContainer = append(this.element, $('div.monaco-submenu'));
            addClasses(this.submenuContainer, 'menubar-menu-items-holder', 'context-view');
            this.parentData.submenu = new Menu(this.submenuContainer, this.submenuActions, this.submenuOptions);
            if (this.menuStyle) {
                this.parentData.submenu.style(this.menuStyle);
            }
            var boundingRect = this.element.getBoundingClientRect();
            var childBoundingRect = this.submenuContainer.getBoundingClientRect();
            var computedStyles = getComputedStyle(this.parentData.parent.domNode);
            var paddingTop = parseFloat(computedStyles.paddingTop || '0') || 0;
            if (window.innerWidth <= boundingRect.right + childBoundingRect.width) {
                this.submenuContainer.style.left = '10px';
                this.submenuContainer.style.top = this.element.offsetTop - this.parentData.parent.scrollOffset + boundingRect.height + "px";
            }
            else {
                this.submenuContainer.style.left = this.element.offsetWidth + "px";
                this.submenuContainer.style.top = this.element.offsetTop - this.parentData.parent.scrollOffset - paddingTop + "px";
            }
            this.submenuDisposables.add(addDisposableListener(this.submenuContainer, EventType.KEY_UP, function (e) {
                var event = new StandardKeyboardEvent(e);
                if (event.equals(15 /* LeftArrow */)) {
                    EventHelper.stop(e, true);
                    _this.parentData.parent.focus();
                    if (_this.parentData.submenu) {
                        _this.parentData.submenu.dispose();
                        _this.parentData.submenu = undefined;
                    }
                    _this.submenuDisposables.clear();
                    _this.submenuContainer = undefined;
                }
            }));
            this.submenuDisposables.add(addDisposableListener(this.submenuContainer, EventType.KEY_DOWN, function (e) {
                var event = new StandardKeyboardEvent(e);
                if (event.equals(15 /* LeftArrow */)) {
                    EventHelper.stop(e, true);
                }
            }));
            this.submenuDisposables.add(this.parentData.submenu.onDidCancel(function () {
                _this.parentData.parent.focus();
                if (_this.parentData.submenu) {
                    _this.parentData.submenu.dispose();
                    _this.parentData.submenu = undefined;
                }
                _this.submenuDisposables.clear();
                _this.submenuContainer = undefined;
            }));
            this.parentData.submenu.focus(selectFirstItem);
            this.mysubmenu = this.parentData.submenu;
        }
        else {
            this.parentData.submenu.focus(false);
        }
    };
    SubmenuMenuActionViewItem.prototype.applyStyle = function () {
        _super.prototype.applyStyle.call(this);
        if (!this.menuStyle) {
            return;
        }
        var isSelected = this.element && hasClass(this.element, 'focused');
        var fgColor = isSelected && this.menuStyle.selectionForegroundColor ? this.menuStyle.selectionForegroundColor : this.menuStyle.foregroundColor;
        this.submenuIndicator.style.backgroundColor = fgColor ? "" + fgColor : null;
        if (this.parentData.submenu) {
            this.parentData.submenu.style(this.menuStyle);
        }
    };
    SubmenuMenuActionViewItem.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
        this.hideScheduler.dispose();
        if (this.mysubmenu) {
            this.mysubmenu.dispose();
            this.mysubmenu = null;
        }
        if (this.submenuContainer) {
            this.submenuContainer = undefined;
        }
    };
    return SubmenuMenuActionViewItem;
}(BaseMenuActionViewItem));
var MenuSeparatorActionViewItem = /** @class */ (function (_super) {
    __extends(MenuSeparatorActionViewItem, _super);
    function MenuSeparatorActionViewItem() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    MenuSeparatorActionViewItem.prototype.style = function (style) {
        this.label.style.borderBottomColor = style.separatorColor ? "" + style.separatorColor : null;
    };
    return MenuSeparatorActionViewItem;
}(ActionViewItem));
export function cleanMnemonic(label) {
    var regex = MENU_MNEMONIC_REGEX;
    var matches = regex.exec(label);
    if (!matches) {
        return label;
    }
    var mnemonicInText = !matches[1];
    return label.replace(regex, mnemonicInText ? '$2$3' : '').trim();
}
