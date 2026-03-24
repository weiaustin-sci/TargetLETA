Use [Trade]
Go

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Vicky
-- Create date: 2020/07/07
-- Description:
--		Transfer To PO For Update
-- =============================================
If Object_Id ( 'dbo.TransferToPO_3_InsertForUpdate', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_3_InsertForUpdate;
Go

Create Procedure [dbo].[TransferToPO_3_InsertForUpdate]
	(
	  @PoID			VarChar(13)		--採購母單
	 ,@PoHandle		VarChar(10)
	 ,@PoSMR		VarChar(10)
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
	Declare @IsExistPo_Supp Int = 0;
	Declare @IsExistPo_Supp_Detail Int = 0;
	
	Select Top 1 @IsExistPo_Supp = 1 From #tmpPO_Supp Where ID = @PoID;

	--因為transfer2po那邊會卡條件產生po_Supp,po_Supp_Detail的資料, 如果資料是空的話,應該連po都不產生
	If @IsExistPo_Supp = 0
	Begin
		Return;
	End;
	
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
	
	Declare @SciRefNo_New VarChar(30);

	Declare @IsPoExist Int = 0;
	Declare @BrandID VarChar(8);
	Declare @StyleID VarChar(15);
	Declare @SeasonID VarChar(10);
	Declare @StyleUkey BigInt;
	Declare @FactoryID VarChar(8);
	Declare @Category VarChar(1);
	Declare @FTYMark VarChar(20);
	Declare @Status VarChar(1);
	Declare @Sel bit;
	Declare @IsFOC bit;
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
		--------------------Loop Start #tmpPO_Supp--------------------
		Set @tmpPo_SuppRowID = 1;
		Select @tmpPo_SuppRowID = Min(RowID), @tmpPo_SuppRowCount = Max(RowID) From #tmpPO_Supp
		Where ID = @PoID
		
		While @tmpPo_SuppRowID <= @tmpPo_SuppRowCount
		Begin
			Select @Seq1 = #tmpPO_Supp.Seq1
				 , @SuppID = #tmpPO_Supp.SuppID
				 , @ShipTermID = #tmpPO_Supp.ShipTermID
				 , @PayTermAPID = #tmpPO_Supp.PayTermAPID
				 , @Remark = #tmpPO_Supp.Remark
				 , @Description = #tmpPO_Supp.Description
				 , @CompanyID = #tmpPO_Supp.CompanyID
				 , @StyleID = isnull(#tmpPO_Supp.StyleID, @StyleID)
			  From #tmpPO_Supp
			 Where RowID = @tmpPo_SuppRowID
			   And ID = @PoID
			
			Set @IsExistPo_Supp = 0;
			Select Top 1 @IsExistPo_Supp = 1 From dbo.PO_Supp Where ID = @PoID And Seq1 = @Seq1;
			If @IsExistPo_Supp = 0
			Begin
				Insert Into dbo.PO_Supp
					(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, AddName, AddDate, StyleID)
				Values
					(@PoID, @Seq1, @SuppID, @ShipTermID, @PayTermAPID, @Remark, @Description, @CompanyID, @UserID, @NowDateTime, @StyleID);
			End
			Else
			Begin
				Update dbo.PO_Supp Set StyleID = @StyleID Where ID = @PoID And Seq1 = @Seq1 And StyleID is null
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
					 , @ColorID = #tmpPO_Supp_Detail.ColorID
					 , @SuppColor = #tmpPO_Supp_Detail.SuppColor
					 , @SizeSpec = #tmpPO_Supp_Detail.SizeSpec
					 , @SizeUnit = #tmpPO_Supp_Detail.SizeUnit
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
					 , @BomZipperInsert = #tmpPO_Supp_Detail.BomZipperInsert
					 , @BomCustPONo = #tmpPO_Supp_Detail.BomCustPONo
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
					 , @Status = #tmpPO_Supp_Detail.Status
					 , @Sel = #tmpPO_Supp_Detail.Sel
					 , @IsFoc = f.IsFOC
					 , @CannotOperateStock = #tmpPO_Supp_Detail.CannotOperateStock
					 , @Keyword_Original = #tmpPO_Supp_Detail.Keyword_Original
				  From #tmpPO_Supp_Detail
				  Left join Trade.dbo.Fabric f on #tmpPO_Supp_Detail.SCIRefNo = f.SCIRefNo
				 Where #tmpPO_Supp_Detail.RowID = @tmpPo_Supp_DetailRowID
				   And #tmpPO_Supp_Detail.ID = @PoID
				   And #tmpPO_Supp_Detail.Seq1 = @Seq1;

				If @Category in ('M', 'T')
				Begin
					Set @NetQty = 0;
					Set @LossQty = 0;
				End;

				if Left(@Seq1, 1) = 'A' or @SuppID = 'FTY'
				Begin
					Set @Complete = 1;
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
						Select ID, Seq1, Seq2, OrderID, @UserID, @NowDateTime
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
					CREATE TABLE #Temp(OriNetQty Numeric(10,2), NewNetQty Numeric(10,2), OriLossQty Numeric(10,2), NewLossQty Numeric(10,2))

					Update po3
						Set Qty = IIF(@Sel = 1, @Qty, Qty)
							, FOC = IIF(@Sel = 1, @FOC, FOC)
							, NetQty = IIF(@Sel = 1, @NetQty, NetQty)
							, LossQty = IIF(@Sel = 1, @LossQty, LossQty)
							, SystemETD = IIF(@Sel = 1 and UpdateSystemETD.ck = 1, @SystemETD, SystemETD)
							, FinalETD = IIF(@Sel = 1 and UpdateSystemETD.ck = 1, COALESCE(RevisedETD, CfmETD, @SystemETD), FinalETD)
							, EditName = @UserID
							, EditDate = @NowDateTime
							, Junk = IIF(@Sel = 1, IIF(@Qty + @FOC = 0, 1, 0), Junk)							
							, CannotOperateStock = @CannotOperateStock
						Output deleted.NetQty, inserted.NetQty, deleted.LossQty, inserted.LossQty into #Temp
						From dbo.PO_Supp_Detail po3
						Outer Apply (select ck = cast(iif(@SystemETD_SpecialRule = 1 and po3.SystemLock is null and po3.CFMETD is null, 1, 0) as bit)) UpdateSystemETD
						Where ID = @PoID
						And Seq1 = @Seq1
						And Seq2 = @Seq2
						And Junk = 0;

					insert into dbo.PO_Modify
					   (ID, Seq1, Seq2, ReasonTypeID, ReasonID, FieldID, OldValue, NewValue, AddName, AddDate)
					select @PoID, @Seq1, @Seq2, 'PO_Modify', '', 'NetQty', OriNetQty, NewNetQty, @UserID, @NowDateTime
					from #Temp where OriNetQty != NewNetQty

					insert into dbo.PO_Modify
					   (ID, Seq1, Seq2, ReasonTypeID, ReasonID, FieldID, OldValue, NewValue, AddName, AddDate)
					select @PoID, @Seq1, @Seq2, 'PO_Modify', '', 'LossQty', OriLossQty, NewLossQty, @UserID, @NowDateTime
					from #Temp where OriLossQty != NewLossQty

					IF OBJECT_ID('tempdb..#Temp') IS NOT NULL
						DROP TABLE #Temp

					Delete From dbo.PO_Supp_Detail_OrderList Where ID = @PoID And Seq1 = @Seq1 And Seq2 = @Seq2;
						
					Insert Into dbo.PO_Supp_Detail_OrderList
						(ID, Seq1, Seq2, OrderID, AddName, AddDate)
						Select ID, Seq1, Seq2, OrderID, @UserID, @NowDateTime
							From #tmpPO_Supp_Detail_OrderList
							Where ID = @PoID
							And Seq1 = @Seq1
							And Seq2 = @Seq2;

					-- 更新70項OrderList
					Delete op4
					From dbo.PO_Supp_Detail op3
					Inner join dbo.PO_Supp_Detail_OrderList op4 on op3.ID = op4.id and op3.Seq1 = op4.SEQ1 and op3.seq2 = op4.SEQ2
					Where op3.ID = @PoID and op3.OutputSeq1 = @Seq1 and op3.OutputSeq2 = @Seq2

					Insert Into dbo.PO_Supp_Detail_OrderList
						(ID, Seq1, Seq2, OrderID, AddName, AddDate)
					Select op3.ID, op3.Seq1, op3.Seq2, po4.OrderID, @UserID, @NowDateTime
					From #tmpPO_Supp_Detail_OrderList po4
					Inner join dbo.PO_Supp_Detail op3 on op3.ID = po4.id and op3.OutputSeq1 = po4.SEQ1 and op3.OutputSeq2 = po4.SEQ2
					Where po4.ID = @PoID And po4.Seq1 = @Seq1 And po4.Seq2 = @Seq2
				End;

				Set @tmpPo_Supp_DetailRowID += 1;
			End;
			--------------------Loop End #tmpPO_Supp_Detail--------------------
			Set @tmpPo_SuppRowID += 1
		End;
		--------------------Loop End #tmpPO_Supp--------------------

		if @AutoInput = 1
		BEGIN
			EXEC TransferToPO_3_AutoInput @PoID, @UserID, @AutoInputReason, '', ''
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