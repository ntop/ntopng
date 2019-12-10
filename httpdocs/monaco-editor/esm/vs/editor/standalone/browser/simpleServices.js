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
import * as strings from '../../../base/common/strings.js';
import * as dom from '../../../base/browser/dom.js';
import { StandardKeyboardEvent } from '../../../base/browser/keyboardEvent.js';
import { Emitter, Event } from '../../../base/common/event.js';
import { SimpleKeybinding, createKeybinding } from '../../../base/common/keyCodes.js';
import { ImmortalReference, toDisposable, DisposableStore, Disposable } from '../../../base/common/lifecycle.js';
import { OS, isLinux, isMacintosh } from '../../../base/common/platform.js';
import Severity from '../../../base/common/severity.js';
import { URI } from '../../../base/common/uri.js';
import { isCodeEditor } from '../../browser/editorBrowser.js';
import { isDiffEditorConfigurationKey, isEditorConfigurationKey } from '../../common/config/commonEditorConfig.js';
import { EditOperation } from '../../common/core/editOperation.js';
import { Position as Pos } from '../../common/core/position.js';
import { Range } from '../../common/core/range.js';
import { isResourceTextEdit } from '../../common/modes.js';
import { CommandsRegistry } from '../../../platform/commands/common/commands.js';
import { IConfigurationService } from '../../../platform/configuration/common/configuration.js';
import { Configuration, ConfigurationModel, DefaultConfigurationModel } from '../../../platform/configuration/common/configurationModels.js';
import { AbstractKeybindingService } from '../../../platform/keybinding/common/abstractKeybindingService.js';
import { KeybindingResolver } from '../../../platform/keybinding/common/keybindingResolver.js';
import { KeybindingsRegistry } from '../../../platform/keybinding/common/keybindingsRegistry.js';
import { ResolvedKeybindingItem } from '../../../platform/keybinding/common/resolvedKeybindingItem.js';
import { USLayoutResolvedKeybinding } from '../../../platform/keybinding/common/usLayoutResolvedKeybinding.js';
import { NoOpNotification } from '../../../platform/notification/common/notification.js';
import { WorkspaceFolder } from '../../../platform/workspace/common/workspace.js';
import { SimpleServicesNLS } from '../../common/standaloneStrings.js';
var SimpleModel = /** @class */ (function () {
    function SimpleModel(model) {
        this.model = model;
        this._onDispose = new Emitter();
    }
    Object.defineProperty(SimpleModel.prototype, "textEditorModel", {
        get: function () {
            return this.model;
        },
        enumerable: true,
        configurable: true
    });
    SimpleModel.prototype.dispose = function () {
        this._onDispose.fire();
    };
    return SimpleModel;
}());
export { SimpleModel };
function withTypedEditor(widget, codeEditorCallback, diffEditorCallback) {
    if (isCodeEditor(widget)) {
        // Single Editor
        return codeEditorCallback(widget);
    }
    else {
        // Diff Editor
        return diffEditorCallback(widget);
    }
}
var SimpleEditorModelResolverService = /** @class */ (function () {
    function SimpleEditorModelResolverService() {
    }
    SimpleEditorModelResolverService.prototype.setEditor = function (editor) {
        this.editor = editor;
    };
    SimpleEditorModelResolverService.prototype.createModelReference = function (resource) {
        var _this = this;
        var model = null;
        if (this.editor) {
            model = withTypedEditor(this.editor, function (editor) { return _this.findModel(editor, resource); }, function (diffEditor) { return _this.findModel(diffEditor.getOriginalEditor(), resource) || _this.findModel(diffEditor.getModifiedEditor(), resource); });
        }
        if (!model) {
            return Promise.reject(new Error("Model not found"));
        }
        return Promise.resolve(new ImmortalReference(new SimpleModel(model)));
    };
    SimpleEditorModelResolverService.prototype.findModel = function (editor, resource) {
        var model = editor.getModel();
        if (model && model.uri.toString() !== resource.toString()) {
            return null;
        }
        return model;
    };
    return SimpleEditorModelResolverService;
}());
export { SimpleEditorModelResolverService };
var SimpleEditorProgressService = /** @class */ (function () {
    function SimpleEditorProgressService() {
    }
    SimpleEditorProgressService.prototype.showWhile = function (promise, delay) {
        return Promise.resolve(undefined);
    };
    return SimpleEditorProgressService;
}());
export { SimpleEditorProgressService };
var SimpleDialogService = /** @class */ (function () {
    function SimpleDialogService() {
    }
    return SimpleDialogService;
}());
export { SimpleDialogService };
var SimpleNotificationService = /** @class */ (function () {
    function SimpleNotificationService() {
    }
    SimpleNotificationService.prototype.info = function (message) {
        return this.notify({ severity: Severity.Info, message: message });
    };
    SimpleNotificationService.prototype.warn = function (message) {
        return this.notify({ severity: Severity.Warning, message: message });
    };
    SimpleNotificationService.prototype.error = function (error) {
        return this.notify({ severity: Severity.Error, message: error });
    };
    SimpleNotificationService.prototype.notify = function (notification) {
        switch (notification.severity) {
            case Severity.Error:
                console.error(notification.message);
                break;
            case Severity.Warning:
                console.warn(notification.message);
                break;
            default:
                console.log(notification.message);
                break;
        }
        return SimpleNotificationService.NO_OP;
    };
    SimpleNotificationService.prototype.status = function (message, options) {
        return Disposable.None;
    };
    SimpleNotificationService.NO_OP = new NoOpNotification();
    return SimpleNotificationService;
}());
export { SimpleNotificationService };
var StandaloneCommandService = /** @class */ (function () {
    function StandaloneCommandService(instantiationService) {
        this._onWillExecuteCommand = new Emitter();
        this._onDidExecuteCommand = new Emitter();
        this._instantiationService = instantiationService;
        this._dynamicCommands = Object.create(null);
    }
    StandaloneCommandService.prototype.addCommand = function (command) {
        var _this = this;
        var id = command.id;
        this._dynamicCommands[id] = command;
        return toDisposable(function () {
            delete _this._dynamicCommands[id];
        });
    };
    StandaloneCommandService.prototype.executeCommand = function (id) {
        var args = [];
        for (var _i = 1; _i < arguments.length; _i++) {
            args[_i - 1] = arguments[_i];
        }
        var command = (CommandsRegistry.getCommand(id) || this._dynamicCommands[id]);
        if (!command) {
            return Promise.reject(new Error("command '" + id + "' not found"));
        }
        try {
            this._onWillExecuteCommand.fire({ commandId: id, args: args });
            var result = this._instantiationService.invokeFunction.apply(this._instantiationService, [command.handler].concat(args));
            this._onDidExecuteCommand.fire({ commandId: id, args: args });
            return Promise.resolve(result);
        }
        catch (err) {
            return Promise.reject(err);
        }
    };
    return StandaloneCommandService;
}());
export { StandaloneCommandService };
var StandaloneKeybindingService = /** @class */ (function (_super) {
    __extends(StandaloneKeybindingService, _super);
    function StandaloneKeybindingService(contextKeyService, commandService, telemetryService, notificationService, domNode) {
        var _this = _super.call(this, contextKeyService, commandService, telemetryService, notificationService) || this;
        _this._cachedResolver = null;
        _this._dynamicKeybindings = [];
        _this._register(dom.addDisposableListener(domNode, dom.EventType.KEY_DOWN, function (e) {
            var keyEvent = new StandardKeyboardEvent(e);
            var shouldPreventDefault = _this._dispatch(keyEvent, keyEvent.target);
            if (shouldPreventDefault) {
                keyEvent.preventDefault();
            }
        }));
        return _this;
    }
    StandaloneKeybindingService.prototype.addDynamicKeybinding = function (commandId, _keybinding, handler, when) {
        var _this = this;
        var keybinding = createKeybinding(_keybinding, OS);
        if (!keybinding) {
            throw new Error("Invalid keybinding");
        }
        var toDispose = new DisposableStore();
        this._dynamicKeybindings.push({
            keybinding: keybinding,
            command: commandId,
            when: when,
            weight1: 1000,
            weight2: 0
        });
        toDispose.add(toDisposable(function () {
            for (var i = 0; i < _this._dynamicKeybindings.length; i++) {
                var kb = _this._dynamicKeybindings[i];
                if (kb.command === commandId) {
                    _this._dynamicKeybindings.splice(i, 1);
                    _this.updateResolver({ source: 1 /* Default */ });
                    return;
                }
            }
        }));
        var commandService = this._commandService;
        if (commandService instanceof StandaloneCommandService) {
            toDispose.add(commandService.addCommand({
                id: commandId,
                handler: handler
            }));
        }
        else {
            throw new Error('Unknown command service!');
        }
        this.updateResolver({ source: 1 /* Default */ });
        return toDispose;
    };
    StandaloneKeybindingService.prototype.updateResolver = function (event) {
        this._cachedResolver = null;
        this._onDidUpdateKeybindings.fire(event);
    };
    StandaloneKeybindingService.prototype._getResolver = function () {
        if (!this._cachedResolver) {
            var defaults = this._toNormalizedKeybindingItems(KeybindingsRegistry.getDefaultKeybindings(), true);
            var overrides = this._toNormalizedKeybindingItems(this._dynamicKeybindings, false);
            this._cachedResolver = new KeybindingResolver(defaults, overrides);
        }
        return this._cachedResolver;
    };
    StandaloneKeybindingService.prototype._documentHasFocus = function () {
        return document.hasFocus();
    };
    StandaloneKeybindingService.prototype._toNormalizedKeybindingItems = function (items, isDefault) {
        var result = [], resultLen = 0;
        for (var _i = 0, items_1 = items; _i < items_1.length; _i++) {
            var item = items_1[_i];
            var when = item.when || undefined;
            var keybinding = item.keybinding;
            if (!keybinding) {
                // This might be a removal keybinding item in user settings => accept it
                result[resultLen++] = new ResolvedKeybindingItem(undefined, item.command, item.commandArgs, when, isDefault);
            }
            else {
                var resolvedKeybindings = this.resolveKeybinding(keybinding);
                for (var _a = 0, resolvedKeybindings_1 = resolvedKeybindings; _a < resolvedKeybindings_1.length; _a++) {
                    var resolvedKeybinding = resolvedKeybindings_1[_a];
                    result[resultLen++] = new ResolvedKeybindingItem(resolvedKeybinding, item.command, item.commandArgs, when, isDefault);
                }
            }
        }
        return result;
    };
    StandaloneKeybindingService.prototype.resolveKeybinding = function (keybinding) {
        return [new USLayoutResolvedKeybinding(keybinding, OS)];
    };
    StandaloneKeybindingService.prototype.resolveKeyboardEvent = function (keyboardEvent) {
        var keybinding = new SimpleKeybinding(keyboardEvent.ctrlKey, keyboardEvent.shiftKey, keyboardEvent.altKey, keyboardEvent.metaKey, keyboardEvent.keyCode).toChord();
        return new USLayoutResolvedKeybinding(keybinding, OS);
    };
    return StandaloneKeybindingService;
}(AbstractKeybindingService));
export { StandaloneKeybindingService };
function isConfigurationOverrides(thing) {
    return thing
        && typeof thing === 'object'
        && (!thing.overrideIdentifier || typeof thing.overrideIdentifier === 'string')
        && (!thing.resource || thing.resource instanceof URI);
}
var SimpleConfigurationService = /** @class */ (function () {
    function SimpleConfigurationService() {
        this._onDidChangeConfiguration = new Emitter();
        this.onDidChangeConfiguration = this._onDidChangeConfiguration.event;
        this._configuration = new Configuration(new DefaultConfigurationModel(), new ConfigurationModel());
    }
    SimpleConfigurationService.prototype.configuration = function () {
        return this._configuration;
    };
    SimpleConfigurationService.prototype.getValue = function (arg1, arg2) {
        var section = typeof arg1 === 'string' ? arg1 : undefined;
        var overrides = isConfigurationOverrides(arg1) ? arg1 : isConfigurationOverrides(arg2) ? arg2 : {};
        return this.configuration().getValue(section, overrides, undefined);
    };
    SimpleConfigurationService.prototype.updateValue = function (key, value, arg3, arg4) {
        this.configuration().updateValue(key, value);
        return Promise.resolve();
    };
    SimpleConfigurationService.prototype.inspect = function (key, options) {
        if (options === void 0) { options = {}; }
        return this.configuration().inspect(key, options, undefined);
    };
    return SimpleConfigurationService;
}());
export { SimpleConfigurationService };
var SimpleResourceConfigurationService = /** @class */ (function () {
    function SimpleResourceConfigurationService(configurationService) {
        var _this = this;
        this.configurationService = configurationService;
        this._onDidChangeConfiguration = new Emitter();
        this.configurationService.onDidChangeConfiguration(function (e) {
            _this._onDidChangeConfiguration.fire(e);
        });
    }
    SimpleResourceConfigurationService.prototype.getValue = function (resource, arg2, arg3) {
        var position = Pos.isIPosition(arg2) ? arg2 : null;
        var section = position ? (typeof arg3 === 'string' ? arg3 : undefined) : (typeof arg2 === 'string' ? arg2 : undefined);
        if (typeof section === 'undefined') {
            return this.configurationService.getValue();
        }
        return this.configurationService.getValue(section);
    };
    return SimpleResourceConfigurationService;
}());
export { SimpleResourceConfigurationService };
var SimpleResourcePropertiesService = /** @class */ (function () {
    function SimpleResourcePropertiesService(configurationService) {
        this.configurationService = configurationService;
    }
    SimpleResourcePropertiesService.prototype.getEOL = function (resource) {
        var filesConfiguration = this.configurationService.getValue('files');
        if (filesConfiguration && filesConfiguration.eol) {
            if (filesConfiguration.eol !== 'auto') {
                return filesConfiguration.eol;
            }
        }
        return (isLinux || isMacintosh) ? '\n' : '\r\n';
    };
    SimpleResourcePropertiesService = __decorate([
        __param(0, IConfigurationService)
    ], SimpleResourcePropertiesService);
    return SimpleResourcePropertiesService;
}());
export { SimpleResourcePropertiesService };
var StandaloneTelemetryService = /** @class */ (function () {
    function StandaloneTelemetryService() {
        this._serviceBrand = undefined;
    }
    StandaloneTelemetryService.prototype.publicLog = function (eventName, data) {
        return Promise.resolve(undefined);
    };
    StandaloneTelemetryService.prototype.publicLog2 = function (eventName, data) {
        return this.publicLog(eventName, data);
    };
    return StandaloneTelemetryService;
}());
export { StandaloneTelemetryService };
var SimpleWorkspaceContextService = /** @class */ (function () {
    function SimpleWorkspaceContextService() {
        var resource = URI.from({ scheme: SimpleWorkspaceContextService.SCHEME, authority: 'model', path: '/' });
        this.workspace = { id: '4064f6ec-cb38-4ad0-af64-ee6467e63c82', folders: [new WorkspaceFolder({ uri: resource, name: '', index: 0 })] };
    }
    SimpleWorkspaceContextService.prototype.getWorkspace = function () {
        return this.workspace;
    };
    SimpleWorkspaceContextService.prototype.getWorkspaceFolder = function (resource) {
        return resource && resource.scheme === SimpleWorkspaceContextService.SCHEME ? this.workspace.folders[0] : null;
    };
    SimpleWorkspaceContextService.SCHEME = 'inmemory';
    return SimpleWorkspaceContextService;
}());
export { SimpleWorkspaceContextService };
export function applyConfigurationValues(configurationService, source, isDiffEditor) {
    if (!source) {
        return;
    }
    if (!(configurationService instanceof SimpleConfigurationService)) {
        return;
    }
    Object.keys(source).forEach(function (key) {
        if (isEditorConfigurationKey(key)) {
            configurationService.updateValue("editor." + key, source[key]);
        }
        if (isDiffEditor && isDiffEditorConfigurationKey(key)) {
            configurationService.updateValue("diffEditor." + key, source[key]);
        }
    });
}
var SimpleBulkEditService = /** @class */ (function () {
    function SimpleBulkEditService(_modelService) {
        this._modelService = _modelService;
        //
    }
    SimpleBulkEditService.prototype.apply = function (workspaceEdit, options) {
        var edits = new Map();
        if (workspaceEdit.edits) {
            for (var _i = 0, _a = workspaceEdit.edits; _i < _a.length; _i++) {
                var edit = _a[_i];
                if (!isResourceTextEdit(edit)) {
                    return Promise.reject(new Error('bad edit - only text edits are supported'));
                }
                var model = this._modelService.getModel(edit.resource);
                if (!model) {
                    return Promise.reject(new Error('bad edit - model not found'));
                }
                var array = edits.get(model);
                if (!array) {
                    array = [];
                }
                edits.set(model, array.concat(edit.edits));
            }
        }
        var totalEdits = 0;
        var totalFiles = 0;
        edits.forEach(function (edits, model) {
            model.applyEdits(edits.map(function (edit) { return EditOperation.replaceMove(Range.lift(edit.range), edit.text); }));
            totalFiles += 1;
            totalEdits += edits.length;
        });
        return Promise.resolve({
            selection: undefined,
            ariaSummary: strings.format(SimpleServicesNLS.bulkEditServiceSummary, totalEdits, totalFiles)
        });
    };
    return SimpleBulkEditService;
}());
export { SimpleBulkEditService };
var SimpleUriLabelService = /** @class */ (function () {
    function SimpleUriLabelService() {
    }
    SimpleUriLabelService.prototype.getUriLabel = function (resource, options) {
        if (resource.scheme === 'file') {
            return resource.fsPath;
        }
        return resource.path;
    };
    return SimpleUriLabelService;
}());
export { SimpleUriLabelService };
var SimpleLayoutService = /** @class */ (function () {
    function SimpleLayoutService(_container) {
        this._container = _container;
        this.onLayout = Event.None;
    }
    Object.defineProperty(SimpleLayoutService.prototype, "container", {
        get: function () {
            return this._container;
        },
        enumerable: true,
        configurable: true
    });
    return SimpleLayoutService;
}());
export { SimpleLayoutService };
