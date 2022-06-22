--1
CREATE TABLE Payments
(
	PaymentID INT IDENTITY PRIMARY KEY,
	PaymentType VARCHAR NOT NULL,
	PaidDate DATE,
	Total MONEY CHECK (Total > 0)
)
--2
CREATE TABLE Categories
(
	CategoryID INT IDENTITY PRIMARY KEY,
	CategoryGroup VARCHAR(50) NOT NULL,
	CategorySubject NVARCHAR(50) NOT NULL,
	CategoryGenre NVARCHAR(50)
)
--3
CREATE TABLE Promotions 
(
	PromotionID INT IDENTITY PRIMARY KEY,
	PromotionTitle NVARCHAR(50) NOT NULL,
	Discount DEC(5,2) CHECK(Discount > 0 AND Discount <= 100) NOT NULL,
	StartDate DATE NOT NULL,
	EndDate DATE NOT NULL,
	Description NVARCHAR(50)
)
--4
CREATE TABLE Suppliers
(
	SupplierName NVARCHAR(50) PRIMARY KEY
)
--5
CREATE TABLE Discounts
(
	DiscountID INT IDENTITY PRIMARY KEY,
	DiscountName NVARCHAR(50) NOT NULL,
	DiscountPercent DEC(5,2) CHECK(DiscountPercent > 0 AND DiscountPercent <= 100),
	StartDate DATE NOT NULL,
	EndDate DATE NOT NULL,
	Quantity INT NOT NULL
)
--6
CREATE TABLE Users
(
	UserID INT IDENTITY PRIMARY KEY,
	UserName NVARCHAR(50) NOT NULL,
	Role VARCHAR(10) CHECK(Role = 'Customer' OR Role = 'Admin'),
	Gender VARCHAR(10) CHECK(Gender = 'Male' OR Gender = 'Female'),
	Birthday DATE,
	PhoneNo VARCHAR(25),
	Email VARCHAR(50),
	Address NVARCHAR(50) NOT NULL
)
--7
CREATE TABLE Orders
(
	OrderID INT IDENTITY PRIMARY KEY,
	OrderDate DATE NOT NULL,
	TotalQuantity INT CHECK(TotalQuantity > 0), --CONSTRAINT
	TotalCost MONEY CHECK(TotalCost >= 0), --CONSTRAINT
	ShipDate DATE,
	UserID INT FOREIGN KEY REFERENCES Users(UserID),
	PaymentID INT FOREIGN KEY REFERENCES Payments(PaymentID)
)
--8
CREATE TABLE Products 
(
	ProductID INT IDENTITY PRIMARY KEY,
	ProductName NVARCHAR(50) NOT NULL,
	Price MONEY NOT NULL,
	Weight INT CHECK(Weight > 0),
	Length DEC(4,1) CHECK(Length > 0),
	Width DEC(4,1) CHECK(Width > 0),
	Height DEC(4,1) CHECK(Height > 0),
	Quantity INT CHECK(Quantity >= 0),
	Description NVARCHAR(50), 
	SupplierName NVARCHAR(50) FOREIGN KEY REFERENCES Suppliers(SupplierName)
)
--9
CREATE TABLE Stationeries
(
	StationeryID INT PRIMARY KEY,
	FOREIGN KEY (StationeryID) REFERENCES Products(ProductID),
	Brand NVARCHAR(50),
	PlaceOfProduction NVARCHAR(50),
	Color VARCHAR(50), 
	Material NVARCHAR(50)
)
--10
CREATE TABLE Books
(
	BookID INT PRIMARY KEY,
	FOREIGN KEY (BookID) REFERENCES Products(ProductID),
	Author NVARCHAR(50) NOT NULL,
	Publisher NVARCHAR(50) NOT NULL, 
	PublicationDate DATE,
	NoOfPages INT CHECK(NoOfPages > 0),
	Form NVARCHAR(50),
	Language NVARCHAR(50),
	CategoryID INT FOREIGN KEY REFERENCES Categories(CategoryID)
)
--11
CREATE TABLE Invoices
(
	InvoiceID INT IDENTITY PRIMARY KEY,
	CreatedDate DATE NOT NULL,
	OrderID INT FOREIGN KEY REFERENCES Orders(OrderID)
)
--12
CREATE TABLE ApplyDiscounts
(
	OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
	DiscountID INT FOREIGN KEY REFERENCES Discounts(DiscountID),
	PRIMARY KEY(OrderID, DiscountID)
)
--13
CREATE TABLE SupplierPromotions
(
	SupplierName NVARCHAR(50) FOREIGN KEY REFERENCES Suppliers(SupplierName),
	PromotionID INT FOREIGN KEY REFERENCES Promotions(PromotionID),
	PRIMARY KEY(SupplierName, PromotionID)
)
--14
CREATE TABLE OrderDetails
(
	OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
	ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
	PRIMARY KEY(OrderID, ProductID),
	Quantity INT CHECK(Quantity > 0)
)
--15
CREATE TABLE Reviews
(
	ReviewID INT IDENTITY PRIMARY KEY,
	Vote INT CHECK(Vote >= 0) NOT NULL,
	Comment NVARCHAR(50),
	UserID INT FOREIGN KEY REFERENCES Users(UserID),
	ProductID INT FOREIGN KEY REFERENCES Products(ProductID)
)

