# 100 SQL Interview Questions and Answers

This document contains a comprehensive list of 100 SQL interview questions and answers, categorized by difficulty level.

## Basic SQL (Questions 1-30)

1.  **What is SQL?**
    *   **Answer:** SQL (Structured Query Language) is a standard programming language used to manage and manipulate relational databases. It allows users to query, insert, update, and delete data.

2.  **What is a DBMS?**
    *   **Answer:** A Database Management System (DBMS) is software that interacts with end-users, applications, and the database itself to capture and analyze the data. Examples include MySQL, PostgreSQL, Oracle, and SQL Server.

3.  **What is an RDBMS?**
    *   **Answer:** RDBMS stands for Relational Database Management System. It is a type of DBMS based on the relational model introduced by E. F. Codd, where data is stored in tables with rows and columns.

4.  **What is a Primary Key?**
    *   **Answer:** A Primary Key is a column or a set of columns that uniquely identifies each row in a table. It must contain unique values and cannot contain NULL values.

5.  **What is a Foreign Key?**
    *   **Answer:** A Foreign Key is a field (or collection of fields) in one table that refers to the Primary Key in another table. It is used to establish a link between two tables.

6.  **What is the difference between CHAR and VARCHAR?**
    *   **Answer:** `CHAR` is a fixed-length character data type, while `VARCHAR` is a variable-length character data type. `CHAR` pads with spaces to the defined length, whereas `VARCHAR` stores only the characters used plus a length byte.

7.  **What is the difference between DELETE and TRUNCATE?**
    *   **Answer:** `DELETE` is a DML command used to remove specific rows based on a WHERE clause and can be rolled back. `TRUNCATE` is a DDL command that removes all rows from a table, resets identity counters, and cannot be rolled back in some RDBMS implementations (though it is transaction-safe in others like PostgreSQL).

8.  **What is the difference between DROP and TRUNCATE?**
    *   **Answer:** `DROP` removes the table structure and its data entirely from the database. `TRUNCATE` removes all data but keeps the table structure.

9.  **What are the different types of SQL commands?**
    *   **Answer:**
        *   **DDL (Data Definition Language):** CREATE, ALTER, DROP, TRUNCATE.
        *   **DML (Data Manipulation Language):** INSERT, UPDATE, DELETE.
        *   **DCL (Data Control Language):** GRANT, REVOKE.
        *   **TCL (Transaction Control Language):** COMMIT, ROLLBACK, SAVEPOINT.
        *   **DQL (Data Query Language):** SELECT.

10. **What is a NULL value?**
    *   **Answer:** A NULL value represents missing, unknown, or inapplicable data. It is not the same as zero or an empty string.

11. **How do you select all columns from a table?**
    *   **Answer:** `SELECT * FROM table_name;`

12. **What is the WHERE clause used for?**
    *   **Answer:** The `WHERE` clause is used to filter records that fulfill a specified condition.

13. **What is the difference between AND and OR operators?**
    *   **Answer:** `AND` displays a record if all the conditions separated by AND are TRUE. `OR` displays a record if any of the conditions separated by OR is TRUE.

14. **What is the ORDER BY keyword used for?**
    *   **Answer:** The `ORDER BY` keyword is used to sort the result-set in ascending or descending order.

15. **What is the DISTINCT statement used for?**
    *   **Answer:** The `SELECT DISTINCT` statement is used to return only distinct (different) values.

16. **What is a JOIN?**
    *   **Answer:** A JOIN clause is used to combine rows from two or more tables, based on a related column between them.

17. **What are the different types of JOINs?**
    *   **Answer:**
        *   **(INNER) JOIN:** Returns records that have matching values in both tables.
        *   **LEFT (OUTER) JOIN:** Returns all records from the left table, and the matched records from the right table.
        *   **RIGHT (OUTER) JOIN:** Returns all records from the right table, and the matched records from the left table.
        *   **FULL (OUTER) JOIN:** Returns all records when there is a match in either left or right table.

18. **What is a Cartesian Product?**
    *   **Answer:** A Cartesian Product (or Cross Join) occurs when each row from the first table is combined with each row from the second table. It happens when no join condition is specified.

19. **What is the LIKE operator?**
    *   **Answer:** The `LIKE` operator is used in a WHERE clause to search for a specified pattern in a column.

20. **What are Wildcards?**
    *   **Answer:** Wildcards are characters used with the LIKE operator. `%` represents zero, one, or multiple characters. `_` represents a single character.

21. **What is the IN operator?**
    *   **Answer:** The `IN` operator allows you to specify multiple values in a WHERE clause. It is a shorthand for multiple OR conditions.

22. **What is the BETWEEN operator?**
    *   **Answer:** The `BETWEEN` operator selects values within a given range. The values can be numbers, text, or dates.

