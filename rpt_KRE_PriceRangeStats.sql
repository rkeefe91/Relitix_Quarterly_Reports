USE [Relitix]
GO

/****** Object:  StoredProcedure [dbo].[rpt_KRE_PriceRangeStats]    Script Date: 5/19/2020 2:35:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO











-- ==============================================================================================
-- Author:		Matt Michalowski
-- Create date: 1/25/2018
-- Description:	KRE Price Range Stats

--Changes:
-- 4/19/2019 - Removed prior year data from the output
-- 7/12/2019 - Added prior year data to the output per client's request
-- 5/6/2020 - updated inventory WHERE clause
-- ==============================================================================================
CREATE PROCEDURE [dbo].[rpt_KRE_PriceRangeStats]
	-- Add the parameters for the stored procedure here
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

--Set Date Defaults
set @cy_qtr_start=(SELECT DATEADD(qq, DATEDIFF(qq, 0, GETDATE()) - 1, 0)) --First Day of Previous Qtr
set @cy_qtr_end=(Select DateAdd(day, -1, dateadd(qq, DateDiff(qq, 0, GETDATE()), 0))) --Last Day of Previous Qtr
set @py_qtr_start=(SELECT DATEADD(YEAR,-1,@cy_qtr_start)) --First Day of Previous Qtr (Prior Year)
set @py_qtr_end=(SELECT DATEADD(YEAR,-1,@cy_qtr_end)) --Last Day of Previous Qtr (Prior Year)

-- Set stats for each price bucket
set @break1 = 125000
set @break2 = 200000
set @break3 = 350000
set @break4 = 500000


;with cte as (
			select cbr.County,lc.*
					,case  when closeprice  < @break1 then 1
							when closeprice >= @break1 AND closeprice < @break2 then 2
							when closeprice >= @break2 AND closeprice < @break3 then 3
							when closeprice >= @break3 AND closeprice < @break4 then 4
							when closeprice >- @break4 then 5
							else NULL end as closepricebucket
					,case  when listprice  < @break1 then 1
							when listprice >= @break1 AND listprice < @break2 then 2
							when listprice >= @break2 AND listprice < @break3 then 3
							when listprice >= @break3 AND listprice < @break4 then 4
							else 5 end as listpricebucket
			from Relitix.dbo.listings_combined lc
				join Relitix.dbo.listings_combined_geo g
					on lc.sourcesystemid = g.sourcesystemid
						and lc.listingkey = g.listingkey
				join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
				join
(SELECT DISTINCT REGION,COUNTY FROM Relitix_Staging.dbo.WRA_CountyByRegion WHERE Region!='Milwaukee') cbr --Single counties can belong to more than one region, so select distinct instead of straight join on this table
on cbr.County=RTRIM(LTRIM(REPLACE(cn.County_name,'County','')))
			where (lc.sourcesystemid = 1 OR lc.sourcesystemID = 4 OR lc.sourcesystemID=8)
				and PropertyType = 'Residential'
				and g.statefp = 55
				and cbr.County IN ('Kenosha','Racine','Walworth')
UNION ALL

select cn.County,lc.*
					,case  when closeprice  < @break1 then 1
							when closeprice >= @break1 AND closeprice < @break2 then 2
							when closeprice >= @break2 AND closeprice < @break3 then 3
							when closeprice >= @break3 AND closeprice < @break4 then 4
							when closeprice >- @break4 then 5
							else NULL end as closepricebucket
					,case  when listprice  < @break1 then 1
							when listprice >= @break1 AND listprice < @break2 then 2
							when listprice >= @break2 AND listprice < @break3 then 3
							when listprice >= @break3 AND listprice < @break4 then 4
							else 5 end as listpricebucket
			from Relitix.dbo.listings_combined lc
				join Relitix.dbo.listings_combined_geo g
					on lc.sourcesystemid = g.sourcesystemid
						and lc.listingkey = g.listingkey
				join
relitix.dbo.Census_County_Names cn 
on g.CountyFP=cn.CountyFP and g.StateFP=cn.State_Num
			where (lc.sourcesystemid=10)
				and PropertyType = 'Residential'
				and RTRIM(LTRIM(REPLACE(cn.County_name,'County',''))) IN ('McHenry')
				and cn.State_Num=17
				),
inv as (
        select 
			county,
			listpricebucket
            ,Count(Rtx_LC_ID) as total_listings
            --,AVG(DATEDIFF(DAY,listingcontractdate,@cy_qtr_end)) as avg_DOM
        from cte
        where StandardStatus <> 'Coming Soon'
                    AND (
                        StandardStatus = 'Active' AND (
                                                            ListingContractDate < @cy_qtr_end
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Active Under Contract' AND (
                                                            ListingContractDate < @cy_qtr_end
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Expired' AND (
                                                            ListingContractDate < @cy_qtr_end
                                                            AND (CloseDate IS NULL OR CloseDate > @cy_qtr_end)
                                                            AND StatusChangeTimestamp>@cy_qtr_end
        ​
                                                            )
        ​
                        OR StandardStatus = 'Pending' AND (
                                                            ListingContractDate < @cy_qtr_end
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Closed' AND (
                                                            ListingContractDate < @cy_qtr_end
                                                            AND (coalesce(closedate, statuschangetimestamp) > @cy_qtr_end)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Withdrawn' AND (
                                                            ListingContractDate < @cy_qtr_end
                                                            AND (CloseDate IS NULL OR CloseDate > @cy_qtr_end)
                                                            AND statuschangetimestamp > @cy_qtr_end
                                                            )
                        OR StandardStatus = 'Canceled' AND (
                                                            ListingContractDate < @cy_qtr_end
                                                            AND (CloseDate IS NULL OR CloseDate > @cy_qtr_end)
                                                            AND statuschangetimestamp > @cy_qtr_end
                                                            )
)
        GROUP BY county,listpricebucket
            ),
solds as (
        select county,listpricebucket
                ,Count(Rtx_LC_ID) as total_sold
				,sum(closeprice) as total_volume_sold
        from cte
        where  CloseDate <= @cy_qtr_end
            AND CloseDate > DATEADD(YEAR,-1,@cy_qtr_end)
            AND ClosePrice > 0
        GROUP BY county,listpricebucket
        ),


pyinv as (
        select 
			county,
			listpricebucket
            ,Count(Rtx_LC_ID) as total_listings
            --,AVG(DATEDIFF(DAY,listingcontractdate,@py_qtr_end)) as avg_DOM
        from cte
        where StandardStatus <> 'Coming Soon'
                    AND (
                        StandardStatus = 'Active' AND (
                                                            ListingContractDate < @py_qtr_end
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Active Under Contract' AND (
                                                            ListingContractDate < @py_qtr_end
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Expired' AND (
                                                            ListingContractDate < @py_qtr_end
                                                            AND (CloseDate IS NULL OR CloseDate > @py_qtr_end)
                                                            AND StatusChangeTimestamp>@py_qtr_end
        ​
                                                            )
        ​
                        OR StandardStatus = 'Pending' AND (
                                                            ListingContractDate < @py_qtr_end
                                            --              AND (CloseDate IS NULL OR CloseDate > @eval_date)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Closed' AND (
                                                            ListingContractDate < @py_qtr_end
                                                            AND (coalesce(closedate, statuschangetimestamp) > @py_qtr_end)
                                            --              AND (ExpirationDate IS NULL OR ExpirationDate >@eval_date)
                                            --              AND (WithdrawnDate IS NULL OR WithdrawnDate > @eval_date)
                                            --              AND (CancelationDate IS NULL OR CancelationDate > @eval_date)
                                                            )
                        OR StandardStatus = 'Withdrawn' AND (
                                                            ListingContractDate < @py_qtr_end
                                                            AND (CloseDate IS NULL OR CloseDate > @py_qtr_end)
                                                            AND statuschangetimestamp > @py_qtr_end
                                                            )
                        OR StandardStatus = 'Canceled' AND (
                                                            ListingContractDate < @py_qtr_end
                                                            AND (CloseDate IS NULL OR CloseDate > @py_qtr_end)
                                                            AND statuschangetimestamp > @py_qtr_end
                                                            )
)
        GROUP BY county,listpricebucket
            ),
pysolds as (
        select county,listpricebucket
                ,Count(Rtx_LC_ID) as total_sold
				,sum(closeprice) as total_volume_sold
        from cte
        where  CloseDate <= @py_qtr_end
            AND CloseDate > DATEADD(YEAR,-1,@py_qtr_end)
            AND ClosePrice > 0
        GROUP BY county,listpricebucket
        ),
DOM AS (
select YEAR(CloseDate) As [Year],county,listpricebucket
	,avg(datediff(day,listingcontractdate,closedate)) as DOM
from cte
where DATEPART(quarter, closedate) = DATEPART(quarter,@cy_qtr_end)
	and YEAR(CloseDate) > DATEPART(year,@py_qtr_end)-1
group by YEAR(CloseDate),county,listpricebucket
)

select
	YEAR(@cy_qtr_end) As Yr, 
	inv.county,
	CASE WHEN inv.listpricebucket=1 THEN '$0 - $' + FORMAT(@break1-1,'#,##')
	WHEN inv.listpricebucket=2 THEN '$' + FORMAT(@break1,'#,##') + ' - $' + FORMAT(@break2-1,'#,##')
	WHEN inv.listpricebucket=3 THEN '$' +FORMAT(@break2,'#,##') + ' - $' + FORMAT(@break3-1,'#,##')
	WHEN inv.listpricebucket=4 THEN '$' + FORMAT(@break3,'#,##') + ' - $' + FORMAT(@break4-1,'#,##')
	WHEN inv.listpricebucket=5 THEN '$' + FORMAT(@break4,'#,##') + '+'
	ELSE NULL END As listpricebucket
    ,inv.total_listings
    ,DOM.DOM As avg_DOM
    ,solds.total_sold
	,solds.total_volume_sold
    ,(cast(inv.total_listings as real))/(cast(solds.total_sold as real)) * 12 as months_inventory
from inv    
    join solds
        on inv.County=solds.County and inv.listpricebucket = solds.listpricebucket
		join DOM on inv.County=DOM.County and inv.listpricebucket=DOM.listpricebucket and DOM.[Year]=YEAR(@cy_qtr_end)
--order by listpricebucket

UNION ALL

select
	YEAR(@py_qtr_end) As Yr, 
	pyinv.county,
	CASE WHEN pyinv.listpricebucket=1 THEN '$0 - $' + FORMAT(@break1-1,'#,##')
	WHEN pyinv.listpricebucket=2 THEN '$' + FORMAT(@break1,'#,##') + ' - $' + FORMAT(@break2-1,'#,##')
	WHEN pyinv.listpricebucket=3 THEN '$' +FORMAT(@break2,'#,##') + ' - $' + FORMAT(@break3-1,'#,##')
	WHEN pyinv.listpricebucket=4 THEN '$' + FORMAT(@break3,'#,##') + ' - $' + FORMAT(@break4-1,'#,##')
	WHEN pyinv.listpricebucket=5 THEN '$' + FORMAT(@break4,'#,##') + '+'
	ELSE NULL END As listpricebucket
    ,pyinv.total_listings
    ,DOM.DOM As avg_DOM
    ,pysolds.total_sold
	,pysolds.total_volume_sold
    ,(cast(pyinv.total_listings as real))/(cast(pysolds.total_sold as real)) * 12 as months_inventory
from pyinv    
    join pysolds
        on pyinv.County=pysolds.County AND pyinv.listpricebucket = pysolds.listpricebucket
		join DOM on pyinv.County=DOM.County and pyinv.listpricebucket=DOM.listpricebucket and DOM.[Year]=YEAR(@py_qtr_end)
order by listpricebucket




END









GO

