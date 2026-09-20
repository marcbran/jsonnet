local c = {
  chart: {
    local c = self,
    option:: error 'Chart requires option',
    links:: {},
    width:: '100%',
    height:: '400px',
    darkTheme:: {
      color: ['#4c657e', '#856350', '#677d67', '#78607b', '#44756f', '#84734c', '#546a78', '#774b4b'],
      backgroundColor: 'transparent',
      textStyle: { color: '#ccc' },
      title: { textStyle: { color: '#ccc' }, subtextStyle: { color: '#999' } },
      legend: { textStyle: { color: '#ccc' } },
      tooltip: { backgroundColor: '#333', borderColor: '#555', textStyle: { color: '#ccc' } },
      grid: { borderColor: '#444' },
      categoryAxis: {
        axisLine: { lineStyle: { color: '#666' } },
        axisLabel: { color: '#ccc' },
        splitLine: { lineStyle: { color: ['#333'] } },
      },
      valueAxis: {
        axisLine: { lineStyle: { color: '#666' } },
        axisLabel: { color: '#ccc' },
        splitLine: { lineStyle: { color: ['#333'] } },
      },
      pie: {
        itemStyle: { borderColor: 'transparent' },
        label: { color: '#ccc', textBorderColor: 'transparent', textBorderWidth: 0 },
        labelLine: { lineStyle: { color: '#666' } },
      },
    },
    local payload = {
      option: { animation: false, backgroundColor: 'transparent' } + c.option,
      theme: c.darkTheme,
      links: c.links,
    },
    local configJson = std.strReplace(std.manifestJsonMinified(payload), '<', '\\u003c'),
    html: [
      {
        element: 'echarts-chart',
        attributes: { style: 'display: block; box-sizing: border-box; width: %s; height: %s;' % [c.width, c.height] },
        children: [
          {
            element: 'script',
            attributes: { type: 'application/json', class: 'echarts-config' },
            children: [{ html: configJson }],
          },
        ],
      },
    ],
  },
  dashboard:
    local chart = {
      local c = self,
      option:: error 'Chart requires option',
      links:: {},
      width:: '100%',
      height:: '400px',
      darkTheme:: {
        color: ['#4c657e', '#856350', '#677d67', '#78607b', '#44756f', '#84734c', '#546a78', '#774b4b'],
        backgroundColor: 'transparent',
        textStyle: { color: '#ccc' },
        title: { textStyle: { color: '#ccc' }, subtextStyle: { color: '#999' } },
        legend: { textStyle: { color: '#ccc' } },
        tooltip: { backgroundColor: '#333', borderColor: '#555', textStyle: { color: '#ccc' } },
        grid: { borderColor: '#444' },
        categoryAxis: {
          axisLine: { lineStyle: { color: '#666' } },
          axisLabel: { color: '#ccc' },
          splitLine: { lineStyle: { color: ['#333'] } },
        },
        valueAxis: {
          axisLine: { lineStyle: { color: '#666' } },
          axisLabel: { color: '#ccc' },
          splitLine: { lineStyle: { color: ['#333'] } },
        },
        pie: {
          itemStyle: { borderColor: 'transparent' },
          label: { color: '#ccc', textBorderColor: 'transparent', textBorderWidth: 0 },
          labelLine: { lineStyle: { color: '#666' } },
        },
      },
      local payload = {
        option: { animation: false, backgroundColor: 'transparent' } + c.option,
        theme: c.darkTheme,
        links: c.links,
      },
      local configJson = std.strReplace(std.manifestJsonMinified(payload), '<', '\\u003c'),
      html: [
        {
          element: 'echarts-chart',
          attributes: { style: 'display: block; box-sizing: border-box; width: %s; height: %s;' % [c.width, c.height] },
          children: [
            {
              element: 'script',
              attributes: { type: 'application/json', class: 'echarts-config' },
              children: [{ html: configJson }],
            },
          ],
        },
      ],
    };

    local style = |||
      @scope (.dashboard) {
        :scope {
          display: flex;
          width: 100%;
          box-sizing: border-box;
          gap: 1em;
        }
        .dashboard-branch {
          display: flex;
          box-sizing: border-box;
          min-width: 0;
          min-height: 0;
          gap: 1em;
        }
        .dashboard-panel {
          display: flex;
          box-sizing: border-box;
          min-width: 0;
          min-height: 0;
        }
      }
    |||;

    local direction(node) = if node.type == 'row' then 'row' else 'column';

    local layoutNode = {
      local c = self,
      node:: error 'LayoutNode requires node',
      html::
        if c.node.type == 'panel' then
          {
            element: 'div',
            attributes: { class: 'dashboard-panel', style: 'flex: %s 1 0%%;' % [c.node.flex] },
            children: [
              chart {
                option:: c.node.chart.option,
                links:: c.node.chart.links,
                width:: '100%',
                height:: '100%',
              },
            ],
          }
        else
          {
            element: 'div',
            attributes: {
              class: 'dashboard-branch',
              style: 'flex: %s 1 0%%; flex-direction: %s;' % [c.node.flex, direction(c.node)],
            },
            children: [
              (layoutNode { node:: c.node.children[i] }).html
              for i in std.range(0, std.length(c.node.children) - 1)
            ],
          },
    };

    {
      local c = self,
      layout:: error 'Dashboard requires layout',
      height:: '600px',
      html: [
        { element: 'style', children: [style] },
        {
          element: 'div',
          attributes: {
            class: 'dashboard',
            style: 'flex-direction: %s; height: %s;' % [direction(c.layout), c.height],
          },
          children: [
            (layoutNode { node:: c.layout.children[i] }).html
            for i in std.range(0, std.length(c.layout.children) - 1)
          ],
        },
      ],
    },
  panel:
    local style = |||
      @scope (.panel) {
        :scope {
          display: block;
          width: 100%;
          box-sizing: border-box;
          padding: 0.25em;
        }
      }
    |||;

    {
      local c = self,
      child:: error 'Panel requires a child',
      html: [
        { element: 'style', children: [style] },
        {
          element: 'div',
          attributes: { class: 'card panel' },
          children: [c.child],
        },
      ],
    },
};
local ui = {
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

    {
      local c = self,
      items:: error 'List requires items',
      groups:: [],
      style:: '',
      html: [
        { element: 'style', children: [style] },
        {
          element: 'aside',
          attributes: { class: 'list' } + (if c.style != '' then { style: c.style } else {}),
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
      rowLink:: null,
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
                      local href = rowHref(c.rowLink, item);
                      {
                        element: 'tr',
                        children: [
                          { element: 'td', children: [cell { item:: item, col:: c.columns[i], href:: href, first:: i == 0 }] }
                          for i in std.range(0, std.length(c.columns) - 1)
                        ],
                      }
                      for item in rows
                    ],
                },
              ],
            },
          ] + (if nav.visible then [nav.html] else []),
        },
        { element: 'script', children: [{ html: sortScript }] },
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

      {
        local c = self,
        items:: error 'List requires items',
        groups:: [],
        style:: '',
        html: [
          { element: 'style', children: [style] },
          {
            element: 'aside',
            attributes: { class: 'list' } + (if c.style != '' then { style: c.style } else {}),
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
      };

    local style = |||
      .resource {
        display: flex;
        flex-wrap: wrap;
        align-items: flex-start;
        gap: 0.25em;
      }
      .resource > .yaml {
        flex: 1 1 0;
        min-width: 0;
      }
    |||;

    {
      local c = self,
      data:: error 'Resource requires data',
      items:: [],
      groups:: [],
      html: [
        { element: 'style', children: [style] },
        {
          element: 'div',
          attributes: { class: 'resource' },
          children:
            (if std.length(c.items) > 0 || std.length(c.groups) > 0 then
               [list { items:: c.items, groups:: c.groups, style:: ' min-width: 8em;' }]
             else []) + [yaml { data:: c.data }],
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
};
local html = {
  manifestHtml(tree): std.native('invoke:html')('manifestHtml', [tree]),
};
local charts =
  local line =
    local common =
      local round(v, decimals) =
        if v == null || decimals == null then v
        else
          local factor = std.pow(10, decimals);
          std.round(v * factor) / factor;

      local siPrefixes = [
        { factor: 1e12, suffix: 'TB' },
        { factor: 1e9, suffix: 'GB' },
        { factor: 1e6, suffix: 'MB' },
        { factor: 1e3, suffix: 'KB' },
        { factor: 1, suffix: 'B' },
      ];

      local maxAbsValue(series) =
        std.foldl(
          function(acc, s) std.foldl(
            function(acc2, point) if point[1] == null then acc2 else std.max(acc2, std.abs(point[1])),
            s.data,
            acc
          ),
          series,
          0
        );

      local siScale(maxAbs) =
        local matches = [p for p in siPrefixes if maxAbs >= p.factor];
        if std.length(matches) > 0 then matches[0] else siPrefixes[std.length(siPrefixes) - 1];

      local scaleSeries(series, factor, decimals) = [
        s { data: [[point[0], round(if point[1] == null then null else point[1] / factor, decimals)] for point in s.data] }
        for s in series
      ];

      {
        timeAxis: {
          type: 'time',
          axisLabel: {
            formatter: {
              year: '{yyyy}',
              month: '{MMM}',
              day: '{MMM} {d}',
              hour: '{HH}:{mm}',
              minute: '{HH}:{mm}',
              second: '{HH}:{mm}:{ss}',
              none: '{yyyy}-{MM}-{dd}',
            },
          },
        },
        round: round,
        maxAbsValue: maxAbsValue,
        siScale: siScale,
        scaleSeries: scaleSeries,
      };

    {
      local c = self,
      title:: null,
      series:: [],
      unit:: null,
      decimals:: 2,
      option::
        local styled = [
          s { type: 'line', showSymbol: true, symbolSize: 16, itemStyle: { opacity: 0 } }
          for s in c.series
        ];
        local scale = if c.unit == 'bytes' then common.siScale(common.maxAbsValue(styled)) else { factor: 1, suffix: null };
        local allSeries = common.scaleSeries(styled, scale.factor, c.decimals);
        {
          title: { text: c.title },
          tooltip: {
            trigger: 'axis',
            axisPointer: { type: 'cross', z: 100, lineStyle: { color: '#888', type: 'dashed' } },
          },
          legend: {
            data: [{ name: s.name, itemStyle: { opacity: 1 } } for s in allSeries],
            type: 'scroll',
            bottom: 0,
            icon: 'roundRect',
          },
          grid: { top: 40, bottom: 40, containLabel: true },
          xAxis: common.timeAxis,
          yAxis: { type: 'value' } + (
            if scale.suffix != null then { axisLabel: { formatter: '{value} ' + scale.suffix } } else {}
          ),
          series: allSeries,
        },
    };
  local stateTimeline =
    local common =
      local round(v, decimals) =
        if v == null || decimals == null then v
        else
          local factor = std.pow(10, decimals);
          std.round(v * factor) / factor;

      local siPrefixes = [
        { factor: 1e12, suffix: 'TB' },
        { factor: 1e9, suffix: 'GB' },
        { factor: 1e6, suffix: 'MB' },
        { factor: 1e3, suffix: 'KB' },
        { factor: 1, suffix: 'B' },
      ];

      local maxAbsValue(series) =
        std.foldl(
          function(acc, s) std.foldl(
            function(acc2, point) if point[1] == null then acc2 else std.max(acc2, std.abs(point[1])),
            s.data,
            acc
          ),
          series,
          0
        );

      local siScale(maxAbs) =
        local matches = [p for p in siPrefixes if maxAbs >= p.factor];
        if std.length(matches) > 0 then matches[0] else siPrefixes[std.length(siPrefixes) - 1];

      local scaleSeries(series, factor, decimals) = [
        s { data: [[point[0], round(if point[1] == null then null else point[1] / factor, decimals)] for point in s.data] }
        for s in series
      ];

      {
        timeAxis: {
          type: 'time',
          axisLabel: {
            formatter: {
              year: '{yyyy}',
              month: '{MMM}',
              day: '{MMM} {d}',
              hour: '{HH}:{mm}',
              minute: '{HH}:{mm}',
              second: '{HH}:{mm}:{ss}',
              none: '{yyyy}-{MM}-{dd}',
            },
          },
        },
        round: round,
        maxAbsValue: maxAbsValue,
        siScale: siScale,
        scaleSeries: scaleSeries,
      };

    {
      local c = self,
      title:: null,
      rows:: [],
      segments:: [],
      option::
        local rowIndex = { [c.rows[i]]: i for i in std.range(0, std.length(c.rows) - 1) };
        {
          title: { text: c.title },
          tooltip: { trigger: 'item', formatter: '{b}' },
          grid: { top: 40, bottom: 40, containLabel: true },
          xAxis: common.timeAxis,
          yAxis: { type: 'category', data: c.rows },
          series: [{
            type: 'custom',
            renderItem: 'stateTimeline',
            encode: { x: [1, 2], y: 0 },
            data: [
              { value: [rowIndex[s.row], s.start, s.end, std.get(s, 'label', null)] }
              + (if std.get(s, 'color', null) != null then { itemStyle: { color: s.color } } else {})
              + (if std.get(s, 'link', null) != null then { link: s.link } else {})
              + (local nm = if std.get(s, 'tooltip', null) != null then s.tooltip else std.get(s, 'label', null); if nm != null then { name: nm } else {})
              for s in c.segments
            ],
          }],
        },
    };

  {
    line: { chart: line },
    stateTimeline: { chart: stateTimeline },
  };

local chartJs = |||
  function stateTimelineRenderItem(params, api) {
    var row = api.value(0);
    var start = api.coord([api.value(1), row]);
    var end = api.coord([api.value(2), row]);
    var height = api.size([0, 1])[1] * 0.6;
    var x = start[0];
    var y = start[1] - height / 2;
    var width = Math.max(end[0] - start[0], 1);
    var label = api.value(3);
    var children = [{
      type: 'rect',
      shape: { x: x, y: y, width: width, height: height },
      style: api.style(),
    }];
    if (label != null && label !== '' && width > String(label).length * 7 + 6) {
      children.push({
        type: 'text',
        style: {
          text: String(label),
          x: x + width / 2,
          y: start[1],
          textAlign: 'center',
          textVerticalAlign: 'middle',
          fill: '#fff',
          fontSize: 11,
        },
      });
    }
    return { type: 'group', children: children };
  }

  var RENDERERS = { stateTimeline: stateTimelineRenderItem };

  class EchartsChart extends HTMLElement {
    connectedCallback() {
      var self = this;
      if (document.readyState === 'complete') self.init();
      else window.addEventListener('load', function () { self.init(); }, { once: true });
    }

    disconnectedCallback() {
      if (this._resize) window.removeEventListener('resize', this._resize);
      if (this._chart) this._chart.dispose();
    }

    init() {
      var configEl = this.querySelector(':scope > script.echarts-config');
      if (!configEl) return;
      var config = JSON.parse(configEl.textContent);
      var option = config.option;
      var links = config.links || {};

      var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      var chart = echarts.init(this, dark ? config.theme : null);
      this._chart = chart;

      option.tooltip = Object.assign({}, option.tooltip, { trigger: 'item' });

      option.brush = {
        xAxisIndex: 'all',
        brushStyle: {
          color: 'rgba(255, 255, 255, 0.08)',
          borderWidth: 0,
        },
      };
      option.toolbox = { show: false };

      (option.series || []).forEach(function (s) {
        if (typeof s.renderItem === 'string' && RENDERERS[s.renderItem]) {
          s.renderItem = RENDERERS[s.renderItem];
        }
      });

      chart.setOption(option);
      this._resize = function () { chart.resize(); };
      window.addEventListener('resize', this._resize);

      chart.dispatchAction({
        type: 'takeGlobalCursor',
        key: 'brush',
        brushOption: { brushType: 'lineX', brushMode: 'single' },
      });
      var pendingRange = null;
      chart.on('brushSelected', function (params) {
        var batch = params.batch && params.batch[0];
        var area = batch && batch.areas && batch.areas[0];
        pendingRange = area && area.coordRange;
      });
      chart.getZr().on('mouseup', function () {
        if (!pendingRange) return;
        var range = pendingRange;
        pendingRange = null;
        var from = new Date(Math.min(range[0], range[1])).toISOString();
        var to = new Date(Math.max(range[0], range[1])).toISOString();
        var url = new URL(window.location.href);
        url.searchParams.set('from', from);
        url.searchParams.set('to', to);
        window.location.href = url.toString();
      });

      var shiftKey = false;
      var cmdKey = false;
      var prevSelected = {};
      var suppress = false;

      var currentSelected = {};
      ((option.legend && option.legend.data) || []).forEach(function (entry) {
        currentSelected[typeof entry === 'string' ? entry : entry.name] = true;
      });
      chart.getZr().on('mousedown', function (e) {
        var ev = e.event;
        shiftKey = !!(ev && ev.shiftKey);
        cmdKey = !!(ev && (ev.ctrlKey || ev.metaKey));
        prevSelected = Object.assign({}, currentSelected);
      });
      chart.on('legendselectchanged', function (params) {
        Object.assign(currentSelected, params.selected);
        if (suppress) return;

        function revertToggle() {
          var toRestore = Object.assign({}, prevSelected);
          suppress = true;
          chart.setOption({ legend: { selected: toRestore } });
          currentSelected = Object.assign({}, toRestore);
          suppress = false;
        }

        if (shiftKey) {
          if (links[params.name]) {
            revertToggle();
            if (cmdKey) window.open(links[params.name], '_blank');
            else window.location.href = links[params.name];
          } else {
            revertToggle();
          }
          return;
        }

        if (cmdKey) {
          var names = Object.keys(prevSelected);
          var wasOnlyThisSelected = names.every(function (name) {
            return name === params.name ? prevSelected[name] : !prevSelected[name];
          });
          var toApply = {};
          if (wasOnlyThisSelected) {
            names.forEach(function (name) { toApply[name] = true; });
          } else {
            names.forEach(function (name) { toApply[name] = name === params.name; });
          }
          suppress = true;
          chart.setOption({ legend: { selected: toApply } });
          currentSelected = Object.assign({}, toApply);
          suppress = false;
          return;
        }
      });

      chart.on('click', function (params) {
        if (params.componentType !== 'series' || !shiftKey) return;
        var link = (params.data && params.data.link) || links[params.seriesName];
        if (!link) return;
        if (cmdKey) window.open(link, '_blank');
        else window.location.href = link;
      });
    }
  }

  if (!customElements.get('echarts-chart')) {
    customElements.define('echarts-chart', EchartsChart);
  }
|||;

local echartsSrc = 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js';
local echartsScript = { element: 'script', attributes: { src: echartsSrc } };
local componentScript = { element: 'script', children: [{ html: chartJs }] };

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: ui.page { fragment:: [echartsScript, componentScript, n._view.fragment] },
    html: html.manifestHtml(self.page),
  },
};

local linkPaths(links) = {
  [k]: links[k]._queryPath
  for k in std.objectFields(links)
  if std.isObject(links[k]) && std.objectHasAll(links[k], '_queryPath')
};

local chartView = baseView {
  _view+:: {
    fragment:
      c.panel {
        child:: c.chart {
          option:: $.option,
          links:: linkPaths(std.get($, 'links', {})),
          width:: std.get($, 'width', '100%'),
          height:: std.get($, 'height', '400px'),
        },
      },
  },
};

local dashboardView = baseView {
  _view+:: {
    fragment:
      c.panel {
        child:: c.dashboard {
          layout:: $.tree,
          height:: std.get($, 'height', '600px'),
        },
      },
  },
};

{
  default: { view: chartView },
  chart: { view: chartView },
  dashboard: { view: dashboardView },
  row(flex, children):: { type: 'row', flex: flex, children: children },
  column(flex, children):: { type: 'column', flex: flex, children: children },
  panel(flex, chart):: { type: 'panel', flex: flex, chart: chart },
} + charts
