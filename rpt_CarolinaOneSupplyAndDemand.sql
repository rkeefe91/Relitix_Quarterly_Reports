USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_CarolinaOneSupplyAndDemand]    Script Date: 7/20/2020 1:27:19 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO








-- ==============================================================================================
-- Author:		Matt Michalowski
-- Create date: 4/14/2020
-- Description:	Carolina One YTD Stats - Supply and Demand Tab

--Changes: 
--6/5/2020: Added areas 74 and 78
--7/12/2020: Changed label for Area 78 to 'Clements Ferry Road/Cainhoy'

-- ==============================================================================================
CREATE PROCEDURE [dbo].[rpt_CarolinaOneSupplyAndDemand]
		@CYEndDate DATE,
		@RptYr INT,
		@eval_date DATE=NULL,
		@break1 numeric=NULL,
	@break2 numeric=NULL,
	@break3 numeric=NULL,
	@break4 numeric=NULL,
	@break5 numeric=NULL,
	@break6 numeric=NULL,
	@break7 numeric=NULL,
	@break8 numeric=NULL,
	@break9 numeric=NULL,
	@break10 numeric=NULL,
	@break11 numeric=NULL,
	@break12 numeric=NULL,
	@break13 numeric=NULL,
	@break14 numeric=NULL,
	@break15 numeric=NULL,
	@break16 numeric=NULL

AS
BEGIN
 -- SET NOCOUNT ON added to prevent extra result sets from
 -- interfering with SELECT statements.
 SET NOCOUNT ON;


DROP TABLE IF EXISTS #cte
DROP TABLE IF EXISTS #inv
DROP TABLE IF EXISTS #solds
DROP TABLE IF EXISTS #DOM
DROP TABLE IF EXISTS #work_lci


-- Set stats for each price bucket
SET @eval_date= dateadd(day,-1,@CYEndDate) --dateadd(day,-1,dateadd(day,1,dateadd(quarter, datediff(quarter, -1, getdate()) - 1, -1)))
set @break1 = 150000
set @break2 = 200000
set @break3 = 250000
set @break4 = 300000
set @break5 = 350000
set @break6 = 400000
set @break7 = 450000
set @break8 = 500000
set @break9 = 600000
set @break10 = 700000
set @break11 = 800000
set @break12 = 900000
set @break13 = 1000000
set @break14 = 1500000
set @break15 = 2000000
set @break16 = 2500000


--Base table for inventory numbers
select CASE WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('21') THEN 'James Island (21)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('23') THEN 'Johns Island (23)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('11','12') THEN 'West Ashley (11-12)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('22') THEN 'Folly Beach (22)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('51') THEN 'Downtown Inside Crosstown (51)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('41') THEN 'Mt. Pleasant - North of IOP Connector (41)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('42') THEN 'Mt. Pleasant - South of IOP Connector (42)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('77') THEN 'Daniel Island (77)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('31','32') THEN 'North Charleston (31-32)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('43') THEN 'Sulivan''s Island (43)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('44') THEN 'Isle of Palms (44)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('45') THEN 'Wild Dunes (45)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('25') THEN 'Kiawah Island (25)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('61','62','63') THEN 'Summerville (61-63)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('72','73') THEN 'Goose Creek (72-73)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('71') THEN 'Hanahan (71)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('82') THEN 'Walterboro (82)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('26','27','28') THEN 'Edisto (26-28)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('74') THEN 'Jedburg (74)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('78') THEN 'Clements Ferry Road/Cainhoy (78)'
ELSE '' END As Area,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket,
lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,lc.StatusChangeTimestamp
INTO #work_lci
from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.PropertyType='Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('21', '23', '11','12', '22', '51', '41', '42', '77', '31','32', '43', '44', '45', '25', '61','62','63', '72','73', '71', '82', '26','27','28','74','78')

UNION ALL

select 'Downtown Charleston (51-52)' As Area,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket,
lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,lc.StatusChangeTimestamp
from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.PropertyType='Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('51','52')

UNION ALL

select 'West Islands (23-26 & 30)' As Area,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket,
lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,lc.StatusChangeTimestamp
from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.PropertyType='Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('23','24','25','26','30')


UNION ALL

select 'South of Broad' As Area,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket,
lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,lc.StatusChangeTimestamp
from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.PropertyType='Residential'
	and Subdivision='South of Broad'

