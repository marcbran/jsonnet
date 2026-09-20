local time = {
  now(): std.native('invoke:time')('now', []),
  addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
  parse(value, layout): std.native('invoke:time')('parse', [value, layout]),
  format(epochMs, layout): std.native('invoke:time')('format', [epochMs, layout]),
};
local telemetry = {
  query(items): std.native('invoke:telemetry')('query', [items]),
};
local chain =
  local root = import 'root';

  local capitalize(s) = std.asciiUpper(s[0:1]) + s[1:];
  local eqMatcher(label, var) = label + '="%(' + var + ')s"';
  local excludeMatcher(label) = label + '!=""';
  local matcherClause(parts) = std.join(', ', parts);
  local promote(arr, idx, val) = arr[:idx] + [val] + arr[idx + 1:];

  local chain(node, calls) = std.foldl(function(n, call) n[call[0]](call[1]), calls, node);
  local chainFields(node, fields) = std.foldl(function(n, f) n[f], fields, node);

  local accs(labels, vars) =
    local n = std.length(labels);
    local initialMatchers = [excludeMatcher(label) for label in labels];
    std.foldl(
      function(acc, i)
        acc + [
          if i == 0 then { ancestorVars: [], matchers: initialMatchers } else
            local prev = acc[i - 1];
            {
              ancestorVars: prev.ancestorVars + [vars[i - 1]],
              matchers: promote(prev.matchers, i - 1, eqMatcher(labels[i - 1], vars[i - 1])),
            },
        ],
      std.range(0, n),
      []
    );

  {
    root: root,
    capitalize: capitalize,
    eqMatcher: eqMatcher,
    excludeMatcher: excludeMatcher,
    matcherClause: matcherClause,
    promote: promote,
    chain: chain,
    chainFields: chainFields,
    accs: accs,
  };
