local c = {
  list: {
    local c = self,
    items:: error 'List requires items',
    html: {
      element: 'aside',
      attributes: { style: 'font-family: monospace' },
      children: [{
        element: 'nav',
        children: [{
          element: 'ul',
          attributes: { style: 'list-style: none;' },
          children: [
            {
              element: 'li',
              children: [{
                element: 'a',
                attributes: { href: item.link, style: 'color: var(--primary-color)' },
                children: [item.text],
              }],
            }
            for item in c.items
          ],
        }],
      }],
    },
  },
  groupList:
    local groupBorder = 'border: 1px solid var(--border-color); border-radius: 0.5em; padding: 0.75em 1em;';

    local itemList(items) = {
      element: 'ul',
      attributes: { style: 'list-style: none; margin: 0; padding: 0;' },
      children: [
        {
          element: 'li',
          children: [{
            element: 'a',
            attributes: { href: item.link, style: 'color: var(--primary-color)' },
            children: [item.text],
          }],
        }
        for item in items
      ],
    };

    {
      local c = self,
      items:: error 'GroupList requires items',
      groups:: [],
      html: {
        element: 'aside',
        attributes: { style: 'font-family: monospace; display: inline-flex; flex-direction: column; gap: 0.25em;' },
        children:
          (if std.length(c.items) > 0 then [{
             element: 'nav',
             attributes: { style: groupBorder },
             children: [itemList(c.items)],
           }] else []) + [
            {
              element: 'nav',
              attributes: { style: groupBorder },
              children: [
                { element: 'strong', children: [group.title] },
                itemList(group.items),
              ],
            }
            for group in c.groups
          ],
      },
    },
  table:
    local cellValue(item, col) =
      if std.objectHas(col, 'value') then col.value(item)
      else std.foldl(
        function(acc, k) if std.type(acc) == 'object' then std.get(acc, k, null) else null,
        col.path,
        item
      );

    local cellContent(item, col) =
      local val = cellValue(item, col);
      local str = if val == null then '' else std.toString(val);
      local link = if std.objectHas(col, 'link') then col.link(item) else null;
      if link != null then
        { element: 'a', attributes: { href: link._queryPath, style: 'color: var(--primary-color)' }, children: [str] }
      else
        str;

    {
      local c = self,
      items:: error 'Table requires items',
      columns:: [],
      html: {
        element: 'table',
        attributes: { style: 'font-family: monospace' },
        children: [
          {
            element: 'thead',
            children: [{
              element: 'tr',
              children: [
                {
                  element: 'th',
                  attributes: { style: 'color: var(--primary-color); font-weight: bold' },
                  children: [col.label],
                }
                for col in c.columns
              ],
            }],
          },
          {
            element: 'tbody',
            children: [
              {
                element: 'tr',
                children: [{ element: 'td', children: [cellContent(item, col)] } for col in c.columns],
              }
              for item in c.items
            ],
          },
        ],
      },
    },
  yaml:
    local yaml = {
      local c = self,

      indent(depth)::
        std.join('', std.makeArray(depth * 2, function(_) ' ')),

      scalar(v)::
        if std.type(v) == 'null' then 'null'
        else if std.type(v) == 'boolean' then (if v then 'true' else 'false')
        else if std.type(v) == 'object' then '{}'
        else if std.type(v) == 'array' then '[]'
        else '%s' % v,

      key(k)::
        { element: 'span', attributes: { style: 'color: var(--primary-color); font-weight: bold' }, children: [k] },

      row(key, value, depth, bullet)::
        local hasChildren =
          (std.type(value) == 'object' || std.type(value) == 'array')
          && std.length(value) > 0;
        if hasChildren then
          [{ element: 'div', children: [
            c.indent(depth),
            bullet,
            c.key(key),
            ':',
          ] }] + c.children(value, depth + 1)
        else
          [{ element: 'div', children: [
            c.indent(depth),
            bullet,
            c.key(key),
            ': ' + c.scalar(value),
          ] }],

      children(value, depth)::
        if std.type(value) == 'object' then
          std.flatMap(
            function(kv) c.row(kv.key, kv.value, depth, ''),
            std.objectKeysValues(value)
          )
        else
          std.flatMap(function(item)
            if std.type(item) == 'object' then
              local kvs = std.objectKeysValues(item);
              c.row(kvs[0].key, kvs[0].value, depth, '- ') +
              std.flatMap(function(kv) c.row(kv.key, kv.value, depth, '  '), kvs[1:])
            else
              [{ element: 'div', children: [
                c.indent(depth),
                '- ' + c.scalar(item),
              ] }]
                      , value),
    };

    {
      local c = self,
      data:: error 'Yaml requires data',
      html: { element: 'pre', children: yaml.children(c.data, 0) },
    },
  page:
    local pageStyle = |||
      * {
        margin: 0;
        padding: 0;
      }
      :root {
        color-scheme: light dark;
        --primary-color: light-dark(#0451a5, #569cd6);
        --background-color: light-dark(
          color-mix(in srgb, var(--primary-color) 3%, white),
          color-mix(in srgb, var(--primary-color) 8%, black)
        );
        --container-low-color: light-dark(
          color-mix(in srgb, var(--primary-color) 8%, white),
          color-mix(in srgb, var(--primary-color) 15%, black)
        );
        --border-color: light-dark(
          color-mix(in srgb, var(--primary-color) 20%, white),
          color-mix(in srgb, var(--primary-color) 30%, black)
        );
      }
      body {
        background-color: var(--background-color);
        padding: 0.5em;
      }
      pre {
        white-space: pre-wrap;
        word-break: break-all;
      }
      a:hover {
        text-decoration: none;
      }
      table {
        border-collapse: collapse;
      }
      th, td {
        padding: 0.1em 0.4em;
      }
    |||;

    {
      local c = self,
      fragment:: error 'HtmlPage requires a fragment',
      html: [
        { doctype: 'html' },
        {
          element: 'html',
          children: [
            { element: 'head', children: [{ element: 'style', children: [pageStyle] }] },
            { element: 'body', children: [c.fragment] },
          ],
        },
      ],
    },
  panel: {
    local c = self,
    child:: error 'Panel requires a child',
    style:: '',
    html: {
      element: 'div',
      attributes: { style: 'display: inline-block; border: 1px solid var(--border-color); border-radius: 0.5em; padding: 0.75em;' + c.style },
      children: [c.child],
    },
  },
};
local html = {
  manifestHtml(tree): std.native('invoke:html')('manifestHtml', [tree]),
};

local collectNeighbors(obj, textPrefix='', exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
        if std.type(value) != 'object' then []
        else
          if std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath') then
            [{ link: value._queryPath, text: textPath }]
          else collectNeighbors(value, textPath, exclude),
    std.objectFields(obj)
  );

local neighbors(obj) =
  local links = std.get(obj, 'links', {});
  (if std.type(links) == 'object' then collectNeighbors(links) else []) +
  collectNeighbors(obj, exclude=['data', '_view', 'links']);

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: c.page { fragment:: n._view.fragment },
    html: html.manifestHtml(self.page),
  },
};

