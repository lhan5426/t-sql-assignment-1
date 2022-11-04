USE WideWorldImporters;
GO

-- 1. List of Persons’ full name, all their fax and phone numbers, as well as the phone number and fax of the company they are working for (if any). 
SELECT Application.People.FullName, Application.People.PhoneNumber [PersonalNumber], Application.People.FaxNumber, Sales.Customers.PhoneNumber [CompanyContactNumber], Sales.Customers.FaxNumber 
FROM Application.People LEFT JOIN Sales.Customers
ON Application.People.PersonID = Sales.Customers.CustomerID 

-- 2. If the customer's primary contact person has the same phone number as the customer’s phone number, list the customer companies. 
SELECT Application.People.FullName
			, Application.People.PhoneNumber
			, Application.People.FaxNumber
			, Sales.Customers.CustomerName
	FROM Application.People LEFT JOIN Sales.Customers
	ON Application.People.PhoneNumber = Sales.Customers.PhoneNumber
	WHERE Application.People.PhoneNumber IS NOT NULL AND Sales.Customers.PhoneNumber IS NOT NULL
	GROUP BY Application.People.FullName
			, Application.People.PhoneNumber
			, Application.People.FaxNumber
			, Sales.Customers.CustomerName
GO

-- 3. List of customers to whom we made a sale prior to 2016 but no sale since 2016-01-01.
SELECT Sales.Customers.CustomerName FROM Sales.Customers 
WHERE Sales.Customers.CustomerID IN
(SELECT DISTINCT Sales.CustomerTransactions.CustomerID
FROM Sales.CustomerTransactions
WHERE TransactionDate < '20160101') 

-- 4. List of Stock Items and total quantity for each stock item in Purchase Orders in Year 2013.
SELECT Warehouse.StockItems.StockItemName,  Warehouse.StockItemHoldings.QuantityOnHand 
FROM Warehouse.StockItems LEFT JOIN Warehouse.StockItemHoldings
ON Warehouse.StockItems.StockItemID = Warehouse.StockItemHoldings.StockItemID
WHERE Warehouse.StockItems.StockItemID IN 
(SELECT StockItemID 
FROM Purchasing.PurchaseOrderLines 
WHERE YEAR(LastReceiptDate) = 2013) 

-- 5. List of stock items that have at least 10 characters in description.
SELECT DISTINCT Warehouse.StockItems.StockItemName  
FROM Warehouse.StockItems LEFT JOIN Sales.OrderLines ON Warehouse.StockItems.StockItemID = Sales.OrderLines.StockItemID
WHERE LEN(Sales.OrderLines.Description) >= 10

-- 6. List of stock items that are not sold to the state of Alabama and Georgia in 2014.
-- SELECT * FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
SELECT Warehouse.StockItems.StockItemName FROM Warehouse.StockItems
WHERE Warehouse.StockItems.StockItemName NOT IN
(SELECT Warehouse.StockItems.StockItemName FROM Warehouse.StockItems 
JOIN Sales.OrderLines ON Warehouse.StockItems.StockItemID = Sales.OrderLines.StockItemID
JOIN Sales.Orders ON Sales.OrderLines.OrderID = Sales.Orders.OrderID
JOIN Sales.Customers ON Sales.Customers.CustomerID = Sales.Orders.CustomerID
JOIN Application.Cities ON Application.Cities.CityID = Sales.Customers.DeliveryCityID
JOIN Application.StateProvinces ON Application.Cities.StateProvinceID = Application.StateProvinces.StateProvinceID
WHERE Application.StateProvinces.StateProvinceName IN ('Alabama', 'Georgia') AND Sales.Orders.OrderDate < '20150101' AND Sales.Orders.OrderDate > '20131231')

