USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_KRE_Quarterly_Towns&Communities_Alt]    Script Date: 5/19/2020 2:41:06 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- ==============================================================================================
-- Author:		Matt Michalowski
-- Create date: 7/12/2019
-- Description:	KRE Quarterly Towns & Communities Level Report

--Changes: 5/12/2020 - Fixed Median calculations

-- ==============================================================================================
CREATE PROCEDURE [dbo].[rpt_KRE_Quarterly_Towns&Communities_Alt]
@PropertySubtype VARCHAR(255)

AS
BEGIN
 -- SET NOCOUNT ON added to prevent extra result sets from
 -- interfering with SELECT statements.
 SET NOCOUNT ON;


--Parse param values into table which will be an inner join on main data query.
SELECT Item
INTO #SubTypes_List 
FROM
Relitix_Dev.dbo.DelimitedSplit8K(@PropertySubType,',')

--Populate municipalities
SELECT *
INTO #KRE_Municipalities
FROM
(
SELECT 'Bloomfield' As Muni,'T' As MuniType UNION ALL
SELECT 'Burlington' As Muni,'C' As MuniType UNION ALL
SELECT 'Darien' As Muni,'T' As MuniType UNION ALL
SELECT 'Delavan' As Muni,'C' As MuniType UNION ALL
SELECT 'Delavan' As Muni,'T' As MuniType UNION ALL
SELECT 'Elkhorn' As Muni,'C' As MuniType UNION ALL
SELECT 'Fontana-on-Geneva Lake' As Muni,'V' As MuniType UNION ALL
SELECT 'Geneva' As Muni,'T' As MuniType UNION ALL
SELECT 'Genoa City' As Muni,'V' As MuniType UNION ALL
SELECT 'La Grange' As Muni,'T' As MuniType UNION ALL
SELECT 'Lafayette' As Muni,'T' As MuniType UNION ALL
SELECT 'Lake Geneva' As Muni,'C' As MuniType UNION ALL
SELECT 'Linn' As Muni,'T' As MuniType UNION ALL
SELECT 'Lyons' As Muni,'T' As MuniType UNION ALL
SELECT 'Sugar Creek' As Muni,'T' As MuniType UNION ALL
SELECT 'Walworth' As Muni,'V' As MuniType UNION ALL
SELECT 'Whitewater' As Muni,'C' As MuniType UNION ALL
SELECT 'Williams Bay' As Muni,'V' As MuniType
) muni


--Populate CustomGeos
SELECT *
INTO #CustomGeos
FROM
(
select distinct custom_geo from relitix_dev.dbo.listings_custom_geo where custom_geo IN ('Abbey Springs','Geneva National')
) geo



--Main Dataset
SELECT
	a.*,b.MedianPrice
FROM
(
select
g.Municipality,
g.MunicipalityType,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
	,sum(closeprice) as sales_volume
	,count(*) as sales_count
	,avg(closePrice) as avg_sale
	,avg(datediff(day,listingcontractdate,closedate)) as avg_dom
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
#KRE_Municipalities m on g.Municipality=m.Muni AND g.MunicipalityType=m.MuniType
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
AND l.PropertySubType IN ('Condominium','Duplex','Single Family Residential','Townhouse')
where 
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
Group by
g.Municipality,
g.MunicipalityType,
DATEPART(Quarter,closedate),
year(closedate)
) a
INNER JOIN
(
select distinct
g.Municipality,
g.MunicipalityType,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY 
									DATEPART(Quarter,closedate),
									year(closedate), 
									g.Municipality,
									g.MunicipalityType
								) AS MedianPrice
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
#KRE_Municipalities m on g.Municipality=m.Muni AND g.MunicipalityType=m.MuniType
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
	AND l.PropertySubType IN ('Condominium','Duplex','Single Family Residential','Townhouse')
--Group by
--g.Municipality,
--g.MunicipalityType,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) b
ON a.yr=b.yr 
and a.Qtr=b.Qtr
and a.Municipality=b.Municipality
and a.MunicipalityType=b.MunicipalityType


UNION ALL

--Main Dataset
SELECT
	a.*,b.MedianPrice
FROM
(
select
cust.custom_geo,
NULL As MunicipalityType,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
	,sum(closeprice) as sales_volume
	,count(*) as sales_count
	,avg(closePrice) as avg_sale
	,avg(datediff(day,listingcontractdate,closedate)) as avg_dom
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
				join relitix_dev.dbo.listings_custom_geo cust
					on cust.ListingKey=l.ListingKey and cust.SSID=l.sourcesystemid
join
#CustomGeos m on cust.custom_geo=m.custom_geo
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where 
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
	AND l.PropertySubType IN ('Condominium','Duplex','Single Family Residential','Townhouse')
Group by
cust.custom_geo,
DATEPART(Quarter,closedate),
year(closedate)
) a
INNER JOIN
(
select distinct
cust.custom_geo,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									cust.custom_geo, 
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
				join relitix_dev.dbo.listings_custom_geo cust
					on cust.ListingKey=l.ListingKey and cust.SSID=l.sourcesystemid
join
#CustomGeos m on cust.custom_geo=m.custom_geo
where
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
	AND l.PropertySubType IN ('Condominium','Duplex','Single Family Residential','Townhouse')
--Group by
--cust.custom_geo,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) b
ON a.yr=b.yr 
and a.Qtr=b.Qtr
and a.custom_geo=b.custom_geo

UNION ALL

--Main Dataset - Woodstock
SELECT
	a.*,b.MedianPrice
FROM
(
select
g.CensusPlace As Municipality,
NULL As MunicipalityType,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
	,sum(closeprice) as sales_volume
	,count(*) as sales_count
	,avg(closePrice) as avg_sale
	,avg(datediff(day,listingcontractdate,closedate)) as avg_dom
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where 
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
	AND l.SourceSystemID=10 and g.CensusPlace IN (
	'Woodstock',
'Richmond',
'Harvard',
'McHenry',
'Crystal Lake',
'Hebron',
'Bull Valley'
	)
	AND l.PropertySubType IN ('Condominium','Duplex','Single Family Residential','Townhouse')
Group by
g.CensusPlace,
DATEPART(Quarter,closedate),
year(closedate)
) a
INNER JOIN
(
select distinct
g.CensusPlace As Municpality,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									g.CensusPlace, 
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
where
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
	AND l.SourceSystemID=10 and g.CensusPlace IN (
	'Woodstock',
'Richmond',
'Harvard',
'McHenry',
'Crystal Lake',
'Hebron',
'Bull Valley'
	)
	AND l.PropertySubType IN ('Condominium','Duplex','Single Family Residential','Townhouse')
--Group by
--g.CensusPlace,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) b
ON a.yr=b.yr 
and a.Qtr=b.Qtr
and a.Municipality=b.Municpality


END









GO