UNION ALL

select 'CHS Tri-County' As Area,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket,
lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,lc.StatusChangeTimestamp
from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.PropertyType='Residential'
	--and m.CountyOrParrish in ('Berkeley','Dorchester','Charleston')
	and CAST(LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) As INT) between 11 and 78

--Base table for Solds
select CASE WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('21') THEN 'James Island (21)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('23') THEN 'Johns Island (23)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('11','12') THEN 'West Ashley (11-12)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('22') THEN 'Folly Beach (22)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('51') THEN 'Downtown Inside Crosstown (51)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('41') THEN 'Mt. Pleasant - North of IOP Connector (41)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('42') THEN 'Mt. Pleasant - South of IOP Connector (42)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('77') THEN 'Daniel Island (77)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('31','32') THEN 'North Charleston (31-32)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('43') THEN 'Sulivan''s Island (43)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('44') THEN 'Isle of Palms (44)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('45') THEN 'Wild Dunes (45)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('25') THEN 'Kiawah Island (25)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('61','62','63') THEN 'Summerville (61-63)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('72','73') THEN 'Goose Creek (72-73)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('71') THEN 'Hanahan (71)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('82') THEN 'Walterboro (82)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('26','27','28') THEN 'Edisto (26-28)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('74') THEN 'Jedburg (74)'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('78') THEN 'Clements Ferry Road/Cainhoy (78)'
ELSE '' END As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [DOM],
lc.*
,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 AND lc.closeprice < @break4 then 4
							when lc.closeprice >= @break4 AND lc.closeprice < @break5 then 5
							when lc.closeprice >= @break5 AND lc.closeprice < @break6 then 6
							when lc.closeprice >= @break6 AND lc.closeprice < @break7 then 7
							when lc.closeprice >= @break7 AND lc.closeprice < @break8 then 8
							when lc.closeprice >= @break8 AND lc.closeprice < @break9 then 9
							when lc.closeprice >= @break9 AND lc.closeprice < @break10 then 10
							when lc.closeprice >= @break10 AND lc.closeprice < @break11 then 11
							when lc.closeprice >= @break11 AND lc.closeprice < @break12 then 12
							when lc.closeprice >= @break12 AND lc.closeprice < @break13 then 13
							when lc.closeprice >= @break13 AND lc.closeprice < @break14 then 14
							when lc.closeprice >= @break14 AND lc.closeprice < @break15 then 15
							else 16 end as closepricebucket,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket
			INTO #cte
			from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.closedate IS NOT NULL
	AND lc.PropertyType='Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('21', '23', '11','12', '22', '51', '41', '42', '77', '31','32', '43', '44', '45', '25', '61','62','63', '72','73','71', '82', '26','27','28','74','78')

UNION ALL

select 'Downtown Charleston (51-52)' As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [DOM],
lc.*
,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 AND lc.closeprice < @break4 then 4
							when lc.closeprice >= @break4 AND lc.closeprice < @break5 then 5
							when lc.closeprice >= @break5 AND lc.closeprice < @break6 then 6
							when lc.closeprice >= @break6 AND lc.closeprice < @break7 then 7
							when lc.closeprice >= @break7 AND lc.closeprice < @break8 then 8
							when lc.closeprice >= @break8 AND lc.closeprice < @break9 then 9
							when lc.closeprice >= @break9 AND lc.closeprice < @break10 then 10
							when lc.closeprice >= @break10 AND lc.closeprice < @break11 then 11
							when lc.closeprice >= @break11 AND lc.closeprice < @break12 then 12
							when lc.closeprice >= @break12 AND lc.closeprice < @break13 then 13
							when lc.closeprice >= @break13 AND lc.closeprice < @break14 then 14
							when lc.closeprice >= @break14 AND lc.closeprice < @break15 then 15
							else 16 end as closepricebucket,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket
			from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.closedate IS NOT NULL
	AND lc.PropertyType='Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('51','52')

UNION ALL

