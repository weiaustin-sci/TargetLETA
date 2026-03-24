Use [Trade]
Go
/****** Object:  StoredProcedure [dbo].[BoaExpend]    Script Date: 2015/10/20 上午 10:06:43 ******/
Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Ben
-- Create date: 2015/11/12
-- Description:
--		Transfer To PO - BOA
-- =============================================
If Object_Id ( 'dbo.TransferToPO_1_ForVasShas', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_1_ForVasShas;
Go

Create Procedure [dbo].[TransferToPO_1_ForVasShas]
	(
	  @PoID			VarChar(13)		--採購母單
	 ,@BrandID		VarChar(8)
	 ,@ProgramID	VarChar(12)
	 ,@Category		VarChar(1)
	 ,@TestType		Int				--資料來源是否為暫存檔
	 ,@IsBOO2PO		bit = 1
	 ,@IsExpendArticle	Bit			= 0			--add by Edward 是否展開至Article，For U.A轉單
	 ,@IncludeQtyZero	Bit			= 0			--add by Edward 是否包含數量為0
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
			 , FabricType VarChar(1) default '', Price Numeric(12,4) default 0, UsedQty Numeric(11,4) default 0, Qty Numeric(10,2) default 0
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
			 , OrderID VarChar(13) default '', OrderList Varchar(max) default ''
			 , Primary Key (ID, Seq1, Seq2, Seq2_Count, OrderID)
			);

		Create Table #tmpPO_Supp_Detail_OrderList
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), OrderID VarChar(13), Seq2_Count Int
			 , Primary Key (ID, Seq1, Seq2, OrderID, Seq2_Count)
			);
		Create Table #tmpPO_Supp_Detail_Spec
		(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), SpecColumnID VarChar(50), SpecValue VarChar(50), Seq2_Count Int
			, OrderID VarChar(13), OrderList Varchar(max) default ''
			, Primary Key (ID, Seq1, Seq2, SpecColumnID, Seq2_Count, OrderID)
		);
		Create Table #tmpPO_Supp_Detail_Keyword
		(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), KeywordField VarChar(30), KeywordValue VarChar(200), Seq2_Count Int
			, OrderID VarChar(13), OrderList Varchar(max) default ''
			, Primary Key (ID, Seq1, Seq2, KeywordField, Seq2_Count, OrderID)
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
	Declare @OrderList VarChar(max);
	Declare @OrderID VarChar(13);
	Declare @Seq2 VarChar(2);
	Declare @Seq2_Count Int;
	Declare @UsedQty Numeric(11,4);
	Declare @NetQty Numeric(10,2);
	Declare @LossQty Numeric(10,2);
	Declare @LossFOC Numeric(10,2);
	Declare @SystemNetQty Numeric(10,2);
	Declare @BatchQty Numeric(12,2);
	Declare @PurchaseQty Numeric(12,2);
	Declare @Remark NVarChar(Max);
	Declare @Remark_Shell NVarChar(Max);	
	----------------------------------------------------------------------
	Declare @AccerroryLoss Table
		(  RowID BigInt Identity(1,1) Not Null, BoaUkey BigInt, Seq1 VarChar(3), SciRefNo VarChar(30), ColorID VarChar(6)
		 , SizeSpec VarChar(15), BomZipperInsert VarChar(5), BomCustPONo VarChar(30), Remark NVarChar(Max), Keyword VarChar(Max)
		 , Special NVarChar(Max)
		 , LossYds Numeric(12,2), LossYds_FOC Numeric(12,2)
		 , OrderID VarChar(13)
		);
	Insert Into @AccerroryLoss
		( OrderID, Seq1, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, Special, LossYds, LossYds_FOC)
		Select OrderID, Seq1, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, Special, Sum(LossYds) as LossYds, Sum(LossYds_FOC) as LossYds_FOC
		  From dbo.GetLossVasShas(@PoID, '', 0, @IsExpendArticle,@IncludeQtyZero) as tmpLoss
		 Group by Seq1, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, Special, OrderID
		 Order by Seq1, OrderID, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, Special;
	-----------------------------------------------------------------------------------------
	Declare @tempSeq1 VarChar(3);
	Declare @tempSuppID VarChar(6);
	Declare @tempSupp_Seq1 Table
		(RowID BigInt Identity(1,1) Not Null, Seq1 VarChar(3), SuppID VarChar(6));
	Declare @tempSupp_Seq1RowID Int;		--Row ID
	Declare @tempSupp_Seq1RowCount Int;	--總資料筆數

	Declare @BoaUkey BigInt;
	Declare @FabricType VarChar(1);
	Declare @FabricCode VarChar(3);
	Declare @RefNo VarChar(36);
	Declare @SCIRefNo VarChar(30);
	Declare @SuppID VarChar(6);
	Declare @ConsPC Numeric(8,4);
	Declare @Width Numeric(5, 2);
	Declare @ColorDetail NVarChar(Max);
	Declare @POUnit VarChar(8);
	Declare @IsECFA Bit;
	Declare @HaveShell Bit;
	Declare @BoaLossType Numeric(1,0);
	Declare @BoaLossPercent Numeric(3,1);
	Declare @BoaLossQty Numeric(3,0);
	Declare @BoaLossStep Numeric(6,0);
	Declare @BomTypeColor Bit;
	Declare @tmpOrder_BOA Table
		(  RowID BigInt Identity(1,1) Not Null, BoaUkey BigInt, FabricType VarChar(1)
		 , RefNo VarChar(36), SCIRefNo VarChar(30), SuppID VarChar(6), ConsPC Numeric(8,4), Width Numeric(5, 2)
		 , Seq1 VarChar(3), ColorDetail NVarChar(Max), POUnit VarChar(8), IsECFA Bit, HaveShell Bit
		 , BomTypeColor Bit, IsTrimCardOther Bit, OrderID VarChar(13)
		);
	Declare @tmpOrder_BOARowID Int;		--Row ID
	Declare @tmpOrder_BOARowCount Int;	--總資料筆數
	
	Declare @Boa_ExpendUkey BigInt;
	Declare @OrderQty Numeric(6,0);
	Declare @Price Numeric(12,4);
	Declare @ColorID VarChar(6);
	Declare @Article VarChar(8);
	Declare @SuppColor NVarChar(Max);
	Declare @SizeCode VarChar(8);
	Declare @SizeSpec VarChar(15);
	Declare @SizeUnit VarChar(8);
	Declare @UsageQty Numeric(12,2);
	Declare @UsageUnit VarChar(8);
	Declare @SysUsageQty Numeric(12,2);
	Declare @ExpendRemark NVarChar(Max);
	Declare @BomZipperInsert VarChar(5);
	Declare @BomCustPONo VarChar(30);
	Declare @Spec VarChar(Max);
	Declare @Keyword VarChar(Max);
	Declare @Keyword_Original VarChar(Max);
	Declare @Special VarChar(Max);
	Declare @tmpOrder_BOA_Expend Table
		(  RowID BigInt Identity(1,1) Not Null, Boa_ExpendUkey BigInt, OrderQty Numeric(6,0)
		 , Price Numeric(12,4), ColorID VarChar(6), Article VarChar(8), SuppColor NVarChar(Max)
		 , SizeCode VarChar(8), SizeSpec VarChar(15), SizeUnit VarChar(8)
		 , UsageQty Numeric(10,2), UsageUnit VarChar(8), SysUsageQty Numeric(10,2), ExpendRemark NVarChar(Max)
		 , BomZipperInsert VarChar(5), BomCustPONo VarChar(30), Keyword VarChar(Max), Keyword_Original VarChar(Max), Special VarChar(Max)
		);
	Declare @tmpOrder_BOA_ExpendRowID Int;		--Row ID
	Declare @tmpOrder_BOA_ExpendRowCount Int;	--總資料筆數

	Declare @tmpOrder_BOA_Expend_Spec Table
		(  RowID BigInt Identity(1,1) Not Null, Boa_ExpendUkeys varchar(max), SpecColumnID Varchar(50), SpecValue Varchar(50)
		);

	Declare @Used_FabricType Table
		(FabricType VarChar(1));

	-- 判斷是否要忽略Remark條件
	Declare @IsIgnoreRemark bit = (Select Trade.dbo.CheckIgnore(@POID, 'TransferIgnoreRemark', 'SCISeason'));
	----------------------------------------------------------------------
	Insert Into @tmpOrder_BOA
		(  BoaUkey, FabricType, RefNo, SCIRefNo, SuppID, ConsPC, Width, Seq1
		 , ColorDetail, POUnit, IsECFA, HaveShell
		 , BomTypeColor, IsTrimCardOther
		)
		Select Order_BOA.Ukey, Fabric.Type, Order_BOA.RefNo, Order_BOA.SciRefNo
			 , supp.NewSupp, Order_BOA.ConsPc, Fabric.Width, Order_BOA.Seq1, Order_BOA.ColorDetail
			 , IsNull(Fabric_Supp.POUnit, '') as POUnit, ifa.IsECFA as IsECFA
			 , IsNull((Select Top 1 1 From dbo.Order_BOA_Shell Where Order_BOAUkey = Order_BOA.Ukey), 0) as HaveShell
			 , Order_BOA.BomTypeColor
			 , mt.IsTrimCardOther
		  From dbo.Order_BOA
		  Left Join Trade.dbo.Fabric
			On Fabric.SCIRefno = Order_BOA.SCIRefno
		  left join Trade.dbo.MtlType mt on Fabric.MtltypeId = mt.ID
		  inner join dbo.Orders on Order_BOA.ID = Orders.ID
		  inner join Trade.dbo.Style on Orders.StyleID = Style.Id and Orders.SeasonID = Style.SeasonID and Orders.BrandID = Style.BrandID
		  left join dbo.Factory on Orders.FactoryID = Factory.ID
		  Outer apply ( select dbo.GetECFA_Refno(Order_BOA.Id, Order_BOA.SuppID, Fabric.SCIRefno) as IsECFA) ifa
		  Outer apply ( select NewSupp = iif(ifa.IsECFA = 1, Order_BOA.SuppID, dbo.GetReplaceSupp_ByPOCombo(Order_BOA.SuppID, Order_BOA.SCIRefno, Orders.ID))) supp
		  Left Join Trade.dbo.Fabric_Supp
			On	   Fabric_Supp.SCIRefno = Order_BOA.SCIRefno
			   And Fabric_Supp.SuppID = supp.NewSupp
		 Where Order_BOA.ID = @PoID
				And Order_BOA.Ukey in ( select Order_BOAUkey from Order_Label_Detail old where old.ID in (select Id from Orders where POID = @PoID) and old.Order_BOAUkey is not null)
		 and (@IsBOO2PO = 1 or mt.IsTrimCardOther = 0)
		 and (@Category != 'G' or (@Category = 'G' and mt.AllowTransPoForGarmentSP = 1 and supp.NewSupp != 'FTY'))
		 Order by Seq1, IsECFA, NewSupp, SCIRefNo;

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
	--------------------Loop Start @tmpOrder_BOA--------------------
	Set @tmpOrder_BOARowID = 1;
	Select @tmpOrder_BOARowID = Min(RowID), @tmpOrder_BOARowCount = Max(RowID) From @tmpOrder_BOA;
	While @tmpOrder_BOARowID <= @tmpOrder_BOARowCount
	Begin
		Select @BoaUkey = BoaUkey
			 , @FabricType = FabricType
			 , @RefNo = RefNo
			 , @SCIRefNo = SCIRefNo
			 , @SuppID = SuppID
			 , @ConsPC = ConsPC
			 , @Width = Width
			 , @Seq1 = Seq1
			 , @ColorDetail = ColorDetail
			 , @POUnit = POUnit
			 , @IsECFA = IsECFA
			 , @HaveShell = HaveShell
			 , @BomTypeColor = BomTypeColor
		  From @tmpOrder_BOA
		 Where RowID = @tmpOrder_BOARowID;

		 If(@@rowcount = 0)
		 Begin
			Set @tmpOrder_BOARowID += 1
			Continue;
		 End
		--------------------------------------
		Set @HavePo_Supp = 0;
		--------------------------------------
		If Not Exists (Select 1 From @Used_FabricType Where FabricType = @FabricType)
		Begin
			Insert Into @Used_FabricType
				(FabricType)
			Values
				(@FabricType);
		End;
		--------------------------------------
		Set @SuppCountry = '';
		Select @SuppCountry = CountryID
		  From Trade.dbo.Supp
		 Where ID = @SuppID;
		--------------------------------------
		--[Seq#1]編號
		--若有同編號不同Supplier，則補上第三碼
		/*
		--Local Supplier 之後補上--
		*/
		Select @CountSeq1 = Count(*)
		  From @tmpOrder_BOA
		 Where Seq1 = @Seq1;

		Select @HaveECFA = iif(Count(distinct IsECFA) > 1, 1, 0)
		  From @tmpOrder_BOA
		 Where Seq1 = @Seq1;
		
		set @Seq1_New = '';

		If (@CountSeq1 <= 1) Or (@CountSeq1 > 1 and (@IsECFA = 0 or @HaveECFA = 0))
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
		End;
		--------------------------------------
		Delete From @tmpOrder_BOA_Expend;
		Insert Into @tmpOrder_BOA_Expend
			(  Boa_ExpendUkey, OrderQty, Price, ColorID, Article, SuppColor, SizeCode, SizeSpec, SizeUnit
			 , UsageQty, UsageUnit, SysUsageQty, ExpendRemark
			 , BomZipperInsert, BomCustPONo, Keyword, Keyword_Original, Special
			)
			Select UKey, OrderQty, Price, boa_spec.Color, Order_BOA_Expend.Article, SuppColor, SizeCode, boa_spec.Size, SizeUnit
				 , UsageQty, UsageUnit, SysUsageQty, getRemark.value
				 , boa_spec.ZipperInsert, boa_spec.CustomerPO, Keyword, Keyword_Original, Special
			  From dbo.Order_BOA_Expend
			  outer apply (
				select *
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(spec.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join dbo.Order_BOA_Expend_Spec spec with (nolock) on spec.Order_BOA_ExpendUkey = Order_BOA_Expend.UKEY and BomType.ID = spec.SpecColumnID
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in
					(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)
				) as p
			  ) boa_spec
			  Outer apply (
				select value = stuff((
					select Distinct Concat('$', dobe.Remark)
					from dbo.Order_BOA_Expend dobe
					outer apply (
						select *
						from 
						(
							select BomTypeID = BomType.ID, SpecValue = isnull(spec.SpecValue, '')
							from Trade.dbo.BomType with (nolock)
							left join dbo.Order_BOA_Expend_Spec spec with (nolock) on spec.Order_BOA_ExpendUkey = dobe.UKEY
						)tmp
						pivot
						(
							MAX(SpecValue) for BomTypeID in
							(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)
						) as p
					) dobe_spec
					where dobe.Id = Order_BOA_Expend.Id
						and dobe.SCIRefno = Order_BOA_Expend.SCIRefno
						and dobe_spec.Color = boa_spec.Color
						and dobe.Article = Order_BOA_Expend.Article
						and dobe.SuppColor = Order_BOA_Expend.SuppColor 
						and dobe.SizeCode = Order_BOA_Expend.SizeCode 
						and dobe_spec.Size = boa_spec.Size
						and dobe_spec.SizeUnit = boa_spec.SizeUnit 
						and dobe.UsageUnit = Order_BOA_Expend.UsageUnit
						and dobe_spec.ZipperInsert = boa_spec.ZipperInsert
						and dobe_spec.CustomerPO = boa_spec.CustomerPO
						and (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and dobe.Remark = Order_BOA_Expend.Remark))
						and dobe.Keyword = Order_BOA_Expend.Keyword
						and dobe.Special = Order_BOA_Expend.Special
					for xml path(''))
				, 1, 1 ,'')
			 ) getRemark
			 Where ID = @PoID
			   And Order_BOAUkey = @BoaUkey
			   --2017.09.12 Add by Ben, 有顏色才轉
			   And (   (@BomTypeColor = 0)
					Or (	@BomTypeColor = 1
						And boa_spec.Color != ''
					   )
				   )
			 Order by UKEY
			   ;

		--------------------Loop Start @tmpOrder_BOA_Expend--------------------
		Set @tmpOrder_BOA_ExpendRowID = 1;
		Select @tmpOrder_BOA_ExpendRowID = Min(RowID), @tmpOrder_BOA_ExpendRowCount = Max(RowID) From @tmpOrder_BOA_Expend;
		While @tmpOrder_BOA_ExpendRowID <= @tmpOrder_BOA_ExpendRowCount
		Begin
			Select @Boa_ExpendUkey = Boa_ExpendUkey
				 , @OrderQty = OrderQty
				 , @Price = Price
				 , @ColorID = IsNull(ColorID, '')
				 , @Article = IsNull(Article, '')
				 , @SuppColor = SuppColor
				 , @SizeCode = IsNull(SizeCode, '')
				 , @SizeSpec = IsNull(SizeSpec, '')
				 , @SizeUnit = IsNull(SizeUnit, '')
				 , @UsageQty = UsageQty
				 , @UsageUnit = UsageUnit
				 , @SysUsageQty = SysUsageQty
				 , @ExpendRemark = IsNull(ExpendRemark, '')
				 , @BomZipperInsert = IsNull(BomZipperInsert, '')
				 , @BomCustPONo = IsNull(BomCustPONo, '')
				 , @Keyword = IsNull(Keyword, '')
				 , @Keyword_Original = IsNull(Keyword_Original, '')
				 , @Special = IsNull(Special, '')
			  From @tmpOrder_BOA_Expend
			 Where RowID = @tmpOrder_BOA_ExpendRowID;
			
			Delete From @tmpOrder_BOA_Expend_Spec
			Insert Into @tmpOrder_BOA_Expend_Spec
				(Boa_ExpendUkeys, SpecColumnID, SpecValue)
			Select Order_BOA_ExpendUkey, SpecColumnID, SpecValue
			From dbo.Order_BOA_Expend_Spec
			Where Order_BOA_ExpendUkey = @Boa_ExpendUkey

			--用第一筆訂單ID當代表
			Select Top 1 @OrderID = Isnull(boaeo.OrderID, boae.Id)
			From dbo.Order_BOA_Expend boae
			Left join dbo.Order_BOA_Expend_OrderList boaeo on boae.UKEY = boaeo.Order_BOA_ExpendUkey
			Where boae.UKEY = @Boa_ExpendUkey
			Order by Isnull(boaeo.OrderID, boae.Id)
			
			Select @OrderList = Stuff((
				Select Concat(',', Isnull(boaeo.OrderID, ''))
				From dbo.Order_BOA_Expend boae
				Left join dbo.Order_BOA_Expend_OrderList boaeo on boae.UKEY = boaeo.Order_BOA_ExpendUkey
				Where boae.UKEY = @Boa_ExpendUkey
				Order by Isnull(boaeo.OrderID, boae.Id)
				For xml path('')
			), 1, 1, '')

			If @UsageQty < 0
			Begin
				Set @tmpOrder_BOA_ExpendRowID += 1;
				Continue;
			End;
			--------------------------------------
			--取得Remark
			Set @Remark = Replace(IsNull(@ExpendRemark, ''), '$', ' ' + Char(13) + Char(10));
			set @Remark_Shell = '';
			If @HaveShell = 1
			Begin
				Set @Remark_Shell = IsNull(dbo.GetShellColor(@PoID, @FabricType, @BoaUkey, @ColorID), '');
				Set @Remark += IIF(@Remark = '', '', Char(13) + Char(10)) + @Remark_Shell;
			End;
			
			--------------------------------------
			--單件用量
			Set @UsedQty = @ConsPC;		
			--------------------------------------
			--採購數量(單位換算)
			Set @NetQty = @UsageQty;
			Set @SystemNetQty = @SysUsageQty;
			--------------------------------------
			--損耗數(Loss Qty)
			Set @LossQty = 0;
			Set @LossFOC = 0;

			Select @LossQty = LossYds
					, @LossFOC = LossYds_FOC
				From @AccerroryLoss
				Where Seq1 = @Seq1
				And SciRefNo = @SCIRefNo
				And ColorID = @ColorID
				And SizeSpec = @SizeSpec
				And BomZipperInsert = @BomZipperInsert
				And BomCustPONo = @BomCustPONo
				And (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and Remark	= @ExpendRemark))
				And Keyword = @Keyword
				And Special = @Special
				And BoaUkey = @BoaUkey;
			--損耗數(單位換算)
			/*
			Set @LossQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @LossQty);
			Set @LossFOC = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @LossFOC);
			*/
			--------------------------------------
			--無條件進位
			--NetQty & LossQty 均無條件進位至小數一位
			/*
			Set @NetQty = Trade.dbo.GetCeiling(@NetQty, @UsageRound, 0);
			Set @SystemNetQty = Trade.dbo.GetCeiling(@SystemNetQty, @UnitRound, 0);
			Set @LossQty = Trade.dbo.GetCeiling(@LossQty, @UsageRound, 0);
			Set @LossFOC = Trade.dbo.GetCeiling(@LossFOC, @UsageRound, 0);
			*/

			--------------------------------------
			--採購Qty
			Set @PurchaseQty = @NetQty + @LossQty;
			--------------------------------------
			If @PurchaseQty > 0
			Begin
				Set @HavePo_Supp = 1;
				Set @Seq2 = '';

				/*
				Select @Seq2_Count = Max(po3.Seq2_Count)
				From #tmpPO_Supp_Detail po3
				Outer apply (
					Select value = Stuff((
						Select Concat(',', po4.OrderID)
						From #tmpPO_Supp_Detail_OrderList po4 
						Where po4.id = po3.ID And po4.SEQ1 = po3.Seq1 And po4.SEQ2 = po3.seq2 And po3.OrderID = po4.OrderID
						Order by po4.OrderID
						For xml path('')
					), 1, 1, '')
				) getOrderList
				Where po3.ID = @PoID
					And po3.Seq1 = @Seq1_New
					And po3.SCIRefNo = @SCIRefNo
					And po3.ColorID = IsNull(@ColorID, '')
					And po3.SizeSpec = IsNull(@SizeSpec, '')
					And po3.BomZipperInsert = IsNull(@BomZipperInsert, '')
					And po3.BomCustPONo = IsNull(@BomCustPONo, '')
					And (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and Remark = IsNull(@Remark, '')))
					And po3.Keyword = IsNull(@Keyword, '')
					And po3.Special = IsNull(@Special, '')
					And getOrderList.value = IsNull(@OrderList, '');
				*/

				Select @Seq2_Count = Max(po3.Seq2_Count)
				From #tmpPO_Supp_Detail po3
				Outer apply (
					Select value = isnull(Stuff((
						Select Concat(',', po4.OrderID)
						From #tmpPO_Supp_Detail_OrderList po4 
						Where po4.id = po3.ID And po4.SEQ1 = po3.Seq1 And po4.Seq2_Count = po3.Seq2_Count
						Order by po4.OrderID
						For xml path('')
					), 1, 1, ''), '')
				) getOrderList
				Outer Apply (
					select count(*) c from (
						(
							select SpecColumnID, SpecValue
							from #tmpPO_Supp_Detail_Spec po3s
							where po3.ID = po3s.ID
							and  po3.Seq1 = po3s.Seq1
							and  po3.Seq2 = po3s.Seq2
							and  po3.Seq2_Count = po3s.Seq2_Count
							except
							select SpecColumnID, SpecValue
							from @tmpOrder_BOA_Expend_Spec
						)
						union
						(
							select SpecColumnID, SpecValue
							from @tmpOrder_BOA_Expend_Spec
							except
							select SpecColumnID, SpecValue
							from #tmpPO_Supp_Detail_Spec po3s
							where po3.ID = po3s.ID
							and  po3.Seq1 = po3s.Seq1
							and  po3.Seq2 = po3s.Seq2
							and  po3.Seq2_Count = po3s.Seq2_Count
						)
					) tmp
				) getCount
				Where po3.ID = @PoID
					And po3.Seq1 = @Seq1_New
					And po3.SCIRefNo = @SCIRefNo
					And getCount.c = 0
					And getOrderList.value = @OrderList;
				
				If IsNull(@Seq2_Count, 0) != 0
				Begin
					--Update Temp Table - PO_Supp_Detail
					Update #tmpPO_Supp_Detail
					   Set Qty += @PurchaseQty
						 , NetQty += @NetQty
						 , LossQty += @LossQty
						 , FOC += @LossFOC
						 , SystemNetQty += @SystemNetQty
					 Where ID = @PoID
					   And Seq1 = @Seq1_New
					   And Seq2 = @Seq2
					   And Seq2_Count = @Seq2_Count
					   And OrderList = @OrderList;

					--寫入Temp Table - PO_Supp_Detail_OrderList
					Insert Into #tmpPO_Supp_Detail_OrderList
						(ID, Seq1, Seq2, OrderID, Seq2_Count)
						Select @PoID, @Seq1_New, @Seq2, OrderID, @Seq2_Count
						  From dbo.Order_BOA_Expend_OrderList
						 Where Order_BOA_ExpendUkey = @Boa_ExpendUkey
						   And Not Exists (Select 1 From #tmpPO_Supp_Detail_OrderList
											Where ID = @PoID
											  And Seq1 = @Seq1_New
											  And Seq2 = @Seq2
											  And Seq2_Count = @Seq2_Count
											  And OrderID = Order_BOA_Expend_OrderList.OrderID
										  );
				End;
				Else
				Begin
					--取得該大項最大號
					Set @Seq2 = '';
					Select @Seq2_Count = IsNull(Max(Seq2_Count), 0) + 1
					  From #tmpPO_Supp_Detail
					 Where ID = @PoID
					   And Seq1 = @Seq1_New

					Set @Spec = @Keyword;
					
					Set @LossQty = 0;
					Set @LossFOC = 0;
					Select @LossQty = LossYds
						 , @LossFOC = LossYds_FOC
					  From @AccerroryLoss
					 Where Seq1 = @Seq1
					   And SciRefNo = @SCIRefNo
					   And ColorID = @ColorID
					   And SizeSpec = @SizeSpec
					   And BomZipperInsert = @BomZipperInsert
					   And BomCustPONo = @BomCustPONo
					   And Remark = @ExpendRemark
					   And Keyword = @Keyword
					   And Special = @Special
					   And OrderID = @OrderID;
					--------------------------------------
					--先寫入Temp Table - PO_Supp,避免最大碼+1後跳號
					--------------------------------------
					If Not Exists(Select * From #tmpPO_Supp Where ID = @PoID And Seq1 = @Seq1_New)
					Begin
						Insert Into #tmpPO_Supp
							(ID, Seq1, SuppID)
						Values
							(@PoID, @Seq1_New, @SuppID);
					End;
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail
					Insert Into #tmpPO_Supp_Detail
					(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit
						, ColorID, SuppColor, Remark, Remark_Shell, Width, NetQty, LossQty, FOC, SystemNetQty
						, ColorDetail, SizeSpec, SizeUnit
						, BomZipperInsert, BomCustPONo, Spec, KeyWord, Keyword_Original, Special--, Article
						, Seq2_Count
						, OrderID, OrderList
					)
					Values
					(  @PoID, @Seq1_New, @Seq2, @RefNo, @SCIRefNo, @FabricType, @Price, @UsedQty, @PurchaseQty, @POUnit
						, @ColorID, @SuppColor, @Remark, @Remark_Shell, @Width, @NetQty, @LossQty, @LossFOC, @SystemNetQty
						, @ColorDetail, @SizeSpec, @SizeUnit
						, @BomZipperInsert, @BomCustPONo, @Spec, @Keyword, @Keyword_Original, @Special--, @Article
						, @Seq2_Count
						, @OrderID, @OrderList
					); 
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_OrderList
					--當OrderList數不等於 Po Combo數時才寫入
					Set @ExceptRowCount = (	Select Count(*)
											  From (Select ID From dbo.Orders
													 Where PoID = @PoID 
													Except
													Select OrderID
													  From dbo.Order_BOF_Expend_OrderList
													 Where Order_BOF_ExpendUkey = @Boa_ExpendUkey
												   ) as tmpCount
										  );
					
					If @ExceptRowCount > 0
					Begin
						Insert Into #tmpPO_Supp_Detail_OrderList
							(ID, Seq1, Seq2, OrderID, Seq2_Count)
							Select @PoID, @Seq1_New, @Seq2, OrderID, @Seq2_Count
							  From dbo.Order_BOA_Expend_OrderList
							 Where Order_BOA_ExpendUkey = @Boa_ExpendUkey
								And Not Exists (
									Select 1 From #tmpPO_Supp_Detail_OrderList
									Where ID = @PoID
										And Seq1 = @Seq1_New
										And Seq2 = @Seq2
										And Seq2_Count = @Seq2_Count
										And OrderID = Order_BOA_Expend_OrderList.OrderID
									);
					End;
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_Spec
					Insert Into #tmpPO_Supp_Detail_Spec(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count, OrderID, OrderList)
					Select @PoID, @Seq1_New, @Seq2, SpecColumnID, SpecValue, @Seq2_Count, @OrderID, @OrderList
					From dbo.Order_BOA_Expend_Spec
					Where Order_BOA_ExpendUkey = @Boa_ExpendUkey
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_Keyword
					Insert Into #tmpPO_Supp_Detail_Keyword(ID, Seq1, Seq2, KeywordField, KeywordValue, Seq2_Count, OrderID, OrderList)
					Select @PoID, @Seq1_New, @Seq2, KeywordField, KeywordValue, @Seq2_Count, @OrderID, @OrderList
					From dbo.Order_BOA_Expend_Keyword
					Where Order_BOA_ExpendUkey = @Boa_ExpendUkey
					--------------------------------------
				End;
			End;
			Set @tmpOrder_BOA_ExpendRowID += 1;
		End;

		--------------------Loop End @tmpOrder_BOA_Expend------------- -------
		--寫入Temp Table - PO_Supp
		If @HavePo_Supp = 1
		Begin
			--------------------------------------
			If Not Exists(Select * From #tmpPO_Supp Where ID = @PoID And Seq1 = @Seq1_New)
			Begin
				Insert Into #tmpPO_Supp
					(ID, Seq1, SuppID)
				Values
					(@PoID, @Seq1_New, @SuppID);
			End;
		End;
		--------------------------------------
		Set @tmpOrder_BOARowID += 1;
	End;
	--------------------Loop End @tmpOrder_BOA--------------------
	--------------------------------------
	--Qty、NetQty、LossQty、FOC、SystemNetQty 一律累加完後才做進位
	--先做單位換算，再做無條件進位
	--NetQty & LossQty 均無條件進位至小數一位
	Update #tmpPO_Supp_Detail
	   Set NetQty = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.NetQty), tmpUnitRound.UsageRound, 0)
		 , LossQty = 
				--若LossQtyCalculateType為1要在此轉換單位，若為2表示GetLossAccessory的時候就已經換過了
				iif(mtl.LossQtyCalculateType = '1'
					, Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.LossQty), tmpUnitRound.UsageRound, 0)
					, Trade.dbo.GetCeiling(#tmpPO_Supp_Detail.LossQty, 0, 0))
		 , FOC = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.FOC), tmpUnitRound.UsageRound, 0)
		 , SystemNetQty = Trade.dbo.GetCeiling(Trade.dbo.GetUnitQty(Fabric.UsageUnit, #tmpPO_Supp_Detail.POUnit, #tmpPO_Supp_Detail.SystemNetQty), tmpUnitRound.UnitRound, 0)
	  From #tmpPO_Supp_Detail
	  Left Join Trade.dbo.Fabric
		On	   Fabric.BrandID = @BrandID
		   And Fabric.SCIRefno = #tmpPO_Supp_Detail.SCIRefNo
	  Left join Trade.dbo.MtlType mtl on Fabric.MtltypeId = mtl.ID
	 Outer Apply (Select * From Trade.dbo.GetUnitRound(@BrandID, @ProgramID, @Category, #tmpPO_Supp_Detail.POUnit)) as tmpUnitRound
	 Where Exists (Select 1 From @Used_FabricType Where FabricType = #tmpPO_Supp_Detail.FabricType);
	
	--更新採購Qty
	Update #tmpPO_Supp_Detail
	   Set Qty = Trade.dbo.GetCeiling((#tmpPO_Supp_Detail.NetQty + #tmpPO_Supp_Detail.LossQty), tmpUnitRound.UnitRound, tmpUnitRound.RoundStep)
	  From #tmpPO_Supp_Detail
	  Left Join Trade.dbo.Fabric
		On	   Fabric.BrandID = @BrandID
		   And Fabric.SCIRefno = #tmpPO_Supp_Detail.SCIRefNo
	 Outer Apply (Select * From Trade.dbo.GetUnitRound(@BrandID, @ProgramID, @Category, #tmpPO_Supp_Detail.POUnit)) as tmpUnitRound
	 Where Exists (Select 1 From @Used_FabricType Where FabricType = #tmpPO_Supp_Detail.FabricType);
	--------------------------------------
	--當Category = 'M'時，不計算損耗，更新NetQty & LossQty = 0
	If @Category = 'M'
	Begin
		Update #tmpPO_Supp_Detail
		   Set NetQty = 0
			 , LossQty = 0
		  From #tmpPO_Supp_Detail
		  Left Join Trade.dbo.Fabric
			On	   Fabric.BrandID = @BrandID
			   And Fabric.SCIRefno = #tmpPO_Supp_Detail.SCIRefNo
		 Outer Apply (Select * From Trade.dbo.GetUnitRound(@BrandID, @ProgramID, @Category, #tmpPO_Supp_Detail.POUnit)) as tmpUnitRound
		 Where Exists (Select 1 From @Used_FabricType Where FabricType = #tmpPO_Supp_Detail.FabricType);
	End;
	--------------------------------------
	--Select * From #tmpPO_Supp;
	--Select * From #tmpPO_Supp_Detail;
	--Select * From #tmpPO_Supp_Detail_OrderList;
	--Select * From #tmpPO_Supp_Detail_Spec;

	--drop table #UsedSizeItems
	--drop table #UsedFabricPanelCodes
End

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_1_ForVasShas';
Go