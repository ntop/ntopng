/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
'use strict';
import * as browsers from '../data/browsers.js';
import { CSSDataManager } from './dataManager.js';
import { CSSDataProvider } from './dataProvider.js';
export * from './entry.js';
export * from './colors.js';
export * from './builtinData.js';
export * from './dataProvider.js';
export * from './dataManager.js';
export var cssDataManager = new CSSDataManager([
    new CSSDataProvider(browsers.cssData)
]);
