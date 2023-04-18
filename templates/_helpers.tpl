{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "gitea.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gitea.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gitea.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create image name and tag used by the deployment.
*/}}
{{- define "gitea.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry -}}
{{- $name := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- $rootless := ternary "-rootless" "" (.Values.image.rootless) -}}
{{- if $registry -}}
  {{- printf "%s/%s:%s%s" $registry $name $tag $rootless -}}
{{- else -}}
  {{- printf "%s:%s%s" $name $tag $rootless -}}
{{- end -}}
{{- end -}}

{{/*
Docker Image Registry Secret Names evaluating values as templates
*/}}
{{- define "gitea.images.pullSecrets" -}}
{{- $pullSecrets := .Values.imagePullSecrets -}}
{{- range .Values.global.imagePullSecrets -}}
    {{- $pullSecrets = append $pullSecrets (dict "name" .) -}}
{{- end -}}
{{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
{{ toYaml $pullSecrets }}
{{- end }}
{{- end -}}


{{/*
Storage Class
*/}}
{{- define "gitea.persistence.storageClass" -}}
{{- $storageClass := .Values.global.storageClass | default .Values.persistence.storageClass }}
{{- if $storageClass }}
storageClassName: {{ $storageClass | quote }}
{{- end }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "gitea.labels" -}}
helm.sh/chart: {{ include "gitea.chart" . }}
app: {{ include "gitea.name" . }}
{{ include "gitea.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "gitea.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gitea.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "postgresql.dns" -}}
{{- printf "%s-postgresql.%s.svc.%s:%g" .Release.Name .Release.Namespace .Values.clusterDomain .Values.postgresql.global.postgresql.service.ports.postgresql -}}
{{- end -}}

{{- define "meilisearch.dns" -}}
{{- printf "http://%s-meilisearch.%s.svc.%s:%g" .Release.Name .Release.Namespace .Values.clusterDomain .Values.meilisearch.service.port | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "minio.dns" -}}
{{- printf "%s-minio-headless.%s.svc.%s:%g" .Release.Name .Release.Namespace .Values.clusterDomain .Values.minio.service.ports.api -}}
{{- end -}}

{{- define "redis.dns" -}}
{{- if .Values.redis.enabled -}}
{{- printf "redis://:%s@%s-redis-master.%s.svc.%s:%g/0?pool_size=100&idle_timeout=180s" .Values.redis.global.redis.password .Release.Name .Release.Namespace .Values.clusterDomain .Values.redis.master.service.ports.redis -}}
{{- else if (index .Values "redis-cluster").enabled -}}
{{- printf "redis+cluster://:%s@%s-redis-cluster-headless.%s.svc.%s:%g/0?pool_size=100&idle_timeout=180s&" (index .Values "redis-cluster").global.redis.password .Release.Name .Release.Namespace .Values.clusterDomain (index .Values "redis-cluster").service.ports.redis -}}
{{- end -}}
{{- end -}}

{{- define "redis.port" -}}
{{- if .Values.redis.enabled -}}
{{ .Values.redis.master.service.ports.redis }}
{{- else if (index .Values "redis-cluster").enabled -}}
{{ (index .Values "redis-cluster").service.ports.redis }}
{{- end -}}
{{- end -}}

{{- define "redis.servicename" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis-master.%s.svc.%s" .Release.Name .Release.Namespace .Values.clusterDomain -}}
{{- else if (index .Values "redis-cluster").enabled -}}
{{- printf "%s-redis-cluster-headless.%s.svc.%s" .Release.Name .Release.Namespace .Values.clusterDomain -}}
{{- end -}}
{{- end -}}

{{- define "gitea.default_domain" -}}
{{- printf "%s-gitea.%s.svc.%s" (include "gitea.fullname" .) .Release.Namespace .Values.clusterDomain | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "gitea.ldap_settings" -}}
{{- $idx := index . 0 }}
{{- $values := index . 1 }}

{{- if not (hasKey $values "bindDn") -}}
{{- $_ := set $values "bindDn" "" -}}
{{- end -}}

{{- if not (hasKey $values "bindPassword") -}}
{{- $_ := set $values "bindPassword" "" -}}
{{- end -}}

{{- $flags := list "notActive" "skipTlsVerify" "allowDeactivateAll" "synchronizeUsers" "attributesInBind" -}}
{{- range $key, $val := $values -}}
{{- if and (ne $key "enabled") (ne $key "existingSecret") -}}
{{- if eq $key "bindDn" -}}
{{- printf "--%s \"${GITEA_LDAP_BIND_DN_%d}\" " ($key | kebabcase) ($idx) -}}
{{- else if eq $key "bindPassword" -}}
{{- printf "--%s \"${GITEA_LDAP_PASSWORD_%d}\" " ($key | kebabcase) ($idx) -}}
{{- else if eq $key "port" -}}
{{- printf "--%s %d " $key ($val | int) -}}
{{- else if has $key $flags -}}
{{- printf "--%s " ($key | kebabcase) -}}
{{- else -}}
{{- printf "--%s %s " ($key | kebabcase) ($val | squote) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "gitea.oauth_settings" -}}
{{- $idx := index . 0 }}
{{- $values := index . 1 }}

{{- if not (hasKey $values "key") -}}
{{- $_ := set $values "key" (printf "${GITEA_OAUTH_KEY_%d}" $idx) -}}
{{- end -}}

{{- if not (hasKey $values "secret") -}}
{{- $_ := set $values "secret" (printf "${GITEA_OAUTH_SECRET_%d}" $idx) -}}
{{- end -}}

{{- range $key, $val := $values -}}
{{- if ne $key "existingSecret" -}}
{{- printf "--%s %s " ($key | kebabcase) ($val | quote) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "gitea.public_protocol" -}}
{{- if and .Values.ingress.enabled (gt (len .Values.ingress.tls) 0) -}}
https
{{- else -}}
{{ .Values.gitea.config.server.PROTOCOL }}
{{- end -}}
{{- end -}}

{{- define "gitea.inline_configuration" -}}
  {{- include "gitea.inline_configuration.init" . -}}
  {{- include "gitea.inline_configuration.defaults" . -}}

  {{- $generals := list -}}
  {{- $inlines := dict -}}

  {{- range $key, $value := .Values.gitea.config  }}
    {{- if kindIs "map" $value }}
      {{- if gt (len $value) 0 }}
        {{- $section := default list (get $inlines $key) -}}
        {{- range $n_key, $n_value := $value }}
          {{- $section = append $section (printf "%s=%v" $n_key $n_value) -}}
        {{- end }}
        {{- $_ := set $inlines $key (join "\n" $section) -}}
      {{- end -}}
    {{- else }}
      {{- if or (eq $key "APP_NAME") (eq $key "RUN_USER") (eq $key "RUN_MODE") -}}
        {{- $generals = append $generals (printf "%s=%s" $key $value) -}}
      {{- else -}}
        {{- (printf "Key %s cannot be on top level of configuration" $key) | fail -}}
      {{- end -}}
    {{- end }}
  {{- end }}

  {{- $_ := set $inlines "_generals_" (join "\n" $generals) -}}
  {{- toYaml $inlines -}}
{{- end -}}

{{- define "gitea.inline_configuration.init" -}}
  {{- if not (hasKey .Values.gitea.config "cache") -}}
    {{- $_ := set .Values.gitea.config "cache" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "server") -}}
    {{- $_ := set .Values.gitea.config "server" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "metrics") -}}
    {{- $_ := set .Values.gitea.config "metrics" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "database") -}}
    {{- $_ := set .Values.gitea.config "database" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "security") -}}
    {{- $_ := set .Values.gitea.config "security" dict -}}
  {{- end -}}
  {{- if not .Values.gitea.config.repository -}}
    {{- $_ := set .Values.gitea.config "repository" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "oauth2") -}}
    {{- $_ := set .Values.gitea.config "oauth2" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "session") -}}
    {{- $_ := set .Values.gitea.config "session" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "queue") -}}
    {{- $_ := set .Values.gitea.config "queue" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "queue.issue_indexer") -}}
    {{- $_ := set .Values.gitea.config "queue.issue_indexer" dict -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config "indexer") -}}
    {{- $_ := set .Values.gitea.config "indexer" dict -}}
  {{- end -}}
{{- end -}}

