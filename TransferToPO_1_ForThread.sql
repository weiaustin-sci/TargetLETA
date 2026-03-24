Use [Trade]
Go

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Edward
-- Create date: 2019/01/07
-- Description:
--		自動轉單 for Thread
-- =============================================
If Object_Id ( 'dbo.TransferToPO_1_ForThread', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_1_ForThread;
Go

Create Procedure [dbo].[TransferToPO_1_ForThread]
(
	  @PoID			VarChar(13)		--採購母單
	 ,@UserID		VarChar(10) = ''
)
As
Begin
	Set NoCount On;
	----------------------------------------------------------------------
	If Object_ID('tempdb..#tmpPO_Supp') Is Null
	Begin
		Create Table #tmpPO_Supp
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), SuppID VarChar(6) default '', ShipTermID VarChar(5) default '', PayTermAPID VarChar(5) default ''
			 , Remark NVarChar(Max) default '', Description NVarChar(Max) default '', CompanyID Numeric(2,0) default 0
			 , StyleID VarChar(15), TargetLETA Date, Junk Bit, Primary Key (ID, Seq1)
			);		
	End;
	If Object_ID('tempdb..#tmpPO_Supp_Detail') Is Null
	Begin
		Create Table #tmpPO_Supp_Detail
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), RefNo VarChar(36) default '', SCIRefNo VarChar(30) default ''
			 , FabricType VarChar(1) default '', Price Numeric(14,4) default 0, UsedQty Numeric(10,4) default 0, Qty Numeric(10,2) default 0
			 , POUnit VarChar(8) default '', Complete Bit default 0, SystemETD Date, CFMETD Date, RevisedETD Date, FinalETD Date, EstETA Date
			 , ShipModeID VarChar(10) default '', PrintDate DateTime, PINO VarChar(25) default '', PIDate Date
			 , ColorID VarChar(6) default '', SuppColor NVarChar(Max) default '', SizeSpec VarChar(15) default '', SizeUnit VarChar(8) default ''
			 , Remark NVarChar(Max) default '', Special NVarChar(Max) default '', Width Numeric(5, 2) default 0
			 , StockQty Numeric(12,1) default 0, NetQty Numeric(10,2) default 0, LossQty Numeric(10,2) default 0, SystemNetQty Numeric(10,2) default 0
			 , SystemCreate bit default 0, FOC Numeric(10,2) default 0, Junk bit default 0, ColorDetail NVarChar(Max) default ''
			 , BomZipperInsert VarChar(5) default '', BomCustPONo VarChar(30) default ''
			 , ShipQty Numeric(10,2) default 0, Shortage Numeric(10,2) default 0, ShipFOC Numeric(10,2) default 0, ApQty Numeric(10,2) default 0
			 , InputQty Numeric(10,2) default 0, OutputQty Numeric(10,2) default 0, Spec NVarChar(Max) default '', ShipETA Date, SystemLock Date
			 , OutputSeq1 VarChar(3) default '', OutputSeq2 VarChar(2) default '', FactoryID VarChar(8) default ''
			 , StockPOID VarChar(13) default '', StockSeq1 VarChar(3) default '', StockSeq2 VarChar(2) default '', InventoryUkey bigint default 0
			 , KeyWord NVarChar(Max) default '', Article varchar(8)
			 , Seq2_Count Int, Remark_Shell NVarChar(Max) default ''
			 , Status varchar(1), Sel bit default 0, IsForOtherBrand bit, CannotOperateStock bit, Keyword_Original varchar(max)
			 , Primary Key (ID, Seq1, Seq2, Seq2_Count)
			);
		Create Table #tmpPO_Supp_Detail_OrderList
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), OrderID VarChar(13), Seq2_Count Int
			 , Primary Key (ID, Seq1, Seq2, OrderID, Seq2_Count)
			);
		Create Table #tmpPO_Supp_Detail_Spec
		(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), SpecColumnID VarChar(50), SpecValue VarChar(50), Seq2_Count Int
			, Primary Key (ID, Seq1, Seq2, SpecColumnID, Seq2_Count)
		);
	End;

	Declare @tmpPo_SuppRowID Int;		--Row ID
	Declare @tmpPo_SuppRowCount Int;	--總資料筆數

	Declare @tmpPo_Supp_DetailRowID Int;	--Row ID
	Declare @tmpPo_Supp_DetailRowCount Int;	--總資料筆數

	Create Table #tmpFinal 
		( StyleID varchar(15), SuppID VarChar(6), Seq1 VarChar(3)
			, SCIRefNo VarChar(30) default '', ColorID Varchar(6), SuppColor NVarChar(Max) default ''
			, POQty Numeric(10,2), UsedQty Numeric(20,2), NetQty Numeric(20,2), LossQty Numeric(10,2)
			, UsageUnit varchar(8), POUnit varchar(8), MtltypeId varchar(20), Refno varchar(36), Type varchar(1)
			, MinQty Numeric(10,2), LimitUp Numeric(10,2), LossForOne bit default 0
		);

	Declare @ExecDate DateTime;
	Set @ExecDate = GetDate();

	Declare @Description NVarChar(Max);
	Declare @CompanyID Numeric(2,0);
	Declare @LockDate Date;
	Declare @ShipModeID VarChar(10);
	Declare @ShipTermID VarChar(5);
	Declare @PayTermAPID VarChar(5);
	Declare @SuppCountry VarCHar(2);
	Declare @FactoryCountry VarCHar(2);
	Declare @RefNo VarChar(36);
	Declare @Qty Numeric(10,2);
	Declare @NetQty Numeric(10,2);
	Declare @LossQty Numeric(10,2);
	Declare @POUnit VarChar(8);
	Declare @SizeSpec VarChar(15);
	Declare @SizeUnit VarChar(8);
	Declare @Width Numeric(5, 2);
	Declare @BomZipperInsert VarChar(5);
	Declare @BomCustPONo VarChar(30);
	Declare @Special NVarChar(Max);
	Declare @Spec NVarChar(Max);
	Declare @MtlLT Numeric(3,0);
	Declare @LTDay Numeric(1,0);
	Declare @StyleID VarChar(15);
	Declare @OrderTypeID VarChar(20)
	Declare @SystemETD Date;
	Declare @Price Numeric(14,4);
	Declare @tmpPrice Numeric(14,4);
	Declare @Fee Numeric(14,4);
	Declare @FeeUnit VarChar(8);
	Declare @StockQty Numeric(10,1);
	Declare @ProjectID VarChar(5);
	Declare @ProgramID VarChar(12);
	Declare @StyleProgramID VarChar(12);
	Declare @Remark NVarChar(Max);
	Declare @KeywordValue NVarChar(MAX) = ''
	Declare @SuppRefno Varchar(30);
	Declare @BrandRefNo varchar(50);
	Declare @BrandID VarChar(8);
	declare @StyleUkey bigint;
	Declare @SeasonID VarChar(10);
	Declare @FactoryID VarChar(8);
	Declare @FactoryKpiCode VarChar(8);
	Declare @Category VarChar(1);
	Declare @CfmDate Date;
	Declare @ThickFabric bit;
	Declare @UseRatioRule VarChar(1);
	Declare @FabricType VarChar(5);
	Declare @ThreadStatus VarChar(10);
	Declare @CountryID Varchar(2);
	Declare @Dest varchar(2);
	Declare @PoComboCount int;
	Declare @GSDType varchar(1);
	Declare @ThreadPlusLossRate Numeric(5,2);
	Declare @RefnoSpec dbo.Refno_Spec;
	Declare @OrderCompany Numeric(2,0);
	Declare @PurchaseCompany Numeric(2,0);
	Declare @CurrencyID VarChar(3);

	select
		@BrandID = BrandID,
		@StyleID = StyleID,
		@StyleUkey = StyleUkey,
		@SeasonID = SeasonID,
		@Category = Category,
		@CfmDate = CFMDate,
		@FactoryID = FactoryID,
		@FactoryKpiCode = Factory.KpiCode,
		@FactoryCountry = Factory.CountryID,
		@CountryID = Factory.CountryID,
		@Dest = Orders.Dest,
		@OrderTypeID = OrderTypeID,
		@ProgramID = ProgramID,
		@ProjectID = ProjectID,
		@ThreadPlusLossRate = isnull(ThreadPlusLossRate, 0),
		@OrderCompany = OrderCompany
	from dbo.Orders 
	inner join Trade.dbo.Factory on Orders.FactoryID = Factory.ID
	where Orders.id = @PoID

	IF @Category = 'A'
	Begin
		Declare @IdList Table (PoID VarChar(13))
		Insert into @IdList select POID from dbo.Orders where AllowanceComboID = @PoID
		
		Insert Into #tmpFinal
		(StyleID, SuppID, Seq1, SCIRefNo, ColorID, SuppColor, POQty, UsedQty, NetQty, LossQty, UsageUnit, POUnit, MtltypeId, Refno, Type, MinQty, LimitUp)
		select PO.StyleID
		, po2.SuppID
		, Seq1 = ''
		, po3.SCIRefNo
		, po3Spec.Color
		, po3.SuppColor
		, POQty = 0
		, UsedQty = AVG(po3.UsedQty)
		, NetQty = SUM(NetQty)
		, LossQty = 0
		, fb.UsageUnit
		, fs.POUnit
		, fb.MtltypeId
		, fb.Refno
		, fb.Type
		, ml.LimitDown
		, ll.LimitUp
		from PO
		inner join PO_Supp po2 on PO.ID = po2.ID
		inner join PO_Supp_Detail po3 on po2.ID = po3.ID and po2.SEQ1 = po3.Seq1
		outer apply dbo.GetPo3Spec(po3.ID, po3.Seq1, po3.Seq2) po3Spec
		inner join Trade.dbo.Fabric fb on fb.SCIRefno = po3.SCIRefNo
		inner join Trade.dbo.Fabric_Supp fs on fs.SCIRefno = po3.SCIRefNo and fs.SuppID = po2.SuppID
		outer apply (select top 1 LimitDown from Trade.dbo.MtlType_Limit ml where ml.Id = fb.MtlTypeID and ml.PoUnit = fs.POUnit) ml
		outer apply (select top 1 LimitUp from Trade.dbo.LossRateAccessory_Limit ll where ll.MtltypeId = fb.MtltypeId and ll.UsageUnit = fs.POUnit) ll
		where po2.ID in (select PoID from @IdList)
		and po2.SEQ1 like 'T%'		
		and fb.Junk = 0 and fs.Lock = 0 and fs.Junk = 0
		and (po3.Junk = 0
			or (po3.Junk = 1 and exists(select 1 from PO_Supp_Detail tmpPo3 where tmpPo3.ID = po3.ID and tmpPo3.OutputSeq1 = po3.Seq1 and tmpPo3.OutputSeq2 = po3.Seq2)))
		group by PO.StyleID, po2.SuppID, po3.SCIRefNo, po3Spec.Color, po3.SuppColor, fb.UsageUnit, fs.POUnit, fb.MtltypeId, fb.Refno, fb.Type, ml.LimitDown, ll.LimitUp

	End
	Else
	Begin
		select 
		@ThickFabric = Style.ThickFabricBulk,
		@FabricType = Style.FabricType,
		@ThreadStatus = Style.ThreadStatus,
		@GSDType = isnull(IETMS.GSDType, ''),
		@StyleProgramID = Style.ProgramID
		from Trade.dbo.Style
		left join Trade.dbo.IETMS on Style.IETMSID_Thread = IETMS.ID and Style.IETMSVersion_Thread = IETMS.Version
		where Style.Ukey = @StyleUkey

		if (@Category in ('B', 'M') and (@ThreadStatus != 'Locked' or @GSDType = 'C'))
		begin
			return;
		end

		--取得UseRatioRule，for MachineType_ThreadRatio_Regular 抓取的時候分類別抓取
		Set @UseRatioRule = Trade.dbo.GetRatioLevel(@StyleUkey, 0)

		/*
			Operation Thread Qty 依照Style_ThreadColorCombo Join Operation, MachineTypeID抓出SeamLength跟Machine UseRatio，再加上Allowance，
			每個Operation都需要算UseRatio跟Allowance所以會依照Operation發散
		*/
		select st.Ukey
        , st.MachineTypeID
		, std.Seq
		, OpThreadQty = sum((op.SeamLength * sto.Frequency * iif(op.Hem = 1 and mt.Hem = 1, Isnull(mtoh.UseRatio, 0), isnull(mtor.UseRatio, mto.UseRatio))) + (iif(op.Tubular = 1, mto.AllowanceTubular, mto.Allowance) * op.Segment))
        into #tmpOpThread
		from Trade.dbo.Style_ThreadColorCombo st
		inner join Trade.dbo.Style_ThreadColorCombo_Operation sto
			on st.Ukey = sto.Style_ThreadColorComboUkey
		OUTER APPLY (SELECT DISTINCT Seq from Trade.dbo.Style_ThreadColorCombo_Detail std WHERE st.Ukey = std.Style_ThreadColorComboUkey) std --抓出有使用到的Seq，排除Color欄位
		inner join Trade.dbo.Operation op
			on op.ID = sto.OperationID
		inner join Trade.dbo.MachineType mt
			on mt.ID = op.MachineTypeID
		inner join Trade.dbo.MachineType_ThreadRatio mto
			on mto.ID = st.MachineTypeID and mto.Seq = std.Seq
		left join Trade.dbo.MachineType_ThreadRatio_Regular mtor
			on mto.ID = mtor.ID and mto.Seq = mtor.Seq and mtor.UseRatioRule = @UseRatioRule
		left join Trade.dbo.MachineType_ThreadRatio_Hem mtoh
			on mto.ID = mtoh.ID and mto.Seq = mtoh.Seq and mtoh.UseRatioRule = @UseRatioRule
		where st.StyleUkey = @StyleUkey
	    group by st.Ukey, st.MachineTypeID, std.Seq

		select sum(Qty) Qty, SuppId, SCIRefNo, ColorID
		into #tmpTtlQty
		from (
			select supp.SuppId, SCIRefNo, ColorID, Qty
			from Trade.dbo.Style_ThreadColorCombo st
			left join Trade.dbo.Style_ThreadColorCombo_Detail std
			on st.Ukey = std.Style_ThreadColorComboUkey
			outer apply (
				select Order_Qty.Qty, Order_Qty.SizeCode, Order_Qty.ID
				from dbo.Order_Qty  
				inner join dbo.Orders o on Order_Qty.ID = o.ID
				where o.POID = @PoID and dbo.CheckOrder_CalculateMtlUsage(o.ID) = 1
				and Order_Qty.Article = std.Article
			) tmpQty
			Outer apply ( select SuppId = Trade.dbo.GetReplaceSupp_Thread(@BrandID, std.SuppID, @CountryID, @Dest, std.SCIRefno, @StyleUkey, @FactoryKpiCode, @FactoryID)) supp
			where StyleUkey = @StyleUkey
			and isnull(ColorID, '') != ''
			and isnull(tmpQty.Qty, 0) != 0
			and EXISTS(select 1 from Trade.dbo.MachineType_ThreadRatio mt where mt.ID = st.MachineTypeID and mt.Seq = std.Seq)
			group by supp.SuppId, SCIRefNo, ColorID, tmpQty.Qty, tmpQty.SizeCode, tmpQty.ID
		) tmp
		group by SuppId, SCIRefNo, ColorID

		--Group by SuppId, SCIRefNo, ColorID 算完NetQty
		Insert Into #tmpFinal
		(StyleID, SuppID, Seq1, SCIRefNo, ColorID, SuppColor, POQty, UsedQty, NetQty, LossQty, UsageUnit, POUnit, MtltypeId, Refno, Type, MinQty, LimitUp)
		select
			@StyleID
			, supp.SuppId
			, Seq1 = ''
			, std.SCIRefNo
			, std.ColorID
			, std.SuppColor
			, POQty = 0
			, UsedQty = round(sum(tot.OpThreadQty * OrderQty), 2)
			, NetQty = round(sum(tot.OpThreadQty * OrderQty), 2)
			, LossQty = 0
			, fb.UsageUnit
			, fs.POUnit
			, fb.MtltypeId
			, fb.Refno
			, fb.Type
			, ml.LimitDown
			, ll.LimitUp
		from #tmpOpThread tot
		inner join Trade.dbo.Style_ThreadColorCombo_Detail std
			on tot.Ukey = std.Style_ThreadColorComboUkey and tot.Seq = std.Seq
		inner join (
			select oq.Article, OrderQty = oq.Qty from dbo.Order_Qty oq 
			inner join dbo.Orders o on oq.ID = o.ID
			where o.POID = @PoID and dbo.CheckOrder_CalculateMtlUsage(o.ID) = 1) oq
			on oq.Article = std.Article
		Outer apply ( select SuppId = Trade.dbo.GetReplaceSupp_Thread(@BrandID, std.SuppID, @CountryID, @Dest, std.SCIRefno, @StyleUkey, @FactoryKpiCode, @FactoryID)) supp
		inner join Trade.dbo.Fabric fb on fb.SCIRefno = std.SCIRefNo
		inner join Trade.dbo.Fabric_Supp fs on fs.SCIRefno = std.SCIRefNo and fs.SuppID = supp.SuppID
		outer apply (select top 1 LimitDown from Trade.dbo.MtlType_Limit ml where ml.Id = fb.MtlTypeID and ml.PoUnit = fs.POUnit) ml
		outer apply (select top 1 LimitUp from Trade.dbo.LossRateAccessory_Limit ll where ll.MtltypeId = fb.MtltypeId and ll.UsageUnit = fs.POUnit) ll
		where isnull(std.ColorID, '') != ''		
			and fb.Junk = 0 and fs.Lock = 0 and fs.Junk = 0
			and EXISTS(select 1 from Trade.dbo.MachineType_ThreadRatio mt where mt.ID = tot.MachineTypeID and mt.Seq = tot.Seq)
		group by supp.SuppId, std.SCIRefNo, std.ColorID, std.SuppColor, fb.UsageUnit, fs.POUnit, fb.MtltypeId, fb.Refno, fb.Type, ml.LimitDown, ll.LimitUp

		--NetQty 單位換算 CM --> UsageUnit --> POUnit
		Update tmp 
			set NetQty = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(tmp.UsageUnit, tmp.POUnit, Trade.dbo.GetUnitQty('CM', tmp.UsageUnit, NetQty)), 0, 0)
			, UsedQty = Trade.dbo.GetUnitQty('CM', tmp.UsageUnit, UsedQty / NULLIF(getTtlQty.Qty, 0))
		from #tmpFinal tmp
		inner join Trade.dbo.Fabric fb
			on fb.SCIRefno = tmp.SCIRefNo
		inner join Trade.dbo.Fabric_Supp fs
			on fs.SCIRefno = tmp.SCIRefNo and fs.SuppID = tmp.SuppID
		inner join #tmpTtlQty getTtlQty
			on getTtlQty.SuppId = tmp.SuppId and getTtlQty.SCIRefNo = tmp.SCIRefNo and getTtlQty.ColorID = tmp.ColorID
	End
	
	IF @Category <> 'B' or (@Category = 'B' and @CfmDate < '2099-12-31') -- for [IST20191807] 在2019/11/25前成立的Bulk單仍須算LossQty
	Begin
		Update tmp set LossForOne = IIF((tmp.UsedQty / ttl.UsedQty) < 0, 1, 0) -- 原為 < 0.01 (暫不上線)
		from #tmpFinal tmp
		outer apply (select sum(UsedQty) UsedQty from #tmpFinal where StyleID = tmp.StyleID) ttl

		Update tmp set
			LossQty = IIF(LossForOne = 1, isnull(ta.Allowance_UserQtyBelowStandard, 3), Trade.dbo.GetCeiling(isnull(nl.netLoss, 0), 0, 0))
		from #tmpFinal tmp
		outer apply (select Data = 1 from Trade.dbo.ThreadCommon tc inner join Trade.dbo.ThreadCommon_Detail tcd on tc.Ukey = tcd.ThreadCommonUkey
					where tc.BrandID = @BrandID and tc.Refno = tmp.Refno and tc.ColorId = tmp.ColorID 
						and @CfmDate between tcd.StartDate and isnull(tcd.EndDate, cast('9999-12-31' as date))
				) tcd
		outer apply (select top 1 Allowance, Allowance_UserQtyBelowStandard from Trade.dbo.Thread_AllowanceScale ta where tmp.NetQty between ta.LowerBound and ta.UpperBound 
						and ta.Type = iif(tcd.Data = 1, 'C', 'N')) ta
		outer apply (select netLoss = isnull(tmp.NetQty, 0) * isnull(ta.Allowance, 0)) nl
	End
	
	Update tmp Set LossQty = IIF(getLoss.LossQty > LimitUp, LimitUp, getLoss.LossQty)
	from #tmpFinal tmp
	outer apply (select LossQty = IIF(@ThreadPlusLossRate = 0, LossQty, CEILING(LossQty * (1 + @ThreadPlusLossRate / 100)))) getLoss

	--POQty
	Update tmp
		set POQty = IIF(@Category = 'A', 0, NetQty) + LossQty
		  , NetQty = IIF(@Category = 'A', 0, NetQty)
	from #tmpFinal tmp

	--使用FULL JOIN判斷是否有新增/刪除採購項
	--當New不為空且Ori為空代表新增 或 當New不為空且Ori不為空且尚未上傳EDI => Status = 1
	--當New為空且Ori不為空代表刪除 => Status = 2 (Update Qty = 0)
	--當New不為空且Ori不為空且已上傳EDI代表更新 => Status = 3
	Declare @tmpResultRowID Int;	--Row ID
	Declare @tmpResultRowCount Int;	--總資料筆數
	Select DENSE_RANK() over(order by StyleID, SuppId, SCIRefNo, ColorID, SuppColor) RowID,*
	Into #tmpResult
	From (
		Select StyleID = isnull(Ori.StyleID, New.StyleID)
		, SuppId = isnull(Ori.SuppId, New.SuppId)
		, Seq1 = isnull(Ori.Seq1, '')
		, Seq2 = isnull(Ori.Seq2, '')
		, Refno = isnull(New.Refno, Ori.Refno)
		, SCIRefNo = isnull(New.SCIRefNo, Ori.SCIRefNo)
		, ColorID = isnull(New.ColorID, Ori.ColorID)
		, SuppColor = isnull(New.SuppColor, Ori.SuppColor)
		, POUnit = isnull(New.POUnit, Ori.POUnit)
		, Type = isnull(New.Type, Ori.FabricType)
		, NewQty = New.POQty
		, OriQty = isnull(Ori.Qty + isnull(Ori.OutputQty, 0), 0)
		, NewLossQty = New.LossQty
		, OriLossQty = isnull(Ori.LossQty, 0)
		, NewNetQty = New.NetQty
		, OriNetQty = isnull(Ori.NetQty, 0)
		, Status = IIF(New.SCIRefNo is not null and Ori.SCIRefNo is null, '1', IIF(New.SCIRefNo is null and Ori.SCIRefNo is not null, '2', IIF(TransEDI = 1,'3','1')))
		, TransEDI = isnull(TransEDI, 0)
		, MinQty = New.MinQty
		, LimitUp = New.LimitUp
		, LossForOne = isnull(New.LossForOne, 0)
		, OutputQty = isnull(Ori.OutputQty, 0)
		from
		(select * from #tmpFinal) New
		Full join 		
		(select po2.SuppId, isnull(po2.StyleID, @StyleID) StyleID, po3.*, TransEDI = Cast(IIF(trasEDI.c > 0 or IsOutput.c > 0, '1', '0') as bit),ColorID =  po3Spec.Color
		from PO_Supp po2
		inner join PO_Supp_Detail po3 on po2.ID = po3.ID and po2.Seq1 = po3.Seq1
		outer apply dbo.GetPo3Spec(po3.ID, po3.Seq1, po3.Seq2) po3Spec
		outer apply (select count(*) c from PO_Supp_Detail where ID = po3.ID and OutputSeq1 = po3.Seq1 and OutputSeq2 = po3.Seq2 and Junk = 0) IsOutput
		outer apply (select count(*) c from [EDIAP].GASA.dbo.PurchaseOrderList WITH (NOLOCK) where POID = po2.ID and Seq1 = po2.Seq1) trasEDI
		where po2.ID = @PoID
			And (@Category = 'A' or (@Category <> 'A' and po2.Seq1 like 'T%'))
			And (po3.Junk = 0 or (po3.Junk = 1 and IsOutput.c > 0 ))
		) Ori
		On New.SuppId = Ori.SuppId
		And New.SCIRefNo = Ori.SCIRefNo
		And New.ColorID = Ori.ColorID
		And New.SuppColor = Ori.SuppColor
		And New.StyleID = Ori.StyleID
	) a

	--將原本的PO_Supp寫入#tmpPO_Supp
	Insert Into #tmpPO_Supp	(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, StyleID, Junk)
	select ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, isnull(StyleID, @StyleID), isnull(getJunk.Junk, 1)
	from PO_Supp po2
	outer apply (select top 1 Junk from PO_Supp_Detail po3 where po3.ID = po2.ID and po3.Seq1 = po2.SEQ1 and po3.Junk = 0) getJunk
	where ID = @PoID And ((@Category = 'A') or (@Category <> 'A' and po2.Seq1 like 'T%'))

	Declare @SameSCIGroupRowID Int;
	Declare @SameSCIGroupRowCount Int;
	Declare @SuppID VarChar(6);
	Declare @Seq1 VarChar(3);
	Declare @Seq2 VarChar(2);
	Declare @SCIRefNo VarChar(30);
	Declare @ColorID Varchar(6);
	Declare @SuppColor NVarChar(Max);
	Declare @NewQty Numeric(10,2);
	Declare @OriQty Numeric(10,2);
	Declare @OriTtlQty Numeric(10,2);
	Declare @DiffQty Numeric(10,2);
	Declare @NewLossQty Numeric(10,2);
	Declare @OriLossQty Numeric(10,2);
	Declare @OriTtlLossQty Numeric(10,2);
	Declare @DiffLossQty Numeric(10,2);
	Declare @NewNetQty Numeric(10,2);
	Declare @OriNetQty Numeric(10,2);
	Declare @OriTtlNetQty Numeric(10,2);
	Declare @DiffNetQty Numeric(10,2);

	Declare @Status varchar(1);

	Declare @tmpSeq1 VarChar(3);
	Declare @transEDI bit = 0;
	Declare @LossForOne bit = 0;
	Declare @MinQty Numeric(10,2);
	Declare @LimitUp Numeric(10,2);
	Declare @POQty Numeric(10,2);
	Declare @OriPOQty Numeric(10,2);
	Declare @OutputQty Numeric(10,2);
	Declare @BalanceQty Numeric(10,2);

	Declare @MtltypeID varchar(20);

	--對新採購項(Seq1 = '')的資料預編Seq1	
	Set @tmpResultRowID = 1;
	Select @tmpResultRowID = Min(RowID), @tmpResultRowCount = Max(RowID) From #tmpResult;
	While @tmpResultRowID <= @tmpResultRowCount
	Begin
		Select @Seq1 = Seq1
		, @SuppID = SuppId
		, @StyleID = StyleID
		From #tmpResult Where RowID = @tmpResultRowID and Seq1 = ''

		If @@RowCount > 0
		Begin
			Select top 1 
			@Seq1 = isnull(Seq1, '')			
			, @transEDI = TransEDI
			From #tmpResult Where SuppId = @SuppID and StyleID = @StyleID and Seq1 != '' Order By Seq1

			IF @Seq1 = ''
			Begin
				Select @tmpSeq1 = IsNull(MAX(Replace(Seq1, 'T', '')), '0') From #tmpResult
				Set @Seq1 = IIF(@Category <> 'A', 'T' + cast(@tmpSeq1 + 1 as nvarchar), RIGHT(REPLICATE('0', 2) + CAST(@tmpSeq1 + 1 as nvarchar), 2))
			End

			Update #tmpResult Set Seq1 = @Seq1, TransEDI = @transEDI where RowID = @tmpResultRowID
		End

		set @tmpResultRowID += 1;
	End
	
	--Status 1:Insert 2:Update Qty = 0 3: Update Qty
	Create Table #SameSCIGroup 
		( RowID BigInt Identity(1,1) Not Null, StyleID varchar(15), SuppID VarChar(6),Seq1 VarChar(3), Seq2 VarChar(2)
			, SCIRefNo VarChar(30) default '', ColorID Varchar(6), SuppColor NVarChar(Max) default ''
			, NewQty Numeric(10,2), OriQty Numeric(10,2), NewLossQty Numeric(10,2), OriLossQty Numeric(10,2)
			, Status varchar(1), transEDI bit default 0, MinQty Numeric(10,2), LimitUp Numeric(10,2), LossForOne bit
			, NewNetQty Numeric(10,2), OriNetQty Numeric(10,2), OutputQty Numeric(10,2)
		);

	Set @tmpResultRowID = 1;
	Select @tmpResultRowID = Min(RowID), @tmpResultRowCount = Max(RowID) From #tmpResult;
	While @tmpResultRowID <= @tmpResultRowCount
	Begin
		truncate table #SameSCIGroup;

		Insert Into #SameSCIGroup
		(StyleID, SuppID, Seq1, Seq2, SCIRefNo, ColorID, SuppColor, NewQty, OriQty, NewLossQty, OriLossQty, Status, transEDI, MinQty, LimitUp, LossForOne, OutputQty
		,NewNetQty ,OriNetQty)
		Select StyleID, SuppID, Seq1, Seq2, SCIRefNo, ColorID, SuppColor, NewQty, OriQty, NewLossQty, OriLossQty, Status, transEDI, MinQty, LimitUp, LossForOne, OutputQty
		,NewNetQty, OriNetQty
		From #tmpResult
		Where RowID = @tmpResultRowID
		Order By Seq1 Desc

		Set @SameSCIGroupRowID = 1;
		Select @SameSCIGroupRowID = Min(RowID), @SameSCIGroupRowCount = Max(RowID) From #SameSCIGroup;

		IF @SameSCIGroupRowCount > 0
		Begin
			select @NewQty = NewQty, @NewNetQty = NewNetQty, @NewLossQty = NewLossQty, @LimitUp = LimitUp from #SameSCIGroup where RowID = @SameSCIGroupRowID
			select @OriTtlQty = sum(OriQty) from #SameSCIGroup

			set @DiffQty = @NewQty - @OriTtlQty
			
			select @OriTtlNetQty = sum(OriNetQty) from #SameSCIGroup
			set @DiffNetQty = @NewNetQty - @OriTtlNetQty
		
			select @OriTtlLossQty = sum(OriLossQty) from #SameSCIGroup
			set @DiffLossQty = iif(@NewLossQty > @LimitUp, @LimitUp, @NewLossQty) - @OriTtlLossQty
		End

		While @SameSCIGroupRowID <= @SameSCIGroupRowCount
		Begin
			Select @StyleID = StyleID
			, @SuppID = SuppID
			, @Seq1 = Seq1
			, @Seq2 = Seq2
			, @SCIRefNo = SCIRefNo
			, @ColorID = ColorID
			, @SuppColor = SuppColor
			, @NewQty = NewQty
			, @OriQty = OriQty
			, @NewLossQty = NewLossQty
			, @OriLossQty = OriLossQty
			, @NewNetQty = NewNetQty
			, @OriNetQty = OriNetQty
			, @Status = Status
			, @transEDI = transEDI
			, @Qty = isnull(OriQty, NewQty)
			, @NetQty = isnull(OriNetQty, NewNetQty)
			, @LossQty = isnull(OriLossQty, NewLossQty)
			, @MinQty = MinQty
			, @POQty = 0
			, @LossForOne = LossForOne
			, @OutputQty = OutputQty
			From #SameSCIGroup
			Where RowID = @SameSCIGroupRowID

			IF @Status = '3' --Update Qty
			Begin
				IF @DiffQty = 0
				Begin
					set @Status = 0
				End
				
				set @POQty = @OriQty - @OutputQty
				set @BalanceQty = @POQty + @OutputQty

				--POQty
				IF @DiffQty < 0
				Begin
					-- '將差異數填入於舊項次，預設不勾選，僅針對數量作更新'
					IF ABS(@DiffQty) > @OriQty
					Begin
						set @Qty = 0
						set @DiffQty = @DiffQty + @OriQty
					End
					Else
					Begin
						set @Qty = @OriQty + @DiffQty
						set @DiffQty = 0
					End
				End

				-- NetQty增加
				IF @DiffNetQty >= 0 or (@DiffQty <= 0 and @NewNetQty > @OriNetQty)
				Begin
					IF @BalanceQty >= @NewNetQty
					Begin
						set @NetQty = @NewNetQty
						set @DiffNetQty = 0
						set @BalanceQty -= @NewNetQty
					End
					Else
					Begin
						set @NetQty = @BalanceQty
						set @DiffNetQty -= (@BalanceQty - @OriNetQty)
						set @BalanceQty = 0
					End
				End

				-- NetQty減少
				IF @DiffNetQty < 0
				Begin
					IF ABS(@DiffNetQty) > @OriNetQty
					Begin
						set @NetQty = 0
						set @DiffNetQty = @DiffNetQty + @OriNetQty
					End
					Else
					Begin
						set @NetQty = @OriNetQty + @DiffNetQty
						set @DiffNetQty = 0
						set @BalanceQty -= @NetQty
					End
				End

				-- LossQty增加
				IF @DiffLossQty >= 0 or (@DiffQty <= 0 and @NewLossQty > @OriLossQty)
				Begin
					IF @OriLossQty > @NewLossQty
					Begin
						set @LossQty = @NewLossQty
						set @DiffLossQty = 0
					End
					Else
					Begin
						IF @BalanceQty >= @NewLossQty
						Begin
							set @LossQty = @NewLossQty
							set @DiffLossQty = 0
						End
						Else
						Begin
							set @LossQty = @BalanceQty
							set @DiffLossQty -= (@BalanceQty - @OriLossQty)
						End
					End
				End

				-- LossQty減少
				IF @DiffLossQty < 0
				Begin
					-- '將差異數填入於舊項次，預設不勾選，僅針對數量作更新'
					IF ABS(@DiffLossQty) > @OriLossQty
					Begin
						set @LossQty = 0
						set @DiffLossQty = @DiffLossQty + @OriLossQty
					End
					Else
					Begin
						IF @BalanceQty >= @OriLossQty + @DiffLossQty
						Begin
							set @LossQty = @OriLossQty + @DiffLossQty
							set @DiffLossQty = 0
						End
						Else
						Begin
							set @LossQty = @BalanceQty
							set @DiffLossQty = @OriLossQty + @DiffLossQty - @BalanceQty
						End
					End
				End
				
				--IF (@DiffQty) > 0
				--Begin
				--	set @Status = 0
				--End

				--IF @POQty > 0
				--Begin
					Insert Into #tmpPO_Supp_Detail
					(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
						, ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty, OutputQty
						, SizeSpec, Complete
						, Seq2_Count, Status
					)
					select @POID, @Seq1, @Seq2, Refno, tmp.SCIRefno, Type, tmpPrice.Price, UsedQty, @POQty, POUnit,
						RTrim(LTrim(tmp.ColorID)), tmp.SuppColor, '', @NetQty, @LossQty, @NetQty, @OutputQty,
						'', 0,
						0, --ROW_NUMBER() over(partition by Seq1 order by tmp.SCIRefno, tmp.ColorID, tmp.SuppColor),
						@Status
					from #tmpFinal tmp	
					outer apply (Select IsNull(Trade.dbo.GetPriceFromMtl(tmp.SCIRefno, tmp.SuppID, @SeasonID, POQty, @Category, @CfmDate, '', tmp.ColorID, @FactoryID), 0) as Price) as tmpPrice
					where StyleID = @StyleID and SuppId = @SuppID and SCIRefNo = @SCIRefNo and ColorID = @ColorID and SuppColor = @SuppColor
				--End

				IF @DiffQty > 0
				Begin
					-- '將差異數成立於新大項，且預設勾選轉出'
					set @Status = 1
					set @Seq2 = ''
					set @Qty = 0
					set @NetQty = 0
					set @LossQty = 0
				End
			End

			IF @Status = '1' --Insert
			Begin
			
				IF @DiffQty < 0 and ABS(@DiffQty) > @Qty
				Begin
					set @DiffQty += @Qty
					set @Qty = 0
				End
				Else
				Begin
					set @Qty += @DiffQty
					set @DiffQty = 0
				End
			
				IF @DiffNetQty < 0 and ABS(@DiffNetQty) > @NetQty
				Begin
					set @DiffNetQty += @NetQty
					set @NetQty = 0
				End
				Else
				Begin
					set @NetQty += @DiffNetQty
					set @DiffNetQty = 0
				End
				
				IF @DiffLossQty < 0 and ABS(@DiffLossQty) > @LossQty
				Begin
					set @DiffLossQty += @LossQty
					set @LossQty = 0
				End
				Else
				Begin
					set @LossQty += @DiffLossQty
					set @DiffLossQty = 0
				End

				IF	@transEDI = 1
				Begin
					Select top 1 @Seq1 = Seq1 from #tmpPO_Supp where ID = @PoID and Seq1 = @Seq1 and SuppID = @SuppID and StyleID = @StyleID order by Seq1 desc
					
					IF Len(@Seq1) > 2
						set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)
					Else
						set @Seq1 = @Seq1 + Char(65)					
				End

				While exists (select 1 from #tmpPO_Supp where Seq1 = @Seq1 and Junk = 1)
				Begin
					IF Len(@Seq1) > 2
						set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)					
					Else
						set @Seq1 = @Seq1 + Char(65)
				End

				IF not exists (select 1 from #tmpPO_Supp where ID = @PoID and Seq1 = @Seq1 and SuppID = @SuppID and StyleID = @StyleID)
				Begin
					Insert Into #tmpPO_Supp	(ID, Seq1, SuppID, StyleID)
					select @POID, @Seq1, @SuppID, @StyleID
				End

				IF @Seq2 = ''
				Begin
					Select @Seq2 = ISNULL(RIGHT(REPLICATE('0', 2) + CAST(MAX(Seq2) + 1 as nvarchar), 2), '01')
					from (
						Select Seq2
						From #tmpPO_Supp_Detail
						Where ID = @PoID and Seq1 = @Seq1

						Union

						Select Seq2
						From #tmpResult
						Where Seq1 = @Seq1
					) tmp
				End

				-- 紀錄原大項的採購數，若為0則表示非新展出的項次
				set @OriPOQty = @POQty
				--set @POQty = IIF(@Category = 'A', 0, @Qty) --+ @LossQty
				set @POQty = @Qty
				IF @Category <> 'B' and @POQty <> @OriQty and @MinQty > (@POQty + @OriPOQty) and @LossForOne = 0
				Begin
					set @POQty = @MinQty - @OriPOQty
				End				

				Insert Into #tmpPO_Supp_Detail
				(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
				 , ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty
				 , SizeSpec, Complete
				 , Seq2_Count
				 , Status, Sel, Junk
				)
				select @POID, @Seq1, @Seq2, Refno, tmp.SCIRefno, Type, tmpPrice.Price, UsedQty, @POQty, POUnit,
					RTrim(LTrim(tmp.ColorID)), tmp.SuppColor, '', isnull(@NetQty, tmp.NetQty), isnull(@LossQty, tmp.LossQty), isnull(@NetQty, tmp.NetQty),
					'', 0,
					0,--ROW_NUMBER() over(partition by Seq1 order by tmp.SCIRefno, tmp.ColorID, tmp.SuppColor),
					@Status, 1, IIF(@POQty = 0, 1, 0)
				from #tmpFinal tmp	
				outer apply (Select IsNull(Trade.dbo.GetPriceFromMtl(tmp.SCIRefno, tmp.SuppID, @SeasonID, POQty, @Category, @CfmDate, '', tmp.ColorID, @FactoryID), 0) as Price) as tmpPrice
				where StyleID = @StyleID and SuppId = @SuppID and SCIRefNo = @SCIRefNo and ColorID = @ColorID and SuppColor = @SuppColor
			End
			
			IF @Status = '2' --Delete => Update Qty = 0
			Begin

				If @transEDI = 1
				Begin
					set @POQty = @OriQty
				End

				Insert Into #tmpPO_Supp_Detail
				(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
					, ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty
					, SizeSpec, Complete
					, Seq2_Count, Status, Sel
				)
				select @POID, @Seq1, @Seq2, Refno, tmp.SCIRefno, Type, tmpPrice.Price, 0, @POQty, POUnit,
					RTrim(LTrim(tmp.ColorID)), tmp.SuppColor, '', 0, 0, 0,
					'', 0,
					0, --ROW_NUMBER() over(partition by Seq1 order by tmp.SCIRefno, tmp.ColorID, tmp.SuppColor),
					@Status, iif(@transEDI = 1, 0, 1)
				from #tmpResult tmp	
				outer apply (Select IsNull(Trade.dbo.GetPriceFromMtl(tmp.SCIRefno, tmp.SuppID, @SeasonID, 0, @Category, @CfmDate, '', tmp.ColorID, @FactoryID), 0) as Price) as tmpPrice
				where RowID = @tmpResultRowID
			End

			set @SameSCIGroupRowID += 1;
		End

		set @tmpResultRowID += 1;
	End

	Set @tmpPo_SuppRowID = 1;
	Select @tmpPo_SuppRowID = Min(RowID), @tmpPo_SuppRowCount = Max(RowID) From #tmpPO_Supp Where Seq1 in (Select Seq1 from #tmpResult);
	While @tmpPo_SuppRowID <= @tmpPo_SuppRowCount
	Begin
		Select @Seq1 = Seq1
			 , @SuppID = SuppID
			 , @Description = Description
		From #tmpPO_Supp
		Where RowID = @tmpPo_SuppRowID and Seq1 in (Select Seq1 from #tmpResult);
		
		Set @LockDate = Null;
		Select @ShipModeID = dbo.GetFactoryDefaultShip(@FactoryID, Supp.ID, @BrandID)
			 , @ShipTermID = newSt.ShipTermID
			 , @PayTermAPID = Trade.dbo.GetSuppPaymentTerm(@BrandID, @SuppID, @Category, @OrderCompany)
			 , @SuppCountry = Supp.CountryID
			 , @LockDate = Supp.LockDate
			 , @CurrencyID = supp.CurrencyID
		From Trade.dbo.Supp
		OUTER APPLY (select ShipTermID from dbo.GetReplaceSupp_ShipTerm(Supp.ID, @Category, @FactoryCountry, @FactoryID, @OrderCompany)) newSt
		Where ID = @SuppID;

		SET @CompanyID = Trade.dbo.GetPurchaseCompany('G', @Category, '', @OrderCompany, @FactoryCountry, @FactoryID, @SuppCountry, @ShipTermID, @CurrencyID, @SuppID)

		Set @ShipModeID = IIF(IsNull(@ShipModeID, '') = '', 'SEA', @ShipModeID); --若Supplier基本檔未設定ShipMode，預設為SEA
		If @LockDate Is Not Null	--已Lock不轉
		Begin
			Delete From #tmpPO_Supp Where ID = @PoID And Seq1 = @Seq1;
			Set @tmpPo_SuppRowID += 1;
			Continue;
		End;

		Set @tmpPo_Supp_DetailRowID = 1;
		Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From #tmpPO_Supp_Detail Where ID = @PoID And Seq1 = @Seq1;
		While @tmpPo_Supp_DetailRowID <= @tmpPo_Supp_DetailRowCount
		Begin
			Select @RefNo = RefNo
				 , @SciRefNo = SCIRefNo
				 , @FabricType = FabricType
				 , @ColorID = ColorID
				 , @Qty = Qty --IIF(@Category = 'B', Qty,trueQty)
				 , @POUnit = POUnit
				 , @SizeSpec = SizeSpec
				 , @SizeUnit = SizeUnit
				 , @Width = Width
				 , @BomZipperInsert = BomZipperInsert
				 , @BomCustPONo = BomCustPONo
				 , @Special = Special
				 , @Spec = Spec
			From #tmpPO_Supp_Detail
			Where RowID = @tmpPo_Supp_DetailRowID
			   And ID = @PoID
			   And Seq1 = @Seq1;

			SELECT @PurchaseCompany = CompanyID
			FROM #tmpPO_Supp
			WHERE ID = @PoID
			   And Seq1 = @Seq1;

			set @MtlTypeID = (select MtltypeID FROM Fabric WHERE SCIRefno = @SCIRefNo);

			If @@RowCount > 0
			Begin
				--取得物料LeadTime
				Set @MtlLT = Trade.dbo.GetMtlLT(@SciRefNo, @Category, @SuppID, @StyleID, @BrandID, @SeasonID, @FactoryCountry, @OrderTypeID, @ColorID);

				Select @LTDay = Fabric_Supp.LTDay
				, @SuppRefno = Fabric_Supp.SuppRefno
				, @BrandRefNo = Fabric.BrandRefNo
				From Trade.dbo.Fabric_Supp
				Left join Trade.dbo.Fabric on Fabric_Supp.SCIRefno = Fabric.SCIRefno
				Where Fabric_Supp.SCIRefno = @SciRefNo
				And Fabric_Supp.SuppID = @SuppID;
				
				If @LTDay = 2
				Begin
					Set @SystemETD = Trade.dbo.GetWorkDay(@CfmDate, @MtlLT);
				End;
				Else
				Begin
					Set @SystemETD = DateAdd(dd, @MtlLT, @CfmDate);
				End;
				
				IF @SystemETD < @ExecDate
				Begin
					Set @SystemETD = DateAdd(dd, 1, @ExecDate);
				End
				--------------------------------------------------------
				--重新抓單價
				Set @tmpPrice = Trade.dbo.GetPriceFromMtl(@SciRefNo, @SuppID,@SeasonID, @Qty, @Category, @CfmDate, @SizeSpec, @ColorID, @FactoryID);
				Set @FeeUnit = ''
				Set @Fee = 0
				Select @FeeUnit = IsNull(UnitID, ''), @Fee = IsNull(Fee, 0) 
				From Trade.dbo.Supp_AdditionalFee 
				Where SuppID = @SuppID And Destination = @FactoryCountry

				If(@FeeUnit <> '')
				Begin
					Set @Price = @tmpPrice + (Trade.dbo.GetUnitQty(@FeeUnit, @POUnit, 1) * @Fee)
				End
				Else
				Begin
					Set @Price = @tmpPrice
				End
				--------------------------------------------------------
				--重新抓庫存
				If SubString(@Seq1, 1, 1) != 'A'	--只有A大項不需計算庫存
				Begin
					delete from @RefnoSpec
					insert into @RefnoSpec (SpecColumnID, SpecValue, BomType)
					select 'Color', @ColorID, cast(1 as bit)

					Set @StockQty = dbo.GetStockQty('', @StyleID, @FactoryID, @ProjectID, @ProgramID, @BrandID, @OrderTypeID,
						@RefNo, @PurchaseCompany, @Width, @FabricType, @Category, @MtlTypeID, @PoID, 0, @SuppRefno, @SuppColor, @BrandRefNo, @RefnoSpec, @SeasonID);
				End;
				--------------------------------------------------------
				--更新Temp Table - PO_Supp_Detail
				Update #tmpPO_Supp_Detail
				   Set ShipModeID = @ShipModeID
					 , SystemETD = @SystemETD
					 , FinalETD = @SystemETD
					 , Price = @Price
					 , StockQty = isnull(@StockQty, 0)
				 Where RowID = @tmpPo_Supp_DetailRowID
				   And ID = @PoID
				   And Seq1 = @Seq1;
			End
			
			Set @tmpPo_Supp_DetailRowID += 1;
		End
		--------------------Loop End #tmpPO_Supp_Detail--------------------
		-------------------------------------
		--取得Supplier Remaek
		Exec Trade.dbo.GetSuppRemark @PoID, @SuppID, @BrandID, @FactoryCountry, @FactoryID, @FabricType, 'P', @Remark Output;
		-------------------------------------
		--更新Temp Table - PO_Supp
		Update #tmpPO_Supp
		   Set ShipTermID = @ShipTermID
			 , PayTermAPID = @PayTermAPID
			 , CompanyID = @CompanyID
			 , Remark = @Remark
			 , Description = @KeywordValue + @Description
		 Where RowID = @tmpPo_SuppRowID;
		-------------------------------------

		Set @tmpPo_SuppRowID += 1;
	End

	declare @idxTbl table (RowID BIGINT, idx int)
	insert into @idxTbl
	select RowID, idx = ROW_NUMBER() OVER(PARTITION by id, Seq1 ORDER by id, Seq1) from #tmpPO_Supp_Detail

	update po3 set Seq2_Count = idx
	from #tmpPO_Supp_Detail po3
	inner join @idxTbl tmp on po3.RowID = tmp.RowID

	Create Table #tmp (Seq1 VarChar(3), Seq2 VarChar(2), ID VarChar(13), Seq2_Count Int);	

	IF @Category = 'A'
	Begin
		update #tmpPO_Supp_Detail set NetQty = 0, SystemNetQty = 0

		insert into #tmp
		select po3.Seq1, po3.Seq2, list.PoID, po3.Seq2_Count
		from @IdList list
		inner join Orders on list.PoID = Orders.POID
		inner join #tmpPO_Supp po2 on Orders.StyleID = po2.StyleID
		inner join #tmpPO_Supp_Detail po3 on po2.Seq1 = po3.Seq1
		group by po3.Seq1, po3.Seq2, list.PoID, po3.Seq2_Count

		Insert Into #tmpPO_Supp_Detail_OrderList
		(ID, Seq1, Seq2, OrderID, Seq2_Count)
		select @PoID, Seq1, Seq2, ID, Seq2_Count from #tmp
	End
	Else
	Begin
		insert into #tmp
		select po3.Seq1, po3.Seq2, oq.ID, po3.Seq2_Count
		from #tmpOpThread tot
		inner join Trade.dbo.Style_ThreadColorCombo_Detail std
			on tot.Ukey = std.Style_ThreadColorComboUkey and tot.Seq = std.Seq
		inner join (
			select oq.Article, o.ID from dbo.Order_Qty oq 
			inner join dbo.Orders o on oq.ID = o.ID
			where o.POID = @PoID and dbo.CheckOrder_CalculateMtlUsage(o.ID) = 1) oq
				on oq.Article = std.Article
		inner join #tmpPO_Supp_Detail po3
			on po3.SCIRefNo = std.SCIRefNo
			and po3.ColorID = std.ColorID
			and po3.SuppColor = std.SuppColor
			and po3.ID = @PoID
		where po3.Seq1 like 'T%'
			and EXISTS(select 1 from Trade.dbo.MachineType_ThreadRatio mt where mt.ID = tot.MachineTypeID and mt.Seq = tot.Seq)
		group by po3.Seq1, po3.Seq2, oq.ID, po3.Seq2_Count

		select @PoComboCount = count(*) from dbo.Orders where Orders.POID = @PoID

		--當OrderList數不等於 Po Combo數時才寫入
		Insert Into #tmpPO_Supp_Detail_OrderList
		(ID, Seq1, Seq2, OrderID, Seq2_Count)
		select @PoID, Seq1, Seq2, ID, Seq2_Count from #tmp tmp
		outer apply (select count(*) c from #tmp where tmp.Seq2_Count = Seq2_Count) Count
		where Count.c != @PoComboCount
	End
	
	delete po3 
    from #tmpPO_Supp_Detail po3 
	inner join #tmpPO_Supp po2 on po3.ID = po2.ID and po3.Seq1 = po2.Seq1
    inner join Trade.dbo.Supp s on po2.SuppID = s.ID
	where po2.Junk = 1 Or s.Junk = 1 Or s.LockDate is not null

    delete po2
    From #tmpPO_Supp po2
    Inner join Trade.dbo.Supp s on po2.SuppID = s.ID
    where po2.Junk = 1 Or s.Junk = 1 Or s.LockDate is not null

	Insert Into #tmpPO_Supp_Detail_Spec
		(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
	Select ID, Seq1, Seq2, 'Color', ColorID, Seq2_Count
	From #tmpPO_Supp_Detail
	
	IF OBJECT_ID('tempdb..#tmpOpThread') IS NOT NULL DROP TABLE #tmpOpThread
	IF OBJECT_ID('tempdb..#tmpTtlQty') IS NOT NULL DROP TABLE #tmpTtlQty
	drop table #tmpFinal
	drop table #tmpResult
	drop table #SameSCIGroup
	drop table #tmp
End
GO

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_1_ForThread', 'Trade';
Go