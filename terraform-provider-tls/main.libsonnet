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
  blocks(val):
    if std.type(val) == 'object'
    then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'blocks')
        then val._.blocks
        else
          if std.objectHas(val._, 'block')
          then { [val._.ref]: val._.block }
          else {}
      else std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(key) build.blocks(val[key]), std.objectFields(val)), {})
    else if std.type(val) == 'array'
    then std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(element) build.blocks(element), val), {})
    else {},
};

local providerTemplate(provider, requirements, rawConfiguration, configuration) = {
  local providerRequirements = {
    ['terraform.required_providers.%s' % [provider]]: requirements,
  },
  local providerAlias = if configuration == null then null else std.get(configuration, 'alias', null),
  local providerConfiguration =
    if configuration == null then { _: { refBlock: {}, blocks: [] } } else {
      _: {
        local _ = self,
        ref: '%s.%s' % [provider, configuration.alias],
        refBlock: {
          provider: _.ref,
        },
        block: {
          provider: {
            [provider]: std.prune(configuration),
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
        blocks: build.blocks([providerConfiguration] + [rawBlock]) + providerRequirements + {
          [_.ref]: _.block,
        },
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
    source: 'registry.terraform.io/hashicorp/tls',
    version: '4.1.0',
  },
  local provider = providerTemplate('tls', requirements, rawConfiguration, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    cert_request(name, block): {
      local resource = blockType.resource('tls_cert_request', name),
      _: resource._(block, {
        cert_request_pem: build.template(std.get(block, 'cert_request_pem', null)),
        dns_names: build.template(std.get(block, 'dns_names', null)),
        id: build.template(std.get(block, 'id', null)),
        ip_addresses: build.template(std.get(block, 'ip_addresses', null)),
        key_algorithm: build.template(std.get(block, 'key_algorithm', null)),
        private_key_pem: build.template(block.private_key_pem),
        uris: build.template(std.get(block, 'uris', null)),
      }),
      cert_request_pem: resource.field(self._.blocks, 'cert_request_pem'),
      dns_names: resource.field(self._.blocks, 'dns_names'),
      id: resource.field(self._.blocks, 'id'),
      ip_addresses: resource.field(self._.blocks, 'ip_addresses'),
      key_algorithm: resource.field(self._.blocks, 'key_algorithm'),
      private_key_pem: resource.field(self._.blocks, 'private_key_pem'),
      uris: resource.field(self._.blocks, 'uris'),
    },
    locally_signed_cert(name, block): {
      local resource = blockType.resource('tls_locally_signed_cert', name),
      _: resource._(block, {
        allowed_uses: build.template(block.allowed_uses),
        ca_cert_pem: build.template(block.ca_cert_pem),
        ca_key_algorithm: build.template(std.get(block, 'ca_key_algorithm', null)),
        ca_private_key_pem: build.template(block.ca_private_key_pem),
        cert_pem: build.template(std.get(block, 'cert_pem', null)),
        cert_request_pem: build.template(block.cert_request_pem),
        early_renewal_hours: build.template(std.get(block, 'early_renewal_hours', null)),
        id: build.template(std.get(block, 'id', null)),
        is_ca_certificate: build.template(std.get(block, 'is_ca_certificate', null)),
        ready_for_renewal: build.template(std.get(block, 'ready_for_renewal', null)),
        set_subject_key_id: build.template(std.get(block, 'set_subject_key_id', null)),
        validity_end_time: build.template(std.get(block, 'validity_end_time', null)),
        validity_period_hours: build.template(block.validity_period_hours),
        validity_start_time: build.template(std.get(block, 'validity_start_time', null)),
      }),
      allowed_uses: resource.field(self._.blocks, 'allowed_uses'),
      ca_cert_pem: resource.field(self._.blocks, 'ca_cert_pem'),
      ca_key_algorithm: resource.field(self._.blocks, 'ca_key_algorithm'),
      ca_private_key_pem: resource.field(self._.blocks, 'ca_private_key_pem'),
      cert_pem: resource.field(self._.blocks, 'cert_pem'),
      cert_request_pem: resource.field(self._.blocks, 'cert_request_pem'),
      early_renewal_hours: resource.field(self._.blocks, 'early_renewal_hours'),
      id: resource.field(self._.blocks, 'id'),
      is_ca_certificate: resource.field(self._.blocks, 'is_ca_certificate'),
      ready_for_renewal: resource.field(self._.blocks, 'ready_for_renewal'),
      set_subject_key_id: resource.field(self._.blocks, 'set_subject_key_id'),
      validity_end_time: resource.field(self._.blocks, 'validity_end_time'),
      validity_period_hours: resource.field(self._.blocks, 'validity_period_hours'),
      validity_start_time: resource.field(self._.blocks, 'validity_start_time'),
    },
    private_key(name, block): {
      local resource = blockType.resource('tls_private_key', name),
      _: resource._(block, {
        algorithm: build.template(block.algorithm),
        ecdsa_curve: build.template(std.get(block, 'ecdsa_curve', null)),
        id: build.template(std.get(block, 'id', null)),
        private_key_openssh: build.template(std.get(block, 'private_key_openssh', null)),
        private_key_pem: build.template(std.get(block, 'private_key_pem', null)),
        private_key_pem_pkcs8: build.template(std.get(block, 'private_key_pem_pkcs8', null)),
        public_key_fingerprint_md5: build.template(std.get(block, 'public_key_fingerprint_md5', null)),
        public_key_fingerprint_sha256: build.template(std.get(block, 'public_key_fingerprint_sha256', null)),
        public_key_openssh: build.template(std.get(block, 'public_key_openssh', null)),
        public_key_pem: build.template(std.get(block, 'public_key_pem', null)),
        rsa_bits: build.template(std.get(block, 'rsa_bits', null)),
      }),
      algorithm: resource.field(self._.blocks, 'algorithm'),
      ecdsa_curve: resource.field(self._.blocks, 'ecdsa_curve'),
      id: resource.field(self._.blocks, 'id'),
      private_key_openssh: resource.field(self._.blocks, 'private_key_openssh'),
      private_key_pem: resource.field(self._.blocks, 'private_key_pem'),
      private_key_pem_pkcs8: resource.field(self._.blocks, 'private_key_pem_pkcs8'),
      public_key_fingerprint_md5: resource.field(self._.blocks, 'public_key_fingerprint_md5'),
      public_key_fingerprint_sha256: resource.field(self._.blocks, 'public_key_fingerprint_sha256'),
      public_key_openssh: resource.field(self._.blocks, 'public_key_openssh'),
      public_key_pem: resource.field(self._.blocks, 'public_key_pem'),
      rsa_bits: resource.field(self._.blocks, 'rsa_bits'),
    },
    self_signed_cert(name, block): {
      local resource = blockType.resource('tls_self_signed_cert', name),
      _: resource._(block, {
        allowed_uses: build.template(block.allowed_uses),
        cert_pem: build.template(std.get(block, 'cert_pem', null)),
        dns_names: build.template(std.get(block, 'dns_names', null)),
        early_renewal_hours: build.template(std.get(block, 'early_renewal_hours', null)),
        id: build.template(std.get(block, 'id', null)),
        ip_addresses: build.template(std.get(block, 'ip_addresses', null)),
        is_ca_certificate: build.template(std.get(block, 'is_ca_certificate', null)),
        key_algorithm: build.template(std.get(block, 'key_algorithm', null)),
        private_key_pem: build.template(block.private_key_pem),
        ready_for_renewal: build.template(std.get(block, 'ready_for_renewal', null)),
        set_authority_key_id: build.template(std.get(block, 'set_authority_key_id', null)),
        set_subject_key_id: build.template(std.get(block, 'set_subject_key_id', null)),
        uris: build.template(std.get(block, 'uris', null)),
        validity_end_time: build.template(std.get(block, 'validity_end_time', null)),
        validity_period_hours: build.template(block.validity_period_hours),
        validity_start_time: build.template(std.get(block, 'validity_start_time', null)),
      }),
      allowed_uses: resource.field(self._.blocks, 'allowed_uses'),
      cert_pem: resource.field(self._.blocks, 'cert_pem'),
      dns_names: resource.field(self._.blocks, 'dns_names'),
      early_renewal_hours: resource.field(self._.blocks, 'early_renewal_hours'),
      id: resource.field(self._.blocks, 'id'),
      ip_addresses: resource.field(self._.blocks, 'ip_addresses'),
      is_ca_certificate: resource.field(self._.blocks, 'is_ca_certificate'),
      key_algorithm: resource.field(self._.blocks, 'key_algorithm'),
      private_key_pem: resource.field(self._.blocks, 'private_key_pem'),
      ready_for_renewal: resource.field(self._.blocks, 'ready_for_renewal'),
      set_authority_key_id: resource.field(self._.blocks, 'set_authority_key_id'),
      set_subject_key_id: resource.field(self._.blocks, 'set_subject_key_id'),
      uris: resource.field(self._.blocks, 'uris'),
      validity_end_time: resource.field(self._.blocks, 'validity_end_time'),
      validity_period_hours: resource.field(self._.blocks, 'validity_period_hours'),
      validity_start_time: resource.field(self._.blocks, 'validity_start_time'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    certificate(name, block): {
      local resource = blockType.resource('tls_certificate', name),
      _: resource._(block, {
        certificates: build.template(std.get(block, 'certificates', null)),
        content: build.template(std.get(block, 'content', null)),
        id: build.template(std.get(block, 'id', null)),
        url: build.template(std.get(block, 'url', null)),
        verify_chain: build.template(std.get(block, 'verify_chain', null)),
      }),
      certificates: resource.field(self._.blocks, 'certificates'),
      content: resource.field(self._.blocks, 'content'),
      id: resource.field(self._.blocks, 'id'),
      url: resource.field(self._.blocks, 'url'),
      verify_chain: resource.field(self._.blocks, 'verify_chain'),
    },
    public_key(name, block): {
      local resource = blockType.resource('tls_public_key', name),
      _: resource._(block, {
        algorithm: build.template(std.get(block, 'algorithm', null)),
        id: build.template(std.get(block, 'id', null)),
        private_key_openssh: build.template(std.get(block, 'private_key_openssh', null)),
        private_key_pem: build.template(std.get(block, 'private_key_pem', null)),
        public_key_fingerprint_md5: build.template(std.get(block, 'public_key_fingerprint_md5', null)),
        public_key_fingerprint_sha256: build.template(std.get(block, 'public_key_fingerprint_sha256', null)),
        public_key_openssh: build.template(std.get(block, 'public_key_openssh', null)),
        public_key_pem: build.template(std.get(block, 'public_key_pem', null)),
      }),
      algorithm: resource.field(self._.blocks, 'algorithm'),
      id: resource.field(self._.blocks, 'id'),
      private_key_openssh: resource.field(self._.blocks, 'private_key_openssh'),
      private_key_pem: resource.field(self._.blocks, 'private_key_pem'),
      public_key_fingerprint_md5: resource.field(self._.blocks, 'public_key_fingerprint_md5'),
      public_key_fingerprint_sha256: resource.field(self._.blocks, 'public_key_fingerprint_sha256'),
      public_key_openssh: resource.field(self._.blocks, 'public_key_openssh'),
      public_key_pem: resource.field(self._.blocks, 'public_key_pem'),
    },
  },
};

local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
  }),
};

providerWithConfiguration
