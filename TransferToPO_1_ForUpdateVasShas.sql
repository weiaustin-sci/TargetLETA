Use [Trade]
Go

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Anderson
-- Create date: 2020/07/02
-- Description:
-- =============================================
If Object_Id ( 'dbo.TransferToPO_1_ForUpdateVasShas ', 'P' ) Is Not Null
    Drop Procedure dbo.TransferToPO_1_ForUpdateVasShas ;
Go

Create Procedure [dbo].[TransferToPO_1_ForUpdateVasShas]
(
	  @PoID			VarChar(13)		--採購母單
	 ,@UserID		VarChar(10) = ''
	 ,@ReturnTable	bit = 0
)
As
Begin
	Set NoCount On;
	----------------------------------------------------------------------

	If Object_ID('tempdb..#tmpPO_Supp') Is Null
	Begin
		Create Table #tmpPO_Supp
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), SuppID VarChar(6) default '', ShipTermID VarChar(5) default '', PayTermAPID VarChar(5) default ''
				, Remark NVarChar(Max) default '', Description NVarChar(Max) default '', CompanyID Numeric(1,0) default 0
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
				, Remark NVarChar(Max) default '', Special NVarChar(Max) default '', Width Numeric(5,1) default 0
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
			, OrderID VarChar(13) default '', OrderList Varchar(max) default ''
			, Primary Key (ID, Seq1, Seq2, SpecColumnID, Seq2_Count, OrderID)
		);
		Create Table #tmpPO_Supp_Detail_Keyword
		(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), KeywordField VarChar(30), KeywordValue VarChar(200), Seq2_Count Int
			, OrderID VarChar(13) default '', OrderList Varchar(max) default ''
			, Primary Key (ID, Seq1, Seq2, KeywordField, Seq2_Count, OrderID)
		);
	End;

	If Object_ID('tempdb..#tmpPO2') Is Null
	Begin
		Create Table #tmpPO2
			(  RowID BigInt Not Null, ID VarChar(13), Seq1 VarChar(3), SuppID VarChar(6) default '', ShipTermID VarChar(5) default '', PayTermAPID VarChar(5) default ''
				, Remark NVarChar(Max) default '', Description NVarChar(Max) default '', CompanyID Numeric(1,0) default 0
				, StyleID VarChar(15), TargetLETA Date, Primary Key (ID, Seq1), Junk Bit
			);
	End;
	If Object_ID('tempdb..#tmpPO3') Is Null
	Begin
		Create Table #tmpPO3
			(  RowID BigInt Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), RefNo VarChar(36) default '', SCIRefNo VarChar(30) default ''
				, FabricType VarChar(1) default '', Price Numeric(14,4) default 0, UsedQty Numeric(10,4) default 0, Qty Numeric(10,2) default 0
				, POUnit VarChar(8) default '', Complete Bit default 0, SystemETD Date, CFMETD Date, RevisedETD Date, FinalETD Date, EstETA Date
				, ShipModeID VarChar(10) default '', PrintDate DateTime, PINO VarChar(25) default '', PIDate Date
				, ColorID VarChar(6) default '', SuppColor NVarChar(Max) default '', SizeSpec VarChar(15) default '', SizeUnit VarChar(8) default ''
				, Remark NVarChar(Max) default '', Special NVarChar(Max) default '', Width Numeric(5,1) default 0
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

		Create Table #tmpPO3S
			(  RowID BigInt Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), SpecColumnID VarChar(50), SpecValue VarChar(50), Seq2_Count Int
				, OrderID VarChar(13), OrderList Varchar(max) default ''
				, Primary Key (ID, Seq1, Seq2, SpecColumnID, Seq2_Count, OrderID)
			);

		Create Table #tmpPO3K
			(  RowID BigInt Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), KeywordField VarChar(30), KeywordValue VarChar(200), Seq2_Count Int
				, OrderID VarChar(13), OrderList Varchar(max) default ''
				, Primary Key (ID, Seq1, Seq2, KeywordField, Seq2_Count, OrderID)
			);

		Create Table #tmpPO4
			(  RowID BigInt Not Null, ID VarChar(13), Seq1 VarChar(3), Seq2 VarChar(2), OrderID VarChar(13), Seq2_Count Int
				, Primary Key (ID, Seq1, Seq2, OrderID, Seq2_Count)
			);		
	End;

	Declare @tmpPo_SuppRowID Int;		--Row ID
	Declare @tmpPo_SuppRowCount Int;	--總資料筆數

	Declare @tmpPo_Supp_DetailRowID Int;	--Row ID
	Declare @tmpPo_Supp_DetailRowCount Int;	--總資料筆數

	Declare @SameSCIGroupRowID Int;
	Declare @SameSCIGroupRowCount Int;
	Create Table #SameSCIGroup 
	( RowID BigInt Not Null, SuppID VarChar(6), Seq1 VarChar(3), Seq2 VarChar(2)
		, SCIRefNo VarChar(30) default '', ColorID Varchar(6), SuppColor NVarChar(Max) default '', SizeSpec VarChar(15) default ''
		, BomZipperInsert VarChar(5) default '' , BomCustPONo VarChar(30) default '', Remark NVarChar(Max) default ''
		, Special NVarChar(Max) default '', Width Numeric(5,1) default 0
		, FirstOrderID VarChar(13) default '', OrderList VarChar(2000) default ''
		, NewQty Numeric(10,2), OriQty Numeric(10,2), NewLossQty Numeric(10,2), OriLossQty Numeric(10,2)
        , Status varchar(1), transEDI bit default 0, NewNetQty Numeric(10,2), OriNetQty Numeric(10,2), OutputQty Numeric(10,2), Seq2_Count Int
	);

	Declare @BrandID VarChar(8);
	Declare @StyleUkey bigint;
	Declare @SeasonID VarChar(10);
	Declare @FactoryID VarChar(8);
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

	declare @TestType	Int = 3 --資料來源是否為暫存檔

	Declare @ExecDate DateTime;
	Set @ExecDate = GetDate();

	Declare @OrderList VarChar(max);
	Declare @FirstOrderID VarChar(13);
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
	Declare @Width Numeric(5,2);
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
	Declare @SuppID VarChar(6);
	Declare @Seq1 VarChar(3);
	Declare @Seq2 VarChar(2);
	Declare @SCIRefNo VarChar(30);
	Declare @ColorID Varchar(6);
	
	Declare @NewSeq1 VarChar(3);
	Declare @tmpSeq1 VarChar(3);
	Declare @transEDI bit = 0;
	Declare @Status varchar(1);

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
	Declare @OutputQty Numeric(10,2);
	Declare @POQty Numeric(10,2);
	Declare @BalanceQty Numeric(10,2);
	Declare @Seq2_Count Int;
	Declare @MtltypeID varchar(20);
	Declare @SuppColor NVarChar(Max);
	Declare @RefnoSpec dbo.Refno_Spec;
	Declare @CannotOperateStock bit;
	Declare @OrderCompany Numeric(2,0);
	Declare @PurchaseCompany Numeric(2,0);
	Declare @SystemETD_AdditionalDays Numeric(3,0);
	
	Declare @CurrencyID VarChar(3);

	select @BrandID = BrandID,
			@StyleID = StyleID,
			@StyleUkey = StyleUkey,
			@SeasonID = SeasonID,
			@Category = Category,
			@CfmDate = CFMDate,
			@FactoryID = FactoryID,
			@FactoryCountry = Factory.CountryID,
			@CountryID = Factory.CountryID,
			@Dest = Orders.Dest,
			@OrderTypeID = OrderTypeID,
			@ProgramID = ProgramID,
			@ProjectID = ProjectID,
			@SystemETD_AdditionalDays = SystemETD_AdditionalDays,
			@OrderCompany = OrderCompany
	from Orders
	inner join Trade.dbo.Factory on Orders.FactoryID = Factory.ID
	Where Orders.ID = @PoID

	Exec TransferToPO_1_ForVasShas @PoID, @BrandID, @ProgramID, @Category, @TestType, 1, 0, 0;

	insert into #tmpPO2
	select * from #tmpPO_Supp

	insert into #tmpPO3
	select * from #tmpPO_Supp_Detail
	
	insert into #tmpPO3S
	select * from #tmpPO_Supp_Detail_Spec

	insert into #tmpPO3K
	select * from #tmpPO_Supp_Detail_Keyword

	insert into #tmpPO4
	select * from #tmpPO_Supp_Detail_OrderList

	delete #tmpPO_Supp
	delete #tmpPO_Supp_Detail
	delete #tmpPO_Supp_Detail_Spec
	delete #tmpPO_Supp_Detail_OrderList

	IF OBJECT_ID('tempdb..#tmpResult') IS NOT NULL DROP TABLE #tmpResult
	Declare @tmpResultRowID Int;	--Row ID
	Declare @tmpResultRowCount Int;	--總資料筆數

	-- 判斷是否要忽略Remark條件
	Declare @IsIgnoreRemark bit = (Select Trade.dbo.CheckIgnore(@POID, 'TransferIgnoreRemark', 'SCISeason'));

	select DENSE_RANK() over(order by Substring(Seq1, 1, 2), NewSeq1, SCIRefNo, a.Seq2_Count, ColorID, SizeSpec, BomZipperInsert, BomCustPONo, iif(@IsIgnoreRemark = 1, '', Remark), Spec, Special, Width, OrderList) RowID, *
	Into #tmpResult
	from (
		select SuppID = isnull(Ori.SuppID, New.SuppID)
			, Seq1 = isnull(Ori.Seq1, '')
			, Seq2 = isnull(Ori.Seq2, '')
			, NewSeq1 = isnull(New.Seq1, '')
			, SCIRefNo = isnull(Ori.SCIRefNo, New.SCIRefNo)
			, ColorID = isnull(Ori.SpecColor, New.SpecColor)
			, SizeSpec = isnull(Ori.SpecSize, New.SpecSize)
			, BomZipperInsert = isnull(Ori.SpecZipperInsert, New.SpecZipperInsert)
			, BomCustPONo = isnull(Ori.SpecCustomerPO, New.SpecCustomerPO)
			, Remark = isnull(Ori.Remark, New.Remark)
			, Spec = isnull(Ori.Spec, New.Spec)
			, Special = isnull(Ori.Special, New.Special)
			, Width = isnull(Ori.Width, New.Width)
			, OrderID = isnull(Ori.OrderID, New.OrderID)
			, OrderList = isnull(Ori.OrderList, New.OrderList)
			, NewQty = New.Qty + isnull(New.FOC, 0)
			, OriQty = isnull(Ori.Qty, 0) + isnull(Ori.OutputQty, 0) + isnull(Ori.FOC, 0)
			, NewLossQty = New.LossQty
			, OriLossQty = isnull(Ori.LossQty, 0)
			, NewNetQty = New.NetQty
			, OriNetQty = isnull(Ori.NetQty, 0)
			, Status = IIF(New.SCIRefNo is not null and Ori.SCIRefNo is null, '1', IIF(New.SCIRefNo is null and Ori.SCIRefNo is not null, '2', IIF(isnull(getTransEDI.value, 0) = 1,'3','1')))
			, TransEDI = isnull(getTransEDI.value, 0)
			, OutputQty = isnull(Ori.OutputQty, 0)
			, Seq2_Count = isnull(New.Seq2_Count, 0)
			------------------補Status = '2'資料用------------------
			, RefNo = isnull(Ori.RefNo, New.RefNo)
			, FabricType = isnull(Ori.FabricType, New.FabricType)
			, Price = isnull(Ori.Price, New.Price)
			, POUnit = isnull(Ori.POUnit, New.POUnit)
			, SuppColor = isnull(Ori.SuppColor, New.SuppColor)
			, SizeUnit = isnull(Ori.SpecSizeUnit, New.SpecSizeUnit)
			, ColorDetail = isnull(Ori.ColorDetail, New.ColorDetail)
			--------------------------------------------------------
		from (
			select po2.SuppId
				, po3.*, spec.*
			from #tmpPO2 po2
			inner join #tmpPO3 po3 on po2.ID = po3.ID and po2.Seq1 = po3.Seq1
			outer apply (
				select SpecColor = p.Color
				, SpecSize = p.Size
				, SpecSizeUnit = p.SizeUnit
				, SpecZipperInsert = p.ZipperInsert
				, SpecArticle = p.Article
				, SpecCOO = p.COO
				, SpecGender = p.Gender
				, SpecCustomerSize = p.CustomerSize
				, SpecDecLabelSize = p.DecLabelSize
				, SpecBrandFactoryCode = p.BrandFactoryCode
				, SpecStyle = p.Style
				, SpecStyleLocation = p.StyleLocation
				, SpecSeason = p.Season
				, SpecCareCode = p.CareCode
				, SpecCustomerPO = p.CustomerPO
				, SpecBuyMonth = p.BuyMonth
				, SpecBuyerDlvMonth = p.BuyerDlvMonth
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(spec.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join #tmpPO3S spec with (nolock) on spec.SpecColumnID = BomType.ID
					where spec.ID = po3.ID and spec.Seq1 = po3.Seq1 and spec.Seq2_Count = po3.Seq2_Count and spec.OrderList = po3.OrderList
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in
					(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)
				) as p
			) spec
			where po2.ID = @PoID
		) New
		Full join (
			select po2.SuppId, po3.*, OrderList = getOrderList.value, getFirstOrderID.OrderID, TransEDI = Cast(1 as bit)
			, spec.*
			from Trade.dbo.PO_Supp po2
			inner join Trade.dbo.PO_Supp_Detail po3 on po2.ID = po3.ID and po2.Seq1 = po3.Seq1
			outer apply (
				select SpecColor = p.Color
				, SpecSize = p.Size
				, SpecSizeUnit = p.SizeUnit
				, SpecZipperInsert = p.ZipperInsert
				, SpecArticle = p.Article
				, SpecCOO = p.COO
				, SpecGender = p.Gender
				, SpecCustomerSize = p.CustomerSize
				, SpecDecLabelSize = p.DecLabelSize
				, SpecBrandFactoryCode = p.BrandFactoryCode
				, SpecStyle = p.Style
				, SpecStyleLocation = p.StyleLocation
				, SpecSeason = p.Season
				, SpecCareCode = p.CareCode
				, SpecCustomerPO = p.CustomerPO
				, SpecBuyMonth = p.BuyMonth
				, SpecBuyerDlvMonth = p.BuyerDlvMonth
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(spec.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join PO_Supp_Detail_Spec spec with (nolock) on spec.SpecColumnID = BomType.ID
					where spec.ID = po3.ID and spec.Seq1 = po3.Seq1 and spec.Seq2 = po3.Seq2
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in
					(Color, Size, SizeUnit, ZipperInsert, Article, COO, Gender, CustomerSize, DecLabelSize, BrandFactoryCode, Style, StyleLocation, Season, CareCode, CustomerPO, BuyMonth, BuyerDlvMonth)
				) as p
			) spec
			Outer apply (
				--已存在DB中的OrderList
				Select value = isnull(stuff((
					Select Concat(',', po4.OrderID)
					From Trade.dbo.PO_Supp_Detail_OrderList po4 
					Where po4.ID = po3.ID and po4.Seq1 = po3.Seq1 and po4.Seq2 = po3.Seq2
					Order by po4.OrderID
					For xml path('')
				), 1, 1, ''), '')
			) getOrderList
			Outer apply (
				Select Top 1 po4.OrderID
				From Trade.dbo.PO_Supp_Detail_OrderList po4 
				Where po4.ID = po3.ID and po4.Seq1 = po3.Seq1 and po4.Seq2 = po3.Seq2
				Order by po4.OrderID
			) getFirstOrderID
			outer apply (
				select count(*) c 
				from Trade.dbo.PO_Supp_Detail 
				where ID = po3.ID and OutputSeq1 = po3.Seq1 and OutputSeq2 = po3.Seq2 and Junk = 0
			) IsOutput
			where po2.ID = @PoID
				and po3.FabricType = 'A'
				And (po3.Junk = 0 or (po3.Junk = 1 and IsOutput.c > 0 ))
				and exists (Select Top 1 1
						From Order_BOA boa
						Where boa.Ukey in (
								Select old.Order_BOAUkey 
								From Order_Label_Detail old 
								Where old.ID in (Select Id From Orders o Where o.POID = @PoID) and old.Order_BOAUkey is not null)
							And po2.Seq1 like boa.Seq1 + '%'
						)
		) Ori On CHARINDEX(New.Seq1, Ori.Seq1) > 0
			and Ori.SuppID			= New.SuppID
			and Ori.SCIRefNo		= New.SCIRefNo
			and Ori.OrderList		= New.OrderList
			
			-- Spec Compare (null != '')
			and ((Ori.SpecColor is null and New.SpecColor is null) or (Ori.SpecColor is not null and New.SpecColor is not null and Ori.SpecColor = New.SpecColor))
			and ((Ori.SpecSize is null and New.SpecSize is null) or (Ori.SpecSize is not null and New.SpecSize is not null and Ori.SpecSize = New.SpecSize))
			and ((Ori.SpecSizeUnit is null and New.SpecSizeUnit is null) or (Ori.SpecSizeUnit is not null and New.SpecSizeUnit is not null and Ori.SpecSizeUnit = New.SpecSizeUnit))
			and ((Ori.SpecZipperInsert is null and New.SpecZipperInsert is null) or (Ori.SpecZipperInsert is not null and New.SpecZipperInsert is not null and Ori.SpecZipperInsert = New.SpecZipperInsert))
			and ((Ori.SpecArticle is null and New.SpecArticle is null) or (Ori.SpecArticle is not null and New.SpecArticle is not null and Ori.SpecArticle = New.SpecArticle))
			and ((Ori.SpecCOO is null and New.SpecCOO is null) or (Ori.SpecCOO is not null and New.SpecCOO is not null and Ori.SpecCOO = New.SpecCOO))
			and ((Ori.SpecGender is null and New.SpecGender is null) or (Ori.SpecGender is not null and New.SpecGender is not null and Ori.SpecGender = New.SpecGender))
			and ((Ori.SpecCustomerSize is null and New.SpecCustomerSize is null) or (Ori.SpecCustomerSize is not null and New.SpecCustomerSize is not null and Ori.SpecCustomerSize = New.SpecCustomerSize))
			and ((Ori.SpecDecLabelSize is null and New.SpecDecLabelSize is null) or (Ori.SpecDecLabelSize is not null and New.SpecDecLabelSize is not null and Ori.SpecDecLabelSize = New.SpecDecLabelSize))
			and ((Ori.SpecBrandFactoryCode is null and New.SpecBrandFactoryCode is null) or (Ori.SpecBrandFactoryCode is not null and New.SpecBrandFactoryCode is not null and Ori.SpecBrandFactoryCode = New.SpecBrandFactoryCode))
			and ((Ori.SpecStyle is null and New.SpecStyle is null) or (Ori.SpecStyle is not null and New.SpecStyle is not null and Ori.SpecStyle = New.SpecStyle))
			and ((Ori.SpecStyleLocation is null and New.SpecStyleLocation is null) or (Ori.SpecStyleLocation is not null and New.SpecStyleLocation is not null and Ori.SpecStyleLocation = New.SpecStyleLocation))
			and ((Ori.SpecSeason is null and New.SpecSeason is null) or (Ori.SpecSeason is not null and New.SpecSeason is not null and Ori.SpecSeason = New.SpecSeason))
			and ((Ori.SpecCareCode is null and New.SpecCareCode is null) or (Ori.SpecCareCode is not null and New.SpecCareCode is not null and Ori.SpecCareCode = New.SpecCareCode))
			and ((Ori.SpecCustomerPO is null and New.SpecCustomerPO is null) or (Ori.SpecCustomerPO is not null and New.SpecCustomerPO is not null and Ori.SpecCustomerPO = New.SpecCustomerPO))
			
			and (@IsIgnoreRemark = 1 Or (@IsIgnoreRemark = 0 and Ori.Remark	= New.Remark))		
		Outer apply (
			select Top 1 value = 1
			from PO_Supp po2
			inner join PO_Supp_Detail po3 on po2.ID = po3.ID and po2.Seq1 = po3.Seq1
			where po2.ID = @PoID
				and po3.FabricType = 'A'
				and exists (Select Top 1 1
						From Order_BOA boa
						Where boa.Ukey in (
								Select old.Order_BOAUkey 
								From Order_Label_Detail old 
								Where old.ID in (Select Id From Orders o Where o.POID = @PoID) and old.Order_BOAUkey is not null)
							And po2.Seq1 like boa.Seq1 + '%'
						)
				and po2.Seq1 like isnull(Ori.Seq1, New.Seq1)  + '%'
		) getTransEDI
	) a;

	--將原本的PO_Supp寫入#tmpPO_Supp
	Insert Into #tmpPO_Supp	(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, StyleID, Junk)
	select distinct ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, Description, CompanyID, isnull(StyleID, @StyleID), isnull(getJunk.Junk, 1)
	from PO_Supp po2
	outer apply (select top 1 Junk from PO_Supp_Detail po3 where po3.ID = po2.ID and po3.Seq1 = po2.SEQ1 and po3.Junk = 0) getJunk
	outer apply (select po3.FabricType from PO_Supp_Detail po3 where po3.ID = po2.ID and po3.Seq1 = po2.SEQ1) getFabricType
	where po2.ID = @PoID
		and getFabricType.FabricType = 'A'

	--對新採購項(Seq1 = '')的資料預編Seq1	
	Set @tmpResultRowID = 1;
	Select @tmpResultRowID = Min(RowID), @tmpResultRowCount = Max(RowID) From #tmpResult;
	While @tmpResultRowID <= @tmpResultRowCount
	Begin
		Select @NewSeq1 = NewSeq1
		From #tmpResult Where RowID = @tmpResultRowID and Seq1 = '' and NewSeq1 !=''

		If @@RowCount > 0
		Begin
			Select top 1 
			@Seq1 = isnull(Seq1, '')
			From #tmpPO_Supp Where CHARINDEX(@NewSeq1, Seq1) = 1 Order By Seq1 desc

			If @@RowCount = 0
			Begin
				Set @Seq1 = @NewSeq1
			End

			Update #tmpResult Set Seq1 = @Seq1 where RowID = @tmpResultRowID
		End

		set @tmpResultRowID += 1;
	End

	Set @tmpResultRowID = 1;
	Select @tmpResultRowID = Min(RowID), @tmpResultRowCount = Max(RowID) From #tmpResult;
	While @tmpResultRowID <= @tmpResultRowCount
	Begin
		truncate table #SameSCIGroup;
		Insert Into #SameSCIGroup
		(RowID, SuppID, Seq1, Seq2, SCIRefNo, ColorID, SuppColor, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Special, Width
			, FirstOrderID, OrderList, NewQty, OriQty, NewLossQty, OriLossQty, Status
			, transEDI, OutputQty, NewNetQty ,OriNetQty, Seq2_Count)
		Select
		RowID, SuppID, Seq1, Seq2, SCIRefNo, ColorID, SuppColor, SizeSpec, BomZipperInsert, BomCustPONo, Remark, Special, Width
			, OrderID, OrderList, NewQty, OriQty, NewLossQty, OriLossQty, Status
			, transEDI, OutputQty, NewNetQty, OriNetQty, Seq2_Count
		From #tmpResult
		Where RowID = @tmpResultRowID
		Order By Seq1 Desc

		Set @SameSCIGroupRowID = 1;
		Select @SameSCIGroupRowID = Min(RowID), @SameSCIGroupRowCount = Max(RowID) From #SameSCIGroup;

		IF @SameSCIGroupRowCount > 0
		Begin
			select @NewQty = sum(NewQty), @NewNetQty = sum(NewNetQty), @NewLossQty = sum(NewLossQty) from #SameSCIGroup where RowID = @SameSCIGroupRowID
			select @OriTtlQty = sum(OriQty) from #SameSCIGroup
			set @DiffQty = @NewQty - @OriTtlQty

			select @OriTtlNetQty = sum(OriNetQty) from #SameSCIGroup
			set @DiffNetQty = @NewNetQty - @OriTtlNetQty
		
			select @OriTtlLossQty = sum(OriLossQty) from #SameSCIGroup
			set @DiffLossQty = @NewLossQty - @OriTtlLossQty
		End

		While @SameSCIGroupRowID <= @SameSCIGroupRowCount
		Begin
			Select @SuppID = SuppID
				, @Seq1 = Seq1
				, @Seq2 = Seq2
				, @SCIRefNo = SCIRefNo
				, @ColorID = ColorID
				, @SizeSpec = SizeSpec
				, @BomZipperInsert = BomZipperInsert
				, @BomCustPONo = BomCustPONo
				, @Remark = Remark
				, @Special = Special
				, @Width = Width
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
				, @POQty = 0
				, @OutputQty = OutputQty
				, @Seq2_Count = Seq2_Count
				, @OrderList = OrderList --Insert PO4時比對用
				, @FirstOrderID = FirstOrderID --Insert PO3時比對用
				, @SuppColor = SuppColor
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
					IF @BalanceQty >= @NewLossQty or @OriLossQty > @NewLossQty
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

				-- 寫入#tmpPO_Supp_Detail
				-- 因前面會撈到OrderID造成很多一樣的採購項，這裡只要抓第一筆當代表就好
				Insert Into #tmpPO_Supp_Detail
				(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit, Complete
					, ColorID, SuppColor, SizeSpec, SizeUnit, Remark, Special, Width
					, NetQty, LossQty, SystemNetQty, OutputQty
					, ColorDetail, BomZipperInsert, BomCustPONo, Spec, Seq2_Count, Status, Sel
					, Remark_Shell
					, OrderID
				)
				select Top 1
					ID, @Seq1, @Seq2, Refno, SCIRefno, FabricType, Price, UsedQty, @POQty, POUnit, 0
					, RTrim(LTrim(ColorID)), SuppColor, SizeSpec, SizeUnit, Remark, Special, Width
					, @NetQty, @LossQty, @NetQty, @OutputQty
					, ColorDetail, BomZipperInsert, BomCustPONo, Spec, @Seq2_Count, @Status, 0
					, Remark_Shell
					, OrderID
				from #tmpPO3
				where substring(Seq1, 1, 2) = substring(@Seq1, 1, 2) 
					And Seq2_Count = @Seq2_Count 
					And OrderList = @OrderList
				Order by OrderID

				-- 寫入#tmpPO_Supp_Detail_Spec
				Insert Into #tmpPO_Supp_Detail_Spec
				(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
				Select ID, @Seq1, @Seq2, SpecColumnID, SpecValue, Seq2_Count
				from #tmpPO3S
				where substring(Seq1, 1, 2) = substring(@Seq1, 1, 2)
					And Seq2_Count = @Seq2_Count					
					And OrderList = @OrderList

				-- 寫入#tmpPO_Supp_Detail_Keyword
				Insert Into #tmpPO_Supp_Detail_Keyword
				(ID, Seq1, Seq2, KeywordField, KeywordValue, Seq2_Count)
				Select ID, @Seq1, @Seq2, KeywordField, KeywordValue, Seq2_Count
				from #tmpPO3K
				where substring(Seq1, 1, 2) = substring(@Seq1, 1, 2)
					And Seq2_Count = @Seq2_Count					
					And OrderList = @OrderList

				-- 寫入#tmpPO_Supp_Detail_OrderList
				if(not exists (
					Select 1 
					From #tmpPO_Supp_Detail_OrderList 
					where Seq1 = @Seq1 
						And Seq2_Count = @Seq2_Count 
						And OrderID in (Select Data From Trade.dbo.SplitString(@OrderList, ','))))
				Begin 
					Insert Into #tmpPO_Supp_Detail_OrderList
					(ID, Seq1, Seq2, OrderID, Seq2_Count)
					Select ID, @Seq1, @Seq2, OrderID, Seq2_Count
					from #tmpPO4 
					where substring(Seq1, 1, 2) = substring(@Seq1, 1, 2) 
						And Seq2_Count = @Seq2_Count 
						And OrderID in (Select Data From Trade.dbo.SplitString(@OrderList, ','))
				End

				IF @DiffQty > 0
				Begin
					-- '將差異數成立於新大項
					set @Status = '1'
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

				set @POQty = @Qty

				IF	@transEDI = 1 or exists (select 1 from #tmpResult where Seq1 = @Seq1 And Status = 2)
				Begin
					Select top 1 @Seq1 = Seq1 from #tmpPO_Supp where Seq1 = @Seq1 and SuppID = @SuppID order by Seq1 desc
					
					IF Len(@Seq1) > 2
						set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)
					Else
						set @Seq1 = @Seq1 + Char(65)	
											
					-- 產生新#tmpPO_Supp項次時並無寫入Junk, 可用來判斷編列Seq1是否重複
					While exists (select 1 from #tmpPO_Supp where Seq1 = @Seq1 and Junk is not null)
					Begin
						set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)	
					End
				End

				-- 判斷@Seq1是否與已Junk的PO_Supp.Seq1相同
				While exists (select 1 from #tmpPO_Supp where Seq1 = @Seq1 and Junk = 1)
				Begin
					IF Len(@Seq1) > 2
						set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)					
					Else
						set @Seq1 = @Seq1 + Char(65)
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

				-- 當Seq2大於99時 重編Seq1 & Seq2
				if (@Seq2 = '00')
				BEGIN
					if (Len(@Seq1) > 2)
					BEGIN
						set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)
					END
					ELSE
					BEGIN
						select @Seq1 = MAX(Seq1)
						from #tmpPO_Supp
						where Seq1 like @Seq1 + '%'

						if exists (select 1 from #tmpPO_Supp_Detail Where ID = @PoID and Seq1 = @Seq1 and Seq2 = '99')
						BEGIN
							if (Len(@Seq1) > 2)
							BEGIN
								set @Seq1 = SUBSTRING(@Seq1, 1, 2) + Char(ASCII(SUBSTRING(@Seq1, 3, 1)) + 1)
							END
							ELSE
							BEGIN
								set @Seq1 = @Seq1 + 'A'
							END
						END
					END
					
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

					print @Seq1 + ' - ' + @seq2;
				END

				IF not exists (select 1 from #tmpPO_Supp where Seq1 = @Seq1 and SuppID = @SuppID)
				Begin
					Insert Into #tmpPO_Supp	(ID, Seq1, SuppID)
					select @PoID, @Seq1, @SuppID
				End

				Insert Into #tmpPO_Supp_Detail
				(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit, Complete
					, ColorID, SuppColor, SizeSpec, SizeUnit, Remark, Special, Width
					, NetQty, LossQty, SystemNetQty
					, ColorDetail, BomZipperInsert, BomCustPONo, Spec, Seq2_Count, Status, Sel, Junk
					, Remark_Shell
					, OrderID
				)
				select 
					ID, @Seq1, @Seq2, po3.Refno, po3.SCIRefno, po3.FabricType, po3.Price, po3.UsedQty, isnull(@POQty, Qty), po3.POUnit, 0
					, RTrim(LTrim(po3.ColorID)), po3.SuppColor, po3.SizeSpec, po3.SizeUnit, po3.Remark, po3.Special, po3.Width
					, isnull(@NetQty, po3.NetQty), isnull(@LossQty, po3.LossQty), isnull(@NetQty, po3.NetQty)
					, po3.ColorDetail, po3.BomZipperInsert, po3.BomCustPONo, po3.Spec, @Seq2_Count, @Status, 1, IIF(@POQty = 0, 1, 0)
					, Remark_Shell
					, po3.OrderID
				from #tmpPO3 po3
				where substring(po3.Seq1, 1, 2) = substring(@Seq1, 1, 2) 
					And po3.Seq2_Count = @Seq2_Count 
					And po3.OrderList = @OrderList			
			
				-- 寫入#tmpPO_Supp_Detail_Spec
				Insert Into #tmpPO_Supp_Detail_Spec
				(ID, Seq1, Seq2, SpecColumnID, SpecValue, Seq2_Count)
				Select ID, @Seq1, @Seq2, SpecColumnID, SpecValue, Seq2_Count
				from #tmpPO3S
				where substring(Seq1, 1, 2) = substring(@Seq1, 1, 2)
					And Seq2_Count = @Seq2_Count
					And OrderList = @OrderList

				-- 寫入#tmpPO_Supp_Detail_Keyword
				Insert Into #tmpPO_Supp_Detail_Keyword
				(ID, Seq1, Seq2, KeywordField, KeywordValue, Seq2_Count)
				Select ID, @Seq1, @Seq2, KeywordField, KeywordValue, Seq2_Count
				from #tmpPO3K
				where substring(Seq1, 1, 2) = substring(@Seq1, 1, 2)
					And Seq2_Count = @Seq2_Count
					And OrderList = @OrderList
			
				if(not exists (
					Select 1 From #tmpPO_Supp_Detail_OrderList 
					where Seq1 = @Seq1 
						and Seq2_Count = @Seq2_Count 
						And OrderID in (Select Data From Trade.dbo.SplitString(@OrderList, ','))))
				Begin
					Insert Into #tmpPO_Supp_Detail_OrderList
					(ID, Seq1, Seq2, OrderID, Seq2_Count)
					Select ID, @Seq1, @Seq2, OrderID, Seq2_Count
					from #tmpPO4
					where substring(Seq1, 1, 2) = substring(@Seq1, 1, 2) 
						And Seq2_Count = @Seq2_Count 
						And OrderID in (Select Data From Trade.dbo.SplitString(@OrderList, ','))
				End 
			End

			IF @Status = '2' --Delete => Update Qty = 0
			Begin

				If @transEDI = 1
				Begin
					set @POQty = @OriQty
				End

				-- 寫入#tmpPO_Supp_Detail
				Insert Into #tmpPO_Supp_Detail
				(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit, Complete
					, ColorID, SuppColor, SizeSpec, SizeUnit, Remark, Special, Width
					, NetQty, LossQty, SystemNetQty
					, ColorDetail, BomZipperInsert, BomCustPONo, Spec, Seq2_Count, Status, Sel, Junk
					, OrderID
				)
				select 
					@PoID, @Seq1, @Seq2, Refno, SCIRefno, FabricType, Price, 0, @POQty, POUnit, 0
					, RTrim(LTrim(ColorID)), SuppColor, SizeSpec, SizeUnit, Remark, Special, Width
					, 0, 0, 0
					, ColorDetail, BomZipperInsert, BomCustPONo, Spec, @Seq2_Count, @Status, 0, IIF(@OriQty = 0, 1, 0)
					, Isnull(OrderID, '')
				from #tmpResult
				where Seq1 = @Seq1 and Seq2 = @Seq2
			End

			set @SameSCIGroupRowID += 1;
		End

		set @tmpResultRowID += 1;
	End

	Set @tmpPo_SuppRowID = 1;
	Select @tmpPo_SuppRowID = Min(RowID), @tmpPo_SuppRowCount = Max(RowID) From #tmpPO_Supp
	While @tmpPo_SuppRowID <= @tmpPo_SuppRowCount
	Begin
		Select @Seq1 = Seq1
				, @SuppID = SuppID
				, @Description = Description
		From #tmpPO_Supp
		Where RowID = @tmpPo_SuppRowID
		
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

		Set @tmpPo_Supp_DetailRowID = 1;
		Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From #tmpPO_Supp_Detail Where Seq1 = @Seq1;
		While @tmpPo_Supp_DetailRowID <= @tmpPo_Supp_DetailRowCount
		Begin
			Select  @Seq2 = Seq2
					, @RefNo = RefNo
					, @SciRefNo = SCIRefNo
					, @FabricType = FabricType
					, @ColorID = ColorID
					, @Qty = Qty
					, @POUnit = POUnit
					, @SizeSpec = SizeSpec
					, @SizeUnit = SizeUnit
					, @Width = Width
					, @BomZipperInsert = BomZipperInsert
					, @BomCustPONo = BomCustPONo
					, @Special = Special
					, @Spec = Spec
					, @Seq2_Count = Seq2_Count
			From #tmpPO_Supp_Detail
			Where RowID = @tmpPo_Supp_DetailRowID
				And Seq1 = @Seq1;

			SELECT @PurchaseCompany = CompanyID
			FROM #tmpPO_Supp
			WHERE ID = @PoID
			And Seq1 = @Seq1;
				
			Select @MtlTypeID = MtltypeID, @CannotOperateStock = CannotOperateStock From Trade.dbo.Fabric Where SCIRefno = @SCIRefNo;

			If @@RowCount > 0
			Begin
				--取得物料LeadTime
				Select @LTDay = Fabric_Supp.LTDay
				, @SuppRefno = Fabric_Supp.SuppRefno
				, @BrandRefNo = Fabric.BrandRefNo
				From Trade.dbo.Fabric_Supp
				Left join Trade.dbo.Fabric on Fabric_Supp.SCIRefno = Fabric.SCIRefno
				Where Fabric_Supp.SCIRefno = @SciRefNo
				And Fabric_Supp.SuppID = @SuppID;
				
				Declare @LoadDate Date;
				DECLARE @POTargetLETA DATE;
				SELECT @POTargetLETA = TargetLETA FROM PO WHERE ID = @PoID
				declare @BeforeShip int = 1
				if @POTargetLETA is null
				begin
					set @POTargetLETA = dbo.GetRequestETA(@PoID)
					set @BeforeShip = 3
				end
				SET @SystemETD = Trade.dbo.GetDefaultDelDate(@SciRefNo, @Category, @SuppID, @StyleID, @BrandID, @SeasonID, @FactoryCountry, @OrderTypeID, @ColorID, @SystemETD_AdditionalDays, @CfmDate);
				IF  @BeforeShip = 1
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
					select SpecColumnID, SpecValue, cast(1 as bit)
					from #tmpPO_Supp_Detail_Spec
					Where ID = @PoID
					   And Seq1 = @Seq1
					   And Seq2 = @Seq2;

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
					, CannotOperateStock = @CannotOperateStock
				Where RowID = @tmpPo_Supp_DetailRowID

				Update #tmpPO_Supp_Detail_OrderList
				Set Seq2 = @Seq2
				Where ID = @PoID
				And Seq1 = @Seq1
				And Seq2_Count = @Seq2_Count
				And isnull(Seq2, '') = '';
			End
			
			Set @tmpPo_Supp_DetailRowID += 1;
		End
		--------------------Loop End #tmpPO_Supp_Detail--------------------
		-------------------------------------
		--取得Supplier Remaek
		Exec Trade.dbo.GetSuppRemark @PoID, @SuppID, @BrandID, @FactoryCountry, @FactoryID, @FabricType, 'P', @Remark Output;
		-------------------------------------
		--更新Temp Table - PO_Supp
		Update Po2
		Set ShipTermID = @ShipTermID
			, PayTermAPID = @PayTermAPID
			, CompanyID = @CompanyID
			, Remark = @Remark
			, Description = @KeywordValue + @Description
			, Junk = isnull(getJunk.Junk, 1)
		From #tmpPO_Supp Po2
		outer apply (select top 1 Junk from #tmpPO_Supp_Detail po3 where po3.ID = po2.ID and po3.Seq1 = po2.SEQ1 and po3.Junk = 0) getJunk
		Where RowID = @tmpPo_SuppRowID and Seq1 = @Seq1;
		-------------------------------------

		Set @tmpPo_SuppRowID += 1;
	End

	delete po3 from #tmpPO_Supp_Detail po3 inner join #tmpPO_Supp po2 on po3.ID = po2.ID and po3.Seq1 = po2.Seq1 where po2.Junk = 1
	delete #tmpPO_Supp where Junk = 1

	--補上原本可能因為物料Match不到而被刪掉的OrderList
	Insert into #tmpPO_Supp_Detail_OrderList (ID, Seq1, Seq2, Seq2_Count, OrderID)
	Select po4.ID, po4.Seq1, po4.Seq2, 0, po4.OrderID
	From Trade.dbo.PO_Supp_Detail_OrderList po4
	Left join Trade.dbo.PO_Supp_Detail po3 on po4.id = po3.ID And po4.SEQ1 = po3.Seq1 And po4.SEQ2 = po3.Seq2
	Where po4.id = @PoID
		And not exists (
				Select 1 
				From #tmpPO_Supp_Detail_OrderList tpo4 
				Where po4.ID = tpo4.ID And po4.Seq1 = tpo4.Seq1 And po4.Seq2 = tpo4.Seq2 And po4.OrderID = tpo4.OrderID
			)
		And po4.SEQ1 in (Select Distinct Seq1 From #tmpPO_Supp_Detail)

	IF @ReturnTable = 1
	Begin
		select * From #tmpResult
		Select * From #tmpPO_Supp;
		Select * From #tmpPO_Supp_Detail
		Select * From #tmpPO_Supp_Detail_OrderList;
	End

	--drop table #tmpPO_Supp;
	--drop table #tmpPO_Supp_Detail;
	--drop table #tmpPO_Supp_Detail_Spec;
	--drop table #tmpPO_Supp_Detail_Keyword;
	--drop table #tmpPO_Supp_Detail_OrderList;
	
	drop table #tmpPO2;
	drop table #tmpPO3;
	drop table #tmpPO3S;
	drop table #tmpPO3K;
	drop table #tmpPO4;

	drop table #tmpResult
	drop table #SameSCIGroup
End
GO