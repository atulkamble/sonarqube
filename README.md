# sonarqube

```
// Use sonarqube via docker 

amazon linux | t3.medium | sonar.pem 
SG: 9000 

sudo yum update -y 
sudo yum install docker -y 
sudo systemctl start docker 
sudo systemctl enable docker 
sudo docker login


sudo docker pull sonarqube:lts-enterprise
sudo docker run -d -p 9000:9000 sonarqube:lts-enterprise 

sudo docker container ls 

// open browser and add http://instance-ip:9000 

// enter username and password >> admin, admin 

update password 
```

Got you, Atul. Here’s a clean, production-friendly way to run **SonarQube (Community) + PostgreSQL** via Docker Compose—complete with persistence, healthchecks, and the host settings SonarQube needs. Then I’ll show two “use” paths: scanning a project from your laptop/runner, and scanning inside Docker.

---

# 1) Prereqs (host)

* **CPU/RAM:** ≥ 4 vCPU, **8–12 GB RAM** (SonarQube + ES needs memory)
* **Ports:** 9000 (SonarQube), 5432 (Postgres, optional external access)
* **Docker:** Engine ≥ 20.10 & Compose V2

### Host kernel limits (ElasticSearch requirement)

Run these once on the host (Amazon Linux/Ubuntu/etc.):

```bash
# Required for embedded Elasticsearch
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536

# Make persistent
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-sonarqube.conf
echo "fs.file-max=65536"       | sudo tee -a /etc/sysctl.d/99-sonarqube.conf
sudo sysctl --system
```

> If you run SonarQube as **rootless Docker** or under strict kernels/VMs, still apply the sysctl on the host—setting it just inside the container can be ignored by the kernel.

---

# 2) Project layout

```text
sonarqube-docker/
├─ .env
├─ docker-compose.yml
└─ sonar/
   └─ extensions/        # place extra plugins if needed (JARs)
```

**.env** (edit passwords/users as needed):

```env
# Postgres
POSTGRES_USER=sonar
POSTGRES_PASSWORD=sonarpass
POSTGRES_DB=sonarqube

# SonarQube (JDBC to Postgres container)
SONAR_JDBC_USERNAME=sonar
SONAR_JDBC_PASSWORD=sonarpass
SONAR_JDBC_URL=jdbc:postgresql://postgres:5432/sonarqube

# Optional: tune Java heap for SQ (adjust to your RAM)
SONARQUBE_JAVA_XMS=1g
SONARQUBE_JAVA_XMX=2g
```

**docker-compose.yml**

```yaml
version: "3.9"

services:
  postgres:
    image: postgres:15
    container_name: postgres-sonar
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - sonar-net

  sonarqube:
    image: sonarqube:latest-community
    container_name: sonarqube
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_USERNAME: ${SONAR_JDBC_USERNAME}
      SONAR_JDBC_PASSWORD: ${SONAR_JDBC_PASSWORD}
      SONAR_JDBC_URL: ${SONAR_JDBC_URL}

      # JVM options (adjust as needed)
      SONARQUBE_JAVA_OPTS: "-Xms${SONARQUBE_JAVA_XMS} -Xmx${SONARQUBE_JAVA_XMX} -XX:+HeapDumpOnOutOfMemoryError -Djava.net.preferIPv4Stack=true"

    # Helpful ulimits for ES & file handles
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
      nproc: 4096

    # Set kernel params in container namespace (host sysctl still recommended)
    sysctls:
      - vm.max_map_count=262144

    volumes:
      - sq_data:/opt/sonarqube/data
      - sq_logs:/opt/sonarqube/logs
      - sq_extensions:/opt/sonarqube/extensions
      - ./sonar/extensions:/opt/sonarqube/extensions/extra:ro
    healthcheck:
      test: ["CMD", "bash", "-c", "curl -f http://localhost:9000/ || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 20
    networks:
      - sonar-net

networks:
  sonar-net:

volumes:
  pg_data:
  sq_data:
  sq_logs:
  sq_extensions:
```

> **Why these volumes?**
>
> * `pg_data`: Postgres persistence
> * `sq_data`: SonarQube indices & data
> * `sq_logs`: logs you can tail outside the container
> * `sq_extensions`: plugins (persist across upgrades)

---

# 3) Bring it up

```bash
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f sonarqube
```

Open: **http\://SERVER\_IP:9000**
Default login: **admin / admin** → you’ll be forced to set a new password on first login.

---

# 4) “Use” SonarQube – two quick paths

## A) Scan from your machine/runner (recommended for CI)