select 'West Islands (23-26 & 30)' As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [DOM],
lc.*
,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 AND lc.closeprice < @break4 then 4
							when lc.closeprice >= @break4 AND lc.closeprice < @break5 then 5
							when lc.closeprice >= @break5 AND lc.closeprice < @break6 then 6
							when lc.closeprice >= @break6 AND lc.closeprice < @break7 then 7
							when lc.closeprice >= @break7 AND lc.closeprice < @break8 then 8
							when lc.closeprice >= @break8 AND lc.closeprice < @break9 then 9
							when lc.closeprice >= @break9 AND lc.closeprice < @break10 then 10
							when lc.closeprice >= @break10 AND lc.closeprice < @break11 then 11
							when lc.closeprice >= @break11 AND lc.closeprice < @break12 then 12
							when lc.closeprice >= @break12 AND lc.closeprice < @break13 then 13
							when lc.closeprice >= @break13 AND lc.closeprice < @break14 then 14
							when lc.closeprice >= @break14 AND lc.closeprice < @break15 then 15
							else 16 end as closepricebucket,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket
			from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.closedate IS NOT NULL
	AND lc.PropertyType='Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('23','24','25','26','30')

UNION ALL

select 'South of Broad' As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [DOM],
lc.*
,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 AND lc.closeprice < @break4 then 4
							when lc.closeprice >= @break4 AND lc.closeprice < @break5 then 5
							when lc.closeprice >= @break5 AND lc.closeprice < @break6 then 6
							when lc.closeprice >= @break6 AND lc.closeprice < @break7 then 7
							when lc.closeprice >= @break7 AND lc.closeprice < @break8 then 8
							when lc.closeprice >= @break8 AND lc.closeprice < @break9 then 9
							when lc.closeprice >= @break9 AND lc.closeprice < @break10 then 10
							when lc.closeprice >= @break10 AND lc.closeprice < @break11 then 11
							when lc.closeprice >= @break11 AND lc.closeprice < @break12 then 12
							when lc.closeprice >= @break12 AND lc.closeprice < @break13 then 13
							when lc.closeprice >= @break13 AND lc.closeprice < @break14 then 14
							when lc.closeprice >= @break14 AND lc.closeprice < @break15 then 15
							else 16 end as closepricebucket,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket
			from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.closedate IS NOT NULL
	AND lc.PropertyType='Residential'
	and Subdivision='South of Broad'

	UNION ALL

select 'CHS Tri-County' As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [DOM],
lc.*
,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 AND lc.closeprice < @break4 then 4
							when lc.closeprice >= @break4 AND lc.closeprice < @break5 then 5
							when lc.closeprice >= @break5 AND lc.closeprice < @break6 then 6
							when lc.closeprice >= @break6 AND lc.closeprice < @break7 then 7
							when lc.closeprice >= @break7 AND lc.closeprice < @break8 then 8
							when lc.closeprice >= @break8 AND lc.closeprice < @break9 then 9
							when lc.closeprice >= @break9 AND lc.closeprice < @break10 then 10
							when lc.closeprice >= @break10 AND lc.closeprice < @break11 then 11
							when lc.closeprice >= @break11 AND lc.closeprice < @break12 then 12
							when lc.closeprice >= @break12 AND lc.closeprice < @break13 then 13
							when lc.closeprice >= @break13 AND lc.closeprice < @break14 then 14
							when lc.closeprice >= @break14 AND lc.closeprice < @break15 then 15
							else 16 end as closepricebucket,
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							when lc.listprice >= @break4 AND lc.listprice < @break5 then 5
							when lc.listprice >= @break5 AND lc.listprice < @break6 then 6
							when lc.listprice >= @break6 AND lc.listprice < @break7 then 7
							when lc.listprice >= @break7 AND lc.listprice < @break8 then 8
							when lc.listprice >= @break8 AND lc.listprice < @break9 then 9
							when lc.listprice >= @break9 AND lc.listprice < @break10 then 10
							when lc.listprice >= @break10 AND lc.listprice < @break11 then 11
							when lc.listprice >= @break11 AND lc.listprice < @break12 then 12
							when lc.listprice >= @break12 AND lc.listprice < @break13 then 13
							when lc.listprice >= @break13 AND lc.listprice < @break14 then 14
							when lc.listprice >= @break14 AND lc.listprice < @break15 then 15
							else 16 end as listpricebucket
			from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.closedate IS NOT NULL
	AND lc.PropertyType='Residential'
	--and m.CountyOrParrish in ('Berkeley','Dorchester','Charleston')
	and CAST(LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) As INT) between 11 and 78


