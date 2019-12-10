import { URI } from '../../../base/common/uri.js';
export var WORKSPACE_EXTENSION = 'code-workspace';
export function isSingleFolderWorkspaceIdentifier(obj) {
    return obj instanceof URI;
}
export function toWorkspaceIdentifier(workspace) {
    if (workspace.configuration) {
        return {
            configPath: workspace.configuration,
            id: workspace.id
        };
    }
    if (workspace.folders.length === 1) {
        return workspace.folders[0].uri;
    }
    // Empty workspace
    return undefined;
}
