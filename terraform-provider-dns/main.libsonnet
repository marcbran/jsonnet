local build = {
  expression(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then val._.ref
        else '"%s"' % [val._.str]
      else '{%s}' % [std.join(',', std.map(function(key) '%s:%s' % [self.expression(key), self.expression(val[key])], std.objectFields(val)))]
    else if std.type(val) == 'array' then '[%s]' % [std.join(',', std.map(function(element) self.expression(element), val))]
    else if std.type(val) == 'string' then '"%s"' % [val]
    else '"%s"' % [val],
  template(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then std.strReplace(self.string(val), '\n', '\\n')
        else val._.str
      else std.mapWithKey(function(key, value) self.template(value), val)
    else if std.type(val) == 'array' then std.map(function(element) self.template(element), val)
    else if std.type(val) == 'string' then std.strReplace(self.string(val), '\n', '\\n')
    else val,
  string(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then '${%s}' % [val._.ref]
        else val._.str
      else '${%s}' % [self.expression(val)]
    else if std.type(val) == 'array' then '${%s}' % [self.expression(val)]
    else if std.type(val) == 'string' then val
    else val,
  providerRequirements(val):
    if std.type(val) == 'object'
    then
      if std.objectHas(val, '_')
      then std.get(val._, 'providerRequirements', {})
      else std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(key) build.providerRequirements(val[key]), std.objectFields(val)), {})
    else if std.type(val) == 'array'
    then std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(element) build.providerRequirements(element), val), {})
    else {},
};

local providerTemplate(provider, requirements, configuration) = {
  local providerRequirements = { [provider]: requirements },
  local providerAlias = if configuration == null then null else configuration.alias,
  local providerWithAlias = if configuration == null then null else '%s.%s' % [provider, providerAlias],
  local providerConfiguration = if configuration == null then {} else { [providerWithAlias]: { provider: { [provider]: configuration } } },
  local providerReference = if configuration == null then {} else { provider: providerWithAlias },
  blockType(blockType): {
    local blockTypePath = if blockType == 'resource' then [] else ['data'],
    resource(type, name): {
      local resourceType = std.substr(type, std.length(provider) + 1, std.length(type)),
      local resourcePath = blockTypePath + [type, name],
      _(rawBlock, block): {
        local metaBlock = {
          depends_on: build.template(std.get(rawBlock, 'depends_on', null)),
          count: build.template(std.get(rawBlock, 'count', null)),
          for_each: build.template(std.get(rawBlock, 'for_each', null)),
        },
        type: if std.objectHas(rawBlock, 'for_each') then 'map' else if std.objectHas(rawBlock, 'count') then 'list' else 'object',
        providerRequirements: build.providerRequirements(rawBlock) + providerRequirements,
        providerConfiguration: providerConfiguration,
        provider: provider,
        providerAlias: providerAlias,
        resourceType: resourceType,
        name: name,
        ref: std.join('.', resourcePath),
        block: {
          [blockType]: {
            [type]: {
              [name]: std.prune(metaBlock + block + providerReference),
            },
          },
        },
      },
      field(fieldName): {
        local fieldPath = resourcePath + [fieldName],
        _: {
          ref: std.join('.', fieldPath),
        },
      },
    },
  },
  func(name, parameters=[]): {
    local parameterString = std.join(', ', [build.expression(parameter) for parameter in parameters]),
    _: {
      providerRequirements: build.providerRequirements(parameters) + providerRequirements,
      providerConfiguration: providerConfiguration,
      ref: 'provider::%s::%s(%s)' % [provider, name, parameterString],
    },
  },
};

