Here’s a step-by-step guide to install and configure SonarQube on **Amazon Linux 2023** for basic practice:

---

### **Step 1: Launch and Connect to the EC2 Instance**
1. **Launch an Amazon Linux 2023 EC2 instance:**
   - Instance type: `t2.medium` or higher.
   - Storage: At least **20GB** (SonarQube requires space for logs and indexing).
   - Security group:
     - **9000** (SonarQube default port).
     - **22** (SSH).
   
2. **Connect to the instance via SSH:**
   ```bash
   ssh -i <your-key-file>.pem ec2-user@<your-ec2-public-ip>
   ```

---

### **Step 2: Update the System and Install Dependencies**
1. **Update system packages:**
   ```bash
   sudo yum update -y
   ```

2. **Install required dependencies:**
   ```bash
   sudo yum install -y java-17-amazon-corretto wget unzip
   ```

---

### **Step 3: Install and Configure PostgreSQL**
1. **Install PostgreSQL:**
   ```bash
   sudo amazon-linux-extras enable postgresql15
   sudo yum install -y postgresql-server
   ```

2. **Initialize and start PostgreSQL:**
   ```bash
   sudo postgresql-setup --initdb
   sudo systemctl enable postgresql
   sudo systemctl start postgresql
   ```

3. **Create a SonarQube database and user:**
   ```bash
   sudo -i -u postgres
   psql
   CREATE DATABASE sonarqube;
   CREATE USER sonar WITH PASSWORD 'secure_password';
   GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
   \q
   exit
   ```

---

### **Step 4: Install SonarQube**
1. **Download SonarQube:**
   ```bash
   wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.2.0.77628.zip
   ```

2. **Extract the package:**
   ```bash
   unzip sonarqube-10.2.0.77628.zip
   sudo mv sonarqube-10.2.0.77628 /opt/sonarqube
   ```

3. **Set ownership:**
   ```bash
   sudo chown -R ec2-user:ec2-user /opt/sonarqube
   ```

4. **Configure SonarQube:**
   Edit the `sonar.properties` file:
   ```bash
   nano /opt/sonarqube/conf/sonar.properties
   ```
   Update the database connection settings:
   ```properties
   sonar.jdbc.username=sonar
   sonar.jdbc.password=secure_password
   sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
   ```

---

### **Step 5: Start SonarQube**
1. **Navigate to the SonarQube binaries directory:**
   ```bash
   cd /opt/sonarqube/bin/linux-x86-64
   ```

2. **Start SonarQube:**
   ```bash
   ./sonar.sh start
   ```

3. **Check logs for issues:**
   ```bash
   tail -f /opt/sonarqube/logs/sonar.log
   ```

---

### **Step 6: Access SonarQube**
1. Open a web browser and navigate to:
   ```
   http://<your-ec2-public-ip>:9000
   ```
2. Use the default credentials to log in:
   - Username: `admin`
   - Password: `admin`

3. After the first login, you’ll be prompted to set a new password.

---

### **Step 7: Configure Reverse Proxy (Optional)**
To make SonarQube accessible on port 80 or 443, configure a reverse proxy with **NGINX** or **Apache**.

Would you like instructions for setting up a reverse proxy?