CREATE TABLE PromotionPrices
(
	ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
	StartDate DATE NOT NULL,
	EndDate DATE NOT NULL,
	ProPrice MONEY CHECK(ProPrice >= 0)
	PRIMARY KEY(ProductID, StartDate)
)
-----------------------------------------------------------------------------
ALTER TABLE [dbo].[Orders]
ADD OrderStatus VARCHAR(15) CHECK(OrderStatus IN ('Processing', 'Approved', 'Disapproved'))
ALTER TABLE [dbo].[Reviews]
ADD ReviewStatus VARCHAR(15) CHECK(ReviewStatus IN ('Processing', 'Approved', 'Disapproved'))

ALTER TABLE [dbo].[Promotions]
ADD SupplierName NVARCHAR(50) REFERENCES [dbo].[Suppliers](SupplierName)

--===============================================================================
--===============================================================================

--	CONSTRAINS & TRIGGERS
--3
ALTER TABLE [dbo].[Promotions]
ADD CONSTRAINT check_Date_Promotions CHECK ([StartDate] < [EndDate])
--5
ALTER TABLE [dbo].[Discounts]
ADD CONSTRAINT check_Date_Discounts CHECK ([StartDate] < [EndDate])
--7
ALTER TABLE [dbo].[Orders]
ADD CONSTRAINT check_Date_Orders CHECK(ShipDate > OrderDate)
--11
ALTER TABLE [dbo].[Invoices]
ADD CONSTRAINT UNIQUE_FK_OrderID_Invoices UNIQUE([OrderID])

ALTER TABLE [dbo].[Reviews]
ADD CONSTRAINT CK_Reviews_Vote_2 CHECK([Vote] <= 5)

ALTER TABLE [dbo].[PromotionPrices]
ADD CONSTRAINT CK_Date_PromotionPrices CHECK([StartDate] < [EndDate])

---------------------------------------
--1. ProductID của book và stationery không được trùng nhau
CREATE TRIGGER TR_CheckDuplicateID_Books_Stationeries ON [dbo].[Books]
AFTER INSERT
AS
	DECLARE @BookID INT 
	SELECT @BookID = BookID FROM inserted
	IF (EXISTS (SELECT StationeryID FROM Stationeries WHERE @BookID = StationeryID))
		BEGIN
			PRINT 'This id already exists in table Stationeries! Please change another one.'
			ROLLBACK TRANSACTION
		END