local timeRange =
  local navScript = |||
    const UNITS = [['w', 6048e5], ['d', 864e5], ['h', 36e5], ['m', 6e4], ['s', 1e3]];
    const UNIT_MS = Object.fromEntries(UNITS);

    function parseOffset(value) {
      const match = /^now(?:([+-])((?:\d+[smhdw])+))?$/.exec(value);
      if (!match) return null;
      if (!match[2]) return 0;
      let magnitude = 0;
      for (const [, amount, unit] of match[2].matchAll(/(\d+)([smhdw])/g)) {
        magnitude += parseInt(amount, 10) * UNIT_MS[unit];
      }
      return match[1] === '+' ? -magnitude : magnitude;
    }

    function resolve(value, nowMs) {
      const offset = parseOffset(value);
      if (offset !== null) return nowMs - offset;
      const parsed = Date.parse(value);
      return isNaN(parsed) ? nowMs : parsed;
    }

    function formatOffset(offsetMs) {
      if (offsetMs === 0) return 'now';
      if (offsetMs % 1000 !== 0) return null;
      const sign = offsetMs > 0 ? '-' : '+';
      let magnitude = Math.abs(offsetMs);
      let parts = '';
      for (const [unit, unitMs] of UNITS) {
        const count = Math.floor(magnitude / unitMs);
        if (count > 0) {
          parts += `${count}${unit}`;
          magnitude -= count * unitMs;
        }
      }
      return `now${sign}${parts}`;
    }

    function formatValue(originalValue, newEpochMs, nowMs) {
      if (parseOffset(originalValue) !== null) {
        const relative = formatOffset(nowMs - newEpochMs);
        if (relative !== null) return relative;
      }
      return new Date(Math.round(newEpochMs)).toISOString();
    }

    function clampToNow(from, to, nowMs) {
      if (to <= nowMs) return { from, to };
      const overshoot = to - nowMs;
      return { from: from - overshoot, to: to - overshoot };
    }

    function shiftRange(fromValue, toValue, direction, nowMs) {
      const from = resolve(fromValue, nowMs);
      const to = resolve(toValue, nowMs);
      const delta = (to - from) * direction;
      const clamped = clampToNow(from + delta, to + delta, nowMs);
      return {
        from: formatValue(fromValue, clamped.from, nowMs),
        to: formatValue(toValue, clamped.to, nowMs),
      };
    }

    function zoomOutRange(fromValue, toValue, nowMs) {
      const from = resolve(fromValue, nowMs);
      const to = resolve(toValue, nowMs);
      const delta = (to - from) / 2;
      const clamped = clampToNow(from - delta, to + delta, nowMs);
      return {
        from: formatValue(fromValue, clamped.from, nowMs),
        to: formatValue(toValue, clamped.to, nowMs),
      };
    }

    function coverRange(fromValue, toValue, edgeMs, direction, nowMs) {
      const size = resolve(toValue, nowMs) - resolve(fromValue, nowMs);
      const rawFrom = direction < 0 ? edgeMs - size : edgeMs;
      const rawTo = direction < 0 ? edgeMs : edgeMs + size;
      const clamped = clampToNow(rawFrom, rawTo, nowMs);
      return {
        from: new Date(Math.round(clamped.from)).toISOString(),
        to: new Date(Math.round(clamped.to)).toISOString(),
      };
    }

    function pad2(n) {
      return String(n).padStart(2, '0');
    }

    function formatLocal(epochMs) {
      const d = new Date(epochMs);
      return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
    }

    function formatLocalDate(epochMs) {
      return formatLocal(epochMs).slice(0, 10);
    }

    function displayValue(value, nowMs) {
      return parseOffset(value) === null ? formatLocal(resolve(value, nowMs)) : value;
    }

    function dateOnlyValue(value, nowMs) {
      return parseOffset(value) === null ? formatLocalDate(resolve(value, nowMs)) : '';
    }

    function combineDatePart(dateOnly, currentValue) {
      let timePart = '00:00:00';
      if (parseOffset(currentValue) === null) {
        const parsed = new Date(Date.parse(currentValue));
        if (!isNaN(parsed.getTime())) timePart = `${pad2(parsed.getHours())}:${pad2(parsed.getMinutes())}:${pad2(parsed.getSeconds())}`;
      }
      return `${dateOnly} ${timePart}`;
    }

    if (typeof HTMLElement !== 'undefined') {
      class TimeRangeNav extends HTMLElement {
        static get observedAttributes() {
          return ['from', 'to', 'result-from', 'result-to'];
        }

        connectedCallback() {
          this.attachShadow({ mode: 'open' });
          this.shadowRoot.innerHTML = `
            <style>
              :host {
                display: flex;
                justify-content: flex-end;
                font-family: monospace;
                font-size: 1.05em;
                margin-bottom: 0.75em;
              }
              .chip {
                display: flex;
                align-items: stretch;
                border: 1px solid var(--border-color);
                border-radius: 0.5em;
                overflow: hidden;
                background: var(--container-low-color);
              }
              .chip > * {
                display: flex;
                align-items: center;
                line-height: 1;
                padding: 0.4em 0.6em;
                border: none;
                border-right: 1px solid var(--border-color);
                border-radius: 0;
                background: transparent;
              }
              .chip > *:last-child {
                border-right: none;
              }
              .chip > button {
                width: 2.6rem;
                height: 2.6rem;
                padding: 0;
                justify-content: center;
                font-size: 2.1em;
                cursor: pointer;
              }
              #label {
                cursor: pointer;
                height: 2.6rem;
                padding-top: 0;
                padding-bottom: 0;
              }
              button, input[type="text"] {
                background: var(--background-color);
                color: inherit;
                border: 1px solid var(--border-color);
                border-radius: 0.3em;
                font: inherit;
                padding: 0.15em 0.5em;
              }
              button {
                cursor: pointer;
              }
              dialog {
                position: fixed;
                inset: auto;
                margin: 0;
                border: 1px solid var(--border-color);
                border-radius: 0.5em;
                padding: 1em 1.2em;
                background: var(--background-color);
                color: inherit;
                font-family: monospace;
                font-size: 0.9rem;
              }
              dialog::backdrop {
                background: transparent;
              }
              dialog button, dialog input[type="text"] {
                padding: 0.3em 0.6em;
              }
              dialog[open] {
                display: flex;
                flex-direction: column;
                gap: 0.75em;
              }
              dialog .row {
                display: flex;
                flex-direction: column;
                gap: 0.3em;
              }
              dialog .field {
                display: flex;
                gap: 0.3em;
              }
              dialog .field input[type="text"] {
                flex: 1;
                min-width: 13em;
              }
              dialog input:focus {
                outline: none;
              }
              dialog .date-wrap {
                position: relative;
                display: inline-flex;
              }
              dialog .date-btn {
                padding: 0.35em 0.5em;
                cursor: pointer;
              }
              dialog .date-wrap input[type="date"] {
                position: absolute;
                inset: 0;
                width: 100%;
                height: 100%;
                padding: 0;
                border: none;
                opacity: 0;
                pointer-events: none;
              }
              dialog .actions {
                display: flex;
                justify-content: flex-end;
                gap: 0.6em;
                margin-top: 0.75em;
              }
            </style>
            <div class="chip">
              <button id="back" type="button" title="Shift back one window">&laquo;</button>
              <button id="back-cover" type="button" title="Older (continue from returned range)">&lsaquo;</button>
              <span id="label" title="Edit time range"></span>
              <button id="forward-cover" type="button" title="Newer (continue from returned range)">&rsaquo;</button>
              <button id="forward" type="button" title="Shift forward one window">&raquo;</button>
              <button id="zoom-out" type="button" title="Zoom out">&#8854;</button>
            </div>
            <dialog id="modal">
              <div class="row">
                <label for="from-input">From</label>
                <div class="field">
                  <input type="text" id="from-input">
                  <div class="date-wrap">
                    <button type="button" class="date-btn" id="from-date-btn" aria-label="Pick from date">&#128197;</button>
                    <input type="date" id="from-date" tabindex="-1" aria-hidden="true">
                  </div>
                </div>
              </div>
              <div class="row">
                <label for="to-input">To</label>
                <div class="field">
                  <input type="text" id="to-input">
                  <div class="date-wrap">
                    <button type="button" class="date-btn" id="to-date-btn" aria-label="Pick to date">&#128197;</button>
                    <input type="date" id="to-date" tabindex="-1" aria-hidden="true">
                  </div>
                </div>
              </div>
              <div class="actions">
                <button type="button" id="apply">Apply</button>
              </div>
            </dialog>
          `;
          this.shadowRoot.getElementById('back').addEventListener('click', () => this.shift(-1));
          this.shadowRoot.getElementById('forward').addEventListener('click', () => this.shift(1));
          this.shadowRoot.getElementById('back-cover').addEventListener('click', () => this.cover(-1));
          this.shadowRoot.getElementById('forward-cover').addEventListener('click', () => this.cover(1));
          this.shadowRoot.getElementById('zoom-out').addEventListener('click', () => this.zoomOut());
          this.shadowRoot.getElementById('label').addEventListener('click', () => this.openModal());
          this.shadowRoot.getElementById('apply').addEventListener('click', () => this.applyModal());
          this.shadowRoot.getElementById('modal').addEventListener('click', (e) => {
            if (e.target === e.currentTarget) this.closeModal();
          });
          this.shadowRoot.getElementById('from-date').addEventListener('change', (e) => this.applyDatePart('from', e.target.value));
          this.shadowRoot.getElementById('to-date').addEventListener('change', (e) => this.applyDatePart('to', e.target.value));
          this.shadowRoot.getElementById('from-date-btn').addEventListener('click', () => this.shadowRoot.getElementById('from-date').showPicker());
          this.shadowRoot.getElementById('to-date-btn').addEventListener('click', () => this.shadowRoot.getElementById('to-date').showPicker());
          this.updateLabel();
          this.updateCoverButtons();
        }

        attributeChangedCallback() {
          this.updateLabel();
          this.updateCoverButtons();
        }

        updateCoverButtons() {
          if (!this.shadowRoot) return;
          const back = this.shadowRoot.getElementById('back-cover');
          const forward = this.shadowRoot.getElementById('forward-cover');
          if (back) back.style.display = this.hasAttribute('result-from') ? '' : 'none';
          if (forward) forward.style.display = this.hasAttribute('result-to') ? '' : 'none';
        }

        updateLabel() {
          const label = this.shadowRoot && this.shadowRoot.getElementById('label');
          if (!label) return;
          const nowMs = Date.now();
          const from = displayValue(this.getAttribute('from'), nowMs);
          const to = displayValue(this.getAttribute('to'), nowMs);
          label.textContent = `${from} to ${to}`;
        }

        navigateTo(newFrom, newTo) {
          const url = new URL(window.location.href);
          url.searchParams.set('from', newFrom);
          url.searchParams.set('to', newTo);
          window.location.href = url.toString();
        }

        shift(direction) {
          const range = shiftRange(this.getAttribute('from'), this.getAttribute('to'), direction, Date.now());
          this.navigateTo(range.from, range.to);
        }

        cover(direction) {
          const edge = direction < 0 ? this.getAttribute('result-from') : this.getAttribute('result-to');
          if (edge === null) return;
          const range = coverRange(this.getAttribute('from'), this.getAttribute('to'), Number(edge), direction, Date.now());
          this.navigateTo(range.from, range.to);
        }

        zoomOut() {
          const range = zoomOutRange(this.getAttribute('from'), this.getAttribute('to'), Date.now());
          this.navigateTo(range.from, range.to);
        }

        openModal() {
          const nowMs = Date.now();
          this.shadowRoot.getElementById('from-input').value = displayValue(this.getAttribute('from'), nowMs);
          this.shadowRoot.getElementById('to-input').value = displayValue(this.getAttribute('to'), nowMs);
          this.shadowRoot.getElementById('from-date').value = dateOnlyValue(this.getAttribute('from'), nowMs);
          this.shadowRoot.getElementById('to-date').value = dateOnlyValue(this.getAttribute('to'), nowMs);
          const modal = this.shadowRoot.getElementById('modal');
          const rect = this.getBoundingClientRect();
          modal.style.top = `${rect.bottom + 4}px`;
          modal.style.right = `${window.innerWidth - rect.right}px`;
          modal.showModal();
        }

        closeModal() {
          this.shadowRoot.getElementById('modal').close();
        }

        applyDatePart(field, dateOnly) {
          if (!dateOnly) return;
          const input = this.shadowRoot.getElementById(`${field}-input`);
          input.value = combineDatePart(dateOnly, input.value);
        }

        applyModal() {
          const nowMs = Date.now();
          const fromValue = this.shadowRoot.getElementById('from-input').value;
          const toValue = this.shadowRoot.getElementById('to-input').value;
          const from = formatValue(fromValue, resolve(fromValue, nowMs), nowMs);
          const to = formatValue(toValue, resolve(toValue, nowMs), nowMs);
          this.navigateTo(from, to);
        }
      }

      if (!customElements.get('time-range-nav')) customElements.define('time-range-nav', TimeRangeNav);
    }

    if (typeof module !== 'undefined' && module.exports) {
      module.exports = { parseOffset, resolve, formatOffset, formatValue, shiftRange, zoomOutRange, coverRange, formatLocal, formatLocalDate, displayValue, dateOnlyValue, combineDatePart };
    }
  |||;

  local element = {
    local c = self,
    from:: error 'element requires from',
    to:: error 'element requires to',
    resultFrom:: null,
    resultTo:: null,
    html: {
      element: 'time-range-nav',
      attributes: { from: c.from, to: c.to }
                  + (if c.resultFrom != null then { 'result-from': std.toString(c.resultFrom) } else {})
                  + (if c.resultTo != null then { 'result-to': std.toString(c.resultTo) } else {}),
    },
  };

  local script = { html: { element: 'script', children: [{ html: navScript }] } };

  {
    paramSpecs: [
      { name: 'from', type: 'string', default: 'now-1h' },
      { name: 'to', type: 'string', default: 'now' },
    ],
    element: element,
    script: script,
    nav: {
      local c = self,
      from:: error 'nav requires from',
      to:: error 'nav requires to',
      resultFrom:: null,
      resultTo:: null,
      html: [
        (element { from:: c.from, to:: c.to, resultFrom:: c.resultFrom, resultTo:: c.resultTo }).html,
        script.html,
      ],
    },
  };

