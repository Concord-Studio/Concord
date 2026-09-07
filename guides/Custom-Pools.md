# Custom Pools

This article details a escape hatch when the List used by Concord Pools is not enough for your System's need.

First we need to understand why this escape hatch is needed so we discuss some upsides and downsides of Lists, we then discuss the solution based on onAdded/onRemoved that Pools provide, and finally look at the escape hatch and its benefits.

## Lists upsides and downsides

Pools in Concord by default use a List implementation that provides fast inserts, fast removals, fast search and fast iteration.

These are all useful for Pools:

- Pools need to check if an Entity is part of the List or not.
- Pools need to add and remove Entities quickly
- The user needs to be able to iterate through the Pool quickly.

However these Lists have a few downsides:

- They consume some extra memory because they need to keep a value -> key hashmap
- They can't guarantee the order of their members
- Sorting is expensive, since the hashmap needs to be regenerated

## List Synchronization/Duplication

Sometimes you need to add your Entities to a different data structure like a Spatial Hash for Physics for example, when working with such a structure, you may end up with code that looks like this:

```lua
local Physics = Concord.System("Physics", {
  boxes = {"position", "size"} 
})

function Physics:init ()
  -- Create a new spatial hash
  local spatialhash = spatialhash()
  self.spatialhash = spatialhash

  -- Whenever there is a new box added to the boxes list
  -- Add the box to the spatial hash
  function self.boxes:onAdded (entity)
    spatialhash:add(entity)
  end

  -- Do the same when a box is removed
  function self.boxes:onRemoved (entity)
    spatialhash:remove(entity)
  end
end
```

Another fairly common example would be if you wanted a Sorted List for Rendering, and don't want the extra cost of sorting the List on each Event and instead would prefer to sort on insertion.

As you can see we have duplication of data, our Spatial Hash has all the same Entities that our `boxes` List. And now the code to sync the List with the Spatial Hash lives inside of the Physics System, which makes it hard to share or reuse.

So Concord offers an escape hatch out of this situation. If you only need the filtering part of a Pool and not the List part, you can bring your own data structure.

## Bring your own data structure

This feature is called **Custom Pools**

The way to define a Custom Pool is fairly simple. You need to create a function that returns an object with 4 methods: `has`, `add`, `remove` and `clear`

We could redo our example above by creating a Custom Pool wrapper for our Spatial Hash (this is not always needed but may be helpful if the method names or their parameters don't match)

```lua
function SpatialHashPool ()
  local storage = {hash = spatialhash()}

  function storage:clear()
    self.hash = spatialhash()
  end

  function storage:add(entity)
    self.hash:add(entity)
  end

  function storage:remove(entity)
    self.hash:remove(entity)
  end

  function storage:has(entity)
    if self.hash:search(entity) > 0 then
      return true
    else
      return false
    end
  end

  return storage
end
```

Then we can use this in any System like so

```lua
local Physics = Concord.System("Physics", {
  boxes = {"position", "size", constructor = SpatialHashPool}
})
```

Please note that the code now lives outside of the Physics System and can now be reused by different Systems or even different projects. This abstraction helps us share and reuse code.

### Additional Methods

The Storage we defined only exposes the methods needed by Concord which means that in order to iterate or perform other iterations you would need to use `self.boxes.hash` to access the Spatial Hash directly. However Concord does not enforce any limit on the methods exposed by your Pool other than those 4 required methods, so you could expose more utility functions that you need to access in your System's code.

For example we could add

```lua
function storage:query(x, y, w, h)
  return self.hash:query(x, y, w, h)
end
```

And use it in our System like so:

```lua
function Physics:update(dt)
  local visibleEntities = self.boxes:query(0, 0, 800, 600)
  
  for _, entity in ipairs(visibleEntities) do
    -- Do something
  end
end
```

### Pool definition

One advantage Custom Pools have is that when they are instantiated you get the complete Filter definition for the Pool as argument to the constructor function:

```lua
function SpatialHashPool (def)
  print(def) -- {"position", "size"}

  -- ...
end
```

This could be useful if you need some additional parameters to generate your storage for example

```lua
function SpatialHashPool (def)
  local storage = { hash = spatialhash(def.width, def.height) }
  
  -- ...

  return storage
end

-------

local Physics = Concord.System("Physics", {
  boxes = {"position", "size", constructor = SpatialHashPool, width = 800, height = 600}
})
```