--2
CREATE TRIGGER TR_CheckDuplicateID_Stationeries_Books ON [dbo].[Stationeries]
AFTER INSERT
AS
	DECLARE @StationeryID INT 
	SELECT @StationeryID = StationeryID FROM inserted
	IF (EXISTS (SELECT BookID FROM Books WHERE @StationeryID = BookID))
		BEGIN
			PRINT 'This id already exists in table Books! Please change another one.'
			ROLLBACK TRANSACTION
		END

--3. ngày tạo hóa đơn phải sau ngày đặt hàng
CREATE TRIGGER TR_CheckDate_Invoices_Orders ON [dbo].[Invoices]
AFTER INSERT, UPDATE
AS
	DECLARE @CreatedDate DATE, @OrderID INT
	SELECT @OrderID = OrderID FROM inserted 
	SELECT @CreatedDate = CreatedDate FROM inserted
	IF @CreatedDate < (SELECT OrderDate FROM Orders WHERE OrderID = @OrderID)
		BEGIN
			PRINT 'Invoice creation date must be after order date.'
			ROLLBACK TRANSACTION
		END

--4. check coi thời gian còn hiệu lực của mã giảm giá, đảm bảo mã giảm giá được áp dụng đúng tg
CREATE TRIGGER TR_CheckDiscountAvailable ON [dbo].[ApplyDiscounts]
AFTER INSERT, UPDATE
AS
	DECLARE @OrderID INT, @DiscountID INT, @StartDate DATE, 
			@EndDate DATE, @OrderDate DATE
	SELECT @OrderID = OrderID, @DiscountID = DiscountID FROM inserted
	SELECT @StartDate = StartDate, @EndDate = EndDate FROM Discounts 
	WHERE DiscountID = @DiscountID
	SELECT @OrderDate FROM Orders WHERE OrderID = @OrderID
	IF @OrderDate NOT BETWEEN @StartDate AND @EndDate
		BEGIN
			PRINT 'The time to apply the discount code to the order is not appropriate.'
			ROLLBACK TRANSACTION
		END

--5. check coi số lượng mã giảm giá còn cho customer apply không
CREATE TRIGGER TR_CheckQuantityDiscount ON [dbo].[ApplyDiscounts]
AFTER INSERT, UPDATE
AS 
	DECLARE @DiscountID INT, @QuantityUsed INT, @Quantity INT
	SELECT @DiscountID = DiscountID FROM inserted

	SELECT @Quantity = Quantity FROM Discounts
	WHERE DiscountID = @DiscountID

	SELECT @QuantityUsed = COUNT(OrderID) FROM ApplyDiscounts
	WHERE DiscountID = @DiscountID
	GROUP BY DiscountID

	IF @Quantity < @QuantityUsed
		BEGIN
			PRINT 'This discount code has exceeded the allowed quantity.'
			ROLLBACK TRANSACTION
		END

--6. Những đơn hàng đang ở status là Processing và Disapproved thì không thể có hóa đơn
CREATE TRIGGER TR_CheckStatus_Invoices_Orders ON [dbo].[Invoices]
AFTER INSERT, UPDATE
AS 
	DECLARE @OrderID INT, @OrderStatus VARCHAR(15)
	SELECT @OrderID = OrderID FROM inserted
	SELECT @OrderStatus = OrderStatus FROM Orders 
	WHERE OrderID = @OrderID
	IF @OrderStatus IN ('Processing', 'Disapproved')
		BEGIN
			PRINT 'The order has not / not been approved.'
			ROLLBACK TRANSACTION
		END

--7. Với những đơn hàng có status là Processing thì phải kiểm tra coi số lượng sản phẩm
--còn đủ cho đơn hàng này không. Ngoài ra những đơn hàng có status là Approved muốn 
--update thêm sp được order thì cũng phải check xem còn đủ hàng không
IF OBJECT_ID('TR_CheckNoOfProductAvailable', 'TR') is not null
	drop trigger TR_CheckNoOfProductAvailable
