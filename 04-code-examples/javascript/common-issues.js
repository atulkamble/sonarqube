// Examples of common JavaScript issues that SonarQube detects

// BUG: Variable declared but never used
// Rule: S1481 - Unused local variables should be removed
function unusedVariableBug() {
    const unusedVar = 'This variable is never used'; // SonarQube flags this
    const usedVar = 'This is used';
    console.log(usedVar);
}

// FIXED VERSION
function unusedVariableFixed() {
    const usedVar = 'This is used';
    console.log(usedVar);
}

// BUG: Equality operators should not be used in "for" loops
// Rule: S888 - Equality operators should not be used in "for" loop termination conditions
function forLoopBug() {
    const items = ['a', 'b', 'c'];
    // SonarQube flags == in for loop condition
    for (let i = 0; i == items.length; i++) { // Should be <
        console.log(items[i]);
    }
}

// FIXED VERSION
function forLoopFixed() {
    const items = ['a', 'b', 'c'];
    for (let i = 0; i < items.length; i++) {
        console.log(items[i]);
    }
    
    // Or better yet, use modern iteration
    items.forEach(item => console.log(item));
}

// VULNERABILITY: Cross-Site Scripting (XSS)
// Rule: S5147 - HTML5 "autofocus" attribute should not be used
function xssVulnerability(userInput) {
    // SonarQube flags direct HTML insertion without sanitization
    document.getElementById('output').innerHTML = userInput; // Dangerous!
}

// FIXED VERSION
function xssVulnerabilityFixed(userInput) {
    // Use textContent instead of innerHTML for user input
    document.getElementById('output').textContent = userInput;
    
    // Or sanitize HTML if HTML content is needed
    // document.getElementById('output').innerHTML = sanitizeHTML(userInput);
}

// BUG: Functions should not be defined inside loops
// Rule: S1515 - Functions should not be defined inside loops
function functionInLoopBug() {
    const buttons = document.querySelectorAll('.button');
    
    for (let i = 0; i < buttons.length; i++) {
        // SonarQube flags function definition inside loop
        buttons[i].addEventListener('click', function() {
            console.log('Button clicked: ' + i); // Also closure issue!
        });
    }
}

// FIXED VERSION
function functionInLoopFixed() {
    const buttons = document.querySelectorAll('.button');
    
    // Define function outside loop
    function createClickHandler(index) {
        return function() {
            console.log('Button clicked: ' + index);
        };
    }
    
    for (let i = 0; i < buttons.length; i++) {
        buttons[i].addEventListener('click', createClickHandler(i));
    }
    
    // Or use modern approach with forEach
    buttons.forEach((button, index) => {
        button.addEventListener('click', () => {
            console.log('Button clicked: ' + index);
        });
    });
}

// CODE SMELL: Complex function with too many parameters
// Rule: S107 - Functions should not have too many parameters
function tooManyParametersBad(name, email, phone, address, city, state, zip, country) {
    // SonarQube flags functions with >7 parameters
    return {
        name, email, phone, address, city, state, zip, country
    };
}

// FIXED VERSION - Use object parameter
function tooManyParametersGood(userInfo) {
    const { name, email, phone, address, city, state, zip, country } = userInfo;
    return { name, email, phone, address, city, state, zip, country };
}

// CODE SMELL: Duplicated string literals
// Rule: S1192 - String literals should not be duplicated
function duplicatedStringsBad() {
    console.log('Error: Invalid input'); // Duplicated string
    alert('Error: Invalid input');       // Same string repeated
    document.title = 'Error: Invalid input';
    throw new Error('Error: Invalid input');
}

// FIXED VERSION
function duplicatedStringsGood() {
    const ERROR_MESSAGE = 'Error: Invalid input';
    console.log(ERROR_MESSAGE);
    alert(ERROR_MESSAGE);
    document.title = ERROR_MESSAGE;
    throw new Error(ERROR_MESSAGE);
}

// BUG: Promise rejections should not be ignored
// Rule: S4822 - Promises should not be misused
async function promiseBug() {
    // SonarQube flags unhandled promise rejection
    fetch('/api/data'); // Missing error handling
    
    const promise = new Promise((resolve, reject) => {
        setTimeout(() => reject(new Error('Failed')), 1000);
    });
    
    promise; // Ignored promise
}

// FIXED VERSION
async function promiseFixed() {
    try {
        const response = await fetch('/api/data');
        if (!response.ok) {
            throw new Error('Network response was not ok');
        }
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Fetch failed:', error);
        throw error;
    }
}

// VULNERABILITY: Insecure randomness
// Rule: S2245 - Using pseudorandom number generators (PRNGs) is security-sensitive
function insecureRandomBug() {
    // SonarQube flags Math.random() for security-sensitive operations
    const sessionToken = Math.random().toString(36); // Predictable!
    return sessionToken;
}

