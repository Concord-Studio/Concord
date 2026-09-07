project = 'Concord'
description = 'A feature-complete ECS library'
file = {'concord', exclude = {'concord/init.lua', 'concord/builtins/init.lua'}}
dir = 'docs'

format = 'markdown'
use_markdown_titles = true

new_type("builtin", "Builtins", true)
kind_names = {topic = 'Guides'}

-- Preprocessed by scripts/build-docs.lua
readme = {
  '.ldoc-guides/Get-Started.md',
  '.ldoc-guides/Why-ECS.md',
  '.ldoc-guides/Custom-Pools.md',
  '.ldoc-guides/Pool-Flushing-and-Timing.md',
}

style = '.'

