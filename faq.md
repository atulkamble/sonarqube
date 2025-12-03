# SonarQube Course FAQ

## General Questions

### Q: What's the difference between SonarQube Community and Commercial editions?

**A:** 
- **Community Edition** (Free): Java, C#, JavaScript, Python, PHP, Go, XML, HTML, CSS, and more. Basic security rules, quality gates, and CI/CD integration.
- **Developer Edition** ($150/year): Adds branch analysis, IDE integration, security analysis for additional languages, and advanced reporting.
- **Enterprise Edition** ($16K/year): Portfolio management, application security, compliance reporting, and advanced governance features.
- **Data Center Edition**: High availability, disaster recovery, and enterprise-grade performance for mission-critical environments.

### Q: Can I use SonarQube for private projects?

**A:** Yes! SonarQube Community Edition is free for both public and private projects with no restrictions on project size or number of developers.

### Q: How often should I run SonarQube analysis?

**A:** 
- **Best Practice**: Every commit via CI/CD pipeline
- **Minimum**: Daily automated analysis
- **Pull Request Analysis**: On every PR (Developer Edition+)
- **Release Analysis**: Before each release deployment

### Q: What's the difference between SonarQube and SonarLint?

**A:**
- **SonarLint**: IDE plugin for individual developers, real-time feedback while coding
- **SonarQube**: Server platform for team analysis, quality gates, and historical tracking
- **Integration**: SonarLint can connect to SonarQube to sync rules and quality profiles

## Installation & Setup

### Q: What are the minimum system requirements?

**A:**
- **RAM**: 4GB minimum, 8GB recommended for production
- **CPU**: 2 cores minimum, 4+ cores recommended
- **Disk**: 2GB for installation + project data storage
- **Database**: PostgreSQL 12+, Oracle 19c+, or SQL Server 2017+ (H2 embedded for development only)

### Q: Can I run SonarQube on Windows?

**A:** Yes, SonarQube supports Windows, Linux, and macOS. However, Linux is recommended for production environments.

### Q: How do I migrate from H2 to PostgreSQL?

**A:** 
1. Export data using SonarQube's backup functionality
2. Set up PostgreSQL database
3. Update `sonar.properties` configuration
4. Restart SonarQube (it will migrate data automatically)

```bash
# Backup current data
curl -u admin:admin http://localhost:9000/api/system/backup

# Update configuration in sonar.properties
sonar.jdbc.url=jdbc:postgresql://localhost/sonar
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
```

## Analysis & Configuration

### Q: Why is my analysis failing with "Insufficient privileges"?

**A:** Common causes:
1. **Missing execute permissions** on SonarQube Scanner
2. **Authentication token issues** - regenerate token
3. **Project key conflicts** - use unique project keys
4. **Quality gate permissions** - check user permissions

```bash
# Fix scanner permissions
chmod +x sonar-scanner

# Verify token
sonar-scanner -Dsonar.login=YOUR_TOKEN -Dsonar.projectKey=test-key -Dsonar.sources=.
```

### Q: How do I exclude files from analysis?

**A:** Use exclusion patterns in `sonar-project.properties`:

```properties
# Exclude specific files/directories
sonar.exclusions=**/target/**,**/node_modules/**,**/*.generated.java

# Exclude from duplication analysis
sonar.cpd.exclusions=**/dto/**,**/entity/**

# Exclude from coverage
sonar.coverage.exclusions=**/test/**,**/config/**
```

### Q: My test coverage is 0%. What's wrong?

**A:** Common issues:
1. **Coverage reports not generated** - run tests with coverage before SonarQube analysis
2. **Wrong report path** - check `sonar.coverage.reportPaths` property
3. **Report format** - ensure compatible format (JaCoCo for Java, LCOV for JavaScript, etc.)

```bash
# Java with Maven
mvn clean test jacoco:report sonar:sonar

# JavaScript with Jest
npm test -- --coverage
npx sonar-scanner -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
```

## Quality Gates & Rules

### Q: What does "Quality Gate Failed" mean?

**A:** Your project doesn't meet the defined quality criteria. Common failures:
- **New bugs > 0**: Any new bugs introduced
- **Coverage < 80%**: Insufficient test coverage
- **Duplicated lines > 3%**: Too much code duplication
- **Maintainability rating worse than A**: Too many code smells

### Q: How do I create custom quality gates?

**A:**
1. Go to **Quality Gates** → **Create**
2. Add conditions (metrics + thresholds)
3. Set for new code vs overall code
4. Assign to projects

```
Example Custom Gate:
- New Bugs = 0
- New Vulnerabilities = 0  
- New Code Coverage ≥ 90%
- New Duplicated Lines ≤ 3%
- New Maintainability Rating ≤ A
```

