USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_KRE_Quarterly_CountyLevel_v3]    Script Date: 5/19/2020 2:36:10 PM ******/
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
CREATE PROCEDURE [dbo].[rpt_KRE_Quarterly_CountyLevel_v3] 
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

DROP TABLE IF EXISTS #kre_work_lci
DROP TABLE IF EXISTS #kre_rpt_cyinv
DROP TABLE IF EXISTS #kre_rpt_cyinvSt
DROP TABLE IF EXISTS #kre_rpt_pyinv
DROP TABLE IF EXISTS #kre_rpt_pyinvSt
DROP TABLE IF EXISTS #KRE_Counties
DROP TABLE IF EXISTS #KRE_rpt_main
DROP TABLE IF EXISTS #cy_main
DROP TABLE IF EXISTS #py_main
DROP TABLE IF EXISTS #cyMedian
DROP TABLE IF EXISTS #pyMedian
DROP TABLE IF EXISTS #kre_rpt_cysolds
DROP TABLE IF EXISTS #kre_rpt_pysolds
DROP TABLE IF EXISTS #kre_rpt_cysoldsSt
DROP TABLE IF EXISTS #kre_rpt_pysoldsSt
DROP TABLE IF EXISTS #cyPricePerSqFoot
DROP TABLE IF EXISTS #pyPricePerSqFoot
DROP TABLE IF EXISTS #cyMedianAllUnitTypes
DROP TABLE IF EXISTS #pyMedianAllUnitTypes
DROP TABLE IF EXISTS #cyPricePerSqFootAllUnitTypes
DROP TABLE IF EXISTS #pyPricePerSqFootAllUnitTypes
DROP TABLE IF EXISTS #kre_rpt_cysoldsAllUnitTypes
DROP TABLE IF EXISTS #kre_rpt_pysoldsAllUnitTypes
DROP TABLE IF EXISTS #kre_rpt_cyinvAllUnitTypes
DROP TABLE IF EXISTS #kre_rpt_pyinvAllUnitTypes
DROP TABLE IF EXISTS #cyMedianSt
DROP TABLE IF EXISTS #pyMedianSt
DROP TABLE IF EXISTS #cyPricePerSqFootSt
DROP TABLE IF EXISTS #pyPricePerSqFootSt
DROP TABLE IF EXISTS #kre_rpt_cysoldsStAUT
DROP TABLE IF EXISTS #kre_rpt_pysoldsStAUT
DROP TABLE IF EXISTS #kre_rpt_cyinvStAUT
DROP TABLE IF EXISTS #kre_rpt_pyinvStAUT

--Inventory Table
--Pull Listings_Combined data for inventory cte's into kre_work_lci table
SELECT
CASE WHEN lc.PropertyType='Land' THEN 'Land'
WHEN lc.PropertyType='Residential' AND lc.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN lc.PropertyType='Residential' AND lc.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END As PropertyType, 
cbr.Region,cbr.County,lc.Rtx_LC_ID,lc.StandardStatus,lc.ListingContractDate,lc.CloseDate,lc.ExpirationDate,lc.WithdrawnDate,lc.CancelationDate,lc.ClosePrice,'WI' As CensusState,lc.StatusChangeTimestamp
INTO #kre_work_lci
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

INSERT INTO #kre_work_lci
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
	PropertyType, 
	County
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_cyinv
FROM #kre_work_lci lci
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
GROUP BY lci.PropertyType,lci.County

--cyinvSt
select
	CensusState,
	PropertyType
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_cyinvSt
FROM #kre_work_lci lci
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
GROUP BY lci.CensusState,PropertyType

--cyinvStAUT
select
	CensusState
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_cyinvStAUT
FROM #kre_work_lci lci
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

--cyinvAllUnitTypes
select
	CensusState,
	County
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_cyinvAllUnitTypes
FROM #kre_work_lci lci
where
--lci.County NOT IN ('McHenry') AND
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
GROUP BY lci.CensusState,County

--pyinv
select 
	PropertyType,
	County
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_pyinv
FROM #kre_work_lci lci
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
GROUP BY lci.PropertyType,lci.County