go

CREATE TRIGGER TR_CheckNoOfProductAvailable ON [dbo].[OrderDetails]
AFTER INSERT, UPDATE
AS 
	DECLARE @Quantity INT, @NoOfProductsOrdered INT = 0, @numIncreased INT = 0,
			@ProductID INT, @num INT, @OrderID INT, @numDel INT

	SELECT @ProductID = ProductID, @num = Quantity, @OrderID = OrderID 
	FROM inserted
	SELECT @numDel = Quantity FROM deleted
	SELECT @Quantity = Quantity FROM Products WHERE ProductID = @ProductID

	IF (SELECT OrderStatus FROM Orders WHERE OrderID = @OrderID) <> 'Disapproved'
	BEGIN
		SELECT @NoOfProductsOrdered = SUM(Quantity) FROM OrderDetails
		WHERE OrderID IN (SELECT OrderID FROM [dbo].[PendingOrders])
			AND ProductID = @ProductID
		GROUP BY ProductID

		IF (SELECT OrderStatus FROM Orders WHERE OrderID = @OrderID) = 'Approved'
			SET @numIncreased = @num - @numDel

		IF (@NoOfProductsOrdered + @numIncreased) > (@Quantity * 1.2)
			BEGIN
				PRINT 'This product quantity is no longer enough for the order.'
				ROLLBACK TRANSACTION
			END
	END
	
	--TEST
	UPDATE OrderDetails
	SET Quantity = 1
	WHERE OrderID = 2 AND ProductID = 44
	
	IF (SELECT OrderStatus FROM Orders WHERE OrderID = 3) <> 'Approved'
		PRINT 'OKIE'

--8. chi co customer moi dc mua hang va review product, admin k dc
CREATE TRIGGER TR_checkRoleUsers_Orders ON [dbo].[Orders]
AFTER INSERT, UPDATE
AS
	DECLARE @UserID INT
	SELECT @UserID = UserID FROM inserted
	IF @UserID IN (SELECT UserID FROM [dbo].[Administrators])
		BEGIN
			PRINT 'Admin is not allowed to buy products.'
			ROLLBACK TRANSACTION
		END

--9
CREATE TRIGGER TR_checkRoleUsers_Reviews ON [dbo].[Reviews]
AFTER INSERT, UPDATE
AS
	DECLARE @UserID INT
	SELECT @UserID = UserID FROM inserted
	IF @UserID IN (SELECT UserID FROM [dbo].[Administrators])
		BEGIN
			PRINT 'Admin is not allowed to review products.'
			ROLLBACK TRANSACTION
		END


--10. Sau khi update status của 1 đơn hàng, nếu status dc chuyển từ Processing --> Approved
--thì số lượng sản phẩm sẽ chính thức dc trừ ra
CREATE TRIGGER TR_manageQuantityOfProduct ON [dbo].[Orders]
AFTER INSERT, UPDATE
AS
	DECLARE @StatusBefore VARCHAR(15), @StatusAfter VARCHAR(15), @OrderID INT,
			@ProductID INT, @Quantity INT

	SELECT @StatusBefore = OrderStatus FROM deleted
	SELECT @StatusAfter = OrderStatus, @OrderID = OrderID FROM inserted

	IF @StatusBefore = 'Processing' AND @StatusAfter = 'Approved'
		BEGIN
			DECLARE currentRow CURSOR
			FOR SELECT ProductID, Quantity FROM [dbo].[GetOrderDeatailsByOrderID](@OrderID)
			OPEN currentRow
			FETCH NEXT FROM currentRow INTO @ProductID, @Quantity
			WHILE @@FETCH_STATUS = 0
				BEGIN
					UPDATE Products SET Quantity = Quantity - @Quantity
					WHERE ProductID = @ProductID
					FETCH NEXT FROM currentRow INTO @ProductID, @Quantity
				END
		END

	IF @@ERROR <> 0 
		BEGIN
			PRINT @@ERROR
			ROLLBACK TRANSACTION
		END

	--test
	UPDATE Orders SET OrderStatus = 'Approved'
	WHERE OrderID = 62 --> CORRECT :>


