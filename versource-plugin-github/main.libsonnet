{
  adapters: {
    user(resource): resource {
      name: super.data.username,
      data: super.data {
        ssh_keys:: null,
      },
    },
    organization(resource): resource {
      name: super.data.login,
      data: super.data {
        members:: null,
        repositories:: null,
        users:: null,
      },
    },
    repository(resource): resource {
      namespace: std.split(super.data.full_name, '/')[0],
      name: std.split(super.data.full_name, '/')[1],
      data: super.data {
        repository_license:: null,
      },
    },
  },
  views: {
    repository: {
      web: |||
        SELECT
            CONCAT('github-repository-web-', uuid) as uid,
            CONCAT_WS('/', NULLIF(namespace, ''), name) as title,
            `data`->>"$.html_url" as arg
        FROM `resources`
        WHERE provider = "github"
        AND resource_type = "repository"
        LIMIT 1000
      |||,
    },
  },
}
