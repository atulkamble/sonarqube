# Hands-On Exercise: Building a Complete SonarQube Workflow

This exercise will guide you through setting up a complete SonarQube workflow from scratch, analyzing real projects, and implementing quality improvements.

## Exercise Overview

**Objective**: Set up SonarQube, analyze multiple projects, fix issues, and establish a quality workflow.

**Time Required**: 3-4 hours

**Skills Practiced**:
- SonarQube installation and configuration
- Multi-language project analysis
- Issue identification and resolution
- Quality gate configuration
- CI/CD integration
- Custom rules creation

## Part 1: Environment Setup (30 minutes)

### Step 1: Install SonarQube with Docker

1. **Create project directory**:
```bash
mkdir sonarqube-exercise
cd sonarqube-exercise
```

2. **Create docker-compose.yml**:
```yaml
version: "3.8"
services:
  sonarqube:
    image: sonarqube:lts-community
    container_name: sonarqube-exercise
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

  db:
    image: postgres:13
    container_name: postgresql-exercise
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgresql_data:/var/lib/postgresql/data

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql_data:
```

3. **Start SonarQube**:
```bash
docker-compose up -d
# Wait for startup (check logs)
docker-compose logs -f sonarqube
```

4. **Verify installation**:
   - Open http://localhost:9000
   - Login: admin/admin
   - Change password when prompted

### Step 2: Install SonarScanner

**macOS**:
```bash
brew install sonar-scanner
```

**Linux**:
```bash
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
unzip sonar-scanner-cli-4.8.0.2856-linux.zip
sudo mv sonar-scanner-4.8.0.2856-linux /opt/sonar-scanner
echo 'export PATH="/opt/sonar-scanner/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Windows**:
```bash
# Download and extract from https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/
# Add bin directory to PATH
```

## Part 2: Create Sample Projects (45 minutes)

We'll create three projects with intentional code quality issues.

### Project 1: Java E-commerce Service

```bash
mkdir java-ecommerce
cd java-ecommerce
```

**pom.xml**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>ecommerce-service</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <sonar.projectKey>java-ecommerce</sonar.projectKey>
        <sonar.projectName>Java E-commerce Service</sonar.projectName>
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
            <plugin>
                <groupId>org.sonarsource.scanner.maven</groupId>
                <artifactId>sonar-maven-plugin</artifactId>
                <version>3.9.1.2184</version>
            </plugin>
        </plugins>
    </build>
</project>
```

