Use [Trade]
Go

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Vicky
-- Create date: 2019/01/07
-- Description:
--		自動轉單 for Thread Allowance Combo
-- =============================================
If Object_Id ( 'dbo.TransferToPO_1_ForThreadAllowance', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_1_ForThreadAllowance;
Go

Create Procedure [dbo].[TransferToPO_1_ForThreadAllowance]
(
	  @PoID			VarChar(13)		--採購母單
	 ,@UserID		VarChar(10) = ''
	 ,@ForReport	bit = 0			-- 報表Purchase_P01_07使用
	 ,@ForMaterialCompare	bit = 0	-- MaterialCompare使用
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
			 , StyleID VarChar(15), TargetLETA Date, Primary Key (ID, Seq1), Junk Bit
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

	Create Table #tmpOpThread 
		( StyleUkey bigint, Ukey bigint, MachineTypeID varchar(10), Seq VarChar(2), OpThreadQty Numeric(20,6) );

	Create Table #tmpFinal 
		( PoID VarChar(13), StyleID varchar(15), SuppID VarChar(6), Seq1 VarChar(3)
			, SCIRefNo VarChar(30) default '', ColorID Varchar(6), SuppColor NVarChar(Max) default ''
			, POQty Numeric(10,2), Foc Numeric(10,2), UsedQty Numeric(20,2), NetQty Numeric(20,2), LossQty Numeric(10,2)
			, UsageUnit varchar(8), POUnit varchar(8), MtltypeId varchar(20), Refno varchar(36), Type varchar(1)
			, MinQty Numeric(10,2), LimitUp Numeric(10,2), TtlNetQty Numeric(20,2)
			, IsForOtherBrand bit, ThreadPlusLossRate Numeric(5,2)
		);

	Create Table #tmpQT 
		( RowID BigInt Identity(1,1) Not Null, SuppID VarChar(6), Seq1 VarChar(3)
			, SCIRefNo VarChar(30) default '', ColorID Varchar(6), SuppColor NVarChar(Max) default ''
			, POQty Numeric(10,2), UsedQty Numeric(20,2), NetQty Numeric(20,2), LossQty Numeric(10,2)
			, UsageUnit varchar(8), POUnit varchar(8), MtltypeId varchar(20), Refno varchar(36), Type varchar(1)
			, MinQty Numeric(10,2), LimitUp Numeric(10,2)
		);
		
	Declare @tmpQTRowID Int;		--Row ID
	Declare @tmpQTRowCount Int;	--總資料筆數

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
	Declare @SystemETD_Plus7D date;
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
	Declare @CustCDID varchar(16);
	Declare @CfmDate Date;
	Declare @ThickFabric bit;
	Declare @UseRatioRule VarChar(1);
	Declare @FabricType VarChar(5);
	Declare @ThreadStatus VarChar(10);
	Declare @CountryID Varchar(2);
	Declare @Dest varchar(2);
	Declare @PoComboCount int;
	Declare @GSDType varchar(1);
	declare @CuttingSP	VarChar(13)
	Declare @OrderCompany Numeric(2,0);
	Declare @PurchaseCompany Numeric(2,0);
	Declare @CurrencyID VarChar(3);

	declare @CurPoID VarChar(13)
	Declare @ComboListRowID Int;	--Row ID
	Declare @ComboListRowCount Int;	--總資料筆數

	---------------------------------------------
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
	Declare @tmpDiffNetQty Numeric(10,2)
	Declare @IsForOtherBrand bit;
	Declare @SystemETD_AdditionalDays Numeric(3,0);
	Declare @Status varchar(1);

	Declare @tmpSeq1 VarChar(3);
	Declare @transEDI bit = 0;
	Declare @MinQty Numeric(10,2);
	Declare @POQty Numeric(10,2);
	Declare @OutputQty Numeric(10,2);
	Declare @BalanceQty Numeric(10,2);
	Declare @MtltypeID varchar(20);
	Declare @IncludePOQty Bit = 0;
	Declare @IsFOC bit;
	Declare @Calc Bit = 0;
	Declare @RefnoSpec dbo.Refno_Spec;
	Declare @Version varchar(5);

	Declare @SystemETD_SpecialRule int;
	Declare @MaxSystemETD Date;
	Declare @LongestETA Date;
	Declare @TargetLETA Date;
	Declare @LoadDate Date;

	--Status 1:Insert 2:Update Qty = 0 3: Update Qty
	Create Table #SameSCIGroup 
		( RowID BigInt Identity(1,1) Not Null, StyleID varchar(15), SuppID VarChar(6),Seq1 VarChar(3), Seq2 VarChar(2)
			, SCIRefNo VarChar(30) default '', ColorID Varchar(6), SuppColor NVarChar(Max) default '', IsForOtherBrand bit
			, NewQty Numeric(10,2), OriQty Numeric(10,2), NewLossQty Numeric(10,2), OriLossQty Numeric(10,2)
			, Status varchar(1), transEDI bit default 0, MinQty Numeric(10,2), LimitUp Numeric(10,2)
			, NewNetQty Numeric(10,2), OriNetQty Numeric(10,2), OutputQty Numeric(10,2)
		);
	---------------------------------------------
	If Object_ID('tempdb..#ComboList') Is Null
	Create Table #ComboList ( RowID BigInt Identity(1,1) Not Null, ID VarChar(13), CFMDate Date, SciDelivery Date, StyleUkey bigint, Calc bit)
	SET IDENTITY_INSERT #ComboList ON

	if exists (select 1 from Orders where ID = @PoID
			and Category = 'B'
			and CFMDate >= (Select Cast(pValue as date) from Trade.dbo.ParameterSetting where pType = 'AllowanceCombo' and pName = 'CfmDate'))
	Begin
		Insert Into #ComboList (RowID, ID, CFMDate, SciDelivery, StyleUkey, Calc)
		Select ROW_NUMBER() OVER(ORDER BY ID) AS ROWID, ID, CFMDate, SciDelivery, StyleUkey, 1
		from Orders where ID = POID and AllowanceComboID = (SELECT AllowanceComboID FROM Orders WHERE ID = @PoID)
	End
	Else
	Begin
		Insert Into #ComboList (RowID, ID, CFMDate, SciDelivery, StyleUkey, Calc)
		Select ROW_NUMBER() OVER(ORDER BY ID) AS ROWID, ID, CFMDate, SciDelivery, StyleUkey, 1
		from Orders where ID = @PoID
	End
	
	if @@ROWCOUNT = 0 return

	Set @ComboListRowID = 1;
	Select @ComboListRowID = Min(RowID), @ComboListRowCount = Max(RowID) From #ComboList;
	While @ComboListRowID <= @ComboListRowCount
	Begin
		select @CurPoID = ID
		from #ComboList
		where ROWID = @ComboListRowID

		-- new loop start
		select
			@BrandID = BrandID,
			@StyleID = StyleID,
			@StyleUkey = StyleUkey,
			@SeasonID = SeasonID,
			@Category = Category,
			@CustCDID = CustCDID,
			@CfmDate = CFMDate,
			@SystemETD_AdditionalDays = SystemETD_AdditionalDays,
			@FactoryID = FactoryID,
			@FactoryKpiCode = Factory.KpiCode,
			@FactoryCountry = Factory.CountryID,
			@CountryID = Factory.CountryID,
			@Dest = Orders.Dest,
			@OrderTypeID = OrderTypeID,
			@ProgramID = ProgramID,
			@ProjectID = ProjectID,
			@OrderCompany = OrderCompany
		from dbo.Orders 
		inner join Trade.dbo.Factory on Orders.FactoryID = Factory.ID
		where Orders.id = @CurPoID

		select 
		@ThickFabric = Style.ThickFabricBulk,
		@FabricType = Style.FabricType,
		@ThreadStatus = Style.ThreadStatus,
		@GSDType = isnull(IETMS.GSDType, ''),
		@StyleProgramID = Style.ProgramID
		from Trade.dbo.Style
		left join Trade.dbo.IETMS on Style.IETMSID_Thread = IETMS.ID and Style.IETMSVersion_Thread = IETMS.Version
		where Style.Ukey = @StyleUkey

		if (@Category in ('B', 'M')
			and (not exists(select 1 from Trade.dbo.Style_ThreadColorCombo_History_Version h WITH (NOLOCK) where h.StyleUkey = @StyleUkey and h.VersionCOO in ('', @CountryID))
				or @GSDType = 'C'))
		begin
			update #ComboList set Calc = 0 where ID = @CurPoID
			set @ComboListRowID += 1;
			continue;
		end

		--取得UseRatioRule，for MachineType_ThreadRatio_Regular 抓取的時候分類別抓取
		Set @UseRatioRule = Trade.dbo.GetRatioLevel(@StyleUkey, 0)

		select top 1 @Version = Version
		from Trade.dbo.Style_ThreadColorCombo_History_Version
		where StyleUkey = @StyleUkey
		and VersionCOO in ('', @CountryID)
		order by VersionCOO desc, Version desc

		/*
			Operation Thread Qty 依照Style_ThreadColorCombo Join Operation, MachineTypeID抓出SeamLength跟Machine UseRatio，再加上Allowance，
			每個Operation都需要算UseRatio跟Allowance所以會依照Operation發散
			[IST20220450] 2022-04-19 改使用Style_ThreadColorCombo歷史檔
		*/
		IF not exists (select 1 from #tmpOpThread where StyleUkey = @StyleUkey)
		Begin
			Insert Into #tmpOpThread (StyleUkey, Ukey, MachineTypeID, Seq, OpThreadQty)
			select st.StyleUkey
			, st.Ukey
			, st.MachineTypeID
			, std.Seq
			, OpThreadQty = sum((sto.SeamLength * sto.Frequency * iif(sto.OperationHem = 1 and sto.MachineTypeHem = 1, std.UseRatioHem, isnull(std.UseRatio, mto.UseRatio))) + (iif(sto.Tubular = 1, std.AllowanceTubular, std.Allowance) * sto.Segment))
			from Trade.dbo.Style_ThreadColorCombo_History st
			inner join Trade.dbo.Style_ThreadColorCombo_History_Operation sto
				on st.Ukey = sto.Style_ThreadColorCombo_HistoryUkey
			outer apply (
				select distinct Seq, UseRatio, UseRatioHem, AllowanceTubular, Allowance
				from Trade.dbo.Style_ThreadColorCombo_History_Detail std
				where st.Ukey = std.Style_ThreadColorCombo_HistoryUkey
			) std
			inner join Trade.dbo.MachineType_ThreadRatio mto on mto.ID = st.MachineTypeID and mto.Seq = std.Seq
			where st.StyleUkey = @StyleUkey and st.Version = @Version
			group by st.StyleUkey, st.Ukey, st.MachineTypeID, std.Seq
		End

		IF OBJECT_ID('tempdb..#tmpStd') IS NOT NULL DROP TABLE #tmpStd
		select grwv.*, std.Seq, std.Style_ThreadColorCombo_HistoryUkey, std.Article, supp.SuppId
		into #tmpStd
		from #tmpOpThread tot
		inner join Trade.dbo.Style_ThreadColorCombo_History_Detail std
			on tot.Ukey = std.Style_ThreadColorCombo_HistoryUkey and tot.Seq = std.Seq
		Outer apply ( select SuppId = Trade.dbo.GetReplaceSupp_ByPOCombo(std.SuppID, std.SciRefno, @CurPoID)) supp
		outer apply Trade.dbo.GetThreadReplaceWithValue(supp.SuppID, std.Ukey, @CfmDate, @Category) grwv


		IF OBJECT_ID('tempdb..#tmpTtlQty') IS NOT NULL DROP TABLE #tmpTtlQty
		select sum(Qty) Qty, SuppId, SCIRefNo, ColorID
		into #tmpTtlQty
		from (
			select std.SuppId, std.SCIRefNo, std.ColorID, Qty
			from Trade.dbo.Style_ThreadColorCombo_History st
			left join #tmpStd std
			on st.Ukey = std.Style_ThreadColorCombo_HistoryUkey
			outer apply (
				select Order_Qty.Qty, Order_Qty.SizeCode, Order_Qty.ID
				from dbo.Order_Qty  
				inner join dbo.Orders o on Order_Qty.ID = o.ID
				where o.POID = @CurPoID and dbo.CheckOrder_CalculateMtlUsage(o.ID) = 1
				and Order_Qty.Article = std.Article
			) tmpQty
			where st.StyleUkey = @StyleUkey
			and st.Version = @Version
			and isnull(std.ColorID, '') != ''
			and isnull(tmpQty.Qty, 0) != 0
			and EXISTS(select 1 from Trade.dbo.MachineType_ThreadRatio mt where mt.ID = st.MachineTypeID and mt.Seq = std.Seq)
			group by std.SuppId, std.SCIRefNo, std.ColorID, tmpQty.Qty, tmpQty.SizeCode, tmpQty.ID
		) tmp
		group by SuppId, SCIRefNo, ColorID

		--Group by SuppId, SCIRefNo, ColorID 算完NetQty
		Insert Into #tmpFinal
		(PoID, StyleID, SuppID, Seq1, SCIRefNo, ColorID, SuppColor, POQty, UsedQty, NetQty, LossQty, UsageUnit, POUnit, MtltypeId, Refno, Type, MinQty, LimitUp, IsForOtherBrand, ThreadPlusLossRate)
		select @CurPoID
			, @StyleID
			, std.SuppId
			, Seq1 = ''
			, std.SciRefno
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
			, std.IsForOtherBrand
			, Orders.ThreadPlusLossRate
		from #tmpOpThread tot
		inner join #tmpStd std
			on tot.Ukey = std.Style_ThreadColorCombo_HistoryUkey and tot.Seq = std.Seq
		inner join (
			select oq.Article, OrderQty = oq.Qty from dbo.Order_Qty oq 
			inner join dbo.Orders o on oq.ID = o.ID
			where o.POID = @CurPoID and dbo.CheckOrder_CalculateMtlUsage(o.ID) = 1) oq
			on oq.Article = std.Article
		inner join Trade.dbo.Fabric fb on fb.SCIRefno = std.SciRefno
		inner join Trade.dbo.Fabric_Supp fs on fs.SCIRefno = std.SciRefno and fs.SuppID = std.SuppID
		outer apply (select top 1 LimitDown from Trade.dbo.MtlType_Limit ml where ml.Id = fb.MtlTypeID and ml.PoUnit = fs.POUnit) ml
		outer apply (select top 1 LimitUp from Trade.dbo.LossRateAccessory_Limit ll where ll.MtltypeId = fb.MtltypeId and ll.UsageUnit = fs.POUnit) ll
		outer apply (select ThreadPlusLossRate = isnull(ThreadPlusLossRate, 0) from Trade.dbo.Orders where ID = @PoID) Orders
		where tot.StyleUkey = @StyleUkey
			and isnull(std.ColorID, '') != ''
			and EXISTS(select 1 from Trade.dbo.MachineType_ThreadRatio mt where mt.ID = tot.MachineTypeID and mt.Seq = tot.Seq)
			and fb.Junk = 0 and fs.Lock = 0 and fs.Junk = 0
		group by std.SuppId, std.SciRefno, std.ColorID, std.SuppColor, fb.UsageUnit, fs.POUnit, fb.MtltypeId, fb.Refno, fb.Type, ml.LimitDown, ll.LimitUp, std.IsForOtherBrand, Orders.ThreadPlusLossRate

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
		where tmp.PoID = @CurPoID

		set @ComboListRowID +=1;
	End
	--new loop end

	IF @Category <> 'B' or (@Category = 'B' and @CfmDate < '2099-12-31') -- for [IST20191807] 在2019/11/25前成立的Bulk單仍須算LossQty
	Begin
		Update tmp set TtlNetQty = Ttl.NetQty
		from #tmpFinal tmp
		outer apply (
			select sum(NetQty) NetQty
			from #tmpFinal tmp1
			where tmp1.StyleID = tmp.StyleID
				and tmp1.SuppID = tmp.SuppID
				and tmp1.SCIRefNo = tmp.SCIRefNo
				and tmp1.ColorID = tmp.ColorID
				and tmp1.SuppColor = tmp.SuppColor
		) Ttl

		Update tmp set
			LossQty = Trade.dbo.GetCeiling(isnull(iif(nl.netLoss > LimitUp, LimitUp, nl.netLoss) * iif(TtlNetQty = 0, 0, NetQty / TtlNetQty), 0), 0, 0)
		from #tmpFinal tmp
		outer apply (
			select Data = 1, Type = iif(isnull(tcd.Type, '') = '', 'C', tcd.Type)
			from Trade.dbo.ThreadCommon tc
			inner join Trade.dbo.ThreadCommon_Detail tcd on tc.Ukey = tcd.ThreadCommonUkey
			where tc.BrandID = @BrandID
			and tc.Refno = tmp.Refno
			and tc.ColorId = tmp.ColorID 
			and @CfmDate between tcd.StartDate
			and isnull(tcd.EndDate, cast('9999-12-31' as date))
		) tcd
		outer apply (select top 1 Allowance from Trade.dbo.Thread_AllowanceScale ta where tmp.TtlNetQty between ta.LowerBound and ta.UpperBound
							and ta.Type = iif(tcd.Data = 1, tcd.Type, 'N')) ta
		outer apply (select netLoss = Trade.dbo.GetCeiling(isnull(tmp.TtlNetQty, 0) * isnull(ta.Allowance, 0),0 ,0)) nl

		-- [IST20231179] 計算ThreadPlusLossRate設定
		Update tmp Set LossQty = IIF(getLoss.LossQty > LimitUp, LimitUp, getLoss.LossQty)
		from #tmpFinal tmp
		outer apply (select LossQty = IIF(ThreadPlusLossRate = 0, LossQty, LossQty + CEILING(NetQty * ThreadPlusLossRate / 100))) getLoss
	End
	
	--POQty
	Update tmp set POQty = NetQty + LossQty
	from #tmpFinal tmp

	-- 報表僅需計算傳入單號
	IF @ForReport = 1
	Begin
		Delete #ComboList Where ID != @PoID
	End

	Set @ComboListRowID = 1;
	Select @ComboListRowID = Min(RowID), @ComboListRowCount = Max(RowID) From #ComboList;
	While @ComboListRowID <= @ComboListRowCount
	Begin
		select @CurPoID = ID
		, @Calc = Calc
		from #ComboList
		where ROWID = @ComboListRowID

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
			@CuttingSP = CuttingSP
		from dbo.Orders 
		inner join Trade.dbo.Factory on Orders.FactoryID = Factory.ID
		where Orders.id = @CurPoID

		IF @Calc = 1
		Begin
			-- QT Thread
			IF OBJECT_ID('tempdb..#tmpQT') IS NOT NULL TRUNCATE TABLE #tmpQT;
			with tmpQty as (
				Select Order_Qty.Article,COALESCE(Order_SizeSpec.SizeSpec, getMarkerSize.SizeCode, Order_Qty.SizeCode) SizeCode, Sum(Order_Qty.Qty) as Qty
				From dbo.Orders
				Left Join dbo.Order_Qty
				On Order_Qty.ID = Orders.ID
				Left Join dbo.Order_SizeSpec
				On Order_SizeSpec.ID = Orders.PoID
					And Order_SizeSpec.SizeItem = 'S00'
					And Order_SizeSpec.SizeCode = Order_Qty.SizeCode
				OUTER APPLY (
					Select TOP 1 ms.SizeCode  
					FROM Orders oo 
					inner JOIN Order_MarkerList om on om.Id = oo.ID 
					inner Join Trade.dbo.Marker_SizeCode ms on om.SMNoticeID = ms.ID and ms.Version = om.MarkerVersion
					WHERE oo.ID = Orders.PoID and oo.Category = 'S'
					and NOT exists(
						select 1 from Order_MarkerList om1
						inner Join Trade.dbo.Marker_SizeCode ms1 on om1.SMNoticeID = ms1.ID and ms1.Version = om1.MarkerVersion and ms1.SizeCode = Order_Qty.SizeCode
						where om1.ID = oo.POID)
					Order by ms.SizeSortNo desc, ms.MarkerUKEY
				)getMarkerSize
				Where Orders.PoID = @CurPoID
				And Orders.CuttingSP = @CuttingSP
				And dbo.CheckOrder_CalculateMtlUsage(Orders.id) = 1
				Group by Order_Qty.Article, COALESCE(Order_SizeSpec.SizeSpec, getMarkerSize.SizeCode, Order_Qty.SizeCode)
			)
			, eachCons as (
				select ml.FabricPanelCode, cc.Article, sum(tmpQty.Qty * ml.ConsPC) YDS
				from Order_MarkerList ml
				inner join Order_ColorCombo cc on cc.Id = ml.Id and cc.FabricPanelCode = ml.FabricPanelCode
				inner join Order_MarkerList_SizeQty mls on ml.Ukey = mls.Order_MarkerListUkey
				inner join tmpQty on cc.Article = tmpQty.Article and mls.SizeCode = tmpQty.SizeCode
				where ml.Id = @CurPoID and ml.CuttingPiece = 0 and ml.MixedSizeMarker = 1
				group by ml.FabricPanelCode, cc.Article
			)
			Insert Into #tmpQT
			(SuppID, Seq1, SCIRefNo, ColorID, SuppColor, POQty, UsedQty, NetQty, LossQty, UsageUnit, POUnit, MtltypeId, Refno, Type, MinQty, LimitUp)
			select supp.SuppId
			, Seq1 = ''
			, std.SCIRefNo
			, std.ColorID
			, std.SuppColor
			, POQty = 0
			, UsedQty = round(sum(getNumberOfNeedle.NumberOfNeedle * tql.Ratio * Trade.dbo.GetUnitQty(fb.UsageUnit, fs.POUnit, Trade.dbo.GetUnitQty('YDS', fb.UsageUnit, ec.YDS))), 2)
			, NetQty = Trade.dbo.GetCeiling(round(sum(getNumberOfNeedle.NumberOfNeedle * tql.Ratio * Trade.dbo.GetUnitQty(fb.UsageUnit, fs.POUnit, Trade.dbo.GetUnitQty('YDS', fb.UsageUnit, ec.YDS))), 2), 0, 0)
			, LossQty = 0
			, fb.UsageUnit
			, fs.POUnit
			, fb.MtltypeId
			, fb.Refno
			, fb.Type
			, ml.LimitDown
			, ll.LimitUp
			from Trade.dbo.Style_QTThreadColorCombo_History st
			inner join Trade.dbo.Style_QTThreadColorCombo_History_Detail std on st.Ukey = std.Style_QTThreadColorCombo_HistoryUkey
			Outer apply ( select SuppId = Trade.dbo.GetReplaceSupp_ByPOCombo(std.SuppID, std.SciRefno, @CurPoID)) supp
			inner join Trade.dbo.Fabric fb on fb.SCIRefno = std.SCIRefNo
			inner join Trade.dbo.Fabric_Supp fs on fs.SCIRefno = std.SCIRefNo and fs.SuppID = supp.SuppID
			inner join Trade.dbo.Style_FabricCode fc on st.StyleUkey = fc.StyleUkey and st.FabricPanelCode = fc.FabricPanelCode
			inner join Trade.dbo.Style_BOF bof on fc.StyleUkey = bof.StyleUkey and fc.FabricCode = bof.FabricCode
			inner join Trade.dbo.Fabric bof_f on bof.SCIRefno = bof_f.SCIRefno
			inner join Trade.dbo.Thread_Quilting_Size tqs on st.Thread_Quilting_SizeUkey = tqs.Ukey
			inner join Trade.dbo.Thread_Quilting_Size_Location tql on tqs.Ukey = tql.Thread_Quilting_SizeUkey and std.Seq = tql.Seq
			inner join eachCons ec on ec.FabricPanelCode = st.FabricPanelCode and ec.Article = std.Article
			outer apply (select top 1 LimitDown from Trade.dbo.MtlType_Limit ml where ml.Id = fb.MtlTypeID and ml.PoUnit = fs.POUnit) ml
			outer apply (select top 1 LimitUp from Trade.dbo.LossRateAccessory_Limit ll where ll.MtltypeId = fb.MtltypeId and ll.UsageUnit = fs.POUnit) ll
			outer apply (
				Select min(f.Width) Width
				From Trade.dbo.Style_FabricCode_QT sfqt
				Inner Join Trade.dbo.Style_FabricCode sf on st.StyleUkey = sf.StyleUkey and sf.FabricPanelCode = sfqt.QTFabricPanelCode
				Inner Join Trade.dbo.Style_BOF bof on st.StyleUkey = bof.StyleUkey and sf.FabricCode = bof.FabricCode
				Inner Join Trade.dbo.Fabric f on bof.SCIRefno = f.SCIRefno
				Where st.StyleUkey = sfqt.StyleUkey and st.FabricPanelCode = sfqt.FabricPanelCode
			) getWidth
			outer apply (select NumberOfNeedle = ceiling(getWidth.Width / tqs.HSize / tqs.NeedleDistance)) getNumberOfNeedle
			where st.StyleUkey = @StyleUkey and st.Version = @Version
			and fb.Junk = 0 and fs.Lock = 0 and fs.Junk = 0
			group by supp.SuppId, std.SCIRefNo, std.ColorID, std.SuppColor, fb.UsageUnit, fs.POUnit, fb.MtltypeId, fb.Refno, fb.Type, ml.LimitDown, ll.LimitUp

			update tmp set LossQty = Trade.dbo.GetCeiling(isnull(nl.netLoss, 0), 0, 0)
			from #tmpQT tmp
			outer apply (select top 1 Allowance from Trade.dbo.Thread_AllowanceScale ta where ta.Type = 'Q' and tmp.NetQty between ta.LowerBound and ta.UpperBound ) ta
			outer apply (select netLoss = Trade.dbo.GetCeiling(isnull(tmp.NetQty, 0) * isnull(ta.Allowance, 0),0 ,0)) nl

			update tmp set POQty = NetQty + LossQty
			from #tmpQT tmp

			Merge #tmpFinal as tmp
			Using #tmpQT as QT
			on tmp.PoID = @CurPoID
				and tmp.SuppID = QT.SuppID
				and tmp.SCIRefNo = QT.SCIRefNo
				and tmp.ColorID = QT.ColorID
				and tmp.SuppColor = QT.SuppColor
			when matched then
				update set tmp.POQty += QT.POQty
					, tmp.NetQty += QT.NetQty
					, tmp.UsedQty += QT.UsedQty
					, tmp.LossQty += QT.LossQty
			when not matched by target then
				insert (PoID, StyleID, SuppID, Seq1, SCIRefNo, ColorID, SuppColor, POQty, UsedQty, NetQty, LossQty, UsageUnit, POUnit, MtltypeId, Refno, Type, MinQty, LimitUp)
				values (@CurPoID, @StyleID, SuppID, Seq1, SCIRefNo, ColorID, SuppColor, POQty, UsedQty, NetQty, LossQty, UsageUnit, POUnit, MtltypeId, Refno, Type, MinQty, LimitUp);
		End

		IF OBJECT_ID('tempdb..#tmpResult') IS NOT NULL DROP TABLE #tmpResult
		--使用FULL JOIN判斷是否有新增/刪除採購項
		--當New不為空且Ori為空代表新增 或 當New不為空且Ori不為空且尚未上傳EDI => Status = 1
		--當New為空且Ori不為空代表刪除 => Status = 2 (Update Qty = 0)
		--當New不為空且Ori不為空且已上傳EDI代表更新 => Status = 3
		Declare @tmpResultRowID Int;	--Row ID
		Declare @tmpResultRowCount Int;	--總資料筆數
		Select DENSE_RANK() over(order by StyleID, SuppId, SCIRefNo, ColorID, SuppColor, IsForOtherBrand) RowID,*
		Into #tmpResult
		From (
			Select StyleID = isnull(Ori.StyleID, New.StyleID)
			, SuppId = isnull(Ori.SuppId, New.SuppId)
			, Seq1 = isnull(Ori.Seq1, '')
			, Seq2 = isnull(Ori.Seq2, '')
			, Refno = isnull(New.Refno, Ori.Refno)
			, SCIRefNo = isnull(New.SCIRefNo, Ori.SCIRefNo)
			, ColorID = isnull(New.ColorID, Ori.Color)
			, SuppColor = isnull(New.SuppColor, Ori.SuppColor)
			, IsForOtherBrand = isnull(New.IsForOtherBrand, Ori.IsForOtherBrand)
			, POUnit = isnull(New.POUnit, Ori.POUnit)
			, Type = isnull(New.Type, Ori.FabricType)
			, NewQty = New.POQty + isnull(New.Foc, 0)
			, OriQty = isnull(iif(Ori.Junk = 1 , 0, Ori.Qty) + isnull(Ori.OutputQty, 0), 0) + isnull(Ori.Foc, 0)
			, NewLossQty = New.LossQty
			, OriLossQty = isnull(Ori.LossQty, 0)
			, NewNetQty = New.NetQty
			, OriNetQty = isnull(Ori.NetQty, 0)
			, Status = IIF(New.SCIRefNo is not null and Ori.SCIRefNo is null, '1', IIF(New.SCIRefNo is null and Ori.SCIRefNo is not null, '2', IIF(TransEDI = 1,'3','1')))
			, TransEDI = isnull(TransEDI, 0)
			, MinQty = New.MinQty
			, OutputQty = isnull(Ori.OutputQty, 0)
			from
			(select * from #tmpFinal where PoID = @CurPoID) New
			Full join 		
			(select po2.SuppId, isnull(po2.StyleID, @StyleID) StyleID, po3.*, po3Spec.Color
			-- 判斷trasEDI.value = 'Y' 或 有領庫 或 PoStatus狀態不為1 則TransEDI = 1 (用於判斷Status)
			-- (等於未設定Supp_API的廠商的物料Status皆為3: Update Qty)
			, TransEDI = Cast(IIF(trasEDI.value = 'Y' or IsOutput.c > 0 or getPoStatus.PoStatus <> '1', '1', '0') as bit)
			from PO_Supp po2
			inner join PO_Supp_Detail po3 on po2.ID = po3.ID and po2.Seq1 = po3.Seq1
			inner join Trade.dbo.Supp with(nolock) on po2.SuppID = Supp.ID
			outer apply dbo.GetPo3Spec(po3.ID, po3.Seq1, po3.Seq2) po3Spec
			outer apply (select count(*) c from PO_Supp_Detail where ID = po3.ID and OutputSeq1 = po3.Seq1 and OutputSeq2 = po3.Seq2 and Junk = 0) IsOutput
			outer apply (
				-- 未設定Supp_API 或 有設定Supp_API且已上傳EDI 皆視為上傳EDI
				select value = iif(not exists (select 1 from Trade.dbo.Supp_API where Supp_API.SuppGroupFabric = Supp.SuppGroupFabric)
								   or (exists (select 1 from Trade.dbo.Supp_API where Supp_API.SuppGroupFabric = Supp.SuppGroupFabric)
										and exists (select 1 from [EDIAP].GASA.dbo.PurchaseOrderList WITH (NOLOCK) where POID = po2.ID and Seq1 = po2.Seq1))
								, 'Y', '')
			) trasEDI
			outer apply (
				Select PoStatus = SUBSTRING(PoStatus, 1, 1)
				From Trade.dbo.GetStatusByPO(po3.ID, po3.Seq1, po3.Seq2)
			) getPoStatus
			where po2.ID = @CurPoID
				And (@Category = 'A' or (@Category <> 'A' and po2.Seq1 like 'T%'))
				And (po3.Junk = 0 or (po3.Junk = 1 and IsOutput.c > 0 ))
				And @ForReport = 0
				And @ForMaterialCompare = 0
			) Ori
			On New.SuppId = Ori.SuppId
			And New.SCIRefNo = Ori.SCIRefNo
			And New.ColorID = Ori.Color
			And New.SuppColor = Ori.SuppColor
			And New.StyleID = Ori.StyleID
			And New.IsForOtherBrand = Ori.IsForOtherBrand
		) a

		--將原本的PO_Supp寫入#tmpPO_Supp
		Insert Into #tmpPO_Supp	(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, StyleID, Junk)
		select ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, isnull(StyleID, @StyleID), isnull(getJunk.Junk, 1)
		from PO_Supp po2
		outer apply (select top 1 Junk from PO_Supp_Detail po3 where po3.ID = po2.ID and po3.Seq1 = po2.SEQ1 and po3.Junk = 0) getJunk
		where ID = @CurPoID And po2.Seq1 like 'T%' And @ForReport = 0

		--對新採購項(Seq1 = '')的資料預編Seq1	
		Set @tmpResultRowID = 1;
		Select @tmpResultRowID = Min(RowID), @tmpResultRowCount = Max(RowID) From #tmpResult;
		While @tmpResultRowID <= @tmpResultRowCount
		Begin
			Select @Seq1 = Seq1
			, @SuppID = SuppId
			, @StyleID = StyleID
			, @IsForOtherBrand = isnull(IsForOtherBrand, 0)
			From #tmpResult Where RowID = @tmpResultRowID and Seq1 = ''

			If @@RowCount > 0
			Begin
				Select top 1 
				@Seq1 = isnull(Seq1, '')			
				, @transEDI = TransEDI
				From #tmpResult Where SuppId = @SuppID and StyleID = @StyleID and Seq1 != '' and isnull(IsForOtherBrand, 0) = @IsForOtherBrand Order By Seq1

				IF @Seq1 = ''
				Begin
					Select @tmpSeq1 = IsNull(MAX(SUBSTRING(Seq1, PATINDEX('%[0-9]%', Seq1), PATINDEX('%[0-9][^0-9]%', Seq1 + 't') - PATINDEX('%[0-9]%', Seq1) + 1)), '0')
					From #tmpResult

					Set @Seq1 = IIF(@Category <> 'A', 'T' + cast(@tmpSeq1 + 1 as nvarchar), RIGHT(REPLICATE('0', 2) + CAST(@tmpSeq1 + 1 as nvarchar), 2))
				End

				Update #tmpResult Set Seq1 = @Seq1, TransEDI = @transEDI where RowID = @tmpResultRowID
			End

			set @tmpResultRowID += 1;
		End

		Set @tmpResultRowID = 1;
		Select @tmpResultRowID = Min(RowID), @tmpResultRowCount = Max(RowID) From #tmpResult;
		While @tmpResultRowID <= @tmpResultRowCount
		Begin
			truncate table #SameSCIGroup;

			Insert Into #SameSCIGroup
			(StyleID, SuppID, Seq1, Seq2, SCIRefNo, ColorID, SuppColor, IsForOtherBrand, NewQty, OriQty, NewLossQty, OriLossQty, Status, transEDI, MinQty, OutputQty
			,NewNetQty ,OriNetQty)
			Select
			StyleID, SuppID, Seq1, Seq2, SCIRefNo, ColorID, SuppColor, IsForOtherBrand, NewQty, OriQty, NewLossQty, OriLossQty, Status, transEDI, MinQty, OutputQty
			,NewNetQty, OriNetQty
			From #tmpResult
			Where RowID = @tmpResultRowID
			Order By Seq1 Desc

			Set @SameSCIGroupRowID = 1;
			Select @SameSCIGroupRowID = Min(RowID), @SameSCIGroupRowCount = Max(RowID) From #SameSCIGroup;

			IF @SameSCIGroupRowCount > 0
			Begin
				select @NewQty = NewQty, @NewNetQty = NewNetQty, @NewLossQty = NewLossQty from #SameSCIGroup where RowID = @SameSCIGroupRowID
				select @OriTtlQty = sum(OriQty) from #SameSCIGroup
				set @DiffQty = @NewQty - @OriTtlQty
			
				select @OriTtlNetQty = sum(OriNetQty) from #SameSCIGroup
				set @DiffNetQty = @NewNetQty - @OriTtlNetQty
		
				select @OriTtlLossQty = sum(OriLossQty) from #SameSCIGroup
				set @DiffLossQty = @NewLossQty - @OriTtlLossQty
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
				, @OutputQty = OutputQty
				, @IsFoc = Isnull(getIsFOC.IsFOC, 0)
				, @IsForOtherBrand = IsForOtherBrand
				From #SameSCIGroup
				Outer apply (
					Select f.IsFOC 
					From Trade.dbo.Fabric f
					Where f.SCIRefno = #SameSCIGroup.SCIRefNo
				) getIsFOC
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
							set @tmpDiffNetQty = iif(@DiffNetQty > @OriLossQty, @OriLossQty, @DiffNetQty)

							set @NetQty = @BalanceQty - @OriLossQty + iif(@DiffNetQty > @OriLossQty, @OriLossQty, @DiffNetQty)
							set @NetQty = case when @NetQty < 0 then 0 else @NetQty end
							set @DiffNetQty -= (@BalanceQty - @OriNetQty - @OriLossQty + @tmpDiffNetQty)
							set @BalanceQty -= @NetQty
						End
					End
					Else IF @DiffNetQty < 0
					Begin
						-- NetQty減少
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
						IF @DiffLossQty = 0
						Begin
							set @LossQty = @OriLossQty
							set @BalanceQty -= @OriLossQty
						End
						Else IF @BalanceQty >= @NewLossQty or @OriLossQty > @NewLossQty
						Begin
							set @LossQty = @NewLossQty
							set @DiffLossQty = 0
							set @BalanceQty -= @NewLossQty
						End
						Else
						Begin
							set @LossQty = @BalanceQty
							set @DiffLossQty -= (@BalanceQty - @OriLossQty)
							set @BalanceQty = 0
						End
					End
					Else IF @DiffLossQty < 0
					Begin
						-- LossQty減少
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
								set @BalanceQty -= @LossQty
							End
							Else
							Begin
								set @LossQty = @BalanceQty
								set @DiffLossQty = @OriLossQty + @DiffLossQty - @BalanceQty
								set @BalanceQty = 0
							End
						End
					End

					-- 判斷是否小於最低採購量
					IF @DiffQty = 0 And @OriTtlQty < @MinQty
					Begin
						Set @DiffQty = @MinQty - @OriTtlQty
					End
				
					Insert Into #tmpPO_Supp_Detail
					(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
						, ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty, OutputQty 
						, SizeSpec, Complete
						, Seq2_Count, Status, IsForOtherBrand
					)
					select @CurPoID, @Seq1, @Seq2, Refno, tmp.SCIRefno, Type, tmpPrice.Price, UsedQty, @POQty, POUnit,
						RTrim(LTrim(tmp.ColorID)), tmp.SuppColor, '', @NetQty, @LossQty, @NetQty, @OutputQty,
						'', 0,
						0, --ROW_NUMBER() over(partition by Seq1 order by tmp.SCIRefno, tmp.ColorID, tmp.SuppColor),
						@Status, @IsForOtherBrand
					from #tmpFinal tmp	
					outer apply (Select IsNull(Trade.dbo.GetPriceFromMtl(tmp.SCIRefno, tmp.SuppID, @SeasonID, POQty, @Category, @CfmDate, '', tmp.ColorID, @FactoryID), 0) as Price) as tmpPrice
					where PoID = @CurPoID and StyleID = @StyleID and SuppId = @SuppID and SCIRefNo = @SCIRefNo and ColorID = @ColorID and SuppColor = @SuppColor and IsForOtherBrand = @IsForOtherBrand

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
						Select top 1 @Seq1 = Seq1 from #tmpPO_Supp where ID = @CurPoID and Seq1 = @Seq1 and SuppID = @SuppID and StyleID = @StyleID order by Seq1 desc
					
						IF Len(@Seq1) > 2
							set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)
						Else
							set @Seq1 = @Seq1 + Char(65)	
											
						-- 產生新#tmpPO_Supp項次時並無寫入Junk, 可用來判斷編列Seq1是否重複
						While exists (select 1 from #tmpPO_Supp where ID = @CurPoID and Seq1 = @Seq1 and Junk is not null)
						Begin
							set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)	
						End
					End

					-- 判斷@Seq1是否與已Junk的PO_Supp.Seq1相同
					While exists (select 1 from #tmpPO_Supp where ID = @CurPoID and Seq1 = @Seq1 and Junk = 1)
					Begin
						IF Len(@Seq1) > 2
							set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)					
						Else
							set @Seq1 = @Seq1 + Char(65)
					End

					IF not exists (select 1 from #tmpPO_Supp where ID = @CurPoID and Seq1 = @Seq1 and SuppID = @SuppID and StyleID = @StyleID)
					Begin
						Insert Into #tmpPO_Supp	(ID, Seq1, SuppID, StyleID)
						select @CurPoID, @Seq1, @SuppID, @StyleID
					End

					IF @Seq2 = ''
					Begin
						Select @Seq2 = ISNULL(RIGHT(REPLICATE('0', 2) + CAST(MAX(Seq2) + 1 as nvarchar), 2), '01')
						from (
							Select Seq2
							From #tmpPO_Supp_Detail
							Where ID = @CurPoID and Seq1 = @Seq1

							Union

							Select Seq2
							From #tmpResult
							Where Seq1 = @Seq1
						) tmp
					End

					-- 判斷最低採購量
					-- 1. 未轉出新成立 or 已轉出未上傳EDI前重轉 => 僅判斷當前採購量
					-- 2. 已轉出已上傳EDI後重轉補買差異量 or 承左轉出結果未上傳EDI前重轉 => 判斷須包含當前採購量及已採購量

					-- 延續上方第2點，符合以下條件則在判斷最低採購量時需扣除已採購數量
					-- @SameSCIGroupRowCount > 1 代表之前已經買過相同料
					-- @transEDI = 1 and @SameSCIGroupRowCount = 1 為已上傳EDI後又重轉增購的狀況(e.g. T1 => "T1A")
					Set @IncludePOQty = 0;
					IF (@SameSCIGroupRowCount > 1 or (@transEDI = 1 and @SameSCIGroupRowCount = 1))
					Begin
						Set @IncludePOQty = 1;
					End

					set @POQty = @Qty
					IF (@IncludePOQty = 1 and @MinQty > (@POQty + @OriTtlQty)) or (@IncludePOQty = 0 and @MinQty > @POQty)
					Begin
						set @POQty = @MinQty - IIF(@IncludePOQty = 1, @OriTtlQty, 0)
					End

					Insert Into #tmpPO_Supp_Detail
					(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
					 , ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty
					 , SizeSpec, Complete
					 , Seq2_Count
					 , Status, Sel, Junk, IsForOtherBrand
					)
					select @CurPoID, @Seq1, @Seq2, Refno, tmp.SCIRefno, Type, tmpPrice.Price, UsedQty, isnull(@POQty, POQty), POUnit,
						RTrim(LTrim(tmp.ColorID)), tmp.SuppColor, '', isnull(@NetQty, tmp.NetQty), isnull(@LossQty, tmp.LossQty), isnull(@NetQty, tmp.NetQty),
						'', 0,
						0,--ROW_NUMBER() over(partition by Seq1 order by tmp.SCIRefno, tmp.ColorID, tmp.SuppColor),
						@Status, 1, IIF(@POQty = 0 And @IsFOC = 0, 1, 0), @IsForOtherBrand
					from #tmpFinal tmp	
					outer apply (Select IsNull(Trade.dbo.GetPriceFromMtl(tmp.SCIRefno, tmp.SuppID, @SeasonID, POQty, @Category, @CfmDate, '', tmp.ColorID, @FactoryID), 0) as Price) as tmpPrice
					where PoID = @CurPoID and StyleID = @StyleID and SuppId = @SuppID and SCIRefNo = @SCIRefNo and ColorID = @ColorID and SuppColor = @SuppColor and IsForOtherBrand = @IsForOtherBrand
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
					select @CurPoID, @Seq1, @Seq2, Refno, tmp.SCIRefno, Type, tmpPrice.Price, 0, @POQty, POUnit,
						RTrim(LTrim(tmp.ColorID)), tmp.SuppColor, '', 0, 0, 0,
						'', 0,
						0, --ROW_NUMBER() over(partition by Seq1 order by tmp.SCIRefno, tmp.ColorID, tmp.SuppColor),
						@Status, iif(@transEDI = 1, 0, 1)
					from #tmpResult tmp	
					outer apply (Select IsNull(Trade.dbo.GetPriceFromMtl(tmp.SCIRefno, tmp.SuppID, @SeasonID, 0, @Category, @CfmDate, '', tmp.ColorID, @FactoryID), 0) as Price) as tmpPrice
					where RowID = @tmpResultRowID and Seq1 = @Seq1 and Seq2 = @Seq2
				End

				set @SameSCIGroupRowID += 1;
			End

			set @tmpResultRowID += 1;
		End

		--成立A3 Item
		Select @tmpQTRowID = Min(RowID), @tmpQTRowCount = Max(RowID) From #tmpQT;
		
		IF @tmpQTRowCount > 0
		Begin
			Insert Into #tmpPO_Supp
				(ID, Seq1, SuppID)
			Values
				(@CurPoID, 'A3', 'FTY');
		End
		
		--------------------Loop Start @tmpQT--------------------
		While @tmpQTRowID <= @tmpQTRowCount
		Begin
			Select @Seq2 = RIGHT(REPLICATE('0', 2) + CAST(@tmpQTRowID as nvarchar), 2)

			Insert Into #tmpPO_Supp_Detail
			(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
				, ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty
				, SizeSpec, Complete, Seq2_Count, Status, Sel, Junk
			)
			select @CurPoID, 'A3', @Seq2, Refno, SCIRefno, Type, tmpPrice.Price, UsedQty, POQty, POUnit,
				RTrim(LTrim(ColorID)), SuppColor, '', NetQty, LossQty, NetQty,
				'', 1, 0, 1, 1, 0
			from #tmpQT tmp
			outer apply (Select IsNull(Trade.dbo.GetPriceFromMtl(tmp.SCIRefno, tmp.SuppID, @SeasonID, POQty, @Category, @CfmDate, '', tmp.ColorID, @FactoryID), 0) as Price) as tmpPrice
			where tmp.RowID = @tmpQTRowID
			
			Set @tmpQTRowID += 1;
		End		
		--------------------Loop End @tmpQT--------------------	

		-- 2023.02.14 add by Vicky [IST20230130]
		Select @SystemETD_SpecialRule = SystemETD_SpecialRule From Trade.dbo.Brand with(nolock) Where ID = @BrandID

		If @SystemETD_SpecialRule = 1
		Begin
			If exists (select 1 from #tmpPO_Supp where TargetLETA is null)
				and exists (select 1 from Trade.dbo.PO where ID = @PoID and TargetLETA is null)
			Begin
				With Po3ByMaxLT as (
					Select getSystemETD.SystemETD, po3.Seq1, po3.Seq2
					From #tmpPO_Supp_Detail po3
					Left Join #tmpPO_Supp po2 on po3.ID = po2.ID and po3.Seq1 = po2.Seq1
					Left Join Trade.dbo.Fabric_Supp on Fabric_Supp.SCIRefno = po3.SciRefNo And Fabric_Supp.SuppID = po2.SuppID
					Outer Apply (select dbo.GetMtlLT(po3.SCIRefNo, @Category, po2.SuppID, @StyleID, @BrandID, @SeasonID, @FactoryCountry, @OrderTypeID, po3.ColorID) as LT) lt
					Outer Apply (select SystemETD = DateAdd(dd, 7, iif(Fabric_Supp.LTDay = 2, Trade.dbo.GetWorkDay(@CfmDate, lt.LT), DateAdd(dd, lt.LT, @CfmDate)))) getSystemETD
					Where po3.ID = @PoID
				)
				Select top 1 @MaxSystemETD = tmp.SystemETD, @LongestETA = getSchedule.Eta
				From Po3ByMaxLT tmp
				Left Join #tmpPO_Supp_Detail po3 on po3.ID = @PoID and po3.Seq1 = tmp.Seq1 and po3.Seq2 = tmp.Seq2
				Left Join #tmpPO_Supp po2 on po3.ID = po2.ID and po3.Seq1 = po2.Seq1
				Left Join Trade.dbo.Supp on Supp.ID = po2.SuppID
				Outer Apply (Select ShipModeID = dbo.GetFactoryDefaultShip(@FactoryID, Supp.ID, @BrandID)) getShipMode
				Outer Apply (select ShipTermID from dbo.GetReplaceSupp_ShipTerm(Supp.ID, @Category, @FactoryCountry, @FactoryID, @OrderCompany)) getShipTerm
				Outer Apply (
					select SuppPort = Trade.dbo.GetPortBySupp(getShipMode.ShipModeID, po2.SuppID)
					, FtyPort = Trade.dbo.GetPortByFactory(getShipMode.ShipModeID, @FactoryID)) tmpPort
				Outer Apply (
					select top 1 s.Eta
					from Trade.dbo.ScheduleGroup as sg with (nolock)
					inner join Trade.dbo.Schedule as s with (nolock) on s.ScheduleGroupID = sg.ID			
					where sg.ExportPort = tmpPort.SuppPort and sg.ImportPort = tmpPort.FtyPort and sg.ShipModeID = getShipMode.ShipModeID
					and Trade.dbo.FilterSchedule(sg.FilterShipTerm, sg.filterSupplier, sg.FilterFactory, getShipTerm.ShipTermID, po2.SuppID, @FactoryID) = 1
					and s.LoadDate >= tmp.SystemETD and s.junk = 0 and s.Second = 0 and s.OnTime = 0
					order by s.LoadDate, s.Eta desc
				) getSchedule
				Where getSchedule.Eta is not null
				Order By getSchedule.Eta desc
		
				Set @TargetLETA = DateAdd(dd, -14, @LongestETA)
			End
			Else
			Begin
				Select top 1 @TargetLETA = @TargetLETA From #tmpPO_Supp
				
				If @TargetLETA is null
				Begin
					select @TargetLETA = TargetLETA from Trade.dbo.PO where ID = @PoID
				End
			End
		End

		Set @tmpPo_SuppRowID = 1;
		Select @tmpPo_SuppRowID = Min(RowID), @tmpPo_SuppRowCount = Max(RowID) From #tmpPO_Supp Where ID = @CurPoID and (Seq1 like 'T%' or Seq1 like 'A%');
		While @tmpPo_SuppRowID <= @tmpPo_SuppRowCount
		Begin
			Select @Seq1 = Seq1
				 , @SuppID = SuppID
				 , @Description = Description
			From #tmpPO_Supp
			Where RowID = @tmpPo_SuppRowID and ID = @CurPoID and (Seq1 like 'T%' or Seq1 like 'A%');
		
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
				Delete From #tmpPO_Supp Where ID = @CurPoID And Seq1 = @Seq1;
				Set @tmpPo_SuppRowID += 1;
				Continue;
			End;

			Set @tmpPo_Supp_DetailRowID = 1;
			Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From #tmpPO_Supp_Detail Where ID = @CurPoID And Seq1 = @Seq1;
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
				   And ID = @CurPoID
				   And Seq1 = @Seq1;

				SELECT @PurchaseCompany = CompanyID
				FROM #tmpPO_Supp
				WHERE ID = @PoID
			    And Seq1 = @Seq1;

				set @MtlTypeID = (select MtltypeID FROM Fabric WHERE SCIRefno = @SCIRefNo);

				If @@RowCount > 0
				Begin				
					Select @LTDay = Fabric_Supp.LTDay
					, @SuppRefno = Fabric_Supp.SuppRefno
					, @BrandRefNo = Fabric.BrandRefNo
					From Trade.dbo.Fabric_Supp
					Left join Trade.dbo.Fabric on Fabric_Supp.SCIRefno = Fabric.SCIRefno
					Where Fabric_Supp.SCIRefno = @SciRefNo
					And Fabric_Supp.SuppID = @SuppID;

					SET @SystemETD = Trade.dbo.GetDefaultDelDate(@SciRefNo, @Category, @SuppID, @StyleID, @BrandID, @SeasonID, @FactoryCountry, @OrderTypeID, @ColorID, @SystemETD_AdditionalDays, @CfmDate);

					-- 2023.02.14 add by Vicky [IST20230130]
					If @SystemETD_SpecialRule = 1
					Begin
						Set @SystemETD_Plus7D = DateAdd(dd, 7, @SystemETD)
						If @SystemETD_Plus7D = @MaxSystemETD
						Begin
							Set @SystemETD = @MaxSystemETD
						End;
						Else
						Begin
							Select @LoadDate = getSchedule.LoadDate
							From (
								select SuppPort = Trade.dbo.GetPortBySupp(@ShipModeID, @SuppID)
								, FtyPort = Trade.dbo.GetPortByFactory(@ShipModeID, @FactoryID)
							) tmpPort
							Outer Apply (
								select top 1 s.LoadDate
								from Trade.dbo.ScheduleGroup as sg with (nolock)
								inner join Trade.dbo.Schedule as s with (nolock) on s.ScheduleGroupID = sg.ID			
								where sg.ExportPort = tmpPort.SuppPort and sg.ImportPort = tmpPort.FtyPort and sg.ShipModeID = @ShipModeID
								and Trade.dbo.FilterSchedule(sg.FilterShipTerm, sg.filterSupplier, sg.FilterFactory, @ShipTermID, @SuppID, @FactoryID) = 1
								and s.Eta <= @TargetLETA and s.junk = 0 and s.Second = 0 and s.OnTime = 0
								order by s.LoadDate Desc
							) getSchedule

							Set @SystemETD = iif(@LoadDate is null or @LoadDate < @SystemETD_Plus7D, @SystemETD_Plus7D, @LoadDate)
						End;
					End
					ELSE
					BEGIN
						DECLARE @POTargetLETA DATE;
						SELECT @POTargetLETA = TargetLETA FROM PO WHERE ID = @PoID
						declare @BeforeShip int = 1
						if @POTargetLETA is null
						begin
							set @POTargetLETA = dbo.GetRequestETA(@PoID)
							set @BeforeShip = 3
						end

						IF @SystemETD_SpecialRule <> 0 and @BeforeShip = 1
						BEGIN
							WITH CTE AS (
								SELECT getSchedule.*
								From (
									select SuppPort = Trade.dbo.GetPortBySupp(@ShipModeID, @SuppID)
									, FtyPort = Trade.dbo.GetPortByFactory(@ShipModeID, @FactoryID)
								) tmpPort
								Outer Apply (
									select  ROW_NUMBER() OVER (ORDER BY iif(s.CYCFS = 'CFS', 1, 2), s.LoadDate desc) AS RowNum, s.LoadDate
									from Trade.dbo.ScheduleGroup as sg with (nolock)
									inner join Trade.dbo.Schedule as s with (nolock) on s.ScheduleGroupID = sg.ID			
									where sg.ExportPort = tmpPort.SuppPort and sg.ImportPort = tmpPort.FtyPort and sg.ShipModeID = @ShipModeID
									and Trade.dbo.FilterSchedule(sg.FilterShipTerm, sg.filterSupplier, sg.FilterFactory, @ShipTermID, @SuppID, @FactoryID) = 1
									and s.Eta < @POTargetLETA and s.junk = 0 and s.Second = 0 and s.OnTime = 0
								) getSchedule
							)

							Select @LoadDate = LoadDate
							FROM CTE
							WHERE RowNum = @BeforeShip

							Set @SystemETD = iif(@LoadDate is null or @LoadDate < @SystemETD, @SystemETD, @LoadDate)
						END
					END
					
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
					 Where RowID = @tmpPo_Supp_DetailRowID and ID = @CurPoID;
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
				 , TargetLETA = @TargetLETA
			 Where RowID = @tmpPo_SuppRowID and ID = @CurPoID and Seq1 = @Seq1;
			-------------------------------------

			Set @tmpPo_SuppRowID += 1;
		End

		set @ComboListRowID += 1;
	End
	
	declare @idxTbl table (RowID BIGINT, idx int)
	insert into @idxTbl
	select RowID, idx = ROW_NUMBER() OVER(PARTITION by id, Seq1 ORDER by id, Seq1) from #tmpPO_Supp_Detail

	update po3 set Seq2_Count = idx
	from #tmpPO_Supp_Detail po3
	inner join @idxTbl tmp on po3.RowID = tmp.RowID

	Create Table #tmp (Seq1 VarChar(3), Seq2 VarChar(2), ID VarChar(13), Seq2_Count Int);
	
	--Create #tmpOpThread2 For performance
	select tot.*, std.Article, std.SCIRefNo, std.ColorID, std.SuppColor
	into #tmpOpThread2
	from #tmpOpThread tot
	inner join Trade.dbo.Style_ThreadColorCombo_History_Detail std
		on tot.Ukey = std.Style_ThreadColorCombo_HistoryUkey and tot.Seq = std.Seq	

	Set @ComboListRowID = 1;
	Select @ComboListRowID = Min(RowID), @ComboListRowCount = Max(RowID) From #ComboList;
	While @ComboListRowID <= @ComboListRowCount
	Begin
		select @CurPoID = ID
			, @StyleUkey = StyleUkey
		from #ComboList
		where ROWID = @ComboListRowID

		truncate table #tmp
		insert into #tmp
		select po3.Seq1, po3.Seq2, oq.ID, po3.Seq2_Count
		from #tmpOpThread2 tot
		inner join (
			select oq.Article, o.ID
			from dbo.Order_Qty oq 
			inner join dbo.Orders o on oq.ID = o.ID
			where o.POID = @CurPoID
			and dbo.CheckOrder_CalculateMtlUsage(o.ID) = 1
		) oq on oq.Article = tot.Article
		inner join #tmpPO_Supp_Detail po3
			on po3.SCIRefNo = tot.SCIRefNo
			and po3.ColorID = tot.ColorID
			and po3.SuppColor = tot.SuppColor
			and po3.ID = @CurPoID
		where tot.StyleUkey = @StyleUkey
			and po3.Seq1 like 'T%'
			and EXISTS(select 1 from Trade.dbo.MachineType_ThreadRatio mt where mt.ID = tot.MachineTypeID and mt.Seq = tot.Seq)
		group by po3.Seq1, po3.Seq2, oq.ID, po3.Seq2_Count

		select @PoComboCount = count(*) from dbo.Orders where Orders.POID = @CurPoID

		--當OrderList數不等於 Po Combo數時才寫入
		Insert Into #tmpPO_Supp_Detail_OrderList
		(ID, Seq1, Seq2, OrderID, Seq2_Count)
		select @CurPoID, Seq1, Seq2, ID, Seq2_Count from #tmp tmp
		outer apply (select count(*) c from #tmp where tmp.Seq2_Count = Seq2_Count) Count
		where Count.c != @PoComboCount

		set @ComboListRowID += 1;
	End
	
	delete po3 
    from #tmpPO_Supp_Detail po3 
	inner join #tmpPO_Supp po2 on po3.ID = po2.ID and po3.Seq1 = po2.Seq1
    inner join Trade.dbo.Supp s on po2.SuppID = s.ID
	where s.Junk = 1 Or s.LockDate is not null

    delete po2
    From #tmpPO_Supp po2
    Inner join Trade.dbo.Supp s on po2.SuppID = s.ID
    where po2.Junk = 1 Or s.Junk = 1 Or s.LockDate is not null

	--2020/11/20 [IST20202042] 更新Qty和Foc，若物料IsFOC = 1 則將新增的Qty更新至Foc
	Update #tmpPO_Supp_Detail
	Set Qty = iif(f.IsFOC = 1, 0, po3.Qty)
		, Foc = iif(f.IsFOC = 1, po3.Qty + po3.FOC, po3.FOC)
	From #tmpPO_Supp_Detail po3
	Left Join Trade.dbo.Fabric f On f.SCIRefno = po3.SCIRefNo
	Where po3.Status = 1

	Insert Into #tmpPO_Supp_Detail_Spec
		(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
	Select ID, Seq1, Seq2, 'Color', ColorID, Seq2_Count
	From #tmpPO_Supp_Detail
	Where Seq1 like 'T%'

	--select * from #tmpFinal
	--select * from #tmpQT
	--select * from #tmpResult
	--select * from #ComboList
	--select * from #tmpPO_Supp
	--select * from #tmpPO_Supp_Detail
	--select * from #tmpPO_Supp_Detail_OrderList

	--drop table #tmpPO_Supp
	--drop table #tmpPO_Supp_Detail
	--drop table #tmpPO_Supp_Detail_OrderList
	--drop table #ComboList

	IF OBJECT_ID('tempdb..#tmpTtlQty') IS NOT NULL DROP TABLE #tmpTtlQty
	drop table #tmpOpThread
	drop table #tmpOpThread2
	drop table #tmpFinal
	drop table #tmpQT
	drop table #tmpResult
	drop table #SameSCIGroup
	drop table #tmp
End
GO

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_1_ForThreadAllowance', 'Trade';
Go