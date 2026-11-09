local a =
  local failure =
    local isFailure(value) = std.isObject(value) && std.objectHas(value, '_failure');

    {
      isFailure: isFailure,
      withFailure: {
        _failure:: if isFailure(std.get(self, 'response')) then self.response._failure else null,
      },
    };
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

    local originValue(node, name) =
      if std.objectHasAll(node, '_vars') && std.objectHas(node._vars, name) then node._vars[name] else node[name];

    local resolveBase(root, node, prefixSegs) =
      std.foldl(
        function(acc, seg)
          if std.objectHas(seg, 'const') then acc[seg.const]
          else acc[seg.origin](std.toString(originValue(node, seg.origin))),
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
      else if std.objectHas(seg, 'origin') then std.toString(originValue(node, seg.origin))
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
    failure:
      local style = |||
        @scope (.failure-card) {
          :scope.card {
            display: inline-flex;
            flex-direction: column;
            gap: 0.5em;
            padding: 0.75em 1em;
            border-color: var(--error-color);
            font-family: monospace;
          }
          .failure-title {
            margin: 0;
            color: var(--error-color);
            font-weight: bold;
          }
          .failure-message {
            margin: 0;
            white-space: pre-wrap;
            overflow-wrap: anywhere;
          }
        }
      |||;

      {
        local c = self,
        failure:: error 'Failure requires failure',
        local code = std.get(c.failure, 'code', null),
        local reason = std.get(c.failure, 'reason', null),
        local message = std.get(c.failure, 'message', null),
        local title = std.join(' ', [std.toString(part) for part in [code, reason] if part != null && part != '']),
        html: [
          { element: 'style', children: [style] },
          {
            element: 'div',
            attributes: { class: 'card failure-card', role: 'alert' },
            children: [
              { element: 'p', attributes: { class: 'failure-title' }, children: [if title == '' then 'Failure' else title] },
            ] + (
              if message == null || message == '' then []
              else [{ element: 'p', attributes: { class: 'failure-message' }, children: [std.toString(message)] }]
            ),
          },
        ],
      },
    breadcrumbs:
      local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
      local varName(seg) = std.substr(seg, 1, std.length(seg) - 1);
      local varValue(node, name) =
        if std.objectHasAll(node, '_vars') && std.objectHas(node._vars, name) then node._vars[name] else std.get(node, name, '');

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
                  local val = std.toString(varValue(c.node, v));
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

  local collectNeighbors(obj, textPrefix='', exclude=[], linkStrings=false, parent=[]) =
    std.flatMap(
      function(k)
        if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
        else
          local value = obj[k];
          local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
          if isNode(value) then [{ link: value._queryPath, text: textPath, name:: k, parent:: parent }]
          else if std.type(value) == 'object' then collectNeighbors(value, textPath, exclude, linkStrings, parent + [k])
          else if linkStrings && std.type(value) == 'string' then [{ link: value, text: textPath, external: true, name:: k, parent:: parent }]
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

  local groupByParent(prefix, items) =
    if std.all([std.length(item.parent) == 0 for item in items]) then [{ title: prefix, items: items }]
    else
      local titleOf(item) = std.join('/', [prefix] + item.parent);
      [
        { title: title, items: [item { text: item.name } for item in items if titleOf(item) == title] }
        for title in std.set([titleOf(item) for item in items])
      ];

  local linksGroups(obj) =
    local links = std.get(obj, 'links', {});
    if std.type(links) != 'object' then []
    else std.flatMap(
      function(k)
        local value = links[k];
        if std.type(value) == 'object' && !isNode(value) then [
          group
          for parent in groupByParent(k, collectNeighbors(value, linkStrings=true))
          for group in [{ title: parent.title, items: filterItems(obj, parent.title, parent.items) }]
        ]
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
      for parent in groupByParent(k, [item for item in collectNeighbors(obj[k]) if !std.setMember(item.link, curated)])
      for group in [{ title: parent.title, items: filterItems(obj, parent.title, parent.items) }]
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

  local failureView = failure.withFailure {
    _view+:: {
      fragment: if $._failure != null then c.failure { failure:: $._failure } else super.fragment,
    },
  };

  local withNode = {
    view+: failureView,
    node: self.view + linkspecs.withLinkSpecs,
  };

  {
    default: { view: listView } + withNode,
    list: { view: listView, component: c.list } + withNode,
    table: { view: tableView, component: c.table } + withNode,
    tree: { view: treeView, component: c.tree } + withNode,
    yaml: { view: yamlView, component: c.yaml } + withNode,
    resource: { view: resourceView, component: c.resource } + withNode,
    action: { view: actionView, component: c.action } + withNode,
    failure: { view: failureView, component: c.failure },
    page: { component: c.page },
    breadcrumbs: { component: c.breadcrumbs },
  },
      aws =
  local collect(value, path) =
    if value == null then []
    else if std.type(value) == 'array' then std.flatMap(function(v) collect(v, path), value)
    else if std.length(path) == 0 then [value]
    else if std.type(value) != 'object' then []
    else collect(std.get(value, path[0], null), path[1:]);

  local regional = {
    ctx:: { account: $.account, region: $.region },
  };

  local global = {
    ctx:: { account: $.account },
  };

  local paginated = {
    inputToken:: 'nextToken',
    outputToken:: 'nextToken',
    pageSize:: null,
    _paramSpecs+: [
      { name: name, type: if name == $.pageSize then 'number' else 'string', default: null }
      for name in [$.pageSize, $.inputToken]
      if name != null
    ],
    page:: {
      [name]: std.get($._params, name, null)
      for name in [$.pageSize, $.inputToken]
      if name != null
    },
    links+: {
      pagination:
        local params = std.get($, '_params', {});
        local next = std.get($.response, $.outputToken, null);
        (if std.get(params, $.inputToken, null) == null then {} else { first: $ { _params: params { [$.inputToken]: null } } })
        + (if next == null then {} else { next: $ { _params: params { [$.inputToken]: next } } }),
    },
  };

  local single = {
    itemsPath:: [],
    response:: error 'single requires a response',
    data:
      local items = collect(std.get($.response, $.itemsPath[0], null), $.itemsPath[1:]);
      if std.objectHas($.response, $.itemsPath[0]) && std.length(items) > 0 then items[0] else $.response,
  };

  local flattened = {
    itemsPath:: error 'flattened requires an itemsPath',
    response:: error 'flattened requires a response',
    data:: { items: collect(std.get($.response, $.itemsPath[0], null), $.itemsPath[1:]) },
  };

  local tag(key) = function(item)
    local matches = [t.Value for t in std.get(item, 'Tags', []) if std.get(t, 'Key', null) == key];
    if std.length(matches) == 0 then null else matches[0];

  {
    regional: regional,
    global: global,
    paginated: paginated,
    single: single,
    flattened: flattened,
    tag: tag,
  },
      root = import 'root',
      call(ctx, operation, input) = std.native('invoke:aws')('call', [ctx, 'ec2', operation, input]);

[
  [['aws', '$account', '$region'], {
    links+: {
      EC2: root.aws.account($.account).region($.region).ec2,
    },
  }],
  [['aws', '$account', '$region', 'ec2']],
  [['aws', '$account', '$region', 'ec2', 'addresses'], a.table.node + aws.regional + {
    response:: call(
      self.ctx,
      'DescribeAddresses',
      {}
    ),
    data:: self.response,
    table:: {
      at: ['Addresses'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'publicIp', kind: 'identifier', label: 'Public IP', path: ['PublicIp'], priority: 'primary' },
        { key: 'allocationId', kind: 'identifier', label: 'Allocation ID', path: ['AllocationId'], priority: 'secondary' },
        { key: 'instanceId', kind: 'identifier', label: 'Instance ID', path: ['InstanceId'], priority: 'secondary' },
        { key: 'privateIpAddress', kind: 'identifier', label: 'Private IP', path: ['PrivateIpAddress'], priority: 'secondary' },
        { key: 'domain', kind: 'text', label: 'Domain', path: ['Domain'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['Addresses'],
        keys: [{ path: ['AllocationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'addresses' }, { param: 'AllocationId', path: ['AllocationId'] }],
      },
      {
        at: ['Addresses'],
        keys: [{ const: 'instance' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
      {
        at: ['Addresses'],
        keys: [{ const: 'network interface' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: ['Addresses'],
        keys: [{ const: 'subnet' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'addresses', '$AllocationId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['Addresses'],
    response:: call(
      self.ctx,
      'DescribeAddresses',
      {
        AllocationIds: [$.AllocationId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'instance' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
      {
        at: [],
        keys: [{ const: 'network interface' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: [],
        keys: [{ const: 'subnet' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeClientVpnEndpoints',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['ClientVpnEndpoints'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'endpointId', kind: 'identifier', label: 'Endpoint ID', path: ['ClientVpnEndpointId'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['Status', 'Code'], priority: 'secondary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'secondary' },
        { key: 'clientCidrBlock', kind: 'text', label: 'Client CIDR', path: ['ClientCidrBlock'], priority: 'secondary' },
        { key: 'creationTime', kind: 'timestamp', label: 'Created', path: ['CreationTime'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['ClientVpnEndpoints'],
        keys: [{ path: ['ClientVpnEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'clientVpnEndpoints' }, { param: 'ClientVpnEndpointId', path: ['ClientVpnEndpointId'] }],
      },
      {
        at: ['ClientVpnEndpoints', 'AssociatedTargetNetworks'],
        keys: [{ const: 'subnet' }, { path: ['NetworkId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['NetworkId'] }],
      },
      {
        at: ['ClientVpnEndpoints', 'SecurityGroupIds'],
        keys: [{ const: 'security groups' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: [] }],
      },
      {
        at: ['ClientVpnEndpoints'],
        keys: [{ const: 'transit gateway attachment' }, { path: ['ClientVpnEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGatewayAttachments' }, { param: 'TransitGatewayAttachmentId', path: ['TransitGatewayConfiguration', 'TransitGatewayAttachmentId'] }],
      },
      {
        at: ['ClientVpnEndpoints'],
        keys: [{ const: 'transit gateway' }, { path: ['ClientVpnEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayConfiguration', 'TransitGatewayId'] }],
      },
      {
        at: ['ClientVpnEndpoints'],
        keys: [{ const: 'vpc' }, { path: ['ClientVpnEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints', '$ClientVpnEndpointId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['ClientVpnEndpoints'],
    response:: call(
      self.ctx,
      'DescribeClientVpnEndpoints',
      {
        ClientVpnEndpointIds: [$.ClientVpnEndpointId],
      }
    ),
    linkSpecs:: [
      {
        at: ['AssociatedTargetNetworks'],
        keys: [{ const: 'subnet' }, { path: ['NetworkId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['NetworkId'] }],
      },
      {
        at: ['SecurityGroupIds'],
        keys: [{ const: 'security groups' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: [] }],
      },
      {
        at: [],
        keys: [{ const: 'transit gateway attachment' }, { path: ['ClientVpnEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGatewayAttachments' }, { param: 'TransitGatewayAttachmentId', path: ['TransitGatewayConfiguration', 'TransitGatewayAttachmentId'] }],
      },
      {
        at: [],
        keys: [{ const: 'transit gateway' }, { path: ['ClientVpnEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayConfiguration', 'TransitGatewayId'] }],
      },
      {
        at: [],
        keys: [{ const: 'vpc' }, { path: ['ClientVpnEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints', '$ClientVpnEndpointId', 'clientVpnAuthorizationRules'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeClientVpnAuthorizationRules',
      self.page {
        ClientVpnEndpointId: $.ClientVpnEndpointId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['AuthorizationRules'],
      columns: [
        { key: 'destinationCidr', kind: 'text', label: 'Destination CIDR', path: ['DestinationCidr'], priority: 'primary' },
        { key: 'groupId', kind: 'identifier', label: 'Group ID', path: ['GroupId'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['Status', 'Code'], priority: 'secondary' },
        { key: 'accessAll', kind: 'boolean', label: 'Access All', path: ['AccessAll'], priority: 'secondary' },
      ],
    },
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints', '$ClientVpnEndpointId', 'clientVpnConnections'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeClientVpnConnections',
      self.page {
        ClientVpnEndpointId: $.ClientVpnEndpointId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['Connections'],
      columns: [
        { key: 'username', kind: 'name', label: 'Username', path: ['Username'], priority: 'primary' },
        { key: 'connectionId', kind: 'identifier', label: 'Connection ID', path: ['ConnectionId'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['Status', 'Code'], priority: 'secondary' },
        { key: 'clientIp', kind: 'text', label: 'Client IP', path: ['ClientIp'], priority: 'secondary' },
        { key: 'established', kind: 'timestamp', label: 'Established', path: ['ConnectionEstablishedTime'], priority: 'tertiary' },
      ],
    },
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints', '$ClientVpnEndpointId', 'clientVpnRoutes'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeClientVpnRoutes',
      self.page {
        ClientVpnEndpointId: $.ClientVpnEndpointId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['Routes'],
      columns: [
        { key: 'destination', kind: 'text', label: 'Destination CIDR', path: ['DestinationCidr'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['Status', 'Code'], priority: 'secondary' },
        { key: 'target_subnet', kind: 'identifier', label: 'Target subnet', path: ['TargetSubnet'], priority: 'secondary' },
        { key: 'origin', kind: 'text', label: 'Origin', path: ['Origin'], priority: 'secondary' },
        { key: 'type', kind: 'text', label: 'Type', path: ['Type'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['Routes'],
        keys: [{ const: 'subnet' }, { path: ['TargetSubnet'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['TargetSubnet'] }],
      },
      {
        at: ['Routes'],
        keys: [{ const: 'transit gateway attachment' }, { path: ['TransitGatewayAttachmentId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGatewayAttachments' }, { param: 'TransitGatewayAttachmentId', path: ['TransitGatewayAttachmentId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints', '$ClientVpnEndpointId', 'clientVpnTargetNetworks'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeClientVpnTargetNetworks',
      self.page {
        ClientVpnEndpointId: $.ClientVpnEndpointId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['ClientVpnTargetNetworks'],
      columns: [
        { key: 'targetNetworkId', kind: 'identifier', label: 'Target Network ID', path: ['TargetNetworkId'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['Status', 'Code'], priority: 'secondary' },
        { key: 'associationId', kind: 'identifier', label: 'Association ID', path: ['AssociationId'], priority: 'secondary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['ClientVpnTargetNetworks'],
        keys: [{ path: ['AssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'clientVpnEndpoints' }, { origin: 'ClientVpnEndpointId' }, { const: 'clientVpnTargetNetworks' }, { param: 'AssociationId', path: ['AssociationId'] }],
      },
      {
        at: ['ClientVpnTargetNetworks'],
        keys: [{ const: 'vpc' }, { path: ['AssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['ClientVpnTargetNetworks'],
        keys: [{ const: 'target subnet' }, { path: ['AssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['TargetNetworkId'] }],
      },
      {
        at: ['ClientVpnTargetNetworks', 'SecurityGroups'],
        keys: [{ const: 'security group' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: [] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints', '$ClientVpnEndpointId', 'clientVpnTargetNetworks', '$AssociationId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['ClientVpnTargetNetworks'],
    response:: call(
      self.ctx,
      'DescribeClientVpnTargetNetworks',
      {
        ClientVpnEndpointId: $.ClientVpnEndpointId,
        AssociationIds: [$.AssociationId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'vpc' }, { path: ['AssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: [],
        keys: [{ const: 'target subnet' }, { path: ['AssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['TargetNetworkId'] }],
      },
      {
        at: ['SecurityGroups'],
        keys: [{ const: 'security group' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: [] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'clientVpnEndpoints', '$ClientVpnEndpointId', 'authorizationPolicy'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetClientVpnEndpointAuthorizationPolicy',
      {
        ClientVpnEndpointId: $.ClientVpnEndpointId,
      }
    ),
    data: self.response,
  }],
  [['aws', '$account', '$region', 'ec2', 'customerGateways'], a.table.node + aws.regional + {
    response:: call(
      self.ctx,
      'DescribeCustomerGateways',
      {}
    ),
    data:: self.response,
    table:: {
      at: ['CustomerGateways'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'customerGatewayId', kind: 'identifier', label: 'Gateway ID', path: ['CustomerGatewayId'], priority: 'primary' },
        { key: 'deviceName', kind: 'name', label: 'Device name', path: ['DeviceName'], priority: 'secondary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'ipAddress', kind: 'text', label: 'IP address', path: ['IpAddress'], priority: 'secondary' },
        { key: 'type', kind: 'text', label: 'Type', path: ['Type'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['CustomerGateways'],
        keys: [{ path: ['CustomerGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'customerGateways' }, { param: 'CustomerGatewayId', path: ['CustomerGatewayId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'customerGateways', '$CustomerGatewayId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['CustomerGateways'],
    response:: call(
      self.ctx,
      'DescribeCustomerGateways',
      {
        CustomerGatewayIds: [$.CustomerGatewayId],
      }
    ),
  }],
  [['aws', '$account', '$region', 'ec2', 'dhcpOptions'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeDhcpOptions',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['DhcpOptions'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'dhcpOptionsId', kind: 'identifier', label: 'DHCP options ID', path: ['DhcpOptionsId'], priority: 'primary' },
        { key: 'ownerId', kind: 'identifier', label: 'Owner ID', path: ['OwnerId'], priority: 'secondary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['DhcpOptions'],
        keys: [{ path: ['DhcpOptionsId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'dhcpOptions' }, { param: 'DhcpOptionsId', path: ['DhcpOptionsId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'dhcpOptions', '$DhcpOptionsId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['DhcpOptions'],
    response:: call(
      self.ctx,
      'DescribeDhcpOptions',
      {
        DhcpOptionsIds: [$.DhcpOptionsId],
      }
    ),
  }],
  [['aws', '$account', '$region', 'ec2', 'egressOnlyInternetGateways'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeEgressOnlyInternetGateways',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['EgressOnlyInternetGateways'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'gatewayId', kind: 'identifier', label: 'Gateway ID', path: ['EgressOnlyInternetGatewayId'], priority: 'primary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['EgressOnlyInternetGateways'],
        keys: [{ path: ['EgressOnlyInternetGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'egressOnlyInternetGateways' }, { param: 'EgressOnlyInternetGatewayId', path: ['EgressOnlyInternetGatewayId'] }],
      },
      {
        at: ['EgressOnlyInternetGateways', 'Attachments'],
        keys: [{ const: 'vpc' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'egressOnlyInternetGateways', '$EgressOnlyInternetGatewayId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['EgressOnlyInternetGateways'],
    response:: call(
      self.ctx,
      'DescribeEgressOnlyInternetGateways',
      {
        EgressOnlyInternetGatewayIds: [$.EgressOnlyInternetGatewayId],
      }
    ),
    linkSpecs:: [
      {
        at: ['Attachments'],
        keys: [{ const: 'vpc' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'instances'], a.table.node + aws.regional + aws.paginated + aws.flattened + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeInstances',
      self.page {
        IncludeManagedResources: std.get($._params, 'IncludeManagedResources', null),
      }
    ),
    itemsPath:: ['Reservations', 'Instances'],
    table:: {
      at: ['items'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'instanceId', kind: 'identifier', label: 'Instance ID', path: ['InstanceId'], priority: 'primary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State', 'Name'], priority: 'secondary' },
        { key: 'instanceType', kind: 'text', label: 'Instance type', path: ['InstanceType'], priority: 'secondary' },
        { key: 'privateIp', kind: 'text', label: 'Private IP', path: ['PrivateIpAddress'], priority: 'secondary' },
        { key: 'availabilityZone', kind: 'text', label: 'Availability zone', path: ['Placement', 'AvailabilityZone'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
      {
        at: ['items', 'BlockDeviceMappings'],
        keys: [{ const: 'volumes' }, { path: ['DeviceName'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'volumes' }, { param: 'VolumeId', path: ['Ebs', 'VolumeId'] }],
      },
      {
        at: ['items', 'NetworkInterfaces'],
        keys: [{ const: 'network interfaces' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: ['items', 'NetworkInterfaces', 'Groups'],
        keys: [{ const: 'network interface security groups' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['items', 'NetworkInterfaces'],
        keys: [{ const: 'network interface subnets' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['items', 'NetworkInterfaces'],
        keys: [{ const: 'network interface VPCs' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['items', 'SecurityGroups'],
        keys: [{ const: 'security groups' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['items'],
        keys: [{ const: 'subnet' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['items'],
        keys: [{ const: 'VPC' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'IncludeManagedResources', type: 'boolean' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'instances', '$InstanceId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['Reservations', 'Instances'],
    response:: call(
      self.ctx,
      'DescribeInstances',
      {
        InstanceIds: [$.InstanceId],
      }
    ),
    linkSpecs:: [
      {
        at: ['BlockDeviceMappings'],
        keys: [{ const: 'volumes' }, { path: ['DeviceName'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'volumes' }, { param: 'VolumeId', path: ['Ebs', 'VolumeId'] }],
      },
      {
        at: ['NetworkInterfaces'],
        keys: [{ const: 'network interfaces' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: ['NetworkInterfaces', 'Groups'],
        keys: [{ const: 'network interface security groups' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['NetworkInterfaces'],
        keys: [{ const: 'network interface subnets' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['NetworkInterfaces'],
        keys: [{ const: 'network interface VPCs' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['SecurityGroups'],
        keys: [{ const: 'security groups' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: [],
        keys: [{ const: 'subnet' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: [],
        keys: [{ const: 'VPC' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'instances', '$InstanceId', 'consoleOutput'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetConsoleOutput',
      {
        InstanceId: $.InstanceId,
        Latest: std.get($._params, 'Latest', null),
      }
    ),
    data: self.response,
    _paramSpecs+: [
      { default: null, name: 'Latest', type: 'boolean' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'instances', '$InstanceId', 'consoleScreenshot'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetConsoleScreenshot',
      {
        InstanceId: $.InstanceId,
        WakeUp: std.get($._params, 'WakeUp', null),
      }
    ),
    data: self.response,
    _paramSpecs+: [
      { default: null, name: 'WakeUp', type: 'boolean' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'instances', '$InstanceId', 'uefiData'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetInstanceUefiData',
      {
        InstanceId: $.InstanceId,
      }
    ),
    data: self.response,
  }],
  [['aws', '$account', '$region', 'ec2', 'instances', '$InstanceId', 'launchTemplateData'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetLaunchTemplateData',
      {
        InstanceId: $.InstanceId,
      }
    ),
    data: self.response,
    linkSpecs:: [
      {
        at: ['LaunchTemplateData'],
        keys: [{ const: 'key pair' }, { path: ['KeyName'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'keyPairs' }, { param: 'KeyName', path: ['KeyName'] }],
      },
      {
        at: ['LaunchTemplateData', 'SecurityGroupIds'],
        keys: [{ const: 'security groups' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: [] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'internetGateways'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeInternetGateways',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['InternetGateways'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'internet_gateway_id', kind: 'identifier', label: 'Internet gateway ID', path: ['InternetGatewayId'], priority: 'primary' },
        { key: 'owner_id', kind: 'identifier', label: 'Owner ID', path: ['OwnerId'], priority: 'secondary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['InternetGateways'],
        keys: [{ path: ['InternetGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'internetGateways' }, { param: 'InternetGatewayId', path: ['InternetGatewayId'] }],
      },
      {
        at: ['InternetGateways', 'Attachments'],
        keys: [{ const: 'vpc' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'internetGateways', '$InternetGatewayId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['InternetGateways'],
    response:: call(
      self.ctx,
      'DescribeInternetGateways',
      {
        InternetGatewayIds: [$.InternetGatewayId],
      }
    ),
    linkSpecs:: [
      {
        at: ['Attachments'],
        keys: [{ const: 'vpc' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'keyPairs'], a.table.node + aws.regional + {
    response:: call(
      self.ctx,
      'DescribeKeyPairs',
      {
        IncludePublicKey: std.get($._params, 'IncludePublicKey', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['KeyPairs'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'key_name', kind: 'name', label: 'Key name', path: ['KeyName'], priority: 'primary' },
        { key: 'key_pair_id', kind: 'identifier', label: 'Key pair ID', path: ['KeyPairId'], priority: 'secondary' },
        { key: 'key_type', kind: 'text', label: 'Key type', path: ['KeyType'], priority: 'secondary' },
        { key: 'create_time', kind: 'timestamp', label: 'Created', path: ['CreateTime'], priority: 'tertiary' },
        { key: 'fingerprint', kind: 'text', label: 'Fingerprint', path: ['KeyFingerprint'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['KeyPairs'],
        keys: [{ path: ['KeyName'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'keyPairs' }, { param: 'KeyName', path: ['KeyName'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'IncludePublicKey', type: 'boolean' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'keyPairs', '$KeyName'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['KeyPairs'],
    response:: call(
      self.ctx,
      'DescribeKeyPairs',
      {
        KeyNames: [$.KeyName],
      }
    ),
  }],
  [['aws', '$account', '$region', 'ec2', 'launchTemplates'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeLaunchTemplates',
      self.page {
        IncludeManagedResources: std.get($._params, 'IncludeManagedResources', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['LaunchTemplates'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'LaunchTemplateName', kind: 'name', label: 'Launch template', path: ['LaunchTemplateName'], priority: 'primary' },
        { key: 'LaunchTemplateId', kind: 'identifier', label: 'Template ID', path: ['LaunchTemplateId'], priority: 'secondary' },
        { key: 'DefaultVersionNumber', kind: 'number', label: 'Default version', path: ['DefaultVersionNumber'], priority: 'secondary' },
        { key: 'LatestVersionNumber', kind: 'number', label: 'Latest version', path: ['LatestVersionNumber'], priority: 'secondary' },
        { key: 'CreateTime', kind: 'timestamp', label: 'Created', path: ['CreateTime'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['LaunchTemplates'],
        keys: [{ path: ['LaunchTemplateId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'launchTemplates' }, { param: 'LaunchTemplateId', path: ['LaunchTemplateId'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'IncludeManagedResources', type: 'boolean' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'launchTemplates', '$LaunchTemplateId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['LaunchTemplates'],
    response:: call(
      self.ctx,
      'DescribeLaunchTemplates',
      {
        LaunchTemplateIds: [$.LaunchTemplateId],
      }
    ),
  }],
  [['aws', '$account', '$region', 'ec2', 'natGateways'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeNatGateways',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['NatGateways'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'nat_gateway_id', kind: 'identifier', label: 'NAT Gateway ID', path: ['NatGatewayId'], priority: 'primary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'connectivity_type', kind: 'text', label: 'Connectivity', path: ['ConnectivityType'], priority: 'secondary' },
        { key: 'subnet_id', kind: 'identifier', label: 'Subnet ID', path: ['SubnetId'], priority: 'secondary' },
        { key: 'vpc_id', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'secondary' },
        { key: 'create_time', kind: 'timestamp', label: 'Created', path: ['CreateTime'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['NatGateways'],
        keys: [{ path: ['NatGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'natGateways' }, { param: 'NatGatewayId', path: ['NatGatewayId'] }],
      },
      {
        at: ['NatGateways', 'NatGatewayAddresses'],
        keys: [{ const: 'elastic IP' }, { path: ['AllocationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'addresses' }, { param: 'AllocationId', path: ['AllocationId'] }],
      },
      {
        at: ['NatGateways', 'NatGatewayAddresses'],
        keys: [{ const: 'network interface' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: ['NatGateways'],
        keys: [{ const: 'route table' }, { path: ['NatGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'routeTables' }, { param: 'RouteTableId', path: ['RouteTableId'] }],
      },
      {
        at: ['NatGateways'],
        keys: [{ const: 'subnet' }, { path: ['NatGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['NatGateways'],
        keys: [{ const: 'VPC' }, { path: ['NatGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['NatGateways', 'AttachedAppliances'],
        keys: [{ const: 'VPC endpoint' }, { path: ['VpcEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcEndpoints' }, { param: 'VpcEndpointId', path: ['VpcEndpointId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'natGateways', '$NatGatewayId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['NatGateways'],
    response:: call(
      self.ctx,
      'DescribeNatGateways',
      {
        NatGatewayIds: [$.NatGatewayId],
      }
    ),
    linkSpecs:: [
      {
        at: ['NatGatewayAddresses'],
        keys: [{ const: 'elastic IP' }, { path: ['AllocationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'addresses' }, { param: 'AllocationId', path: ['AllocationId'] }],
      },
      {
        at: ['NatGatewayAddresses'],
        keys: [{ const: 'network interface' }, { path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: [],
        keys: [{ const: 'route table' }, { path: ['NatGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'routeTables' }, { param: 'RouteTableId', path: ['RouteTableId'] }],
      },
      {
        at: [],
        keys: [{ const: 'subnet' }, { path: ['NatGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: [],
        keys: [{ const: 'VPC' }, { path: ['NatGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['AttachedAppliances'],
        keys: [{ const: 'VPC endpoint' }, { path: ['VpcEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcEndpoints' }, { param: 'VpcEndpointId', path: ['VpcEndpointId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'networkAcls'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeNetworkAcls',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['NetworkAcls'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'networkAclId', kind: 'identifier', label: 'Network ACL ID', path: ['NetworkAclId'], priority: 'primary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'secondary' },
        { key: 'isDefault', kind: 'boolean', label: 'Default', path: ['IsDefault'], priority: 'secondary' },
        { key: 'ownerId', kind: 'identifier', label: 'Owner ID', path: ['OwnerId'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['NetworkAcls'],
        keys: [{ path: ['NetworkAclId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkAcls' }, { param: 'NetworkAclId', path: ['NetworkAclId'] }],
      },
      {
        at: ['NetworkAcls'],
        keys: [{ const: 'vpc' }, { path: ['NetworkAclId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['NetworkAcls', 'Associations'],
        keys: [{ const: 'subnet' }, { path: ['NetworkAclAssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'networkAcls', '$NetworkAclId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['NetworkAcls'],
    response:: call(
      self.ctx,
      'DescribeNetworkAcls',
      {
        NetworkAclIds: [$.NetworkAclId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'vpc' }, { path: ['NetworkAclId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['Associations'],
        keys: [{ const: 'subnet' }, { path: ['NetworkAclAssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'networkInterfaces'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeNetworkInterfaces',
      self.page {
        IncludeManagedResources: std.get($._params, 'IncludeManagedResources', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['NetworkInterfaces'],
      columns: [
        { key: 'networkInterfaceId', kind: 'identifier', label: 'Network interface ID', path: ['NetworkInterfaceId'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['Status'], priority: 'secondary' },
        { key: 'privateIpAddress', kind: 'text', label: 'Private IP', path: ['PrivateIpAddress'], priority: 'secondary' },
        { key: 'subnetId', kind: 'identifier', label: 'Subnet ID', path: ['SubnetId'], priority: 'secondary' },
        { key: 'instanceId', kind: 'identifier', label: 'Instance ID', path: ['Attachment', 'InstanceId'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['NetworkInterfaces'],
        keys: [{ path: ['NetworkInterfaceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: ['NetworkInterfaces', 'Association'],
        keys: [{ const: 'elastic IP' }, { path: ['AllocationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'addresses' }, { param: 'AllocationId', path: ['AllocationId'] }],
      },
      {
        at: ['NetworkInterfaces', 'Attachment'],
        keys: [{ const: 'instance' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
      {
        at: ['NetworkInterfaces', 'Groups'],
        keys: [{ const: 'security group' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['NetworkInterfaces', 'AssociatedSubnets'],
        keys: [{ const: 'associated subnet' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: [] }],
      },
      {
        at: ['NetworkInterfaces'],
        keys: [{ const: 'subnet' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['NetworkInterfaces'],
        keys: [{ const: 'VPC' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['NetworkInterfaces', 'PrivateIpAddresses', 'Association'],
        keys: [{ const: 'elastic IP' }, { path: ['AllocationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'addresses' }, { param: 'AllocationId', path: ['AllocationId'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'IncludeManagedResources', type: 'boolean' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'networkInterfaces', '$NetworkInterfaceId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['NetworkInterfaces'],
    response:: call(
      self.ctx,
      'DescribeNetworkInterfaces',
      {
        NetworkInterfaceIds: [$.NetworkInterfaceId],
      }
    ),
    linkSpecs:: [
      {
        at: ['Association'],
        keys: [{ const: 'elastic IP' }, { path: ['AllocationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'addresses' }, { param: 'AllocationId', path: ['AllocationId'] }],
      },
      {
        at: ['Attachment'],
        keys: [{ const: 'instance' }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
      {
        at: ['Groups'],
        keys: [{ const: 'security group' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['AssociatedSubnets'],
        keys: [{ const: 'associated subnet' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: [] }],
      },
      {
        at: [],
        keys: [{ const: 'subnet' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: [],
        keys: [{ const: 'VPC' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['PrivateIpAddresses', 'Association'],
        keys: [{ const: 'elastic IP' }, { path: ['AllocationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'addresses' }, { param: 'AllocationId', path: ['AllocationId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'networkInterfaces', '$NetworkInterfaceId', 'attribute'], a.table.node + aws.regional + {
    response:: call(
      self.ctx,
      'DescribeNetworkInterfaceAttribute',
      {
        NetworkInterfaceId: $.NetworkInterfaceId,
        Attribute: std.get($._params, 'Attribute', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['Groups'],
      columns: [
        { key: 'groupName', kind: 'name', label: 'Group name', path: ['GroupName'], priority: 'primary' },
        { key: 'groupId', kind: 'identifier', label: 'Group ID', path: ['GroupId'], priority: 'secondary' },
      ],
    },
    _paramSpecs+: [
      { default: null, name: 'Attribute', type: 'string' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'routeTables'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeRouteTables',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['RouteTables'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'routeTableId', kind: 'identifier', label: 'Route table ID', path: ['RouteTableId'], priority: 'primary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'secondary' },
        { key: 'ownerId', kind: 'identifier', label: 'Owner ID', path: ['OwnerId'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['RouteTables'],
        keys: [{ path: ['RouteTableId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'routeTables' }, { param: 'RouteTableId', path: ['RouteTableId'] }],
      },
      {
        at: ['RouteTables'],
        keys: [{ const: 'vpc' }, { path: ['RouteTableId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['RouteTables', 'Associations'],
        keys: [{ const: 'subnet' }, { path: ['RouteTableAssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['RouteTables', 'PropagatingVgws'],
        keys: [{ const: 'VPN gateway' }, { path: ['GatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpnGateways' }, { param: 'VpnGatewayId', path: ['GatewayId'] }],
      },
      {
        at: ['RouteTables', 'Routes'],
        keys: [{ const: 'egress-only internet gateway' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'egressOnlyInternetGateways' }, { param: 'EgressOnlyInternetGatewayId', path: ['EgressOnlyInternetGatewayId'] }],
      },
      {
        at: ['RouteTables', 'Routes'],
        keys: [{ const: 'instance' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
      {
        at: ['RouteTables', 'Routes'],
        keys: [{ const: 'NAT gateway' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'natGateways' }, { param: 'NatGatewayId', path: ['NatGatewayId'] }],
      },
      {
        at: ['RouteTables', 'Routes'],
        keys: [{ const: 'network interface' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: ['RouteTables', 'Routes'],
        keys: [{ const: 'transit gateway' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
      {
        at: ['RouteTables', 'Routes'],
        keys: [{ const: 'VPC peering connection' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'routeTables', '$RouteTableId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['RouteTables'],
    response:: call(
      self.ctx,
      'DescribeRouteTables',
      {
        RouteTableIds: [$.RouteTableId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'vpc' }, { path: ['RouteTableId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['Associations'],
        keys: [{ const: 'subnet' }, { path: ['RouteTableAssociationId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['PropagatingVgws'],
        keys: [{ const: 'VPN gateway' }, { path: ['GatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpnGateways' }, { param: 'VpnGatewayId', path: ['GatewayId'] }],
      },
      {
        at: ['Routes'],
        keys: [{ const: 'egress-only internet gateway' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'egressOnlyInternetGateways' }, { param: 'EgressOnlyInternetGatewayId', path: ['EgressOnlyInternetGatewayId'] }],
      },
      {
        at: ['Routes'],
        keys: [{ const: 'instance' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
      {
        at: ['Routes'],
        keys: [{ const: 'NAT gateway' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'natGateways' }, { param: 'NatGatewayId', path: ['NatGatewayId'] }],
      },
      {
        at: ['Routes'],
        keys: [{ const: 'network interface' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: ['NetworkInterfaceId'] }],
      },
      {
        at: ['Routes'],
        keys: [{ const: 'transit gateway' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
      {
        at: ['Routes'],
        keys: [{ const: 'VPC peering connection' }, { path: ['DestinationCidrBlock'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'securityGroups'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeSecurityGroups',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['SecurityGroups'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'groupName', kind: 'name', label: 'Group name', path: ['GroupName'], priority: 'primary' },
        { key: 'groupId', kind: 'identifier', label: 'Group ID', path: ['GroupId'], priority: 'secondary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'secondary' },
        { key: 'ownerId', kind: 'identifier', label: 'Owner ID', path: ['OwnerId'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['SecurityGroups'],
        keys: [{ path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['SecurityGroups'],
        keys: [{ const: 'vpc' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['SecurityGroups', 'IpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'referenced security group' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['SecurityGroups', 'IpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'vpc' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['SecurityGroups', 'IpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'VPC peering connection' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
      {
        at: ['SecurityGroups', 'IpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'referenced security group (egress)' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['SecurityGroups', 'IpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'vpc (egress)' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['SecurityGroups', 'IpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'VPC peering connection (egress)' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'securityGroups', '$GroupId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['SecurityGroups'],
    response:: call(
      self.ctx,
      'DescribeSecurityGroups',
      {
        GroupIds: [$.GroupId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'vpc' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['IpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'referenced security group' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['IpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'vpc' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['IpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'VPC peering connection' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
      {
        at: ['IpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'referenced security group (egress)' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['IpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'vpc (egress)' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['IpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'VPC peering connection (egress)' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'securityGroups', '$GroupId', 'references'], a.table.node + aws.regional + {
    response:: call(
      self.ctx,
      'DescribeSecurityGroupReferences',
      {
        GroupId: $.GroupId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['SecurityGroupReferenceSet'],
      columns: [
        { key: 'groupId', kind: 'identifier', label: 'Group ID', path: ['GroupId'], priority: 'primary' },
        { key: 'referencingVpcId', kind: 'identifier', label: 'Referencing VPC', path: ['ReferencingVpcId'], priority: 'secondary' },
        { key: 'transitGatewayId', kind: 'identifier', label: 'Transit Gateway', path: ['TransitGatewayId'], priority: 'secondary' },
        { key: 'vpcPeeringConnectionId', kind: 'identifier', label: 'Peering Connection', path: ['VpcPeeringConnectionId'], priority: 'secondary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['SecurityGroupReferenceSet'],
        keys: [{ const: 'vpc' }, { path: ['ReferencingVpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['ReferencingVpcId'] }],
      },
      {
        at: ['SecurityGroupReferenceSet'],
        keys: [{ const: 'transit gateway' }, { path: ['TransitGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
      {
        at: ['SecurityGroupReferenceSet'],
        keys: [{ const: 'VPC peering connection' }, { path: ['VpcPeeringConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'subnets'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeSubnets',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['Subnets'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'subnetId', kind: 'identifier', label: 'Subnet ID', path: ['SubnetId'], priority: 'primary' },
        { key: 'cidrBlock', kind: 'text', label: 'IPv4 CIDR', path: ['CidrBlock'], priority: 'secondary' },
        { key: 'availabilityZone', kind: 'text', label: 'Availability Zone', path: ['AvailabilityZone'], priority: 'secondary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'availableIpAddressCount', kind: 'count', label: 'Available IPs', path: ['AvailableIpAddressCount'], priority: 'secondary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['Subnets'],
        keys: [{ path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['Subnets'],
        keys: [{ const: 'vpc' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'subnets', '$SubnetId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['Subnets'],
    response:: call(
      self.ctx,
      'DescribeSubnets',
      {
        SubnetIds: [$.SubnetId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'vpc' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'subnets', '$SubnetId', 'cidrReservations'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetSubnetCidrReservations',
      {
        SubnetId: $.SubnetId,
        MaxResults: std.get($._params, 'MaxResults', null),
        NextToken: std.get($._params, 'NextToken', null),
      }
    ),
    data: self.response,
    _paramSpecs+: [
      { default: null, name: 'MaxResults', type: 'number' },
      { default: null, name: 'NextToken', type: 'string' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'transitGatewayAttachments'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeTransitGatewayAttachments',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['TransitGatewayAttachments'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'attachmentId', kind: 'identifier', label: 'Attachment ID', path: ['TransitGatewayAttachmentId'], priority: 'primary' },
        { key: 'resourceId', kind: 'identifier', label: 'Resource ID', path: ['ResourceId'], priority: 'secondary' },
        { key: 'resourceType', kind: 'text', label: 'Resource type', path: ['ResourceType'], priority: 'secondary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'transitGatewayId', kind: 'identifier', label: 'Transit gateway ID', path: ['TransitGatewayId'], priority: 'secondary' },
        { key: 'creationTime', kind: 'timestamp', label: 'Created', path: ['CreationTime'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['TransitGatewayAttachments'],
        keys: [{ path: ['TransitGatewayAttachmentId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGatewayAttachments' }, { param: 'TransitGatewayAttachmentId', path: ['TransitGatewayAttachmentId'] }],
      },
      {
        at: ['TransitGatewayAttachments'],
        keys: [{ const: 'transit gateway' }, { path: ['TransitGatewayAttachmentId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'transitGatewayAttachments', '$TransitGatewayAttachmentId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['TransitGatewayAttachments'],
    response:: call(
      self.ctx,
      'DescribeTransitGatewayAttachments',
      {
        TransitGatewayAttachmentIds: [$.TransitGatewayAttachmentId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'transit gateway' }, { path: ['TransitGatewayAttachmentId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'transitGatewayAttachments', '$TransitGatewayAttachmentId', 'propagations'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'GetTransitGatewayAttachmentPropagations',
      self.page {
        TransitGatewayAttachmentId: $.TransitGatewayAttachmentId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['TransitGatewayAttachmentPropagations'],
      columns: [
        { key: 'transitGatewayRouteTableId', kind: 'identifier', label: 'Route table ID', path: ['TransitGatewayRouteTableId'], priority: 'primary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
      ],
    },
  }],
  [['aws', '$account', '$region', 'ec2', 'transitGatewayAttachments', '$TransitGatewayAttachmentId', 'natConfiguration'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetTransitGatewayAttachmentNatConfiguration',
      {
        TransitGatewayAttachmentId: $.TransitGatewayAttachmentId,
      }
    ),
    data: self.response,
  }],
  [['aws', '$account', '$region', 'ec2', 'transitGateways'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeTransitGateways',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['TransitGateways'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'transitGatewayId', kind: 'identifier', label: 'Transit Gateway ID', path: ['TransitGatewayId'], priority: 'primary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'creationTime', kind: 'timestamp', label: 'Created', path: ['CreationTime'], priority: 'secondary' },
        { key: 'amazonSideAsn', kind: 'number', label: 'Amazon-side ASN', path: ['Options', 'AmazonSideAsn'], priority: 'tertiary' },
        { key: 'dnsSupport', kind: 'boolean', label: 'DNS support', path: ['Options', 'DnsSupport'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['TransitGateways'],
        keys: [{ path: ['TransitGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'transitGateways', '$TransitGatewayId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['TransitGateways'],
    response:: call(
      self.ctx,
      'DescribeTransitGateways',
      {
        TransitGatewayIds: [$.TransitGatewayId],
      }
    ),
  }],
  [['aws', '$account', '$region', 'ec2', 'volumes'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeVolumes',
      self.page {
        IncludeManagedResources: std.get($._params, 'IncludeManagedResources', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['Volumes'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'volumeId', kind: 'identifier', label: 'Volume ID', path: ['VolumeId'], priority: 'primary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'size', kind: 'count', label: 'Size (GiB)', path: ['Size'], priority: 'secondary' },
        { key: 'volumeType', kind: 'text', label: 'Type', path: ['VolumeType'], priority: 'secondary' },
        { key: 'availabilityZone', kind: 'text', label: 'Availability Zone', path: ['AvailabilityZone'], priority: 'secondary' },
        { key: 'createTime', kind: 'timestamp', label: 'Created', path: ['CreateTime'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['Volumes'],
        keys: [{ path: ['VolumeId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'volumes' }, { param: 'VolumeId', path: ['VolumeId'] }],
      },
      {
        at: ['Volumes', 'Attachments'],
        keys: [{ const: 'attached instance' }, { path: ['VolumeId'] }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'IncludeManagedResources', type: 'boolean' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'volumes', '$VolumeId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['Volumes'],
    response:: call(
      self.ctx,
      'DescribeVolumes',
      {
        VolumeIds: [$.VolumeId],
      }
    ),
    linkSpecs:: [
      {
        at: ['Attachments'],
        keys: [{ const: 'attached instance' }, { path: ['VolumeId'] }, { path: ['InstanceId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'instances' }, { param: 'InstanceId', path: ['InstanceId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcEndpoints'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeVpcEndpoints',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['VpcEndpoints'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'vpcEndpointId', kind: 'identifier', label: 'Endpoint ID', path: ['VpcEndpointId'], priority: 'primary' },
        { key: 'serviceName', kind: 'name', label: 'Service', path: ['ServiceName'], priority: 'secondary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'secondary' },
        { key: 'endpointType', kind: 'text', label: 'Type', path: ['VpcEndpointType'], priority: 'secondary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['CreationTimestamp'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['VpcEndpoints'],
        keys: [{ path: ['VpcEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcEndpoints' }, { param: 'VpcEndpointId', path: ['VpcEndpointId'] }],
      },
      {
        at: ['VpcEndpoints'],
        keys: [{ const: 'vpc' }, { path: ['VpcEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['VpcEndpoints', 'Groups'],
        keys: [{ const: 'security groups' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['VpcEndpoints', 'Ipv4Prefixes'],
        keys: [{ const: 'subnets' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['VpcEndpoints', 'Ipv6Prefixes'],
        keys: [{ const: 'subnets' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['VpcEndpoints', 'NetworkInterfaceIds'],
        keys: [{ const: 'network interfaces' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: [] }],
      },
      {
        at: ['VpcEndpoints', 'RouteTableIds'],
        keys: [{ const: 'route tables' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'routeTables' }, { param: 'RouteTableId', path: [] }],
      },
      {
        at: ['VpcEndpoints', 'SubnetIds'],
        keys: [{ const: 'subnets' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: [] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcEndpoints', '$VpcEndpointId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['VpcEndpoints'],
    response:: call(
      self.ctx,
      'DescribeVpcEndpoints',
      {
        VpcEndpointIds: [$.VpcEndpointId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'vpc' }, { path: ['VpcEndpointId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['Groups'],
        keys: [{ const: 'security groups' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['Ipv4Prefixes'],
        keys: [{ const: 'subnets' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['Ipv6Prefixes'],
        keys: [{ const: 'subnets' }, { path: ['SubnetId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: ['SubnetId'] }],
      },
      {
        at: ['NetworkInterfaceIds'],
        keys: [{ const: 'network interfaces' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'networkInterfaces' }, { param: 'NetworkInterfaceId', path: [] }],
      },
      {
        at: ['RouteTableIds'],
        keys: [{ const: 'route tables' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'routeTables' }, { param: 'RouteTableId', path: [] }],
      },
      {
        at: ['SubnetIds'],
        keys: [{ const: 'subnets' }, { path: [] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'subnets' }, { param: 'SubnetId', path: [] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcPeeringConnections'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeVpcPeeringConnections',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['VpcPeeringConnections'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'connectionId', kind: 'identifier', label: 'Peering connection', path: ['VpcPeeringConnectionId'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['Status', 'Code'], priority: 'secondary' },
        { key: 'requesterVpc', kind: 'identifier', label: 'Requester VPC', path: ['RequesterVpcInfo', 'VpcId'], priority: 'secondary' },
        { key: 'accepterVpc', kind: 'identifier', label: 'Accepter VPC', path: ['AccepterVpcInfo', 'VpcId'], priority: 'secondary' },
        { key: 'expirationTime', kind: 'timestamp', label: 'Expires', path: ['ExpirationTime'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['VpcPeeringConnections'],
        keys: [{ path: ['VpcPeeringConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
      {
        at: ['VpcPeeringConnections'],
        keys: [{ const: 'requester vpc' }, { path: ['VpcPeeringConnectionId'] }, { path: ['RequesterVpcInfo', 'VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['RequesterVpcInfo', 'VpcId'] }],
      },
      {
        at: ['VpcPeeringConnections'],
        keys: [{ const: 'accepter vpc' }, { path: ['VpcPeeringConnectionId'] }, { path: ['AccepterVpcInfo', 'VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['AccepterVpcInfo', 'VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcPeeringConnections', '$VpcPeeringConnectionId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['VpcPeeringConnections'],
    response:: call(
      self.ctx,
      'DescribeVpcPeeringConnections',
      {
        VpcPeeringConnectionIds: [$.VpcPeeringConnectionId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'requester vpc' }, { path: ['VpcPeeringConnectionId'] }, { path: ['RequesterVpcInfo', 'VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['RequesterVpcInfo', 'VpcId'] }],
      },
      {
        at: [],
        keys: [{ const: 'accepter vpc' }, { path: ['VpcPeeringConnectionId'] }, { path: ['AccepterVpcInfo', 'VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['AccepterVpcInfo', 'VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcs'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeVpcs',
      self.page
    ),
    data:: self.response,
    table:: {
      at: ['Vpcs'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'primary' },
        { key: 'cidrBlock', kind: 'text', label: 'IPv4 CIDR', path: ['CidrBlock'], priority: 'secondary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'isDefault', kind: 'boolean', label: 'Default', path: ['IsDefault'], priority: 'secondary' },
        { key: 'instanceTenancy', kind: 'text', label: 'Tenancy', path: ['InstanceTenancy'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['Vpcs'],
        keys: [{ path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
      {
        at: ['Vpcs'],
        keys: [{ const: 'dhcp options' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'dhcpOptions' }, { param: 'DhcpOptionsId', path: ['DhcpOptionsId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcs', '$VpcId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['Vpcs'],
    response:: call(
      self.ctx,
      'DescribeVpcs',
      {
        VpcIds: [$.VpcId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'dhcp options' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'dhcpOptions' }, { param: 'DhcpOptionsId', path: ['DhcpOptionsId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcs', '$VpcId', 'securityGroupsForVpc'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'GetSecurityGroupsForVpc',
      self.page {
        VpcId: $.VpcId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['SecurityGroupForVpcs'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'group_name', kind: 'name', label: 'Group name', path: ['GroupName'], priority: 'primary' },
        { key: 'group_id', kind: 'identifier', label: 'Group ID', path: ['GroupId'], priority: 'secondary' },
        { key: 'vpc_id', kind: 'identifier', label: 'VPC ID', path: ['PrimaryVpcId'], priority: 'secondary' },
        { key: 'owner_id', kind: 'identifier', label: 'Owner ID', path: ['OwnerId'], priority: 'tertiary' },
      ],
    },
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcs', '$VpcId', 'staleSecurityGroups'], a.table.node + aws.regional + aws.paginated + {
    inputToken:: 'NextToken',
    outputToken:: 'NextToken',
    pageSize:: 'MaxResults',
    response:: call(
      self.ctx,
      'DescribeStaleSecurityGroups',
      self.page {
        VpcId: $.VpcId,
      }
    ),
    data:: self.response,
    table:: {
      at: ['StaleSecurityGroupSet'],
      columns: [
        { key: 'groupName', kind: 'name', label: 'Group name', path: ['GroupName'], priority: 'primary' },
        { key: 'groupId', kind: 'identifier', label: 'Group ID', path: ['GroupId'], priority: 'secondary' },
        { key: 'vpcId', kind: 'identifier', label: 'VPC ID', path: ['VpcId'], priority: 'secondary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['StaleSecurityGroupSet', 'StaleIpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'security group' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['StaleSecurityGroupSet', 'StaleIpPermissions', 'UserIdGroupPairs'],
        keys: [{ const: 'VPC peering connection' }, { path: ['VpcPeeringConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
      {
        at: ['StaleSecurityGroupSet', 'StaleIpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'security group' }, { path: ['GroupId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'securityGroups' }, { param: 'GroupId', path: ['GroupId'] }],
      },
      {
        at: ['StaleSecurityGroupSet', 'StaleIpPermissionsEgress', 'UserIdGroupPairs'],
        keys: [{ const: 'VPC peering connection' }, { path: ['VpcPeeringConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcPeeringConnections' }, { param: 'VpcPeeringConnectionId', path: ['VpcPeeringConnectionId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpcs', '$VpcId', 'resourcesBlockingEncryptionEnforcement'], a.resource.node + aws.regional + {
    response:: call(
      self.ctx,
      'GetVpcResourcesBlockingEncryptionEnforcement',
      {
        VpcId: $.VpcId,
        MaxResults: std.get($._params, 'MaxResults', null),
        NextToken: std.get($._params, 'NextToken', null),
      }
    ),
    data: self.response,
    _paramSpecs+: [
      { default: null, name: 'MaxResults', type: 'number' },
      { default: null, name: 'NextToken', type: 'string' },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpnConnections'], a.table.node + aws.regional + {
    response:: call(
      self.ctx,
      'DescribeVpnConnections',
      {}
    ),
    data:: self.response,
    table:: {
      at: ['VpnConnections'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'vpnConnectionId', kind: 'identifier', label: 'VPN connection ID', path: ['VpnConnectionId'], priority: 'primary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'customerGatewayId', kind: 'identifier', label: 'Customer gateway ID', path: ['CustomerGatewayId'], priority: 'secondary' },
        { key: 'vpnGatewayId', kind: 'identifier', label: 'VPN gateway ID', path: ['VpnGatewayId'], priority: 'secondary' },
        { key: 'transitGatewayId', kind: 'identifier', label: 'Transit gateway ID', path: ['TransitGatewayId'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['VpnConnections'],
        keys: [{ path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpnConnections' }, { param: 'VpnConnectionId', path: ['VpnConnectionId'] }],
      },
      {
        at: ['VpnConnections'],
        keys: [{ const: 'customer gateway' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'customerGateways' }, { param: 'CustomerGatewayId', path: ['CustomerGatewayId'] }],
      },
      {
        at: ['VpnConnections'],
        keys: [{ const: 'transit gateway' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
      {
        at: ['VpnConnections'],
        keys: [{ const: 'VPN gateway' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpnGateways' }, { param: 'VpnGatewayId', path: ['VpnGatewayId'] }],
      },
      {
        at: ['VpnConnections'],
        keys: [{ const: 'transit gateway attachment' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGatewayAttachments' }, { param: 'TransitGatewayAttachmentId', path: ['Options', 'TransportTransitGatewayAttachmentId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpnConnections', '$VpnConnectionId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['VpnConnections'],
    response:: call(
      self.ctx,
      'DescribeVpnConnections',
      {
        VpnConnectionIds: [$.VpnConnectionId],
      }
    ),
    linkSpecs:: [
      {
        at: [],
        keys: [{ const: 'customer gateway' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'customerGateways' }, { param: 'CustomerGatewayId', path: ['CustomerGatewayId'] }],
      },
      {
        at: [],
        keys: [{ const: 'transit gateway' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGateways' }, { param: 'TransitGatewayId', path: ['TransitGatewayId'] }],
      },
      {
        at: [],
        keys: [{ const: 'VPN gateway' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpnGateways' }, { param: 'VpnGatewayId', path: ['VpnGatewayId'] }],
      },
      {
        at: [],
        keys: [{ const: 'transit gateway attachment' }, { path: ['VpnConnectionId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'transitGatewayAttachments' }, { param: 'TransitGatewayAttachmentId', path: ['Options', 'TransportTransitGatewayAttachmentId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpnGateways'], a.table.node + aws.regional + {
    response:: call(
      self.ctx,
      'DescribeVpnGateways',
      {}
    ),
    data:: self.response,
    table:: {
      at: ['VpnGateways'],
      columns: [
        { label: 'Name', value:: aws.tag('Name') },
        { key: 'vpnGatewayId', kind: 'identifier', label: 'VPN Gateway ID', path: ['VpnGatewayId'], priority: 'primary' },
        { key: 'state', kind: 'status', label: 'State', path: ['State'], priority: 'secondary' },
        { key: 'amazonSideAsn', kind: 'number', label: 'Amazon-side ASN', path: ['AmazonSideAsn'], priority: 'secondary' },
        { key: 'availabilityZone', kind: 'text', label: 'Availability zone', path: ['AvailabilityZone'], priority: 'tertiary' },
        { key: 'type', kind: 'text', label: 'Type', path: ['Type'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['VpnGateways'],
        keys: [{ path: ['VpnGatewayId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpnGateways' }, { param: 'VpnGatewayId', path: ['VpnGatewayId'] }],
      },
      {
        at: ['VpnGateways', 'VpcAttachments'],
        keys: [{ const: 'vpc' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
  [['aws', '$account', '$region', 'ec2', 'vpnGateways', '$VpnGatewayId'], a.resource.node + aws.regional + aws.single + {
    itemsPath:: ['VpnGateways'],
    response:: call(
      self.ctx,
      'DescribeVpnGateways',
      {
        VpnGatewayIds: [$.VpnGatewayId],
      }
    ),
    linkSpecs:: [
      {
        at: ['VpcAttachments'],
        keys: [{ const: 'vpc' }, { path: ['VpcId'] }],
        value: [{ const: 'aws' }, { origin: 'account' }, { origin: 'region' }, { const: 'ec2' }, { const: 'vpcs' }, { param: 'VpcId', path: ['VpcId'] }],
      },
    ],
  }],
]