23. **What is an Alias?**
    *   **Answer:** SQL aliases are used to give a table, or a column in a table, a temporary name. They are often used to make column names more readable.

24. **What is the GROUP BY statement?**
    *   **Answer:** The `GROUP BY` statement groups rows that have the same values into summary rows, like "find the number of customers in each country".

25. **What is the HAVING clause?**
    *   **Answer:** The `HAVING` clause was added to SQL because the `WHERE` keyword could not be used with aggregate functions. It allows filtering of groups created by `GROUP BY`.

26. **What are Aggregate Functions?**
    *   **Answer:** Aggregate functions perform a calculation on a set of values and return a single value. Examples: `COUNT()`, `SUM()`, `AVG()`, `MIN()`, `MAX()`.

27. **What is a Constraint?**
    *   **Answer:** Constraints are rules enforced on data columns on a table. They are used to limit the type of data that can go into a table.

28. **What are common constraints?**
    *   **Answer:** `NOT NULL`, `UNIQUE`, `PRIMARY KEY`, `FOREIGN KEY`, `CHECK`, `DEFAULT`, `INDEX`.

29. **What is NOT NULL Constraint?**
    *   **Answer:** It ensures that a column cannot accept NULL values.

30. **What is UNIQUE Constraint?**
    *   **Answer:** It ensures that all values in a column are different.

## Intermediate SQL (Questions 31-70)

31. **What is a Subquery?**
    *   **Answer:** A Subquery (or Inner Query) is a query within another SQL query and embedded within the WHERE clause.

32. **What is the difference between WHERE and HAVING?**
    *   **Answer:** `WHERE` clause filters rows before aggregation (before GROUP BY). `HAVING` clause filters groups after aggregation (after GROUP BY).

33. **What is a Self Join?**
    *   **Answer:** A Self Join is a regular join, but the table is joined with itself. It is useful for comparing rows within the same table.

34. **What is UNION and UNION ALL?**
    *   **Answer:** `UNION` combines the result-set of two or more SELECT statements and removes duplicates. `UNION ALL` does the same but includes duplicate values.

35. **What is an Index?**
    *   **Answer:** An Index is a database structure that improves the speed of data retrieval operations on a table at the cost of additional writes and storage space.

36. **What is the difference between Clustered and Non-Clustered Index?**
    *   **Answer:** A **Clustered Index** determines the physical order of data in a table (only one per table). A **Non-Clustered Index** is stored separately from the data rows and contains pointers to the physical data (multiple allowed per table).

37. **What is a View?**
    *   **Answer:** A View is a virtual table based on the result-set of an SQL statement. It contains rows and columns, just like a real table, but usually doesn't store data itself.

38. **What are the advantages of Views?**
    *   **Answer:** Views can simplify complex queries, provide security by hiding columns, and present data in a specific format.

39. **What is Normalization?**
    *   **Answer:** Normalization is the process of organizing data in a database to reduce redundancy and improve data integrity.

40. **Explain 1NF, 2NF, 3NF.**
    *   **Answer:**
        *   **1NF (First Normal Form):** Table has atomic values, no repeating groups.
        *   **2NF (Second Normal Form):** In 1NF and all non-key attributes are fully functional dependent on the primary key (no partial dependency).
        *   **3NF (Third Normal Form):** In 2NF and has no transitive dependencies (non-key attributes depend only on the primary key).

41. **What is Denormalization?**
    *   **Answer:** Denormalization is the process of adding redundant data to an already normalized database to improve read performance.

42. **What is a Transaction?**
    *   **Answer:** A Transaction is a sequence of operations performed as a single logical unit of work. It must adhere to ACID properties.

43. **What are ACID properties?**
    *   **Answer:**
        *   **Atomicity:** All or nothing.
        *   **Consistency:** Database remains in a valid state.
        *   **Isolation:** Transactions occur independently.
        *   **Durability:** Committed changes are permanent.

44. **What is a Stored Procedure?**
    *   **Answer:** A Stored Procedure is a prepared SQL code that you can save, so the code can be reused over and over again.

45. **What is a Trigger?**
    *   **Answer:** A Trigger is a stored procedure in a database that automatically invokes whenever a special event (INSERT, UPDATE, DELETE) occurs in the database.

46. **What is SQL Injection?**
    *   **Answer:** SQL Injection is a code injection technique where an attacker executes malicious SQL statements that control a web application's database server.

47. **How to prevent SQL Injection?**
    *   **Answer:** Use prepared statements (parameterized queries), input validation, and stored procedures.

48. **What is the difference between Count(*) and Count(column_name)?**
    *   **Answer:** `COUNT(*)` counts all rows including NULLs. `COUNT(column_name)` counts all rows where the specified column is NOT NULL.

