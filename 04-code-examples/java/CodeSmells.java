package com.sonarqube.examples.smells;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Examples of code smells that SonarQube detects
 * Code smells indicate maintainability issues
 */
public class CodeSmells {

    // CODE SMELL: Magic Numbers
    // Rule: S109 - Magic numbers should not be used
    public double calculateCircleAreaBad(double radius) {
        // SonarQube flags 3.14159 as magic number
        return 3.14159 * radius * radius;
    }

    // FIXED VERSION
    private static final double PI = 3.14159;
    
    public double calculateCircleAreaGood(double radius) {
        return PI * radius * radius;
    }

    // CODE SMELL: Long Method
    // Rule: S138 - Functions should not have too many lines
    public void longMethodBad(List<String> data) {
        // SonarQube will flag methods with >75 lines
        System.out.println("Processing data...");
        
        // Data validation (should be extracted)
        if (data == null) {
            throw new IllegalArgumentException("Data cannot be null");
        }
        if (data.isEmpty()) {
            throw new IllegalArgumentException("Data cannot be empty");
        }
        
        // Data cleaning (should be extracted)
        List<String> cleanedData = new ArrayList<>();
        for (String item : data) {
            if (item != null && !item.trim().isEmpty()) {
                cleanedData.add(item.trim().toLowerCase());
            }
        }
        
        // Data processing (should be extracted)
        Map<String, Integer> counts = new HashMap<>();
        for (String item : cleanedData) {
            counts.put(item, counts.getOrDefault(item, 0) + 1);
        }
        
        // Result formatting (should be extracted)
        List<Map.Entry<String, Integer>> sortedEntries = counts.entrySet()
            .stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
            .collect(Collectors.toList());
            
        // Output generation (should be extracted)
        System.out.println("Results:");
        for (Map.Entry<String, Integer> entry : sortedEntries) {
            System.out.printf("%s: %d%n", entry.getKey(), entry.getValue());
        }
        
        // Statistics calculation (should be extracted)
        int total = counts.values().stream().mapToInt(Integer::intValue).sum();
        double average = total / (double) counts.size();
        System.out.printf("Total: %d, Average: %.2f%n", total, average);
        
        System.out.println("Processing complete.");
    }

    // FIXED VERSION - Extracted methods
    public void longMethodGood(List<String> data) {
        validateData(data);
        List<String> cleanedData = cleanData(data);
        Map<String, Integer> counts = processData(cleanedData);
        displayResults(counts);
    }

    private void validateData(List<String> data) {
        if (data == null) {
            throw new IllegalArgumentException("Data cannot be null");
        }
        if (data.isEmpty()) {
            throw new IllegalArgumentException("Data cannot be empty");
        }
    }

    private List<String> cleanData(List<String> data) {
        return data.stream()
            .filter(Objects::nonNull)
            .map(String::trim)
            .filter(s -> !s.isEmpty())
            .map(String::toLowerCase)
            .collect(Collectors.toList());
    }

    private Map<String, Integer> processData(List<String> data) {
        return data.stream()
            .collect(Collectors.groupingBy(
                item -> item,
                Collectors.summingInt(item -> 1)
            ));
    }

    private void displayResults(Map<String, Integer> counts) {
        System.out.println("Results:");
        counts.entrySet()
            .stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
            .forEach(entry -> System.out.printf("%s: %d%n", entry.getKey(), entry.getValue()));
            
        int total = counts.values().stream().mapToInt(Integer::intValue).sum();
        double average = total / (double) counts.size();
        System.out.printf("Total: %d, Average: %.2f%n", total, average);
    }

    // CODE SMELL: Too Many Parameters
    // Rule: S107 - Functions should not have too many parameters
    public void tooManyParametersBad(String name, String email, String phone, 
                                   String address, String city, String state, 
                                   String zip, String country, int age, 
                                   boolean isActive, Date joinDate) {
        // SonarQube flags methods with >7 parameters
        // Implementation...
    }

    // FIXED VERSION - Use parameter object
    public static class UserInfo {
        private String name;
        private String email;
        private String phone;
        private Address address;
        private PersonalDetails personalDetails;

        // Constructor, getters, setters...
        public UserInfo(String name, String email, String phone, 
                       Address address, PersonalDetails personalDetails) {
            this.name = name;
            this.email = email;
            this.phone = phone;
            this.address = address;
            this.personalDetails = personalDetails;
        }
        
        // Getters and setters omitted for brevity
    }

    public static class Address {
        private String street;
        private String city;
        private String state;
        private String zip;
        private String country;
        
