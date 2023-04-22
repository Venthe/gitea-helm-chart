# High Availability

Most components (in-memory DB, volume/asset storage, code indexer) used by Gitea are not HA-ready by default.
The following document explains how to achieve a HA-ready Gitea deployment.
Before diving into the individual components, it is important to understand the following:

- The resulting Gitea deployment will consist of ~ 10 pods (depending on the chosen components and their replicas)
- One should evaluate upfront whether a HA-deployment is required as switching between HA/non-HA comes with some effort
- If your Gitea instance is of medium to large size, a HA setup is recommended as both load handling and storage scaling can be handled in a more robust way

A general comment about chart dependencies and external services: 
Instead of relying on many Gitea-specific components bootstrapped by this helm chart, it is often better to rely on an external, (managed) instances of in-memory databases, storage providers, etc..
Many cloud providers offer such services, at least for databases or in-memory databases.
They might cost a bit more than using a self-hosted k8s variant but are usually easier to maintain and scale, if needed.
Also they can be centrally managed and are not linked to the Gitea helm chart or namespace.
Consider using external services before you start off with your Gitea HA setup.

The helm chart tries to help as much as possible to simplify the provisioning of a HA-ready Gitea instance by implementing smart conditionals if `replicaCount` is set to a value > 1.
Nevertheless, we cannot guarantee for every possible combination of dependencies to work together perfectly with different Gitea versions.
Also the HA setup is still early days and not battle-tested yet.
It is *highly recommended* to have a test environment aside on which to test possible changes/upgrades before applying these to a production installation.

## Requirements for HA

Storage-wise, the HA-Gitea setup requires a RWX file-system which can be shared among the deployment-based replica pods.
In addition, the following components are required for HA-readiness:

- A HA-ready code indexer (`elasticsearch` or `meilisearch`)
- A HA-ready external object/asset storage (`minio`) (optional, assets can also be stored on the RWX file-system)
- A HA-ready cache (`redis-cluster`)
- DB: a HA-ready DB (the built-in sqlite and postgres chart dependency will not work)

`postgres.enabled`, which default to `true`, must be set to `false` for a HA setup.
The default `postgres` chart dependency is not HA-ready (there's a dedicated `postgres-ha` chart).

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

A `redis` instance is required for the in-memory cache.
Two options exist:

- `redis`
- `redis-cluster`

The chart only provides `redis-cluster` as a dependency as this one can be used for both HA and non-HA setups.
You're also welcome to go with `redis` if you prefer or already have a running instance.

It should be noted that `redis-cluster` support is only available starting with Gitea 1.19.2.
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
While most of these can be stored on the RWX file-system, it is recommended to use an external S3-compatible object storage for such, mainly for performance reasons.

By default the chart provisions a single RWO volume to store everything (repos, avatars, packages, etc.).
This volume cannot be mounted by multiple pods.
Hence, either a RWX volume is required or an external object storage (or both: storing the repositories on the RWX volume and the rest on the external object storage).

You can use the built-in chart dependency `minio` via `minio.enabled` or configure an external `minio` instance yourself.

If you use the built-in `minio` dependency, you need to provide `gitea.config.storage.MINIO_BUCKET`, `gitea.config.storage.MINIO_LOCATION`, `gitea.config.storage.MINIO_ACCESS_KEY_ID` and `gitea.config.storage.MINIO_SECRET_ACCESS_KEY`.
If you start out with a recent `minio`, be aware that "access key" and "secret acces key" have been renamed to "rootUser" and "rootPassword", respectively.

To store packages in `minio`, you need to explicitly define `gitea.config."storage.packages".STORAGE_TYPE` as shown below.

Note that `MINIO_BUCKET` here is just a name and does not refer to a S3 bucket.
It's the root access point for all objects belonging to the respective application, i.e., to Gitea in this case.

If you use an external instance, you need to define `gitea.config.storage.MINIO_ENDPOINT` and `gitea.config.storage.MINIO_USE_SSL` additionally.

```yml
gitea:
  config:
    attachment:
      STORAGE_TYPE: minio
    lfs:
      STORAGE_TYPE: minio
    picture:
      AVATAR_STORAGE_TYPE: minio
    "storage.packages":
      STORAGE_TYPE: minio

    storage:
      MINIO_ENDPOINT: <s3 endpoint>
      MINIO_LOCATION: <location>
      MINIO_ACCESS_KEY_ID: <access key>
      MINIO_SECRET_ACCESS_KEY: <secret key>
      MINIO_BUCKET: <bucket name>
      MINIO_USE_SSL: false
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