{{- define "gitea.inline_configuration.defaults" -}}
  {{- include "gitea.inline_configuration.defaults.server" . -}}
  {{- include "gitea.inline_configuration.defaults.database" . -}}

  {{- if not .Values.gitea.config.repository.ROOT -}}
    {{- $_ := set .Values.gitea.config.repository "ROOT" "/data/git/gitea-repositories" -}}
  {{- end -}}
  {{- if not .Values.gitea.config.security.INSTALL_LOCK -}}
    {{- $_ := set .Values.gitea.config.security "INSTALL_LOCK" "true" -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config.metrics "ENABLED") -}}
    {{- $_ := set .Values.gitea.config.metrics "ENABLED" .Values.gitea.metrics.enabled -}}
  {{- end -}}
 {{- if or .Values.redis.enabled (index .Values "redis-cluster").enabled -}}
    {{- $_ := set .Values.gitea.config.cache "ENABLED" "true" -}}
    {{- $_ := set .Values.gitea.config.cache "ADAPTER" "redis" -}}
    {{- if not (.Values.gitea.config.cache.HOST) -}}
      {{- $_ := set .Values.gitea.config.cache "HOST" (include "redis.dns" .) -}}
    {{- end -}}
  {{- end -}}
  {{- /* redis queue */ -}}
  {{- if or (index .Values "redis-cluster").enabled .Values.redis.enabled -}}
    {{- $_ := set .Values.gitea.config.queue "TYPE" "redis" -}}
    {{- $_ := set .Values.gitea.config.queue "CONN_STR" (include "redis.dns" .) -}}
  {{- end -}}
  {{- /* multiple replicas */ -}}
  {{- if gt .Values.replicaCount 1.0 -}}
    {{- if not (get .Values.gitea.config.session "PROVIDER") -}}
    {{- $_ := set .Values.gitea.config.session "PROVIDER" "redis" -}}
    {{- end -}}
    {{- if not (get .Values.gitea.config.session "PROVIDER_CONFIG") -}}
    {{- $_ := set .Values.gitea.config.session "PROVIDER_CONFIG" (include "redis.dns" .) -}}
    {{- end -}}
    {{- if (ne (get .Values.gitea.config.indexer "REPO_INDEXER_TYPE") "elasticsearch") -}}
      {{- $_ := set .Values.gitea.config.indexer "REPO_INDEXER_ENABLED" "false" -}}
    {{- end -}}
  {{- if and (not (get .Values.gitea.config.indexer "ISSUE_INDEXER_TYPE")) (not .Values.meilisearch.enabled) -}}
   {{- $_ := set .Values.gitea.config.indexer "ISSUE_INDEXER_TYPE" "db" -}}
  {{- else if and (not (get .Values.gitea.config.indexer "ISSUE_INDEXER_TYPE")) (.Values.meilisearch.enabled) -}}
   {{- $_ := set .Values.gitea.config.indexer "ISSUE_INDEXER_TYPE" "meilisearch" -}}
  {{- end -}}
  {{- if and (not (get .Values.gitea.config.indexer "ISSUE_INDEXER_CONN_STR")) (eq (get .Values.gitea.config.indexer "ISSUE_INDEXER_TYPE") "meilisearch") -}}
    {{- $_ := set .Values.gitea.config.indexer "ISSUE_INDEXER_CONN_STR" (include "meilisearch.dns" .) -}}
  {{- end -}}
  {{- if .Values.gitea.config.attachment -}}
    {{- if and (not .Values.gitea.config.attachment.STORAGE_TYPE) ( .Values.minio.enabled) -}}
      {{- $_ := set .Values.gitea.config.attachment "STORAGE_TYPE" "minio" -}}
    {{- end -}}
  {{- end -}}
  {{- if .Values.gitea.config.lfs -}}
    {{- if and (not (hasKey .Values.gitea.config.lfs "STORAGE_TYPE")) ( .Values.minio.enabled) -}}
      {{- $_ := set .Values.gitea.config.lfs "STORAGE_TYPE" "minio" -}}
    {{- end -}}
  {{- end -}}
  {{- if .Values.gitea.config.picture -}}
    {{- if and (not (hasKey .Values.gitea.config.picture "AVATAR_STORAGE_TYPE")) ( .Values.minio.enabled) -}}
      {{- $_ := set .Values.gitea.config.picture "AVATAR_STORAGE_TYPE" "minio" -}}
    {{- end -}}
  {{- end -}}
  {{- if .Values.gitea.config.storage -}}
    {{- if and (not (hasKey .Values.gitea.config.storage "MINIO_ENDPOINT")) ( .Values.minio.enabled) -}}
      {{- $_ := set .Values.gitea.config.storage "MINIO_ENDPOINT" (include "minio.dns" .) -}}
    {{- end -}}
  {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "gitea.inline_configuration.defaults.server" -}}
  {{- if not (hasKey .Values.gitea.config.server "HTTP_PORT") -}}
    {{- $_ := set .Values.gitea.config.server "HTTP_PORT" .Values.service.http.port -}}
  {{- end -}}
  {{- if not .Values.gitea.config.server.PROTOCOL -}}
    {{- $_ := set .Values.gitea.config.server "PROTOCOL" "http" -}}
  {{- end -}}
  {{- if not (.Values.gitea.config.server.DOMAIN) -}}
    {{- if gt (len .Values.ingress.hosts) 0 -}}
      {{- $_ := set .Values.gitea.config.server "DOMAIN" (index .Values.ingress.hosts 0).host -}}
    {{- else -}}
      {{- $_ := set .Values.gitea.config.server "DOMAIN" (include "gitea.default_domain" .) -}}
    {{- end -}}
  {{- end -}}
  {{- if not .Values.gitea.config.server.ROOT_URL -}}
    {{- $_ := set .Values.gitea.config.server "ROOT_URL" (printf "%s://%s" (include "gitea.public_protocol" .) .Values.gitea.config.server.DOMAIN) -}}
  {{- end -}}
  {{- if not .Values.gitea.config.server.SSH_DOMAIN -}}
    {{- $_ := set .Values.gitea.config.server "SSH_DOMAIN" .Values.gitea.config.server.DOMAIN -}}
  {{- end -}}
  {{- if not .Values.gitea.config.server.SSH_PORT -}}
    {{- $_ := set .Values.gitea.config.server "SSH_PORT" .Values.service.ssh.port -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config.server "SSH_LISTEN_PORT") -}}
    {{- if not .Values.image.rootless -}}
      {{- $_ := set .Values.gitea.config.server "SSH_LISTEN_PORT" .Values.gitea.config.server.SSH_PORT -}}
    {{- else -}}
      {{- $_ := set .Values.gitea.config.server "SSH_LISTEN_PORT" "2222" -}}
    {{- end -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config.server "START_SSH_SERVER") -}}
    {{- if .Values.image.rootless -}}
      {{- $_ := set .Values.gitea.config.server "START_SSH_SERVER" "true" -}}
    {{- end -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config.server "APP_DATA_PATH") -}}
    {{- $_ := set .Values.gitea.config.server "APP_DATA_PATH" "/data" -}}
  {{- end -}}
  {{- if not (hasKey .Values.gitea.config.server "ENABLE_PPROF") -}}
    {{- $_ := set .Values.gitea.config.server "ENABLE_PPROF" false -}}
  {{- end -}}
{{- end -}}

