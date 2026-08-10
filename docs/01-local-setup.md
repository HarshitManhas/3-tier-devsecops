# Local Setup Guide

This guide covers setting up the DevOps Project environment locally for development and testing.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Clone the Repository](#clone-the-repository)
3. [Environment Configuration](#environment-configuration)
4. [Start Services](#start-services)
5. [Verification](#verification)
6. [Logs](#logs)
7. [Stopping the Environment](#stopping-the-environment)
8. [Testing Login Credentials](#testing-login-credentials)
9. [Troubleshooting](#troubleshooting)

## Prerequisites
Before starting, ensure you have the following installed:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/) (Version 20+)

## Clone the Repository
```bash
git clone <your-repo-url>
cd 3-tier-devsecops
```

## Environment Configuration
Copy the example environment file for the API and configure it.
```bash
cp api/.env.example api/.env
```
Open `api/.env` and fill in the required values:
- `DB_HOST`: Database hostname (usually `db` when using Docker Compose)
- `DB_USER`: Database user (e.g., `root` or `admin`)
- `DB_PASS`: Database password
- `DB_NAME`: Name of the database to use
- `JWT_SECRET`: Secret key for JWT signing

## Start Services
Run the following command to start the application, API, and database services in the background:
```bash
docker-compose up -d
```

## Verification
Verify all 3 services are running:
```bash
docker-compose ps
```
### Access URLs
- **Frontend**: http://localhost:3000
- **Backend API / Health Check**: http://localhost:5000/health

## Logs
To view logs for all services:
```bash
docker-compose logs -f
```
For a specific service (e.g., api):
```bash
docker-compose logs -f api
```

## Stopping the Environment
To stop and remove containers, networks, and images created by `up`:
```bash
docker-compose down
```
To preserve volumes but stop containers:
```bash
docker-compose stop
```

## Testing Login Credentials
After setup, use the default seeded credentials to log in via the frontend interface at `http://localhost:3000`. Refer to the `api/seed.sql` for the default admin credentials setup instructions.

## Troubleshooting
- **MySQL not starting**: Check if another instance of MySQL is running locally on port 3306.
- **Port conflicts**: If ports 3000 or 5000 are in use, change the mappings in `docker-compose.yml`.