-- 7. List of States and Avg dates for processing (confirmed delivery date – order date).
--SELECT Application.StateProvinces.StateProvinceName
SELECT Application.StateProvinces.StateProvinceName, AVG(DATEDIFF(DAY, Sales.Orders.OrderDate, Sales.Invoices.ConfirmedDeliveryTime)) AS ProcessingTime
FROM Sales.Orders JOIN Sales.Invoices ON Sales.Orders.OrderID = Sales.Invoices.OrderID
	JOIN Sales.Customers ON Sales.Invoices.CustomerID = Sales.Customers.CustomerID
	JOIN Application.Cities ON Application.Cities.CityID = Sales.Customers.PostalCityID
	JOIN Application.StateProvinces ON Application.StateProvinces.StateProvinceID = Application.Cities.StateProvinceID
GROUP BY Application.StateProvinces.StateProvinceName

-- 8. List of States and Avg dates for processing (confirmed delivery date – order date) by month.
SELECT Application.StateProvinces.StateProvinceName, MONTH(Sales.Orders.OrderDate) AS SaleMonth, AVG(DATEDIFF(DAY, Sales.Orders.OrderDate, Sales.Invoices.ConfirmedDeliveryTime)) AS ProcessingTime
FROM Sales.Orders JOIN Sales.Invoices ON Sales.Orders.OrderID = Sales.Invoices.OrderID
	JOIN Sales.Customers ON Sales.Invoices.CustomerID = Sales.Customers.CustomerID
	JOIN Application.Cities ON Application.Cities.CityID = Sales.Customers.PostalCityID
	JOIN Application.StateProvinces ON Application.StateProvinces.StateProvinceID = Application.Cities.StateProvinceID
GROUP BY Application.StateProvinces.StateProvinceName , MONTH(Sales.Orders.OrderDate)
ORDER BY Application.StateProvinces.StateProvinceName, MONTH(Sales.Orders.OrderDate)

-- 9. List of StockItems that the company purchased more than sold in the year of 2015.
SELECT Warehouse.StockItems.StockItemName 
FROM  Warehouse.StockItems JOIN
(SELECT OrderLines.StockItemID
FROM 
(SELECT DISTINCT Sales.OrderLines.StockItemID, SUM(Sales.OrderLines.Quantity) OVER(PARTITION BY Sales.OrderLines.StockItemID) AS OrderTotalQuantity
FROM Sales.OrderLines JOIN Sales.Orders ON Sales.OrderLines.OrderID = Sales.Orders.OrderID
	JOIN Warehouse.StockItems ON Sales.OrderLines.StockItemID = Warehouse.StockItems.StockItemID
WHERE YEAR(Sales.Orders.OrderDate) = 2015) [OrderLines]
JOIN 
(SELECT DISTINCT Warehouse.StockItemHoldings.StockItemID, Warehouse.StockItemHoldings.QuantityOnHand 
FROM Warehouse.StockItemHoldings
JOIN Warehouse.StockItemTransactions ON Warehouse.StockItemHoldings.StockItemID = Warehouse.StockItemTransactions.StockItemID
WHERE YEAR(Warehouse.StockItemTransactions.TransactionOccurredWhen) = 2015) [StockLines]
ON OrderLines.StockItemID = StockLines.StockItemID
WHERE OrderLines.OrderTotalQuantity > StockLines.QuantityOnHand) [Overstocked2015]
ON Warehouse.StockItems.StockItemID = Overstocked2015.StockItemID

-- 10. List of Customers and their phone number, together with the primary contact person’s name, to whom we did not sell more than 10  mugs (search by name) in the year 2016.
WITH CustomerPrimaryContact (CustomerID, PrimaryPhoneNumber, ContactFullName)
AS
(
SELECT Sales.Customers.CustomerID, Sales.Customers.PhoneNumber, Application.People.FullName
FROM Sales.Customers LEFT JOIN Application.People 
ON Application.People.PersonID = Sales.Customers.PrimaryContactPersonID 
)