local queryLib = function(time, telemetry)
  local rfc3339 = '2006-01-02T15:04:05Z07:00';
  local resolveTime(nowMs, value) =
    if value == 'now' then std.toString(nowMs)
    else if std.length(value) > 3 && std.substr(value, 0, 3) == 'now' then
      std.toString(time.addDuration(nowMs, std.substr(value, 3, std.length(value) - 3)))
    else
      std.toString(time.parse(value, rfc3339));

  function(datasource, items, from='now-1h', to='now')
    local nowMs = time.now();
    local resolvedFrom = resolveTime(nowMs, from);
    local resolvedTo = resolveTime(nowMs, to);
    telemetry.query([
      item { datasource: datasource, from: resolvedFrom, to: resolvedTo }
      for item in items
    ]);
local browseLib = function(query)
  local result(datasource, expr, from='now-5m', to='now') =
    query(datasource, [{ type: 'promql', expr: expr, instant: true }], from, to).results[0];

  local labelValues(result, label) = [
    v
    for s in result.series
    for v in [std.get(s.labels, label, null)]
    if v != null
  ];

  local labelNames(result) =
    std.set(std.flattenArrays([
      [k for k in std.objectFields(s.labels) if k != '__name__']
      for s in result.series
    ]));

  local defaultGroup(n) = n._pathTemplate[std.length(n._pathTemplate) - 1];

  {
    result: result,
    labelValues: labelValues,
    labelNames: labelNames,
    defaultGroup: defaultGroup,
  };
