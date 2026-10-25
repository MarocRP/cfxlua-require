--[[
    https://github.com/overextended/cfxlua-require

    This file is licensed under MPL-2.0 <https://www.mozilla.org/en-US/MPL/2.0/>

    Copyright © 2026 Linden <https://github.com/thelindat>
]]

if package then
    warn('A module system is already initialised and will be overridden.')
end

-- Aggressively set upvalues to prevent other scripts from overwriting them and changing intended functionality
local type = type
local load = load
local pcall = pcall
local error = error
local assert = assert
local tostring = tostring
local LoadResourceFile = LoadResourceFile
local debug_getinfo = debug.getinfo
local table_concat = table.concat
local table_wipe = table.wipe

local package = {
    path = './?.lua;./?/init.lua',
    preload = {},
    loaded = {},
}

local sentinel = msgpack.sentinel()
local resourceName = GetCurrentResourceName()

---Resolves a module name to its target resource and resource-relative module path.
---@param modName string
---@return string
---@return string
local function getModuleInfo(modName)
    local resource, path = modName:match('^@(.-)/(.+)$')
    resource = resource or modName:match('^@(.+)$')

    if resource then
        return resource, path or 'init'
    end

    local idx = 4

    while true do
        local src = debug_getinfo(idx, 'S')?.source

        if not src then
            return resourceName, modName
        end

        if src ~= 'require' then
            resource = src:match('^@@([^/]+)/.+')

            if resource then
                return resource, modName
            end
        end

        idx += 1
    end
end

local tempData = {}

---@param name string
---@param path string
---@return string? filename
---@return string? errmsg
function package.searchpath(name, path)
    local resource, modName = getModuleInfo(name:gsub('%.', '/'))
    local modulePath = modName:gsub('%.', '/')
    local tried = {}

    for template in path:gmatch('[^;]+') do
        local fileName = template:gsub('^%./', ''):gsub('%?', function() return modulePath end)
        local file = LoadResourceFile(resource, fileName)

        if file then
            tempData[1] = file
            tempData[2] = resource
            return fileName
        end

        tried[#tried + 1] = ("no file '@%s/%s'"):format(resource, fileName)
    end

    return nil, table_concat(tried, "\n\t")
end

---Resolves and compiles a Lua module without executing it.
---@param modName string
---@param env? table
local function loadModule(modName, env)
    local fileName, err = package.searchpath(modName, package.path)

    if fileName then
        local file = tempData[1]
        local resource = tempData[2]

        table_wipe(tempData)

        return assert(load(file, ('@@%s/%s'):format(resource, fileName), 't', env or _ENV)), fileName
    end

    return nil, err or 'unknown error'
end

local lua_require = require

---@alias PackageSearcher
---| fun(modName: string): function, any loader function and data
---| fun(modName: string): nil, string errmsg

---@type PackageSearcher[]
package.searchers = {
    function(modName)
        local ok, result, data = pcall(lua_require, modName)

        if ok then
            return function() return result, data end
        end

        return nil, result
    end,
    function(modName)
        if package.preload[modName] ~= nil then
            return package.preload[modName], ':preload:'
        end

        return nil, ("no field package.preload['%s']"):format(modName)
    end,
    function(modName) return loadModule(modName) end,
}

---Loads the given module, returns any value returned by the seacher (`true` when `nil`).\
---Passing `@resourceName.modName` loads a module from a remote resource.
---@param modName string
---@return unknown module
---@return unknown? loaderdata
function require(modName)
    if type(modName) ~= 'string' then
        error(("module name must be a string (received '%s')"):format(modName), 3)
    end

    local module = package.loaded[modName]

    if module == sentinel then
        error(("circular-dependency occurred while loading module '%s'"):format(modName), 2)
    end

    if module ~= nil then return module end

    package.loaded[modName] = sentinel

    local err = {}

    for i = 1, #package.searchers do
        local loader, data = package.searchers[i](modName)

        if loader then
            local ok, result = pcall(loader, modName, data)

            if ok then
                if result ~= nil then
                    package.loaded[modName] = result
                elseif package.loaded[modName] == sentinel then
                    package.loaded[modName] = true
                end

                return package.loaded[modName], data
            end

            table.wipe(err)

            err[1] = ("an error occurred while loading module '%s'"):format(modName)
            err[2] = tostring(result)

            break
        end

        err[#err + 1] = tostring(data)
    end

    if package.loaded[modName] == sentinel then
        package.loaded[modName] = nil
    end

    error(("%s"):format(table_concat(err, "\n\t")), 2)
end

_ENV.package = package

return require
