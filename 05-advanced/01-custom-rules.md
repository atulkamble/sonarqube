# Custom Rules Development

Learn how to create custom SonarQube rules to enforce your organization's specific coding standards.

## Overview

While SonarQube comes with hundreds of built-in rules, you might need custom rules for:
- Organization-specific coding standards
- Domain-specific requirements
- Legacy code patterns to avoid
- Security requirements unique to your environment
- Performance patterns specific to your architecture

## Rule Development Approaches

### 1. Template Rules (Easiest)
Customize existing rule templates through the web interface.

### 2. Custom Plugin Development (Most Flexible)
Create a complete plugin with custom rules using the SonarQube Plugin API.

### 3. External Rule Import
Import rules from external tools like PMD, Checkstyle, or ESLint.

## Template Rules

### Creating Template Rules via Web Interface

1. **Access Rule Templates**
   - Go to Administration → Rules
   - Filter by "Template" = "Yes"
   - Select a template rule

2. **Create Custom Rule**
   - Click "Create" button
   - Fill in rule details:
     - Name: Descriptive name
     - Key: Unique identifier
     - Description: Detailed explanation
     - Parameters: Configure rule behavior

### Example: Custom Naming Convention Rule

**Java Method Naming Template:**
```
Template: "Method names should comply with a naming convention"
Custom Rule Name: "Service methods must start with 'handle'"
Pattern: handle[A-Z][a-zA-Z0-9]*
Message: "Service methods should start with 'handle' followed by PascalCase"
```

**Usage in Code:**
```java
// ✅ Compliant
public class UserService {
    public void handleUserRegistration() { }
    public User handleUserRetrieval(String id) { }
}

// ❌ Non-compliant - will trigger custom rule
public class UserService {
    public void registerUser() { }        // Should be handleUserRegistration
    public User getUser(String id) { }   // Should be handleUserRetrieval
}
```

## Custom Plugin Development

### Setting Up Development Environment

**Prerequisites:**
- Java 11+
- Maven 3.6+
- SonarQube Developer Edition or Community Edition

**Create Plugin Project:**
```bash
mvn archetype:generate \
  -DgroupId=com.company.sonar \
  -DartifactId=custom-rules-plugin \
  -DarchetypeGroupId=org.sonarsource.sonarqube-plugins \
  -DarchetypeArtifactId=sonar-plugin-archetype \
  -DarchetypeVersion=1.0
```

### Plugin Structure

```
custom-rules-plugin/
├── pom.xml
└── src/
    └── main/
        ├── java/
        │   └── com/company/sonar/
        │       ├── CustomRulesPlugin.java
        │       ├── CustomRulesDefinition.java
        │       └── checks/
        │           ├── AbstractBaseCheck.java
        │           ├── NoSystemOutPrintlnCheck.java
        │           └── RequiredJavadocCheck.java
        └── resources/
            └── org/sonar/l10n/java/rules/custom/
                ├── NoSystemOutPrintlnCheck.html
                └── RequiredJavadocCheck.html
```

### Example 1: No System.out.println Rule

