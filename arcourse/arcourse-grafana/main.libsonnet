local a =
  local c = {
    chart: {
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
      html: {
        element: 'div',
        attributes: { style: 'width: 100%; height: 100%; box-sizing: border-box;' },
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
    },
    dashboard:
      local chart = {
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
        html: {
          element: 'div',
          attributes: { style: 'width: 100%; height: 100%; box-sizing: border-box;' },
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
      };

      local flexStyle(node) =
        'flex: %s 1 0%%; min-width: 0; min-height: 0; box-sizing: border-box;' % [node.flex];

      local direction(node) = if node.type == 'row' then 'row' else 'column';

      local render(node, path) =
        if node.type == 'panel' then
          {
            element: 'div',
            attributes: { style: flexStyle(node) + ' display: flex;' },
            children: [
              chart {
                option:: node.chart.option,
                links:: node.chart.links,
                id:: 'chart-' + std.join('-', [std.toString(p) for p in path]),
                width:: '100%',
                height:: '100%',
              },
            ],
          }
        else
          {
            element: 'div',
            attributes: { style: flexStyle(node) + ' display: flex; flex-direction: %s; gap: 1em;' % [direction(node)] },
            children: [
              render(node.children[i], path + [i])
              for i in std.range(0, std.length(node.children) - 1)
            ],
          };

      {
        local c = self,
        layout:: error 'Dashboard requires layout',
        height:: '600px',
        html: {
          element: 'div',
          attributes: {
            style: 'display: flex; flex-direction: %s; height: %s; width: 100%%; box-sizing: border-box; gap: 1em;' % [
              direction(c.layout),
              c.height,
            ],
          },
          children: [
            render(c.layout.children[i], [i])
            for i in std.range(0, std.length(c.layout.children) - 1)
          ],
        },
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

  local echartsSrc = 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js';
  local echartsScript = { element: 'script', attributes: { src: echartsSrc } };

  local baseView = {
    local n = self,
    _view:: {
      fragment: error 'view requires a fragment',
      page: c.page { fragment:: [echartsScript, n._view.fragment] },
      html: html.manifestHtml(self.page),
    },
  };

  local chartView = baseView {
    _view+:: {
      fragment:
        c.panel {
          style:: ' display: block; width: 100%; box-sizing: border-box; padding: 0.25em;',
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
          style:: ' display: block; width: 100%; box-sizing: border-box; padding: 0.25em;',
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
  };
local ui =
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
  };
local time = {
  now(): std.native('invoke:time')('now', []),
  addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
  parseRFC3339(value): std.native('invoke:time')('parseRFC3339', [value]),
};
local root = import 'root';

local request(input) = std.native('invoke:grafana')('request', [input]);

local refId(i) = std.char(std.codepoint('A') + i);

local queryDefaults = { instant: false, range: !self.instant };

local resolveTime(nowMs, value) =
  if value == 'now' then std.toString(nowMs)
  else if std.length(value) > 3 && std.substr(value, 0, 3) == 'now' then
    std.toString(time.addDuration(nowMs, std.substr(value, 3, std.length(value) - 3)))
  else
    std.toString(time.parseRFC3339(value));

local query(datasource, queries, from='now-1h', to='now') =
  local nowMs = time.now();
  local reqQueries = [
    queryDefaults + queries[i] { refId: refId(i) }
    for i in std.range(0, std.length(queries) - 1)
  ];
  request({
    method: 'POST',
    path: '/api/ds/query',
    readonly: true,
    context: { datasource: datasource },
    body: { queries: reqQueries, from: resolveTime(nowMs, from), to: resolveTime(nowMs, to) },
  });

local seriesName(frame) =
  std.get(frame.schema.fields[1].config, 'displayNameFromDS', frame.schema.refId);

local hasSeries(frame) = std.length(frame.schema.fields) > 1;

local round(v, decimals) =
  if v == null || decimals == null then v
  else
    local factor = std.pow(10, decimals);
    std.round(v * factor) / factor;

local seriesFromFrames(frames, type, decimals) = [
  {
    name: seriesName(frame),
    type: type,
    showSymbol: true,
    symbolSize: 16,
    itemStyle: { opacity: 0 },
    data: [
      [frame.data.values[0][j], round(frame.data.values[1][j], decimals)]
      for j in std.range(0, std.length(frame.data.values[0]) - 1)
    ],
  }
  for frame in frames
  if hasSeries(frame)
];

local linksFromFrames(frames, linkFn) =
  if linkFn == null then {}
  else {
    [seriesName(frame)]: linkFn(frame.schema.fields[1].labels)._queryPath
    for frame in frames
    if hasSeries(frame) && linkFn(frame.schema.fields[1].labels) != null
  };

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

local timeParams = [
  { name: 'from', type: 'string', default: 'now-1h' },
  { name: 'to', type: 'string', default: 'now' },
];

local timeRangeNavScript = importstr 'time-range-nav.js';

local timeRangeNav(from, to) = [
  { element: 'time-range-nav', attributes: { from: from, to: to } },
  { element: 'script', children: [{ html: timeRangeNavScript }] },
];

local chartNode = a.chart.view {
  type:: 'line',
  decimals:: 2,
  unit:: null,
  _params:: timeParams,
  data: query($.datasource, $.queries, $.from, $.to),
  links::
    local results = $.data.results;
    std.foldl(
      function(acc, i) acc + linksFromFrames(results[refId(i)].frames, std.get($.queries[i], 'link', null)),
      std.range(0, std.length($.queries) - 1),
      {}
    ),
  option::
    local results = $.data.results;
    local rawSeries = std.flattenArrays([
      seriesFromFrames(results[refId(i)].frames, $.type, null)
      for i in std.range(0, std.length($.queries) - 1)
    ]);
    local scale = if $.unit == 'bytes' then siScale(maxAbsValue(rawSeries)) else { factor: 1, suffix: null };
    local allSeries = scaleSeries(rawSeries, scale.factor, $.decimals);
    {
      title: { text: $.title },
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
      xAxis: {
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
      yAxis: { type: 'value' } + (
        if scale.suffix != null then { axisLabel: { formatter: '{value} ' + scale.suffix } } else {}
      ),
      series: allSeries,
    },
  _view+:: {
    local base = super.fragment,
    fragment: base { child:: [timeRangeNav($.from, $.to), base.child] },
  },
};

local collectQueries(node) =
  if node.type == 'panel' then node.chart.queries
  else std.flattenArrays([collectQueries(child) for child in node.children]);

local remapResults(results, offset, count) = {
  [refId(i)]: results[refId(offset + i)]
  for i in std.range(0, count - 1)
};

local resolveTree(node, results, index) =
  if node.type == 'panel' then
    local count = std.length(node.chart.queries);
    local resolved = chartNode + node.chart { data: { results: remapResults(results, index, count) } };
    { node: node { chart: { option: resolved.option, links: resolved.links } }, next: index + count }
  else
    local acc = std.foldl(
      function(acc, child)
        local r = resolveTree(child, results, acc.next);
        { children: acc.children + [r.node], next: r.next },
      node.children,
      { children: [], next: index }
    );
    { node: node { children: acc.children }, next: acc.next };

local dashboardNode = a.dashboard.view {
  local n = self,
  layout:: error 'Dashboard requires layout',
  _params:: timeParams,
  data: query(n.datasource, collectQueries(n.layout), n.from, n.to),
  tree:: resolveTree(n.layout, n.data.results, 0).node,
  _view+:: {
    local base = super.fragment,
    fragment: base { child:: [timeRangeNav(n.from, n.to), base.child] },
  },
};

local instantFrames(datasource, expr, from='now-5m', to='now') =
  query(datasource, [{ expr: expr, instant: true, range: false }], from, to).results.A.frames;

local frameLabelValues(frames, label) = [
  v
  for frame in frames
  for v in [std.get(frame.schema.fields[1].labels, label, null)]
  if v != null
];

local frameLabelNames(frames) =
  std.set(std.flattenArrays([
    [k for k in std.objectFields(frame.schema.fields[1].labels) if k != '__name__']
    for frame in frames
  ]));

local defaultGroup(n) = n._pathTemplate[std.length(n._pathTemplate) - 1];

local listNode = ui.groupList.view {
  local n = self,
  expr:: error 'List requires expr',
  label:: error 'List requires label',
  link:: error 'List requires link',
  group:: defaultGroup(n),
  data: frameLabelValues(instantFrames(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
};

local labelsNode = ui.groupList.view {
  local n = self,
  expr:: error 'Labels requires expr',
  link:: error 'Labels requires link',
  group:: defaultGroup(n),
  data: frameLabelNames(instantFrames(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now'))),
  links: { [n.group]: { [name]: n.link(name) for name in n.data } },
};

local valuesNode = ui.yaml.view {
  local n = self,
  expr:: error 'Values requires expr',
  label:: error 'Values requires label',
  data: frameLabelValues(instantFrames(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
};

local graph(datasourceNames) = [
  [['grafana']],
  [['grafana', 'datasources'], {
    data: datasourceNames,
    links: { [name]: root.grafana.datasource(name) for name in datasourceNames },
  }, ui.list.view],
  [['grafana', '$datasource']],
  [['grafana', '$datasource', 'metrics'], listNode {
    expr:: 'count by (__name__) ({__name__=~".+"})',
    label:: '__name__',
    link:: function(name) root.grafana.datasource($.datasource).metric(name),
  }],
  [['grafana', '$datasource', '$metric'], labelsNode {
    expr:: $.metric,
    group:: 'labels',
    link:: function(name) root.grafana.datasource($.datasource).metric($.metric).label(name),
  }],
  [['grafana', '$datasource', '$metric', '$label'], valuesNode {
    expr:: $.metric,
    label:: $.label,
  }],
];

{
  chart: { node: chartNode },
  dashboard: { node: dashboardNode },
  list: { node: listNode },
  labels: { node: labelsNode },
  values: { node: valuesNode },
  graph: graph,
}
