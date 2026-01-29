# Sample: ASP.NET + SQL Server dev stack with Docker Compose

This folder contains a minimal example of how a Microsoft-stack team can:
- Build an ASP.NET app into a container image (multi-stage Dockerfile)
- Run the app + SQL Server together locally using Docker Compose

## Prerequisites
- Docker Desktop installed and running
- Your repository has a project at `MyApp/MyApp.csproj` and produces `MyApp.dll` (adjust the Dockerfile if not)

## Quick start
1. Copy `.env.example` to `.env` and set `MSSQL_SA_PASSWORD` to a strong value.
2. From the repo root, run:
   ```bash
   docker compose up --build
   ```
3. Open the app at http://localhost:8080

## Notes for real environments
- This is intended for **local dev/test**.
- Production SQL Server in containers is possible, but it requires strong ops maturity (HA, backups, patching, monitoring).
- Do **not** bake secrets into images. Use secret stores (Key Vault, etc.) for real deployments.

## Troubleshooting
- If SQL Server won’t start, your SA password may not meet complexity requirements. Set a stronger password and retry.
