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
import { Emitter } from '../../../base/common/event.js';
import { Disposable, DisposableStore } from '../../../base/common/lifecycle.js';
import * as platform from '../../../base/common/platform.js';
import { EDITOR_MODEL_DEFAULTS } from '../config/editorOptions.js';
import { TextModel } from '../model/textModel.js';
import { PLAINTEXT_LANGUAGE_IDENTIFIER } from '../modes/modesRegistry.js';
import { ITextResourcePropertiesService } from './resourceConfiguration.js';
import { IConfigurationService } from '../../../platform/configuration/common/configuration.js';
function MODEL_ID(resource) {
    return resource.toString();
}
var ModelData = /** @class */ (function () {
    function ModelData(model, onWillDispose, onDidChangeLanguage) {
        this._modelEventListeners = new DisposableStore();
        this.model = model;
        this._languageSelection = null;
        this._languageSelectionListener = null;
        this._modelEventListeners.add(model.onWillDispose(function () { return onWillDispose(model); }));
        this._modelEventListeners.add(model.onDidChangeLanguage(function (e) { return onDidChangeLanguage(model, e); }));
    }
    ModelData.prototype._disposeLanguageSelection = function () {
        if (this._languageSelectionListener) {
            this._languageSelectionListener.dispose();
            this._languageSelectionListener = null;
        }
        if (this._languageSelection) {
            this._languageSelection.dispose();
            this._languageSelection = null;
        }
    };
    ModelData.prototype.dispose = function () {
        this._modelEventListeners.dispose();
        this._disposeLanguageSelection();
    };
    ModelData.prototype.setLanguage = function (languageSelection) {
        var _this = this;
        this._disposeLanguageSelection();
        this._languageSelection = languageSelection;
        this._languageSelectionListener = this._languageSelection.onDidChange(function () { return _this.model.setMode(languageSelection.languageIdentifier); });
        this.model.setMode(languageSelection.languageIdentifier);
    };
    return ModelData;
}());
var DEFAULT_EOL = (platform.isLinux || platform.isMacintosh) ? 1 /* LF */ : 2 /* CRLF */;
var ModelServiceImpl = /** @class */ (function (_super) {
    __extends(ModelServiceImpl, _super);
    function ModelServiceImpl(configurationService, resourcePropertiesService) {
        var _this = _super.call(this) || this;
        _this._onModelAdded = _this._register(new Emitter());
        _this.onModelAdded = _this._onModelAdded.event;
        _this._onModelRemoved = _this._register(new Emitter());
        _this.onModelRemoved = _this._onModelRemoved.event;
        _this._onModelModeChanged = _this._register(new Emitter());
        _this.onModelModeChanged = _this._onModelModeChanged.event;
        _this._configurationService = configurationService;
        _this._resourcePropertiesService = resourcePropertiesService;
        _this._models = {};
        _this._modelCreationOptionsByLanguageAndResource = Object.create(null);
        _this._configurationServiceSubscription = _this._configurationService.onDidChangeConfiguration(function (e) { return _this._updateModelOptions(); });
        _this._updateModelOptions();
        return _this;
    }
    ModelServiceImpl._readModelOptions = function (config, isForSimpleWidget) {
        var tabSize = EDITOR_MODEL_DEFAULTS.tabSize;
        if (config.editor && typeof config.editor.tabSize !== 'undefined') {
            var parsedTabSize = parseInt(config.editor.tabSize, 10);
            if (!isNaN(parsedTabSize)) {
                tabSize = parsedTabSize;
            }
            if (tabSize < 1) {
                tabSize = 1;
            }
        }
        var indentSize = tabSize;
        if (config.editor && typeof config.editor.indentSize !== 'undefined' && config.editor.indentSize !== 'tabSize') {
            var parsedIndentSize = parseInt(config.editor.indentSize, 10);
            if (!isNaN(parsedIndentSize)) {
                indentSize = parsedIndentSize;
            }
            if (indentSize < 1) {
                indentSize = 1;
            }
        }
        var insertSpaces = EDITOR_MODEL_DEFAULTS.insertSpaces;
        if (config.editor && typeof config.editor.insertSpaces !== 'undefined') {
            insertSpaces = (config.editor.insertSpaces === 'false' ? false : Boolean(config.editor.insertSpaces));
        }
        var newDefaultEOL = DEFAULT_EOL;
        var eol = config.eol;
        if (eol === '\r\n') {
            newDefaultEOL = 2 /* CRLF */;
        }
        else if (eol === '\n') {
            newDefaultEOL = 1 /* LF */;
        }
        var trimAutoWhitespace = EDITOR_MODEL_DEFAULTS.trimAutoWhitespace;
        if (config.editor && typeof config.editor.trimAutoWhitespace !== 'undefined') {
            trimAutoWhitespace = (config.editor.trimAutoWhitespace === 'false' ? false : Boolean(config.editor.trimAutoWhitespace));
        }
        var detectIndentation = EDITOR_MODEL_DEFAULTS.detectIndentation;
        if (config.editor && typeof config.editor.detectIndentation !== 'undefined') {
            detectIndentation = (config.editor.detectIndentation === 'false' ? false : Boolean(config.editor.detectIndentation));
        }
        var largeFileOptimizations = EDITOR_MODEL_DEFAULTS.largeFileOptimizations;
        if (config.editor && typeof config.editor.largeFileOptimizations !== 'undefined') {
            largeFileOptimizations = (config.editor.largeFileOptimizations === 'false' ? false : Boolean(config.editor.largeFileOptimizations));
        }
        return {
            isForSimpleWidget: isForSimpleWidget,
            tabSize: tabSize,
            indentSize: indentSize,
            insertSpaces: insertSpaces,
            detectIndentation: detectIndentation,
            defaultEOL: newDefaultEOL,
            trimAutoWhitespace: trimAutoWhitespace,
            largeFileOptimizations: largeFileOptimizations
        };
    };
    ModelServiceImpl.prototype.getCreationOptions = function (language, resource, isForSimpleWidget) {
        var creationOptions = this._modelCreationOptionsByLanguageAndResource[language + resource];
        if (!creationOptions) {
            var editor = this._configurationService.getValue('editor', { overrideIdentifier: language, resource: resource });
            var eol = this._resourcePropertiesService.getEOL(resource, language);
            creationOptions = ModelServiceImpl._readModelOptions({ editor: editor, eol: eol }, isForSimpleWidget);
            this._modelCreationOptionsByLanguageAndResource[language + resource] = creationOptions;
        }
        return creationOptions;
    };
    ModelServiceImpl.prototype._updateModelOptions = function () {
        var oldOptionsByLanguageAndResource = this._modelCreationOptionsByLanguageAndResource;
        this._modelCreationOptionsByLanguageAndResource = Object.create(null);
        // Update options on all models
        var keys = Object.keys(this._models);
        for (var i = 0, len = keys.length; i < len; i++) {
            var modelId = keys[i];
            var modelData = this._models[modelId];
            var language = modelData.model.getLanguageIdentifier().language;
            var uri = modelData.model.uri;
            var oldOptions = oldOptionsByLanguageAndResource[language + uri];
            var newOptions = this.getCreationOptions(language, uri, modelData.model.isForSimpleWidget);
            ModelServiceImpl._setModelOptionsForModel(modelData.model, newOptions, oldOptions);
        }
    };
    ModelServiceImpl._setModelOptionsForModel = function (model, newOptions, currentOptions) {
        if (currentOptions
            && (currentOptions.detectIndentation === newOptions.detectIndentation)
            && (currentOptions.insertSpaces === newOptions.insertSpaces)
            && (currentOptions.tabSize === newOptions.tabSize)
            && (currentOptions.indentSize === newOptions.indentSize)
            && (currentOptions.trimAutoWhitespace === newOptions.trimAutoWhitespace)) {
            // Same indent opts, no need to touch the model
            return;
        }
        if (newOptions.detectIndentation) {
            model.detectIndentation(newOptions.insertSpaces, newOptions.tabSize);
            model.updateOptions({
                trimAutoWhitespace: newOptions.trimAutoWhitespace
            });
        }
        else {
            model.updateOptions({
                insertSpaces: newOptions.insertSpaces,
                tabSize: newOptions.tabSize,
                indentSize: newOptions.indentSize,
                trimAutoWhitespace: newOptions.trimAutoWhitespace
            });
        }
    };
    ModelServiceImpl.prototype.dispose = function () {
        this._configurationServiceSubscription.dispose();
        _super.prototype.dispose.call(this);
    };
    // --- begin IModelService
    ModelServiceImpl.prototype._createModelData = function (value, languageIdentifier, resource, isForSimpleWidget) {
        var _this = this;
        // create & save the model
        var options = this.getCreationOptions(languageIdentifier.language, resource, isForSimpleWidget);
        var model = new TextModel(value, options, languageIdentifier, resource);
        var modelId = MODEL_ID(model.uri);
        if (this._models[modelId]) {
            // There already exists a model with this id => this is a programmer error
            throw new Error('ModelService: Cannot add model because it already exists!');
        }
        var modelData = new ModelData(model, function (model) { return _this._onWillDispose(model); }, function (model, e) { return _this._onDidChangeLanguage(model, e); });
        this._models[modelId] = modelData;
        return modelData;
    };
    ModelServiceImpl.prototype.createModel = function (value, languageSelection, resource, isForSimpleWidget) {
        if (isForSimpleWidget === void 0) { isForSimpleWidget = false; }
        var modelData;
        if (languageSelection) {
            modelData = this._createModelData(value, languageSelection.languageIdentifier, resource, isForSimpleWidget);
            this.setMode(modelData.model, languageSelection);
        }
        else {
            modelData = this._createModelData(value, PLAINTEXT_LANGUAGE_IDENTIFIER, resource, isForSimpleWidget);
        }
        this._onModelAdded.fire(modelData.model);
        return modelData.model;
    };
    ModelServiceImpl.prototype.setMode = function (model, languageSelection) {
        if (!languageSelection) {
            return;
        }
        var modelData = this._models[MODEL_ID(model.uri)];
        if (!modelData) {
            return;
        }
        modelData.setLanguage(languageSelection);
    };
    ModelServiceImpl.prototype.getModels = function () {
        var ret = [];
        var keys = Object.keys(this._models);
        for (var i = 0, len = keys.length; i < len; i++) {
            var modelId = keys[i];
            ret.push(this._models[modelId].model);
        }
        return ret;
    };
    ModelServiceImpl.prototype.getModel = function (resource) {
        var modelId = MODEL_ID(resource);
        var modelData = this._models[modelId];
        if (!modelData) {
            return null;
        }
        return modelData.model;
    };
    // --- end IModelService
    ModelServiceImpl.prototype._onWillDispose = function (model) {
        var modelId = MODEL_ID(model.uri);
        var modelData = this._models[modelId];
        delete this._models[modelId];
        modelData.dispose();
        // clean up cache
        delete this._modelCreationOptionsByLanguageAndResource[model.getLanguageIdentifier().language + model.uri];
        this._onModelRemoved.fire(model);
    };
    ModelServiceImpl.prototype._onDidChangeLanguage = function (model, e) {
        var oldModeId = e.oldLanguage;
        var newModeId = model.getLanguageIdentifier().language;
        var oldOptions = this.getCreationOptions(oldModeId, model.uri, model.isForSimpleWidget);
        var newOptions = this.getCreationOptions(newModeId, model.uri, model.isForSimpleWidget);
        ModelServiceImpl._setModelOptionsForModel(model, newOptions, oldOptions);
        this._onModelModeChanged.fire({ model: model, oldModeId: oldModeId });
    };
    ModelServiceImpl = __decorate([
        __param(0, IConfigurationService),
        __param(1, ITextResourcePropertiesService)
    ], ModelServiceImpl);
    return ModelServiceImpl;
}(Disposable));
export { ModelServiceImpl };