{{- define "gitea.inline_configuration.defaults.database" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- $_ := set .Values.gitea.config.database "DB_TYPE"   "postgres" -}}
    {{- if not (.Values.gitea.config.database.HOST) -}}
      {{- $_ := set .Values.gitea.config.database "HOST"      (include "postgresql.dns" .) -}}
    {{- end -}}
    {{- $_ := set .Values.gitea.config.database "NAME"      .Values.postgresql.global.postgresql.auth.database -}}
    {{- $_ := set .Values.gitea.config.database "USER"      .Values.postgresql.global.postgresql.auth.username -}}
    {{- $_ := set .Values.gitea.config.database "PASSWD"    .Values.postgresql.global.postgresql.auth.password -}}
  {{- end -}}
{{- end -}}

{{- define "gitea.init-additional-mounts" -}}
  {{- /* Honor the deprecated extraVolumeMounts variable when defined */ -}}
  {{- if gt (len .Values.extraInitVolumeMounts) 0 -}}
    {{- toYaml .Values.extraInitVolumeMounts -}}
  {{- else if gt (len .Values.extraVolumeMounts) 0 -}}
    {{- toYaml .Values.extraVolumeMounts -}}
  {{- end -}}
{{- end -}}

{{- define "gitea.container-additional-mounts" -}}
  {{- /* Honor the deprecated extraVolumeMounts variable when defined */ -}}
  {{- if gt (len .Values.extraContainerVolumeMounts) 0 -}}
    {{- toYaml .Values.extraContainerVolumeMounts -}}
  {{- else if gt (len .Values.extraVolumeMounts) 0 -}}
    {{- toYaml .Values.extraVolumeMounts -}}
  {{- end -}}
{{- end -}}

{{- define "gitea.gpg-key-secret-name" -}}
{{ default (printf "%s-gpg-key" (include "gitea.fullname" .)) .Values.signing.existingSecret }}
{{- end -}}
