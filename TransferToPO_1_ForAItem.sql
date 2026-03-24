Use [Trade]
Go
/****** Object:  StoredProcedure [dbo].[BoaExpend]    Script Date: 2015/10/20 上午 10:06:43 ******/
Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Ben
-- Create date: 2015/11/13
-- Description:
--		Transfer To PO - A大項
-- =============================================
If Object_Id ( 'dbo.TransferToPO_1_ForAItem', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_1_ForAItem;
Go

Create Procedure [dbo].[TransferToPO_1_ForAItem]
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
	Declare @Seq1 VarChar(3);
	Declare @SuppID VarChar(6);
	----------------------------------------------------------------------
	Declare @Seq2 VarChar(2);
	Declare @Seq2_Count Int;
	Declare @RefNo VarChar(36);
	Declare @SCIRefNo VarChar(30);
	Declare @FabricType VarChar(1);
	Declare @ColorID VarChar(6);
	Declare @SuppColor NVarChar(Max);
	Declare @SizeSpec VarChar(15);
	Declare @SizeUnit VarChar(8);
	Declare @Special NVarChar(Max);
	Declare @Complete Bit;
	Declare @Price Numeric(14,4);
	Declare @UsedQty Numeric(10,4);
	Declare @UnitRound Numeric(2,0);
	Declare @UsageRound Numeric(2,0);
	Declare @RoundStep Numeric(4,2);
	Declare @NetQty Numeric(10,2);
	Declare @LossQty Numeric(10,2);
	Declare @SystemNetQty Numeric(10,2);
	Declare @PurchaseQty Numeric(12,2);
	Declare @Remark NVarChar(Max);
	----------------------------------------------------------------------
	Declare @CfmDate Date;
	Declare @StyleID VarChar(15);
	Declare @SeasonID VarChar(10);
	Declare @StyleUkey BigInt;

	Select @CfmDate = CfmDate
		 , @StyleID = StyleID
		 , @SeasonID = SeasonID
	  From dbo.Orders
	 Where ID = @PoID;
	
	Select @StyleUkey = Ukey
	  From Trade.dbo.Style
	 Where BrandID = @BrandID
	   And ID = @StyleID
	   And SeasonID = @SeasonID;
	----------------------------------------------------------------------
	Declare @BofUkey BigInt;
	Declare @BofSuppID VarChar(6);
	Declare @FabricCode VarChar(3);
	Declare @BofRemark NVarCHar(Max);
	Declare @Direction NVarCHar(40);
	Declare @CuttingWidth VarChar(8);
	Declare @PoUnit VarChar(8);
	Declare @UsageUnit VarChar(8);
	Declare @OrderQty Numeric(6,0);
	Declare @YDS Numeric(8,2);
	Declare @tmpA1 Table
		(  RowID BigInt Identity(1,1) Not Null, BofUkey BigInt, RefNo VarChar(36), SciRefNo VarChar(30)
		 , BofSuppID VarChar(6), FabricType VarChar(1), FabricCode VarChar(3), ColorID VarChar(6)
		 , BofRemark NVarChar(Max), Direction NVarCHar(40), CuttingWidth VarChar(8)
		 , PoUnit VarChar(8), UsageUnit VarChar(8), OrderQty Numeric(6,0), YDS Numeric(8,2)
		);
	Declare @tmpA1RowID Int;	--Row ID
	Declare @tmpA1RowCount Int;	--總資料筆數

	Declare @FabricPanelCode VarChar(2);
	Declare @tmpQT Table
		(RowID BigInt Identity(1,1) Not Null, FabricCode VarChar(3), FabricPanelCode VarChar(2));
	Declare @tmpQTRowID Int;	--Row ID
	Declare @tmpQTRowCount Int;	--總資料筆數
	
	Declare @tmpA2 Table
		(RowID BigInt Identity(1,1) Not Null, ColorID VarCHar(6), CuttingWidth VarChar(8), OrderQty Numeric(6,0), YDS Numeric(8,2));
	Declare @tmpA2RowID Int;	--Row ID
	Declare @tmpA2RowCount Int;	--總資料筆數
	
	Declare @QtRemark NVarCHar(Max);
	Declare @BofQtRemark NVarCHar(Max);
	Declare @tmpA2_QtRemark Table
		(RowID BigInt Identity(1,1) Not Null, QtRemark NVarChar(Max));
	Declare @tmpA2_QtRemarkRowID Int;		--Row ID
	Declare @tmpA2_QtRemarkRowCount Int;	--總資料筆數
	----------------------------------------------------------------------
	--外裁織帶
	Insert Into @tmpA1
		(  BofUkey, RefNo, SciRefNo, BofSuppID, FabricType, FabricCode, ColorID
		 , BofRemark, Direction, CuttingWidth, PoUnit, UsageUnit, OrderQty, YDS
		)
		Select Order_BOF.Ukey, Order_BOF.RefNo, Order_BOF.SCIRefNo, Order_BOF.SuppID, Fabric.Type
			 , Order_EachCons.FabricCode, Order_EachCons_Color.ColorID
			 , Order_BOF.Remark, Order_EachCons.Direction, Order_EachCons.CuttingWidth
			 , IsNull(Fabric_Supp.POUnit, '') as POUnit, IsNull(Fabric.UsageUnit, '') as UsageUnit
			 , Sum(Order_EachCons_Color.OrderQty) OrderQty
			 , Sum(Order_EachCons_Color.YDS) YDS
		  From dbo.Order_EachCons
		  Left Join dbo.Order_EachCons_Color
			On Order_EachCons_Color.Order_EachConsUkey = Order_EachCons.Ukey
		  Left Join dbo.Order_BOF
			On	   Order_BoF.ID = Order_EachCons.ID
			   And Order_BoF.FabricCode = Order_EachCons.FabricCode
		  Left Join Trade.dbo.Fabric
			On Fabric.SCIRefNo = Order_BOF.SCIRefNo
		  Left Join Trade.dbo.Fabric_Supp
			On	   Fabric_Supp.SCIRefNo = Order_BOF.SCIRefNo
			   And Fabric_Supp.SuppID = Order_BOF.SuppID
		 Where Order_EachCons.ID = @PoID
		   And Order_EachCons.CuttingPiece = 1
		   And Order_EachCons.Type != '2'
		 Group by Order_BOF.Ukey, Order_BOF.RefNo, Order_BOF.SCIRefNo, Order_BOF.SuppID, Fabric.Type
				, Order_EachCons.FabricCode, Order_EachCons_Color.ColorID
				, Order_BOF.Remark, Order_EachCons.Direction, Order_EachCons.CuttingWidth
				, Fabric_Supp.POUnit, Fabric.UsageUnit
	--------------------Loop Start @tmpA1--------------------
	Set @Seq2_Count = 0;
	Set @tmpA1RowID = 1;
	Select @tmpA1RowID = Min(RowID), @tmpA1RowCount = Max(RowID) From @tmpA1;
	While @tmpA1RowID <= @tmpA1RowCount
	Begin
		Select @RefNo = RefNo
			 , @SCIRefNo =SciRefNo
			 , @BofSuppID =BofSuppID
			 , @FabricType = FabricType
			 , @FabricCode = FabricCode
			 , @ColorID = ColorID
			 , @Remark = BofRemark
			 , @Direction = Direction
			 , @CuttingWidth = CuttingWidth
			 , @PoUnit = PoUnit
			 , @UsageUnit = UsageUnit
			 , @OrderQty = OrderQty
			 , @YDS = YDS
		  From @tmpA1
		 Where RowID = @tmpA1RowID;
		
		Set @Seq1 = 'A1';
		Set @SuppID = 'FTY';
		--------------------------------------
		Set @Complete = 1;
		Set @SizeSpec = @CuttingWidth;
		Set @Special = @Direction;
		Set @SuppColor = Trade.dbo.GetSuppColorList(@SciRefNo, @BofSuppID, @ColorID, @BrandID, @SeasonID, @ProgramID, @StyleID);
		--------------------------------------
		--單件用量
		Set @UsedQty = IIF(@OrderQty = 0, 0, @YDS / @OrderQty);
		--------------------------------------
		--Price
		Set @Price = Trade.dbo.GetPriceFromMtl(@SCIRefNo, @BofSuppID, @SeasonID, @YDS, @Category, @CfmDate, '', '', '');
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
		Set @NetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @YDS);
		Set @SystemNetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @YDS);
		Set @LossQty = 0
		--------------------------------------
		--無條件進位
		--NetQty & LossQty 均無條件進位至小數一位
		Set @NetQty = Trade.dbo.GetCeiling(@NetQty, @UsageRound, 0);
		Set @SystemNetQty = Trade.dbo.GetCeiling(@SystemNetQty, @UnitRound, 0);
		--------------------------------------
		--採購Qty
		Set @PurchaseQty = Trade.dbo.GetCeiling((@NetQty + @LossQty), @UnitRound, @RoundStep);
		If @PurchaseQty > 0
		Begin
			Set @Seq2 = '';
			Select @Seq2_Count = IsNull(Max(Seq2_Count), 0) + 1
			  From #tmpPO_Supp_Detail
			 Where ID = @PoID
			   And Seq1 = @Seq1;
			
			If @Category = 'M'
			Begin
				Set @NetQty = 0;
				Set @LossQty = 0;
			End;
			--------------------------------------
			--寫入Temp Table - PO_Supp
			If Not Exists(Select * From #tmpPO_Supp Where ID = @PoID And Seq1 = @Seq1)
			Begin
				Insert Into #tmpPO_Supp
					(ID, Seq1, SuppID)
				Values
					(@PoID, @Seq1, @SuppID);
			End;
			--------------------------------------
			--寫入Temp Table - PO_Supp_Detail
			Insert Into #tmpPO_Supp_Detail
				(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
				 , ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty
				 , SizeSpec, Special, Complete
				 , Seq2_Count
				)
			Values
				(  @PoID, @Seq1, @Seq2, @RefNo, @SCIRefNo, @FabricType, @Price, @UsedQty, @PurchaseQty, @POUnit
				 , RTrim(LTrim(@ColorID)), @SuppColor, @Remark, @NetQty, @LossQty, @SystemNetQty
				 , @SizeSpec, @Special, @Complete
				 , @Seq2_Count
				);
			--------------------------------------
			--寫入Temp Table - PO_Supp_Detail_Spec
			Insert Into #tmpPO_Supp_Detail_Spec
				(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
			Values
				(@PoID, @Seq1, @Seq2, 'Color', @ColorID, @Seq2_Count)
				, (@PoID, @Seq1, @Seq2, 'Size', @SizeSpec, @Seq2_Count)
				;
			--------------------------------------
		End;
		Set @tmpA1RowID += 1;
	End;
	--------------------Loop End @tmpA1--------------------
	--------------------------------------
	--A2項帶出規則
	-- 1. Bill of Fabric 勾選[Special]
	-- 2. 布種有設定QT
	-- 3. QT其中一項REF# 的 [Fabric Kind] = 3(Polyfill)
	--------------------------------------
	Declare @FabricLoss Table
		(  RowID BigInt Identity(1,1) Not Null, SciRefNo VarChar(30), FabricCode VarChar(3), ColorID VarChar(6)
		 , RealLoss Numeric(10,4), PlusName VarChar(30)
		);
	Insert Into @FabricLoss
		(SciRefNo, FabricCode, ColorID, RealLoss, PlusName)
		Select SciRefNo, FabricCode, ColorID, RealLoss, PlusName
		  From dbo.GetLossFabric(@PoID, '', @IsExpendArticle) as tmpLoss
		 Order by FabricCode, ColorID;
	
	Insert Into @tmpQT
		(FabricCode, FabricPanelCode)
		Select f2.FabricCode, Order_FabricCode_QT.FabricPanelCode
		  From dbo.Order_FabricCode_QT
		  Left Join dbo.Order_FabricCode
			On	   Order_FabricCode.ID = Order_FabricCode_QT.ID
			   And Order_FabricCode.FabricPanelCode = Order_FabricCode_QT.QTFabricPanelCode
		  Left Join dbo.Order_BOF
			On	   Order_BOF.ID = Order_FabricCode_QT.ID
			   And Order_BOF.FabricCode = Order_FabricCode.FabricCode
		  Left Join Trade.dbo.Style_BOF
			On Style_BOF.StyleUkey = @StyleUkey
			   And Style_BOF.FabricCode = Order_FabricCode.FabricCode
		--[9740] add by Edward : 帶出原本 Q Polyfill的 FabricCode 跟部位，及排除原Polyfill項目
		  inner Join dbo.Order_FabricCode f2
			On	   f2.ID = Order_FabricCode.ID
			   And f2.FabricPanelCode = Order_FabricCode_QT.FabricPanelCode
			   and f2.FabricCode != Order_FabricCode.FabricCode
		  inner Join dbo.Order_BOF bof2
			On	   bof2.ID = Order_FabricCode_QT.ID
			   And bof2.FabricCode = f2.FabricCode
		 Where Order_FabricCode_QT.ID = @PoID
		   And Order_BOF.Kind = '3'
		   And Style_BOF.Special = 1
		   And bof2.Kind != '3'
		 Group by f2.FabricCode, Order_FabricCode_QT.FabricPanelCode
		 Order by f2.FabricCode, Order_FabricCode_QT.FabricPanelCode;
	--------------------Loop Start @tmpQT--------------------
	Set @Seq2_Count = 0;
	Set @tmpQTRowID = 1;
	Select @tmpQTRowID = Min(RowID), @tmpQTRowCount = Max(RowID) From @tmpQT;
	While @tmpQTRowID <= @tmpQTRowCount
	Begin
		Select @FabricCode = FabricCode
			 , @FabricPanelCode = FabricPanelCode
		  From @tmpQT
		 Where RowID = @tmpQTRowID;
		--------------------------------------
		Set @Seq1 = 'A2';
		Set @SuppID = 'FTY';
		--------------------------------------
		Set @RefNo = '';
		Set @SCIRefNo = '';
		Set @FabricType = '';
		Set @BofSuppID = '';
		Set @PoUnit = '';
		Set @UsageUnit = '';
		Set @BofRemark = '';
		Select @RefNo = Order_BOF.RefNo
			 , @SCIRefNo = Order_BOF.SCIRefNo
			 , @FabricType = Fabric.Type
			 , @BofSuppID = Order_BOF.SuppID
			 , @PoUnit = Fabric_Supp.POUnit
			 , @UsageUnit = Fabric.UsageUnit
			 , @BofRemark = Order_BOF.Remark
		  From dbo.Order_BOF
		  Left Join Trade.dbo.Fabric
			On Fabric.SCIRefNo = Order_BOF.SCIRefNo
		  Left Join Trade.dbo.Fabric_Supp
			On	   Fabric_Supp.SCIRefNo = Order_BOF.SCIRefNo
			   And Fabric_Supp.SuppID = Order_BOF.SuppID
		 Where ID = @PoID
		   And FabricCode = @FabricCode;
		--------------------------------------
		--取得QT棉的 Remark
		Delete From @tmpA2_QtRemark;
		Insert Into @tmpA2_QtRemark
			(QtRemark)
			Select Order_BOF.Remark
			  From dbo.Order_FabricCode_QT
			  Left Join dbo.Order_FabricCode
				On	   Order_FabricCode.ID = Order_FabricCode_QT.ID
				   And Order_FabricCode.FabricPanelCode = Order_FabricCode_QT.QTFabricPanelCode
			  Left Join dbo.Order_BOF
				On	   Order_BOF.ID = Order_FabricCode_QT.ID
				   And Order_BOF.FabricCode = Order_FabricCode.FabricCode
			 Where Order_FabricCode_QT.ID = @PoID
			   And Order_FabricCode_QT.FabricPanelCode = @FabricPanelCode
			   And Order_BOF.Kind = '3';
		--------------------Loop Start @tmpA2_QtRemark--------------------
		Set @BofQtRemark = '';
		Set @tmpA2_QtRemarkRowID = 1; 
		Select @tmpA2_QtRemarkRowID = Min(RowID), @tmpA2_QtRemarkRowCount = Max(RowID) From @tmpA2_QtRemark;
		While @tmpA2_QtRemarkRowID <= @tmpA2_QtRemarkRowCount
		Begin
			Select @QtRemark = QtRemark
			  From @tmpA2_QtRemark
			 Where RowID = @tmpA2_QtRemarkRowID;
			
			Set @BofQtRemark += @QtRemark;

			Set @tmpA2_QtRemarkRowID += 1; 
		End;
		--------------------Loop End @tmpA2_QtRemark--------------------
		--------------------------------------
		Delete From @tmpA2;
		Insert Into @tmpA2
			(ColorID, CuttingWidth, OrderQty, YDS)
			Select Order_EachCons_Color.ColorID, Order_EachCons.CuttingWidth
				 , Sum(Order_EachCons_Color.OrderQty) as OrderQty
				 , Sum(Order_EachCons_Color.YDS) as YDS
			  From dbo.Order_EachCons
			  Left Join dbo.Order_EachCons_Color
				On Order_EachCons_Color.Order_EachConsUkey = Order_EachCons.Ukey
			 Where Order_EachCons.ID = @PoID
			   And Order_EachCons.FabricPanelCode = @FabricPanelCode
			 Group by Order_EachCons_Color.ColorID, Order_EachCons.CuttingWidth;
		--------------------Loop Start @tmpA2--------------------
		Set @tmpA2RowID = 1;
		Select @tmpA2RowID = Min(RowID), @tmpA2RowCount = Max(RowID) From @tmpA2;
		While @tmpA2RowID <= @tmpA2RowCount
		Begin
			Select @ColorID = ColorID
				 , @CuttingWidth = CuttingWidth
				 , @OrderQty = OrderQty
				 , @YDS = YDS
			  From @tmpA2
			 Where RowID = @tmpA2RowID;
			--------------------------------------
			Set @Remark = 'Refno#QUILTING;' + Char(13);
			Set @Remark += 'Spec: SHELL FABRIC REF NO :' + RTrim(@RefNo) + Char(13);
			If @QtRemark != ''
			Begin
				Set @Remark += RTrim(@BofQtRemark) + Char(13);
			End;
			Set @Remark +=  RTrim(@BofRemark) + Char(13);
			--------------------------------------
			Set @Complete = 1;
			Set @SizeSpec = @CuttingWidth;
			Set @SuppColor = Trade.dbo.GetSuppColorList(@SciRefNo, @BofSuppID, @ColorID, @BrandID, @SeasonID, @ProgramID, @StyleID);
			--------------------------------------
			--單件用量
			Set @UsedQty = IIF(@OrderQty = 0, 0, @YDS / @OrderQty);
			--------------------------------------
			--Price
			Set @Price = 0;
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
			Set @NetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @YDS);
			Set @SystemNetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @YDS);
			--------------------------------------
			--損耗數(Loss Qty)
			Set @LossQty = 0
			Select @LossQty = sum(Trade.dbo.GetCeiling(RealLoss, @UsageRound, 0))
			  From @FabricLoss
			 Where SciRefNo = @SCIRefNo
			   And FabricCode in (select FabricCode from @tmpQT) --在此一次算完該QT的Loss，只在QT的第一個項目Insert的時候把Loss寫進去
			   And ColorID = @ColorID;
			
			--損耗數(單位換算)
			Set @LossQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @LossQty);
			--------------------------------------
			--無條件進位
			--NetQty & LossQty 均無條件進位至小數一位
			--Set @NetQty = Trade.dbo.GetCeiling(@NetQty, @UsageRound, 0);
			--Set @SystemNetQty = Trade.dbo.GetCeiling(@SystemNetQty, @UnitRound, 0);
			--Set @LossQty = Trade.dbo.GetCeiling(@LossQty, @UsageRound, 0);
			--------------------------------------
			--採購Qty
			Set @PurchaseQty = @NetQty + @LossQty;
			--------------------------------------
			If @PurchaseQty > 0
			Begin
				Set @Seq2 = '';
				Select @Seq2_Count = IsNull(Max(Seq2_Count), 0) + 1
				  From #tmpPO_Supp_Detail
				 Where ID = @PoID
				   And Seq1 = @Seq1;
				
				If @Category = 'M'
				Begin
					Set @NetQty = 0;
					Set @LossQty = 0;
				End;
				--------------------------------------
				--寫入Temp Table - PO_Supp
				If Not Exists(Select * From #tmpPO_Supp Where ID = @PoID And Seq1 = @Seq1)
				Begin
					Insert Into #tmpPO_Supp
						(ID, Seq1, SuppID)
					Values
						(@PoID, @Seq1, @SuppID);
				End;
				--------------------------------------
				--寫入Temp Table - PO_Supp_Detail
				if (not exists(select 1 from #tmpPO_Supp_Detail 
					where ID = @PoID AND Seq1 = @Seq1 AND SCIRefNo = @SCIRefNo AND FabricType = @FabricType AND ColorID = @ColorID))
				BEGIN
					Insert Into #tmpPO_Supp_Detail
						(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
						 , ColorID, SuppColor, Remark, NetQty, LossQty, SystemNetQty
						 , SizeSpec, Complete
						 , Seq2_Count
						)
					Values
						(  @PoID, @Seq1, @Seq2, @RefNo, @SCIRefNo, @FabricType, @Price, @UsedQty, @PurchaseQty, @POUnit
						 , RTrim(LTrim(@ColorID)), @SuppColor, @Remark, @NetQty, @LossQty, @SystemNetQty
						 , @SizeSpec, @Complete
						 , @Seq2_Count
						);

					Insert Into #tmpPO_Supp_Detail_Spec
						(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
					Values
						(@PoID, @Seq1, @Seq2, 'Color', @ColorID, @Seq2_Count);
				END
				ELSE
				BEGIN
					UPDATE #tmpPO_Supp_Detail
						SET 
						UsedQty += @UsedQty,
						NetQty += @NetQty,
						SystemNetQty += @SystemNetQty
					WHERE ID = @PoID AND Seq1 = @Seq1 AND SCIRefNo = @SCIRefNo AND FabricType = @FabricType AND ColorID = @ColorID;
				END
				--------------------------------------
			End;
			Set @tmpA2RowID += 1;

			--------------------Loop End @tmpA2--------------------
			--------------------------------------
			--Qty、NetQty、LossQty、FOC、SystemNetQty 一律累加完後才做進位
			--先做單位換算，再做無條件進位
			--NetQty & LossQty 均無條件進位至小數一位
			Update #tmpPO_Supp_Detail
			   Set NetQty = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.NetQty), tmpUnitRound.UsageRound, 0)
				 , LossQty = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.LossQty), tmpUnitRound.UsageRound, 0)
				 , FOC = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.FOC), tmpUnitRound.UsageRound, 0)
				 , SystemNetQty = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.SystemNetQty), tmpUnitRound.UnitRound, 0)
			  From #tmpPO_Supp_Detail
			  Left Join Trade.dbo.Fabric
				On	   Fabric.BrandID = @BrandID
				   And Fabric.SCIRefno = #tmpPO_Supp_Detail.SCIRefNo
			 Outer Apply (Select * From Trade.dbo.GetUnitRound(@BrandID, @ProgramID, @Category, #tmpPO_Supp_Detail.POUnit)) as tmpUnitRound
			 Where #tmpPO_Supp_Detail.ID = @PoID and #tmpPO_Supp_Detail.Seq1 = @Seq1 
				AND #tmpPO_Supp_Detail.SCIRefNo = @SCIRefNo 
				AND #tmpPO_Supp_Detail.FabricType = @FabricType 
				AND #tmpPO_Supp_Detail.ColorID = @ColorID;
	
			--更新採購Qty
			Update #tmpPO_Supp_Detail
			   Set Qty = Trade.dbo.GetCeiling((#tmpPO_Supp_Detail.NetQty + #tmpPO_Supp_Detail.LossQty), tmpUnitRound.UnitRound, tmpUnitRound.RoundStep)
			  From #tmpPO_Supp_Detail
			  Left Join Trade.dbo.Fabric
				On	   Fabric.BrandID = @BrandID
				   And Fabric.SCIRefno = #tmpPO_Supp_Detail.SCIRefNo
			 Outer Apply (Select * From Trade.dbo.GetUnitRound(@BrandID, @ProgramID, @Category, #tmpPO_Supp_Detail.POUnit)) as tmpUnitRound
			 Where #tmpPO_Supp_Detail.ID = @PoID and #tmpPO_Supp_Detail.Seq1 = @Seq1 
				AND #tmpPO_Supp_Detail.SCIRefNo = @SCIRefNo 
				AND #tmpPO_Supp_Detail.FabricType = @FabricType 
				AND #tmpPO_Supp_Detail.ColorID = @ColorID;

		End;
		--------------------Loop End @tmpA2--------------------
		Set @tmpQTRowID += 1;
	End;
	--------------------Loop End @tmpQT--------------------
	--------------------------------------

	--------------------------------------
	--A3新增於TransferToPO_1_ForThreadAllowance
	--紀錄Style-P22 [QT Color Combo]採購項
	--------------------------------------

	--Select * From #tmpPO_Supp;
	--Select * From #tmpPO_Supp_Detail;
End

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_1_ForAItem';
Go
