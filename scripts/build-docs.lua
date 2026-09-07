-- Build LDoc docs with Markdown preprocess and HTML postprocess.
-- Usage: lua scripts/build-docs.lua

local function split_lines(text)
   text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
   if text:sub(-1) ~= "\n" then
      text = text .. "\n"
   end
   local lines = {}
   for line in text:gmatch("(.-)\n") do
      lines[#lines + 1] = line
   end
   return lines
end

local function join_lines(lines)
   return table.concat(lines, "\n") .. "\n"
end

-- Strip one Markdown blockquote level inside <details>, so LDoc sees
-- fenced code at column 0 and can emit highlighted <pre> blocks.
local function unquote_details(text)
   return text:gsub("(<details[^>]*>)([%s%S]-)(</details>)", function(open, body, close)
      local lines = split_lines(body)
      for i, line in ipairs(lines) do
         lines[i] = line:match("^>%s?(.*)$") or line
      end
      return open .. join_lines(lines) .. close
   end)
end

-- Turn GitHub-style callouts into HTML asides LDoc will pass through.
--   > [!NOTE]
--   > body
local function convert_callouts(text)
   local lines = split_lines(text)
   local out = {}
   local i = 1
   while i <= #lines do
      local kind, rest = lines[i]:match("^>%s*%[!(%u+)%]%s*(.*)$")
      if kind then
         local body = {}
         if rest ~= "" then
            body[#body + 1] = rest
         end
         i = i + 1
         while i <= #lines do
            local quoted = lines[i]:match("^>%s?(.*)$")
            if quoted == nil then
               break
            end
            body[#body + 1] = quoted
            i = i + 1
         end
         local class = kind:lower()
         out[#out + 1] = ('<aside class="callout callout-%s">'):format(class)
         out[#out + 1] = ""
         for _, line in ipairs(body) do
            out[#out + 1] = line
         end
         out[#out + 1] = ""
         out[#out + 1] = "</aside>"
      else
         out[#out + 1] = lines[i]
         i = i + 1
      end
   end
   return join_lines(out)
end

local function preprocess(text)
   return convert_callouts(unquote_details(text))
end

-- LDoc puts the current kind first in the sidebar; keep a stable order.
local SIDEBAR_KINDS = { "Modules", "Classes", "Builtins", "Topics", "Guides" }
local SIDEBAR_LABELS = { Builtins = "Builtin Components", Topics = "Guides" }

local function strip_getting_started(list)
   list = list:gsub('<li>%s*<a href="[^"]+"[^>]*>Getting Started%s*</a>%s*</li>%s*', "")
   list = list:gsub('<li>%s*<strong>Getting Started%s*</strong>%s*</li>%s*', "")
   return list
end

local function reorder_sidebar(html)
   return (html:gsub('<div id="navigation">([%s%S]-)</div>', function(nav)
      local blocks = {}
      for _, title in ipairs(SIDEBAR_KINDS) do
         nav = nav:gsub('<h2>' .. title .. '</h2>%s*(<ul[%s%S]-</ul>)', function(list)
            if title == "Topics" or title == "Guides" then
               list = strip_getting_started(list)
            end
            blocks[title] = '<h2>' .. (SIDEBAR_LABELS[title] or title) .. '</h2>\n' .. list
            return ""
         end, 1)
      end
      local trimmed = nav:gsub("%s+$", "")
      local parts = { trimmed }
      for _, title in ipairs(SIDEBAR_KINDS) do
         if blocks[title] then
            parts[#parts + 1] = ""
            parts[#parts + 1] = blocks[title]
         end
      end
      parts[#parts + 1] = ""
      return '<div id="navigation">' .. table.concat(parts, "\n") .. '</div>'
   end, 1))
end

local HOME = "Getting Started"
local HOME_TOPIC = "Get-Started.md.html"

local function replace_home_link(html, path)
   local item
   if path:match("index%.html$") then
      item = "<strong>" .. HOME .. "</strong>"
   else
      item = '<a href="../index.html">' .. HOME .. "</a>"
   end
   local home = "<ul>\n  <li>" .. item .. "</li>\n</ul>"
   local replaced, n = html:gsub(
      '<ul>%s*<li><a href="[^"]*index%.html">Index</a></li>%s*</ul>',
      home,
      1
   )
   if n == 0 then
      replaced = html:gsub("(<h1>Concord</h1>)", "%1\n\n" .. home, 1)
   end
   return replaced
end

-- Getting Started lives at index.html; keep old topic URLs working.
local function point_getting_started_at_index(html)
   html = html:gsub('href="Get%-Started%.md%.html"', 'href="../index.html"')
   html = html:gsub('href="%.%./guides/Get%-Started%.md%.html"', 'href="../index.html"')
   html = html:gsub('href="%.%./topics/Get%-Started%.md%.html"', 'href="../index.html"')
   html = html:gsub('href="guides/Get%-Started%.md%.html"', 'href="index.html"')
   html = html:gsub('href="topics/Get%-Started%.md%.html"', 'href="index.html"')
   return html
end

local function topic_home_to_index(html)
   html = html:gsub('href="%.%./', 'href="')
   html = html:gsub(
      '<ul>%s*<li><a href="index%.html">' .. HOME .. "</a></li>%s*</ul>",
      "<ul>\n  <li><strong>" .. HOME .. "</strong></li>\n</ul>",
      1
   )
   return html
end

local HOME_REDIRECT = [[<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <meta http-equiv="refresh" content="0; url=../index.html"/>
  <link rel="canonical" href="../index.html"/>
  <title>Getting Started</title>
</head>
<body>
  <p><a href="../index.html">Getting Started</a></p>
</body>
</html>
]]

-- The index table uses topic filenames; the sidebar already has Markdown titles.
local function retitle_index_topics(html)
   local nav = html:match('<div id="navigation">([%s%S]-)</div>')
   if not nav then
      return html
   end
   local list = nav:match('<h2>Guides</h2>%s*<ul[^>]*>([%s%S]-)</ul>')
      or nav:match('<h2>Topics</h2>%s*<ul[^>]*>([%s%S]-)</ul>')
   if not list then
      return html
   end
   local titles = {}
   for href, title in list:gmatch('<a href="([^"]+)">([^<]+)</a>') do
      titles[href] = title
   end
   return (html:gsub(
      '<td class="name"%s+nowrap><a href="((?:guides|topics)/[^"]+)">([^<]+)</a></td>',
      function(href, name)
         return ('<td class="name"  nowrap><a href="%s">%s</a></td>'):format(
            href,
            titles[href] or name
         )
      end
   ))
end

local INDEX_KINDS = { "Modules", "Classes", "Builtin Components", "Guides" }

local function reorder_index_sections(html)
   return (html:gsub('<div id="content">([%s%S]-)</div> <!%-%- id="content" %-%->', function(content)
      local blocks = {}
      for _, title in ipairs(INDEX_KINDS) do
         content = content:gsub(
            '<h2>' .. title .. '</h2>%s*(<table class="module_list">[%s%S]-</table>)',
            function(table_html)
               blocks[title] = '<h2>' .. title .. '</h2>\n' .. table_html
               return ""
            end,
            1
         )
      end
      local trimmed = content:gsub("%s+$", "")
      local parts = { trimmed }
      for _, title in ipairs(INDEX_KINDS) do
         if blocks[title] then
            parts[#parts + 1] = ""
            parts[#parts + 1] = blocks[title]
         end
      end
      parts[#parts + 1] = ""
      return '<div id="content">' .. table.concat(parts, "\n") .. '</div> <!-- id="content" -->'
   end, 1))
end

-- Markdown wraps some block-level HTML in <p>; unwrap those.
local function postprocess(html, path)
   html = html:gsub('<p>%s*(<aside[^>]*>)%s*</p>', '%1')
   html = html:gsub('(<aside[^>]*>)%s*</p>', '%1')
   html = html:gsub('<p>%s*(</aside>)%s*</p>', '%1')
   html = html:gsub('<p>%s*(</aside>)', '%1')
   html = html:gsub('(</aside>)%s*</p>', '%1')
   html = html:gsub('<p>%s*(<details[%s%S]-</summary>)%s*</p>', '%1')
   html = html:gsub('<p>%s*(</details>)%s*</p>', '%1')
   -- Leftover callouts if a page was built without preprocess
   html = html:gsub(
      '<blockquote>%s*<p>%[!(%u+)%]%s*([%s%S]-)</p>%s*</blockquote>',
      function(kind, body)
         return ('<aside class="callout callout-%s"><p>%s</p></aside>'):format(
            kind:lower(),
            body
         )
      end
   )
   html = html:gsub('%s*<link rel="stylesheet" href="[^"]*ldoc%-custom%.css"[^>]*>', "")
   html = reorder_sidebar(html)
   html = retitle_index_topics(html)
   html = html:gsub('<h2>Builtins</h2>', '<h2>Builtin Components</h2>')
   html = html:gsub('<h2>Topics</h2>', '<h2>Guides</h2>')
   html = html:gsub(
      '<tr>%s*<td class="name"%s+nowrap><a href="[^"]+">Getting Started</a></td>%s*<td class="summary">[^<]*</td>%s*</tr>%s*',
      ""
   )
   html = reorder_index_sections(html)
   html = replace_home_link(html, path)
   if path:sub(-#HOME_TOPIC) ~= HOME_TOPIC then
      -- Keep the topic page's current-item markup so it can become index.html.
      html = point_getting_started_at_index(html)
   end
   return html
end

local function read_file(path)
   local f, err = io.open(path, "r")
   if not f then
      error("cannot read " .. path .. ": " .. tostring(err))
   end
   local text = f:read("*a")
   f:close()
   return text
end

local function write_file(path, text)
   local f, err = io.open(path, "w")
   if not f then
      error("cannot write " .. path .. ": " .. tostring(err))
   end
   f:write(text)
   f:close()
end

local function run(cmd)
   local ok, why, code = os.execute(cmd)
   if not ok then
      error(cmd .. " failed (" .. tostring(why) .. " " .. tostring(code) .. ")")
   end
end

local function list_html(dir)
   local files = {}
   local pipe = io.popen('find "' .. dir .. '" -name "*.html"')
   for line in pipe:lines() do
      files[#files + 1] = line
   end
   pipe:close()
   return files
end

local root = arg[0]:match("^(.*)/scripts/build%-docs%.lua$") or "."
if root == "" then
   root = "."
end

run('mkdir -p "' .. root .. '/.ldoc-guides"')

local pipe = io.popen('ls -1 "' .. root .. '/guides/"*.md')
for path in pipe:lines() do
   local name = path:match("([^/]+)$")
   write_file(root .. "/.ldoc-guides/" .. name, preprocess(read_file(path)))
end
pipe:close()

run('rm -rf "' .. root .. '/docs"')
run('mkdir "' .. root .. '/docs"')
run('cd "' .. root .. '" && ldoc --fatalwarnings .')

for _, path in ipairs(list_html(root .. "/docs")) do
   write_file(path, postprocess(read_file(path), path))
end

local topic_home = root .. "/docs/guides/" .. HOME_TOPIC
write_file(root .. "/docs/index.html", topic_home_to_index(read_file(topic_home)))
write_file(topic_home, HOME_REDIRECT)

print("docs built in " .. root .. "/docs")