local nodesChartLib =
  local a =
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
    } + charts;
  local time = {
    now(): std.native('invoke:time')('now', []),
    addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
    parse(value, layout): std.native('invoke:time')('parse', [value, layout]),
    format(epochMs, layout): std.native('invoke:time')('format', [epochMs, layout]),
  };

  function(query, timeRange)
    local defaultSeriesName(labels) =
      local name = std.get(labels, '__name__', null);
      local rest = std.join(', ', ['%s="%s"' % [k, labels[k]] for k in std.objectFields(labels) if k != '__name__']);
      if name != null && rest != '' then '%s{%s}' % [name, rest]
      else if name != null then name
      else if rest != '' then '{%s}' % rest
      else 'value';

    local applyLegendFormat(legendFormat, labels) =
      std.foldl(
        function(acc, k) std.strReplace(acc, '{{%s}}' % k, labels[k]),
        std.objectFields(labels),
        legendFormat
      );

    local seriesName(labels, legendFormat) =
      if legendFormat != null then applyLegendFormat(legendFormat, labels)
      else defaultSeriesName(labels);

    local hasPoints(series) = std.length(series.points) > 0;

    local minList(l) = std.foldl(function(a, b) if b < a then b else a, l[1:], l[0]);

    local stepFor(points) =
      local ts = [p[0] for p in points];
      local deltas = [ts[j + 1] - ts[j] for j in std.range(0, std.length(ts) - 2) if ts[j + 1] > ts[j]];
      if std.length(deltas) > 0 then minList(deltas) else 60000;

    local segmentsFor(points, step) =
      local active = [p for p in points if p[1] != null && p[1] != 0];
      if std.length(active) == 0 then []
      else
        local res = std.foldl(
          function(acc, p)
            local ts = p[0];
            local v = p[1];
            if acc.cur == null then acc { cur: { start: ts, end: ts + step, value: v } }
            else if v == acc.cur.value && ts <= acc.cur.end + step * 0.5 then acc { cur: acc.cur { end: ts + step } }
            else acc { segs: acc.segs + [acc.cur], cur: { start: ts, end: ts + step, value: v } },
          active,
          { segs: [], cur: null }
        );
        res.segs + (if res.cur != null then [res.cur] else []);

    local linksFromResult(result, linkFn, legendFormat) =
      if linkFn == null then {}
      else {
        [seriesName(s.labels, legendFormat)]: linkFn(s.labels)
        for s in result.series
        if hasPoints(s) && linkFn(s.labels) != null
      };

    {
      base: a.chart.view {
        local n = self,
        datasource:: 'default',
        queries:: error 'Chart requires queries',
        _paramSpecs: timeRange.paramSpecs,
        _telemetryItems:: [
          { type: 'promql', expr: qr.expr, instant: std.get(qr, 'instant', false) }
          for qr in n.queries
        ],
        data: query(n.datasource, n._telemetryItems, n._params.from, n._params.to),
        _view+:: {
          local baseFragment = super.fragment,
          fragment: baseFragment { child:: [(timeRange.nav { from:: n._params.from, to:: n._params.to }).html, baseFragment.child] },
        },
      },

      line: a.line.chart {
        local n = self,
        links: std.foldl(
          function(acc, i) acc + linksFromResult(
            n.data.results[i],
            std.get(n.queries[i], 'link', null),
            std.get(n.queries[i], 'legendFormat', null)
          ),
          std.range(0, std.length(n.queries) - 1),
          {}
        ),
        series:: std.flattenArrays([
          [
            { name: seriesName(s.labels, std.get(n.queries[i], 'legendFormat', null)), data: [[p[0], p[1]] for p in s.points] }
            for s in n.data.results[i].series
            if hasPoints(s)
          ]
          for i in std.range(0, std.length(n.queries) - 1)
        ]),
      },

      stateTimeline: a.stateTimeline.chart {
        local n = self,
        local render(template, labels, value) =
          if template != null then applyLegendFormat(template, labels { value: std.toString(value) }) else null,
        local linkFor(linkFn, labels) = if linkFn == null then null else linkFn(labels),
        local rawSeries = std.flattenArrays([
          [
            {
              row: if n.rowBy != null then applyLegendFormat(n.rowBy, s.labels) else seriesName(s.labels, std.get(n.queries[i], 'legendFormat', null)),
              color: if n.colorBy != null then std.get(n.colors, applyLegendFormat(n.colorBy, s.labels), null) else null,
              linkNode: linkFor(std.get(n.queries[i], 'link', null), s.labels),
              labels: s.labels,
              segments: segmentsFor(s.points, stepFor(s.points)),
            }
            for s in n.data.results[i].series
            if hasPoints(s)
          ]
          for i in std.range(0, std.length(n.queries) - 1)
        ]),
        local active = [s for s in rawSeries if std.length(s.segments) > 0],
        rowBy:: null,
        colorBy:: null,
        colors:: {},
        labelBy:: null,
        tooltip:: null,
        timeFormat:: '2006-01-02 15:04',
        rows:: std.foldl(function(acc, s) if std.member(acc, s.row) then acc else acc + [s.row], active, []),
        links: std.foldl(function(acc, s) if s.linkNode != null then acc { [s.row]: s.linkNode } else acc, active, {}),
        segments:: std.flattenArrays([
          [{
            row: s.row,
            start: seg.start,
            end: seg.end,
            color: s.color,
            label: render(n.labelBy, s.labels, seg.value),
            tooltip: render(n.tooltip, s.labels { from: time.format(seg.start, n.timeFormat), to: time.format(seg.end, n.timeFormat) }, seg.value),
            link: if s.linkNode != null then s.linkNode._queryPath else null,
          } for seg in s.segments]
          for s in active
        ]),
      },
    };
