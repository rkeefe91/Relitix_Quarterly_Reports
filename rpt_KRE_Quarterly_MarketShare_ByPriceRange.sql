USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_KRE_Quarterly_MarketShare_ByPriceRange]    Script Date: 5/19/2020 2:36:47 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO











-- ==============================================================================================
-- Author:		Matt Michalowski
-- Create date: 1/29/2018
-- Description:	KRE Quarterly Stats Market Share By Price Range Report

--Changes:

-- ==============================================================================================
CREATE PROCEDURE [dbo].[rpt_KRE_Quarterly_MarketShare_ByPriceRange]
@PropertySubtype VARCHAR(255),
	@break1 numeric=NULL,
	@break2 numeric=NULL,
	@break3 numeric=NULL,
	@break4 numeric=NULL

AS
BEGIN
 -- SET NOCOUNT ON added to prevent extra result sets from
 -- interfering with SELECT statements.
 SET NOCOUNT ON;


-- Set stats for each price bucket
set @break1 = 125000
set @break2 = 200000
set @break3 = 350000
set @break4 = 500000

select *
INTO #lcc
from
(
--All Closed Listings
select
RTRIM(LTRIM(REPLACE(cn.County_name,'County',''))) As County,
CASE WHEN oc.OfficeName LIKE 'Keefe %' THEN 'Keefe Real Estate'
WHEN (oc.OfficeName LIKE '@properties%' OR
  oc.OfficeName LIKE '@Properties%') THEN '@properties'
WHEN (oc.OfficeName LIKE '%THE REAL ESTATE GROUP%' OR
    oc.OfficeName LIKE '%The Real Estate Group%') THEN 'CB The Real Estate Group'
WHEN UPPER(oc.OfficeName) LIKE 'SHOREWEST%' THEN 'Shorewest'
WHEN oc.OfficeName like '%Geneva Lakefront%' THEN 'Geneva Lakefront Realty'
WHEN oc.OfficeName like '%Rauland%' THEN 'Rauland Agency'
WHEN oc.OfficeName like '%Lake Geneva Area%' THEN 'Lake Geneva Area Realty'
WHEN oc.OfficeName like '%Aprile%' THEN 'D''Aprile Properties'
WHEN oc.OfficeName like '%Redfin%' THEN 'Redfin Corporation'
WHEN (oc.OfficeName like 'NON-MLS%' OR oc.OfficeName like 'NON MLS%') THEN 'NON MLS'
ELSE 'Other' END As Company,
lcv.*
					,case  when lcv.closeprice  < @break1 then 1
							when lcv.closeprice >= @break1 AND lcv.closeprice < @break2 then 2
							when lcv.closeprice >= @break2 AND lcv.closeprice < @break3 then 3
							when lcv.closeprice >= @break3 AND lcv.closeprice < @break4 then 4
							when lcv.closeprice >- @break4 then 5
							ELSE 'Other' END as closepricebucket
					,case  when lcv.listprice  < @break1 then 1
							when lcv.listprice >= @break1 AND lcv.listprice < @break2 then 2
							when lcv.listprice >= @break2 AND lcv.listprice < @break3 then 3
							when lcv.listprice >= @break3 AND lcv.listprice < @break4 then 4
							else 5 end as listpricebucket
 from relitix.dbo.listings_combined_for_volume lcv
inner join listings_combined lc on lcv.ListingKey=lc.ListingKey
inner join offices_combined oc on lcv.Office_key=oc.OfficeKey
join listings_combined_geo g
		on lcv.listingkey = g.listingkey
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
 where 
 lcv.sourcesystemid=1
 and 
 lcv.CloseDate is not null
 and DATEPART(Year,lcv.CloseDate)>2016
 and RTRIM(LTRIM(REPLACE(cn.County_name,'County',''))) IN ('Kenosha','Racine','Walworth')
 and lcv.propertytype='Residential'

 UNION ALL

 select
RTRIM(LTRIM(REPLACE(cn.County_name,'County',''))) As County,
CASE WHEN oc.OfficeName LIKE 'Keefe %' THEN 'Keefe Real Estate'
WHEN (oc.OfficeName LIKE '@properties%' OR
  oc.OfficeName LIKE '@Properties%') THEN '@properties'
WHEN (oc.OfficeName LIKE '%THE REAL ESTATE GROUP%' OR
    oc.OfficeName LIKE '%The Real Estate Group%') THEN 'CB The Real Estate Group'
WHEN UPPER(oc.OfficeName) LIKE 'SHOREWEST%' THEN 'Shorewest'
WHEN oc.OfficeName like '%Geneva Lakefront%' THEN 'Geneva Lakefront Realty'
WHEN oc.OfficeName like '%Rauland%' THEN 'Rauland Agency'
WHEN oc.OfficeName like '%Lake Geneva Area%' THEN 'Lake Geneva Area Realty'
WHEN oc.OfficeName like '%Aprile%' THEN 'D''Aprile Properties'
WHEN oc.OfficeName like '%Redfin%' THEN 'Redfin Corporation'
WHEN (oc.OfficeName like 'NON-MLS%' OR oc.OfficeName like 'NON MLS%') THEN 'NON MLS'
ELSE 'Other' END As Company,
lcv.*
					,case  when lcv.closeprice  < @break1 then 1
							when lcv.closeprice >= @break1 AND lcv.closeprice < @break2 then 2
							when lcv.closeprice >= @break2 AND lcv.closeprice < @break3 then 3
							when lcv.closeprice >= @break3 AND lcv.closeprice < @break4 then 4
							when lcv.closeprice >- @break4 then 5
							ELSE 'Other' END as closepricebucket
					,case  when lcv.listprice  < @break1 then 1
							when lcv.listprice >= @break1 AND lcv.listprice < @break2 then 2
							when lcv.listprice >= @break2 AND lcv.listprice < @break3 then 3
							when lcv.listprice >= @break3 AND lcv.listprice < @break4 then 4
							else 5 end as listpricebucket
 from relitix.dbo.listings_combined_for_volume lcv
inner join listings_combined lc on lcv.ListingKey=lc.ListingKey
inner join offices_combined oc on lcv.Office_key=oc.OfficeKey
join listings_combined_geo g
		on lcv.listingkey = g.listingkey
join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
 where 
 lcv.sourcesystemid=10
 and 
 lcv.CloseDate is not null
 and DATEPART(Year,lcv.CloseDate)>2016
 and RTRIM(LTRIM(REPLACE(cn.County_name,'County',''))) IN ('McHenry')
 and lcv.propertytype='Residential'
 ) a