--Inv by lpb
        select 
			area,
			listpricebucket
            ,Count(Rtx_LC_ID) as total_listings
        INTO #inv
		from #work_lci cte
        where StandardStatus <> 'Coming Soon'
                    AND (
                        StandardStatus = 'Active' AND (
                                                            ListingContractDate < @eval_date
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Active Under Contract' AND (
                                                            ListingContractDate < @eval_date
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Expired' AND (
                                                            ListingContractDate < @eval_date
                                                            AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                                            AND StatusChangeTimestamp>@eval_date
        ​
                                                            )
        ​
                        OR StandardStatus = 'Pending' AND (
                                                            ListingContractDate < @eval_date
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Closed' AND (
                                                            ListingContractDate < @eval_date
                                                            AND (coalesce(closedate, statuschangetimestamp) > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Withdrawn' AND (
                                                            ListingContractDate < @eval_date
                                                            AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                                            AND statuschangetimestamp > @eval_date
                                                            )
                        OR StandardStatus = 'Canceled' AND (
                                                            ListingContractDate < @eval_date
                                                            AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                                            AND statuschangetimestamp > @eval_date
                                                            )
                            )
        GROUP BY area,listpricebucket

--solds by lpb in last 6 months
        select area,closepricebucket
                ,Count(Rtx_LC_ID) as total_sold
				,sum(closeprice) as total_volume_sold
        into #solds
		from #cte cte
        where  CloseDate < @CYEndDate
            AND CloseDate >= DATEADD(MONTH,-6,@CYEndDate)
            AND ClosePrice > 0
        GROUP BY area,closepricebucket


--DOM
select 
	YEAR(CloseDate) As [Year],
	area,closepricebucket,
	avg(datediff(day,listingcontractdate,closedate)) as DOM
INTO #DOM
from #cte cte
where CloseDate < @CYEndDate
            AND CloseDate >= DATEADD(MONTH,-6,@CYEndDate)
            AND ClosePrice > 0
group by YEAR(CloseDate),area,closepricebucket


--Report Output
select distinct
	solds.Area,
	solds.closepricebucket As Sort,
	CASE WHEN solds.closepricebucket=1 THEN '$0 - $' + FORMAT(@break1-1,'#,##')
	WHEN solds.closepricebucket=2 THEN '$' + FORMAT(@break1,'#,##') + ' - $' + FORMAT(@break2-1,'#,##')
	WHEN solds.closepricebucket=3 THEN '$' +FORMAT(@break2,'#,##') + ' - $' + FORMAT(@break3-1,'#,##')
	WHEN solds.closepricebucket=4 THEN '$' +FORMAT(@break3,'#,##') + ' - $' + FORMAT(@break4-1,'#,##')
	WHEN solds.closepricebucket=5 THEN '$' +FORMAT(@break4,'#,##') + ' - $' + FORMAT(@break5-1,'#,##')
	WHEN solds.closepricebucket=6 THEN '$' +FORMAT(@break5,'#,##') + ' - $' + FORMAT(@break6-1,'#,##')
	WHEN solds.closepricebucket=7 THEN '$' +FORMAT(@break6,'#,##') + ' - $' + FORMAT(@break7-1,'#,##')
	WHEN solds.closepricebucket=8 THEN '$' +FORMAT(@break7,'#,##') + ' - $' + FORMAT(@break8-1,'#,##')
	WHEN solds.closepricebucket=9 THEN '$' +FORMAT(@break8,'#,##') + ' - $' + FORMAT(@break9-1,'#,##')
	WHEN solds.closepricebucket=10 THEN '$' +FORMAT(@break9,'#,##') + ' - $' + FORMAT(@break10-1,'#,##')
	WHEN solds.closepricebucket=11 THEN '$' +FORMAT(@break10,'#,##') + ' - $' + FORMAT(@break11-1,'#,##')
	WHEN solds.closepricebucket=12 THEN '$' +FORMAT(@break11,'#,##') + ' - $' + FORMAT(@break12-1,'#,##')
	WHEN solds.closepricebucket=13 THEN '$' +FORMAT(@break12,'#,##') + ' - $' + FORMAT(@break13-1,'#,##')
	WHEN solds.closepricebucket=14 THEN '$' +FORMAT(@break13,'#,##') + ' - $' + FORMAT(@break14-1,'#,##')
	WHEN solds.closepricebucket=15 THEN '$' +FORMAT(@break14,'#,##') + ' - $' + FORMAT(@break15-1,'#,##')
	WHEN solds.closepricebucket=16 THEN '$' + FORMAT(@break15,'#,##') + '+'
	ELSE NULL END As ListPriceBucket
    ,inv.total_listings As ActiveListings
    ,solds.total_sold As Sold_Prior6Months
	,DOM.DOM As AvgDOM
	--,solds.total_volume_sold
    --,(cast(inv.total_listings as real))/(cast(solds.total_sold as real)) * 3 as months_inventory
from #solds solds
left join #inv inv
        on inv.area=solds.area and inv.listpricebucket = solds.closepricebucket
		left join #DOM DOM on solds.area=DOM.area and solds.closepricebucket=DOM.closepricebucket and DOM.[Year]=@RptYr

UNION ALL

--Fill in where solds is null and active listings > 0
select distinct
	--@RptYr As Yr, 
	inv.Area,
	inv.listpricebucket As Sort,
	CASE WHEN inv.listpricebucket=1 THEN '$0 - $' + FORMAT(@break1-1,'#,##')
	WHEN inv.listpricebucket=2 THEN '$' + FORMAT(@break1,'#,##') + ' - $' + FORMAT(@break2-1,'#,##')
	WHEN inv.listpricebucket=3 THEN '$' +FORMAT(@break2,'#,##') + ' - $' + FORMAT(@break3-1,'#,##')
	WHEN inv.listpricebucket=4 THEN '$' +FORMAT(@break3,'#,##') + ' - $' + FORMAT(@break4-1,'#,##')
	WHEN inv.listpricebucket=5 THEN '$' +FORMAT(@break4,'#,##') + ' - $' + FORMAT(@break5-1,'#,##')
	WHEN inv.listpricebucket=6 THEN '$' +FORMAT(@break5,'#,##') + ' - $' + FORMAT(@break6-1,'#,##')
	WHEN inv.listpricebucket=7 THEN '$' +FORMAT(@break6,'#,##') + ' - $' + FORMAT(@break7-1,'#,##')
	WHEN inv.listpricebucket=8 THEN '$' +FORMAT(@break7,'#,##') + ' - $' + FORMAT(@break8-1,'#,##')
	WHEN inv.listpricebucket=9 THEN '$' +FORMAT(@break8,'#,##') + ' - $' + FORMAT(@break9-1,'#,##')
	WHEN inv.listpricebucket=10 THEN '$' +FORMAT(@break9,'#,##') + ' - $' + FORMAT(@break10-1,'#,##')
	WHEN inv.listpricebucket=11 THEN '$' +FORMAT(@break10,'#,##') + ' - $' + FORMAT(@break11-1,'#,##')
	WHEN inv.listpricebucket=12 THEN '$' +FORMAT(@break11,'#,##') + ' - $' + FORMAT(@break12-1,'#,##')
	WHEN inv.listpricebucket=13 THEN '$' +FORMAT(@break12,'#,##') + ' - $' + FORMAT(@break13-1,'#,##')
	WHEN inv.listpricebucket=14 THEN '$' +FORMAT(@break13,'#,##') + ' - $' + FORMAT(@break14-1,'#,##')
	WHEN inv.listpricebucket=15 THEN '$' +FORMAT(@break14,'#,##') + ' - $' + FORMAT(@break15-1,'#,##')
	WHEN inv.listpricebucket=16 THEN '$' + FORMAT(@break15,'#,##') + '+'
	ELSE NULL END As ListPriceBucket
    ,inv.total_listings As ActiveListings
     ,solds.total_sold As Sold_Prior6Months
	 ,DOM.DOM As AvgDOM   
	--,solds.total_volume_sold
    --,(cast(inv.total_listings as real))/(cast(solds.total_sold as real)) * 3 as months_inventory
from #inv inv
left join #solds solds
        on inv.area=solds.area and inv.listpricebucket = solds.closepricebucket
		left join #DOM DOM on inv.area=DOM.area and inv.listpricebucket=DOM.closepricebucket and DOM.[Year]=@RptYr
where solds.closepricebucket is null



END

















GO