local nodeListsDrilldownLib = function(c)
  function(params)
    local base = params.base;
    local rootNode = c.chainFields(c.root, base);
    local vars = params.vars;
    local labels = std.get(params, 'labels', vars);
    local titles = std.get(params, 'titles', [c.capitalize(v) for v in vars]);
    local metric = params.metric;
    local n = std.length(vars);

    local pathSuffixes = [
      [vars[i] + 's', if i == n - 1 then metric else vars[n - 1] + c.capitalize(metric)]
      for i in std.range(0, n - 1)
    ] + [[metric]];

    local accs = c.accs(labels, vars);

    local levelInputs = [
      local idx = if i == n then n - 1 else i;
      {
        isLeaf: i == n,
        label: labels[idx],
        var: vars[idx],
        title: titles[idx],
        ancestorVars: accs[i].ancestorVars,
        matchers: c.matcherClause(accs[i].matchers),
        path: base + ['$' + v for v in accs[i].ancestorVars] + pathSuffixes[i],
        nextPathSuffix: if i < n then pathSuffixes[i + 1] else null,
      }
      for i in std.range(0, n)
    ];

    [
      local ctx = params {
        groupBy:: li.label,
        matchers:: li.matchers,
        titleGroupBy:: if li.isLeaf then '' else 'by %s ' % li.title,
      };
      local override = std.get(std.get(ctx, 'levels', {}), ctx.groupBy, {});
      [li.path, ctx + override {
        title:: ctx.title,
        queries: [
          {
            expr: ctx.expr % $,
            legendFormat: if std.objectHasAll(params, 'legend') then ctx.legend else '{{%s}}' % ctx.groupBy,
            link:: if li.isLeaf then null else function(series)
              c.chainFields(
                c.chain(rootNode, [[v, $[v]] for v in li.ancestorVars] + [[li.var, series[li.label]]]),
                li.nextPathSuffix
              ),
          },
        ],
      }]
      for li in levelInputs
    ];
local nodeListsEntityLib = function(c, listNode, drilldown, logsNode)
  function(params)
    local base = params.base;
    local rootNode = c.chainFields(c.root, base);
    local vars = params.vars;
    local labels = std.get(params, 'labels', vars);
    local n = std.length(vars);
    local last = n - 1;

    local accs = c.accs(labels, vars);
    local ancestorVars = accs[last].ancestorVars;
    local matchers = c.matcherClause(accs[last].matchers);

    local collectionPath = base + ['$' + v for v in ancestorVars] + [vars[last] + 's'];
    local placeholderPath = base + ['$' + v for v in ancestorVars] + ['$' + vars[last]];

    local ctx = params { groupBy:: labels[last], matchers:: matchers };

    local entityEntries =
      if std.objectHasAll(params, 'entityBase') then
        local entityNode = c.chainFields(c.root, params.entityBase);
        local entityPath = params.entityBase + ['$' + v for v in vars];
        [
          [placeholderPath, { links+: { entity: c.chain(entityNode, [[v, $[v]] for v in vars]) } }],
          [entityPath, { links+: { telemetry: c.chain(rootNode, [[v, $[v]] for v in vars]) } }],
        ]
      else [[placeholderPath]];

    local browseEntries = [
      [collectionPath, listNode {
        expr:: ctx.listExpr % $,
        label:: labels[last],
        link:: function(name)
          c.chain(rootNode, [[v, $[v]] for v in ancestorVars] + [[vars[last], name]]),
      }],
    ] + entityEntries;

    local drillDowns = std.get(params, 'drillDowns', {});
    local drillDownEntries = std.flattenArrays([
      drilldown(params + drillDowns[metric] { metric:: metric })
      for metric in std.objectFields(drillDowns)
    ]);

    local logsEntries =
      if std.objectHasAll(params, 'logs') then
        local logsLink = { links+: { logs: c.chain(rootNode, [[v, $[v]] for v in vars]).logs } };
        [
          [placeholderPath + ['logs'], logsNode + params.logs],
          [placeholderPath, logsLink],
        ] + (
          if std.objectHasAll(params, 'entityBase')
          then [[params.entityBase + ['$' + v for v in vars], logsLink]]
          else []
        )
      else [];

    browseEntries + logsEntries + drillDownEntries;
local nodeListsEntitiesLib = function(entity)
  function(specs)
    std.flattenArrays([entity(spec) for spec in specs]);
