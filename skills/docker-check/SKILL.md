---
name: docker-check
description: >
  Validate Docker environment: running containers, port conflicts, image health,
  compose status, and resource usage. Use before starting containerized services.
  Triggers: "docker check", "check containers", "docker status", "container health".

  Do NOT use this skill for: writing Dockerfiles, debugging application code inside
  containers, or managing Kubernetes clusters.
metadata:
  user-invocable: true
  slash-command: /docker-check
  proactive: false
---

# Docker Environment Check

Validate Docker environment health before starting or debugging containerized services.

## Steps

1. **Check Docker daemon:**
   - `docker info > /dev/null 2>&1` — is Docker running?
   - If not running, report and suggest starting it
   - Check Docker version: `docker --version`

2. **List running containers:**
   - `docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"`
   - Flag any containers in unhealthy or restarting state
   - Flag any containers using ports needed by the current project

3. **Check port conflicts:**
   - Extract ports from `docker-compose.yml` or `Dockerfile`
   - Check if those ports are already in use: `lsof -i :<port>`
   - Report which process is using conflicting ports

4. **Validate Docker Compose (if applicable):**
   - `docker compose config --quiet` — is the compose file valid?
   - Check that all referenced images exist or can be built
   - Check that all referenced volumes and networks are defined
   - Verify environment variables and `.env` file presence

5. **Check resource usage:**
   - `docker system df` — disk usage by images, containers, volumes
   - Flag if disk usage is above 80%
   - Suggest `docker system prune` if significant space can be reclaimed

6. **Check image freshness:**
   - List local images relevant to the project
   - Flag images older than 30 days that might be stale
   - Check if base images have security updates available

7. **Report summary:**
   - Docker status: running/stopped
   - Containers: X running, Y stopped, Z unhealthy
   - Port conflicts: list or "none"
   - Disk usage: X GB used
   - Recommendations: actions to take before starting services

## Important

- **Don't start or stop containers automatically** — report findings and let the user decide.
- **Don't expose secrets** from container environment variables in the report.
- **Check compose file format** — v2 vs v3 syntax differences can cause subtle issues.
