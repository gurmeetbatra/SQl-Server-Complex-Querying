/*1. Create a database named db_{yourfirstname}*/
create database db_Gurmeet;
/*2. Create Customer table with at least the following columns: (1/2 mark)
CustomerID INT NOT NULL
FirstName Nvarchar(50 ) NOT NULL
LastName Nvarchar(50) NOT NULL*/
create table Customer
(CustomerID INT NOT NULL,
FirstName Nvarchar(50) NOT NULL,
LastName Nvarchar(50) NOT NULL,
PRIMARY KEY(CustomerID));
/*3. Create Orders table as follows: (1/2 mark)
OrderID INT Not NULL
CustomerID INT NOT NULL
OrderDate datetime Not NULL
*/
Create table Orders
(OrderID INT Not NULL,
CustomerID INT NOT NULL,
OrderDate datetime Not NULL,
Primary Key (OrderID));
/*4. Use triggers to impose the following constraints (4 marks)
a)    A Customer with Orders cannot be deleted from Customer table.
b)   Create a custom error and use Raiserror to notify when delete Customer with Orders fails.
c)   If CustomerID is updated in Customers, referencing rows in Orders must be updated accordingly.
d)   Updating and Insertion of rows in Orders table must verify 
that CustomerID exists in Customer table, otherwise Raiserror to notify.*/
CREATE TRIGGER NoDelCustomer ON Customer
AFTER DELETE
AS 
BEGIN
	SET NOCOUNT ON;
	(SELECT * FROM deleted AS D
	JOIN Orders AS O ON D.CustomerID = O.CustomerID
	Where D.CustomerID = O.CustomerID)
	BEGIN
		RAISERROR('Customer has Order History. Can not be deleted!', 16, 1);
        ROLLBACK TRAN;
		RETURN;
	END;
END;
--Part b
CREATE TRIGGER updateCustomerID ON Customer
AFTER UPDATE
AS
BEGIN
DECLARE @id INT;
SELECT @id = CustomerID FROM inserted;
UPDATE Orders SET CustomerID = @id;
END;
--Part C
CREATE TRIGGER updateCustomerID ON Customer
AFTER UPDATE
AS
BEGIN
SET NOCOUNT ON;
DECLARE @Custid INT;
DECLARE @Delid INT;
SELECT @Custid = INSERTED.CustomerID FROM INSERTED
SELECT @Delid = deleted.CustomerID FROM deleted
UPDATE Orders SET CustomerID = @Custid where CustomerID = @Delid;
END;
--Part D
CREATE TRIGGER CustomerExist ON Orders
AFTER UPDATE, INSERT AS
BEGIN
	SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 'True' FROM inserted
        LEFT JOIN Customer ON inserted.CustomerID = Customer.CustomerID
        WHERE Customer.CustomerID IS NULL
    )
    BEGIN
            RAISERROR('Customer Does not Exist in Customer Table', 16, 1);
            ROLLBACK TRAN;
            RETURN;
    END;
END;
/*5. Create a scalar function named fn_CheckName(@FirstName, @LastName) 
to check that the FirstName and LastName are not the same. (2 marks)*/
CREATE FUNCTION fn_CheckName (@fname NVARCHAR(50), @lname NVARCHAR(50))
RETURNS BIT
AS
BEGIN
	declare @value NVARCHAR(50);
	IF(@fname = @lname)
	set @value = 'False'
	ELSE
	set @value = 'True'
	return @value
END;
/*6. Create a stored procedure called sp_InsertCustomer that would take 
Firstname and Lastname and optional CustomerID as parameters 
and Insert into Customer table.
a) If CustomerID is not provided, increment the last CustomerID and use that.
b) Use the fn_CheckName function to verify that the customer name is correct. 
Do not insert record if verification fails. (4 marks)*/
CREATE PROCEDURE dbo.sp_InsertCustomer 
	@FirstName NVARCHAR(50), 
	@LastName NVARCHAR(50),
	@CustomerID INT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @funcRes BIT;
	SET @funcRes = dbo.fn_CheckName( @FirstName, @LastName )
    IF(@CustomerID = 0)
		BEGIN
			SET @CustomerID = ( SELECT MAX(CustomerID) FROM Customer ) + 1;
		END;
	IF(@funcRes = 1)
        BEGIN
			INSERT INTO dbo.Customer
			(CustomerID, 
            FirstName, 
            LastName
			)
			VALUES
            (@CustomerID, 
            @FirstName, 
            @LastName
            );
        END;
END;
/*7. Log all updates to Customer table to CusAudit table. Indicate the previous 
and new values of data, the date and time 
and the login name of the person who made the changes. (4 marks)*/
CREATE TABLE CusAudit (
  ID int IDENTITY(1,1) PRIMARY KEY, 
  CustomerID int Not Null,
  FirstName NVARCHAR(50) NOT NULL, 
  LastName NVARCHAR(50) NOT NULL,
  UpdatedOn datetime NOT NULL,
  UpdatedBy NVARCHAR(100) NOT NULL, 
  OLD_FirstName NVARCHAR(50) NOT NULL,
  OLD_LastName NVARCHAR(50) NOT NULL
  );
Create TRIGGER UpdateInsertAudit ON Customer 
FOR UPDATE, INSERT
AS
BEGIN
	Declare @Oldfname NVARCHAR(50);
	Declare @Oldlname NVARCHAR(50);
	IF EXISTS(SELECT * FROM DELETED)
		Begin
		select @Oldfname = deleted.FirstName from deleted;
		select @Oldlname = deleted.LastName from deleted;
		end;
		else
		begin
		set @Oldfname='New Record';
		set @Oldlname='New Record';
		end;
	INSERT INTO CusAudit
         (CustomerId,
		  FirstName, 
		  LastName, 
          UpdatedBy, 
          UpdatedOn,
		  OLD_FirstName,
		  OLD_LastName
         )
	SELECT i.CustomerId, i.FirstName, i.LastName, SUSER_NAME(), GETDATE(),@Oldfname, @Oldlname FROM Customer as c
	INNER JOIN inserted as i ON c.CustomerID = i.CustomerID;
END;

