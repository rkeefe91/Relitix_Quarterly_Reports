USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_CarolinaOneQuarterlyMarketAreaTab]    Script Date: 5/19/2020 11:34:17 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO














-- ==============================================================================================
-- Author:		Matt Michalowski
-- Create date: 4/14/2020
-- Description:	Carolina One Quarterly Stats - Market Area Tab

--Changes: Added Median DOM calculation
--5/12/2020: Corrected median calculations		   

-- ==============================================================================================
CREATE PROCEDURE [dbo].[rpt_CarolinaOneQuarterlyMarketAreaTab]
--@PropertySubtype VARCHAR(255)
	@eval_date DATE=NULL,
	@py_eval_date DATE=NULL,
	@cy_qtr_start DATE=NULL,
	@cy_qtr_end DATE=NULL,
	@py_qtr_start DATE=NULL,
	@py_qtr_end DATE=NULL

AS
BEGIN
 -- SET NOCOUNT ON added to prevent extra result sets from
 -- interfering with SELECT statements.
 SET NOCOUNT ON;


----Parse param values into table which will be an inner join on main data query.
----SELECT Item
----INTO #SubTypes_List 
----FROM
----Relitix_Dev.dbo.DelimitedSplit8K(@PropertySubType,',')
DROP TABLE IF EXISTS #cte
DROP TABLE IF EXISTS #inv
DROP TABLE IF EXISTS #pyinv
DROP TABLE IF EXISTS #work_lci

--Set Date Defaults
set @cy_qtr_start=(SELECT DATEADD(qq, DATEDIFF(qq, 0, GETDATE()) - 1, 0)) --First Day of Previous Qtr
set @cy_qtr_end=(Select DateAdd(day, -1, dateadd(qq, DateDiff(qq, 0, GETDATE()), 0))) --Last Day of Previous Qtr
set @py_qtr_start=(SELECT DATEADD(YEAR,-1,@cy_qtr_start)) --First Day of Previous Qtr (Prior Year)
set @py_qtr_end=(SELECT DATEADD(YEAR,-1,@cy_qtr_end)) --Last Day of Previous Qtr (Prior Year)

--Base table for inventory numbers
select CASE WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('21') THEN 'James Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('23') THEN 'Johns Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('11','12') THEN 'West Ashley'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('22') THEN 'Folly Beach'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('51') THEN 'Downtown Inside Crosstown'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('52') THEN 'Downtown Charleston Above the Crosstown'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('41') THEN 'North Mt. Pleasant'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('42') THEN 'South Mt. Pleasant'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('77') THEN 'Daniel Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('31','32') THEN 'North Charleston'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('43') THEN 'Sulivan''s Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('44') THEN 'Isle of Palms'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('45') THEN 'Wild Dunes'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('25') THEN 'Kiawah Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('61','62','63') THEN 'Summerville'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('72','73') THEN 'Goose Creek'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('76') THEN 'Moncks Corner'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('71') THEN 'Hanahan'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('82') THEN 'Walterboro'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('26','28') THEN 'Edisto Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('27') THEN 'Edisto Beach'
ELSE '' END As Area,
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
	--AND lc.PropertySubType='Single Family Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('21', '23', '11','12', '22', '51','52', '51', '41', '42', '77', '31','32', '43', '44', '45', '25', '61','62','63', '72','73', '76', '71', '82', '26','27','28')

--UNION ALL

--select 'Downtown Inside of Crosstown' As Area,
--lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice
--from listings_combined lc
--	join listings_combined_geo g
--		on lc.listingkey = g.listingkey
--			and lc.sourcesystemid = g.sourcesystemid
--join
--Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
--			where 
--	lc.PropertyType='Residential'
--	--AND lc.PropertySubType='Single Family Residential'
--	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('51')

UNION ALL


select 'South of Broad' As Area,
lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,lc.StatusChangeTimestamp
from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.PropertyType='Residential'
	--AND lc.PropertySubType='Single Family Residential'
	and Subdivision='South of Broad'


UNION ALL



select 'CHS Tri-County' As Area,
lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,lc.StatusChangeTimestamp
from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.PropertyType='Residential'
	--AND lc.PropertySubType='Single Family Residential'
	and m.CountyOrParrish in ('Berkeley','Dorchester','Charleston')

--Base table for solds
			select CASE WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('21') THEN 'James Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('23') THEN 'Johns Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('11','12') THEN 'West Ashley'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('22') THEN 'Folly Beach'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('51') THEN 'Downtown Inside Crosstown'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('52') THEN 'Downtown Charleston Above the Crosstown'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('41') THEN 'North Mt. Pleasant'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('42') THEN 'South Mt. Pleasant'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('77') THEN 'Daniel Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('31','32') THEN 'North Charleston'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('43') THEN 'Sulivan''s Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('44') THEN 'Isle of Palms'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('45') THEN 'Wild Dunes'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('25') THEN 'Kiawah Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('61','62','63') THEN 'Summerville'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('72','73') THEN 'Goose Creek'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('76') THEN 'Moncks Corner'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('71') THEN 'Hanahan'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('82') THEN 'Walterboro'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('26','28') THEN 'Edisto Island'
