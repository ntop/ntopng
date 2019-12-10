// Common data transfers
export var DataTransfers = {
    /**
     * Application specific resource transfer type
     */
    RESOURCES: 'ResourceURLs',
    /**
     * Browser specific transfer type to download
     */
    DOWNLOAD_URL: 'DownloadURL',
    /**
     * Browser specific transfer type for files
     */
    FILES: 'Files',
    /**
     * Typically transfer type for copy/paste transfers.
     */
    TEXT: 'text/plain'
};
var DragAndDropData = /** @class */ (function () {
    function DragAndDropData(data) {
        this.data = data;
    }
    DragAndDropData.prototype.update = function () {
        // noop
    };
    DragAndDropData.prototype.getData = function () {
        return this.data;
    };
    return DragAndDropData;
}());
export { DragAndDropData };
export var StaticDND = {
    CurrentDragAndDropData: undefined
};
