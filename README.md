# sonarqube

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
    After=syslog.target network.target

    [Service]
    Type=forking
    ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
    ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
    User=sonar
    Group=sonar
    Restart=on-failure
    LimitNOFILE=65536
    LimitNPROC=4096

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