--11. một nhà cung cấp k thể cớ 2 chương trình khuyến mãi đồng thời
CREATE TRIGGER TR_checkPromotionSameTime ON [dbo].[Promotions]
AFTER INSERT, UPDATE
AS
	DECLARE @SupplierName NVARCHAR(50), @DateB DATE, @StartDate DATE, 
			@EndDate DATE, @DateE DATE, @id INT
	SELECT @id = PromotionID, @SupplierName = SupplierName, @DateB = StartDate, @DateE = EndDate 
	FROM inserted

	IF EXISTS (SELECT * FROM [dbo].[GetPromotionsOfASupplier](@SupplierName))
		BEGIN
			DECLARE currentRow CURSOR
			FOR SELECT StartDate, EndDate FROM [dbo].[GetPromotionsOfASupplier](@SupplierName)
			WHERE PromotionID <> @id
			OPEN currentRow
			FETCH NEXT FROM currentRow INTO @StartDate, @EndDate
			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF (@DateB BETWEEN @StartDate AND @EndDate) OR (@DateE BETWEEN @StartDate AND @EndDate)
						BEGIN
							PRINT 'A supplier cannot have 2 or more promotions running concurrently.'
							ROLLBACK TRANSACTION
						END
					ELSE
						FETCH NEXT FROM currentRow INTO @StartDate, @EndDate
				END
		END
	CLOSE currentRow
	DEALLOCATE currentRow
GO

UPDATE Promotions SET EndDate = '2021-8-17' WHERE PromotionID = 7 --> correct :>

--12. sau khi inseert vào promotion thì giá của các sp do nhà cc đó cung cấp sẽ 
--được tự động giảm trong bảng PromotionPrices
CREATE TRIGGER TR_AutoUpdatePrice ON [dbo].[Promotions]
AFTER INSERT 
AS
	DECLARE @SupplierName NVARCHAR(50), @StartDate DATE, @EndDate DATE, @Discount DEC(5,2), 
			@ProductID INT, @ProPrice MONEY, @Price MONEY
	SELECT @SupplierName = SupplierName, @StartDate = StartDate, 
			@EndDate = EndDate, @Discount = Discount 
	FROM inserted

	DECLARE curRow CURSOR
	FOR SELECT ProductID, Price FROM [dbo].[GetProductsBySupplierName](@SupplierName)
	OPEN curRow
	FETCH NEXT FROM curRow INTO @ProductID, @Price
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @ProPrice = @Price - @Price * @Discount / 100
			EXEC [dbo].[InsertPromotionPrices] @ProductID, @StartDate, @EndDate, @ProPrice
			FETCH NEXT FROM curRow INTO @ProductID, @Price
		END

	CLOSE curRow
	DEALLOCATE curRow
	IF @@ERROR <> 0 
		BEGIN
			PRINT @@ERROR
			ROLLBACK TRANSACTION
		END
GO

INSERT INTO Promotions(PromotionTitle, Discount, StartDate, EndDate, SupplierName) VALUES('SCD', 20, '2021-11-4', '2021-11-5', N'NXB Trẻ')



--==
--=================================================================================
--=================================================================================

--	ADD DATA INTO TABLE
--1)	Categories
INSERT INTO Categories VALUES('Domestic Books', N'Văn Học', NULL)

--=================================================================================
--=================================================================================

--	VIEW
-- 1. Những đơn hàng đang trong tình trạng chờ xử lý
IF OBJECT_ID('PendingOrders', 'V') IS NOT NULL
DROP VIEW NV_NU
GO
CREATE VIEW PendingOrders
AS
SELECT * FROM Orders
WHERE OrderStatus = 'Processing'

