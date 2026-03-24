Use [Trade]
Go

Set Ansi_Nulls On
Go
Set Quoted_Identifier On
Go
-- =============================================
-- Author:		Edward
-- Create date: 2017/03/16
-- Description:
--		計算 Each Consumption 外裁，及 PO 的 A1 項目
-- =============================================
If Object_Id ( 'dbo.CalculateEachConsCuttingPieceAndItemA1', 'P' ) Is Not Null
    Drop Procedure dbo.CalculateEachConsCuttingPieceAndItemA1;
Go

Create Procedure [dbo].[CalculateEachConsCuttingPieceAndItemA1]
-- Add the parameters for the stored procedure here
(
	@PoID VarChar(13)
	,@CuttingSP VarChar(13)
	,@UserID VarChar(10) = ''
	,@IsPurchase	 bit = 1		--判斷是Purchase(=1)還是Production(=0)，預設=1
)
As
Begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	Set NoCount On; 

	Declare @TestType Int = 0		--是否為虛擬庫存計算(0: 實際寫入Table; 1: 僅傳出Temp Table; 2: 不回傳Temp Table; 3: 實際寫入Table，但不回傳Temp Table)
	Declare @BrandID VarChar(8) = ''
	Declare @ProgramID VarChar(12) = ''
	Declare @Category VarChar(1) = ''
	Declare @PoHandle VarChar(10) = ''
	Declare @PoSMR VarChar(10) = ''
	Declare @CalType VarChar(1)		--M: 混尺碼計算; S: 只取單尺碼馬克
	select @BrandID = BrandID, @ProgramID = ProgramID, @Category = Category from Orders where CuttingSP = @CuttingSP
	select @PoHandle = POHandle, @PoSMR = POSMR from PO where ID = @PoID
	select @CalType = iif(IsMixMarker = 1, 'M', 'S') from Orders where POID = @PoID and CuttingSP = @CuttingSP

	Exec dbo.CalculateEachCons @PoID, @CuttingSP, @CalType, 2, @TestType, @UserID, @IsPurchase

	If Object_ID('tempdb..#tmpPO_Supp') Is Null
	Begin
		Create Table #tmpPO_Supp
			(  RowID BigInt Identity(1,1) Not Null, ID VarChar(13), Seq1 VarChar(3), SuppID VarChar(6) default '', ShipTermID VarChar(5) default '', PayTermAPID VarChar(5) default ''
			 , Remark NVarChar(Max) default '', Description NVarChar(Max) default '', CompanyID Numeric(2,0) default 0
			 , StyleID VarChar(15), TargetLETA Date, Primary Key (ID, Seq1)
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
			 , Remark NVarChar(Max) default '', Special NVarChar(Max) default '', Width Numeric(5,2) default 0
			 , StockQty Numeric(12,1) default 0, NetQty Numeric(10,2) default 0, LossQty Numeric(10,2) default 0, SystemNetQty Numeric(10,2) default 0
			 , SystemCreate bit default 0, FOC Numeric(10,2) default 0, Junk bit default 0, ColorDetail NVarChar(Max) default ''
			 , BomZipperInsert VarChar(5) default '', BomCustPONo VarChar(30) default ''
			 , ShipQty Numeric(10,2) default 0, Shortage Numeric(10,2) default 0, ShipFOC Numeric(10,2) default 0, ApQty Numeric(10,2) default 0
			 , InputQty Numeric(10,2) default 0, OutputQty Numeric(10,2) default 0, Spec NVarChar(Max) default '', ShipETA Date, SystemLock Date
			 , OutputSeq1 VarChar(3) default '', OutputSeq2 VarChar(2) default '', FactoryID VarChar(8) default ''
			 , StockPOID VarChar(13) default '', StockSeq1 VarChar(3) default '', StockSeq2 VarChar(2) default '', InventoryUkey bigint default 0
			 , KeyWord NVarChar(Max) default '', Article varchar(8)
			 , Seq2_Count Int, Remark_Shell NVarChar(Max) default '', IsForOtherBrand bit, CannotOperateStock bit, Keyword_Original varchar(max)
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

	--[IST20180396] 2018.04.11 Edward add delete A Item
	DELETE FROM PO_Supp_Detail_Spec WHERE ID = @PoID AND (Seq1 = 'A1' or SEQ1 = 'A2')
	DELETE FROM PO_Supp_Detail_Keyword WHERE ID = @PoID AND (Seq1 = 'A1' or SEQ1 = 'A2')
	DELETE FROM PO_Supp_Detail WHERE ID = @PoID AND (Seq1 = 'A1' or SEQ1 = 'A2')
	DELETE FROM PO_Supp WHERE ID = @PoID AND (Seq1 = 'A1' or SEQ1 = 'A2')

	Exec dbo.TransferToPO_1_ForAItem @PoID, @BrandID, @ProgramID, @Category, @TestType	--Item A to PO
	Exec dbo.TransferToPO_2 @PoID, 0, @TestType, @UserID;	--填入共同資料
	Exec dbo.TransferToPO_3_Insert @PoID, '', '', @PoHandle, @PoSMR, 0, @UserID	--將資料轉入至Table

End