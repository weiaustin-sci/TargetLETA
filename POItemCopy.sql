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
--		Purchase Item Copy
-- =============================================
If Object_Id ( 'dbo.POItemCopy', 'P' ) Is Not Null
    Drop Procedure dbo.POItemCopy;
Go

Create Procedure [dbo].[POItemCopy]
	(
	  @CopyType			Numeric(1,0)	--複製類型: 1. Copy to Seq1; 2. Copy to Seq2
	 ,@ToPoID			VarChar(13)		--採購母單單號
	 ,@FromPoID			VarChar(13)		--採購母單單號
	 ,@UserID			VarChar(10) = ''
	 ,@ErrorMessage		VarChar(Max) = ''	Output
	)
As
Begin
	Set NoCount On;
	Set @ErrorMessage = '';
	----------------------------------------------------------------------
	If Object_ID('tempdb..#tmpSeq') Is Null
	Begin
		Create Table #tmpSeq (Seq1 VarChar(3), Seq2 VarChar(2), SciRefNo VarChar(30), SuppID VarChar(6), NewSeq1 VarChar(3), NewSuppID VarChar(6), NewQty Numeric(10,2), NewFOC Numeric(8,2))
		Set @ErrorMessage = 'Temp Table #tmpSeq is null'
		Return 0;
	End;
	----------------------------------------------------------------------
	Declare @Seq1 VarChar(3);
	Declare @SuppID VarChar(6);
	Declare @SuppID_New VarChar(6);
	Declare @ShipTermID VarChar(5);
	Declare @PayTermAPID VarChar(5);
	Declare @Remark NVarChar(Max);
	Declare @Description NVarChar(Max);
	Declare @CompanyID Numeric(2,0);

	Declare @tmpPo_Supp Table
		(  RowID BigInt Identity(1,1) Not Null, Seq1 VarChar(3), SuppID VarChar(6), ShipTermID VarChar(5), PayTermAPID VarChar(5)
		 , Remark NVarChar(Max), [Description] NVarChar(Max), CompanyID Numeric(2,0), NewSeq1 VarChar(3), NewSuppID VarChar(6), OnHold bit
		);
	Declare @tmpPo_SuppRowID Int;		--Row ID
	Declare @tmpPo_SuppRowCount Int;	--總資料筆數

	Declare @Seq2 VarChar(2);
	Declare @SCIRefNo VarChar(30);
	Declare @SCIRefNo_New VarChar(30);
	Declare @RefNo VarChar(36);
	Declare @ColorID VarChar(6);
	Declare @PoQty NUMERIC(10,2);
	Declare @FabricType VarChar(1);
	Declare @ShipModeID VarChar(10);

	Declare @tmpPo_Supp_Detail Table
		(  RowID BigInt Identity(1,1) Not Null, Seq1 VarChar(3), Seq2 VarChar(2), RefNo VarChar(36), SCIRefNo VarChar(30)
		 , FabricType VarChar(1), Price Numeric(16,4), UsedQty Numeric(10,4), Qty Numeric(10,2), POUnit VarChar(8)
		 , FinalETD Date, EstETA Date, ShipModeID Varchar(10), ColorID VarChar(6), SuppColor NVarChar(Max)
		 , Remark NVarChar(Max), Special NVarChar(120), Width Numeric(5,2)
		 , FOC Numeric(8,2), ColorDetail NVarchar(200), SystemETD DATE
		 , Spec NVarChar(Max), FactoryID VarChar(10), CopyFromSeq1 VarChar(3), CopyFromSeq2 VarChar(2)
		 , NewSeq1 VarChar(3), Keyword_Original VarChar(Max), OnHold bit
		);
	Declare @tmpPo_Supp_DetailRowID Int;	--Row ID
	Declare @tmpPo_Supp_DetailRowCount Int;	--總資料筆數

	Declare @tmpPo_Supp_Detail_Spec Table
		(  RowID BigInt, Seq1 VarChar(3), Seq2 VarChar(2), SpecColumnID Varchar(50), SpecValue Varchar(50));

	Declare @tmpPo_Supp_Detail_Keyword Table
		(  RowID BigInt, Seq1 VarChar(3), Seq2 VarChar(2), KeywordField Varchar(30), KeywordValue Varchar(200));
	
	Declare @SuppLockDate Date;
	Declare @SuppDelayDate Date;
	Declare @FabricLock Bit;
	Declare @FabricJunk Bit;

	Declare @Complete Bit;
	Declare @ToBrandID VarChar(8);
	Declare @FromBrandID VarChar(8);
	DECLARE @IsThirdSchedule BIT;
	Declare @Category VarChar(1);
	Declare @FactoryID VarChar(8);
	Declare @FtyCountry VarChar(2);
	Declare @OrderTypeID VarChar(20);
	Declare @StyleID VarChar(15);
	Declare @CFMDate DATE;
	Declare @SeasonID VarChar(10);	
	Declare @HaveFormA Bit;
	Declare @ProgramID VarChar(12);
	Declare @SuppColor NVarChar(Max);
	
	Declare @SystemETD_SpecialRule Bit;
	Declare @TargetLETA Date;
	Declare @LoadDate Date;
	Declare @OrderCompany numeric(2,0);

	Select @ToBrandID = Orders.BrandID
		 , @Category = Orders.Category
		 , @FactoryID = Orders.FactoryID
		 , @FtyCountry = Factory.CountryID
		 , @OrderTypeID = OrderTypeID
		 , @StyleID = StyleID
		 , @CFMDate = CFMDate
		 , @SeasonID = SeasonID
		 , @ProgramID = ProgramID
		 , @OrderCompany = OrderCompany
	  From dbo.Orders
	  Left Join dbo.Factory
		On Factory.ID = Orders.FactoryID
	 Where Orders.ID = @ToPoID;
	
	Select @Complete = PO.Complete
	  From dbo.PO
	 Where PO.ID = @ToPoID;

	Select 
		@FromBrandID = PO.BrandID
		,@IsThirdSchedule = PO.IsThirdSchedule
	 From dbo.PO
	Where PO.ID = @FromPoID
	
	--有無formA條件
	Set @HaveFormA = dbo.GetFormA(@FromPoID);

	Insert Into @tmpPo_Supp
		(Seq1, SuppID, ShipTermID, PayTermAPID, Remark, [Description], CompanyID, NewSeq1, NewSuppID, OnHold)
	Select distinct PO_Supp.Seq1, PO_Supp.SuppID, PO_Supp.ShipTermID, PO_Supp.PayTermAPID
		, PO_Supp.Remark, PO_Supp.Description, PO_Supp.CompanyID, tmp.NewSeq1, NewSuppID = IIF(isnull(tmp.NewSuppID, '') = '', PO_Supp.SuppID, tmp.NewSuppID), PO_Supp.OnHold
	From dbo.PO_Supp
	Inner join #tmpSeq tmp on tmp.Seq1 = PO_Supp.SEQ1
	Where PO_Supp.ID = @FromPoID
	Order by tmp.NewSeq1;

	Insert Into @tmpPo_Supp_Detail
		(  Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit, FinalETD, EstETA, ShipModeID
		 , ColorID, SuppColor, Remark, Special, Width, FOC, ColorDetail
		 , Spec, FactoryID, CopyFromSeq1, CopyFromSeq2, NewSeq1, Keyword_Original, OnHold
		)
		Select PO_Supp_Detail.Seq1, PO_Supp_Detail.Seq2, PO_Supp_Detail.RefNo, PO_Supp_Detail.SCIRefNo, PO_Supp_Detail.FabricType
			 , PO_Supp_Detail.Price, PO_Supp_Detail.UsedQty, tmp.NewQty, PO_Supp_Detail.POUnit
			 , PO_Supp_Detail.FinalETD, PO_Supp_Detail.EstETA, PO_Supp_Detail.ShipModeID
			 , po3Spec.Color, PO_Supp_Detail.SuppColor
			 , PO_Supp_Detail.Remark, PO_Supp_Detail.Special, PO_Supp_Detail.Width, tmp.NewFOC, PO_Supp_Detail.ColorDetail
			 , PO_Supp_Detail.Spec, PO_Supp_Detail.FactoryID, CopyFromSeq1 = PO_Supp_Detail.Seq1, CopyFromSeq2 = PO_Supp_Detail.Seq2, tmp.NewSeq1
			 , PO_Supp_Detail.Keyword_Original, PO_Supp_Detail.OnHold
		  From dbo.PO_Supp_Detail
		  Inner join #tmpSeq tmp on tmp.Seq1 = PO_Supp_Detail.SEQ1 And tmp.Seq2 = PO_Supp_Detail.SEQ2
		  outer apply dbo.GetPo3Spec(PO_Supp_Detail.ID, PO_Supp_Detail.Seq1, PO_Supp_Detail.Seq2) po3Spec
		 Where PO_Supp_Detail.ID = @FromPoID
		 Order by Seq1, Seq2;

	Insert Into @tmpPo_Supp_Detail_Spec
		(  RowID, Seq1, Seq2, SpecColumnID, SpecValue)
		Select po3.RowID, po4.Seq1, po4.Seq2, SpecColumnID, SpecValue
		From dbo.PO_Supp_Detail_Spec po4
		Inner join @tmpPo_Supp_Detail po3 on po4.Seq1 = po3.Seq1 and po4.Seq2 = po3.Seq2
		Where po4.ID = @FromPoID
		 Order by Seq1, Seq2;
	
	Insert Into @tmpPo_Supp_Detail_Keyword
		(  RowID, Seq1, Seq2, KeywordField, KeywordValue)
		Select po3.RowID, po4.Seq1, po4.Seq2, KeywordField, KeywordValue
		From dbo.PO_Supp_Detail_Keyword po4
		Inner join @tmpPo_Supp_Detail po3 on po4.Seq1 = po3.Seq1 and po4.Seq2 = po3.Seq2
		Where po4.ID = @FromPoID
		 Order by Seq1, Seq2;
	-------------------------------------------------
	Declare @Width numeric(5, 2);
	Declare @PoUnit Varchar(8);
	Declare @ColorDetail Nvarchar(100);
	Declare @Price NUMERIC(16,4);
	Declare @SystemETD date;
	Declare @SystemETD_Plus7D date;

	Declare @IsPo_SuppExist Bit;
	Declare @Seq1_New VarChar(3);
	Declare @Pre_Seq1_New VarChar(3) = '';
	Declare @numSeq2_New Numeric(3,0) = 0;
	Declare @Seq2_New VarChar(3);
	-------------------------------------------------
	--------------------Loop Start @tmpPo_Supp--------------------
	Set @tmpPo_SuppRowID = 1;
	Select @tmpPo_SuppRowID = Min(RowID), @tmpPo_SuppRowCount = Max(RowID) From @tmpPo_Supp;
	While @tmpPo_SuppRowID <= @tmpPo_SuppRowCount
	Begin
		Select @Seq1 = Seq1
			 , @SuppID = SuppID
			 , @ShipTermID = ShipTermID
			 , @PayTermAPID = PayTermAPID
			 , @Remark = Remark
			 , @Description = [Description]
			 , @CompanyID = CompanyID
			 , @Seq1_New = NewSeq1
			 , @SuppID_New = NewSuppID
		  From @tmpPo_Supp
		 Where RowID = @tmpPo_SuppRowID;

		 Select top 1 @FabricType = FabricType From @tmpPo_Supp_Detail Where Seq1 = @Seq1 and NewSeq1 = @Seq1_New

		--------------------------------------
		--根據新的Supplier帶相對應的 Shipping Mode, Shipment Term , Payment Term
		Set @SuppLockDate = null;
		Set @SuppDelayDate = null;
		Select @SuppLockDate = Supp.LockDate
			 , @SuppDelayDate = Supp.Delay
			 , @ShipModeID = dbo.GetFactoryDefaultShip(@FactoryID, Supp.ID, @ToBrandID)--2019/10/07 [IST20191534] modify by Poya 根據supp與Factory帶出ShipMode
			 , @ShipTermID = newSt.ShipTermID
			 , @PayTermAPID = Trade.dbo.GetSuppPaymentTerm(@ToBrandID, @SuppID_New, @Category, @OrderCompany)
			 , @CompanyID = isnull(getCompany.CompanyID, newSt.CompanyID)
		From Trade.dbo.Supp
		OUTER APPLY (select * from dbo.GetReplaceSupp_ShipTerm(Supp.ID, @Category, @FtyCountry, @FactoryID, @OrderCompany)) newSt
        OUTER APPLY (
            SELECT CompanyID = dbo.GetPurchaseCompany(
                'G',
                @Category,
                @FabricType,
                @OrderCompany,
                @FtyCountry,
                @FactoryID,
                Supp.CountryID,
                Supp.ShipTermID,
                Supp.CurrencyID,
                Supp.ID
            )
		) AS getCompany
		Where Supp.ID = @SuppID_New;

		--若COPY為新廠代則重新取Remark
		If @SuppID != @SuppID_New
		Begin
			Exec dbo.GetSuppRemark @FromPoID, @SuppID_New, @ToBrandID, @FtyCountry, @FactoryID, '', 'P', @Remark Output;
		End;
		--------------------------------------

		If @Seq1_New != @Pre_Seq1_New
		Begin
			Set @numSeq2_New = 0;
		End

		If exists (select 1 from dbo.PO_Supp_Detail where ID = @ToPoID and Seq1 = @Seq1_New)
		Begin
			Select @numSeq2_New = Max(Seq2) from dbo.PO_Supp_Detail where ID = @ToPoID and Seq1 = @Seq1_New
		End

		--------------------Loop Start @tmpPo_Supp_Detail--------------------
		Set @tmpPo_Supp_DetailRowID = 1;
		Select @tmpPo_Supp_DetailRowID = Min(RowID), @tmpPo_Supp_DetailRowCount = Max(RowID) From @tmpPo_Supp_Detail Where Seq1 = @Seq1 and NewSeq1 = @Seq1_New
		While @tmpPo_Supp_DetailRowID <= @tmpPo_Supp_DetailRowCount
		Begin
			Select @Seq2 = Seq2
				 , @SCIRefNo = SCIRefNo
				 , @RefNo = RefNo
				 , @FabricType = FabricType
				 , @ColorID = ColorID
				 , @PoQty = Qty
				 , @PoUnit = POUnit
			  From @tmpPo_Supp_Detail
			 Where RowID = @tmpPo_Supp_DetailRowID
			   And Seq1 = @Seq1;
			-------------------------------------------------
			--編新的小項編號
			Set @numSeq2_New += 1;
			Set @Seq2_New = Format(@numSeq2_New, '00');
			-------------------------------------------------
			Set @FabricJunk = 0;
			Set @FabricLock = 0;
			If @FromBrandID <> @ToBrandID --2018/06/26 Mantis:IST20180846 add by Poya
			BEGIN
				select @SCIRefno = f.SCIRefno
				From Fabric f
				Where f.BrandID = @ToBrandID
				and f.RefNo = @RefNo
				and f.Type = @FabricType

				Select @FabricJunk = cfu.Junk
					 , @FabricLock = cfu.Lock
					 , @SCIRefNo_New = Fabric.SCIRefno
					 , @Width = Fabric.Width
					 , @PoUnit = Fabric_Supp.POUnit
					 , @ColorDetail = Fabric.ColorDetail
				  From dbo.Fabric
				  Left Join dbo.Fabric_Supp On Fabric_Supp.SCIRefno = Fabric.SCIRefno
				  Outer apply (select * From dbo.CheckFabricUseful(Fabric.SCIRefno, @SeasonID, Fabric_Supp.SuppID)) cfu
					where Fabric.BrandID = @ToBrandID
						and Fabric.SCIRefno = @SCIRefNo
						and Fabric_Supp.SuppID = @SuppID_New;
			END
			ELSE
			BEGIN
				Select @FabricJunk = cfu.Junk
					 , @FabricLock = cfu.Lock
					 , @SCIRefNo_New = Fabric.SCIRefno
					 , @Width = Fabric.Width
					 , @PoUnit = Fabric_Supp.POUnit
					 , @ColorDetail = Fabric.ColorDetail
				  From dbo.Fabric
				  Left Join dbo.Fabric_Supp On Fabric_Supp.SCIRefno = Fabric.SCIRefno
				  Outer apply (select * From dbo.CheckFabricUseful(Fabric.SCIRefno, @SeasonID, Fabric_Supp.SuppID)) cfu
					where Fabric.BrandID = @ToBrandID
						and Fabric.SCIRefno = @SCIRefno
						and Fabric_Supp.SuppID = @SuppID_New;
			END;

			-------------------------------------------------
			If @SuppID != @SuppID_New
			Begin
			    If IsNull(@Remark, '') = ''
                Begin
                    Exec dbo.GetSuppRemark @FromPoID, @SuppID_New, @ToBrandID, @FtyCountry, @FactoryID, @FabricType, 'P', @Remark Output;
                End;

				Set @SuppColor = Trade.dbo.GetSuppColorList(@SCIRefNo, @SuppID_New, @ColorID, @ToBrandID, @SeasonID, @ProgramID, @StyleID)
			End
			Else
			Begin
				Set @SuppColor = Trade.dbo.GetSuppColorList(@SCIRefNo, @SuppID, @ColorID, @ToBrandID, @SeasonID, @ProgramID, @StyleID)
			End;
			-------------------------------------------------
			set @Price = dbo.GetPriceFromMtl(@SCIRefNo_New, @SuppID_New, @SeasonID, @PoQty, @Category, @CFMDate, '', @ColorID, @FactoryID);
			
			IF @IsThirdSchedule = 1
			BEGIN
				DECLARE @eta DATETIME = (SELECT TOP 1 MinKPILETA FROM dbo.GetSCI(@FromPoID, @Category));
				Set @SystemETD = (SELECT TOP 1 * from Trade.dbo.GetThirdSchedule(@FactoryID, @SuppID, @ShipModeID, @ShipTermID, @eta) ORDER BY LoadDate ASC);
			END
			ELSE
			BEGIN	
				set @SystemETD = DATEADD(DAY, dbo.GetMtlLT(@SCIRefNo_New, @Category, @SuppID_New, @StyleID, @ToBrandID, @SeasonID, @FtyCountry, @OrderTypeID, @ColorID), @CFMDate);
			END

			-- 2023.02.14 add by Vicky [IST20230130]
			Select @SystemETD_SpecialRule = SystemETD_SpecialRule From Trade.dbo.Brand with(nolock) Where ID = @ToBrandID

			If @SystemETD_SpecialRule = 1
			Begin				
				Select @TargetLETA = TargetLETA From Trade.dbo.PO where ID = @ToPoID
				If @TargetLETA is not null
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
			End
			-------------------------------------------------
			--將資料更新至 Temp Table Variable
			Update @tmpPo_Supp_Detail
			   Set Seq1 = @Seq1_New
				 , Seq2 = @Seq2_New
				 , ShipModeID = isnull(@ShipModeID, '')
				 , SCIRefNo = isnull(@SCIRefNo_New, '')
				 , Width = isnull(@Width, 0)
				 , POUnit = isnull(@PoUnit, '')
				 , ColorDetail = isnull(@ColorDetail, '')
				 , Price = iif(@SCIRefNo = @SCIRefNo_New, Price, isnull(@Price, 0)) --新舊料號一樣則不更換Price
				 , SystemETD = @SystemETD
				 , SuppColor = isnull(@SuppColor, '')
			 Where RowID = @tmpPo_Supp_DetailRowID;

			Update @tmpPo_Supp_Detail_Spec
			   Set Seq1 = @Seq1_New
				 , Seq2 = @Seq2_New
			Where RowID = @tmpPo_Supp_DetailRowID;

			Update @tmpPo_Supp_Detail_Keyword
			   Set Seq1 = @Seq1_New
				 , Seq2 = @Seq2_New
			Where RowID = @tmpPo_Supp_DetailRowID;
			-------------------------------------------------
			Set @tmpPo_Supp_DetailRowID += 1;
		End;
		--------------------Loop End @tmpPo_Supp_Detail--------------------
		--小項資料筆數不可超過99筆
		If @numSeq2_New >= 100
		Begin
			Set @ErrorMessage += 'Seq1: ' + @Seq1 + ' - Seq#2 can''t be greater than 99';
		End;
		-------------------------------------------------
		--將資料更新至 Temp Table Variable
		Update @tmpPo_Supp
		   Set Seq1 = @Seq1_New
			 , SuppID = @SuppID_New
			 , ShipTermID = @ShipTermID
			 , PayTermAPID = @PayTermAPID
			 , Remark = @Remark
			 , CompanyID = @CompanyID
		 Where RowID = @tmpPo_SuppRowID;
		-------------------------------------------------
		Set @Pre_Seq1_New = @Seq1_New;
		Set @tmpPo_SuppRowID += 1;
	End;

	--Edward 刪除沒有小項的項目
	delete @tmpPo_Supp where not exists(select 1 from @tmpPo_Supp_Detail where [@tmpPo_Supp].Seq1 = [@tmpPo_Supp_Detail].Seq1)
	--------------------Loop End @tmpPo_Supp--------------------

	If IsNull(@ErrorMessage, '') != ''
	Begin
		Return 0;
	End;

	Declare @AddDate DateTime = GetDate();
	Begin Try
		Begin Transaction;

		Insert Into dbo.PO_Supp
			(ID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, [Description], CompanyID, AddName, AddDate, OnHold)
			Select distinct @ToPoID, Seq1, SuppID, ShipTermID, PayTermAPID, Remark, [Description], CompanyID
				 , @UserID, @AddDate, OnHold
			  From (select rn = ROW_NUMBER() OVER (PARTITION BY Seq1 ORDER BY Remark Desc), * from @tmpPo_Supp) tmp
			  Where tmp.rn = 1
			  and not exists (select 1 from dbo.PO_Supp po2 where po2.ID = @ToPoID and po2.Seq1 = tmp.Seq1);
		
		Insert Into dbo.PO_Supp_Detail
			(  ID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit, ShipModeID
			 , SuppColor, Remark, Special, Width, FOC, ColorDetail
			 , SystemETD, FinalETD
			 , Spec, FactoryID, AddName, AddDate
			 , CopyFromSeq1, CopyFromSeq2, Keyword_Original, OnHold
			)
			Select @ToPoID, Seq1, Seq2, RefNo, SCIRefNo, FabricType, Price, UsedQty, Qty, POUnit, ShipModeID
				 , SuppColor, Remark, Special, Width, FOC, ColorDetail
				 , SystemETD, SystemETD
				 , Spec, FactoryID, @UserID, @AddDate
				 , CopyFromSeq1, CopyFromSeq2, Keyword_Original, OnHold
			  From @tmpPo_Supp_Detail;
		
		Insert Into dbo.PO_Supp_Detail_Spec
			(ID, Seq1, Seq2, SpecColumnID, SpecValue, AddName, AddDate)
			Select @ToPoID, Seq1, Seq2, SpecColumnID, SpecValue, @UserID, @AddDate
			From @tmpPo_Supp_Detail_Spec;
			
		Insert Into dbo.PO_Supp_Detail_Keyword
			(ID, Seq1, Seq2, KeywordField, KeywordValue, AddName, AddDate)
			Select @ToPoID, Seq1, Seq2, KeywordField, KeywordValue, @UserID, @AddDate
			From @tmpPo_Supp_Detail_Keyword;

		If @Complete =1
		Begin
			Update dbo.PO
			   Set Complete = 0
			 Where ID = @ToPoID;
		End;
		Commit Transaction;
	End Try
	Begin Catch
		RollBack Transaction

		Declare @ErrorMsg NVarChar(4000);
		Declare @ErrorSeverity Int;
		Declare @ErrorState Int;

		Set @ErrorMsg = Error_Message();
		Set @ErrorSeverity = Error_Severity();
		Set @ErrorState = Error_State();

		RaisError (@ErrorMsg,		-- Message text.
				   @ErrorSeverity,	-- Severity.
				   @ErrorState		-- State.
				  );
	End Catch;
End
