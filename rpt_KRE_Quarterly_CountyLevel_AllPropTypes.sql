USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_KRE_Quarterly_CountyLevel_AllPropTypes]    Script Date: 5/19/2020 2:35:50 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- =======================================================================================================================================
-- Author:		Matt Michalowski
-- Initial Create date: 7/18/2019
-- Description:	KRE Quarterly Stats - County Level

--Changes: 5/6/2020 - updated inventory WHERE clause
--		   5/12/2020 - fixed Median calculations where PropertyType filter was missing and partition by did not include quarter
-- =======================================================================================================================================
CREATE PROCEDURE [dbo].[rpt_KRE_Quarterly_CountyLevel_AllPropTypes] 
	-- Add the parameters for the stored procedure here
	@eval_date DATE,
	@py_eval_date DATE=NULL,
	@ReportQtr INT=NULL,
	@ReportYear INT=NULL,
	@PrevReportYear INT=NULL
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SET @py_eval_date=DATEADD(YEAR,-1,@eval_date)
SET @ReportQtr=DATEPART(Quarter,@eval_date)
SET @ReportYear=DATEPART(Year,@eval_date)
SET @PrevReportYear=DATEPART(Year,@eval_date)-1

DROP TABLE IF EXISTS #kre_work_lci_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_cyinv_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_cyinvSt_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_pyinv_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_pyinvSt_AllPropTypes
DROP TABLE IF EXISTS #KRE_Counties_AllPropTypes
DROP TABLE IF EXISTS #KRE_rpt_main_AllPropTypes
DROP TABLE IF EXISTS #cy_main_AllPropTypes
DROP TABLE IF EXISTS #py_main_AllPropTypes
DROP TABLE IF EXISTS #cyMedian_AllPropTypes
DROP TABLE IF EXISTS #pyMedian_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_cysolds_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_pysolds_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_cysoldsSt_AllPropTypes
DROP TABLE IF EXISTS #kre_rpt_pysoldsSt_AllPropTypes


--Inventory Table
--Pull Listings_Combined data for inventory cte's into kre_work_lci table
SELECT
CASE WHEN lc.PropertyType='Land' THEN 'Land'
WHEN lc.PropertyType='Residential' AND lc.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN lc.PropertyType='Residential' AND lc.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END As PropertyType, 
cbr.Region,cbr.County,lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,'WI' As CensusState,lc.StatusChangeTimestamp
INTO #kre_work_lci_AllPropTypes
FROM Relitix.dbo.Listings_Combined lc
join
Relitix.dbo.Listings_Combined_Geo lcg 
on lc.ListingKey=lcg.ListingKey and lc.SourceSystemID=lcg.SourceSystemID
join
relitix.dbo.Census_County_Names cn 
on lcg.CountyFP=cn.CountyFP and lcg.StateFP=cn.State_Num
join
(SELECT DISTINCT REGION,COUNTY FROM Relitix_Staging.dbo.WRA_CountyByRegion WHERE Region!='Milwaukee') cbr --Single counties can belong to more than one region, so select distinct instead of straight join on this table
on cbr.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
where
(lc.sourcesystemid = 1 OR lc.sourcesystemID = 4 OR lc.sourcesystemID=8) AND 
cn.State_num=55 AND --WI Only
cn.County IN ('Kenosha','Racine','Walworth')
AND lc.PropertyType IN ('Residential','Land')


INSERT INTO #kre_work_lci_AllPropTypes
SELECT
CASE WHEN lc.PropertyType='Land' THEN 'Land'
WHEN lc.PropertyType='Residential' AND lc.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN lc.PropertyType='Residential' AND lc.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END As PropertyType, 
null as Region,cn.County,lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,'WI' As CensusState,lc.StatusChangeTimestamp
FROM Relitix.dbo.Listings_Combined lc
join
Relitix.dbo.Listings_Combined_Geo lcg 
on lc.ListingKey=lcg.ListingKey and lc.SourceSystemID=lcg.SourceSystemID
join
relitix.dbo.Census_County_Names cn 
on lcg.CountyFP=cn.CountyFP and lcg.StateFP=cn.State_Num
--join
--(SELECT DISTINCT REGION,COUNTY FROM Relitix_Staging.dbo.WRA_CountyByRegion WHERE Region!='Milwaukee') cbr --Single counties can belong to more than one region, so select distinct instead of straight join on this table
--on cbr.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
where
(lc.sourcesystemid = 10 AND
--cn.State_num=55 AND --WI Only
cn.County IN ('McHenry'))
AND lc.PropertyType IN ('Residential','Land')

