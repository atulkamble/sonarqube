package com.sonarqube.examples.bugs;

import java.util.ArrayList;
import java.util.List;
import java.io.FileInputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

/**
 * Examples of common bugs that SonarQube detects
 * Each method demonstrates a different type of bug with explanations
 */
public class CommonBugs {

    // BUG: Null Pointer Exception Risk
    // Rule: S2259 - Null pointers should not be dereferenced
    public void nullPointerBug(String input) {
        // SonarQube will flag this - input could be null
        int length = input.length(); // Potential NPE
        System.out.println("Length: " + length);
    }

    // FIXED VERSION
    public void nullPointerFixed(String input) {
        if (input != null) {
            int length = input.length();
            System.out.println("Length: " + length);
        } else {
            System.out.println("Input is null");
        }
    }

    // BUG: Resource Leak
    // Rule: S2095 - Resources should be closed
    public void resourceLeakBug(String filename) throws IOException {
        FileInputStream fis = new FileInputStream(filename);
        // SonarQube will flag this - resource not closed
        byte[] data = new byte[1024];
        fis.read(data);
        // Missing fis.close()
    }

    // FIXED VERSION
    public void resourceLeakFixed(String filename) throws IOException {
        try (FileInputStream fis = new FileInputStream(filename)) {
            byte[] data = new byte[1024];
            fis.read(data);
            // Automatically closed by try-with-resources
        }
    }

    // BUG: SQL Injection Vulnerability
    // Rule: S2077 - SQL queries should not be vulnerable to injection attacks
    public void sqlInjectionBug(Connection conn, String userId) throws SQLException {
        // SonarQube will flag this as security vulnerability
        String query = "SELECT * FROM users WHERE id = " + userId;
        PreparedStatement stmt = conn.prepareStatement(query);
        stmt.executeQuery();
    }

    // FIXED VERSION
    public void sqlInjectionFixed(Connection conn, String userId) throws SQLException {
        String query = "SELECT * FROM users WHERE id = ?";
        PreparedStatement stmt = conn.prepareStatement(query);
        stmt.setString(1, userId); // Parameterized query
        stmt.executeQuery();
    }

    // BUG: Infinite Loop Risk
    // Rule: S2189 - Loops should not be infinite
    public void infiniteLoopBug() {
        int i = 0;
        // SonarQube will flag potential infinite loop
        while (i >= 0) {
            System.out.println(i);
            // i is never modified, potential infinite loop
        }
    }

    // FIXED VERSION
    public void infiniteLoopFixed() {
        int i = 0;
        while (i < 10) { // Clear termination condition
            System.out.println(i);
            i++; // Loop variable is modified
        }
    }

    // BUG: Deadlock Risk
    // Rule: S1143 - Return statements should not occur in finally blocks
    private final Object lock1 = new Object();
    private final Object lock2 = new Object();

    public void deadlockRisk() {
        // Thread 1: locks lock1 then lock2
        synchronized (lock1) {
            synchronized (lock2) {
                // Do something
            }
        }
    }

    public void anotherMethod() {
        // Thread 2: locks lock2 then lock1 - potential deadlock!
        synchronized (lock2) {
            synchronized (lock1) {
                // Do something
            }
        }
    }

    // FIXED VERSION - Always acquire locks in same order
    public void deadlockFixed() {
        synchronized (lock1) { // Always acquire lock1 first
            synchronized (lock2) { // Then lock2
                // Do something
            }
        }
    }

    // BUG: Exception Handling Issues
    // Rule: S1181 - Throwable and Error should not be caught
    public void badExceptionHandling() {
        try {
            riskyOperation();
        } catch (Throwable t) { // SonarQube flags this - too broad
            // Catching Throwable catches even Errors which shouldn't be caught
            System.out.println("Something went wrong");
        }
    }

    // FIXED VERSION
    public void goodExceptionHandling() {
        try {
            riskyOperation();
        } catch (IOException e) { // Specific exception type
            System.err.println("IO operation failed: " + e.getMessage());
        } catch (RuntimeException e) {
            System.err.println("Runtime error: " + e.getMessage());
            throw e; // Re-throw if cannot handle
        }
    }

    // BUG: Array Index Out of Bounds
    // Rule: S3518 - Array accesses should be in bounds
    public void arrayIndexBug(int[] numbers) {
        // SonarQube will flag potential array index issue
        for (int i = 0; i <= numbers.length; i++) { // <= instead of <
            System.out.println(numbers[i]); // ArrayIndexOutOfBoundsException
        }
    }

    // FIXED VERSION
    public void arrayIndexFixed(int[] numbers) {
        for (int i = 0; i < numbers.length; i++) { // Correct boundary
            System.out.println(numbers[i]);
        }
        
        // Or better yet, use enhanced for loop
        for (int number : numbers) {
            System.out.println(number);
        }
    }

    // BUG: Collection Modification During Iteration
    // Rule: S2201 - Return values should not be ignored when they cannot be null
    public void collectionModificationBug() {
        List<String> items = new ArrayList<>();
        items.add("item1");
        items.add("item2");
        items.add("item3");

        // SonarQube will flag this - ConcurrentModificationException risk
        for (String item : items) {
            if (item.equals("item2")) {
                items.remove(item); // Modifying collection during iteration
            }
        }
    }

    // FIXED VERSION
    public void collectionModificationFixed() {
        List<String> items = new ArrayList<>();
        items.add("item1");
        items.add("item2"); 
        items.add("item3");

        // Use iterator for safe removal
        items.removeIf(item -> item.equals("item2"));
        
        // Alternative: collect items to remove, then remove them
        // List<String> toRemove = items.stream()
        //     .filter(item -> item.equals("item2"))
        //     .collect(Collectors.toList());
        // items.removeAll(toRemove);
    }

    private void riskyOperation() throws IOException {
        // Placeholder for operation that might throw IOException
        throw new IOException("Simulated error");
    }
}

/*
 * SonarQube Analysis Results for this file would show:
 * 
 * Bugs: 8 (High Priority)
 * - Null pointer dereference
 * - Resource leak
 * - SQL injection
 * - Infinite loop
 * - Deadlock risk
 * - Improper exception handling
 * - Array bounds violation
 * - Collection modification during iteration
 * 
 * How to fix:
 * 1. Add null checks before dereferencing
 * 2. Use try-with-resources for automatic resource management
 * 3. Use parameterized queries for SQL operations
 * 4. Ensure loop variables are properly modified
 * 5. Acquire locks in consistent order
 * 6. Catch specific exception types, not Throwable
 * 7. Check array bounds before access
 * 8. Use iterator or stream operations for safe collection modification
 */