1. **Generate a project & token**

   * In SonarQube UI: **Projects → Create Project** (Manually), pick a key like `inventory-manager`.
   * **Administration → Security → Users/Tokens**: create **User Token** (copy it).

2. **Install sonar-scanner** locally or on your CI agent:

**macOS (Homebrew):**

```bash
brew install sonar-scanner
```

**Linux (generic):**

```bash
# Download from SonarSource; unzip to /opt/sonar-scanner; add to PATH
# Example path:
export PATH=/opt/sonar-scanner/bin:$PATH
sonar-scanner -v
```

3. In your repo root, create **sonar-project.properties**:

```properties
sonar.projectKey=inventory-manager
sonar.projectName=Inventory Manager
sonar.projectVersion=1.0

# Where to scan
sonar.sources=.

# Optional: language-specific tweaks
# sonar.language=java

# Point to your SQ server
sonar.host.url=http://YOUR_SERVER_IP:9000

# Set token via env for security
# export SONAR_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxx
```

4. Run a scan:

```bash
export SONAR_TOKEN=YOUR_TOKEN_HERE
sonar-scanner \
  -Dsonar.login=$SONAR_TOKEN
```

Navigate to your project in the UI to see **Issues, Code Smells, Coverage (if you feed reports), and Quality Gate**.

> **Coverage:** Feed your unit test coverage (e.g., Jacoco, lcov, Cobertura) with the corresponding properties (`sonar.javascript.lcov.reportPaths`, `sonar.java.coveragePlugin`, etc.) so dashboards show coverage.

---

## B) Scan inside Docker (no local install)

From your repo directory:

```bash
# Example for generic (non-Java) project:
docker run --rm \
  -e SONAR_HOST_URL="http://YOUR_SERVER_IP:9000" \
  -e SONAR_LOGIN="YOUR_TOKEN_HERE" \
  -v "$PWD":/usr/src \
  sonarsource/sonar-scanner-cli:latest
```

For **Maven/Gradle** projects, use the official scanners:

```bash
# Maven
mvn -DskipTests=true sonar:sonar \
  -Dsonar.host.url=http://YOUR_SERVER_IP:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE

# Gradle
./gradlew sonarqube \
  -Dsonar.host.url=http://YOUR_SERVER_IP:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE
```

---

# 5) Optional: Reverse proxy + TLS (Nginx)

If you want HTTPS quickly (e.g., behind an ALB or with Nginx), add an **nginx** service and terminate TLS there. Example (HTTP pass-through):

```yaml
  nginx:
    image: nginx:alpine
    depends_on:
      - sonarqube
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - sonar-net
```

**nginx.conf**

```nginx
server {
  listen 80;
  server_name _;

  location / {
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_pass http://sonarqube:9000;
  }
}
```

(For TLS, add certs and `listen 443 ssl;` or place SonarQube behind an AWS ALB with HTTPS.)

---

# 6) Backups & upgrades

**Backup Postgres & SQ data:**

```bash
# DB backup
docker exec -t postgres-sonar pg_dump -U sonar sonarqube > sonarqube_$(date +%F).sql

# SQ indices can always be rebuilt, but you may archive data/logs/extensions
docker run --rm -v sq_data:/src -v $PWD:/dst alpine sh -c "cd /src && tar czf /dst/sq_data_$(date +%F).tgz ."
```

**Upgrade flow:**

1. `docker compose pull` (fetch newer `sonarqube:latest-community`)
2. `docker compose up -d`
3. Visit **/setup** if SonarQube asks to migrate.
4. Watch logs: `docker compose logs -f sonarqube`

---

# 7) Troubleshooting quick hits

* **Service stuck / ES errors:**

  * Ensure host **`vm.max_map_count=262144`** (verify with `sysctl vm.max_map_count`)
  * Allocate more RAM (`-Xmx`), and increase Docker memory on Mac/Windows Desktop.
* **Port 9000 in use:** change `ports: "9000:9000"` to another host port (e.g., `19000:9000`).
* **DB auth failures:** check `.env` values and that `SONAR_JDBC_URL` points to `postgres` service, not `localhost`.
* **Slow startup after upgrade:** ES reindexing can take several minutes; watch logs.
* **Plugins:** drop JARs into `./sonar/extensions` (or upload via UI), then restart.

---

# 8) (Bonus) Jenkins integration in 90 seconds

1. In Jenkins: **Manage Plugins → SonarQube Scanner** + (optional) **Quality Gates** plugins.
2. **Manage Jenkins → System → SonarQube servers**: add `http://YOUR_SERVER_IP:9000` and a **Server token** credential.
3. Pipeline snippet:

```groovy
pipeline {
  agent any
  environment {
    SONARQUBE_SERVER = 'MySonar'   // name configured in Jenkins
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Build')    { steps { sh 'echo build your app here' } }
    stage('SonarQube Scan') {
      steps {
        withSonarQubeEnv("${env.SONARQUBE_SERVER}") {
          sh """
            sonar-scanner \
              -Dsonar.projectKey=inventory-manager \
              -Dsonar.projectName=InventoryManager \
              -Dsonar.host.url=$SONAR_HOST_URL
          """
        }
      }
    }
    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }
  }
}
```

In SonarQube, set **Quality Gate** (e.g., “fail if Coverage < 80%”).

---

If you want, I can tailor this compose for **Amazon Linux 2023** hardening, add **NGINX + Let’s Encrypt**, or produce a **one-shot install script** that sets sysctls, writes the files, and brings the stack up automatically.


Got you, Atul. Here’s a clean, production-friendly way to run SonarQube (Community) + PostgreSQL via Docker Compose—complete with persistence, healthchecks, and the host settings SonarQube needs. Then I’ll show two “use” paths: scanning a project from your laptop/runner, and scanning inside Docker.

⸻

1) Prereqs (host)
	•	CPU/RAM: ≥ 4 vCPU, 8–12 GB RAM (SonarQube + ES needs memory)
	•	Ports: 9000 (SonarQube), 5432 (Postgres, optional external access)
	•	Docker: Engine ≥ 20.10 & Compose V2

Host kernel limits (ElasticSearch requirement)

Run these once on the host (Amazon Linux/Ubuntu/etc.):

# Required for embedded Elasticsearch
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536

# Make persistent
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-sonarqube.conf
echo "fs.file-max=65536"       | sudo tee -a /etc/sysctl.d/99-sonarqube.conf
sudo sysctl --system

If you run SonarQube as rootless Docker or under strict kernels/VMs, still apply the sysctl on the host—setting it just inside the container can be ignored by the kernel.

⸻

2) Project layout

sonarqube-docker/
├─ .env
├─ docker-compose.yml
└─ sonar/
   └─ extensions/        # place extra plugins if needed (JARs)

.env (edit passwords/users as needed):

# Postgres
POSTGRES_USER=sonar
POSTGRES_PASSWORD=sonarpass
POSTGRES_DB=sonarqube

# SonarQube (JDBC to Postgres container)
SONAR_JDBC_USERNAME=sonar
SONAR_JDBC_PASSWORD=sonarpass
SONAR_JDBC_URL=jdbc:postgresql://postgres:5432/sonarqube

# Optional: tune Java heap for SQ (adjust to your RAM)
SONARQUBE_JAVA_XMS=1g
SONARQUBE_JAVA_XMX=2g

docker-compose.yml

version: "3.9"

services:
  postgres:
    image: postgres:15
    container_name: postgres-sonar
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - sonar-net

  sonarqube:
    image: sonarqube:latest-community
    container_name: sonarqube
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_USERNAME: ${SONAR_JDBC_USERNAME}
      SONAR_JDBC_PASSWORD: ${SONAR_JDBC_PASSWORD}
      SONAR_JDBC_URL: ${SONAR_JDBC_URL}

      # JVM options (adjust as needed)
      SONARQUBE_JAVA_OPTS: "-Xms${SONARQUBE_JAVA_XMS} -Xmx${SONARQUBE_JAVA_XMX} -XX:+HeapDumpOnOutOfMemoryError -Djava.net.preferIPv4Stack=true"

    # Helpful ulimits for ES & file handles
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
      nproc: 4096

    # Set kernel params in container namespace (host sysctl still recommended)
    sysctls:
      - vm.max_map_count=262144

    volumes:
      - sq_data:/opt/sonarqube/data
      - sq_logs:/opt/sonarqube/logs
      - sq_extensions:/opt/sonarqube/extensions
      - ./sonar/extensions:/opt/sonarqube/extensions/extra:ro
    healthcheck:
      test: ["CMD", "bash", "-c", "curl -f http://localhost:9000/ || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 20
    networks:
      - sonar-net

networks:
  sonar-net:

volumes:
  pg_data:
  sq_data:
  sq_logs:
  sq_extensions:

Why these volumes?
	•	pg_data: Postgres persistence
	•	sq_data: SonarQube indices & data
	•	sq_logs: logs you can tail outside the container
	•	sq_extensions: plugins (persist across upgrades)

⸻

3) Bring it up

docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f sonarqube

Open: http://SERVER_IP:9000
Default login: admin / admin → you’ll be forced to set a new password on first login.

⸻

4) “Use” SonarQube – two quick paths

