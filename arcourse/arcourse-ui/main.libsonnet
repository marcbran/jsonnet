local c = {
  list:
    local style = |||
      @scope (.list) {
        :scope {
          font-family: monospace;
        }
        a {
          color: var(--primary-color);
        }
        a:hover {
          text-decoration: none;
        }
        ul {
          list-style: none;
        }
      }
    |||;

    {
      local c = self,
      items:: error 'List requires items',
      style:: '',
      html: [
        { element: 'style', children: [style] },
        {
          element: 'aside',
          attributes: { class: 'list card' } + (if c.style != '' then { style: c.style } else {}),
          children: [{
            element: 'nav',
            children: [{
              element: 'ul',
              children: [
                {
                  element: 'li',
                  children: [{
                    element: 'a',
                    attributes: { href: item.link },
                    children: [item.text],
                  }],
                }
                for item in c.items
              ],
            }],
          }],
        },
      ],
    },
  groupList:
    local style = |||
      @scope (.group-list) {
        :scope {
          font-family: monospace;
          display: inline-flex;
          flex-direction: column;
          gap: 0.25em;
        }
        a {
          color: var(--primary-color);
        }
        a:hover {
          text-decoration: none;
        }
        ul {
          list-style: none;
          margin: 0;
          padding: 0;
        }
      }
    |||;

    local itemList = {
      local c = self,
      items:: error 'ItemList requires items',
      html: {
        element: 'ul',
        children: [
          {
            element: 'li',
            children: [{
              element: 'a',
              attributes: { href: item.link },
              children: [item.text],
            }],
          }
          for item in c.items
        ],
      },
    };

    {
      local c = self,
      items:: error 'GroupList requires items',
      groups:: [],
      html: [
        { element: 'style', children: [style] },
        {
          element: 'aside',
          attributes: { class: 'group-list' },
          children:
            (if std.length(c.items) > 0 then [{
               element: 'nav',
               attributes: { class: 'card' },
               children: [itemList { items:: c.items }],
             }] else []) + [
              {
                element: 'nav',
                attributes: { class: 'card' },
                children: [
                  { element: 'strong', children: [group.title] },
                  itemList { items:: group.items },
                ],
              }
              for group in c.groups
            ],
        },
      ],
    },
  table:
    local style = |||
      @scope (.table) {
        :scope {
          display: inline-table;
          border-collapse: separate;
          border-spacing: 0;
          font-family: monospace;
        }
        th {
          color: var(--primary-color);
          font-weight: bold;
          padding: 0.3em 0.4em;
        }
        td {
          padding: 0;
        }
        td > * {
          display: block;
          box-sizing: border-box;
          height: 100%;
          padding: 0.3em 0.4em;
        }
        td > a {
          text-decoration: none;
          color: var(--on-background-color);
        }
        tbody tr:has(a):hover {
          background-color: var(--container-low-color);
        }
        td.empty {
          text-align: center;
          opacity: 0.6;
        }
      }
    |||;

    local cellValue(item, col) =
      if std.objectHas(col, 'value') then col.value(item)
      else std.foldl(
        function(acc, k) if std.type(acc) == 'object' then std.get(acc, k, null) else null,
        col.path,
        item
      );

    local cellText(item, col) =
      local val = cellValue(item, col);
      if val == null then '' else std.toString(val);

    local rowHref(rowLink, item) =
      if rowLink == null then null
      else
        local target = rowLink(item);
        if std.type(target) == 'object' && std.objectHasAll(target, '_queryPath')
        then target._queryPath
        else null;

    local cell = {
      local c = self,
      item:: error 'Cell requires item',
      col:: error 'Cell requires col',
      href:: null,
      local text = cellText(c.item, c.col),
      html:
        if c.href == null then
          { element: 'span', children: [text] }
        else
          { element: 'a', attributes: { href: c.href }, children: [text] },
    };

    local emptyRow = {
      local c = self,
      columnCount:: error 'EmptyRow requires columnCount',
      html: {
        element: 'tr',
        children: [{
          element: 'td',
          attributes: { class: 'empty', colspan: std.max(1, c.columnCount) },
          children: [{ element: 'span', children: ['No items'] }],
        }],
      },
    };

    {
      local c = self,
      items:: error 'Table requires items',
      columns:: [],
      rowLink:: null,
      local rows = if std.isArray(c.items) then c.items else [],
      html: [
        { element: 'style', children: [style] },
        {
          element: 'table',
          attributes: { class: 'table card' },
          children: [
            {
              element: 'thead',
              children: [{
                element: 'tr',
                children: [
                  { element: 'th', children: [col.label] }
                  for col in c.columns
                ],
              }],
            },
            {
              element: 'tbody',
              children:
                if std.length(rows) == 0 then [emptyRow { columnCount:: std.length(c.columns) }]
                else [
                  local href = rowHref(c.rowLink, item);
                  {
                    element: 'tr',
                    children: [
                      { element: 'td', children: [cell { item:: item, col:: col, href:: href }] }
                      for col in c.columns
                    ],
                  }
                  for item in rows
                ],
            },
          ],
        },
      ],
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

    local style = |||
      .yaml {
        white-space: pre-wrap;
        word-break: break-all;
      }
    |||;

    {
      local c = self,
      data:: error 'Yaml requires data',
      html: [
        { element: 'style', children: [style] },
        { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, 0) },
      ],
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
        --on-background-color: light-dark(
          color-mix(in srgb, var(--primary-color) 12%, black),
          color-mix(in srgb, var(--primary-color) 12%, white)
        );
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
        color: var(--on-background-color);
        padding: 0.5em;
      }
      .card {
        display: inline-block;
        border: 1px solid var(--border-color);
        border-radius: 0.5em;
        padding: 0.75em;
      }
      .deck {
        display: contents;
      }
      .deck:has(.card ~ .card) {
        display: inline-flex;
        gap: 0.25em;
        border: 1px solid var(--border-color);
        border-radius: 0.5em;
        padding: 0.25em;
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
            {
              element: 'body',
              children: [{ element: 'div', attributes: { class: 'deck' }, children: c.fragment }],
            },
          ],
        },
      ],
    },
};
local html = {
  manifestHtml(tree): std.native('invoke:html')('manifestHtml', [tree]),
};
local linkspecs =
  local walk(current, remaining, buildFn) =
    if std.length(remaining) == 0 then
      if std.type(current) == 'array' then
        std.foldl(function(acc, item) acc + buildFn(item), current, {})
      else buildFn(current)
    else
      local next =
        if std.type(current) == 'object' then std.get(current, remaining[0], null)
        else null;
      if next == null then {}
      else if std.type(next) == 'array' then
        std.foldl(function(acc, item) acc + walk(item, remaining[1:], buildFn), next, {})
      else
        walk(next, remaining[1:], buildFn);

  local itemPath(item, path) =
    std.foldl(
      function(acc, seg) if std.type(acc) == 'object' then std.get(acc, seg, null) else null,
      path,
      item
    );

  local nestValue(labels, index, value) =
    if index == std.length(labels) - 1 then { [labels[index]]: value }
    else { [labels[index]]+: nestValue(labels, index + 1, value) };

  local nestKeys(keySegs, item, value) =
    local labels = [
      if std.objectHas(seg, 'const') then seg.const else std.toString(itemPath(item, seg.path))
      for seg in keySegs
    ];
    nestValue(labels, 0, value);

  local resolveTarget(root, node, item, valueSegs) =
    std.foldl(
      function(acc, seg)
        if std.objectHas(seg, 'const') then acc[seg.const]
        else if std.objectHas(seg, 'origin') then acc[seg.origin](std.toString(node[seg.origin]))
        else acc[seg.param](std.toString(itemPath(item, seg.path))),
      valueSegs,
      root
    );

  local resolvable(item, valueSegs) =
    std.all([
      itemPath(item, seg.path) != null
      for seg in valueSegs
      if std.objectHas(seg, 'path')
    ]);

  local buildLinks(node, specs, root=import 'root') =
    std.foldl(
      function(acc, spec)
        acc + walk(
          node.data,
          spec.at,
          function(item)
            if resolvable(item, spec.value)
            then nestKeys(spec.keys, item, resolveTarget(root, node, item, spec.value))
            else {}
        ),
      specs,
      {}
    );

  local rowLinkSpec(specs, at) =
    local matches = [spec for spec in specs if spec.at == at];
    if std.length(matches) == 0 then null else matches[0];

  local rowLinkFor(node, specs, at, root=import 'root') =
    local spec = rowLinkSpec(specs, at);
    if spec == null then null
    else function(item)
      if resolvable(item, spec.value) then resolveTarget(root, node, item, spec.value) else null;

  {
    buildLinks: buildLinks,
    rowLinkFor: rowLinkFor,
    withLinkSpecs: {
      linkSpecs:: [],
      links: buildLinks(self, self.linkSpecs, import 'root'),
    },
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
    fragment: c.list { items:: neighbors($) },
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
    fragment: c.groupList {
      items:: directNeighbors($, exclude=['data', '_view', 'links']) + linksItems($),
      groups:: linksGroups($),
    },
  },
};

local yamlView = baseView {
  _view+:: {
    fragment: c.yaml { data:: $.data },
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
      local table = std.get($, 'table', {});
      local at = std.get(table, 'at', ['items']);
      local items = safeGet($.data, at);
      c.table {
        items:: items,
        columns:: std.get(table, 'columns', []),
        rowLink:: linkspecs.rowLinkFor($, std.get($, 'linkSpecs', []), at),
      },
  },
};

local resourceView = baseView {
  _view+:: {
    fragment:
      local items = neighbors($);
      local listCard = if std.length(items) > 0 then [c.list { items:: items, style:: ' min-width: 8em;' }] else [];
      listCard + [c.yaml { data:: $.data }],
  },
};

local withNode = { node: self.view + linkspecs.withLinkSpecs };

{
  default: { view: neighborView } + withNode,
  list: { view: neighborView } + withNode,
  groupList: { view: groupView } + withNode,
  table: { view: tableView } + withNode,
  yaml: { view: yamlView } + withNode,
  resource: { view: resourceView } + withNode,
}
