create or replace PACKAGE BODY CUSTOMUSR.XX_OSSA_BOM_CONV_PKG
AS
/***************************************************************************************************
 * Package Body CUSTOMUSR.XX_OSSA_BOM_CONV_PKG
 * 
 * BOM_INVENTORY_COMPONENTS -- Standard Oracle Base table
 * BOM_BILL_OF_MATERIALS -- Standard Oracle Base table
 *
 * Description:
 * This package is used for Bill of Materials conversion in the Oracle system.
 *
 * Change History
 * Version          Date                     Name                      Description of Change
 * -------          -------              ------------------------      ---------------------------------
 * 1.0              05/05/2020           Manoj Arava (Cognizant)      Initial Creation...
 * 
 ****************************************************************************************************/
/***************************************************************************************************
 * PROCEDURE FND_LOG
 * 
 * Description:
 * Prints concurrent program log.
 * 
 ****************************************************************************************************/
	TYPE g_bom_rec IS RECORD
		(
		org_code					 customusr.xx_ossa_bom_conv_stg_tbl.org_code%TYPE,
		assembly_item_num            customusr.xx_ossa_bom_conv_stg_tbl.assembly_item_num%TYPE,
		alternate_bom                customusr.xx_ossa_bom_conv_stg_tbl.alternate_bom%TYPE
		);

	TYPE g_bom IS TABLE OF g_bom_rec;

	gn_bom_tbl g_bom;

	TYPE g_bom_comp IS RECORD
		(
		org_code					 customusr.xx_ossa_bom_conv_stg_tbl.org_code%TYPE,
		assembly_item_num            customusr.xx_ossa_bom_conv_stg_tbl.assembly_item_num%TYPE,
		line_item_num                customusr.xx_ossa_bom_conv_stg_tbl.line_item_num%TYPE,
		BASIS_TYPE                        customusr.xx_ossa_bom_conv_stg_tbl.BASIS_TYPE%TYPE,
		wip_supply_type			     customusr.xx_ossa_bom_conv_stg_tbl.wip_supply_type%TYPE,
		optional	                 customusr.xx_ossa_bom_conv_stg_tbl.optional%TYPE,
		quantity                     customusr.xx_ossa_bom_conv_stg_tbl.quantity%TYPE,
		item_sequence_number         customusr.xx_ossa_bom_conv_stg_tbl.item_sequence_number%TYPE,
		operation_sequence_number    customusr.xx_ossa_bom_conv_stg_tbl.operation_sequence_number%TYPE,
		yield_of_component           customusr.xx_ossa_bom_conv_stg_tbl.yield_of_component%TYPE,
		supply_subinventory          customusr.xx_ossa_bom_conv_stg_tbl.supply_subinventory%TYPE,
		locator                      customusr.xx_ossa_bom_conv_stg_tbl.locator%TYPE,
		alternate_bom                customusr.xx_ossa_bom_conv_stg_tbl.alternate_bom%TYPE,
		sub_comp_item_num			 customusr.xx_ossa_bom_conv_stg_tbl.sub_comp_item_num%TYPE,
		sub_comp_quantity			 customusr.xx_ossa_bom_conv_stg_tbl.sub_comp_quantity%TYPE,
		enforce_integer_quantity	 customusr.xx_ossa_bom_conv_stg_tbl.enforce_integer_quantity%TYPE,
		include_in_cost_rollup_code	 customusr.xx_ossa_bom_conv_stg_tbl.include_in_cost_rollup_code%TYPE
		);

	TYPE g_bom_comp_rec IS TABLE OF g_bom_comp;

	gn_bom_comp_tbl g_bom_comp_rec;

PROCEDURE FND_LOG(P_MSG VARCHAR2)
AS
BEGIN
	apps.xx_comn_pers_util_pkg.FND_LOG(P_MSG);
	EXCEPTION WHEN OTHERS THEN
	NULL; --debug
END FND_LOG;
/***************************************************************************************************
 * PROCEDURE FND_OUT
 * 
 * Description:
 * Prints concurrent program output.
 * 
 ****************************************************************************************************/
PROCEDURE FND_OUT(P_MSG VARCHAR2)
AS
BEGIN
	apps.xx_comn_pers_util_pkg.FND_OUT(p_MSG);
	EXCEPTION WHEN OTHERS THEN
	NULL; --debug
END FND_OUT;
/***************************************************************************************************
 * PROCEDURE VALIDATE_ORG
 * 
 * Description:
 * Validates organization code in the data file
 * 
 ****************************************************************************************************/
PROCEDURE validate_org(p_org_code IN VARCHAR2
                       ,p_org_id OUT NUMBER
					   ,p_err_flag OUT VARCHAR2
					   ,p_err_msg OUT VARCHAR2
					   )
AS
  BEGIN
    SELECT organization_id
	INTO p_org_id
	FROM apps.org_organization_definitions
	WHERE organization_code = p_org_code;
	p_err_flag := 'N';
	p_err_msg := NULL;
  EXCEPTION 
   WHEN NO_DATA_FOUND THEN
     p_err_flag := 'Y';
	 p_err_msg := 'The org code provided is not valid in system';
	 p_org_id := NULL;
   WHEN OTHERS THEN
	 p_err_flag := 'Y';
	 p_err_msg := 'Exception while validating organization '||SQLCODE||' '||SQLERRM;
	 apps.xx_comn_conv_debug_prc ( p_i_level =>NULL,
						      p_i_proc_name => 'BOM Conversion',
						      p_i_phase => 'VALIDATE_ORG',
						      p_i_stgtable => 'xx_ossa_bom_conv_stg_tbl' ,
						      p_i_message => 'Exception while validating organization '||SQLCODE||' '||SQLERRM);
  END validate_org;
/***************************************************************************************************
 * PROCEDURE VALIDATE_ITEM
 * 
 * Description:
 * Prints concurrent program output.
 * 
 ****************************************************************************************************/
PROCEDURE VALIDATE_ITEM(P_I_ITEM_NUM IN VARCHAR2
                       ,P_I_ORG_ID IN NUMBER
					   ,P_O_ITEM_ID OUT NUMBER
					   ,P_O_ERR_MSG OUT VARCHAR2
					   ,P_O_ERR_FLAG OUT VARCHAR2
					   )
AS
LV_ERR_MSG VARCHAR2 (200);
ln_inventory_item_id NUMBER;
BEGIN
	SELECT
		inventory_item_id
	INTO
		P_O_ITEM_ID
	FROM
		apps.mtl_system_items_b msi
	WHERE
		segment1 = P_I_ITEM_NUM
	AND
		msi.organization_id = P_I_ORG_ID;
	P_O_ERR_FLAG := 'N';
  P_O_ERR_MSG := NULL;
EXCEPTION WHEN NO_DATA_FOUND THEN
	P_O_ERR_MSG := ' - Invalid Item Number for Organization';
	P_O_ERR_FLAG := 'Y';
	P_O_ITEM_ID := -1;
WHEN OTHERS THEN
	P_O_ITEM_ID := -1;
	P_O_ERR_FLAG := 'Y';
	P_O_ERR_MSG := ' Exception While validating Item Number'||SQLCODE||' '||SQLERRM;

END VALIDATE_ITEM;
/***************************************************************************************************
 * PROCEDURE VALIDATE_BASIS
 * 
 * Description:
 * This Procedures validates the basis provided in data
 * 
 ****************************************************************************************************/
PROCEDURE validate_basis(p_basis IN VARCHAR2
                       ,p_basis_type OUT VARCHAR2
					   ,p_err_flag OUT VARCHAR2
					   ,p_err_msg OUT VARCHAR2
					   )
AS
  BEGIN
    SELECT lookup_code
	INTO p_basis_type
	FROM apps.mfg_lookups
	WHERE lookup_type = 'BOM_BASIS_TYPE'
	AND enabled_flag = 'Y'
	AND (end_date_active IS NULL OR end_date_active > SYSDATE)
	AND UPPER(meaning) = UPPER(p_basis)
	;
	p_err_flag := 'N';
	p_err_msg := NULL;
  EXCEPTION 
   WHEN NO_DATA_FOUND THEN
     p_err_flag := 'Y';
	 p_err_msg := 'The basis provided is not valid in system';
	 p_basis_type := NULL;
   WHEN OTHERS THEN
	 p_err_flag := 'Y';
	 p_err_msg := 'Exception while validating basis '||SQLCODE||' '||SQLERRM;

  END validate_basis;
  /***************************************************************************************************
 * PROCEDURE VALIDATE_SUPPLY
 * 
 * Description:
 * This Procedures validates the supply type provided in data
 * 
 ****************************************************************************************************/
  PROCEDURE validate_supply(p_supply IN VARCHAR2
                       ,p_supply_type OUT VARCHAR2
                       ,p_err_flag OUT VARCHAR2
					   ,p_err_msg OUT VARCHAR2
					   )
AS
  ln_cnt NUMBER;
  BEGIN
    SELECT lookup_code
	INTO p_supply_type
	FROM apps.mfg_lookups
	WHERE lookup_type = 'WIP_SUPPLY'
	AND enabled_flag = 'Y'
	AND (end_date_active IS NULL OR end_date_active > SYSDATE)
	AND UPPER(meaning) = UPPER(p_supply)
	;
	p_err_flag := 'N';
	p_err_msg := NULL;
  EXCEPTION 
   WHEN NO_DATA_FOUND THEN
     p_err_flag := 'Y';
	 p_err_msg := 'The supply type provided is not valid in system';
	 p_supply_type := NULL;
   WHEN OTHERS THEN
	 p_err_flag := 'Y';
	 p_err_msg := 'Exception while validating supply type '||SQLCODE||' '||SQLERRM;
	   END validate_supply;
   /***************************************************************************************************
 * PROCEDURE validate_op_seq
 * 
 * Description:
 * This Procedures validates the validate_op_seq provided in data
 * 
 ****************************************************************************************************/
  PROCEDURE validate_op_seq(p_op_seq IN NUMBER
                       ,p_org_id IN NUMBER
					   ,p_item_id IN NUMBER
                       ,p_err_flag OUT VARCHAR2
					   ,p_err_msg OUT VARCHAR2
					   )
AS
  ln_op_seq NUMBER;
  BEGIN
    SELECT COUNT(1) 
	INTO ln_op_seq
	 FROM 
	 apps.BOM_OPERATIONAL_ROUTINGS ROUTING,
	 apps.BOM_OPERATION_SEQUENCES SEQUENCES
	 WHERE ROUTING.ROUTING_SEQUENCE_ID = SEQUENCES.ROUTING_SEQUENCE_ID
	 AND ROUTING.ASSEMBLY_ITEM_ID =  p_item_id
	 AND ROUTING.ORGANIZATION_ID = p_org_id
	 AND SEQUENCES.OPERATION_SEQ_NUM =  p_op_seq
	 ;
	 IF ln_op_seq > 0 THEN
	p_err_flag := 'N';
	p_err_msg := NULL;
	ELSE 
     p_err_flag := 'Y';
	 p_err_msg := 'The operation sequence is not valid in system';
	 END IF;
	 EXCEPTION
	WHEN OTHERS THEN
	 p_err_flag := 'Y';
	 p_err_msg := 'Exception while validating operation sequence '||SQLCODE||' '||SQLERRM;
	  END validate_op_seq;
  /***************************************************************************************************
 * PROCEDURE validate_uom
 * 
 * Description:
 * This Procedures validates the UOM provided in data
 * 
 ****************************************************************************************************/

  PROCEDURE validate_uom(p_inventory_item IN NUMBER,
							p_organization_id IN NUMBER,
							p_unit_of_measure OUT VARCHAR2,
							p_valid_uom OUT VARCHAR2,
							p_error_msg OUT VARCHAR2)
    AS  
	BEGIN
	     SELECT primary_uom_code
		 INTO p_unit_of_measure
		 FROM apps.mtl_system_items_b
		where organization_id = p_organization_id
			 and inventory_item_id = p_inventory_item;
		IF p_unit_of_measure IS NOT NULL THEN
        	p_valid_uom :='N';
		ELSE 
		p_valid_uom:='Y';
		END IF;
		 EXCEPTION
    WHEN OTHERS THEN
      p_error_msg := p_error_msg||'Problem in determining Unit of measure validity due to: '||SQLERRM;
      p_valid_uom := 'Y';
  END validate_uom;