        // Constructor, getters, setters...
    }

    public static class PersonalDetails {
        private int age;
        private boolean isActive;
        private Date joinDate;
        
        // Constructor, getters, setters...
    }

    public void tooManyParametersGood(UserInfo userInfo) {
        // Much cleaner method signature
        // Implementation...
    }

    // CODE SMELL: Duplicated Code
    // Rule: S4144 - Methods should not have identical implementations
    public void processUsersBad(List<String> users) {
        System.out.println("Starting user processing...");
        for (String user : users) {
            if (user != null && !user.isEmpty()) {
                String processed = user.trim().toLowerCase();
                System.out.println("Processed: " + processed);
            }
        }
        System.out.println("User processing complete.");
    }

    public void processProductsBad(List<String> products) {
        System.out.println("Starting product processing...");
        for (String product : products) {
            if (product != null && !product.isEmpty()) {
                String processed = product.trim().toLowerCase();
                System.out.println("Processed: " + processed);
            }
        }
        System.out.println("Product processing complete.");
    }

    // FIXED VERSION - Extract common logic
    public void processUsersGood(List<String> users) {
        processItems(users, "user");
    }

    public void processProductsGood(List<String> products) {
        processItems(products, "product");
    }

    private void processItems(List<String> items, String itemType) {
        System.out.println("Starting " + itemType + " processing...");
        items.stream()
            .filter(item -> item != null && !item.isEmpty())
            .map(item -> item.trim().toLowerCase())
            .forEach(processed -> System.out.println("Processed: " + processed));
        System.out.println(itemType + " processing complete.");
    }

    // CODE SMELL: Complex Boolean Expression
    // Rule: S1067 - Expressions should not be too complex
    public boolean complexConditionBad(User user, Product product, Order order) {
        // SonarQube flags overly complex boolean expressions
        return user != null && user.isActive() && user.getAge() >= 18 && 
               user.hasValidEmail() && product != null && product.isAvailable() && 
               product.getPrice() > 0 && product.getStock() > 0 && order != null && 
               order.getQuantity() > 0 && order.getTotal() > 0 && 
               order.getStatus() == OrderStatus.PENDING;
    }

    // FIXED VERSION - Break into meaningful methods
    public boolean complexConditionGood(User user, Product product, Order order) {
        return isValidUser(user) && 
               isValidProduct(product) && 
               isValidOrder(order);
    }

    private boolean isValidUser(User user) {
        return user != null && 
               user.isActive() && 
               user.getAge() >= 18 && 
               user.hasValidEmail();
    }

    private boolean isValidProduct(Product product) {
        return product != null && 
               product.isAvailable() && 
               product.getPrice() > 0 && 
               product.getStock() > 0;
    }

    private boolean isValidOrder(Order order) {
        return order != null && 
               order.getQuantity() > 0 && 
               order.getTotal() > 0 && 
               order.getStatus() == OrderStatus.PENDING;
    }

    // CODE SMELL: Large Class
    // Rule: S104 - Files should not have too many lines of code
    // This class is getting large and should be split into multiple classes:
    // - DataValidator
    // - DataProcessor
    // - ResultDisplayer
    // - UserService
    // - ProductService
    // - OrderService

    // Placeholder classes for the examples
    static class User {
        public boolean isActive() { return true; }
        public int getAge() { return 25; }
        public boolean hasValidEmail() { return true; }
    }

    static class Product {
        public boolean isAvailable() { return true; }
        public double getPrice() { return 10.0; }
        public int getStock() { return 5; }
    }

    static class Order {
        public int getQuantity() { return 1; }
        public double getTotal() { return 10.0; }
        public OrderStatus getStatus() { return OrderStatus.PENDING; }
    }

    enum OrderStatus {
        PENDING, CONFIRMED, SHIPPED, DELIVERED
    }
}

/*
 * SonarQube Analysis Results for this file would show:
 * 
 * Code Smells: 6 (Maintainability Issues)
 * - Magic numbers used directly in calculations
 * - Method too long (>75 lines)
 * - Too many parameters in method signature (>7)
 * - Duplicated code blocks
 * - Overly complex boolean expressions
 * - File/class too large
 * 
 * Impact on Technical Debt:
 * - Each code smell adds to technical debt
 * - Reduces code readability and maintainability
 * - Makes code harder to test and debug
 * - Increases risk of introducing bugs during changes
 * 
 * Refactoring Benefits:
 * - Improved readability and understanding
 * - Easier to test individual components
 * - Reduced duplication means fewer places to fix bugs
 * - Better separation of concerns
 * - More maintainable codebase
 */