local nodesListLib =
  local a =
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

      local hexDigits = '0123456789ABCDEF';

      local percentEncode(s) =
        std.join('', [
          local c = s[i];
          local cp = std.codepoint(c);
          if (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) || (cp >= 48 && cp <= 57)
             || c == '-' || c == '_' || c == '.' || c == '~'
          then c
          else '%' + hexDigits[std.floor(cp / 16)] + hexDigits[cp % 16]
          for i in std.range(0, std.length(s) - 1)
        ]);

      local resolveLiteralSegment(node, item, seg) =
        if std.objectHas(seg, 'const') then seg.const
        else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
        else resolveKey(seg, item);

      local resolveLiteralSegments(node, item, segs) =
        std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

      local resolveQuery(node, item, queryObj) =
        local keys = std.objectFields(queryObj);
        if std.length(keys) == 0 then ''
        else '?' + std.join('&', [
          percentEncode(k) + '=' + percentEncode(resolveLiteralSegments(node, item, queryObj[k]))
          for k in keys
        ]);

      local resolveUrl(node, item, url) =
        local scheme = std.get(url, 'scheme', null);
        local host = std.get(url, 'host', []);
        local path = std.get(url, 'path', []);
        local query = std.get(url, 'query', {});
        (if scheme != null then scheme + '://' else '')
        + resolveLiteralSegments(node, item, host)
        + (
          if std.length(path) > 0 then
            '/' + std.join('/', [percentEncode(resolveLiteralSegment(node, item, seg)) for seg in path])
          else ''
        )
        + resolveQuery(node, item, query);

      local urlSegments(url) =
        std.get(url, 'host', []) + std.get(url, 'path', [])
        + std.flattenArrays([url.query[k] for k in std.objectFields(std.get(url, 'query', {}))]);

      local buildLinks(node, specs, root=import 'root') =
        std.foldl(
          function(acc, spec)
            acc + (
              if std.type(spec.value) == 'object' then
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, urlSegments(spec.value))
                    then nestKeys(spec.keys, item, resolveUrl(node, item, spec.value))
                    else {}
                )
              else
                local split = splitPrefix(spec.value);
                local base = resolveBase(root, node, split.prefix);
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, spec.value)
                    then nestKeys(spec.keys, item, resolveFromBase(base, item, split.suffix))
                    else {}
                )
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
        else
          local split = splitPrefix(spec.value);
          local base = resolveBase(root, node, split.prefix);
          function(item)
            if resolvable(item, spec.value) then resolveFromBase(base, item, split.suffix) else null;

      {
        buildLinks: buildLinks,
        rowLinkFor: rowLinkFor,
        withLinkSpecs: {
          linkSpecs:: [],
          links: buildLinks(self, self.linkSpecs, import 'root'),
        },
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

    local linksGroups(obj) =
      local links = std.get(obj, 'links', {});
      if std.type(links) != 'object' then []
      else std.flatMap(
        function(k)
          local value = links[k];
          if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value, linkStrings=true) }]
          else [],
        std.objectFields(links)
      );

    local neighborItems(obj) = collectNeighbors(obj, '', ['data', '_view', 'links']) + linksItems(obj);

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
          groups:: linksGroups($),
        },
      },
    };

    local yamlView = baseView {
      _view+:: {
        fragment: c.yaml { data:: $.data },
      },
    };

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
            pagination:: std.get(std.get($, 'links', {}), 'pagination', null),
          },
      },
    };

    local resourceView = baseView {
      _view+:: {
        fragment: c.resource {
          data:: $.data,
          items:: neighborItems($),
          groups:: linksGroups($),
        },
      },
    };

    local withNode = { node: self.view + linkspecs.withLinkSpecs };

    {
      default: { view: listView } + withNode,
      list: { view: listView } + withNode,
      table: { view: tableView } + withNode,
      yaml: { view: yamlView } + withNode,
      resource: { view: resourceView } + withNode,
    };

  function(browse)
    a.list.view {
      local n = self,
      datasource:: 'default',
      expr:: error 'List requires expr',
      label:: error 'List requires label',
      link:: error 'List requires link',
      group:: browse.defaultGroup(n),
      data: browse.labelValues(browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
      links: { [n.group]: { [name]: n.link(name) for name in n.data } },
    };
local nodesLabelsLib =
  local a =
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

      local hexDigits = '0123456789ABCDEF';

      local percentEncode(s) =
        std.join('', [
          local c = s[i];
          local cp = std.codepoint(c);
          if (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) || (cp >= 48 && cp <= 57)
             || c == '-' || c == '_' || c == '.' || c == '~'
          then c
          else '%' + hexDigits[std.floor(cp / 16)] + hexDigits[cp % 16]
          for i in std.range(0, std.length(s) - 1)
        ]);

      local resolveLiteralSegment(node, item, seg) =
        if std.objectHas(seg, 'const') then seg.const
        else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
        else resolveKey(seg, item);

      local resolveLiteralSegments(node, item, segs) =
        std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

      local resolveQuery(node, item, queryObj) =
        local keys = std.objectFields(queryObj);
        if std.length(keys) == 0 then ''
        else '?' + std.join('&', [
          percentEncode(k) + '=' + percentEncode(resolveLiteralSegments(node, item, queryObj[k]))
          for k in keys
        ]);

      local resolveUrl(node, item, url) =
        local scheme = std.get(url, 'scheme', null);
        local host = std.get(url, 'host', []);
        local path = std.get(url, 'path', []);
        local query = std.get(url, 'query', {});
        (if scheme != null then scheme + '://' else '')
        + resolveLiteralSegments(node, item, host)
        + (
          if std.length(path) > 0 then
            '/' + std.join('/', [percentEncode(resolveLiteralSegment(node, item, seg)) for seg in path])
          else ''
        )
        + resolveQuery(node, item, query);

      local urlSegments(url) =
        std.get(url, 'host', []) + std.get(url, 'path', [])
        + std.flattenArrays([url.query[k] for k in std.objectFields(std.get(url, 'query', {}))]);

      local buildLinks(node, specs, root=import 'root') =
        std.foldl(
          function(acc, spec)
            acc + (
              if std.type(spec.value) == 'object' then
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, urlSegments(spec.value))
                    then nestKeys(spec.keys, item, resolveUrl(node, item, spec.value))
                    else {}
                )
              else
                local split = splitPrefix(spec.value);
                local base = resolveBase(root, node, split.prefix);
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, spec.value)
                    then nestKeys(spec.keys, item, resolveFromBase(base, item, split.suffix))
                    else {}
                )
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
        else
          local split = splitPrefix(spec.value);
          local base = resolveBase(root, node, split.prefix);
          function(item)
            if resolvable(item, spec.value) then resolveFromBase(base, item, split.suffix) else null;

      {
        buildLinks: buildLinks,
        rowLinkFor: rowLinkFor,
        withLinkSpecs: {
          linkSpecs:: [],
          links: buildLinks(self, self.linkSpecs, import 'root'),
        },
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

    local linksGroups(obj) =
      local links = std.get(obj, 'links', {});
      if std.type(links) != 'object' then []
      else std.flatMap(
        function(k)
          local value = links[k];
          if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value, linkStrings=true) }]
          else [],
        std.objectFields(links)
      );

    local neighborItems(obj) = collectNeighbors(obj, '', ['data', '_view', 'links']) + linksItems(obj);

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
          groups:: linksGroups($),
        },
      },
    };

    local yamlView = baseView {
      _view+:: {
        fragment: c.yaml { data:: $.data },
      },
    };

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
            pagination:: std.get(std.get($, 'links', {}), 'pagination', null),
          },
      },
    };

    local resourceView = baseView {
      _view+:: {
        fragment: c.resource {
          data:: $.data,
          items:: neighborItems($),
          groups:: linksGroups($),
        },
      },
    };

    local withNode = { node: self.view + linkspecs.withLinkSpecs };

    {
      default: { view: listView } + withNode,
      list: { view: listView } + withNode,
      table: { view: tableView } + withNode,
      yaml: { view: yamlView } + withNode,
      resource: { view: resourceView } + withNode,
    };

  function(browse)
    a.list.view {
      local n = self,
      datasource:: 'default',
      expr:: error 'Labels requires expr',
      link:: error 'Labels requires link',
      group:: browse.defaultGroup(n),
      data: browse.labelNames(browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now'))),
      links: { [n.group]: { [name]: n.link(name) for name in n.data } },
    };
local nodesValuesLib =
  local a =
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

      local hexDigits = '0123456789ABCDEF';

      local percentEncode(s) =
        std.join('', [
          local c = s[i];
          local cp = std.codepoint(c);
          if (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) || (cp >= 48 && cp <= 57)
             || c == '-' || c == '_' || c == '.' || c == '~'
          then c
          else '%' + hexDigits[std.floor(cp / 16)] + hexDigits[cp % 16]
          for i in std.range(0, std.length(s) - 1)
        ]);

      local resolveLiteralSegment(node, item, seg) =
        if std.objectHas(seg, 'const') then seg.const
        else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
        else resolveKey(seg, item);

      local resolveLiteralSegments(node, item, segs) =
        std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

      local resolveQuery(node, item, queryObj) =
        local keys = std.objectFields(queryObj);
        if std.length(keys) == 0 then ''
        else '?' + std.join('&', [
          percentEncode(k) + '=' + percentEncode(resolveLiteralSegments(node, item, queryObj[k]))
          for k in keys
        ]);

      local resolveUrl(node, item, url) =
        local scheme = std.get(url, 'scheme', null);
        local host = std.get(url, 'host', []);
        local path = std.get(url, 'path', []);
        local query = std.get(url, 'query', {});
        (if scheme != null then scheme + '://' else '')
        + resolveLiteralSegments(node, item, host)
        + (
          if std.length(path) > 0 then
            '/' + std.join('/', [percentEncode(resolveLiteralSegment(node, item, seg)) for seg in path])
          else ''
        )
        + resolveQuery(node, item, query);

      local urlSegments(url) =
        std.get(url, 'host', []) + std.get(url, 'path', [])
        + std.flattenArrays([url.query[k] for k in std.objectFields(std.get(url, 'query', {}))]);

      local buildLinks(node, specs, root=import 'root') =
        std.foldl(
          function(acc, spec)
            acc + (
              if std.type(spec.value) == 'object' then
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, urlSegments(spec.value))
                    then nestKeys(spec.keys, item, resolveUrl(node, item, spec.value))
                    else {}
                )
              else
                local split = splitPrefix(spec.value);
                local base = resolveBase(root, node, split.prefix);
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, spec.value)
                    then nestKeys(spec.keys, item, resolveFromBase(base, item, split.suffix))
                    else {}
                )
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
        else
          local split = splitPrefix(spec.value);
          local base = resolveBase(root, node, split.prefix);
          function(item)
            if resolvable(item, spec.value) then resolveFromBase(base, item, split.suffix) else null;

      {
        buildLinks: buildLinks,
        rowLinkFor: rowLinkFor,
        withLinkSpecs: {
          linkSpecs:: [],
          links: buildLinks(self, self.linkSpecs, import 'root'),
        },
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

    local linksGroups(obj) =
      local links = std.get(obj, 'links', {});
      if std.type(links) != 'object' then []
      else std.flatMap(
        function(k)
          local value = links[k];
          if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value, linkStrings=true) }]
          else [],
        std.objectFields(links)
      );

    local neighborItems(obj) = collectNeighbors(obj, '', ['data', '_view', 'links']) + linksItems(obj);

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
          groups:: linksGroups($),
        },
      },
    };

    local yamlView = baseView {
      _view+:: {
        fragment: c.yaml { data:: $.data },
      },
    };

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
            pagination:: std.get(std.get($, 'links', {}), 'pagination', null),
          },
      },
    };

    local resourceView = baseView {
      _view+:: {
        fragment: c.resource {
          data:: $.data,
          items:: neighborItems($),
          groups:: linksGroups($),
        },
      },
    };

    local withNode = { node: self.view + linkspecs.withLinkSpecs };

    {
      default: { view: listView } + withNode,
      list: { view: listView } + withNode,
      table: { view: tableView } + withNode,
      yaml: { view: yamlView } + withNode,
      resource: { view: resourceView } + withNode,
    };

  function(browse)
    a.yaml.view {
      local n = self,
      datasource:: 'default',
      expr:: error 'Values requires expr',
      label:: error 'Values requires label',
      data: browse.labelValues(browse.result(n.datasource, n.expr, std.get(n, 'from', 'now-5m'), std.get(n, 'to', 'now')), n.label),
    };
