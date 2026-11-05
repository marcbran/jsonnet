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
      call(ctx, method, params) = std.native('invoke:gcp')('call', [ctx, 'compute', method, params]);

local referenced = gcp.referenced {
  referenceService:: 'compute',
  referenceServicePath:: 'compute/v1/',
  referenceRoutes:: [
    { route: ['global', 'addresses', '$address'], template: ['global', 'addresses', '{address}'] },
    { route: ['global', 'firewalls', '$firewall'], template: ['global', 'firewalls', '{firewall}'] },
    { route: ['global', 'images', '$image'], template: ['global', 'images', '{image}'] },
    { route: ['global', 'networks', '$network'], template: ['global', 'networks', '{network}'] },
    { route: ['global', 'snapshots', '$snapshot'], template: ['global', 'snapshots', '{snapshot}'] },
    { route: ['regions', '$region'], template: ['regions', '{region}'] },
    { route: ['regions', '$region', 'addresses', '$address'], template: ['regions', '{region}', 'addresses', '{address}'] },
    { route: ['regions', '$region', 'resourcePolicies', '$resourcePolicy'], template: ['regions', '{region}', 'resourcePolicies', '{resourcePolicy}'] },
    { route: ['regions', '$region', 'subnetworks', '$subnetwork'], template: ['regions', '{region}', 'subnetworks', '{subnetwork}'] },
    { route: ['zones', '$zone'], template: ['zones', '{zone}'] },
    { route: ['zones', '$zone', 'disks', '$disk'], template: ['zones', '{zone}', 'disks', '{disk}'] },
    { route: ['zones', '$zone', 'instances', '$instance'], template: ['zones', '{zone}', 'instances', '{instance}'] },
    { route: ['zones', '$zone', 'machineTypes', '$machineType'], template: ['zones', '{zone}', 'machineTypes', '{machineType}'] },
  ],
};

