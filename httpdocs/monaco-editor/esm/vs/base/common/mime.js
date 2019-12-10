/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { basename, posix } from './path.js';
import { endsWith, startsWithUTF8BOM } from './strings.js';
import { match } from './glob.js';
import { Schemas } from './network.js';
import { DataUri } from './resources.js';
export var MIME_TEXT = 'text/plain';
export var MIME_UNKNOWN = 'application/unknown';
var registeredAssociations = [];
var nonUserRegisteredAssociations = [];
var userRegisteredAssociations = [];
/**
 * Associate a text mime to the registry.
 */
export function registerTextMime(association, warnOnOverwrite) {
    if (warnOnOverwrite === void 0) { warnOnOverwrite = false; }
    // Register
    var associationItem = toTextMimeAssociationItem(association);
    registeredAssociations.push(associationItem);
    if (!associationItem.userConfigured) {
        nonUserRegisteredAssociations.push(associationItem);
    }
    else {
        userRegisteredAssociations.push(associationItem);
    }
    // Check for conflicts unless this is a user configured association
    if (warnOnOverwrite && !associationItem.userConfigured) {
        registeredAssociations.forEach(function (a) {
            if (a.mime === associationItem.mime || a.userConfigured) {
                return; // same mime or userConfigured is ok
            }
            if (associationItem.extension && a.extension === associationItem.extension) {
                console.warn("Overwriting extension <<" + associationItem.extension + ">> to now point to mime <<" + associationItem.mime + ">>");
            }
            if (associationItem.filename && a.filename === associationItem.filename) {
                console.warn("Overwriting filename <<" + associationItem.filename + ">> to now point to mime <<" + associationItem.mime + ">>");
            }
            if (associationItem.filepattern && a.filepattern === associationItem.filepattern) {
                console.warn("Overwriting filepattern <<" + associationItem.filepattern + ">> to now point to mime <<" + associationItem.mime + ">>");
            }
            if (associationItem.firstline && a.firstline === associationItem.firstline) {
                console.warn("Overwriting firstline <<" + associationItem.firstline + ">> to now point to mime <<" + associationItem.mime + ">>");
            }
        });
    }
}
function toTextMimeAssociationItem(association) {
    return {
        id: association.id,
        mime: association.mime,
        filename: association.filename,
        extension: association.extension,
        filepattern: association.filepattern,
        firstline: association.firstline,
        userConfigured: association.userConfigured,
        filenameLowercase: association.filename ? association.filename.toLowerCase() : undefined,
        extensionLowercase: association.extension ? association.extension.toLowerCase() : undefined,
        filepatternLowercase: association.filepattern ? association.filepattern.toLowerCase() : undefined,
        filepatternOnPath: association.filepattern ? association.filepattern.indexOf(posix.sep) >= 0 : false
    };
}
/**
 * Given a file, return the best matching mime type for it
 */
export function guessMimeTypes(resource, firstLine) {
    var path;
    if (resource) {
        switch (resource.scheme) {
            case Schemas.file:
                path = resource.fsPath;
                break;
            case Schemas.data:
                var metadata = DataUri.parseMetaData(resource);
                path = metadata.get(DataUri.META_DATA_LABEL);
                break;
            default:
                path = resource.path;
        }
    }
    if (!path) {
        return [MIME_UNKNOWN];
    }
    path = path.toLowerCase();
    var filename = basename(path);
    // 1.) User configured mappings have highest priority
    var configuredMime = guessMimeTypeByPath(path, filename, userRegisteredAssociations);
    if (configuredMime) {
        return [configuredMime, MIME_TEXT];
    }
    // 2.) Registered mappings have middle priority
    var registeredMime = guessMimeTypeByPath(path, filename, nonUserRegisteredAssociations);
    if (registeredMime) {
        return [registeredMime, MIME_TEXT];
    }
    // 3.) Firstline has lowest priority
    if (firstLine) {
        var firstlineMime = guessMimeTypeByFirstline(firstLine);
        if (firstlineMime) {
            return [firstlineMime, MIME_TEXT];
        }
    }
    return [MIME_UNKNOWN];
}
function guessMimeTypeByPath(path, filename, associations) {
    var filenameMatch = null;
    var patternMatch = null;
    var extensionMatch = null;
    // We want to prioritize associations based on the order they are registered so that the last registered
    // association wins over all other. This is for https://github.com/Microsoft/vscode/issues/20074
    for (var i = associations.length - 1; i >= 0; i--) {
        var association = associations[i];
        // First exact name match
        if (filename === association.filenameLowercase) {
            filenameMatch = association;
            break; // take it!
        }
        // Longest pattern match
        if (association.filepattern) {
            if (!patternMatch || association.filepattern.length > patternMatch.filepattern.length) {
                var target = association.filepatternOnPath ? path : filename; // match on full path if pattern contains path separator
                if (match(association.filepatternLowercase, target)) {
                    patternMatch = association;
                }
            }
        }
        // Longest extension match
        if (association.extension) {
            if (!extensionMatch || association.extension.length > extensionMatch.extension.length) {
                if (endsWith(filename, association.extensionLowercase)) {
                    extensionMatch = association;
                }
            }
        }
    }
    // 1.) Exact name match has second highest prio
    if (filenameMatch) {
        return filenameMatch.mime;
    }
    // 2.) Match on pattern
    if (patternMatch) {
        return patternMatch.mime;
    }
    // 3.) Match on extension comes next
    if (extensionMatch) {
        return extensionMatch.mime;
    }
    return null;
}
function guessMimeTypeByFirstline(firstLine) {
    if (startsWithUTF8BOM(firstLine)) {
        firstLine = firstLine.substr(1);
    }
    if (firstLine.length > 0) {
        // We want to prioritize associations based on the order they are registered so that the last registered
        // association wins over all other. This is for https://github.com/Microsoft/vscode/issues/20074
        for (var i = registeredAssociations.length - 1; i >= 0; i--) {
            var association = registeredAssociations[i];
            if (!association.firstline) {
                continue;
            }
            var matches = firstLine.match(association.firstline);
            if (matches && matches.length > 0) {
                return association.mime;
            }
        }
    }
    return null;
}