--cyinv
select
	County
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_cyinv_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
where
lci.PropertyType in ('Single Family Residential','Condominium') AND
StandardStatus <> 'Coming Soon'
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
GROUP BY lci.County

--cyinvSt
select
	CensusState
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_cyinvSt_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
where
lci.County NOT IN ('McHenry') AND
lci.PropertyType in ('Single Family Residential','Condominium') AND
StandardStatus <> 'Coming Soon'
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
GROUP BY lci.CensusState

--pyinv
select 
	County
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_pyinv_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
where
lci.PropertyType in ('Single Family Residential','Condominium') AND
StandardStatus <> 'Coming Soon'
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
GROUP BY lci.County

--pyinvSt
select 
	CensusState
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_pyinvSt_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
where
lci.County NOT IN ('McHenry') AND
lci.PropertyType in ('Single Family Residential','Condominium') AND
StandardStatus <> 'Coming Soon'
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
GROUP BY lci.CensusState


--Populate counties
SELECT *
INTO #KRE_Counties_AllPropTypes
FROM
(
SELECT 'Kenosha' As County UNION ALL
SELECT 'Racine' As County UNION ALL
SELECT 'Walworth' As County UNION ALL
SELECT 'McHenry' As County
) county

--CY Median Price Tri County
select distinct
'WI' As CensusState,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									--(cn.County),
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #cyMedian_AllPropTypes
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties_AllPropTypes m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	cn.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear AND
	l.PropertyType IN ('Residential','Land')
--Group by
--cn.County,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--PY Median Price TriCounty
select distinct
'WI' As CensusState,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									--(cn.County),
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #pyMedian_AllPropTypes
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties_AllPropTypes m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	m.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear AND
	l.PropertyType IN ('Residential','Land')
--Group by
--cn.County,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--CY Price Per Sq Foot Tri County
select distinct
cn.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
INTO #cyPricePerSqFoot
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties_AllPropTypes m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	cn.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear AND
	l.PropertyType IN ('Residential','Land')
Group by
cn.County,
DATEPART(Quarter,closedate),
year(closedate)

--PY Price Per Sq Foot TriCounty
select distinct
cn.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
INTO #pyPricePerSqFoot
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties_AllPropTypes m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	m.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear AND
	l.PropertyType IN ('Residential','Land')
Group by
cn.County,
DATEPART(Quarter,closedate),
year(closedate)

--Main Dataset
SELECT
	a.*,b.MedianPrice
INTO #KRE_rpt_main_AllPropTypes
FROM
(
select
'WI' As CensusState,
m.County,
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
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties_AllPropTypes m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where 
	closedate IS NOT NULL AND l.PropertyType IN ('Residential','Land')
Group by
m.County,
DATEPART(Quarter,closedate),
year(closedate)
) a
INNER JOIN
(
select distinct
m.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									(m.County),
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties_AllPropTypes m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	closedate IS NOT NULL AND l.PropertyType IN ('Residential','Land')
--Group by
--m.County,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) b
ON a.yr=b.yr 
and a.Qtr=b.Qtr
and a.County=b.County
where a.Qtr=@ReportQtr and a.yr IN (@ReportYear,@PrevReportYear)


select 
*
INTO #cy_main_AllPropTypes
from
#KRE_rpt_main_AllPropTypes
where qtr=@ReportQtr and yr=@ReportYear

select 
*
INTO #py_main_AllPropTypes
from
#KRE_rpt_main_AllPropTypes
where qtr=@ReportQtr and yr=@PrevReportYear



--cySolds
select County
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_cysolds_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
		where 
		lci.PropertyType!='Other' AND
		CloseDate < @eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@eval_date)
			AND ClosePrice > 0
		GROUP BY County