local nodesLogsLib =
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
  local logs =
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
    local time = {
      now(): std.native('invoke:time')('now', []),
      addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
      parse(value, layout): std.native('invoke:time')('parse', [value, layout]),
      format(epochMs, layout): std.native('invoke:time')('format', [epochMs, layout]),
    };

    local defaultColors = {
      fatal: '#8a3a3a',
      critical: '#8a3a3a',
      'error': '#a35454',
      warn: '#b0902f',
      warning: '#b0902f',
      info: '#5a7a94',
      debug: '#7a7a7a',
      trace: '#6a6a6a',
    };

    local style = |||
      @scope (.logs) {
        :scope {
          font-family: monospace;
          display: flex;
          flex-direction: column;
          gap: 0.1em;
          min-width: 32em;
        }
        .log-entry {
          border-left: 0.25em solid var(--border-color);
          border-radius: 0.25em;
        }
        .log-row {
          display: flex;
          align-items: baseline;
          gap: 0.5em;
          padding: 0.1em 0.4em;
          list-style: none;
        }
        .log-row::-webkit-details-marker {
          display: none;
        }
        details.log-entry > summary.log-row {
          cursor: pointer;
        }
        details.log-entry > summary.log-row:hover {
          background-color: var(--container-low-color);
          border-radius: 0.25em;
        }
        .log-time {
          color: var(--primary-color);
          white-space: nowrap;
          opacity: 0.8;
        }
        .log-body {
          white-space: pre-wrap;
          word-break: break-all;
        }
        .log-detail {
          padding: 0 0.4em 0.3em;
        }
        .logs-empty {
          opacity: 0.6;
        }
      }
    |||;

    local logRow = {
      local r = self,
      record:: error 'LogRow requires record',
      colors:: {},
      timeFormat:: error 'LogRow requires timeFormat',
      local rec = r.record,
      local fields = std.get(rec, 'fields', {}),
      local expandable = std.length(fields) > 0,
      local color = std.get(r.colors, std.asciiLower(std.get(rec, 'severity', '')), null),
      local entryAttrs = { class: 'log-entry' } + (if color != null then { style: 'border-left-color: %s' % color } else {}),
      local rowChildren = [
        { element: 'span', attributes: { class: 'log-time' }, children: [time.format(rec.timestamp, r.timeFormat)] },
        { element: 'span', attributes: { class: 'log-body' }, children: [std.get(rec, 'body', '')] },
      ],
      html:
        if expandable then {
          element: 'details',
          attributes: entryAttrs,
          children: [
            { element: 'summary', attributes: { class: 'log-row' }, children: rowChildren },
            { element: 'div', attributes: { class: 'log-detail' }, children: [yaml { data:: fields }] },
          ],
        } else {
          element: 'div',
          attributes: entryAttrs,
          children: [
            { element: 'div', attributes: { class: 'log-row' }, children: rowChildren },
          ],
        },
    };

    {
      local c = self,
      records:: error 'Logs requires records',
      colors:: defaultColors,
      timeFormat:: '2006-01-02 15:04:05.000',
      html: [
        { element: 'style', children: [style] },
        {
          element: 'div',
          attributes: { class: 'logs card' },
          children:
            if std.length(c.records) == 0 then
              [{ element: 'div', attributes: { class: 'logs-empty' }, children: ['No logs'] }]
            else
              [(logRow { record:: rec, colors:: c.colors, timeFormat:: c.timeFormat }).html for rec in c.records],
        },
      ],
    };

  function(query, timeRange)
    {
      local n = self,
      datasource:: 'default',
      type:: 'logql',
      expr:: error 'Logs requires expr',
      _paramSpecs: timeRange.paramSpecs,
      _telemetryItems:: [{ type: n.type, expr: n.expr }],
      data: query(n.datasource, n._telemetryItems, n._params.from, n._params.to),
      records: std.reverse(std.sort(
        std.get(n.data.results[0], 'records', []),
        function(rec) rec.timestamp
      )),
      _view:: {
        local hasRecords = std.length(n.records) > 0,
        local nav = timeRange.element {
          from:: n._params.from,
          to:: n._params.to,
          resultTo:: if hasRecords then n.records[0].timestamp else null,
          resultFrom:: if hasRecords then n.records[std.length(n.records) - 1].timestamp else null,
        },
        fragment: [
          timeRange.script.html,
          nav.html,
          logs { records:: n.records },
          nav.html,
        ],
        page: ui.page {
          fragment:: n._view.fragment,
          breadcrumbs:: ui.breadcrumbs { pathTemplate:: std.get(n, '_pathTemplate', []), node:: n },
        },
        html: html.manifestHtml(self.page),
      },
    };