SELECT CustomerPrimaryContact.CustomerID, CustomerPrimaryContact.PrimaryPhoneNumber, CustomerPrimaryContact.ContactFullName
FROM CustomerPrimaryContact
JOIN
(SELECT Sales.Invoices.CustomerID
FROM Sales.Invoices LEFT JOIN 
(SELECT Sales.OrderLines.OrderID, Sales.OrderLines.Description
FROM Sales.OrderLines
WHERE Sales.OrderLines.Description LIKE '%mug%' AND Quantity <= 10) [MugOrders]
ON Sales.Invoices.OrderID = MugOrders.OrderID AND YEAR(Sales.Invoices.InvoiceDate) = 2015) [MugOrderID]
ON [CustomerPrimaryContact].CustomerID = [MugOrderID].CustomerID

-- 11. List all the cities that were updated after 2015-01-01.
SELECT Application.Cities.CityName FROM Application.Cities JOIN
(SELECT DISTINCT Sales.Customers.PostalCityID FROM Sales.Customers JOIN
(SELECT Sales.Invoices.CustomerID FROM Sales.Invoices JOIN 
(SELECT Sales.OrderLines.OrderID FROM Sales.OrderLines
WHERE Sales.OrderLines.LastEditedWhen > '20150101') [2015Orders]
ON Sales.Invoices.OrderID =  [2015Orders].OrderID) [2015Customers]
ON Sales.Customers.CustomerID = [2015Customers].CustomerID ) [2015CityID]
ON Application.Cities.CityID = [2015CityID].PostalCityID

-- 12. List all the Order Detail (Stock Item name, delivery address, delivery state, city, country, customer name, customer contact person name, customer phone, quantity) for the date of 2014-07-01. Info should be relevant to that date.

SELECT w_si.StockItemID, w_si.StockItemName, s_c.DeliveryAddressLine2, s_c.DeliveryAddressLine1, s_c.CustomerName, s_c.PhoneNumber, s_ol.Quantity, a_city.CityName, a_sp.StateProvinceName, a_country.CountryName
FROM Sales.Orders s_o 
JOIN Sales.Customers s_c ON s_o.CustomerID = s_c.CustomerID
JOIN Sales.OrderLines s_ol ON s_o.OrderID = s_ol.OrderID 
JOIN Warehouse.StockItems w_si ON s_ol.StockItemID = w_si.StockItemID
JOIN Application.Cities a_city ON a_city.CityID = s_c.DeliveryCityID
JOIN Application.StateProvinces a_sp ON a_sp.StateProvinceID = a_city.StateProvinceID
JOIN Application.Countries a_country ON a_sp.CountryID = a_country.CountryID
WHERE s_o.OrderDate = '2014-07-01'

-- 13. List of stock item groups and total quantity purchased, total quantity sold, and the remaining stock quantity (quantity purchased – quantity sold)
SELECT Sold.StockGroupName, Purchased.QuantityPurchased, Sold.QuantitySold, Purchased.QuantityPurchased - Sold.QuantitySold [RemainingStock] 
FROM 
	(SELECT w_sisg.StockGroupID, SUM(p_pol.OrderedOuters * w_si.QuantityPerOuter) [QuantityPurchased]
	FROM  Warehouse.StockItemStockGroups w_sisg 
	JOIN Purchasing.PurchaseOrderLines p_pol ON w_sisg.StockItemID = p_pol.StockItemID
	JOIN Warehouse.StockItems w_si ON p_pol.StockItemID = w_si.StockItemID
	GROUP BY w_sisg.StockGroupID) [Purchased]
JOIN 
	(SELECT w_sg.StockGroupID, w_sg.StockGroupName , SUM(s_ol.Quantity) [QuantitySold] 
	FROM Warehouse.StockGroups w_sg 
	JOIN Warehouse.StockItemStockGroups w_sisg ON w_sg.StockGroupID = w_sisg.StockItemStockGroupID
	JOIN Sales.OrderLines s_ol ON w_sisg.StockItemID = s_ol.StockItemID
	GROUP BY w_sg.StockGroupID, w_sg.StockGroupName) [Sold]