A) Scan from your machine/runner (recommended for CI)
	1.	Generate a project & token
	•	In SonarQube UI: Projects → Create Project (Manually), pick a key like inventory-manager.
	•	Administration → Security → Users/Tokens: create User Token (copy it).
	2.	Install sonar-scanner locally or on your CI agent:

macOS (Homebrew):

brew install sonar-scanner

Linux (generic):

# Download from SonarSource; unzip to /opt/sonar-scanner; add to PATH
# Example path:
export PATH=/opt/sonar-scanner/bin:$PATH
sonar-scanner -v

	3.	In your repo root, create sonar-project.properties:

sonar.projectKey=inventory-manager
sonar.projectName=Inventory Manager
sonar.projectVersion=1.0

# Where to scan
sonar.sources=.

# Optional: language-specific tweaks
# sonar.language=java

# Point to your SQ server
sonar.host.url=http://YOUR_SERVER_IP:9000

# Set token via env for security
# export SONAR_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxx

	4.	Run a scan:

export SONAR_TOKEN=YOUR_TOKEN_HERE
sonar-scanner \
  -Dsonar.login=$SONAR_TOKEN

Navigate to your project in the UI to see Issues, Code Smells, Coverage (if you feed reports), and Quality Gate.

Coverage: Feed your unit test coverage (e.g., Jacoco, lcov, Cobertura) with the corresponding properties (sonar.javascript.lcov.reportPaths, sonar.java.coveragePlugin, etc.) so dashboards show coverage.

⸻

B) Scan inside Docker (no local install)

From your repo directory:

# Example for generic (non-Java) project:
docker run --rm \
  -e SONAR_HOST_URL="http://YOUR_SERVER_IP:9000" \
  -e SONAR_LOGIN="YOUR_TOKEN_HERE" \
  -v "$PWD":/usr/src \
  sonarsource/sonar-scanner-cli:latest

For Maven/Gradle projects, use the official scanners:

# Maven
mvn -DskipTests=true sonar:sonar \
  -Dsonar.host.url=http://YOUR_SERVER_IP:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE

# Gradle
./gradlew sonarqube \
  -Dsonar.host.url=http://YOUR_SERVER_IP:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE


⸻

5) Optional: Reverse proxy + TLS (Nginx)

If you want HTTPS quickly (e.g., behind an ALB or with Nginx), add an nginx service and terminate TLS there. Example (HTTP pass-through):

  nginx:
    image: nginx:alpine
    depends_on:
      - sonarqube
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - sonar-net

nginx.conf

server {
  listen 80;
  server_name _;

  location / {
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_pass http://sonarqube:9000;
  }
}

(For TLS, add certs and listen 443 ssl; or place SonarQube behind an AWS ALB with HTTPS.)

⸻

6) Backups & upgrades

Backup Postgres & SQ data:

# DB backup
docker exec -t postgres-sonar pg_dump -U sonar sonarqube > sonarqube_$(date +%F).sql

# SQ indices can always be rebuilt, but you may archive data/logs/extensions
docker run --rm -v sq_data:/src -v $PWD:/dst alpine sh -c "cd /src && tar czf /dst/sq_data_$(date +%F).tgz ."

Upgrade flow:
	1.	docker compose pull (fetch newer sonarqube:latest-community)
	2.	docker compose up -d
	3.	Visit /setup if SonarQube asks to migrate.
	4.	Watch logs: docker compose logs -f sonarqube

⸻

7) Troubleshooting quick hits
	•	Service stuck / ES errors:
	•	Ensure host vm.max_map_count=262144 (verify with sysctl vm.max_map_count)
	•	Allocate more RAM (-Xmx), and increase Docker memory on Mac/Windows Desktop.
	•	Port 9000 in use: change ports: "9000:9000" to another host port (e.g., 19000:9000).
	•	DB auth failures: check .env values and that SONAR_JDBC_URL points to postgres service, not localhost.
	•	Slow startup after upgrade: ES reindexing can take several minutes; watch logs.
	•	Plugins: drop JARs into ./sonar/extensions (or upload via UI), then restart.

⸻

8) (Bonus) Jenkins integration in 90 seconds
	1.	In Jenkins: Manage Plugins → SonarQube Scanner + (optional) Quality Gates plugins.
	2.	Manage Jenkins → System → SonarQube servers: add http://YOUR_SERVER_IP:9000 and a Server token credential.
	3.	Pipeline snippet:

pipeline {
  agent any
  environment {
    SONARQUBE_SERVER = 'MySonar'   // name configured in Jenkins
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Build')    { steps { sh 'echo build your app here' } }
    stage('SonarQube Scan') {
      steps {
        withSonarQubeEnv("${env.SONARQUBE_SERVER}") {
          sh """
            sonar-scanner \
              -Dsonar.projectKey=inventory-manager \
              -Dsonar.projectName=InventoryManager \
              -Dsonar.host.url=$SONAR_HOST_URL
          """
        }
      }
    }
    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }
  }
}

In SonarQube, set Quality Gate (e.g., “fail if Coverage < 80%”).

⸻

If you want, I can tailor this compose for Amazon Linux 2023 hardening, add NGINX + Let’s Encrypt, or produce a one-shot install script that sets sysctls, writes the files, and brings the stack up automatically.

Installing and configuring SonarQube on an EC2 instance involves several steps, including setting up the server environment, installing dependencies, and configuring SonarQube itself. Here’s a detailed guide on how to get SonarQube running on Amazon Linux or Ubuntu:

### Prerequisites

1. **EC2 Instance**: Launch an EC2 instance (preferably t2.medium or larger) with Amazon Linux 2 or Ubuntu, as SonarQube requires sufficient memory and CPU.
2. **Security Group**: Allow inbound access to ports:
   - **9000**: SonarQube default web interface port.
   - **22**: SSH access for configuration.
3. **Minimum Requirements**:
   - Java 11 or 17
   - PostgreSQL 10 or higher (SonarQube’s preferred database)

---

### Step 1: Update and Install Required Packages

**For Amazon Linux 2 or Ubuntu:**

```bash
sudo yum update -y               # Amazon Linux
sudo apt update && sudo apt upgrade -y   # Ubuntu
```

### Step 2: Install Java

SonarQube requires Java 11 or Java 17 (depending on the version). Install Java:

```bash
# Amazon Linux or Ubuntu
sudo yum install java -y
sudo yum install java-11-openjdk-devel -y    # Amazon Linux
sudo apt install openjdk-11-jdk -y           # Ubuntu

# Verify Java installation
java -version
```

### Step 3: Install and Configure PostgreSQL

1. **Install PostgreSQL**:

    ```bash
    sudo yum install postgresql-server postgresql-contrib -y    # Amazon Linux
    sudo apt install postgresql postgresql-contrib -y           # Ubuntu
    ```

2. **Initialize and start PostgreSQL** (Amazon Linux):

    ```bash
    sudo postgresql-setup initdb
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    ```

   For Ubuntu:

    ```bash
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    ```

3. **Create a Database and User for SonarQube**:

    ```bash
    sudo -u postgres psql
    CREATE DATABASE sonar;
    CREATE USER sonar WITH ENCRYPTED PASSWORD 'Passw0rd';
    GRANT ALL PRIVILEGES ON DATABASE sonar TO sonar;
    \q
    ```

### Step 4: Install SonarQube

1. **Download SonarQube**:

    ```bash
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.7.0.96327.zip
    sudo unzip sonarqube-10.7.0.96327.zip -d /opt/
    sudo mv /opt/sonarqube-10.7.0.96327 /opt/sonarqube
    ```

2. **Configure SonarQube**:

    Edit the SonarQube configuration file to specify the PostgreSQL database connection:

    ```bash
    sudo nano /opt/sonarqube/conf/sonar.properties
    ```

    Update the following lines:

    ```properties
    sonar.jdbc.username=sonar
    sonar.jdbc.password=Passw0rd
    sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonar
    ```

3. **Configure System Limits** (important for SonarQube performance):

    ```bash
    sudo nano /etc/sysctl.conf
    ```

    Add:

    ```bash
    vm.max_map_count=262144
    fs.file-max=65536
    ```

    Then run:

    ```bash
    sudo sysctl -p
    ```

    Add user limits in `/etc/security/limits.conf`:

    ```bash
    sonar   -   nofile   65536
    sonar   -   nproc    4096
    ```

4. **Create a SonarQube User and Set Permissions**:

    ```bash
    sudo useradd -M -d /opt/sonarqube sonar
    sudo chown -R sonar:sonar /opt/sonarqube
    ```

### Step 5: Start SonarQube

1. **Switch to the SonarQube Directory** and start SonarQube:

    ```bash
    cd /opt/sonarqube/bin/linux-x86-64
    sudo -u sonar ./sonar.sh start
    ```

2. **Configure SonarQube as a Service** (Optional but recommended):

    Create a service file:

    ```bash
    sudo nano /etc/systemd/system/sonarqube.service
    ```

    Add the following configuration:

