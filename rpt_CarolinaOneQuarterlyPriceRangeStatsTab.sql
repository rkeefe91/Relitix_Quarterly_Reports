USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_CarolinaOneQuarterlyPriceRangeStatsTab]    Script Date: 5/19/2020 11:34:34 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[rpt_CarolinaOneQuarterlyPriceRangeStatsTab]
--@PropertySubtype VARCHAR(255)
	@eval_date DATE=NULL,
	@py_eval_date DATE=NULL,
	@cy_qtr_start DATE=NULL,
	@cy_qtr_end DATE=NULL,
	@py_qtr_start DATE=NULL,
	@py_qtr_end DATE=NULL,
	@break1 numeric=NULL,
	@break2 numeric=NULL,
	@break3 numeric=NULL,
	@break4 numeric=NULL
AS
BEGIN
 -- SET NOCOUNT ON added to prevent extra result sets from
 -- interfering with SELECT statements.
 SET NOCOUNT ON;


DROP TABLE IF EXISTS #cte
DROP TABLE IF EXISTS #inv
DROP TABLE IF EXISTS #pyinv
DROP TABLE IF EXISTS #solds
DROP TABLE IF EXISTS #solds_qtr
DROP TABLE IF EXISTS #pysolds
DROP TABLE IF EXISTS #pysolds_qtr
DROP TABLE IF EXISTS #DOM
DROP TABLE IF EXISTS #work_lci

	
--Set Date Defaults
set @cy_qtr_start=(SELECT DATEADD(qq, DATEDIFF(qq, 0, GETDATE()) - 1, 0)) --First Day of Previous Qtr
set @cy_qtr_end=(Select DateAdd(day, -1, dateadd(qq, DateDiff(qq, 0, GETDATE()), 0))) --Last Day of Previous Qtr
set @py_qtr_start=(SELECT DATEADD(YEAR,-1,@cy_qtr_start)) --First Day of Previous Qtr (Prior Year)
set @py_qtr_end=(SELECT DATEADD(YEAR,-1,@cy_qtr_end)) --Last Day of Previous Qtr (Prior Year)

--select @cy_qtr_start,@cy_qtr_end,@py_qtr_start,@py_qtr_end

-- Set stats for each price bucket
set @break1 = 300000
set @break2 = 600000
set @break3 = 1000000
set @break4 = 1500000

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
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							else 4 end as listpricebucket,
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
--case  when lc.listprice  < @break1 then 1
--							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
--							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
--							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
--							else 4 end as listpricebucket,
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
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							else 4 end as listpricebucket,
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
case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							else 4 end as listpricebucket,
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

--Base table for Solds
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
--[Cumulative DOM],
datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
lc.*
					,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 then 4
							--when lc.closeprice >= @break4 then 5
							else NULL end as closepricebucket
					,case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							else 4 end as listpricebucket
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
	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('21', '23', '11','12', '22', '51','52', '51', '41', '42', '77', '31','32', '43', '44', '45', '25', '61','62','63', '72','73', '76', '71', '82', '26','27','28')

--UNION ALL

--select 'Downtown Inside of Crosstown' As Area,
----[Cumulative DOM],
--datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
--lc.*
--					,case  when lc.closeprice  < @break1 then 1
--							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
--							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
--							when lc.closeprice >= @break3 then 4
--							--when lc.closeprice >= @break4 then 5
--							else NULL end as closepricebucket
--					,case  when lc.listprice  < @break1 then 1
--							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
--							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
--							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
--							else 4 end as listpricebucket
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
--	and LTRIM(RTRIM(SUBSTRING(area, 1, CASE CHARINDEX('-', area) WHEN 0 THEN LEN(area) ELSE CHARINDEX('-', area) - 1 END))) in ('51')

	UNION ALL

select 'South of Broad' As Area,
--[Cumulative DOM],
datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
lc.*
					,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 then 4
							--when lc.closeprice >= @break4 then 5
							else NULL end as closepricebucket
					,case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							else 4 end as listpricebucket
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
--[Cumulative DOM],
datediff(day,m.ListingContractDate,m.CloseDate) As [Cumulative DOM],
lc.*
					,case  when lc.closeprice  < @break1 then 1
							when lc.closeprice >= @break1 AND lc.closeprice < @break2 then 2
							when lc.closeprice >= @break2 AND lc.closeprice < @break3 then 3
							when lc.closeprice >= @break3 then 4
							--when lc.closeprice >= @break4 then 5
							else NULL end as closepricebucket
					,case  when lc.listprice  < @break1 then 1
							when lc.listprice >= @break1 AND lc.listprice < @break2 then 2
							when lc.listprice >= @break2 AND lc.listprice < @break3 then 3
							--when lc.listprice >= @break3 AND lc.listprice < @break4 then 4
							else 4 end as listpricebucket
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

				--),
--inv as (
        select 
			area,
			listpricebucket
            ,Count(Rtx_LC_ID) as total_listings
            --,AVG(DATEDIFF(DAY,listingcontractdate,@cy_qtr_end)) as avg_DOM
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
            --),