49. **What is a CTE (Common Table Expression)?**
    *   **Answer:** A CTE is a temporary result set that defines a derived table, which can be referenced in a SELECT, INSERT, UPDATE, or DELETE statement. Defined using the `WITH` clause.

50. **What is the difference between local and global variables?**
    *   **Answer:** Local variables are defined within a function or block and only accessible there. Global variables are accessible throughout the session or system.

51. **What is the EXISTS operator?**
    *   **Answer:** The `EXISTS` operator is used to test for the existence of any record in a subquery. It returns TRUE if the subquery returns one or more records.

52. **What is the CASE statement?**
    *   **Answer:** The `CASE` statement goes through conditions and returns a value when the first condition is met (like an if-then-else statement).

53. **What is the COALESCE function?**
    *   **Answer:** `COALESCE` returns the first non-null value in a list.

54. **What is data integrity?**
    *   **Answer:** Data integrity refers to the accuracy and consistency of data stored in a database. It is maintained via constraints.

55. **What is a Cursor?**
    *   **Answer:** A Cursor is a database object used to retrieve, manipulate, and traverse a result set row-by-row.

56. **What are the disadvantages of Cursors?**
    *   **Answer:** Cursors are generally slower than set-based operations and consume more memory/network resources.

57. **What is an Identity column?**
    *   **Answer:** An Identity column is a column in a database table that is made up of values generated by the database. It is often used for Primary Keys.

58. **What is the difference between CHAR_LENGTH and LENGTH?**
    *   **Answer:** `CHAR_LENGTH` typically returns the number of characters, while `LENGTH` might return the number of bytes (implementation dependent).

59. **What is the difference between RANK(), DENSE_RANK(), and ROW_NUMBER()?**
    *   **Answer:**
        *   `ROW_NUMBER()`: Unique sequential number for each row (1, 2, 3, 4).
        *   `RANK()`: Ranking with gaps (1, 2, 2, 4).
        *   `DENSE_RANK()`: Ranking without gaps (1, 2, 2, 3).

60. **What is a Composite Key?**
    *   **Answer:** A Composite Key is a Primary Key composed of two or more columns.

61. **What is a Candidate Key?**
    *   **Answer:** A Candidate Key is a column, or set of columns, that can uniquely identify a database record. A Primary Key is selected from Candidate Keys.

62. **What is referential integrity?**
    *   **Answer:** Referential integrity ensures that the relationship between two tables (Primary Key and Foreign Key) remains consistent.

63. **What is a Schema?**
    *   **Answer:** A Schema is a collection of database objects (tables, views, indexes, etc.) associated with a database username.

64. **What is the LIMIT clause?**
    *   **Answer:** The `LIMIT` clause is used to specify the number of records to return. (Syntax varies by RDBMS, e.g., `TOP` in SQL Server).

65. **How to copy data from one table to another?**
    *   **Answer:** `INSERT INTO table2 SELECT * FROM table1;` or `SELECT * INTO newtable FROM oldtable;` (syntax varies).

66. **What is a Temporary Table?**
    *   **Answer:** A Temporary Table is a table that exists temporarily on the database server. It is automatically deleted when the session ends.

67. **What is Pattern Matching?**
    *   **Answer:** Pattern matching is used to search for patterns in strings, typically using `LIKE` or `REGEXP`.

68. **What is the difference between NVL, IFNULL, and ISNULL?**
    *   **Answer:** These are functions to replace NULL values, but they are specific to different SQL dialects (Oracle uses NVL, MySQL uses IFNULL, SQL Server uses ISNULL).

69. **How do you find duplicate records in a table?**
    *   **Answer:** Use `GROUP BY` on the columns and `HAVING COUNT(*) > 1`.

70. **What is the purpose of the CHECK constraint?**
    *   **Answer:** The `CHECK` constraint limits the value range that can be placed in a column.

## Advanced SQL (Questions 71-100)

71. **What are Window Functions?**
    *   **Answer:** Window functions perform calculations across a set of table rows that are somehow related to the current row (e.g., `OVER()`, `PARTITION BY`). Unlike aggregate functions, they don't collapse rows.

72. **What is a Recursive CTE?**
    *   **Answer:** A Recursive CTE is a CTE that references itself. It is useful for querying hierarchical data like organizational charts or graph structures.

73. **What is Database Sharding?**
    *   **Answer:** Sharding is a horizontal partition of data in a database or search engine. Each individual partition is referred to as a shard or database shard.

74. **What is Partitioning?**
    *   **Answer:** Partitioning is the division of a logical database or its constituent elements into distinct independent parts. It improves performance and manageability.

75. **What is the difference between Horizontal and Vertical Scaling?**
    *   **Answer:** Horizontal scaling adds more machines to the pool. Vertical scaling adds more power (CPU, RAM) to an existing machine.