**src/main/java/com/example/ecommerce/service/OrderService.java**:
```java
package com.example.ecommerce.service;

import java.util.*;
import java.sql.*;

public class OrderService {
    
    private String dbPassword = "admin123"; // VULNERABILITY: Hardcoded password
    private Connection connection;
    
    // BUG: Resource leak - connection not closed
    public void connectToDatabase() throws SQLException {
        connection = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/ecommerce", "admin", dbPassword);
    }
    
    // VULNERABILITY: SQL Injection
    public List<Order> getOrdersByUserId(String userId) throws SQLException {
        String sql = "SELECT * FROM orders WHERE user_id = " + userId;
        Statement stmt = connection.createStatement();
        ResultSet rs = stmt.executeQuery(sql);
        
        List<Order> orders = new ArrayList<>();
        while (rs.next()) {
            Order order = new Order();
            order.setId(rs.getInt("id"));
            order.setUserId(rs.getString("user_id"));
            order.setTotal(rs.getDouble("total"));
            orders.add(order);
        }
        return orders;
    }
    
    // CODE SMELL: Method too complex
    public double calculateOrderTotal(Order order, String couponCode, boolean isPremiumCustomer) {
        double total = 0;
        List<OrderItem> items = order.getItems();
        
        if (items != null) {
            for (OrderItem item : items) {
                if (item != null) {
                    if (item.getProduct() != null) {
                        double price = item.getProduct().getPrice();
                        if (price > 0) {
                            int quantity = item.getQuantity();
                            if (quantity > 0) {
                                double itemTotal = price * quantity;
                                if (item.getProduct().getCategory().equals("Electronics")) {
                                    if (quantity > 5) {
                                        itemTotal = itemTotal * 0.95; // 5% bulk discount
                                    }
                                }
                                total += itemTotal;
                            }
                        }
                    }
                }
            }
        }
        
        // Apply tax
        total = total * 1.08; // 8% tax rate (magic number)
        
        // Apply coupon
        if (couponCode != null) {
            if (couponCode.equals("SAVE10")) {
                total = total * 0.9;
            } else if (couponCode.equals("SAVE20")) {
                total = total * 0.8;
            } else if (couponCode.equals("PREMIUM")) {
                if (isPremiumCustomer) {
                    total = total * 0.75;
                }
            }
        }
        
        return total;
    }
    
    // CODE SMELL: Duplicated code
    public void processPaymentWithCreditCard(Order order, String cardNumber) {
        System.out.println("Processing credit card payment...");
        double total = order.getTotal();
        if (total > 0) {
            // Simulate payment processing
            if (cardNumber != null && cardNumber.length() == 16) {
                System.out.println("Payment processed successfully");
                order.setStatus("PAID");
            } else {
                System.out.println("Invalid card number");
                order.setStatus("PAYMENT_FAILED");
            }
        }
    }
    
    // CODE SMELL: Duplicated code (similar to above)
    public void processPaymentWithPayPal(Order order, String email) {
        System.out.println("Processing PayPal payment...");
        double total = order.getTotal();
        if (total > 0) {
            // Simulate payment processing
            if (email != null && email.contains("@")) {
                System.out.println("Payment processed successfully");
                order.setStatus("PAID");
            } else {
                System.out.println("Invalid email");
                order.setStatus("PAYMENT_FAILED");
            }
        }
    }
    
    // BUG: Potential null pointer exception
    public void sendOrderConfirmation(Order order) {
        String customerEmail = order.getCustomer().getEmail(); // NPE risk
        System.out.println("Sending confirmation to: " + customerEmail);
    }
}

// Supporting classes
class Order {
    private int id;
    private String userId;
    private double total;
    private String status;
    private List<OrderItem> items;
    private Customer customer;
    
    // Getters and setters...
    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }
    public double getTotal() { return total; }
    public void setTotal(double total) { this.total = total; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public List<OrderItem> getItems() { return items; }
    public void setItems(List<OrderItem> items) { this.items = items; }
    public Customer getCustomer() { return customer; }
    public void setCustomer(Customer customer) { this.customer = customer; }
}

class OrderItem {
    private Product product;
    private int quantity;
    
    public Product getProduct() { return product; }
    public void setProduct(Product product) { this.product = product; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
}

class Product {
    private double price;
    private String category;
    
    public double getPrice() { return price; }
    public void setPrice(double price) { this.price = price; }
    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
}

class Customer {
    private String email;
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
}
```

**src/test/java/com/example/ecommerce/service/OrderServiceTest.java**:
```java
package com.example.ecommerce.service;

import org.junit.Test;
import static org.junit.Assert.*;

public class OrderServiceTest {
    
    @Test
    public void testCalculateOrderTotal() {
        // Minimal test - low coverage
        OrderService service = new OrderService();
        Order order = new Order();
        double total = service.calculateOrderTotal(order, null, false);
        assertTrue(total >= 0);
    }
    
    // Missing tests for other methods
}
```

### Project 2: JavaScript React Application

```bash
cd ..
mkdir react-todo-app
cd react-todo-app
```

**package.json**:
```json
{
  "name": "react-todo-app",
  "version": "1.0.0",
  "description": "Todo app with code quality issues",
  "main": "src/index.js",
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test --coverage --watchAll=false",
    "sonar": "sonar-scanner"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@testing-library/react": "^13.3.0",
    "@testing-library/jest-dom": "^5.16.4",
    "react-scripts": "5.0.1"
  },
  "jest": {
    "collectCoverageFrom": [
      "src/**/*.{js,jsx}",
      "!src/index.js"
    ]
  }
}
```

**sonar-project.properties**:
```properties
sonar.projectKey=react-todo-app
sonar.projectName=React Todo Application
sonar.projectVersion=1.0.0

sonar.sources=src
sonar.tests=src
sonar.test.inclusions=**/*.test.js,**/*.spec.js

sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.exclusions=node_modules/**,build/**,public/**
```

