# Examples of common Python issues that SonarQube detects

import os
import re
import json
import sqlite3
import subprocess
from typing import List, Dict, Optional

# BUG: Unused import
# Rule: S1481 - Unused local variables should be removed
import sys  # SonarQube flags unused import

class PythonIssuesExamples:
    """Examples of common Python issues detected by SonarQube"""

    # BUG: Mutable default arguments
    # Rule: S2234 - Parameters should be passed in the correct order
    def mutable_default_bug(self, items=[]):  # Dangerous!
        """SonarQube flags mutable default arguments"""
        items.append('new_item')
        return items

    # FIXED VERSION
    def mutable_default_fixed(self, items=None):
        """Proper way to handle mutable default arguments"""
        if items is None:
            items = []
        items.append('new_item')
        return items

    # VULNERABILITY: SQL Injection
    # Rule: S2077 - SQL queries should not be vulnerable to injection attacks
    def sql_injection_bug(self, user_id: str) -> List[Dict]:
        """SonarQube flags SQL injection vulnerability"""
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        # Dangerous - SQL injection vulnerability
        query = f"SELECT * FROM users WHERE id = {user_id}"
        cursor.execute(query)
        
        results = cursor.fetchall()
        conn.close()
        return results

    # FIXED VERSION
    def sql_injection_fixed(self, user_id: str) -> List[Dict]:
        """Parameterized query prevents SQL injection"""
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        # Safe - parameterized query
        query = "SELECT * FROM users WHERE id = ?"
        cursor.execute(query, (user_id,))
        
        results = cursor.fetchall()
        conn.close()
        return results

    # VULNERABILITY: Command Injection
    # Rule: S4823 - Using shell=True is security-sensitive
    def command_injection_bug(self, filename: str) -> str:
        """SonarQube flags shell injection vulnerability"""
        # Dangerous - command injection vulnerability
        result = subprocess.run(f"cat {filename}", shell=True, capture_output=True, text=True)
        return result.stdout

    # FIXED VERSION
    def command_injection_fixed(self, filename: str) -> str:
        """Safe command execution without shell"""
        try:
            result = subprocess.run(['cat', filename], capture_output=True, text=True, check=True)
            return result.stdout
        except subprocess.CalledProcessError as e:
            print(f"Error reading file: {e}")
            return ""

    # BUG: Exception handling issues
    # Rule: S1181 - Catching Exception is not allowed
    def exception_handling_bug(self):
        """SonarQube flags overly broad exception handling"""
        try:
            risky_operation()
        except Exception:  # Too broad - catches everything
            print("Something went wrong")
            pass  # Silent failure is bad

    # FIXED VERSION
    def exception_handling_fixed(self):
        """Specific exception handling with proper logging"""
        try:
            risky_operation()
        except FileNotFoundError as e:
            print(f"File not found: {e}")
            raise  # Re-raise if cannot handle
        except ValueError as e:
            print(f"Invalid value: {e}")
            return None
        except Exception as e:
            print(f"Unexpected error: {e}")
            raise  # Don't suppress unexpected exceptions

    # CODE SMELL: Function too complex
    # Rule: S3776 - Cognitive Complexity of functions should not be too high
    def complex_function_bug(self, data: List[Dict]) -> Dict:
        """SonarQube flags high cognitive complexity"""
        result = {}
        
        for item in data:
            if item:
                if 'type' in item:
                    if item['type'] == 'user':
                        if 'active' in item:
                            if item['active']:
                                if 'age' in item:
                                    if item['age'] >= 18:
                                        if 'email' in item:
                                            if '@' in item['email']:
                                                result[item['id']] = item
        return result

    # FIXED VERSION
    def complex_function_fixed(self, data: List[Dict]) -> Dict:
        """Reduced complexity with early returns and helper methods"""
        result = {}
        
        for item in data:
            if self._is_valid_adult_user(item):
                result[item['id']] = item
                
        return result

    def _is_valid_adult_user(self, item: Dict) -> bool:
        """Helper method to reduce complexity"""
        if not item or item.get('type') != 'user':
            return False
            
        if not item.get('active', False):
            return False
            
        if item.get('age', 0) < 18:
            return False
            
        email = item.get('email', '')
        return '@' in email

    # CODE SMELL: Duplicated code
    # Rule: S4144 - Methods should not have identical implementations
    def process_users_bug(self, users: List[str]) -> List[str]:
        """SonarQube detects code duplication"""
        processed = []
        for user in users:
            if user and user.strip():
                cleaned = user.strip().lower()
                if len(cleaned) > 2:
                    processed.append(cleaned)
        return processed

    def process_products_bug(self, products: List[str]) -> List[str]:
        """Identical logic - code duplication"""
        processed = []
        for product in products:
            if product and product.strip():
                cleaned = product.strip().lower()
                if len(cleaned) > 2:
                    processed.append(cleaned)
        return processed

    # FIXED VERSION
    def process_users_fixed(self, users: List[str]) -> List[str]:
        """Extracted common logic"""
        return self._process_string_list(users)

    def process_products_fixed(self, products: List[str]) -> List[str]:
        """Reuses common processing logic"""
        return self._process_string_list(products)

    def _process_string_list(self, items: List[str]) -> List[str]:
        """Common processing logic extracted"""
        return [
            item.strip().lower()
            for item in items
            if item and item.strip() and len(item.strip()) > 2
        ]

    # BUG: Resource leak
    # Rule: S2095 - Resources should be closed
    def resource_leak_bug(self, filename: str) -> str:
        """SonarQube flags unclosed resources"""
        file = open(filename, 'r')  # Not closed properly
        content = file.read()
        # Missing file.close()
        return content

    # FIXED VERSION
    def resource_leak_fixed(self, filename: str) -> str:
        """Proper resource management with context manager"""
        try:
            with open(filename, 'r') as file:
                return file.read()
        except IOError as e:
            print(f"Error reading file {filename}: {e}")
            return ""

    # VULNERABILITY: Hardcoded secrets
    # Rule: S2068 - Hard-coded credentials are security-sensitive
    def hardcoded_secrets_bug(self):
        """SonarQube flags hardcoded credentials"""
        api_key = "sk-1234567890abcdef"  # Hardcoded API key
        password = "admin123"  # Hardcoded password
        
        return {"api_key": api_key, "password": password}

    # FIXED VERSION
    def hardcoded_secrets_fixed(self):
        """Use environment variables for secrets"""
        api_key = os.getenv('API_KEY')
        password = os.getenv('DB_PASSWORD')
        
        if not api_key or not password:
            raise ValueError("Missing required environment variables")
            
        return {"api_key": api_key, "password": password}

    # BUG: Regex Denial of Service (ReDoS)
    # Rule: S5852 - Regular expressions should not be vulnerable to ReDoS
    def regex_dos_bug(self, text: str) -> bool:
        """SonarQube flags potentially vulnerable regex"""
        # Vulnerable to catastrophic backtracking
        pattern = r'^(a+)+$'
        return bool(re.match(pattern, text))

    # FIXED VERSION
    def regex_dos_fixed(self, text: str) -> bool:
        """Non-vulnerable regex pattern"""
        pattern = r'^a+$'  # Atomic grouping prevents backtracking
        return bool(re.match(pattern, text))

    # CODE SMELL: Magic numbers
    # Rule: S109 - Magic numbers should not be used
    def magic_numbers_bug(self, radius: float) -> float:
        """SonarQube flags magic numbers"""
        return 3.14159 * radius * radius  # Magic number

    # FIXED VERSION
    PI = 3.14159  # Class constant
    
    def magic_numbers_fixed(self, radius: float) -> float:
        """Named constant instead of magic number"""
        return self.PI * radius * radius

    # BUG: Incorrect string comparison
    # Rule: S1940 - Boolean checks should not be inverted
    def string_comparison_bug(self, text: str) -> bool:
        """SonarQube flags problematic string comparisons"""
        # Problematic - should use 'is' for None comparison
        if text == None:  # Should be 'is None'
            return False
        
        # Problematic - case sensitivity issues
        if text == "Admin":  # Case sensitive
            return True
            
        return False

    # FIXED VERSION
    def string_comparison_fixed(self, text: str) -> bool:
        """Proper None and string comparisons"""
        if text is None:
            return False
            
        # Case insensitive comparison
        if text.lower() == "admin":
            return True
            
        return False

    # PERFORMANCE: Inefficient loops
    # Code smell: Inefficient string concatenation in loops
    def inefficient_loop_bug(self, items: List[str]) -> str:
        """Inefficient string concatenation"""
        result = ""
        for item in items:
            result += item + ", "  # Inefficient string concatenation
        return result

    # FIXED VERSION
    def inefficient_loop_fixed(self, items: List[str]) -> str:
        """Efficient string joining"""
        return ", ".join(items)

    # BUG: Unreachable code
    # Rule: S1763 - Jump statements should not be redundant
    def unreachable_code_bug(self):
        """SonarQube flags unreachable code"""
        return "early return"
        print("This will never execute")  # Unreachable

    # FIXED VERSION
    def unreachable_code_fixed(self):
        """Remove unreachable code"""
        return "early return"

