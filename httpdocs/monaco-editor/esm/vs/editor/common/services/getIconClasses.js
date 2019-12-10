/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { Schemas } from '../../../base/common/network.js';
import { DataUri, basenameOrAuthority } from '../../../base/common/resources.js';
import { PLAINTEXT_MODE_ID } from '../modes/modesRegistry.js';
import { FileKind } from '../../../platform/files/common/files.js';
export function getIconClasses(modelService, modeService, resource, fileKind) {
    // we always set these base classes even if we do not have a path
    var classes = fileKind === FileKind.ROOT_FOLDER ? ['rootfolder-icon'] : fileKind === FileKind.FOLDER ? ['folder-icon'] : ['file-icon'];
    if (resource) {
        // Get the path and name of the resource. For data-URIs, we need to parse specially
        var name_1;
        if (resource.scheme === Schemas.data) {
            var metadata = DataUri.parseMetaData(resource);
            name_1 = metadata.get(DataUri.META_DATA_LABEL);
        }
        else {
            name_1 = cssEscape(basenameOrAuthority(resource).toLowerCase());
        }
        // Folders
        if (fileKind === FileKind.FOLDER) {
            classes.push(name_1 + "-name-folder-icon");
        }
        // Files
        else {
            // Name & Extension(s)
            if (name_1) {
                classes.push(name_1 + "-name-file-icon");
                var dotSegments = name_1.split('.');
                for (var i = 1; i < dotSegments.length; i++) {
                    classes.push(dotSegments.slice(i).join('.') + "-ext-file-icon"); // add each combination of all found extensions if more than one
                }
                classes.push("ext-file-icon"); // extra segment to increase file-ext score
            }
            // Detected Mode
            var detectedModeId = detectModeId(modelService, modeService, resource);
            if (detectedModeId) {
                classes.push(cssEscape(detectedModeId) + "-lang-file-icon");
            }
        }
    }
    return classes;
}
export function detectModeId(modelService, modeService, resource) {
    if (!resource) {
        return null; // we need a resource at least
    }
    var modeId = null;
    // Data URI: check for encoded metadata
    if (resource.scheme === Schemas.data) {
        var metadata = DataUri.parseMetaData(resource);
        var mime = metadata.get(DataUri.META_DATA_MIME);
        if (mime) {
            modeId = modeService.getModeId(mime);
        }
    }
    // Any other URI: check for model if existing
    else {
        var model = modelService.getModel(resource);
        if (model) {
            modeId = model.getModeId();
        }
    }
    // only take if the mode is specific (aka no just plain text)
    if (modeId && modeId !== PLAINTEXT_MODE_ID) {
        return modeId;
    }
    // otherwise fallback to path based detection
    return modeService.getModeIdByFilepathOrFirstLine(resource);
}
export function cssEscape(val) {
    return val.replace(/\s/g, '\\$&'); // make sure to not introduce CSS classes from files that contain whitespace
}
