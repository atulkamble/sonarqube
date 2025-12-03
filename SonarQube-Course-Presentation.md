# SonarQube Course Presentation

**Author:** Atul Kamble  
**GitHub:** https://github.com/atulkamble  
**LinkedIn:** https://www.linkedin.com/in/atuljkamble/

---

## Slide 1: Title Slide
**SonarQube: Mastering Code Quality & Security Analysis**
- *A Comprehensive Course on Static Code Analysis*
- **Author:** Atul Kamble
- **GitHub:** [github.com/atulkamble](https://github.com/atulkamble)
- **LinkedIn:** [linkedin.com/in/atuljkamble](https://www.linkedin.com/in/atuljkamble/)
- **Date:** December 2025

---

## Slide 2: Course Overview
**What You'll Learn Today**
- ✅ Understanding Code Quality & Technical Debt
- ✅ SonarQube Architecture & Components
- ✅ Hands-on Setup & Configuration
- ✅ Multi-language Code Analysis
- ✅ Security Vulnerability Detection
- ✅ CI/CD Integration Best Practices

---

## Slide 3: The Code Quality Crisis
**Why Code Quality Matters**
- 💰 **Financial Impact**: Poor code costs $85B annually in the US
- 🐛 **Bug Statistics**: 60% of bugs come from poor code quality
- ⏱️ **Developer Time**: 75% spent on maintenance vs. new features
- 🔒 **Security**: 83% of vulnerabilities from coding flaws

> *"Technical debt is like a loan - eventually, you have to pay it back with interest"*

---

## Slide 4: What is SonarQube?
**Static Code Analysis Platform**
```
Code → SonarQube Scanner → Analysis Engine → Quality Report
```

**Key Capabilities:**
- 🔍 **Bug Detection**: Reliability issues
- 🛡️ **Security Analysis**: Vulnerabilities & hotspots
- 📏 **Code Smells**: Maintainability issues
- 📊 **Technical Debt**: Quantified remediation effort
- 📈 **Quality Gates**: Pass/fail criteria

---

## Slide 5: SonarQube Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SonarScanner  │───▶│   SonarQube      │───▶│    Database     │
│                 │    │     Server       │    │  (PostgreSQL)   │
├─────────────────┤    ├──────────────────┤    ├─────────────────┤
│ • Maven Plugin  │    │ • Web Interface  │    │ • Projects      │
│ • CLI Scanner   │    │ • Compute Engine │    │ • Issues        │
│ • IDE Plugin    │    │ • Analysis Rules │    │ • Metrics       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

---

## Slide 6: Supported Languages
**25+ Programming Languages**

| **Enterprise** | **Community** | **Popular Frameworks** |
|---------------|---------------|----------------------|
| Java, C#, C++ | JavaScript    | Spring Boot          |
| Python, PHP   | TypeScript    | React/Angular        |
| Go, Swift     | HTML/CSS      | Django/Flask         |
| Kotlin, Scala | XML/JSON      | .NET Core            |

---

## Slide 7: Demo - Common Java Issues
**Example: SQL Injection Vulnerability**
```java
// ❌ VULNERABLE CODE
public User getUser(String userId) {
    String sql = "SELECT * FROM users WHERE id = " + userId;
    return jdbcTemplate.queryForObject(sql, User.class);
}

// ✅ SECURE CODE
public User getUser(String userId) {
    String sql = "SELECT * FROM users WHERE id = ?";
    return jdbcTemplate.queryForObject(sql, User.class, userId);
}
```
**SonarQube Detection:** `squid:S2077 - SQL injection vulnerability`

---

## Slide 8: Demo - JavaScript Code Smells
**Example: Unused Variables & Functions**
```javascript
// ❌ CODE SMELL
function processData(data, unusedParam) {  // Unused parameter
    const unusedVar = "hello";             // Unused variable
    let result = data.map(item => item.value);
    
    function unusedFunction() {            // Dead code
        return "never called";
    }
    
    return result;
}

// ✅ CLEAN CODE
function processData(data) {
    return data.map(item => item.value);
}
```

---

## Slide 9: Demo - Python Security Issues
**Example: Hardcoded Credentials**
```python
# ❌ SECURITY HOTSPOT
class DatabaseConnection:
    def __init__(self):
        self.password = "admin123"  # Hardcoded password
        self.api_key = "sk-1234567890abcdef"  # Exposed API key
    
    def connect(self):
        # Insecure connection logic
        pass

# ✅ SECURE APPROACH
import os
class DatabaseConnection:
    def __init__(self):
        self.password = os.getenv('DB_PASSWORD')
        self.api_key = os.getenv('API_KEY')
```

---

## Slide 10: Quality Gates
**Automated Quality Control**

```
┌─────────────────┐
│   New Code      │
│                 │
│ Coverage ≥ 80%  │ ──┐
│ Duplications<3% │   │    ┌─────────┐
│ Maintainability │   ├───▶│  PASS   │
│ Rating ≤ A      │   │    │  FAIL   │
│ Security ≤ A    │ ──┘    └─────────┘
└─────────────────┘
```

**Default Conditions:**
- 🎯 Coverage on new code ≥ 80%
- 🔄 Duplicated lines ≤ 3%
- 🏆 Maintainability Rating ≤ A
- 🔒 Security Rating ≤ A

---

## Slide 11: CI/CD Integration
**Jenkins Pipeline Example**
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }
        stage('Quality Gate') {
            steps {
                waitForQualityGate abortPipeline: true
            }
        }
    }
}
```

---

## Slide 12: GitHub Actions Integration
**Automated Analysis on PR**
```yaml
name: SonarQube Analysis
on:
  pull_request:
    branches: [ main ]
    