```ini
[Unit]
Description=SonarQube service
After=network.target postgresql.service
Wants=network-online.target

[Service]
Type=simple
User=sonarqube
Group=sonarqube
# IMPORTANT: never run as root; create user if needed:
# sudo useradd -r -s /bin/false sonarqube && sudo chown -R sonarqube:sonarqube /opt/sonarqube

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=always
RestartSec=10

# File descriptors / processes for ES
LimitNOFILE=65536
LimitNPROC=4096

# If you previously injected tiny heaps via env, neutralize them:
Environment="SONAR_WEB_JAVAOPTS="
Environment="SONAR_SEARCH_JAVAOPTS="

# Hardening
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
    ```

    Then enable and start the service:

    ```bash
    sudo systemctl enable sonarqube
    sudo systemctl start sonarqube
    ```

### Step 6: Access SonarQube

1. Open your browser and go to:

   ```
   http://<EC2_Public_IP>:9000
   ```

2. **Default Credentials**:
   - Username: `admin`
   - Password: `admin`

3. **Update Admin Password**: On first login, update the password and configure additional settings.

---

### Optional Step: Configure SonarQube with a Reverse Proxy (e.g., Nginx)

To access SonarQube through a custom domain or via HTTPS, you can set up Nginx as a reverse proxy:

1. **Install Nginx**:

    ```bash
    sudo yum install nginx -y            # Amazon Linux
    sudo apt install nginx -y            # Ubuntu
    ```

2. **Configure Nginx for SonarQube**:

    ```bash
    sudo nano /etc/nginx/conf.d/sonarqube.conf
    ```

    Add the following configuration:

    ```nginx
    server {
        listen 80;
        server_name yourdomain.com;

        location / {
            proxy_pass http://127.0.0.1:9000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    ```

3. **Restart Nginx**:

    ```bash
    sudo systemctl restart nginx
    ```

This setup will route traffic from `http://yourdomain.com` to `http://<EC2_Public_IP>:9000`. If you want HTTPS, you can use **Certbot** to set up a free SSL certificate with Let's Encrypt.

Gotcha, Atul! Here’s a clean, end-to-end setup to run SonarQube locally, integrate it with Jenkins pipelines, enforce Quality Gates, and publish code-quality dashboards/metrics—complete with ready-to-use configs and Jenkinsfiles.

---

# 1) Spin up SonarQube (Docker Compose)

```yaml
# docker-compose.sonarqube.yml
version: "3.8"
services:
  sonarqube:
    image: sonarqube:community
    container_name: sonarqube
    depends_on:
      - db
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs

  db:
    image: postgres:13
    container_name: sonarqube_db
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgresql:/var/lib/postgresql
      - postgresql_data:/var/lib/postgresql/data

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql:
  postgresql_data:
```

```bash
docker compose -f docker-compose.sonarqube.yml up -d
# Open http://localhost:9000 (default login admin / admin)
# On first login, change the password.
```

---

# 2) Jenkins prerequisites

### Install plugins

* **SonarQube Scanner for Jenkins**
* **Pipeline** (and standard Pipeline dependencies)
* (Java builds) **Maven Integration**, **JUnit**, **JaCoCo**

### Configure tools (Manage Jenkins → Tools)

* **JDK 17** (SonarQube & modern build tools prefer 17)
* **Maven** (if building Maven projects)
* **SonarQube Scanner** (name it e.g. `sonar-scanner-4.x`)

### Configure SonarQube server in Jenkins

* Manage Jenkins → **System** → **SonarQube servers**

  * Name: `SonarLocal`
  * Server URL: `http://localhost:9000`
  * Credentials: **Secret Text** = a **SonarQube user token**

Create token in SonarQube:

1. **My Account → Security → Generate Tokens** (e.g., `jenkins-token`).
2. Add that token to Jenkins **Credentials → Secret text** (ID: `sonar-token` or via the SonarQube servers page).

### (Optional) Webhook from SonarQube to Jenkins

To speed up quality gate results:

* SonarQube **Administration → Configuration → Webhooks → Create**

  * Name: `Jenkins`
  * URL: `http://<jenkins-host>/sonarqube-webhook/`
    This lets `waitForQualityGate()` return as soon as analysis is processed.

---

# 3) Project-level config

## A) Polyglot projects (Sonar Scanner CLI)

Add a `sonar-project.properties` at your repo root:

```properties
sonar.projectKey=inventory-manager
sonar.projectName=Inventory Manager
sonar.projectVersion=1.0
sonar.sources=src
sonar.tests=tests
sonar.exclusions=**/node_modules/**,**/dist/**,**/build/**,**/*.min.js
sonar.test.inclusions=**/*Test.java,**/*.spec.js,**/*.test.ts
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.python.coverage.reportPaths=coverage.xml
sonar.java.binaries=**/target/classes
sonar.sourceEncoding=UTF-8
```