### Q: Can I disable specific rules for certain files?

**A:** Yes, several approaches:
1. **File-level exclusions** in sonar-project.properties
2. **In-code suppressions** using `@SuppressWarnings`
3. **Quality profile customization** to disable rules globally

```java
// Suppress specific rule
@SuppressWarnings("java:S106") // System.out usage
public void debugMethod() {
    System.out.println("Debug info");
}
```

## Performance & Troubleshooting

### Q: Analysis is very slow. How can I speed it up?

**A:** Optimization strategies:
1. **Incremental analysis** (Developer Edition+)
2. **Exclude unnecessary files** (generated code, dependencies)
3. **Increase scanner memory**: `-Xmx4g`
4. **Parallel analysis** for multi-module projects
5. **SonarQube server tuning**

```bash
# Scanner optimization
export SONAR_SCANNER_OPTS="-Xmx4g"
sonar-scanner -Dsonar.java.jvmargs="-Xmx2g"

# Exclude large directories
sonar.exclusions=**/target/**,**/build/**,**/node_modules/**
```

### Q: SonarQube server is running out of memory

**A:** Server tuning:
```bash
# In sonar.sh or environment
export SONAR_JAVA_PATH=/path/to/java
export SONAR_WEB_JAVA_OPTS="-Xms512m -Xmx2g"
export SONAR_CE_JAVA_OPTS="-Xms512m -Xmx2g"

# For large instances
export SONAR_WEB_JAVA_OPTS="-Xms2g -Xmx4g" 
export SONAR_CE_JAVA_OPTS="-Xms2g -Xmx4g"
```

### Q: Database connection errors during startup

**A:** Common solutions:
1. **Check database is running**: `pg_isready` for PostgreSQL
2. **Verify connection string**: Check host, port, database name
3. **Check credentials**: Username/password in sonar.properties
4. **Network connectivity**: Firewall, security groups
5. **Database permissions**: User has CREATE, ALTER, SELECT permissions

## Security & Authentication

### Q: How do I set up LDAP authentication?

**A:** Configure in `sonar.properties`:

```properties
# Enable LDAP
sonar.security.realm=LDAP

# LDAP configuration
sonar.ldap.url=ldap://ldap.company.com:389
sonar.ldap.bindDn=cn=bind-user,dc=company,dc=com
sonar.ldap.bindPassword=secret

# User mapping
sonar.ldap.user.baseDn=ou=users,dc=company,dc=com
sonar.ldap.user.request=(&(objectClass=inetOrgPerson)(uid={login}))
sonar.ldap.user.realNameAttribute=cn
sonar.ldap.user.emailAttribute=mail

# Group mapping
sonar.ldap.group.baseDn=ou=groups,dc=company,dc=com  
sonar.ldap.group.request=(&(objectClass=groupOfUniqueNames)(uniqueMember={dn}))
```

### Q: How do I secure SonarQube in production?

**A:** Security checklist:
1. **Change default credentials** (admin/admin)
2. **Use HTTPS** with valid SSL certificates
3. **Enable authentication** (LDAP, SAML, OAuth)
4. **Configure firewall** - only necessary ports open
5. **Regular updates** - apply security patches
6. **Backup encryption** - encrypt database backups
7. **Access control** - principle of least privilege

## Integration

### Q: How do I integrate with Jenkins?

**A:**
1. **Install SonarQube Scanner plugin** in Jenkins
2. **Configure SonarQube server** in Jenkins Global Configuration
3. **Add analysis step** to pipeline

```groovy
pipeline {
    agent any
    stages {
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'sonar-scanner'
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }
}
```

### Q: GitHub Actions integration not working?

**A:** Common issues:
1. **Token authentication** - use `SONAR_TOKEN` secret
2. **Branch analysis** - requires Developer Edition+
3. **PR decoration** - check webhook configuration