--/****************************************************************************************************************
-- * procedure  : item_revision                                                                         *
-- * Purpose   : This procedure will check if the org code is setup in oracle.                          *
-- ****************************************************************************************************************/
PROCEDURE item_revision(
    p_org_id  IN NUMBER,
    p_item_id IN NUMBER,
    p_item_rev OUT VARCHAR2,
    p_valid_rev OUT VARCHAR2,
    p_error_msg OUT VARCHAR2 )
AS
BEGIN
  SELECT revision
  INTO p_item_rev
  FROM apps.mtl_item_revisions
  WHERE inventory_item_id = p_item_id
  AND organization_id     = p_org_id
  AND effectivity_date    =
    (SELECT MAX(effectivity_date)
    FROM apps.mtl_item_revisions
    WHERE inventory_item_id=p_item_id
    AND organization_id    =p_org_id
    AND effectivity_date  <= SYSDATE
    );
  p_valid_rev := 'N';
EXCEPTION
WHEN OTHERS THEN
  p_error_msg := p_error_msg||'Problem in deriving item revision for:'||p_item_id ;
  p_valid_rev := 'Y';
END item_revision;
/***************************************************************************************************
 * PROCEDURE validate_sub_inventory
 * 
 * Description:
 * This Procedures validates the subinventory provided in data
 * 
 ****************************************************************************************************/
PROCEDURE validate_sub_inventory(p_subinventory IN VARCHAR2
                       ,p_org_id IN NUMBER
					   ,p_err_flag OUT VARCHAR2
					   ,p_err_msg OUT VARCHAR2
					   )
AS
lv_subinventory_code varchar2(50);
  BEGIN
    SELECT secondary_inventory_name
	INTO lv_subinventory_code
	FROM apps.mtl_secondary_inventories
	WHERE secondary_inventory_name = p_subinventory
	AND organization_id = p_org_id
	;
	IF lv_subinventory_code IS NULL THEN
	p_err_flag := 'Y';
	p_err_msg := 'The subinventory provided is not valid in system';
	ELSE
	p_err_flag := 'N';
	p_err_msg := NULL;
	END IF;
  EXCEPTION 
   WHEN NO_DATA_FOUND THEN
     p_err_flag := 'Y';
	 p_err_msg := 'The subinventory provided is not valid in system';
   WHEN OTHERS THEN
	 p_err_flag := 'Y';
	 p_err_msg := 'Exception while validating subinventory '||SQLCODE||' '||SQLERRM;
	   END validate_sub_inventory;
  /***************************************************************************************************
 * PROCEDURE validate_locator
 * 
 * Description:
 * This Procedures validates the locator provided in data
 * 
 ****************************************************************************************************/
PROCEDURE validate_locator(p_locator IN VARCHAR2
                       ,p_org_id IN NUMBER
					   ,p_locator_id OUT NUMBER
					   ,p_subinventory IN VARCHAR2
					   ,p_err_flag OUT VARCHAR2
					   ,p_err_msg OUT VARCHAR2
					   )
AS
  BEGIN
    SELECT inventory_location_id
	INTO p_locator_id
	FROM apps.mtl_item_locations_kfv
	WHERE concatenated_segments = p_locator
	AND organization_id = p_org_id
	AND subinventory_code = p_subinventory
	;
	IF p_locator_id IS NULL THEN
	p_err_flag := 'Y';
	p_err_msg := 'The locator provided is not valid for the given subinventory in system';
	ELSE
	p_err_flag := 'N';
	p_err_msg := NULL;
	END IF;
  EXCEPTION 
   WHEN NO_DATA_FOUND THEN
     p_err_flag := 'Y';
	 p_err_msg := 'The locator provided is not valid in system';
	 p_locator_id := NULL;
   WHEN OTHERS THEN
	 p_err_flag := 'Y';
	 p_err_msg := 'Exception while validating locator '||SQLCODE||' '||SQLERRM;
	   END validate_locator;
   /***************************************************************************************************
 * PROCEDURE validate_alternate_bom
 * 
 * Description:
 * This Procedures validates the Alternate BOM provided in data
 * 
 ****************************************************************************************************/
PROCEDURE validate_alternate_bom(p_alternate_bom IN VARCHAR2
                       ,p_org_id IN NUMBER
					   ,p_err_flag OUT VARCHAR2
					   ,p_err_msg OUT VARCHAR2
					   )
AS
lv_alternate_bom VARCHAR2(50) := NULL;
  BEGIN
	SELECT alternate_designator_code
	INTO lv_alternate_bom
	FROM apps.bom_alternate_designators_tl
	WHERE alternate_designator_code = p_alternate_bom
	AND organization_id = p_org_id
	;
	IF lv_alternate_bom IS NULL THEN
	p_err_flag := 'Y';
	p_err_msg := 'The Alternate BOM provided is not valid in system';
	ELSE
	p_err_flag := 'N';
	p_err_msg := NULL;
	END IF;
  EXCEPTION 
   WHEN NO_DATA_FOUND THEN
     p_err_flag := 'Y';
	 p_err_msg := 'The Alternate BOM provided is not valid in system';
   WHEN OTHERS THEN
	 p_err_flag := 'Y';
	 p_err_msg := 'Exception while validating Alternate BOM '||SQLCODE||' '||SQLERRM;
	   END validate_alternate_bom;
/***************************************************************************************************
 * PROCEDURE BOM_VALIDATE
 * 
 * Description:
 * This Procedures validates the staging records for Bill of Materials
 * 
 *****************************************************************************************************/