**NoSystemOutPrintlnCheck.java:**
```java
package com.company.sonar.checks;

import org.sonar.check.Rule;
import org.sonar.plugins.java.api.IssuableSubscriptionVisitor;
import org.sonar.plugins.java.api.tree.*;
import java.util.Collections;
import java.util.List;

@Rule(key = "NoSystemOutPrintln")
public class NoSystemOutPrintlnCheck extends IssuableSubscriptionVisitor {
    
    @Override
    public List<Tree.Kind> nodesToVisit() {
        return Collections.singletonList(Tree.Kind.METHOD_INVOCATION);
    }
    
    @Override
    public void visitNode(Tree tree) {
        MethodInvocationTree methodCall = (MethodInvocationTree) tree;
        
        if (isSystemOutPrintCall(methodCall)) {
            reportIssue(methodCall, 
                "Remove this usage of System.out.println(). Use a proper logging framework instead.");
        }
    }
    
    private boolean isSystemOutPrintCall(MethodInvocationTree methodCall) {
        ExpressionTree methodSelect = methodCall.methodSelect();
        
        if (methodSelect.is(Tree.Kind.MEMBER_SELECT)) {
            MemberSelectExpressionTree memberSelect = (MemberSelectExpressionTree) methodSelect;
            String methodName = memberSelect.identifier().name();
            
            if ("println".equals(methodName) || "print".equals(methodName)) {
                ExpressionTree expression = memberSelect.expression();
                if (expression.is(Tree.Kind.MEMBER_SELECT)) {
                    MemberSelectExpressionTree systemOut = (MemberSelectExpressionTree) expression;
                    return "out".equals(systemOut.identifier().name()) && 
                           isSystemClass(systemOut.expression());
                }
            }
        }
        return false;
    }
    
    private boolean isSystemClass(ExpressionTree expression) {
        if (expression.is(Tree.Kind.IDENTIFIER)) {
            IdentifierTree identifier = (IdentifierTree) expression;
            return "System".equals(identifier.name());
        }
        return false;
    }
}
```

**Rule Description (NoSystemOutPrintlnCheck.html):**
```html
<p>
Using <code>System.out.println()</code> in production code is considered bad practice because:
</p>
<ul>
    <li>It cannot be configured or disabled</li>
    <li>It doesn't provide log levels</li>
    <li>It's not suitable for production environments</li>
    <li>It cannot be redirected to files or external systems</li>
</ul>

<h2>Noncompliant Code Example</h2>
<pre>
public void processUser(User user) {
    System.out.println("Processing user: " + user.getName()); // Noncompliant
    // ... processing logic
}
</pre>

<h2>Compliant Solution</h2>
<pre>
private static final Logger logger = LoggerFactory.getLogger(UserService.class);

public void processUser(User user) {
    logger.info("Processing user: {}", user.getName()); // Compliant
    // ... processing logic
}
</pre>
```

### Example 2: Required Javadoc Rule

**RequiredJavadocCheck.java:**
```java
package com.company.sonar.checks;

import org.sonar.check.Rule;
import org.sonar.check.RuleProperty;
import org.sonar.plugins.java.api.IssuableSubscriptionVisitor;
import org.sonar.plugins.java.api.tree.*;
import java.util.Arrays;
import java.util.List;

@Rule(key = "RequiredJavadoc")
public class RequiredJavadocCheck extends IssuableSubscriptionVisitor {
    
    @RuleProperty(
        key = "minimumVisibility",
        description = "Minimum visibility level requiring Javadoc",
        defaultValue = "PUBLIC"
    )
    public String minimumVisibility = "PUBLIC";
    
    @RuleProperty(
        key = "checkMethods",
        description = "Check methods for Javadoc",
        defaultValue = "true"
    )
    public boolean checkMethods = true;
    
    @RuleProperty(
        key = "checkClasses",
        description = "Check classes for Javadoc", 
        defaultValue = "true"
    )
    public boolean checkClasses = true;
    
    @Override
    public List<Tree.Kind> nodesToVisit() {
        return Arrays.asList(
            Tree.Kind.METHOD,
            Tree.Kind.CONSTRUCTOR,
            Tree.Kind.CLASS,
            Tree.Kind.INTERFACE
        );
    }
    
    @Override
    public void visitNode(Tree tree) {
        if (tree.is(Tree.Kind.METHOD, Tree.Kind.CONSTRUCTOR)) {
            if (checkMethods) {
                checkMethodDocumentation((MethodTree) tree);
            }
        } else if (tree.is(Tree.Kind.CLASS, Tree.Kind.INTERFACE)) {
            if (checkClasses) {
                checkClassDocumentation((ClassTree) tree);
            }
        }
    }
    
    private void checkMethodDocumentation(MethodTree method) {
        if (shouldCheckVisibility(method.modifiers()) && !hasJavadoc(method)) {
            String methodType = method.is(Tree.Kind.CONSTRUCTOR) ? "Constructor" : "Method";
            reportIssue(method.simpleName(), 
                methodType + " should have Javadoc documentation.");
        }
    }
    
    private void checkClassDocumentation(ClassTree classTree) {
        if (shouldCheckVisibility(classTree.modifiers()) && !hasJavadoc(classTree)) {
            String classType = classTree.is(Tree.Kind.INTERFACE) ? "Interface" : "Class";
            reportIssue(classTree.simpleName(), 
                classType + " should have Javadoc documentation.");
        }
    }
    
    private boolean shouldCheckVisibility(ModifiersTree modifiers) {
        switch (minimumVisibility.toUpperCase()) {
            case "PRIVATE":
                return true;
            case "PACKAGE":
                return !modifiers.has(Modifier.PRIVATE);
            case "PROTECTED":
                return modifiers.has(Modifier.PUBLIC) || modifiers.has(Modifier.PROTECTED);
            case "PUBLIC":
            default:
                return modifiers.has(Modifier.PUBLIC);
        }
    }
    
    private boolean hasJavadoc(Tree tree) {
        // Check if the tree has Javadoc comments
        return tree.firstToken().trivias().stream()
            .anyMatch(trivia -> trivia.comment().startsWith("/**"));
    }
}
```

