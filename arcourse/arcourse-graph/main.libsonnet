local url =
  local hexDigits = '0123456789ABCDEF';

  local unreserved(b) =
    (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || (b >= 48 && b <= 57)
    || b == 45 || b == 95 || b == 46 || b == 126;

  local unreservedChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~';

  local percentEncode(s) =
    if std.length(std.stripChars(s, unreservedChars)) == 0 then s
    else std.join('', [
      if unreserved(b) then std.char(b)
      else '%' + hexDigits[std.floor(b / 16)] + hexDigits[b % 16]
      for b in std.encodeUTF8(s)
    ]);

  local queryValue(value) =
    if std.isString(value) then value
    else if std.isArray(value) then std.manifestJsonMinified(value)
    else std.toString(value);

  local query(params) =
    local keys = std.objectFields(params);
    if std.length(keys) == 0 then ''
    else '?' + std.join('&', [
      percentEncode(k) + '=' + percentEncode(queryValue(params[k]))
      for k in keys
    ]);

  function(u)
    local scheme = std.get(u, 'scheme', null);
    local path = std.get(u, 'path', []);
    (if scheme != null then scheme + '://' else '')
    + std.get(u, 'host', '')
    + (if std.length(path) > 0 then '/' + std.join('/', [percentEncode(seg) for seg in path]) else '')
    + query(std.get(u, 'params', {}));

local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
local varNameOf(seg) = std.substr(seg, 1, std.length(seg) - 1);

local resolvePath(node, path) =
  std.join('.', ['root'] + [
    if isVar(p) then varNameOf(p) + '("' + node[varNameOf(p)] + '")'
    else p
    for p in path
  ]);

local urlPathSegments(node, path) =
  ['root'] + std.flatMap(
    function(p)
      if isVar(p) then [varNameOf(p), node[varNameOf(p)]]
      else [p],
    path
  );

local specDefaults(specs) = {
  [spec.name]: spec.default
  for spec in specs
  if std.objectHas(spec, 'default') && spec.default != null
};

local nonDefaultParams(node) =
  local params = node._params;
  if std.length(params) == 0 then {}
  else
    local defaults = node._defaultParams;
    {
      [k]: params[k]
      for k in std.objectFields(params)
      if !std.objectHas(defaults, k) || defaults[k] != params[k]
    };

local mergeLayers(base, layers) =
  std.foldl(function(acc, l) acc + l, layers, base);

local node(path, body={}) =
  local layers = if std.isArray(body) then body else [body];
  local vars = std.map(varNameOf, std.filter(isVar, path));
  local base = { _params:: specDefaults(std.get(self, '_paramSpecs', [])) };
  local requiredVars = { [var]: error 'variable %s is required' % var for var in vars };
  mergeLayers(if std.length(vars) == 0 then base else requiredVars + base, layers) +
  {
    _node: true,
    _vars:: vars,
    _pathTemplate:: path,
    _defaultParams:: super._params,
    _evalPath:: resolvePath(self, path),
    _queryPath:: local n = self; url({ path: urlPathSegments(n, path), params: nonDefaultParams(n) }),
  };

local toLayers(nodeSpecs) =
  std.flatMap(
    function(spec)
      local bodies = std.slice(spec, 1, null, 1);
      local effective = if std.length(bodies) == 0 then [{}] else bodies;
      [{ path: spec[0], fullPath: spec[0], layer: b } for b in effective],
    nodeSpecs,
  );

local shape(layers) =
  local build(ls) =
    local firstSegments(ls) =
      std.set([l.path[0] for l in ls if std.length(l.path) > 0], function(k) k);
    {
      leafs: [l.index for l in ls if std.length(l.path) == 0],
      children: {
        [k]: build([
          l { path: std.slice(l.path, 1, null, 1) }
          for l in ls
          if std.length(l.path) > 0 && l.path[0] == k
        ])
        for k in firstSegments(ls)
      },
    };
  build([{ path: layers[i].path, index: i } for i in std.range(0, std.length(layers) - 1)]);

local instantiateFromShape(shapeNode, layers, defaultView={}, vars={}) =
  local withDefaultView(obj) =
    if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
  local leafs = [layers[i] for i in shapeNode.leafs];
  local children = {
    [if isVar(k) then varNameOf(k) else k]:
      if isVar(k) then
        local vName = varNameOf(k);
        function(val) instantiateFromShape(shapeNode.children[k], layers, defaultView, vars { [vName]: val })
      else
        instantiateFromShape(shapeNode.children[k], layers, defaultView, vars)
    for k in std.objectFields(shapeNode.children)
  };
  if std.length(leafs) == 0 then withDefaultView(children)
  else withDefaultView(node(leafs[0].fullPath, [l.layer for l in leafs]) + vars + children);

local rootFromShape(layers, compiledShape, defaultView={}) =
  local withDefaultView(obj) =
    if std.objectHasAll(obj, '_view') then obj else obj + defaultView;
  withDefaultView(node([]) + instantiateFromShape(compiledShape, layers, defaultView));

local graphFromShape(nodeSpecs, compiledShape, defaultView={}) =
  rootFromShape(toLayers(nodeSpecs), compiledShape, defaultView);

local graph(nodeSpecs, defaultView={}) =
  local layers = toLayers(nodeSpecs);
  rootFromShape(layers, shape(layers), defaultView);

{
  node: node,
  graph: graph,
  toLayers: toLayers,
  shape: shape,
  graphFromShape: graphFromShape,
}