--cySolds Tri County
select CensusState As State
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_cysoldsSt_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
		where 
		lci.PropertyType!='Other' AND
		lci.County NOT IN ('McHenry') AND
		CloseDate < @eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState

--pySolds
select County
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_pysolds_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
		where 
		lci.PropertyType!='Other' AND CloseDate < @py_eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@py_eval_date)
			AND ClosePrice > 0
		GROUP BY County

--pySolds Tri County
select CensusState As State
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_pysoldsSt_AllPropTypes
FROM #kre_work_lci_AllPropTypes lci
		where 
		lci.PropertyType!='Other' AND lci.County NOT IN ('McHenry') AND
		CloseDate < @py_eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@py_eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState



--ReportOutput
select
rpt.County
,cy.sales_count As CurrentYearSalesCount
,cy.price_per_foot As CurrentPricePerFoot
,cyPPSF.price_per_foot As CurrentTriCountyPricePerFoot
,cy.sales_volume As CurrentSalesVolume
,cy.avg_sale As CurrentAvgSale
,cy.avg_dom As CurrentAvgDOM
,cy.MedianPrice As CurrentMedianPrice
,cym.MedianPrice As CurrentTriCountyMedian
,py.sales_count As PreviousYearSalesCount
,py.price_per_foot As PreviousPricePerFoot
,pyPPSF.price_per_foot As PreviousTriCountyPricePerFoot
,py.sales_volume As PreviousSalesVolume
,py.avg_sale As PreviousAvgSale
,py.avg_dom As PreviousAvgDOM
,py.MedianPrice As PreviousMedianPrice
,pym.MedianPrice As PreviousTriCountyMedian
--inventory at end of Q1/sold count in Q1 * 12
,cast(round(((cast(cyinv.total_listings as real))/(cast(cysolds.total_sold as real)) * 12),1) As DECIMAL(11,1)) as cy_months_inventory
,cast(round(((cast(pyinv.total_listings as real))/(cast(pysolds.total_sold as real)) * 12),1) As DECIMAL(11,1)) as py_months_inventory
,cast(round(((cast(cyinvSt.total_listings as real))/(cast(cySoldsSt.total_sold as real)) * 12),1) As DECIMAL(11,1)) as cy_TriCounty_months_inventory
,cast(round(((cast(pyinvSt.total_listings as real))/(cast(pySoldsSt.total_sold as real)) * 12),1) As DECIMAL(11,1)) as py_TriCounty_months_inventory
from
(select distinct CensusState,County from #KRE_rpt_main_AllPropTypes) rpt
left join
	#cy_main_AllPropTypes cy
on
	rpt.County=cy.County
left join
	#py_main_AllPropTypes py
on
	rpt.County=py.County
left join
	#kre_rpt_cyinv_AllPropTypes cyinv
on
	rpt.county=cyinv.county
left join
	#kre_rpt_pyinv_AllPropTypes pyinv
on
	rpt.county=pyinv.county
left join
	#kre_rpt_cyinvSt_AllPropTypes cyinvSt
on
	rpt.CensusState=cyinvSt.CensusState
left join
	#kre_rpt_pyinvSt_AllPropTypes pyinvSt
on
	rpt.CensusState=pyinvSt.CensusState
left join
	#cyMedian_AllPropTypes cym
on
	rpt.CensusState=cym.CensusState
left join
	#pyMedian_AllPropTypes pym
on
	rpt.CensusState=pym.CensusState
left join
	#kre_rpt_cysolds_AllPropTypes cysolds
on
	rpt.County=cysolds.County
left join
	#kre_rpt_pysoldsSt_AllPropTypes cySoldsSt
on
	rpt.CensusState=cySoldsSt.State
left join
	#kre_rpt_pysolds_AllPropTypes pySolds
on
	rpt.County=pySolds.County
left join
	#kre_rpt_pysoldsSt_AllPropTypes pySoldsSt
on
	rpt.CensusState=pySoldsSt.State
left join
	#cyPricePerSqFoot cyPPSF
on
	rpt.County=cyPPSF.County
left join
	#pyPricePerSqFoot pyPPSF
on
	rpt.County=pyPPSF.County

END
















GO

