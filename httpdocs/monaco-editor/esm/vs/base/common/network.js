/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { URI } from './uri.js';
import * as platform from './platform.js';
export var Schemas;
(function (Schemas) {
    /**
     * A schema that is used for models that exist in memory
     * only and that have no correspondence on a server or such.
     */
    Schemas.inMemory = 'inmemory';
    /**
     * A schema that is used for setting files
     */
    Schemas.vscode = 'vscode';
    /**
     * A schema that is used for internal private files
     */
    Schemas.internal = 'private';
    /**
     * A walk-through document.
     */
    Schemas.walkThrough = 'walkThrough';
    /**
     * An embedded code snippet.
     */
    Schemas.walkThroughSnippet = 'walkThroughSnippet';
    Schemas.http = 'http';
    Schemas.https = 'https';
    Schemas.file = 'file';
    Schemas.mailto = 'mailto';
    Schemas.untitled = 'untitled';
    Schemas.data = 'data';
    Schemas.command = 'command';
    Schemas.vscodeRemote = 'vscode-remote';
    Schemas.vscodeRemoteResource = 'vscode-remote-resource';
    Schemas.userData = 'vscode-userdata';
})(Schemas || (Schemas = {}));
var RemoteAuthoritiesImpl = /** @class */ (function () {
    function RemoteAuthoritiesImpl() {
        this._hosts = Object.create(null);
        this._ports = Object.create(null);
        this._connectionTokens = Object.create(null);
        this._preferredWebSchema = 'http';
    }
    RemoteAuthoritiesImpl.prototype.setPreferredWebSchema = function (schema) {
        this._preferredWebSchema = schema;
    };
    RemoteAuthoritiesImpl.prototype.rewrite = function (authority, path) {
        var host = this._hosts[authority];
        var port = this._ports[authority];
        var connectionToken = this._connectionTokens[authority];
        return URI.from({
            scheme: platform.isWeb ? this._preferredWebSchema : Schemas.vscodeRemoteResource,
            authority: host + ":" + port,
            path: "/vscode-remote-resource",
            query: "path=" + encodeURIComponent(path) + "&tkn=" + encodeURIComponent(connectionToken)
        });
    };
    return RemoteAuthoritiesImpl;
}());
export var RemoteAuthorities = new RemoteAuthoritiesImpl();
