---
title: DevOps
nav_order: 10
parent: Templates
---
# CLAUDE.md — DevOps / Infrastructure Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your IaC tool and cloud provider -->
This is an infrastructure-as-code project using Terraform with AWS (adjust for your provider). All infrastructure changes must go through code — no manual console changes. Use HCL for Terraform configs, YAML for CI/CD pipelines, and shell scripts for automation.

## Terraform Conventions

<!-- Terraform file organization -->
- One directory per environment: `environments/{dev,staging,prod}/`
- Shared modules in `modules/` — reusable, parameterized, versioned
- State stored remotely (S3 + DynamoDB lock, or Terraform Cloud)
- Variables in `variables.tf`, outputs in `outputs.tf`, providers in `providers.tf`
- Use `terraform fmt` before every commit
- Tag all resources with: `Environment`, `Project`, `ManagedBy=terraform`

## Safety Rules

<!-- Critical safety constraints -->
- **NEVER run `terraform apply` on production without explicit user approval**
- **NEVER run `terraform destroy` without triple-confirming the target environment**
- Always run `terraform plan` first and review the output before applying
- Use `-target` sparingly — it creates state drift
- Lock state files during operations — never bypass locks
- Keep production and non-production state files completely separate

## Docker

<!-- Container conventions -->
- Multi-stage builds: build stage with full toolchain, runtime with minimal image
- Pin base image versions: `node:20.11-alpine` not `node:latest`
- Non-root user in production containers
- Health checks in every Dockerfile: `HEALTHCHECK CMD ...`
- `.dockerignore` must exclude: `.git`, `node_modules`, `.env`, `*.md`
- Scan images for vulnerabilities: `docker scout`, `trivy`, or equivalent

## CI/CD Pipelines

<!-- Pipeline conventions -->
- All pipelines defined in code (GitHub Actions, GitLab CI, etc.)
- Pipeline stages: lint → test → build → security scan → deploy
- Secrets in CI/CD secrets manager — never in pipeline files
- Deploy to staging automatically, production requires manual approval
- Rollback plan documented for every deployment step

## Secrets Management

<!-- How secrets are handled -->
- Never hardcode secrets in any file — use secret managers (AWS Secrets Manager, Vault, etc.)
- Environment variables for runtime secrets
- `.env` files only for local development — never committed
- Rotate secrets on schedule, immediately on suspected compromise
- Audit secret access logs periodically

## Monitoring & Alerting

<!-- Observability patterns -->
- Every service must have: health check endpoint, structured logging, basic metrics
- Alert on: error rate spikes, latency P99 degradation, resource utilization > 80%
- Dashboard for every service in Grafana/CloudWatch/Datadog
- Runbooks linked from alerts — every alert should have a documented response

## Networking

<!-- Network conventions -->
- Private subnets for application workloads, public subnets only for load balancers
- Security groups: principle of least privilege, no `0.0.0.0/0` ingress except HTTPS on ALB
- Use parameter store or service discovery — never hardcode IPs
- TLS everywhere: terminate at load balancer, internal traffic over private network

## Verification

<!-- What to check before declaring done -->
- `terraform fmt -check` passes
- `terraform validate` passes
- `terraform plan` shows only expected changes
- `tflint` or `checkov` passes (if configured)
- Docker images build successfully
- Pipeline runs pass on the branch

## Git & GitHub

<!-- Safety rules -->
- Do not apply infrastructure changes without explicit permission
- Do not perform destructive operations (destroy, force-unlock) without asking first
- Infrastructure PRs require at least one review before merge
- All Terraform changes must include plan output in PR description
