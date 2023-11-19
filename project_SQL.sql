
DROP DATABASE IF EXISTS pos;

CREATE DATABASE pos;

CREATE TABLE pos.Zip(
    zip INT PRIMARY KEY,
    city VARCHAR(100),
    `state` VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE pos.Customer(
    id INT NOT NULL PRIMARY KEY,
    firstName VARCHAR(200),
    lastName VARCHAR(200),
    email VARCHAR(100),
    address VARCHAR(1000),
    city VARCHAR(100),
    state VARCHAR(100),
    birthDate DATE,
    zip INT
) ENGINE=InnoDB;

CREATE TABLE pos.`Order`(
    id INT NOT NULL PRIMARY KEY,
    customerID INT,
    CONSTRAINT order_fk FOREIGN KEY(customerID) REFERENCES pos.Customer(id)
) ENGINE=InnoDB;

CREATE TABLE pos.`Product`(
    id INT NOT NULL PRIMARY KEY,
    app VARCHAR(200),
    price DECIMAL(4,2)
) ENGINE=InnoDB;

CREATE TABLE pos.OrderLine(
    orderID INT NOT NULL,
    productID INT NOT NULL,
    quantity INT,
    PRIMARY KEY(orderID,productID),
    CONSTRAINT orderl_fk FOREIGN KEY(orderID) REFERENCES pos.`Order`(id),
    CONSTRAINT product_fk FOREIGN KEY(productID) REFERENCES pos.Product(id)
) ENGINE=InnoDB;

CREATE TABLE pos.OrderLine_dummy(
    orderID INT NOT NULL,
    productID INT NOT NULL
) ENGINE=InnoDB;

use pos;
select * from product;

SET GLOBAL local_infile=1;
LOAD DATA LOCAL INFILE 'C:/Users/sxx210007/Desktop/pos-billing-system-sql-script/Product.csv'
INTO TABLE pos.`Product`
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id,app,@p)
set price=replace(@p,'$','');

LOAD DATA LOCAL INFILE 'C:/Users/sxx210007/Desktop/pos-billing-system-sql-script/Customer.csv' 
INTO TABLE pos.Customer
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id,firstName,lastName,email,address,city,state,zip,@bd)
SET birthDate = STR_TO_DATE(@bd,'%m/%d/%Y');

INSERT INTO Zip select DISTINCT zip,city,`state` from pos.Customer;
select * from Customer;
ALTER TABLE pos.Customer DROP COLUMN city;
ALTER TABLE pos.Customer DROP COLUMN `state`;
ALTER TABLE pos.Customer ADD CONSTRAINT zipid_fk FOREIGN KEY (zip) REFERENCES pos.Zip(zip);

LOAD DATA LOCAL INFILE 'C:/Users/sxx210007/Desktop/pos-billing-system-sql-script/Order.csv' 
INTO TABLE pos.`Order`
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(id,customerID);

LOAD DATA LOCAL INFILE 'C:/Users/sxx210007/Desktop/pos-billing-system-sql-script/OrderLine.csv' 
INTO TABLE pos.OrderLine_dummy
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(orderID,productID);

#select * from orderline_dummy;

INSERT INTO pos.OrderLine select OrderID,ProductID,COUNT(*) as quantity from pos.OrderLine_dummy GROUP BY OrderID,ProductID;

DROP TABLE pos.OrderLine_dummy;
----------------------------------

DROP TABLE IF EXISTS pos.mv_ProductCustomers;

CREATE OR REPLACE VIEW pos.v_Customers AS SELECT c.lastName,c.firstName,c.email,c.address,z.city,z.state,c.zip from pos.Customer c inner join pos.Zip z on c.zip = z.zip;

CREATE OR REPLACE VIEW pos.v_CustomerProducts 
AS 
    SELECT 
    c.lastName,
    c.firstName,
    GROUP_CONCAT(DISTINCT p.app ORDER BY p.app SEPARATOR ',') as apps
    FROM pos.Customer c LEFT JOIN pos.`Order` o ON c.id = o.customerID LEFT JOIN pos.OrderLine ol ON o.id = ol.orderID LEFT JOIN pos.Product p on ol.productID = p.id 
    GROUP BY c.lastName,c.firstName
    ORDER BY c.lastName,c.firstName;

