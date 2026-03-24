USE [Trade]
GO

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Harry
-- Create date: 2021/12/8
-- Description:
--		Report - Purchase.R08  for Power BI
-- =============================================
If Object_Id ( 'dbo.PowerBI_PurchaseList', 'P' ) Is Not Null
    Drop Procedure dbo.PowerBI_PurchaseList;
Go

Create Procedure [dbo].PowerBI_PurchaseList
As
Begin
	Set NoCount On;
	SET XACT_ABORT ON;

	DECLARE @SciDelivery_S DATE = dateadd(m, datediff(m,0,DATEADD(month,-6,getdate())),0)  --取前6個月的月初
	DECLARE @SciDelivery_E DATE = dateadd(day ,-1, dateadd(m, datediff(m,0,DATEADD(Year,1,getdate()))+1,0)) --取1年後的月底

	
	DECLARE @ExecSQL VARCHAR(MAX);
	
	--建立暫存比對用table
	SET @ExecSQL ='
	If Exists(Select * From PBIReportData.sys.tables Where Name = ''PurchaseList_tmp'')
	Begin
		Drop Table PBIReportData.dbo.PurchaseList_tmp
	End;
	Create Table PBIReportData.dbo.PurchaseList_tmp
		(   [Factory] [varchar](8) NOT NULL,
			[Country of Destination] [varchar](30) NULL,
			[Country of Loading] [varchar](30) NULL,
			[Country of Loading (Original)] [varchar](30) NULL,
			[Supplier] [varchar](6) NULL,
			[Supplier Name] [nvarchar](25) NULL,
			[PINo Need] [varchar](1) NOT NULL,
			[Est. Supplier Del.] [date] NULL,
			[Sup.Del. 1st cfm] [date] NULL,
			[Sup.Del Rvsd] [date] NULL,
			[SP#] [varchar](13) NULL,
			[Category] [varchar](20) Null,
			[SMR] [nvarchar](69) NULL,
			[MR] [nvarchar](69) NULL,
			[PC Handle] [nvarchar](69) NULL,
			[PO Handle] [nvarchar](69) NULL,
			[PO SMR] [nvarchar](69) NULL,
			[Style] [varchar](15) NOT NULL,
			[Program] [varchar](12) NOT NULL,
			[Seq1] [varchar](3) NULL,
			[Seq2] [varchar](2) NULL,
			[Ref#] [varchar](36) NULL,
			[Brand Ref#] [varchar](50) NULL,
			[OrderType] [varchar](20) NULL,
			[Price] [numeric](16, 4) NULL,
			[Currency] [varchar](3) NULL,
			[Unit] [varchar](8) NULL,
			[Purchase Qty] [numeric](10, 2) NULL,
			[Ship Qty] [numeric](10, 2) NOT NULL,
			[Balance Qty] [numeric](11, 2) NULL,
			[Purchase FOC Qty] [numeric](10, 2) NULL,
			[Ship FOC Qty] [numeric](10, 2) NULL,
			[Balance FOC Qty] [numeric](11, 2) NULL,
			[Use Qty] [numeric](10, 2) NULL,
			[Loss Qty] [numeric](10, 2) NULL,
			[Amount(USD)] [numeric](18, 2) NULL,
			[In-Line Date] [date] NULL,
			[Season] [varchar](10) NOT NULL,
			[PI#] [varchar](25) NULL,
			[Size] [varchar](50) NULL,
			[S/Unit] [varchar](50) NULL,
			[Color ID] [varchar](50) NULL,
			[Color Desc] [nvarchar](150) NULL,
			[Actual ETA] [date] NULL,
			[PONo] [varchar](30) NULL,
			[KPI L/ETA] [date] NULL,
			[Shipping Schedule] [date] NULL,
			[Estimate ETA] [date] NULL,
			[SCI Delivery] [date] NULL,
			[Buyer Delivery] [date] NULL,
			[CRD Date] [date] NULL,
			[Partial Shipment] [int] NULL,
			[Order Q’ty] [numeric](38, 0) NULL,
			[CustCD] [varchar](16) NULL,
			[Supplier Over Shipping Qty] [numeric](11, 2) NULL,
			[Supplier over shipping Qty %] [numeric](28, 13) NULL,
			[Input Qty] [numeric](38, 2) NULL,
			[Adject Qty] [numeric](38, 2) NULL,
			[Lead Time] [numeric](3, 0) NULL,
			[Order cfm Date] [date] NOT NULL,
			[CPU] [numeric](8, 3) NOT NULL,
			[Spec] [nvarchar](max) NULL,
			[Special] [nvarchar](max) NULL,
			[Long L/T Reason] [nvarchar](500) NULL,
			[WK#] [nvarchar](max) NULL,
			[Complete] [varchar](1) NOT NULL,
			[Stock C] [varchar](1) NOT NULL,
			[Shipping Mark] [varchar](20) NULL,
			[ECFA] [varchar](1) NOT NULL,
			[ECFA Duty] [numeric](6, 2) NULL,
			[Import Duty] [numeric](6, 2) NULL,
			[P/I Date] [date] NULL,
			[Materila Type] [varchar](20) NULL,
			[Ship Mode] [varchar](10) NULL,
			[Order List] [nvarchar](max) NULL,
			[Stock QTY (at PO Create Date)] [numeric](12, 1) NULL,
			[PR Comments] [nvarchar](max) NULL,
			[MR Comments] [nvarchar](max) NULL,
			[Buy Back] [varchar](1) NOT NULL,
			[Still need to Production] [varchar](1) NOT NULL,
			[Brand] [varchar](8) NOT NULL,
			[Supplier RefNo] [varchar](50) NULL,
			[Supplier Color] [nvarchar](max) NULL,
			[Remark] [nvarchar](max) NULL,
			[In the name of] [varchar](8) NULL,
			[For Other Brand] [varchar](1) NULL,
			[Eco thread SP#] [varchar](20) NULL,
			[without create M (for Eco RefNo)] [varchar](1) NULL,
			[Not output yet (for Eco RefNo)] [varchar](1) NULL,
		    [Supplier Group]	[NVarChar](20),
		    [Supplier Delivery]	[VarChar](10),			
		    [Material]			[VarChar](10),
            [Mtl. Complete]    [VarChar](1),
			[Is 3rd Country] [VarChar](1),
			[TransferBIDate] [datetime],
			[GMT complete] [VarChar](1),
			[Last Buyer Delivery] [date] NULL,
			[Prod Item] [VarChar](20),
			[Order Cancel] VarChar(1),			
			[Mtl. O.Standing Reason] NVarChar(510),			
            [KPI L/ETA (Order List)] date,            	
			[Print Date] [datetime],            	
			[Default del. by L/T] [date],            	
			[Sup. del. Planning] [date],            	
			[FTY L/ETA] [date],
			[Packing LETA] [date]
		);		
		CREATE INDEX IX_PurchaseList_MergeKey ON PBIReportData.dbo.PurchaseList_tmp ([SP#], SEQ1, SEQ2);
		If Exists(Select * From PBIReportData.sys.tables Where Name = ''T_PO3OrderList_tmp'')
		Begin
			Drop Table PBIReportData.dbo.T_PO3OrderList_tmp
		End;
		Create Table PBIReportData.dbo.T_PO3OrderList_tmp
			(   
				[id] [varchar](13) NOT NULL,
				[SEQ1] [varchar](3) NOT NULL,
				[SEQ2] [varchar](2) NOT NULL,
				[OrderID] [varchar](13) NOT NULL,
				[AddName] [varchar](10) NULL,
				[AddDate] [datetime] NULL,
				[EditName] [varchar](10) NULL,
				[EditDate] [datetime] NULL,
			);		
	'
	EXEC (@ExecSQL) AT [PowerBI];

	SELECT poid, MinSciDelivery, MinBuyerDelivery, MinKPILETA
	into #tmp
	FROM Orders o
	CROSS APPLY  (
		SELECT MinSciDelivery, MinBuyerDelivery
		FROM dbo.GetMinDelivery(o.poid, o.category)
	) s1
	CROSS APPLY (
		SELECT MinKPILETA
		FROM dbo.GetSCI(o.POID, o.Category)
	) kpi
	WHERE o.ID = o.POID
	and ((s1.MinSciDelivery BETWEEN @SciDelivery_S and @SciDelivery_E) 
		or EXISTS (SELECT 1 FROM PO_Supp_Detail po3 WHERE po3.ID = o.poID and (po3.AddDate >= CAST(DATEADD(DAY, -7,GETDATE()) AS DATE) or po3.EditDate >= CAST(DATEADD(DAY, -7,GETDATE()) AS DATE)))
		or EXISTS (SELECT 1 FROM PO_Supp po2 WHERE po2.ID = o.poID and (po2.AddDate >= CAST(DATEADD(DAY, -7,GETDATE()) AS DATE) or po2.EditDate >= CAST(DATEADD(DAY, -7,GETDATE()) AS DATE)))
	)


	EXEC ('TRUNCATE TABLE PBIReportData.dbo.PurchaseList_tmp') AT [PowerBI];
	Insert Into [PowerBI].PBIReportData.dbo.PurchaseList_tmp
	Select o.FactoryID
    , CountryOfDestination = cty.Alias
    , CountryOfLoading = suppcty.Alias
    , [Origi_CountryOfLoading] = isnull(OriCountry.Alias, suppcty.Alias)
    , po2.SuppID
    , SuppName = Supp.AbbCH + '/' + isnull(Supp.AbbEN, '')
    , npi.needPI
    , po3.SystemETD
    , SuppDel1stCfm = IsNull(stockPO3.CfmETD, stockPO3.SystemETD)
    , stockPO3.RevisedETD
    , [SPNo] = PO.id
    , Category = isnull(category.Name, '')
    , SMR = SMR.IdAndNameAndExt
    , MR = MRHandle.IdAndNameAndExt
    , PCHandle = PCHandle.IdAndNameAndExt
    , POHandle = POHandle.IdAndNameAndExt
    , POSMR = POSMR.IdAndNameAndExt
    , o.StyleID
    , o.ProgramID
    , po3.Seq1
    , po3.Seq2
    , po3.RefNo
    , BrandRefno = isnull(f.BrandRefno, '')
    , OrderTypeID = isnull(o.OrderTypeID, '')
    , Price = isnull(round(stockPO3.Price * poStockSuppRate.Rate, 4, 1), 0)
    , Supp.CurrencyID
    , po3.POUnit
    , POQty = isnull(po3.Qty, 0)
    , ShipQty = isnull(po3.ShipQty, 0)
    , BalQty = isnull(p3Qty.Qty, 0)
    , POFoc = isnull(po3.FOC, 0)
    , ShipFOC = isnull(po3.ShipFOC, 0)
    , BalFoc = isnull(po3.ShipFOC, 0) - isnull(po3.FOC, 0)
    , NetQty = isnull(po3.NetQty, 0)
    , LossQty = isnull(po3.LossQty, 0)
    , AmtUSD = Isnull(getPOAmount.value, 0) + Isnull(getPOStockAmount.value, 0)
    , o.SewInLIne
    , o.SeasonID
    , PINO = isnull(po3.PINO, '')
    , SizeSpec = po3Spec.Size
    , po3Spec.SizeUnit
    , ColorID = po3Spec.Color
    , ColorName = Color.Name
    , stockPO3.ShipETA 
    , CustPONo = isnull(o.CustPONo, '')
    , tmp.MinKPILETA
    , ShippingSchedule = getScheduleDate.ScheduleDate
    , FirstETA = getScheduleDate.ETA
    , tmp.MinSciDelivery
    , tmp.MinBuyerDelivery
    , getOrderInfo.MinCRDDate
    , PartialShipment = isnull(getPartialShipment.value, 0)
    , OrderQty = isnull(getOrderInfo.OrdersQty, 0)
    , CustCDID = isnull(o.CustCDID, '')
    , SuppOverShipQty = isnull(p3Qty2.Qty, 0)
    , SuppOverShipQtyPercent = iif(isnull(p3Qty2.Qty, 0) != 0 and isnull(po3.Qty, 0) != 0, (isnull(p3Qty2.Qty, 0) / isnull(po3.Qty, 0)) * 100, 0 )
    , InputQty = isnull(inv.type1Qty, 0)
    , AdjQty = isnull(inv.type4Qty, 0)
    , LT = isnull(getLT.value, 0)
    , o.CFMDate
    , o.CPU
    , Spec = isnull(po3.Spec, '')
    , po3.Special    
    , LongerLTReason = isnull(ReasonLongerLT.Name, '')
    , WKID = isnull(exs.exStr, '')
    , Complete = case po3.Complete when 1 then 'Y' else '' end
    , StockComplete = iif(Isnull(po3.StockSeq1, '') = '' or stockPO3.Complete = 0, '', 'Y') 
    , FTYMark = isnull(PO.FTYMark, '')
    , ECFA = iif(IsECFA.value = 1, 'Y', '')
    , ECFADuty = iif(IsECFA.value = 1, isnull(Duty.ECFADuty, 0), 0)
    , ImportDuty = iif(IsECFA.value = 0, isnull(Duty.ImportDuty, 0), 0)
    , po3.PIDate
    , f.MtltypeId
    , po3.ShipModeID
    , po3Show.OrderList
    , StockQty = isnull(po3.StockQty,0)
    , Comments_PR = isnull(po3.Comments_PR,'')
    , Comments_MR = isnull(po3.Comments_MR,'')
    , IsBuyBack = iif(o.IsBuyBack=1,'Y','')
    , NeedProduction = iif(o.NeedProduction=1,'Y','')
    , o.BrandID
    , SuppRefno = isnull(fs.SuppRefno,'')
    , SuppColor = isnull(po3.SuppColor,'')
    , Remark = isnull(po3.Remark,'')
    , InTheNameOfBrandID = isnull(o.InTheNameOfBrandID, '')
    , IsForOtherBrand = iif(po3.IsForOtherBrand = 1, 'Y', '')
    , [Eco thread SP#] = po3.ToMtlPOID + '-' + po3.ToMtlSeq1 + '-' + po3.ToMtlSeq2
    , [without create M (for Eco RefNo)] = iif(po3.IsForOtherBrand = 1 and isnull(po3.ToMtlPOID, '') = '' and po3.qty > 0, 'Y', '')
    , [Not output yet (for Eco RefNo)] = iif(po3.IsForOtherBrand = 1 and po3.qty > 0, 'Y', '')
	, SuppGroup = SuppGroup.ID + '-' + SuppGroup.AbbCH
	, FinalETD = CONVERT(varchar(10), po3.FinalETD, 111)
	, Material = IIF(po3.FabricType = 'F', 'Fabric', 'Accessory')
	, POComplete = IIF(PO.Complete = 1, 'Y', '')
	, [Is 3rd Country] = IIF(Supp.ThirdCountry = 1, 'Y', '')
	, [TransferBIDate] = GetDate()
	, [GMT complete] = iif(getOrderInfo.GMTComplete = 0, '', 'Y')
	, [Last Buyer Delivery] = getOrderInfo.MaxBuyerDelivery
	, [Prod Item] = m.ProductionType
	, [Order Cancel] = iif(getOrderInfo.Junk = 0, '', 'Y')
	, [Mtl. O.Standing Reason] =  isnull(PO_MtlOStanding.ReasonID + '-' + Reason.Name, '') 
    , [KPI L/ETA (Order List)] = isnull(getKPILETAByOrderList.MinLETA, tmp.MinKPILETA)
	, [Print Date] = po3.PrintDate
	, [Default del. by L/T] = getDefaultDelDate.DefaultDelDate
	, [Sup. del. Planning] = GetSupDelTarget.SupDelTarget
	, [FTY L/ETA] = po.FtyLETA
	, [Packing LETA] = O.PackLETA
	from Trade.dbo.orders o WITH (NOLOCK)
	inner JOIN #tmp tmp on o.id= tmp.poid
	left join Trade.dbo.Brand WITH(Nolock) on Brand.ID = o.BrandID
	left join Trade.dbo.PO WITH (NOLOCK) on o.id = PO.id
	left join Trade.dbo.PO_Supp po2 WITH (NOLOCK) on po2.id = PO.id
	left join Trade.dbo.PO_Supp_Detail po3 WITH (NOLOCK) on po3.id = po2.id and po3.Seq1 = po2.SEQ1
	outer apply dbo.GetPo3Spec(po3.ID, po3.Seq1, po3.Seq2) po3Spec
	left join Trade.dbo.PO_Supp_Detail_OrderList_Show po3Show WITH (NOLOCK) on po3Show.ID = po3.ID And po3Show.Seq1 = po3.Seq1 And po3Show.Seq2 = po3.Seq2
	left join Trade.dbo.Supp WITH (NOLOCK) on po2.suppid = supp.id
	left join Trade.dbo.Supp SuppGroup WITH (NOLOCK) on SuppGroup.ID = Supp.SuppGroupFabric
	left join Trade.dbo.Factory fty WITH (NOLOCK) on o.factoryid = fty.id
	left join Trade.dbo.Country cty WITH (NOLOCK) on fty.CountryID = cty.id
	left join Trade.dbo.Country suppcty WITH (NOLOCK) on Supp.CountryID = suppcty.id
	left join Trade.dbo.Color WITH (NOLOCK) on o.BrandID = Color.BrandID And po3Spec.Color = Color.ID
	left join Trade.dbo.fabric f WITH (NOLOCK) on f.SCIRefno = po3.SCIRefno
	left join Trade.dbo.Mtltype m WITH (NOLOCK) on f.MtltypeId = m.ID
	left join Trade.dbo.PO_Supp OriPo2 WITH (NOLOCK) on OriPo2.ID = po3.StockPOID and OriPo2.SEQ1 = po3.StockSeq1
	left join Trade.dbo.Supp OriSupp WITH (NOLOCK) on OriPo2.SuppID = OriSupp.ID
	left join Trade.dbo.Unit u with(nolock) on u.ID = po3.PoUnit
	left join Trade.dbo.Country OriCountry WITH (NOLOCK) on OriSupp.CountryID = OriCountry.ID
	left join Trade.dbo.Fabric_Supp fs with(nolock) on fs.SCIRefno = f.SCIRefno and fs.SuppID = po2.SuppID
	left join Trade.dbo.Inventory with(nolock) on po3.InventoryUkey = Inventory.Ukey
	left join Trade.dbo.InvtransReason with(nolock) on Inventory.ReasonID = InvtransReason.ID		
	left join Trade.dbo.DropDownList category with(nolock) on category.Type = 'Category' And category.ID = o.Category
	left join Trade.dbo.GetName SMR on SMR.ID = o.SMR
	left join Trade.dbo.GetName MRHandle on MRHandle.ID = o.MRHandle
	left join Trade.dbo.GetName PCHandle on PCHandle.ID = po.PCHandle
	left join Trade.dbo.GetName POHandle on POHandle.ID = po.POHandle
	left join Trade.dbo.GetName POSMR on POSMR.ID = po.POSMR
	left join (
		Select PoID, SEQ1, SEQ2
		, Sum(iif(Type = '1', Qty, 0)) type1Qty
		, Sum(iif(Type = '4', Qty, 0)) type4Qty 
		From Trade.dbo.Invtrans_Detail WITH (NOLOCK)
		Where Invtrans_Detail.ConfirmDate IS NOT NULL
			and Invtrans_Detail.Type in ('1','4')
		group by PoID, SEQ1, SEQ2
	) inv on inv.PoID = o.id and inv.SEQ1 = po3.SEQ1 and inv.SEQ2 = po3.SEQ2
	OUTER APPLY (Select DefaultDelDate = dbo.GetDefaultDelDate(po3.SciRefNo, o.Category, po2.SuppID, o.StyleID, o.BrandID, o.SeasonID, fty.CountryID, o.OrderTypeID, po3Spec.Color, o.SystemETD_AdditionalDays, o.CfmDate))getDefaultDelDate
	Outer apply (select * from dbo.GetSupDelTarget(po3.ID, po3.Seq1, po3.Seq2, po.TargetLETA)) GetSupDelTarget
	cross apply (select isnull(po3.ShipQty, 0) - po3.Qty as Qty) p3Qty
	cross apply (select iif(p3Qty.Qty < 0, 0 , p3Qty.Qty) as Qty) p3Qty2
	cross apply (
		SELECT tmpPO3.CfmETD
		, tmpPO3.SystemETD
		, tmpPO3.RevisedETD
		, tmpPO3.ShipETA
		, tmpPO2.SuppID
		, tmpPO3.Complete
		, tmpPO3.FinalETD
		, tmpPO3.EstETA
		, stockOrders.Category
		, stockOrders.CFMDate
		, POID = tmpPO3.ID
		, tmpPO3.Seq1
		, tmpPO3.Seq2
		, tmpPO3.Price
		, stockSupp.CurrencyID
		FROM Trade.dbo.PO_Supp_Detail tmpPO3 WITH (NOLOCK)
		INNER JOIN Trade.dbo.Po_Supp tmpPO2 WITH (NOLOCK) ON tmpPO3.ID = tmpPO2.ID AND tmpPO3.Seq1 = tmpPO2.Seq1
		INNER JOIN Trade.dbo.Supp stockSupp WITH (NOLOCK) ON tmpPO2.SuppID = stockSupp.ID
		INNER JOIN Trade.dbo.Orders stockOrders WITH (NOLOCK) ON stockOrders.ID = tmpPO3.ID
		CROSS APPLY (
			SELECT ID = IIF(ISNULL(po3.StockPOID, '') = '', po3.ID, po3.StockPOID)
			   , Seq1 = IIF(ISNULL(po3.StockPOID, '') = '', po3.Seq1, po3.StockSeq1)
			   , Seq2 = IIF(ISNULL(po3.StockPOID, '') = '', po3.Seq2, po3.StockSeq2)
		) getPo3
		WHERE tmpPO3.ID = getPo3.ID
		AND tmpPO3.Seq1 = getPo3.Seq1
		AND tmpPO3.Seq2 = getPo3.Seq2
	) stockPO3
	Left Join Trade.dbo.PO_MtlOStanding On PO_MtlOStanding.ID = stockPO3.POID And PO_MtlOStanding.Seq1 = stockPO3.Seq1 And PO_MtlOStanding.Seq2 = stockPO3.Seq2
	Left Join dbo.Reason On Reason.ReasonTypeID = 'PO_MtlOutStanding' And Reason.ID = PO_MtlOStanding.ReasonID
	Left Join Trade.dbo.Reason ReasonLongerLT On ReasonLongerLT.ReasonTypeID = 'LongerLT' AND ReasonLongerLT.ID = po3.LongerLTReasonID AND ReasonLongerLT.Junk = 0
	OUTER APPLY (
		Select Min(IIF(o.PFETA Is Null, IIF(o.Category Not In ('S','T'), o.LETA, o.PFETA), o.PFETA)) as MinLETA
		From Orders o
		Where ID in (
			Select OrderID
			From PO_Supp_Detail_OrderList po4
			Where po4.id = po3.ID
			and po4.SEQ1 = po3.Seq1
			and po4.SEQ2 = po3.Seq2
	  ) And o.Junk = 0
	) getKPILETAByOrderList
	cross apply (SELECT value = Trade.dbo.GetECFA_Refno(o.ID, po2.suppid, po3.SCIRefNo)) as IsECFA
	Outer apply (
		SELECT hsCode.ECFADuty, hsCode.ImportDuty
		FROM Trade.dbo.Fabric_HsCode AS hsCode WITH (NOLOCK)
		WHERE hsCode.SCIRefno = po3.SCIRefNo
		AND hsCode.SuppID = po2.SuppID
		AND hsCode.Year = YEAR(po3.FinalETD)
		AND hsCode.HSType = '1'
	) Duty
	cross apply(
		SELECT needPI = CASE
				WHEN o.Category IN ('B', 'S', 'M') THEN IIF(Supp.BulkPI = 1, 'Y', 'N')
				ELSE ''
			END
	) npi
	Outer apply (
		SELECT exStr = (
			SELECT CONCAT('(#', Export.ID, ',ETD:', Export.ETD, ',ETA:', Export.ETA, ',', CEILING(Export_Detail.Qty + Export_Detail.FOC), ')') + ','
			FROM Trade.dbo.Export WITH (NOLOCK)
			INNER JOIN Trade.dbo.Export_Detail WITH (NOLOCK) ON Export.ID = Export_Detail.ID
			WHERE Export_Detail.PoID = PO.id
			AND Export_Detail.Seq1 = po3.Seq1
			AND Export_Detail.Seq2 = po3.Seq2
			FOR XML PATH (''))
	) exs
	cross apply (
		SELECT ScheduleDate, ETA
		FROM Trade.dbo.GetShip_Detail_MinETA(PO.id, po3.Seq1, po3.Seq2, 'G')
	) getScheduleDate
	Outer apply (
		SELECT value = COUNT(Export_Detail.ID)
		FROM Trade.dbo.Export_Detail WITH (NOLOCK)
		WHERE Export_Detail.POID = PO.id
		AND Export_Detail.SEQ1 = po3.Seq1
		AND Export_Detail.SEQ2 = po3.Seq2
	) getPartialShipment
	cross apply (
		SELECT value = Trade.dbo.GetMtlLT(po3.SCIRefNo, o.Category, po2.SuppID, o.StyleID, o.BrandID, o.SeasonID, fty.CountryID, o.OrderTypeID, po3Spec.Color)
	) getLT
	Outer Apply Trade.dbo.GetCurrencyRate('FX', Supp.CurrencyID, 'USD', o.CFMDate) poNormalRate
	Outer Apply Trade.dbo.GetCurrencyRate('FX', stockPO3.CurrencyID, 'USD', stockPO3.CFMDate) poStockRate
	Outer Apply Trade.dbo.GetCurrencyRate('FX', stockPO3.CurrencyID, Supp.CurrencyID, stockPO3.CFMDate) poStockSuppRate
	Outer apply (
		SELECT value = IIF(ISNULL(po3.StockPOID, '') = '' OR ISNULL(InvtransReason.IsFOC, 0) = 1, 0, ROUND(po3.Qty * stockPO3.Price * poStockRate.Rate / ISNULL(u.PriceRate, 1), ISNULL(poStockRate.Exact, 0)))
	) getPOStockAmount
	Outer apply (
		SELECT value = ROUND(po3.Qty * po3.Price * poNormalRate.Rate / ISNULL(u.PriceRate, 1), ISNULL(poNormalRate.Exact, 0)) 
	) getPOAmount
	Outer apply (
		Select Max(BuyerDelivery) as MaxBuyerDelivery
		, Min(CRDDate) as MinCRDDate
		, Sum(Orders.Qty) as OrdersQty
		, Min(Cast(Orders.Junk as int)) as Junk
		, Min(iif(Orders.GMTComplete in ('C', 'S'), 1, 0)) as GMTComplete
		From Orders WITH (NOLOCK)
		Where Orders.POID = tmp.poid
	) getOrderInfo
	where o.ID = o.POID and po3.Junk =0
	
	EXEC ('TRUNCATE TABLE PBIReportData.dbo.T_PO3OrderList_tmp') AT [PowerBi];
	Insert Into [PowerBI].PBIReportData.dbo.T_PO3OrderList_tmp
	Select 
	po3So.id, po3So.SEQ1, po3So.SEQ2, po3So.OrderID, po3So.AddName, po3So.AddDate, po3So.EditName, po3So.EditDate
	from Trade.dbo.orders o WITH (NOLOCK)
	inner JOIN #tmp tmp on o.id= tmp.poid
	inner join Trade.dbo.Brand With(Nolock) on Brand.ID = o.BrandID
	inner join Trade.dbo.PO WITH (NOLOCK) on o.id = PO.id
	inner join Trade.dbo.PO_Supp po2 WITH (NOLOCK) on po2.id = PO.id
	inner join Trade.dbo.PO_Supp_Detail po3 WITH (NOLOCK) on po3.id = po2.id and po3.Seq1 = po2.SEQ1
	inner join Trade.dbo.PO_Supp_Detail_OrderList po3So WITH (NOLOCK) on po3So.ID = po3.ID And po3So.Seq1 = po3.Seq1 And po3So.Seq2 = po3.Seq2
	where o.ID = o.POID and po3.Junk =0
			
--用SP,Seq1,Seq2比對本次取得資料,存在更新,不存在新增
SET @ExecSQL ='
Merge PBIReportData.dbo.PurchaseList as t
	Using PBIReportData.dbo.PurchaseList_tmp as s
		On s.[SP#] = t.[SP#] AND s.SEQ1 = t.SEQ1 AND s.SEQ2 = t.SEQ2
	When Not Matched By Target
		Then Insert (  
			[Factory] ,
			[Country of Destination] ,
			[Country of Loading],
			[Country of Loading (Original)],
			[Supplier],
			[Supplier Name],
			[PINo Need],
			[Est. Supplier Del.],
			[Sup.Del. 1st cfm],
			[Sup.Del Rvsd],
			[SP#],
			[Category],
			[SMR],
			[MR],
			[PC Handle],
			[PO Handle],
			[PO SMR],
			[Style],
			[Program],
			[Seq1],
			[Seq2],
			[Ref#],
			[Brand Ref#],
			[OrderType],
			[Price],
			[Currency],
			[Unit],
			[Purchase Qty],
			[Ship Qty],
			[Balance Qty],
			[Purchase FOC Qty],
			[Ship FOC Qty],
			[Balance FOC Qty],
			[Use Qty],
			[Loss Qty],
			[Amount(USD)],
			[In-Line Date],
			[Season],
			[PI#],
			[Size],
			[S/Unit],
			[Color ID],
			[Color Desc],
			[Actual ETA],
			[PONo],
			[KPI L/ETA],
			[Shipping Schedule],
			[Estimate ETA],
			[SCI Delivery],
			[Buyer Delivery],
			[CRD Date],
			[Partial Shipment],
			[Order Q’ty],
			[CustCD],
			[Supplier Over Shipping Qty],
			[Supplier over shipping Qty %],
			[Input Qty],
			[Adject Qty],
			[Lead Time],
			[Order cfm Date],
			[CPU],
			[Spec],
			[Special],
			[Long L/T Reason],
			[WK#],
			[Complete],
			[Stock C],
			[Shipping Mark],
			[ECFA],
			[ECFA Duty],
			[Import Duty],
			[P/I Date],
			[Materila Type],
			[Ship Mode],
			[Order List],
			[Stock QTY (at PO Create Date)],
			[PR Comments],
			[MR Comments],
			[Buy Back],
			[Still need to Production],
			[Brand],
			[Supplier RefNo],
			[Supplier Color],
			[Remark],
			[In the name of],
			[For Other Brand],
			[Eco thread SP#],
			[without create M (for Eco RefNo)],
			[Not output yet (for Eco RefNo)],
		    [Supplier Group],
		    [Supplier Delivery],
		    [Material],
            [Mtl. Complete],
			[Is 3rd Country],
			[TransferBIDate],
			[GMT complete],
			[Last Buyer Delivery],
			[Prod Item],
			[Order Cancel],
			[Mtl. O.Standing Reason],
            [KPI L/ETA (Order List)],
			[Print Date],
			[Default del. by L/T],
			[Sup. del. Planning],
			[FTY L/ETA],
			[Packing LETA]
		)
		Values ( 
			s.[Factory] ,
			s.[Country of Destination] ,
			s.[Country of Loading],
			s.[Country of Loading (Original)],
			s.[Supplier],
			s.[Supplier Name],
			s.[PINo Need],
			s.[Est. Supplier Del.],
			s.[Sup.Del. 1st cfm],
			s.[Sup.Del Rvsd],
			s.[SP#],
			s.[Category],
			s.[SMR],
			s.[MR],
			s.[PC Handle],
			s.[PO Handle],
			s.[PO SMR],
			s.[Style],
			s.[Program],
			s.[Seq1],
			s.[Seq2],
			s.[Ref#],
			s.[Brand Ref#],
			s.[OrderType],
			s.[Price],
			s.[Currency],
			s.[Unit],
			s.[Purchase Qty],
			s.[Ship Qty],
			s.[Balance Qty],
			s.[Purchase FOC Qty],
			s.[Ship FOC Qty],
			s.[Balance FOC Qty],
			s.[Use Qty],
			s.[Loss Qty],
			s.[Amount(USD)],
			s.[In-Line Date],
			s.[Season],
			s.[PI#],
			s.[Size],
			s.[S/Unit],
			s.[Color ID],
			s.[Color Desc],
			s.[Actual ETA],
			s.[PONo],
			s.[KPI L/ETA],
			s.[Shipping Schedule],
			s.[Estimate ETA],
			s.[SCI Delivery],
			s.[Buyer Delivery],
			s.[CRD Date],
			s.[Partial Shipment],
			s.[Order Q’ty],
			s.[CustCD],
			s.[Supplier Over Shipping Qty],
			s.[Supplier over shipping Qty %],
			s.[Input Qty],
			s.[Adject Qty],
			s.[Lead Time],
			s.[Order cfm Date],
			s.[CPU],
			s.[Spec],
			s.[Special],
			s.[Long L/T Reason],
			s.[WK#],
			s.[Complete],
			s.[Stock C],
			s.[Shipping Mark],
			s.[ECFA],
			s.[ECFA Duty],
			s.[Import Duty],
			s.[P/I Date],
			s.[Materila Type],
			s.[Ship Mode],
			s.[Order List],
			s.[Stock QTY (at PO Create Date)],
			s.[PR Comments],
			s.[MR Comments],
			s.[Buy Back],
			s.[Still need to Production],
			s.[Brand],
			s.[Supplier RefNo],
			s.[Supplier Color],
			s.[Remark],
			s.[In the name of],
			s.[For Other Brand],
			s.[Eco thread SP#],
			s.[without create M (for Eco RefNo)],
			s.[Not output yet (for Eco RefNo)],
		    s.[Supplier Group],
		    s.[Supplier Delivery],
		    s.[Material],
            s.[Mtl. Complete],
			s.[Is 3rd Country],
			s.[TransferBIDate],
			s.[GMT complete],
			s.[Last Buyer Delivery],
			s.[Prod Item],
			s.[Order Cancel],
			s.[Mtl. O.Standing Reason],
            s.[KPI L/ETA (Order List)],
			s.[Print Date],
			s.[Default del. by L/T],
			s.[Sup. del. Planning],
			s.[FTY L/ETA],
			S.[Packing LETA]
		)
	WHEN MATCHED THEN
		UPDATE SET 
		t.[Factory]  = s.[Factory] ,
		t.[Country of Destination]  = s.[Country of Destination] ,
		t.[Country of Loading] = s.[Country of Loading],
		t.[Country of Loading (Original)] = s.[Country of Loading (Original)],
		t.[Supplier] = s.[Supplier],
		t.[Supplier Name] = s.[Supplier Name],
		t.[PINo Need] = s.[PINo Need],
		t.[Est. Supplier Del.] = s.[Est. Supplier Del.],
		t.[Sup.Del. 1st cfm] = s.[Sup.Del. 1st cfm],
		t.[Sup.Del Rvsd] = s.[Sup.Del Rvsd],
		t.[Category] = s.[Category],
		t.[SMR] = s.[SMR],
		t.[MR] = s.[MR],
		t.[PC Handle] = s.[PC Handle],
		t.[PO Handle] = s.[PO Handle],
		t.[PO SMR] = s.[PO SMR],
		t.[Style] = s.[Style],
		t.[Program] = s.[Program],
		t.[Ref#] = s.[Ref#],
		t.[Brand Ref#] = s.[Brand Ref#],
		t.[OrderType] = s.[OrderType],
		t.[Price] = s.[Price],
		t.[Currency] = s.[Currency],
		t.[Unit] = s.[Unit],
		t.[Purchase Qty] = s.[Purchase Qty],
		t.[Ship Qty] = s.[Ship Qty],
		t.[Balance Qty] = s.[Balance Qty],
		t.[Purchase FOC Qty] = s.[Purchase FOC Qty],
		t.[Ship FOC Qty] = s.[Ship FOC Qty],
		t.[Balance FOC Qty] = s.[Balance FOC Qty],
		t.[Use Qty] = s.[Use Qty],
		t.[Loss Qty] = s.[Loss Qty],
		t.[Amount(USD)] = s.[Amount(USD)],
		t.[In-Line Date] = s.[In-Line Date],
		t.[Season] = s.[Season],
		t.[PI#] = s.[PI#],
		t.[Size] = s.[Size],
		t.[S/Unit] = s.[S/Unit],
		t.[Color ID] = s.[Color ID],
		t.[Color Desc] = s.[Color Desc],
		t.[Actual ETA] = s.[Actual ETA],
		t.[PONo] = s.[PONo],
		t.[KPI L/ETA] = s.[KPI L/ETA],
		t.[Shipping Schedule] = s.[Shipping Schedule],
		t.[Estimate ETA] = s.[Estimate ETA],
		t.[SCI Delivery] = s.[SCI Delivery],
		t.[Buyer Delivery] = s.[Buyer Delivery],
		t.[CRD Date] = s.[CRD Date],
		t.[Partial Shipment] = s.[Partial Shipment],
		t.[Order Q’ty] = s.[Order Q’ty],
		t.[CustCD] = s.[CustCD],
		t.[Supplier Over Shipping Qty] = s.[Supplier Over Shipping Qty],
		t.[Supplier over shipping Qty %] = s.[Supplier over shipping Qty %],
		t.[Input Qty] = s.[Input Qty],
		t.[Adject Qty] = s.[Adject Qty],
		t.[Lead Time] = s.[Lead Time],
		t.[Order cfm Date] = s.[Order cfm Date],
		t.[CPU] = s.[CPU],
		t.[Spec] = s.[Spec],
		t.[Special] = s.[Special],
		t.[Long L/T Reason] = s.[Long L/T Reason],
		t.[WK#] = s.[WK#],
		t.[Complete] = s.[Complete],
		t.[Stock C] = s.[Stock C],
		t.[Shipping Mark] = s.[Shipping Mark],
		t.[ECFA] = s.[ECFA],
		t.[ECFA Duty] = s.[ECFA Duty],
		t.[Import Duty] = s.[Import Duty],
		t.[P/I Date] = s.[P/I Date],
		t.[Materila Type] = s.[Materila Type],
		t.[Ship Mode] = s.[Ship Mode],
		t.[Order List] = s.[Order List],
		t.[Stock QTY (at PO Create Date)] = s.[Stock QTY (at PO Create Date)],
		t.[PR Comments] = s.[PR Comments],
		t.[MR Comments] = s.[MR Comments],
		t.[Buy Back] = s.[Buy Back],
		t.[Still need to Production] = s.[Still need to Production],
		t.[Brand] = s.[Brand],
		t.[Supplier RefNo] = s.[Supplier RefNo],
		t.[Supplier Color] = s.[Supplier Color],
		t.[Remark] = s.[Remark],
		t.[In the name of] = s.[In the name of],
		t.[For Other Brand] = s.[For Other Brand],
		t.[Eco thread SP#] = s.[Eco thread SP#],
		t.[without create M (for Eco RefNo)] = s.[without create M (for Eco RefNo)],
		t.[Not output yet (for Eco RefNo)] = s.[Not output yet (for Eco RefNo)],
		t.[Supplier Group] = s.[Supplier Group],
		t.[Supplier Delivery] = s.[Supplier Delivery],
		t.[Material] = s.[Material],
        t.[Mtl. Complete] = s.[Mtl. Complete],
		t.[Is 3rd Country] = s.[Is 3rd Country],
		t.[TransferBIDate] = s.[TransferBIDate],
		t.[GMT complete] = s.[GMT complete],
		t.[Last Buyer Delivery] = s.[Last Buyer Delivery],
		t.[Prod Item] = s.[Prod Item],
		t.[Order Cancel] = s.[Order Cancel],
		t.[Mtl. O.Standing Reason] = s.[Mtl. O.Standing Reason],
        t.[KPI L/ETA (Order List)] = s.[KPI L/ETA (Order List)],
		t.[Print Date] = s.[Print Date],
		t.[Default del. by L/T] = s.[Default del. by L/T],
		t.[Sup. del. Planning] = s.[Sup. del. Planning],
		t.[FTY L/ETA] = s.[FTY L/ETA],
		T.[Packing LETA] = S.[Packing LETA]
		;	
		Merge PBIReportData.dbo.T_PO3OrderList as t
		Using PBIReportData.dbo.T_PO3OrderList_tmp as s
			On s.ID = t.ID AND s.SEQ1 = t.SEQ1 AND s.SEQ2 = t.SEQ2 AND s.OrderID = t.OrderID
		When Not Matched By Target
			Then Insert (  
				[ID] ,
				[SEQ1] ,
				[SEQ2],
				[OrderID],
				[AddName],
				[AddDate],
				[EditName],
				[EditDate]
			)
			Values ( 
				s.[ID] ,
				s.[SEQ1] ,
				s.[SEQ2] ,
				s.[OrderID],
				s.[AddName],
				s.[AddDate],
				s.[EditName],
				s.[EditDate]
			)
		WHEN MATCHED THEN
			UPDATE SET 
			t.[EditName]  = s.[EditName] ,
			t.[EditDate]  = s.[EditDate] 
		;
		'

		EXEC (@ExecSQL) AT [PowerBI];

		DELETE p 
		FROM [POWERBI].PBIReportData.dbo.PurchaseList p
		Left JOIN Trade.dbo.PO_Supp_Detail p3
		on p.[SP#] = p3.ID and p.Seq1 = p3.Seq1 and p.Seq2 = p3.Seq2
		WHERE p3.Junk = 1 or p3.ID is null		

		DELETE p 
		FROM [POWERBI].PBIReportData.dbo.T_PO3OrderList p
		Left JOIN Trade.dbo.PO_Supp_Detail p3
		on p.ID = p3.ID and p.Seq1 = p3.Seq1 and p.Seq2 = p3.Seq2
		LEFT JOIN Trade.dbo.PO_Supp_Detail_OrderList p3o
		on p.ID = p3o.ID and p.Seq1 = p3o.Seq1 and p.Seq2 = p3o.Seq2 and p.OrderID = p3o.OrderID
		WHERE p3.Junk = 1 or p3.ID is null or p3o.ID is null	

		-- 同步更新新表(PurchaseList_2024)
		SET @ExecSQL ='
Merge PBIReportData.dbo.PurchaseList_2024 as t
	Using PBIReportData.dbo.PurchaseList_tmp as s
		On s.[SP#] = t.[SP#] AND s.SEQ1 = t.SEQ1 AND s.SEQ2 = t.SEQ2
	When Not Matched By Target
		Then Insert (  
			[Factory] ,
			[Country of Destination] ,
			[Country of Loading],
			[Country of Loading (Original)],
			[Supplier],
			[Supplier Name],
			[PINo Need],
			[Est. Supplier Del.],
			[Sup.Del. 1st cfm],
			[Sup.Del Rvsd],
			[SP#],
			[Category],
			[SMR],
			[MR],
			[PC Handle],
			[PO Handle],
			[PO SMR],
			[Style],
			[Program],
			[Seq1],
			[Seq2],
			[Ref#],
			[Brand Ref#],
			[OrderType],
			[Price],
			[Currency],
			[Unit],
			[Purchase Qty],
			[Ship Qty],
			[Balance Qty],
			[Purchase FOC Qty],
			[Ship FOC Qty],
			[Balance FOC Qty],
			[Use Qty],
			[Loss Qty],
			[Amount(USD)],
			[In-Line Date],
			[Season],
			[PI#],
			[Size],
			[S/Unit],
			[Color ID],
			[Color Desc],
			[Actual ETA],
			[PONo],
			[KPI L/ETA],
			[Shipping Schedule],
			[Estimate ETA],
			[SCI Delivery],
			[Buyer Delivery],
			[CRD Date],
			[Partial Shipment],
			[Order Q’ty],
			[CustCD],
			[Supplier Over Shipping Qty],
			[Supplier over shipping Qty %],
			[Input Qty],
			[Adject Qty],
			[Lead Time],
			[Order cfm Date],
			[CPU],
			[Special],
			[Long L/T Reason],
			[WK#],
			[Complete],
			[Stock C],
			[Shipping Mark],
			[ECFA],
			[ECFA Duty],
			[Import Duty],
			[P/I Date],
			[Materila Type],
			[Ship Mode],
			[Order List],
			[Stock QTY (at PO Create Date)],
			[Buy Back],
			[Still need to Production],
			[Brand],
			[Supplier RefNo],
			[Supplier Color],
			[In the name of],
			[For Other Brand],
			[Eco thread SP#],
			[without create M (for Eco RefNo)],
			[Not output yet (for Eco RefNo)],
		    [Supplier Group],
		    [Supplier Delivery],
		    [Material],
            [Mtl. Complete],
			[Is 3rd Country],
			[TransferBIDate],
			[GMT complete],
			[Last Buyer Delivery],
			[Prod Item],
			[Order Cancel],
			[Mtl. O.Standing Reason],
            [KPI L/ETA (Order List)],
			[Print Date],
			[Default del. by L/T],
			[Sup. del. Planning],
			[FTY L/ETA],
			[Packing LETA]
		)
		Values ( 
			s.[Factory] ,
			s.[Country of Destination] ,
			s.[Country of Loading],
			s.[Country of Loading (Original)],
			s.[Supplier],
			s.[Supplier Name],
			s.[PINo Need],
			s.[Est. Supplier Del.],
			s.[Sup.Del. 1st cfm],
			s.[Sup.Del Rvsd],
			s.[SP#],
			s.[Category],
			s.[SMR],
			s.[MR],
			s.[PC Handle],
			s.[PO Handle],
			s.[PO SMR],
			s.[Style],
			s.[Program],
			s.[Seq1],
			s.[Seq2],
			s.[Ref#],
			s.[Brand Ref#],
			s.[OrderType],
			s.[Price],
			s.[Currency],
			s.[Unit],
			s.[Purchase Qty],
			s.[Ship Qty],
			s.[Balance Qty],
			s.[Purchase FOC Qty],
			s.[Ship FOC Qty],
			s.[Balance FOC Qty],
			s.[Use Qty],
			s.[Loss Qty],
			s.[Amount(USD)],
			s.[In-Line Date],
			s.[Season],
			s.[PI#],
			s.[Size],
			s.[S/Unit],
			s.[Color ID],
			s.[Color Desc],
			s.[Actual ETA],
			s.[PONo],
			s.[KPI L/ETA],
			s.[Shipping Schedule],
			s.[Estimate ETA],
			s.[SCI Delivery],
			s.[Buyer Delivery],
			s.[CRD Date],
			s.[Partial Shipment],
			s.[Order Q’ty],
			s.[CustCD],
			s.[Supplier Over Shipping Qty],
			s.[Supplier over shipping Qty %],
			s.[Input Qty],
			s.[Adject Qty],
			s.[Lead Time],
			s.[Order cfm Date],
			s.[CPU],
			s.[Special],
			s.[Long L/T Reason],
			s.[WK#],
			s.[Complete],
			s.[Stock C],
			s.[Shipping Mark],
			s.[ECFA],
			s.[ECFA Duty],
			s.[Import Duty],
			s.[P/I Date],
			s.[Materila Type],
			s.[Ship Mode],
			s.[Order List],
			s.[Stock QTY (at PO Create Date)],
			s.[Buy Back],
			s.[Still need to Production],
			s.[Brand],
			s.[Supplier RefNo],
			s.[Supplier Color],
			s.[In the name of],
			s.[For Other Brand],
			s.[Eco thread SP#],
			s.[without create M (for Eco RefNo)],
			s.[Not output yet (for Eco RefNo)],
		    s.[Supplier Group],
		    s.[Supplier Delivery],
		    s.[Material],
            s.[Mtl. Complete],
			s.[Is 3rd Country],
			s.[TransferBIDate],
			s.[GMT complete],
			s.[Last Buyer Delivery],
			s.[Prod Item],
			s.[Order Cancel],
			s.[Mtl. O.Standing Reason],
            s.[KPI L/ETA (Order List)],
			s.[Print Date],
			s.[Default del. by L/T],
			s.[Sup. del. Planning],
			s.[FTY L/ETA],
			s.[Packing LETA]
		)
	WHEN MATCHED THEN
		UPDATE SET 
		t.[Factory]  = s.[Factory] ,
		t.[Country of Destination]  = s.[Country of Destination] ,
		t.[Country of Loading] = s.[Country of Loading],
		t.[Country of Loading (Original)] = s.[Country of Loading (Original)],
		t.[Supplier] = s.[Supplier],
		t.[Supplier Name] = s.[Supplier Name],
		t.[PINo Need] = s.[PINo Need],
		t.[Est. Supplier Del.] = s.[Est. Supplier Del.],
		t.[Sup.Del. 1st cfm] = s.[Sup.Del. 1st cfm],
		t.[Sup.Del Rvsd] = s.[Sup.Del Rvsd],
		t.[Category] = s.[Category],
		t.[SMR] = s.[SMR],
		t.[MR] = s.[MR],
		t.[PC Handle] = s.[PC Handle],
		t.[PO Handle] = s.[PO Handle],
		t.[PO SMR] = s.[PO SMR],
		t.[Style] = s.[Style],
		t.[Program] = s.[Program],
		t.[Ref#] = s.[Ref#],
		t.[Brand Ref#] = s.[Brand Ref#],
		t.[OrderType] = s.[OrderType],
		t.[Price] = s.[Price],
		t.[Currency] = s.[Currency],
		t.[Unit] = s.[Unit],
		t.[Purchase Qty] = s.[Purchase Qty],
		t.[Ship Qty] = s.[Ship Qty],
		t.[Balance Qty] = s.[Balance Qty],
		t.[Purchase FOC Qty] = s.[Purchase FOC Qty],
		t.[Ship FOC Qty] = s.[Ship FOC Qty],
		t.[Balance FOC Qty] = s.[Balance FOC Qty],
		t.[Use Qty] = s.[Use Qty],
		t.[Loss Qty] = s.[Loss Qty],
		t.[Amount(USD)] = s.[Amount(USD)],
		t.[In-Line Date] = s.[In-Line Date],
		t.[Season] = s.[Season],
		t.[PI#] = s.[PI#],
		t.[Size] = s.[Size],
		t.[S/Unit] = s.[S/Unit],
		t.[Color ID] = s.[Color ID],
		t.[Color Desc] = s.[Color Desc],
		t.[Actual ETA] = s.[Actual ETA],
		t.[PONo] = s.[PONo],
		t.[KPI L/ETA] = s.[KPI L/ETA],
		t.[Shipping Schedule] = s.[Shipping Schedule],
		t.[Estimate ETA] = s.[Estimate ETA],
		t.[SCI Delivery] = s.[SCI Delivery],
		t.[Buyer Delivery] = s.[Buyer Delivery],
		t.[CRD Date] = s.[CRD Date],
		t.[Partial Shipment] = s.[Partial Shipment],
		t.[Order Q’ty] = s.[Order Q’ty],
		t.[CustCD] = s.[CustCD],
		t.[Supplier Over Shipping Qty] = s.[Supplier Over Shipping Qty],
		t.[Supplier over shipping Qty %] = s.[Supplier over shipping Qty %],
		t.[Input Qty] = s.[Input Qty],
		t.[Adject Qty] = s.[Adject Qty],
		t.[Lead Time] = s.[Lead Time],
		t.[Order cfm Date] = s.[Order cfm Date],
		t.[CPU] = s.[CPU],
		t.[Special] = s.[Special],
		t.[Long L/T Reason] = s.[Long L/T Reason],
		t.[WK#] = s.[WK#],
		t.[Complete] = s.[Complete],
		t.[Stock C] = s.[Stock C],
		t.[Shipping Mark] = s.[Shipping Mark],
		t.[ECFA] = s.[ECFA],
		t.[ECFA Duty] = s.[ECFA Duty],
		t.[Import Duty] = s.[Import Duty],
		t.[P/I Date] = s.[P/I Date],
		t.[Materila Type] = s.[Materila Type],
		t.[Ship Mode] = s.[Ship Mode],
		t.[Order List] = s.[Order List],
		t.[Stock QTY (at PO Create Date)] = s.[Stock QTY (at PO Create Date)],
		t.[Buy Back] = s.[Buy Back],
		t.[Still need to Production] = s.[Still need to Production],
		t.[Brand] = s.[Brand],
		t.[Supplier RefNo] = s.[Supplier RefNo],
		t.[Supplier Color] = s.[Supplier Color],
		t.[In the name of] = s.[In the name of],
		t.[For Other Brand] = s.[For Other Brand],
		t.[Eco thread SP#] = s.[Eco thread SP#],
		t.[without create M (for Eco RefNo)] = s.[without create M (for Eco RefNo)],
		t.[Not output yet (for Eco RefNo)] = s.[Not output yet (for Eco RefNo)],
		t.[Supplier Group] = s.[Supplier Group],
		t.[Supplier Delivery] = s.[Supplier Delivery],
		t.[Material] = s.[Material],
        t.[Mtl. Complete] = s.[Mtl. Complete],
		t.[Is 3rd Country] = s.[Is 3rd Country],
		t.[TransferBIDate] = s.[TransferBIDate],
		t.[GMT complete] = s.[GMT complete],
		t.[Last Buyer Delivery] = s.[Last Buyer Delivery],
		t.[Prod Item] = s.[Prod Item],
		t.[Order Cancel] = s.[Order Cancel],
		t.[Mtl. O.Standing Reason] = s.[Mtl. O.Standing Reason],
        t.[KPI L/ETA (Order List)] = s.[KPI L/ETA (Order List)],
		t.[Print Date] = s.[Print Date],
		t.[Default del. by L/T] = s.[Default del. by L/T],
		t.[Sup. del. Planning] = s.[Sup. del. Planning],
		t.[FTY L/ETA] = s.[FTY L/ETA],
		t.[Packing LETA] = s.[Packing LETA]
		;
		'

		EXEC (@ExecSQL) AT [PowerBI];

		DELETE p 
		FROM [POWERBI].PBIReportData.dbo.PurchaseList_2024 p
		Left JOIN Trade.dbo.PO_Supp_Detail p3
		on p.[SP#] = p3.ID and p.Seq1 = p3.Seq1 and p.Seq2 = p3.Seq2
		WHERE p3.Junk = 1 or p3.ID is null		

		SET @ExecSQL = '
		if Exists(select 1 FROM PBIReportData.dbo.BITableInfo where id=''PurchaseList'')
		BEGIN
			UPDATE PBIReportData.dbo.BITableInfo SET TransferDate = GETDATE() WHERE ID = ''PurchaseList''
		END
		ELSE
		BEGIN
			INSERT INTO PBIReportData.dbo.BITableInfo (ID, TransferDate) VALUES (''PurchaseList'', getdate())
		END
		
		if Exists(select 1 FROM PBIReportData.dbo.BITableInfo where id=''PurchaseList_2024'')
		BEGIN
			UPDATE PBIReportData.dbo.BITableInfo SET TransferDate = GETDATE() WHERE ID = ''PurchaseList_2024''
		END
		ELSE
		BEGIN
			INSERT INTO PBIReportData.dbo.BITableInfo (ID, TransferDate) VALUES (''PurchaseList_2024'', getdate())
		END';
		EXECUTE (@ExecSQL) AT [PowerBI];
End

Go


