--! @brief Check if the specified path is a directory.
--! @param path to check.
--! @return true if it's a direcory, false otherwise.
function ntop.isdir(string path)

--! @brief Create the specified directory structure.
--! @param path the directory tree to create.
--! @return true on success, false otherwise.
function ntop.mkdir(string path)

--! @brief Check if the specified file is not empty.
--! @param filename the file to check.
--! @return true if file is not empty, false otherwise.
function ntop.notEmptyFile(string filename)

--! @brief Check if the specified file or directory exists.
--! @param path the path to check.
--! @return true if the path exists, false otherwise.
function ntop.exists(string path)

--! @brief Get the last time the specified file has changed.
--! @param filename the file to query.
--! @return last modification time on success, -1 otherwise.
function ntop.fileLastChange(string filename)

--! @brief List directory files and dirs contents.
--! @param path the directory to traverse.
--! @return table (entry_name -> entry_name) on success, nil otherwise.
function ntop.readdir(string path)

--! @brief Recursively remove a file or directory.
--! @param path the path to remove.
function ntop.rmdir(string path)

--! @brief Dump a file contents to the webserver.
--! @param path the file path.
function ntop.dumpBinaryFile(string path)

--! @brief Set the default ntopng file permissions on the given path.
--! @param file_path the path to the file
--! @note this function can fix some permission mismatches on Ubuntu 18.
function ntop.setDefaultFilePermissions(string file_path)

--! @brief Delete RRDs older than the specified deadline.
--! @param ifpath starting path for the delete operation
--! @param deadline maximum modification date for the files
function ntop.deleteOldRRDs(string ifpath, int deadline)