### Example 3: Security Rule - No Hardcoded Passwords

**NoHardcodedPasswordsCheck.java:**
```java
package com.company.sonar.checks;

import org.sonar.check.Rule;
import org.sonar.plugins.java.api.IssuableSubscriptionVisitor;
import org.sonar.plugins.java.api.tree.*;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Pattern;

@Rule(key = "NoHardcodedPasswords")
public class NoHardcodedPasswordsCheck extends IssuableSubscriptionVisitor {
    
    private static final Pattern PASSWORD_PATTERN = Pattern.compile(
        "(?i).*(password|passwd|pwd|secret|key|token).*"
    );
    
    private static final List<String> SUSPICIOUS_VARIABLE_NAMES = Arrays.asList(
        "password", "passwd", "pwd", "secret", "apikey", "secretkey", "token", "auth"
    );
    
    @Override
    public List<Tree.Kind> nodesToVisit() {
        return Arrays.asList(
            Tree.Kind.VARIABLE,
            Tree.Kind.ASSIGNMENT_EXPRESSION
        );
    }
    
    @Override
    public void visitNode(Tree tree) {
        if (tree.is(Tree.Kind.VARIABLE)) {
            checkVariableDeclaration((VariableTree) tree);
        } else if (tree.is(Tree.Kind.ASSIGNMENT_EXPRESSION)) {
            checkAssignment((AssignmentExpressionTree) tree);
        }
    }
    
    private void checkVariableDeclaration(VariableTree variable) {
        String variableName = variable.simpleName().name().toLowerCase();
        
        if (isSuspiciousVariableName(variableName)) {
            ExpressionTree initializer = variable.initializer();
            if (initializer != null && isHardcodedString(initializer)) {
                reportIssue(variable, 
                    "Hardcoded password/secret detected. Use configuration or environment variables instead.");
            }
        }
    }
    
    private void checkAssignment(AssignmentExpressionTree assignment) {
        ExpressionTree variable = assignment.variable();
        if (variable.is(Tree.Kind.IDENTIFIER)) {
            String variableName = ((IdentifierTree) variable).name().toLowerCase();
            
            if (isSuspiciousVariableName(variableName) && isHardcodedString(assignment.expression())) {
                reportIssue(assignment, 
                    "Hardcoded password/secret detected. Use configuration or environment variables instead.");
            }
        }
    }
    
    private boolean isSuspiciousVariableName(String name) {
        return SUSPICIOUS_VARIABLE_NAMES.stream()
            .anyMatch(suspicious -> name.contains(suspicious));
    }
    
    private boolean isHardcodedString(ExpressionTree expression) {
        if (expression.is(Tree.Kind.STRING_LITERAL)) {
            LiteralTree literal = (LiteralTree) expression;
            String value = literal.value();
            
            // Remove quotes and check if it looks like a real secret
            String cleanValue = value.substring(1, value.length() - 1);
            return cleanValue.length() > 6 && !isPlaceholderValue(cleanValue);
        }
        return false;
    }
    
    private boolean isPlaceholderValue(String value) {
        String lowerValue = value.toLowerCase();
        return lowerValue.equals("password") || 
               lowerValue.equals("secret") ||
               lowerValue.equals("your_password_here") ||
               lowerValue.equals("changeme") ||
               lowerValue.startsWith("${") || // Environment variable placeholder
               lowerValue.startsWith("{{"); // Template placeholder
    }
}
```

