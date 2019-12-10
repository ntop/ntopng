/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as extpath from './extpath.js';
import * as paths from './path.js';
import { URI } from './uri.js';
import { equalsIgnoreCase } from './strings.js';
import { Schemas } from './network.js';
import { isLinux, isWindows } from './platform.js';
export function hasToIgnoreCase(resource) {
    // A file scheme resource is in the same platform as code, so ignore case for non linux platforms
    // Resource can be from another platform. Lowering the case as an hack. Should come from File system provider
    return resource && resource.scheme === Schemas.file ? !isLinux : true;
}
export function basenameOrAuthority(resource) {
    return basename(resource) || resource.authority;
}
/**
 * Tests wheter the two authorities are the same
 */
export function isEqualAuthority(a1, a2) {
    return a1 === a2 || equalsIgnoreCase(a1, a2);
}
export function isEqual(first, second, ignoreCase) {
    if (ignoreCase === void 0) { ignoreCase = hasToIgnoreCase(first); }
    if (first === second) {
        return true;
    }
    if (!first || !second) {
        return false;
    }
    if (first.scheme !== second.scheme || !isEqualAuthority(first.authority, second.authority)) {
        return false;
    }
    var p1 = first.path || '/', p2 = second.path || '/';
    return p1 === p2 || ignoreCase && equalsIgnoreCase(p1 || '/', p2 || '/');
}
export function basename(resource) {
    return paths.posix.basename(resource.path);
}
/**
 * Return a URI representing the directory of a URI path.
 *
 * @param resource The input URI.
 * @returns The URI representing the directory of the input URI.
 */
export function dirname(resource) {
    if (resource.path.length === 0) {
        return resource;
    }
    if (resource.scheme === Schemas.file) {
        return URI.file(paths.dirname(originalFSPath(resource)));
    }
    var dirname = paths.posix.dirname(resource.path);
    if (resource.authority && dirname.length && dirname.charCodeAt(0) !== 47 /* Slash */) {
        console.error("dirname(\"" + resource.toString + ")) resulted in a relative path");
        dirname = '/'; // If a URI contains an authority component, then the path component must either be empty or begin with a CharCode.Slash ("/") character
    }
    return resource.with({
        path: dirname
    });
}
/**
 * Join a URI path with path fragments and normalizes the resulting path.
 *
 * @param resource The input URI.
 * @param pathFragment The path fragment to add to the URI path.
 * @returns The resulting URI.
 */
export function joinPath(resource) {
    var _a;
    var pathFragment = [];
    for (var _i = 1; _i < arguments.length; _i++) {
        pathFragment[_i - 1] = arguments[_i];
    }
    var joinedPath;
    if (resource.scheme === Schemas.file) {
        joinedPath = URI.file(paths.join.apply(paths, [originalFSPath(resource)].concat(pathFragment))).path;
    }
    else {
        joinedPath = (_a = paths.posix).join.apply(_a, [resource.path || '/'].concat(pathFragment));
    }
    return resource.with({
        path: joinedPath
    });
}
/**
 * Normalizes the path part of a URI: Resolves `.` and `..` elements with directory names.
 *
 * @param resource The URI to normalize the path.
 * @returns The URI with the normalized path.
 */
export function normalizePath(resource) {
    if (!resource.path.length) {
        return resource;
    }
    var normalizedPath;
    if (resource.scheme === Schemas.file) {
        normalizedPath = URI.file(paths.normalize(originalFSPath(resource))).path;
    }
    else {
        normalizedPath = paths.posix.normalize(resource.path);
    }
    return resource.with({
        path: normalizedPath
    });
}
/**
 * Returns the fsPath of an URI where the drive letter is not normalized.
 * See #56403.
 */
export function originalFSPath(uri) {
    var value;
    var uriPath = uri.path;
    if (uri.authority && uriPath.length > 1 && uri.scheme === Schemas.file) {
        // unc path: file://shares/c$/far/boo
        value = "//" + uri.authority + uriPath;
    }
    else if (isWindows
        && uriPath.charCodeAt(0) === 47 /* Slash */
        && extpath.isWindowsDriveLetter(uriPath.charCodeAt(1))
        && uriPath.charCodeAt(2) === 58 /* Colon */) {
        value = uriPath.substr(1);
    }
    else {
        // other path
        value = uriPath;
    }
    if (isWindows) {
        value = value.replace(/\//g, '\\');
    }
    return value;
}
/**
 * Returns a relative path between two URIs. If the URIs don't have the same schema or authority, `undefined` is returned.
 * The returned relative path always uses forward slashes.
 */
export function relativePath(from, to, ignoreCase) {
    if (ignoreCase === void 0) { ignoreCase = hasToIgnoreCase(from); }
    if (from.scheme !== to.scheme || !isEqualAuthority(from.authority, to.authority)) {
        return undefined;
    }
    if (from.scheme === Schemas.file) {
        var relativePath_1 = paths.relative(from.path, to.path);
        return isWindows ? extpath.toSlashes(relativePath_1) : relativePath_1;
    }
    var fromPath = from.path || '/', toPath = to.path || '/';
    if (ignoreCase) {
        // make casing of fromPath match toPath
        var i = 0;
        for (var len = Math.min(fromPath.length, toPath.length); i < len; i++) {
            if (fromPath.charCodeAt(i) !== toPath.charCodeAt(i)) {
                if (fromPath.charAt(i).toLowerCase() !== toPath.charAt(i).toLowerCase()) {
                    break;
                }
            }
        }
        fromPath = toPath.substr(0, i) + fromPath.substr(i);
    }
    return paths.posix.relative(fromPath, toPath);
}
/**
 * Data URI related helpers.
 */
export var DataUri;
(function (DataUri) {
    DataUri.META_DATA_LABEL = 'label';
    DataUri.META_DATA_DESCRIPTION = 'description';
    DataUri.META_DATA_SIZE = 'size';
    DataUri.META_DATA_MIME = 'mime';
    function parseMetaData(dataUri) {
        var metadata = new Map();
        // Given a URI of:  data:image/png;size:2313;label:SomeLabel;description:SomeDescription;base64,77+9UE5...
        // the metadata is: size:2313;label:SomeLabel;description:SomeDescription
        var meta = dataUri.path.substring(dataUri.path.indexOf(';') + 1, dataUri.path.lastIndexOf(';'));
        meta.split(';').forEach(function (property) {
            var _a = property.split(':'), key = _a[0], value = _a[1];
            if (key && value) {
                metadata.set(key, value);
            }
        });
        // Given a URI of:  data:image/png;size:2313;label:SomeLabel;description:SomeDescription;base64,77+9UE5...
        // the mime is: image/png
        var mime = dataUri.path.substring(0, dataUri.path.indexOf(';'));
        if (mime) {
            metadata.set(DataUri.META_DATA_MIME, mime);
        }
        return metadata;
    }
    DataUri.parseMetaData = parseMetaData;
})(DataUri || (DataUri = {}));
