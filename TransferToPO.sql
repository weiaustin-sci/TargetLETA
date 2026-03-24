Use [Trade]
Go

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Ben
-- Create date: 2015/11/09
-- Description:
--		Transfer To PO
-- =============================================
If Object_Id ( 'dbo.TransferToPO', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO;
Go

Create Procedure [dbo].[TransferToPO]
	(
	  @PoID				VarChar(13)		--採購母單
	 ,@PoHandle			VarChar(10)
	 ,@PoSMR			VarChar(10)
	 ,@IsExpend_BOF		Bit				--是否展開BOF
	 ,@IsExpend_BOA		Bit				--是否展開BOA
	 ,@IsBOF2PO			Bit				--是否將BOF資料轉入採購
	 ,@IsBOA2PO			Bit				--是否將BOA資料轉入採購
	 ,@TestType			Int				--是否為虛擬庫存計算(0: 實際寫入Table; 1: 僅傳出Temp Table; 2: 不回傳Temp Table; 3: 實際寫入Table，但不回傳Temp Table)
	 ,@UserID			VarChar(10) = ''
	 ,@IsBOO2PO			bit = 0
	 ,@IsExpendArticle	Bit	= 0			--add by Edward 是否展開至Article，For U.A轉單
	 ,@IsExpend_Aitem	Bit	= 1			--是否將A項目資料轉入採購
	 ,@IsBOT2PO			Bit	= 1			--是否將Thread資料轉入採購
	 ,@IsPOHeadOnly		BIT = 0			--是否只轉出PO表頭
	)
As
Begin
	Set NoCount On;

	Declare @Progress VarChar(Max);
	Declare @StartTime DateTime;
	Declare @EndTime DateTime;
	Declare @TimeDuration Int;

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
			 , SystemCreate bit default 0, FOC Numeric(10,2) default 0, Junk bit default 0, ColorDetail NVarChar(200) default ''
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
		
		Create Table #tmpPO_Supp_Detail_Keyword
		(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), KeywordField VarChar(30), KeywordValue VarChar(200), Seq2_Count Int
			, Primary Key (ID, Seq1, Seq2, KeywordField, Seq2_Count)
		);
	End;
	----------------------------------------------------------------------
	Declare @ErrorMessage NVarChar(4000);
	Declare @ErrorSeverity Int;
	Declare @ErrorState Int;

	Declare @BrandID VarChar(8);
	Declare @ProgramID VarChar(12);
	Declare @Category VarChar(1);
	Declare @IsMixMarker VarChar(1);
	Declare @CFMDate Date;
	Declare @AllowanceCombinDate Date;

	Select @BrandID = Orders.BrandID
		 , @ProgramID = Orders.ProgramID
		 , @Category = Orders.Category
		 , @IsMixMarker = Orders.IsMixMarker
		 , @CFMDate = Orders.CFMDate
	  From dbo.Orders
	 Where ID = @PoID;

	Select @AllowanceCombinDate = Cast(pValue as date) from Trade.dbo.ParameterSetting where pType = 'AllowanceCombo' and pName = 'CfmDate'

	--確認Order資料是否存在
	If @@RowCount = 0
	Begin
		Return;
	End;
	----------------------------------------------------------------------
	--Check PO Only IsBuyBack or not	
	IF (SELECT Count(DISTINCT IsBuyBack) FROM Orders WHERE POID = @PoID) > 1
	BEGIN
		Set @Progress = 'PO - ' + @PoID + ' - The SP# in PO combo must be all buy back or all not';
		RaisError (@Progress, 0, 1) With NoWait;
		return;
	END	
	----------------------------------------------------------------------
	--組合 Cutting Combine
	Declare @tmpCuttingCombo Table
		(PoID VarChar(13), CuttingSP VarChar(13), OrderID VarChar(13));
	Insert Into @tmpCuttingCombo 
		Exec dbo.GetCuttingCombine @PoID, 0;
	Begin Try
		Begin Transaction

		Update dbo.Orders
		   Set Orders.CuttingSP = (Select CuttingSP From @tmpCuttingCombo Where [@tmpCuttingCombo].OrderID = Orders.ID)
		 Where PoID = @PoID;
		
		Commit Transaction;
	End Try
	Begin Catch
		RollBack Transaction

		Set @ErrorMessage = Error_Message();
		Set @ErrorSeverity = Error_Severity();
		Set @ErrorState = Error_State();

		RaisError (@ErrorMessage,	-- Message text.
				   @ErrorSeverity,	-- Severity.
				   @ErrorState		-- State.
				  );
	End Catch;
	----------------------------------------------------------------------
	--Prophet訂單自動轉單.不計算Each Cons. 
	If @IsExpend_BOF = 1 And @IsMixMarker != 1
	Begin
		Set @StartTime = GetDate();

		Declare @CuttingSP VarChar(13);
		Declare @CuttingCombo Table
			(RowID BigInt Identity(1,1) Not Null, CuttingSP VarChar(13));
		Declare @CuttingComboRowID Int;		--Row ID
		Declare @CuttingComboRowCount Int;	--總資料筆數

		Insert Into @CuttingCombo
			(CuttingSP)
			Select CuttingSP
			  From dbo.Orders
			 Where ID = @PoID
			 Group by CuttingSP
			 Order by CuttingSP;
		--------------------Loop Start @CuttingCombo--------------------
		Set @CuttingComboRowID = 1;
		Select @CuttingComboRowID = Min(RowID), @CuttingComboRowCount = Max(RowID) From @CuttingCombo
		While @CuttingComboRowID <= @CuttingComboRowCount
		Begin
			Select @CuttingSP = CuttingSP
			  From @CuttingCombo
			 Where RowID = @CuttingComboRowID;
			 
			 IF(@IsMixMarker = 0)
			 BEGIN
				Exec dbo.CalculateEachCons @PoID, @CuttingSP, 'S', 0, @TestType;
			 END
			 ELSE
			 BEGIN
				--Compare
				Exec dbo.CompareEachCons @PoID, 0, 'S', 'M', 0, @UserID, ''
			 END
			
			If @TestType = 0 Or @TestType = 3
			Begin
				Begin Try
					Begin Transaction

					Update dbo.Orders
					   Set Orders.EachConsSource = 'O'
					 Where CuttingSP = @CuttingSP;
				
					Commit Transaction;
				End Try
				Begin Catch
					RollBack Transaction

					Set @ErrorMessage = Error_Message();
					Set @ErrorSeverity = Error_Severity();
					Set @ErrorState = Error_State();

					RaisError (@ErrorMessage,	-- Message text.
							   @ErrorSeverity,	-- Severity.
							   @ErrorState		-- State.
							  );
				End Catch;
			End;
			Set @CuttingComboRowID += 1;
		End;
		--------------------Loop End @CuttingCombo--------------------
		Set @EndTime = GetDate();
		Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
		Set @Progress = 'PO - ' + @PoID + ' - Cal. Each Cons. Time:' + Convert(VarChar(Max), @TimeDuration);
		RaisError (@Progress, 0, 1) With NoWait;
	End;
	----------------------------------------------------------------------
	--Expend BOF
	If @IsExpend_BOF = 1
	Begin
		Set @StartTime = GetDate();

		Exec dbo.BofExpend @PoID, '', @TestType, @UserID, @IsExpendArticle;

		Set @EndTime = GetDate();
		Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
		Set @Progress = 'PO - ' + @PoID + ' - Expend BOF Time:' + Convert(VarChar(Max), @TimeDuration);
		RaisError (@Progress, 0, 1) With NoWait;
	End;
	----------------------------------------------------------------------
	--Expend BOA
	If @IsExpend_BOA = 1
	Begin
		Set @StartTime = GetDate();

		Exec dbo.BoaExpend 
			@ID = @PoID, 
			@Order_BOAUkey = 0, 
			@TestType = @TestType, 
			@UserID = @UserID, 
			@IsGetFabQuot = 1, 
			@IsExpendDetail = 0, 
			@IsExpendArticle = @IsExpendArticle;

		Set @EndTime = GetDate();
		Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
		Set @Progress = 'PO - ' + @PoID + ' - Expend BOA Time:' + Convert(VarChar(Max), @TimeDuration);
		RaisError (@Progress, 0, 1) With NoWait;
	End;
	----------------------------------------------------------------------
	--BOF to PO
	If @IsBOF2PO = 1 AND @IsPOHeadOnly = 0
	Begin
		Set @StartTime = GetDate();

		Exec dbo.TransferToPO_1_ForBOF @PoID, @BrandID, @ProgramID, @Category, @TestType, @IsExpendArticle;

		Set @EndTime = GetDate();
		Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
		Set @Progress = 'PO - ' + @PoID + ' - Transfer PO - BOF Time:' + Convert(VarChar(Max), @TimeDuration);
		RaisError (@Progress, 0, 1) With NoWait;
	End;
	----------------------------------------------------------------------
	--BOA to PO
	If @IsBOA2PO = 1 AND @IsPOHeadOnly = 0
	Begin
		Set @StartTime = GetDate();

		Exec dbo.TransferToPO_1_ForBOA @PoID, @BrandID, @ProgramID, @Category, @TestType, @IsBOO2PO, @IsExpendArticle;

		Set @EndTime = GetDate();
		Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
		Set @Progress = 'PO - ' + @PoID + ' - Transfer PO - BOA Time:' + Convert(VarChar(Max), @TimeDuration);
		RaisError (@Progress, 0, 1) With NoWait;
	End;
	----------------------------------------------------------------------
	--Item A to PO
	If @IsExpend_Aitem = 1 AND @IsPOHeadOnly = 0
	BEGIN
		Set @StartTime = GetDate();

		Exec dbo.TransferToPO_1_ForAItem @PoID, @BrandID, @ProgramID, @Category, @TestType, @IsExpendArticle;

		Set @EndTime = GetDate();
		Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
		Set @Progress = 'PO - ' + @PoID + ' - Transfer PO - Item A Time:' + Convert(VarChar(Max), @TimeDuration);
		RaisError (@Progress, 0, 1) With NoWait;
	END	
	----------------------------------------------------------------------
	--填入共同資料
	Set @StartTime = GetDate();

	Exec dbo.TransferToPO_2 @PoID, 0, @TestType, @UserID;

	Set @EndTime = GetDate();
	Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
	Set @Progress = 'PO - ' + @PoID + ' - Transfer PO2 Time:' + Convert(VarChar(Max), @TimeDuration);
	RaisError (@Progress, 0, 1) With NoWait;
	----------------------------------------------------------------------
	--Item Thread
	If @IsBOT2PO = 1 AND @IsPOHeadOnly = 0
	BEGIN
		IF @CFMDate < @AllowanceCombinDate
		BEGIN
			Set @StartTime = GetDate();

			Exec dbo.TransferToPO_1_ForThread @PoID;

			Set @EndTime = GetDate();
			Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
			Set @Progress = 'PO - ' + @PoID + ' - Transfer PO - Item Thread (old) Time:' + Convert(VarChar(Max), @TimeDuration);
			RaisError (@Progress, 0, 1) With NoWait;
		END
		ELSE
		BEGIN
			Set @StartTime = GetDate();

			Exec dbo.TransferToPO_1_ForThreadAllowance @PoID;

			Set @EndTime = GetDate();
			Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
			Set @Progress = 'PO - ' + @PoID + ' - Transfer PO - Item Thread (new) Time:' + Convert(VarChar(Max), @TimeDuration);
			RaisError (@Progress, 0, 1) With NoWait;
		END
	END	
	----------------------------------------------------------------------
	--將資料轉入至Table
	If @TestType = 0 Or @TestType = 3
	Begin
		Set @StartTime = GetDate();

		Exec dbo.TransferToPO_3_Insert @PoID, '', '', @PoHandle, @PoSMR, 0, @UserID;

		Set @EndTime = GetDate();
		Set @TimeDuration = DateDiff(Second, @StartTime, @EndTime);
		Set @Progress = 'PO - ' + @PoID + ' - Transfer PO Insert Complete Time:' + Convert(VarChar(Max), @TimeDuration);
		RaisError (@Progress, 0, 1) With NoWait;
	End;
	
	If (@TestType <> 2) And (@TestType <> 3)
	Begin
		Select * From #tmpPO_Supp;
		Select * From #tmpPO_Supp_Detail;
		Select * From #tmpPO_Supp_Detail_OrderList;
	End;

	Drop Table #tmpPO_Supp;
	Drop Table #tmpPO_Supp_Detail;
	Drop Table #tmpPO_Supp_Detail_OrderList;
End;

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO';
Go
