﻿/*Factmarkethistory Load*/

DROP FUNCTION IF EXISTS FactmarkethistoryLoad();
CREATE FUNCTION FactmarkethistoryLoad()
RETURNS VOID AS $$
BEGIN

	DROP TABLE IF EXISTS FMHTemp1,FMHTemp2,FMHTemp3,FMHTemp4,FMHTemp5,FMHTemp6,FMHTemp7,FMHTemp8,FMHTemp9,
	FMHTemp10,FMHTemp11,FMHTemp12, T1,T2;
	--DELETE  FROM Factmarkethistory where SK_SecurityID is not null;


	CREATE TEMPORARY TABLE FMHTemp1 AS
	SELECT DM_S_SYMB, DM_DATE, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL,
	MAX(DM_HIGH) FILTER (WHERE DM_DATE > DM_DATE - interval '1 year') 
	OVER (PARTITION BY DM_S_SYMB ORDER BY DM_DATE ROWS UNBOUNDED PRECEDING) AS FiftyTwoWeekHigh,
	MIN(DM_LOW) FILTER (WHERE DM_DATE > DM_DATE - interval '1 year') 
	OVER (PARTITION BY DM_S_SYMB ORDER BY DM_DATE ROWS UNBOUNDED PRECEDING) AS FiftyTwoWeekLow
	FROM DailyMarket
	ORDER BY DM_S_SYMB, DM_DATE;


	CREATE TEMPORARY TABLE FMHTemp2 AS
	SELECT DM_S_SYMB, DM_DATE, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, FiftyTwoWeekHigh, FiftyTwoWeekLow,
	MIN(DM_DATE) FILTER (WHERE DM_DATE > DM_DATE - interval '1 year') 
	    OVER (PARTITION BY DM_S_SYMB, FiftyTwoWeekHigh ORDER BY DM_DATE ROWS UNBOUNDED PRECEDING) AS DateFiftyTwoWeekHigh,
	MIN(DM_DATE) FILTER (WHERE DM_DATE > DM_DATE - interval '1 year') 
	   OVER (PARTITION BY DM_S_SYMB, FiftyTwoWeekLow ORDER BY DM_DATE ROWS UNBOUNDED PRECEDING) AS DateFiftyTwoWeekLow
	FROM FMHTemp1
	ORDER BY DM_S_SYMB, DM_DATE;


	CREATE TEMPORARY TABLE FMHTemp3 AS
	SELECT DM_DATE, DM_S_SYMB, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, SK_SecurityID, 
	SK_CompanyID,  Dividend, (Dividend/DM_CLOSE)*100 AS Yield,
	FiftyTwoWeekHigh, FiftyTwoWeekLow, DateFiftyTwoWeekHigh, DateFiftyTwoWeekLow
	FROM FMHTemp2 D, DimSecurity S
	WHERE D.DM_S_SYMB = S.Symbol AND
	--S.IsCurrent=TRUE AND
	DM_DATE >= EffectiveDate AND
	DM_DATE < EndDate;


	CREATE TEMPORARY TABLE FMHTemp4 AS
	SELECT  DM_DATE, DM_S_SYMB, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, 
	SK_SecurityID, SK_CompanyID, SK_DateID, Dividend, Yield,
	FiftyTwoWeekHigh, FiftyTwoWeekLow, DateFiftyTwoWeekHigh, DateFiftyTwoWeekLow
	FROM FMHTemp3 D, DimDate S
	WHERE D.DM_DATE = S.DateValue;-- LIMIT 1000;

	--DROP TABLE IF EXISTS T1,T2, FMHTemp5
	CREATE TEMPORARY TABLE T1 AS
	SELECT EPS::NUMERIC, CoNameOrCIK, name, SK_Companyid,to_date(F.PTS, 'YYYYMMDD') AS PTS --SUM(EPS::NUMERIC) AS SumOfEPS
	FROM FIN F, DimCompany D
	where 
	F.conameorcik = D.name AND
	 to_date(F.PTS, 'YYYYMMDD') >= EffectiveDate AND 
	 to_date(F.PTS, 'YYYYMMDD') < EndDate
	GROUP BY CoNameOrCIK, name, SK_Companyid, EPS,PTS ORDER BY CoNameOrCIK;

	CREATE TEMPORARY TABLE T2 AS
	SELECT EPS::NUMERIC, CoNameOrCIK, name, SK_Companyid,to_date(F.PTS, 'YYYYMMDD') AS PTS --SUM(EPS::NUMERIC) AS SumOfEPS
	FROM FIN F, DimCompany D
	where 
	LENGTH(CoNameOrCIK) =10 AND
	 F.conameorcik::INTEGER = D.CompanyID AND 
	 to_date(F.PTS, 'YYYYMMDD') >= EffectiveDate AND 
	 to_date(F.PTS, 'YYYYMMDD') < EndDate 
	GROUP BY CoNameOrCIK, name, SK_Companyid, EPS,PTS ORDER BY CoNameOrCIK;

	CREATE TEMPORARY TABLE FMHTemp5 AS
	SELECT * FROM T1
	UNION 
	SELECT * FROM T2;




	CREATE TEMPORARY TABLE FMHTemp6 AS
	SELECT SK_Companyid, SUM(EPS) AS SUMOFEPS
	FROM FMHTemp5
	GROUP BY SK_Companyid ORDER BY SK_Companyid;

	CREATE TEMPORARY TABLE FMHTemp7 AS
	SELECT DM_DATE, DM_S_SYMB, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, 
	SK_SecurityID, F.SK_CompanyID, SK_DateID, Dividend, Yield,SUMOFEPS,(DM_CLOSE/SUMOFEPS) AS PERatio,
	FiftyTwoWeekHigh, FiftyTwoWeekLow, DateFiftyTwoWeekHigh, DateFiftyTwoWeekLow
	FROM FMHTemp4 F LEFT OUTER JOIN FMHTemp6 S
	ON( F.SK_CompanyID =  S.SK_CompanyID);





	--DROP TABLE IF EXISTS FMHTemp6
	/*CREATE TEMPORARY TABLE FMHTemp6 AS
	SELECT DM_DATE, DM_S_SYMB, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, 
	SK_SecurityID, F.SK_CompanyID, SK_DateID, Dividend, Yield,
	FiftyTwoWeekHigh, FiftyTwoWeekLow, DateFiftyTwoWeekHigh, DateFiftyTwoWeekLow,
	--EPS, CoNameOrCIK, name, SK_Companyid
	SUM(S.EPS) FILTER (WHERE S.PTS BETWEEN (DM_DATE - interval '1 year') AND DM_DATE) 
	OVER (PARTITION BY S.SK_Companyid) AS SUMOFEPS
	FROM FMHTemp4 F, FMHTemp5 S
	WHERE F.SK_CompanyID =  S.SK_CompanyID
	AND F.SK_CompanyID=4
	ORDER BY F.SK_CompanyID LIMIT 10000;*/



	CREATE TEMPORARY TABLE FMHTemp8 AS
	SELECT DM_DATE, DM_S_SYMB, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, 
	SK_SecurityID, F.SK_CompanyID, F.SK_DateID, Dividend, Yield,SUMOFEPS,PERatio,
	FiftyTwoWeekHigh, FiftyTwoWeekLow, DateFiftyTwoWeekHigh, DateFiftyTwoWeekLow,
	D.SK_DateID AS SK_FiftyTwoWeekHighDate
	  FROM FMHTemp7 F LEFT OUTER JOIN DimDate D
	ON
	(F.DateFiftyTwoWeekHigh = D.Datevalue);


	CREATE TEMPORARY TABLE FMHTemp9 AS
	SELECT DM_DATE, DM_S_SYMB, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, 
	SK_SecurityID, F.SK_CompanyID, F.SK_DateID, Dividend, Yield,SUMOFEPS,PERatio,
	FiftyTwoWeekHigh, FiftyTwoWeekLow, DateFiftyTwoWeekHigh, DateFiftyTwoWeekLow,SK_FiftyTwoWeekHighDate,
	D.SK_DateID AS SK_FiftyTwoWeekLowDate
	  FROM FMHTemp8 F LEFT OUTER JOIN DimDate D
	ON
	(F.DateFiftyTwoWeekLow = D.Datevalue);


	INSERT INTO Factmarkethistory( SK_SecurityID, SK_CompanyID, SK_DateID, PERatio, Yield, FiftyTwoWeekHigh,
	SK_FiftyTwoWeek, FiftyTwoWeekLow, SK_FiftyTwoWeekL, ClosePrice,  DayHigh, DayLow, Volume, BatchID)
	SELECT SK_SecurityID, SK_CompanyID, SK_DateID, PERatio, Yield, FiftyTwoWeekHigh,
	SK_FiftyTwoWeekHighDate, FiftyTwoWeekLow, SK_FiftyTwoWeekLowDate, DM_CLOSE, DM_HIGH, DM_LOW, DM_VOL, 1
	FROM
	FMHTemp9;

	INSERT INTO DImessages(MessageDateAndTime, BatchID, MessageSource, MessageText, MessageType,MessageData)
	SELECT CURRENT_TIMESTAMP, 1, 'FactMarketHistory', 'No earnings for company', 'Alert',
	CONCAT('DM_S_SYMB = ',DM_S_SYMB)
	FROM
	FMHTemp9 
	WHERE
	SUMOFEPS IS NULL;
END;
$$ LANGUAGE 'plpgsql';
