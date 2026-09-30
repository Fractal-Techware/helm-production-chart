# A production-shaped Helm chart for a stateless HTTP service — secure defaults, strict values schema, 38 unit tests

[![helm tests](https://github.com/Fractal-Techware/helm-production-chart/actions/workflows/test.yml/badge.svg)](https://github.com/Fractal-Techware/helm-production-chart/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Helm 3.14+ | 4.x](https://img.shields.io/badge/Helm-3.14%2B%20%7C%204.x-0f1689?logo=helm&logoColor=white)
![Kubernetes 1.32–1.37](https://img.shields.io/badge/kubernetes-1.32--1.37-326ce5?logo=kubernetes&logoColor=white)
![helm-unittest: 38](https://img.shields.io/badge/helm--unittest-38%20passing-brightgreen)

`helm create` gives you a scaffold with no security context, no values schema and no tests.
**`ftw-app` is the chart you actually want to deploy**: a Deployment, Service, ServiceAccount,
ConfigMap and optional Ingress for a stateless HTTP service, with the boring decisions already made.

- **Pod Security `restricted` by default** — non-root UID 10001, `seccompProfile: RuntimeDefault`,
  all capabilities dropped, `allowPrivilegeEscalation: false`, read-only root filesystem with a
  writable `/tmp` emptyDir, no service account token mounted
- **Startup, liveness and readiness probes**, requests plus a memory limit (no CPU limit, so you
  do not buy throttling latency), `maxUnavailable: 0`, `revisionHistoryLimit`
- **Config changes roll the pods** — the ConfigMap content hash is a pod annotation
- **Strict `values.schema.json`** — a typo'd key, a wrong type, `:latest`, a malformed digest or a
  bad `pathType` fails `helm template` / `helm install` before the cluster sees it
- **38 helm-unittest assertions** across 7 suites covering every template and every toggle
- **Optional Ingress** (`networking.k8s.io/v1`, `ingressClassName`, TLS), labels, annotations,
  node selectors, tolerations, affinity, topology spread, extra volumes and env — all schema-checked

Tested on Helm 4.0.5 and `kubeconform -strict` against the Kubernetes 1.32, 1.35 and 1.37 schemas.

By [Fractal Techware](https://store.fractaltechware.com/?utm_source=github&utm_medium=readme&utm_campaign=free-repo). MIT licensed.

## What's included

| File | What it gives you |
|---|---|
| [`charts/ftw-app/templates/deployment.yaml`](charts/ftw-app/templates/deployment.yaml) | Deployment: secure pod + container securityContext, 3 probes, resources, config checksum annotation, digest pinning, `/tmp` emptyDir, extra env/volumes |
| [`charts/ftw-app/templates/service.yaml`](charts/ftw-app/templates/service.yaml) | ClusterIP/NodePort/LoadBalancer Service on the named `http` port |
| [`charts/ftw-app/templates/serviceaccount.yaml`](charts/ftw-app/templates/serviceaccount.yaml) | Dedicated ServiceAccount, token automount off unless you ask for it |
| [`charts/ftw-app/templates/configmap.yaml`](charts/ftw-app/templates/configmap.yaml) | ConfigMap from `config.data`, as env vars and/or mounted files |
| [`charts/ftw-app/templates/ingress.yaml`](charts/ftw-app/templates/ingress.yaml) | Optional Ingress: `ingressClassName`, multiple hosts/paths, TLS |
| [`charts/ftw-app/templates/NOTES.txt`](charts/ftw-app/templates/NOTES.txt) | Post-install output, plus warnings for unpinned images and `replicaCount: 1` |
| [`charts/ftw-app/values.schema.json`](charts/ftw-app/values.schema.json) | Strict JSON Schema (`additionalProperties: false`) for every value |
| [`charts/ftw-app/values.yaml`](charts/ftw-app/values.yaml) | Every key documented inline |
| [`charts/ftw-app/ci/all-features-values.yaml`](charts/ftw-app/ci/all-features-values.yaml) | Every optional feature switched on, linted and rendered in CI |
| [`charts/ftw-app/tests/`](charts/ftw-app/tests) | 7 helm-unittest suites, 38 tests |
| [`tests/invalid-values/`](tests/invalid-values) | 8 values files the schema **must** reject |
| [`run-tests.sh`](run-tests.sh) | Everything CI runs, on your machine |

1 chart · 5 resource templates + NOTES.txt · 38 helm-unittest tests · 8 schema rejection tests · kubeconform on 3 Kubernetes versions.

## Quick start (60 seconds)

```bash
git clone https://github.com/Fractal-Techware/helm-production-chart.git
cd helm-production-chart
helm plugin install https://github.com/helm-unittest/helm-unittest --version v1.1.2 --verify=false
./run-tests.sh
```

```
==> helm v4.0.5: lint --strict + template
  ok  default values
==> values.schema.json rejects invalid values
  ok  latest-tag.yaml rejected (/image/tag)
==> helm unittest --strict
Tests:       38 passed, 38 total
==> kubeconform -strict (Kubernetes 1.32.0 1.35.0 1.37.0)
All checks passed.
```

Then deploy your own image:

```bash
helm install web charts/ftw-app -n apps --create-namespace \
  --set image.repository=ghcr.io/you/web \
  --set image.tag=1.4.2 \
  --set image.digest=sha256:... \
  --set containerPort=8080
kubectl -n apps rollout status deployment/web-ftw-app
```

The defaults assume your image listens on port 8080 as a non-root user and answers `GET /`.
If it does not, override `containerPort`, the probe paths and `podSecurityContext.runAsUser`
(the three usual failures: a port below 1024, a root-only image, and writes outside `/tmp` —
add an `extraVolumes` emptyDir for those paths).

Copying the chart into your own repo is the expected workflow: it has no dependencies, so
`cp -R charts/ftw-app charts/my-service` and edit.

## Why a values schema and unit tests

Charts fail in ways `helm lint` never catches: a typo'd key silently does nothing, a `:latest`
tag makes rollbacks meaningless, a selector change breaks the upgrade, a config change does not
restart the pods. `values.schema.json` turns the first two into an error at render time, and
[helm-unittest](https://github.com/helm-unittest/helm-unittest) asserts on the rendered manifest —
so "the securityContext is still restricted" and "changing config rolls the pods" are checked on
every push, not the next incident.

```
charts/ftw-app/        the chart (templates, values, schema, ci values)
charts/ftw-app/tests/  helm-unittest suites
tests/invalid-values/  values files that must be rejected, each with the expected error
run-tests.sh           lint + template + schema tests + unit tests + kubeconform
```

## Want the full kit?

This chart is the free, MIT-licensed sample of the
**[Production Helm Chart Kit](https://store.fractaltechware.com/l/helm-production-chart?utm_source=github&utm_medium=readme&utm_campaign=free-repo)**
— the same chart, plus the library chart and the release machinery that goes around it.

| | **Free** (this repo) | **Starter** $19 | **Pro** $49 | **Studio** $99 |
|---|:---:|:---:|:---:|:---:|
| `ftw-app` chart + strict values schema | yes | yes | yes | yes |
| helm-unittest suite for `ftw-app` | 38 tests | – | – | yes |
| Quickstart, troubleshooting, compatibility matrix | README only | yes | yes | yes |
| `ftw-lib` library chart (14 templates: HPA, PDB, NetworkPolicy, ServiceMonitor/PodMonitor, ExternalSecret, HTTPRoute, CronJob, Job) | – | – | yes | yes |
| Example charts (web API, worker, cron job) + library reference + upgrade/rollback guide | – | – | yes | yes |
| Full helm-unittest suite (135 assertions), `ct.yaml`, testing guide | – | – | – | yes |
| GitHub Actions release workflow (OCI push to GHCR + cosign signing) | – | – | – | yes |
| Argo CD + Flux examples, dev/staging/prod values, OpenTelemetry injection | – | – | – | yes |
| License | MIT | own organization | own organization | client / agency use |

[See the full kit on Gumroad →](https://store.fractaltechware.com/l/helm-production-chart?utm_source=github&utm_medium=readme&utm_campaign=free-repo)
· More free, tested infrastructure repos at [github.com/Fractal-Techware](https://github.com/Fractal-Techware)

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Every template
change needs a helm-unittest assertion.

## License

[MIT](LICENSE) © Fractal Techware SRL
