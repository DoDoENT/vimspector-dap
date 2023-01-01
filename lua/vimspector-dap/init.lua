local dap = require( 'dap' )
local dapui = require( 'dapui' )
local Path = require( 'plenary.path' )

local function getKeys( tbl )
    local keys = {}
    for k, _ in pairs( tbl ) do
        table.insert( keys, k )
    end
    return keys
end

local function replaceVimspectorVariables( config )
    local workspaceRoot = vim.loop.cwd()
    for k, v in pairs( config ) do
        if type( v ) == 'string' then
            config[ k ] = v:gsub( '${workspaceRoot}', workspaceRoot )
        end
    end
end

local function runSelectedVimspectorConfig( configurations, selectedConfig )
    local config = configurations[ selectedConfig ]
    local dap_config = config.configuration
    -- override/add type setting, as that is different between dap and vimspector
    if dap_config.type == nil or dap_config.type == '' then
        dap_config.type = string.lower( config.adapter )
    end
    replaceVimspectorVariables( dap_config )
    dap.run( dap_config )

    vim.api.nvim_command( 'cclose' )
    dapui.open()
end

local vimspectorConfig = '.vimspector.json'

local function getVimspectorConfigurations()
    if not Path:new( vimspectorConfig ):exists() then
        vim.notify( 'No .vimspector.json file found. Nothing to run', vim.log.levels.ERROR, { title = 'vimspector-dap' } )
        return
    end
    local vimspectorJson = vim.json.decode( Path:new( vimspectorConfig ):read() )
    return vimspectorJson.configurations
end

local function saveVimspectorConfigurations( configurations )
    local savePath = Path:new( vimspectorConfig )
    savePath:write( vim.json.encode( { configurations = configurations } ), 'w' )
    vim.fn.system( 'python3 -m json.tool ' .. tostring( savePath ) .. ' ' .. tostring( savePath ) )

    local bufnr = vim.fn.bufnr( vimspectorConfig )
    if bufnr ~= -1 then
        vim.cmd( 'silent checktime ' .. bufnr )
    end
end

-- Asks user to select one of the existing vimspector configuration and starts debugging session via DAP UI
local function runVimspectorConfigOnDap()
    local configurations = getVimspectorConfigurations()
    if configurations == nil then
        vim.notify( 'Missing "configurations" entry in .vimspector.json. Nothing to run', vim.log.levels.ERROR, { title = 'vimspector-dap' } )
        return
    end

    -- ask user to select configuration
    vim.ui.select( getKeys( configurations ), { prompt = 'Select vimspector configuration' }, function( choice, idx )
        if not idx then
            return
        end
        runSelectedVimspectorConfig( configurations, choice )
    end)
end

-- Starts debugging session via DAP UI for given vimspector configuration name
-- @param selectedConfig string: name of the vimspector configuration
local function runSelectedVimspectorConfigOnDap( selectedConfig )
    local configurations = getVimspectorConfigurations()
    if configurations == nil then
        vim.notify( 'Missing "configurations" entry in .vimspector.json. Nothing to run', vim.log.levels.ERROR, { title = 'vimspector-dap' } )
        return
    end

    runSelectedVimspectorConfig( configurations, selectedConfig )
end

-- Returns the command line arguments for specific vimspector configuration
-- @param selectedConfig string: name of the vimspector configuration
local function getConfigArgs( selectedConfig )
    local configurations = getVimspectorConfigurations()
    if configurations == nil then
        return nil
    end
    local config = configurations[ selectedConfig ]
    if config == nil then
        return nil
    end
    return config.configuration.args
end

-- Updates vimspector c++ configuration entry with new path to executable, arguments and debug adapter. If configuration does not exist, a new one will be automatically created.
-- @param configName string: name of the vimspector configuration.
-- @param executablePath string: path to the executable that will be debugged
-- @param args table?: list of arguments that will be given to the executable on startup
-- @param adapter string?: name of the debug adapter that will be used
local function updateCppConfiguration( configName, executablePath, args, adapter )
    adapter = adapter and adapter or 'CodeLLDB'
    args = args and args or {}

    local configurations = getVimspectorConfigurations()
    configurations = configurations and configurations or { configurations = {} }
    local cppConfig = configurations[ configName ] and configurations[ configName ] or {
        adapter = adapter,
        configuration = {
            cwd = "${workspaceRoot}",
            request = "launch"
        }
    }
    cppConfig.configuration.args = args
    cppConfig.configuration.program = executablePath

    configurations[ configName ] = cppConfig

    saveVimspectorConfigurations( configurations )
end

-- Updates vimspector c++ configuration entry with new path to executable and debug adapter. If configuration does not exist, a new one will be automatically created.
-- @param configName string: name of the vimspector configuration.
-- @param executablePath string: path to the executable that will be debugged
-- @param adapter string?: name of the debug adapter that will be used
local function updateCppExePath( configName, executablePath, adapter )
    adapter = adapter and adapter or 'CodeLLDB'

    local configurations = getVimspectorConfigurations()
    configurations = configurations and configurations or { configurations = {} }
    local cppConfig = configurations[ configName ] and configurations[ configName ] or {
        adapter = adapter,
        configuration = {
            cwd = "${workspaceRoot}",
            request = "launch"
        }
    }
    cppConfig.configuration.program = executablePath

    configurations[ configName ] = cppConfig

    saveVimspectorConfigurations( configurations )
end

return {
    runVimspectorConfigOnDap = runVimspectorConfigOnDap,
    runSelectedVimspectorConfigOnDap = runSelectedVimspectorConfigOnDap,
    getVimspectorConfigurationArgs = getConfigArgs,
    updateVimspectorCppConfiguration = updateCppConfiguration,
    updateVimspectorCppExecutablePath = updateCppExePath,
}