--pyinvSt
select 
	CensusState,
	PropertyType
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_pyinvSt
FROM #kre_work_lci lci
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
GROUP BY lci.CensusState,PropertyType

--pyinvStAUT
select 
	CensusState
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_pyinvStAUT
FROM #kre_work_lci lci
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

--pyinvStAllUnitTypes
select 
	CensusState,
	County
	,Count(Rtx_LC_ID) as total_listings
INTO #kre_rpt_pyinvAllUnitTypes
FROM #kre_work_lci lci
where
--lci.County NOT IN ('McHenry') AND
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
GROUP BY lci.CensusState,County


--Populate counties
SELECT *
INTO #KRE_Counties
FROM
(
SELECT 'Kenosha' As County UNION ALL
SELECT 'Racine' As County UNION ALL
SELECT 'Walworth' As County UNION ALL
SELECT 'McHenry' As County
) county

--CY Median Price Tri County
select distinct
CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END AS PropertyType,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									(CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #cyMedian
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	cn.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear AND
	l.PropertyType IN ('Residential','Land')
--Group by
--(CASE WHEN l.PropertyType='Land' THEN 'Land'
--WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
--WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--PY Median Price TriCounty
select distinct
CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END AS PropertyType,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									(CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #pyMedian
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	m.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear AND
	l.PropertyType IN ('Residential','Land')
--Group by
--(CASE WHEN l.PropertyType='Land' THEN 'Land'
--WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
--WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--PY Median Price TriCounty All Unit Types
select distinct
'WI' As CensusState,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #pyMedianSt
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	m.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear AND
	l.PropertyType IN ('Residential','Land')
--Group by
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--CY Median Price All Unit Types
select distinct
cn.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									(cn.County),
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #cyMedianAllUnitTypes
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	l.PropertyType IN ('Residential','Land') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear
--Group by
--cn.County,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--CY Median Price Tri County All Types
select distinct
'WI' As CensusState,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #cyMedianSt
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	cn.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear AND
	l.PropertyType IN ('Residential','Land')
--Group by
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--PY Median Price All Unit Types
select distinct
cn.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									(cn.County),
									DATEPART(Quarter,closedate),
									year(closedate)
								) AS MedianPrice
INTO #pyMedianAllUnitTypes
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	l.PropertyType IN ('Residential','Land') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear
--Group by
--cn.County,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice

--CY Price Per Sq Foot Tri County
select distinct
CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END AS PropertyType,
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
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	cn.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear AND
	l.PropertyType IN ('Residential','Land')
Group by
(CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
DATEPART(Quarter,closedate),
year(closedate)

--CY Price Per Sq Foot Tri County All Unit Types
select distinct
'WI' As CensusState,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
INTO #cyPricePerSqFootSt
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	cn.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear AND
	l.PropertyType IN ('Residential','Land')
Group by
DATEPART(Quarter,closedate),
year(closedate)

--PY Price Per Sq Foot TriCounty
select distinct
CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END AS PropertyType,
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
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	m.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear AND
	l.PropertyType IN ('Residential','Land')
Group by
(CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
DATEPART(Quarter,closedate),
year(closedate)

--PY Price Per Sq Foot TriCounty
select distinct
'WI' As CensusState,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
INTO #pyPricePerSqFootSt
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	m.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear AND
	l.PropertyType IN ('Residential','Land')
Group by
DATEPART(Quarter,closedate),
year(closedate)


--CY Price Per Sq Foot All Unit Types
select distinct
cn.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
INTO #cyPricePerSqFootAllUnitTypes
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	l.PropertyType IN ('Residential','Land') AND
	--cn.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@ReportYear
Group by
cn.County,
DATEPART(Quarter,closedate),
year(closedate)


--PY Price Per Sq Foot All Unit Types
select distinct
cn.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
avg(iif(buildingareatotal>0,closeprice/BuildingAreaTotal,NULL)) as price_per_foot
INTO #pyPricePerSqFootAllUnitTypes
from listings_combined l
	join listings_combined_geo g
		on l.listingkey = g.listingkey
			and l.sourcesystemid = g.sourcesystemid
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
join
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	l.PropertyType IN ('Residential','Land') AND
	--m.County NOT IN ('McHenry') AND
	closedate IS NOT NULL AND
	DATEPART(Quarter,closedate)=@ReportQtr AND
	year(closedate)=@PrevReportYear
Group by
cn.County,
DATEPART(Quarter,closedate),
year(closedate)

--Main Dataset
SELECT
	a.*,b.MedianPrice
INTO #KRE_rpt_main
FROM
(
select
'WI' As CensusState,
CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END As PropertyType,
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
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where 
	closedate IS NOT NULL AND l.PropertyType IN ('Residential','Land')
Group by
(CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
m.County,
DATEPART(Quarter,closedate),
year(closedate)
) a
INNER JOIN
(
select distinct
CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END AS PropertyType,
m.County,
DATEPART(Quarter,closedate) As Qtr,
year(closedate) As Yr,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClosePrice)   
                            OVER (
									PARTITION BY
									(CASE WHEN l.PropertyType='Land' THEN 'Land'
WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
									m.County, 
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
#KRE_Counties m ON m.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
--INNER JOIN #SubTypes_List AS PropertySubTypes ON l.PropertySubType = PropertySubTypes.Item --Use join instead of where clause
where
	closedate IS NOT NULL AND l.PropertyType IN ('Residential','Land')
--Group by
--(CASE WHEN l.PropertyType='Land' THEN 'Land'
--WHEN l.PropertyType='Residential' AND l.PropertySubType!='Condominium' THEN 'Single Family Residential'
--WHEN l.PropertyType='Residential' AND l.PropertySubType='Condominium' THEN 'Condominium' ELSE 'Other' END),
--m.County,
--DATEPART(Quarter,closedate),
--year(closedate),ClosePrice
) b
ON a.yr=b.yr 
and a.Qtr=b.Qtr
and a.County=b.County
and a.PropertyType=b.PropertyType
where a.Qtr=@ReportQtr and a.yr IN (@ReportYear,@PrevReportYear)


select 
*
INTO #cy_main
from
#KRE_rpt_main
where qtr=@ReportQtr and yr=@ReportYear

select 
*
INTO #py_main
from
#KRE_rpt_main
where qtr=@ReportQtr and yr=@PrevReportYear

--cySolds
select County,PropertyType
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_cysolds
FROM #kre_work_lci lci
		where CloseDate < @eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@eval_date)
			AND ClosePrice > 0
		GROUP BY County,PropertyType

--cySolds Tri County
select CensusState As State
		,PropertyType
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_cysoldsSt
FROM #kre_work_lci lci
		where 
		lci.County NOT IN ('McHenry') AND
		CloseDate < @eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState,PropertyType

--cySolds Tri County All Unit Types
select CensusState As State
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_cysoldsStAUT
FROM #kre_work_lci lci
		where 
		lci.County NOT IN ('McHenry') AND
		CloseDate < @eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState

--cySolds All Unit Types
select CensusState As State
		,County
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_cysoldsAllUnitTypes
FROM #kre_work_lci lci
		where 
		--lci.County NOT IN ('McHenry') AND
		CloseDate < @eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState,County

--pySolds
select County,PropertyType
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_pysolds
FROM #kre_work_lci lci
		where CloseDate < @py_eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@py_eval_date)
			AND ClosePrice > 0
		GROUP BY County,PropertyType

--pySolds Tri County
select CensusState As State
		,PropertyType
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_pysoldsSt
FROM #kre_work_lci lci
		where 
		lci.County NOT IN ('McHenry') AND
		CloseDate < @py_eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@py_eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState,PropertyType

--pySolds Tri County All Unit Types
select CensusState As State
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_pysoldsStAUT
FROM #kre_work_lci lci
		where 
		lci.County NOT IN ('McHenry') AND
		CloseDate < @py_eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@py_eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState

--pySolds All Unit Types
select CensusState As State
		,County
				,Count(lci.Rtx_LC_ID) as total_sold
INTO #kre_rpt_pysoldsAllUnitTypes
FROM #kre_work_lci lci
		where 
		--lci.County NOT IN ('McHenry') AND
		CloseDate < @py_eval_date
			AND CloseDate >= DATEADD(YEAR,-1,@py_eval_date)
			AND ClosePrice > 0
		GROUP BY CensusState,County

--ReportOutput
select
rpt.PropertyType
,rpt.County
,cy.sales_count As CurrentYearSalesCount
,cy.price_per_foot As CurrentPricePerFoot
,cyPPSF.price_per_foot As CurrentTriCountyPricePerFoot
,cypAllUnitTypes.price_per_foot As CurrentAllUnitTypesPricePerFoot
,cyPricePerSqFootSt.price_per_foot As CurrentTriCountyPricePerFootAllUnitTypes
,cy.sales_volume As CurrentSalesVolume
,cy.avg_sale As CurrentAvgSale
,cy.avg_dom As CurrentAvgDOM
,cy.MedianPrice As CurrentMedianPrice
,cym.MedianPrice As CurrentTriCountyMedian
,cymAllUnitTypes.MedianPrice As CurrentAllUnitTypesMedian
,cyMedianSt.MedianPrice As CurrentMedianTriCountyAllUnitTypes
,py.sales_count As PreviousYearSalesCount
,py.price_per_foot As PreviousPricePerFoot
,pyPPSF.price_per_foot As PreviousTriCountyPricePerFoot
,pypAllUnitTypes.price_per_foot As PreviousAllUnitTypesPricePerFoot
,pyPricePerSqFootSt.price_per_foot As PreviousTriCountyPricePerFootAllUnitTypes
,py.sales_volume As PreviousSalesVolume
,py.avg_sale As PreviousAvgSale
,py.avg_dom As PreviousAvgDOM
,py.MedianPrice As PreviousMedianPrice
,pym.MedianPrice As PreviousTriCountyMedian
,pymAllUnitTypes.MedianPrice As PreviousAllUnitTypesMedian
,pyMedianSt.MedianPrice As PreviousMedianTriCountyAllUnitTypes
--inventory at end of Q1/sold count in Q1 * 12
,cast(round(((cast(cyinv.total_listings as real))/(cast(cysolds.total_sold as real)) * 12),1) As DECIMAL(11,1)) as cy_months_inventory
,cast(round(((cast(pyinv.total_listings as real))/(cast(pysolds.total_sold as real)) * 12),1) As DECIMAL(11,1)) as py_months_inventory
,cast(round(((cast(cyinvSt.total_listings as real))/(cast(cySoldsSt.total_sold as real)) * 12),1) As DECIMAL(11,1)) as cy_TriCounty_months_inventory
,cast(round(((cast(pyinvSt.total_listings as real))/(cast(pySoldsSt.total_sold as real)) * 12),1) As DECIMAL(11,1)) as py_TriCounty_months_inventory
,cast(round(((cast(cyinvAllUnitTypes.total_listings as real))/(cast(cySoldsAllUnitTypes.total_sold as real)) * 12),1) As DECIMAL(11,1)) as cy_AllUnitTypes_months_inventory
,cast(round(((cast(pyinvAllUnitTypes.total_listings as real))/(cast(pySoldsAllUnitTypes.total_sold as real)) * 12),1) As DECIMAL(11,1)) as py_AllUnitTypes_months_inventory
,cast(round(((cast(cyinvStAUT.total_listings as real))/(cast(cySoldsStAUT.total_sold as real)) * 12),1) As DECIMAL(11,1)) as cy_TriCountyAllUnitTypes_months_inventory
,cast(round(((cast(pyinvStAUT.total_listings as real))/(cast(pySoldsStAUT.total_sold as real)) * 12),1) As DECIMAL(11,1)) as py_TriCountyAllUnitTypes_months_inventory
from
(select distinct CensusState,PropertyType,County from #KRE_rpt_main) rpt
left join
	#cy_main cy
on
	rpt.PropertyType=cy.PropertyType AND
	rpt.County=cy.County
left join
	#py_main py
on
	rpt.PropertyType=py.PropertyType AND
	rpt.County=py.County
left join
	#kre_rpt_cyinv cyinv
on
	rpt.PropertyType=cyinv.PropertyType and
	rpt.county=cyinv.county
left join
	#kre_rpt_pyinv pyinv
on
	rpt.PropertyType=pyinv.PropertyType and
	rpt.county=pyinv.county
left join
	#kre_rpt_cyinvSt cyinvSt
on
	rpt.CensusState=cyinvSt.CensusState and
	rpt.PropertyType=cyinvSt.PropertyType
left join
	#kre_rpt_pyinvSt pyinvSt
on
	rpt.CensusState=pyinvSt.CensusState and
	rpt.PropertyType=pyinvSt.PropertyType
left join
	#cyMedian cym
on
	rpt.PropertyType=cym.PropertyType
left join
	#pyMedian pym
on
	rpt.PropertyType=pym.PropertyType
left join
	#kre_rpt_cysolds cysolds
on
	rpt.County=cysolds.County AND rpt.PropertyType=cysolds.PropertyType
left join
	#kre_rpt_pysoldsSt cySoldsSt
on
	rpt.PropertyType=cySoldsSt.PropertyType
left join
	#kre_rpt_pysolds pySolds
on
	rpt.County=pySolds.County AND rpt.PropertyType=pySolds.PropertyType
left join
	#kre_rpt_pysoldsSt pySoldsSt
on
	rpt.PropertyType=pySoldsSt.PropertyType
left join
	#cyPricePerSqFoot cyPPSF
on
	rpt.PropertyTYpe=cyPPSF.PropertyType
left join
	#pyPricePerSqFoot pyPPSF
on
	rpt.PropertyTYpe=pyPPSF.PropertyType
left join
	#cyMedianAllUnitTypes cymAllUnitTypes
on
	rpt.County=cymAllUnitTypes.County
left join
	#pyMedianAllUnitTypes pymAllUnitTypes
on
	rpt.County=pymAllUnitTypes.County
left join
	#cyPricePerSqFootAllUnitTypes cypAllUnitTypes
on
	rpt.County=cypAllUnitTypes.County
left join
	#pyPricePerSqFootAllUnitTypes pypAllUnitTypes
on
	rpt.County=pypAllUnitTypes.County
left join
	#kre_rpt_cyinvAllUnitTypes cyinvAllUnitTypes
on
	rpt.County=cyinvAllUnitTypes.County
left join
	#kre_rpt_pyinvAllUnitTypes pyinvAllUnitTypes
on
	rpt.County=pyinvAllUnitTypes.County
left join
	#kre_rpt_cysoldsAllUnitTypes cysoldsAllUnitTypes
on
	rpt.County=cysoldsAllUnitTypes.County
left join
	#kre_rpt_pysoldsAllUnitTypes pysoldsAllUnitTypes
on
	rpt.County=pysoldsAllUnitTypes.County
left join
	#cyMedianSt cyMedianSt
on
	rpt.CensusState=cyMedianSt.CensusState
left join
	#pyMedianSt pyMedianSt
on
	rpt.CensusState=pyMedianSt.CensusState
left join
	#cyPricePerSqFootSt cyPricePerSqFootSt
on
	rpt.CensusState=cyMedianSt.CensusState
left join
	#pyPricePerSqFootSt pyPricePerSqFootSt
on
	rpt.CensusState=pyPricePerSqFootSt.CensusState
left join
	#kre_rpt_cysoldsStAUT cysoldsStAUT
on
	rpt.CensusState=cysoldsStAUT.State
left join
	#kre_rpt_pysoldsStAUT pysoldsStAUT
on
	rpt.CensusState=pysoldsStAUT.State
left join
	#kre_rpt_cyinvStAUT cyinvStAUT
on
	rpt.CensusState=cyinvStAUT.CensusState
left join
	#kre_rpt_pyinvStAUT pyinvStAUT
on
	rpt.CensusState=pyinvStAUT.CensusState
where rpt.PropertyType!='Other'

END
















GO