jobs:
  sonarqube:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: SonarQube Scan
      uses: sonarqube-quality-gate-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

---

## Slide 13: Real-World Benefits
**Success Metrics from Industry**

| **Metric** | **Before SonarQube** | **After SonarQube** | **Improvement** |
|------------|---------------------|-------------------|-----------------|
| Bug Density | 2.5 bugs/KLOC | 0.8 bugs/KLOC | **68% reduction** |
| Security Issues | 15/month | 3/month | **80% reduction** |
| Code Coverage | 45% | 85% | **89% increase** |
| Technical Debt | 180 days | 45 days | **75% reduction** |

---

## Slide 14: Best Practices
**SonarQube Implementation Guidelines**

🏗️ **Setup Best Practices:**
- Use dedicated database (PostgreSQL recommended)
- Configure appropriate heap size (4GB+ for enterprise)
- Enable HTTPS in production

📊 **Analysis Best Practices:**
- Run analysis on every commit
- Set up branch analysis for PRs
- Configure quality gates per project type

👥 **Team Best Practices:**
- Train developers on SonarLint IDE plugin
- Review issues during code reviews
- Establish "Definition of Done" with quality criteria

---

## Slide 15: Advanced Features
**Enterprise Capabilities**

🔄 **Branch Analysis:**
- Compare branches against master
- PR decoration with inline comments
- Short-lived branch analysis

📈 **Portfolio Management:**
- Multi-project dashboards
- Executive reporting
- Technical debt tracking across applications

🏢 **Enterprise Security:**
- LDAP/SAML integration
- Advanced security rules
- Compliance reporting (OWASP, SANS)

---

## Slide 16: Custom Rules Development
**Extending SonarQube**
```java
@Rule(key = "CustomNamingRule")
public class CustomNamingRule extends BaseTreeVisitor implements JavaFileScanner {
    
    @Override
    public void visitMethod(MethodTree tree) {
        String methodName = tree.simpleName().name();
        
        if (!methodName.matches("^[a-z][a-zA-Z0-9]*$")) {
            reportIssue(tree.simpleName(), 
                "Method name should be camelCase");
        }
        
        super.visitMethod(tree);
    }
}
```

---

## Slide 17: Troubleshooting Common Issues
**Quick Solutions**

❌ **"Project not found"**
→ Check project key in scanner configuration

❌ **"Quality Gate failed"**  
→ Review new code conditions and thresholds

❌ **"Scanner execution failed"**
→ Verify token permissions and server connectivity

❌ **"Out of memory errors"**
→ Increase JVM heap size: `-Xmx4G`

---

## Slide 18: Hands-On Exercise Preview
**Practical Workshop (4 hours)**

🛠️ **Setup Phase:**
- Docker-based SonarQube installation
- Multi-language project analysis

🔍 **Analysis Phase:**
- Java e-commerce service (Spring Boot)
- React Todo application  
- Python data processor

🎯 **Remediation Phase:**
- Fix security vulnerabilities
- Improve code coverage
- Eliminate code smells

---

## Slide 19: Resources & Next Steps
**Continue Your Learning Journey**

📚 **Documentation:**
- Official SonarQube docs: docs.sonarqube.org
- Community forum: community.sonarsource.com
- GitHub examples: github.com/SonarSource

🎓 **Certification:**
- SonarQube Certified Developer
- SonarQube Certified Administrator

🛠️ **Tools:**
- SonarLint IDE plugins
- SonarScanner CLI
- Quality gate webhooks

---

## Slide 20: Q&A
**Questions & Discussion**

💬 **Common Questions:**
- How to handle false positives?
- Integration with existing CI/CD pipelines?
- Licensing and cost considerations?
- Custom rule development timeline?

📧 **Contact Information:**
- **Course Author:** Atul Kamble
- **GitHub:** [github.com/atulkamble](https://github.com/atulkamble)
- **LinkedIn:** [linkedin.com/in/atuljkamble](https://www.linkedin.com/in/atuljkamble/)
- **Course Repository:** [github.com/atulkamble/sonar-course](https://github.com/atulkamble/sonar-course)

---

## Slide 21: Thank You!
**SonarQube: Your Path to Better Code Quality**

🎯 **Remember:**
- Quality is everyone's responsibility
- Automate what you can measure
- Continuous improvement over perfection

🚀 **Start Your Journey:**
- Install SonarQube today
- Begin with community edition
- Integrate with your CI/CD pipeline

*"The best time to fix a bug was when you wrote it. The second best time is now."*

---

## Presentation Notes

### Timing Recommendations:
- **Introduction (Slides 1-6):** 15 minutes
- **Demo & Examples (Slides 7-9):** 20 minutes
- **Quality Gates & CI/CD (Slides 10-12):** 15 minutes
- **Benefits & Best Practices (Slides 13-16):** 15 minutes
- **Advanced Topics (Slides 17-19):** 10 minutes
- **Q&A & Wrap-up (Slides 20-21):** 10 minutes

### Interactive Elements:
- Live demo during slides 7-9
- Hands-on setup during slide 18
- Group discussion on best practices
- Real-time Q&A throughout presentation

### Technical Requirements:
- Projector/screen for slides
- Internet connection for live demos
- SonarQube instance (can be local Docker)
- Sample code repositories
- Attendee laptops for hands-on portions