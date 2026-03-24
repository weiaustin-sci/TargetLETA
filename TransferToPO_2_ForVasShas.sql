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
If Object_Id ( 'dbo.TransferToPO_2_ForVasShas', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_2_ForVasShas;
Go

Create Procedure [dbo].[TransferToPO_2_ForVasShas]
	(
	  @PoID			VarChar(13)		--採購母單
	 ,@AppType		Bit				--重新產生資料時是否要覆蓋原始資料
	 ,@TestType		Int				--資料來源是否為暫存檔
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
			 , Status varchar(1), Sel bit default 0, IsForOtherBrand bit
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
	Declare @ExecDate DateTime;
	Set @ExecDate = GetDate();

	Declare @Seq1 VarChar(3);
	Declare @SuppID VarChar(6);
	Declare @ShipTermID VarChar(5);
	Declare @PayTermAPID VarChar(5);
	Declare @Remark NVarChar(Max);
	Declare @Description NVarChar(Max);
	Declare @CompanyID Numeric(2,0);

	Declare @Seq2 VarChar(2);
	Declare @Seq2_Count Int;;
	Declare @Seq2_Add Int;
	Declare @NewSeq2 Numeric(2);
	Declare @NewSeq2_Chr VarChar(2);
	Declare @RefNo VarChar(36);
	Declare @SciRefNo VarChar(30);
	Declare @FabricType VarChar(1);
	Declare @ShipModeID VarChar(10);
	Declare @ColorID VarChar(6);
	Declare @MtlLT Numeric(3,0);
	Declare @LTDay Numeric(1,0);
	Declare @SystemETD Date;
	Declare @SystemETD_Plus7D date;
	Declare @Price Numeric(14,4);
	Declare @tmpPrice Numeric(14,4);
	Declare @Fee Numeric(14,4);
	Declare @FeeUnit VarChar(8);
	Declare @Qty Numeric(10,2);
	Declare @POUnit VarChar(8);
	Declare @StockQty Numeric(10,1);
	Declare @SizeSpec VarChar(15);
	Declare @SizeUnit VarChar(8);
	Declare @Width Numeric(5, 2);
	--Declare @BomFactory VarChar(8);
	--Declare @BomCountry VarChar(2);
	--Declare @BomStyle VarChar(15);
	--Declare @BomCustCD VarChar(20);
	--Declare @BomArticle VarChar(8);
	Declare @BomZipperInsert VarChar(5);
	--Declare @BomBuymonth VarChar(10);
	Declare @BomCustPONo VarChar(30);
	Declare @Special NVarChar(Max);
	Declare @Spec NVarChar(Max);
	Declare @SuppRefno Varchar(30);
	Declare @BrandRefNo varchar(50);
	Declare @BrandID VarChar(8);
	Declare @StyleID VarChar(15);
	Declare @SeasonID VarChar(10);
	Declare @FactoryID VarChar(8);
	Declare @Category VarChar(1);
	Declare @CfmDate Date;
	Declare @OrderTypeID VarChar(20)
	Declare @StyleUkey BigInt;
	Declare @GmtLT Numeric(3,0);
	Declare @ProjectID VarChar(5);
	Declare @ProgramID VarChar(12);
	Declare @OrderCompany Numeric(2,0);
	Declare @PurchaseCompany Numeric(2,0);
	
	Declare @CurrencyID VarChar(3);

	DECLARE @MtlTypeID varchar(20);
	DECLARE @SuppColor varchar(max);
	Declare @RefnoSpec dbo.Refno_Spec;
	Declare @SystemETD_SpecialRule Bit;
	Declare @TargetLETA Date;
	Declare @LoadDate Date;

	Select @BrandID = BrandID
		 , @StyleID = StyleID
		 , @SeasonID = SeasonID
		 , @FactoryID = FactoryID
		 , @Category = Category
		 , @CfmDate = CfmDate
		 , @ProjectID = ProjectID
		 , @ProgramID = ProgramID
		 , @OrderTypeID = OrderTypeID
		 , @OrderCompany = OrderCompany
	  From dbo.Orders
	 Where ID = @PoID;

	DECLARE @IsThirdSchedule BIT = 0;

	SELECT 
		@IsThirdSchedule = IsThirdSchedule 
	FROM dbo.PO 
	WHERE ID = @PoID;

	 DECLARE @KeywordValue NVARCHAR(MAX) = ''

	 IF EXISTS(SELECT 1 FROM Trade.dbo.Brand_PODesc WHERE ID = @BrandID AND ProjectID = @ProjectID AND Category = Category)
	 BEGIN
		select @KeywordValue = dbo.GetKeyword(@PoID, 0, Keyword, '', '', '', 1) from Trade.dbo.Brand_PODesc where ID = @BrandID AND ProjectID = @ProjectID AND Category = @Category
	 END

	Select @StyleUkey = Ukey
		 , @GmtLT = GmtLT
	  From Trade.dbo.Style
	 Where BrandID = @BrandID
	   And ID = @StyleID
	   And SeasonID = @SeasonID;

	Declare @Po_Supp_Detail_Seq Table
		(Seq1 VarChar(3), Seq2 VarChar(2));
	
	If @AppType = 1
	Begin
		Insert Into @Po_Supp_Detail_Seq
		Select Seq1, Seq2
		  From dbo.PO_Supp_Detail
		 Where ID = @PoID
		 Order by Seq1, Seq2;
	End;
	----------------------------------------------------------------------
	Declare @NewSeq1 Numeric(3);
	Declare @NewSeq1_Chr VarChar(3);
	Declare @NewSeq1_Prefix VarChar(1);
	Declare @Format varchar(2);

	Declare @NewSeq1_List Table (Seq1 VarChar(3));
	Declare @Seq2Index Int;

	/*-- 2017.11.23 mark by Ben
	Declare @Seq99_Seq1 VarCHar(3);
	Declare @Po_Seq99 Table
		(RowID BigInt Identity(1,1) Not Null, Seq1 VarChar(3), CntSeq2 Int);
	Declare @Po_Seq99RowID Int;		--Row ID
	Declare @Po_Seq99RowCount Int;	--總資料筆數
	
	Declare @Detail_Seq1 VarCHar(3);
	Declare @Detail_Seq2 VarCHar(2);
	Declare @tmpDetail_Seq Table
		(RowID BigInt Identity(1,1) Not Null, Seq1 VarChar(3), Seq2 VarChar(2));
	Declare @tmpDetail_SeqRowID Int;	--Row ID
	Declare @tmpDetail_SeqRowCount Int;	--總資料筆數
	
	--檢查是否有小項超過99的資料
	Insert Into @Po_Seq99
		(Seq1, CntSeq2)
		Select Seq1, Count(Seq2) CntSeq2
		  From #tmpPO_Supp_Detail
		 Group by Seq1
		Having Count(Seq2) > 99
		Order by Seq1;
	--------------------Loop Start @Po_Seq99--------------------
	Declare @CheckSeq Bit;
	Declare @NCnt Int;
	Declare @ICnt Int;
	Set @Po_Seq99RowID = 1;
	Select @Po_Seq99RowID = Min(RowID), @Po_Seq99RowCount = Max(RowID) From @Po_Seq99;
	While @Po_Seq99RowID <= @Po_Seq99RowCount
	Begin
		Select @Seq99_Seq1 = Seq1
		  From @Po_Seq99
		 Where RowID = @Po_Seq99RowID;
		
		--計算小項
		Set @NCnt = 0;
		Set @ICnt = 1;

		Delete From @tmpDetail_Seq;
		Insert Into @tmpDetail_Seq
			(Seq1, Seq2)
			Select Seq1, Seq2 From #tmpPO_Supp_Detail
			 Where ID = @PoID
			   And Seq1 = @Seq99_Seq1;
		--------------------Loop Start @tmpDetail_Seq--------------------
		Set @tmpDetail_SeqRowID = 1;
		Select @tmpDetail_SeqRowID = Min(RowID), @tmpDetail_SeqRowCount = Max(RowID) From @tmpDetail_Seq;
		While @tmpDetail_SeqRowID <= @tmpDetail_SeqRowCount
		Begin
			Select @Detail_Seq1 = Seq1
				 , @Detail_Seq2 = Seq2
			  From @tmpDetail_Seq
			 Where RowID = @tmpDetail_SeqRowID;
			/*
			Set @NCnt += 1;
			If @NCnt <= 99
			Begin
				Continue;
			End;
			*/
			Set @ICnt = IIF(@ICnt > 99, 1, @ICnt);
			If @ICnt = 1
			Begin
				Set @NewSeq1 = Convert(Numeric(2), SubString(@Seq99_Seq1, 1, 2));
				Set @NewSeq1_Chr = Convert(VarChar(3), @NewSeq1);
				Set @CheckSeq = 1;

				While (@CheckSeq = 1) And (@NewSeq1 <= 99) And (@NewSeq1 Not Between 70 And 79)	--大項超過99，須注意
				Begin
					Set @NewSeq1 += 1;
					--Set @NewSeq1_Chr = Convert(VarChar(3), @NewSeq1);
					Set @NewSeq1_Chr = Format(@NewSeq1, '00');

					If	   (Not Exists(Select ID From dbo.OrdeR_BOF Where ID = @PoID And Seq1 = @NewSeq1_Chr)) 
					   And (Not Exists(Select ID From dbo.OrdeR_BOA Where ID = @PoID And Seq1 = @NewSeq1_Chr))
					   And (Not Exists(Select ID From #tmpPO_Supp Where ID = @PoID And Seq1 = @NewSeq1_Chr))
					Begin
						Set @CheckSeq = 1;
					End;
				End;

				If Exists(Select ID From #tmpPO_Supp Where ID = @PoID And Seq1 = @Detail_Seq1)
				Begin
					Insert Into #tmpPO_Supp
						(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID)
						Select ID, @NewSeq1_Chr, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID
						  From #tmpPO_Supp
						 Where ID = @PoID
						   And Seq1 = @Detail_Seq1;
				End;
			End;
			If @ICnt <= 99
			Begin
				Update #tmpPO_Supp_Detail Set Seq1 = @NewSeq1_Chr
				 Where ID = @PoID And Seq1 = @Detail_Seq1 And Seq2 = @Detail_Seq2;
				Update #tmpPO_Supp_Detail_OrderList Set Seq1 = @NewSeq1_Chr
				 Where ID = @PoID And Seq1 = @Detail_Seq1 And Seq2 = @Detail_Seq2;
				Set @ICnt += 1;
			End;
			Set @tmpDetail_SeqRowID += 1;
		End;
		--------------------Loop End @tmpDetail_Seq--------------------
		Set @Po_Seq99RowID += 1;
	End;
	--------------------Loop End @Po_Seq99--------------------
	*/
	----------------------------------------------------------------------
	Declare @ImportPort VarCHar(20);
	Declare @FactoryCountry VarCHar(2);
	Declare @SuppCountry VarCHar(2);
	Declare @LockDate Date;

	Select @FactoryCountry = CountryID
		 , @ImportPort = PortSea
	  From Trade.dbo.Factory
	 Where ID = @FactoryID;

	-- 2023.02.14 add by Vicky [IST20230130]
	Select @SystemETD_SpecialRule = SystemETD_SpecialRule From Trade.dbo.Brand with(nolock) Where ID = @BrandID

	If @SystemETD_SpecialRule = 1
	Begin
		Select @TargetLETA = TargetLETA From Trade.dbo.PO where ID = @PoID
	End

	Declare @tmpPo_SuppRowID Int;		--Row ID
	Declare @tmpPo_SuppRowCount Int;	--總資料筆數

	Declare @tmpPo_Supp_DetailRowID Int;	--Row ID
	Declare @tmpPo_Supp_DetailRowCount Int;	--總資料筆數
	--------------------Loop Start #tmpPO_Supp--------------------
	Set @tmpPo_SuppRowID = 1;
	Select @tmpPo_SuppRowID = Min(RowID), @tmpPo_SuppRowCount = Max(RowID) From #tmpPO_Supp;
	While @tmpPo_SuppRowID <= @tmpPo_SuppRowCount
	Begin
		Select @Seq1 = Seq1
			 , @SuppID = SuppID
			 , @Description = Description
		  From #tmpPO_Supp
		 Where RowID = @tmpPo_SuppRowID;
		/*
		Set @NewSeq1_Prefix = '';
		Set @Format = '';
		If ASCII(SubString(@Seq1, 1, 1)) > 57
		Begin
			Set @NewSeq1_Prefix = SubString(@Seq1, 1, 1);
			Set @NewSeq1 = Convert(Numeric(1), SubString(@Seq1, 2, 1));
			Set @Format = '0';
		End;
		Else
		Begin
			Set @NewSeq1_Prefix = '';
			Set @NewSeq1 = Convert(Numeric(3), SubString(@Seq1, 1, 2));
			Set @Format = '00';
		End;
		Set @NewSeq1_Chr = @NewSeq1_Prefix + Format(@NewSeq1, @Format);
		*/
		
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

		Set @ShipModeID = IIF(IsNull(@ShipModeID, '') = '', 'SEA', @ShipModeID);	--若Supplier基本檔未設定ShipMode，預設為SEA

		If @LockDate Is Not Null	--已Lock不轉
		Begin
			Delete From #tmpPO_Supp Where ID = @PoID And Seq1 = @Seq1;
			Set @tmpPo_SuppRowID += 1;
			Continue;
		End;
		-------------------------------------
		If @AppType = 1
		Begin
			Set @Seq2_Add = 0;
			Select @NewSeq2_Chr = IsNull(Max(Seq2), '0')
			  From @Po_Supp_Detail_Seq
			 Where Seq1 = @NewSeq1_Chr;
			Set @NewSeq2 = Convert(Numeric(2), @NewSeq2_Chr);
		End;
		Else
		Begin
			Set @Seq2_Add = 0;
		End;
		-------------------------------------
		Delete From @NewSeq1_List;
		--------------------Loop Start #tmpPO_Supp_Detail--------------------
		Select @Seq2Index = IsNull(Max(Cast(Seq2 as int)), 0)
		From #tmpPO_Supp_Detail
		Where Seq1 = @Seq1

		Set @tmpPo_Supp_DetailRowID = 1;
		Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From #tmpPO_Supp_Detail Where ID = @PoID And Seq1 = @Seq1;
		While @tmpPo_Supp_DetailRowID <= @tmpPo_Supp_DetailRowCount
		Begin
			Select @Seq2 = Seq2
				 , @Seq2_Count = Seq2_Count
				 , @RefNo = RefNo
				 , @SciRefNo = SCIRefNo
				 , @FabricType = FabricType
				 , @ColorID = ColorID
				 , @Qty = Qty
				 , @POUnit = POUnit
				 , @SizeSpec = SizeSpec
				 , @SizeUnit = SizeUnit
				 , @Width = Width
				 --, @BomFactory = BomFactory
				 --, @BomCountry = BomCountry
				 --, @BomStyle = BomStyle
				 --, @BomCustCD = BomCustCD
				 --, @BomArticle = BomArticle
				 , @BomZipperInsert = BomZipperInsert
				 --, @BomBuymonth = BomBuymonth
				 , @BomCustPONo = BomCustPONo
				 , @Special = Special
				 , @Spec = Spec
				 , @SuppColor = SuppColor
			  From #tmpPO_Supp_Detail
			 Where RowID = @tmpPo_Supp_DetailRowID
			   And ID = @PoID
			   And Seq1 = @Seq1;

			SELECT @PurchaseCompany = CompanyID
			FROM #tmpPO_Supp
			WHERE ID = @PoID
			And Seq1 = @Seq1;
			
			SET @MtlTypeID = (select MtltypeID FROM Fabric WHERE SCIRefno = @SCIRefNo);

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
				
				IF @IsThirdSchedule = 1
				BEGIN
					DECLARE @eta DATETIME = (SELECT TOP 1 MinKPILETA FROM dbo.GetSCI(@PoID, @Category));
					Set @SystemETD = (SELECT TOP 1 * from Trade.dbo.GetThirdSchedule(@FactoryID, @SuppID, @ShipModeID, @ShipTermID, @eta) ORDER BY LoadDate ASC);
				END
				ELSE
				BEGIN
					If @LTDay = 2
					Begin
						Set @SystemETD = Trade.dbo.GetWorkDay(@CfmDate, @MtlLT);
					End;
					Else
					Begin
						Set @SystemETD = DateAdd(dd, @MtlLT, @CfmDate);
					End;
				END

				-- 2023.02.14 add by Vicky [IST20230130]
				If @SystemETD_SpecialRule = 1 and @TargetLETA is not null
				Begin
					Select @LoadDate = getSchedule.LoadDate
					From (
						select SuppPort = dbo.GetPortBySupp(@ShipModeID, @SuppID)
						, FtyPort = dbo.GetPortByFactory(@ShipModeID, @FactoryID)
					) tmpPort
					Outer Apply (
						select top 1 s.LoadDate
						from dbo.ScheduleGroup as sg with (nolock)
						inner join dbo.Schedule as s with (nolock) on s.ScheduleGroupID = sg.ID			
						where sg.ExportPort = tmpPort.SuppPort and sg.ImportPort = tmpPort.FtyPort and sg.ShipModeID = @ShipModeID
						and dbo.FilterSchedule(sg.FilterShipTerm, sg.filterSupplier, sg.FilterFactory, @ShipTermID, @SuppID, @FactoryID) = 1
						and s.Eta <= @TargetLETA and s.junk = 0 and s.Second = 0 and s.OnTime = 0
						order by s.LoadDate Desc
					) getSchedule

					Set @SystemETD_Plus7D = DateAdd(dd, 7, @SystemETD)
					Set @SystemETD = iif(@LoadDate is null or @LoadDate < @SystemETD_Plus7D, @SystemETD_Plus7D, @LoadDate)
				End
				--------------------------------------------------------
				/*
				--2017.10.10 add by Ben, 當小項超過99時，將大項+1，小項歸零，重新insert
				If @NewSeq2 = 99
				Begin
					Set @NewSeq1 += 1;
					Set @NewSeq1_Chr = @NewSeq1_Prefix + Format(@NewSeq1, '00');
					While (Exists(Select 1 From #tmpPO_Supp Where ID = @PoID And Seq1 = @NewSeq1_Chr))
						 Or (@NewSeq1 Between 50 And 59)
						 Or (@NewSeq1 Between 70 And 79)
					Begin
						Set @NewSeq1 += 1;
						Set @NewSeq1_Chr = @NewSeq1_Prefix + Format(@NewSeq1, '00');
					End;
										
					Set @NewSeq2 = 0;
				End;

				Set @NewSeq2 += 1;
				Set @NewSeq2_Chr = Format(@NewSeq2, '00');
				*/
				If @Seq2 = ''
				Begin
					Set @Seq2Index = @Seq2Index + 1;	
				End;

				--2017.11.24 add by Ben, 調整大小項編號方式
				Select @NewSeq1_Chr = Seq1
					 , @NewSeq2_Chr = Seq2
				  From Trade.dbo.GetPOSeq(@Seq1, @Seq2Index);
				
				If @Seq2 <> ''
				Begin
					Set @NewSeq2_Chr = @Seq2;	
				End;

				If Not Exists (Select 1 From #tmpPO_Supp Where ID = @PoID And Seq1 = @NewSeq1_Chr)
				Begin
					If Not Exists (Select 1 From @NewSeq1_List Where Seq1 = @NewSeq1_Chr)
					Begin
						Insert Into @NewSeq1_List (Seq1) Values (@NewSeq1_Chr);
					End;
				End;
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
					Set @StockQty = 0;
					--取得庫存Ref#
					/*
					Select @InvRefID = InventoryRefNo.ID
					  From Trade.dbo.InventoryRefNo
					 Inner Join dbo.Orders
						On Orders.ID = @PoID
					 Inner Join Trade.dbo.Brand
						On Brand.ID = Orders.BrandID
					 Inner Join Trade.dbo.Inventory
						On	   Inventory.InventoryRefNoID = InventoryRefNo.ID
						   And Inventory.Qty > 0
						   And Inventory.Lock = 0
						   And (   Inventory.ProjectID = ''
							    Or Inventory.ProjectID = Orders.ProjectID
							   )
						   And Inventory.BrandGroup = Brand.BrandGroup
						   And Inventory.FabricType = @FabricType
					 Where InventoryRefNo.RefNo = @RefNo
					   And InventoryRefNo.ColorID = @ColorID
					   And InventoryRefNo.SizeSpec = @SizeSpec
					   And InventoryRefNo.SizeUnit = @SizeUnit
					   And InventoryRefNo.Width = @Width
					   --And InventoryRefNo.BomFactory = @BomFactory
					   --And InventoryRefNo.BomCountry = @BomCountry
					   --And InventoryRefNo.BomStyle = @BomStyle
					   --And InventoryRefNo.BomCustCD = @BomCustCD
					   --And InventoryRefNo.BomArticle = @BomArticle
					   And InventoryRefNo.BomZipperInsert = @BomZipperInsert
					   --And InventoryRefNo.BomBuymonth = @BomBuymonth
					   And InventoryRefNo.BomCustPONo = @BomCustPONo
					   And @Qty != 0;
					*/
					
					delete from @RefnoSpec
					insert into @RefnoSpec (SpecColumnID, SpecValue, BomType)
					select SpecColumnID, SpecValue, cast(1 as bit)
					from #tmpPO_Supp_Detail_Spec
					Where ID = @PoID
					   And Seq1 = @Seq1
					   And Seq2_Count = @Seq2_Count;

					Set @StockQty = dbo.GetStockQty('', @StyleID, @FactoryID, @ProjectID, @ProgramID, @BrandID, @OrderTypeID,
						@RefNo, @PurchaseCompany, @Width, @FabricType, @Category, @MtlTypeID, @PoID, 0, @SuppRefno, @SuppColor, @BrandRefNo, @RefnoSpec, @SeasonID);

				End;
				--------------------------------------------------------
				--更新Temp Table - PO_Supp_Detail
				Update #tmpPO_Supp_Detail
				   Set Seq1 = @NewSeq1_Chr
					 , Seq2 = @NewSeq2_Chr
					 , ShipModeID = @ShipModeID
					 , SystemETD = @SystemETD
					 , FinalETD = @SystemETD
					 , Price = @Price
					 , StockQty = isnull(@StockQty, 0)
				 Where ID = @PoID
				   And Seq1 = @Seq1
				   And (Seq2 = '' or Seq2 = @Seq2)
				   And Seq2_Count = @Seq2_Count;
				
				Update #tmpPO_Supp_Detail_OrderList
				   Set Seq1 = @NewSeq1_Chr
					 , Seq2 = @NewSeq2_Chr
				 Where ID = @PoID
				   And Seq1 = @Seq1
				   And Seq2 = ''
				   And Seq2_Count = @Seq2_Count;

				Update #tmpPO_Supp_Detail_Spec
				   Set Seq1 = @NewSeq1_Chr
					 , Seq2 = @NewSeq2_Chr
				 Where ID = @PoID
				   And Seq1 = @Seq1
				   And Seq2 = ''
				   And Seq2_Count = @Seq2_Count;
			End;
			Set @tmpPo_Supp_DetailRowID += 1;
		End;
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
		 Where ID = @PoID
		   And Seq1 = @Seq1;

		Insert Into #tmpPO_Supp
			(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID)
			Select #tmpPO_Supp.ID, NewSeq1_List.Seq1, #tmpPO_Supp.SuppID, #tmpPO_Supp.ShipTermID, #tmpPO_Supp.PayTermAPID
				 , #tmpPO_Supp.Remark, #tmpPO_Supp.Description, #tmpPO_Supp.CompanyID
			  From @NewSeq1_List as NewSeq1_List
			 Inner Join #tmpPO_Supp
				On #tmpPO_Supp.ID = @POID And #tmpPO_Supp.Seq1 = @Seq1
		-------------------------------------

		Set @tmpPo_SuppRowID += 1;
	End;
	--------------------Loop End #tmpPO_Supp--------------------
	Delete From #tmpPO_Supp_Detail 
	 Where Not Exists (Select ID, Seq1
						From #tmpPO_Supp
					   Where #tmpPO_Supp.ID = #tmpPO_Supp_Detail.ID
					     And #tmpPO_Supp.Seq1 = #tmpPO_Supp_Detail.Seq1
					  );
	Delete From #tmpPO_Supp
	 Where Not Exists (Select ID, Seq1
						From #tmpPO_Supp_Detail
					   Where #tmpPO_Supp_Detail.ID = #tmpPO_Supp.ID
					     And #tmpPO_Supp_Detail.Seq1 = #tmpPO_Supp.Seq1
					  );
End

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_2_ForVasShas';
Go