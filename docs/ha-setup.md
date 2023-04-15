# High Availability

Most components (in-memory DB, volume/asset storage, code indexer) used by Gitea are not HA-ready by default.
The following document explains how to achieve a HA-ready Gitea deployment.
Before diving into the individual components, it is important to understand the following:

- The resulting Gitea deployment will consist of ~ 10 pods (depending on the chosen components and their replicas)
- One should evaluate upfront whether a HA-deployment is required as switching between HA/non-HA comes with some effort
- If your Gitea instance is of medium to large size, a HA setup is recommended as both load handling and storage scaling can be handled in a more robust way

The helm chart tries to help as much as possible by implementing smart conditionals if `replicaCount` is set to a value > 1.
Nevertheless, we cannot guarantee for every possible combination of dependencies to work together perfectly with different Gitea versions.
Also the HA setup is still early days and not battle-tested yet.
It is *highly recommended* to have a test environment aside on which to test possible changes/upgrades before applying these to a production installation.

## Requirements for HA

Storage-wise, the HA-Gitea setup requires a RWX file-system which can be shared among the deployment-based replica pods.
In addition, the following components are required for HA-readiness:

- A HA-ready code indexer (`elasticsearch` or `meilisearch`)
- A HA-ready external object/asset storage (`minio`) (optional, assets can also be stored on the RWX file-system)
- A HA-ready memcache (`redis` or `redis-cluster`)
- DB: a HA-ready DB (the built-in sqlite and postgres chart dependency will not work)

Settings `memcached.enabled` and `postgres.enabled`, which default to `true`, must be set to `false` for a HA setup.
The default `postgres` chart dependency is not HA-ready (there's a dedicated `postgres-ha` chart) and the built-in `memcached` dependency cannot work with connection requests from multiple replicas.

The following sections discuss each of the components in more detail.
Note that for each component discussed, the shown configurations only provides a (working) starting point, not necessarily the most optimal setup.
We try to optimize this document over time as we have gained more experience with HA setups from users.

## Indexers (Issues and code/repo)

The default code indexer `bleve` is not able to allow multiple connections and hence cannot be used in a HA setup.
Alternatives are `elasticsearch` and `meilisearch` (as of >= 1.20).
Unless you have an existing `elasticsearch` cluster, we recommend using `meilisearch` as it is faster and requires way less resources.

Unfortunately, `meilisearch` does only support the `ISSUE_INDEXER` and not the `REPO_INDEXER` yet.
This means that the `REPO_INDEXER` must still be disabled for a HA setup right now.
An alternative to the two options above for the `ISSUE_INDEXER` is `"db"`, however we recommend to just go with `meilisearch` in this case and to not bother the DB with indexing.

Once you set `meilisearch.enabled`, the chart will automatically configure the `ISSUE_INDEXER` to use `meilisearch` for you and also disable the `REPO_INDEXER` unless you manually set it to `"elasticsearch"`.

When enabling `meilisearch`, make sure to also enable `persistence` using a RWX file-system.

## In-memory cache

The built-in `memcached` dependency can itself run in HA yet it does not work when getting requests from multiple Gitea replicas.
Hence, a `redis` instance is required for the in-memory cache.
Two options exist:

- `redis`
- `redis-cluster`

It is up to you which one to choose and there are many comparisons out there which can help you decide.
Both support HA for themselves and work well with Gitea.
It should be noted that `redis-cluster` support is only available starting with Gitea 1.20.
You can also configure an external (managed) `redis` instance to be used.
To do so, you need to set the following configuration values yourself:

- `gitea.config.queue.TYPE`: redis`
- `gitea.config.queue.CONN_STR`: `<your redis connection string>`

- `gitea.config.session.PROVIDER`: `redis`
- `gitea.config.session.PROVIDER_CONFIG`: `<your redis connection string>`

- `gitea.config.cache.ENABLED`: `true`
- `gitea.config.cache.ADAPTER`: `redis`
- `gitea.config.cache.HOST`: `<your redis connection string>`

## Object and asset storage

Object/asset storage refers to the storage of attachments, avatars, LFS files, etc.
While most of these can be stored on the RWX file-system, it is recommended to use an external object storage for these if you plan to use the "Packages" feature and upload docker images or similar.
Otherwise, these would go to your RWX file-system and would quickly fill it up and/or incur high costs.

Apps like [`minio`](https://min.io/), which support HA, can be used for object storage.
You can use the built-in chart dependency via `minio.enabled` or configure an external `minio` instance.
If you use an external instance, make sure to configure all required settings as documented in the [Gitea documentation](https://docs.gitea.io/en-us/config-cheat-sheet/#issue-and-pull-request-attachments-attachment):

```yml
gitea:
  config:
    attachment:
      STORAGE_TYPE: minio
    lfs:
      STORAGE_TYPE: minio
    picture:
      AVATAR_STORAGE_TYPE: minio

    storage:
      MINIO_ENDPOINT: <s3 endpoint>
      MINIO_LOCATION: <location>
      MINIO_ACCESS_KEY_ID: <access key>
      MINIO_BUCKET: <bucket name>
      MINIO_USE_SSL: true
```

## Database

If you do not have an HA-ready DB, using a managed database service in the cloud might be the easiest and most robust solution.
Remember: disable the built-in `postgres` dependency and configure the database connection manually via `gitea.config.database`:

```yml
gitea:
  database:
    builtIn:
      postgresql:
        enabled: false
  config:
    database:
      DB_TYPE: postgres
      HOST: <host>
      NAME: <name>
      USER: <user>
```

## Known issues

Currently Cron jobs are run on all replicas as no leader election is implemented.
See [https://github.com/go-gitea/gitea/issues/13791](https://github.com/go-gitea/gitea/issues/13791) for a discussion and possible solution.