### Plugin Configuration

**CustomRulesDefinition.java:**
```java
package com.company.sonar;

import com.company.sonar.checks.*;
import org.sonar.api.server.rule.RulesDefinition;
import org.sonar.plugins.java.Java;
import org.sonarsource.analyzer.commons.RuleMetadataLoader;

import java.util.Arrays;
import java.util.List;

public class CustomRulesDefinition implements RulesDefinition {
    
    public static final String REPOSITORY_KEY = "custom-java-rules";
    public static final String REPOSITORY_NAME = "Custom Java Rules";
    
    // Rule classes
    private static final List<Class<?>> RULE_CLASSES = Arrays.asList(
        NoSystemOutPrintlnCheck.class,
        RequiredJavadocCheck.class,
        NoHardcodedPasswordsCheck.class
    );
    
    @Override
    public void define(Context context) {
        NewRepository repository = context
            .createRepository(REPOSITORY_KEY, Java.KEY)
            .setName(REPOSITORY_NAME);
            
        // Load rule metadata from resources
        RuleMetadataLoader ruleMetadataLoader = new RuleMetadataLoader(
            "org/sonar/l10n/java/rules/custom"
        );
        
        ruleMetadataLoader.addRulesByClass(repository, RULE_CLASSES);
        
        repository.done();
    }
}
```

**CustomRulesPlugin.java:**
```java
package com.company.sonar;

import org.sonar.api.Plugin;

public class CustomRulesPlugin implements Plugin {
    
    @Override
    public void define(Context context) {
        // Register rule definitions
        context.addExtension(CustomRulesDefinition.class);
        
        // Register rule implementations
        context.addExtension(CustomJavaFileCheckRegistrar.class);
    }
}
```

**pom.xml Configuration:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.company.sonar</groupId>
    <artifactId>custom-rules-plugin</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>sonar-plugin</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <sonar.version>9.4.0.54424</sonar.version>
        <sonar-java.version>7.15.0.30507</sonar-java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.sonarsource.sonarqube</groupId>
            <artifactId>sonar-plugin-api</artifactId>
            <version>${sonar.version}</version>
            <scope>provided</scope>
        </dependency>
        
        <dependency>
            <groupId>org.sonarsource.java</groupId>
            <artifactId>sonar-java-plugin</artifactId>
            <version>${sonar-java.version}</version>
            <scope>provided</scope>
        </dependency>
        
        <!-- Test dependencies -->
        <dependency>
            <groupId>org.sonarsource.java</groupId>
            <artifactId>java-checks-testkit</artifactId>
            <version>${sonar-java.version}</version>
            <scope>test</scope>
        </dependency>
        
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
                <groupId>org.sonarsource.sonar-packaging-maven-plugin</groupId>
                <artifactId>sonar-packaging-maven-plugin</artifactId>
                <version>1.21.0.505</version>
                <extensions>true</extensions>
                <configuration>
                    <pluginKey>custom-java-rules</pluginKey>
                    <pluginName>Custom Java Rules</pluginName>
                    <pluginClass>com.company.sonar.CustomRulesPlugin</pluginClass>
                    <sonarLintSupported>true</sonarLintSupported>
                    <sonarQubeMinVersion>8.9</sonarQubeMinVersion>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