ON Purchased.StockGroupID = Sold.StockGroupID

-- 14. List of Cities in the US and the stock item that the city got the most deliveries in 2016. If the city did not purchase any stock items in 2016, print “No Sales”.
/*
SELECT a_c.CityID, a_c.CityName
FROM Application.Cities a_c JOIN 
*/
/*
SELECT s_il.StockItemID, MAX(s_il.Quantity) [MaxQUantity] FROM
Sales.InvoiceLines s_il JOIN Sales.Invoices s_i ON s_il.InvoiceID = s_i.InvoiceID
GROUP BY s_il.StockItemID
*/
SELECT s_c.DelivertyCityID, s
--Sales.Customers s_c ON a_c.CityID = s_c.DeliveryCityID) [Cities]

/*SELECT s_il.StockItemID, MAX(s_il.Quantity)
FROM Sales.InvoiceLines s_il JOIN Sales.Invoices s_i ON s_il.InvoiceID = s_i.InvoiceID
JOIN Sales.Customers s_c ON s_i.CustomerID = s_c.CustomerID
JOIN Application.Cities a_c ON s_c.PostalCityID = a_c.CityID
WHERE YEAR(s_i.ConfirmedDeliveryTime) = 2016
GROUP BY 
*/
-- 15. List any orders that had more than one delivery attempt (located in invoice table).

SELECT OrderID, COUNT(Event)
FROM Sales.Invoices s_i
CROSS APPLY OPENJSON(s_i.ReturnedDeliveryData) 
WITH 
	(
		Events nvarchar(max) '$.Events'
	) [t1]
CROSS APPLY OPENJSON(t1.Events) 
WITH 
	(
		Event nvarchar(max) '$.Event'
	) [t2]
WHERE Event = 'DeliveryAttempt'
GROUP BY OrderID
HAVING COUNT(Event) > 1

-- 16. List all stock items that are manufactured in China. (Country of Manufacture)
SELECT StockItemID
FROM Warehouse.StockItems w_si
CROSS APPLY OPENJSON(w_si.CustomFields)
WITH 
	(
		CountryOfManufacture nvarchar(max) '$.CountryOfManufacture'
	)
WHERE CountryOfManufacture = 'China'

-- 17. Total quantity of stock items sold in 2015, group by country of manufacturing.
SELECT w_si.StockItemID, CountryOfManufacture, SUM(s_ol.Quantity) [QuantitySold]
FROM Warehouse.StockItems w_si
CROSS APPLY OPENJSON(w_si.CustomFields)
WITH 
	(
		CountryOfManufacture nvarchar(max) '$.CountryOfManufacture'
	)
JOIN Sales.OrderLines s_ol ON w_si.StockItemID = s_ol.StockItemID
GROUP BY w_si.StockItemID, CountryOfManufacture

-- 18. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Stock Group Name, 2013, 2014, 2015, 2016, 2017]
DROP VIEW IF EXISTS TotalStockGroupItemsSoldByYear
GO
CREATE VIEW TotalStockGroupItemsSoldByYear
AS
SELECT StockGroupName, StockGroupID,
	SUM(CASE WHEN t1.[year] = '2013' THEN t1.TotalQuantity ELSE 0 END) [2013], 
	SUM(CASE WHEN t1.[year] = '2014' THEN t1.TotalQuantity ELSE 0 END) [2014], 
	SUM(CASE WHEN t1.[year] = '2015' THEN t1.TotalQuantity ELSE 0 END) [2015], 
	SUM(CASE WHEN t1.[year] = '2016' THEN t1.TotalQuantity ELSE 0 END) [2016], 
	SUM(CASE WHEN t1.[year] = '2017' THEN t1.TotalQuantity ELSE 0 END) [2017]