local provider(configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/dns',
    version: '3.4.2',
  },
  local provider = providerTemplate('dns', requirements, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    a_record_set(name, block): {
      local resource = blockType.resource('dns_a_record_set', name),
      _: resource._(block, {
        addresses: build.template(block.addresses),
        id: build.template(std.get(block, 'id', null)),
        name: build.template(std.get(block, 'name', null)),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      addresses: resource.field('addresses'),
      id: resource.field('id'),
      name: resource.field('name'),
      ttl: resource.field('ttl'),
      zone: resource.field('zone'),
    },
    aaaa_record_set(name, block): {
      local resource = blockType.resource('dns_aaaa_record_set', name),
      _: resource._(block, {
        addresses: build.template(block.addresses),
        id: build.template(std.get(block, 'id', null)),
        name: build.template(std.get(block, 'name', null)),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      addresses: resource.field('addresses'),
      id: resource.field('id'),
      name: resource.field('name'),
      ttl: resource.field('ttl'),
      zone: resource.field('zone'),
    },
    cname_record(name, block): {
      local resource = blockType.resource('dns_cname_record', name),
      _: resource._(block, {
        cname: build.template(block.cname),
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      cname: resource.field('cname'),
      id: resource.field('id'),
      name: resource.field('name'),
      ttl: resource.field('ttl'),
      zone: resource.field('zone'),
    },
    mx_record_set(name, block): {
      local resource = blockType.resource('dns_mx_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(std.get(block, 'name', null)),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      id: resource.field('id'),
      name: resource.field('name'),
      ttl: resource.field('ttl'),
      zone: resource.field('zone'),
    },
    ns_record_set(name, block): {
      local resource = blockType.resource('dns_ns_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
        nameservers: build.template(block.nameservers),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      id: resource.field('id'),
      name: resource.field('name'),
      nameservers: resource.field('nameservers'),
      ttl: resource.field('ttl'),
      zone: resource.field('zone'),
    },
    ptr_record(name, block): {
      local resource = blockType.resource('dns_ptr_record', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(std.get(block, 'name', null)),
        ptr: build.template(block.ptr),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      id: resource.field('id'),
      name: resource.field('name'),
      ptr: resource.field('ptr'),
      ttl: resource.field('ttl'),
      zone: resource.field('zone'),
    },
    srv_record_set(name, block): {
      local resource = blockType.resource('dns_srv_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      id: resource.field('id'),
      name: resource.field('name'),
      ttl: resource.field('ttl'),
      zone: resource.field('zone'),
    },
    txt_record_set(name, block): {
      local resource = blockType.resource('dns_txt_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(std.get(block, 'name', null)),
        ttl: build.template(std.get(block, 'ttl', null)),
        txt: build.template(block.txt),
        zone: build.template(block.zone),
      }),
      id: resource.field('id'),
      name: resource.field('name'),
      ttl: resource.field('ttl'),
      txt: resource.field('txt'),
      zone: resource.field('zone'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    a_record_set(name, block): {
      local resource = blockType.resource('dns_a_record_set', name),
      _: resource._(block, {
        addrs: build.template(std.get(block, 'addrs', null)),
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
      }),
      addrs: resource.field('addrs'),
      host: resource.field('host'),
      id: resource.field('id'),
    },
    aaaa_record_set(name, block): {
      local resource = blockType.resource('dns_aaaa_record_set', name),
      _: resource._(block, {
        addrs: build.template(std.get(block, 'addrs', null)),
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
      }),
      addrs: resource.field('addrs'),
      host: resource.field('host'),
      id: resource.field('id'),
    },
    cname_record_set(name, block): {
      local resource = blockType.resource('dns_cname_record_set', name),
      _: resource._(block, {
        cname: build.template(std.get(block, 'cname', null)),
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
      }),
      cname: resource.field('cname'),
      host: resource.field('host'),
      id: resource.field('id'),
    },
    mx_record_set(name, block): {
      local resource = blockType.resource('dns_mx_record_set', name),
      _: resource._(block, {
        domain: build.template(block.domain),
        id: build.template(std.get(block, 'id', null)),
        mx: build.template(std.get(block, 'mx', null)),
      }),
      domain: resource.field('domain'),
      id: resource.field('id'),
      mx: resource.field('mx'),
    },
    ns_record_set(name, block): {
      local resource = blockType.resource('dns_ns_record_set', name),
      _: resource._(block, {
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
        nameservers: build.template(std.get(block, 'nameservers', null)),
      }),
      host: resource.field('host'),
      id: resource.field('id'),
      nameservers: resource.field('nameservers'),
    },
    ptr_record_set(name, block): {
      local resource = blockType.resource('dns_ptr_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        ip_address: build.template(block.ip_address),
        ptr: build.template(std.get(block, 'ptr', null)),
      }),
      id: resource.field('id'),
      ip_address: resource.field('ip_address'),
      ptr: resource.field('ptr'),
    },
    srv_record_set(name, block): {
      local resource = blockType.resource('dns_srv_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        service: build.template(block.service),
        srv: build.template(std.get(block, 'srv', null)),
      }),
      id: resource.field('id'),
      service: resource.field('service'),
      srv: resource.field('srv'),
    },
    txt_record_set(name, block): {
      local resource = blockType.resource('dns_txt_record_set', name),
      _: resource._(block, {
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
        record: build.template(std.get(block, 'record', null)),
        records: build.template(std.get(block, 'records', null)),
      }),
      host: resource.field('host'),
      id: resource.field('id'),
      record: resource.field('record'),
      records: resource.field('records'),
    },
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
  })),
};

providerWithConfiguration
