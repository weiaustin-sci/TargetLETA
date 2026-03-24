Use [Trade]
Go
/****** Object:  StoredProcedure [dbo].[TransferToPO_1_ForBOF]    Script Date: 2015/10/20 上午 10:06:43 ******/
Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Ben
-- Create date: 2015/11/09
-- Description:
--		Transfer To PO - BOF
-- =============================================
If Object_Id ( 'dbo.TransferToPO_1_ForBOF', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_1_ForBOF;
Go

Create Procedure [dbo].[TransferToPO_1_ForBOF]
	(
	  @PoID			VarChar(13)		--採購母單
	 ,@BrandID		VarChar(8)
	 ,@ProgramID	VarChar(12)
	 ,@Category		VarChar(1)
	 ,@TestType		Int				--資料來源是否為暫存檔
	 ,@IsExpendArticle	Bit			= 0			--add by Edward 是否展開至Article，For U.A轉單
	)
As
Begin
	Set NoCount On;
	----------------------------------------------------------------------
	If Object_ID('tempdb..#tmpPO_Supp') Is Null
	Begin
		/*
		Select * Into #tmpPO_Supp
		  From dbo.PO_Supp
		 Where 1 = 2;
		*/
		
		Create Table #tmpPO_Supp
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), SuppID VarChar(6) default '', ShipTermID VarChar(5) default '', PayTermAPID VarChar(5) default ''
			 , Remark NVarChar(Max) default '', Description NVarChar(Max) default '', CompanyID Numeric(2,0) default 0
			 , StyleID VarChar(15), TargetLETA Date, Junk Bit, Primary Key (ID, Seq1)
			);
		
	End;
	If Object_ID('tempdb..#tmpPO_Supp_Detail') Is Null
	Begin
		/*
		Select * Into #tmpPO_Supp_Detail
		  From dbo.PO_Supp_Detail
		 Where 1 = 2;
		Select * Into #tmpPO_Supp_Detail_OrderList
		  From dbo.PO_Supp_Detail_OrderList
		 Where 1 = 2;
		*/
		
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
	----------------------------------------------------------------------
	Declare @ExceptRowCount Int;

	Declare @IsMiAdidas Bit;
	Declare @HavePo_Supp Bit;
	Declare @HaveFormA Bit;
	Declare @HaveECFA Bit;
	Declare @CountSeq1 Int;
	Declare @IsExist_Supp Bit;
	Declare @Seq1 VarChar(3);
	Declare @Seq1_New VarChar(3);
	Declare @Seq1_AscII Int;
	Declare @SuppCountry VarChar(2);
	Declare @MtlFormA Bit;
	----------------------------------------------------------------------
	Declare @Seq2 VarChar(2);
	Declare @Seq2_Count Int;
	Declare @UsedQty Numeric(10,4);
	Declare @UnitRound Numeric(2,0);
	Declare @UsageRound Numeric(2,0);
	Declare @RoundStep Numeric(4,2);
	Declare @NetQty Numeric(29,18);
	Declare @LossQty Numeric(29,18);
	Declare @SystemNetQty Numeric(29,18);
	Declare @BatchQty Numeric(10,2);
	Declare @PurchaseQty Numeric(12,2);
	Declare @Remark NVarChar(Max);
	Declare @Remark_Shell NVarChar(Max);	
	----------------------------------------------------------------------
	Declare @FabricLoss Table
		(  RowID BigInt Identity(1,1) Not Null, SciRefNo VarChar(30), FabricCode VarChar(3), ColorID VarChar(6)
		 , Special NVarChar(Max)
		 , RealLoss Numeric(10,4)
		);
	Insert Into @FabricLoss
		(SciRefNo, FabricCode, ColorID, Special, RealLoss)
		Select SciRefNo, FabricCode, ColorID, '', sum(RealLoss)
		  From dbo.GetLossFabric(@PoID, '', @IsExpendArticle) as tmpLoss
		  group by SciRefNo, FabricCode, ColorID
		 Order by FabricCode, ColorID;

	Declare @tempSeq1 VarChar(3);
	Declare @tempSuppID VarChar(6);
	Declare @tempSupp_Seq1 Table
		(RowID BigInt Identity(1,1) Not Null, Seq1 VarChar(3), SuppID VarChar(6));
	Declare @tempSupp_Seq1RowID Int;		--Row ID
	Declare @tempSupp_Seq1RowCount Int;	--總資料筆數

	Declare @BofUkey BigInt;
	Declare @FabricType VarChar(1);
	Declare @FabricCode VarChar(3);
	Declare @RefNo VarChar(36);
	Declare @SCIRefNo VarChar(30);
	Declare @SuppID VarChar(6);
	Declare @ColorDetail NVarChar(Max);
	Declare @BofRemark NVarChar(Max);
	Declare @POUnit VarChar(8);
	Declare @IsECFA Bit;
	Declare @HaveShell Bit;
	Declare @tmpOrder_BOF Table
		(  RowID BigInt Identity(1,1) Not Null, BofUkey BigInt, FabricType VarChar(1), FabricCode VarChar(3)
		 , RefNo VarChar(36), SCIRefNo VarChar(30), SuppID VarChar(6)
		 , Seq1 VarChar(3), ColorDetail NVarChar(Max), BofRemark NVarChar(Max), POUnit VarChar(8)
		 , IsECFA Bit, HaveShell Bit
		);
	Declare @tmpOrder_BOFRowID Int;		--Row ID
	Declare @tmpOrder_BOFRowCount Int;	--總資料筆數
	
	Declare @Bof_ExpendUkeys varchar(MAX);
	Declare @ColorID VarChar(6);
	Declare @SuppColor NVarChar(Max);
	Declare @OrderQty Numeric(10,4);
	Declare @Price Numeric(14,4);
	Declare @UsageQty Numeric(12,2);
	Declare @UsageUnit VarChar(8);
	Declare @Width Numeric(5, 2);
	Declare @SysUsageQty Numeric(10,2);
	Declare @ExpendRemark NVarChar(max);
	Declare @Special NVarChar(max);
	Declare @tmpOrder_BOF_Expend Table
		(  RowID BigInt Identity(1,1) Not Null, Bof_ExpendUkeys varchar(max), ColorID VarChar(6), SuppColor NVarChar(Max)
		 , OrderQty Numeric(10,4), Price Numeric(14,4), UsageQty Numeric(10,2), UsageUnit VarChar(8)
		 , Width Numeric(5, 2), SysUsageQty Numeric(10,2), ExpendRemark NVarChar(max), Special NVarChar(max)
		);
	Declare @tmpOrder_BOF_ExpendRowID Int;		--Row ID
	Declare @tmpOrder_BOF_ExpendRowCount Int;	--總資料筆數

	-- 判斷是否要忽略Remark條件
	Declare @IsIgnoreRemark bit = (Select Trade.dbo.CheckIgnore(@POID, 'TransferIgnoreRemark', 'SCISeason'));
	----------------------------------------------------------------------
	Insert Into @tmpOrder_BOF
		(  BofUkey, FabricType, FabricCode, RefNo, SCIRefNo
		 , SuppID, Seq1, ColorDetail, BofRemark
		 , POUnit, IsECFA, HaveShell
		)
		Select Order_BOF.Ukey, Fabric.Type, Order_BOF.FabricCode, Order_BOF.RefNo, Order_BOF.SciRefNo
			 , supp.NewSupp, Order_BOF.Seq1, Order_BOF.ColorDetail, Order_BOF.Remark
			 , IsNull(Fabric_Supp.POUnit, '') as POUnit, ifa.IsECFA as IsECFA
			 , IsNull((Select Top 1 1 From dbo.Order_BOF_Shell Where Order_BOFUkey = Order_BOF.Ukey), 0) as HaveShell
		  From dbo.Order_BOF
		  Left Join Trade.dbo.Fabric
			On Fabric.SCIRefno = Order_BOF.SCIRefno
		  Left Join Trade.dbo.MtlType mt on Fabric.MtltypeId = mt.ID
		  inner join dbo.Orders on Order_BOF.ID = Orders.ID
		  left join dbo.Factory on Orders.FactoryID = Factory.ID
		  Outer apply ( select dbo.GetECFA_Refno(Order_BOF.Id, Order_BOF.SuppID, Fabric.SCIRefno) as IsECFA) ifa
		  Outer apply ( select NewSupp = iif(ifa.IsECFA = 1, Order_BOF.SuppID, dbo.GetReplaceSupp_ByPOCombo(Order_BOF.SuppID, Order_BOF.SCIRefno, Orders.ID))) supp
		  Left Join Trade.dbo.Fabric_Supp
			On	   Fabric_Supp.SCIRefno = Order_BOF.SCIRefno
			   And Fabric_Supp.SuppID = supp.NewSupp
		  Outer apply (Select Junk, Lock From dbo.CheckFabricUseful(Fabric.SCIRefno, Orders.SeasonID, supp.NewSupp)) cfu
		 Where Order_BOF.ID = @PoID
		 and (@Category != 'G' or (@Category = 'G' and mt.AllowTransPoForGarmentSP = 1 and supp.NewSupp != 'FTY'))
		 And cfu.Lock = 0 And cfu.Junk = 0
		 Order by Seq1, IsECFA, NewSupp, FabricCode, SCIRefNo;
	----------------------------------------------------------------------
	--建立虛擬Table
	If object_id('tempdb..#Tmp_BofExpend_All') is not null
	Drop table #Tmp_BofExpend_All

	Create Table #Tmp_BofExpend_All
	(  ExpendUkey BigInt Identity(1,1) Not Null, ID Varchar(13), Order_BOFUkey BigInt, ColorID Varchar(6), SuppColor NVarchar(Max)
		 , OrderQty Numeric(10,4), Price Numeric(9,4), UsageQty Numeric(9,2) ,UsageUnit Varchar(8)
		 , Width Numeric(5,2), SysUsageQty Numeric(9,2), QTFabricPanelCode NVarchar(100), Remark NVarchar(max), OrderList NVarchar(max), ColorDesc varchar(150)
		 , Special VarChar(Max)
		 , Primary Key (ExpendUkey)
		 , Index Idx_ID NonClustered (ID, Order_BOFUkey, ColorID) -- table index
		);

	If object_id('tempdb..#Tmp_BofExpend') is not null
	Drop table #Tmp_BofExpend

	Create Table #Tmp_BofExpend
	(  ExpendUkey BigInt Not Null, ID Varchar(13), Order_BOFUkey BigInt, ColorID Varchar(6), SuppColor NVarchar(Max)
		 , OrderQty Numeric(10,4), Price Numeric(9,4), UsageQty Numeric(9,2) ,UsageUnit Varchar(8)
		 , Width Numeric(5,2), SysUsageQty Numeric(9,2), QTFabricPanelCode NVarchar(100), Remark NVarchar(max)
		 , Special VarChar(Max)
		 , Primary Key (ExpendUkey)
		 , Index Idx_ID NonClustered (ID, Order_BOFUkey, ColorID) -- table index
		);

	If object_id('tempdb..#Tmp_BofExpend_OrderList') is not null
	Drop table #Tmp_BofExpend_OrderList

	Create Table #Tmp_BofExpend_OrderList
	(	ExpendUkey BigInt, ID Varchar(13), OrderID Varchar(13)
		Index Idx_ID NonClustered (ExpendUkey, ID, OrderID) -- table index
	);

	--是否為虛擬展開
	if @TestType = 1
	BEGIN		
		
		Insert Into #Tmp_BofExpend_All( ID ,Order_BOFUkey ,ColorID ,SuppColor ,OrderQty ,Price ,UsageQty ,UsageUnit
		,Width ,SysUsageQty ,QTFabricPanelCode ,Remark, OrderList, ColorDesc, Special )
		select ID ,Order_BOFUkey ,ColorID ,SuppColor ,OrderQty ,Price ,UsageQty ,UsageUnit
			,Width ,SysUsageQty ,QTFabricPanelCode ,Remark, OrderList, ColorDesc, Special
		from GetBOFExpend(@POID, @FabricCode, @IsExpendArticle)
		order by ColorID, Special, Width

		Declare @Keyword_xml xml;
		
		Declare @ExpendCursor Table
			(RowID BigInt Identity(1,1) Not Null, ExpendUkey BigInt);

		Declare @RowID Int;		--ID起始比數
		Declare @RowCount Int;	--總資料筆數		
		Declare @ExpendUkey BigInt;

		Insert Into @ExpendCursor (ExpendUkey)
		Select ExpendUkey From #Tmp_BofExpend_All;
		Set @RowID = 1
		--Select @RowCount = Count(*) From #Tmp_BoaExpend_All
		Select @RowID = Min(RowID), @RowCount = Max(RowID) From @ExpendCursor;
		While @RowID <= @RowCount
		Begin
			Select @ExpendUkey = ExpendUkey
			From @ExpendCursor
			Where RowID = @RowID;

			Insert Into #Tmp_BofExpend
			( ExpendUkey, ID, Order_BOFUkey, ColorID, SuppColor, OrderQty, Price, UsageQty
				 , UsageUnit, Width, SysUsageQty, QTFabricPanelCode, Remark
				 , Special
				)
			select ExpendUkey, ID, Order_BOFUkey, ColorID, SuppColor, OrderQty, Price, UsageQty
					 , UsageUnit, Width, SysUsageQty, QTFabricPanelCode, Remark, Special
			from #Tmp_BofExpend_All
			Where ExpendUkey = @ExpendUkey;

			Insert Into #Tmp_BofExpend_OrderList (ID, ExpendUkey, OrderID)
			Select ID, ExpendUkey, tmp.Data
			From #Tmp_BofExpend_All
			Cross Apply (Select * From dbo.SplitString(#Tmp_BofExpend_All.OrderList, ',') where Data <> '') as tmp
			Where ExpendUkey = @ExpendUkey;

			Set @RowID += 1
		END
	END
	ELSE
	BEGIN
		Insert Into #Tmp_BofExpend
		( ExpendUkey, ID, Order_BOFUkey, ColorID, SuppColor, OrderQty, Price, UsageQty
		 , UsageUnit, Width, SysUsageQty, QTFabricPanelCode, Remark, Special
		)
		select UKEY, ID, Order_BOFUkey, ColorID, SuppColor, OrderQty, Price, UsageQty
				 , UsageUnit, Width, SysUsageQty, QTFabricPanelCode, Remark, Special
		from Order_BOf_Expend
		WHERE Id = @PoID

		Insert Into #Tmp_BofExpend_OrderList (ID, ExpendUkey, OrderID)
		SELECT ID, Order_BOF_ExpendUkey, OrderID 
		FROM Order_BOF_Expend_OrderList
		WHERE ID = @PoID
	END

	----------------------------------------------------------------------
	--是否為Mi Adidas
	Set @IsMiAdidas = 0;
	Select @IsMiAdidas = MiAdidas
	  From Trade.dbo.Program
	 Where BrandID = @BrandID
	   And ID = @ProgramID;
	--訂單是否走FormA
	Set @HaveFormA = Trade.dbo.GetFormA(@PoID);
	--訂單是否走ECFA
	Set @HaveECFA = Trade.dbo.GetECFA(@PoID);
	----------------------------------------------------------------------
	--------------------Loop Start @tmpOrder_BOF--------------------
	Set @tmpOrder_BOFRowID = 1;
	Select @tmpOrder_BOFRowID = Min(RowID), @tmpOrder_BOFRowCount = Max(RowID) From @tmpOrder_BOF;
	While @tmpOrder_BOFRowID <= @tmpOrder_BOFRowCount
	Begin
		Select @BofUkey = BofUkey
			 , @FabricType = FabricType
			 , @FabricCode = FabricCode
			 , @RefNo = RefNo
			 , @SCIRefNo = SCIRefNo
			 , @SuppID = SuppID
			 , @Seq1 = Seq1
			 , @ColorDetail = ColorDetail
			 , @BofRemark = BofRemark
			 , @POUnit = POUnit
			 , @IsECFA = IsECFA
			 , @HaveShell = HaveShell
		  From @tmpOrder_BOF
		 Where RowID = @tmpOrder_BOFRowID;
		--------------------------------------
		Set @HavePo_Supp = 0;
		--------------------------------------
		Set @SuppCountry = '';
		Select @SuppCountry = CountryID
		  From Trade.dbo.Supp
		 Where ID = @SuppID;

		Set @MtlFormA = '';
		Select @MtlFormA = MtlFormA
		  From Trade.dbo.Country
		 Where ID = @SuppCountry;
		--------------------------------------
		--[Seq#1]編號
		--若有同編號不同Supplier，則補上第三碼
		/*
		--Local Supplier 之後補上--
		*/
		Select @CountSeq1 = Count(*)
		  From @tmpOrder_BOF
		 Where Seq1 = @Seq1;		

		Select @HaveECFA = iif(Count(distinct IsECFA) > 1, 1, 0)
		  From @tmpOrder_BOF
		 Where Seq1 = @Seq1;
		
		set @Seq1_New = '';

		If (@CountSeq1 <= 1)
		Begin
			Set @Seq1_New = Rtrim(@Seq1);
		End;
		Else
		Begin
			Set @IsExist_Supp = 0;

			Delete From @tempSupp_Seq1;
			Insert Into @tempSupp_Seq1
				(Seq1, SuppID)
				Select Seq1, SuppID
				  From #tmpPO_Supp
				 Where ID = @PoID
				   And Seq1 Like RTrim(@Seq1)+'%';

			if not EXISTS(select 1 from @tempSupp_Seq1) or EXISTS (select 1 from @tempSupp_Seq1 where suppID = @SuppID)
            BEGIN
                Set @Seq1_New = RTrim(@Seq1);
            end
			--------------------Loop Start @tempSupp_Seq1--------------------
			Set @tempSupp_Seq1RowID = 1;
			Select @tempSupp_Seq1RowID = Min(RowID), @tempSupp_Seq1RowCount = Max(RowID) From @tempSupp_Seq1;
			While @tempSupp_Seq1RowID <= @tempSupp_Seq1RowCount
			Begin
				Select @tempSeq1 = Seq1
					 , @tempSuppID = SuppID
				  From @tempSupp_Seq1
				 Where RowID = @tempSupp_Seq1RowID;
			
				If @tempSeq1 != @Seq1
				Begin
					If @tempSuppID = @SuppID
					Begin
						Set @Seq1_New = @tempSeq1;
						Set @IsExist_Supp = 1;
						Break;
					End;

					Set @Seq1_New = IIF(@tempSeq1 >= @Seq1_New, @tempSeq1, @Seq1_New);
				End;
				Set @tempSupp_Seq1RowID += 1;
			End;
			--------------------Loop End @tempSupp_Seq1--------------------
			If @Seq1_New = ''
			Begin
				Set @Seq1_New = RTrim(@Seq1)+'1';
			End;
			/*If @Seq1_New != '' And @IsExist_Supp = 0
			Begin
				Set @Seq1_AscII = AscII(SubString(@Seq1_New,3,1)) + 1;
				If @Seq1_AscII > 57
				Begin
					Set @Seq1_New = Rtrim(@Seq1)+Char(@Seq1_AscII+9);
				End;
				Else
				Begin
					Set @Seq1_New = Convert(VarChar(3), Convert(Numeric(3), @Seq1_New) + 1);
				End;
			End;*/
		End;
		
		--------------------------------------
		Delete From @tmpOrder_BOF_Expend;
		Insert Into @tmpOrder_BOF_Expend
			(Bof_ExpendUkeys, ColorID, SuppColor, OrderQty, Price, UsageQty, UsageUnit, Width
			 , SysUsageQty, ExpendRemark, Special
			)
			Select ukeys, ColorID, SuppColor, sum(OrderQty), max(Price), sum(UsageQty), UsageUnit, Width
				 , sum(SysUsageQty), getRemark.value, Special = ''
			  From #Tmp_BofExpend Order_BOF_Expend
			  outer apply (
				select ukeys = stuff((select ',' + cast(ExpendUkey as varchar(max)) 
				from #Tmp_BofExpend tmp 
				where tmp.Order_BOFUkey = Order_BOF_Expend.Order_BOFUkey 
					and tmp.ColorId = Order_BOF_Expend.ColorId 
					and tmp.SuppColor = Order_BOF_Expend.SuppColor 
					and tmp.UsageUnit = Order_BOF_Expend.UsageUnit 
					and tmp.Width = Order_BOF_Expend.Width 
					and (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and tmp.Remark = Order_BOF_Expend.Remark))
				for xml path('')),1,1,'')) uks
			 outer apply (
				select value = stuff((
					select Distinct Concat('$', Trade.dbo.ReplaceASCII(tmp.Remark))
					from #Tmp_BofExpend tmp 
					where tmp.Order_BOFUkey = Order_BOF_Expend.Order_BOFUkey 
					and tmp.ColorId = Order_BOF_Expend.ColorId 
					and tmp.SuppColor = Order_BOF_Expend.SuppColor 
					and tmp.UsageUnit = Order_BOF_Expend.UsageUnit 
					and tmp.Width = Order_BOF_Expend.Width 
					and (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and tmp.Remark = Order_BOF_Expend.Remark))
					for xml path(''), type).value('(./text())[1]','nvarchar(max)')
				, 1, 1 ,'')
				) getRemark
			 Where Order_BOFUkey = @BofUkey
			 group by ukeys, ColorId, SuppColor, UsageUnit, Width, getRemark.value
			 Order by ColorID, Special, Width;
		--------------------Loop Start @tmpOrder_BOF_Expend--------------------
		Set @tmpOrder_BOF_ExpendRowID = 1;
		Select @tmpOrder_BOF_ExpendRowID = Min(RowID), @tmpOrder_BOF_ExpendRowCount = Max(RowID) From @tmpOrder_BOF_Expend;
		While @tmpOrder_BOF_ExpendRowID <= @tmpOrder_BOF_ExpendRowCount
		Begin
			Select @Bof_ExpendUkeys = Bof_ExpendUkeys
				 , @ColorID = ColorID
				 , @SuppColor = SuppColor
				 , @OrderQty = OrderQty
				 , @Price = Price
				 , @UsageQty = UsageQty
				 , @UsageUnit = UsageUnit
				 , @Width = Width
				 , @SysUsageQty = SysUsageQty
				 , @ExpendRemark = ExpendRemark
				 , @Special = Special
			  From @tmpOrder_BOF_Expend
			 Where RowID = @tmpOrder_BOF_ExpendRowID;
			
			If @UsageQty < 0
			Begin
				Set @tmpOrder_BOF_ExpendRowID += 1;
				Continue;
			End;
			--------------------------------------
			--取得Remark
			SET @Remark = REPLACE(ISNULL(@ExpendRemark, ''), '$', ' ' + CHAR(13) + CHAR(10));
			set @Remark_Shell = '';
			If @HaveShell = 1
			Begin
				Set @Remark_Shell = IsNull(dbo.GetShellColor(@PoID, @FabricType, @BofUkey, ''), '');
				SET @Remark += IIF(@Remark = '', '', CHAR(13) + CHAR(10)) + @Remark_Shell;
			End;
		
			--------------------------------------
			--單件用量
			--Set @UsedQty = @UsageQty / @OrderQty;
			Set @UsedQty = @OrderQty;
			--------------------------------------
			--取得無條件進位的小數位數
			Set @UnitRound = 0;
			Set @UsageRound = 0;
			Set @RoundStep = 0;
			Select @UnitRound = UnitRound
				 , @UsageRound = UsageRound
				 , @RoundStep = RoundStep
			  From Trade.dbo.GetUnitRound(@BrandID, @ProgramID, @Category, @UsageUnit);
			--------------------------------------
			--採購數量(單位換算)
			Set @NetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @UsageQty);
			Set @SystemNetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @SysUsageQty);
			--------------------------------------
			--損耗數(Loss Qty)
			Set @LossQty = 0;
			Select @LossQty = RealLoss
			  From @FabricLoss
			 Where SciRefNo = @SCIRefNo
			   And FabricCode = @FabricCode
			   And ColorID = @ColorID
			   And Special = @Special;
			
			--損耗數(單位換算)
			Set @LossQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @LossQty);
			--------------------------------------
			--無條件進位
			--NetQty & LossQty 均無條件進位至小數一位
			Set @NetQty = Trade.dbo.GetCeiling(@NetQty, @UsageRound, 0);
			Set @SystemNetQty = Trade.dbo.GetCeiling(@SystemNetQty, @UnitRound, 0);
			Set @LossQty = Trade.dbo.GetCeiling(@LossQty, @UsageRound, 0);
			--------------------------------------
			--採購Qty
			Set @PurchaseQty = Trade.dbo.GetCeiling((@NetQty + @LossQty), @UnitRound, @RoundStep);
			--------------------------------------
			If @PurchaseQty > 0
			Begin
				Set @HavePo_Supp = 1;

				Set @Seq2 = '';

				If @Category = 'M'
				Begin
					Set @NetQty = 0;
					Set @LossQty = 0;
				End;			

				Select @Seq2_Count = Max(po3.Seq2_Count)
				From #tmpPO_Supp_Detail po3
				Where po3.ID = @PoID
					And po3.Seq1 = @Seq1_New
					And po3.SCIRefNo = @SCIRefNo
					And po3.ColorID = @ColorID

				If IsNull(@Seq2_Count, 0) != 0
				Begin
					--Update Temp Table - PO_Supp_Detail
					Update #tmpPO_Supp_Detail
					   Set Qty += @PurchaseQty
						 , NetQty += @NetQty
						 , LossQty += @LossQty
						 , SystemNetQty += @SystemNetQty
					 Where ID = @PoID
					   And Seq1 = @Seq1_New
					   And Seq2 = @Seq2
					   And Seq2_Count = @Seq2_Count;
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_OrderList
					--當OrderList數不等於 Po Combo數時才寫入
					Set @ExceptRowCount = (	Select Count(*)
											From (
												Select ID From dbo.Orders
												Where PoID = @PoID 
												Except
												Select OrderID
												From #Tmp_BofExpend_OrderList
												Where ExpendUkey in (select data from Trade.dbo.SplitString(@Bof_ExpendUkeys, ','))
											) as tmpCount
										  );
				
					If @ExceptRowCount > 0
					Begin
						Insert Into #tmpPO_Supp_Detail_OrderList
						(ID, Seq1, Seq2, OrderID, Seq2_Count)
						Select DISTINCT @PoID, @Seq1_New, @Seq2, OrderID, @Seq2_Count
						From #Tmp_BofExpend_OrderList Order_BOF_Expend_OrderList
						Where Order_BOF_Expend_OrderList.ExpendUkey in (select data from Trade.dbo.SplitString(@Bof_ExpendUkeys, ','))
						and not exists (select 1 from #tmpPO_Supp_Detail_OrderList p4 where p4.ID = @PoID and p4.Seq1 = @Seq1_New and p4.Seq2 = @Seq2 and p4.OrderID = Order_BOF_Expend_OrderList.OrderID and p4.Seq2_Count = @Seq2_Count);
					End;
				End
				Else
				Begin
					Select @Seq2_Count = IsNull(Max(Seq2_Count), 0) + 1
					From #tmpPO_Supp_Detail
					Where ID = @PoID
					And Seq1 = @Seq1_New;
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail
					Insert Into #tmpPO_Supp_Detail
						(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
						 , ColorID, SuppColor, Remark, Remark_Shell, Width, NetQty, LossQty, SystemNetQty
						 , ColorDetail
						 , Seq2_Count
						 , Special
						)
					Values
						(  @PoID, @Seq1_New, @Seq2, @RefNo, @SCIRefNo, @FabricType, @Price, @UsedQty, @PurchaseQty, @POUnit
						 , RTrim(LTrim(@ColorID)), @SuppColor, @Remark, @Remark_Shell, @Width, @NetQty, @LossQty, @SystemNetQty
						 , @ColorDetail
						 , @Seq2_Count
						 , @Special
						);
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_OrderList
					--當OrderList數不等於 Po Combo數時才寫入
					Set @ExceptRowCount = (	Select Count(*)
											  From (Select ID From dbo.Orders
													 Where PoID = @PoID 
													Except
													Select OrderID
													  From #Tmp_BofExpend_OrderList
													 Where ExpendUkey in (select data from Trade.dbo.SplitString(@Bof_ExpendUkeys, ','))
												   ) as tmpCount
										  );
				
					If @ExceptRowCount > 0
					Begin
						Insert Into #tmpPO_Supp_Detail_OrderList
							(ID, Seq1, Seq2, OrderID, Seq2_Count)
							Select DISTINCT @PoID, @Seq1_New, @Seq2, OrderID, @Seq2_Count
							  From #Tmp_BofExpend_OrderList
							 Where ExpendUkey in (select data from Trade.dbo.SplitString(@Bof_ExpendUkeys, ','));
					End;
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_Spec
					Insert Into #tmpPO_Supp_Detail_Spec
						(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
					Values
						(@PoID, @Seq1_New, @Seq2, 'Color', @ColorID, @Seq2_Count);
					--------------------------------------
				End				
			End;
			Set @tmpOrder_BOF_ExpendRowID += 1;
		End;
		--------------------Loop End @tmpOrder_BOF_Expend--------------------
		--------------------------------------
		--寫入Temp Table - PO_Supp
		If @HavePo_Supp = 1
		Begin
			If Not Exists(Select * From #tmpPO_Supp Where ID = @PoID And Seq1 = @Seq1_New)
			Begin
				Insert Into #tmpPO_Supp
					(ID, Seq1, SuppID)
				Values
					(@PoID, @Seq1_New, @SuppID);
			End;
		End;
		--------------------------------------
		Set @tmpOrder_BOFRowID += 1;
	End;
	--------------------Loop End @tmpOrder_BOF--------------------

	--2020/11/20 [IST20202042] 更新Qty和Foc，若物料IsFOC = 1 則將Qty更新至Foc
	Update #tmpPO_Supp_Detail
	Set Qty = iif(f.IsFOC = 1, 0, po3.Qty)
		, Foc = iif(f.IsFOC = 1, po3.Qty + po3.FOC, po3.FOC)
	From #tmpPO_Supp_Detail po3
	Left Join Trade.dbo.Fabric f On f.SCIRefno = po3.SCIRefNo

	--Select * From #tmpPO_Supp;
	--Select * From #tmpPO_Supp_Detail;
	--Select * From #tmpPO_Supp_Detail_OrderList;
End

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_1_ForBOF';
Go
