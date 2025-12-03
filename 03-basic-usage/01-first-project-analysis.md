# First Project Analysis

This guide will walk you through analyzing your first project with SonarQube. We'll cover different languages and build tools.

## Prerequisites

- SonarQube server running (see [Installation Guide](../02-installation/02-docker-setup.md))
- SonarQube Scanner installed
- Access to SonarQube web interface at `http://localhost:9000`

## Step 1: Create Your First Project

### Via Web Interface

1. **Login to SonarQube**
   - Open `http://localhost:9000`
   - Login with admin/admin (change password when prompted)

2. **Create New Project**
   - Click "Create Project" → "Manually"
   - Project key: `my-first-project`
   - Display name: `My First Project`
   - Click "Set Up"

3. **Generate Token**
   - Choose "Generate a token"
   - Token name: `my-first-analysis`
   - Click "Generate"
   - **Copy and save the token** - you'll need it for analysis

4. **Choose Analysis Method**
   - Select your build tool or "Other" for generic scanner
   - Follow the provided instructions

## Step 2: Prepare Sample Projects

Let's create sample projects to analyze:

### Java Project with Maven

```bash
# Create directory structure
mkdir -p java-sample/src/main/java/com/example
mkdir -p java-sample/src/test/java/com/example

cd java-sample
```

**pom.xml:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>java-sample</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <sonar.projectKey>java-sample</sonar.projectKey>
        <sonar.projectName>Java Sample Project</sonar.projectName>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.sonarsource.scanner.maven</groupId>
                <artifactId>sonar-maven-plugin</artifactId>
                <version>3.9.1.2184</version>
            </plugin>
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>0.8.8</version>
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
        </plugins>
    </build>
</project>
```

**src/main/java/com/example/Calculator.java:**
```java
package com.example;

import java.util.List;

public class Calculator {
    
    // BUG: Method can throw NPE
    public int add(Integer a, Integer b) {
        return a + b; // Potential NullPointerException
    }
    
    // CODE SMELL: Magic number
    public double calculateCircleArea(double radius) {
        return 3.14159 * radius * radius; // Magic number
    }
    
    // BUG: Division by zero not handled
    public double divide(double a, double b) {
        return a / b; // No zero check
    }
    
    // CODE SMELL: Duplicated code
    public int sumPositiveNumbers(List<Integer> numbers) {
        int sum = 0;
        for (Integer num : numbers) {
            if (num != null && num > 0) {
                sum += num;
            }
        }
        return sum;
    }
    
    // CODE SMELL: Duplicated code (similar to above)
    public int sumEvenNumbers(List<Integer> numbers) {
        int sum = 0;
        for (Integer num : numbers) {
            if (num != null && num % 2 == 0) {
                sum += num;
            }
        }
        return sum;
    }
    
    // VULNERABILITY: Potential security issue with user input
    public String processUserInput(String input) {
        // Direct processing without validation
        return input.toUpperCase();
    }
}
```

**src/test/java/com/example/CalculatorTest.java:**
```java
package com.example;

import org.junit.Test;
import org.junit.Assert;
import java.util.Arrays;

public class CalculatorTest {
    
    private Calculator calculator = new Calculator();
    
    @Test
    public void testAdd() {
        Assert.assertEquals(5, calculator.add(2, 3));
    }
    
    @Test
    public void testCalculateCircleArea() {
        double result = calculator.calculateCircleArea(1.0);
        Assert.assertTrue(result > 3.0 && result < 3.2);
    }
    
    // Missing test for divide method
    // Missing test for null inputs
    // Low test coverage will be reported
}
```

### JavaScript Project

```bash
mkdir -p javascript-sample/src
mkdir -p javascript-sample/test
cd javascript-sample
```

**package.json:**
```json
{
  "name": "javascript-sample",
  "version": "1.0.0",
  "description": "Sample JavaScript project for SonarQube analysis",
  "main": "src/index.js",
  "scripts": {
    "test": "jest",
    "sonar": "sonar-scanner"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0"
  },
  "jest": {
    "collectCoverage": true,
    "coverageDirectory": "coverage",
    "coverageReporters": ["lcov", "text"]
  }
}
```

**sonar-project.properties:**
```properties
sonar.projectKey=javascript-sample
sonar.projectName=JavaScript Sample Project
sonar.projectVersion=1.0.0

# Source code location
sonar.sources=src
sonar.tests=test

# JavaScript specific
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.testExecutionReportPaths=test-results/sonar-report.xml

