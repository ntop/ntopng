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
import { transformErrorForSerialization } from '../errors.js';
import { Disposable } from '../lifecycle.js';
import { isWeb } from '../platform.js';
import * as types from '../types.js';
var INITIALIZE = '$initialize';
var webWorkerWarningLogged = false;
export function logOnceWebWorkerWarning(err) {
    if (!isWeb) {
        // running tests
        return;
    }
    if (!webWorkerWarningLogged) {
        webWorkerWarningLogged = true;
        console.warn('Could not create web worker(s). Falling back to loading web worker code in main thread, which might cause UI freezes. Please see https://github.com/Microsoft/monaco-editor#faq');
    }
    console.warn(err.message);
}
var SimpleWorkerProtocol = /** @class */ (function () {
    function SimpleWorkerProtocol(handler) {
        this._workerId = -1;
        this._handler = handler;
        this._lastSentReq = 0;
        this._pendingReplies = Object.create(null);
    }
    SimpleWorkerProtocol.prototype.setWorkerId = function (workerId) {
        this._workerId = workerId;
    };
    SimpleWorkerProtocol.prototype.sendMessage = function (method, args) {
        var _this = this;
        var req = String(++this._lastSentReq);
        return new Promise(function (resolve, reject) {
            _this._pendingReplies[req] = {
                resolve: resolve,
                reject: reject
            };
            _this._send({
                vsWorker: _this._workerId,
                req: req,
                method: method,
                args: args
            });
        });
    };
    SimpleWorkerProtocol.prototype.handleMessage = function (message) {
        if (!message || !message.vsWorker) {
            return;
        }
        if (this._workerId !== -1 && message.vsWorker !== this._workerId) {
            return;
        }
        this._handleMessage(message);
    };
    SimpleWorkerProtocol.prototype._handleMessage = function (msg) {
        var _this = this;
        if (msg.seq) {
            var replyMessage = msg;
            if (!this._pendingReplies[replyMessage.seq]) {
                console.warn('Got reply to unknown seq');
                return;
            }
            var reply = this._pendingReplies[replyMessage.seq];
            delete this._pendingReplies[replyMessage.seq];
            if (replyMessage.err) {
                var err = replyMessage.err;
                if (replyMessage.err.$isError) {
                    err = new Error();
                    err.name = replyMessage.err.name;
                    err.message = replyMessage.err.message;
                    err.stack = replyMessage.err.stack;
                }
                reply.reject(err);
                return;
            }
            reply.resolve(replyMessage.res);
            return;
        }
        var requestMessage = msg;
        var req = requestMessage.req;
        var result = this._handler.handleMessage(requestMessage.method, requestMessage.args);
        result.then(function (r) {
            _this._send({
                vsWorker: _this._workerId,
                seq: req,
                res: r,
                err: undefined
            });
        }, function (e) {
            if (e.detail instanceof Error) {
                // Loading errors have a detail property that points to the actual error
                e.detail = transformErrorForSerialization(e.detail);
            }
            _this._send({
                vsWorker: _this._workerId,
                seq: req,
                res: undefined,
                err: transformErrorForSerialization(e)
            });
        });
    };
    SimpleWorkerProtocol.prototype._send = function (msg) {
        var transfer = [];
        if (msg.req) {
            var m = msg;
            for (var i = 0; i < m.args.length; i++) {
                if (m.args[i] instanceof ArrayBuffer) {
                    transfer.push(m.args[i]);
                }
            }
        }
        else {
            var m = msg;
            if (m.res instanceof ArrayBuffer) {
                transfer.push(m.res);
            }
        }
        this._handler.sendMessage(msg, transfer);
    };
    return SimpleWorkerProtocol;
}());
/**
 * Main thread side
 */
