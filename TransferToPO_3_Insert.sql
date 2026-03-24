Use [Trade]
Go

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Ben
-- Create date: 2015/11/13
-- Description:
--		Transfer To PO
-- =============================================
If Object_Id ( 'dbo.TransferToPO_3_Insert', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_3_Insert;
Go

Create Procedure [dbo].[TransferToPO_3_Insert]
	(
	  @PoID			VarChar(13)		--採購母單
	 ,@Seq1_Start	VarChar(3)		--採購大項區間(起)
	 ,@Seq1_End		VarChar(3)		--採購大項區間(迄)
	 ,@PoHandle		VarChar(10)
	 ,@PoSMR		VarChar(10)
	 ,@AppType		Bit				--重新產生資料時是否要覆蓋原始資料
	 ,@UserID		VarChar(10)
	 ,@AutoInput	Bit	 = 	0		--是否要自動入庫
	 ,@AutoInputReason	varchar(5)	 = 	''		--是否要自動入庫
	)
As
Begin
	Set NoCount On;

	Declare @NowDateTime DateTime = GetDate();
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
			 , SuppColor NVarChar(Max) default '', SizeSpec VarChar(15) default '', SizeUnit VarChar(8) default ''
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
			 , Primary Key (ID, Seq1, Seq2)
			);
		Create Table #tmpPO_Supp_Detail_OrderList
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), OrderID VarChar(13)
			 , Primary Key (ID, Seq1, Seq2, OrderID)
			);
		Create Table #tmpPO_Supp_Detail_Spec
		(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), SpecColumnID VarChar(50), SpecValue VarChar(50), Seq2_Count Int
			, Primary Key (ID, Seq1, Seq2, SpecColumnID, Seq2_Count)
		);
		Create Table #tmpPO_Supp_Detail_Keyword
		(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), KeywordField VarChar(30), KeywordValue VarChar(200), Seq2_Count Int
			, Primary Key (ID, Seq1, Seq2, KeywordField, Seq2_Count)
		);
		
	End;
	----------------------------------------------------------------------
	--2018.05.07 modify by Ben, 第三碼是因為小項超過99項，由系統自動產生，所以轉單區間，僅須輸入前兩碼，但須包含第三碼一起轉至PO
	If @Seq1_End != '' And Len(@Seq1_End) = 2
	Begin
		Set @Seq1_End += 'Z';
	End
	----------------------------------------------------------------------
	Declare @IsExistPo_Supp Int = 0;
	Declare @IsExistPo_Supp_Detail Int = 0;
	
	Select Top 1 @IsExistPo_Supp = 1 From #tmpPO_Supp Where ID = @PoID;

	--因為transfer2po那邊會卡條件產生po_Supp,po_Supp_Detail的資料, 如果資料是空的話,應該連po都不產生
	/*If @IsExistPo_Supp = 0
	Begin
		Return;
	End;*/
	
	Declare @ShipMark NVarCHar(Max);
	
	Declare @Seq1 VarChar(3);
	Declare @SuppID VarChar(6);
	Declare @ShipTermID VarChar(5);
	Declare @PayTermAPID VarChar(5);
	Declare @Remark NVarChar(Max);
	Declare @Remark_Shell NVarChar(Max);	
	Declare @Description NVarChar(Max);
	Declare @CompanyID Numeric(2,0);
	
	Declare @Seq2 VarChar(2);
	Declare @RefNo VarChar(36);
	Declare @SciRefNo VarChar(30);
	Declare @FabricType VarChar(1);
	Declare @Price Numeric(14,4);
	Declare @UsedQty Numeric(10,4);
	Declare @Qty Numeric(10,2);
	Declare @POUnit VarChar(8);
	Declare @Complete Bit;
	Declare @SystemETD Date;
	Declare @CFMETD Date;
	Declare @RevisedETD Date;
	Declare @FinalETD Date;
	Declare @EstETA Date;
	Declare @ShipModeID VarChar(10);
	Declare @PrintDate DateTime;
	Declare @PINO VarChar(25);
	Declare @PIDate Date;
	Declare @ColorID VarChar(6);
	Declare @SuppColor NVarChar(Max);
	Declare @SizeSpec VarChar(15);
	Declare @SizeUnit VarChar(8);
	Declare @Detail_Remark NVarChar(Max);
	Declare @Special NVarChar(Max);
	Declare @Spec NVarChar(Max);
	Declare @Width Numeric(5, 2);
	Declare @StockQty Numeric(12,1);
	Declare @NetQty Numeric(10,2);
	Declare @LossQty Numeric(10,2);
	Declare @SystemNetQty Numeric(10,2);
	Declare @SystemCreate bit;
	Declare @FOC Numeric(10,2);
	Declare @Junk bit;
	Declare @ColorDetail NVarChar(Max);
	Declare @BomZipperInsert VarChar(5);
	Declare @BomCustPONo VarChar(30);
	Declare @ShipQty Numeric(10,2);
	Declare @Shortage Numeric(10,2);
	Declare @ShipFOC Numeric(10,2);
	Declare @ApQty Numeric(10,2);
	Declare @InputQty Numeric(10,2);
	Declare @OutputQty Numeric(10,2);
	Declare @ShipETA Date;
	Declare @SystemLock Date;
	Declare @OutputSeq1 VarChar(3);
	Declare @OutputSeq2 VarChar(2);
	Declare @Detail_FactoryID VarChar(8);
	Declare @StockPOID VarChar(13);
	Declare @StockSeq1 VarChar(3);
	Declare @StockSeq2 VarChar(2);
	Declare @InventoryUkey bigint;
	Declare @CannotOperateStock bit;
	Declare @Keyword_Original varchar(max);

	Declare @tmpPo_SuppRowID Int;		--Row ID
	Declare @tmpPo_SuppRowCount Int;	--總資料筆數

	Declare @tmpPo_Supp_DetailRowID Int;	--Row ID
	Declare @tmpPo_Supp_DetailRowCount Int;	--總資料筆數
	------------------------------------------------------------------
	Declare @IsFabricExist Bit = 0;
	Declare @FabricJunk Bit = 0;
	Declare @FabricLock Bit = 0;
	Declare @SeasonID varchar(10);
	Declare @SciRefNo_New VarChar(30);

	Declare @CreateA Bit = 0;
	Declare @HaveA1 Bit = 0;
	Declare @HaveA2 Bit = 0;
	--------------------Loop Start #tmpPO_Supp_Detail--------------------
	Set @tmpPo_Supp_DetailRowID = 1;
	Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From #tmpPO_Supp_Detail Where ID = @PoID And SubString(Seq1,1,1) = 'A'
	While @tmpPo_Supp_DetailRowID <= @tmpPo_Supp_DetailRowCount
	Begin
		Select @Seq1 =#tmpPO_Supp_Detail.Seq1
			 , @Seq2 =#tmpPO_Supp_Detail.Seq2
			 , @SuppID =#tmpPO_Supp.SuppID
			 , @RefNo = #tmpPO_Supp_Detail.RefNo
			 , @SciRefNo = #tmpPO_Supp_Detail.SCIRefNo
		  From #tmpPO_Supp_Detail
		  Left Join #tmpPO_Supp
			On	   #tmpPO_Supp.ID = #tmpPO_Supp_Detail.ID
			   And #tmpPO_Supp_Detail.Seq1 = #tmpPO_Supp_Detail.Seq1
		 Where #tmpPO_Supp_Detail.RowId = @tmpPo_Supp_DetailRowID
		   And #tmpPO_Supp_Detail.ID = @PoID
		   And SubString(#tmpPO_Supp_Detail.Seq1,1,1) = 'A';
		
		Set @CreateA = 0;
		--產生A1項的時候，該料號被junk 或 lock時，須以新的SCIRefNo判斷更新回po_Supp_Detail
		Select @SeasonID = SeasonID From PO where ID = @PoID;
		Select Top 1 @IsFabricExist = 1 From Trade.dbo.Fabric Where Fabric.SCIRefNo = @SciRefNo;
		If @IsFabricExist = 1
		Begin
			Select @FabricJunk = cfu.Junk
				 , @FabricLock = cfu.Lock
			 From dbo.CheckFabricUseful(@SciRefNo, @SeasonID, @SuppID) cfu;
			
			If @FabricJunk = 1 Or @FabricLock = 1
			Begin
				--不存在現行採購單中
				Select Top 1 @SciRefNo_New = @SciRefNo
				  From dbo.PO_Supp_Detail
				 Where PO_Supp_Detail.ID = @PoID
				   And PO_Supp_Detail.RefNo = @RefNo
				   And SubString(PO_Supp_Detail.Seq1,1,1) != '7'
				 Order by ID, Seq1, Seq2;
				
				If @@RowCount > 0
				Begin
					--將SciRefNo換成線上的SciRefNo
					Update #tmpPO_Supp_Detail Set SCIRefNo = @SciRefNo_New
					 Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;
					
					Set @CreateA = 1;
				End;
			End;
			Else
			Begin
				Set @CreateA = 1;
			End;
		End;

		If @CreateA = 0
		Begin
			Delete From #tmpPO_Supp_Detail Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;
			Delete From #tmpPO_Supp_Detail_OrderList Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;
		End;
		Else
		Begin
			If @Seq1 = 'A1'
			Begin
				Set @HaveA1 = 1;
			End;
			If @Seq1 = 'A2'
			Begin
				Set @HaveA2 = 1;
			End;
		End;

		Set @tmpPo_Supp_DetailRowID += 1;
	End;
	--------------------Loop End #tmpPO_Supp_Detail--------------------
	If @HaveA1 = 0
	Begin
		Delete From #tmpPO_Supp Where ID = @PoID And Seq1 = 'A1';
	End;
	If @HaveA2 = 0
	Begin
		Delete From #tmpPO_Supp Where ID = @PoID And Seq1 = 'A2';
	End;
	------------------------------------------------------------------
	Declare @IsPoExist Int = 0;
	Declare @BrandID VarChar(8);
	Declare @StyleID VarChar(15);
	Declare @StyleUkey BigInt;
	Declare @FactoryID VarChar(8);
	Declare @Category VarChar(1);
	Declare @FTYMark VarChar(20);
	Declare @SystemETD_SpecialRule int;
	Declare @TargetLETA Date;
	
	Select @BrandID = Orders.BrandID
		 , @StyleID = Orders.StyleID
		 , @SeasonID = Orders.SeasonID
		 , @StyleUkey = Orders.StyleUkey
		 , @FactoryID = Orders.FactoryID
		 , @Category = Orders.Category
		 , @FTYMark = GetShippingMarkCode.ShipMark
	  From dbo.Orders
	  Outer Apply (Select ShipMark from Trade.dbo.GetShippingMarkCode(Orders.FactoryID, Orders.BrandID, Orders.Category, '', Orders.OrderCompany)) GetShippingMarkCode
	 Where Orders.ID = @PoID;

	-- 2023.02.14 add by Vicky [IST20230130]
	Select @SystemETD_SpecialRule = SystemETD_SpecialRule From Trade.dbo.Brand with(nolock) Where ID = @BrandID
	If @SystemETD_SpecialRule = 1
	Begin
		Select top 1 @TargetLETA = TargetLETA From #tmpPO_Supp Where ID = @PoID
	End

	Begin Try
		Begin Transaction;

		--判斷是否已成立過PO
		Select Top 1 @IsPoExist = 1 From dbo.PO Where PO.ID = @PoID;
		If @IsPoExist = 0
		Begin
			Set @ShipMark = dbo.GetShippingMark(@FactoryID, @PoID, @StyleID, @SeasonID, @PoHandle);
		
			Insert Into dbo.Po
				(ID, StyleUkey, BrandID, StyleID, SeasonId, POSMR, POHandle, PCSMR, PCHandle, ShipMark, FTYMark, TargetLETA, AddName, AddDate)
			Values
				(@PoID, @StyleUkey, @BrandID, @StyleID, @SeasonId, @PoSMR, @PoHandle, @PoSMR, @PoHandle, @ShipMark, @FTYMark, @TargetLETA, @UserID, @NowDateTime);
		End;
		Else
		Begin
			If @AppType = 0
			Begin
				Insert Into PO_Modify (ID, FieldId, Oldvalue, NewValue, AddName, AddDate)
				Select ID, 'TargetLETA', TargetLETA, @TargetLETA, @UserID, @NowDateTime
				From Trade.dbo.PO
				Where ID = @POID and @SystemETD_SpecialRule = 1 and isnull(TargetLETA, '') != isnull(@TargetLETA, '')

				Set @ShipMark = dbo.GetShippingMark(@FactoryID, @PoID, @StyleID, @SeasonID, @PoHandle);
				Update dbo.PO Set ShipMark = @ShipMark
								, FTYMark = @FTYMark
								, TargetLETA = iif(@SystemETD_SpecialRule = 1, @TargetLETA, TargetLETA)
								, EditName = @UserID
								, EditDate = @NowDateTime
				Where Po.ID = @PoID;
			End;
		End;
		--------------------Loop Start #tmpPO_Supp--------------------
		Set @tmpPo_SuppRowID = 1;
		Select @tmpPo_SuppRowID = Min(RowID), @tmpPo_SuppRowCount = Max(RowID) From #tmpPO_Supp
		 Where ID = @PoID
		   And (   (@Seq1_Start = '' And @Seq1_End = '')
				Or (@Seq1_Start != '' And @Seq1_End != '' And Seq1 Between @Seq1_Start And @Seq1_End)
			   )
		While @tmpPo_SuppRowID <= @tmpPo_SuppRowCount
		Begin
			Select @Seq1 = #tmpPO_Supp.Seq1
				 , @SuppID = #tmpPO_Supp.SuppID
				 , @ShipTermID = #tmpPO_Supp.ShipTermID
				 , @PayTermAPID = #tmpPO_Supp.PayTermAPID
				 , @Remark = #tmpPO_Supp.Remark
				 , @Description = #tmpPO_Supp.Description
				 , @CompanyID = #tmpPO_Supp.CompanyID
			  From #tmpPO_Supp
			 Where RowID = @tmpPo_SuppRowID
			   And ID = @PoID
			   And (   (@Seq1_Start = '' And @Seq1_End = '')
					Or (@Seq1_Start != '' And @Seq1_End != '' And Seq1 Between @Seq1_Start And @Seq1_End)
				   )
			
			Set @IsExistPo_Supp = 0;
			Select Top 1 @IsExistPo_Supp = 1 From dbo.PO_Supp Where ID = @PoID And Seq1 = @Seq1;
			If @IsExistPo_Supp = 0
			Begin
				Insert Into dbo.PO_Supp
					(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, AddName, AddDate)
				Values
					(@PoID, @Seq1, @SuppID, @ShipTermID, @PayTermAPID, @Remark, @Description, @CompanyID, @UserID, @NowDateTime);
			End;
			Else
			Begin
				If @AppType = 0
				Begin
					Update dbo.PO_Supp
					   Set SuppID = @SuppID
						 , ShipTermID = @ShipTermID
						 , PayTermAPID = @PayTermAPID
						 , Remark = @Remark
						 , [Description] = @Description
						 , CompanyID = @CompanyID
						 , EditName = @UserID
						 , EditDate = @NowDateTime
					 Where ID = @PoID
					   And Seq1 = @Seq1;
				
					Delete From dbo.PO_Supp_Detail Where ID = @PoID And Seq1 = @Seq1;
					Delete From dbo.PO_Supp_Detail_OrderList Where ID = @PoID And Seq1 = @Seq1;
					Delete From dbo.PO_Supp_Detail_Spec Where ID = @PoID And Seq1 = @Seq1;
					Delete From dbo.PO_Supp_Detail_Keyword Where ID = @PoID And Seq1 = @Seq1;

					-- [IST20210476] 一併刪除Material O.Standing 的資料
					Delete From dbo.PO_MTLOstanding Where ID = @PoID And Seq1 = @Seq1;
				End;
			End;
			--------------------Loop Start #tmpPO_Supp_Detail--------------------
			Set @tmpPo_Supp_DetailRowID = 1;
			Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From #tmpPO_Supp_Detail Where ID = @PoID And Seq1 = @Seq1;
			While @tmpPo_Supp_DetailRowID <= @tmpPo_Supp_DetailRowCount
			Begin
				Select @Seq2 = #tmpPO_Supp_Detail.Seq2
					 , @RefNo = #tmpPO_Supp_Detail.RefNo
					 , @SciRefNo = #tmpPO_Supp_Detail.SciRefNo
					 , @FabricType = #tmpPO_Supp_Detail.FabricType
					 , @Price = #tmpPO_Supp_Detail.Price
					 , @UsedQty = #tmpPO_Supp_Detail.UsedQty
					 , @Qty = #tmpPO_Supp_Detail.Qty
					 , @POUnit = #tmpPO_Supp_Detail.POUnit
					 , @Complete = #tmpPO_Supp_Detail.Complete
					 , @SystemETD = #tmpPO_Supp_Detail.SystemETD
					 , @CFMETD = #tmpPO_Supp_Detail.CFMETD
					 , @RevisedETD = #tmpPO_Supp_Detail.RevisedETD
					 , @FinalETD = #tmpPO_Supp_Detail.FinalETD
					 , @EstETA = #tmpPO_Supp_Detail.EstETA
					 , @ShipModeID = #tmpPO_Supp_Detail.ShipModeID
					 , @PrintDate = #tmpPO_Supp_Detail.PrintDate
					 , @PINO = #tmpPO_Supp_Detail.PINO
					 , @PIDate = #tmpPO_Supp_Detail.PIDate
					 , @SuppColor = #tmpPO_Supp_Detail.SuppColor
					 , @Detail_Remark = #tmpPO_Supp_Detail.Remark
					 , @Special = #tmpPO_Supp_Detail.Special
					 , @Spec = #tmpPO_Supp_Detail.Spec
					 , @Width = #tmpPO_Supp_Detail.Width
					 , @StockQty = #tmpPO_Supp_Detail.StockQty
					 , @NetQty = #tmpPO_Supp_Detail.NetQty
					 , @LossQty = #tmpPO_Supp_Detail.LossQty
					 , @SystemNetQty  = #tmpPO_Supp_Detail.SystemNetQty
					 , @SystemCreate  = #tmpPO_Supp_Detail.SystemCreate
					 , @FOC = #tmpPO_Supp_Detail.FOC
					 , @Junk = #tmpPO_Supp_Detail.Junk
					 , @ColorDetail = #tmpPO_Supp_Detail.ColorDetail
					 , @ShipQty = #tmpPO_Supp_Detail.ShipQty
					 , @Shortage = #tmpPO_Supp_Detail.Shortage
					 , @ShipFOC = #tmpPO_Supp_Detail.ShipFOC
					 , @ApQty = #tmpPO_Supp_Detail.ApQty
					 , @InputQty = #tmpPO_Supp_Detail.InputQty
					 , @OutputQty = #tmpPO_Supp_Detail.OutputQty
					 , @ShipETA = #tmpPO_Supp_Detail.ShipETA
					 , @SystemLock = #tmpPO_Supp_Detail.SystemLock
					 , @OutputSeq1 = #tmpPO_Supp_Detail.OutputSeq1
					 , @OutputSeq2 = #tmpPO_Supp_Detail.OutputSeq2
					 , @Detail_FactoryID = #tmpPO_Supp_Detail.FactoryID
					 , @StockPOID = #tmpPO_Supp_Detail.StockPOID
					 , @StockSeq1 = #tmpPO_Supp_Detail.StockSeq1
					 , @StockSeq2 = #tmpPO_Supp_Detail.StockSeq2
					 , @InventoryUkey = #tmpPO_Supp_Detail.InventoryUkey
					 , @Remark_Shell = #tmpPO_Supp_Detail.Remark_Shell
					 , @CannotOperateStock = #tmpPO_Supp_Detail.CannotOperateStock
					 , @Keyword_Original = isnull(#tmpPO_Supp_Detail.Keyword_Original, '')
				  From #tmpPO_Supp_Detail
				 Where #tmpPO_Supp_Detail.RowID = @tmpPo_Supp_DetailRowID
				   And #tmpPO_Supp_Detail.ID = @PoID
				   And #tmpPO_Supp_Detail.Seq1 = @Seq1;
				
				if Left(@Seq1, 1) = 'A' or @SuppID = 'FTY'
				Begin
					Set @Complete = 1;
				End;

				If @Category in ('M', 'T')
				Begin
					Set @NetQty = 0;
					Set @LossQty = 0;
				End;

				Set @SystemCreate = 1;

				Set @IsExistPo_Supp_Detail = 0;
				Select Top 1 @IsExistPo_Supp_Detail = 1 From dbo.PO_Supp_Detail Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;
				If @IsExistPo_Supp_Detail = 0
				Begin
					Insert Into dbo.PO_Supp_Detail
						(  ID, Seq1, Seq2, RefNo, SciRefNo, FabricType, Price, UsedQty, Qty, POUnit, Complete
						 , SystemETD, CFMETD, RevisedETD, FinalETD, EstETA, ShipModeID
						 , PrintDate, PINO, PIDate, SuppColor, Remark
						 , Special, Width, StockQty, NetQty, LossQty, SystemNetQty, SystemCreate
						 , FOC, Junk, ColorDetail, ShipQty, Shortage
						 , ShipFOC, ApQty, InputQty, OutputQty, ShipETA, SystemLock
						 , OutputSeq1, OutputSeq2, FactoryID, StockPOID, StockSeq1, StockSeq2, InventoryUkey
						 , AddName, AddDate, Spec, Remark_Shell, CannotOperateStock, Keyword_Original
						)
					Values
						(  @PoID, @Seq1, @Seq2, @RefNo, @SciRefNo, @FabricType, @Price, @UsedQty, @Qty, @POUnit, @Complete
						 , @SystemETD, @CFMETD, @RevisedETD, @FinalETD, @EstETA, @ShipModeID
						 , @PrintDate, @PINO, @PIDate, IsNull(@SuppColor, ''), @Detail_Remark
						 , @Special, @Width, @StockQty, @NetQty, @LossQty, @SystemNetQty, @SystemCreate
						 , @FOC, @Junk, @ColorDetail, @ShipQty, @Shortage
						 , @ShipFOC, @ApQty, @InputQty, @OutputQty, @ShipETA, @SystemLock
						 , @OutputSeq1, @OutputSeq2, @Detail_FactoryID, @StockPOID, @StockSeq1, @StockSeq2, @InventoryUkey
						 , @UserID, @NowDateTime, @Spec, @Remark_Shell, @CannotOperateStock, @Keyword_Original
						);
					
					Insert Into dbo.PO_Supp_Detail_OrderList
						(ID, Seq1, Seq2, OrderID, AddName, AddDate)
						Select DISTINCT ID, Seq1, Seq2, OrderID, @UserID, @NowDateTime
						  From #tmpPO_Supp_Detail_OrderList
						 Where ID = @PoID
						   And Seq1 = @Seq1
						   And Seq2 = @Seq2;

					Insert Into dbo.PO_Supp_Detail_Spec
						(ID, Seq1, Seq2, SpecColumnID, SpecValue, AddName, AddDate)
						Select ID, Seq1, Seq2, SpecColumnID, SpecValue, @UserID, @NowDateTime
						  From #tmpPO_Supp_Detail_Spec
						 Where ID = @PoID
						   And Seq1 = @Seq1
						   And Seq2 = @Seq2;

					Insert Into dbo.PO_Supp_Detail_Keyword
						(ID, Seq1, Seq2, KeywordField, KeywordValue, AddName, AddDate)
						Select ID, Seq1, Seq2, KeywordField, KeywordValue, @UserID, @NowDateTime
						  From #tmpPO_Supp_Detail_Keyword
						 Where ID = @PoID
						   And Seq1 = @Seq1
						   And Seq2 = @Seq2;
				End;
				Else
				Begin
					If @AppType = 0
					Begin
						Update dbo.PO_Supp_Detail
						   Set RefNo = @RefNo
							 , SciRefNo = @SciRefNo
							 , FabricType = @FabricType
							 , Price = @Price
							 , UsedQty = @UsedQty
							 , Qty = @Qty
							 , POUnit = @POUnit
							 , Complete = @Complete
							 , SystemETD = @SystemETD
							 , CFMETD = @CFMETD
							 , RevisedETD = @RevisedETD
							 , FinalETD = @FinalETD
							 , EstETA = @EstETA
							 , ShipModeID = @ShipModeID
							 , PrintDate = @PrintDate
							 , PINO = @PINO
							 , PIDate = @PIDate
							 , SuppColor = @SuppColor
							 , Remark = @Detail_Remark
							 , Special = @Special
							 , Spec = @Spec
							 , Width = @Width
							 , StockQty = @StockQty
							 , NetQty = @NetQty
							 , LossQty = @LossQty
							 , SystemNetQty = @SystemNetQty
							 , SystemCreate = @SystemCreate
							 , FOC = @FOC
							 , Junk = @Junk
							 , ColorDetail = @ColorDetail
							 , ShipQty = @ShipQty
							 , Shortage = @Shortage
							 , ShipFOC = @ShipFOC
							 , ApQty = @ApQty
							 , InputQty = @InputQty
							 , OutputQty = @OutputQty
							 , ShipETA = @ShipETA
							 , SystemLock = @SystemLock
							 , OutputSeq1 = @OutputSeq1
							 , OutputSeq2 = @OutputSeq2
							 , FactoryID = @Detail_FactoryID
							 , StockPOID = @StockPOID
							 , StockSeq1 = @StockSeq1
							 , StockSeq2 = @StockSeq2
							 , InventoryUkey = @InventoryUkey
							 , EditName = @UserID
							 , EditDate = @NowDateTime
							 , CannotOperateStock = @CannotOperateStock
							 , Keyword_Original = @Keyword_Original
						 Where ID = @PoID
						   And Seq1 = @Seq1
						   And Seq2 = @Seq2;
						
						Delete From dbo.PO_Supp_Detail_OrderList Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;
						
						Insert Into dbo.PO_Supp_Detail_OrderList
							(ID, Seq1, Seq2, OrderID, AddName, AddDate)
							Select DISTINCT ID, Seq1, Seq2, OrderID, @UserID, @NowDateTime
							  From #tmpPO_Supp_Detail_OrderList
							 Where ID = @PoID
							   And Seq1 = @Seq1
							   And Seq2 = @Seq2;

						Delete From dbo.PO_Supp_Detail_Spec Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;

						Insert Into dbo.PO_Supp_Detail_Spec
						(ID, Seq1, Seq2, SpecColumnID, SpecValue, AddName, AddDate)
						Select ID, Seq1, Seq2, SpecColumnID, SpecValue, @UserID, @NowDateTime
						  From #tmpPO_Supp_Detail_Spec
						 Where ID = @PoID
						   And Seq1 = @Seq1
						   And Seq2 = @Seq2;

						Delete From dbo.PO_Supp_Detail_Keyword Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;

						Insert Into dbo.PO_Supp_Detail_Keyword
						(ID, Seq1, Seq2, KeywordField, KeywordValue, AddName, AddDate)
						Select ID, Seq1, Seq2, KeywordField, KeywordValue, @UserID, @NowDateTime
						  From #tmpPO_Supp_Detail_Keyword
						 Where ID = @PoID
						   And Seq1 = @Seq1
						   And Seq2 = @Seq2;
					End;
				End;

				Set @tmpPo_Supp_DetailRowID += 1;
			End;
			--------------------Loop End #tmpPO_Supp_Detail--------------------
			Set @tmpPo_SuppRowID += 1
		End;
		--------------------Loop End #tmpPO_Supp--------------------

		if @AutoInput = 1
		BEGIN
			EXEC TransferToPO_3_AutoInput @PoID, @UserID, @AutoInputReason, @Seq1_Start, @Seq1_End
		END
		Commit Transaction;
	End Try
	Begin Catch
		RollBack Transaction

		Declare @ErrorMessage NVarChar(4000);
		Declare @ErrorSeverity Int;
		Declare @ErrorState Int;

		Set @ErrorMessage = Error_Message();
		Set @ErrorSeverity = Error_Severity();
		Set @ErrorState = Error_State();

		RaisError (@ErrorMessage,	-- Message text.
				   @ErrorSeverity,	-- Severity.
				   @ErrorState		-- State.
				  );
	End Catch;

	
End

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_3_Insert';
Go