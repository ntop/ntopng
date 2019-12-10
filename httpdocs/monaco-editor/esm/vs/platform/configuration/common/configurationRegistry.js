/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as nls from '../../../nls.js';
import { Emitter } from '../../../base/common/event.js';
import { Registry } from '../../registry/common/platform.js';
import * as types from '../../../base/common/types.js';
import * as strings from '../../../base/common/strings.js';
import { Extensions as JSONExtensions } from '../../jsonschemas/common/jsonContributionRegistry.js';
export var Extensions = {
    Configuration: 'base.contributions.configuration'
};
export var allSettings = { properties: {}, patternProperties: {} };
export var applicationSettings = { properties: {}, patternProperties: {} };
export var machineSettings = { properties: {}, patternProperties: {} };
export var machineOverridableSettings = { properties: {}, patternProperties: {} };
export var windowSettings = { properties: {}, patternProperties: {} };
export var resourceSettings = { properties: {}, patternProperties: {} };
export var editorConfigurationSchemaId = 'vscode://schemas/settings/editor';
var contributionRegistry = Registry.as(JSONExtensions.JSONContribution);
var ConfigurationRegistry = /** @class */ (function () {
    function ConfigurationRegistry() {
        this.overrideIdentifiers = [];
        this._onDidSchemaChange = new Emitter();
        this._onDidUpdateConfiguration = new Emitter();
        this.defaultOverridesConfigurationNode = {
            id: 'defaultOverrides',
            title: nls.localize('defaultConfigurations.title', "Default Configuration Overrides"),
            properties: {}
        };
        this.configurationContributors = [this.defaultOverridesConfigurationNode];
        this.editorConfigurationSchema = { properties: {}, patternProperties: {}, additionalProperties: false, errorMessage: 'Unknown editor configuration setting', allowsTrailingCommas: true, allowComments: true };
        this.configurationProperties = {};
        this.excludedConfigurationProperties = {};
        this.computeOverridePropertyPattern();
        contributionRegistry.registerSchema(editorConfigurationSchemaId, this.editorConfigurationSchema);
    }
    ConfigurationRegistry.prototype.registerConfiguration = function (configuration, validate) {
        if (validate === void 0) { validate = true; }
        this.registerConfigurations([configuration], validate);
    };
    ConfigurationRegistry.prototype.registerConfigurations = function (configurations, validate) {
        var _this = this;
        if (validate === void 0) { validate = true; }
        var properties = [];
        configurations.forEach(function (configuration) {
            properties.push.apply(properties, _this.validateAndRegisterProperties(configuration, validate)); // fills in defaults
            _this.configurationContributors.push(configuration);
            _this.registerJSONConfiguration(configuration);
            _this.updateSchemaForOverrideSettingsConfiguration(configuration);
        });
        this._onDidSchemaChange.fire();
        this._onDidUpdateConfiguration.fire(properties);
    };
    ConfigurationRegistry.prototype.registerOverrideIdentifiers = function (overrideIdentifiers) {
        var _a;
        (_a = this.overrideIdentifiers).push.apply(_a, overrideIdentifiers);
        this.updateOverridePropertyPatternKey();
    };
    ConfigurationRegistry.prototype.validateAndRegisterProperties = function (configuration, validate, scope, overridable) {
        if (validate === void 0) { validate = true; }
        if (scope === void 0) { scope = 3 /* WINDOW */; }
        if (overridable === void 0) { overridable = false; }
        scope = types.isUndefinedOrNull(configuration.scope) ? scope : configuration.scope;
        overridable = configuration.overridable || overridable;
        var propertyKeys = [];
        var properties = configuration.properties;
        if (properties) {
            for (var key in properties) {
                var message = void 0;
                if (validate && (message = validateProperty(key))) {
                    console.warn(message);
                    delete properties[key];
                    continue;
                }
                // fill in default values
                var property = properties[key];
                var defaultValue = property.default;
                if (types.isUndefined(defaultValue)) {
                    property.default = getDefaultValue(property.type);
                }
                // Inherit overridable property from parent
                if (overridable) {
                    property.overridable = true;
                }
                if (OVERRIDE_PROPERTY_PATTERN.test(key)) {
                    property.scope = undefined; // No scope for overridable properties `[${identifier}]`
                }
                else {
                    property.scope = types.isUndefinedOrNull(property.scope) ? scope : property.scope;
                }
                // Add to properties maps
                // Property is included by default if 'included' is unspecified
                if (properties[key].hasOwnProperty('included') && !properties[key].included) {
                    this.excludedConfigurationProperties[key] = properties[key];
                    delete properties[key];
                    continue;
                }
                else {
                    this.configurationProperties[key] = properties[key];
                }
                propertyKeys.push(key);
            }
        }
        var subNodes = configuration.allOf;
        if (subNodes) {
            for (var _i = 0, subNodes_1 = subNodes; _i < subNodes_1.length; _i++) {
                var node = subNodes_1[_i];
                propertyKeys.push.apply(propertyKeys, this.validateAndRegisterProperties(node, validate, scope, overridable));
            }
        }
        return propertyKeys;
    };
    ConfigurationRegistry.prototype.getConfigurationProperties = function () {
        return this.configurationProperties;
    };
    ConfigurationRegistry.prototype.registerJSONConfiguration = function (configuration) {
        function register(configuration) {
            var properties = configuration.properties;
            if (properties) {
                for (var key in properties) {
                    allSettings.properties[key] = properties[key];
                    switch (properties[key].scope) {
                        case 1 /* APPLICATION */:
                            applicationSettings.properties[key] = properties[key];
                            break;
                        case 2 /* MACHINE */:
                            machineSettings.properties[key] = properties[key];
                            break;
                        case 5 /* MACHINE_OVERRIDABLE */:
                            machineOverridableSettings.properties[key] = properties[key];
                            break;
                        case 3 /* WINDOW */:
                            windowSettings.properties[key] = properties[key];
                            break;
                        case 4 /* RESOURCE */:
                            resourceSettings.properties[key] = properties[key];
                            break;
                    }
                }
            }
            var subNodes = configuration.allOf;
            if (subNodes) {
                subNodes.forEach(register);
            }
        }
        register(configuration);
    };
    ConfigurationRegistry.prototype.updateSchemaForOverrideSettingsConfiguration = function (configuration) {
        if (configuration.id !== SETTINGS_OVERRRIDE_NODE_ID) {
            this.update(configuration);
            contributionRegistry.registerSchema(editorConfigurationSchemaId, this.editorConfigurationSchema);
        }
    };
    ConfigurationRegistry.prototype.updateOverridePropertyPatternKey = function () {
        var patternProperties = allSettings.patternProperties[this.overridePropertyPattern];
        if (!patternProperties) {
            patternProperties = {
                type: 'object',
                description: nls.localize('overrideSettings.defaultDescription', "Configure editor settings to be overridden for a language."),
                errorMessage: 'Unknown Identifier. Use language identifiers',
                $ref: editorConfigurationSchemaId
            };
        }
        delete allSettings.patternProperties[this.overridePropertyPattern];
        delete applicationSettings.patternProperties[this.overridePropertyPattern];
        delete machineSettings.patternProperties[this.overridePropertyPattern];
        delete machineOverridableSettings.patternProperties[this.overridePropertyPattern];
        delete windowSettings.patternProperties[this.overridePropertyPattern];
        delete resourceSettings.patternProperties[this.overridePropertyPattern];
        this.computeOverridePropertyPattern();
        allSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
        applicationSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
        machineSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
        machineOverridableSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
        windowSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
        resourceSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
        this._onDidSchemaChange.fire();
    };
    ConfigurationRegistry.prototype.update = function (configuration) {
        var _this = this;
        var properties = configuration.properties;
        if (properties) {
            for (var key in properties) {
                if (properties[key].overridable) {
                    this.editorConfigurationSchema.properties[key] = this.getConfigurationProperties()[key];
                }
            }
        }
        var subNodes = configuration.allOf;
        if (subNodes) {
            subNodes.forEach(function (subNode) { return _this.update(subNode); });
        }
    };
    ConfigurationRegistry.prototype.computeOverridePropertyPattern = function () {
        this.overridePropertyPattern = this.overrideIdentifiers.length ? OVERRIDE_PATTERN_WITH_SUBSTITUTION.replace('${0}', this.overrideIdentifiers.map(function (identifier) { return strings.createRegExp(identifier, false).source; }).join('|')) : OVERRIDE_PROPERTY;
    };
    return ConfigurationRegistry;
}());
var SETTINGS_OVERRRIDE_NODE_ID = 'override';
var OVERRIDE_PROPERTY = '\\[.*\\]$';
var OVERRIDE_PATTERN_WITH_SUBSTITUTION = '\\[(${0})\\]$';
export var OVERRIDE_PROPERTY_PATTERN = new RegExp(OVERRIDE_PROPERTY);
export function getDefaultValue(type) {
    var t = Array.isArray(type) ? type[0] : type;
    switch (t) {
        case 'boolean':
            return false;
        case 'integer':
        case 'number':
            return 0;
        case 'string':
            return '';
        case 'array':
            return [];
        case 'object':
            return {};
        default:
            return null;
    }
}
var configurationRegistry = new ConfigurationRegistry();
Registry.add(Extensions.Configuration, configurationRegistry);
export function validateProperty(property) {
    if (OVERRIDE_PROPERTY_PATTERN.test(property)) {
        return nls.localize('config.property.languageDefault', "Cannot register '{0}'. This matches property pattern '\\\\[.*\\\\]$' for describing language specific editor settings. Use 'configurationDefaults' contribution.", property);
    }
    if (configurationRegistry.getConfigurationProperties()[property] !== undefined) {
        return nls.localize('config.property.duplicate', "Cannot register '{0}'. This property is already registered.", property);
    }
    return null;
}