CREATE OR REPLACE VIEW pos.v_ProductCustomers 
AS 
    SELECT 
    p.app,
    p.id as productID,
    GROUP_CONCAT(DISTINCT CONCAT(c.firstName,' ',c.lastName) ORDER BY c.lastName,c.firstName SEPARATOR ',') as customers
    FROM pos.Product p LEFT JOIN pos.OrderLine ol ON p.id=ol.productID LEFT JOIN pos.`Order` o ON ol.orderID = o.id LEFT JOIN pos.Customer c ON o.customerID = c.id
    GROUP BY p.app,p.id;

CREATE TABLE pos.mv_ProductCustomers(  
    app VARCHAR(100), 
    productID INT NOT NULL PRIMARY KEY,
    customers TEXT
)ENGINE = InnoDB;
INSERT INTO pos.mv_ProductCustomers select app,productID,customers from pos.v_ProductCustomers;

-------------------------------------

CREATE OR REPLACE INDEX app_index ON pos.Product(app);

CREATE OR REPLACE FULLTEXT INDEX customer_index ON pos.mv_ProductCustomers(customers);

-------------------------------------

START TRANSACTION;
SET autocommit=0;

INSERT INTO pos.Customer (id,firstName,lastName,email,address,birthDate,zip) VALUES(99999,'Priyanka','Tuteja','priyanka@awesome.com','Flat: 1234, RR',STR_TO_DATE('04/21/1995','%m/%d/%Y'),2216);

INSERT INTO pos.`Order` (id,customerID) VALUES(99999,99999);

INSERT INTO pos.OrderLine (orderID,productID,quantity) VALUES(99999,17,1);
INSERT INTO pos.OrderLine (orderID,productID,quantity) VALUES(99999,27,1);
INSERT INTO pos.OrderLine (orderID,productID,quantity) VALUES(99999,57,1);
COMMIT;

START TRANSACTION;
SET autocommit=0;

INSERT INTO pos.Customer (id,firstName,lastName,email,address,birthDate,zip) VALUES(99998,'Mohana','Dave','mohana@awesome.com','Flat: 5678, Z',STR_TO_DATE('05/23/1999','%m/%d/%Y'),53779);

INSERT INTO pos.`Order` (id,customerID) VALUES(99998,99997);

INSERT INTO pos.OrderLine (orderID,productID,quantity) VALUES(99998,18,2);
INSERT INTO pos.OrderLine (orderID,productID,quantity) VALUES(99998,28,2);
INSERT INTO pos.OrderLine (orderID,productID,quantity) VALUES(99998,58,2);
COMMIT;

--------------------------------------
USE pos;

ALTER TABLE OrderLine ADD COLUMN IF NOT EXISTS (
    unitPrice DECIMAL(4,2),
    totalPrice DECIMAL(6,2)
);
ALTER TABLE `Order` ADD COLUMN IF NOT EXISTS (
    totalPrice DECIMAL(6,2)
);

DELIMITER //
CREATE OR REPLACE PROCEDURE spCalculateTotals()
BEGIN 
    UPDATE OrderLine, Product SET OrderLine.unitPrice = `Product`.price WHERE OrderLine.productID = `Product`.id AND OrderLine.unitPrice IS NULL;
    UPDATE OrderLine SET OrderLine.totalPrice = OrderLine.unitPrice*OrderLine.quantity;
    CREATE OR REPLACE VIEW grouped_orderline AS SELECT OrderLine.orderID as id, SUM(OrderLine.totalPrice) as total FROM OrderLine GROUP BY OrderLine.orderID;
    UPDATE `Order`, grouped_orderline SET `Order`.totalPrice = grouped_orderline.total WHERE `Order`.id = grouped_orderline.id;

    DROP grouped_orderline;
