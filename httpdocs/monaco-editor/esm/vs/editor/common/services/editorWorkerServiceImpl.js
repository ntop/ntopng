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
import { IntervalTimer } from '../../../base/common/async.js';
import { Disposable, dispose, toDisposable, DisposableStore } from '../../../base/common/lifecycle.js';
import { SimpleWorkerClient, logOnceWebWorkerWarning } from '../../../base/common/worker/simpleWorker.js';
import { DefaultWorkerFactory } from '../../../base/worker/defaultWorkerFactory.js';
import * as modes from '../modes.js';
import { LanguageConfigurationRegistry } from '../modes/languageConfigurationRegistry.js';
import { EditorSimpleWorker } from './editorSimpleWorker.js';
import { IModelService } from './modelService.js';
import { ITextResourceConfigurationService } from './resourceConfiguration.js';
import { regExpFlags } from '../../../base/common/strings.js';
import { isNonEmptyArray } from '../../../base/common/arrays.js';
import { ILogService } from '../../../platform/log/common/log.js';
import { StopWatch } from '../../../base/common/stopwatch.js';
/**
 * Stop syncing a model to the worker if it was not needed for 1 min.
 */
var STOP_SYNC_MODEL_DELTA_TIME_MS = 60 * 1000;
/**
 * Stop the worker if it was not needed for 5 min.
 */