[
  [['gcp', '$project'], {
    links+: {
      'Compute Engine': root.gcp.project($.project).compute,
    },
  }],
  [['gcp', '$project', 'compute']],
  [['gcp', '$project', 'compute', 'addresses'], a.table.node + gcp.project + gcp.paginated + gcp.aggregated + {
    itemsKey:: 'addresses',
    response:: call(
      self.ctx,
      'compute.addresses.aggregatedList',
      self.page {
        filter: std.get($._params, 'filter', null),
        includeAllScopes: std.get($._params, 'includeAllScopes', null),
        orderBy: std.get($._params, 'orderBy', null),
        serviceProjectNumber: std.get($._params, 'serviceProjectNumber', null),
      }
    ),
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: '_region', label: 'Region', path: ['_region'], priority: 'secondary' },
        { key: 'address', kind: 'text', label: 'IP address', path: ['address'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'addressType', kind: 'text', label: 'Type', path: ['addressType'], priority: 'tertiary' },
        { key: 'purpose', kind: 'text', label: 'Purpose', path: ['purpose'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['_scope'] }, { path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'regions' }, { param: 'region', path: ['_region'] }, { const: 'addresses' }, { param: 'address', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'includeAllScopes', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
      { default: null, name: 'serviceProjectNumber', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'disks'], a.table.node + gcp.project + gcp.paginated + gcp.aggregated + {
    itemsKey:: 'disks',
    response:: call(
      self.ctx,
      'compute.disks.aggregatedList',
      self.page {
        filter: std.get($._params, 'filter', null),
        includeAllScopes: std.get($._params, 'includeAllScopes', null),
        orderBy: std.get($._params, 'orderBy', null),
        serviceProjectNumber: std.get($._params, 'serviceProjectNumber', null),
      }
    ),
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: '_zone', label: 'Zone', path: ['_zone'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'sizeGb', kind: 'number', label: 'Size (GB)', path: ['sizeGb'], priority: 'secondary' },
        { key: 'type', kind: 'text', label: 'Type', path: ['type'], priority: 'secondary', value:: gcp.ref(['type']) },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['_scope'] }, { path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'zones' }, { param: 'zone', path: ['_zone'] }, { const: 'disks' }, { param: 'disk', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'includeAllScopes', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
      { default: null, name: 'serviceProjectNumber', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'global']],
  [['gcp', '$project', 'compute', 'global', 'addresses'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.globalAddresses.list',
      self.page {
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'address', kind: 'identifier', label: 'IP address', path: ['address'], priority: 'secondary' },
        { key: 'addressType', kind: 'text', label: 'Type', path: ['addressType'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'purpose', kind: 'text', label: 'Purpose', path: ['purpose'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'global' }, { const: 'addresses' }, { param: 'address', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'global', 'addresses', '$address'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.globalAddresses.get',
      {
        address: $.address,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'global', 'firewalls'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.firewalls.list',
      self.page {
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'direction', kind: 'text', label: 'Direction', path: ['direction'], priority: 'secondary' },
        { key: 'priority', kind: 'number', label: 'Priority', path: ['priority'], priority: 'secondary' },
        { key: 'disabled', kind: 'boolean', label: 'Disabled', path: ['disabled'], priority: 'secondary' },
        { key: 'network', kind: 'text', label: 'Network', path: ['network'], priority: 'tertiary', value:: gcp.ref(['network']) },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'global' }, { const: 'firewalls' }, { param: 'firewall', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'global', 'firewalls', '$firewall'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.firewalls.get',
      {
        firewall: $.firewall,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'global', 'images'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.images.list',
      self.page {
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'family', kind: 'text', label: 'Family', path: ['family'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'architecture', kind: 'text', label: 'Architecture', path: ['architecture'], priority: 'secondary' },
        { key: 'diskSizeGb', kind: 'number', label: 'Disk size (GB)', path: ['diskSizeGb'], priority: 'tertiary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'global' }, { const: 'images' }, { param: 'image', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'global', 'images', '$image'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.images.get',
      {
        image: $.image,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'global', 'networks'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.networks.list',
      self.page {
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'IPv4Range', kind: 'text', label: 'IPv4 range', path: ['IPv4Range'], priority: 'secondary' },
        { key: 'autoCreateSubnetworks', kind: 'boolean', label: 'Auto subnetworks', path: ['autoCreateSubnetworks'], priority: 'secondary' },
        { key: 'routingMode', kind: 'text', label: 'Routing mode', path: ['routingConfig', 'routingMode'], priority: 'secondary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'global' }, { const: 'networks' }, { param: 'network', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'global', 'networks', '$network'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.networks.get',
      {
        network: $.network,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'global', 'snapshots'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.snapshots.list',
      self.page {
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'secondary' },
        { key: 'diskSizeGb', kind: 'number', label: 'Disk Size (GB)', path: ['diskSizeGb'], priority: 'secondary' },
        { key: 'storageBytes', kind: 'count', label: 'Storage (bytes)', path: ['storageBytes'], priority: 'tertiary' },
        { key: 'snapshotType', kind: 'text', label: 'Type', path: ['snapshotType'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'global' }, { const: 'snapshots' }, { param: 'snapshot', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'global', 'snapshots', '$snapshot'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.snapshots.get',
      {
        snapshot: $.snapshot,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'instances'], a.table.node + gcp.project + gcp.paginated + gcp.aggregated + {
    itemsKey:: 'instances',
    response:: call(
      self.ctx,
      'compute.instances.aggregatedList',
      self.page {
        filter: std.get($._params, 'filter', null),
        includeAllScopes: std.get($._params, 'includeAllScopes', null),
        orderBy: std.get($._params, 'orderBy', null),
        serviceProjectNumber: std.get($._params, 'serviceProjectNumber', null),
      }
    ),
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: '_zone', label: 'Zone', path: ['_zone'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'machineType', kind: 'text', label: 'Machine type', path: ['machineType'], priority: 'secondary', value:: gcp.ref(['machineType']) },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['_scope'] }, { path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'zones' }, { param: 'zone', path: ['_zone'] }, { const: 'instances' }, { param: 'instance', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'includeAllScopes', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
      { default: null, name: 'serviceProjectNumber', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'machineTypes'], a.table.node + gcp.project + gcp.paginated + gcp.aggregated + {
    itemsKey:: 'machineTypes',
    response:: call(
      self.ctx,
      'compute.machineTypes.aggregatedList',
      self.page {
        filter: std.get($._params, 'filter', null),
        includeAllScopes: std.get($._params, 'includeAllScopes', null),
        orderBy: std.get($._params, 'orderBy', null),
        serviceProjectNumber: std.get($._params, 'serviceProjectNumber', null),
      }
    ),
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: '_zone', label: 'Zone', path: ['_zone'], priority: 'secondary' },
        { key: 'guestCpus', kind: 'count', label: 'vCPUs', path: ['guestCpus'], priority: 'secondary' },
        { key: 'memoryMb', kind: 'number', label: 'Memory (MB)', path: ['memoryMb'], priority: 'secondary' },
        { key: 'architecture', kind: 'text', label: 'Architecture', path: ['architecture'], priority: 'secondary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['_scope'] }, { path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'zones' }, { param: 'zone', path: ['_zone'] }, { const: 'machineTypes' }, { param: 'machineType', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'includeAllScopes', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
      { default: null, name: 'serviceProjectNumber', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'regions'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.regions.list',
      self.page {
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Region', path: ['name'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'secondary' },
        { key: 'deprecatedState', kind: 'status', label: 'Deprecation', path: ['deprecated', 'state'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'regions' }, { param: 'region', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'regions', '$region'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.regions.get',
      {
        region: $.region,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'regions', '$region', 'addresses'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.addresses.list',
      self.page {
        region: $.region,
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'address', kind: 'text', label: 'IP address', path: ['address'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'addressType', kind: 'text', label: 'Type', path: ['addressType'], priority: 'tertiary' },
        { key: 'purpose', kind: 'text', label: 'Purpose', path: ['purpose'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'regions' }, { origin: 'region' }, { const: 'addresses' }, { param: 'address', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'regions', '$region', 'addresses', '$address'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.addresses.get',
      {
        region: $.region,
        address: $.address,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'regions', '$region', 'resourcePolicies'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.resourcePolicies.list',
      self.page {
        region: $.region,
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'regions' }, { origin: 'region' }, { const: 'resourcePolicies' }, { param: 'resourcePolicy', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'regions', '$region', 'resourcePolicies', '$resourcePolicy'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.resourcePolicies.get',
      {
        region: $.region,
        resourcePolicy: $.resourcePolicy,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'regions', '$region', 'subnetworks'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.subnetworks.list',
      self.page {
        region: $.region,
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
        views: std.get($._params, 'views', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'ipCidrRange', kind: 'text', label: 'IPv4 range', path: ['ipCidrRange'], priority: 'secondary' },
        { key: 'network', kind: 'identifier', label: 'Network', path: ['network'], priority: 'secondary', value:: gcp.ref(['network']) },
        { key: 'purpose', kind: 'text', label: 'Purpose', path: ['purpose'], priority: 'tertiary' },
        { key: 'state', kind: 'status', label: 'State', path: ['state'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'regions' }, { origin: 'region' }, { const: 'subnetworks' }, { param: 'subnetwork', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
      { default: null, name: 'views', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'regions', '$region', 'subnetworks', '$subnetwork'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.subnetworks.get',
      {
        region: $.region,
        subnetwork: $.subnetwork,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'resourcePolicies'], a.table.node + gcp.project + gcp.paginated + gcp.aggregated + {
    itemsKey:: 'resourcePolicies',
    response:: call(
      self.ctx,
      'compute.resourcePolicies.aggregatedList',
      self.page {
        filter: std.get($._params, 'filter', null),
        includeAllScopes: std.get($._params, 'includeAllScopes', null),
        orderBy: std.get($._params, 'orderBy', null),
        serviceProjectNumber: std.get($._params, 'serviceProjectNumber', null),
      }
    ),
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: '_region', label: 'Region', path: ['_region'], priority: 'secondary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['_scope'] }, { path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'regions' }, { param: 'region', path: ['_region'] }, { const: 'resourcePolicies' }, { param: 'resourcePolicy', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'includeAllScopes', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
      { default: null, name: 'serviceProjectNumber', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'subnetworks'], a.table.node + gcp.project + gcp.paginated + gcp.aggregated + {
    itemsKey:: 'subnetworks',
    response:: call(
      self.ctx,
      'compute.subnetworks.aggregatedList',
      self.page {
        filter: std.get($._params, 'filter', null),
        includeAllScopes: std.get($._params, 'includeAllScopes', null),
        orderBy: std.get($._params, 'orderBy', null),
        serviceProjectNumber: std.get($._params, 'serviceProjectNumber', null),
        views: std.get($._params, 'views', null),
      }
    ),
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: '_region', label: 'Region', path: ['_region'], priority: 'secondary' },
        { key: 'ipCidrRange', kind: 'text', label: 'IPv4 range', path: ['ipCidrRange'], priority: 'secondary' },
        { key: 'network', kind: 'identifier', label: 'Network', path: ['network'], priority: 'secondary', value:: gcp.ref(['network']) },
        { key: 'purpose', kind: 'text', label: 'Purpose', path: ['purpose'], priority: 'tertiary' },
        { key: 'state', kind: 'status', label: 'State', path: ['state'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['_scope'] }, { path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'regions' }, { param: 'region', path: ['_region'] }, { const: 'subnetworks' }, { param: 'subnetwork', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'includeAllScopes', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
      { default: null, name: 'serviceProjectNumber', type: 'string' },
      { default: null, name: 'views', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'zones'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.zones.list',
      self.page {
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'region', kind: 'identifier', label: 'Region', path: ['region'], priority: 'secondary', value:: gcp.ref(['region']) },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'tertiary' },
        { key: 'supportsPzs', kind: 'boolean', label: 'Supports PZS', path: ['supportsPzs'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'zones' }, { param: 'zone', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'zones', '$zone'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.zones.get',
      {
        zone: $.zone,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'zones', '$zone', 'disks'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.disks.list',
      self.page {
        zone: $.zone,
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'sizeGb', kind: 'number', label: 'Size (GB)', path: ['sizeGb'], priority: 'secondary' },
        { key: 'type', kind: 'text', label: 'Type', path: ['type'], priority: 'secondary', value:: gcp.ref(['type']) },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'zones' }, { origin: 'zone' }, { const: 'disks' }, { param: 'disk', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'zones', '$zone', 'disks', '$disk'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.disks.get',
      {
        zone: $.zone,
        disk: $.disk,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'zones', '$zone', 'instances'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.instances.list',
      self.page {
        zone: $.zone,
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'status', kind: 'status', label: 'Status', path: ['status'], priority: 'secondary' },
        { key: 'machineType', kind: 'text', label: 'Machine type', path: ['machineType'], priority: 'secondary', value:: gcp.ref(['machineType']) },
        { key: 'creationTimestamp', kind: 'timestamp', label: 'Created', path: ['creationTimestamp'], priority: 'tertiary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'zones' }, { origin: 'zone' }, { const: 'instances' }, { param: 'instance', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'zones', '$zone', 'instances', '$instance'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.instances.get',
      {
        zone: $.zone,
        instance: $.instance,
      }
    ),
    data: self.response,
  }],
  [['gcp', '$project', 'compute', 'zones', '$zone', 'machineTypes'], a.table.node + gcp.project + gcp.paginated + {
    response:: call(
      self.ctx,
      'compute.machineTypes.list',
      self.page {
        zone: $.zone,
        filter: std.get($._params, 'filter', null),
        orderBy: std.get($._params, 'orderBy', null),
      }
    ),
    data:: self.response,
    table:: {
      at: ['items'],
      columns: [
        { key: 'name', kind: 'name', label: 'Name', path: ['name'], priority: 'primary' },
        { key: 'guestCpus', kind: 'count', label: 'vCPUs', path: ['guestCpus'], priority: 'secondary' },
        { key: 'memoryMb', kind: 'number', label: 'Memory (MB)', path: ['memoryMb'], priority: 'secondary' },
        { key: 'architecture', kind: 'text', label: 'Architecture', path: ['architecture'], priority: 'secondary' },
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['name'] }],
        value: [{ const: 'gcp' }, { origin: 'project' }, { const: 'compute' }, { const: 'zones' }, { origin: 'zone' }, { const: 'machineTypes' }, { param: 'machineType', path: ['name'] }],
      },
    ],
    _paramSpecs+: [
      { default: null, name: 'filter', type: 'string' },
      { default: null, name: 'orderBy', type: 'string' },
    ],
  }],
  [['gcp', '$project', 'compute', 'zones', '$zone', 'machineTypes', '$machineType'], a.resource.node + gcp.project + referenced + {
    response:: call(
      self.ctx,
      'compute.machineTypes.get',
      {
        zone: $.zone,
        machineType: $.machineType,
      }
    ),
    data: self.response,
  }],
]