var SimpleWorkerClient = /** @class */ (function (_super) {
    __extends(SimpleWorkerClient, _super);
    function SimpleWorkerClient(workerFactory, moduleId, host) {
        var _this = _super.call(this) || this;
        var lazyProxyReject = null;
        _this._worker = _this._register(workerFactory.create('vs/base/common/worker/simpleWorker', function (msg) {
            _this._protocol.handleMessage(msg);
        }, function (err) {
            // in Firefox, web workers fail lazily :(
            // we will reject the proxy
            if (lazyProxyReject) {
                lazyProxyReject(err);
            }
        }));
        _this._protocol = new SimpleWorkerProtocol({
            sendMessage: function (msg, transfer) {
                _this._worker.postMessage(msg, transfer);
            },
            handleMessage: function (method, args) {
                if (typeof host[method] !== 'function') {
                    return Promise.reject(new Error('Missing method ' + method + ' on main thread host.'));
                }
                try {
                    return Promise.resolve(host[method].apply(host, args));
                }
                catch (e) {
                    return Promise.reject(e);
                }
            }
        });
        _this._protocol.setWorkerId(_this._worker.getId());
        // Gather loader configuration
        var loaderConfiguration = null;
        if (typeof self.require !== 'undefined' && typeof self.require.getConfig === 'function') {
            // Get the configuration from the Monaco AMD Loader
            loaderConfiguration = self.require.getConfig();
        }
        else if (typeof self.requirejs !== 'undefined') {
            // Get the configuration from requirejs
            loaderConfiguration = self.requirejs.s.contexts._.config;
        }
        var hostMethods = types.getAllMethodNames(host);
        // Send initialize message
        _this._onModuleLoaded = _this._protocol.sendMessage(INITIALIZE, [
            _this._worker.getId(),
            JSON.parse(JSON.stringify(loaderConfiguration)),
            moduleId,
            hostMethods,
        ]);
        // Create proxy to loaded code
        var proxyMethodRequest = function (method, args) {
            return _this._request(method, args);
        };
        _this._lazyProxy = new Promise(function (resolve, reject) {
            lazyProxyReject = reject;
            _this._onModuleLoaded.then(function (availableMethods) {
                resolve(types.createProxyObject(availableMethods, proxyMethodRequest));
            }, function (e) {
                reject(e);
                _this._onError('Worker failed to load ' + moduleId, e);
            });
        });
        return _this;
    }
    SimpleWorkerClient.prototype.getProxyObject = function () {
        return this._lazyProxy;
    };
    SimpleWorkerClient.prototype._request = function (method, args) {
        var _this = this;
        return new Promise(function (resolve, reject) {
            _this._onModuleLoaded.then(function () {
                _this._protocol.sendMessage(method, args).then(resolve, reject);
            }, reject);
        });
    };
    SimpleWorkerClient.prototype._onError = function (message, error) {
        console.error(message);
        console.info(error);
    };
    return SimpleWorkerClient;
}(Disposable));
export { SimpleWorkerClient };
/**
 * Worker side
 */
var SimpleWorkerServer = /** @class */ (function () {
    function SimpleWorkerServer(postMessage, requestHandlerFactory) {
        var _this = this;
        this._requestHandlerFactory = requestHandlerFactory;
        this._requestHandler = null;
        this._protocol = new SimpleWorkerProtocol({
            sendMessage: function (msg, transfer) {
                postMessage(msg, transfer);
            },
            handleMessage: function (method, args) { return _this._handleMessage(method, args); }
        });
    }
    SimpleWorkerServer.prototype.onmessage = function (msg) {
        this._protocol.handleMessage(msg);
    };
    SimpleWorkerServer.prototype._handleMessage = function (method, args) {
        if (method === INITIALIZE) {
            return this.initialize(args[0], args[1], args[2], args[3]);
        }
        if (!this._requestHandler || typeof this._requestHandler[method] !== 'function') {
            return Promise.reject(new Error('Missing requestHandler or method: ' + method));
        }
        try {
            return Promise.resolve(this._requestHandler[method].apply(this._requestHandler, args));
        }
        catch (e) {
            return Promise.reject(e);
        }
    };
    SimpleWorkerServer.prototype.initialize = function (workerId, loaderConfig, moduleId, hostMethods) {
        var _this = this;
        this._protocol.setWorkerId(workerId);
        var proxyMethodRequest = function (method, args) {
            return _this._protocol.sendMessage(method, args);
        };
        var hostProxy = types.createProxyObject(hostMethods, proxyMethodRequest);
        if (this._requestHandlerFactory) {
            // static request handler
            this._requestHandler = this._requestHandlerFactory(hostProxy);
            return Promise.resolve(types.getAllMethodNames(this._requestHandler));
        }
        if (loaderConfig) {
            // Remove 'baseUrl', handling it is beyond scope for now
            if (typeof loaderConfig.baseUrl !== 'undefined') {
                delete loaderConfig['baseUrl'];
            }
            if (typeof loaderConfig.paths !== 'undefined') {
                if (typeof loaderConfig.paths.vs !== 'undefined') {
                    delete loaderConfig.paths['vs'];
                }
            }
            // Since this is in a web worker, enable catching errors
            loaderConfig.catchError = true;
            self.require.config(loaderConfig);
        }
        return new Promise(function (resolve, reject) {
            // Use the global require to be sure to get the global config
            self.require([moduleId], function (module) {
                _this._requestHandler = module.create(hostProxy);
                if (!_this._requestHandler) {
                    reject(new Error("No RequestHandler!"));
                    return;
                }
                resolve(types.getAllMethodNames(_this._requestHandler));
            }, reject);
        });
    };
    return SimpleWorkerServer;
}());
export { SimpleWorkerServer };
/**
 * Called on the worker side
 */
export function create(postMessage) {
    return new SimpleWorkerServer(postMessage, null);
}
