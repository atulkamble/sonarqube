# Docker Setup for SonarQube

This is the easiest and most popular way to get SonarQube running quickly for development and testing.

## Prerequisites

- Docker installed and running
- At least 4GB RAM available
- 2GB free disk space

## Quick Start with Docker Compose

### 1. Create docker-compose.yml

Create a `docker-compose.yml` file in your project directory:

```yaml
version: "3.8"

services:
  sonarqube:
    image: sonarqube:lts-community
    hostname: sonarqube
    container_name: sonarqube
    depends_on:
      - db
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ports:
      - "9000:9000"
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
      nproc: 4096
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G

  db:
    image: postgres:13
    hostname: postgresql
    container_name: postgresql
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql_data:
```

### 2. Start SonarQube

```bash
# Start the services
docker-compose up -d

# Check logs
docker-compose logs -f sonarqube

# Wait for SonarQube to start (usually 2-3 minutes)
# Look for "SonarQube is up" in the logs
```

### 3. Access SonarQube

- Open browser to `http://localhost:9000`
- Default credentials:
  - Username: `admin`
  - Password: `admin`
- You'll be prompted to change the password on first login

## Alternative: Single Docker Container (Development Only)

For quick testing without PostgreSQL:

```bash
# Run SonarQube with embedded H2 database
docker run -d --name sonarqube \
  -p 9000:9000 \
  sonarqube:lts-community

# Check logs
docker logs -f sonarqube
```

**Note:** H2 database is not suitable for production use.

## Production Docker Setup

### Enhanced docker-compose.yml for Production

```yaml
version: "3.8"

services:
  sonarqube:
    image: sonarqube:lts-community
    hostname: sonarqube
    container_name: sonarqube
    depends_on:
      - db
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD_FILE: /run/secrets/db_password
      SONAR_WEB_JAVAADDITIONALOPTS: "-server -Xms2048m -Xmx2048m"
      SONAR_CE_JAVAADDITIONALOPTS: "-server -Xms1024m -Xmx1024m"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ports:
      - "9000:9000"
    secrets:
      - db_password
    ulimits:
      nofile:
        soft: 131072
        hard: 131072
      nproc: 8192
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 6G
        reservations:
          cpus: '1'
          memory: 3G
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/api/system/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  db:
    image: postgres:13-alpine
    hostname: postgresql
    container_name: postgresql
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      POSTGRES_DB: sonar
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgresql_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql:ro
    secrets:
      - db_password
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 3G
        reservations:
          cpus: '0.5'
          memory: 1G
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar -d sonar"]
      interval: 30s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - sonarqube
    restart: unless-stopped

secrets:
  db_password:
    file: ./secrets/db_password.txt

volumes:
  sonarqube_data:
    driver: local
  sonarqube_extensions:
    driver: local
  sonarqube_logs:
    driver: local
  postgresql_data:
    driver: local

networks:
  default:
    driver: bridge
```

### Create Required Files

1. **Create secrets directory and password file:**
```bash
mkdir -p secrets
echo "your-secure-password-here" > secrets/db_password.txt
chmod 600 secrets/db_password.txt
```

2. **Create init-db.sql:**
```sql
-- Database initialization script
ALTER SYSTEM SET max_connections = 300;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
SELECT pg_reload_conf();
```

3. **Create nginx.conf:**
```nginx
events {
    worker_connections 1024;
}

http {
    upstream sonarqube {
        server sonarqube:9000;
    }

    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        client_max_body_size 50M;

        location / {
            proxy_pass http://sonarqube;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
    }
}
```

## Troubleshooting

### Common Issues and Solutions

1. **SonarQube won't start (Exit code 1)**
```bash
# Check system requirements
sysctl vm.max_map_count
# If less than 524288, set it:
sudo sysctl -w vm.max_map_count=524288

# Check file descriptor limits
ulimit -n
# Should be at least 131072

# Check logs for specific errors
docker-compose logs sonarqube
```

2. **Database connection issues**
```bash
# Check if PostgreSQL is running
docker-compose ps

# Test database connection
docker-compose exec db psql -U sonar -d sonar -c "SELECT 1;"

# Reset database if corrupted
docker-compose down -v  # WARNING: This deletes all data
docker-compose up -d
```

3. **Performance issues**
```bash
# Monitor resource usage
docker stats

# Check SonarQube system info
curl http://localhost:9000/api/system/info

# Increase memory if needed (in docker-compose.yml)
SONAR_WEB_JAVAADDITIONALOPTS: "-server -Xms4g -Xmx4g"
```

4. **Plugin installation issues**
```bash
# Check extensions volume
docker-compose exec sonarqube ls -la /opt/sonarqube/extensions/plugins/

# Restart SonarQube after plugin installation
docker-compose restart sonarqube
```

## Docker Commands Reference

### Management Commands
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart SonarQube only
docker-compose restart sonarqube

# View logs
docker-compose logs -f sonarqube
docker-compose logs -f db

# Check service status
docker-compose ps

# Execute commands in container
docker-compose exec sonarqube bash
docker-compose exec db psql -U sonar

# Update to latest version
docker-compose pull
docker-compose up -d
```

### Backup and Restore
```bash
# Backup database
docker-compose exec db pg_dump -U sonar sonar > backup.sql

# Restore database
docker-compose exec -T db psql -U sonar sonar < backup.sql

# Backup volumes
docker run --rm -v sonar_postgresql_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/db_backup.tar.gz -C /data .

docker run --rm -v sonar_sonarqube_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/sonarqube_backup.tar.gz -C /data .
```

## Next Steps

After SonarQube is running:

1. **Initial Configuration**: [04-initial-configuration.md](04-initial-configuration.md)
2. **First Analysis**: [../03-basic-usage/01-first-project-analysis.md](../03-basic-usage/01-first-project-analysis.md)
3. **Quality Gates Setup**: [../03-basic-usage/04-quality-gates.md](../03-basic-usage/04-quality-gates.md)

## Production Considerations

- Use external PostgreSQL for better performance
- Set up SSL/TLS termination with nginx or load balancer
- Configure backup strategy for database and data volumes
- Monitor resource usage and scale accordingly
- Set up log aggregation (ELK stack, Splunk, etc.)
- Configure authentication (LDAP, SAML, OAuth)
- Regular security updates and patching
- Network security and firewall configuration