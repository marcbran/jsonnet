local a = import 'arcourse-ui/main.libsonnet',
      gcp =
  local root = import 'root';

  local project = {
    ctx:: { project: $.project },
  };

  local paginated = {
    inputToken:: 'pageToken',
    outputToken:: 'nextPageToken',
    pageSize:: 'maxResults',
    _paramSpecs+: [
      { name: name, type: if name == $.pageSize then 'number' else 'string', default: null }
      for name in [$.pageSize, $.inputToken]
    ],
    page:: {
      [name]: std.get($._params, name, null)
      for name in [$.pageSize, $.inputToken]
    },
    links+: {
      pagination:
        local params = std.get($, '_params', {});
        local next = std.get($.response, $.outputToken, null);
        (if std.get(params, $.inputToken, null) == null then {} else { first: $ { _params: params { [$.inputToken]: null } } })
        + (if next == null then {} else { next: $ { _params: params { [$.inputToken]: next } } }),
    },
  };

  local scopeFields(scope) =
    local parts = std.split(scope, '/');
    if std.length(parts) != 2 then { _scope: scope }
    else { _scope: parts[1], ['_' + std.rstripChars(parts[0], 's')]: parts[1] };

  local aggregated = {
    itemsKey:: error 'aggregated requires an itemsKey',
    response:: error 'aggregated requires a response',
    data:: {
      local scopes = std.get($.response, 'items', {}),
      items: [
        item + scopeFields(scope)
        for scope in std.objectFields(scopes)
        for item in std.get(scopes[scope], $.itemsKey, [])
      ],
    },
  };

  local ref(path) = function(item)
    local value = std.foldl(function(acc, key) if std.type(acc) == 'object' then std.get(acc, key, null) else null, path, item);
    if std.type(value) == 'string' && std.startsWith(value, 'https://') then
      local segments = std.split(value, '/');
      segments[std.length(segments) - 1]
    else value;

  local referenceFieldsSkipped = ['selfLink', 'selfLinkWithId'];

  local urlStrings(value, path) =
    if std.type(value) == 'string' then
      if std.startsWith(value, 'https://') then [{ path: path, url: value }] else []
    else if std.type(value) == 'array' then
      std.flattenArrays([urlStrings(value[i], path + [std.toString(i)]) for i in std.range(0, std.length(value) - 1)])
    else if std.type(value) == 'object' then
      std.flattenArrays([
        urlStrings(value[k], path + [k])
        for k in std.objectFields(value)
        if !std.member(referenceFieldsSkipped, k)
      ])
    else [];

  local isTemplateVar(seg) = std.startsWith(seg, '{') && std.endsWith(seg, '}');

  local matchTemplate(template, segments) =
    if std.length(template) != std.length(segments) then null
    else std.foldl(
      function(acc, i)
        if acc == null then null
        else if isTemplateVar(template[i]) then acc { [std.substr(template[i], 1, std.length(template[i]) - 2)]: segments[i] }
        else if template[i] == segments[i] then acc
        else null,
      std.range(0, std.length(template) - 1),
      {}
    );

  local referencedNode(service, routes, project, rest) =
    local matches = [
      { route: r.route, vars: vars }
      for r in routes
      for vars in [matchTemplate(r.template, rest)]
      if vars != null
    ];
    if std.length(matches) == 0 then null
    else std.foldl(
      function(acc, seg)
        if std.startsWith(seg, '$') then acc[seg[1:]](matches[0].vars[seg[1:]])
        else acc[seg],
      matches[0].route,
      root.gcp.project(project)[service]
    );

  local resolveReference(service, servicePath, routes, project, url) =
    local marker = '/' + servicePath;
    local found = std.findSubstr(marker, url);
    if std.length(found) == 0 then null
    else
      local start = found[0] + std.length(marker);
      local segments = std.split(std.substr(url, start, std.length(url) - start), '/');
      if std.length(segments) >= 2 && segments[0] == 'projects' then referencedNode(service, routes, segments[1], segments[2:])
      else referencedNode(service, routes, project, segments);

  local referenced = {
    referenceService:: error 'referenced requires a referenceService',
    referenceServicePath:: error 'referenced requires a referenceServicePath',
    referenceRoutes:: [],
    links+: {
      [std.join('/', ref.path)]: node
      for ref in urlStrings(std.get($, 'data', null), [])
      for node in [resolveReference($.referenceService, $.referenceServicePath, $.referenceRoutes, $.project, ref.url)]
      if node != null
    },
  };

  {
    project: project,
    paginated: paginated,
    aggregated: aggregated,
    ref: ref,
    referenced: referenced,
  },
      root = import 'root',
      call(ctx, method, params) = std.native('invoke:gcp')('call', [ctx, 'storage', method, params]);

