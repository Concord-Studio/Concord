# Getting Started

Concord is a feature complete library that allows you to use Entity - Component - System (ECS) model  to write and organize your Lua code.

Concord puts a lot of effort on being easy to use and provide a great developer experience, while trying to be competitive in performance with alternative libraries.

## Installation

As a first step you will need to download this repository and add the `concord` folder to your project.

In that folder you will find all the necessary files to use Concord.

Once added you can import Concord in your code

```lua
local Concord = require("path.to.concord")
```

> [!NOTE]
> Please note that the file imported should be `concord/init.lua`, some Lua runtimes will allow you to require `concord` but others will need `concord.init`

### World

The first thing you will define with Concord is a World.

The World will provide a single interaction point for all our Systems, and will hold all our Entities.

We will explain those concepts later, but first we need a World:

```lua
local world = Concord.World()
```

### Components

You can think of Components as the data and state that make up all of your game.
Components themselves don't exist as part of our World, they instead are the pieces that build up Entities.

Components have a name, and some arbitrary shape that you can define.
For example if we wanted to store the Position of a given Entity, we would define a component called `position` with a shape that could be something like `{x: number, y: number}`

In Concord this would look like this:

```lua
Concord.Component("position", function (component, x, y)
  component.x = x
  component.y = y
end)
```

The first argument is the name, and the second is what we call the **populate** function.
Components start as empty tables and this **populate** function assigns the values for each of the Component properties.

Sometimes you don't need to store data on the Component since the Component itself will act as a flag, in those cases you don't need to provide a **populate** function:

```lua
Concord.Component("terrestrial")
```

> [!NOTE]
> All Components are registered to Concord itself, not to a specific World.
> This is why all the Components you define, regardless of the World you use them in, MUST have different names, two different Components can't share a name.

### Entities

In ECS everything that exists as part of the World is an Entity. An Entity could be a Player, an Enemy, a Crate, a Bullet, etc.

Entities by themselves are empty packages with nothing on them, and they would all behave the same if we left them like that. To tell them appart and give unique data to each of them, we need to give them some Components.

In Concord this is very simple:

```lua
local Cat = world:newEntity()
--local Cat = Concord.Entity(world) -- Alternative syntax

Cat:give("position", 50, 50)
Cat:give("terrestrial")
```

Once you give a Component to an Entity, the Component will become a part of it:

```lua
print(Cat.position.x, Cat.position.y) -- Prints: 50, 50

if Cat.terrestrial then print("Walks!") end -- Prints: Walks! 
```

> [!NOTE]
> Any Component can be given to any Entity ONCE. You can't give a Component multiple times, giving the same Component one more time will override the previous instance of the Component.

### Filters

The power of Concord and ECS in general comes from grouping a bunch of Entities based on rules. These rules acts as a Filter where we can ask the World for all Entities that have all the Components we required.

For example we could ask the World for a list of all the Entities that are `terrestrial` and have a `position`, and that are not a `machine`:

```lua
local animals = world:query({ "terrestrial", "position", "!machine" }) -- The ! in front of machine indicates negation

for i, entity in ipairs(animals) do
  print(entity.position.x, entity.position.y)
end
```

<!-- markdownlint-disable MD033 -->
<details><summary>Side note on Filter rules</summary>

> If we had another Entity like this one:
>
> ```lua
> local Parrot = world:newEntity()
> 
> Parrot:give("position", 100, 100)
> ```
>
> It would not be part of our list above, since the filter required:
>
> _`terrestrial` and `position` and not `machine`_
>
> And although Parrot has `position` and doesn't have `machine`, it lacks the `terrestrial` Component.

</details>
<!-- markdownlint-enable MD033 -->

This is great but the `World:query` operation is rather expensive, so Concord instead provides Pools.
A Pool has an associated Filter and will be updated when Entities are added or modified in the World.

In order to use pools however, we need to speak about Systems

### Systems

In ECS, Components and Entities generally don't have behavior themselves, and instead rely on Systems that define how a group of Entities should behave.

For example if we want all terrestrial animals to move 5 pixels to the right every time we receive a `move` event we would first create a System like:

```lua
local Movement = Concord.System("Movement", {animals = { "terrestrial", "position" }})
```

This system is called `Movement` and has a Pool called `animals` that contains all the Entities with `terrestrial` and `position` Components.

We now want to receive all `move` events. To do that we define a callback in our System like so:

```lua
function Movement:move ()
  for i, entity in ipairs(self.animals) do
    entity.position.x = entity.position.x + 5
  end
end
```

Whenever we receive a `move` event in our World, this callback will execute, and the Movement System will iterate through the Pool of animals changing their position Components to move them 5 pixels to the right.

### Events

In the previous section we defined a `move` callback, but we don't yet know how to execute that callback.

To do that first the System needs to be added to our World

```lua
world:addSystem(Movement)
```

> [!NOTE]
> You can add each System once to a given World.
> A System can be added to multiple Worlds (they will be different/separate instances of the System).

Finally we need to fire the `move` event, to do that, we don't call the System directly, instead we emit the event to the World

```lua
world:emit("move")
```

Once emitted, all the Systems that define a `move` callback will be called in the order they were added to the World.

You can also provide extra arguments to these events, for example if we had:

```lua
function Movement:update(dt)
  -- Do something here
end
```

You could provide the `dt` argument like so:

```lua
world:emit("update", 5) --dt = 5
```

### Summary

We defined a few big terms and how they are used in Concord, but to summarize them:

- **World**: This is where Entities and Systems live, it receives external and internal Events.
- **Components**: Data and state, each with a name and a shape. Each Component describes a specific aspect of an Entity.
- **Entities**: Everything that exists in the World. They are bundles of Components.
- **Filters**: A way to group Entities based on the Components they have or don't have.
- **Systems**: Behaviors that apply to groups of Entities and react to Events received by the World.
- **Events**: Signals that tell the World something happened or needs to happen, the World delegates the Events to all the Systems that can respond to it.

These are Concord definitions, and although they may apply to other ECS libraries or frameworks, some differences may exist.

With this we have covered the basics. Continue with [Components](guides/Components.md.html), then [Entities](guides/Entities.md.html), [Systems](guides/Systems.md.html), and [Worlds](guides/Worlds.md.html). After those, [Making a game with Concord and LÖVE](guides/Making-a-Game.md.html) brings everything together.

If you don't see the benefits, consider reading [Why ECS?](guides/Why-ECS.md.html), this goes into the design decisions made with Concord.
