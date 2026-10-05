# Terraform vs Helm — the split, in plain language

**Terraform manages infrastructure. Helm packages applications.** They overlap
on Kubernetes on purpose: Terraform is good at "make the platform look like
this," Helm is good at "install this release of this app here."

| | Terraform | Helm |
|---|---|---|
| Thinks in | **Resources** (deployments, services, VPCs, databases) | **Releases** (a packaged, versioned app) |
| Question it answers | "Does the world match my description?" | "What version of this app is installed, and how is it configured?" |
| State | Remembers what it created (`terraform.tfstate`) and diffs on every run | Remembers releases in the cluster (`helm list`) |
| Reuse | Modules (share infra patterns) | Charts (share app packages, e.g. postgres) |
| Strengths | Cross-provider (AWS + DNS + K8s in one plan), drift detection | Templating, values per environment, rollbacks, chart repos |
| Weakness for this job | Clumsy at app versioning/rollbacks | Clumsy at things outside the cluster |

## How they work together here

- The **Helm chart** (`helm/orders/`) is how the demo app ships: two services,
  configurable image tag, resource limits, and CPU autoscaling via `values.yaml`.
  Same chart installs to dev, staging, and prod with different values files —
  that's the "app packaging" job.
- The **Terraform config** (`terraform/`) is the infrastructure side: it could
  create the namespace, install the chart via the `helm` Terraform provider,
  and own the cluster-adjacent resources (namespaces, quotas, ingress, DNS)
  that no chart should manage itself. Here it declares the same services
  directly with the `kubernetes` provider to show the IaC shape end to end.

The practical rule of thumb: **if it changes on every deploy (image tag,
feature flags), it belongs in Helm. If it changes rarely and outlives deploys
(namespaces, quotas, the cluster itself), it belongs in Terraform.** Mixing
them up gives you either a deployment pipeline that can't roll back, or an
app chart that tries to own the cluster.
