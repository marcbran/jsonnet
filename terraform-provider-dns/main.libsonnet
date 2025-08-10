local build = {
  expression(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then val._.ref
        else '"%s"' % [val._.str]
      else '{%s}' % [std.join(',', std.map(function(key) '%s:%s' % [self.expression(key), self.expression(val[key])], std.objectFields(val)))]
    else if std.type(val) == 'array' then '[%s]' % [std.join(',', std.map(function(element) self.expression(element), val))]
    else if std.type(val) == 'string' then '"%s"' % [val]
    else '"%s"' % [val],
  template(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then std.strReplace(self.string(val), '\n', '\\n')
        else val._.str
      else std.mapWithKey(function(key, value) self.template(value), val)
    else if std.type(val) == 'array' then std.map(function(element) self.template(element), val)
    else if std.type(val) == 'string' then std.strReplace(self.string(val), '\n', '\\n')
    else val,
  string(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then '${%s}' % [val._.ref]
        else val._.str
      else '${%s}' % [self.expression(val)]
    else if std.type(val) == 'array' then '${%s}' % [self.expression(val)]
    else if std.type(val) == 'string' then val
    else val,
  blocks(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'blocks')
        then val._.blocks
        else
          if std.objectHas(val._, 'block')
          then { [val._.ref]: val._.block }
          else {}
      else std.foldl(
        function(acc, val) std.mergePatch(acc, val),
        std.map(function(key) build.blocks(val[key]), std.objectFields(val)),
        {}
      )
    else
      if std.type(val) == 'array' then std.foldl(
        function(acc, val) std.mergePatch(acc, val),
        std.map(function(element) build.blocks(element), val),
        {}
      )
      else {},
};
local providerTemplate(provider, requirements, rawConfiguration, configuration) = {
  local providerRequirements = { ['terraform.required_providers.%s' % [provider]]: requirements },
  local providerAlias = if configuration == null then null else std.get(configuration, 'alias', null),
  local providerConfiguration = if configuration == null then { _: { refBlock: {}, blocks: [] } } else {
    _: {
      local _ = self,
      ref: '%s.%s' % [provider, configuration.alias],
      refBlock: {
        provider: _.ref,
      },
      block: {
        provider: {
          provider: std.prune(configuration),
        },
      },
      blocks: build.blocks(rawConfiguration) + {
        [_.ref]: _.block,
      },
    },
  },
  blockType(blockType): {
    local blockTypePath = if blockType == 'resource' then [] else ['data'],
    resource(type, name): {
      local resourceType = std.substr(type, std.length(provider) + 1, std.length(type)),
      local resourcePath = blockTypePath + [type, name],
      _(rawBlock, block): {
        local _ = self,
        local metaBlock = {
          depends_on: build.template(std.get(rawBlock, 'depends_on', null)),
          count: build.template(std.get(rawBlock, 'count', null)),
          for_each: build.template(std.get(rawBlock, 'for_each', null)),
        },
        type: if std.objectHas(rawBlock, 'for_each') then 'map' else if std.objectHas(rawBlock, 'count') then 'list' else 'object',
        provider: provider,
        providerAlias: providerAlias,
        resourceType: resourceType,
        name: name,
        ref: std.join('.', resourcePath),
        block: {
          [blockType]: {
            [type]: {
              [name]: std.prune(providerConfiguration._.refBlock + metaBlock + block),
            },
          },
        },
        blocks: build.blocks([providerConfiguration] + [rawBlock]) + providerRequirements + { [_.ref]: _.block },
      },
      field(blocks, fieldName): {
        local fieldPath = resourcePath + [fieldName],
        _: {
          ref: std.join('.', fieldPath),
          blocks: blocks,
        },
      },
    },
  },
  func(name, parameters=[]): {
    local parameterString = std.join(', ', [build.expression(parameter) for parameter in parameters]),
    _: {
      ref: 'provider::%s::%s(%s)' % [provider, name, parameterString],
      blocks: build.blocks([providerConfiguration] + [parameters]) + providerRequirements,
    },
  },
};
local provider(rawConfiguration, configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/dns',
    version: '3.4.3',
  },
  local provider = providerTemplate('dns', requirements, rawConfiguration, configuration),
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
      addresses: resource.field(self._.blocks, 'addresses'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone: resource.field(self._.blocks, 'zone'),
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
      addresses: resource.field(self._.blocks, 'addresses'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone: resource.field(self._.blocks, 'zone'),
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
      cname: resource.field(self._.blocks, 'cname'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone: resource.field(self._.blocks, 'zone'),
    },
    mx_record_set(name, block): {
      local resource = blockType.resource('dns_mx_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(std.get(block, 'name', null)),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone: resource.field(self._.blocks, 'zone'),
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
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      nameservers: resource.field(self._.blocks, 'nameservers'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone: resource.field(self._.blocks, 'zone'),
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
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ptr: resource.field(self._.blocks, 'ptr'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone: resource.field(self._.blocks, 'zone'),
    },
    srv_record_set(name, block): {
      local resource = blockType.resource('dns_srv_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
        ttl: build.template(std.get(block, 'ttl', null)),
        zone: build.template(block.zone),
      }),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone: resource.field(self._.blocks, 'zone'),
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
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ttl: resource.field(self._.blocks, 'ttl'),
      txt: resource.field(self._.blocks, 'txt'),
      zone: resource.field(self._.blocks, 'zone'),
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
      addrs: resource.field(self._.blocks, 'addrs'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
    },
    aaaa_record_set(name, block): {
      local resource = blockType.resource('dns_aaaa_record_set', name),
      _: resource._(block, {
        addrs: build.template(std.get(block, 'addrs', null)),
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
      }),
      addrs: resource.field(self._.blocks, 'addrs'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
    },
    cname_record_set(name, block): {
      local resource = blockType.resource('dns_cname_record_set', name),
      _: resource._(block, {
        cname: build.template(std.get(block, 'cname', null)),
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
      }),
      cname: resource.field(self._.blocks, 'cname'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
    },
    mx_record_set(name, block): {
      local resource = blockType.resource('dns_mx_record_set', name),
      _: resource._(block, {
        domain: build.template(block.domain),
        id: build.template(std.get(block, 'id', null)),
        mx: build.template(std.get(block, 'mx', null)),
      }),
      domain: resource.field(self._.blocks, 'domain'),
      id: resource.field(self._.blocks, 'id'),
      mx: resource.field(self._.blocks, 'mx'),
    },
    ns_record_set(name, block): {
      local resource = blockType.resource('dns_ns_record_set', name),
      _: resource._(block, {
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
        nameservers: build.template(std.get(block, 'nameservers', null)),
      }),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      nameservers: resource.field(self._.blocks, 'nameservers'),
    },
    ptr_record_set(name, block): {
      local resource = blockType.resource('dns_ptr_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        ip_address: build.template(block.ip_address),
        ptr: build.template(std.get(block, 'ptr', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      ip_address: resource.field(self._.blocks, 'ip_address'),
      ptr: resource.field(self._.blocks, 'ptr'),
    },
    srv_record_set(name, block): {
      local resource = blockType.resource('dns_srv_record_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        service: build.template(block.service),
        srv: build.template(std.get(block, 'srv', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      service: resource.field(self._.blocks, 'service'),
      srv: resource.field(self._.blocks, 'srv'),
    },
    txt_record_set(name, block): {
      local resource = blockType.resource('dns_txt_record_set', name),
      _: resource._(block, {
        host: build.template(block.host),
        id: build.template(std.get(block, 'id', null)),
        record: build.template(std.get(block, 'record', null)),
        records: build.template(std.get(block, 'records', null)),
      }),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      record: resource.field(self._.blocks, 'record'),
      records: resource.field(self._.blocks, 'records'),
    },
  },
};
local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
  }),
};
providerWithConfiguration
