SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Vicky
-- Create date: 2022/12/05
-- Description:	找GetSupDelTarget資訊
-- =============================================
If Object_Id ( 'dbo.GetSupDelTarget' ) Is Not Null
Begin
    Drop function dbo.GetSupDelTarget;
End;
Go

Create FUNCTION [dbo].GetSupDelTarget
(	
	 @ID varchar(13)
	 , @Seq1 varchar(3)
	 , @Seq2 varchar (2)
	 , @TargetLETA DATE
)
RETURNS @TmpSupDelTarget TABLE
(
	SupDelTarget Date
	, SupDelTargetETA Date
)
AS
BEGIN
	declare @LoadDate date;
	declare @ETA date;
	declare @SystemETD date;
	declare @BeforeShip int = 1 -- 設定往前幾班船 (Target L/ETA被押上時, 往前推一班船)

	declare @PlanningETD_SpecialRule bit = 0
	declare @PlanningETD_AdditionalLTDays int = 0
	declare @MinBuyerDelivery date
	declare @TempDate date
	declare @KPIHolidayCnt int = 0
	declare @Category varchar(1)

	select @PlanningETD_SpecialRule = b.PlanningETD_SpecialRule
	, @PlanningETD_AdditionalLTDays = b.PlanningETD_AdditionalLTDays
	, @Category = o.Category
	from dbo.Orders o
	join dbo.Brand b on o.BrandID = b.ID
	where o.ID = @ID

	-- Sup. Del Planning
	if @Category = 'B' and @PlanningETD_SpecialRule = 1 and @TargetLETA is null
	begin
		if exists (select 1 from dbo.PO_Supp_Detail_OrderList where id = @ID and SEQ1 = @Seq1 and SEQ2 = @Seq2)
		begin
			select @MinBuyerDelivery = min(o.BuyerDelivery)
			from dbo.PO_Supp_Detail_OrderList po4
			join dbo.Orders o on po4.OrderID = o.ID and o.Category != 'S' and o.Junk = 0
			where po4.id = @ID and po4.SEQ1 = @Seq1 and po4.SEQ2 = @Seq2
		end
		else
		begin
			select @MinBuyerDelivery = min(o.BuyerDelivery)
			from dbo.Orders o
			where o.POID = @ID and o.Category != 'S' and o.Junk = 0
		end

		set @TempDate = DATEADD(DAY, - @PlanningETD_AdditionalLTDays, @MinBuyerDelivery)

		select @KPIHolidayCnt = dbo.GetKPIHolidayCnt(f.CountryID, f.ID, @TempDate, @MinBuyerDelivery)
		from dbo.Orders o
		join dbo.Factory f on o.FactoryID = f.ID
		where o.ID = @ID

		set @ETA = DATEADD(DAY, - @KPIHolidayCnt, @TempDate)

		select @LoadDate = getSchedule.LoadDate
		from dbo.po_Supp_Detail as po3 with(nolock)
		outer apply (
			select poid = iif( @seq1 like '7%' ,po3.StockPOID, po3.ID)
			, Seq1 = iif( @seq1 like '7%' ,po3.StockSeq1, po3.Seq1)
			, Seq2 = iif( @seq1 like '7%' ,po3.StockSeq2, po3.Seq2)
		) transPO
		left join dbo.po_Supp_Detail as real_PO3 with(nolock) on real_PO3.ID = transPO.poid and real_PO3.Seq1 = transPO.Seq1 and real_PO3.Seq2 = transPO.Seq2
		left join dbo.PO_Supp as po2 with(nolock) on po2.ID = transPO.poid and po2.Seq1 = transPO.Seq1
		inner join dbo.Orders o with(nolock) on po2.ID = o.ID
		cross apply (select ShipModeGroup from ShipMode sm with(nolock) where sm.id = real_PO3.ShipModeID) sm
		left join dbo.Supp_Port pdSupp with(nolock) on po2.SuppID = pdSupp.ID and sm.ShipModeGroup = pdSupp.ShipModeGroup
		left join dbo.Factory_Port pdFty with(nolock) on o.FactoryID = pdFty.ID and sm.ShipModeGroup = pdFty.ShipModeGroup
		Outer Apply (
			select top 1 s.LoadDate
			from Trade.dbo.ScheduleGroup as sg with (nolock)
			inner join Trade.dbo.Schedule as s with (nolock) on s.ScheduleGroupID = sg.ID			
			where sg.ExportPort = pdSupp.PortID and sg.ImportPort = pdFty.PortID and sg.ShipModeID = real_PO3.ShipModeID
			and Trade.dbo.FilterSchedule(sg.FilterShipTerm, sg.filterSupplier, sg.FilterFactory, po2.ShipTermID, po2.SuppID, o.FactoryID) = 1
			and s.Eta <= @ETA and s.junk = 0 and s.Second = 0 and s.OnTime = 0
			order by s.LoadDate Desc
		) getSchedule
		where po3.ID = @ID and po3.Seq1 = @Seq1 and po3.Seq2 = @Seq2
	end
	else
	begin
		if @TargetLETA is null
		begin
			set @BeforeShip = 3 -- Target L/ETA未被押上時, 往前推三班船
			set @TargetLETA = dbo.GetRequestETA(@ID)
		end

		select top 1 @SystemETD = getSystemETD.SystemETD
		, @LoadDate = foreSchedule.LoadDate
		, @ETA = foreSchedule.Eta
		from dbo.po_Supp_Detail as tmp
		outer apply (
			select poid = iif( @Seq1 like '7%' ,tmp.StockPOID, @ID)
			, Seq1 = iif( @Seq1 like '7%' ,tmp.StockSeq1, @Seq1)
			, Seq2 = iif( @Seq1 like '7%' ,tmp.StockSeq2, @Seq2)
		) as transPO
		left join dbo.po_Supp_Detail as real_PO3 with (nolock) on real_PO3.ID = transPO.poid and real_PO3.Seq1 = transPO.Seq1 and real_PO3.Seq2 = transPO.Seq2
		Outer apply dbo.GetPo3Spec(real_PO3.ID, real_PO3.Seq1, real_PO3.Seq2) po3Spec
		left join dbo.PO_Supp as po2 with (nolock) on  po2.ID = transPO.poid and po2.Seq1 = transPO.Seq1
		left join dbo.Orders as o with (nolock) on  o.ID = transPO.poid
		left join dbo.Supp with (nolock) on Supp.ID = po2.SuppID
		left join dbo.Factory with (nolock) on Factory.ID = o.FactoryID
		left join dbo.Fabric_Supp fs with (nolock) on real_PO3.SCIRefNo = fs.SCIRefno and po2.SuppID = fs.SuppID
		OUTER APPLY (Select SystemETD = dbo.GetDefaultDelDate(real_PO3.SciRefNo, o.Category, po2.SuppID, o.StyleID, o.BrandID, o.SeasonID, Factory.CountryID, o.OrderTypeID, po3Spec.Color, o.SystemETD_AdditionalDays, o.CfmDate))getSystemETD
		outer apply (
			select SuppPort = dbo.GetPortBySupp(real_PO3.ShipModeID, Supp.ID)
			, FtyPort = dbo.GetPortByFactory(real_PO3.ShipModeID,Factory.ID)
		) as tmpPort
		outer apply (
			select ROW_NUMBER() OVER (ORDER BY iif(s.CYCFS = 'CFS', 1, 2), s.LoadDate desc) AS RowNum, s.*
			from dbo.ScheduleGroup as sg with (nolock)
			inner join dbo.Schedule as s with (nolock) on s.ScheduleGroupID = sg.ID			
			where sg.ExportPort = tmpPort.SuppPort and sg.ImportPort = tmpPort.FtyPort and sg.ShipModeID = real_PO3.ShipModeID
			and dbo.FilterSchedule( sg.FilterShipTerm ,sg.filterSupplier, sg.FilterFactory ,po2.ShipTermID ,po2.SuppID, o.FactoryID) = 1
			and s.Eta < @TargetLETA and s.Eta > o.CFMDate and s.junk = 0 and s.Second = 0 and s.OnTime = 0
		) as foreSchedule
		where tmp.ID = @ID and tmp.Seq1 = @Seq1 and tmp.Seq2 = @Seq2
		and foreSchedule.RowNum = @BeforeShip

		if @LoadDate < @SystemETD
		begin
			select top 1 @LoadDate = @SystemETD, @ETA = foreSchedule.Eta
			from dbo.po_Supp_Detail as tmp
			outer apply (
				select poid = iif( @Seq1 like '7%' ,tmp.StockPOID, @ID)
				, Seq1 = iif( @Seq1 like '7%' ,tmp.StockSeq1, @Seq1)
				, Seq2 = iif( @Seq1 like '7%' ,tmp.StockSeq2, @Seq2)
			) as transPO
			left join dbo.po_Supp_Detail as real_PO3 with (nolock) on real_PO3.ID = transPO.poid and real_PO3.Seq1 = transPO.Seq1 and real_PO3.Seq2 = transPO.Seq2
			Outer apply dbo.GetPo3Spec(real_PO3.ID, real_PO3.Seq1, real_PO3.Seq2) po3Spec
			left join dbo.PO_Supp as po2 with (nolock) on  po2.ID = transPO.poid and po2.Seq1 = transPO.Seq1
			left join dbo.Orders as o with (nolock) on  o.ID = transPO.poid
			left join dbo.Supp with (nolock) on Supp.ID = po2.SuppID
			left join dbo.Factory with (nolock) on Factory.ID = o.FactoryID
			left join dbo.Fabric_Supp fs with (nolock) on real_PO3.SCIRefNo = fs.SCIRefno and po2.SuppID = fs.SuppID
			OUTER APPLY (Select SystemETD = dbo.GetDefaultDelDate(real_PO3.SciRefNo, o.Category, po2.SuppID, o.StyleID, o.BrandID, o.SeasonID, Factory.CountryID, o.OrderTypeID, po3Spec.Color, o.SystemETD_AdditionalDays, o.CfmDate))getSystemETD
			outer apply (
				select SuppPort = dbo.GetPortBySupp(real_PO3.ShipModeID, Supp.ID)
				, FtyPort = dbo.GetPortByFactory(real_PO3.ShipModeID,Factory.ID)
			) as tmpPort
			outer apply (
				select s.*
				from dbo.ScheduleGroup as sg with (nolock)
				inner join dbo.Schedule as s with (nolock) on s.ScheduleGroupID = sg.ID			
				where sg.ExportPort = tmpPort.SuppPort and sg.ImportPort = tmpPort.FtyPort and sg.ShipModeID = real_PO3.ShipModeID
				and dbo.FilterSchedule( sg.FilterShipTerm ,sg.filterSupplier, sg.FilterFactory ,po2.ShipTermID ,po2.SuppID, o.FactoryID) = 1
				and s.LoadDate >= @SystemETD and s.Eta > o.CFMDate and s.junk = 0 and s.Second = 0 and s.OnTime = 0
			) as foreSchedule
			where tmp.ID = @ID and tmp.Seq1 = @Seq1 and tmp.Seq2 = @Seq2
			order by iif(foreSchedule.CYCFS = 'CFS', 1, 2), foreSchedule.LoadDate
		end
	end

	insert into @TmpSupDelTarget (SupDelTarget, SupDelTargetETA)
	select @LoadDate, @ETA

	Return;
END
GO