--2. DS các admin 
IF OBJECT_ID('Administrators', 'V') IS NOT NULL
DROP VIEW Administrators
GO
CREATE VIEW Administrators
AS
SELECT * FROM Users
WHERE Role = 'Admin'


--==================================================================================
--==================================================================================

--	TRANSACTION

--1
BEGIN TRANSACTION
	
COMMIT TRANSACTION



--===================================================================================
--===================================================================================

--	PROCEDURE & FUNCTION
-- viết 1 function để admin kiểm duyệt coi customer review sp đó thì đã mua hay chưa



--1. trong mọi lúc, mỗi đơn hàng phải tồn tại ít nhất 1 sản phẩm
CREATE PROCEDURE InsertOrder
	@OrderDate DATE, @ShipDate DATE, @UserID INT, 
	@ProductID INT, @Quantity INT
AS
	BEGIN TRANSACTION
		DECLARE @OrderID INT
		INSERT INTO Orders(OrderDate, ShipDate, UserID) VALUES(@OrderDate, @ShipDate, @UserID)
		IF @@ERROR <> 0
			BEGIN
				ROLLBACK TRANSACTION
				PRINT @@ERROR
			END		
		ELSE
			BEGIN
				SELECT @OrderID = OrderID FROM Orders 
				WHERE OrderID NOT IN (SELECT OrderID FROM OrderDetails)
				INSERT INTO OrderDetails VALUES(@OrderID, @ProductID, @Quantity)
				IF @@ERROR <> 0
					BEGIN
						ROLLBACK TRANSACTION
						PRINT @@ERROR
					END		
			END		
	COMMIT TRANSACTION

	--TEST
	EXEC InsertOrder '2021-9-9', '2021-10-9', 1, 1, 1 --> CORRECT :>

--2. insert data into promotionPrices
CREATE PROCEDURE InsertPromotionPrices
	@ProductID INT, @StartDate DATE, @EndDate DATE, @ProPrice MONEY
AS
	BEGIN
		INSERT INTO PromotionPrices VALUES(@ProductID, @StartDate, @EndDate, @ProPrice)
	END

	EXEC InsertPromotionPrices 1, '2021-10-28', '2021-11-30', 30 --> CORRECT :>

--3.
CREATE PROCEDURE UpdateTotalQuantityOfOrders
	@OrderID INT
AS
	BEGIN
		DECLARE @TotalQuantity INT
		SELECT @TotalQuantity = SUM(Quantity) FROM OrderDetails WHERE OrderID = @OrderID
		GROUP BY OrderID
		UPDATE Orders SET TotalQuantity = @TotalQuantity WHERE OrderID = @OrderID
	END

	EXEC UpdateTotalQuantityOfOrders 2


--4.
CREATE PROCEDURE UpdateTotalCostOfOrders
	@OrderID INT
AS
	BEGIN
		DECLARE @DiscountID INT, @TotalCost MONEY, @DiscountPercent DEC(5,2),
				@TotalDiscount DEC(5,2) = 0

		DECLARE curRow CURSOR
		FOR SELECT DiscountID FROM ApplyDiscounts WHERE OrderID = @OrderID
		OPEN curRow
		FETCH NEXT FROM curRow INTO @DiscountID
		WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @DiscountPercent = DiscountPercent FROM Discounts 
				WHERE DiscountID = @DiscountID

				SET @TotalDiscount = @TotalDiscount + @DiscountPercent
				FETCH NEXT FROM curRow INTO @DiscountID
			END

		CLOSE curRow
		DEALLOCATE curRow

		SET @TotalCost = [dbo].[ComputeTotalCostOfOrder](@OrderID)
		SET @TotalCost = @TotalCost - @TotalCost * @TotalDiscount / 100
		UPDATE Orders SET TotalCost = @TotalCost WHERE OrderID = @OrderID
	END

	EXEC UpdateTotalCostOfOrders 1

