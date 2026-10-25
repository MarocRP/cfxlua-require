# cfxlua-require
A standalone implementation of `lua_require` for FiveM and RedM.

Originally part of [ox_lib](https://github.com/overextended/ox_lib), this module has been extracted into its own repository to provide a more standardised, flexible, and reusable module system that can be distributed independently or integrated into other projects.

> [!NOTE]
> `require` relies on dynamically loading files at runtime and inspecting the calling context. As a result, encrypted files (e.g. asset escrow) are not supported, as the required `load` and `debug.getinfo` functionality is unavailable for these files.

## Compatibility

| Behaviour | Lua 5.4 | cfxlua-require |
| --- | --- | --- |
| Module resolution | Searches configured paths using standard Lua searchers. | Resolves Lua files through Cfx.re resource APIs. |
| Module loading | Supports Lua and, where available, C modules and other loader types. | Supports runtime-provided modules, preloaded loaders, and Lua files. |
| Module search context | Resolves modules using the configured search paths. | Resolves unqualified imports relative to the calling resource. |
| `package.path` | Uses filesystem path templates. | Uses resource-relative path templates, defaulting to `./?.lua;./?/init.lua`. |
| `package.searchpath` | Returns a matching filename or `nil` and an error message. | Returns a resource-relative filename or `nil` and an error message. |
| `package.searchers` | Uses standard searchers for preload, Lua, C, and other supported module types. | Checks the runtime's native `require`, `package.preload`, and Lua files, in that order. |
| `package.loaded` | Caches loaded modules. | Caches module results and detects circular loading using an internal sentinel. |

## Additional features

| Feature | Description |
| --- | --- |
| Cross-resource imports | Load modules from other resources using the `@resourceName.moduleName` syntax. |
| Resource-aware resolution | Automatically determines the calling resource for unqualified module names. |
| Circular dependency detection | Raises an error when a module is required recursively while it is still being initialised. |

## Changes from ox_lib
- `package.loaded` is now mutable, matching the behaviour of Lua 5.4
- Circular dependencies now use a sentinel value rather than `'__loading'`.
- Loader errors now clear sentinel values and report information more clearly.
- `loadfile`, `dofile`, functions are now provided, replacing the `lib.load` with Lua-like behaviour.
- `lib.loadJson` is instead assigned to `json.load`.
- Resource resolution using `debug.getinfo` now resolves the initial call depth and chunk name, rather than using static values.
- Explicit error levels help distinguish module execution errors from search failures.
- `require` now returns `loaderdata` when the module is first loaded, matching Lua behaviour.

Note that ox_lib itself still provides both `lib.load` and `lib.loadJson` functions for backwards compatibility.

## License

This project is licensed under [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/). A complete copy of the license is included in [LICENSE](./LICENSE).

Copyright © 2026 [Linden](https://github.com/thelindat)
