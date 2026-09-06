# Why ECS? Why Concord?

There are various reasons why people choose ECS for their projects, there is a very large [FAQ for ECS](https://github.com/SanderMertens/ecs-faq) made by the author of [FLECS](https://github.com/SanderMertens/flecs), but we can go through some of the reasons here as a starting point:

## It's a trend

Yeah it's a trend, most game engines are moving towards ECS as their pattern of choice, big names in the industry are using the pattern and more people are following this trend ([Unity](https://unity.com/ecs), [Unreal Engine](https://dev.epicgames.com/community/learning/talks-and-demos/37Oz/large-numbers-of-entities-with-mass-in-unreal-engine-5), [Overwatch (video)](https://www.youtube.com/watch?v=W3aieHjyNvw), etc).

This is not a good reason to use Concord but it does help that more and more documentation is being written about ECS and how to use it to organize your game code.

But this is also a downside, ECS is NOW being used by more game engines, but OOP has been the king for way longer and is more prevalent and used in this market.

Concord isn't here as part of the trend, and doesn't intend to follow what other ECS frameworks do. It instead presents it's own interpretation of ECS and makes a heavy focus on the ease of use and development.

## It doesn't rely on inheritance

So to follow this discussion, a reason people choose ECS is so that they can get away from the ugly parts of OOP.

The ugly part being [inheritance and all the problems it comes with](https://en.wikipedia.org/wiki/Inheritance_(object-oriented_programming)#Issues_and_alternatives). A possible solution would be mixins or decorators, but most people agree that the problems are still there.

So that's when they start to consider [composition over inheritance](https://en.wikipedia.org/wiki/Composition_over_inheritance). This is a very common pattern in OOP where you [put objects inside objects](https://en.wikipedia.org/wiki/Object_composition) instead of trying to define their behavior in term of inheritance. And ECS is very close to this pattern, remember how we put Components inside of our Entities? That's composition.

But in "Composition over inheritance" we would still define our behaviors in our objects, and we would still need to [forward our events to each component](https://en.wikipedia.org/wiki/Delegation_(object-oriented_programming)). So that's when people start to consider ECS, behaviors existing outside of the object/entity helps organize the code more neatly.

Concord does make use of OOP and the [metaprogramming](https://en.wikipedia.org/wiki/Metaprogramming) functionality in Lua, to help implements ECS, and does still allow you to work with Components and Systems as if they were objects. So if you are escaping from the "bad parts" of OOP, your OOP knowledge will not be wasted while using Concord.

## It's faster

Well this is the argument most game engines make to sell you ECS as the best architecture.

Remember our behaviors and data are stored separately? This helps keep our data small.
Remember how we don't make distinction between entities and instead rely on filtering? This allows us to pack our entities close together in memory so that we don't have to jump around so much when looping through them in our systems.

Unfortunately this doesn't apply to Concord because in Lua land we can't benefit from all of this, our representation of Components, Entities and Pools don't provide an advantage towards objects. Yeah Concord is fast for the majority of use cases, but this is not its selling point. You can probably write faster code without a library, and there are plenty alternatives that focus on speed.

Lua although fast, is not used for optimization purposes, and the same applies to Concord. Concord tries to be reliable, easy to use and feature complete, it is not an optimization.

We actually made [an experiment](https://github.com/Keyslam/Sniper) making a super efficient ECS library, but it was awful to code with and one line of code could throw all the optimizations away. In our opinion, although it's possible to make a super-fast ECS library and speed does make a huge difference, it's not worth it when working in Lua where JIT optimization is hard

### Reminds me of Functional Programming

If you have tried ["The Elm Architecture"](https://elmprogramming.com/elm-architecture-conclusion.html) or ["Redux"](https://redux.js.org/tutorials/fundamentals/part-2-concepts-data-flow#redux-application-data-flow) you may find the unidirectional data flow in ECS familiar.

If we think about our Entities and Components as our Model or State, and Systems as our Update or Reducers.
The only way to mutate our Model/State is through an Event processed by our Update/Reducer

This [unidirectional data flow](https://en.wikipedia.org/wiki/Unidirectional_Data_Flow_%28computer_science%29) and the concept of using [reducer functions](https://en.wikipedia.org/wiki/Fold_%28higher-order_function%29) as a way to update state is a proven concept and widely used in Functional Programming.

This mental model has worked really well for Front-end Web developers, and is a very good way to reason about how our systems update over time while keeping our state as our only source of truth and purely as data. If you are already familiar with these architecture you'll be able to pick up Concord and ECS in general, with relative ease.

In addition to that, if we combine ECS with [immutable data structures](https://en.wikipedia.org/wiki/Persistent_data_structure) for Components and Entities, then we wouldn't be too far away from "The Elm Architecture" and all its benefits like [Time Traveling debugging](https://elm-lang.org/news/time-travel-made-easy).

Unfortunately immutable data structures aren't cheap and the Lua garbage collector is not tuned for them.
Concord doesn't use immutable data structures, but if you treat your Components as just data, it does allow you to recover state through serialization and deserialization.

## It's more organized

If you find this mental model intuitive and start to reason only through this paradigm you'll find yourself writing code in a more structured way. There are very specific ways to do things in ECS and Concord will push you towards these patterns.

This is however at the expense of a higher learning curve with a big payoff in maintainability and reusability of your code. Concord keeps this risk low by allowing you to write code outside of Concord without extra hurdles.

In the long run we hope you'll find yourself at home using Concord, without needing these escape hatches, in order to accomplish this we try to ease this learning curve through guides, documentation and tooling that will hopefully make working with Concord a great experience.
