/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import './contextMenuHandler.css';
import { ActionRunner } from '../../../base/common/actions.js';
import { combinedDisposable, DisposableStore } from '../../../base/common/lifecycle.js';
import { Menu } from '../../../base/browser/ui/menu/menu.js';
import { EventType, $, removeNode } from '../../../base/browser/dom.js';
import { attachMenuStyler } from '../../theme/common/styler.js';
import { domEvent } from '../../../base/browser/event.js';
import { StandardMouseEvent } from '../../../base/browser/mouseEvent.js';
var ContextMenuHandler = /** @class */ (function () {
    function ContextMenuHandler(contextViewService, telemetryService, notificationService, keybindingService, themeService) {
        this.contextViewService = contextViewService;
        this.telemetryService = telemetryService;
        this.notificationService = notificationService;
        this.keybindingService = keybindingService;
        this.themeService = themeService;
        this.options = { blockMouse: true };
    }
    ContextMenuHandler.prototype.configure = function (options) {
        this.options = options;
    };
    ContextMenuHandler.prototype.showContextMenu = function (delegate) {
        var _this = this;
        var actions = delegate.getActions();
        if (!actions.length) {
            return; // Don't render an empty context menu
        }
        this.focusToReturn = document.activeElement;
        var menu;
        this.contextViewService.showContextView({
            getAnchor: function () { return delegate.getAnchor(); },
            canRelayout: false,
            anchorAlignment: delegate.anchorAlignment,
            render: function (container) {
                var className = delegate.getMenuClassName ? delegate.getMenuClassName() : '';
                if (className) {
                    container.className += ' ' + className;
                }
                // Render invisible div to block mouse interaction in the rest of the UI
                if (_this.options.blockMouse) {
                    _this.block = container.appendChild($('.context-view-block'));
                }
                var menuDisposables = new DisposableStore();
                var actionRunner = delegate.actionRunner || new ActionRunner();
                actionRunner.onDidBeforeRun(_this.onActionRun, _this, menuDisposables);
                actionRunner.onDidRun(_this.onDidActionRun, _this, menuDisposables);
                menu = new Menu(container, actions, {
                    actionViewItemProvider: delegate.getActionViewItem,
                    context: delegate.getActionsContext ? delegate.getActionsContext() : null,
                    actionRunner: actionRunner,
                    getKeyBinding: delegate.getKeyBinding ? delegate.getKeyBinding : function (action) { return _this.keybindingService.lookupKeybinding(action.id); }
                });
                menuDisposables.add(attachMenuStyler(menu, _this.themeService));
                menu.onDidCancel(function () { return _this.contextViewService.hideContextView(true); }, null, menuDisposables);
                menu.onDidBlur(function () { return _this.contextViewService.hideContextView(true); }, null, menuDisposables);
                domEvent(window, EventType.BLUR)(function () { _this.contextViewService.hideContextView(true); }, null, menuDisposables);
                domEvent(window, EventType.MOUSE_DOWN)(function (e) {
                    if (e.defaultPrevented) {
                        return;
                    }
                    var event = new StandardMouseEvent(e);
                    var element = event.target;
                    // Don't do anything as we are likely creating a context menu
                    if (event.rightButton) {
                        return;
                    }
                    while (element) {
                        if (element === container) {
                            return;
                        }
                        element = element.parentElement;
                    }
                    _this.contextViewService.hideContextView(true);
                }, null, menuDisposables);
                return combinedDisposable(menuDisposables, menu);
            },
            focus: function () {
                if (menu) {
                    menu.focus(!!delegate.autoSelectFirstItem);
                }
            },
            onHide: function (didCancel) {
                if (delegate.onHide) {
                    delegate.onHide(!!didCancel);
                }
                if (_this.block) {
                    removeNode(_this.block);
                    _this.block = null;
                }
                if (_this.focusToReturn) {
                    _this.focusToReturn.focus();
                }
            }
        });
    };
    ContextMenuHandler.prototype.onActionRun = function (e) {
        if (this.telemetryService) {
            this.telemetryService.publicLog2('workbenchActionExecuted', { id: e.action.id, from: 'contextMenu' });
        }
        this.contextViewService.hideContextView(false);
        // Restore focus here
        if (this.focusToReturn) {
            this.focusToReturn.focus();
        }
    };
    ContextMenuHandler.prototype.onDidActionRun = function (e) {
        if (e.error && this.notificationService) {
            this.notificationService.error(e.error);
        }
    };
    return ContextMenuHandler;
}());
export { ContextMenuHandler };
