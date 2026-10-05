# Configuration management best practices

Terraform and Helm (see the README) describe *what should exist*. Configuration
management is the discipline of describing *how it should behave* — per
environment, per release — without forking the description. The practices
below are what keep "it works on my cluster" from becoming a production
incident.

## The practices

1. **Declare desired state, never procedures.** Say "3 replicas of this
   image", not "run kubectl scale". The tool converges reality to the file.
   (This repo's Terraform resources and Helm templates both follow this.)
2. **One base, layered overrides.** Keep a single canonical base config and
   express environments as *deltas* on top — never copy-paste the whole file
   per environment. Deltas stay small, diffs stay reviewable, drift has
   nowhere to hide.
3. **Separate config from code.** Anything that varies by environment
   (replica counts, resource limits, feature flags, endpoints) lives in
   values files, not in templates or application code.
4. **Secrets are references, never values.** No passwords, tokens, or keys in
   values files, HCL, or git. Reference them: Kubernetes `external-secrets`
   / `sealed-secrets`, Vault agent injection, or cloud secret-manager CSI
   drivers. If `git log -p` can show it, it isn't a secret.
5. **Idempotence.** Applying the same config twice changes nothing the
   second time. This is what makes re-runs safe and `terraform plan`
   trustworthy.
6. **Version and review everything.** Config changes go through the same PR
   review as code. `helm template` / `terraform plan` output belongs in the
   PR so reviewers see the *rendered* effect, not just the diff.
7. **Detect drift.** Reality diverges (someone `kubectl edit`s at 2am).
   Scheduled `plan` runs / GitOps reconcilers (ArgoCD, Flux) surface or
   auto-correct it.

## Concrete example: env-layered Helm values

The chart ships `helm/orders/values.yaml` as the base. A production delta
overrides only what differs — everything else inherits:

```yaml
# helm/orders/values-prod.yaml — PROD DELTA, not a copy of values.yaml
autoscaling:
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 60

resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"

image:
  tag: v1.4.2          # prod pins a release; demo floats on :demo
```

Render base + delta (later files win), no cluster needed:

```bash
cd helm
helm template orders ./orders -f values.yaml -f ../docs/values-prod.example.yaml --namespace siamo-prod
```

What to observe: the rendered HPAs carry the prod replica bounds
(`minReplicas: 3`, `maxReplicas: 10`), the Deployments carry the prod
resources and the pinned `v1.4.2` image tag, while everything *not*
mentioned in the delta (namespace, service ports, per-service replica
counts, HPA shape) still comes from the base. Add a staging delta the same
way — the pattern scales to N environments with one base file.

## Honest scope

Layering is a *convention*, not enforcement: nothing stops someone from
duplicating the base into `values-prod-full.yaml` and drifting. Teams
enforce it with PR checks (`helm template` diff in CI), required reviewers
on values files, and GitOps as the only writer to the cluster.
