local time = {
  now(): std.native('invoke:time')('now', []),
  addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
  parseRFC3339(value): std.native('invoke:time')('parseRFC3339', [value]),
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

  local accs(names, vars) =
    local n = std.length(names);
    local initialMatchers = [excludeMatcher(name) for name in names];
    std.foldl(
      function(acc, i)
        acc + [
          if i == 0 then { ancestorVars: [], matchers: initialMatchers } else
            local prev = acc[i - 1];
            {
              ancestorVars: prev.ancestorVars + [vars[i - 1]],
              matchers: promote(prev.matchers, i - 1, eqMatcher(names[i - 1], vars[i - 1])),
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
  local navScript = importstr 'time-range-nav.js';

  {
    paramSpecs: [
      { name: 'from', type: 'string', default: 'now-1h' },
      { name: 'to', type: 'string', default: 'now' },
    ],
    nav: {
      local c = self,
      from:: error 'nav requires from',
      to:: error 'nav requires to',
      html: [
        { element: 'time-range-nav', attributes: { from: c.from, to: c.to } },
        { element: 'script', children: [{ html: navScript }] },
      ],
    },
  };

local query = (import 'query.libsonnet')(time, telemetry);
local browse = (import 'browse.libsonnet')(query);

{
  promql: {
    chart: {
      node: (import 'nodes/chart.libsonnet')(query, timeRange),
      drillDown: { nodeList: (import 'nodeLists/drilldown.libsonnet')(chain, $.promql.chart.node) },
      entity: { nodeList: (import 'nodeLists/entity.libsonnet')(chain, $.promql.list.node, $.promql.chart.drillDown.nodeList) },
    },
    list: { node: (import 'nodes/list.libsonnet')(browse) },
    labels: { node: (import 'nodes/labels.libsonnet')(browse) },
    values: { node: (import 'nodes/values.libsonnet')(browse) },
  },
  telemetry: {
    dashboard: { node: (import 'nodes/dashboard.libsonnet')(query, timeRange) },
  },
}
