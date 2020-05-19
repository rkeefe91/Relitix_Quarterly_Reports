USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_KRE_Quarterly_CustomGeoLevel]    Script Date: 5/19/2020 2:36:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO











-- ==============================================================================================
-- Author:		Matt Michalowski
-- Create date: 1/17/2019
-- Description:	KRE Quarterly CustomGeo Level Report

--Changes:
--7/12/2019 - Removed all "non-lakefront" geographies as the request was "Lakefront" only
--4/15/2020 - Added logic to populate 0 values for custom geos that did not have sales in that yr/qtr
--5/12/2020 - Fixed Median calculation
-- ==============================================================================================
CREATE PROCEDURE [dbo].[rpt_KRE_Quarterly_CustomGeoLevel]
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

--Populate CustomGeos
SELECT *
INTO #CustomGeos
FROM
(
select distinct custom_geo from relitix_dev.dbo.listings_custom_geo where custom_geo like '%lakefront%'
) geo


--Main Dataset
SELECT
	a.*,b.MedianPrice
INTO #rpt
FROM
(
select
cust.custom_geo,
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
					on cust.ListingKey=l.ListingKey and cust.SSID=l.sourcesystemid and cust.LakefrontFlag=1
join
#CustomGeos m on cust.custom_geo=m.custom_geo
INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where 
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
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
					on cust.ListingKey=l.ListingKey and cust.SSID=l.sourcesystemid and cust.LakefrontFlag=1
join
#CustomGeos m on cust.custom_geo=m.custom_geo
where
	closedate IS NOT NULL
	AND l.PropertyType='Residential'
--Group by
--cust.custom_geo,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) b
ON a.yr=b.yr 
and a.Qtr=b.Qtr
and a.custom_geo=b.custom_geo

--insert missing custom_geo, yr, and qtr combos
INSERT INTO #rpt
select cg.custom_geo,cg.Qtr,cg.yr,0,0,0,0,0,0
from
(
select cg.*,r.* from #CustomGeos cg
cross join
(select distinct yr,qtr from #rpt) r
) cg left join
#rpt r on cg.custom_geo=r.custom_geo and cg.yr=r.yr and cg.qtr=r.qtr
where r.custom_geo is null

select * from #rpt


END









GO