76. **What is an Execution Plan?**
    *   **Answer:** An execution plan is the result of the query optimizer's attempt to calculate the most efficient way to implement a SQL statement.

77. **How do you optimize a slow SQL query?**
    *   **Answer:** Analyze the execution plan, add proper indexes, avoid `SELECT *`, use joins instead of subqueries where appropriate, and avoid wildcards at the start of `LIKE` patterns.

78. **What is the difference between OLTP and OLAP?**
    *   **Answer:**
        *   **OLTP (Online Transaction Processing):** Focuses on transaction processing, data entry, and retrieval (e.g., banking systems).
        *   **OLAP (Online Analytical Processing):** Focuses on data analysis, reporting, and decision making (e.g., data warehouses).

79. **What is a Deadlock?**
    *   **Answer:** A Deadlock is a situation where two or more transactions are waiting for one another to give up locks.

80. **What is the difference between Materialized View and View?**
    *   **Answer:** A standard View calculates data on-the-fly. A Materialized View pre-calculates and stores the result physically, refreshing it periodically. It is faster for reading but slower for writing.

81. **What is the MERGE statement?**
    *   **Answer:** The `MERGE` statement (UPSERT) performs INSERT, UPDATE, or DELETE operations on a target table based on the results of a join with a source table.

82. **What is Isolation Level?**
    *   **Answer:** Isolation levels define the degree to which a transaction must be isolated from the data modifications made by other transactions. Levels: Read Uncommitted, Read Committed, Repeatable Read, Serializable.

83. **What is Phantom Read?**
    *   **Answer:** A Phantom Read occurs when, in the course of a transaction, two identical queries are executed, and the collection of rows returned by the second query is different from the first (e.g., a new row inserted by another transaction).

84. **What is Dirty Read?**
    *   **Answer:** A Dirty Read occurs when a transaction reads data that has not yet been committed by another transaction.

85. **What is Pivoting?**
    *   **Answer:** Pivoting is a technique to rotate data from rows to columns (Cross-Tabulation).

86. **What is Dynamic SQL?**
    *   **Answer:** Dynamic SQL is SQL code that is generated and executed programmatically at runtime.

87. **What is the difference between function and stored procedure?**
    *   **Answer:** Functions must return a value, cannot change database state (usually), and can be used in SELECT statements. Stored procedures may not return a value, can change database state, and cannot be used in SELECT statements.

88. **What is a Surrogate Key?**
    *   **Answer:** A Surrogate Key is a system-generated unique identifier for a table (like an auto-incrementing integer) that has no business meaning.

89. **What is Database Normalization vs. De-normalization?**
    *   **Answer:** Normalization removes redundancy. De-normalization introduces redundancy to improve read performance.

90. **What is B-Tree?**
    *   **Answer:** B-Tree is a self-balancing tree data structure that maintains sorted data and allows searches, sequential access, insertions, and deletions in logarithmic time. It is commonly used for database indexes.

91. **What is NoSQL?**
    *   **Answer:** NoSQL databases are non-relational databases designed for distributed data stores. They provide mechanism for storage and retrieval of data modeled in means other than tabular relations (e.g., Key-Value, Document, Graph).

92. **What is the CAP Theorem?**
    *   **Answer:** It states that a distributed data store can only guarantee two of the following three: Consistency, Availability, and Partition Tolerance.

93. **What is the difference between WHERE and ON clause in Joins?**
    *   **Answer:** `ON` defines the join condition between tables. `WHERE` filters the result set after the join is performed. For Inner Joins, they are often equivalent, but for Outer Joins, `ON` filters rows before joining, while `WHERE` filters after.

94. **What is a Natural Join?**
    *   **Answer:** A Natural Join creates an implicit join clause for you based on common columns in two tables.

95. **What is the difference between UNION and JOIN?**
    *   **Answer:** `JOIN` combines columns from two or more tables horizontally. `UNION` combines rows from two or more result sets vertically.

96. **How to fetch common records from two tables?**
    *   **Answer:** Use `INTERSECT`.

97. **How to fetch records present in one table but not in another?**
    *   **Answer:** Use `EXCEPT` (or `MINUS` in Oracle), or `LEFT JOIN` with `WHERE ... IS NULL`.

98. **What is the STRING_AGG (or GROUP_CONCAT) function?**
    *   **Answer:** It concatenates values from multiple rows into a single string, usually separated by a specified delimiter.

99. **What is a Lateral Join?**
    *   **Answer:** A `LATERAL` join allows a subquery in the FROM clause to reference columns from preceding tables in the FROM clause.

100. **What is Query Optimization?**
    *   **Answer:** The process of selecting the most efficient way to execute a SQL statement. Techniques include using indexes, analyzing execution plans, and rewriting queries.
