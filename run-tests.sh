#!/usr/bin/env bash
# Run every check CI runs against charts/ftw-app:
#
#   ./run-tests.sh
#
#   1. helm lint --strict + helm template  (default values and ci/all-features-values.yaml)
#   2. values.schema.json negative tests   (tests/invalid-values/*.yaml must be rejected)
#   3. helm unittest --strict              (charts/ftw-app/tests/*_test.yaml)
#   4. kubeconform -strict                 (every rendered manifest, several Kubernetes versions)
#
# Requires helm 3.14+ (pinned: v4.0.5) and the helm-unittest plugin:
#   helm plugin install https://github.com/helm-unittest/helm-unittest --version v1.1.2 --verify=false
# kubeconform is used from your PATH, otherwise the pinned Docker image (set USE_DOCKER=1 to force it).
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source scripts/versions.env

CHART=charts/ftw-app
command -v helm >/dev/null || { echo "helm is required (https://helm.sh/docs/intro/install/)"; exit 2; }

echo "==> helm $(helm version --template '{{.Version}}'): lint --strict + template"
helm lint --strict "$CHART" >/dev/null
helm template t "$CHART" -n apps >/dev/null
echo "  ok  default values"
helm lint --strict "$CHART" -f "$CHART/ci/all-features-values.yaml" >/dev/null
helm template t "$CHART" -n apps -f "$CHART/ci/all-features-values.yaml" >/dev/null
echo "  ok  ci/all-features-values.yaml"

echo "==> values.schema.json rejects invalid values"
for f in tests/invalid-values/*.yaml; do
  pattern="$(sed -n 's/^# expect: //p' "$f")"
  if out="$(helm template t "$CHART" -n apps -f "$f" 2>&1)"; then
    echo "FAIL: $f was accepted"; exit 1
  fi
  grep -qF -- "$pattern" <<<"$out" || { echo "FAIL: $f rejected without '$pattern'"; echo "$out" | tail -5; exit 1; }
  echo "  ok  $(basename "$f") rejected ($pattern)"
done

echo "==> helm unittest --strict"
helm unittest --help >/dev/null 2>&1 || {
  echo "helm-unittest is missing. Install it with:"
  echo "  helm plugin install https://github.com/helm-unittest/helm-unittest --version $HELM_UNITTEST_VERSION --verify=false"
  exit 2
}
helm unittest --strict "$CHART"

echo "==> kubeconform -strict (Kubernetes $KUBECONFORM_K8S_VERSIONS)"
# Rendered under the repository (not /tmp) so Docker file sharing covers it on macOS too.
WORK="$PWD/.rendered"
rm -rf "$WORK"; mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT
helm template t "$CHART" -n apps >"$WORK/default.yaml"
helm template t "$CHART" -n apps -f "$CHART/ci/all-features-values.yaml" >"$WORK/all-features.yaml"
run_kubeconform() { # kubernetes-version
  if [ -z "${USE_DOCKER:-}" ] && command -v kubeconform >/dev/null 2>&1; then
    kubeconform -strict -summary -kubernetes-version "$1" "$WORK"
  else
    docker run --rm -v "$WORK:/manifests:ro" "$KUBECONFORM_IMAGE" \
      -strict -summary -kubernetes-version "$1" /manifests
  fi
}
for kv in $KUBECONFORM_K8S_VERSIONS; do
  out="$(run_kubeconform "$kv")"
  echo "  $kv: $out"
  # A mount that did not reach the container would validate nothing and still exit 0.
  grep -qE "^Summary: [1-9][0-9]* resources? found" <<<"$out" || { echo "FAIL: kubeconform validated no manifests"; exit 1; }
done

echo "All checks passed."
