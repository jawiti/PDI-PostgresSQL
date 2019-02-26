﻿/*ProspectLoad*/
DROP FUNCTION IF EXISTS ProspectLoadInc1();
CREATE FUNCTION ProspectLoadInc1()
RETURNS VOID AS $$
BEGIN

	Drop table if exists DP1temp,DP1temp1,DP1temp2,DP1temp3,DP1temp4,DTOTAL;



	--Get SK_RecordDateID by joining BatchDate to DimDate (only one tuple)
	CREATE TEMPORARY TABLE DP1temp AS
	SELECT SK_DateID AS SK_RecordDateID, SK_DateID AS SK_UpdateDateID  
	FROM DimDate, BatchDate1
	WHERE DateValue = BatchDateColumn;

	--for each tuple in Prospect, append the SK_RecordDateID
	CREATE TEMPORARY TABLE DP1temp1 AS
	SELECT *
	FROM DP1temp, TempProspect1;

	-- add the ff. columns needed to insert into prospect table
	ALTER TABLE DP1temp1
	ADD MarketingNameplate varchar(100),
	ADD IsCustomer BOOLEAN,
	ADD BatchID INT ;

	--Check DimCustomer if there exist a tuple in the Prospect file. This is done by comparing the 
	--lastname, firstname, address 1 and 2, postalcode.
	--Store such tuples in DP1temp2
	CREATE TEMPORARY TABLE DP1temp2 AS
	SELECT D.SK_RecordDateID, D.SK_UpdateDateID, D.AgencyID, D.BatchID, D.LastName, D.FirstName,
	D.MiddleInitial, D.Gender, D.AddressLine1, D.AddressLine2, D.PostalCode, D.City, D.State, D.Country,
	D.Phone, D.Income, D.numericberCars, D.numericberChildren, D.MaritalStatus, D.Age, D.CreditRating,
	D.OwnOrRentFlag, D.Employer, D.numericberCreditCards, D.NetWorth,D.MarketingNameplate, D.IsCustomer
	FROM  DP1temp1 D , DimCustomer 
	WHERE DimCustomer.Status = 'ACTIVE' AND
	TRIM(BOTH ' ' FROM UPPER(D.LastName)) = TRIM(BOTH ' ' FROM UPPER(DimCustomer.LastName)) AND 
	TRIM(BOTH ' ' FROM UPPER(D.FirstName)) = TRIM(BOTH ' ' FROM UPPER(DimCustomer.FirstName)) AND 
	TRIM(BOTH ' ' FROM UPPER(D.AddressLine1)) = TRIM(BOTH ' ' FROM UPPER(DimCustomer.AddressLine1)) AND 
	(TRIM(BOTH ' ' FROM UPPER(D.AddressLine2)) = TRIM(BOTH ' ' FROM UPPER(DimCustomer.AddressLine2))-- AND
	 OR DimCustomer.AddressLine2 IS NULL) AND 
	TRIM(BOTH ' ' FROM UPPER(D.PostalCode)) = TRIM(BOTH ' ' FROM UPPER(DimCustomer.PostalCode));


	--For tuples in DP1temp2 (already in DimCustomer), set IsCustomer to true
	UPDATE DP1temp2
	SET IsCustomer=TRUE;

	--Get tuples that do not exist in DimCustomer by performing a difference operation
	--Store such tuples in DT
	CREATE TEMPORARY TABLE DTOTAL AS
	SELECT AgencyID, LastName ,FirstName, AddressLine1, AddressLine2, PostalCode
	FROM DP1temp1 
	EXCEPT
	SELECT  AgencyID, LastName, FirstName, AddressLine1, AddressLine2, PostalCode
	FROM DP1temp2;

	--Join DT to the Original relation (DP1temp1) to obtain the other columns
	-- Store in DP1temp3
	CREATE TEMPORARY TABLE DP1temp3 AS
		SELECT SK_RecordDateID, SK_UpdateDateID, D.AgencyID, BatchID, D.LastName, D.FirstName,
	MiddleInitial, Gender, D.AddressLine1, D.AddressLine2, D.PostalCode, City, State, Country,
	Phone, Income, numericberCars, numericberChildren, MaritalStatus, Age, CreditRating,
	OwnOrRentFlag, Employer, numericberCreditCards, NetWorth,MarketingNameplate, IsCustomer
		FROM DP1temp1 D , DTOTAL T
	WHERE D.AgencyID =T.AgencyID;

	--Set IsCustomer to FALSE for DP1temp3(Tuples that do not exist in DimCustomer)
	UPDATE DP1temp3
	SET IsCustomer=FALSE;

	--UNION Both relations
	CREATE TEMPORARY TABLE DP1temp4 AS
	SELECT SK_RecordDateID, SK_UpdateDateID, AgencyID, BatchID, LastName, FirstName,
	MiddleInitial, Gender, AddressLine1, AddressLine2, PostalCode, City, State, Country,
	Phone, Income, numericberCars, numericberChildren, MaritalStatus, Age, CreditRating,
	OwnOrRentFlag, Employer, numericberCreditCards, NetWorth,MarketingNameplate, IsCustomer
		FROM DP1temp2
	UNION
		SELECT SK_RecordDateID, SK_UpdateDateID, AgencyID, BatchID, LastName, FirstName,
	MiddleInitial, Gender, AddressLine1, AddressLine2, PostalCode, City, State, Country,
	Phone, Income, numericberCars, numericberChildren, MaritalStatus, Age, CreditRating,
	OwnOrRentFlag, Employer, numericberCreditCards, NetWorth,MarketingNameplate, IsCustomer
		FROM DP1temp3;

	--Set MarketingNameplate based on 4.5.15.1 of specifications document
		UPDATE DP1temp4
	SET MarketingNameplate =  CONCAT(MarketingNameplate, '+', 'HighValue')
	WHERE NetWorth>1000000 OR Income > 200000;

	UPDATE DP1temp4
	SET MarketingNameplate =  CONCAT(MarketingNameplate, '+', 'Expenses')
	WHERE numericberChildren>3 OR numericberCreditCards > 5;

	UPDATE DP1temp4
	SET MarketingNameplate =  CONCAT(MarketingNameplate, '+', 'Boomer')
	WHERE Age>45;

	UPDATE DP1temp4
	SET MarketingNameplate =  CONCAT(MarketingNameplate, '+', 'MoneyAlert')
	WHERE Income<50000 OR CreditRating < 600 OR NetWorth<100000;

	UPDATE DP1temp4
	SET MarketingNameplate =  CONCAT(MarketingNameplate, '+', 'Spender')
	WHERE numericberCars>3 OR numericberCreditCards > 7;

	UPDATE DP1temp4
	SET MarketingNameplate =  CONCAT(MarketingNameplate, '+', 'Inherited')
	WHERE Age<25 AND NetWorth>1000000;

	UPDATE DP1temp4
	SET BatchID  = 1;

	UPDATE DP1temp4
	SET MarketingNameplate = btrim(MarketingNameplate, '+');

	--Delete if already existing
	DELETE FROM Prospect 
	USING DP1temp4
	WHERE
	Prospect.AgencyID = DP1temp4.AgencyID;



	--Finally insert all propective customers
	INSERT INTO Prospect(SK_RecordDateID, SK_UpdateDateID,AgencyID, BatchID,IsCustomer,LastName, FirstName,
	MiddleInitial, Gender, AddressLine1, AddressLine2, PostalCode, City, State, Country,
	Phone, Income, numericberCars, numericberChildren, MaritalStatus, Age, CreditRating,
	OwnOrRentFlag, Employer, numericberCreditCards, NetWorth,MarketingNameplate)
	select SK_RecordDateID, SK_UpdateDateID,AgencyID, 2, IsCustomer, LastName, FirstName,
	MiddleInitial, Gender, AddressLine1, AddressLine2, PostalCode, City, State, Country,
	Phone, Income, numericberCars, numericberChildren, MaritalStatus, Age, CreditRating,
	OwnOrRentFlag, Employer, numericberCreditCards, NetWorth,MarketingNameplate 
	from DP1temp4 
	ORDER BY AgencyID ASC;

END;
$$ LANGUAGE 'plpgsql';

--SELECT * FROM Prospect WHERE ISCUSTOMER =FALSE;