END //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE PROCEDURE spCalculateTotalsLoop()
BEGIN
    DECLARE done INT DEFAULT false;
    DECLARE oid INT;
    DECLARE pid INT;
    DECLARE pri DECIMAL(4,2);
    DECLARE qua INT;

    DECLARE olcur CURSOR FOR SELECT o.orderID,o.productID,p.price,o.quantity from OrderLine o INNER JOIN Product p WHERE o.productID=p.id;
    DECLARE ocur CURSOR FOR SELECT id FROM `Order`;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    OPEN olcur;

    orderline_loop:LOOP
    FETCH olcur INTO oid,pid,pri,qua;

    IF done THEN
        LEAVE orderline_loop;
        END IF;

    UPDATE OrderLine ol SET ol.unitPrice = pri WHERE ol.OrderID = oid AND ol.productID = pid AND ol.unitPrice IS NULL;
    UPDATE OrderLine ol SET ol.totalPrice = pri*qua WHERE ol.OrderID = oid AND ol.productID = pid AND ol.totalPrice IS NULL;

    END LOOP orderline_loop;
    CLOSE olcur;

    SET done = false;

    OPEN ocur;

    order_loop:LOOP
    FETCH ocur INTO oid;

    IF done THEN
        LEAVE order_loop;
        END IF;

    UPDATE `Order` o SET o.totalPrice = (SELECT SUM(ol.totalPrice) FROM OrderLine ol WHERE ol.OrderID=oid GROUP BY ol.orderID) WHERE o.id = oid;

    END LOOP order_loop;
    CLOSE ocur;

END //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE PROCEDURE spFillMVProductCustomers()
    BEGIN 
    DELETE from mv_ProductCustomers;
    INSERT INTO mv_ProductCustomers select app,productID,customers from v_ProductCustomers;
END // 
DELIMITER ;

-----------------------------------------

USE pos;

CALL spCalculateTotals;

CREATE or REPLACE TABLE HistoricalPricing(
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  productID INT NOT NULL,
  changeTime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  oldPrice Double(5,2),
  newPrice Double(5,2),
  CONSTRAINT productid_fk FOREIGN KEY(productID) REFERENCES `Product`(id) ON DELETE RESTRICT
)ENGINE=InnoDB;

DELIMITER //
CREATE OR REPLACE TRIGGER before_insert_orderline
BEFORE INSERT ON OrderLine 
FOR EACH ROW
  BEGIN
  SET NEW.unitPrice = (SELECT `Product`.price FROM `Product` WHERE id=NEW.productID);
  SET NEW.totalPrice = NEW.unitPrice*CAST(NEW.quantity as DECIMAL(5,2));

  UPDATE `Order` SET totalPrice = (SELECT SUM(totalPrice)+NEW.totalPrice FROM OrderLine WHERE orderID=NEW.orderID) WHERE id=NEW.orderID;
END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER before_update_orderline
BEFORE UPDATE ON OrderLine 
FOR EACH ROW
  BEGIN
  SET NEW.unitPrice = (SELECT `Product`.price FROM `Product` WHERE id=NEW.productID);
  SET NEW.totalPrice = NEW.unitPrice*CAST(NEW.quantity as DECIMAL(5,2));

  UPDATE `Order` SET totalPrice = (SELECT SUM(totalPrice)+NEW.totalPrice-OLD.totalPrice FROM OrderLine WHERE orderID=NEW.orderID) WHERE id=NEW.orderID;
  IF OLD.productID == NEW.productID AND OLD.unitPrice == NEW.unitPrice THEN
  UPDATE `Order` SET totalPrice = (SELECT SUM(totalPrice)-OLD.totalPrice FROM OrderLine WHERE orderID=OLD.orderID) WHERE id=OLD.orderID;
  UPDATE `Order` SET totalPrice = (SELECT SUM(totalPrice)+NEW.totalPrice FROM OrderLine WHERE orderID=NEW.orderID) WHERE id=NEW.orderID;
  END IF;
END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER before_delete_orderline
BEFORE DELETE ON OrderLine 
FOR EACH ROW
  BEGIN
  UPDATE `Order` SET totalPrice = (SELECT SUM(totalPrice)-OLD.totalPrice FROM OrderLine WHERE orderID=OLD.orderID) WHERE id=OLD.orderID;
END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER after_delete_orderline
AFTER DELETE ON OrderLine 
FOR EACH ROW
BEGIN
SET @prod_id = 0;
SET @customer_names = '';
SELECT p.id as productID,
GROUP_CONCAT(DISTINCT CONCAT(c.firstName,' ',c.lastName) ORDER BY c.lastName,c.firstName SEPARATOR ',') as customers
FROM `Product` p LEFT JOIN OrderLine ol ON p.id=ol.productID LEFT JOIN `Order` o ON ol.orderID = o.id LEFT JOIN Customer c ON o.customerID = c.id WHERE p.id = OLD.productID GROUP BY p.app,p.id INTO @prod_id,@customer_names;