PROCEDURE BOM_VALIDATE(P_I_RUN_MODE IN VARCHAR2) AS
  CURSOR cur_bom_stg IS
   SELECT ROWID,a.org_code,
				a.assembly_item_num,
				a.unit_of_measure,
				a.line_item_num,
				a.sub_comp_item_num,
				a.basis,
				a.supply_type,
				a.optional_flag,
				a.quantity,
				a.item_sequence_number,
				a.operation_sequence_number,
				a.yield_of_component,
				a.supply_subinventory,
				a.locator,
				a.alternate_bom,--SELECT COLUMNS 
				a.enforce_integer_quantity,
				a.include_in_cost_rollup	
	FROM customusr.xx_ossa_bom_conv_stg_tbl a
	WHERE a.hdr_process_flag = 'N'
	AND a.request_id = gn_conc_req_id
	;
  CURSOR cur_bom_err_stg IS
    SELECT *
	FROM customusr.xx_ossa_bom_conv_stg_tbl
	WHERE hdr_process_flag = 'VE'
	AND request_id = gn_conc_req_id
	;
    TYPE xx_bom_rec IS RECORD
		(
		ROWID UROWID,
		-- write all columns written in cur_bom_stg
		org_code					 customusr.xx_ossa_bom_conv_stg_tbl.org_code%TYPE,
		assembly_item_num            customusr.xx_ossa_bom_conv_stg_tbl.assembly_item_num%TYPE,
		unit_of_measure              customusr.xx_ossa_bom_conv_stg_tbl.unit_of_measure%TYPE,
		line_item_num                customusr.xx_ossa_bom_conv_stg_tbl.line_item_num%TYPE,
		sub_comp_item_num            customusr.xx_ossa_bom_conv_stg_tbl.sub_comp_item_num%TYPE,
		basis                        customusr.xx_ossa_bom_conv_stg_tbl.basis%TYPE,
		supply_type                  customusr.xx_ossa_bom_conv_stg_tbl.supply_type%TYPE,
		optional_flag                customusr.xx_ossa_bom_conv_stg_tbl.optional_flag%TYPE,
		quantity                     customusr.xx_ossa_bom_conv_stg_tbl.quantity%TYPE,
		item_sequence_number         customusr.xx_ossa_bom_conv_stg_tbl.item_sequence_number%TYPE,
		operation_sequence_number    customusr.xx_ossa_bom_conv_stg_tbl.operation_sequence_number%TYPE,
		yield_of_component           customusr.xx_ossa_bom_conv_stg_tbl.yield_of_component%TYPE,
		supply_subinventory          customusr.xx_ossa_bom_conv_stg_tbl.supply_subinventory%TYPE,
		locator                      customusr.xx_ossa_bom_conv_stg_tbl.locator%TYPE,
		alternate_bom                customusr.xx_ossa_bom_conv_stg_tbl.alternate_bom%TYPE,
		enforce_integer_quantity	 customusr.xx_ossa_bom_conv_stg_tbl.enforce_integer_quantity%TYPE,
		include_in_cost_rollup		 customusr.xx_ossa_bom_conv_stg_tbl.include_in_cost_rollup%TYPE
		);

	TYPE lt_bom IS TABLE OF xx_bom_rec;

	xx_bom_tbl lt_bom;


  ln_org_id apps.org_organization_definitions.organization_id%TYPE;
  lc_err_flag VARCHAR2(2) := 'N';
  lc_err_msg VARCHAR2(4000) := NULL;
  lc_err_flag1 VARCHAR2(2) := 'N';
  lc_err_msg1 VARCHAR2(4000) := NULL;
  lc_err_flag2 VARCHAR2(2) := 'N';
  lc_err_msg2 VARCHAR2(4000) := NULL;
  lc_err_flag3 VARCHAR2(2) := 'N';
  lc_err_msg3 VARCHAR2(4000) := NULL;
  lc_err_flag4 VARCHAR2(2) := 'N';
  lc_err_msg4 VARCHAR2(4000) := NULL;
  lc_err_flag5 VARCHAR2(2) := 'N';
  lc_err_msg5 VARCHAR2(4000) := NULL;
  lc_err_flag6 VARCHAR2(2) := 'N';
  lc_err_msg6 VARCHAR2(4000) := NULL;
  lc_err_flag7 VARCHAR2(2) := 'N';
  lc_err_msg7 VARCHAR2(4000) := NULL;
  lc_err_flag8 VARCHAR2(2) := 'N';
  lc_err_msg8 VARCHAR2(4000) := NULL;
  lc_err_flag9 VARCHAR2(2) := 'N';
  lc_err_msg9 VARCHAR2(4000) := NULL;
  lc_err_flag10 VARCHAR2(2) := 'N';
  lc_err_msg10 VARCHAR2(4000) := NULL;
  lc_err_flag11 VARCHAR2(2) := 'N';
  lc_err_msg11 VARCHAR2(4000) := NULL;
  lc_err_flag12 VARCHAR2(2) := 'N';
  lc_err_msg12 VARCHAR2(4000) := NULL;
  lc_bom_exist_flag VARCHAR2(2) := 'N';
  ln_ass_item_id apps.mtl_system_items_b.inventory_item_id%TYPE;
  ln_line_item_id apps.mtl_system_items_b.inventory_item_id%TYPE;
  lc_ora_subinv apps.mtl_secondary_inventories.secondary_inventory_name%TYPE;
  ln_mutually_exclusive NUMBER;
  lc_basis_type apps.mfg_lookups.lookup_code%TYPE;
  lc_supply_type apps.mfg_lookups.lookup_code%TYPE;
  ln_optional NUMBER;
  ln_tot_rec_count NUMBER;
  ln_succ_rec_cnt NUMBER := 0;
  ln_err_rec_cnt NUMBER := 0;
  lv_uom VARCHAR2(50) :=NULL;
  lv_item_rev VARCHAR2(50) :=NULL;
  lv_comp_rev VARCHAR2(50) :=NULL;
  ln_sub_comp_item_id NUMBER :=0;
  ln_locator_id NUMBER:= 0;
  ln_cost_rollup_code VARCHAR2(10) :=NULL;

  BEGIN
   ----------------------------------------------------
   -- add request id to new records
   ----------------------------------------------------
   UPDATE 	customusr.xx_ossa_bom_conv_stg_tbl
   SET 	request_id  = gn_conc_req_id
   WHERE 	hdr_process_flag = 'N';
   ----------------------------------------------------
   -- check for duplicates
   ----------------------------------------------------
   UPDATE customusr.xx_ossa_bom_conv_stg_tbl
   SET hdr_process_flag = 'VE'
     , hdr_error_msg = 'Duplicate record found'
   WHERE ROWID IN (SELECT ROWID
                FROM (SELECT ROWID, ROW_NUMBER () 
                      OVER (PARTITION BY assembly_item_num, org_code, line_item_num, operation_sequence_number, item_sequence_number, request_id  ORDER BY ROWID) AS ROW_NUMBER
                      FROM customusr.xx_ossa_bom_conv_stg_tbl)
                      WHERE ROW_NUMBER > 1); 
  COMMIT;
   ----------------------------------------------------
   -- other validations
   ----------------------------------------------------
	OPEN cur_bom_stg ;
	LOOP
	FETCH cur_bom_stg
	BULK COLLECT INTO xx_bom_tbl LIMIT 5000;
	EXIT WHEN xx_bom_tbl.COUNT = 0;
	FOR c_bom_rec IN 1 .. xx_bom_tbl.COUNT
	LOOP
     lc_err_flag := 'N';
     lc_err_msg := NULL;
     lc_err_flag1 := 'N';
     lc_err_msg1 := NULL;
     lc_err_flag2 := 'N';
     lc_err_msg2 := NULL;
     lc_err_flag3 := 'N';
     lc_err_msg3 := NULL;
     lc_err_flag4 := 'N';
     lc_err_msg4 := NULL;
     lc_err_flag5 := 'N';	
     lc_err_msg5 := NULL;
	 lc_err_flag6 := 'N';
     lc_err_msg6 := NULL;
	 lc_err_flag7 := 'N';
     lc_err_msg7 := NULL;
	 lc_err_flag8 := 'N';
     lc_err_msg8 := NULL;
	 lc_err_flag9 := 'N';
     lc_err_msg9 := NULL;
	 lc_err_flag10 := 'N';
     lc_err_msg10 := NULL;
	 lc_err_flag11 := 'N';
     lc_err_msg11 := NULL;
	 lc_err_flag12 := 'N';
     lc_err_msg12 := NULL;
     lc_bom_exist_flag := 'N';
     ln_org_id := NULL;
    -- ln_mutually_exclusive:= 2;
     ln_optional:= 2;
     ln_org_id:= NULL;
     ln_ass_item_id:= NULL;
     ln_line_item_id:= NULL;
     lc_basis_type := NULL;
     lc_supply_type := NULL;
	 lv_uom := NULL;
	 lv_item_rev:= NULL;
	 lv_comp_rev := NULL;
	 ln_sub_comp_item_id := NULL;
	 ln_locator_id := NULL;
	 ln_cost_rollup_code := NULL;
     IF xx_bom_tbl(c_bom_rec).org_code IS NULL THEN
		lc_err_flag := 'Y';
	   lc_err_msg := 'Organization Code cannot be blank in the data.';        
	 ELSE
	  validate_org(xx_bom_tbl(c_bom_rec).org_code, ln_org_id, lc_err_flag1, lc_err_msg1);	
	 IF xx_bom_tbl(c_bom_rec).assembly_item_num IS NOT NULL THEN
	   validate_item(xx_bom_tbl(c_bom_rec).assembly_item_num,ln_org_id, ln_ass_item_id, lc_err_msg2, lc_err_flag2);
	   IF lc_err_msg2 = ' - Invalid Item Number for Organization' THEN 
	   lc_err_msg2 := ' - Invalid Assembly Item Number for Organization';
	   END IF;
	   -- UOM derivation
	   /*IF xx_bom_tbl(c_bom_rec).unit_of_measure IS NULL AND lc_err_flag2 ='N' THEN
		validate_uom(ln_ass_item_id ,ln_org_id ,lv_uom ,lc_err_flag7,lc_err_msg7);
		END IF;*/
	 IF xx_bom_tbl(c_bom_rec).line_item_num IS NOT NULL THEN
	   validate_item(xx_bom_tbl(c_bom_rec).line_item_num,ln_org_id, ln_line_item_id, lc_err_msg3, lc_err_flag3);
		 IF lc_err_msg3 = ' - Invalid Item Number for Organization' THEN 
	   lc_err_msg3 := ' - Invalid Component Item Number for Organization';
	   END IF;
	 ELSE
	   lc_err_flag := 'Y';
	   lc_err_msg := lc_err_msg||' : '||'Component Item Number cannot be blank in the data.';
	 END IF;
	 IF xx_bom_tbl(c_bom_rec).sub_comp_item_num IS NOT NULL THEN
		validate_item(xx_bom_tbl(c_bom_rec).sub_comp_item_num,ln_org_id, ln_sub_comp_item_id, lc_err_msg9, lc_err_flag9);
			IF lc_err_msg9 = ' - Invalid Item Number for Organization' THEN 
			lc_err_msg9 := ' - Invalid Substitute Item Number for Organization';
			END IF;

		END IF;
	 IF xx_bom_tbl(c_bom_rec).basis IS NOT NULL THEN
	   validate_basis (xx_bom_tbl(c_bom_rec).basis,lc_basis_type,lc_err_flag4, lc_err_msg4);
	 ELSE
	   lc_err_flag := 'Y';
	   lc_err_msg := lc_err_msg||' : '||'Basis cannot be blank in the data.';
	 END IF;
	 IF xx_bom_tbl(c_bom_rec).supply_type IS NOT NULL THEN
	   validate_supply (xx_bom_tbl(c_bom_rec).supply_type,lc_supply_type,lc_err_flag5, lc_err_msg5);
	 END IF;

	 IF xx_bom_tbl(c_bom_rec).optional_flag IS NOT NULL THEN
	   IF UPPER(xx_bom_tbl(c_bom_rec).optional_flag) IN ('Y','YES','1') THEN
	     ln_optional := 1;
	   ELSE 
	     ln_optional := 2;
	   END IF;			
	  END IF;

	  IF xx_bom_tbl(c_bom_rec).quantity IS NULL OR xx_bom_tbl(c_bom_rec).quantity < 0  THEN
	    lc_err_msg := lc_err_msg ||' - QUANTITY cannot be NULL or Negative. ';
		lc_err_flag := 'Y';
	  END IF;
	  IF xx_bom_tbl(c_bom_rec).item_sequence_number IS NULL THEN
	    lc_err_msg := lc_err_msg ||' - item sequence number cannot be NULL. ';
		lc_err_flag := 'Y';
	  END IF;
	  IF xx_bom_tbl(c_bom_rec).operation_sequence_number IS NULL THEN
	    lc_err_msg := lc_err_msg ||' - operation sequence number cannot be NULL. ';
		lc_err_flag := 'Y';
	  else 
		validate_op_seq (xx_bom_tbl(c_bom_rec).operation_sequence_number,ln_org_id,ln_ass_item_id,lc_err_flag6, lc_err_msg6);
	  END IF;

	  IF xx_bom_tbl(c_bom_rec).yield_of_component IS NULL THEN
	    lc_err_msg := lc_err_msg ||' - Yield of component cannot be NULL. ';
		lc_err_flag := 'Y';
	  END IF;

	IF xx_bom_tbl(c_bom_rec).supply_subinventory IS NOT NULL THEN
	    validate_sub_inventory(xx_bom_tbl(c_bom_rec).supply_subinventory,ln_org_id, lc_err_flag7, lc_err_msg7);
	  END IF;	  
	  IF xx_bom_tbl(c_bom_rec).locator IS NOT NULL THEN
	    validate_locator(xx_bom_tbl(c_bom_rec).locator,ln_org_id, ln_locator_id, xx_bom_tbl(c_bom_rec).supply_subinventory, lc_err_flag8, lc_err_msg8);
		  END IF;
	  IF xx_bom_tbl(c_bom_rec).enforce_integer_quantity IS NOT NULL THEN
	   IF xx_bom_tbl(c_bom_rec).enforce_integer_quantity NOT IN ('None','Up','Down') THEN
	    lc_err_flag := 'Y';
		lc_err_msg := lc_err_msg||' : '||'enforce integer quantity is invalid';
	   END IF;			
	  END IF;
	  IF xx_bom_tbl(c_bom_rec).include_in_cost_rollup IS NOT NULL THEN
	   IF UPPER(xx_bom_tbl(c_bom_rec).include_in_cost_rollup) = 'YES' THEN
	     ln_cost_rollup_code := 1;
	   ELSE 
	     ln_cost_rollup_code := 2;
	   END IF;			
	   ELSE 
	   lc_err_msg := lc_err_msg||' : '||'Include cost rollup cannot be blank in the data.';
	  END IF;
	   IF xx_bom_tbl(c_bom_rec).alternate_bom IS NOT NULL THEN
	    validate_alternate_bom(xx_bom_tbl(c_bom_rec).alternate_bom,ln_org_id, lc_err_msg10, lc_err_flag10);
	  END IF;
	  ELSE
	   lc_err_flag := 'Y';
	   lc_err_msg := lc_err_msg||' : '||'Assembly Item Number cannot be blank in the data.';
	 END IF;
	 END IF;
	  IF (lc_err_flag = 'N' AND lc_err_flag1 = 'N' AND lc_err_flag2 = 'N' AND lc_err_flag3 = 'N'
	      AND lc_err_flag4 = 'N' AND lc_err_flag5 = 'N' AND lc_err_flag6 = 'N' AND lc_err_flag7 = 'N' AND lc_err_flag8 = 'N' AND lc_err_flag9 = 'N' AND lc_err_flag10 = 'N') THEN
		  UPDATE customusr.xx_ossa_bom_conv_stg_tbl
		  SET hdr_process_flag = 'V'
		   ,org_id = ln_org_id
		   ,assembly_item_id = ln_ass_item_id
		   ,line_item_id = ln_line_item_id
		   ,basis_type = lc_basis_type
		   ,wip_supply_type = lc_supply_type
		   ,optional = ln_optional
		   ,unit_of_measure = nvl(lv_uom,xx_bom_tbl(c_bom_rec).unit_of_measure)
		   ,bom_revision = lv_item_rev
		   ,comp_revision = lv_comp_rev
		   ,sub_comp_item_id = ln_sub_comp_item_id
		   ,locator_id = ln_locator_id
		   ,include_in_cost_rollup_code = ln_cost_rollup_code
		WHERE request_id  = gn_conc_req_id
    AND ROWID = xx_bom_tbl(c_bom_rec).ROWID
    ;
	IF P_I_RUN_MODE <> 'CONVERSION' THEN
	    ----------------------------------------------------
   -- check if bom exists
   ----------------------------------------------------
		   UPDATE customusr.xx_ossa_bom_conv_stg_tbl xbct
		   SET hdr_process_flag = 'U'
		  WHERE xbct.hdr_process_flag = 'V'
		  AND 	xbct.request_id = gn_conc_req_id
		  AND EXISTS (SELECT 'Y' 
				 FROM 	apps.bom_bill_of_materials bbom
				 WHERE bbom.assembly_item_id = ln_ass_item_id
				 AND bbom.organization_id = ln_org_id)
			AND NOT EXISTS 
				(SELECT 'Y' 
				 FROM apps.bom_bill_of_materials bbom,
					  apps.bom_inventory_components bic
				 WHERE bbom.assembly_item_id = ln_ass_item_id
			  AND bbom.organization_id = ln_org_id
			  AND bbom.bill_sequence_id = bic.bill_sequence_id
			  AND bic.COMPONENT_ITEM_ID= ln_line_item_id
			 )
   ;
    ----------------------------------------------------
   -- check if bom and its components also exists
   ----------------------------------------------------
		   UPDATE customusr.xx_ossa_bom_conv_stg_tbl xbct
		   SET hdr_process_flag = 'UE'
			 , hdr_error_msg = 'BOM Already Exists For the Combination of assembly item and component'
			  WHERE xbct.hdr_process_flag = 'V'
			  AND 	xbct.request_id = gn_conc_req_id
			  AND  EXISTS 
			(SELECT 'Y' 
			 FROM 	apps.bom_bill_of_materials bbom,
                apps.bom_inventory_components bic
			 WHERE bbom.assembly_item_id = ln_ass_item_id
			  AND bbom.organization_id = ln_org_id
			  AND bbom.bill_sequence_id = bic.bill_sequence_id
			  AND bic.COMPONENT_ITEM_ID= ln_line_item_id
			 )

   ;
   END IF;
	--COMMIT;
	  ELSE
	    --ln_err_rec_cnt := ln_err_rec_cnt + 1;
		lc_err_msg := lc_err_msg||':'||lc_err_msg1||':'||lc_err_msg2||':'
		            ||lc_err_msg3||':'||lc_err_msg4||':'||lc_err_msg5||':'||lc_err_msg6||':'
		            ||lc_err_msg7||':'||lc_err_msg8||':'||lc_err_msg9||':'||lc_err_msg10;
		UPDATE customusr.xx_ossa_bom_conv_stg_tbl
		SET hdr_process_flag = 'VE'
		   ,hdr_error_msg = lc_err_msg
		WHERE request_id  = gn_conc_req_id
		AND ROWID = xx_bom_tbl(c_bom_rec).ROWID
		;
		gn_ret_code := 1;
		--COMMIT;
	  END IF;
   END LOOP;
   COMMIT;
   END LOOP;
   CLOSE cur_bom_stg;


   -------------------------------------
	UPDATE customusr.xx_ossa_bom_conv_stg_tbl stg
	SET hdr_process_flag = 'VE'
	   ,hdr_error_msg = 'One of the records for the BOM has errored out'
	WHERE request_id  = gn_conc_req_id
	AND hdr_process_flag = 'V'
	AND (org_code,assembly_item_num) in ( Select distinct org_code,assembly_item_num 
										  from customusr.xx_ossa_bom_conv_stg_tbl 
										  where  request_id  = gn_conc_req_id 
										  AND hdr_process_flag = 'VE'
										  AND hdr_error_msg <> 'Duplicate record found'
										)    
   ;
   COMMIT;

   IF P_I_RUN_MODE = 'CONVERSION' THEN
   UPDATE customusr.xx_ossa_bom_conv_stg_tbl xbct
	SET hdr_process_flag = 'VE'
	   ,hdr_error_msg = 'BOM Already Exists'
	WHERE request_id  = gn_conc_req_id
	AND hdr_process_flag = 'V'
	AND EXISTS (SELECT 'Y' 
			 FROM 	apps.bom_bill_of_materials bbom
			 WHERE bbom.assembly_item_id = xbct.assembly_item_id
			 AND bbom.organization_id = xbct.org_id);
	END IF;		 
   BEGIN
   SELECT COUNT(1)
   INTO ln_tot_rec_count
   FROM customusr.xx_ossa_bom_conv_stg_tbl
   WHERE request_id  = gn_conc_req_id
   ;
   EXCEPTION
    WHEN OTHERS THEN
  FND_LOG('Problem IN TOTAL COUNT .');
  END;
  BEGIN
   SELECT COUNT(1)
   INTO ln_succ_rec_cnt
   FROM customusr.xx_ossa_bom_conv_stg_tbl
   WHERE request_id  = gn_conc_req_id
   AND hdr_process_flag = 'V'
   ;
    EXCEPTION
    WHEN OTHERS THEN
  FND_LOG('Problem IN TOTAL COUNT .');
  END;
   ln_err_rec_cnt :=  ln_tot_rec_count - ln_succ_rec_cnt;

					FND_OUT( '****************************************************************');
					FND_OUT( '                 BOM VALIDATE Summary                          ');
	  apps.xx_comn_pers_util_pkg.FND_OUT( '================================================================');
	  apps.xx_comn_pers_util_pkg.FND_OUT('  ');
	  apps.xx_comn_pers_util_pkg.FND_OUT('  ');
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Program Name ',55)||': '||gv_conc_prog_name);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Request ID ',55)||':'||gn_conc_req_id);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('User Name ',55)||': '||gv_user_name);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Requested Date ',55)||': '||gd_conc_prog_date);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Completion Date ',55)||': '||SYSDATE);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no of record validated ',55)||': '||ln_tot_rec_count);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no records validated successfuly ',55)||': '||ln_succ_rec_cnt);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no records errored validation ',55)||': '||ln_err_rec_cnt );
	  IF ln_err_rec_cnt > 0 THEN
		   apps.xx_comn_pers_util_pkg.FND_LOG('For error details please refer to the log file');
		   apps.xx_comn_pers_util_pkg.FND_LOG('****************************************************************');
		 apps.xx_comn_pers_util_pkg.FND_LOG('               Validation Error Details                         ');
		 apps.xx_comn_pers_util_pkg.FND_LOG('****************************************************************');
		   apps.xx_comn_pers_util_pkg.FND_LOG(' ');
		   apps.xx_comn_pers_util_pkg.FND_LOG(' ');
		   apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent program name ', 55)||': '||gv_conc_prog_name);
		 apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent Request ID ',55)||':'||gn_conc_req_id);
		 apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('User Name ',55)||': '||gv_user_name);
		   apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Requested Date ',55)||': '||gd_conc_prog_date);
		 apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Completion Date ',55)||': '||SYSDATE);
		   apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Table Name ', 55)||': '||  'customusr.xx_ossa_bom_conv_stg_tbl'    );
		   apps.xx_comn_pers_util_pkg.FND_LOG(' ');
		   apps.xx_comn_pers_util_pkg.FND_LOG(' ');
		   apps.xx_comn_pers_util_pkg.FND_LOG('Org Code,Assembly Item Number,Component Item Number, Operation Sequence, Item Sequence Number, Quantity, Supply Type, Subinventory, Locator, Substitute Item Number, Error Message ');
		   FOR l_rec_err IN cur_bom_err_stg LOOP
			 apps.xx_comn_pers_util_pkg.FND_LOG(l_rec_err.org_code||','||l_rec_err.assembly_item_num||','||l_rec_err.line_item_num||','||l_rec_err.operation_sequence_number||','||l_rec_err.item_sequence_number||','||l_rec_err.quantity||','||l_rec_err.supply_type||','||l_rec_err.supply_subinventory||','||l_rec_err.locator||','||l_rec_err.sub_comp_item_num||','||l_rec_err.hdr_error_msg
			 );
			 END LOOP;
		 END IF;

  EXCEPTION 
  WHEN OTHERS THEN
  FND_LOG('Problem executing validate procedure.');
  FND_LOG('Error Details : '||SQLERRM);
  gn_ret_code := 2;
	apps.xx_comn_conv_debug_prc ( p_i_level =>NULL,
						p_i_proc_name => 'BOM Conversion',
						p_i_phase => 'BOM_VALIDATE',
						p_i_stgtable => 'xx_ossa_bom_conv_stg_tbl' ,
						p_i_message => 'Error while Validating records'||SQLCODE||SQLERRM);
  END bom_validate;