```yaml
name: SonarQube Analysis
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  sonarqube:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0
    - name: SonarQube Scan
      uses: sonarqube-quality-gate-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

## Language-Specific Questions

### Q: Java analysis shows "No sources to scan"

**A:** Common solutions:
1. **Check source paths**: Verify `sonar.sources` property
2. **Maven structure**: Ensure standard `src/main/java` structure
3. **Build first**: Compile code before analysis
4. **Encoding issues**: Set `sonar.sourceEncoding=UTF-8`

```properties
# Explicit source configuration  
sonar.sources=src/main/java,src/main/resources
sonar.tests=src/test/java
sonar.java.binaries=target/classes
```

### Q: JavaScript analysis not finding files?

**A:** Configuration checklist:
1. **File extensions**: Check `sonar.javascript.file.suffixes`
2. **Node.js version**: Use supported version
3. **Dependencies**: Run `npm install` before analysis
4. **Exclusions**: Don't exclude all JS files accidentally

```properties
# JavaScript configuration
sonar.javascript.file.suffixes=.js,.jsx,.vue
sonar.typescript.file.suffixes=.ts,.tsx
sonar.exclusions=node_modules/**,build/**,dist/**
```

### Q: Python analysis issues?

**A:** Common problems:
1. **Python version**: SonarQube supports Python 3.6+
2. **Virtual environment**: Analysis from correct environment
3. **Import paths**: Set `PYTHONPATH` if needed
4. **Test framework**: Ensure pytest or unittest format

```bash
# Python analysis setup
python -m pip install pytest pytest-cov
python -m pytest --cov=src --cov-report=xml
sonar-scanner -Dsonar.python.coverage.reportPaths=coverage.xml
```

## Maintenance & Monitoring

### Q: How do I backup SonarQube data?

**A:** Backup strategy:
1. **Database backup**: Use database-specific tools
2. **File system backup**: `data/` directory
3. **Configuration**: `conf/` directory
4. **Plugins**: `extensions/plugins/` directory

```bash
# PostgreSQL backup
pg_dump -h localhost -U sonar sonar > sonar_backup.sql

# File system backup  
tar -czf sonar_data_backup.tar.gz /opt/sonarqube/data/
tar -czf sonar_conf_backup.tar.gz /opt/sonarqube/conf/
```

### Q: How do I monitor SonarQube health?

**A:** Monitoring endpoints:
- **Health check**: `GET /api/system/health`
- **System info**: `GET /api/system/info`
- **Database status**: `GET /api/system/db_migration_status`

```bash
# Health monitoring script
#!/bin/bash
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/api/system/health)
if [ $RESPONSE != "200" ]; then
    echo "SonarQube is unhealthy"
    exit 1
fi
```

## Troubleshooting Decision Tree

```
Analysis Failing?
├── Authentication Error?
│   ├── Check token validity
│   └── Verify permissions
├── Scanner Not Found?
│   ├── Install scanner
│   └── Add to PATH
├── Out of Memory?
│   ├── Increase scanner memory
│   └── Tune server JVM
├── Quality Gate Failed?
│   ├── Review new issues
│   └── Check coverage
└── Database Error?
    ├── Check DB connectivity
    └── Verify credentials
```

## Getting Help

### Q: Where can I get more help?

**A:** Resources:
1. **Official Documentation**: https://docs.sonarqube.org/
2. **Community Forum**: https://community.sonarsource.com/
3. **Stack Overflow**: Tag with `sonarqube`
4. **GitHub Issues**: For bugs in specific language analyzers
5. **Professional Support**: Available with commercial licenses

### Q: How do I report bugs or request features?

**A:**
1. **Check existing issues**: Search community forum first
2. **Provide details**: Version, configuration, logs
3. **Minimal reproduction**: Create simple test case
4. **Language-specific**: Use appropriate GitHub repository

**Bug Report Template:**
```
SonarQube Version: X.X.X
Language: Java/JavaScript/Python
Scanner: Maven/Gradle/SonarScanner
Operating System: Linux/Windows/macOS

Description:
[Detailed description of the issue]

Steps to Reproduce:
1. [First Step]
2. [Second Step] 
3. [And so on...]

Expected Result:
[What you expected to happen]

Actual Result:
[What actually happened]

Logs:
[Relevant log excerpts]
```

## Quick Reference

### Essential URLs
- Dashboard: `http://localhost:9000`
- System Info: `http://localhost:9000/api/system/info`
- Health Check: `http://localhost:9000/api/system/health`
- Rules: `http://localhost:9000/coding_rules`

### Key Configuration Files
- Server config: `conf/sonar.properties`
- Project config: `sonar-project.properties`
- Quality profiles: Web interface only
- Quality gates: Web interface only

### Important System Properties
```properties
# Essential properties
sonar.projectKey=unique-project-key
sonar.projectName=Display Name
sonar.projectVersion=1.0.0
sonar.sources=src
sonar.tests=test
sonar.host.url=http://localhost:9000
sonar.login=your-token-here

# Language specific
sonar.java.binaries=target/classes
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.python.coverage.reportPaths=coverage.xml

# Exclusions
sonar.exclusions=**/target/**,**/node_modules/**
sonar.test.exclusions=**/*Test.java,**/*IT.java
sonar.coverage.exclusions=**/config/**,**/dto/**
```