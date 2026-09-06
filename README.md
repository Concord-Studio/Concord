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

Start with **[Get Started](docs/Get%20Started.md)**. It covers Worlds, Components, Entities, Filters, Systems, and Events.

### Guides

- [Why ECS?](docs/Why%20ECS.md) — when Concord (and ECS in general) is a good fit
- [Custom Pools](docs/Custom%20Pools.md) — using a different data structure than the default Pool list
- [Pool Flushing and Timing](docs/Pool%20Flushing%20and%20Timing.md) — when Filters update, and how that interacts with Events

API reference is generated with LDoc and published on the [GitHub page](https://keyslam-group.github.io/Concord/).

## Contributors

- **Pablo Mayobre**: Rewrite, constant support and a good rubberduck
- **Brbl**: Early testing and issue reporting
- **Josh**: Squashed a few bugs and generated docs
- **Erasio**: I took inspiration from HooECS. He also introduced me to ECS
- **Speak**: Lots of testing for new features of Concord
- **Tesselode**: Brainstorming and helpful support

## License

MIT Licensed - Copyright Justin van der Leij (Tjakka5)
