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
import { Action } from '../../../base/common/actions.js';
import { createDecorator } from '../../instantiation/common/instantiation.js';
import { IContextKeyService } from '../../contextkey/common/contextkey.js';
import { ICommandService } from '../../commands/common/commands.js';
import { Emitter } from '../../../base/common/event.js';
export function isIMenuItem(item) {
    return item.command !== undefined;
}
export var IMenuService = createDecorator('menuService');
export var MenuRegistry = new /** @class */ (function () {
    function class_1() {
        this._commands = new Map();
        this._menuItems = new Map();
        this._onDidChangeMenu = new Emitter();
        this.onDidChangeMenu = this._onDidChangeMenu.event;
    }
    class_1.prototype.addCommand = function (command) {
        var _this = this;
        this._commands.set(command.id, command);
        this._onDidChangeMenu.fire(0 /* CommandPalette */);
        return {
            dispose: function () {
                if (_this._commands.delete(command.id)) {
                    _this._onDidChangeMenu.fire(0 /* CommandPalette */);
                }
            }
        };
    };
    class_1.prototype.getCommand = function (id) {
        return this._commands.get(id);
    };
    class_1.prototype.getCommands = function () {
        var map = new Map();
        this._commands.forEach(function (value, key) { return map.set(key, value); });
        return map;
    };
    class_1.prototype.appendMenuItem = function (id, item) {
        var _this = this;
        var array = this._menuItems.get(id);
        if (!array) {
            array = [item];
            this._menuItems.set(id, array);
        }
        else {
            array.push(item);
        }
        this._onDidChangeMenu.fire(id);
        return {
            dispose: function () {
                var idx = array.indexOf(item);
                if (idx >= 0) {
                    array.splice(idx, 1);
                    _this._onDidChangeMenu.fire(id);
                }
            }
        };
    };
    class_1.prototype.getMenuItems = function (id) {
        var result = (this._menuItems.get(id) || []).slice(0);
        if (id === 0 /* CommandPalette */) {
            // CommandPalette is special because it shows
            // all commands by default
            this._appendImplicitItems(result);
        }
        return result;
    };
    class_1.prototype._appendImplicitItems = function (result) {
        var set = new Set();
        var temp = result.filter(function (item) { return isIMenuItem(item); });
        for (var _i = 0, temp_1 = temp; _i < temp_1.length; _i++) {
            var _a = temp_1[_i], command = _a.command, alt = _a.alt;
            set.add(command.id);
            if (alt) {
                set.add(alt.id);
            }
        }
        this._commands.forEach(function (command, id) {
            if (!set.has(id)) {
                result.push({ command: command });
            }
        });
    };
    return class_1;
}());
var ExecuteCommandAction = /** @class */ (function (_super) {
    __extends(ExecuteCommandAction, _super);
    function ExecuteCommandAction(id, label, _commandService) {
        var _this = _super.call(this, id, label) || this;
        _this._commandService = _commandService;
        return _this;
    }
    ExecuteCommandAction.prototype.run = function () {
        var _a;
        var args = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            args[_i] = arguments[_i];
        }
        return (_a = this._commandService).executeCommand.apply(_a, [this.id].concat(args));
    };
    ExecuteCommandAction = __decorate([
        __param(2, ICommandService)
    ], ExecuteCommandAction);
    return ExecuteCommandAction;
}(Action));
export { ExecuteCommandAction };
var SubmenuItemAction = /** @class */ (function (_super) {
    __extends(SubmenuItemAction, _super);
    function SubmenuItemAction(item) {
        var _this = this;
        typeof item.title === 'string' ? _this = _super.call(this, '', item.title, 'submenu') || this : _this = _super.call(this, '', item.title.value, 'submenu') || this;
        _this.item = item;
        return _this;
    }
    return SubmenuItemAction;
}(Action));
export { SubmenuItemAction };
var MenuItemAction = /** @class */ (function (_super) {
    __extends(MenuItemAction, _super);
    function MenuItemAction(item, alt, options, contextKeyService, commandService) {
        var _this = this;
        typeof item.title === 'string' ? _this = _super.call(this, item.id, item.title, commandService) || this : _this = _super.call(this, item.id, item.title.value, commandService) || this;
        _this._cssClass = undefined;
        _this._enabled = !item.precondition || contextKeyService.contextMatchesRules(item.precondition);
        _this._checked = Boolean(item.toggled && contextKeyService.contextMatchesRules(item.toggled));
        _this._options = options || {};
        _this.item = item;
        _this.alt = alt ? new MenuItemAction(alt, undefined, _this._options, contextKeyService, commandService) : undefined;
        return _this;
    }
    MenuItemAction.prototype.dispose = function () {
        if (this.alt) {
            this.alt.dispose();
        }
        _super.prototype.dispose.call(this);
    };
    MenuItemAction.prototype.run = function () {
        var args = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            args[_i] = arguments[_i];
        }
        var runArgs = [];
        if (this._options.arg) {
            runArgs = runArgs.concat([this._options.arg]);
        }
        if (this._options.shouldForwardArgs) {
            runArgs = runArgs.concat(args);
        }
        return _super.prototype.run.apply(this, runArgs);
    };
    MenuItemAction = __decorate([
        __param(3, IContextKeyService),
        __param(4, ICommandService)
    ], MenuItemAction);
    return MenuItemAction;
}(ExecuteCommandAction));
export { MenuItemAction };