/***************************************************************************************************
 * PROCEDURE BOM_CREATE
 * 
 * Description:
 * This Procedures Calls the API to create On Hand Inventory in Oracle system.
 *
 ****************************************************************************************************/
PROCEDURE bom_create AS

	CURSOR cur_new_bom IS
      SELECT xbct.org_code
			,xbct.assembly_item_num
			,xbct.alternate_bom
	  FROM 	customusr.xx_ossa_bom_conv_stg_tbl xbct
	  WHERE xbct.hdr_process_flag = 'V'
	  AND 	xbct.request_id = gn_conc_req_id
	  AND NOT EXISTS 
			(SELECT 'Y' 
			 FROM 	apps.bom_bill_of_materials bbom
			 WHERE bbom.assembly_item_id = xbct.assembly_item_id
			 AND bbom.organization_id = xbct.org_id
			 )
	  GROUP BY xbct.assembly_item_num,xbct.org_code,xbct.alternate_bom
	  ;
	CURSOR cur_bom_comp(p_org_code VARCHAR2
	                   ,p_assembly_item_num VARCHAR2) IS
      SELECT org_code,					
	         assembly_item_num,           
	         line_item_num,               
	         BASIS_TYPE,
	         wip_supply_type,
	         optional,
	         quantity,
	         item_sequence_number,
	         operation_sequence_number,
	         yield_of_component,
	         supply_subinventory,
	         locator,
	         alternate_bom,
	         sub_comp_item_num,
	         sub_comp_quantity,
			 enforce_integer_quantity,
			 include_in_cost_rollup_code	
	  FROM 	customusr.xx_ossa_bom_conv_stg_tbl stg
	  WHERE hdr_process_flag = 'V'
	  AND 	request_id = gn_conc_req_id
	  AND 	assembly_item_num = p_assembly_item_num
	  AND 	org_code = p_org_code
	  ;

	/*CURSOR cur_ext_bom IS
      SELECT xbct.assembly_item_num
          ,xbct.assembly_item_id
         	,xbct.org_code
          ,xbct.org_id
	  FROM 	customusr.xx_ossa_bom_conv_stg_tbl xbct
	  WHERE xbct.hdr_process_flag = 'V'
	  AND 	xbct.request_id = gn_conc_req_id
	  AND EXISTS 
			(SELECT 'Y' 
			 FROM 	apps.bom_bill_of_materials bbom
			 WHERE bbom.assembly_item_id = xbct.assembly_item_id
			 AND bbom.organization_id = xbct.org_id
			 )
	  GROUP BY xbct.assembly_item_id,xbct.assembly_item_num,xbct.org_code,xbct.org_id
	  ;*/
	CURSOR cur_bom_err_stg IS
      SELECT *
	  FROM customusr.xx_ossa_bom_conv_stg_tbl
	  WHERE hdr_process_flag = 'E'
	  AND request_id = gn_conc_req_id
	  ;
	ln_request_id NUMBER:=0;
	ln_batch_id NUMBER;
	lv_Err_Flag VARCHAR2(2);
	LV_ERR_MSG VARCHAr2(4000);
	ln_hdr_rec_count NUMBER :=0;
	ln_hdr_err_count NUMBER :=0;
	ln_hdr_success_count NUMBER :=0;
	ln_hdr_dup_count NUMBER :=0;
	ln_lin_rec_count NUMBER :=0;
	ln_lin_err_count NUMBER :=0;
	ln_lin_success_count NUMBER :=0;
	ln_lin_dup_count NUMBER :=0;
	lb_req_return_status BOOLEAN;
	ln_rec_count NUMBER :=0;
	ln_err_count NUMBER :=0;
	ln_success_count NUMBER :=0;

	-- API input variables
	l_bom_header_rec              apps.Bom_Bo_Pub.bom_head_rec_type                := apps.Bom_Bo_Pub.g_miss_bom_header_rec;
	l_bom_revision_tbl            apps.Bom_Bo_Pub.bom_revision_tbl_type            := apps.Bom_Bo_Pub.g_miss_bom_revision_tbl;
	l_bom_component_tbl           apps.Bom_Bo_Pub.bom_comps_tbl_type               := apps.Bom_Bo_Pub.g_miss_bom_component_tbl;
	l_bom_ref_designator_tbl      apps.Bom_Bo_Pub.bom_ref_designator_tbl_type      := apps.Bom_Bo_Pub.g_miss_bom_ref_designator_tbl;
	l_bom_sub_component_tbl       apps.Bom_Bo_Pub.bom_sub_component_tbl_type       := apps.Bom_Bo_Pub.g_miss_bom_sub_component_tbl;
	-- API output variables
	l_o_bom_header_rec              apps.Bom_Bo_Pub.bom_head_rec_type                := apps.Bom_Bo_Pub.g_miss_bom_header_rec;
	l_o_bom_revision_tbl            apps.Bom_Bo_Pub.bom_revision_tbl_type            := apps.Bom_Bo_Pub.g_miss_bom_revision_tbl;
	l_o_bom_component_tbl           apps.Bom_Bo_Pub.bom_comps_tbl_type               := apps.Bom_Bo_Pub.g_miss_bom_component_tbl;
	l_o_bom_ref_designator_tbl      apps.Bom_Bo_Pub.bom_ref_designator_tbl_type      := apps.Bom_Bo_Pub.g_miss_bom_ref_designator_tbl;
	l_o_bom_sub_component_tbl       apps.Bom_Bo_Pub.bom_sub_component_tbl_type       := apps.Bom_Bo_Pub.g_miss_bom_sub_component_tbl;
	l_o_message_list                apps.Error_Handler.Error_Tbl_Type;
	l_error_table           apps.Error_Handler.Error_Tbl_Type;        
	l_output_dir            VARCHAR2(500) :=  '/usr/tmp';
	l_debug_filename        VARCHAR2(60) :=  'bom_debug_08_16.dbg';
	lv_return_status         VARCHAR2(1) := NULL;
	ln_msg_count             NUMBER      := 0;
	ln_cnt                   NUMBER      := 1;
	ln_comp_exist   NUMBER;
	ln_start_seq_num   NUMBER := 0; 
	ln_tot_rec_count NUMBER;
    ln_succ_rec_cnt NUMBER := 0;
    ln_err_rec_cnt NUMBER := 0;
	lv_api_error  VARCHAr2(4000);
	BEGIN
	----------------------------------------------------
	-- add request id to Validated records
	----------------------------------------------------

    UPDATE  customusr.xx_ossa_bom_conv_stg_tbl k
    SET     request_id  = gn_conc_req_id,
			TRX_TYPE = 'CONVERSION'
    WHERE   hdr_process_flag in ('V')    
	;
	COMMIT;
	OPEN cur_new_bom ;
	LOOP
	FETCH cur_new_bom
	BULK COLLECT INTO gn_bom_tbl LIMIT 10000;
	EXIT WHEN gn_bom_tbl.COUNT = 0;

	FOR c_new_bom_rec IN 1 .. gn_bom_tbl.COUNT
	LOOP
	l_bom_header_rec         		:= apps.Bom_Bo_Pub.g_miss_bom_header_rec;
	l_bom_revision_tbl              := apps.Bom_Bo_Pub.g_miss_bom_revision_tbl;
	l_bom_component_tbl             := apps.Bom_Bo_Pub.g_miss_bom_component_tbl;
	l_bom_ref_designator_tbl        := apps.Bom_Bo_Pub.g_miss_bom_ref_designator_tbl;
	l_bom_sub_component_tbl         := apps.Bom_Bo_Pub.g_miss_bom_sub_component_tbl;


	 --L_BOM_HEADER_REC.delete;
    L_BOM_HEADER_REC:= NULL;
	lv_api_error := NULL;
    l_bom_component_tbl.DELETE;
    ln_rec_count:= ln_rec_count +1;
	  -- initialize BOM header
      lv_return_status := NULL;
      l_bom_header_rec.assembly_item_name := gn_bom_tbl(c_new_bom_rec).assembly_item_num;
      l_bom_header_rec.organization_code  := gn_bom_tbl(c_new_bom_rec).org_code; 
      l_bom_header_rec.assembly_type      := 1;
      l_bom_header_rec.transaction_type   := 'CREATE';
      l_bom_header_rec.return_status      := NULL;                   	
      l_bom_header_rec.alternate_bom_code := gn_bom_tbl(c_new_bom_rec).ALTERNATE_BOM;  -- For creating alternate bills


	  ln_cnt := 0;
	  OPEN cur_bom_comp(gn_bom_tbl(c_new_bom_rec).org_code,gn_bom_tbl(c_new_bom_rec).assembly_item_num) ;
		LOOP
		FETCH cur_bom_comp
		BULK COLLECT INTO gn_bom_comp_tbl LIMIT 10000;
		EXIT WHEN gn_bom_comp_tbl.COUNT = 0;

	FOR c_bom_comp_rec IN 1 .. gn_bom_comp_tbl.COUNT
	LOOP

		ln_cnt := ln_cnt + 1;
		l_bom_component_tbl (ln_cnt).organization_code 				:= gn_bom_comp_tbl(c_bom_comp_rec).org_code;
		l_bom_component_tbl (ln_cnt).assembly_item_name 			:= gn_bom_comp_tbl(c_bom_comp_rec).assembly_item_num;
		l_bom_component_tbl (ln_cnt).start_effective_date 			:=  SYSDATE; -- to_date('16-JUL-2010 19:30:39','DD-MON-YY HH24:MI:SS'); -- should match timestamp for UPDATE
		l_bom_component_tbl (ln_cnt).component_item_name			:=  gn_bom_comp_tbl(c_bom_comp_rec).line_item_num;
		l_bom_component_tbl (ln_cnt).alternate_bom_code 			:= gn_bom_comp_tbl(c_bom_comp_rec).ALTERNATE_BOM;   -- For creating alternate bills
		l_bom_component_tbl (ln_cnt).supply_subinventory 			:= apps.xx_comn_conv_util_pkg.xx_comn_conv_subinv_fnc(gn_bom_comp_tbl(c_bom_comp_rec).supply_subinventory);
		l_bom_component_tbl (ln_cnt).location_name 					:= gn_bom_comp_tbl(c_bom_comp_rec).locator;
		--l_bom_component_tbl (ln_cnt).comments 					:= gn_bom_comp_tbl(c_bom_comp_rec).comments;
		l_bom_component_tbl (ln_cnt).item_sequence_number 			:= gn_bom_comp_tbl(c_bom_comp_rec).item_sequence_number ;
		l_bom_component_tbl (ln_cnt).operation_sequence_number 		:= gn_bom_comp_tbl(c_bom_comp_rec).operation_sequence_number;
		l_bom_component_tbl (ln_cnt).transaction_type 				:= 'CREATE';
		l_bom_component_tbl (ln_cnt).quantity_per_assembly 			:=  gn_bom_comp_tbl(c_bom_comp_rec).quantity;
		l_bom_component_tbl (ln_cnt).return_status 					:= NULL;
		l_bom_component_tbl (ln_cnt).Projected_Yield 				:= gn_bom_comp_tbl(c_bom_comp_rec).yield_of_component;
		l_bom_component_tbl (ln_cnt).wip_supply_type 				:= gn_bom_comp_tbl(c_bom_comp_rec).wip_supply_type;
		--l_bom_component_tbl (ln_cnt).mutually_exclusive 			:= gn_bom_comp_tbl(c_bom_comp_rec).mutually_exclusive;
		L_BOM_COMPONENT_TBL (LN_CNT).OPTIONAL 						:= gn_bom_comp_tbl(c_bom_comp_rec).OPTIONAL;
		l_bom_component_tbl (ln_cnt).Include_In_Cost_Rollup 		:= gn_bom_comp_tbl(c_bom_comp_rec).include_in_cost_rollup_code;
		l_bom_component_tbl (ln_cnt).Enforce_Int_Requirements 		:= gn_bom_comp_tbl(c_bom_comp_rec).enforce_integer_quantity;
		--L_BOM_COMPONENT_TBL (LN_CNT).New_revised_Item_Revision 		:= gn_bom_comp_tbl(c_bom_comp_rec).comp_revision;
			IF gn_bom_comp_tbl(c_bom_comp_rec).BASIS_TYPE = 1 THEN	
			L_BOM_COMPONENT_TBL (LN_CNT).BASIS_TYPE 						:= null;
			ELSE
			L_BOM_COMPONENT_TBL (LN_CNT).BASIS_TYPE := gn_bom_comp_tbl(c_bom_comp_rec).BASIS_TYPE;	
			END IF;
		-- IF gn_bom_comp_tbl(c_bom_comp_rec).sub_comp_item_num IS NOT NULL THEN
		  l_bom_sub_component_tbl(ln_cnt).organization_code         	:=  gn_bom_comp_tbl(c_bom_comp_rec).org_code;
          l_bom_sub_component_tbl(ln_cnt).assembly_item_name        	:=  TRIM(gn_bom_comp_tbl(c_bom_comp_rec).assembly_item_num);       
          l_bom_sub_component_tbl(ln_cnt).start_effective_date      	:=  sysdate; 
          l_bom_sub_component_tbl(ln_cnt).alternate_bom_code        	:=  gn_bom_comp_tbl(c_bom_comp_rec).ALTERNATE_BOM;   -- For alternate bills -- NULL = FND_API.G_MISS_CHAR;
          l_bom_sub_component_tbl(ln_cnt).operation_sequence_number 	:=  gn_bom_comp_tbl(c_bom_comp_rec).operation_sequence_number;
          l_bom_sub_component_tbl(ln_cnt).component_item_name       	:=  TRIM(gn_bom_comp_tbl(c_bom_comp_rec).line_item_num);
		  l_bom_sub_component_tbl(ln_cnt).substitute_component_name 	:=  TRIM(gn_bom_comp_tbl(c_bom_comp_rec).sub_comp_item_num);
          l_bom_sub_component_tbl(ln_cnt).substitute_item_quantity  	:=  gn_bom_comp_tbl(c_bom_comp_rec).sub_comp_quantity;
          l_bom_sub_component_tbl(ln_cnt).transaction_type          	:=  'CREATE';
          l_bom_sub_component_tbl(ln_cnt).Return_Status             	:=  NULL;
		  --END IF;

	  END LOOP;	
	  END LOOP;
	CLOSE cur_bom_comp;



	  -- initialize error stack for logging errors
      apps.Error_Handler.initialize;
		apps.xx_comn_pers_util_pkg.xx_process_bom_prc('BOM',
									1.0,
									'TRUE',
									l_bom_header_rec,
									l_bom_revision_tbl,
									l_bom_component_tbl,
									l_bom_ref_designator_tbl,
									l_bom_sub_component_tbl,
									l_o_bom_header_rec,
									l_o_bom_revision_tbl,
									l_o_bom_component_tbl,
									l_o_bom_ref_designator_tbl,
									l_o_bom_sub_component_tbl,
									lv_return_status,
									ln_msg_count    ,
									'N',
									gn_user_id,
									gn_resp_id,
									gn_resp_appL_ID
                              --,p_write_err_to_conclog    	=> 'Y'
                              );
	  IF (lv_return_status = apps.fnd_api.g_ret_sts_success) THEN
	    ln_success_count := ln_success_count + 1;
		UPDATE 	customusr.xx_ossa_bom_conv_stg_tbl
		SET hdr_process_flag = 'S'
		WHERE 	request_id  = gn_conc_req_id
		AND 	assembly_item_num = gn_bom_tbl(c_new_bom_rec).assembly_item_num
		AND     org_code = gn_bom_tbl(c_new_bom_rec).org_code
		; 
	  ELSE 
		ln_err_count := ln_err_count + 1;
		apps.error_handler.get_message_list(x_message_list => l_error_table);
		fnd_log('BOM create API has returned error.');
        fnd_log('Assembly Item Number:'||gn_bom_tbl(c_new_bom_rec).assembly_item_num);
		fnd_log('Error Message Count :'||l_error_table.COUNT);
        FOR i IN 1..l_error_table.COUNT 
		LOOP
          fnd_log(to_char(i)||':'||l_error_table(i).entity_index||':'||l_error_table(i).table_name);
          fnd_log(to_char(i)||':'||l_error_table(i).message_text);
		  --lv_api_error : = lv_api_error || l_error_table(i).message_text;
        END LOOP; 
		UPDATE 	customusr.xx_ossa_bom_conv_stg_tbl
		SET 	hdr_process_flag = 'E'
		       ,hdr_error_msg = 'BOM create API has returned error. Please refer log file '--|| lv_api_error
		WHERE 	request_id  = gn_conc_req_id
		AND 	assembly_item_num = gn_bom_tbl(c_new_bom_rec).assembly_item_num
		AND     org_code = gn_bom_tbl(c_new_bom_rec).org_code
		;
		gn_ret_code := 1;
	  END IF;

	END LOOP;
	COMMIT;
	END LOOP;
	CLOSE cur_new_bom;

    SELECT COUNT(1)
    INTO ln_succ_rec_cnt
    FROM customusr.xx_ossa_bom_conv_stg_tbl
    WHERE request_id  = gn_conc_req_id
    AND hdr_process_flag = 'S'
    ;
	SELECT COUNT(1)
    INTO ln_err_rec_cnt
    FROM customusr.xx_ossa_bom_conv_stg_tbl
    WHERE request_id  = gn_conc_req_id
    AND hdr_process_flag = 'E'
    ;

	--------------------------------------------------------------------------------
	--Summary report
	--------------------------------------------------------------------------------
	FND_OUT( '****************************************************************');
					FND_OUT( '                 BOM IMPORT Summary                          ');
	  apps.xx_comn_pers_util_pkg.FND_OUT( '================================================================');
	  apps.xx_comn_pers_util_pkg.FND_OUT('  ');
	  apps.xx_comn_pers_util_pkg.FND_OUT('  ');
		apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Program Name ',55)||': '||gv_conc_prog_name);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Request ID ',55)||':'||gn_conc_req_id);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('User Name ',55)||': '||gv_user_name);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Requested Date ',55)||': '||gd_conc_prog_date);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Completion Date ',55)||': '||SYSDATE);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no records Imported successfuly ',55)||': '||ln_succ_rec_cnt);
	  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no records errored validation ',55)||': '||ln_err_rec_cnt );
	IF ln_err_rec_cnt <> 0 THEN	
	  FND_LOG('Error Details : ');
      FND_LOG('Assembly Item Number,Organization_Code,Component,Item Sequence,Operation Sequence,Quantity,Basis,Supply Type,Subinventory,Locator,Optional Flag,Error Message');	
	  FOR c_err_rec in cur_bom_err_stg 
	  LOOP
	    FND_LOG(c_err_rec.assembly_item_num||','||c_err_rec.org_code||','||c_err_rec.line_item_num||','||c_err_rec.item_sequence_number||','||
		c_err_rec.operation_sequence_number||','||c_err_rec.quantity||','||
              c_err_rec.basis||','||c_err_rec.supply_type||','||c_err_rec.supply_subinventory||','||
              c_err_rec.locator||','||c_err_rec.optional_flag||','||c_err_rec.hdr_error_msg
			   );
	  END LOOP;
    END IF;
	EXCEPTION 
	WHEN OTHERS THEN
	gn_ret_code := 2;
	  FND_LOG('Problem executing import procedure.');
      FND_LOG('Error Details : '||SQLERRM);
      apps.xx_comn_conv_debug_prc ( p_i_level =>NULL,
							p_i_proc_name => 'BOM Conversion',
							p_i_phase => 'BOM_CREATE',
							p_i_stgtable => 'xx_ossa_bom_conv_stg_tbl' ,
							p_i_message => 'Error while Creating records'||SQLCODE||SQLERRM);
	END bom_create;