local nodesDashboardLib =
  local a =
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
    } + charts;

  function(query, timeRange)
    local collectItems(node) =
      if node.type == 'panel' then node.chart._telemetryItems
      else std.flattenArrays([collectItems(child) for child in node.children]);

    local resolveTree(node, results, index) =
      if node.type == 'panel' then
        local count = std.length(node.chart._telemetryItems);
        local resolved = node.chart { data: { results: results[index:index + count] } };
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

    a.dashboard.view {
      local n = self,
      datasource:: 'default',
      layout:: error 'Dashboard requires layout',
      _paramSpecs: timeRange.paramSpecs,
      data: query(n.datasource, collectItems(n.layout), n._params.from, n._params.to),
      tree:: resolveTree(n.layout, n.data.results, 0).node,
      _view+:: {
        local base = super.fragment,
        fragment: base { child:: [(timeRange.nav { from:: n._params.from, to:: n._params.to }).html, base.child] },
      },
    };

local query = queryLib(time, telemetry);
local browse = browseLib(query);
local chartLib = nodesChartLib(query, timeRange);
local logsLib = nodesLogsLib(query, timeRange);

{
  promql: {
    chart: { base: chartLib.base },
    line: { chart: $.promql.chart.base + chartLib.line },
    stateTimeline: { chart: $.promql.chart.base + chartLib.stateTimeline },
    drilldown: { nodeList: nodeListsDrilldownLib(chain) },
    entity: { nodeList: nodeListsEntityLib(chain, $.promql.list.node, $.promql.drilldown.nodeList, $.logs.node) },
    entities: { nodeList: nodeListsEntitiesLib($.promql.entity.nodeList) },
    list: { node: nodesListLib(browse) },
    labels: { node: nodesLabelsLib(browse) },
    values: { node: nodesValuesLib(browse) },
  },
  logs: { node: logsLib },
  telemetry: {
    dashboard: { node: nodesDashboardLib(query, timeRange) },
  },
}