## B) Maven projects

Add to `pom.xml`:

```xml
<build>
  <plugins>
    <!-- Unit test coverage -->
    <plugin>
      <groupId>org.jacoco</groupId>
      <artifactId>jacoco-maven-plugin</artifactId>
      <version>0.8.11</version>
      <executions>
        <execution>
          <goals>
            <goal>prepare-agent</goal>
          </goals>
        </execution>
        <execution>
          <id>report</id>
          <phase>test</phase>
          <goals>
            <goal>report</goal>
          </goals>
        </execution>
      </executions>
    </plugin>

    <!-- Sonar -->
    <plugin>
      <groupId>org.sonarsource.scanner.maven</groupId>
      <artifactId>sonar-maven-plugin</artifactId>
      <version>3.10.0.2594</version>
    </plugin>
  </plugins>
</build>
```

---

# 4) Jenkins Pipelines (Declarative)

## A) Generic (Sonar Scanner CLI)

Works for Node/TS/Python/Go/Java mixed repos using `sonar-project.properties`.

```groovy
// Jenkinsfile (Scanner CLI)
pipeline {
  agent any

  environment {
    SONARQUBE_ENV = 'SonarLocal' // name from "SonarQube servers"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build & Test') {
      steps {
        sh '''
          # Example for Node
          if [ -f package.json ]; then
            npm ci || npm install
            npm test --if-present || true
          fi

          # Example for Python
          if [ -f requirements.txt ]; then
            python3 -m venv .venv && . .venv/bin/activate
            pip install -r requirements.txt
            pytest --maxfail=1 --disable-warnings -q --cov=. --cov-report=xml || true
          fi

          # Example for Java/Maven
          if [ -f pom.xml ]; then
            mvn -B -ntp clean verify
          fi
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml, **/junit.xml'
          publishHTML(target: [
            reportDir: 'coverage', reportFiles: 'index.html',
            reportName: 'Coverage', keepAll: true, alwaysLinkToLastBuild: true, allowMissing: true
          ])
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv("${env.SONARQUBE_ENV}") {
          sh '''
            # Use installed global tool "SonarQube Scanner" if configured,
            # otherwise fallback to 'sonar-scanner' on PATH
            if command -v sonar-scanner >/dev/null 2>&1; then
              sonar-scanner
            else
              ${SCANNER_HOME}/bin/sonar-scanner
            fi
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        script {
          // waits for webhook or polls; aborts pipeline on failure
          def qg = waitForQualityGate abortPipeline: true
          echo "Quality Gate status: ${qg.status}"
        }
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'sonar-report/**/*', onlyIfSuccessful: false, allowEmptyArchive: true
    }
  }
}
```

> Tip: In **Global Tool Configuration**, name the Sonar Scanner installation as `SCANNER_HOME` so `${SCANNER_HOME}/bin/sonar-scanner` works.

## B) Maven-native Sonar

Preferred for pure Java/Maven:

```groovy
// Jenkinsfile (Maven + Sonar)
pipeline {
  agent any
  environment {
    SONARQUBE_ENV = 'SonarLocal'
  }
  tools {
    jdk 'jdk17'
    maven 'maven-3.9'
  }
  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Build & Test') {
      steps {
        sh 'mvn -B -ntp clean verify'
      }
      post {
        always {
          junit 'target/surefire-reports/*.xml'
          jacoco execPattern: '**/target/jacoco.exec', classPattern: 'target/classes', sourcePattern: 'src/main/java'
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv("${env.SONARQUBE_ENV}") {
          sh '''
            mvn -B -ntp sonar:sonar \
              -Dsonar.projectKey=inventory-manager \
              -Dsonar.projectName="Inventory Manager"
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        script {
          def qg = waitForQualityGate abortPipeline: true
          echo "Quality Gate status: ${qg.status}"
        }
      }
    }
  }
}
```

## C) Multibranch hints

* In SonarQube **Project Settings → Branches & Pull Requests**, enable your SCM flavor.
* For PR decoration (comments in PRs), configure **Dev Edition+** with your Git hosting (GitHub/GitLab/Bitbucket) PAT/App.

---

# 5) Define & Enforce Quality Gates

1. In SonarQube **Quality Gates → Create** (e.g., “Cloudnautic Gate”):

   * **New Code** (since last leak period or since specific date/branch):

     * Coverage ≥ 80%
     * Duplicated Lines Density ≤ 3%
     * Maintainability: New Code **Code Smells = 0** or **Rating ≤ A**
     * Reliability: New Code **Bugs = 0** or **Rating ≤ A**
     * Security: New Code **Vulnerabilities = 0** and **Security Hotspots Reviewed = 100%**