FROM
	(
	SELECT w_sg.StockGroupName, w_sisg.StockGroupID, SUM(CAST(s_ol.Quantity AS FLOAT)) [TotalQuantity], YEAR(s_o.OrderDate) [Year]
	FROM Warehouse.StockGroups w_sg 
	JOIN Warehouse.StockItemStockGroups w_sisg ON w_sg.StockGroupID = w_sisg.StockGroupID
	JOIN Sales.OrderLines s_ol ON w_sisg.StockItemID = s_ol.StockItemID
	JOIN Sales.Orders s_o ON s_ol.OrderID = s_ol.OrderID
	WHERE YEAR(s_o.OrderDate) >= '2013' AND YEAR(s_o.OrderDate) <= '2017'
	GROUP BY w_sg.StockGroupName, w_sisg.StockGroupID, YEAR(s_o.OrderDate)
	) [t1]
GROUP BY StockGroupName, StockGroupID
GO
SELECT * FROM TotalStockGroupItemsSoldByYear
GO

-- 19. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Year, Stock Group Name1, Stock Group Name2, Stock Group Name3, … , Stock Group Name10] 
DROP VIEW IF EXISTS TotalStockGroupItemsSoldByYear2
GO
CREATE VIEW TotalStockGroupItemsSoldByYear2
AS
	SELECT [Year], [1],[2],[3],[4],[5],[6],[7],[8],[9],[10]
	FROM
		(
			SELECT StockGroupID, [Year], [Value]
			FROM TotalStockGroupItemsSoldByYear dview1
			UNPIVOT
			([Value] FOR [Year] in ([2013], [2014], [2015], [2016], [2017]))
			unpiv
		) [t1]
		PIVOT
		(
			SUM(Value)
			FOR StockGroupID IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10])
		) [t2] 
GO
SELECT * FROM TotalStockGroupItemsSoldByYear2
GO

-- 20. Create a function, input: order id; return: total of that order. List invoices and use that function to attach the order total to the other fields of invoices. 
GO
CREATE FUNCTION GetOrderPriceTotal(@OrderID int)
RETURNS TABLE
AS
-- Returns total price of a specific order 
RETURN
	(
		SELECT s_ol.Quantity * s_ol.UnitPrice [TotalPrice]
		FROM Sales.Orderlines s_ol
		WHERE s_ol.OrderID = @OrderID
	)
GO

SELECT * FROM Sales.Invoices s_i CROSS APPLY GetOrderPriceTotal(s_i.OrderID)

-- 21. Create a new table called ods.Orders. Create a stored procedure, with proper error handling and transactions, that input is a date; when executed, it would find orders of that day, calculate order total, and save the information (order id, order date, order total, customer id) into the new table. If a given date is already existing in the new table, throw an error and roll back. Execute the stored procedure 5 times using different dates. 
DROP SCHEMA IF EXISTS ods
GO
CREATE SCHEMA ods
GO
DROP TABLE IF EXISTS ods.Orders
CREATE TABLE ods.Orders (
    OrderID INT PRIMARY KEY,
	OrderDate DATE,
	OrderTotal DECIMAL(18,2),
	CustomerID INT
)
GO

-- code from MSSQL documentation  
--https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql?view=sql-server-ver16
CREATE PROCEDURE usp_GetErrorInfo  
AS  
SELECT  
    ERROR_NUMBER() AS ErrorNumber  
    ,ERROR_SEVERITY() AS ErrorSeverity  
    ,ERROR_STATE() AS ErrorState  
    ,ERROR_PROCEDURE() AS ErrorProcedure  
    ,ERROR_LINE() AS ErrorLine  
    ,ERROR_MESSAGE() AS ErrorMessage;  
GO  

DROP PROCEDURE IF EXISTS FindOrderDetails
GO