var STOP_WORKER_DELTA_TIME_MS = 5 * 60 * 1000;
function canSyncModel(modelService, resource) {
    var model = modelService.getModel(resource);
    if (!model) {
        return false;
    }
    if (model.isTooLargeForSyncing()) {
        return false;
    }
    return true;
}
var EditorWorkerServiceImpl = /** @class */ (function (_super) {
    __extends(EditorWorkerServiceImpl, _super);
    function EditorWorkerServiceImpl(modelService, configurationService, logService) {
        var _this = _super.call(this) || this;
        _this._modelService = modelService;
        _this._workerManager = _this._register(new WorkerManager(_this._modelService));
        _this._logService = logService;
        // todo@joh make sure this happens only once
        _this._register(modes.LinkProviderRegistry.register('*', {
            provideLinks: function (model, token) {
                if (!canSyncModel(_this._modelService, model.uri)) {
                    return Promise.resolve({ links: [] }); // File too large
                }
                return _this._workerManager.withWorker().then(function (client) { return client.computeLinks(model.uri); }).then(function (links) {
                    return links && { links: links };
                });
            }
        }));
        _this._register(modes.CompletionProviderRegistry.register('*', new WordBasedCompletionItemProvider(_this._workerManager, configurationService, _this._modelService)));
        return _this;
    }
    EditorWorkerServiceImpl.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
    };
    EditorWorkerServiceImpl.prototype.canComputeDiff = function (original, modified) {
        return (canSyncModel(this._modelService, original) && canSyncModel(this._modelService, modified));
    };
    EditorWorkerServiceImpl.prototype.computeDiff = function (original, modified, ignoreTrimWhitespace) {
        return this._workerManager.withWorker().then(function (client) { return client.computeDiff(original, modified, ignoreTrimWhitespace); });
    };
    EditorWorkerServiceImpl.prototype.computeMoreMinimalEdits = function (resource, edits) {
        var _this = this;
        if (isNonEmptyArray(edits)) {
            if (!canSyncModel(this._modelService, resource)) {
                return Promise.resolve(edits); // File too large
            }
            var sw_1 = StopWatch.create(true);
            var result = this._workerManager.withWorker().then(function (client) { return client.computeMoreMinimalEdits(resource, edits); });
            result.finally(function () { return _this._logService.trace('FORMAT#computeMoreMinimalEdits', resource.toString(true), sw_1.elapsed()); });
            return result;
        }
        else {
            return Promise.resolve(undefined);
        }
    };
    EditorWorkerServiceImpl.prototype.canNavigateValueSet = function (resource) {
        return (canSyncModel(this._modelService, resource));
    };
    EditorWorkerServiceImpl.prototype.navigateValueSet = function (resource, range, up) {
        return this._workerManager.withWorker().then(function (client) { return client.navigateValueSet(resource, range, up); });
    };
    EditorWorkerServiceImpl.prototype.canComputeWordRanges = function (resource) {
        return canSyncModel(this._modelService, resource);
    };
    EditorWorkerServiceImpl.prototype.computeWordRanges = function (resource, range) {
        return this._workerManager.withWorker().then(function (client) { return client.computeWordRanges(resource, range); });
    };
    EditorWorkerServiceImpl = __decorate([
        __param(0, IModelService),
        __param(1, ITextResourceConfigurationService),
        __param(2, ILogService)
    ], EditorWorkerServiceImpl);
    return EditorWorkerServiceImpl;
}(Disposable));
export { EditorWorkerServiceImpl };
var WordBasedCompletionItemProvider = /** @class */ (function () {
    function WordBasedCompletionItemProvider(workerManager, configurationService, modelService) {
        this._debugDisplayName = 'wordbasedCompletions';
        this._workerManager = workerManager;
        this._configurationService = configurationService;
        this._modelService = modelService;
    }
    WordBasedCompletionItemProvider.prototype.provideCompletionItems = function (model, position) {
        var wordBasedSuggestions = this._configurationService.getValue(model.uri, position, 'editor').wordBasedSuggestions;
        if (!wordBasedSuggestions) {
            return undefined;
        }
        if (!canSyncModel(this._modelService, model.uri)) {
            return undefined; // File too large
        }
        return this._workerManager.withWorker().then(function (client) { return client.textualSuggest(model.uri, position); });
    };
    return WordBasedCompletionItemProvider;
}());
var WorkerManager = /** @class */ (function (_super) {
    __extends(WorkerManager, _super);
    function WorkerManager(modelService) {
        var _this = _super.call(this) || this;
        _this._modelService = modelService;
        _this._editorWorkerClient = null;
        _this._lastWorkerUsedTime = (new Date()).getTime();
        var stopWorkerInterval = _this._register(new IntervalTimer());
        stopWorkerInterval.cancelAndSet(function () { return _this._checkStopIdleWorker(); }, Math.round(STOP_WORKER_DELTA_TIME_MS / 2));
        _this._register(_this._modelService.onModelRemoved(function (_) { return _this._checkStopEmptyWorker(); }));
        return _this;
    }
    WorkerManager.prototype.dispose = function () {
        if (this._editorWorkerClient) {
            this._editorWorkerClient.dispose();
            this._editorWorkerClient = null;
        }
        _super.prototype.dispose.call(this);
    };
    /**
     * Check if the model service has no more models and stop the worker if that is the case.
     */
    WorkerManager.prototype._checkStopEmptyWorker = function () {
        if (!this._editorWorkerClient) {
            return;
        }
        var models = this._modelService.getModels();
        if (models.length === 0) {
            // There are no more models => nothing possible for me to do
            this._editorWorkerClient.dispose();
            this._editorWorkerClient = null;
        }
    };
    /**
     * Check if the worker has been idle for a while and then stop it.
     */
    WorkerManager.prototype._checkStopIdleWorker = function () {
        if (!this._editorWorkerClient) {
            return;
        }
        var timeSinceLastWorkerUsedTime = (new Date()).getTime() - this._lastWorkerUsedTime;
        if (timeSinceLastWorkerUsedTime > STOP_WORKER_DELTA_TIME_MS) {
            this._editorWorkerClient.dispose();
            this._editorWorkerClient = null;
        }
    };
    WorkerManager.prototype.withWorker = function () {
        this._lastWorkerUsedTime = (new Date()).getTime();
        if (!this._editorWorkerClient) {
            this._editorWorkerClient = new EditorWorkerClient(this._modelService, 'editorWorkerService');
        }
        return Promise.resolve(this._editorWorkerClient);
    };
    return WorkerManager;
}(Disposable));
var EditorModelManager = /** @class */ (function (_super) {
    __extends(EditorModelManager, _super);
    function EditorModelManager(proxy, modelService, keepIdleModels) {
        var _this = _super.call(this) || this;
        _this._syncedModels = Object.create(null);
        _this._syncedModelsLastUsedTime = Object.create(null);
        _this._proxy = proxy;
        _this._modelService = modelService;
        if (!keepIdleModels) {
            var timer = new IntervalTimer();
            timer.cancelAndSet(function () { return _this._checkStopModelSync(); }, Math.round(STOP_SYNC_MODEL_DELTA_TIME_MS / 2));
            _this._register(timer);
        }
        return _this;
    }
    EditorModelManager.prototype.dispose = function () {
        for (var modelUrl in this._syncedModels) {
            dispose(this._syncedModels[modelUrl]);
        }
        this._syncedModels = Object.create(null);
        this._syncedModelsLastUsedTime = Object.create(null);
        _super.prototype.dispose.call(this);
    };
    EditorModelManager.prototype.ensureSyncedResources = function (resources) {
        for (var _i = 0, resources_1 = resources; _i < resources_1.length; _i++) {
            var resource = resources_1[_i];
            var resourceStr = resource.toString();
            if (!this._syncedModels[resourceStr]) {
                this._beginModelSync(resource);
            }
            if (this._syncedModels[resourceStr]) {
                this._syncedModelsLastUsedTime[resourceStr] = (new Date()).getTime();
            }
        }
    };
    EditorModelManager.prototype._checkStopModelSync = function () {
        var currentTime = (new Date()).getTime();
        var toRemove = [];
        for (var modelUrl in this._syncedModelsLastUsedTime) {
            var elapsedTime = currentTime - this._syncedModelsLastUsedTime[modelUrl];
            if (elapsedTime > STOP_SYNC_MODEL_DELTA_TIME_MS) {
                toRemove.push(modelUrl);
            }
        }
        for (var _i = 0, toRemove_1 = toRemove; _i < toRemove_1.length; _i++) {
            var e = toRemove_1[_i];
            this._stopModelSync(e);
        }
    };
    EditorModelManager.prototype._beginModelSync = function (resource) {
        var _this = this;
        var model = this._modelService.getModel(resource);
        if (!model) {
            return;
        }
        if (model.isTooLargeForSyncing()) {
            return;
        }
        var modelUrl = resource.toString();
        this._proxy.acceptNewModel({
            url: model.uri.toString(),
            lines: model.getLinesContent(),
            EOL: model.getEOL(),
            versionId: model.getVersionId()
        });
        var toDispose = new DisposableStore();
        toDispose.add(model.onDidChangeContent(function (e) {
            _this._proxy.acceptModelChanged(modelUrl.toString(), e);
        }));
        toDispose.add(model.onWillDispose(function () {
            _this._stopModelSync(modelUrl);
        }));
        toDispose.add(toDisposable(function () {
            _this._proxy.acceptRemovedModel(modelUrl);
        }));
        this._syncedModels[modelUrl] = toDispose;
    };
    EditorModelManager.prototype._stopModelSync = function (modelUrl) {
        var toDispose = this._syncedModels[modelUrl];
        delete this._syncedModels[modelUrl];
        delete this._syncedModelsLastUsedTime[modelUrl];
        dispose(toDispose);
    };
    return EditorModelManager;
}(Disposable));
var SynchronousWorkerClient = /** @class */ (function () {
    function SynchronousWorkerClient(instance) {
        this._instance = instance;
        this._proxyObj = Promise.resolve(this._instance);
    }
    SynchronousWorkerClient.prototype.dispose = function () {
        this._instance.dispose();
    };
    SynchronousWorkerClient.prototype.getProxyObject = function () {
        return this._proxyObj;
    };
    return SynchronousWorkerClient;
}());
var EditorWorkerHost = /** @class */ (function () {
    function EditorWorkerHost(workerClient) {
        this._workerClient = workerClient;
    }
    // foreign host request
    EditorWorkerHost.prototype.fhr = function (method, args) {
        return this._workerClient.fhr(method, args);
    };
    return EditorWorkerHost;
}());
export { EditorWorkerHost };
var EditorWorkerClient = /** @class */ (function (_super) {
    __extends(EditorWorkerClient, _super);
    function EditorWorkerClient(modelService, label) {
        var _this = _super.call(this) || this;
        _this._modelService = modelService;
        _this._workerFactory = new DefaultWorkerFactory(label);
        _this._worker = null;
        _this._modelManager = null;
        return _this;
    }
    // foreign host request
    EditorWorkerClient.prototype.fhr = function (method, args) {
        throw new Error("Not implemented!");
    };
    EditorWorkerClient.prototype._getOrCreateWorker = function () {
        if (!this._worker) {
            try {
                this._worker = this._register(new SimpleWorkerClient(this._workerFactory, 'vs/editor/common/services/editorSimpleWorker', new EditorWorkerHost(this)));
            }
            catch (err) {
                logOnceWebWorkerWarning(err);
                this._worker = new SynchronousWorkerClient(new EditorSimpleWorker(new EditorWorkerHost(this), null));
            }
        }
        return this._worker;
    };
    EditorWorkerClient.prototype._getProxy = function () {
        var _this = this;
        return this._getOrCreateWorker().getProxyObject().then(undefined, function (err) {
            logOnceWebWorkerWarning(err);
            _this._worker = new SynchronousWorkerClient(new EditorSimpleWorker(new EditorWorkerHost(_this), null));
            return _this._getOrCreateWorker().getProxyObject();
        });
    };
    EditorWorkerClient.prototype._getOrCreateModelManager = function (proxy) {
        if (!this._modelManager) {
            this._modelManager = this._register(new EditorModelManager(proxy, this._modelService, false));
        }
        return this._modelManager;
    };
    EditorWorkerClient.prototype._withSyncedResources = function (resources) {
        var _this = this;
        return this._getProxy().then(function (proxy) {
            _this._getOrCreateModelManager(proxy).ensureSyncedResources(resources);
            return proxy;
        });
    };
    EditorWorkerClient.prototype.computeDiff = function (original, modified, ignoreTrimWhitespace) {
        return this._withSyncedResources([original, modified]).then(function (proxy) {
            return proxy.computeDiff(original.toString(), modified.toString(), ignoreTrimWhitespace);
        });
    };
    EditorWorkerClient.prototype.computeMoreMinimalEdits = function (resource, edits) {
        return this._withSyncedResources([resource]).then(function (proxy) {
            return proxy.computeMoreMinimalEdits(resource.toString(), edits);
        });
    };
    EditorWorkerClient.prototype.computeLinks = function (resource) {
        return this._withSyncedResources([resource]).then(function (proxy) {
            return proxy.computeLinks(resource.toString());
        });
    };
    EditorWorkerClient.prototype.textualSuggest = function (resource, position) {
        var _this = this;
        return this._withSyncedResources([resource]).then(function (proxy) {
            var model = _this._modelService.getModel(resource);
            if (!model) {
                return null;
            }
            var wordDefRegExp = LanguageConfigurationRegistry.getWordDefinition(model.getLanguageIdentifier().id);
            var wordDef = wordDefRegExp.source;
            var wordDefFlags = regExpFlags(wordDefRegExp);
            return proxy.textualSuggest(resource.toString(), position, wordDef, wordDefFlags);
        });
    };
    EditorWorkerClient.prototype.computeWordRanges = function (resource, range) {
        var _this = this;
        return this._withSyncedResources([resource]).then(function (proxy) {
            var model = _this._modelService.getModel(resource);
            if (!model) {
                return Promise.resolve(null);
            }
            var wordDefRegExp = LanguageConfigurationRegistry.getWordDefinition(model.getLanguageIdentifier().id);
            var wordDef = wordDefRegExp.source;
            var wordDefFlags = regExpFlags(wordDefRegExp);
            return proxy.computeWordRanges(resource.toString(), range, wordDef, wordDefFlags);
        });
    };
    EditorWorkerClient.prototype.navigateValueSet = function (resource, range, up) {
        var _this = this;
        return this._withSyncedResources([resource]).then(function (proxy) {
            var model = _this._modelService.getModel(resource);
            if (!model) {
                return null;
            }
            var wordDefRegExp = LanguageConfigurationRegistry.getWordDefinition(model.getLanguageIdentifier().id);
            var wordDef = wordDefRegExp.source;
            var wordDefFlags = regExpFlags(wordDefRegExp);
            return proxy.navigateValueSet(resource.toString(), range, up, wordDef, wordDefFlags);
        });
    };
    return EditorWorkerClient;
}(Disposable));
export { EditorWorkerClient };
