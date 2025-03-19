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

local providerTemplate(provider, requirements, configuration) = {
  local providerRequirements = { ['terraform.required_providers.%s' % [provider]]: requirements },
  local providerAlias = if configuration == null then null else configuration.alias,
  local providerRef = if configuration == null then null else '%s.%s' % [provider, providerAlias],
  local providerConfiguration = if configuration == null then {} else { [providerRef]: { provider: { [provider]: configuration } } },
  local providerRefBlock = if configuration == null then {} else { provider: providerRef },
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
              [name]: std.prune(metaBlock + block + providerRefBlock),
            },
          },
        },
        blocks: build.blocks(rawBlock) + providerRequirements + providerConfiguration + {
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
      blocks: build.blocks(parameters) + providerRequirements + providerConfiguration,
    },
  },
};

local provider(configuration) = {
  local requirements = {
    source: 'registry.terraform.io/kreuzwerker/docker',
    version: '3.0.2',
  },
  local provider = providerTemplate('docker', requirements, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    config(name, block): {
      local resource = blockType.resource('docker_config', name),
      _: resource._(block, {
        data: build.template(block.data),
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
      }),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
    },
    container(name, block): {
      local resource = blockType.resource('docker_container', name),
      _: resource._(block, {
        attach: build.template(std.get(block, 'attach', null)),
        bridge: build.template(std.get(block, 'bridge', null)),
        cgroupns_mode: build.template(std.get(block, 'cgroupns_mode', null)),
        command: build.template(std.get(block, 'command', null)),
        container_logs: build.template(std.get(block, 'container_logs', null)),
        container_read_refresh_timeout_milliseconds: build.template(std.get(block, 'container_read_refresh_timeout_milliseconds', null)),
        cpu_set: build.template(std.get(block, 'cpu_set', null)),
        cpu_shares: build.template(std.get(block, 'cpu_shares', null)),
        destroy_grace_seconds: build.template(std.get(block, 'destroy_grace_seconds', null)),
        dns: build.template(std.get(block, 'dns', null)),
        dns_opts: build.template(std.get(block, 'dns_opts', null)),
        dns_search: build.template(std.get(block, 'dns_search', null)),
        domainname: build.template(std.get(block, 'domainname', null)),
        entrypoint: build.template(std.get(block, 'entrypoint', null)),
        env: build.template(std.get(block, 'env', null)),
        exit_code: build.template(std.get(block, 'exit_code', null)),
        gpus: build.template(std.get(block, 'gpus', null)),
        group_add: build.template(std.get(block, 'group_add', null)),
        hostname: build.template(std.get(block, 'hostname', null)),
        id: build.template(std.get(block, 'id', null)),
        image: build.template(block.image),
        init: build.template(std.get(block, 'init', null)),
        ipc_mode: build.template(std.get(block, 'ipc_mode', null)),
        log_driver: build.template(std.get(block, 'log_driver', null)),
        log_opts: build.template(std.get(block, 'log_opts', null)),
        logs: build.template(std.get(block, 'logs', null)),
        max_retry_count: build.template(std.get(block, 'max_retry_count', null)),
        memory: build.template(std.get(block, 'memory', null)),
        memory_swap: build.template(std.get(block, 'memory_swap', null)),
        must_run: build.template(std.get(block, 'must_run', null)),
        name: build.template(block.name),
        network_data: build.template(std.get(block, 'network_data', null)),
        network_mode: build.template(std.get(block, 'network_mode', null)),
        pid_mode: build.template(std.get(block, 'pid_mode', null)),
        privileged: build.template(std.get(block, 'privileged', null)),
        publish_all_ports: build.template(std.get(block, 'publish_all_ports', null)),
        read_only: build.template(std.get(block, 'read_only', null)),
        remove_volumes: build.template(std.get(block, 'remove_volumes', null)),
        restart: build.template(std.get(block, 'restart', null)),
        rm: build.template(std.get(block, 'rm', null)),
        runtime: build.template(std.get(block, 'runtime', null)),
        security_opts: build.template(std.get(block, 'security_opts', null)),
        shm_size: build.template(std.get(block, 'shm_size', null)),
        start: build.template(std.get(block, 'start', null)),
        stdin_open: build.template(std.get(block, 'stdin_open', null)),
        stop_signal: build.template(std.get(block, 'stop_signal', null)),
        stop_timeout: build.template(std.get(block, 'stop_timeout', null)),
        storage_opts: build.template(std.get(block, 'storage_opts', null)),
        sysctls: build.template(std.get(block, 'sysctls', null)),
        tmpfs: build.template(std.get(block, 'tmpfs', null)),
        tty: build.template(std.get(block, 'tty', null)),
        user: build.template(std.get(block, 'user', null)),
        userns_mode: build.template(std.get(block, 'userns_mode', null)),
        wait: build.template(std.get(block, 'wait', null)),
        wait_timeout: build.template(std.get(block, 'wait_timeout', null)),
        working_dir: build.template(std.get(block, 'working_dir', null)),
      }),
      attach: resource.field(self._.blocks, 'attach'),
      bridge: resource.field(self._.blocks, 'bridge'),
      cgroupns_mode: resource.field(self._.blocks, 'cgroupns_mode'),
      command: resource.field(self._.blocks, 'command'),
      container_logs: resource.field(self._.blocks, 'container_logs'),
      container_read_refresh_timeout_milliseconds: resource.field(self._.blocks, 'container_read_refresh_timeout_milliseconds'),
      cpu_set: resource.field(self._.blocks, 'cpu_set'),
      cpu_shares: resource.field(self._.blocks, 'cpu_shares'),
      destroy_grace_seconds: resource.field(self._.blocks, 'destroy_grace_seconds'),
      dns: resource.field(self._.blocks, 'dns'),
      dns_opts: resource.field(self._.blocks, 'dns_opts'),
      dns_search: resource.field(self._.blocks, 'dns_search'),
      domainname: resource.field(self._.blocks, 'domainname'),
      entrypoint: resource.field(self._.blocks, 'entrypoint'),
      env: resource.field(self._.blocks, 'env'),
      exit_code: resource.field(self._.blocks, 'exit_code'),
      gpus: resource.field(self._.blocks, 'gpus'),
      group_add: resource.field(self._.blocks, 'group_add'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      image: resource.field(self._.blocks, 'image'),
      init: resource.field(self._.blocks, 'init'),
      ipc_mode: resource.field(self._.blocks, 'ipc_mode'),
      log_driver: resource.field(self._.blocks, 'log_driver'),
      log_opts: resource.field(self._.blocks, 'log_opts'),
      logs: resource.field(self._.blocks, 'logs'),
      max_retry_count: resource.field(self._.blocks, 'max_retry_count'),
      memory: resource.field(self._.blocks, 'memory'),
      memory_swap: resource.field(self._.blocks, 'memory_swap'),
      must_run: resource.field(self._.blocks, 'must_run'),
      name: resource.field(self._.blocks, 'name'),
      network_data: resource.field(self._.blocks, 'network_data'),
      network_mode: resource.field(self._.blocks, 'network_mode'),
      pid_mode: resource.field(self._.blocks, 'pid_mode'),
      privileged: resource.field(self._.blocks, 'privileged'),
      publish_all_ports: resource.field(self._.blocks, 'publish_all_ports'),
      read_only: resource.field(self._.blocks, 'read_only'),
      remove_volumes: resource.field(self._.blocks, 'remove_volumes'),
      restart: resource.field(self._.blocks, 'restart'),
      rm: resource.field(self._.blocks, 'rm'),
      runtime: resource.field(self._.blocks, 'runtime'),
      security_opts: resource.field(self._.blocks, 'security_opts'),
      shm_size: resource.field(self._.blocks, 'shm_size'),
      start: resource.field(self._.blocks, 'start'),
      stdin_open: resource.field(self._.blocks, 'stdin_open'),
      stop_signal: resource.field(self._.blocks, 'stop_signal'),
      stop_timeout: resource.field(self._.blocks, 'stop_timeout'),
      storage_opts: resource.field(self._.blocks, 'storage_opts'),
      sysctls: resource.field(self._.blocks, 'sysctls'),
      tmpfs: resource.field(self._.blocks, 'tmpfs'),
      tty: resource.field(self._.blocks, 'tty'),
      user: resource.field(self._.blocks, 'user'),
      userns_mode: resource.field(self._.blocks, 'userns_mode'),
      wait: resource.field(self._.blocks, 'wait'),
      wait_timeout: resource.field(self._.blocks, 'wait_timeout'),
      working_dir: resource.field(self._.blocks, 'working_dir'),
    },
    image(name, block): {
      local resource = blockType.resource('docker_image', name),
      _: resource._(block, {
        force_remove: build.template(std.get(block, 'force_remove', null)),
        id: build.template(std.get(block, 'id', null)),
        image_id: build.template(std.get(block, 'image_id', null)),
        keep_locally: build.template(std.get(block, 'keep_locally', null)),
        name: build.template(block.name),
        platform: build.template(std.get(block, 'platform', null)),
        pull_triggers: build.template(std.get(block, 'pull_triggers', null)),
        repo_digest: build.template(std.get(block, 'repo_digest', null)),
        triggers: build.template(std.get(block, 'triggers', null)),
      }),
      force_remove: resource.field(self._.blocks, 'force_remove'),
      id: resource.field(self._.blocks, 'id'),
      image_id: resource.field(self._.blocks, 'image_id'),
      keep_locally: resource.field(self._.blocks, 'keep_locally'),
      name: resource.field(self._.blocks, 'name'),
      platform: resource.field(self._.blocks, 'platform'),
      pull_triggers: resource.field(self._.blocks, 'pull_triggers'),
      repo_digest: resource.field(self._.blocks, 'repo_digest'),
      triggers: resource.field(self._.blocks, 'triggers'),
    },
    network(name, block): {
      local resource = blockType.resource('docker_network', name),
      _: resource._(block, {
        attachable: build.template(std.get(block, 'attachable', null)),
        check_duplicate: build.template(std.get(block, 'check_duplicate', null)),
        driver: build.template(std.get(block, 'driver', null)),
        id: build.template(std.get(block, 'id', null)),
        ingress: build.template(std.get(block, 'ingress', null)),
        internal: build.template(std.get(block, 'internal', null)),
        ipam_driver: build.template(std.get(block, 'ipam_driver', null)),
        ipam_options: build.template(std.get(block, 'ipam_options', null)),
        ipv6: build.template(std.get(block, 'ipv6', null)),
        name: build.template(block.name),
        options: build.template(std.get(block, 'options', null)),
        scope: build.template(std.get(block, 'scope', null)),
      }),
      attachable: resource.field(self._.blocks, 'attachable'),
      check_duplicate: resource.field(self._.blocks, 'check_duplicate'),
      driver: resource.field(self._.blocks, 'driver'),
      id: resource.field(self._.blocks, 'id'),
      ingress: resource.field(self._.blocks, 'ingress'),
      internal: resource.field(self._.blocks, 'internal'),
      ipam_driver: resource.field(self._.blocks, 'ipam_driver'),
      ipam_options: resource.field(self._.blocks, 'ipam_options'),
      ipv6: resource.field(self._.blocks, 'ipv6'),
      name: resource.field(self._.blocks, 'name'),
      options: resource.field(self._.blocks, 'options'),
      scope: resource.field(self._.blocks, 'scope'),
    },
    plugin(name, block): {
      local resource = blockType.resource('docker_plugin', name),
      _: resource._(block, {
        alias: build.template(std.get(block, 'alias', null)),
        enable_timeout: build.template(std.get(block, 'enable_timeout', null)),
        enabled: build.template(std.get(block, 'enabled', null)),
        env: build.template(std.get(block, 'env', null)),
        force_destroy: build.template(std.get(block, 'force_destroy', null)),
        force_disable: build.template(std.get(block, 'force_disable', null)),
        grant_all_permissions: build.template(std.get(block, 'grant_all_permissions', null)),
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
        plugin_reference: build.template(std.get(block, 'plugin_reference', null)),
      }),
      alias: resource.field(self._.blocks, 'alias'),
      enable_timeout: resource.field(self._.blocks, 'enable_timeout'),
      enabled: resource.field(self._.blocks, 'enabled'),
      env: resource.field(self._.blocks, 'env'),
      force_destroy: resource.field(self._.blocks, 'force_destroy'),
      force_disable: resource.field(self._.blocks, 'force_disable'),
      grant_all_permissions: resource.field(self._.blocks, 'grant_all_permissions'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      plugin_reference: resource.field(self._.blocks, 'plugin_reference'),
    },
    registry_image(name, block): {
      local resource = blockType.resource('docker_registry_image', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        insecure_skip_verify: build.template(std.get(block, 'insecure_skip_verify', null)),
        keep_remotely: build.template(std.get(block, 'keep_remotely', null)),
        name: build.template(block.name),
        sha256_digest: build.template(std.get(block, 'sha256_digest', null)),
        triggers: build.template(std.get(block, 'triggers', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      insecure_skip_verify: resource.field(self._.blocks, 'insecure_skip_verify'),
      keep_remotely: resource.field(self._.blocks, 'keep_remotely'),
      name: resource.field(self._.blocks, 'name'),
      sha256_digest: resource.field(self._.blocks, 'sha256_digest'),
      triggers: resource.field(self._.blocks, 'triggers'),
    },
    secret(name, block): {
      local resource = blockType.resource('docker_secret', name),
      _: resource._(block, {
        data: build.template(block.data),
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
      }),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
    },
    service(name, block): {
      local resource = blockType.resource('docker_service', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
      }),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
    },
    tag(name, block): {
      local resource = blockType.resource('docker_tag', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        source_image: build.template(block.source_image),
        source_image_id: build.template(std.get(block, 'source_image_id', null)),
        target_image: build.template(block.target_image),
      }),
      id: resource.field(self._.blocks, 'id'),
      source_image: resource.field(self._.blocks, 'source_image'),
      source_image_id: resource.field(self._.blocks, 'source_image_id'),
      target_image: resource.field(self._.blocks, 'target_image'),
    },
    volume(name, block): {
      local resource = blockType.resource('docker_volume', name),
      _: resource._(block, {
        driver: build.template(std.get(block, 'driver', null)),
        driver_opts: build.template(std.get(block, 'driver_opts', null)),
        id: build.template(std.get(block, 'id', null)),
        mountpoint: build.template(std.get(block, 'mountpoint', null)),
        name: build.template(std.get(block, 'name', null)),
      }),
      driver: resource.field(self._.blocks, 'driver'),
      driver_opts: resource.field(self._.blocks, 'driver_opts'),
      id: resource.field(self._.blocks, 'id'),
      mountpoint: resource.field(self._.blocks, 'mountpoint'),
      name: resource.field(self._.blocks, 'name'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    image(name, block): {
      local resource = blockType.resource('docker_image', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        name: build.template(block.name),
        repo_digest: build.template(std.get(block, 'repo_digest', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      repo_digest: resource.field(self._.blocks, 'repo_digest'),
    },
    logs(name, block): {
      local resource = blockType.resource('docker_logs', name),
      _: resource._(block, {
        details: build.template(std.get(block, 'details', null)),
        discard_headers: build.template(std.get(block, 'discard_headers', null)),
        follow: build.template(std.get(block, 'follow', null)),
        id: build.template(std.get(block, 'id', null)),
        logs_list_string: build.template(std.get(block, 'logs_list_string', null)),
        logs_list_string_enabled: build.template(std.get(block, 'logs_list_string_enabled', null)),
        name: build.template(block.name),
        show_stderr: build.template(std.get(block, 'show_stderr', null)),
        show_stdout: build.template(std.get(block, 'show_stdout', null)),
        since: build.template(std.get(block, 'since', null)),
        tail: build.template(std.get(block, 'tail', null)),
        timestamps: build.template(std.get(block, 'timestamps', null)),
        until: build.template(std.get(block, 'until', null)),
      }),
      details: resource.field(self._.blocks, 'details'),
      discard_headers: resource.field(self._.blocks, 'discard_headers'),
      follow: resource.field(self._.blocks, 'follow'),
      id: resource.field(self._.blocks, 'id'),
      logs_list_string: resource.field(self._.blocks, 'logs_list_string'),
      logs_list_string_enabled: resource.field(self._.blocks, 'logs_list_string_enabled'),
      name: resource.field(self._.blocks, 'name'),
      show_stderr: resource.field(self._.blocks, 'show_stderr'),
      show_stdout: resource.field(self._.blocks, 'show_stdout'),
      since: resource.field(self._.blocks, 'since'),
      tail: resource.field(self._.blocks, 'tail'),
      timestamps: resource.field(self._.blocks, 'timestamps'),
      until: resource.field(self._.blocks, 'until'),
    },
    network(name, block): {
      local resource = blockType.resource('docker_network', name),
      _: resource._(block, {
        driver: build.template(std.get(block, 'driver', null)),
        id: build.template(std.get(block, 'id', null)),
        internal: build.template(std.get(block, 'internal', null)),
        ipam_config: build.template(std.get(block, 'ipam_config', null)),
        name: build.template(block.name),
        options: build.template(std.get(block, 'options', null)),
        scope: build.template(std.get(block, 'scope', null)),
      }),
      driver: resource.field(self._.blocks, 'driver'),
      id: resource.field(self._.blocks, 'id'),
      internal: resource.field(self._.blocks, 'internal'),
      ipam_config: resource.field(self._.blocks, 'ipam_config'),
      name: resource.field(self._.blocks, 'name'),
      options: resource.field(self._.blocks, 'options'),
      scope: resource.field(self._.blocks, 'scope'),
    },
    plugin(name, block): {
      local resource = blockType.resource('docker_plugin', name),
      _: resource._(block, {
        alias: build.template(std.get(block, 'alias', null)),
        enabled: build.template(std.get(block, 'enabled', null)),
        env: build.template(std.get(block, 'env', null)),
        grant_all_permissions: build.template(std.get(block, 'grant_all_permissions', null)),
        id: build.template(std.get(block, 'id', null)),
        name: build.template(std.get(block, 'name', null)),
        plugin_reference: build.template(std.get(block, 'plugin_reference', null)),
      }),
      alias: resource.field(self._.blocks, 'alias'),
      enabled: resource.field(self._.blocks, 'enabled'),
      env: resource.field(self._.blocks, 'env'),
      grant_all_permissions: resource.field(self._.blocks, 'grant_all_permissions'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      plugin_reference: resource.field(self._.blocks, 'plugin_reference'),
    },
    registry_image(name, block): {
      local resource = blockType.resource('docker_registry_image', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        insecure_skip_verify: build.template(std.get(block, 'insecure_skip_verify', null)),
        name: build.template(block.name),
        sha256_digest: build.template(std.get(block, 'sha256_digest', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      insecure_skip_verify: resource.field(self._.blocks, 'insecure_skip_verify'),
      name: resource.field(self._.blocks, 'name'),
      sha256_digest: resource.field(self._.blocks, 'sha256_digest'),
    },
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
    ca_material: build.template(std.get(block, 'ca_material', null)),
    cert_material: build.template(std.get(block, 'cert_material', null)),
    cert_path: build.template(std.get(block, 'cert_path', null)),
    host: build.template(std.get(block, 'host', null)),
    key_material: build.template(std.get(block, 'key_material', null)),
    ssh_opts: build.template(std.get(block, 'ssh_opts', null)),
  })),
};

providerWithConfiguration
