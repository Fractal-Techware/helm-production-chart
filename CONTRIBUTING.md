# Contributing

Thanks for helping improve this chart.

- **Bug reports** (a template renders the wrong thing, the schema rejects valid values, the chart
  fails to install): open an issue with your Helm and Kubernetes versions, the values you used
  and the error output.
- **Pull requests**: every template change needs a matching assertion in
  `charts/ftw-app/tests/*_test.yaml`. New values must be added to `values.yaml` (with a `# --`
  comment), to `values.schema.json`, and — when they are optional features — to
  `charts/ftw-app/ci/all-features-values.yaml`. A value the schema should reject belongs in
  `tests/invalid-values/` with an `# expect:` line naming the expected error fragment.
- Run `./run-tests.sh` before opening the PR; CI runs exactly the same checks.

Conventions: secure defaults stay secure (a change that relaxes `securityContext`,
`automountServiceAccountToken` or the read-only root filesystem by default will not be merged —
make it a value instead), no inline secrets in values, no `:latest`.

By contributing you agree that your contribution is licensed under the MIT License.