**src/TodoApp.js**:
```javascript
import React, { useState, useEffect } from 'react';

// VULNERABILITY: Hardcoded API key
const API_KEY = 'sk-1234567890abcdef';

function TodoApp() {
    const [todos, setTodos] = useState([]);
    const [inputValue, setInputValue] = useState('');
    
    // BUG: useEffect with missing dependency
    useEffect(() => {
        console.log('Todos updated:', todos.length); // CODE SMELL: console.log
    }, []); // Missing todos dependency
    
    // VULNERABILITY: XSS vulnerability
    const renderTodo = (todo) => {
        return (
            <div 
                key={todo.id} 
                dangerouslySetInnerHTML={{__html: todo.text}} // Dangerous!
            />
        );
    };
    
    // CODE SMELL: Function too complex
    const handleAddTodo = () => {
        if (inputValue) {
            if (inputValue.length > 0) {
                if (inputValue.trim().length > 0) {
                    if (!todos.some(todo => todo.text === inputValue)) {
                        if (todos.length < 100) {
                            const newTodo = {
                                id: Date.now(), // BUG: Not unique enough
                                text: inputValue,
                                completed: false,
                                createdAt: new Date(),
                                priority: 'medium'
                            };
                            setTodos(prevTodos => [...prevTodos, newTodo]);
                            setInputValue('');
                        } else {
                            alert('Too many todos!'); // CODE SMELL: alert usage
                        }
                    } else {
                        alert('Todo already exists!');
                    }
                } else {
                    alert('Todo cannot be empty!');
                }
            }
        }
    };
    
    // BUG: No error handling
    const saveTodosToServer = async () => {
        const response = await fetch('/api/todos', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${API_KEY}` // Using hardcoded key
            },
            body: JSON.stringify(todos)
        });
        const result = await response.json(); // No error handling
        return result;
    };
    
    // CODE SMELL: Magic numbers
    const getPriorityColor = (priority) => {
        switch (priority) {
            case 'high':
                return '#ff4444'; // Magic color value
            case 'medium':
                return '#ffaa44';
            case 'low':
                return '#44ff44';
            default:
                return '#cccccc';
        }
    };
    
    // BUG: Mutation of props/state
    const toggleTodo = (id) => {
        const todo = todos.find(t => t.id === id);
        todo.completed = !todo.completed; // Direct mutation
        setTodos([...todos]); // Force re-render
    };
    
    // CODE SMELL: Duplicated code
    const markAllCompleted = () => {
        const updatedTodos = todos.map(todo => ({
            ...todo,
            completed: true
        }));
        setTodos(updatedTodos);
    };
    
    // CODE SMELL: Duplicated code (similar logic)
    const markAllIncomplete = () => {
        const updatedTodos = todos.map(todo => ({
            ...todo,
            completed: false
        }));
        setTodos(updatedTodos);
    };
    
    var unusedVariable = 'This is never used'; // BUG: Unused variable
    
    return (
        <div>
            <h1>Todo App</h1>
            <input 
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleAddTodo()}
            />
            <button onClick={handleAddTodo}>Add Todo</button>
            <button onClick={saveTodosToServer}>Save to Server</button>
            
            <div>
                {todos.map(renderTodo)} {/* Using vulnerable render method */}
            </div>
            
            <div>
                <button onClick={markAllCompleted}>Mark All Completed</button>
                <button onClick={markAllIncomplete}>Mark All Incomplete</button>
            </div>
        </div>
    );
}

export default TodoApp;
```

**src/TodoApp.test.js**:
```javascript
import React from 'react';
import { render, screen } from '@testing-library/react';
import TodoApp from './TodoApp';

test('renders todo app title', () => {
  render(<TodoApp />);
  const titleElement = screen.getByText(/Todo App/i);
  expect(titleElement).toBeInTheDocument();
});

// Missing tests for other functionality - low coverage
```

### Project 3: Python Data Processor

```bash
cd ..
mkdir python-data-processor
cd python-data-processor
```

**sonar-project.properties**:
```properties
sonar.projectKey=python-data-processor
sonar.projectName=Python Data Processor
sonar.projectVersion=1.0.0

sonar.sources=src
sonar.tests=tests