CREATE PROCEDURE FindOrderDetails
@Date date
AS
	BEGIN TRY
		-- IF EXISTS (SELECT * FROM ods.Orders WHERE OrderDate = @Date)
		--	THROW 50000, 'Date already in table; rolling back', 16
		--ELSE
			BEGIN TRANSACTION
				INSERT INTO ods.Orders(OrderId, OrderDate, OrderTotal, CustomerID)
				SELECT OrderID, @Date [OrderDate], OrderTotal, CustomerID
				FROM 
				(
					SELECT s_o.OrderID, SUM(s_ol.Quantity * s_ol.UnitPrice) [OrderTotal], s_o.CustomerID
					FROM Sales.Orders s_o JOIN Sales.OrderLines s_ol 
					ON s_o.OrderID = s_ol.OrderID
					WHERE s_o.OrderDate = @Date
					--WHERE s_o.OrderDate = '2013-11-04'
					GROUP BY s_o.OrderID, s_o.CustomerID
					
				) [t1]
			COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			EXECUTE usp_GetErrorInfo
		ROLLBACK TRANSACTION
	END CATCH
GO


EXEC FindOrderDetails @Date = '2013-11-04'
EXEC FindOrderDetails @Date = '2013-11-05'
EXEC FindOrderDetails @Date = '2013-11-06'
EXEC FindOrderDetails @Date = '2013-11-07'
EXEC FindOrderDetails @Date = '2013-11-08'

GO
SELECT * FROM ods.Orders

-- 22. Create a new table called ods.StockItem. It has following columns: [StockItemID], [StockItemName] ,[SupplierID] ,[ColorID] ,[UnitPackageID] ,[OuterPackageID] ,[Brand] ,[Size] ,[LeadTimeDays] ,[QuantityPerOuter] ,
-- [IsChillerStock] ,[Barcode] ,[TaxRate]  ,[UnitPrice],[RecommendedRetailPrice] ,[TypicalWeightPerUnit] ,[MarketingComments]  ,[InternalComments], [CountryOfManufacture], [Range], [Shelflife]. 
-- Migrate all the data in the original stock item table.
DROP TABLE IF EXISTS ods.StockItem
CREATE TABLE ods.StockItem (
    StockItemID INT PRIMARY KEY,
	StockItemName nvarchar(100),
	SupplierID INT,
	ColorID INT,
	UnitPackageID INT,
	OuterPackageID INT,
	Brand nvarchar(50),
	Size nvarchar(20),
	LeadTimeDays INT,
	QuantityPerOuter INT,
	IsChillerStock BIT,
	Barcode nvarchar(50),
	TaxRate DECIMAL(18,3),
	UnitPrice DECIMAL(18,2),
	RecommendedRetailPrice DECIMAL(18,2),
	TypicalWeightPerUnit DECIMAL(18,3),
	MarketingComments nvarchar(max),
	InternalComments nvarchar(max),
	CountryOfManufacture nvarchar(50),
	[Range] nvarchar(50),
	ShelfLife nvarchar(50)
)
GO
INSERT INTO ods.StockItem (
	   [StockItemID]
      ,[StockItemName]
      ,[SupplierID]
      ,[ColorID]
      ,[UnitPackageID]
      ,[OuterPackageID]
      ,[Brand]
      ,[Size]
      ,[LeadTimeDays]
      ,[QuantityPerOuter]
      ,[IsChillerStock]
      ,[Barcode]
      ,[TaxRate]
      ,[UnitPrice]
      ,[RecommendedRetailPrice]
      ,[TypicalWeightPerUnit]
      ,[MarketingComments]
      ,[InternalComments]
	  ,CountryOfManufacture
	  ,[Range]
	  ,ShelfLife
)
SELECT [StockItemID]
      ,[StockItemName]
      ,[SupplierID]
      ,[ColorID]
      ,[UnitPackageID]
      ,[OuterPackageID]
      ,[Brand]
      ,[Size]
      ,[LeadTimeDays]
      ,[QuantityPerOuter]
      ,[IsChillerStock]
      ,[Barcode]
      ,[TaxRate]
      ,[UnitPrice]
      ,[RecommendedRetailPrice]
      ,[TypicalWeightPerUnit]
      ,[MarketingComments]
      ,[InternalComments]
	  ,JSON_VALUE([CustomFields], 'lax $.CountryOfManufacture') [CountryOfManufacture]
	  ,JSON_VALUE([CustomFields], 'lax $.Range') [Range]
	  ,JSON_VALUE([CustomFields], 'lax $.ShelfLife') [ShelfLife]
