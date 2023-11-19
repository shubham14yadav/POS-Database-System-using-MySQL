# POS-Database-System-using-MySQL


Description:
This project features the creation and management of a comprehensive Point of Sale (POS) database system using MySQL. The database encompasses various entities such as Zip codes, Customers, Orders, Products, and Order Lines, providing a holistic view of the sales process. The project showcases advanced SQL techniques including table creation, data normalization, foreign key constraints, complex views, triggers, and procedures for data integrity and automated processing.

Key Features and SQL Components:

Database and Table Creation:
Initiated with DROP DATABASE IF EXISTS pos; CREATE DATABASE pos; followed by the creation of tables Zip, Customer, Order, Product, and OrderLine with proper relationships and InnoDB engine for transactional support.

Data Import and Normalization:
Used LOAD DATA LOCAL INFILE to import data into tables from CSV files and normalized data by populating the Zip table from Customer and updating foreign key references.

Complex SQL Views:
Created views v_Customers, v_CustomerProducts, and v_ProductCustomers for streamlined data retrieval and reporting, linking customers to their orders and products purchased.

Materialized View Implementation:
Implemented a materialized view mv_ProductCustomers for performance optimization in retrieving product-customer relationships.

Indexing and Full-Text Search:
Enhanced query performance and search capabilities through CREATE OR REPLACE INDEX and CREATE OR REPLACE FULLTEXT INDEX.

Transactional Data Entry:
Demonstrated transactional data entry with START TRANSACTION and COMMIT to ensure data integrity in customer and order inserts.

Dynamic Pricing and Historical Tracking:
Managed product pricing dynamically and tracked historical price changes using triggers on the Product table, storing changes in HistoricalPricing.

Automated Total Calculations:
Developed stored procedures spCalculateTotals and spCalculateTotalsLoop to automate the calculation of order totals and line item totals, ensuring data accuracy.

Advanced Triggers:
Implemented a series of triggers (before_insert_orderline, after_delete_orderline, after_update_orderline, etc.) to maintain consistency across related tables and update the materialized view mv_ProductCustomers.

JSON Data Export:
Utilized MySQL's JSON functions to export customer and order data into a structured JSON file, showcasing modern data interchange formats.

Technologies Used: MySQL.

Project Outcome:
This project successfully demonstrates the creation and management of a complex POS database system, emphasizing data integrity, normalization, performance optimization, and advanced SQL features. The system is capable of handling a wide range of POS operations, making it a robust tool for retail data management and analysis.