## Testing Custom Rules

### Unit Testing Rules

**NoSystemOutPrintlnCheckTest.java:**
```java
package com.company.sonar.checks;

import org.junit.jupiter.api.Test;
import org.sonar.java.checks.verifier.CheckVerifier;

class NoSystemOutPrintlnCheckTest {
    
    @Test
    void test() {
        CheckVerifier.newVerifier()
            .onFile("src/test/files/NoSystemOutPrintlnCheck.java")
            .withCheck(new NoSystemOutPrintlnCheck())
            .verifyIssues();
    }
}
```

**Test File (src/test/files/NoSystemOutPrintlnCheck.java):**
```java
class TestClass {
    
    void compliantMethod() {
        Logger logger = LoggerFactory.getLogger(TestClass.class);
        logger.info("This is compliant"); // Compliant
    }
    
    void nonCompliantMethod() {
        System.out.println("This is not allowed"); // Noncompliant
        System.out.print("Neither is this"); // Noncompliant
    }
    
    void anotherCompliantMethod() {
        System.currentTimeMillis(); // Compliant - not System.out
        System.getProperty("user.home"); // Compliant
    }
}
```

## JavaScript Custom Rules

### Example: No Console.log Rule

**NoConsoleLogRule.js:**
```javascript
module.exports = {
    meta: {
        type: 'problem',
        docs: {
            description: 'Disallow console.log statements',
            category: 'Best Practices',
            recommended: true
        },
        fixable: 'code',
        schema: []
    },
    
    create(context) {
        return {
            CallExpression(node) {
                if (isConsoleCall(node, 'log')) {
                    context.report({
                        node,
                        message: 'Remove console.log statement. Use a proper logging library.',
                        fix(fixer) {
                            return fixer.remove(node.parent);
                        }
                    });
                }
            }
        };
    }
};

function isConsoleCall(node, methodName) {
    return node.callee &&
           node.callee.type === 'MemberExpression' &&
           node.callee.object &&
           node.callee.object.name === 'console' &&
           node.callee.property &&
           node.callee.property.name === methodName;
}
```

## Python Custom Rules

### Example: No Print Statements Rule

**no_print_statements.py:**
```python
import ast
from typing import List

class NoPrintStatementsChecker(ast.NodeVisitor):
    """Custom rule to detect print() statements in production code."""
    
    def __init__(self):
        self.issues: List[dict] = []
    
    def visit_Call(self, node: ast.Call) -> None:
        """Visit function call nodes."""
        if (isinstance(node.func, ast.Name) and 
            node.func.id == 'print'):
            
            self.issues.append({
                'line': node.lineno,
                'column': node.col_offset,
                'message': 'Remove print() statement. Use logging instead.',
                'rule': 'no-print-statements',
                'severity': 'MAJOR'
            })
        
        self.generic_visit(node)
    
    def check_file(self, file_path: str) -> List[dict]:
        """Check a Python file for print statements."""
        with open(file_path, 'r', encoding='utf-8') as f:
            try:
                tree = ast.parse(f.read(), filename=file_path)
                self.visit(tree)
                return self.issues
            except SyntaxError as e:
                return [{
                    'line': e.lineno or 0,
                    'column': e.offset or 0,
                    'message': f'Syntax error: {e.msg}',
                    'rule': 'syntax-error',
                    'severity': 'BLOCKER'
                }]
```

## Deploying Custom Rules

### Building and Installing Plugin

```bash
# Build the plugin
mvn clean package

# Copy to SonarQube plugins directory
cp target/custom-rules-plugin-1.0-SNAPSHOT.jar \
   /path/to/sonarqube/extensions/plugins/

# Restart SonarQube
docker-compose restart sonarqube
```

### Enabling Custom Rules

1. **Go to Quality Profiles**
   - Administration → Quality Profiles
   - Select your language profile (e.g., "Sonar way")