/***************************************************************************************************
 * PROCEDURE BOM_UPDATE
 * 
 * Description:
 * This Procedures Calls the API to update BOM in Oracle system.
 *
 ****************************************************************************************************/
PROCEDURE bom_update AS

	CURSOR cur_update_bom IS
      SELECT xbct.org_code
			,xbct.assembly_item_num
			,xbct.alternate_bom
	  FROM 	customusr.xx_ossa_bom_conv_stg_tbl xbct
	  WHERE xbct.hdr_process_flag IN ('U','UE')
	  AND 	xbct.request_id = gn_conc_req_id
	  GROUP BY xbct.assembly_item_num,xbct.org_code,xbct.alternate_bom;

	  CURSOR cur_create_bom_comp(p_org_code VARCHAR2
	                   ,p_assembly_item_num VARCHAR2) IS
      SELECT org_code,					
	         assembly_item_num,           
	         line_item_num,               
	         BASIS_TYPE,
	         wip_supply_type,
	         optional,
	         quantity,
	         item_sequence_number,
	         operation_sequence_number,
	         yield_of_component,
	         supply_subinventory,
	         locator,
	         alternate_bom,
	         sub_comp_item_num,
	         sub_comp_quantity,
			 enforce_integer_quantity,
			 include_in_cost_rollup_code	
	  FROM 	customusr.xx_ossa_bom_conv_stg_tbl stg
	  WHERE hdr_process_flag = 'U'
	  AND 	request_id = gn_conc_req_id
	  AND 	assembly_item_num = p_assembly_item_num
	  AND 	org_code = p_org_code
	  ;
	CURSOR cur_update_bom_comp(p_org_code VARCHAR2
	                   ,p_assembly_item_num VARCHAR2) IS
     SELECT org_code,					
	         assembly_item_num,           
	         line_item_num,               
	         BASIS_TYPE,
	         wip_supply_type,
	         optional,
	         quantity,
	         item_sequence_number,
	         operation_sequence_number,
	         yield_of_component,
	         supply_subinventory,
	         locator,
	         alternate_bom,
	         sub_comp_item_num,
	         sub_comp_quantity,
			 enforce_integer_quantity,
			 include_in_cost_rollup_code	  	  
	  FROM 	customusr.xx_ossa_bom_conv_stg_tbl stg
	  WHERE hdr_process_flag = 'UE'
	  AND 	request_id = gn_conc_req_id
	  AND 	assembly_item_num = p_assembly_item_num
	  AND 	org_code = p_org_code
	  ;
	CURSOR cur_bom_err_stg IS
      SELECT *
	  FROM customusr.xx_ossa_bom_conv_stg_tbl
	  WHERE hdr_process_flag = 'E'
	  AND request_id = gn_conc_req_id
	  ;
	ln_request_id NUMBER:=0;
	ln_batch_id NUMBER;
	lv_Err_Flag VARCHAR2(2);
	LV_ERR_MSG VARCHAr2(4000);
	ln_hdr_rec_count NUMBER :=0;
	ln_hdr_err_count NUMBER :=0;
	ln_hdr_success_count NUMBER :=0;
	ln_hdr_dup_count NUMBER :=0;
	ln_lin_rec_count NUMBER :=0;
	ln_lin_err_count NUMBER :=0;
	ln_lin_success_count NUMBER :=0;
	ln_lin_dup_count NUMBER :=0;
	lb_req_return_status BOOLEAN;
	ln_rec_count NUMBER :=0;
	ln_err_count NUMBER :=0;
	ln_success_count NUMBER :=0;

	-- API input variables
	l_bom_header_rec              apps.Bom_Bo_Pub.bom_head_rec_type                := apps.Bom_Bo_Pub.g_miss_bom_header_rec;
	l_bom_revision_tbl            apps.Bom_Bo_Pub.bom_revision_tbl_type            := apps.Bom_Bo_Pub.g_miss_bom_revision_tbl;
	l_bom_component_tbl           apps.Bom_Bo_Pub.bom_comps_tbl_type               := apps.Bom_Bo_Pub.g_miss_bom_component_tbl;
	l_bom_ref_designator_tbl      apps.Bom_Bo_Pub.bom_ref_designator_tbl_type      := apps.Bom_Bo_Pub.g_miss_bom_ref_designator_tbl;
	l_bom_sub_component_tbl       apps.Bom_Bo_Pub.bom_sub_component_tbl_type       := apps.Bom_Bo_Pub.g_miss_bom_sub_component_tbl;
	-- API output variables
	l_o_bom_header_rec              apps.Bom_Bo_Pub.bom_head_rec_type                := apps.Bom_Bo_Pub.g_miss_bom_header_rec;
	l_o_bom_revision_tbl            apps.Bom_Bo_Pub.bom_revision_tbl_type            := apps.Bom_Bo_Pub.g_miss_bom_revision_tbl;
	l_o_bom_component_tbl           apps.Bom_Bo_Pub.bom_comps_tbl_type               := apps.Bom_Bo_Pub.g_miss_bom_component_tbl;
	l_o_bom_ref_designator_tbl      apps.Bom_Bo_Pub.bom_ref_designator_tbl_type      := apps.Bom_Bo_Pub.g_miss_bom_ref_designator_tbl;
	l_o_bom_sub_component_tbl       apps.Bom_Bo_Pub.bom_sub_component_tbl_type       := apps.Bom_Bo_Pub.g_miss_bom_sub_component_tbl;
	l_o_message_list                apps.Error_Handler.Error_Tbl_Type;
	l_error_table           apps.Error_Handler.Error_Tbl_Type;        
	l_output_dir            VARCHAR2(500) :=  '/usr/tmp';
	l_debug_filename        VARCHAR2(60) :=  'bom_debug_08_16.dbg';
	lv_return_status         VARCHAR2(1) := NULL;
	ln_msg_count             NUMBER      := 0;
	ln_cnt                   NUMBER      := 1;
	ln_comp_exist   NUMBER;
	ln_start_seq_num   NUMBER := 0; 
	ln_tot_rec_count NUMBER;
    ln_succ_rec_cnt NUMBER := 0;
    ln_err_rec_cnt NUMBER := 0;

	BEGIN
	----------------------------------------------------
	-- add request id to Validated records
	----------------------------------------------------

    UPDATE  customusr.xx_ossa_bom_conv_stg_tbl k
    SET     request_id  = gn_conc_req_id,
			TRX_TYPE = 'INTERFACE'
    WHERE   hdr_process_flag in ('U','UE')    
	;
	COMMIT;

	COMMIT;
	OPEN cur_update_bom ;
	LOOP
	FETCH cur_update_bom
	BULK COLLECT INTO gn_bom_tbl LIMIT 10000;
	EXIT WHEN gn_bom_tbl.COUNT = 0;

	FOR c_update_bom_rec IN 1 .. gn_bom_tbl.COUNT
	LOOP
	 --L_BOM_HEADER_REC.delete;
    L_BOM_HEADER_REC:= NULL;
    l_bom_component_tbl.DELETE;
    ln_rec_count:= ln_rec_count +1;
	  -- initialize BOM header
      lv_return_status := NULL;
      l_bom_header_rec.assembly_item_name := gn_bom_tbl(c_update_bom_rec).assembly_item_num;
      l_bom_header_rec.organization_code  := gn_bom_tbl(c_update_bom_rec).org_code; 
      l_bom_header_rec.assembly_type      := 1;
      l_bom_header_rec.transaction_type   := 'UPDATE';
      l_bom_header_rec.return_status      := NULL;
      l_bom_header_rec.alternate_bom_code := gn_bom_tbl(c_update_bom_rec).alternate_bom;  -- For creating alternate bills

	  ln_cnt := 0;
	  --CREATE NEW COMPONENTS FOR THE PRE-DEFINED BOM
	  OPEN cur_create_bom_comp(gn_bom_tbl(c_update_bom_rec).org_code,gn_bom_tbl(c_update_bom_rec).assembly_item_num) ;
		LOOP
		FETCH cur_create_bom_comp
		BULK COLLECT INTO gn_bom_comp_tbl LIMIT 10000;
		EXIT WHEN gn_bom_comp_tbl.COUNT = 0;

		FOR c_bom_comp_rec IN 1 .. gn_bom_comp_tbl.COUNT
		LOOP

		ln_cnt := ln_cnt + 1;
		l_bom_component_tbl (ln_cnt).organization_code 				:= gn_bom_comp_tbl(c_bom_comp_rec).org_code;
		l_bom_component_tbl (ln_cnt).assembly_item_name 			:= gn_bom_comp_tbl(c_bom_comp_rec).assembly_item_num;
		l_bom_component_tbl (ln_cnt).start_effective_date 			:=  SYSDATE; -- to_date('16-JUL-2010 19:30:39','DD-MON-YY HH24:MI:SS'); -- should match timestamp for UPDATE
		l_bom_component_tbl (ln_cnt).component_item_name			:=  gn_bom_comp_tbl(c_bom_comp_rec).line_item_num;
		l_bom_component_tbl (ln_cnt).alternate_bom_code 			:= gn_bom_comp_tbl(c_bom_comp_rec).ALTERNATE_BOM;   -- For creating alternate bills
		l_bom_component_tbl (ln_cnt).supply_subinventory 			:= apps.xx_comn_conv_util_pkg.xx_comn_conv_subinv_fnc(gn_bom_comp_tbl(c_bom_comp_rec).supply_subinventory);
		l_bom_component_tbl (ln_cnt).location_name 					:= gn_bom_comp_tbl(c_bom_comp_rec).locator;
		--l_bom_component_tbl (ln_cnt).comments 					:= gn_bom_comp_tbl(c_bom_comp_rec).comments;
		l_bom_component_tbl (ln_cnt).item_sequence_number 			:= gn_bom_comp_tbl(c_bom_comp_rec).item_sequence_number ;
		l_bom_component_tbl (ln_cnt).operation_sequence_number 		:= gn_bom_comp_tbl(c_bom_comp_rec).operation_sequence_number;
		l_bom_component_tbl (ln_cnt).transaction_type 				:= 'CREATE';
		l_bom_component_tbl (ln_cnt).quantity_per_assembly 			:=  gn_bom_comp_tbl(c_bom_comp_rec).quantity;
		l_bom_component_tbl (ln_cnt).return_status 					:= NULL;
		l_bom_component_tbl (ln_cnt).Projected_Yield 				:= gn_bom_comp_tbl(c_bom_comp_rec).yield_of_component;
		l_bom_component_tbl (ln_cnt).wip_supply_type 				:= gn_bom_comp_tbl(c_bom_comp_rec).wip_supply_type;
		--l_bom_component_tbl (ln_cnt).mutually_exclusive 			:= gn_bom_comp_tbl(c_bom_comp_rec).mutually_exclusive;
		L_BOM_COMPONENT_TBL (LN_CNT).OPTIONAL 						:= gn_bom_comp_tbl(c_bom_comp_rec).OPTIONAL;
		l_bom_component_tbl (ln_cnt).Include_In_Cost_Rollup 		:= gn_bom_comp_tbl(c_bom_comp_rec).include_in_cost_rollup_code;
		l_bom_component_tbl (ln_cnt).Enforce_Int_Requirements 		:= gn_bom_comp_tbl(c_bom_comp_rec).enforce_integer_quantity;
		--L_BOM_COMPONENT_TBL (LN_CNT).New_revised_Item_Revision 		:= gn_bom_comp_tbl(c_bom_comp_rec).comp_revision;
		IF gn_bom_comp_tbl(c_bom_comp_rec).BASIS_TYPE = 1 THEN	
    L_BOM_COMPONENT_TBL (LN_CNT).BASIS_TYPE 						:= null;
    ELSE
    L_BOM_COMPONENT_TBL (LN_CNT).BASIS_TYPE := gn_bom_comp_tbl(c_bom_comp_rec).BASIS_TYPE;	
    END IF;
		-- IF gn_bom_comp_tbl(c_bom_comp_rec).sub_comp_item_num IS NOT NULL THEN
		  l_bom_sub_component_tbl(ln_cnt).organization_code         	:=  gn_bom_comp_tbl(c_bom_comp_rec).org_code;
          l_bom_sub_component_tbl(ln_cnt).assembly_item_name        	:=  gn_bom_comp_tbl(c_bom_comp_rec).assembly_item_num;       
          l_bom_sub_component_tbl(ln_cnt).start_effective_date      	:=  sysdate; 
          l_bom_sub_component_tbl(ln_cnt).alternate_bom_code        	:=  gn_bom_comp_tbl(c_bom_comp_rec).ALTERNATE_BOM;   -- For alternate bills
          l_bom_sub_component_tbl(ln_cnt).operation_sequence_number 	:=  gn_bom_comp_tbl(c_bom_comp_rec).operation_sequence_number;
          l_bom_sub_component_tbl(ln_cnt).component_item_name       	:=  gn_bom_comp_tbl(c_bom_comp_rec).line_item_num;
          l_bom_sub_component_tbl(ln_cnt).substitute_component_name 	:=  gn_bom_comp_tbl(c_bom_comp_rec).sub_comp_item_num;
          l_bom_sub_component_tbl(ln_cnt).substitute_item_quantity  	:=  gn_bom_comp_tbl(c_bom_comp_rec).sub_comp_quantity;
          l_bom_sub_component_tbl(ln_cnt).transaction_type          	:=  'CREATE';
          l_bom_sub_component_tbl(ln_cnt).Return_Status             	:=  NULL;
		--  END IF;

	  END LOOP;	
	  END LOOP;
	  CLOSE cur_create_bom_comp;
	  --- UPDATE THE COMPONENTS FOR PRE-DEFINED BOM COMPONENTS
		OPEN cur_update_bom_comp(gn_bom_tbl(c_update_bom_rec).org_code,gn_bom_tbl(c_update_bom_rec).assembly_item_num) ;
		LOOP
		FETCH cur_update_bom_comp
		BULK COLLECT INTO gn_bom_comp_tbl LIMIT 10000;
		EXIT WHEN gn_bom_comp_tbl.COUNT = 0;

		FOR c_bom_comp_upd_rec IN 1 .. gn_bom_comp_tbl.COUNT
		LOOP

		ln_cnt := ln_cnt + 1;
		l_bom_component_tbl (ln_cnt).organization_code 				:= gn_bom_comp_tbl(c_bom_comp_upd_rec).org_code;
		l_bom_component_tbl (ln_cnt).assembly_item_name 			:= gn_bom_comp_tbl(c_bom_comp_upd_rec).assembly_item_num;
		l_bom_component_tbl (ln_cnt).start_effective_date 			:=  SYSDATE; -- to_date('16-JUL-2010 19:30:39','DD-MON-YY HH24:MI:SS'); -- should match timestamp for UPDATE
		l_bom_component_tbl (ln_cnt).component_item_name			:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).line_item_num;
		l_bom_component_tbl (ln_cnt).alternate_bom_code 			:= gn_bom_comp_tbl(c_bom_comp_upd_rec).ALTERNATE_BOM;   -- For creating alternate bills
		l_bom_component_tbl (ln_cnt).supply_subinventory 			:= apps.xx_comn_conv_util_pkg.xx_comn_conv_subinv_fnc(gn_bom_comp_tbl(c_bom_comp_upd_rec).supply_subinventory);
		l_bom_component_tbl (ln_cnt).location_name 					:= gn_bom_comp_tbl(c_bom_comp_upd_rec).locator;
		--l_bom_component_tbl (ln_cnt).comments 					:= gn_bom_comp_tbl(c_bom_comp_upd_rec).comments;
		l_bom_component_tbl (ln_cnt).item_sequence_number 			:= gn_bom_comp_tbl(c_bom_comp_upd_rec).item_sequence_number ;
		l_bom_component_tbl (ln_cnt).operation_sequence_number 		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).operation_sequence_number;
		l_bom_component_tbl (ln_cnt).transaction_type 				:= 'UPDATE';
		l_bom_component_tbl (ln_cnt).quantity_per_assembly 			:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).quantity;
		l_bom_component_tbl (ln_cnt).return_status 					:= NULL;
		l_bom_component_tbl (ln_cnt).Projected_Yield 				:= gn_bom_comp_tbl(c_bom_comp_upd_rec).yield_of_component;
		l_bom_component_tbl (ln_cnt).wip_supply_type 				:= gn_bom_comp_tbl(c_bom_comp_upd_rec).wip_supply_type;
		--l_bom_component_tbl (ln_cnt).mutually_exclusive 			:= gn_bom_comp_tbl(c_bom_comp_upd_rec).mutually_exclusive;
		L_BOM_COMPONENT_TBL (LN_CNT).OPTIONAL 						:= gn_bom_comp_tbl(c_bom_comp_upd_rec).OPTIONAL;
		l_bom_component_tbl (ln_cnt).Include_In_Cost_Rollup 		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).include_in_cost_rollup_code;
		l_bom_component_tbl (ln_cnt).Enforce_Int_Requirements 		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).enforce_integer_quantity;
		--L_BOM_COMPONENT_TBL (LN_CNT).New_revised_Item_Revision 		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).comp_revision;
		IF gn_bom_comp_tbl(c_bom_comp_upd_rec).BASIS_TYPE = 1 THEN	
    L_BOM_COMPONENT_TBL (LN_CNT).BASIS_TYPE 						:= null;
    ELSE
    L_BOM_COMPONENT_TBL (LN_CNT).BASIS_TYPE := gn_bom_comp_tbl(c_bom_comp_upd_rec).BASIS_TYPE;	
    END IF;
		 IF gn_bom_comp_tbl(c_bom_comp_upd_rec).sub_comp_item_num IS NOT NULL THEN
		  l_bom_sub_component_tbl(ln_cnt).organization_code         	:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).org_code;
          l_bom_sub_component_tbl(ln_cnt).assembly_item_name        	:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).assembly_item_num;       
          l_bom_sub_component_tbl(ln_cnt).start_effective_date      	:=  sysdate; 
          l_bom_sub_component_tbl(ln_cnt).alternate_bom_code        	:=  NULL;   -- For alternate bills
          l_bom_sub_component_tbl(ln_cnt).operation_sequence_number 	:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).operation_sequence_number;
          l_bom_sub_component_tbl(ln_cnt).component_item_name       	:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).line_item_num;
          l_bom_sub_component_tbl(ln_cnt).substitute_component_name 	:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).sub_comp_item_num;
          l_bom_sub_component_tbl(ln_cnt).substitute_item_quantity  	:=  gn_bom_comp_tbl(c_bom_comp_upd_rec).sub_comp_quantity;
          l_bom_sub_component_tbl(ln_cnt).transaction_type          	:=  'CREATE';
          l_bom_sub_component_tbl(ln_cnt).Return_Status             	:=  NULL;
		  END IF;
		/*  l_bom_revision_tbl(ln_cnt).assembly_item_name 		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).assembly_item_num;
	  l_bom_revision_tbl(ln_cnt).organization_code  		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).org_code; 
	  l_bom_revision_tbl(ln_cnt).revision 					:= gn_bom_comp_tbl(c_bom_comp_upd_rec).bom_revision;      
	  l_bom_revision_tbl(ln_cnt).revision_label	    		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).bom_revision;
	  l_bom_revision_tbl(ln_cnt).transaction_type   		:= 'CREATE';
	  l_bom_revision_tbl(ln_cnt).Alternate_Bom_Code 		:= gn_bom_comp_tbl(c_bom_comp_upd_rec).alternate_bom;     
	  l_bom_revision_tbl(ln_cnt).start_effective_date 	:= SYSDATE;*/
	  END LOOP;	  
	  END LOOP;
	  CLOSE cur_update_bom_comp;   

	  -- initialize error stack for logging errors
      apps.Error_Handler.initialize;
		apps.xx_comn_pers_util_pkg.xx_process_bom_prc('BOM',
									1.0,
									'TRUE',
									l_bom_header_rec,
									l_bom_revision_tbl,
									l_bom_component_tbl,
									l_bom_ref_designator_tbl,
									l_bom_sub_component_tbl,
									l_o_bom_header_rec,
									l_o_bom_revision_tbl,
									l_o_bom_component_tbl,
									l_o_bom_ref_designator_tbl,
									l_o_bom_sub_component_tbl,
									lv_return_status,
									ln_msg_count    ,
									'N',
									gn_user_id,
									gn_resp_id,
									gn_resp_appL_ID
                              --,p_write_err_to_conclog    	=> 'Y'
                              );
	  IF (lv_return_status = apps.fnd_api.g_ret_sts_success) THEN
	    ln_success_count := ln_success_count + 1;
		fnd_log('BOM update API success.');
		UPDATE 	customusr.xx_ossa_bom_conv_stg_tbl
		SET hdr_process_flag = 'S'
		WHERE 	request_id  = gn_conc_req_id
		AND 	assembly_item_num = gn_bom_tbl(c_update_bom_rec).assembly_item_num
		AND     org_code = gn_bom_tbl(c_update_bom_rec).org_code
		; 
		COMMIT;
	  ELSE 
		ln_err_count := ln_err_count + 1;
		apps.error_handler.get_message_list(x_message_list => l_error_table);
		fnd_log('BOM update API has returned error.');
        fnd_log('Assembly Item Number:'||gn_bom_tbl(c_update_bom_rec).assembly_item_num);
		fnd_log('Error Message Count :'||l_error_table.COUNT);
        FOR i IN 1..l_error_table.COUNT 
		LOOP
          fnd_log(to_char(i)||':'||l_error_table(i).entity_index||':'||l_error_table(i).table_name);
          fnd_log(to_char(i)||':'||l_error_table(i).message_text);
        END LOOP; 
		UPDATE 	customusr.xx_ossa_bom_conv_stg_tbl
		SET 	hdr_process_flag = 'E'
		       ,hdr_error_msg = 'BOM update API has returned error. Please refer log file'
		WHERE 	request_id  = gn_conc_req_id
		AND 	assembly_item_num = gn_bom_tbl(c_update_bom_rec).assembly_item_num
		AND     org_code = gn_bom_tbl(c_update_bom_rec).org_code
		;
		COMMIT;
	  END IF;
	END LOOP;
	END LOOP;
	CLOSE cur_update_bom;
	COMMIT;


    SELECT COUNT(1)
    INTO ln_succ_rec_cnt
    FROM customusr.xx_ossa_bom_conv_stg_tbl
    WHERE request_id  = gn_conc_req_id
    AND hdr_process_flag = 'S'
    ;
	SELECT COUNT(1)
    INTO ln_err_rec_cnt
    FROM customusr.xx_ossa_bom_conv_stg_tbl
    WHERE request_id  = gn_conc_req_id
    AND hdr_process_flag = 'E'
    ;

	--------------------------------------------------------------------------------
	--Update Summary report
	--------------------------------------------------------------------------------
	FND_OUT('Concurent Program Name :'           ||gv_conc_prog_name);
	FND_OUT('Concurent Request ID :'				||gn_conc_req_id);
	FND_OUT('User Name :'						||gv_user_name);
	FND_OUT('Requested Date :'					||gd_conc_prog_date);
	FND_OUT('Completion Date :'					||SYSDATE);
	--FND_OUT('Total records processed :'		    ||ln_tot_rec_count);
	FND_OUT('Total records imported successfully :'		||ln_succ_rec_cnt);
	FND_OUT('Total records failed import :'		||ln_err_rec_cnt);
	FND_OUT('------------------------------------------------------------------------------------------------------------------');
	FND_OUT('');
	FND_OUT('');
	IF ln_err_rec_cnt <> 0 THEN	
	  FND_LOG('Error Details : ');
      FND_LOG('Assembly Item Number,Organization_Code,Component,Item Sequence,Operation Sequence,Quantity,Basis,Supply Type,Subinventory,Locator,Optional Flag,Error Message');	
	  FOR c_err_rec in cur_bom_err_stg 
	  LOOP
	    FND_LOG(c_err_rec.assembly_item_num||','||c_err_rec.org_code||','||c_err_rec.line_item_num||','||c_err_rec.item_sequence_number||','||
		c_err_rec.operation_sequence_number||','||c_err_rec.quantity||','||
              c_err_rec.basis||','||c_err_rec.supply_type||','||c_err_rec.supply_subinventory||','||
              c_err_rec.locator||','||c_err_rec.optional_flag||','||c_err_rec.hdr_error_msg
			   );
	  END LOOP;
    END IF;
	EXCEPTION 
	WHEN OTHERS THEN
	  FND_LOG('Problem executing bom_update import procedure.');
      FND_LOG('Error Details : '||SQLERRM);
      apps.xx_comn_conv_debug_prc ( p_i_level =>NULL,
							p_i_proc_name => 'BOM Conversion',
							p_i_phase => 'bom_update',
							p_i_stgtable => 'xx_ossa_bom_conv_stg_tbl' ,
							p_i_message => 'Error while Creating records'||SQLCODE||SQLERRM);
	END bom_update;
