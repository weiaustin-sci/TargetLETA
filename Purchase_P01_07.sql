Use [Trade]
Go
Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Vicky
-- Create date: 2020/05/18
-- Description:
--			Purchase_P01_07 抓取報表
-- =============================================
If Object_Id ( 'dbo.Purchase_P01_07') Is Not Null
    Drop Procedure dbo.Purchase_P01_07;
Go

CREATE PROCEDURE dbo.Purchase_P01_07
	@OrderID VARCHAR(13)
AS
BEGIN
	--Declare @OrderID	VarChar(13) = '20042496PP'

	Create Table #tmpPO_Supp
	(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), SuppID VarChar(6) default ''
	, ShipTermID VarChar(5) default '', PayTermAPID VarChar(5) default ''
	, Remark NVarChar(Max) default '', Description NVarChar(Max) default '', CompanyID Numeric(2,0) default 0
	, StyleID VarChar(15), TargetLETA Date, Junk Bit, Primary Key (ID, Seq1)
	);
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
	, Seq2_Count Int, Remark_Shell NVarChar(Max) default '', IsForOtherBrand bit, CannotOperateStock bit, Keyword_Original varchar(max)
	, Primary Key (ID, Seq1, Seq2, Seq2_Count)
	, Status varchar(1), Sel bit default 0
	);

	Declare @tmpPo_Supp_DetailRowID Int;	--Row ID
	Declare @tmpPo_Supp_DetailRowCount Int;	--總資料筆數

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

	Create Table #tmpDetail
	(  PoID VarChar(13),ActSeq VarChar(20), Seq1 VarChar(3), Seq2 VarChar(2), Qty Numeric(10,2), InputQty Numeric(10,2)
	);

	Create Table #tmpTable
	( PoID VarChar(13),Type VarChar(10), Seq1 VarChar(3) default '', Seq2 VarChar(2) default '', RefNo VarChar(36) default ''
	, ColorID VarChar(6) default '', SizeSpec VarChar(15) default '', SizeUnit VarChar(8) default ''
	, Qty Numeric(10,2) default 0, NetQty Numeric(10,2) default 0, LossQty Numeric(10,2) default 0
	, InputQty Numeric(10,2) default 0, DiffQty Numeric(10,2) default 0, DiffAmount Numeric(14,2) default 0, ActSeq VarChar(20) default ''
	, ActSeq1 VarChar(3) default '', ActSeq2 VarChar(2) default ''
	, OriQty Numeric(10,2) default 0, BalanceQty Numeric(10,2) default 0, BalancePercent Numeric(10,2) default 0, Remark NVarChar(Max) default '', Spec NVarChar(Max) default ''
	, Width Numeric(5, 2) default 0, Special NVarChar(Max) default '', BomZipperInsert VarChar(5) default ''
	, BomCustPONo VarChar(30) default '', POUnit VarChar(8) default '', Price Numeric(14,4) default 0, PriceExchange numeric(13,8), PriceUSD Numeric(14,4) default 0
	 , CurrencyID VarChar(3) default '', OrderList nvarchar(max) default ''
	);

	--比對欄位
	Declare @Seq1				VarChar(3)
	Declare @Seq2				VarChar(2)
	Declare @RefNo				VarChar(36)
	Declare @Width				Numeric(5, 2)
	Declare @ColorID			VarChar(6)
	Declare @SizeSpec			VarChar(15)
	Declare @SizeUnit			VarChar(8)
	Declare @BomCustPONo		VarChar(30)
	Declare @BomZipperInsert	VarChar(5)
	Declare @Spec				NVarChar(Max)
	Declare @Special			NVarChar(Max)

	Declare @PoID		VarChar(13);
	Declare @BrandID	VarChar(8);
	Declare @ProgramID	VarChar(12);
	Declare @Category	VarChar(1);
	Declare @TestType	Int	= 3

	Select @PoID = POID
	, @BrandID = BrandID
	, @ProgramID = ProgramID
	, @Category = Category
	From Orders
	Where ID = @OrderID

	-- 試轉BOF、BOA、BOT
	exec TransferToPO_1_ForBOF @PoID, @BrandID, @ProgramID, @Category, @TestType;
	exec TransferToPO_1_ForBOA @PoID, @BrandID, @ProgramID, @Category, @TestType;
	exec TransferToPO_2 @PoID, 0, @TestType;

	-- BOT的補PO_Supp資料已合併於該Procedure，執行順序不可互換
	exec TransferToPO_1_ForThreadAllowance @PoID, '', 1

	-- 抓現有採購單項次
	select * into #curPO_Supp from PO_Supp where ID = @PoID and SEQ1 not like 'A%'
	select * into #curPO_Supp_Detail from PO_Supp_Detail where ID = @PoID and SEQ1 not like 'A%'
	select * into #curPO_Supp_Detail_Spec from PO_Supp_Detail_Spec where ID = @PoID and SEQ1 not like 'A%'

	Set @tmpPo_Supp_DetailRowID = 1;
	Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From #tmpPO_Supp_Detail
	While @tmpPo_Supp_DetailRowID <= @tmpPo_Supp_DetailRowCount
	Begin
		-- 取試轉採購項規格
		Select @Seq1 = Seq1
		, @Seq2 = Seq2
		, @RefNo = Refno
		, @Width = Width
		, @ColorID = po3Spec.Color
		, @SizeSpec = po3Spec.Size
		, @SizeUnit = po3Spec.SizeUnit
		, @BomCustPONo = po3Spec.CustomerPO
		, @BomZipperInsert = po3Spec.ZipperInsert
		, @Spec = Spec
		, @Special = Special
		From #tmpPO_Supp_Detail
		outer apply (
			select *
			from 
			(
				select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
				from Trade.dbo.BomType with (nolock)
				left join #tmpPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = #tmpPO_Supp_Detail.ID and po3s.Seq1 = #tmpPO_Supp_Detail.Seq1 and po3s.Seq2 = #tmpPO_Supp_Detail.Seq2 and BomType.ID = po3s.SpecColumnID
			)tmp
			pivot
			(
				MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
			) as p
		) po3Spec
		Where RowID = @tmpPo_Supp_DetailRowID

		-- 從現有採購項找出相符的項次寫入#tmpDetail
		truncate table #tmpDetail;
		Insert Into #tmpDetail (PoID,ActSeq, Seq1, Seq2, Qty, inputQty)
		Select @PoID,ActSeq, Seq1, Seq2, Qty, inputQty
		From (
			-- 一般項
			Select ActSeq = Seq1 + '-' + Seq2, Seq1, Seq2, Qty, inputQty
			from #curPO_Supp_Detail
			outer apply (
				select *
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join #curPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = #curPO_Supp_Detail.ID and po3s.Seq1 = #curPO_Supp_Detail.Seq1 and po3s.Seq2 = #curPO_Supp_Detail.Seq2 and BomType.ID = po3s.SpecColumnID
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
				) as p
			) po3Spec
			Where Refno = @Refno
			and Width = @Width
			and po3Spec.Color = @ColorID
			and po3Spec.Size = @SizeSpec
			and po3Spec.SizeUnit = @SizeUnit
			and po3Spec.CustomerPO = @BomCustPONo
			and po3Spec.ZipperInsert = @BomZipperInsert
			and Spec = @Spec
			and Special = @Special
			and Seq1 not like '7%'
			and Junk = 0

			union all

			-- 庫存項
			Select ActSeq = po3.Seq1 + '-' + po3.Seq2 + '(' + tmp.Seq1 + '-' + tmp.Seq2 + ')', po3.Seq1, po3.Seq2, Qty, inputQty
			from #curPO_Supp_Detail po3
			outer apply (
				Select Seq1, Seq2
				from #curPO_Supp_Detail
				outer apply (
					select *
					from 
					(
						select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
						from Trade.dbo.BomType with (nolock)
						left join #curPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = #curPO_Supp_Detail.ID and po3s.Seq1 = #curPO_Supp_Detail.Seq1 and po3s.Seq2 = #curPO_Supp_Detail.Seq2 and BomType.ID = po3s.SpecColumnID
					)tmp
					pivot
					(
						MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
					) as p
				) po3Spec
				Where Refno = @Refno
				and Width = @Width
				and po3Spec.Color = @ColorID
				and po3Spec.Size = @SizeSpec
				and po3Spec.SizeUnit = @SizeUnit
				and po3Spec.CustomerPO = @BomCustPONo
				and po3Spec.ZipperInsert = @BomZipperInsert
				and Spec = @Spec
				and Special = @Special
				and Seq1 not like '7%') tmp
			where OutputSeq1 = tmp.Seq1
			and OutputSeq2 = tmp.Seq2
			and po3.Seq1 like '7%'
		) tmp

		insert #tmpTable
		(PoID,Type, Seq1, Seq2, Refno, ColorID, SizeSpec, SizeUnit, Qty, NetQty, LossQty, InputQty, DiffQty, BalanceQty,BalancePercent, ActSeq, ActSeq1, ActSeq2
		, OriQty, Remark, Spec, Width, Special, BomZipperInsert, BomCustPONo, POUnit, Price,PriceExchange,PriceUSD,DiffAmount, CurrencyID, OrderList)
		select * from (
			-- 將試轉項寫入SubTotal行
			Select @PoID as id,Type = iif(detail.Qty is null, 'Increase', 'Maintain')
			, subtotal.Seq1
			, subtotal.Seq2
			, subtotal.RefNo
			, ColorID = po3Spec.Color
			, SizeSpec = po3Spec.Size
			, po3Spec.SizeUnit
			, subtotal.Qty
			, subtotal.NetQty
			, subtotal.LossQty
			, InputQty = detail.InputQty
			, DiffQty = (isnull(detail.Qty, 0) - subtotal.Qty)
			, BalanceQty = (isnull(detail.Qty, 0) - isnull(subtotal.Qty,0) - isnull(detail.InputQty,0))
			, BalancePercent = iif(isnull(subtotal.Qty,0)=0,0,((isnull(detail.Qty, 0) - subtotal.Qty - isnull(detail.InputQty,0)) /subtotal.Qty))
			, ActSeq = ''
			, ActSeq1 = ''
			, ActSeq2 = ''
			, OriQty = detail.Qty
			, subtotal.Remark
			, subtotal.Spec
			, subtotal.Width
			, subtotal.Special
			, BomZipperInsert = po3Spec.ZipperInsert
			, BomCustPONo = po3Spec.CustomerPO
			, subtotal.POUnit
			, subtotal.Price
			, Currency.Rate
			, PriceUSD = (subtotal.Price * Currency.Rate)
			, DiffAmount = (OriginalAmount.Amount - ReviseAmount.Amount )*Currency.Rate
			, Supp.CurrencyID
			, OrderList = isnull(tmpOrderList.OrderIdList, '')
			from #tmpPO_Supp_Detail subtotal
			outer apply (
				select *
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join #tmpPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = subtotal.ID and po3s.Seq1 = subtotal.Seq1 and po3s.Seq2 = subtotal.Seq2 and BomType.ID = po3s.SpecColumnID
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
				) as p
			) po3Spec
			inner join #tmpPO_Supp po2 on subtotal.Seq1 = po2.Seq1
			inner join Supp on po2.SuppID = Supp.ID
			Left join Orders On Orders.ID = subtotal.ID
			Left Join (
				Select ID, Seq1, Seq2
				, OrderIdList = (
					Select SubString(OrderID,9,5)+'/' 
					From #tmpPO_Supp_Detail_OrderList as tmp 
					Where tmp.ID = #tmpPO_Supp_Detail_OrderList.ID
					And tmp.Seq1 = #tmpPO_Supp_Detail_OrderList.Seq1
					And tmp.Seq2 = #tmpPO_Supp_Detail_OrderList.Seq2 for XML path('')) 
				From #tmpPO_Supp_Detail_OrderList
				Group by ID, Seq1, Seq2
			) as tmpOrderList On subtotal.ID = tmpOrderList.ID
				And subtotal.Seq1 = tmpOrderList.Seq1
				And subtotal.Seq2 = tmpOrderList.Seq2
			outer apply (select Sum(Qty) Qty, Sum(InputQty) InputQty from #tmpDetail) detail
			OUTER APPLY( SELECT	Amount	FROM GetAmountByUnit(subtotal.Price, subtotal.Qty, subtotal.POUnit, 4)) ReviseAmount 
			OUTER APPLY( SELECT	Amount	FROM GetAmountByUnit(subtotal.Price, detail.Qty, subtotal.POUnit, 4)) OriginalAmount
			Outer apply dbo.GetCurrencyRate('FX',Supp.CurrencyID,'USD', Orders.CFMDate) as Currency
			where subtotal.RowID = @tmpPo_Supp_DetailRowID
	
			union all

			-- 將現有項次寫入Detail行
			select @PoID as id ,Type = 'Maintain'
			, subtotal.Seq1
			, subtotal.Seq2
			, subtotal.RefNo
			, subtotal.ColorID
			, subtotal.SizeSpec
			, subtotal.SizeUnit
			, Qty = 0
			, NetQty = 0
			, LossQty = 0
			, detail.inputQty
			, DiffQty = 0
			, BalanceQty = (isnull(detail2.Qty, 0) - isnull(subtotal.Qty,0) - detail2.InputQty)
			, BalancePercent = iif(isnull(subtotal.Qty,0)=0,0,((isnull(detail2.Qty, 0) - subtotal.Qty - isnull(detail2.InputQty,0)) /subtotal.Qty)) 
			, ActSeq = detail.ActSeq
			, ActSeq1 = detail.Seq1
			, ActSeq2 = detail.Seq2
			, OriQty = detail.Qty
			, subtotal.Remark
			, subtotal.Spec
			, subtotal.Width
			, subtotal.Special
			, subtotal.BomZipperInsert
			, subtotal.BomCustPONo
			, subtotal.POUnit
			, subtotal.Price
			, Currency.Rate
			, PriceUSD = (subtotal.Price * Currency.Rate)
			, DiffAmount = (OriginalAmount.Amount - ReviseAmount.Amount )*Currency.Rate
			, subtotal.CurrencyID
			, subtotal.OrderList
			from #tmpDetail detail
			outer apply (
				select tmpPo3.ID, tmpPo3.Seq1, tmpPo3.Seq2, tmpPo3.RefNo, tmpPo3.Qty, tmpPo3.Remark, tmpPo3.Spec, tmpPo3.Width, tmpPo3.Special, tmpPo3.POUnit, tmpPo3.Price
				, ColorID = po3Spec.Color, SizeSpec = po3Spec.Size, po3Spec.SizeUnit, BomZipperInsert = po3Spec.ZipperInsert, BomCustPONo = po3Spec.CustomerPO
				, Supp.CurrencyID
				, OrderList = isnull(tmpOrderList.OrderIdList, '')
				from #tmpPO_Supp_Detail tmpPo3
				outer apply (
					select *
					from 
					(
						select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
						from Trade.dbo.BomType with (nolock)
						left join #tmpPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = tmpPo3.ID and po3s.Seq1 = tmpPo3.Seq1 and po3s.Seq2 = tmpPo3.Seq2 and BomType.ID = po3s.SpecColumnID
					)tmp
					pivot
					(
						MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
					) as p
				) po3Spec
				inner join #tmpPO_Supp tmpPo2 on tmpPo3.Seq1 = tmpPo2.Seq1
				inner join Supp on tmpPo2.SuppID = Supp.ID
				Left Join (
					Select ID, Seq1, Seq2
					, OrderIdList = (
						Select SubString(OrderID,9,5)+'/' 
						From #tmpPO_Supp_Detail_OrderList as tmp 
						Where tmp.ID = #tmpPO_Supp_Detail_OrderList.ID
						And tmp.Seq1 = #tmpPO_Supp_Detail_OrderList.Seq1
						And tmp.Seq2 = #tmpPO_Supp_Detail_OrderList.Seq2 for XML path('')) 
					From #tmpPO_Supp_Detail_OrderList
					Group by ID, Seq1, Seq2
				) as tmpOrderList On tmpPo3.ID = tmpOrderList.ID
					And tmpPo3.Seq1 = tmpOrderList.Seq1
					And tmpPo3.Seq2 = tmpOrderList.Seq2
				where tmpPo3.RowID = @tmpPo_Supp_DetailRowID
			) subtotal
			Left join Orders On Orders.ID = subtotal.ID
			outer apply (select Sum(Qty) Qty, Sum(InputQty) InputQty from #tmpDetail) detail2
			Outer apply dbo.GetCurrencyRate('FX',subtotal.CurrencyID,'USD', Orders.CFMDate) as Currency
			OUTER APPLY( SELECT	Amount	FROM GetAmountByUnit(subtotal.Price, subtotal.Qty, subtotal.POUnit, 4)) ReviseAmount 
			OUTER APPLY( SELECT	Amount	FROM GetAmountByUnit(subtotal.Price, detail2.Qty, subtotal.POUnit, 4)) OriginalAmount
		) tmp
		
		Set @tmpPo_Supp_DetailRowID += 1;
	End

	-- 找出現有採購項中不存在試轉採購項的項次
	truncate table #tmpDetail;
	Insert Into #tmpDetail (PoID,ActSeq, Seq1, Seq2, Qty, inputQty)
	Select ID,ActSeq, Seq1, Seq2, Qty, inputQty
	From (
		-- 一般項
		Select ID,ActSeq = Seq1 + '-' + Seq2, Seq1, Seq2, Qty, inputQty
		From #curPO_Supp_Detail cur
		outer apply (
			select *
			from 
			(
				select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
				from Trade.dbo.BomType with (nolock)
				left join #curPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = cur.ID and po3s.Seq1 = cur.Seq1 and po3s.Seq2 = cur.Seq2 and BomType.ID = po3s.SpecColumnID
			)tmp
			pivot
			(
				MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
			) as p
		) curPo3Spec
		where cur.Seq1 not like '7%'
		and not exists (
			select 1 from #tmpPO_Supp_Detail tmp
			outer apply (
				select *
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join #tmpPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = tmp.ID and po3s.Seq1 = tmp.Seq1 and po3s.Seq2 = tmp.Seq2 and BomType.ID = po3s.SpecColumnID
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
				) as p
			) tmpPo3Spec
			where tmp.Refno = cur.Refno
				and tmp.Width = cur.Width
				and tmpPo3Spec.Color = curPo3Spec.Color
				and tmpPo3Spec.Size = curPo3Spec.Size
				and tmpPo3Spec.SizeUnit = curPo3Spec.SizeUnit
				and tmpPo3Spec.CustomerPO = curPo3Spec.CustomerPO
				and tmpPo3Spec.ZipperInsert = tmpPo3Spec.ZipperInsert
				and tmp.Spec = cur.Spec
				and tmp.Special = cur.Special)
		and cur.Junk = 0
	
		union all

		-- 庫存項
		Select ID,ActSeq = curStock.Seq1 + '-' + curStock.Seq2 + '(' + cur.Seq1 + '-' + cur.Seq2 + ')', curStock.Seq1, curStock.Seq2, Qty, inputQty
		From #curPO_Supp_Detail curStock
		outer apply (
			select Seq1, Seq2 from #curPO_Supp_Detail cur
			outer apply (
				select *
				from 
				(
					select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
					from Trade.dbo.BomType with (nolock)
					left join #curPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = cur.ID and po3s.Seq1 = cur.Seq1 and po3s.Seq2 = cur.Seq2 and BomType.ID = po3s.SpecColumnID
				)tmp
				pivot
				(
					MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
				) as p
			) curPo3Spec
			where cur.Seq1 not like '7%'
				and not exists (
					select 1 from #tmpPO_Supp_Detail tmp
					outer apply (
						select *
						from 
						(
							select BomTypeID = BomType.ID, SpecValue = isnull(po3s.SpecValue, '')
							from Trade.dbo.BomType with (nolock)
							left join #tmpPO_Supp_Detail_Spec po3s with (nolock) on po3s.ID = tmp.ID and po3s.Seq1 = tmp.Seq1 and po3s.Seq2 = tmp.Seq2 and BomType.ID = po3s.SpecColumnID
						)tmp
						pivot
						(
							MAX(SpecValue) for BomTypeID in (Color, Size, SizeUnit, ZipperInsert, CustomerPO)
						) as p
					) tmpPo3Spec
					where tmp.Refno = cur.Refno
						and tmp.Width = cur.Width
						and tmpPo3Spec.Color = curPo3Spec.Color
						and tmpPo3Spec.Size = curPo3Spec.Size
						and tmpPo3Spec.SizeUnit = curPo3Spec.SizeUnit
						and tmpPo3Spec.CustomerPO = curPo3Spec.CustomerPO
						and tmpPo3Spec.ZipperInsert = tmpPo3Spec.ZipperInsert
						and tmp.Spec = cur.Spec
						and tmp.Special = cur.Special)) cur
		where curStock.OutputSeq1 = cur.Seq1
		and curStock.OutputSeq2 = cur.Seq2
		and curStock.Seq1 like '7%'
		and curStock.Junk = 0
	) tmp

	-- 寫入一筆減少項次總數
	insert #tmpTable
	(PoID,Type, InputQty, DiffQty, BalanceQty, OriQty)
	select  @PoID,Type = 'Decrease'
	, InputQty = sum(detail.inputQty)
	, DiffQty = sum(detail.Qty)
	, BalanceQty = sum(detail.Qty) - sum(detail.inputQty)
	, OriQty = sum(detail.Qty)
	from #tmpDetail detail

	-- 將不存在試轉採購項的項次寫入#tmpTable
	insert #tmpTable
	(PoID,Type, InputQty, ActSeq, ActSeq1, ActSeq2, OriQty)
	select detail.PoID 
	, Type = 'Decrease'
	, detail.inputQty
	, ActSeq = detail.ActSeq
	, ActSeq1 = detail.Seq1
	, ActSeq2 = detail.Seq2
	, OriQty = detail.Qty
	from #tmpDetail detail

	select * from #tmpTable
	order by case [Type] when 'Decrease' then 1 else 0 end
	, Seq1, Seq2, Qty desc

	--select * from #tmpPO_Supp
	--select * from #curPO_Supp
	--select * from #tmpPO_Supp_Detail_OrderList
	--select * from #tmpPO_Supp_Detail_Spec
	--select * from #tmpPO_Supp_Detail_Keyword
	--select * from #tmpPO_Supp_Detail
	--select * from #curPO_Supp_Detail

	drop table #tmpDetail
	drop table #tmpTable
	drop table #tmpPO_Supp
	drop table #tmpPO_Supp_Detail
	drop table #tmpPO_Supp_Detail_OrderList
	drop table #tmpPO_Supp_Detail_Spec
	drop table #tmpPO_Supp_Detail_Keyword
	drop table #curPO_Supp
	drop table #curPO_Supp_Detail
END