local referenced = gcp.referenced {
  referenceService:: 'storage',
  referenceServicePath:: 'storage/v1/',
  referenceRoutes:: [
    { route: ['buckets', '$bucket'], template: ['b', '{bucket}'] },
    { route: ['buckets', '$bucket', 'objects', '$object'], template: ['b', '{bucket}', 'o', '{object}'] },
  ],
};

[
  [['gcp', '$project'], {
    links+: {
      'Cloud Storage': root.gcp.project($.project).storage,
    },
  }],
  [['gcp', '$project', 'storage']],
  [['gcp', '$project', 'storage', 'buckets'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'storage.buckets.list',
      self.page {
        prefix: std.get($._params, 'prefix', null),
        projection: std.get($._params, 'projection', null),
        returnPartialSuccess: std.get($._params, 'returnPartialSuccess', null),
        softDeleted: std.get($._params, 'softDeleted', null),
        userProject: std.get($._params, 'userProject', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'location', kind: 'text', label: 'Location', path: ['location'], priority: 'secondary' },
        { key: 'storageClass', kind: 'text', label: 'Storage class', path: ['storageClass'], priority: 'secondary' },
        { key: 'timeCreated', kind: 'timestamp', label: 'Created', path: ['timeCreated'], priority: 'tertiary' },
        { key: 'versioning.enabled', kind: 'boolean', label: 'Versioning', path: ['versioning', 'enabled'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'storage' }, { const: 'buckets' }, { param: 'bucket', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'prefix', type: 'string' },
      { default: null, name: 'projection', type: 'string' },
      { default: null, name: 'returnPartialSuccess', type: 'string' },
      { default: null, name: 'softDeleted', type: 'string' },
      { default: null, name: 'userProject', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'storage', 'buckets', '$bucket'], a.resource.node + gcp.project + referenced + {
    data: call(
      self.ctx,
      'storage.buckets.get',
      {
        bucket: $.bucket,
      }
    ),
  }],
  [['gcp', '$project', 'storage', 'buckets', '$bucket', 'objects'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'storage.objects.list',
      self.page {
        bucket: $.bucket,
        delimiter: std.get($._params, 'delimiter', null),
        endOffset: std.get($._params, 'endOffset', null),
        filter: std.get($._params, 'filter', null),
        includeFoldersAsPrefixes: std.get($._params, 'includeFoldersAsPrefixes', null),
        includeTrailingDelimiter: std.get($._params, 'includeTrailingDelimiter', null),
        matchGlob: std.get($._params, 'matchGlob', null),
        prefix: std.get($._params, 'prefix', null),
        projection: std.get($._params, 'projection', null),
        softDeleted: std.get($._params, 'softDeleted', null),
        startOffset: std.get($._params, 'startOffset', null),
        userProject: std.get($._params, 'userProject', null),
        versions: std.get($._params, 'versions', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'size', kind: 'number', label: 'Size', path: ['size'], priority: 'secondary' },
        { key: 'storageClass', kind: 'text', label: 'Storage class', path: ['storageClass'], priority: 'secondary' },
        { key: 'updated', kind: 'timestamp', label: 'Updated', path: ['updated'], priority: 'secondary' },
        { key: 'contentType', kind: 'text', label: 'Content type', path: ['contentType'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'storage' }, { const: 'buckets' }, { origin: 'bucket' }, { const: 'objects' }, { param: 'object', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'delimiter', type: 'string' },
      { default: null, name: 'endOffset', type: 'string' },
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'includeFoldersAsPrefixes', type: 'string' },
      { default: null, name: 'includeTrailingDelimiter', type: 'string' },
      { default: null, name: 'matchGlob', type: 'string' },
      { default: null, name: 'prefix', type: 'string' },
      { default: null, name: 'projection', type: 'string' },
      { default: null, name: 'softDeleted', type: 'string' },
      { default: null, name: 'startOffset', type: 'string' },
      { default: null, name: 'userProject', type: 'string' },
      { default: null, name: 'versions', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'storage', 'buckets', '$bucket', 'objects', '$object'], a.resource.node + gcp.project + referenced + {
    data: call(
      self.ctx,
      'storage.objects.get',
      {
        bucket: $.bucket,
        object: $.object,
      }
    ),
  }],
]
