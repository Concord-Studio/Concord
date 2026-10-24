# Concord

Concord is a feature complete library that allows you to use the Entity - Component - System (ECS) model to write and organize your Lua code.

Concord puts a lot of effort on being easy to use and provide a great developer experience, while trying to be competitive in performance with alternative libraries.

## Installation

Download this repository and add the `concord` folder to your project. Then import it:

```lua
local Concord = require("path.to.concord")
```

> [!NOTE]
> The file imported should be `concord/init.lua`. Some Lua runtimes will allow you to require `concord`, but others will need `concord.init`.

## Documentation

User guides and API reference live at [concord.studio](https://concord.studio).

## Contributors

- **Keyslam**: Author, great ideas, cool guy
- **Pablo Mayobre**: Rewrite, constant support and a good rubberduck
- **Brbl**: Early testing and issue reporting
- **Josh**: Squashed a few bugs and generated docs
- **Erasio**: I took inspiration from HooECS. He also introduced me to ECS
- **Speak**: Lots of testing for new features of Concord
- **Tesselode**: Brainstorming and helpful support

## License

MIT Licensed - Copyright Justin van der Leij (Tjakka5/Keyslam)
