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
If Object_Id ( 'dbo.TransferToPO_1_ForBOA', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_1_ForBOA;
Go

Create Procedure [dbo].[TransferToPO_1_ForBOA]
	(
	  @PoID			VarChar(13)		--採購母單
	 ,@BrandID		VarChar(8)
	 ,@ProgramID	VarChar(12)
	 ,@Category		VarChar(1)
	 ,@TestType		Int				--資料來源是否為暫存檔
	 ,@IsBOO2PO		bit = 1
	 ,@IsExpendArticle	Bit			= 0			--add by Edward 是否展開至Article，For U.A轉單
	 ,@IncludeQtyZero	Bit			= 0			--add by Edward 是否包含數量為0
	 ,@UpdateType	Int				= 0			--0:PO, 1:Vas/Shas
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
	Declare @UsedQty Numeric(11,4);
	--Declare @UnitRound Numeric(2,0);
	--Declare @UsageRound Numeric(2,0);
	--Declare @RoundStep Numeric(4,2);
	Declare @NetQty Numeric(10,2);
	Declare @LossQty Numeric(10,2);
	Declare @LossFOC Numeric(10,2);
	Declare @SystemNetQty Numeric(10,2);
	Declare @BatchQty Numeric(12,2);
	Declare @PurchaseQty Numeric(12,2);
	Declare @Remark NVarChar(Max);
	Declare @Remark_Shell NVarChar(Max);

	----------------------------------------------------------------------
	/*
	Declare @AccerroryLoss Table
		(  RowID BigInt Identity(1,1) Not Null, SciRefNo VarChar(30), ColorID VarChar(6), Article VarChar(8)
		 , SizeCode VarChar(8), Remark NVarChar(Max), BomZipperInsert VarChar(5)
		 , BomCustPONo VarChar(30), LossYds Numeric(9,2), LossYds_FOC Numeric(9,2), PlusName VarChar(30)
		);
		
	Insert Into @AccerroryLoss
		(  SciRefNo, ColorID, Article, SizeCode, BomZipperInsert, BomCustPONo, LossYds, LossYds_FOC, PlusName
		)
		Select SciRefNo, ColorID, Article, SizeCode, BomZipperInsert, BomCustPONo, LossYds, LossYds_FOC, PlusName
		  From dbo.GetLossAccessory(@PoID, '') as tmpLoss
		 Order by SciRefNo, ColorID, Article, SizeCode, BomZipperInsert, BomCustPONo;
	*/
	-----------------------------------------------------------------------------------------
	--2017.09.13 modify by Ben
	/*
	Declare @AccerroryLoss Table
		(  RowID BigInt Identity(1,1) Not Null, SciRefNo VarChar(30), ColorID VarChar(6)
		 , SizeSpec VarChar(15), BomZipperInsert VarChar(5), BomCustPONo VarChar(30), Keyword VarChar(Max)
		 , LossYds Numeric(12,2), LossYds_FOC Numeric(12,2), PlusName VarChar(100)
		);
	Insert Into @AccerroryLoss
		(  SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Keyword, LossYds, LossYds_FOC, PlusName
		)
		Select SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Keyword, LossYds, LossYds_FOC, PlusName
		  From dbo.GetLossAccessory(@PoID, '', 0) as tmpLoss
		 Order by SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Keyword;
	*/
	Declare @AccerroryLoss Table
		(  RowID BigInt Identity(1,1) Not Null, BoaUkey BigInt, Seq1 VarChar(3), SciRefNo VarChar(30), ColorID VarChar(6)
		 , SizeSpec VarChar(15), BomZipperInsert VarChar(5), BomCustPONo VarChar(30), Remark NVarChar(Max), Keyword VarChar(Max)
		 , Special NVarChar(Max)
		 , LossYds Numeric(12,2), LossYds_FOC Numeric(12,2)
		);
	Insert Into @AccerroryLoss
		( Seq1, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, Special, LossYds, LossYds_FOC)
		Select Seq1, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, CalSpecial, Sum(LossYds) as LossYds, Sum(LossYds_FOC) as LossYds_FOC
		  From dbo.GetLossAccessory(@PoID, '', 0, @IsExpendArticle,@IncludeQtyZero) as tmpLoss
		  outer apply (select CalSpecial = iif(tmpLoss.MtlTypeID = 'STICKER' and @Category in ('B', 'M') and @IsExpendArticle = 1
												, tmpLoss.Special, '')) csp
		 Group by Seq1, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, CalSpecial
		 Order by Seq1, SciRefNo, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Keyword, CalSpecial;
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
		 /*, LossType Numeric(1,0), LossPercent Numeric(3,1), LossQty Numeric(3,0), LossStep Numeric(6,0)*/
		 , BomTypeColor Bit, IsTrimCardOther Bit
		);
	Declare @tmpOrder_BOARowID Int;		--Row ID
	Declare @tmpOrder_BOARowCount Int;	--總資料筆數
	
	Declare @Boa_ExpendUkeys varchar(max);
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
	--Declare @BomFactory VarChar(8);
	--Declare @BomCountry VarChar(2);
	--Declare @BomStyle VarChar(15);
	--Declare @BomCustCD VarChar(20);
	--Declare @BomArticle VarChar(8);
	Declare @BomZipperInsert VarChar(5);
	--Declare @BomBuymonth VarChar(10);
	Declare @BomCustPONo VarChar(30);
	Declare @Spec VarChar(Max);
	Declare @Keyword VarChar(Max);
	Declare @Keyword_Original VarChar(Max);
	Declare @Special VarChar(Max);
	Declare @SeasonID varchar(10);

	-- 判斷是否要忽略Remark條件
	Declare @IsIgnoreRemark bit = (Select Trade.dbo.CheckIgnore(@POID, 'TransferIgnoreRemark', 'SCISeason'));

	Declare @tmpOrder_BOA_Expend Table
		(  RowID BigInt Identity(1,1) Not Null, Boa_ExpendUkeys varchar(max), OrderQty Numeric(6,0)
		 , Price Numeric(12,4), ColorID VarChar(6), Article VarChar(8), SuppColor NVarChar(Max)
		 , SizeCode VarChar(8), SizeSpec VarChar(15), SizeUnit VarChar(8)
		 , UsageQty Numeric(10,2), UsageUnit VarChar(8), SysUsageQty Numeric(10,2), ExpendRemark NVarChar(Max)
		 , BomZipperInsert VarChar(5), BomCustPONo VarChar(30), Keyword VarChar(Max), Keyword_Original VarChar(Max), Special VarChar(Max)
		);
	Declare @tmpOrder_BOA_ExpendRowID Int;		--Row ID
	Declare @tmpOrder_BOA_ExpendRowCount Int;	--總資料筆數

	Declare @tmpOrder_BOA_Expend_OrderList Table
		(  RowID BigInt Identity(1,1) Not Null, Boa_ExpendUkeys varchar(max), OrderID Varchar(13)
		);

	Declare @tmpOrder_BOA_Expend_Spec Table
		(  RowID BigInt Identity(1,1) Not Null, Boa_ExpendUkeys varchar(max), SpecColumnID Varchar(50), SpecValue Varchar(50)
		);

	Declare @Used_FabricType Table
		(FabricType VarChar(1));
	----------------------------------------------------------------------
	/*	--2017.09.12 mark by Ben
	Select distinct SizeItem, Description into #UsedSizeItems From Order_SizeItem Where ID = @PoID and SizeItem <= 'Z50' and SizeItem <> 'S00' order by SizeItem

	Select FabricPanelCode into #UsedFabricPanelCodes From (
		Select distinct FabricPanelCode From Order_ColorCombo Where ID = @PoID
	) x order by Right(' ' + FabricPanelCode, 2)
	*/
	Insert Into @tmpOrder_BOA
		(  BoaUkey, FabricType, RefNo, SCIRefNo, SuppID, ConsPC, Width, Seq1
		 , ColorDetail, POUnit, IsECFA, HaveShell
		 --, LossType, LossPercent, LossQty, LossStep
		 , BomTypeColor, IsTrimCardOther
		)
		Select Order_BOA.Ukey, Fabric.Type, Order_BOA.RefNo, Order_BOA.SciRefNo
			 , supp.NewSupp, Order_BOA.ConsPc, Fabric.Width, Order_BOA.Seq1, Order_BOA.ColorDetail
			 , IsNull(Fabric_Supp.POUnit, '') as POUnit, ifa.IsECFA as IsECFA
			 , IsNull((Select Top 1 1 From dbo.Order_BOA_Shell Where Order_BOAUkey = Order_BOA.Ukey), 0) as HaveShell
			 --, Order_BOA.LossType, Order_BOA.LossPercent, Order_BOA.LossQty, Order_BOA.LossQty
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
		  Outer apply (Select Junk, Lock From dbo.CheckFabricUseful(Fabric.SCIRefno, Orders.SeasonID, supp.NewSupp)) cfu
		 Where Order_BOA.ID = @PoID
			And ((@UpdateType = 0
					And Order_BOA.Ukey not in ( select Order_BOAUkey from Order_Label_Detail old where old.ID in (select Id from Orders where POID = @PoID) and old.Order_BOAUkey is not null))
				 Or
				 (@UpdateType = 1
					And Order_BOA.Ukey in ( select Order_BOAUkey from Order_Label_Detail old where old.ID in (select Id from Orders where POID = @PoID) and old.Order_BOAUkey is not null)))
			And cfu.Lock = 0 And cfu.Junk = 0
			
		 /*	--2017.09.12 mark by Ben
		 --AND (isnull(Order_BOA.SizeItem,'') = '' or exists(select 1 from #UsedSizeItems us where us.SizeItem = Order_BOA.SizeItem))
		 --AND (isnull(Order_BOA.FabricPanelCode,'') = '' or exists(select 1 from #UsedFabricPanelCodes uf where uf.FabricPanelCode = Order_BOA.FabricPanelCode))
		 */
		 and (@IsBOO2PO = 1 or mt.IsTrimCardOther = 0)
		 and (@Category != 'G' or (@Category = 'G' and mt.AllowTransPoForGarmentSP = 1 and supp.NewSupp != 'FTY'))
		 Order by Seq1, IsECFA, NewSupp, SCIRefNo;
	----------------------------------------------------------------------
	--建立虛擬Table
	If object_id('tempdb..#Tmp_BoaExpend_All') is not null
	Drop table #Tmp_BoaExpend_All

	Create Table #Tmp_BoaExpend_All
	(  ExpendUkey BigInt Identity(1,1) Not Null, ID Varchar(13), Order_BOAUkey BigInt
		, RefNo VarChar(36), SCIRefNo VarChar(30), Article VarChar(8), ColorID VarChar(6), SuppColor NVarChar(Max)
		, SizeCode VarChar(8), SizeSpec VarChar(15), SizeUnit VarChar(8), Remark NVarChar(Max)
		, OrderQty Numeric(6,0), Price Numeric(12,4), UsageQty Numeric(11,2), UsageUnit VarChar(8), SysUsageQty  Numeric(11,2)
		, BomZipperInsert VarChar(5), BomCustPONo VarChar(30), Keyword VarChar(Max), Keyword_Original VarChar(Max), Keyword_xml VarChar(Max)
		, OrderList nvarchar(max), ColorDesc nvarchar(150), Special nvarchar(max)
		, BomTypeColorID varchar(50), BomTypeSize varchar(50), BomTypeSizeUnit varchar(50), BomTypeZipperInsert varchar(50), BomTypeArticle varchar(50), BomTypeCOO varchar(50)
		, BomTypeGender varchar(50), BomTypeCustomerSize varchar(50), BomTypeDecLabelSize varchar(50), BomTypeBrandFactoryCode varchar(50), BomTypeStyle varchar(50)
		, BomTypeStyleLocation varchar(50), BomTypeSeason varchar(50), BomTypeCareCode varchar(50), BomTypeCustomerPO varchar(50), BomTypeBuyMonth varchar(50), BomTypeBuyerDlvMonth varchar(50)
		, Primary Key (ExpendUkey)
		, Index Idx_ID NonClustered (ID, Order_BOAUkey, ColorID) -- table index
	);

	If object_id('tempdb..#Tmp_BoaExpend') is not null
	Drop table #Tmp_BoaExpend

	Create Table #Tmp_BoaExpend
	(  ExpendUkey BigInt Not Null, ID Varchar(13), Order_BOAUkey BigInt
		, RefNo VarChar(36), SCIRefNo VarChar(30), Article VarChar(8), SuppColor NVarChar(Max)
		, SizeCode VarChar(8), Remark NVarChar(Max)
		, OrderQty Numeric(6,0), Price Numeric(12,4), UsageQty Numeric(11,2), UsageUnit VarChar(8), SysUsageQty  Numeric(11,2)
		, Keyword VarChar(Max), Keyword_Original VarChar(Max), Keyword_xml VarChar(Max), Special nvarchar(max)
		, Primary Key (ExpendUkey)
		, Index Idx_ID NonClustered (ID, Order_BOAUkey) -- table index
	);

	If object_id('tempdb..#Tmp_BoaExpend_OrderList') is not null
	Drop table #Tmp_BoaExpend_OrderList

	Create Table #Tmp_BoaExpend_OrderList
	(	ExpendUkey BigInt, ID Varchar(13), OrderID Varchar(13)
		Index Idx_ID NonClustered (ExpendUkey, ID, OrderID) -- table index
	);

	If object_id('tempdb..#Tmp_BoaExpend_Spec') is not null
	Drop table #Tmp_BoaExpend_Spec

	Create Table #Tmp_BoaExpend_Spec
	(	ExpendUkey BigInt, ID Varchar(13), SpecColumnID Varchar(50), SpecValue Varchar(50)
		Index Idx_ID NonClustered (ExpendUkey, ID, SpecColumnID) -- table index
	);

	If object_id('tempdb..#Tmp_BoaExpend_Keyword') is not null
	Drop table #Tmp_BoaExpend_Keyword

	Create Table #Tmp_BoaExpend_Keyword
	(	ExpendUkey BigInt, ID Varchar(13), KeywordField Varchar(30), KeywordValue Varchar(200)
		Index Idx_ID NonClustered (ExpendUkey, ID, KeywordField) -- table index
	);

	--是否為虛擬展開
	if @TestType = 1
	BEGIN		
		declare @Tmp_Order_Qty dbo.QtyBreakdown
		insert into @Tmp_Order_Qty
		select Order_Qty.ID ,Article ,SizeCode ,Order_Qty.Qty ,SewOutputQty ,SewOutputUpdate ,OriQty  From dbo.Order_Qty
		 Inner Join dbo.Orders
			On Orders.ID = Order_Qty.ID
		 Where Orders.PoID = @POID;

		Insert Into #Tmp_BoaExpend_All(ID, Order_BOAUkey, RefNo, SCIRefNo, Article, ColorID, SuppColor, SizeCode
		, SizeSpec, SizeUnit, Remark, OrderQty, Price, UsageQty, UsageUnit, SysUsageQty, BomZipperInsert
		, BomCustPONo, Keyword, Keyword_Original, Keyword_xml, OrderList, ColorDesc, Special
		, BomTypeColorID, BomTypeSize, BomTypeSizeUnit, BomTypeZipperInsert, BomTypeArticle, BomTypeCOO, BomTypeGender, BomTypeCustomerSize
		, BomTypeDecLabelSize, BomTypeBrandFactoryCode, BomTypeStyle, BomTypeStyleLocation, BomTypeSeason, BomTypeCareCode, BomTypeCustomerPO
		, BomTypeBuyMonth, BomTypeBuyerDlvMonth)
		select ID, Order_BOAUkey, RefNo, SCIRefNo, Article, ColorID, SuppColor, SizeCode
		, SizeSpec, SizeUnit, Remark, OrderQty, Price, UsageQty, UsageUnit, SysUsageQty , BomZipperInsert
		, BomCustPONo, Keyword, Keyword_Original, Keyword_xml, OrderList, ColorDesc, Special
		, BomTypeColorID, BomTypeSize, BomTypeSizeUnit, BomTypeZipperInsert, BomTypeArticle, BomTypeCOO, BomTypeGender, BomTypeCustomerSize
		, BomTypeDecLabelSize, BomTypeBrandFactoryCode, BomTypeStyle, BomTypeStyleLocation, BomTypeSeason, BomTypeCareCode, BomTypeCustomerPO
		, BomTypeBuyMonth, BomTypeBuyerDlvMonth
		from GetBOAExpend(@POID, 0, 1, 0, @Tmp_Order_Qty, @IsExpendArticle, @IncludeQtyZero)
		order by RefNo, SCIRefNo, ColorID, Article, SizeSeq, SizeSpec, BomZipperInsert, Keyword, Special

		Declare @Keyword_xml xml;
		
		Declare @ExpendCursor Table
			(RowID BigInt Identity(1,1) Not Null, ExpendUkey BigInt);

		Declare @RowID Int;		--ID起始比數
		Declare @RowCount Int;	--總資料筆數		
		Declare @ExpendUkey BigInt;

		Insert Into @ExpendCursor (ExpendUkey)
		Select ExpendUkey From #Tmp_BoaExpend_All;
		Set @RowID = 1
		--Select @RowCount = Count(*) From #Tmp_BoaExpend_All
		Select @RowID = Min(RowID), @RowCount = Max(RowID) From @ExpendCursor;
		While @RowID <= @RowCount
		Begin
			Select @ExpendUkey = ExpendUkey
			From @ExpendCursor
			Where RowID = @RowID;

			Insert Into #Tmp_BoaExpend
			(  ExpendUkey, ID, Order_BOAUkey, RefNo, SCIRefNo, Article, SuppColor
					, SizeCode, Remark, OrderQty, Price, UsageQty
					, UsageUnit, SysUsageQty, Keyword, Keyword_Original
					, Special
				)
			select ExpendUkey, ID, Order_BOAUkey, RefNo, SCIRefNo, Article, SuppColor
					, SizeCode, Remark, OrderQty, Price, UsageQty
					, UsageUnit, SysUsageQty, Keyword, Keyword_Original, Special
			from #Tmp_BoaExpend_All
			Where ExpendUkey = @ExpendUkey;

			Insert Into #Tmp_BoaExpend_OrderList (ID, ExpendUkey, OrderID)
			Select ID, ExpendUkey, tmp.Data
			From #Tmp_BoaExpend_All
			Cross Apply (Select * From dbo.SplitString(#Tmp_BoaExpend_All.OrderList, ',') where Data <> '') as tmp
			Where ExpendUkey = @ExpendUkey;

			Insert Into #Tmp_BoaExpend_Spec
			(	ID, ExpendUkey, SpecColumnID, SpecValue)
			SELECT @POID, @ExpendUkey, SpecColumnID, SpecValue
			FROM   
			   (SELECT Color = BomTypeColorID
			   , Size = BomTypeSize
			   , SizeUnit = BomTypeSizeUnit
			   , ZipperInsert = BomTypeZipperInsert
			   , Article = BomTypeArticle
			   , COO = BomTypeCOO
			   , Gender = BomTypeGender
			   , CustomerSize = BomTypeCustomerSize
			   , DecLabelSize = BomTypeDecLabelSize
			   , BrandFactoryCode = BomTypeBrandFactoryCode
			   , Style = BomTypeStyle
			   , StyleLocation = BomTypeStyleLocation
			   , Season = BomTypeSeason
			   , CareCode = BomTypeCareCode
			   , CustomerPO = BomTypeCustomerPO
			   , BuyMonth = BomTypeBuyMonth
			   , BuyerDlvMonth = BomTypeBuyerDlvMonth
			   FROM #Tmp_BoaExpend_All
			   Where ExpendUkey = @ExpendUkey) p  
			UNPIVOT  
			(
				SpecValue FOR SpecColumnID IN   
				(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)  
			) AS unpvt
			Where SpecValue is not null;

			Select @Keyword_xml = cast(Keyword_xml as xml)
			From #Tmp_BoaExpend_All
			Where ExpendUkey = @ExpendUkey;

			Insert Into #Tmp_BoaExpend_Keyword
			(	ID, ExpendUkey, KeywordField, KeywordValue)
			SELECT @POID
				, @ExpendUkey
				, KeywordField = Tbl.Col.value('KeywordField[1]', 'VARCHAR(30)')
				, KeywordValue = Tbl.Col.value('KeywordValue[1]', 'VARCHAR(200)')
			FROM @Keyword_xml.nodes('//row') Tbl(Col)

			Set @RowID += 1
		END
	END
	ELSE
	BEGIN
		Insert Into #Tmp_BoaExpend
		( ExpendUkey, ID, Order_BOAUkey, RefNo, SCIRefNo, Article, SuppColor
				, SizeCode, Remark, OrderQty, Price, UsageQty
				, UsageUnit, SysUsageQty, Keyword, Keyword_Original
				, Special
			)
		select UKEY, ID, Order_BOAUkey, RefNo, SCIRefNo, Article, SuppColor
				, SizeCode, Remark, OrderQty, Price, UsageQty
				, UsageUnit, SysUsageQty, Keyword, Keyword_Original, Special
		from Order_BOA_Expend
		WHERE Id = @PoID

		Insert Into #Tmp_BoaExpend_OrderList (ID, ExpendUkey, OrderID)
		SELECT ID, Order_BOA_ExpendUkey, OrderID 
		FROM Order_BOA_Expend_OrderList
		WHERE ID = @PoID

		Insert Into #Tmp_BoaExpend_Spec
			(	ID, ExpendUkey, SpecColumnID, SpecValue)
		SELECT ID, Order_BOA_ExpendUkey, SpecColumnID, SpecValue
		FROM Order_BOA_Expend_Spec
		Where ID = @PoID

		Insert Into #Tmp_BoaExpend_Keyword
			(	ID, ExpendUkey, KeywordField, KeywordValue)
		SELECT ID, Order_BOA_ExpendUkey, KeywordField, KeywordValue
		FROM Order_BOA_Expend_Keyword
		Where ID = @PoID
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
			 /*
			 , @BoaLossType = LossType
			 , @BoaLossPercent = LossPercent
			 , @BoaLossQty = LossQty
			 , @BoaLossStep = LossStep
			 */
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
		Delete From @tmpOrder_BOA_Expend;
		Insert Into @tmpOrder_BOA_Expend
			(  Boa_ExpendUkeys, OrderQty, Price, ColorID, Article, SuppColor, SizeCode, SizeSpec, SizeUnit
			 , UsageQty, UsageUnit, SysUsageQty, ExpendRemark
			 , BomZipperInsert, BomCustPONo, Keyword, Keyword_Original, Special
			)
			Select ukeys, sum(OrderQty), max(Price), obe_spec.Color, obe_spec.Article, SuppColor, SizeCode, obe_spec.Size, SizeUnit
				 , sum(UsageQty), obe.UsageUnit, sum(SysUsageQty), getRemark.value
				 , obe_spec.ZipperInsert, obe_spec.CustomerPO, obe.Keyword, obe.Keyword_Original, CalSpecial
			  From #Tmp_BoaExpend obe
			  outer apply (
				select *
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(spec.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join #Tmp_BoaExpend_Spec spec with (nolock) on spec.ExpendUkey = obe.ExpendUkey and BomType.ID = spec.SpecColumnID
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in
					(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)
				) as p
			  ) obe_spec
			  inner join dbo.Order_BOA boa on obe.Order_BOAUkey = boa.Ukey
			  LEFT JOIN Trade.dbo.Fabric f on obe.SCIRefno = f.SCIRefno
			  outer apply (select CalSpecial = iif(f.MtlTypeID = 'STICKER', obe.Special, '')) csp
			  outer apply (
				select ukeys = stuff((select ',' + cast(tmp.ExpendUkey as varchar(max)) 
				from #Tmp_BoaExpend tmp
				outer apply (
					select *
					from 
					(
						select BomTypeID = BomType.ID, SpecValue = isnull(spec.SpecValue, '')
						from Trade.dbo.BomType with (nolock)
						left join #Tmp_BoaExpend_Spec spec with (nolock) on spec.ExpendUkey = tmp.ExpendUkey and BomType.ID = spec.SpecColumnID
					)tmp
					pivot
					(
						MAX(SpecValue) for BomTypeID in
						(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)
					) as p
				) tmp_spec
				LEFT JOIN Trade.dbo.Fabric f on tmp.SCIRefno = f.SCIRefno
				outer apply (select CalSpecial = iif(f.MtlTypeID = 'STICKER', tmp.Special, '')) csp2
				where tmp.Order_BOAUkey = obe.Order_BOAUkey
					and tmp_spec.Color = obe_spec.Color 
					and tmp_spec.Article = obe_spec.Article 
					and tmp.SuppColor = obe.SuppColor 
					and tmp.SizeCode = obe.SizeCode 
					and tmp_spec.Size = obe_spec.Size
					and isnull(tmp_spec.SizeUnit, '') = isnull(obe_spec.SizeUnit, '')
					and tmp.UsageUnit = obe.UsageUnit
					and (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and tmp.Remark = obe.Remark))
					and tmp_spec.ZipperInsert = obe_spec.ZipperInsert
					and tmp_spec.CustomerPO = obe_spec.CustomerPO
					and isnull(tmp.Keyword, '') = isnull(obe.Keyword, '')
					and tmp.Special = obe.Special
					and csp.CalSpecial = csp2.CalSpecial
				for xml path('')),1,1,'')) uks
			 outer apply (
				select value = stuff((
					select Distinct Concat('$', Trade.dbo.ReplaceASCII(dobe.Remark))
					from #Tmp_BoaExpend dobe
					outer apply (
						select *
						from 
						(
							select BomTypeID = BomType.ID, SpecValue = isnull(spec.SpecValue, '')
							from Trade.dbo.BomType with (nolock)
							left join #Tmp_BoaExpend_Spec spec with (nolock) on spec.ExpendUkey = dobe.ExpendUkey and BomType.ID = spec.SpecColumnID
						)tmp
						pivot
						(
							MAX(SpecValue) for BomTypeID in
							(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)
						) as p
					) dobe_spec
					inner join dbo.Order_BOA oboa on dobe.Order_BOAUkey = oboa.Ukey
					outer apply (select CalSpecial = iif(f.MtlTypeID = 'STICKER', dobe.Special, '')) csp2
					where oboa.Seq1 = boa.Seq1
					and dobe.Id = obe.Id
					and dobe.SCIRefno = obe.SCIRefno
					and dobe_spec.Color = obe_spec.Color
					and dobe_spec.Article = obe_spec.Article
					and dobe.SuppColor = obe.SuppColor 
					and dobe.SizeCode = obe.SizeCode 
					and dobe_spec.Size = obe_spec.Size 
					and isnull(dobe_spec.SizeUnit, '') = isnull(obe_spec.SizeUnit, '')
					and dobe.UsageUnit = obe.UsageUnit
					and (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and dobe.Remark = obe.Remark))
					and dobe_spec.ZipperInsert = obe_spec.ZipperInsert
					and dobe_spec.CustomerPO = obe_spec.CustomerPO
					and isnull(dobe.Keyword, '') = isnull(obe.Keyword, '')
					and dobe.Special = obe.Special
					and csp.CalSpecial = csp2.CalSpecial
					for xml path(''), type).value('(./text())[1]','nvarchar(max)')
				, 1, 1 ,'')
			 ) getRemark
			 Where obe.ID = @PoID
			   And Order_BOAUkey = @BoaUkey
			   --2017.09.12 Add by Ben, 有顏色才轉
			   And (   (@BomTypeColor = 0)
					Or (	@BomTypeColor = 1
						And obe_spec.Color != ''
					   )
				   )
			 group by ukeys, obe_spec.Color, obe_spec.Article, SuppColor, SizeCode, obe_spec.Size, SizeUnit
				 , obe.UsageUnit, getRemark.value
				 , obe_spec.ZipperInsert, obe_spec.CustomerPO, obe.Keyword, obe.Keyword_Original, CalSpecial
			 Order by ukeys
			   ;
		--------------------Loop Start @tmpOrder_BOA_Expend--------------------
		Set @tmpOrder_BOA_ExpendRowID = 1;
		Select @tmpOrder_BOA_ExpendRowID = Min(RowID), @tmpOrder_BOA_ExpendRowCount = Max(RowID) From @tmpOrder_BOA_Expend;
		While @tmpOrder_BOA_ExpendRowID <= @tmpOrder_BOA_ExpendRowCount
		Begin
			Select @Boa_ExpendUkeys = Boa_ExpendUkeys
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
				 --, @BomFactory = BomFactory
				 --, @BomCountry = BomCountry
				 --, @BomStyle = BomStyle
				 --, @BomCustCD = BomCustCD
				 --, @BomArticle = BomArticle
				 , @BomZipperInsert = IsNull(BomZipperInsert, '')
				 --, @BomBuymonth = BomBuymonth
				 , @BomCustPONo = IsNull(BomCustPONo, '')
				 , @Keyword = IsNull(Keyword, '')
				 , @Keyword_Original = IsNull(Keyword_Original, '')
				 , @Special = IsNull(Special, '')
			  From @tmpOrder_BOA_Expend
			 Where RowID = @tmpOrder_BOA_ExpendRowID;
			
			Delete From @tmpOrder_BOA_Expend_Spec
			Insert Into @tmpOrder_BOA_Expend_Spec
				(Boa_ExpendUkeys, SpecColumnID, SpecValue)
			Select ExpendUkey, SpecColumnID, SpecValue
			From #Tmp_BoaExpend_Spec
			Where ExpendUkey in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ','))

			Delete From @tmpOrder_BOA_Expend_OrderList
			Insert Into @tmpOrder_BOA_Expend_OrderList
				(Boa_ExpendUkeys, OrderID)
			Select ExpendUkey, OrderID
			From #Tmp_BoaExpend_OrderList
			Where ExpendUkey in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ','))

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
				Set @Remark += IIF(@Remark = '', '',Char(13) + Char(10)) + @Remark_Shell;
			End;
			
			--------------------------------------
			--單件用量
			Set @UsedQty = @ConsPC;
			--------------------------------------
			--取得無條件進位的小數位數
			/*
			Set @UnitRound = 0;
			Set @UsageRound = 0;
			Set @RoundStep = 0;
			Select @UnitRound = UnitRound
				 , @UsageRound = UsageRound
				 , @RoundStep = RoundStep
			  From Trade.dbo.GetUnitRound(@BrandID, @ProgramID, @Category, @UsageUnit);
			*/
			--------------------------------------
			--採購數量(單位換算)
			--Set @NetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @UsageQty);
			--Set @SystemNetQty = Trade.dbo.GetUnitQty(@UsageUnit, @POUnit, @SysUsageQty);
			Set @NetQty = @UsageQty;
			Set @SystemNetQty = @SysUsageQty;
			--------------------------------------
			--損耗數(Loss Qty)
			Set @LossQty = 0;
			Set @LossFOC = 0;
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
			--Set @PurchaseQty = Trade.dbo.GetCeiling((@NetQty + @LossQty), @UnitRound, @RoundStep);
			Set @PurchaseQty = @NetQty + @LossQty;
			--------------------------------------
			If @PurchaseQty > 0
			Begin
				Set @HavePo_Supp = 1;
				
				Set @Seq2 = '';

				/*
				Select @Seq2_Count = Max(Seq2_Count)
				  From #tmpPO_Supp_Detail
				 Where ID = @PoID
				   And Seq1 = @Seq1_New
				   And SCIRefNo = @SCIRefNo
				   And ColorID = IsNull(@ColorID, '')
				   And SizeSpec = IsNull(@SizeSpec, '')
				   And BomZipperInsert = IsNull(@BomZipperInsert, '')
				   And BomCustPONo = IsNull(@BomCustPONo, '')
				   And (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 And Remark = IsNull(@Remark, '')))
				   And Keyword = IsNull(@Keyword, '')
				   And Special = IsNull(@Special, '');
				*/

				Select @Seq2_Count = Max(po3.Seq2_Count)
				From #tmpPO_Supp_Detail po3
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
					   And Seq2_Count = @Seq2_Count;
					
					--寫入Temp Table - PO_Supp_Detail_OrderList
					--當不存在Order_BOA_Expend_OrderList時，將全數OrderList寫入#tmpPO_Supp_Detail_OrderList，最後會判斷刪除
					If not exists (select 1 from @tmpOrder_BOA_Expend_OrderList Where Boa_ExpendUkeys in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ',')))
					Begin
						Insert Into #tmpPO_Supp_Detail_OrderList (ID, Seq1, Seq2, OrderID, Seq2_Count)
						Select DISTINCT @PoID, @Seq1_New, @Seq2, ID, @Seq2_Count
						From dbo.Orders
						Where PoID = @PoID 
						And Not Exists (Select 1 From #tmpPO_Supp_Detail_OrderList
										Where ID = @PoID
											And Seq1 = @Seq1_New
											And Seq2 = @Seq2
											And Seq2_Count = @Seq2_Count
											And OrderID = Orders.ID
										);
					End
					Else
					Begin
						Insert Into #tmpPO_Supp_Detail_OrderList (ID, Seq1, Seq2, OrderID, Seq2_Count)
						Select DISTINCT @PoID, @Seq1_New, @Seq2, OrderID, @Seq2_Count
						From #Tmp_BoaExpend_OrderList Order_BOA_Expend_OrderList
						Where ExpendUkey in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ','))
						And Not Exists (Select 1 From #tmpPO_Supp_Detail_OrderList
										Where ID = @PoID
											And Seq1 = @Seq1_New
											And Seq2 = @Seq2
											And Seq2_Count = @Seq2_Count
											And OrderID = Order_BOA_Expend_OrderList.OrderID
										);
					End
				End;
				Else
				Begin
					--取得該大項最大號
					Set @Seq2 = '';
					Select @Seq2_Count = IsNull(Max(Seq2_Count), 0) + 1
					  From #tmpPO_Supp_Detail
					 Where ID = @PoID
					   And Seq1 = @Seq1_New;
					--------------------------------------
					/*
					If @Category = 'M'
					Begin
						Set @NetQty = 0;
						Set @LossQty = 0;
					End;
					*/
					--------------------------------------
					Set @Spec = @Keyword;
					
					Set @LossQty = 0;
					Set @LossFOC = 0;
					Select @LossQty = sum(LossYds)
						 , @LossFOC = sum(LossYds_FOC)
					  From @AccerroryLoss
					 Where Seq1 = @Seq1
					   And SciRefNo = @SCIRefNo
					   And ColorID = @ColorID
					   And SizeSpec = @SizeSpec
					   And BomZipperInsert = @BomZipperInsert
					   And BomCustPONo = @BomCustPONo
					   And (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 And Remark = @ExpendRemark))
					   And Keyword = @Keyword
					   And Special = @Special;
					/* -- 2017.09.28 mark by Ben
					If @BomZipperInsert != ''
					Begin
						If @BomZipperInsert = 'Right'
						Begin
							Set @Spec = 'Right Insert(右插左拉)' + @Keyword
						End;
						If @BomZipperInsert = 'Left'
						Begin
							Set @Spec = 'Left Insert(左插右拉)' + @Keyword
						End;
					End;
					*/
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
						)
					Values
						(  @PoID, @Seq1_New, @Seq2, @RefNo, @SCIRefNo, @FabricType, @Price, @UsedQty, @PurchaseQty, @POUnit
						 , RTrim(LTrim(@ColorID)), @SuppColor, @Remark, @Remark_Shell, @Width, @NetQty, @LossQty, @LossFOC, @SystemNetQty
						 , @ColorDetail, @SizeSpec, @SizeUnit
						 , @BomZipperInsert, @BomCustPONo, @Spec, @Keyword, @Keyword_Original, @Special--, @Article
						 , @Seq2_Count
						);
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_OrderList
					If not exists (select 1 from @tmpOrder_BOA_Expend_OrderList Where Boa_ExpendUkeys in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ',')))
					Begin						
						--當不存在Order_BOA_Expend_OrderList時，將全數OrderList寫入#tmpPO_Supp_Detail_OrderList，最後會判斷刪除
						Insert Into #tmpPO_Supp_Detail_OrderList (ID, Seq1, Seq2, OrderID, Seq2_Count)
						Select DISTINCT @PoID, @Seq1_New, @Seq2, ID, @Seq2_Count
						From dbo.Orders
						Where PoID = @PoID
					End
					Else
					Begin
						Insert Into #tmpPO_Supp_Detail_OrderList
						(ID, Seq1, Seq2, OrderID, Seq2_Count)
						Select DISTINCT @PoID, @Seq1_New, @Seq2, OrderID, @Seq2_Count
						From #Tmp_BoaExpend_OrderList
						Where ExpendUkey in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ','));
					End
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_Spec
					Insert Into #tmpPO_Supp_Detail_Spec(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
					Select DISTINCT @PoID, @Seq1_New, @Seq2, SpecColumnID, SpecValue, @Seq2_Count
					From #Tmp_BoaExpend_Spec
					Where ExpendUkey in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ','))
					--------------------------------------
					--寫入Temp Table - PO_Supp_Detail_Keyword
					Insert Into #tmpPO_Supp_Detail_Keyword(ID, Seq1, Seq2, KeywordField, KeywordValue, Seq2_Count)
					Select DISTINCT @PoID, @Seq1_New, @Seq2, KeywordField, KeywordValue, @Seq2_Count
					From #Tmp_BoaExpend_Keyword
					Where ExpendUkey in (select data from Trade.dbo.SplitString(@Boa_ExpendUkeys, ','))
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
	--2020/11/20 [IST20202042] 更新Qty和Foc，若物料IsFOC = 1 則將Qty更新至Foc
	Update #tmpPO_Supp_Detail
	   Set Qty = iif(Fabric.IsFOC = 1, 0, Trade.dbo.GetCeiling((#tmpPO_Supp_Detail.NetQty + #tmpPO_Supp_Detail.LossQty), tmpUnitRound.UnitRound, tmpUnitRound.RoundStep))
		, Foc = iif(Fabric.IsFOC = 1
			, Trade.dbo.GetCeiling((#tmpPO_Supp_Detail.NetQty + #tmpPO_Supp_Detail.LossQty), tmpUnitRound.UnitRound, tmpUnitRound.RoundStep) + #tmpPO_Supp_Detail.FOC
			, #tmpPO_Supp_Detail.FOC)
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
	--當OrderList數等於#tmpPO_Supp_Detail_OrderList數時刪除#tmpPO_Supp_Detail_OrderList
	delete tmpPo4
	from #tmpPO_Supp_Detail_OrderList tmpPo4
	outer apply (select count(*) c From dbo.Orders Where PoID = @PoID) orderlist
	outer apply (
		select count(*) c
		From #tmpPO_Supp_Detail_OrderList tmp
		where tmp.ID = tmpPo4.ID
		and tmp.Seq1 = tmpPo4.Seq1
		and tmp.Seq2 = tmpPo4.Seq2
		and tmp.Seq2_Count = tmpPo4.Seq2_Count
	) po4
	where po4.c = orderlist.c
	--------------------------------------

	--Select * From #tmpPO_Supp;
	--Select * From #tmpPO_Supp_Detail;
	--Select * From #tmpPO_Supp_Detail_OrderList;

	--drop table #UsedSizeItems
	--drop table #UsedFabricPanelCodes
End

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_1_ForBOA';
Go