// FIXED VERSION
function insecureRandomFixed() {
    // Use crypto.getRandomValues() for cryptographic purposes
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

// CODE SMELL: Magic numbers
// Rule: S109 - Magic numbers should not be used
function magicNumbersBad() {
    const radius = 5;
    return 3.14159 * radius * radius; // Magic number
}

// FIXED VERSION
function magicNumbersGood() {
    const PI = 3.14159;
    const radius = 5;
    return PI * radius * radius;
}

// BUG: Array and Object methods should be used correctly
// Rule: S4043 - Array and Object methods should be used appropriately
function arrayMethodsBug() {
    const numbers = [1, 2, 3, 4, 5];
    
    // SonarQube flags incorrect use of reduce
    const doubled = numbers.reduce((acc, num) => {
        acc.push(num * 2); // Should use map instead
        return acc;
    }, []);
    
    return doubled;
}

// FIXED VERSION
function arrayMethodsFixed() {
    const numbers = [1, 2, 3, 4, 5];
    
    // Use map for transformation
    const doubled = numbers.map(num => num * 2);
    
    return doubled;
}

// VULNERABILITY: RegExp Denial of Service (ReDoS)
// Rule: S5852 - Regular expressions should not be vulnerable to Denial of Service attacks
function regexDosBug(input) {
    // SonarQube flags potentially catastrophic backtracking
    const vulnerableRegex = /^(a+)+$/;
    return vulnerableRegex.test(input); // Can cause CPU exhaustion
}

// FIXED VERSION
function regexDosFixed(input) {
    // Use more efficient regex without nested quantifiers
    const safeRegex = /^a+$/;
    return safeRegex.test(input);
}

// CODE SMELL: Functions should not be empty
// Rule: S1186 - Functions should not be empty
function emptyFunctionBug() {
    // SonarQube flags empty functions
}

// FIXED VERSION
function emptyFunctionFixed() {
    // Either implement the function or remove it
    console.log('Function implemented');
}

// Alternatively, if intentionally empty, add comment
function emptyFunctionIntentional() {
    // Intentionally empty - placeholder for future implementation
}

// VULNERABILITY: Hardcoded credentials
// Rule: S2068 - Hard-coded credentials are security-sensitive
function hardcodedCredentialsBug() {
    // SonarQube flags hardcoded credentials
    const apiKey = 'sk-1234567890abcdef'; // Hardcoded API key
    const password = 'admin123'; // Hardcoded password
    
    return { apiKey, password };
}

// FIXED VERSION
function hardcodedCredentialsFixed() {
    // Use environment variables or secure configuration
    const apiKey = process.env.API_KEY;
    const password = process.env.DB_PASSWORD;
    
    if (!apiKey || !password) {
        throw new Error('Missing required credentials in environment');
    }
    
    return { apiKey, password };
}

// PERFORMANCE: Inefficient DOM manipulation
// Not a SonarQube rule but common performance issue
function inefficientDOMBad() {
    const container = document.getElementById('container');
    
    // Inefficient: Multiple reflows and repaints
    for (let i = 0; i < 1000; i++) {
        const div = document.createElement('div');
        div.textContent = `Item ${i}`;
        container.appendChild(div); // Multiple DOM modifications
    }
}

// FIXED VERSION
function efficientDOMGood() {
    const container = document.getElementById('container');
    const fragment = document.createDocumentFragment();
    
    // Efficient: Batch DOM operations
    for (let i = 0; i < 1000; i++) {
        const div = document.createElement('div');
        div.textContent = `Item ${i}`;
        fragment.appendChild(div);
    }
    
    container.appendChild(fragment); // Single DOM modification
}

// Export functions for testing (if using modules)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        unusedVariableFixed,
        forLoopFixed,
        xssVulnerabilityFixed,
        functionInLoopFixed,
        tooManyParametersGood,
        duplicatedStringsGood,
        promiseFixed,
        insecureRandomFixed,
        magicNumbersGood,
        arrayMethodsFixed,
        regexDosFixed,
        emptyFunctionFixed,
        hardcodedCredentialsFixed,
        efficientDOMGood
    };
}

/*
 * SonarQube Analysis Results Summary:
 * 
 * Bugs: 8
 * - Unused variables
 * - Incorrect loop conditions
 * - Functions defined in loops
 * - Unhandled promises
 * - Incorrect array method usage
 * - Empty functions
 * - DOM inefficiencies
 * - Logic errors
 * 
 * Vulnerabilities: 4
 * - Cross-Site Scripting (XSS)
 * - Insecure randomness
 * - RegExp Denial of Service
 * - Hardcoded credentials
 * 
 * Code Smells: 3
 * - Too many parameters
 * - Duplicated strings
 * - Magic numbers
 * 
 * Best Practices for JavaScript Code Quality:
 * 1. Use strict mode ('use strict')
 * 2. Declare variables properly (const/let, not var)
 * 3. Handle promises with try/catch or .catch()
 * 4. Sanitize user input before DOM insertion
 * 5. Use meaningful variable and function names
 * 6. Avoid deeply nested callbacks (callback hell)
 * 7. Use modern ES6+ features appropriately
 * 8. Implement proper error handling
 * 9. Use ESLint with SonarQube rules
 * 10. Write unit tests for all functions
 */