2. **Activate Custom Rules**
   - Click "Activate More" 
   - Search for your custom repository
   - Select and activate desired rules

3. **Create Custom Quality Profile**
   - Copy existing profile
   - Add/remove rules as needed
   - Set as default for projects

## Best Practices for Custom Rules

### 1. Rule Design Principles

```java
// ✅ Good Rule Design
@Rule(key = "SpecificBusinessLogic")
public class SpecificBusinessLogicCheck extends IssuableSubscriptionVisitor {
    
    @RuleProperty(
        key = "allowedPatterns",
        description = "Comma-separated list of allowed patterns",
        defaultValue = "handle.*,process.*"
    )
    public String allowedPatterns = "handle.*,process.*";
    
    // Clear, specific, actionable rule logic
}

// ❌ Poor Rule Design
@Rule(key = "BadCode")  // Too generic
public class BadCodeCheck extends IssuableSubscriptionVisitor {
    // Vague, hard to understand rule
}
```

### 2. Performance Considerations

```java
// ✅ Efficient Rule Implementation
public class EfficientCheck extends IssuableSubscriptionVisitor {
    
    private static final Set<String> FORBIDDEN_METHODS = 
        Set.of("System.exit", "Runtime.halt");
    
    @Override
    public List<Tree.Kind> nodesToVisit() {
        // Only visit nodes we care about
        return Collections.singletonList(Tree.Kind.METHOD_INVOCATION);
    }
    
    @Override
    public void visitNode(Tree tree) {
        // Fast checks first
        MethodInvocationTree method = (MethodInvocationTree) tree;
        String methodName = getMethodName(method);
        
        if (FORBIDDEN_METHODS.contains(methodName)) {
            // Expensive checks only when necessary
            if (isSystemClass(method)) {
                reportIssue(method, "Don't use system exit methods");
            }
        }
    }
}
```

### 3. Comprehensive Testing

```java
@Test
void should_detect_all_variants() {
    CheckVerifier.newVerifier()
        .onFile("src/test/files/AllVariants.java")
        .withCheck(new MyCustomCheck())
        .verifyIssues();
}

@Test
void should_not_trigger_false_positives() {
    CheckVerifier.newVerifier()
        .onFile("src/test/files/ValidCases.java") 
        .withCheck(new MyCustomCheck())
        .verifyNoIssues();
}
```

### 4. Clear Documentation

```html
<!-- Rule description should include -->
<h2>Why is this an issue?</h2>
<p>Explain the problem and impact...</p>

<h2>How to fix it</h2>
<p>Provide clear fix instructions...</p>

<h2>Code examples</h2>
<h3>Noncompliant code example</h3>
<pre>// Bad code example</pre>

<h3>Compliant solution</h3>
<pre>// Good code example</pre>
```

## Next Steps

1. **Advanced Plugin Development**: [Plugin Development Guide](02-plugins-development.md)
2. **CI/CD Integration**: [Automated Rule Enforcement](03-cicd-integration.md)
3. **Team Adoption**: [Best Practices](../06-best-practices/01-best-practices.md)

## Resources

- [SonarQube Plugin API Documentation](https://docs.sonarqube.org/latest/extend/developing-plugin/)
- [Java AST Explorer](https://github.com/SonarSource/sonar-java/tree/master/java-frontend/src/main/java/org/sonar/java/model)
- [SonarSource Plugin Examples](https://github.com/SonarSource/sonar-custom-rules-examples)
- [Rule Writing Guidelines](https://docs.sonarqube.org/latest/extend/adding-coding-rules/)

## Assignment

**Create Your Own Custom Rule:**

1. Identify a coding pattern your team wants to enforce
2. Implement the rule using the appropriate approach
3. Write comprehensive tests
4. Create clear documentation
5. Deploy and test in a development environment
6. Get team feedback and iterate

**Examples to try:**
- Naming conventions for your domain classes
- Required annotations for certain method types
- Forbidden API usage patterns
- Security-sensitive code patterns
- Performance anti-patterns specific to your application