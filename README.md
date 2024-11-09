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