UPDATE mv_ProductCustomers SET customers = @customer_names WHERE productID = @prod_id;
END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER after_update_orderline
AFTER UPDATE ON OrderLine 
FOR EACH ROW
BEGIN
SET @old_customer_names = '';
SET @new_customer_names = '';
SELECT GROUP_CONCAT(DISTINCT CONCAT(c.firstName,' ',c.lastName) ORDER BY c.lastName,c.firstName SEPARATOR ',') as customers
FROM `Product` p LEFT JOIN OrderLine ol ON p.id=ol.productID LEFT JOIN `Order` o ON ol.orderID = o.id LEFT JOIN Customer c ON o.customerID = c.id WHERE p.id = OLD.productID GROUP BY p.app,p.id INTO @old_customer_names;

SELECT GROUP_CONCAT(DISTINCT CONCAT(c.firstName,' ',c.lastName) ORDER BY c.lastName,c.firstName SEPARATOR ',') as customers
FROM `Product` p LEFT JOIN OrderLine ol ON p.id=ol.productID LEFT JOIN `Order` o ON ol.orderID = o.id LEFT JOIN Customer c ON o.customerID = c.id WHERE p.id = NEW.productID GROUP BY p.app,p.id INTO @new_customer_names;

UPDATE mv_ProductCustomers SET customers = @new_customer_names WHERE productID = NEW.productID;
UPDATE mv_ProductCustomers SET customers = @old_customer_names WHERE productID = OLD.productID;

END; //
DELIMITER ;


DELIMITER //
CREATE OR REPLACE TRIGGER after_insert_orderline
AFTER INSERT ON OrderLine 
FOR EACH ROW
BEGIN
SET @customer_names = '';
SELECT GROUP_CONCAT(DISTINCT CONCAT(c.firstName,' ',c.lastName) ORDER BY c.lastName,c.firstName SEPARATOR ',') as customers
FROM pos.Product p LEFT JOIN pos.OrderLine ol ON p.id=ol.productID LEFT JOIN pos.`Order` o ON ol.orderID = o.id LEFT JOIN pos.Customer c ON o.customerID = c.id WHERE p.id = NEW.productID GROUP BY p.app,p.id INTO @customer_names;

UPDATE mv_ProductCustomers SET customers = @customer_names WHERE productID = NEW.productID;

END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER product_update
AFTER UPDATE ON `Product`
FOR EACH ROW
  BEGIN
  IF OLD.price <> NEW.price THEN
  INSERT INTO HistoricalPricing (productID,oldPrice,newPrice) VALUES(OLD.id,OLD.price,NEW.price);
  END IF;
  CALL spFillMVProductCustomers;
END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER product_insert
AFTER INSERT ON `Product`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER product_delete
AFTER DELETE ON `Product`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER customer_update
AFTER UPDATE ON `Customer`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER customer_insert
AFTER INSERT ON `Customer`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER customer_delete
AFTER DELETE ON `Customer`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER order_update
AFTER UPDATE ON `Order`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER order_insert
AFTER INSERT ON `Order`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER order_delete
AFTER DELETE ON `Order`
FOR EACH ROW
  BEGIN
  CALL spFillMVProductCustomers;
  END; //
DELIMITER ;

#---------------------------------------------------------------------------------


CREATE OR REPLACE VIEW pos.orderlinedata AS 
SELECT o.customerID,c.firstName,c.lastName,o.id orderID ,o.totalPrice,ol.quantity,p.app 
FROM pos.Order o INNER JOIN pos.Customer c ON o.customerID = c.id INNER JOIN pos.OrderLine ol ON ol.orderID = o.id INNER JOIN pos.Product p ON p.id = ol.productID;


select json_object("Customer ID",c.id,
                  "First Name",c.firstName,
                  "Last Name",c.lastName,
                  "Orders",(
                    select json_arrayagg(
                      json_object("Order ID",o.id,
                                  "Order Total",o.totalPrice,
                                  "Items",(
                                    select json_arrayagg(
                                      json_object("Quantity",ol.quantity,
                                                  "Application",p.app
                                                 )
                                          ) 
                                      from Product p INNER JOIN OrderLine ol ON ol.productID = p.id 
                                      WHERE o.id=ol.orderID)
                                   )
                                  )
                              from `Order` o 
                              where o.customerID=c.id
                          )
                  )
    FROM Customer c into OUTFILE "file.json";