/***************************************************************************************************
 * PROCEDURE GET_CONC_DETAILS
 * 
 * Description:
 * This Procedures fetch the details to be printed in error report.
 *
 ****************************************************************************************************/
	PROCEDURE GET_CONC_DETAILS
	AS
	BEGIN
	SELECT fcr.request_date,fcp.user_concurrent_program_name 
	INTO  	gd_conc_prog_date,gv_conc_prog_name
	FROM 	apps.fnd_concurrent_requests fcr,
			apps.fnd_concurrent_programs_tl fcp
	WHERE 	fcr.request_id = gn_conc_req_id
			AND fcp.concurrent_program_id = fcr.concurrent_program_id
			AND fcp.language = USERENV('LANG')
	;
	Select 	USER_NAME 
	INTO 	gv_user_name
	from 	apps.FND_USER
	where 	user_id = gn_user_id
	;
	EXCEPTION WHEN OTHERS THEN
		apps.xx_comn_conv_debug_prc ( p_i_level =>NULL,
							p_i_proc_name => 'BOM Conversion',
							p_i_phase => 'GET_CONC_DETAILS',
							p_i_stgtable => 'xx_ossa_bom_conv_stg_tbl' ,
							p_i_message => 'Error :'||SQLCODE||SQLERRM);
	END GET_CONC_DETAILS;