FROM Warehouse.StockItems

SELECT * FROM ods.StockItem

-- 23. Rewrite your stored procedure in (21). Now with a given date, it should wipe out all the order data prior to the input date and load the order data that was placed in the next 7 days following the input date.
DROP PROCEDURE IF EXISTS RestartFromCurrentWeek
GO

CREATE PROCEDURE RestartFromCurrentWeek
@Date date
AS
	BEGIN TRY
		-- IF EXISTS (SELECT * FROM ods.Orders WHERE OrderDate = @Date)
		--	THROW 50000, 'Date already in table; rolling back', 16
		--ELSE
			BEGIN TRANSACTION
				DELETE FROM ods.Orders
				WHERE Day(OrderDate) < Day(@Date)
			COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			EXECUTE usp_GetErrorInfo
		ROLLBACK TRANSACTION
	END CATCH

	BEGIN TRY
		BEGIN TRANSACTION 
			INSERT INTO ods.Orders(OrderId, OrderDate, OrderTotal, CustomerID)
			SELECT OrderID, @Date [OrderDate], OrderTotal, CustomerID
			FROM 
			(
				SELECT s_o.OrderID, SUM(s_ol.Quantity * s_ol.UnitPrice) [OrderTotal], s_o.CustomerID
				FROM Sales.Orders s_o JOIN Sales.OrderLines s_ol 
				ON s_o.OrderID = s_ol.OrderID
				WHERE s_o.OrderDate = @Date 
				GROUP BY s_o.OrderID, s_o.CustomerID
					
			) [t1]
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			EXECUTE usp_GetErrorInfo
		ROLLBACK TRANSACTION
	END CATCH
GO

EXEC RestartFromCurrentWeek @date = '2013-06-12'
SELECT * FROM ods.Orders

-- 24. Consider the JSON file:
 -- Looks like that it is our missed purchase orders. Migrate these data into Stock Item, Purchase Order and Purchase Order Lines tables. Of course, save the script.

DECLARE @missing_purchase_order_json NVARCHAR(MAX) = '{
   "PurchaseOrders":[
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"7",
         "UnitPackageId":"1",
         "OuterPackageId":[6,7],
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-01",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"WWI2308"
      },
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"5",
         "UnitPackageId":"1",
         "OuterPackageId":"7",
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-025",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"269622390"
      }
   ]
}'

SELECT * 
INTO Warehouse.StockItemsCopy2
FROM OPENJSON(@missing_purchase_order_json)
WITH (PurchaseOrders nvarchar(100) '$.PurchaseOrders') [t]
CROSS APPLY OPENJSON(t.PurchaseOrders)
WITH (StockItemName nvarchar(100))
		/*
        Supplier int,
        UnitPackageId int,
		OuterPackageId nvarchar(50),
        Brand nvarchar(50),
         LeadTimeDays int,
         QuantityPerOuter int,
         TaxRate decimal(18,3),
         UnitPrice decimal(18,2),
         RecommendedRetailPrice decimal(18,2),
         TypicalWeightPerUnit decimal(18,3),
         CountryOfManufacture nvarchar(100),
         Range nvarchar(100),
         OrderDate date,
         DeliveryMethod nvarchar(50),
         ExpectedDeliveryDate date,
         SupplierReference nvarchar(20)
		 */

SELECT *
INTO Warehouse.StockItemsCopy
FROM Warehouse.StockItems
WHERE 1 <> 1

SELECT * FROM Warehouse.StockItemsCopy

-- 25. Revisit your answer in (19). Convert the result in JSON string and save it to the server using TSQL FOR JSON PATH.
SELECT * FROM TotalStockGroupItemsSoldByYear2
FOR JSON PATH, ROOT('Year')