2. **Set as Default**, or assign it to selected projects.

3. Jenkins will **fail** at `waitForQualityGate` if the gate fails (visible in Blue Ocean/console).

---

# 6) Code-Quality Dashboard & Reporting

### Built-in dashboards

* **Project Overview**: Reliability, Security, Maintainability ratings + coverage + duplications.
* **Measures**: drill-down per file/component.
* **Issues**: triage, assign, mark as False Positive/Won’t Fix.
* **Security Hotspots**: review workflow.
* **Coverage**: upload LCOV/XML/JaCoCo reports to see trends.

### Exporting key metrics (REST API)

You can pull measures into Jenkins (or a nightly job) and publish a simple HTML/PDF.

**Example: curl metrics → JSON:**

```bash
# Replace token and project key
SONAR_HOST="http://localhost:9000"
TOKEN="YOUR_READ_TOKEN"
PROJECT="inventory-manager"
curl -s -u "$TOKEN:" \
  "$SONAR_HOST/api/measures/component?component=$PROJECT&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,security_hotspots,tests,test_errors,test_failures" \
  -o sonar_metrics.json
```

**Optional Jenkins step to publish a simple HTML report:**

```groovy
stage('Publish Sonar Summary') {
  steps {
    sh '''
      mkdir -p sonar-report
      cat > sonar-report/index.html <<'HTML'
      <html><head><title>Sonar Summary</title></head><body>
      <h1>SonarQube Summary</h1>
      <p>See SonarQube project dashboard for drill-down details.</p>
      </body></html>
      HTML
    '''
    publishHTML(target: [reportDir: 'sonar-report', reportFiles: 'index.html', reportName: 'Sonar Summary'])
  }
}
```

> For a richer report, transform `sonar_metrics.json` with a small script (Node/Python) into HTML and archive.

---

# 7) Sample language coverage wiring

## Node/TypeScript

* **Jest**: `jest --coverage --coverageReporters=lcov --coverageReporters=text-summary`
* Ensure `coverage/lcov.info` exists and properties set:
  `sonar.javascript.lcov.reportPaths=coverage/lcov.info`
  `sonar.typescript.lcov.reportPaths=coverage/lcov.info`

## Python (pytest + coverage)

```bash
pytest -q --cov=. --cov-report=xml
```

`sonar.python.coverage.reportPaths=coverage.xml`

## Java (JaCoCo)

Already added in `pom.xml`; Sonar picks up `target/site/jacoco/jacoco.xml` automatically in recent setups.
If needed:
`sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml`

---

# 8) Common pitfalls & fixes

* **Quality Gate never completes in Jenkins**
  Add SonarQube **Webhook** to Jenkins URL `/sonarqube-webhook/`, and make sure Jenkins can be reached from SonarQube (network/DNS).

* **Analysis fails: “Authentication failed”**
  Check the Sonar token validity and **SonarQube server** config in Jenkins.

* **Coverage shows 0%**
  Ensure the correct report path(s) in `sonar-project.properties` and that the coverage files are produced *before* the Sonar step.

* **Large monorepos**
  Use multiple `sonar-project.properties` per submodule and analyze with different `sonar.projectKey`s or use `sonar.modules` (deprecated style—prefer separate analyses).

* **Branch/PR decoration missing**
  Requires SonarQube **Developer Edition+** and proper SCM integration; community edition displays branches without PR decoration.

---

# 9) Minimal “works everywhere” folder layout

```
repo/
├─ Jenkinsfile
├─ sonar-project.properties
├─ src/...
├─ tests/...
├─ package.json or pom.xml (as applicable)
└─ coverage/ (created by test tools)
```

---

# 10) Quick checklist (copy/paste)

* [ ] Start SonarQube & DB via Docker Compose
* [ ] Create Sonar **Project** & **User Token**
* [ ] Jenkins: install **SonarQube Scanner** plugin
* [ ] Configure **SonarQube server** + **Scanner tool**
* [ ] Add **Webhook** in SonarQube → Jenkins
* [ ] Add `sonar-project.properties` (or Maven sonar plugin)
* [ ] Add `Jenkinsfile` with `withSonarQubeEnv` + `waitForQualityGate`
* [ ] Generate coverage files; map paths in sonar properties
* [ ] Define **Quality Gate** and set default
* [ ] (Optional) Pull metrics via API and publish HTML summary

---

If you want, tell me your target stack (Maven/Gradle/Node/Python/Go) and I’ll tailor the `Jenkinsfile`, `sonar-project.properties`, and coverage commands exactly to your repo—plus wire it to your Docker Hub/ECR flow.

