--- Helper module for misc operations
-- @module Utils

local Utils = {}

--- Raises a formatted error.
-- @int level Error level passed to error(), plus one
-- @string str Format string
-- @param ... Format arguments
function Utils.error(level, str, ...)
    error(string.format(str, ...), level + 1)
end

--- Copies keys from orig into target. Existing keys in target are overwritten.
-- @tparam table orig Table to copy from
-- @tparam table target Table to copy into
-- @treturn table target
function Utils.shallowCopy(orig, target)
   for key, value in pairs(orig) do
      target[key] = value
   end

   return target
end

--- Requires files and stores them in a namespace table.
-- Accepts a table of require paths: {"path/to/file_1", "path/to/another/file_2", "etc"}
-- Accepts a path to a directory of Lua files: "my_files/here"
-- Directory loading uses love.filesystem and requires LÖVE.
-- If namespace is omitted, files are still required and this function returns nil.
-- @param pathOrFiles A directory path or a table of require paths
-- @tparam[opt] table namespace Table that will hold the required files
-- @treturn table|nil The namespace table
function Utils.loadNamespace(pathOrFiles, namespace)
   if type(pathOrFiles) ~= "string" and type(pathOrFiles) ~= "table" then
       Utils.error(2, "bad argument #1 to 'loadNamespace' (string/table of strings expected, got %s)", type(pathOrFiles))
   end

   if type(pathOrFiles) == "string" then
       local info = love.filesystem.getInfo(pathOrFiles) -- luacheck: ignore
       if info == nil or info.type ~= "directory" then
            Utils.error(2, "bad argument #1 to 'loadNamespace' (path '%s' not found)", pathOrFiles)
       end

       local files = love.filesystem.getDirectoryItems(pathOrFiles)

       for _, file in ipairs(files) do
            local isFile = love.filesystem.getInfo(pathOrFiles .. "/" .. file).type == "file"

            if isFile and string.match(file, '%.lua$') ~= nil then
                 local name = file:sub(1, #file - 4)
                 local path = pathOrFiles.."."..name

                 local value = require(path:gsub("%/", "."))
                 if namespace then namespace[name] = value end
            end
       end
   elseif type(pathOrFiles) == "table" then
       for _, path in ipairs(pathOrFiles) do
            if type(path) ~= "string" then
                Utils.error(2, "bad argument #2 to 'loadNamespace' (string/table of strings expected, got table containing %s)", type(path)) -- luacheck: ignore
            end

            local name = path

            local dotIndex, slashIndex = path:match("^.*()%."), path:match("^.*()%/")
            if dotIndex or slashIndex then
                name = path:sub((dotIndex or slashIndex) + 1)
            end

            local value = require(path:gsub("%/", "."))
            if namespace then namespace[name] = value end
       end
   end

   return namespace
end

return Utils
