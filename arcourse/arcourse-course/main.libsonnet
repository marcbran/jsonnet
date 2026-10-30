local a =
  local linkspecs =
    local url(u) = std.native('invoke:url')('format', [u]);

    local walk(current, remaining) =
      if std.length(remaining) == 0 then
        if std.type(current) == 'array' then current else [current]
      else
        local next =
          if std.type(current) == 'object' then std.get(current, remaining[0], null)
          else null;
        if next == null then []
        else if std.type(next) == 'array' then
          std.flatMap(function(item) walk(item, remaining[1:]), next)
        else
          walk(next, remaining[1:]);

    local itemPath(item, path) =
      std.foldl(
        function(acc, seg) if std.type(acc) == 'object' then std.get(acc, seg, null) else null,
        path,
        item
      );

    local keyLabels(keySegs, item) = [
      if std.objectHas(seg, 'const') then seg.const else std.toString(itemPath(item, seg.path))
      for seg in keySegs
    ];

    local nestEntries(entries, depth) =
      local nestGroup(group) =
        local ending = [e for e in group if std.length(e.labels) == depth + 1];
        local deeper = [e for e in group if std.length(e.labels) > depth + 1];
        if std.length(deeper) == 0 then ending[std.length(ending) - 1].value
        else if std.length(ending) == 0 then nestEntries(deeper, depth + 1)
        else ending[std.length(ending) - 1].value + nestEntries(deeper, depth + 1);
      local sorted = std.sort(entries, function(e) e.labels[depth]);
      local n = std.length(sorted);
      local starts = [i for i in std.range(0, n - 1) if i == 0 || sorted[i].labels[depth] != sorted[i - 1].labels[depth]];
      local bounds = starts + [n];
      {
        [sorted[bounds[j]].labels[depth]]: nestGroup(sorted[bounds[j]:bounds[j + 1]])
        for j in std.range(0, std.length(starts) - 1)
      };

    local splitPrefix(valueSegs) =
      if std.length(valueSegs) == 0 then { prefix: [], suffix: [] }
      else if std.objectHas(valueSegs[0], 'param') || std.objectHas(valueSegs[0], 'path') then { prefix: [], suffix: valueSegs }
      else
        local rest = splitPrefix(valueSegs[1:]);
        { prefix: [valueSegs[0]] + rest.prefix, suffix: rest.suffix };

    local resolveBase(root, node, prefixSegs) =
      std.foldl(
        function(acc, seg)
          if std.objectHas(seg, 'const') then acc[seg.const]
          else acc[seg.origin](std.toString(node[seg.origin])),
        prefixSegs,
        root
      );

    local resolveKey(spec, item) =
      if std.type(spec) == 'string' then spec
      else
        local raw = itemPath(item, spec.path);
        if std.objectHas(spec, 'transform') then spec.transform(raw) else raw;

    local resolveFromBase(base, item, suffixSegs) =
      std.foldl(
        function(acc, seg)
          if std.objectHas(seg, 'param') then
            acc[resolveKey(seg.param, item)](std.toString(itemPath(item, seg.path)))
          else if std.objectHas(seg, 'const') then
            acc[seg.const]
          else
            acc[resolveKey(seg, item)],
        suffixSegs,
        base
      );

    local resolvable(item, valueSegs) =
      std.all(
        [itemPath(item, seg.path) != null for seg in valueSegs if std.objectHas(seg, 'path')] +
        [
          itemPath(item, seg.param.path) != null
          for seg in valueSegs
          if std.objectHas(seg, 'param') && std.type(seg.param) == 'object'
        ]
      );

    local resolveLiteralSegment(node, item, seg) =
      if std.objectHas(seg, 'const') then seg.const
      else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
      else resolveKey(seg, item);

    local resolveLiteralSegments(node, item, segs) =
      std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

    local resolveUrl(node, item, literal) =
      local query = std.get(literal, 'query', {});
      url({
        scheme: std.get(literal, 'scheme', null),
        host: resolveLiteralSegments(node, item, std.get(literal, 'host', [])),
        path: [resolveLiteralSegment(node, item, seg) for seg in std.get(literal, 'path', [])],
        params: { [k]: resolveLiteralSegments(node, item, query[k]) for k in std.objectFields(query) },
      });

    local urlSegments(literal) =
      std.get(literal, 'host', []) + std.get(literal, 'path', [])
      + std.flattenArrays([literal.query[k] for k in std.objectFields(std.get(literal, 'query', {}))]);

    local specEntries(node, spec, root) =
      if std.type(spec.value) == 'object' then
        local segs = urlSegments(spec.value);
        [
          if resolvable(item, segs)
          then { labels: keyLabels(spec.keys, item), value: resolveUrl(node, item, spec.value) }
          else null
          for item in walk(node.data, spec.at)
        ]
      else
        local split = splitPrefix(spec.value);
        local base = resolveBase(root, node, split.prefix);
        [
          if resolvable(item, spec.value)
          then { labels: keyLabels(spec.keys, item), value: resolveFromBase(base, item, split.suffix) }
          else null
          for item in walk(node.data, spec.at)
        ];

    local linksFromEntries(entriesPerSpec) =
      local entries = [e for entries in entriesPerSpec for e in entries if e != null];
      if std.length(entries) == 0 then {} else nestEntries(entries, 0);

    local buildLinks(node, specs, root=import 'root') =
      linksFromEntries([specEntries(node, spec, root) for spec in specs]);

    local rowLinksFor(node, specs, at) =
      local matches = [i for i in std.range(0, std.length(specs) - 1) if specs[i].at == at];
      if std.length(matches) == 0 then []
      else
        local entries =
          if std.objectHasAll(node, '_linkEntries') then node._linkEntries[matches[0]]
          else specEntries(node, specs[matches[0]], import 'root');
        [if e == null then null else e.value for e in entries];

    {
      buildLinks: buildLinks,
      rowLinksFor: rowLinksFor,
      withLinkSpecs: {
        linkSpecs:: [],
        _linkEntries:: [specEntries(self, spec, import 'root') for spec in self.linkSpecs],
        links: linksFromEntries(self._linkEntries),
      },
    };
  local c = {
    list:
      local style = |||
        @scope (.list) {
          :scope {
            font-family: monospace;
            display: inline-flex;
            flex-direction: column;
            gap: 0.25em;
          }
          a {
            color: var(--primary-color);
            border-radius: 0.5em;
          }
          a:hover {
            text-decoration: none;
          }
          a:focus {
            outline: 2px solid var(--primary-color);
            outline-offset: 2px;
          }
          ul {
            list-style: none;
            margin: 0;
            padding: 0;
          }
          :scope.columns {
            flex-direction: row;
            flex-wrap: wrap;
            align-items: flex-start;
          }
          .list-column {
            display: flex;
            flex-direction: column;
            gap: 0.25em;
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
                attributes: { href: item.link } + (
                  if std.get(item, 'external', false)
                  then { target: '_blank', rel: 'noopener noreferrer' }
                  else {}
                ),
                children: [item.text],
              }],
            }
            for item in c.items
          ],
        },
      };

      local card = {
        local c = self,
        title:: null,
        items:: error 'Card requires items',
        lines:: std.length(c.items) + (if c.title == null then 0 else 1),
        html: {
          element: 'nav',
          attributes: { class: 'card' },
          children:
            (if c.title == null then [] else [{ element: 'strong', children: [c.title] }])
            + [itemList { items:: c.items }],
        },
      };

      local column = {
        local c = self,
        cards:: error 'Column requires cards',
        html: {
          element: 'div',
          attributes: { class: 'list-column' },
          children: [card.html for card in c.cards],
        },
      };

      local lineCount(cards) = std.foldl(function(acc, card) acc + card.lines, cards, 0);

      local distribute(cards, count) =
        local target = lineCount(cards) / count;
        std.foldl(
          function(columns, card)
            local last = columns[std.length(columns) - 1];
            if std.length(last) > 0 && std.length(columns) < count && lineCount(last) + card.lines / 2 > target
            then columns + [[card]]
            else columns[:std.length(columns) - 1] + [last + [card]],
          cards,
          [[]]
        );

      {
        local c = self,
        items:: error 'List requires items',
        groups:: [],
        columns:: 1,
        style:: '',
        local cards =
          (if std.length(c.items) > 0 then [card { items:: c.items }] else [])
          + [card { title:: group.title, items:: group.items } for group in c.groups],
        html: [
          { element: 'style', children: [style] },
          {
            element: 'aside',
            attributes: { class: if c.columns > 1 then 'list columns' else 'list' } + (if c.style != '' then { style: c.style } else {}),
            children:
              if c.columns > 1 then [column { cards:: cards }.html for cards in distribute(cards, c.columns)]
              else [card.html for card in cards],
          },
        ],
      },
    table:
      local style = |||
        @scope (.table-card) {
          :scope.card {
            padding: 0.25em;
          }
          :scope {
            display: inline-flex;
            flex-direction: column;
            align-items: flex-start;
            gap: 0.5em;
          }
        }
        @scope (.table) {
          :scope {
            border-collapse: separate;
            border-spacing: 0;
            font-family: monospace;
          }
          th {
            color: var(--primary-color);
            font-weight: bold;
            padding: 0.3em 0.4em;
            cursor: pointer;
            user-select: none;
            white-space: nowrap;
          }
          th:hover {
            text-decoration: underline;
          }
          th.sort-asc::after {
            content: ' ↑';
          }
          th.sort-desc::after {
            content: ' ↓';
          }
          td {
            padding: 0;
            border-top: 2px solid transparent;
            border-bottom: 2px solid transparent;
          }
          td:first-child {
            border-left: 2px solid transparent;
          }
          td:last-child {
            border-right: 2px solid transparent;
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
          tbody tr:has(a:focus) td {
            background-color: var(--container-low-color);
            border-color: var(--primary-color);
          }
          tbody tr:has(a:focus) td:first-child {
            border-radius: 0.8em 0 0 0.8em;
          }
          tbody tr:has(a:focus) td:last-child {
            border-radius: 0 0.8em 0.8em 0;
          }
          td > a:focus {
            outline: none;
          }
          td.empty {
            text-align: center;
            opacity: 0.6;
          }
        }
        @scope (.table-pagination) {
          :scope {
            display: flex;
            align-items: stretch;
            width: fit-content;
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            overflow: hidden;
            background: var(--container-low-color);
            font-family: monospace;
          }
          a, span.disabled {
            display: flex;
            align-items: center;
            justify-content: center;
            line-height: 1;
            width: 2.6rem;
            height: 2.6rem;
            font-size: 1.4em;
            border-right: 1px solid var(--border-color);
            text-decoration: none;
            color: var(--on-background-color);
          }
          a:last-child, span.disabled:last-child {
            border-right: none;
          }
          a:hover {
            background-color: var(--background-color);
          }
          span.disabled {
            opacity: 0.4;
          }
        }
      |||;

      local sortScript = |||
        (function () {
          if (window.__tableSortBound) return;
          window.__tableSortBound = true;

          var observer = null;

          function headers(table) {
            return Array.prototype.slice.call(table.querySelectorAll('thead th'));
          }

          function cellText(row, i) {
            var td = row.children[i];
            return td ? td.textContent.trim() : '';
          }

          function compare(a, b) {
            var na = Number(a);
            var nb = Number(b);
            if (a !== '' && b !== '' && !isNaN(na) && !isNaN(nb)) return na - nb;
            return a.localeCompare(b);
          }

          function firstCol(table) {
            var th = table.querySelector('thead th');
            return th ? th.dataset.col : null;
          }

          function apply(table) {
            var ths = headers(table);
            ths.forEach(function (th) { th.classList.remove('sort-asc', 'sort-desc'); });
            if (ths.length === 0) return;
            var key = window.hashParams.get('sort');
            var desc = window.hashParams.get('dir') === 'desc';
            var i = 0;
            if (key) {
              i = -1;
              ths.forEach(function (th, idx) { if (th.dataset.col === key) i = idx; });
              if (i < 0) { i = 0; desc = false; }
            } else {
              desc = false;
            }
            ths[i].classList.add(desc ? 'sort-desc' : 'sort-asc');
            var tbody = table.querySelector('tbody');
            if (!tbody || tbody.querySelector('td.empty')) return;
            var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
            rows.sort(function (a, b) {
              var r = compare(cellText(a, i), cellText(b, i));
              return desc ? -r : r;
            });
            rows.forEach(function (r) { tbody.appendChild(r); });
          }

          function applyAll() {
            if (observer) observer.disconnect();
            document.querySelectorAll('table.table').forEach(apply);
            if (observer) {
              var target = document.getElementById('node') || document.body;
              if (target) observer.observe(target, { childList: true, subtree: true });
            }
          }

          document.addEventListener('click', function (e) {
            var th = e.target.closest ? e.target.closest('th') : null;
            if (!th || !th.dataset.col) return;
            var table = th.closest('table.table');
            if (!table) return;
            var key = th.dataset.col;
            var first = firstCol(table);
            var curKey = window.hashParams.get('sort') || first;
            var curDesc = window.hashParams.get('dir') === 'desc';
            var nextKey;
            var nextDesc;
            if (curKey !== key) {
              nextKey = key;
              nextDesc = false;
            } else if (!curDesc) {
              nextKey = key;
              nextDesc = true;
            } else {
              nextKey = first;
              nextDesc = false;
            }
            if (nextKey === first && !nextDesc) {
              window.hashParams.remove('sort');
              window.hashParams.remove('dir');
            } else {
              window.hashParams.set('sort', nextKey);
              if (nextDesc) window.hashParams.set('dir', 'desc');
              else window.hashParams.remove('dir');
            }
            applyAll();
          });

          function init() {
            observer = new MutationObserver(applyAll);
            applyAll();
          }

          if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
          else init();
        })();
      |||;

      local slug(label) = std.asciiLower(std.strReplace(std.toString(label), ' ', '-'));

      local cellText(item, col) =
        local val = std.get(item, col.key, null);
        if val == null then '' else std.toString(val);

      local rowHref(target) =
        if std.type(target) == 'object' && std.objectHasAll(target, '_queryPath')
        then target._queryPath
        else null;

      local cell = {
        local c = self,
        item:: error 'Cell requires item',
        col:: error 'Cell requires col',
        href:: null,
        first:: true,
        local text = cellText(c.item, c.col),
        html:
          if c.href == null then
            { element: 'span', children: [text] }
          else
            { element: 'a', attributes: { href: c.href } + (if c.first then {} else { tabindex: '-1' }), children: [text] },
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

      local navLink = {
        local c = self,
        icon:: error 'NavLink requires icon',
        title:: error 'NavLink requires title',
        href:: null,
        html:
          if c.href == null then
            { element: 'span', attributes: { class: 'disabled', title: c.title }, children: [c.icon] }
          else
            { element: 'a', attributes: { href: c.href, title: c.title }, children: [c.icon] },
      };

      local paginationDirections = [
        { key: 'first', icon: '«', title: 'First page' },
        { key: 'prev', icon: '‹', title: 'Previous page' },
        { key: 'next', icon: '›', title: 'Next page' },
        { key: 'last', icon: '»', title: 'Last page' },
      ];

      local paginationNav = {
        local c = self,
        pagination:: null,
        local links = if c.pagination == null then {} else c.pagination,
        visible:: std.length(std.objectFields(links)) > 0,
        html: {
          element: 'div',
          attributes: { class: 'table-pagination' },
          children: [
            local target = std.get(links, dir.key, null);
            (navLink {
               icon:: dir.icon,
               title:: dir.title,
               href:: if target == null then null else target._queryPath,
             }).html
            for dir in paginationDirections
          ],
        },
      };

      {
        local c = self,
        items:: error 'Table requires items',
        columns:: [],
        rowLinks:: [],
        pagination:: null,
        local rows = if std.isArray(c.items) then c.items else [],
        local nav = paginationNav { pagination:: c.pagination },
        html: [
          { element: 'style', children: [style] },
          {
            element: 'div',
            attributes: { class: 'card table-card' },
            children: [
              {
                element: 'table',
                attributes: { class: 'table' },
                children: [
                  {
                    element: 'thead',
                    children: [{
                      element: 'tr',
                      children: [
                        { element: 'th', attributes: { 'data-col': slug(col.label) }, children: [col.label] }
                        for col in c.columns
                      ],
                    }],
                  },
                  {
                    element: 'tbody',
                    children:
                      if std.length(rows) == 0 then [emptyRow { columnCount:: std.length(c.columns) }]
                      else [
                        local item = rows[r];
                        local href = rowHref(if r < std.length(c.rowLinks) then c.rowLinks[r] else null);
                        {
                          element: 'tr',
                          children: [
                            { element: 'td', children: [cell { item:: item, col:: c.columns[i], href:: href, first:: i == 0 }] }
                            for i in std.range(0, std.length(c.columns) - 1)
                          ],
                        }
                        for r in std.range(0, std.length(rows) - 1)
                      ],
                  },
                ],
              },
            ] + (if nav.visible then [nav.html] else []),
          },
          { element: 'script', children: [{ html: sortScript }] },
        ],
      },
    tree:
      local style = |||
        @scope (.tree) {
          :scope {
            font-family: monospace;
            display: block;
            overflow-x: auto;
            line-height: 1.3;
          }
          ul {
            list-style: none;
            margin: 0;
            padding: 0;
          }
          li {
            white-space: pre;
          }
          a {
            color: var(--primary-color);
          }
          a:hover {
            text-decoration: none;
          }
          .prefix {
            opacity: 0.4;
            user-select: none;
          }
          .detail {
            opacity: 0.55;
            margin-left: 0.75em;
            font-size: 0.85em;
          }
        }
      |||;

      local link = {
        local c = self,
        node:: error 'Link requires a node',
        html: {
          element: 'a',
          attributes: { href: c.node.link },
          children: [c.node.text],
        },
      };

      local rowsOf(nodes, indent, root) = std.flatMap(
        function(i)
          local node = nodes[i];
          local last = i == std.length(nodes) - 1;
          [{
            node: node,
            prefix: if root then '' else indent + (if last then '╰─ ' else '├─ '),
          }] + rowsOf(
            std.get(node, 'children', []),
            if root then '' else indent + (if last then '   ' else '│  '),
            false,
          ),
        std.range(0, std.length(nodes) - 1)
      );

      local row = {
        local c = self,
        prefix:: error 'Row requires a prefix',
        item:: error 'Row requires an item',
        html: {
          element: 'li',
          children: [
            { element: 'span', attributes: { class: 'prefix' }, children: [c.prefix] },
            c.item,
          ],
        },
      };

      local rowList = {
        local c = self,
        rows:: error 'RowList requires rows',
        item:: error 'RowList requires an item',
        html: {
          element: 'ul',
          children: [
            row { prefix:: r.prefix, item:: c.item { node:: r.node } }
            for r in c.rows
          ],
        },
      };

      {
        local c = self,
        nodes:: error 'Tree requires nodes',
        item:: link,
        html: [
          { element: 'style', children: [style] },
          {
            element: 'section',
            attributes: { class: 'tree card' },
            children: [rowList { rows:: rowsOf(c.nodes, '', true), item:: c.item }],
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

        at(links, k)::
          if std.isObject(links) && std.isString(k) then std.get(links, k, null)
          else if std.isArray(links) && std.isNumber(k) && k < std.length(links) then links[k]
          else null,

        href(target)::
          if std.isString(target) then target
          else if std.isObject(target) && std.objectHasAll(target, '_queryPath') then target._queryPath
          else null,

        link(target, children, style)::
          local href = c.href(target);
          if href == null then { element: 'span', attributes: { style: style }, children: children }
          else { element: 'a', attributes: { href: href, style: style }, children: children },

        key(k, target)::
          c.link(target, [k], 'color: var(--primary-color); font-weight: bold'),

        value(v, target)::
          if c.href(target) == null then c.scalar(v)
          else c.link(target, [c.scalar(v)], 'color: inherit'),

        isMultiline(v)::
          std.isString(v) && std.length(std.findSubstr('\n', v)) > 0,

        leaf:: {
          local l = self,
          prefix:: [],
          data:: error 'leaf requires data',
          target:: null,
          depth:: 0,
          html:
            if !c.isMultiline(l.data) then
              [{ element: 'div', children: l.prefix + [c.value(l.data, l.target)] }]
            else
              local trailing = std.length(l.data) - std.length(std.rstripChars(l.data, '\n'));
              local indicator = if trailing == 0 then '|-' else if trailing == 1 then '|' else '|+';
              local lines = std.split(if trailing > 0 then std.substr(l.data, 0, std.length(l.data) - 1) else l.data, '\n');
              [{ element: 'div', children: l.prefix + [indicator] }] + [
                { element: 'div', children: [c.indent(l.depth + 1), c.value(line, l.target)] }
                for line in lines
              ],
        },

        isLeaf(value)::
          !((std.type(value) == 'object' || std.type(value) == 'array') && std.length(value) > 0),

        mapLeaves(value, fn, path=[])::
          if c.isLeaf(value) then fn(path, value)
          else if std.isObject(value) then { [k]: c.mapLeaves(value[k], fn, path + [k]) for k in std.objectFields(value) }
          else [c.mapLeaves(value[i], fn, path + [i]) for i in std.range(0, std.length(value) - 1)],

        row(key, value, links, depth, bullet)::
          if !c.isLeaf(value) then
            [{ element: 'div', children: [
              c.indent(depth),
              bullet,
              c.key(key, null),
              ':',
            ] }] + c.children(value, links, depth + 1)
          else
            (c.leaf {
               prefix:: [
                 c.indent(depth),
                 bullet,
                 c.key(key, c.at(links, 'key')),
                 ': ',
               ],
               data:: value,
               target:: c.at(links, 'value'),
               depth:: depth,
             }).html,

        children(value, links, depth)::
          if std.type(value) == 'object' then
            std.flatMap(
              function(kv) c.row(kv.key, kv.value, c.at(links, kv.key), depth, ''),
              std.objectKeysValues(value)
            )
          else
            std.flatMap(
              function(i)
                local item = value[i];
                local itemLinks = c.at(links, i);
                if std.type(item) == 'object' then
                  local kvs = std.objectKeysValues(item);
                  c.row(kvs[0].key, kvs[0].value, c.at(itemLinks, kvs[0].key), depth, '- ') +
                  std.flatMap(function(kv) c.row(kv.key, kv.value, c.at(itemLinks, kv.key), depth, '  '), kvs[1:])
                else
                  (c.leaf {
                     prefix:: [c.indent(depth), '- '],
                     data:: item,
                     target:: c.at(itemLinks, 'value'),
                     depth:: depth,
                   }).html,
              std.range(0, std.length(value) - 1)
            ),
      };

      local style = |||
        .yaml {
          white-space: pre-wrap;
          word-break: break-all;
        }
        .yaml a {
          text-decoration: none;
        }
        .yaml a:hover {
          text-decoration: underline;
        }
      |||;

      {
        local c = self,
        data:: error 'Yaml requires data',
        embeddedLinks:: null,
        mapLeaves(value, fn):: yaml.mapLeaves(value, fn),
        html: [
          { element: 'style', children: [style] },
          { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, c.embeddedLinks, 0) },
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
          --error-color: light-dark(#c62828, #f48771);
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
        .deck:has(.breadcrumbs),
        .deck:has(.card ~ .card),
        .deck:has(.list):has(.yaml) {
          display: inline-flex;
          flex-direction: column;
          align-items: flex-start;
          gap: 0.25em;
          border: 1px solid var(--border-color);
          border-radius: 0.5em;
          padding: 0.25em;
        }
      |||;

      local hashScript = |||
        (function () {
          if (window.hashParams) return;

          function read() {
            return new URLSearchParams(window.location.hash.slice(1));
          }

          function serialize(p) {
            var parts = [];
            p.forEach(function (value, key) {
              parts.push(value === '' ? encodeURIComponent(key) : encodeURIComponent(key) + '=' + encodeURIComponent(value));
            });
            return parts.join('&');
          }

          function write(p) {
            var s = serialize(p);
            var base = window.location.pathname + window.location.search;
            history.replaceState(null, '', s ? base + '#' + s : base);
          }

          window.hashParams = {
            get: function (key) {
              return read().get(key);
            },
            has: function (key) {
              return read().has(key);
            },
            set: function (key, value) {
              var p = read();
              if (value === null || value === undefined) p.delete(key);
              else p.set(key, value);
              write(p);
            },
            remove: function (key) {
              this.set(key, null);
            },
          };
        })();
      |||;
      local navScript = |||
        (function () {
          if (typeof HTMLElement === 'undefined') return;

          var GROUPS = [
            { key: 'breadcrumbs', title: 'breadcrumbs' },
            { key: 'links', title: 'links' },
            { key: 'table', title: 'table' },
          ];

          function scrapeItems() {
            var items = [];
            document.querySelectorAll('.breadcrumbs a[href]').forEach(function (a) {
              var text = a.textContent.trim();
              if (text) items.push({ text: text, link: a.href, group: 'breadcrumbs' });
            });
            document.querySelectorAll('.list a[href]').forEach(function (a) {
              var text = a.textContent.trim();
              if (text) items.push({ text: text, link: a.href, group: 'links' });
            });
            document.querySelectorAll('.table tbody tr').forEach(function (tr) {
              var a = tr.querySelector('a[href]');
              if (!a) return;
              var text = Array.prototype.map
                .call(tr.querySelectorAll('td'), function (td) { return td.textContent.trim(); })
                .filter(Boolean)
                .join('  ');
              if (text) items.push({ text: text, link: a.href, group: 'table' });
            });
            return items;
          }

          function isBoundary(ch) {
            return ch === undefined || /[\s_\/\-.]/.test(ch);
          }

          function fuzzyScore(query, text) {
            if (!query) return 0;
            var q = query.toLowerCase();
            var t = text.toLowerCase();
            var score = 0;
            var qi = 0;
            var prev = -2;
            for (var ti = 0; ti < t.length && qi < q.length; ti++) {
              if (t[ti] === q[qi]) {
                score += ti === prev + 1 ? 3 : 1;
                if (isBoundary(t[ti - 1])) score += 2;
                prev = ti;
                qi++;
              }
            }
            return qi === q.length ? score : -1;
          }

          function rank(query, items) {
            if (!query) return items.slice();
            var scored = [];
            for (var i = 0; i < items.length; i++) {
              var s = fuzzyScore(query, items[i].text);
              if (s >= 0) scored.push({ item: items[i], score: s, index: i });
            }
            scored.sort(function (a, b) { return b.score - a.score || a.index - b.index; });
            return scored.map(function (e) { return e.item; });
          }

          var template = `
            <style>
              :host { font-family: monospace; }
              dialog {
                border: 1px solid var(--border-color);
                border-radius: 0.5em;
                background: var(--background-color);
                color: var(--on-background-color);
                padding: 0;
                width: min(90vw, 42em);
                margin-top: 12vh;
                box-shadow: 0 0.5em 2em rgba(0, 0, 0, 0.35);
              }
              dialog::backdrop { background: rgba(0, 0, 0, 0.4); }
              input {
                width: 100%;
                box-sizing: border-box;
                font: inherit;
                padding: 0.6em 0.75em;
                border: none;
                border-bottom: 1px solid var(--border-color);
                background: transparent;
                color: inherit;
                outline: none;
              }
              ul { list-style: none; margin: 0; padding: 0.25em; max-height: 50vh; overflow-y: auto; }
              li {
                padding: 0.35em 0.5em;
                border-radius: 0.25em;
                cursor: pointer;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
              }
              li.selected { background: var(--container-low-color); }
              li.empty { opacity: 0.6; cursor: default; }
              li.group {
                cursor: default;
                padding: 0.5em 0.5em 0.15em;
                opacity: 0.5;
                font-size: 0.85em;
                text-transform: uppercase;
                letter-spacing: 0.05em;
              }
              li.group:first-child { padding-top: 0.15em; }
            </style>
            <dialog part="modal">
              <input type="text" autocomplete="off" spellcheck="false" placeholder="Jump to…" />
              <ul></ul>
            </dialog>
          `;

          class QuickNav extends HTMLElement {
            connectedCallback() {
              if (!this.shadowRoot) this.attachShadow({ mode: 'open' });
              this.shadowRoot.innerHTML = template;
              this.modal = this.shadowRoot.querySelector('dialog');
              this.input = this.shadowRoot.querySelector('input');
              this.results = this.shadowRoot.querySelector('ul');
              this.items = [];
              this.matches = [];
              this.itemEls = [];
              this.selected = 0;

              this.input.addEventListener('input', function () {
                this.selected = 0;
                this.render();
              }.bind(this));

              this.modal.addEventListener('keydown', this.onKeydown.bind(this));
              this.modal.addEventListener('click', function (e) {
                if (e.target === this.modal) this.closeModal();
              }.bind(this));
              this.modal.addEventListener('close', function () {
                window.hashParams.remove('quick-nav');
              });

              if (!window.__quickNavBound) {
                window.__quickNavBound = true;
                document.addEventListener('keydown', function (e) {
                  if (e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey) return;
                  var el = document.activeElement;
                  while (el && el.shadowRoot && el.shadowRoot.activeElement) el = el.shadowRoot.activeElement;
                  var tag = el && el.tagName;
                  if (tag === 'INPUT' || tag === 'TEXTAREA' || (el && el.isContentEditable)) return;
                  var nav = document.querySelector('quick-nav');
                  if (nav && !nav.isOpen()) {
                    e.preventDefault();
                    nav.openModal();
                  }
                }, true);
              }

              if (window.hashParams.has('quick-nav')) {
                requestAnimationFrame(function () { this.openModal(); }.bind(this));
              }
            }

            isOpen() {
              return !!(this.modal && this.modal.open);
            }

            openModal() {
              this.items = scrapeItems();
              this.input.value = '';
              this.selected = 0;
              this.render();
              this.modal.showModal();
              this.input.focus();
              window.hashParams.set('quick-nav', '');
            }

            closeModal() {
              if (this.modal.open) this.modal.close();
            }

            onKeydown(e) {
              if (e.key === 'ArrowDown') {
                e.preventDefault();
                this.move(1);
              } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                this.move(-1);
              } else if (e.key === 'Enter') {
                e.preventDefault();
                this.choose(e.shiftKey);
              }
            }

            move(delta) {
              if (this.matches.length === 0) return;
              this.selected = (this.selected + delta + this.matches.length) % this.matches.length;
              this.highlight();
            }

            choose(keepOpen) {
              var match = this.matches[this.selected];
              if (!match) return;
              window.hashParams.remove('quick-nav');
              var url = new URL(match.link, window.location.href);
              url.hash = keepOpen ? 'quick-nav' : '';
              window.location.href = url.toString();
            }

            highlight() {
              for (var i = 0; i < this.itemEls.length; i++) {
                var on = i === this.selected;
                this.itemEls[i].classList.toggle('selected', on);
                if (on) this.itemEls[i].scrollIntoView({ block: 'nearest' });
              }
            }

            render() {
              var self = this;
              var ranked = rank(this.input.value.trim(), this.items);
              this.results.innerHTML = '';
              this.matches = [];
              this.itemEls = [];

              GROUPS.forEach(function (group) {
                var groupItems = ranked.filter(function (m) { return m.group === group.key; });
                if (groupItems.length === 0) return;
                var header = document.createElement('li');
                header.className = 'group';
                header.textContent = group.title;
                self.results.appendChild(header);
                groupItems.forEach(function (match) {
                  var index = self.matches.length;
                  self.matches.push(match);
                  var li = document.createElement('li');
                  li.textContent = match.text;
                  if (index === self.selected) li.classList.add('selected');
                  li.addEventListener('mousemove', function () {
                    self.selected = index;
                    self.highlight();
                  });
                  li.addEventListener('click', function () {
                    self.selected = index;
                    self.choose();
                  });
                  self.results.appendChild(li);
                  self.itemEls.push(li);
                });
              });

              if (this.matches.length === 0) {
                var empty = document.createElement('li');
                empty.className = 'empty';
                empty.textContent = 'No matches';
                this.results.appendChild(empty);
              }
            }
          }

          if (!customElements.get('quick-nav')) customElements.define('quick-nav', QuickNav);
        })();
      |||;

      {
        local c = self,
        fragment:: error 'HtmlPage requires a fragment',
        breadcrumbs:: { html: [] },
        html: [
          { doctype: 'html' },
          {
            element: 'html',
            children: [
              {
                element: 'head',
                children: [
                  { element: 'style', children: [pageStyle] },
                  { element: 'script', children: [{ html: hashScript }] },
                ],
              },
              {
                element: 'body',
                children: [
                  { element: 'div', attributes: { class: 'deck' }, children: [c.breadcrumbs, c.fragment] },
                  { element: 'quick-nav' },
                  { element: 'script', children: [{ html: navScript }] },
                ],
              },
            ],
          },
        ],
      },
    resource:
      local list =
        local style = |||
          @scope (.list) {
            :scope {
              font-family: monospace;
              display: inline-flex;
              flex-direction: column;
              gap: 0.25em;
            }
            a {
              color: var(--primary-color);
              border-radius: 0.5em;
            }
            a:hover {
              text-decoration: none;
            }
            a:focus {
              outline: 2px solid var(--primary-color);
              outline-offset: 2px;
            }
            ul {
              list-style: none;
              margin: 0;
              padding: 0;
            }
            :scope.columns {
              flex-direction: row;
              flex-wrap: wrap;
              align-items: flex-start;
            }
            .list-column {
              display: flex;
              flex-direction: column;
              gap: 0.25em;
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
                  attributes: { href: item.link } + (
                    if std.get(item, 'external', false)
                    then { target: '_blank', rel: 'noopener noreferrer' }
                    else {}
                  ),
                  children: [item.text],
                }],
              }
              for item in c.items
            ],
          },
        };

        local card = {
          local c = self,
          title:: null,
          items:: error 'Card requires items',
          lines:: std.length(c.items) + (if c.title == null then 0 else 1),
          html: {
            element: 'nav',
            attributes: { class: 'card' },
            children:
              (if c.title == null then [] else [{ element: 'strong', children: [c.title] }])
              + [itemList { items:: c.items }],
          },
        };

        local column = {
          local c = self,
          cards:: error 'Column requires cards',
          html: {
            element: 'div',
            attributes: { class: 'list-column' },
            children: [card.html for card in c.cards],
          },
        };

        local lineCount(cards) = std.foldl(function(acc, card) acc + card.lines, cards, 0);

        local distribute(cards, count) =
          local target = lineCount(cards) / count;
          std.foldl(
            function(columns, card)
              local last = columns[std.length(columns) - 1];
              if std.length(last) > 0 && std.length(columns) < count && lineCount(last) + card.lines / 2 > target
              then columns + [[card]]
              else columns[:std.length(columns) - 1] + [last + [card]],
            cards,
            [[]]
          );

        {
          local c = self,
          items:: error 'List requires items',
          groups:: [],
          columns:: 1,
          style:: '',
          local cards =
            (if std.length(c.items) > 0 then [card { items:: c.items }] else [])
            + [card { title:: group.title, items:: group.items } for group in c.groups],
          html: [
            { element: 'style', children: [style] },
            {
              element: 'aside',
              attributes: { class: if c.columns > 1 then 'list columns' else 'list' } + (if c.style != '' then { style: c.style } else {}),
              children:
                if c.columns > 1 then [column { cards:: cards }.html for cards in distribute(cards, c.columns)]
                else [card.html for card in cards],
            },
          ],
        };
      local yaml =
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

          at(links, k)::
            if std.isObject(links) && std.isString(k) then std.get(links, k, null)
            else if std.isArray(links) && std.isNumber(k) && k < std.length(links) then links[k]
            else null,

          href(target)::
            if std.isString(target) then target
            else if std.isObject(target) && std.objectHasAll(target, '_queryPath') then target._queryPath
            else null,

          link(target, children, style)::
            local href = c.href(target);
            if href == null then { element: 'span', attributes: { style: style }, children: children }
            else { element: 'a', attributes: { href: href, style: style }, children: children },

          key(k, target)::
            c.link(target, [k], 'color: var(--primary-color); font-weight: bold'),

          value(v, target)::
            if c.href(target) == null then c.scalar(v)
            else c.link(target, [c.scalar(v)], 'color: inherit'),

          isMultiline(v)::
            std.isString(v) && std.length(std.findSubstr('\n', v)) > 0,

          leaf:: {
            local l = self,
            prefix:: [],
            data:: error 'leaf requires data',
            target:: null,
            depth:: 0,
            html:
              if !c.isMultiline(l.data) then
                [{ element: 'div', children: l.prefix + [c.value(l.data, l.target)] }]
              else
                local trailing = std.length(l.data) - std.length(std.rstripChars(l.data, '\n'));
                local indicator = if trailing == 0 then '|-' else if trailing == 1 then '|' else '|+';
                local lines = std.split(if trailing > 0 then std.substr(l.data, 0, std.length(l.data) - 1) else l.data, '\n');
                [{ element: 'div', children: l.prefix + [indicator] }] + [
                  { element: 'div', children: [c.indent(l.depth + 1), c.value(line, l.target)] }
                  for line in lines
                ],
          },

          isLeaf(value)::
            !((std.type(value) == 'object' || std.type(value) == 'array') && std.length(value) > 0),

          mapLeaves(value, fn, path=[])::
            if c.isLeaf(value) then fn(path, value)
            else if std.isObject(value) then { [k]: c.mapLeaves(value[k], fn, path + [k]) for k in std.objectFields(value) }
            else [c.mapLeaves(value[i], fn, path + [i]) for i in std.range(0, std.length(value) - 1)],

          row(key, value, links, depth, bullet)::
            if !c.isLeaf(value) then
              [{ element: 'div', children: [
                c.indent(depth),
                bullet,
                c.key(key, null),
                ':',
              ] }] + c.children(value, links, depth + 1)
            else
              (c.leaf {
                 prefix:: [
                   c.indent(depth),
                   bullet,
                   c.key(key, c.at(links, 'key')),
                   ': ',
                 ],
                 data:: value,
                 target:: c.at(links, 'value'),
                 depth:: depth,
               }).html,

          children(value, links, depth)::
            if std.type(value) == 'object' then
              std.flatMap(
                function(kv) c.row(kv.key, kv.value, c.at(links, kv.key), depth, ''),
                std.objectKeysValues(value)
              )
            else
              std.flatMap(
                function(i)
                  local item = value[i];
                  local itemLinks = c.at(links, i);
                  if std.type(item) == 'object' then
                    local kvs = std.objectKeysValues(item);
                    c.row(kvs[0].key, kvs[0].value, c.at(itemLinks, kvs[0].key), depth, '- ') +
                    std.flatMap(function(kv) c.row(kv.key, kv.value, c.at(itemLinks, kv.key), depth, '  '), kvs[1:])
                  else
                    (c.leaf {
                       prefix:: [c.indent(depth), '- '],
                       data:: item,
                       target:: c.at(itemLinks, 'value'),
                       depth:: depth,
                     }).html,
                std.range(0, std.length(value) - 1)
              ),
        };

        local style = |||
          .yaml {
            white-space: pre-wrap;
            word-break: break-all;
          }
          .yaml a {
            text-decoration: none;
          }
          .yaml a:hover {
            text-decoration: underline;
          }
        |||;

        {
          local c = self,
          data:: error 'Yaml requires data',
          embeddedLinks:: null,
          mapLeaves(value, fn):: yaml.mapLeaves(value, fn),
          html: [
            { element: 'style', children: [style] },
            { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, c.embeddedLinks, 0) },
          ],
        };

      local style = |||
        .resource {
          display: flex;
          flex-wrap: wrap;
          align-items: flex-start;
          gap: 0.25em;
        }
        .resource > .yaml,
        .resource > .tree {
          flex: 1 1 0;
          min-width: 0;
        }
        .resource.stacked {
          flex-direction: column;
          flex-wrap: nowrap;
        }
        .resource.stacked > .yaml,
        .resource.stacked > .tree {
          flex: none;
        }
      |||;

      {
        local c = self,
        data:: error 'Resource requires data',
        content:: yaml { data:: c.data },
        items:: [],
        groups:: [],
        columns:: 1,
        stacked:: false,
        local links =
          if std.length(c.items) > 0 || std.length(c.groups) > 0 then
            [list { items:: c.items, groups:: c.groups, columns:: c.columns, style:: ' min-width: 8em;' }]
          else [],
        html: [
          { element: 'style', children: [style] },
          {
            element: 'div',
            attributes: { class: if c.stacked then 'resource stacked' else 'resource' },
            children: if c.stacked then [c.content] + links else links + [c.content],
          },
        ],
      },
    breadcrumbs:
      local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
      local varName(seg) = std.substr(seg, 1, std.length(seg) - 1);

      local style = |||
        @scope (.breadcrumbs) {
          :scope {
            font-family: monospace;
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 0.4em;
            width: fit-content;
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            padding: 0.5em 0.75em;
          }
          a {
            color: var(--primary-color);
            text-decoration: none;
            border-radius: 0.5em;
          }
          a:hover {
            text-decoration: underline;
          }
          a:focus {
            outline: 2px solid var(--primary-color);
            outline-offset: 2px;
          }
          .key {
            opacity: 0.55;
          }
          .sep {
            opacity: 0.4;
          }
          .current {
            color: var(--on-background-color);
          }
        }
      |||;

      local crumbInner = {
        local c = self,
        name:: null,
        value:: error 'crumbInner requires value',
        html:
          if c.name == null then [c.value]
          else [{ element: 'span', attributes: { class: 'key' }, children: [c.name + '/'] }, c.value],
      };

      {
        local c = self,
        pathTemplate:: [],
        node:: {},
        local crumbs =
          std.foldl(
            function(acc, seg)
              local entry =
                if isVar(seg) then
                  local v = varName(seg);
                  local val = std.toString(std.get(c.node, v, ''));
                  { url: acc.url + '/' + v + '/' + val, name: v, value: val }
                else
                  { url: acc.url + '/' + seg, name: null, value: seg };
              {
                url: entry.url,
                crumbs: acc.crumbs + [{ name: entry.name, value: entry.value, queryPath: entry.url }],
              },
            c.pathTemplate,
            { url: '/root', crumbs: [{ name: null, value: 'root', queryPath: '/root' }] }
          ).crumbs,
        html:
          if std.length(c.pathTemplate) == 0 then []
          else [
            { element: 'style', children: [style] },
            {
              element: 'nav',
              attributes: { class: 'breadcrumbs' },
              children: std.flattenArrays([
                (if i > 0 then [{ element: 'span', attributes: { class: 'sep' }, children: ['›'] }] else []) +
                [
                  if i == std.length(crumbs) - 1
                  then { element: 'span', attributes: { class: 'current' }, children: [crumbInner { name:: crumbs[i].name, value:: crumbs[i].value }] }
                  else { element: 'a', attributes: { href: crumbs[i].queryPath }, children: [crumbInner { name:: crumbs[i].name, value:: crumbs[i].value }] },
                ]
                for i in std.range(0, std.length(crumbs) - 1)
              ]),
            },
          ],
      },
    action:
      local script = |||
        function isDirty(controls) {
          return Array.prototype.some.call(controls, function (control) {
            if (control.options) {
              const defaultIndex = Array.prototype.findIndex.call(control.options, function (option) {
                return option.defaultSelected;
              });
              return control.selectedIndex !== Math.max(defaultIndex, 0);
            }
            return control.value !== control.defaultValue;
          });
        }

        if (typeof HTMLElement !== 'undefined') {
          class ActionCard extends HTMLElement {
            connectedCallback() {
              this.update = this.update.bind(this);
              this.addEventListener('input', this.update);
              this.addEventListener('change', this.update);
              window.addEventListener('pageshow', this.update);
              this.update();
            }

            disconnectedCallback() {
              window.removeEventListener('pageshow', this.update);
            }

            update() {
              const apply = this.querySelector('form.apply button');
              if (!apply) return;
              apply.disabled = isDirty(this.querySelectorAll('form.params input, form.params select'));
            }
          }

          if (!customElements.get('action-card')) customElements.define('action-card', ActionCard);
        }

        if (typeof module !== 'undefined' && module.exports) {
          module.exports = { isDirty };
        }
      |||;

      local style = |||
        @scope (.action) {
          :scope {
            font-family: monospace;
            display: inline-flex;
            flex-direction: column;
            align-items: flex-start;
            gap: 0.75em;
            padding: 0.5em;
          }
          p {
            margin: 0;
          }
          form {
            margin: 0;
          }
          form.params {
            display: flex;
            flex-direction: column;
            gap: 0.5em;
          }
          label {
            display: flex;
            align-items: baseline;
            gap: 0.75em;
          }
          input, select {
            font-family: inherit;
            font-size: inherit;
            color: var(--on-background-color);
            background-color: var(--container-low-color);
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            padding: 0.3em 0.6em;
          }
          input:focus, select:focus {
            outline: 2px solid var(--primary-color);
            outline-offset: 2px;
          }
          .issue {
            color: var(--error-color);
          }
          .issue.hint {
            color: inherit;
            opacity: 0.6;
          }
          .buttons {
            display: flex;
            gap: 0.5em;
            align-self: flex-end;
          }
          button {
            font-family: inherit;
            font-size: inherit;
            color: var(--on-background-color);
            background-color: var(--container-low-color);
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            padding: 0.4em 1em;
            cursor: pointer;
          }
          button:hover {
            color: var(--primary-color);
            border-color: var(--primary-color);
          }
          button:focus {
            outline: 2px solid var(--primary-color);
            outline-offset: 2px;
          }
          button:disabled {
            opacity: 0.4;
            cursor: not-allowed;
          }
          button:disabled:hover {
            color: var(--on-background-color);
            border-color: var(--border-color);
          }
        }
      |||;

      local paramsFormId = 'action-params';

      local issue = {
        local c = self,
        message:: error 'issue requires a message',
        hint:: false,
        html: {
          element: 'p',
          attributes: { class: if c.hint then 'issue hint' else 'issue' },
          children: [c.message],
        },
      };

      local numberControl = {
        local c = self,
        name:: error 'numberControl requires a name',
        value:: null,
        html: {
          element: 'input',
          attributes: { type: 'number', step: 'any', name: c.name, value: if c.value == null then null else std.toString(c.value) },
        },
      };

      local textControl = {
        local c = self,
        name:: error 'textControl requires a name',
        value:: null,
        html: {
          element: 'input',
          attributes: { type: 'text', name: c.name, value: c.value },
        },
      };

      local booleanOption = {
        local c = self,
        value:: error 'booleanOption requires a value',
        selected:: false,
        html: {
          element: 'option',
          attributes: { value: c.value, selected: c.selected },
          children: [c.value],
        },
      };

      local booleanControl = {
        local c = self,
        name:: error 'booleanControl requires a name',
        value:: null,
        local current = if c.value == null then '' else std.toString(c.value),
        html: {
          element: 'select',
          attributes: { name: c.name },
          children: [
            booleanOption { value:: v, selected:: v == current }
            for v in ['', 'true', 'false']
          ],
        },
      };

      local hiddenControl = {
        local c = self,
        name:: error 'hiddenControl requires a name',
        value:: null,
        html: [
          { element: 'input', attributes: { type: 'hidden', name: c.name, value: std.toString(v) } }
          for v in if c.value == null then [] else if std.isArray(c.value) then c.value else [c.value]
        ],
      };

      local controls = {
        number: numberControl,
        string: textControl,
        boolean: booleanControl,
      };

      local field = {
        local c = self,
        spec:: error 'field requires a spec',
        params:: {},
        initialValues:: {},
        issues:: [],
        local name = c.spec.name,
        local present = std.objectHas(c.params, name),
        local initial = std.objectHas(c.initialValues, name),
        local value = if present then c.params[name] else if initial then c.initialValues[name] else null,
        html:
          if std.objectHas(controls, c.spec.type) then [{
            element: 'label',
            children: [
              { element: 'span', children: [name] },
              controls[c.spec.type] { name:: name, value:: value },
            ],
          }] + [
            issue { message:: i.message, hint:: !present }
            for i in c.issues
            if present || !initial
          ]
          else hiddenControl { name:: name, value:: value },
      };

      local paramsForm = {
        local c = self,
        paramSpecs:: [],
        params:: {},
        initialValues:: {},
        issues:: [],
        html: {
          element: 'form',
          attributes: { id: paramsFormId, class: 'params', method: 'get' },
          children: [
            field {
              spec:: spec,
              params:: c.params,
              initialValues:: c.initialValues,
              issues:: [i for i in c.issues if std.get(i, 'param', null) == spec.name],
            }
            for spec in c.paramSpecs
          ],
        },
      };

      local planButton = {
        html: {
          element: 'button',
          attributes: { type: 'submit', form: paramsFormId },
          children: ['Plan'],
        },
      };

      local applyForm = {
        local c = self,
        evaluationId:: error 'applyForm requires an evaluationId',
        label:: 'Apply',
        html: {
          element: 'form',
          attributes: { class: 'apply', method: 'post', action: '/exec' },
          children: [
            { element: 'input', attributes: { type: 'hidden', name: 'evaluationId', value: c.evaluationId } },
            { element: 'button', attributes: { type: 'submit' }, children: [c.label] },
          ],
        },
      };

      {
        local c = self,
        evaluationId:: error 'Action requires an evaluationId',
        summary:: '',
        label:: 'Apply',
        paramSpecs:: [],
        params:: {},
        initialValues:: {},
        action:: null,
        local hasParams = std.length(c.paramSpecs) > 0,
        local issues = if c.action != null && std.objectHas(c.action, 'issues') then c.action.issues else [],
        local applicable = c.action != null && !std.objectHas(c.action, 'issues'),
        local paramNames = [spec.name for spec in c.paramSpecs if std.objectHas(controls, spec.type)],
        local formIssues = [i for i in issues if !std.member(paramNames, std.get(i, 'param', null))],
        html: [
          { element: 'style', children: [style] },
        ] + (if hasParams then [{ element: 'script', children: [{ html: script }] }] else []) + [
          {
            element: 'action-card',
            attributes: { class: 'action card' },
            children:
              (if c.summary != '' then [{ element: 'p', children: [c.summary] }] else []) +
              [
                issue { message:: if std.objectHas(i, 'param') then '%s: %s' % [i.param, i.message] else i.message }
                for i in formIssues
              ] +
              (if hasParams then [paramsForm { paramSpecs:: c.paramSpecs, params:: c.params, initialValues:: c.initialValues, issues:: issues }] else []) +
              [{
                element: 'div',
                attributes: { class: 'buttons' },
                children:
                  (if hasParams then [planButton] else []) +
                  (if applicable then [applyForm { evaluationId:: c.evaluationId, label:: c.label }] else []),
              }],
          },
        ],
      },
  };
  local html = {
    manifestHtml(tree): std.native('invoke:html')('manifestHtml', [tree]),
  };

  local isNode(value) =
    std.type(value) == 'object' && std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath');

  local collectNeighbors(obj, textPrefix='', exclude=[], linkStrings=false) =
    std.flatMap(
      function(k)
        if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
        else
          local value = obj[k];
          local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
          if isNode(value) then [{ link: value._queryPath, text: textPath }]
          else if std.type(value) == 'object' then collectNeighbors(value, textPath, exclude, linkStrings)
          else if linkStrings && std.type(value) == 'string' then [{ link: value, text: textPath, external: true }]
          else [],
      std.objectFields(obj)
    );

  local linksItems(obj) =
    local links = std.get(obj, 'links', {});
    if std.type(links) != 'object' then []
    else std.flatMap(
      function(k)
        local value = links[k];
        if isNode(value) then [{ link: value._queryPath, text: k }]
        else if std.type(value) == 'string' then [{ link: value, text: k, external: true }]
        else [],
      std.objectFields(links)
    );

  local filterItems(obj, title, items) =
    local hidden = std.get(std.get(std.get(obj, 'list', {}), 'hiddenItems', {}), title, []);
    [item for item in items if !std.member(hidden, item.text)];

  local linksGroups(obj) =
    local links = std.get(obj, 'links', {});
    if std.type(links) != 'object' then []
    else std.flatMap(
      function(k)
        local value = links[k];
        if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: filterItems(obj, k, collectNeighbors(value, linkStrings=true)) }]
        else [],
      std.objectFields(links)
    );

  local curatedLinks(obj) =
    std.set([
      item.link
      for item in linksItems(obj) + std.flatMap(function(group) group.items, linksGroups(obj))
    ]);

  local neighborKeys(obj) = [
    k
    for k in std.objectFields(obj)
    if !std.member(['data', '_view', 'links'], k) && std.substr(k, 0, 1) != '_' && std.type(obj[k]) == 'object'
  ];

  local nodeGroupsSpec(obj) = std.get(std.get(obj, 'list', {}), 'nodeGroups', {});

  local nodeGroupedKeys(obj) =
    local spec = nodeGroupsSpec(obj);
    std.set(std.flattenArrays([spec[title] for title in std.objectFields(spec)]));

  local neighborItems(obj) =
    local curated = curatedLinks(obj);
    local grouped = nodeGroupedKeys(obj);
    filterItems(obj, '', [
      { link: obj[k]._queryPath, text: k }
      for k in neighborKeys(obj)
      if isNode(obj[k]) && !std.setMember(obj[k]._queryPath, curated) && !std.setMember(k, grouped)
    ] + linksItems(obj));

  local nodeGroups(obj) =
    local spec = nodeGroupsSpec(obj);
    local curated = curatedLinks(obj);
    [
      group
      for title in std.objectFields(spec)
      for group in [{
        title: title,
        items: filterItems(obj, title, [
          { link: obj[k]._queryPath, text: k }
          for k in spec[title]
          if std.objectHas(obj, k) && isNode(obj[k]) && !std.setMember(obj[k]._queryPath, curated)
        ]),
      }]
      if std.length(group.items) > 0
    ];

  local childGroups(obj) =
    local curated = curatedLinks(obj);
    [
      group
      for k in neighborKeys(obj)
      if !isNode(obj[k])
      for group in [{ title: k, items: filterItems(obj, k, [item for item in collectNeighbors(obj[k]) if !std.setMember(item.link, curated)]) }]
      if std.length(group.items) > 0
    ];

  local orderGroups(groups, order) =
    local rank = { [order[i]]: i for i in std.range(0, std.length(order) - 1) };
    local keyed = [
      { group: groups[i], key: std.get(rank, groups[i].title, std.length(order) + i) }
      for i in std.range(0, std.length(groups) - 1)
    ];
    [entry.group for entry in std.sort(keyed, function(entry) entry.key)];

  local neighborGroups(obj) =
    local list = std.get(obj, 'list', {});
    local hidden = std.get(list, 'hiddenGroups', []);
    [
      group
      for group in orderGroups(linksGroups(obj) + childGroups(obj) + nodeGroups(obj), std.get(list, 'groupOrder', []))
      if !std.member(hidden, group.title)
    ];

  local safeGet(obj, path) =
    std.foldl(
      function(acc, k)
        if acc != null && std.isObject(acc) && std.objectHasAll(acc, k) then acc[k] else null,
      path,
      obj
    );

  local baseView = {
    local n = self,
    _view:: {
      fragment: error 'view requires a fragment',
      page: c.page {
        fragment:: n._view.fragment,
        breadcrumbs:: c.breadcrumbs { pathTemplate:: std.get($, '_pathTemplate', []), node:: $ },
      },
      html: html.manifestHtml(self.page),
    },
  };

  local listView = baseView {
    _view+:: {
      fragment: c.list {
        items:: neighborItems($),
        groups:: neighborGroups($),
        columns:: std.get(std.get($, 'list', {}), 'columns', 1),
      },
    },
  };

  local yamlView = baseView {
    _view+:: {
      fragment: c.yaml { data:: $.data },
    },
  };

  local columnValue(item, col) =
    if std.objectHasAll(col, 'value') then col.value(item) else safeGet(item, col.path);

  local isAlphanumeric(ch) =
    (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9');

  local labelWords(label) = [
    word
    for word in std.split(std.join('', [if isAlphanumeric(ch) then ch else ' ' for ch in std.stringChars(label)]), ' ')
    if word != ''
  ];

  local lowerCamelCase(label) =
    local parts = labelWords(std.toString(label));
    if std.length(parts) == 0 then ''
    else std.asciiLower(parts[0]) + std.join('', [std.asciiUpper(part[0]) + part[1:] for part in parts[1:]]);

  local columnKey(col) = std.get(col, 'key', lowerCamelCase(col.label));

  local projectItem(item, columns) = {
    [col.key]: value
    for col in columns
    for value in [columnValue(item, col)]
    if value != null
  };

  local tableView = baseView {
    data:: error 'table requires data',
    local table = std.get($, 'table', {}),
    local at = std.get(table, 'at', ['items']),
    local columns = [col { key: columnKey(col) } for col in std.get(table, 'columns', [])],
    local found = safeGet($.data, at),
    local dataItems = if std.isArray(found) then found else [],
    items: [projectItem(item, columns) for item in dataItems],
    _view+:: {
      fragment:
        c.table {
          items:: $.items,
          columns:: columns,
          rowLinks:: linkspecs.rowLinksFor($, std.get($, 'linkSpecs', []), at),
          pagination:: std.get(std.get($, 'links', {}), 'pagination', null),
        },
    },
  };

  local treeView = baseView {
    _view+:: {
      fragment:
        local tree = std.get($, 'tree', {});
        c.resource {
          items:: neighborItems($),
          groups:: neighborGroups($),
          columns:: std.get(std.get($, 'list', {}), 'columns', 1),
          content:: c.tree {
            nodes:: std.get(tree, 'nodes', []),
            item:: std.get(tree, 'item', super.item),
          },
        },
    },
  };

  local resourceView = baseView {
    _view+:: {
      fragment: c.resource {
        data:: $.data,
        items:: neighborItems($),
        groups:: neighborGroups($),
        columns:: std.get(std.get($, 'list', {}), 'columns', 1),
        stacked:: std.get(std.get($, 'resource', {}), 'stacked', false),
      },
    },
  };

  local actionView = baseView {
    _view+:: {
      fragment: c.action {
        evaluationId:: std.get($, '_evaluationId', ''),
        summary:: std.get($, '_summary', ''),
        paramSpecs:: std.get($, '_paramSpecs', []),
        params:: std.get($, '_params', {}),
        initialValues:: std.get($, '_paramInitialValues', {}),
        action:: std.get($, '_action', null),
      },
    },
  };

  local withNode = { node: self.view + linkspecs.withLinkSpecs };

  {
    default: { view: listView } + withNode,
    list: { view: listView } + withNode,
    table: { view: tableView } + withNode,
    tree: { view: treeView } + withNode,
    yaml: { view: yamlView } + withNode,
    resource: { view: resourceView } + withNode,
    action: { view: actionView } + withNode,
  };
local root = import 'root';
local invoke(name, args=[]) = std.native('invoke:course')(name, args);
local unrecorded = { _record: false };

local evaluationContentStyle = |||
  .evaluation-content {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.25em;
    width: 75vw;
  }
  .evaluation-preview {
    box-sizing: border-box;
    width: 100%;
    height: 70vh;
    border: 1px solid var(--border-color);
    background: var(--background-color);
  }
|||;

local evaluationContent = {
  local c = self,
  content:: error 'EvaluationContent requires content',
  src:: error 'EvaluationContent requires a src',
  html: [
    { element: 'style', children: [evaluationContentStyle] },
    {
      element: 'div',
      attributes: { class: 'evaluation-content' },
      children: [
        c.content,
        {
          element: 'iframe',
          attributes: {
            class: 'evaluation-preview card',
            src: c.src,
            sandbox: '',
            loading: 'lazy',
          },
          children: [],
        },
      ],
    },
  ],
};

local visitItem = {
  local c = self,
  node:: error 'VisitItem requires a node',
  html: [
    {
      element: 'a',
      attributes: { href: c.node.link },
      children: [c.node.address],
    },
    {
      element: 'span',
      attributes: { class: 'detail' },
      children: [
        if c.node.remarks == 0 then c.node.time
        else if c.node.remarks == 1 then '%s 1 remark' % c.node.time
        else '%s %d remarks' % [c.node.time, c.node.remarks],
      ],
    },
  ],
};

local executionItem = {
  local c = self,
  node:: error 'ExecutionItem requires a node',
  html: [
    {
      element: 'a',
      attributes: { href: c.node.link },
      children: ['execution'],
    },
    {
      element: 'span',
      attributes: { class: 'detail' },
      children: ['%s %s' % [c.node.time, c.node.status]],
    },
  ],
};

local courseItem = {
  local c = self,
  node:: error 'CourseItem requires a node',
  html: (if c.node.kind == 'execution' then executionItem else visitItem) { node:: c.node }.html,
};

[
  [['arcourse', 'sessions'], a.table.node + unrecorded {
    data:: { items: invoke('sessions') },
    table:: {
      at: ['items'],
      columns: [
        { label: 'Session', path: ['id'] },
        { label: 'Visits', path: ['visits'] },
        { label: 'First seen', path: ['first'] },
        { label: 'Last seen', path: ['last'] },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['id'] }],
        value: [{ const: 'arcourse' }, { param: 'session', path: ['id'] }],
      },
    ],
  }],
  [['arcourse', '$session'], a.tree.node + unrecorded {
    data: invoke('session', [$.session]),
    local session = root.arcourse.session($.session),
    local visitIds = { [visit.visitId]: true for visit in $.data.visits },
    local executionIds = { [execution.executionId]: true for execution in $.data.executions },
    local branches(visits, executions) = [
      entry.branch
      for entry in std.sort(
        [{ timestamp: visit.timestamp, branch: visitBranch(visit) } for visit in visits] +
        [{ timestamp: execution.timestamp, branch: executionBranch(execution) } for execution in executions],
        function(entry) entry.timestamp,
      )
    ],
    local visitBranch(visit) = {
      kind: 'visit',
      address: visit.address,
      time: std.substr(visit.timestamp, 11, 8),
      remarks: visit.remarks,
      link: session.visit(visit.visitId)._queryPath,
      children: branches(
        [child for child in $.data.visits if child.parent.visit == visit.visitId],
        [execution for execution in $.data.executions if execution.visitId == visit.visitId],
      ),
    },
    local executionBranch(execution) = {
      kind: 'execution',
      status: execution.status,
      time: std.substr(execution.timestamp, 11, 8),
      link: session.execution(execution.executionId)._queryPath,
      children: branches(
        [child for child in $.data.visits if child.parent.execution == execution.executionId],
        [],
      ),
    },
    tree:: {
      nodes: branches(
        [
          visit
          for visit in $.data.visits
          if !std.objectHas(visitIds, visit.parent.visit)
             && !std.objectHas(executionIds, visit.parent.execution)
        ],
        [
          execution
          for execution in $.data.executions
          if !std.objectHas(visitIds, execution.visitId)
        ],
      ),
      item: courseItem,
    },
  }],
  [['arcourse', '$session', '$visit'], a.resource.node + unrecorded {
    local visit = invoke('visit', [$.visit]),
    local session = invoke('session', [$.session]),
    local sessionNode = root.arcourse.session($.session),
    local visitOf = { [v.visitId]: v for v in session.visits },
    local parent = std.get(visitOf, $.visit, { parent: { visit: '', execution: '' } }).parent,
    local childIds = [v.visitId for v in session.visits if v.parent.visit == $.visit],
    local evaluations = visit.evaluations,
    local executions = visit.executions,
    data: {
      address: visit.address,
      versions: visit.versions,
      first: evaluations[0].timestamp,
      last: evaluations[std.length(evaluations) - 1].timestamp,
    } + (
      if std.length(visit.remarks) > 0
      then { remarks: [{ time: remark.timestamp, text: remark.text } for remark in visit.remarks] }
      else {}
    ),
    links: {
      course: {
        node: { _node: true, _queryPath: '/' + visit.address },
        session: sessionNode,
      },
    } + (
      if std.objectHas(visitOf, parent.visit)
      then { from: { [visitOf[parent.visit].address]: sessionNode.visit(parent.visit) } }
      else if parent.execution != ''
      then { from: { execution: sessionNode.execution(parent.execution) } }
      else {}
    ) + (
      if std.length(childIds) > 0
      then {
        next: {
          ['%02d %s' % [i + 1, visitOf[childIds[i]].address]]:
            sessionNode.visit(childIds[i])
          for i in std.range(0, std.length(childIds) - 1)
        },
      }
      else {}
    ) + (
      if std.length(executions) > 0
      then {
        executions: {
          ['%02d %s %s' % [i + 1, std.substr(executions[i].timestamp, 11, 8), executions[i].status]]:
            sessionNode.execution(executions[i].executionId)
          for i in std.range(0, std.length(executions) - 1)
        },
      }
      else {}
    ) + {
      versions: {
        ['%02d %s' % [i + 1, std.substr(evaluations[i].timestamp, 11, 8)]]:
          sessionNode.visit($.visit).evaluation(evaluations[i].evaluationId)
        for i in std.range(0, std.length(evaluations) - 1)
      },
    },
  }],
  [['arcourse', '$session', '$visit', '$evaluation'], a.resource.node + unrecorded {
    local evaluation = invoke('evaluation', [$.evaluation]),
    local visit = invoke('visit', [$.visit]),
    local evaluations = visit.evaluations,
    local remarks = [remark for remark in visit.remarks if remark.from == $.evaluation],
    local positions = [
      i
      for i in std.range(0, std.length(evaluations) - 1)
      if evaluations[i].evaluationId == $.evaluation
    ],
    local position = if std.length(positions) > 0 then positions[0] else -1,
    local adjacent = (
      if position > 0
      then {
        prev: root.arcourse.session($.session).visit($.visit)
              .evaluation(evaluations[position - 1].evaluationId),
      }
      else {}
    ) + (
      if position >= 0 && position < std.length(evaluations) - 1
      then {
        next: root.arcourse.session($.session).visit($.visit)
              .evaluation(evaluations[position + 1].evaluationId),
      }
      else {}
    ),
    data: {
      address: evaluation.address,
      timestamp: evaluation.timestamp,
      version: '%d of %d' % [position + 1, std.length(evaluations)],
    } + (
      if std.length(remarks) > 0
      then { remarks: [{ time: remark.timestamp, text: remark.text } for remark in remarks] }
      else {}
    ),
    links: {
      format: {
        html: $.html,
        json: $.json,
      },
      course: {
        node: { _node: true, _queryPath: '/' + evaluation.address },
        visit: root.arcourse.session($.session).visit($.visit),
        session: root.arcourse.session($.session),
      },
    } + (
      if std.length(adjacent) > 0
      then { versions: adjacent }
      else {}
    ),
    _view+:: {
      fragment: super.fragment {
        local yamlContent = super.content,
        content:: evaluationContent {
          content:: yamlContent,
          src:: $.html._queryPath,
        },
      },
    },
  }],
  [['arcourse', '$session', '$visit', '$evaluation', 'html'], unrecorded {
    _view:: { html: invoke('content', [$.evaluation, 'html']) },
  }],
  [['arcourse', '$session', '$visit', '$evaluation', 'json'], a.yaml.node + unrecorded {
    local content = std.parseJson(invoke('content', [$.evaluation, 'json'])),
    data: {
      [key]: content[key]
      for key in std.objectFields(content)
      if key != '_node'
    },
  }],
  [['arcourse', '$session', '$execution'], a.resource.node + unrecorded {
    local execution = invoke('execution', [$.execution]),
    local session = invoke('session', [$.session]),
    local sessionNode = root.arcourse.session($.session),
    local content = std.parseJson(invoke('content', [execution.from, 'json'])),
    local visitOf = { [v.visitId]: v for v in session.visits },
    local nextIds = [v.visitId for v in session.visits if v.parent.execution == $.execution],
    data: {
      address: execution.address,
      action: std.get(content, '_action', {}),
      status: execution.status,
      started: execution.timestamp,
    } + (
      if execution.finished != '' then { finished: execution.finished } else {}
    ) + (
      if execution['error'] != '' then { 'error': execution['error'] } else {}
    ),
    links: {
      course: {
        node: { _node: true, _queryPath: '/' + execution.address },
        evaluation: sessionNode.visit(execution.visitId).evaluation(execution.from),
        visit: sessionNode.visit(execution.visitId),
        session: sessionNode,
      },
    } + (
      if execution.hasOutput then { content: { output: $.output } } else {}
    ) + (
      if std.length(nextIds) > 0
      then {
        next: {
          ['%02d %s' % [i + 1, visitOf[nextIds[i]].address]]:
            sessionNode.visit(nextIds[i])
          for i in std.range(0, std.length(nextIds) - 1)
        },
      }
      else {}
    ),
  }],
  [['arcourse', '$session', '$execution', 'output'], a.yaml.node + unrecorded {
    data: { output: invoke('output', [$.execution]) },
  }],
]