# Helper function for examples
def risky_operation():
    """Simulates a risky operation that might fail"""
    raise FileNotFoundError("Simulated file not found error")

# Example usage and testing
if __name__ == "__main__":
    examples = PythonIssuesExamples()
    
    # Test fixed versions
    print("Testing fixed methods:")
    
    # Test mutable default fix
    list1 = examples.mutable_default_fixed()
    list2 = examples.mutable_default_fixed()
    print(f"Mutable default fix: {list1 == list2}")  # Should be False
    
    # Test string processing
    users = ["  JOHN  ", "jane", "a", "  Bob Smith  "]
    processed = examples.process_users_fixed(users)
    print(f"Processed users: {processed}")
    
    # Test resource management
    try:
        content = examples.resource_leak_fixed("nonexistent.txt")
        print(f"File content: {content}")
    except Exception as e:
        print(f"Expected error: {e}")

"""
SonarQube Analysis Results Summary for Python:

Bugs: 10
- Mutable default arguments
- SQL injection vulnerability
- Command injection vulnerability
- Overly broad exception handling
- Resource leaks (unclosed files)
- Incorrect None comparisons
- Unreachable code
- Logic errors in conditions
- Missing error handling
- Improper resource management

Vulnerabilities: 4
- SQL injection (parameterized queries needed)
- Command injection (avoid shell=True)
- Hardcoded credentials (use environment variables)
- RegExp DoS (avoid catastrophic backtracking)

Code Smells: 6
- High cognitive complexity
- Code duplication
- Magic numbers
- Long functions/methods
- Too many parameters
- Inefficient algorithms

Python-Specific Best Practices:
1. Use context managers (with statements) for resource management
2. Avoid mutable default arguments
3. Use specific exception types, not broad Exception
4. Follow PEP 8 style guidelines
5. Use type hints for better code documentation
6. Prefer list comprehensions over loops when appropriate
7. Use 'is' for None comparisons, not '=='
8. Store secrets in environment variables
9. Validate and sanitize all external input
10. Use parameterized queries for database operations
11. Avoid shell=True in subprocess calls
12. Use pathlib for file path operations
13. Implement proper logging instead of print statements
14. Write docstrings for all public methods
15. Use f-strings for string formatting
"""