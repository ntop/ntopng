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
import { illegalArgument } from '../../base/common/errors.js';
import { URI } from '../../base/common/uri.js';
import { ICodeEditorService } from './services/codeEditorService.js';
import { Position } from '../common/core/position.js';
import { IModelService } from '../common/services/modelService.js';
import { ITextModelService } from '../common/services/resolverService.js';
import { MenuRegistry } from '../../platform/actions/common/actions.js';
import { CommandsRegistry } from '../../platform/commands/common/commands.js';
import { ContextKeyExpr, IContextKeyService } from '../../platform/contextkey/common/contextkey.js';
import { KeybindingsRegistry } from '../../platform/keybinding/common/keybindingsRegistry.js';
import { Registry } from '../../platform/registry/common/platform.js';
import { ITelemetryService } from '../../platform/telemetry/common/telemetry.js';
import { withNullAsUndefined } from '../../base/common/types.js';
var Command = /** @class */ (function () {
    function Command(opts) {
        this.id = opts.id;
        this.precondition = opts.precondition;
        this._kbOpts = opts.kbOpts;
        this._menubarOpts = opts.menubarOpts;
        this._description = opts.description;
    }
    Command.prototype.register = function () {
        var _this = this;
        if (this._menubarOpts) {
            MenuRegistry.appendMenuItem(this._menubarOpts.menuId, {
                group: this._menubarOpts.group,
                command: {
                    id: this.id,
                    title: this._menubarOpts.title,
                },
                when: this._menubarOpts.when,
                order: this._menubarOpts.order
            });
        }
        if (this._kbOpts) {
            var kbWhen = this._kbOpts.kbExpr;
            if (this.precondition) {
                if (kbWhen) {
                    kbWhen = ContextKeyExpr.and(kbWhen, this.precondition);
                }
                else {
                    kbWhen = this.precondition;
                }
            }
            KeybindingsRegistry.registerCommandAndKeybindingRule({
                id: this.id,
                handler: function (accessor, args) { return _this.runCommand(accessor, args); },
                weight: this._kbOpts.weight,
                when: kbWhen,
                primary: this._kbOpts.primary,
                secondary: this._kbOpts.secondary,
                win: this._kbOpts.win,
                linux: this._kbOpts.linux,
                mac: this._kbOpts.mac,
                description: this._description
            });
        }
        else {
            CommandsRegistry.registerCommand({
                id: this.id,
                handler: function (accessor, args) { return _this.runCommand(accessor, args); },
                description: this._description
            });
        }
    };
    return Command;
}());
export { Command };
var EditorCommand = /** @class */ (function (_super) {
    __extends(EditorCommand, _super);
    function EditorCommand() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    /**
     * Create a command class that is bound to a certain editor contribution.
     */
    EditorCommand.bindToContribution = function (controllerGetter) {
        return /** @class */ (function (_super) {
            __extends(EditorControllerCommandImpl, _super);
            function EditorControllerCommandImpl(opts) {
                var _this = _super.call(this, opts) || this;
                _this._callback = opts.handler;
                return _this;
            }
            EditorControllerCommandImpl.prototype.runEditorCommand = function (accessor, editor, args) {
                var controller = controllerGetter(editor);
                if (controller) {
                    this._callback(controllerGetter(editor), args);
                }
            };
            return EditorControllerCommandImpl;
        }(EditorCommand));
    };
    EditorCommand.prototype.runCommand = function (accessor, args) {
        var _this = this;
        var codeEditorService = accessor.get(ICodeEditorService);
        // Find the editor with text focus or active
        var editor = codeEditorService.getFocusedCodeEditor() || codeEditorService.getActiveCodeEditor();
        if (!editor) {
            // well, at least we tried...
            return;
        }
        return editor.invokeWithinContext(function (editorAccessor) {
            var kbService = editorAccessor.get(IContextKeyService);
            if (!kbService.contextMatchesRules(withNullAsUndefined(_this.precondition))) {
                // precondition does not hold
                return;
            }
            return _this.runEditorCommand(editorAccessor, editor, args);
        });
    };
    return EditorCommand;
}(Command));
export { EditorCommand };
var EditorAction = /** @class */ (function (_super) {
    __extends(EditorAction, _super);
    function EditorAction(opts) {
        var _this = _super.call(this, opts) || this;
        _this.label = opts.label;
        _this.alias = opts.alias;
        _this.menuOpts = opts.menuOpts;
        return _this;
    }
    EditorAction.prototype.register = function () {
        if (this.menuOpts) {
            MenuRegistry.appendMenuItem(7 /* EditorContext */, {
                command: {
                    id: this.id,
                    title: this.label
                },
                when: ContextKeyExpr.and(this.precondition, this.menuOpts.when),
                group: this.menuOpts.group,
                order: this.menuOpts.order
            });
        }
        _super.prototype.register.call(this);
    };
    EditorAction.prototype.runEditorCommand = function (accessor, editor, args) {
        this.reportTelemetry(accessor, editor);
        return this.run(accessor, editor, args || {});
    };
    EditorAction.prototype.reportTelemetry = function (accessor, editor) {
        accessor.get(ITelemetryService).publicLog2('editorActionInvoked', { name: this.label, id: this.id });
    };
    return EditorAction;
}(EditorCommand));
export { EditorAction };
//#endregion EditorAction
// --- Registration of commands and actions
export function registerLanguageCommand(id, handler) {
    CommandsRegistry.registerCommand(id, function (accessor, args) { return handler(accessor, args || {}); });
}
export function registerDefaultLanguageCommand(id, handler) {
    registerLanguageCommand(id, function (accessor, args) {
        var resource = args.resource, position = args.position;
        if (!(resource instanceof URI)) {
            throw illegalArgument('resource');
        }
        if (!Position.isIPosition(position)) {
            throw illegalArgument('position');
        }
        var model = accessor.get(IModelService).getModel(resource);
        if (model) {
            var editorPosition = Position.lift(position);
            return handler(model, editorPosition, args);
        }
        return accessor.get(ITextModelService).createModelReference(resource).then(function (reference) {
            return new Promise(function (resolve, reject) {
                try {
                    var result = handler(reference.object.textEditorModel, Position.lift(position), args);
                    resolve(result);
                }
                catch (err) {
                    reject(err);
                }
            }).finally(function () {
                reference.dispose();
            });
        });
    });
}
export function registerEditorCommand(editorCommand) {
    EditorContributionRegistry.INSTANCE.registerEditorCommand(editorCommand);
    return editorCommand;
}
export function registerEditorAction(ctor) {
    EditorContributionRegistry.INSTANCE.registerEditorAction(new ctor());
}
export function registerInstantiatedEditorAction(editorAction) {
    EditorContributionRegistry.INSTANCE.registerEditorAction(editorAction);
}
export function registerEditorContribution(ctor) {
    EditorContributionRegistry.INSTANCE.registerEditorContribution(ctor);
}
export var EditorExtensionsRegistry;
(function (EditorExtensionsRegistry) {
    function getEditorCommand(commandId) {
        return EditorContributionRegistry.INSTANCE.getEditorCommand(commandId);
    }
    EditorExtensionsRegistry.getEditorCommand = getEditorCommand;
    function getEditorActions() {
        return EditorContributionRegistry.INSTANCE.getEditorActions();
    }
    EditorExtensionsRegistry.getEditorActions = getEditorActions;
    function getEditorContributions() {
        return EditorContributionRegistry.INSTANCE.getEditorContributions();
    }
    EditorExtensionsRegistry.getEditorContributions = getEditorContributions;
})(EditorExtensionsRegistry || (EditorExtensionsRegistry = {}));
// Editor extension points
var Extensions = {
    EditorCommonContributions: 'editor.contributions'
};
var EditorContributionRegistry = /** @class */ (function () {
    function EditorContributionRegistry() {
        this.editorContributions = [];
        this.editorActions = [];
        this.editorCommands = Object.create(null);
    }
    EditorContributionRegistry.prototype.registerEditorContribution = function (ctor) {
        this.editorContributions.push(ctor);
    };
    EditorContributionRegistry.prototype.registerEditorAction = function (action) {
        action.register();
        this.editorActions.push(action);
    };
    EditorContributionRegistry.prototype.getEditorContributions = function () {
        return this.editorContributions.slice(0);
    };
    EditorContributionRegistry.prototype.getEditorActions = function () {
        return this.editorActions.slice(0);
    };
    EditorContributionRegistry.prototype.registerEditorCommand = function (editorCommand) {
        editorCommand.register();
        this.editorCommands[editorCommand.id] = editorCommand;
    };
    EditorContributionRegistry.prototype.getEditorCommand = function (commandId) {
        return (this.editorCommands[commandId] || null);
    };
    EditorContributionRegistry.INSTANCE = new EditorContributionRegistry();
    return EditorContributionRegistry;
}());
Registry.add(Extensions.EditorCommonContributions, EditorContributionRegistry.INSTANCE);
