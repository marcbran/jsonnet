local c = {
  chart:
    local style = |||
      @scope (.chart) {
        :scope {
          width: 100%;
          box-sizing: border-box;
        }
      }
    |||;

    {
      local c = self,
      option:: error 'Chart requires option',
      links:: {},
      id:: 'chart',
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
      html: [
        { element: 'style', children: [style] },
        {
          element: 'div',
          attributes: { class: 'chart' },
          children: [
            {
              element: 'div',
              attributes: { id: c.id, style: 'width: %s; height: %s;' % [c.width, c.height] },
            },
            {
              element: 'script',
              children: [
                {
                  html: |||
                    (function () {
                      function init() {
                        var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                        var chart = echarts.init(document.getElementById('%s'), dark ? %s : null);
                        var option = %s;
                        option.tooltip = Object.assign({}, option.tooltip, { trigger: 'item' });

                        option.brush = {
                          xAxisIndex: 'all',
                          brushStyle: {
                            color: 'rgba(255, 255, 255, 0.08)',
                            borderWidth: 0,
                          },
                        };
                        option.toolbox = { show: false };

                        chart.setOption(option);
                        window.addEventListener('resize', function () { chart.resize(); });

                        chart.dispatchAction({
                          type: 'takeGlobalCursor',
                          key: 'brush',
                          brushOption: { brushType: 'lineX', brushMode: 'single' },
                        });
                        // Drag-select a horizontal range to navigate to it as an
                        // absolute time range, mirroring Grafana's chart-drag zoom.
                        // brushSelected fires continuously while dragging, so it
                        // only tracks the pending range - navigation happens once,
                        // on mouseup, so it doesn't fire mid-drag.
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

                        var links = %s;
                        // Click: toggle. Cmd/ctrl+click: toggle all (isolate this
                        // one / restore all). Shift+click: open link, same tab.
                        // Shift+cmd/ctrl+click: open link, new tab.
                        var shiftKey = false;
                        var cmdKey = false;
                        var prevSelected = {};
                        var suppress = false;
                        // Tracked ourselves instead of read from chart.getOption(),
                        // since ECharts only lazily populates legend[0].selected
                        // once the user has interacted with the legend at least once.
                        var currentSelected = {};
                        (option.legend.data || []).forEach(function (entry) {
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

                        // Shift/shift+cmd on a data point mirrors the legend's
                        // link-opening behavior (same tab / new tab); plain and
                        // cmd-only clicks on items are left alone.
                        chart.on('click', function (params) {
                          if (params.componentType !== 'series' || !shiftKey) return;
                          var link = links[params.seriesName];
                          if (!link) return;
                          if (cmdKey) window.open(link, '_blank');
                          else window.location.href = link;
                        });
                      }
                      if (document.readyState === 'complete') init();
                      else window.addEventListener('load', init);
                    })();
                  ||| % [
                    c.id,
                    std.manifestJsonMinified(c.darkTheme),
                    std.manifestJsonMinified({ animation: false, backgroundColor: 'transparent' } + c.option),
                    std.manifestJsonMinified(c.links),
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
  dashboard:
    local chart =
      local style = |||
        @scope (.chart) {
          :scope {
            width: 100%;
            box-sizing: border-box;
          }
        }
      |||;

      {
        local c = self,
        option:: error 'Chart requires option',
        links:: {},
        id:: 'chart',
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
        html: [
          { element: 'style', children: [style] },
          {
            element: 'div',
            attributes: { class: 'chart' },
            children: [
              {
                element: 'div',
                attributes: { id: c.id, style: 'width: %s; height: %s;' % [c.width, c.height] },
              },
              {
                element: 'script',
                children: [
                  {
                    html: |||
                      (function () {
                        function init() {
                          var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                          var chart = echarts.init(document.getElementById('%s'), dark ? %s : null);
                          var option = %s;
                          option.tooltip = Object.assign({}, option.tooltip, { trigger: 'item' });

                          option.brush = {
                            xAxisIndex: 'all',
                            brushStyle: {
                              color: 'rgba(255, 255, 255, 0.08)',
                              borderWidth: 0,
                            },
                          };
                          option.toolbox = { show: false };

                          chart.setOption(option);
                          window.addEventListener('resize', function () { chart.resize(); });

                          chart.dispatchAction({
                            type: 'takeGlobalCursor',
                            key: 'brush',
                            brushOption: { brushType: 'lineX', brushMode: 'single' },
                          });
                          // Drag-select a horizontal range to navigate to it as an
                          // absolute time range, mirroring Grafana's chart-drag zoom.
                          // brushSelected fires continuously while dragging, so it
                          // only tracks the pending range - navigation happens once,
                          // on mouseup, so it doesn't fire mid-drag.
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

                          var links = %s;
                          // Click: toggle. Cmd/ctrl+click: toggle all (isolate this
                          // one / restore all). Shift+click: open link, same tab.
                          // Shift+cmd/ctrl+click: open link, new tab.
                          var shiftKey = false;
                          var cmdKey = false;
                          var prevSelected = {};
                          var suppress = false;
                          // Tracked ourselves instead of read from chart.getOption(),
                          // since ECharts only lazily populates legend[0].selected
                          // once the user has interacted with the legend at least once.
                          var currentSelected = {};
                          (option.legend.data || []).forEach(function (entry) {
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

                          // Shift/shift+cmd on a data point mirrors the legend's
                          // link-opening behavior (same tab / new tab); plain and
                          // cmd-only clicks on items are left alone.
                          chart.on('click', function (params) {
                            if (params.componentType !== 'series' || !shiftKey) return;
                            var link = links[params.seriesName];
                            if (!link) return;
                            if (cmdKey) window.open(link, '_blank');
                            else window.location.href = link;
                          });
                        }
                        if (document.readyState === 'complete') init();
                        else window.addEventListener('load', init);
                      })();
                    ||| % [
                      c.id,
                      std.manifestJsonMinified(c.darkTheme),
                      std.manifestJsonMinified({ animation: false, backgroundColor: 'transparent' } + c.option),
                      std.manifestJsonMinified(c.links),
                    ],
                  },
                ],
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
      path:: [],
      html::
        if c.node.type == 'panel' then
          {
            element: 'div',
            attributes: { class: 'dashboard-panel', style: 'flex: %s 1 0%%;' % [c.node.flex] },
            children: [
              chart {
                option:: c.node.chart.option,
                links:: c.node.chart.links,
                id:: 'chart-' + std.join('-', [std.toString(p) for p in c.path]),
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
              (layoutNode { node:: c.node.children[i], path:: c.path + [i] }).html
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
            (layoutNode { node:: c.layout.children[i], path:: [i] }).html
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

    local sortScript = importstr 'table-sort.js';

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
      .deck:has(.card ~ .card),
      .deck:has(.list):has(.yaml) {
        display: inline-flex;
        gap: 0.25em;
        border: 1px solid var(--border-color);
        border-radius: 0.5em;
        padding: 0.25em;
      }
    |||;

    local hashScript = importstr 'hash.js';
    local navScript = importstr 'quick-nav.js';

    {
      local c = self,
      fragment:: error 'HtmlPage requires a fragment',
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
                { element: 'div', attributes: { class: 'deck' }, children: c.fragment },
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
};
local html = {
  manifestHtml(tree): std.native('invoke:html')('manifestHtml', [tree]),
};

local echartsSrc = 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js';
local echartsScript = { element: 'script', attributes: { src: echartsSrc } };

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: ui.page { fragment:: [echartsScript, n._view.fragment] },
    html: html.manifestHtml(self.page),
  },
};

local chartView = baseView {
  _view+:: {
    fragment:
      c.panel {
        child:: c.chart {
          option:: $.option,
          links:: std.get($, 'links', {}),
          id:: std.get($, 'chartId', 'chart'),
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
}