local neighborView = baseView {
  _view+:: {
    fragment: c.panel { child:: c.list { items:: neighbors($) } },
  },
};

local isNode(value) =
  std.type(value) == 'object' && std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath');

local directNeighbors(obj, exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        if isNode(value) then [{ link: value._queryPath, text: k }] else [],
    std.objectFields(obj)
  );

local linksItems(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k) if isNode(links[k]) then [{ link: links[k]._queryPath, text: k }] else [],
    std.objectFields(links)
  );

local linksGroups(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k)
      local value = links[k];
      if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value) }]
      else [],
    std.objectFields(links)
  );

local groupView = baseView {
  _view+:: {
    fragment: c.panel { style:: ' padding: 0.25em;', child:: c.groupList {
      items:: directNeighbors($, exclude=['data', '_view', 'links']) + linksItems($),
      groups:: linksGroups($),
    } },
  },
};

local yamlView = baseView {
  _view+:: {
    fragment: c.panel { child:: c.yaml { data:: $.data } },
  },
};

local safeGet(obj, path) =
  std.foldl(
    function(acc, k)
      if acc != null && std.isObject(acc) && std.objectHasAll(acc, k) then acc[k] else null,
    path,
    obj
  );

local tableView = baseView {
  _view+:: {
    fragment:
      local items = safeGet($.data, std.get($, 'itemsPath', ['items']));
      if std.isArray(items) then
        c.panel { child:: c.table { items:: items, columns:: std.get($, 'columns', []) } }
      else
        c.panel { child:: c.yaml { data:: $.data } },
  },
};

local resourceView = baseView {
  _view+:: {
    fragment:
      local items = neighbors($);
      if std.length(items) > 0 then
        {
          element: 'div',
          attributes: { style: 'display: inline-flex; gap: 0.25em; border: 1px solid var(--border-color); border-radius: 0.5em; padding: 0.25em;' },
          children: [
            c.panel { child:: c.list { items:: items }, style:: ' min-width: 8em;' },
            c.panel { child:: c.yaml { data:: $.data } },
          ],
        }
      else
        c.panel { child:: c.yaml { data:: $.data } },
  },
};

{
  default: { view: neighborView },
  list: { view: neighborView },
  groupList: { view: groupView },
  table: { view: tableView },
  yaml: { view: yamlView },
  resource: { view: resourceView },
}
