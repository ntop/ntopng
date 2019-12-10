var SyncDescriptor = /** @class */ (function () {
    function SyncDescriptor(ctor, staticArguments, supportsDelayedInstantiation) {
        if (staticArguments === void 0) { staticArguments = []; }
        if (supportsDelayedInstantiation === void 0) { supportsDelayedInstantiation = false; }
        this.ctor = ctor;
        this.staticArguments = staticArguments;
        this.supportsDelayedInstantiation = supportsDelayedInstantiation;
    }
    return SyncDescriptor;
}());
export { SyncDescriptor };