--------------------------------------------------------------------------
--5. parameter là 1 orderID và sẽ return về những product của đơn hàng đó
CREATE FUNCTION GetOrderDeatailsByOrderID (@OrderID INT)
RETURNS TABLE
AS
	RETURN SELECT ProductID, Quantity FROM OrderDetails 
	WHERE OrderID = @OrderID

SELECT * FROM [dbo].[GetOrderDeatailsByOrderID](2)


--6. DS chương trình khuyến mãi của 1 nhà cung cấp

CREATE FUNCTION GetPromotionsOfASupplier (@SupplierName NVARCHAR(50))
RETURNS TABLE
AS
	RETURN SELECT * FROM Promotions WHERE SupplierName = @SupplierName

SELECT * FROM [dbo].[GetPromotionsOfASupplier](N'NXB Trẻ')
IF EXISTS (SELECT * FROM [dbo].[GetPromotionsOfASupplier](N'NXB Trẻ'))
	PRINT 'OKIE'


--7. input vào 1 nhà cung cấp và sẽ lấy được list product của nhà cc đó
CREATE FUNCTION GetProductsBySupplierName (@SupplierName NVARCHAR(50))
RETURNS TABLE
AS
	RETURN SELECT * FROM Products WHERE SupplierName = @SupplierName

SELECT * FROM [dbo].[GetProductsBySupplierName](N'Tân Việt') --> CORRECT :>

--8.
CREATE FUNCTION ComputeTotalCostOfOrder (@OrderID INT)
RETURNS MONEY
AS
	BEGIN
		DECLARE @OrderDate DATE, @ProductID INT, @Quantity INT, @ProPrice MONEY,
				@TotalCost MONEY = 0

		SELECT @OrderDate = OrderDate FROM Orders WHERE OrderID = @OrderID

		DECLARE curRow CURSOR
		FOR SELECT ProductID, Quantity FROM OrderDetails WHERE OrderID = @OrderID
		OPEN curRow
		FETCH NEXT FROM curRow INTO @ProductID, @Quantity
		WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @ProPrice = ProPrice FROM PromotionPrices 
				WHERE ProductID = @ProductID AND 
						(@OrderDate BETWEEN StartDate AND EndDate)

				IF @ProPrice IS NULL 
					SET @ProPrice = (SELECT Price FROM Products WHERE ProductID = @ProductID)

				SET @TotalCost = @TotalCost + @ProPrice * @Quantity

				SET @ProPrice = NULL
				FETCH NEXT FROM curRow INTO @ProductID, @Quantity
			END

		CLOSE curRow
		DEALLOCATE curRow

		RETURN @TotalCost
	END

	PRINT [dbo].[ComputeTotalCostOfOrder](2)

--9. Top ... sp ban chay hat
CREATE FUNCTION Top_BestSellingProducts(@top INT)
RETURNS TABLE
AS
	RETURN 
		SELECT * FROM Products WHERE ProductID IN
		(SELECT TOP (@top) ProductID FROM OrderDetails GROUP BY ProductID
		ORDER BY SUM(Quantity) DESC)

SELECT* FROM [dbo].[Top_BestSellingProducts](10)

--10. Top ... quyen sach ban chay nhat
CREATE FUNCTION Top_BestSellingBooks(@top INT)
RETURNS TABLE
AS
	RETURN 
		SELECT * FROM Products WHERE ProductID IN
		(SELECT TOP (@top) ProductID FROM OrderDetails 
		GROUP BY ProductID
		ORDER BY SUM(Quantity) DESC)

--==================================================================================
DECLARE @count INT, @i INT = 1
SELECT @count = (OrderID) FROM Orders 
WHILE @i <= @count
	BEGIN
		EXEC UpdateTotalQuantityOfOrders @i
		EXEC UpdateTotalCostOfOrders @i
		IF @@ERROR <> 0
			CONTINUE
		SET @i = @i + 1
	END
	