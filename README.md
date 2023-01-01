vimspector-dap
=====================

This plugin bridges the gap between [puremourning/vimspector](https://github.com/puremourning/vimspector) and [rcarriga/nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui). It provides useful functions for selecting the existing configuration in `.vimspector.json` file and starting the debugging session on `nvim-dap-ui`.

The idea behind this plugin is to provide support for easier migration from `Vimspector` to `nvim-dap`. While `Vimspector` is more mature and has support for persisting debug configurations in `.vimspector.json` file, `nvim-dap` is more modern, a lot faster, and better supported in Neovim. However, `nvim-dap` does not have support for persisting debug configurations in practical JSON files and expects users to always edit some Lua code to setup the debugging session. This plugin let's you re-use your existing `.vimspector.json` debugging configurations after migrating to `nvim-dap`.

# Installation

Add following line to your packer configuration:

```lua
use {
    'DoDoENT/vimspector-dap',
    requires = {
        { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } },
        { 'nvim-lua/plenary.nvim' }
    }
}
```

# Usage

Plugin will not register any commands nor mappings - it will only provide utility functions that you can use as building block in your plugin or in your mapping.

For example, to map `F5` to start debugging your existing vimspector configuration, use

```lua
vim.keymap.set( "n", "<F5>", require( 'vimspector-dap' ).runVimspectorConfigOnDap, { silent = true } )
```

Feel free to investigate other [functions](https://github.com/DoDoENT/vimspector-dap/blob/master/lua/vimspector-dap/init.lua) and use them for your benefit.

# Example with [DoDoENT/neovim-additional-tasks](https://github.com/DoDoENT/neovim-additional-tasks)

This example will create a new user command that will set new command line parameters to currently active CMake target and will also update local `.vimspector.json` file for easier debugging:

```lua
local ProjectConfig = require( 'tasks.project_config' )
local cmake_utils = require( 'tasks.cmake_kits_utils' )
local utils = require('tasks.utils')
local vimspector = require( 'vimspector-dap' )

-- runs cmake target with given arguments, but also saves those arguments to
-- .vimspector.json for future use
function SetCMakeRunArgumentsAndRun( args )
    local project_config = ProjectConfig:new()
    local argsArray = utils.split_args( args )
    project_config[ 'cmake_kits' ][ 'args' ][ 'run'   ] = argsArray
    project_config[ 'cmake_kits' ][ 'args' ][ 'debug' ] = argsArray
    project_config:write()

    local target, executable = cmake_utils.getCurrentTargetAndExePath()
    vimspector.updateVimspectorCppConfiguration( target, executable, argsArray )

    vim.cmd( [[Task start cmake_kits run]] )
end
vim.cmd( [[command! -nargs=? CMakeSetParamsAndRun lua SetCMakeRunArgumentsAndRun(<f-args>)]] )
vim.keymap.set( "n", "<leader>cR", [[:CMakeSetParamsAndRun ]] )

-- updates the path to executable in .vimspector.json
-- useful after changing CMake build type or build kit
local function updateVimspectorExe()
    local target, executable = cmake_utils.getCurrentTargetAndExePath()

    local vimspector = require( 'vimspector-dap' )
    vimspector.updateVimspectorCppExecutablePath( target, executable )

    vim.notify( 'Update vimspector executable path for target ' .. target .. ' to: ' .. vim.inspect( executable ), vim.log.levels.INFO, { title = 'cmake-tasks' } )
end
vim.keymap.set( "n", "<leader>cs", updateVimspectorExe )

-- loads program arguments from .vimspector.json into cmake_kits tasks module
local function loadVimspectorArgs()
    local project_config = ProjectConfig:new()

    local target = project_config[ 'cmake_kits' ].target
    if target == nil or target == 'all' then
        vim.notify( "Please select a runnable target!", vim.log.levels.ERROR, { title = 'cmake-tasks' } )
        return
    end

    local args = vimspector.getVimspectorConfigurationArgs( target )
    local cmake_kits_config = project_config[ 'cmake_kits' ]
    if not cmake_kits_config.args then
        cmake_kits_config.args = {}
    end
    cmake_kits_config.args.run   = args
    cmake_kits_config.args.debug = args
    project_config:write()

    vim.notify( 'Arguments for target ' .. target .. ' loaded and set to: ' .. vim.inspect( args ), vim.log.levels.INFO, { title = 'cmake-tasks' } )
end
vim.keymap.set( "n", "<leader>cl", loadVimspectorArgs )
```