# Exclude files
sonar.exclusions=node_modules/**,coverage/**,dist/**
```

**src/index.js:**
```javascript
// BUG: Unused variable
const unusedVariable = 'This is never used';

// VULNERABILITY: XSS vulnerability
function displayMessage(message) {
    document.getElementById('output').innerHTML = message; // Dangerous!
}

// CODE SMELL: Magic numbers
function calculatePrice(quantity) {
    const basePrice = 19.99; // Magic number
    const taxRate = 0.08; // Magic number
    return quantity * basePrice * (1 + taxRate);
}

// BUG: No error handling
async function fetchUserData(userId) {
    const response = await fetch(`/api/users/${userId}`);
    return response.json(); // No error handling
}

// CODE SMELL: Complex function
function processOrder(order) {
    if (order) {
        if (order.items) {
            if (order.items.length > 0) {
                if (order.customer) {
                    if (order.customer.email) {
                        if (order.total > 0) {
                            return true;
                        }
                    }
                }
            }
        }
    }
    return false;
}

// VULNERABILITY: Hardcoded credentials
const API_KEY = 'sk-1234567890abcdef';

module.exports = {
    displayMessage,
    calculatePrice,
    fetchUserData,
    processOrder
};
```

**test/index.test.js:**
```javascript
const { calculatePrice, processOrder } = require('../src/index');

describe('Calculator functions', () => {
    test('calculatePrice should return correct price', () => {
        expect(calculatePrice(1)).toBeCloseTo(21.59);
    });
    
    test('processOrder should validate order', () => {
        const validOrder = {
            items: [{ id: 1, name: 'Item 1' }],
            customer: { email: 'test@example.com' },
            total: 100
        };
        expect(processOrder(validOrder)).toBe(true);
    });
    
    // Missing tests for other functions
    // Low coverage will be reported
});
```

### Python Project

```bash
mkdir -p python-sample/src
mkdir -p python-sample/tests
cd python-sample
```

**sonar-project.properties:**
```properties
sonar.projectKey=python-sample
sonar.projectName=Python Sample Project
sonar.projectVersion=1.0.0

# Source code
sonar.sources=src
sonar.tests=tests

# Python specific
sonar.python.coverage.reportPaths=coverage.xml
sonar.python.xunit.reportPath=test-results.xml

# Exclude files
sonar.exclusions=**/__pycache__/**,**/venv/**,.pytest_cache/**
```

**src/calculator.py:**
```python
import os

class Calculator:
    """Sample calculator class with various code quality issues"""
    
    # VULNERABILITY: Hardcoded secret
    SECRET_KEY = "secret-key-123"
    
    def add(self, a, b):
        """BUG: No type checking or validation"""
        return a + b  # Can fail with incompatible types
    
    def divide(self, a, b):
        """BUG: No zero division check"""
        return a / b  # ZeroDivisionError possible
    
    def calculate_circle_area(self, radius):
        """CODE SMELL: Magic number"""
        return 3.14159 * radius * radius  # Magic number
    
    # VULNERABILITY: SQL injection risk (simulated)
    def get_user_data(self, user_id):
        """Simulated SQL injection vulnerability"""
        query = f"SELECT * FROM users WHERE id = {user_id}"  # Dangerous!
        return query
    
    # CODE SMELL: Complex method
    def process_data(self, data):
        """Overly complex method with high cognitive complexity"""
        result = []
        if data:
            if isinstance(data, list):
                for item in data:
                    if item:
                        if isinstance(item, dict):
                            if 'value' in item:
                                if item['value'] > 0:
                                    if item['value'] < 1000:
                                        result.append(item['value'] * 2)
        return result
    
    # BUG: Resource not closed
    def read_file(self, filename):
        """Resource leak - file not properly closed"""
        file = open(filename, 'r')  # Not using context manager
        content = file.read()
        # Missing file.close()
        return content
```

**tests/test_calculator.py:**
```python
import pytest
from src.calculator import Calculator

class TestCalculator:
    def setup_method(self):
        self.calculator = Calculator()
    
    def test_add(self):
        assert self.calculator.add(2, 3) == 5
    
    def test_calculate_circle_area(self):
        result = self.calculator.calculate_circle_area(1)
        assert 3.0 < result < 3.2
    
    # Missing tests for other methods
    # Low test coverage will be reported
```

## Step 3: Run Analysis

### Java with Maven

```bash
cd java-sample

# Run tests and generate coverage
mvn clean test

# Run SonarQube analysis
mvn sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE
```

### JavaScript with SonarScanner

```bash
cd javascript-sample

# Install dependencies
npm install

# Run tests with coverage
npm test

# Run SonarQube analysis
npx sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE
```

### Python with SonarScanner

```bash
cd python-sample

# Install dependencies (if any)
pip install pytest pytest-cov

# Run tests with coverage
pytest --cov=src --cov-report=xml

# Run SonarQube analysis
sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE
```

### Generic Project with SonarScanner

For any project without specific build tool integration:

```bash
sonar-scanner \
  -Dsonar.projectKey=my-project \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_TOKEN_HERE
```

## Step 4: View Results

1. **Go to SonarQube Dashboard**
   - Open `http://localhost:9000`
   - Click on your project

2. **Explore the Overview**
   - Quality Gate status
   - New code vs Overall code metrics
   - Issues breakdown by type

3. **Review Issues**
   - Click "Issues" tab
   - Filter by type: Bugs, Vulnerabilities, Code Smells
   - Click on individual issues to see details

4. **Check Coverage**
   - Look at test coverage percentage
   - Identify uncovered lines

## Step 5: Understanding the Results

### Expected Results for Sample Projects

**Java Project:**
- **Bugs**: 2-3 (NPE risk, division by zero)
- **Vulnerabilities**: 1 (unvalidated input)
- **Code Smells**: 4-5 (magic numbers, duplication, complexity)
- **Coverage**: ~40% (missing tests)

**JavaScript Project:**
- **Bugs**: 2-3 (unused variable, no error handling)
- **Vulnerabilities**: 2 (XSS, hardcoded credentials)
- **Code Smells**: 2-3 (magic numbers, complexity)
- **Coverage**: ~50%

**Python Project:**
- **Bugs**: 3-4 (type errors, resource leak, division by zero)
- **Vulnerabilities**: 2 (hardcoded secret, SQL injection pattern)
- **Code Smells**: 2-3 (magic numbers, complexity)
- **Coverage**: ~40%

### Key Metrics Explained

1. **Reliability**: Bugs that could cause runtime failures
2. **Security**: Vulnerabilities that could be exploited
3. **Maintainability**: Code smells affecting long-term maintenance
4. **Coverage**: Percentage of code tested by unit tests
5. **Duplication**: Percentage of duplicated code blocks

## Step 6: Fix Issues

Let's fix one issue from each category:

### Fix a Bug (Java NPE):

**Before:**
```java
public int add(Integer a, Integer b) {
    return a + b; // Potential NPE
}
```

**After:**
```java
public int add(Integer a, Integer b) {
    if (a == null || b == null) {
        throw new IllegalArgumentException("Parameters cannot be null");
    }
    return a + b;
}
```

### Fix a Vulnerability (JavaScript XSS):

**Before:**
```javascript
function displayMessage(message) {
    document.getElementById('output').innerHTML = message; // Dangerous!
}
```

**After:**
```javascript
function displayMessage(message) {
    document.getElementById('output').textContent = message; // Safe!
}
```

### Fix a Code Smell (Python magic number):

**Before:**
```python
def calculate_circle_area(self, radius):
    return 3.14159 * radius * radius  # Magic number
```

**After:**
```python
PI = 3.14159  # Named constant

def calculate_circle_area(self, radius):
    return self.PI * radius * radius
```

## Step 7: Re-run Analysis

After fixing issues, run the analysis again to see improvements:

```bash
# Re-run the appropriate command from Step 3
# You should see fewer issues in the new analysis
```

## Troubleshooting

### Common Issues

1. **Scanner not found:**
```bash
# Install SonarScanner
# On macOS:
brew install sonar-scanner

# On Linux:
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
unzip sonar-scanner-cli-4.8.0.2856-linux.zip
export PATH=$PATH:/path/to/sonar-scanner-4.8.0.2856-linux/bin
```

2. **Authentication failed:**
```bash
# Check your token is correct
# Regenerate token if needed from SonarQube web interface
```

3. **Analysis fails:**
```bash
# Check SonarQube logs
docker-compose logs sonarqube

# Verify project key doesn't contain special characters
# Check sonar-project.properties syntax
```

4. **No coverage data:**
```bash
# Ensure test coverage is generated before analysis
# Check coverage file paths in sonar-project.properties
# Verify coverage format is supported (JaCoCo, LCOV, Cobertura, etc.)
```

## Best Practices

1. **Regular Analysis**: Run analysis on every commit or at least daily
2. **Quality Gates**: Set up gates to prevent poor quality code from deployment
3. **Team Review**: Review issues as a team, not just individual developers
4. **Incremental Improvement**: Focus on "New Code" to prevent quality regression
5. **Custom Rules**: Adapt rules to your team's coding standards
6. **Documentation**: Document decisions about accepted technical debt

## Next Steps

Now that you've completed your first analysis:

1. **Explore the Dashboard**: [Understanding the Dashboard](02-understanding-dashboard.md)
2. **Set up Quality Gates**: [Quality Gates](04-quality-gates.md)
3. **Integrate with CI/CD**: [CI/CD Integration](../05-advanced/03-cicd-integration.md)

## Assignment

**Practice Exercise:**

1. Create a project in your preferred language
2. Introduce 2-3 bugs, 1-2 vulnerabilities, and several code smells
3. Run SonarQube analysis
4. Fix all critical and major issues
5. Improve test coverage to >80%
6. Re-run analysis and verify improvements

**Success Criteria:**
- Zero bugs and vulnerabilities
- <30 minutes technical debt
- >80% test coverage
- Quality gate passes