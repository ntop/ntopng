/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import BaseSeverity from '../../../base/common/severity.js';
import { createDecorator } from '../../instantiation/common/instantiation.js';
export var Severity = BaseSeverity;
export var INotificationService = createDecorator('notificationService');
var NoOpNotification = /** @class */ (function () {
    function NoOpNotification() {
    }
    return NoOpNotification;
}());
export { NoOpNotification };