-- 26. Revisit your answer in (19). Convert the result into an XML string and save it to the server using TSQL FOR XML PATH.
SELECT * FROM TotalStockGroupItemsSoldByYear2
FOR XML PATH, ROOT('Year')

-- 27. Create a new table called ods.ConfirmedDeliveryJson with 3 columns (id, date, value) . Create a stored procedure, input is a date. 
-- The logic would load invoice information (all columns) as well as invoice line information (all columns) and forge them into a JSON string and then insert into the new table just created. 
-- Then write a query to run the stored procedure for each DATE that customer id 1 got something delivered to him.

DROP TABLE IF EXISTS ods.ConfirmedDeliveryJson
CREATE TABLE ods.ConfirmedDeliveryJson (
    _ID INT PRIMARY KEY,
	[Date] DATE,
	[Value] nvarchar(max),
)

DROP PROCEDURE IF EXISTS LoadInvoiceInsertAsJSON
GO

CREATE PROCEDURE LoadInvoiceInsertAsJSON
@Date date
AS
	BEGIN TRANSACTION
		DECLARE @json_str nvarchar(max)
		SET @json_str =
				(SELECT s_i.[InvoiceID]
				,s_i.[CustomerID]
				,s_i.[BillToCustomerID]
				,s_i.[OrderID]
				,s_i.[DeliveryMethodID]
				,s_i.[ContactPersonID]
				,s_i.[AccountsPersonID]
				,s_i.[SalespersonPersonID]
				,s_i.[PackedByPersonID]
				,s_i.[InvoiceDate]
				,s_i.[CustomerPurchaseOrderNumber]
				,s_i.[IsCreditNote]
				,s_i.[CreditNoteReason]
				,s_i.[Comments]
				,s_i.[DeliveryInstructions]
				,s_i.[InternalComments]
				,s_i.[TotalDryItems]
				,s_i.[TotalChillerItems]
				,s_i.[DeliveryRun]
				,s_i.[RunPosition]
				,s_i.[ReturnedDeliveryData]
				,s_i.[ConfirmedDeliveryTime]
				,s_i.[ConfirmedReceivedBy]
				,s_il.[InvoiceLineID]
				,s_il.[StockItemID]
				,s_il.[Description]
				,s_il.[PackageTypeID]
				,s_il.[Quantity]
				,s_il.[UnitPrice]
				,s_il.[TaxRate]
				,s_il.[TaxAmount]
				,s_il.[LineProfit]
				,s_il.[ExtendedPrice]
				FROM [WideWorldImporters].[Sales].[Invoices] [s_i] JOIN [WideWorldImporters].[Sales].[InvoiceLines] [s_il]
				ON s_i.InvoiceID = s_il.InvoiceID
				FOR JSON PATH, ROOT('ExtraFields')) 
		INSERT INTO ods.ConfirmedDeliveryJson([Date],[Value])
		VALUES(@Date, @json_str)
	COMMIT TRANSACTION
GO

SELECT * 
INTO Warehouse.StockItemsCopy2
FROM OPENJSON(@missing_purchase_order_json)
WITH (PurchaseOrders nvarchar(100) '$.PurchaseOrders') [t]
CROSS APPLY OPENJSON(t.PurchaseOrders)
WITH (StockItemName nvarchar(100))

/*
DECLARE @curr_date DATE
DECLARE cur CURSOR LOCAL FOR
    SELECT DISTINCT CONVERT(DATE, s_i.ConfirmedDeliveryTime) AS OrderDate
	FROM Sales.Invoices s_i 
	WHERE CustomerID = 1
OPEN cur
FETCH NEXT FROM cur INTO @curr_date
WHILE @@FETCH_STATUS = 0 BEGIN
    EXEC LoadInvoiceInsertAsJSON  @curr_date
    FETCH NEXT FROM cur INTO @curr_date
END
CLOSE cur
DEALLOCATE cur;

SELECT * FROM ods.ConfirmedDeliveryJson;
*/
