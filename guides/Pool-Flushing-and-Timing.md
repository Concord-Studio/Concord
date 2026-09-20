# Pool Flushing and Timing

This article will help you understand when the Pools' Filters get synchronized with the latest changes to Entities in the World, the relationship with Events, how it affects your game and how you can avoid the default behaviors.

## Synchronous Operations

Concord has a synchronous part and an asynchronous part. For the most part you'll be using the synchronous part, so whenever you make a change, most of the things update immediately, for example, giving a component, removing a component, getting a reference to an entity, sorting a  pool and many others are synchronous operations, they execute immediately when you perform them and you can see the effects in real time.

```lua

entity:give("position", 10, 20)

entity.position -- { x = 10, y = 20 }

entity.position.x = 30

entity.position -- { x = 30, y = 20 }

world:emit("update") -- All Systems with an update listener are called immediately 
                     -- in the order you added them to the World

```

As you can see most operations are immediate and you can see the results right after

## Asynchronous Operations

There is one place however where we can't have immediate updates without introducing other sets of issues. That is Pools and Filters.

As discussed in the [Systems](Systems.md) guide, all Pools have an associated Filter. This Filter specifies the requirements Entities should have to be in the Pool. The one checking that Pools have all the Entities that meet their requirements is the World.

### Syncing the Pools

In order to make sure that the Pools have the Entities they need, the World goes through all the necessary Entities and checks them against the filters of every Pool, one by one. This is a very expensive operation which we call Flush.

You can actually trigger a Flush manually through `World:flush()` and you may sometimes want to do so. We will discuss the use cases later on.

### When do we sync?

Entities change a lot, we often change multiple Components one after the other, add Entities in bulk, apply Assemblages that give multiple Components at once, delete a bunch of Entities that died simultaneously and so on.

The World gets notified of ALL these changes, then keeps track of all the Entities that have been changed, removed, or added to the World, and waits until it's ready to perform a Flush.

Flushes can be manually triggered as we previously discussed, but Concord also has a built-in mechanism for flushes to happen automatically.

### When can the sync cause issues?

A sync performs additions and removals on Pools, so the biggest issue it can create is if you were iterating over one Pool, and suddenly the Entities inside were to shift around. This is not a problem with Concord, its List implementation or flushes, this also happens in regular Lua:

```lua
for k, v in ipairs(t) do
  table.insert(t, 1, k) -- This has undefined behavior and can cause an infinite loop
  print(k, v)
end
```

So it's not a good idea to add or remove inside to the current Pool we are iterating on. So we should not flush while we iterate. These iterations generally happen inside event listeners inside your Systems, since that's where Pools live, so we shouldn't flush while a System's event listener is executing.

### `World:emit()`

Concord tries to keep the list of Entities consistent through an entire `emit` event and won't automatically flush until the Event is over. This is so that if System A and System B handle the same event their Pools are consistent with each other, this assumption may be broken if `World:flush()` is called manually, but that's an explicit choice by the user.

The best time for the automatic flush then is before the Event is forwarded to the Systems, it's a spot where no updates are being made, no iteration is going on, the World has complete control of the main thread.

However `World:emit()` can be called from inside `World:emit()` so Concord makes sure that by default a nested `World:emit()` doesn't cause an automatic flush.

If you wanted to emit an Event without causing a flush at all you can use `World:emitNoFlush()` as a replacement to `World:emit()`. This can be used to gain more control on when flushes happen.

```lua
love.update = function (dt)
  World:emit("update", dt) -- Flushes before forwarding the event to the Systems
end

love.draw = function ()
  World:emitNoFlush("draw") -- Doesn't flush
end

function RenderSystem:update ()
  self:getWorld():emit("prepareForRender") -- Doesn't flush

  self:getWorld():flush() -- This is a manual flush
end
```

### `World:query()`

This function is always executed against the most up to date version of the Entity list, it is not affected by flushes and it includes the latest updates at the time of executing the function.

```lua
local myEntity = World:newEntity():give("position", 10, 20)

local list = World:query({"position"}) -- list contains myEntity even though there was no flush
```

If you want to perform additions/removals of Entities, keep in mind you shouldn't use the `onMatch` function since that happens a loop. You can still use the list alternative.

```lua
-- Don't do this
World:query({"position"}, function (e)
  World:newEntity()
  e:destroy()
end)

-- Do this instead
local list = World:query({"position"})
for _, e in ipairs(list) do
  -- This is safe because list is not mutated
  World:newEntity()
  e:destroy()
end
```

### Forbidden Flush

There are a few places where flushing is forbidden the list is short though:

- `World:onEntityAdded` / `World:onEntityRemoved`
- `Pool:onAdded` / `Pool:onRemoved`

These callbacks happen during a flush, you can't flush during a flush since the buffers are in use.

If your code performs a flush but may be called from inside of one of these callbacks you can use `World:canFlush()` to check if flushing is allowed, otherwise an error will be thrown.

```lua
if World:canFlush() then
  World:flush()
end
```
