USE [Trade]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Harry
-- Create date: 2024/9/6
-- Description:
--		Transfer To PO 後自動入庫
-- =============================================
If Object_Id ( 'dbo.TransferToPO_3_AutoInput', 'P' ) Is Not Null
DROP PROCEDURE dbo.TransferToPO_3_AutoInput;
GO

Create Procedure [dbo].[TransferToPO_3_AutoInput]
	(
	  @PoID			VarChar(13)		--採購母單
	 ,@UserID		VarChar(10)
	 ,@ReasonID		VarChar(5)
	 ,@Seq1_Start	VarChar(3)	= ''	--採購大項區間(起)
	 ,@Seq1_End		VarChar(3)	= ''	--採購大項區間(迄)
	)
As
Begin
SET NOCOUNT ON;

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
		
	End;
----------------------------------------------------------------------


	DECLARE @InvTransID VARCHAR(13);
	DECLARE @RaisError VARCHAR(1000);

	SELECT TOP 1
		@InvTransID = 'ST' + FORMAT(GETDATE(), 'yyyyMM') + FORMAT(CONVERT(INT, RIGHT(ID, 5)) + 1, '00000')
	FROM Trade.dbo.InvTrans
	WHERE ID LIKE 'ST' + FORMAT(GETDATE(), 'yyyyMM') + '%'
	ORDER BY ID DESC;

	IF (ISNULL(@InvTransID, '') = '')
	BEGIN
		SET @InvTransID = 'ST' + FORMAT(GETDATE(), 'yyyyMM') + '00001'
	end

	-- 成立Invtrans
	INSERT INTO Trade.dbo.Invtrans (ID, Type, CreateDate, Handle, Qty, Amount, Status, ConfirmHandle, ConfirmDate, Confirmed, Remark)
		SELECT
			ID = @InvTransID
		   ,Type = '1'
		   ,CreateDate = GETDATE()
		   ,Handle = @UserID
		   ,Qty = SUM(ISNULL(po3.Qty, 0))
		   ,Amount = SUM(ROUND(ISNULL(po3.Qty, 0) * ISNULL(po3.Price, 0) * cur.Rate, cur.Exact))
		   ,Status = 'F'
		   ,ConfirmHandle = @UserID
		   ,ConfirmDate = GETDATE()
		   ,Confirmed = 0
		   ,Remark = 'Auto input from Transfer to PO'
		FROM #tmpPO_Supp_Detail po3
		LEFT JOIN Orders o ON o.ID = po3.ID
		LEFT JOIN #tmpPO_Supp AS po2 ON po2.ID = po3.ID
				AND po2.Seq1 = po3.Seq1
		LEFT JOIN Trade.dbo.Supp AS s ON s.ID = po2.SuppID
		OUTER APPLY Trade.dbo.GetCurrencyRate('FX', s.CurrencyID, 'TWD', o.CFMDate) AS cur
		WHERE po3.ID = @PoID
		AND ((@Seq1_Start = ''
			AND @Seq1_End = '')
			OR (@Seq1_Start != ''
			AND @Seq1_End != ''
			AND po3.Seq1 BETWEEN @Seq1_Start AND @Seq1_End)
		)
		And po2.SuppID <> 'FTY'
		AND po3.Seq1 NOT LIKE 'A%'
		AND po3.Seq1 NOT LIKE '7%';

	-- 成立Invtrans_Detail
	INSERT INTO Trade.dbo.Invtrans_Detail (ID, ConfirmDate, ConfirmHandle, Confirmed, Status
	, Qty, Type, TransferFactory, InventoryUkey, InventoryRefnoId
	, PoID, Seq1, Seq2, InventoryPOID, InventorySeq1, InventorySeq2
	, Seq70PoID, Seq70Seq1, Seq70Seq2, Deadline
	, ReasonID, Remark, PoHandle, PoSmr, OrderHandle, OrderSmr
	, PoFactory, LimitHandle, LimitSmr, AuthMr, VoucherId
	, BrandID, BrandGroup, Refno, FabricType, FactoryID, MtlTypeID
	, ProjectID, SeasonID, StyleID, UnitID, BomCustPONo, BomZipperInsert
	, AddName, AddDate, InventoryReasonID)
		SELECT
			it.ID
		   ,it.ConfirmDate
		   ,it.ConfirmHandle
		   ,it.Confirmed
		   ,it.Status
		   ,po3.Qty
		   ,it.Type
		   ,TransferFactory = ''
		   ,InventoryUkey = ''
		   ,InventoryRefnoId = ''
		   ,po3.ID
		   ,po3.Seq1
		   ,po3.Seq2
		   ,InventoryPOID = po3.ID
		   ,InventorySeq1 = po3.Seq1
		   ,InventorySeq2 = po3.Seq2
		   ,Seq70PoID = ''
		   ,Seq70Seq1 = ''
		   ,Seq70Seq2 = ''
		   ,Deadline = invDeadline.Deadline
		   ,@ReasonID
		   ,Remark = ''
		   ,po1.PoHandle
		   ,po1.PoSmr
		   ,o.MRHandle
		   ,o.SMR
		   ,o.FactoryID
		   ,LimitHandle = ''
		   ,LimitSmr = ''
		   ,AuthMr = ''
		   ,VoucherId = ''
		   ,o.BrandID
		   ,b.BrandGroup
		   ,po3.Refno
		   ,po3.FabricType
		   ,o.FactoryID
		   ,fab.MtlTypeID
		   ,o.ProjectID
		   ,o.SeasonID
		   ,o.StyleID
		   ,po3.POUnit
		   ,po3Spec.CustomerPO
		   ,po3Spec.ZipperInsert
		   ,@UserID
		   ,GETDATE()
		   ,InventoryReasonID = @ReasonID
		FROM #tmpPO_Supp_Detail AS po3
		OUTER APPLY Trade.dbo.GetPo3Spec(po3.ID, po3.Seq1, po3.Seq2) po3Spec
		LEFT JOIN Orders o ON o.ID = po3.ID
		LEFT JOIN #tmpPO_Supp AS po2 ON po2.ID = po3.ID
				AND po2.SEQ1 = po3.SEQ1
		LEFT JOIN Trade.dbo.PO AS po1	ON po1.ID = po3.ID
		INNER JOIN Trade.dbo.InvTrans AS it	ON it.ID = @InvTransID
		LEFT JOIN Trade.dbo.Brand b ON b.ID = o.BrandID
		LEFT JOIN Trade.dbo.Fabric AS fab	ON fab.SCIRefno = po3.SCIRefno
		CROSS APPLY Trade.dbo.GetInventory_Deadline(o.BrandID, o.ProjectID, o.CFMDate) AS invDeadline
		OUTER APPLY (SELECT
				invtransQty = ISNULL(SUM(Qty), 0)
			FROM Trade.dbo.Invtrans_Detail ivD
			WHERE ivD.Type IN ('1', '4')
			AND ivD.PoID = po3.Id
			AND ivD.Seq1 = po3.seq1
			AND ivD.Seq2 = po3.Seq2) GetInvQty
		WHERE po3.ID = @PoID
		AND ((@Seq1_Start = ''
			AND @Seq1_End = '')
			OR (@Seq1_Start != ''
			AND @Seq1_End != ''
			AND po3.Seq1 BETWEEN @Seq1_Start AND @Seq1_End)
		)
		And po2.SuppID <> 'FTY'
		AND (po3.Qty - GetInvQty.invtransQty > 0)
		AND po3.Seq1 NOT LIKE 'A%'
		AND po3.Seq1 NOT LIKE '7%'

	-- 呼叫ConfirmInvtrans_Input
	EXECUTE Trade.dbo.ConfirmInvtrans_Input @InvTransID,@UserID

END
GO

Go
Exec Trade.dbo.CopyProcedureToDataBase 'MemDB', 'TransferToPO_3_AutoInput', 'Trade', 'P';
Go