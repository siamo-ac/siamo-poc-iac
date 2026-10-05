# siamo-poc-iac

**Siamo Workflow Atlas — backend-architecture POC #8: Infrastructure as Code.**

## The concept, in plain language

Infrastructure as Code means your servers, networks, and Kubernetes objects
are **described in files** instead of clicked together in a console. The files
are versioned like code, reviewed like code, and a tool makes reality match
them. Change the file → the tool computes the diff → applies only what's
needed. No snowflake servers, no "who changed that?" mysteries.

This POC deploys the microservices demo shape — 2 services (frontend :8081,
backend :8082), ClusterIP Services, and CPU-based autoscaling (2–5 replicas) —
two ways, to show where each tool belongs:

- **`terraform/`** — Terraform + `kubernetes` provider: the *infrastructure*
  view. Declares namespace, deployments, services, HPAs as stateful resources.
- **`helm/orders/`** — a Helm chart: the *application packaging* view. Same
  services as a versioned, templated release installable with different values
  per environment.
- **`docs/terraform-vs-helm.md`** — when to reach for which, and how they
  cooperate.

**This POC is config + docs** — nothing runs. It validates configs and explains
the split. That is the honest scope.

## Validate

Terraform needs its provider first (one-time, needs network):

```bash
cd terraform
terraform init -backend=false   # downloads the kubernetes provider, no state
terraform validate              # syntax + provider schema check, no cluster needed
# terraform fmt -check          # optional style check
```

Helm (works fully offline):

```bash
cd helm
helm lint ./orders
helm template orders ./orders --namespace siamo-demo   # render manifests, no cluster
```

## What to observe

- `terraform validate` passes: the HCL is syntactically valid and every
  resource attribute matches the `kubernetes` provider schema — without ever
  touching a cluster.
- `helm lint` passes and `helm template` renders **6 manifests** (2
  Deployments, 2 Services, 2 HPAs) with the demo image `siamo/orders:demo`,
  matching the Terraform shape 1:1.
- The **shape parity**: `terraform/main.tf` (`local.services`) and the chart
  (`values.yaml` → `services:`) describe the same two services, showing the
  two tools are different *views* of the same deployment.
- `docs/terraform-vs-helm.md` explains the split: Terraform = platform
  resources that outlive deploys; Helm = versioned app releases per
  environment.

## Honest limits

- **Nothing is applied.** `validate`/`lint` check the *description*, not a
  real deployment — no cluster, no metrics-server (which real HPAs need), no
  registry holding `siamo/orders:demo` (placeholder image).
- **No remote state / locking** (`-backend=false`): fine for a demo, mandatory
  for any team use.
- **Toy HPA policy**: single CPU metric at 70%; real autoscaling tunes
  multiple signals and behavior windows.
- POC — not production hardening.