WHEN LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) IN ('27') THEN 'Edisto Beach'
ELSE '' END As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
lc.*
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
	--AND lc.PropertySubType='Single Family Residential'
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) 
	in ('21', '23', '11','12', '22', '51','52', '51', '41', '42', '77', '31','32', '43', '44', '45', '25', '61','62','63', '72','73', '76', '71', '82', '26','27','28')

--UNION ALL

--select 'Downtown Inside of Crosstown' As Area,
--datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
--lc.*
--			from listings_combined lc
--	join listings_combined_geo g
--		on lc.listingkey = g.listingkey
--			and lc.sourcesystemid = g.sourcesystemid
--join
--Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
--			where 
--	lc.closedate IS NOT NULL
--	AND lc.PropertyType='Residential'
--	--AND lc.PropertySubType='Single Family Residential'
--	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) 
--	in ('51')

UNION ALL

select 'South of Broad' As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
lc.*
			from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.closedate IS NOT NULL
	AND lc.PropertyType='Residential'
	--AND lc.PropertySubType='Single Family Residential'
	and Subdivision='South of Broad'

UNION ALL

select 'CHS Tri-County' As Area,
datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
lc.*
			from listings_combined lc
	join listings_combined_geo g
		on lc.listingkey = g.listingkey
			and lc.sourcesystemid = g.sourcesystemid
join
Listings_CHARLESTON m on lc.ListingKey=m.ListingKey and lc.SourceSystemID=m.SourceSystemiD
			where 
	lc.closedate IS NOT NULL
	AND lc.PropertyType='Residential'
	--AND lc.PropertySubType='Single Family Residential'
	and m.CountyOrParrish in ('Berkeley','Dorchester','Charleston')

--inv as (
        select 
			YEAR(@cy_qtr_end) As InvYear
			,area
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
        GROUP BY area


		 select 
			YEAR(@py_qtr_end) As InvYear,
			area
            ,Count(Rtx_LC_ID) as total_listings
            --,AVG(DATEDIFF(DAY,listingcontractdate,@py_qtr_end)) as avg_DOM
        INTO #pyinv
		from #work_lci cte
        where StandardStatus <> 'Coming Soon'
                    AND (
                        StandardStatus = 'Active' AND (
                                                            ListingContractDate < @py_eval_date
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Active Under Contract' AND (
                                                            ListingContractDate < @py_eval_date
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Expired' AND (
                                                            ListingContractDate < @py_eval_date
                                                            AND (CloseDate IS NULL OR CloseDate > @py_eval_date)
                                                            AND StatusChangeTimestamp>@py_eval_date
        ​
                                                            )
        ​
                        OR StandardStatus = 'Pending' AND (
                                                            ListingContractDate < @py_eval_date
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Closed' AND (
                                                            ListingContractDate < @py_eval_date
                                                            AND (coalesce(closedate, statuschangetimestamp) > @py_eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Withdrawn' AND (
                                                            ListingContractDate < @py_eval_date
                                                            AND (CloseDate IS NULL OR CloseDate > @py_eval_date)
                                                            AND statuschangetimestamp > @py_eval_date
                                                            )
                        OR StandardStatus = 'Canceled' AND (
                                                            ListingContractDate < @py_eval_date
                                                            AND (CloseDate IS NULL OR CloseDate > @py_eval_date)
                                                            AND statuschangetimestamp > @py_eval_date
                                                            )
                            )
        GROUP BY area




SELECT
	a.*,b.MedianPrice,
	inv.total_listings As ActiveListings,
	dom.avg_DOM
FROM
(
select
Area,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
	,sum(closeprice) as sales_volume
	,count(*) as sales_count
	,avg(closePrice) as avg_sale
from 
#cte
Group by
Area,
DATEPART(Quarter,closedate),
year(closedate)
) a
INNER JOIN
(
select distinct
Area,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY 
									DATEPART(Quarter,closedate),
									year(closedate), 
									Area
								) AS MedianPrice
from 
#cte 
--Group by
--Area,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) b
ON a.yr=b.yr 
and a.Qtr=b.Qtr
and a.Area=b.Area
left join
(
select * from #inv
union all
select * from #pyinv
) inv on a.yr=inv.InvYear and a.Area=inv.Area
left join
(
select distinct
area,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [cumulative dom])   
                            OVER (
									PARTITION BY 
									DATEPART(Quarter,closedate),
									year(closedate), 
									area
								) AS avg_DOM
from #cte
--Group by
--area,
--[cumulative dom],
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) DOM on a.yr=dom.yr and a.qtr=dom.qtr and a.area=dom.area



END












GO