sonar.python.coverage.reportPaths=coverage.xml
sonar.exclusions=**/__pycache__/**,venv/**
```

**src/data_processor.py**:
```python
import os
import json
import sqlite3
import requests
from typing import List, Dict, Any

class DataProcessor:
    """Data processor with various code quality issues"""
    
    # VULNERABILITY: Hardcoded credentials
    DATABASE_PASSWORD = "secret123"
    API_SECRET = "api-key-xyz789"
    
    def __init__(self, db_path: str = "data.db"):
        self.db_path = db_path
        self.connection = None
    
    # BUG: Resource leak - connection not properly closed
    def connect_to_database(self):
        """Connect to SQLite database"""
        self.connection = sqlite3.connect(self.db_path)
        return self.connection
    
    # VULNERABILITY: SQL injection
    def get_user_data(self, user_id: str) -> List[Dict]:
        """Get user data - vulnerable to SQL injection"""
        query = f"SELECT * FROM users WHERE id = {user_id}"  # Dangerous!
        cursor = self.connection.cursor()
        cursor.execute(query)
        return cursor.fetchall()
    
    # CODE SMELL: Method too complex (high cognitive complexity)
    def process_user_records(self, records: List[Dict]) -> List[Dict]:
        """Process user records with overly complex logic"""
        processed_records = []
        
        for record in records:
            if record:
                if 'user_data' in record:
                    if record['user_data']:
                        user_data = record['user_data']
                        if 'age' in user_data:
                            if user_data['age'] > 0:
                                if user_data['age'] < 150:
                                    if 'email' in user_data:
                                        if '@' in user_data['email']:
                                            if 'status' in record:
                                                if record['status'] == 'active':
                                                    if 'subscription' in record:
                                                        if record['subscription'] in ['premium', 'basic']:
                                                            processed_records.append({
                                                                'id': record.get('id'),
                                                                'email': user_data['email'],
                                                                'age_group': self._get_age_group(user_data['age']),
                                                                'subscription': record['subscription']
                                                            })
        return processed_records
    
    def _get_age_group(self, age: int) -> str:
        """Determine age group with magic numbers"""
        if age < 18:  # Magic number
            return 'minor'
        elif age < 35:  # Magic number
            return 'young_adult'
        elif age < 65:  # Magic number
            return 'adult'
        else:
            return 'senior'
    
    # BUG: Exception handling too broad
    def load_data_from_api(self, endpoint: str) -> Dict[str, Any]:
        """Load data from API with poor error handling"""
        try:
            url = f"https://api.example.com/{endpoint}"
            headers = {'Authorization': f'Bearer {self.API_SECRET}'}
            
            response = requests.get(url, headers=headers)
            return response.json()  # No status code check
            
        except Exception:  # Too broad exception handling
            print("Something went wrong")  # Poor logging
            return {}
    
    # CODE SMELL: Duplicated code
    def save_users_to_file(self, users: List[Dict], filename: str):
        """Save users to JSON file"""
        try:
            with open(filename, 'w') as f:
                json.dump(users, f, indent=2)
            print(f"Users saved to {filename}")
        except IOError as e:
            print(f"Error saving users: {e}")
    
    # CODE SMELL: Duplicated code (similar to above)
    def save_products_to_file(self, products: List[Dict], filename: str):
        """Save products to JSON file"""
        try:
            with open(filename, 'w') as f:
                json.dump(products, f, indent=2)
            print(f"Products saved to {filename}")
        except IOError as e:
            print(f"Error saving products: {e}")
    
    # BUG: Mutable default argument
    def filter_records(self, records: List[Dict], filters: Dict = {}) -> List[Dict]:
        """Filter records with mutable default argument"""
        filtered = []
        for record in records:
            matches = True
            for key, value in filters.items():
                if record.get(key) != value:
                    matches = False
                    break
            if matches:
                filtered.append(record)
        return filtered
    
    # BUG: No input validation
    def calculate_average_age(self, users: List[Dict]) -> float:
        """Calculate average age without validation"""
        total_age = sum(user['age'] for user in users)  # KeyError risk
        return total_age / len(users)  # ZeroDivisionError risk
    
    # PERFORMANCE: Inefficient algorithm
    def find_duplicates(self, items: List[str]) -> List[str]:
        """Find duplicates with O(n²) complexity"""
        duplicates = []
        for i in range(len(items)):
            for j in range(i + 1, len(items)):
                if items[i] == items[j] and items[i] not in duplicates:
                    duplicates.append(items[i])
        return duplicates
    
    # BUG: Resource not closed in finally block
    def read_config_file(self, filename: str) -> Dict:
        """Read configuration file with resource leak"""
        file_handle = None
        try:
            file_handle = open(filename, 'r')
            return json.load(file_handle)
        except FileNotFoundError:
            return {}
        # Missing finally block to close file

# CODE SMELL: Class too large (should be split into multiple classes)
class DataValidator:
    """Additional class that makes the file too large"""
    
    @staticmethod
    def validate_email(email: str) -> bool:
        """Basic email validation"""
        return '@' in email and '.' in email
    
    @staticmethod 
    def validate_age(age: int) -> bool:
        """Age validation with magic numbers"""
        return 0 < age < 150  # Magic numbers
    
    # More methods would make this class and file even larger...

# BUG: Unreachable code
def unreachable_function():
    """This function is never called"""
    return "This code is unreachable"
    print("This line is unreachable")  # Unreachable code

if __name__ == "__main__":
    processor = DataProcessor()
    processor.connect_to_database()
    
    # Example usage with potential issues
    sample_data = [
        {'id': 1, 'user_data': {'age': 25, 'email': 'user@example.com'}, 'status': 'active', 'subscription': 'premium'}
    ]
    
    result = processor.process_user_records(sample_data)
    print(f"Processed {len(result)} records")
```

**tests/test_data_processor.py**:
```python
import unittest
from src.data_processor import DataProcessor, DataValidator

class TestDataProcessor(unittest.TestCase):
    
    def setUp(self):
        self.processor = DataProcessor()
    
    def test_get_age_group(self):
        """Test age group calculation"""
        self.assertEqual(self.processor._get_age_group(16), 'minor')
        self.assertEqual(self.processor._get_age_group(25), 'young_adult')
    
    def test_email_validation(self):
        """Test email validation"""
        validator = DataValidator()
        self.assertTrue(validator.validate_email('test@example.com'))
        self.assertFalse(validator.validate_email('invalid-email'))
    
    # Missing tests for other methods - low coverage

if __name__ == '__main__':
    unittest.main()
```

## Part 3: Initial Analysis (45 minutes)

### Step 1: Create Projects in SonarQube

1. **Login to SonarQube** (http://localhost:9000)
2. **Generate tokens** for each project:
   - Go to My Account → Security → Generate Tokens
   - Create three tokens: `java-token`, `react-token`, `python-token`

### Step 2: Run Initial Analysis

**Java Project**:
```bash
cd java-ecommerce
mvn clean test sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_JAVA_TOKEN
```

**React Project**:
```bash
cd ../react-todo-app
npm install
npm test
npx sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_REACT_TOKEN
```

**Python Project**:
```bash
cd ../python-data-processor
pip install requests pytest pytest-cov
python -m pytest tests/ --cov=src --cov-report=xml
sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_PYTHON_TOKEN
```

### Step 3: Review Initial Results

For each project, document:
1. **Total number of issues** by type (Bugs, Vulnerabilities, Code Smells)
2. **Test coverage** percentage
3. **Technical debt** ratio
4. **Quality Gate** status (likely failed)

**Expected Results**:
- Java: ~15-20 issues, ~30% coverage
- React: ~10-15 issues, ~20% coverage  
- Python: ~15-20 issues, ~25% coverage

## Part 4: Issue Resolution (90 minutes)

### Step 1: Fix Critical Issues

Choose 2-3 critical issues from each project and fix them:

**Java Example Fixes**:

1. **Fix SQL Injection**:
```java
// Before (vulnerable)
String sql = "SELECT * FROM orders WHERE user_id = " + userId;

// After (secure)
String sql = "SELECT * FROM orders WHERE user_id = ?";
PreparedStatement stmt = connection.prepareStatement(sql);
stmt.setString(1, userId);
ResultSet rs = stmt.executeQuery();
```

2. **Fix Resource Leak**:
```java
// Before (resource leak)
public void connectToDatabase() throws SQLException {
    connection = DriverManager.getConnection(url, user, password);
}

// After (proper resource management)
public Connection connectToDatabase() throws SQLException {
    return DriverManager.getConnection(url, user, password);
}

// Use try-with-resources in calling code
try (Connection conn = connectToDatabase()) {
    // Use connection
}
```

3. **Remove Hardcoded Password**:
```java
// Before
private String dbPassword = "admin123";

// After
private String dbPassword = System.getenv("DB_PASSWORD");
```

**React Example Fixes**:

1. **Fix XSS Vulnerability**:
```javascript
// Before (dangerous)
<div dangerouslySetInnerHTML={{__html: todo.text}} />

// After (safe)
<div>{todo.text}</div>
```

2. **Fix useEffect Dependency**:
```javascript
// Before (missing dependency)
useEffect(() => {
    console.log('Todos updated:', todos.length);
}, []);

// After (correct dependencies)
useEffect(() => {
    console.log('Todos updated:', todos.length);
}, [todos]);
```

3. **Remove Hardcoded API Key**:
```javascript
// Before
const API_KEY = 'sk-1234567890abcdef';

// After
const API_KEY = process.env.REACT_APP_API_KEY;
```

**Python Example Fixes**:

1. **Fix SQL Injection**:
```python
# Before (vulnerable)
query = f"SELECT * FROM users WHERE id = {user_id}"

# After (secure)
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))
```

2. **Fix Mutable Default Argument**:
```python
# Before (dangerous)
def filter_records(self, records: List[Dict], filters: Dict = {}) -> List[Dict]:

# After (safe)
def filter_records(self, records: List[Dict], filters: Dict = None) -> List[Dict]:
    if filters is None:
        filters = {}
```

3. **Fix Resource Management**:
```python
# Before (resource leak)
def read_config_file(self, filename: str) -> Dict:
    file_handle = open(filename, 'r')
    return json.load(file_handle)

# After (proper resource management)
def read_config_file(self, filename: str) -> Dict:
    try:
        with open(filename, 'r') as file_handle:
            return json.load(file_handle)
    except FileNotFoundError:
        return {}
```

### Step 2: Improve Test Coverage

Add tests to reach >80% coverage:

**Java Test Example**:
```java
@Test
public void testGetOrdersByUserId() {
    // Test the fixed method
    OrderService service = new OrderService();
    // Add proper test implementation
}

@Test(expected = IllegalArgumentException.class)
public void testSendOrderConfirmationWithNullCustomer() {
    OrderService service = new OrderService();
    Order order = new Order();
    order.setCustomer(null);
    service.sendOrderConfirmation(order); // Should throw exception
}
```

**React Test Example**:
```javascript
test('should add new todo', () => {
    render(<TodoApp />);
    const input = screen.getByRole('textbox');
    const button = screen.getByText('Add Todo');
    
    fireEvent.change(input, { target: { value: 'New todo' } });
    fireEvent.click(button);
    
    expect(screen.getByText('New todo')).toBeInTheDocument();
});
```

**Python Test Example**:
```python
def test_calculate_average_age_with_valid_data(self):
    users = [{'age': 25}, {'age': 30}, {'age': 35}]
    average = self.processor.calculate_average_age(users)
    self.assertEqual(average, 30.0)

def test_calculate_average_age_with_empty_list(self):
    with self.assertRaises(ZeroDivisionError):
        self.processor.calculate_average_age([])
```

## Part 5: Quality Gates Configuration (30 minutes)

### Step 1: Create Custom Quality Gate

1. **Go to Quality Gates** in SonarQube
2. **Create new gate** named "Strict Quality Gate"
3. **Add conditions**:
   - New Bugs = 0
   - New Vulnerabilities = 0
   - New Code Coverage ≥ 90%
   - New Duplicated Lines ≤ 2%
   - New Maintainability Rating ≤ A
   - New Reliability Rating ≤ A
   - New Security Rating ≤ A

### Step 2: Apply to Projects

1. **Assign quality gate** to all three projects
2. **Re-run analysis** for each project
3. **Verify** quality gate status

## Part 6: CI/CD Integration (20 minutes)

### Create GitHub Actions Workflow

**.github/workflows/sonarqube.yml**:
```yaml
name: SonarQube Analysis

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  sonarqube-java:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0
        
    - name: Set up JDK 11
      uses: actions/setup-java@v3
      with:
        java-version: '11'
        distribution: 'temurin'
        
    - name: Run tests
      run: |
        cd java-ecommerce
        mvn clean test
        
    - name: SonarQube Scan
      uses: sonarqube-quality-gate-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
      with:
        projectBaseDir: java-ecommerce

  sonarqube-react:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0
        
    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install dependencies and run tests
      run: |
        cd react-todo-app
        npm install
        npm test
        
    - name: SonarQube Scan
      uses: sonarqube-quality-gate-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
      with:
        projectBaseDir: react-todo-app

  sonarqube-python:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0
        
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
        
    - name: Install dependencies and run tests
      run: |
        cd python-data-processor
        pip install requests pytest pytest-cov
        python -m pytest tests/ --cov=src --cov-report=xml
        
    - name: SonarQube Scan
      uses: sonarqube-quality-gate-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
      with:
        projectBaseDir: python-data-processor
```

## Part 7: Documentation & Retrospective (20 minutes)

### Document Your Experience

Create a summary document including:

1. **Initial Analysis Results**:
   - Issue counts by project and type
   - Coverage percentages
   - Quality gate failures

2. **Issues Fixed**:
   - List of specific issues resolved
   - Time taken for each fix
   - Difficulty level (1-5 scale)

3. **Key Learnings**:
   - Most surprising findings
   - Hardest issues to fix
   - Most valuable SonarQube features

4. **Recommendations**:
   - Process improvements for your team
   - Rule customizations needed
   - Training priorities

### Sample Summary Template

```markdown
# SonarQube Exercise Summary

## Project Results

### Java E-commerce Service
- **Initial Issues**: 18 (8 bugs, 3 vulnerabilities, 7 code smells)
- **Final Issues**: 3 (0 bugs, 0 vulnerabilities, 3 code smells)
- **Coverage**: 32% → 85%
- **Quality Gate**: Failed → Passed

### React Todo App  
- **Initial Issues**: 12 (5 bugs, 2 vulnerabilities, 5 code smells)
- **Final Issues**: 2 (0 bugs, 0 vulnerabilities, 2 code smells)
- **Coverage**: 18% → 82%
- **Quality Gate**: Failed → Passed

### Python Data Processor
- **Initial Issues**: 16 (7 bugs, 3 vulnerabilities, 6 code smells)  
- **Final Issues**: 4 (0 bugs, 0 vulnerabilities, 4 code smells)
- **Coverage**: 25% → 88%
- **Quality Gate**: Failed → Passed

## Time Investment
- Setup: 30 minutes
- Initial Analysis: 45 minutes  
- Issue Resolution: 90 minutes
- Testing Improvements: 60 minutes
- Quality Gates: 30 minutes
- CI/CD Integration: 20 minutes
- **Total**: 4 hours 45 minutes

## Key Learnings
1. Security vulnerabilities are often the easiest to fix but hardest to spot
2. Test coverage improvements take the most time
3. Code smells often indicate deeper design issues
4. Quality gates provide excellent guardrails for teams

## Recommendations
1. Implement SonarQube analysis in all CI pipelines
2. Set up quality gates as deployment blockers
3. Regular team training on secure coding practices
4. Establish code review checklist based on SonarQube rules
```

## Bonus Challenges

### Challenge 1: Custom Rule Creation
Create a custom rule for your organization's naming conventions.

### Challenge 2: Performance Analysis
Use SonarQube to identify and fix performance issues in the Python project.

### Challenge 3: Security Hardening
Achieve zero security vulnerabilities across all projects.

### Challenge 4: Legacy Code Integration
Take a real legacy project and create a gradual improvement plan using SonarQube.

## Success Criteria

- [ ] All three projects analyzed successfully
- [ ] Critical bugs and vulnerabilities fixed (0 remaining)
- [ ] Test coverage >80% for all projects
- [ ] Quality gates passing for all projects
- [ ] CI/CD integration configured
- [ ] Custom quality gate created and applied
- [ ] Documentation completed

## Next Steps

1. **Apply to Real Projects**: Use these techniques on your actual codebase
2. **Team Training**: Share learnings with your development team
3. **Process Integration**: Incorporate SonarQube into your development workflow
4. **Continuous Improvement**: Regular quality reviews and rule updates

Congratulations on completing the comprehensive SonarQube exercise! You now have hands-on experience with the complete SonarQube workflow from setup to production integration.