/***************************************************************************************************
 * PROCEDURE MAIN
 * 
 * Description:
 * This is the main procedure called by the concurrent program "OSSA INV On Hand Conversion".
 * This program depending on P_I_RUN_MODE parameter either validates or creates itemc categories.
 *
 ****************************************************************************************************/
	PROCEDURE MAIN(P_O_ERR_BUFF    OUT VARCHAR2,
	P_O_RET_CODE    OUT NUMBER,
	P_I_RUN_MODE    IN VARCHAR2
	)
	AS
	BEGIN
		GET_CONC_DETAILS;
		IF P_I_RUN_MODE = 'CONVERSION' THEN
			BOM_VALIDATE(P_I_RUN_MODE);
			BOM_CREATE;
		ELSIF P_I_RUN_MODE = 'INTERFACE' THEN
			BOM_VALIDATE(P_I_RUN_MODE);
			BOM_UPDATE;
		END IF;
		P_O_RET_CODE:= gn_ret_code;
		P_O_ERR_BUFF:= gv_err_buff;
	EXCEPTION WHEN OTHERS THEN
		apps.xx_comn_conv_debug_prc ( p_i_level =>NULL,
							p_i_proc_name => 'BOM Conversion',
							p_i_phase => 'MAIN',
							p_i_stgtable => 'xx_ossa_bom_conv_stg_tbl' ,
							p_i_message => 'Error in Main'||SQLCODE||SQLERRM);
	END MAIN;	
END XX_OSSA_BOM_CONV_PKG;
/