--Sides by Qtr and Year (Entire MLS)
select
County,
listpricebucket,
DATEPART(QUARTER,lcc.CloseDate) As date_qtr,
DATEPART(YEAR,lcc.CloseDate) As date_year,
SUM(sides) As SidesCount,
SUM(volume_credit) As VolumeTotal
INTO #tl
FROM #lcc lcc
group by County,listpricebucket,DATEPART(QUARTER,lcc.CloseDate),DATEPART(YEAR,lcc.CloseDate)


--Sides by Qtr and Year (Per Company)
select
County,
listpricebucket,
ISNULL(lcc.Company,'Others') As Company,DATEPART(QUARTER,lcc.CloseDate) As date_qtr,DATEPART(YEAR,lcc.CloseDate) As date_year,
SUM(sides) As SidesCount,
SUM(volume_credit) As VolumeTotal
INTO #lbc
FROM #lcc lcc
group by County,listpricebucket,lcc.Company,DATEPART(QUARTER,lcc.CloseDate),DATEPART(YEAR,lcc.CloseDate)


--Output
select lbc.*,
	CASE WHEN lbc.listpricebucket=1 THEN '$0 - $' + FORMAT(@break1-1,'#,##')
	WHEN lbc.listpricebucket=2 THEN '$' + FORMAT(@break1,'#,##') + ' - $' + FORMAT(@break2-1,'#,##')
	WHEN lbc.listpricebucket=3 THEN '$' +FORMAT(@break2,'#,##') + ' - $' + FORMAT(@break3-1,'#,##')
	WHEN lbc.listpricebucket=4 THEN '$' + FORMAT(@break3,'#,##') + ' - $' + FORMAT(@break4-1,'#,##')
	WHEN lbc.listpricebucket=5 THEN '$' + FORMAT(@break4,'#,##') + '+'
	ELSE NULL END As listpricebuckettext,
cast(lbc.SidesCount as real)/cast(tl.SidesCount as real)*100 As SidesMarketShare,
cast(lbc.VolumeTotal as real)/cast(tl.VolumeTotal as real)*100 As VolumeMarketShare
from #lbc lbc join #tl tl on lbc.listpricebucket=tl.listpricebucket and lbc.County=tl.County and lbc.date_qtr=tl.date_qtr and lbc.date_year=tl.date_year
order by date_year,date_qtr,sidesCount DESC




END









GO