--solds as (
        select area,listpricebucket
                ,Count(Rtx_LC_ID) as total_sold
				,sum(closeprice) as total_volume_sold
        into #solds
		from #cte cte
        where  CloseDate <= @cy_qtr_end
            AND CloseDate > DATEADD(YEAR,-1,@cy_qtr_end)
            AND ClosePrice > 0
        GROUP BY area,listpricebucket
        --),

		        select area,listpricebucket
                ,Count(Rtx_LC_ID) as total_sold
				,sum(closeprice) as total_volume_sold
        into #solds_qtr
		from #cte cte
        where  CloseDate <= @cy_qtr_end
            AND CloseDate > DATEADD(QUARTER,-1,@cy_qtr_end)
            AND ClosePrice > 0
        GROUP BY area,listpricebucket

--pyinv as (
        select 
			area,
			listpricebucket
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
        GROUP BY area,listpricebucket
            --),
--pysolds as (
        select area,listpricebucket
                ,Count(Rtx_LC_ID) as total_sold
				,sum(closeprice) as total_volume_sold
        INTO #pysolds
		from #cte cte
        where  CloseDate <= @py_qtr_end
            AND CloseDate > DATEADD(YEAR,-1,@py_qtr_end)
            AND ClosePrice > 0
        GROUP BY area,listpricebucket
        --),


        select area,listpricebucket
                ,Count(Rtx_LC_ID) as total_sold
				,sum(closeprice) as total_volume_sold
        INTO #pysolds_qtr
		from #cte cte
        where  CloseDate <= @py_qtr_end
            AND CloseDate > DATEADD(QUARTER,-1,@py_qtr_end)
            AND ClosePrice > 0
        GROUP BY area,listpricebucket

--DOM AS (
select YEAR(CloseDate) As [Year],area,listpricebucket,
	avg(datediff(day,listingcontractdate,closedate)) as DOM
	--avg([Cumulative DOM]) as DOM
INTO #DOM
from #cte cte
where DATEPART(quarter, closedate) = DATEPART(quarter,@cy_qtr_end)
	and YEAR(CloseDate) > DATEPART(year,@py_qtr_end)-1
group by YEAR(CloseDate),area,listpricebucket
--)

--CY Values
select distinct
	YEAR(@cy_qtr_end) As Yr, 
	inv.area,
	CASE WHEN inv.listpricebucket=1 THEN '$0 - $' + FORMAT(@break1-1,'#,##')
	WHEN inv.listpricebucket=2 THEN '$' + FORMAT(@break1,'#,##') + ' - $' + FORMAT(@break2-1,'#,##')
	WHEN inv.listpricebucket=3 THEN '$' +FORMAT(@break2,'#,##') + ' - $' + FORMAT(@break3-1,'#,##')
	WHEN inv.listpricebucket=4 THEN '$' + FORMAT(@break3,'#,##') + '+'
	--+ ' - $' + FORMAT(@break4-1,'#,##')
	--WHEN inv.listpricebucket=5 THEN '$' + FORMAT(@break4,'#,##') + '+'
	ELSE NULL END As listpricebucket
    ,inv.total_listings
    ,DOM.DOM As avg_DOM
    ,sq.total_sold
	,sq.total_volume_sold
    ,(cast(inv.total_listings as real))/(cast(sq.total_sold as real)) * 3 as months_inventory
from #inv inv    
    left join #solds solds
        on inv.area=solds.area and inv.listpricebucket = solds.listpricebucket
		left join #DOM DOM on inv.area=DOM.area and inv.listpricebucket=DOM.listpricebucket and DOM.[Year]=YEAR(@cy_qtr_end)
		left join #solds_qtr sq on inv.area=sq.area and inv.listpricebucket=sq.listpricebucket
--order by listpricebucket

UNION ALL

--PY Values
select distinct
	YEAR(@py_qtr_end) As Yr, 
	pyinv.area,
	CASE WHEN pyinv.listpricebucket=1 THEN '$0 - $' + FORMAT(@break1-1,'#,##')
	WHEN pyinv.listpricebucket=2 THEN '$' + FORMAT(@break1,'#,##') + ' - $' + FORMAT(@break2-1,'#,##')
	WHEN pyinv.listpricebucket=3 THEN '$' +FORMAT(@break2,'#,##') + ' - $' + FORMAT(@break3-1,'#,##')
	WHEN pyinv.listpricebucket=4 THEN '$' + FORMAT(@break3,'#,##') + '+'
	--+ ' - $' + FORMAT(@break4-1,'#,##')
	--WHEN pyinv.listpricebucket=5 THEN '$' + FORMAT(@break4,'#,##') + '+'
	ELSE NULL END As listpricebucket
    ,pyinv.total_listings
    ,DOM.DOM As avg_DOM
    ,sq.total_sold
	,sq.total_volume_sold
    ,(cast(pyinv.total_listings as real))/(cast(sq.total_sold as real)) * 3 as months_inventory
from #pyinv pyinv    
    left join #pysolds pysolds
        on pyinv.area=pysolds.area AND pyinv.listpricebucket = pysolds.listpricebucket
		left join #DOM DOM on pyinv.area=DOM.area and pyinv.listpricebucket=DOM.listpricebucket and DOM.[Year]=YEAR(@py_qtr_end)
		left join #pysolds_qtr sq on pyinv.area=sq.area and pyinv.listpricebucket=sq.listpricebucket
order by listpricebucket



END











GO

