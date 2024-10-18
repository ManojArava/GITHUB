create or replace PACKAGE BODY           XX_BOM_ROUTING_CONV_PKG
											  
AS
/*******************************************************************************/
     
	  gn_user_id 				CONSTANT NUMBER:=FND_GLOBAL.USER_ID;
	  gn_login_id 				CONSTANT NUMBER:=FND_GLOBAL.login_id;
	  gn_resp_id 				CONSTANT NUMBER:= FND_GLOBAL.resp_id;
	  gn_resp_appl_id CONSTANT NUMBER := FND_GLOBAL.RESP_APPL_ID;
		gc_valid CONSTANT VARCHAR2(1):='V';
		gc_error CONSTANT VARCHAR2(1):='E';
		gc_succs CONSTANT VARCHAR2(1):='S';
		gc_verror CONSTANT VARCHAR2(2):='VE';
		gn_conc_req_id CONSTANT NUMBER:=FND_GLOBAL.CONC_REQUEST_ID;
		gd_conc_prog_date DATE;
		gv_conc_prog_name VARCHAR2(200) :=' BOM Routing Conversion';
		gv_user_name VARCHAR2(200) := FND_GLOBAL.USER_NAME;
		gn_org_id CONSTANT NUMBER := FND_GLOBAL.ORG_ID;
		gv_org_name CONSTANT HR_ALL_ORGANIZATION_UNITS_TL.name%type := FND_GLOBAL.ORG_NAME;
	  
/***************************************************************************************************
 * PROCEDURE FND_LOG
 * 
 * Description:
 * Prints concurrent program log.
 * 
 ****************************************************************************************************/
 
PROCEDURE FND_LOG(P_MSG VARCHAR2)
AS
BEGIN

	FND_FILE.PUT_LINE(fnd_file.LOG,p_MSG);

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

	FND_FILE.PUT_LINE(fnd_file.OUTPUT,p_MSG);

	EXCEPTION WHEN OTHERS THEN
	NULL; --debug
END FND_OUT;

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
	FROM 	fnd_concurrent_requests fcr,
			fnd_concurrent_programs_tl fcp
	WHERE 	fcr.request_id = gn_conc_req_id
			AND fcp.concurrent_program_id = fcr.concurrent_program_id
			AND fcp.language = USERENV('LANG')
	;

	Select 	USER_NAME 
	INTO 	gv_user_name
	from 	FND_USER
	where 	user_id = gn_user_id
	;

	EXCEPTION WHEN OTHERS THEN
		XX_COMN_CONV_DEBUG_PRC ( p_i_level =>NULL,
							p_i_proc_name => 'On Hand Quantity',
							p_i_phase => 'GET_CONC_DETAILS',
							p_i_stgtable => 'XX_INV_ONHAND_TBL' ,
							p_i_message => 'Error :'||SQLCODE||SQLERRM);
	END GET_CONC_DETAILS;

PROCEDURE VALIDATE_ORG_CODE(p_io_organization IN VARCHAR2,
							p_io_error_msg    IN OUT VARCHAR2)  
AS
   lc_org_code   VARCHAR2(10);
   ln_count      NUMBER;
 BEGIN
	
    SELECT count(1) 
					INTO ln_count
				FROM org_organization_definitions
				WHERE UPPER(ORGANIZATION_CODE) = UPPER(p_io_organization);
	--lc_org_code := p_io_organization;
				
	IF ln_count = 0
	    THEN
		   p_io_error_msg := p_io_error_msg|| 'Organization not mapped in Oracle';
			
	END IF;
	EXCEPTION
		WHEN OTHERS THEN
				   p_io_error_msg := p_io_error_msg|| 'Organization not mapped in Oracle';

END VALIDATE_ORG_CODE;


FUNCTION get_org_id (p_i_org_code IN VARCHAR2, p_io_error_msg IN OUT VARCHAR2)
   RETURN NUMBER
IS
   ln_org_id   NUMBER;
BEGIN
   SELECT organization_id
     INTO ln_org_id
     FROM org_organization_definitions
    WHERE organization_code = p_i_org_code;

   RETURN ln_org_id;
EXCEPTION
   WHEN OTHERS
   THEN
      p_io_error_msg :=
         p_io_error_msg || 'Error in get_org_id ' || SUBSTR (SQLERRM, 1, 100);
      RETURN 0;
END get_org_id;

PROCEDURE ITEM_EXISTS (p_i_inventory_item    IN     VARCHAR2,
                       p_i_organization_id   IN     NUMBER,
                       p_io_error_msg         IN OUT VARCHAR2)
AS
   lc_cnt   NUMBER;
BEGIN
   IF p_i_inventory_item IS NOT NULL AND p_i_organization_id IS NOT NULL
   THEN
      SELECT COUNT (1)
        INTO lc_cnt
        FROM MTL_SYSTEM_ITEMS_B msi
       WHERE segment1 = p_i_inventory_item
             AND msi.organization_id = p_i_organization_id;

      IF lc_cnt <= 0
      THEN
         p_io_error_msg :=
            p_io_error_msg || 'Item ' || p_i_inventory_item || ' does not exists ';
			
										 
									   
													 
																	   
			  
      END IF;
   ELSE
      p_io_error_msg := p_io_error_msg || 'Inventory Item should not be null. ';
	  
										 
									   
													 
																	   
			  
   END IF;
EXCEPTION
   WHEN OTHERS
   THEN
      p_io_error_msg :=
            p_io_error_msg
         || 'Error in ITEM_EXISTS '
         || p_i_inventory_item
         || SQLERRM
         || ',';
END ITEM_EXISTS;

FUNCTION ROUTING_EXISTS (p_i_inventory_item    IN     VARCHAR2,
                         p_i_organization_id   IN     NUMBER,
                         p_io_error_msg         IN OUT VARCHAR2)
   RETURN NUMBER
AS
   ln_count   NUMBER := 0;
BEGIN
   IF p_i_inventory_item IS NOT NULL AND p_i_organization_id IS NOT NULL
   THEN
      SELECT COUNT (1)
        INTO ln_count
        FROM bom_operational_routings b, mtl_system_items_b m
       WHERE     b.assembly_item_id = m.inventory_item_id
             AND b.organization_id = m.organization_id
             AND m.segment1 = p_i_inventory_item
             AND m.organization_id = p_i_organization_id
             AND alternate_routing_designator IS NULL;

      IF ln_count > 0
      THEN
         p_io_error_msg :=
               p_io_error_msg
            || 'Routing for item '
            || p_i_inventory_item
            || ' is already exists. ';
		
										 
										  
													 
																		  
			  
      END IF;
   END IF;

   RETURN ln_count;
EXCEPTION
   WHEN OTHERS
   THEN
      p_io_error_msg :=
            p_io_error_msg
         || 'Error in ROUTING_EXISTS of item'
         || p_i_inventory_item
         || SQLERRM
         || ',';
		 
										 
										  
													 
																		  
			  
      RETURN 0;
END ROUTING_EXISTS;

function DEPARTMENT_CODE_EXISTS (p_i_department_code    IN     VARCHAR2,
                                 p_i_organization_id    IN     NUMBER,
                                 p_io_error_msg         IN OUT VARCHAR2)
return number
AS
   ln_department_id   NUMBER;
BEGIN
   IF p_i_department_code IS NOT NULL AND p_i_organization_id IS NOT NULL
   THEN
         SELECT department_id
           INTO ln_department_id
           FROM bom_departments
          WHERE     department_code = p_i_department_code
                AND organization_id = p_i_organization_id
                AND NVL (disable_date, SYSDATE + 1) > SYSDATE; 
 
   ELSE
       p_io_error_msg := p_io_error_msg || 'Department Code or Operation code should not be null. ';
	   
										 
											 
													 
																				  
			  
       return 0;
   END IF;
   return ln_department_id;
EXCEPTION
   when no_data_found then
    p_io_error_msg := p_io_error_msg || 'Department Code '||p_i_department_code ||' does not exist or disabled. ';  
											   
										 
											 
													 
																				  
			  
	 
										
    return 0;
   WHEN OTHERS
   THEN
      p_io_error_msg := p_io_error_msg || 'Error in Department Code ' || p_i_department_code || ':'||substr(sqlerrm,1,100);
	  
										 
											 
													 
																				  
			  
      RETURN 0;
END DEPARTMENT_CODE_EXISTS; 

PROCEDURE resource_exists (p_i_resource_code      IN     VARCHAR2,
                           p_i_dept_code          IN       VARCHAR2,
                           p_i_org_id             IN       NUMBER,
						   p_o_res_cnt            OUT      NUMBER,
                           p_io_error_msg         IN OUT   VARCHAR2)
IS
   lc_count   NUMBER;
   ln_res_length   NUMBER;
BEGIN
   
   ln_res_length := LENGTH(p_i_resource_code);
   FND_LOG('validate resource length:' ||LENGTH(p_i_resource_code));
    IF ln_res_length>10
	THEN
	    p_io_error_msg :=
               p_io_error_msg
            || ' Resource '||p_i_resource_code||' is more than 10 characters '
            || p_i_dept_code
            || '. ';
											  
										 
										   
													 
																			   
			  
		
										
		lc_count:=0;
		
	ELSE
	BEGIN
	      FND_LOG('validate resource with dept');
		 SELECT COUNT (*)
			INTO lc_count
			FROM BOM_RESOURCES BR,
				 BOM_DEPARTMENT_RESOURCES BDR,
				 BOM_DEPARTMENTS BD
		   WHERE     br.resource_id = bdr.resource_id
				-- AND resource_type = 2                     -- Person Type Resource
				 AND bd.department_code = p_i_dept_code
				 AND bd.department_id = bdr.department_id
				 AND BR.ORGANIZATION_ID = BD.ORGANIZATION_ID
				 AND BR.ORGANIZATION_ID = p_i_org_id
				 --AND TRIM(BR.RESOURCE_CODE)   like p_i_resource_code
				  AND replace(br.resource_code,chr(13),'')=p_i_resource_code;
	EXCEPTION
		WHEN OTHERS THEN
			lc_count:=0;
	END;

      IF lc_count = 0
      THEN
         p_io_error_msg :=
               p_io_error_msg
            || ' Resource '||p_i_resource_code||' is not attached with Department '
            || p_i_dept_code
            || '. ';
		  
										 
										   
													 
																		   
			  
      END IF;
	   
	END IF;
	
	p_o_res_cnt := lc_count;
		 
						  
														 
												  
										 
										   
													 
																		   
			
			
	 
 
   FND_LOG('FRom resource exist block :'||p_i_resource_code||' '||p_io_error_msg);
  
END resource_exists;

PROCEDURE op_code_exists (p_i_op_code      IN     VARCHAR2,
                           p_i_dept_code   IN     VARCHAR2,
                           p_i_dept_id          IN       NUMBER,
                           p_i_org_id             IN       NUMBER,
						   p_o_op_cnt            OUT      NUMBER,
                           p_io_error_msg         IN OUT   VARCHAR2)
IS
   lc_count   NUMBER;
   ln_res_length   NUMBER;
BEGIN
   
   ln_res_length := LENGTH(p_i_op_code);
   FND_LOG('validate resource length:' ||LENGTH(p_i_op_code));
    IF ln_res_length>4
	THEN
	    p_io_error_msg :=
               p_io_error_msg
            || ' Operation Code '||p_i_op_code||' is more than 4 characters '
            || '. ';
											  
										 
												 
													 
																				   
			  
										
		lc_count:=0;
		
	ELSE
	BEGIN
	      FND_LOG('validate resource with dept');
		 SELECT COUNT (*)
			INTO lc_count
			FROM BOM_STANDARD_OPERATIONS  bo
			WHERE ORGANIZATION_ID=p_i_org_id
			--AND   OPERATION_CODE=p_i_op_code
			AND   DEPARTMENT_ID=p_i_dept_id
			AND replace(bo.OPERATION_CODE,chr(13),'')=p_i_op_code;
	EXCEPTION
		WHEN OTHERS THEN
			lc_count:=0;
	END;

      IF lc_count = 0
      THEN
         p_io_error_msg :=
               p_io_error_msg
            || ' Operation_Code '||p_i_op_code||' is not attached with Department '
            || p_i_dept_code
            || '. ';
		  
										 
												 
													 
																				 
			  
      END IF;
	   
	END IF;
	
	p_o_op_cnt := lc_count;
   FND_LOG('FRom operation code exist block :'||p_i_op_code||' '||p_io_error_msg);
  
END op_code_exists;

PROCEDURE op_derive_dept (p_i_op_code      IN     VARCHAR2,
                           p_i_org_id             IN       NUMBER,
						   p_i_dept_code            OUT      VARCHAR2,
                           p_io_error_msg         IN OUT   VARCHAR2)
IS
   lc_count   NUMBER;
   ln_res_length   NUMBER;
   lv_department_code VARCHAR2(30);
BEGIN
   
   	BEGIN
	      FND_LOG('derive dept with op code');
		 SELECT  bd.department_code 
          INTO  lv_department_code 
           FROM bom_departments bd 
				,BOM_STANDARD_OPERATIONS  bo 
          WHERE     1=1
        AND bd.organization_id = p_i_org_id
				AND bd.organization_id = bo.organization_id
        AND NVL (bd.disable_date, SYSDATE + 1) > SYSDATE
        AND bd.department_id = bo.department_id
		AND replace(bo.OPERATION_CODE,chr(13),'')= p_i_op_code

        ;
	EXCEPTION
		WHEN OTHERS THEN
			lv_department_code:=NULL;
	END;

      p_i_dept_code := lv_department_code;
	  IF lv_department_code IS NULL 
      THEN
         p_io_error_msg :=
               p_io_error_msg
            || ' Unable to derive Department for Operation_Code '||p_i_op_code|| '. ';
		  
      END IF;
	
  
END op_derive_dept;

PROCEDURE GET_SUBINVENTORY(p_i_subinv_code        IN     VARCHAR2,
                           p_o_subinv_code        OUT       VARCHAR2,
                           p_io_error_msg         IN OUT   VARCHAR2)
	AS
	l_subinv_code   MTL_SECONDARY_INVENTORIES.SECONDARY_INVENTORY_NAME%TYPE;
	BEGIN
	    l_subinv_code := XX_COMN_CONV_UTIL_PKG.xx_comn_conv_subinv_fnc(p_i_subinv_code); 
        IF 	l_subinv_code IS NULL
			THEN
			   p_o_subinv_code := NULL;
			   p_io_error_msg :=
               p_io_error_msg
            || ' Subinventory '||p_i_subinv_code||' is not defined in Oracle ';
           
			
										 
										  
													 
																		
			  
		ELSE
			p_o_subinv_code := l_subinv_code;
										
		END IF;
	
END GET_SUBINVENTORY;

PROCEDURE GET_LOCATOR(p_i_subinv_code        IN     VARCHAR2,
                      p_i_locator_code       IN     VARCHAR2,
                           p_o_locator_code        OUT       VARCHAR2,
                           p_io_error_msg         IN OUT   VARCHAR2)
	AS
	l_locator_code  MTL_ITEM_LOCATIONS_KFV.CONCATENATED_SEGMENTS%TYPE;
	BEGIN
	    l_locator_code := XX_COMN_CONV_UTIL_PKG.xx_comn_conv_locator_fnc(p_i_subinv_code,p_i_locator_code); 
        IF 	l_locator_code IS NULL
			THEN
			   p_o_locator_code := NULL;
			   p_io_error_msg :=
               p_io_error_msg
            || ' Locator '||p_i_locator_code||' is not defined in Oracle for subinventory :'||p_i_subinv_code ;
           
			
										 
									 
													 
																   
			  
		ELSE
			p_o_locator_code := l_locator_code;
										
		END IF;
	
END GET_LOCATOR;

FUNCTION GET_MV_HOUR_CODE(p_i_org_code IN VARCHAR2)
  RETURN VARCHAR2
  AS
	lv_move_resource_code VARCHAR2(10);
  BEGIN
	  SELECT flv.meaning
             INTO lv_move_resource_code
           FROM apps.fnd_lookup_values flv 
           WHERE flv.lookup_type  = 'XX_ROUTING_MOVE_RESOURCE_CODE' 
           AND flv.language     = USERENV('LANG')
           AND flv.description = p_i_org_code
           AND flv.enabled_flag = 'Y'
           AND NVl(flv.end_date_active,SYSDATE+1)>SYSDATE; 
		   RETURN lv_move_resource_code;
 EXCEPTION
	WHEN OTHERS THEN
		xx_comn_conv_debug_prc ( p_i_level =>NULL,
										p_i_proc_name => 'BOM Routing',
										p_i_phase => 'GET_MV_HOUR_CODE',
										p_i_stgtable => 'XX_BOM_ROUT_CNV_STG_TBL' ,
										p_i_message => 'Error in GET_MV_HOUR_CODE: '
										);
		RETURN NULL;
 END GET_MV_HOUR_CODE;

PROCEDURE DUPLICATE_BATCH( p_o_count OUT NUMBER) AS

CURSOR CUR_DUP_OP_SEQ IS
	 SELECT count(1) REC_OP_CNT,
             assembly_item_number,
			 org_code,
			 operation_seq
         FROM STGUSR.XX_BOM_ROUT_CNV_STG_TBL
		WHERE 1=1
    and request_id = gn_conc_req_id
		AND   process_flag = 'N'
   -- and assembly_item_number='EQAG123-001'
    group by assembly_item_number,
			 org_code,
			 operation_seq
       having count(1) >1;

CURSOR CUR_DUP_BAT IS 
SELECT          
		COUNT(1) REC_CNT,
		ASSEMBLY_ITEM_NUMBER,
	ORG_CODE				,
						   
						 
						  
						 
						 
	OPERATION_SEQ	        ,
						   
						   
							
						 
	DEPARTMENT_CODE	        ,
	COUNT_POINT_FLAG	    ,
	BACKFLUSH_FLAG	        ,
	ROLLUP_FLAG	            ,
						   
	RESOURCE_CODE	        ,
	ACTIVITY			    ,
						 
	BASIS_TYPE			    ,
						   
	SCHEDULE_FLAG	        ,
    AUTOCHARGE_TYPE	        ,
    ASSIGNED_UNITS	        ,
    USAGE_RATE_OR_AMOUNT	,
    SETUP_HRS	            ,
	TRANSIT_DAYS
    FROM   STGUSR.XX_BOM_ROUT_CNV_STG_TBL
    WHERE  PROCESS_FLAG = 'N'   
	AND    REQUEST_ID   = gn_conc_req_id
    GROUP BY
                ASSEMBLY_ITEM_NUMBER,
				ORG_CODE				,
							  
							
							 
							
							
				OPERATION_SEQ	        ,
							  
							  
							   
							
				DEPARTMENT_CODE	        ,
				COUNT_POINT_FLAG	    ,
				BACKFLUSH_FLAG	        ,
				ROLLUP_FLAG	            ,
							  
				RESOURCE_CODE	        ,
				ACTIVITY			    ,
							
				BASIS_TYPE			    ,
							  
				SCHEDULE_FLAG	        ,
				AUTOCHARGE_TYPE	        ,
				ASSIGNED_UNITS	        ,
				USAGE_RATE_OR_AMOUNT	,
				SETUP_HRS     			,
				TRANSIT_DAYS
           HAVING
               COUNT(*) > 1;


ln_count NUMBER:=0;
lv_error_message VARCHAR2(500);

BEGIN

	FND_LOG('Check the batch for duplicate records');
	
	FOR j IN CUR_DUP_OP_SEQ
	LOOP
	   lv_error_message := null;
	   BEGIN
			UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL
					SET
						process_flag = 'VE',
						error_msg = 'Duplicate Operation Sequence Found.'
				    where 1=1
					AND ASSEMBLY_ITEM_NUMBER = j.ASSEMBLY_ITEM_NUMBER
					AND ORG_CODE			 = j.ORG_CODE
					AND OPERATION_SEQ	     = NVL(j.OPERATION_SEQ,OPERATION_SEQ)
					AND request_id 			 = gn_conc_req_id ;
	  EXCEPTION
		WHEN OTHERS THEN
				  lv_error_message := lv_error_message || SUBSTR(SQLERRM,1,250);
				   FND_LOG ('From Duplicate Batch block :'||lv_error_message);
				  
									  
									  
												  
																						
	  END;
	END LOOP;
    COMMIT;
	FOR i IN CUR_DUP_BAT
	LOOP

		ln_count := ln_count + i.REC_CNT;
		lv_error_message := NULL;
		
		IF i.REC_CNT>1 THEN
		BEGIN
		    FND_LOG('inside dup batch loop');   
			
					UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL
					SET
						process_flag = 'VE',
						error_msg = 'Duplicate Records Found.'
				    where 1=1
					AND ASSEMBLY_ITEM_NUMBER = i.ASSEMBLY_ITEM_NUMBER
					AND ORG_CODE			 = i.ORG_CODE
					AND OPERATION_SEQ	     = NVL(i.OPERATION_SEQ,OPERATION_SEQ)
					AND	DEPARTMENT_CODE	        = NVL(i.DEPARTMENT_CODE,DEPARTMENT_CODE)
					AND	COUNT_POINT_FLAG	    = NVL(i.COUNT_POINT_FLAG,COUNT_POINT_FLAG)
					AND	BACKFLUSH_FLAG	        = NVL(i.BACKFLUSH_FLAG,BACKFLUSH_FLAG)
					AND	ROLLUP_FLAG	            = NVL(i.ROLLUP_FLAG,ROLLUP_FLAG)
					--AND	OPERATION_DESC	        = NVL(i.OPERATION_DESC,OPERATION_DESC)
					AND	RESOURCE_CODE	        = NVL(i.RESOURCE_CODE,RESOURCE_CODE)
					AND	ACTIVITY			    = NVL(i.ACTIVITY,ACTIVITY)
					AND	BASIS_TYPE			    = NVL(i.BASIS_TYPE,BASIS_TYPE)
					AND	SCHEDULE_FLAG	        =NVL(i.SCHEDULE_FLAG,SCHEDULE_FLAG)
					AND	AUTOCHARGE_TYPE	        = NVL(i.AUTOCHARGE_TYPE,AUTOCHARGE_TYPE)
					AND	ASSIGNED_UNITS	        = NVL(i.ASSIGNED_UNITS,ASSIGNED_UNITS)
					AND USAGE_RATE_OR_AMOUNT	= NVL(i.USAGE_RATE_OR_AMOUNT,USAGE_RATE_OR_AMOUNT)
					AND SETUP_HRS	            = NVL(i.SETUP_HRS,SETUP_HRS)
				    AND  PROCESS_FLAG = 'N'
					AND  REQUEST_ID = gn_conc_req_id;
				
					commit;
					
				
																									
																							
																										   
																								  
												 
			EXCEPTION
				WHEN OTHERS THEN
				   lv_error_message := lv_error_message || SUBSTR(SQLERRM,1,250);
				   FND_LOG ('From Duplicate Batch block :'||lv_error_message);
				  
									  
									  
												  
																						
			END;
		END IF;

	END LOOP;
	FND_LOG ('Duplicate Records : '||ln_count);
	p_o_count := ln_count;
    COMMIT;
	EXCEPTION WHEN OTHERS THEN
		XX_COMN_CONV_DEBUG_PRC ( p_i_level =>NULL,
							p_i_proc_name => 'BOM Routing',
							p_i_phase => 'DUPLICATE_BATCH',
							p_i_stgtable => 'XX_BOM_ROUT_CNV_STG_TBL' ,
							p_i_message => 'Error while Checking Duplicate in a batch');
END DUPLICATE_BATCH;

PROCEDURE VALIDATE 
AS
   CURSOR CUR_VALID
   IS
      SELECT ROWID AS row_id,
             assembly_item_number,
			 org_code,
			 operation_seq,
             department_code,
			 resource_code,
			 operation_code,
			 MOVE_HRS,
			 COMP_SUBINVENTORY,
			 COMP_LOCATOR,
             ERROR_MSG,
			 TRANSIT_DAYS,
			 REFERENCE_FLAG
        FROM STGUSR.XX_BOM_ROUT_CNV_STG_TBL
		WHERE request_id = gn_conc_req_id
		AND   process_flag = 'N'
		order by assembly_item_number,org_code,operation_seq
       ;
	   
	CURSOR CUR_ERR_STG 
	IS
	    SELECT ROWID AS row_id,
             assembly_item_number,
			 org_code,
			 operation_seq,
             department_code,
			 resource_code,
			 COMP_SUBINVENTORY,
			 COMP_LOCATOR,
             ERROR_MSG
        FROM STGUSR.XX_BOM_ROUT_CNV_STG_TBL
		WHERE request_id = gn_conc_req_id
		AND   process_flag = 'VE'
		order by assembly_item_number,org_code,operation_seq
		;
	  
   lv_error_msg         VARCHAR2 (4000);
   ln_error_flag        NUMBER  :=0;
   lc_department_code   VARCHAR2 (100);
--ln_count             NUMBER;
   ln_total_cnt         NUMBER;
   ln_count            NUMBER;
   ln_validate          NUMBER;
   ln_error             NUMBER;
   ln_flag              NUMBER := 1;
   ln_route             NUMBER := 0;
   ln_operation_code    NUMBER;
   ln_dept_id           NUMBER;
   lc_org_code          VARCHAR2(30);
   ln_org_id            NUMBER;
   lv_subinv_code       MTL_SECONDARY_INVENTORIES.SECONDARY_INVENTORY_NAME%TYPE;
   lv_locator_code      MTL_ITEM_LOCATIONS_KFV.CONCATENATED_SEGMENTS%TYPE;
   ln_res_cnt           NUMBER;
   ln_op_cnt            NUMBER;
   lv_subinv_err_msg    VARCHAR2(500);
   l_update_count       NUMBER;
   lv_dummy_res_code   VARCHAR2(30);
BEGIN
   fnd_file.
   put_line (
      fnd_file.LOG,
      RPAD (
         '***************************************************************************',
         100,
         '*'));
   fnd_file.put_line (fnd_file.LOG, '  Under Validation Process ');
   fnd_file.
   put_line (
      fnd_file.LOG,
      RPAD (
         '***************************************************************************',
         100,
         '*'));
		 
	BEGIN
	   UPDATE STGUSR.XX_BOM_ROUT_CNV_STG_TBL
		  SET ASSEMBLY_ITEM_NUMBER = TRIM (ASSEMBLY_ITEM_NUMBER),
			  ORG_CODE             = TRIM(ORG_CODE),
			  DEPARTMENT_CODE = TRIM(DEPARTMENT_CODE),
			  REVISION        = TRIM(REVISION),
			  COMP_SUBINVENTORY = TRIM(COMP_SUBINVENTORY),
			  COMP_LOCATOR      = TRIM(COMP_LOCATOR),
			  OPERATION_CODE    = TRIM(OPERATION_CODE),
			  REFERENCE_FLAG    =TRIM(REFERENCE_FLAG),
			  OPTION_DEPENDENT_FLAG = TRIM(OPTION_DEPENDENT_FLAG),
			  COUNT_POINT_FLAG     =TRIM(COUNT_POINT_FLAG),
			  BACKFLUSH_FLAG     =TRIM(BACKFLUSH_FLAG),
			  ROLLUP_FLAG        =TRIM(ROLLUP_FLAG),
			  RESOURCE_CODE      =TRIM(RESOURCE_CODE),
			  ACTIVITY           =TRIM(ACTIVITY),
			  STANDARD_RATE_FLAG =TRIM(STANDARD_RATE_FLAG),
			  SCHEDULE_FLAG      =TRIM(SCHEDULE_FLAG),
			  REQUEST_ID         =gn_conc_req_id,
			  ERROR_MSG = NULL
		 WHERE PROCESS_FLAG ='N';
	EXCEPTION
		WHEN OTHERS
		  THEN
		    lv_error_msg := lv_error_msg || SUBSTR(SQLERRM,1,150);
		    
									  
									   
												  
																		
	END;

   COMMIT;
   
   SELECT COUNT(*)
	 INTO ln_total_cnt 
	  FROM STGUSR.XX_BOM_ROUT_CNV_STG_TBL a
	  WHERE a.process_flag = 'N'
	  AND request_id    = gn_conc_req_id;
	  
	FND_LOG('Calling DUPLICATE_BATCH' );
	--Validate Duplicate records in batch
	DUPLICATE_BATCH(ln_count );
    FND_LOG('After DUPLICATE_BATCH' );
   
   FOR c_valid IN CUR_VALID
   LOOP
      ln_error_flag := 0;
      lv_error_msg := NULL;
	  lv_subinv_err_msg := NULL;
      ln_dept_id := 0;
	  ln_org_id := 0;
	  lc_org_code := c_valid.org_code;
	  lv_subinv_code  := NULL;
	  lv_locator_code := NULL;
	  
	   VALIDATE_ORG_CODE( lc_org_code, lv_error_msg);
	      
	   ln_org_id := get_org_id(lc_org_code, lv_error_msg);
	   
															   
	   
	   IF ln_org_id>0 THEN
      
															
	       
		    ITEM_EXISTS (c_valid.assembly_item_number, ln_org_id, lv_error_msg);
			
			IF NVL(lv_error_msg,'X') ='X'
			   THEN
				ln_route :=
					ROUTING_EXISTS (c_valid.assembly_item_number, ln_org_id, lv_error_msg);
					
																
	
																		
					   

				IF ln_route = 0
				THEN 
				    IF NVL(c_valid.operation_seq,0) <> 0
					  THEN
						
						
						
						lc_department_code := c_valid.department_code;
						
						IF lc_department_code IS NULL THEN 
							op_derive_dept (c_valid.operation_code,
										   ln_org_id,
										   lc_department_code,
										   lv_error_msg);
							IF lc_department_code IS NOT NULL THEN 
								UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL
								 SET department_code = lc_department_code
									 WHERE ROWID = c_valid.row_id
									 AND   request_id = gn_conc_req_id; 
							END IF;
							
						END IF;
				  
						ln_dept_id :=
						   DEPARTMENT_CODE_EXISTS (lc_department_code,
												   ln_org_id,
												   lv_error_msg);

						IF ln_dept_id > 0 
							THEN
							   
											   
																	
							   IF  c_valid.resource_code IS NOT NULL
									THEN		
							
									
									resource_exists (c_valid.resource_code,
													lc_department_code,
													ln_org_id,
													ln_res_cnt,
													lv_error_msg);
													FND_LOG('step4');

									
									IF ln_res_cnt=0
									  THEN
									    LN_ERROR_FLAG:=1;
										lv_error_msg  :=  lv_error_msg ;--|| ' Invalid RESOURCE';
									END IF;
																
																				   
									
								END IF;  -- resource check ends
								
								IF NVL(c_valid.MOVE_HRS,-1) >= 0
								  THEN
								     ln_res_cnt:=0;
									 lv_dummy_res_code := GET_MV_HOUR_CODE(lc_org_code);
									 resource_exists (lv_dummy_res_code,
													lc_department_code,
													ln_org_id,
													ln_res_cnt,
													lv_error_msg);
													FND_LOG('step4.1');

																						
									IF ln_res_cnt=0
									  THEN
									    ln_error_flag:=1;
										lv_error_msg  :=  lv_error_msg || ' Invalid Move RESOURCE';
									END IF;
									 
								END IF;
								
								IF NVL(c_valid.TRANSIT_DAYS,-1) >= 0
								  THEN
								     ln_res_cnt:=0;
									 resource_exists ('TRANSITDAY',
													lc_department_code,
													ln_org_id,
													ln_res_cnt,
													lv_error_msg);
													FND_LOG('step4.1');

									IF ln_res_cnt=0
									  THEN
									    LN_ERROR_FLAG:=1;
										--lv_error_msg  :=  lv_error_msg || ' Invalid Transit RESOURCE';
									END IF;
									 
								END IF;
								
								IF  c_valid.operation_code IS NOT NULL
									THEN		
							
									op_code_exists (c_valid.operation_code ,
												    lc_department_code     ,
												    ln_dept_id,
												    ln_org_id,
												    ln_op_cnt     ,
												    lv_error_msg   
												   );
													FND_LOG('step4');

																						
									IF ln_op_cnt=0
									  THEN
									    ln_error_flag:=1;
									END IF;
																
																				   
									
								END IF;  -- operation code check ends
								
								IF  c_valid.operation_code IS NULL AND UPPER(c_valid.REFERENCE_FLAG) IN ('YES' ,'Y') THEN
									lv_error_msg  :=  lv_error_msg || ' Operation Code cannot be NUll if operation is referenced';
									ln_error_flag := 1;
								END IF;
								
						ELSE
						    ln_error_flag := 1;
						END IF; -- dept validation check ends
				    ELSE
						ln_error_flag := 1;
						lv_error_msg  :=  lv_error_msg || ' Operation Sequence is not present in the file';
				  END IF;	-- Operation Seq check ends
			ELSE
			    ln_error_flag := 1;
            END IF;  -- Routing check ends
		 ELSE
		    ln_error_flag := 1;
         END IF; --  ITEM check ends
	  ELSE
	      				ln_error_flag := 1;
	  END IF;  -- ORG ID check ends
	    IF c_valid.COMP_SUBINVENTORY IS NOT NULL
			THEN
			   GET_SUBINVENTORY(c_valid.COMP_SUBINVENTORY,
								lv_subinv_code,
								lv_subinv_err_msg);
								--FND_LOG('step5');

				IF lv_subinv_code IS NOT NULL
				THEN
					GET_LOCATOR(lv_subinv_code,
								c_valid.COMP_LOCATOR,
								lv_locator_code,
								lv_subinv_err_msg);
								--FND_LOG('step6');

	   
							   
		 
						 
			
	   
		  
						  
				END IF; -- locator checking ends
			
			END IF;  --- sub inv code check ends
    FND_LOG('lv_error_msg :'||lv_error_msg);
    IF (ln_error_flag = 1) OR (lv_error_msg IS NOT NULL)
		THEN
		  BEGIN
			    UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL
				 SET process_flag = 'VE',
					 error_msg = lv_error_msg,
					 last_update_date = SYSDATE,
					 last_updated_by = fnd_global.user_id
					 WHERE ROWID = c_valid.row_id
					 AND   request_id = gn_conc_req_id;
					 
			    
		   EXCEPTION
			 WHEN OTHERS
				THEN
				   lv_error_msg := lv_error_msg || SUBSTR(SQLERRM,1,150);
				
									   
										
												   
														 
																							 
			END;
	ELSE
	       BEGIN
			  UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL
				 SET process_flag = 'V',
				     error_msg = lv_subinv_err_msg,
				     oracle_sub_inventory = lv_subinv_code,
					 oracle_locator = lv_locator_code,
					 --error_msg = lv_error_msg,
					 last_update_date = SYSDATE,
					 last_updated_by = fnd_global.user_id
					 WHERE ROWID = c_valid.row_id
					 AND   request_id = gn_conc_req_id;
					
		   EXCEPTION
			 WHEN OTHERS
				THEN
				   lv_error_msg := lv_error_msg || SUBSTR(SQLERRM,1,150);
								
									   
										
												   
														   
																						   
			END;
	
	END IF;
      
      END LOOP;
	  commit;
	 FND_LOG ('After main loop '); 
	 
					  
										
							 
										
							 
													  
	  
		fnd_log('l_update_count :'||l_update_count);
      l_update_count:=0;		
		
	  FOR i IN (SELECT  count(1) as cnt ,assembly_item_number, error_msg
					FROM STGUSR.XX_BOM_ROUT_CNV_STG_TBL
				WHERE process_flag = 'VE'
				AND   request_id    = gn_conc_req_id
				AND error_msg IS NOT NULL
				group by assembly_item_number, error_msg
				)
		LOOP
		    l_update_count := l_update_count+1;
		  	
		   
													
											  
		   BEGIN
			  UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL
				 SET process_flag = 'VE',
				     error_msg = i.error_msg,
				     --error_msg = lv_error_msg,
					 last_update_date = SYSDATE,
					 last_updated_by = fnd_global.user_id
					 WHERE assembly_item_number = i.assembly_item_number
					 AND   request_id = gn_conc_req_id
					 AND   process_flag='V';
				FND_LOG('UPDATE count :'||SQL%ROWCOUNT);
			EXCEPTION
				WHEN OTHERS
					THEN 
					lv_error_msg := lv_error_msg || SUBSTR(SQLERRM,1,150);
					
									   
										
												   
														   
			END;
		END LOOP;
		  fnd_log('l_update_count :'||l_update_count);
  commit;
     FND_LOG ('After Secondary loop '); 
     SELECT COUNT(*)
	 INTO ln_validate 
	  FROM STGUSR.XX_BOM_ROUT_CNV_STG_TBL a
	  WHERE a.process_flag = 'V'
	  AND request_id    = gn_conc_req_id;
     FND_LOG ('After count '); 

     SELECT COUNT(*)
	 INTO ln_error
	 FROM STGUSR.XX_BOM_ROUT_CNV_STG_TBL a 
	 WHERE a.process_flag = 'VE'
	 AND request_id    = gn_conc_req_id;
	FND_LOG ('After count 1'); 
     fnd_file.put_line (fnd_file.LOG,'===========================================================');
     fnd_file.put_line (fnd_file.LOG,'No. of Records                               : '|| ln_total_cnt);
     fnd_file.put_line (fnd_file.LOG,'No. of Validated Records                     : '|| ln_validate);
     fnd_file.put_line (fnd_file.LOG,'No. of Error Records                         : '|| ln_error);
     fnd_file.put_line (fnd_file.LOG,'************************************************************'); 
     fnd_file.put_line (fnd_file.LOG,'+---------------------------------------------------------------------------+'); 
	 FND_OUT('------------------------------------------------------------------------------------------------------------------');
	 FND_OUT('Error Details : ');
	 
	 GET_CONC_DETAILS;
		--Print Output
	   FND_OUT('Concurrent Program Name :'||gv_conc_prog_name);
	   FND_OUT('Concurrent Request ID :'||gn_conc_req_id);
	   FND_OUT('User Name :'||gv_user_name);
	   FND_OUT('Requested Date :'||gd_conc_prog_date);
	   FND_OUT('Completion Date :'||SYSDATE);
       FND_OUT('Record Count :'||ln_total_cnt);
	   FND_OUT('Success Count :'||ln_validate);
	   FND_OUT('Error Count :'||LN_ERROR);
     FND_OUT('------------------------------------------------------------------------------------------------------------------');
	FND_OUT('Error Details : ');
    FND_OUT('ORG_CODE,ITEM_NUM,OPERATION_SEQ,Department_Code,RESOURCE_CODE,Sub Inventory,Locator,Error Message');
	 FOR I in CUR_ERR_STG LOOP
		FND_OUT(I.ORG_CODE||','||I.ASSEMBLY_ITEM_NUMBER||','||I.OPERATION_SEQ||','||i.department_code||','||i.resource_code||','||i.COMP_SUBINVENTORY||','||
																																																												 
																																			  
				i.COMP_LOCATOR||','||I.ERROR_MSG);


	 END LOOP;
	   
	   	   
EXCEPTION
   WHEN OTHERS
   THEN
      fnd_file.
      put_line (fnd_file.LOG,
                'Error while validating data in stage table: ' || SQLERRM);
	     lv_error_msg := lv_error_msg || SUBSTR(SQLERRM,1,150);
		    XX_COMN_CONV_DEBUG_PRC ( p_i_level =>NULL,
							p_i_proc_name => 'BOM Routing',
							p_i_phase => 'Validate Procedure',
							p_i_stgtable => 'XX_BOM_ROUT_CNV_STG_TBL' ,
							p_i_message => 'Error while Vallidating Records: ');
END VALIDATE;

 procedure xx_bom_routing_attachment
AS
    ln_rec_text_cnt   NUMBER;
	ln_text_num       NUMBER;
	ln_seq_text_num   NUMBER;
	ln_text_category_id  NUMBER;
	ln_media_text_id   NUMBER;
	lv_text_attach_data VARCHAR2(1200) := NULL;
	lv_entity_name     VARCHAR2(100) := 'BOM_OPERATION_SEQUENCES';
	lv_out     ROWID;
	LN_DOC_ID  NUMBER;
	L_SO_DESCRIPTION   VARCHAR2(250);
	L_PRI_KEY_ID     NUMBER;
	LV_ERR_MSG VARCHAR2(4000);
	lv_err_code VARCHAR2(2);
	
	CURSOR CUR_OP_SPEC
	  IS
		SELECT STG.ROWID ROW_ID,
    org.ORGANIZATION_ID,
    STG.ASSEMBLY_ITEM_NUMBER,
    STG.OPERATION_SEQ,
    stg.operation_spec
    from 
			STGUSR.xx_bom_rout_cnv_stg_tbl stg
			,org_organization_definitions org
			where stg.process_flag ='P'
			AND stg.org_code=org.organization_code
			AND stg.request_id=gn_conc_req_id
						   
																				
												   
			AND  operation_spec IS NOT NULL
			AND  EXISTS(
			 SELECT COUNT (1)
						  FROM bom_operational_routings b
							, mtl_system_items_b m
				   WHERE     b.assembly_item_id = m.inventory_item_id
						 AND b.organization_id = m.organization_id
						 AND m.segment1 =stg.assembly_item_number
						 AND m.organization_id = org.organization_ID
						 AND alternate_routing_designator IS NULL)
			ORDER BY  ORG_CODE,ASSEMBLY_ITEM_NUMBER,OPERATION_SEQ;
			
	 BEGIN
	    FOR j IN cur_op_spec
		  LOOP
		  ln_rec_text_cnt := ln_rec_text_cnt + 1;
		  ln_text_num := 0;
		  ln_seq_text_num := 0;
		  ln_text_category_id := 0;
		  L_PRI_KEY_ID   := 0;
      LV_ERR_MSG := NULL;
      LV_ERR_CODE := 'S';
		  If j.operation_spec IS NOT NULL THEN
     
			  FND_LOG('ATTACHEMENT - j.assembly_item_number - '||J.ASSEMBLY_ITEM_NUMBER); 
			  FND_LOG('ATTACHEMENT - j.operation_seq - '||J.operation_seq); 
			  FND_LOG('ATTACHEMENT - j.organization_id - '||j.organization_id); 
			   BEGIN
					   SELECT o.operation_sequence_id 
						 INTO l_pri_key_id
						  FROM bom_operational_routings b
							 , mtl_system_items_b m
							 , bom_operation_sequences o
						WHERE     b.assembly_item_id = m.inventory_item_id
						 AND b.organization_id = m.organization_id
						 AND b.routing_sequence_id = o.routing_sequence_id
						 AND m.segment1 = j.assembly_item_number 
						 AND m.organization_id = j.organization_id
						 AND o.operation_seq_num = j.operation_seq
						 AND alternate_routing_designator IS NULL;
						 
						 FND_LOG('ATTACHEMENT - l_pri_key_id :'||l_pri_key_id);
						  
					EXCEPTION
						WHEN OTHERS THEN
								l_pri_key_id :=0;
								LV_ERR_MSG := 'Error while validating Operation Sequence';
								LV_ERR_CODE := 'AE';
				   END;
					IF l_pri_key_id > 0 THEN	   
					      ln_text_num  := fnd_attached_documents_s.NEXTVAL;
						  FND_LOG('ATTACHEMENT - ln_text_num :'||ln_text_num);
						  BEGIN
						  SELECT
							nvl(
								MAX(seq_num),
								0
								) + 10
							   INTO
							   ln_seq_text_num
							   FROM
							   fnd_attached_documents
							   WHERE
							   pk1_value = l_pri_key_id
							   AND
							   entity_name = lv_entity_name;
							EXCEPTION WHEN NO_DATA_FOUND THEN
								ln_seq_text_num := 10;
							WHEN OTHERS THEN 
								ln_seq_text_num := 10;
							END;
								  FND_LOG('ATTACHEMENT - ln_seq_text_num :'||ln_seq_text_num);
							
							   BEGIN
							   SELECT
								category_id
								INTO
								ln_text_category_id
								FROM
								apps.fnd_document_categories_vl
								WHERE
								user_name = 'Operation Attachments'; 
									END;
									
										  FND_LOG('ATTACHEMENT - ln_text_category_id :'||ln_text_category_id);
							  
								ln_media_text_id:= FND_DOCUMENTS_LONG_TEXT_S.NEXTVAL;
								FND_LOG('ATTACHEMENT - ln_media_text_id :'||ln_media_text_id);
								ln_doc_id := fnd_documents_s.NEXTVAL;
								FND_LOG('ATTACHEMENT - ln_doc_id :'||ln_doc_id);
						BEGIN	
							  fnd_documents_pkg.insert_row
										(x_rowid => lv_out,
										 x_document_id => ln_doc_id,
										 x_creation_date => SYSDATE,
										 x_created_by => gn_user_id,
										 x_last_update_date => SYSDATE,
										 x_last_updated_by => gn_user_id,
										 x_last_update_login => gn_user_id,
										 x_datatype_id => 2,
										 x_security_id => j.organization_ID ,--Security ID defined in your Attchments, Usaully SOB ID/ORG_ID
										 x_publish_flag => 'Y', --This flag allow the file to share across multiple organization
										 x_category_id => ln_text_category_id,
										 x_security_type => 1,
										 x_usage_type => 'O',
										 x_language => 'US',
										 x_description => l_so_description,
										 --x_file_name => i.file_name,
										 x_media_id => ln_media_text_id
										  );
							 
						FND_LOG('fnd_documents_pkg.insert_row');
							  -- Description informations will be stored in below table based on languages.
							   fnd_documents_pkg.insert_tl_row
											  (x_document_id => ln_doc_id,
											   x_creation_date => SYSDATE,
											   x_created_by => gn_user_id,
											   x_last_update_date => SYSDATE,
											   x_last_updated_by => gn_user_id,
											   x_last_update_login => gn_user_id,
											   x_language => 'US',
											   x_description => l_so_description
											   );

								FND_LOG('fnd_documents_pkg.insert_tl_row');	   
								fnd_attached_documents_pkg.insert_row
											  (x_rowid => lv_out,
											   x_attached_document_id => ln_text_num,
											   x_document_id => ln_doc_id,
											   x_creation_date => SYSDATE,
											   x_created_by => gn_user_id,
											   x_last_update_date => SYSDATE,
											   x_last_updated_by => gn_user_id,
											   x_last_update_login => gn_user_id,
											   x_seq_num => ln_seq_text_num,
											   x_entity_name => lv_entity_name,
											   x_column1 => NULL,
											   x_pk1_value => l_pri_key_id,
											   x_pk2_value => NULL,
											   x_pk3_value => NULL,
											   x_pk4_value => NULL,
											   x_pk5_value => NULL,
											   x_automatically_added_flag => 'N',
											   x_datatype_id => 2,
											   x_category_id => ln_text_category_id,
											   x_security_type => 1,
											   x_security_id => j.organization_ID , 
											   x_publish_flag => 'Y',
											   x_language => 'US',
											   x_description => l_so_description,
											   x_media_id => ln_media_text_id
												);
							FND_LOG('fnd_attached_documents_pkg.insert_row');	   
											 --COMMIT;
							FND_LOG('operation_spec :'||j.operation_spec);
						BEGIN
						   INSERT INTO fnd_documents_long_text --change begin end
								  (
									media_id,
									long_text
									)
									VALUES
									(
									ln_media_text_id,
									j.operation_spec
									);
						EXCEPTION WHEN OTHERS THEN 
							ROLLBACK;
							LV_ERR_MSG := 'Error while inserting long text';
							LV_ERR_CODE := 'AE';
						END;
							COMMIT;
						 FND_LOG('fnd_attached_documents_pkg.insert_row');	
						EXCEPTION WHEN OTHERS THEN 
							ROLLBACK;
							LV_ERR_MSG := 'Error calling API fnd_attached_documents_pkg.insert_row';
							LV_ERR_CODE := 'AE';
						END;
					END IF;
		  END IF;
      
      UPDATE  STGUSR.XX_BOM_ROUT_CNV_STG_TBL
      SET PROCESS_FLAG = LV_ERR_CODE , ERROR_MSG = 'BOM Routing created. Attachment Error : '||LV_ERR_MSG
      Where rowid = j.row_id;
      
		 END LOOP;
     COMMIT;
  EXCEPTION WHEN OTHERS THEN 
    lv_err_msg := SQLCODE||' - '||SQLERRM;
    FND_LOG('Error During Attachment process :'||lv_err_msg);	
    --FND_OUT('Error During Attachment process :'||lv_err_msg);	
	END  xx_bom_routing_attachment;	

PROCEDURE UPLOAD 
AS
   l_rtg_header_rec       bom_rtg_pub.rtg_header_rec_type
                             := bom_rtg_pub.g_miss_rtg_header_rec;
							 
   l_rtg_revision_tbl     bom_rtg_pub.rtg_revision_tbl_type
                             := bom_rtg_pub.g_miss_rtg_revision_tbl;
							 
   l_operation_tbl        bom_rtg_pub.operation_tbl_type
                             := bom_rtg_pub.g_miss_operation_tbl;
							 
   l_op_resource_tbl      bom_rtg_pub.op_resource_tbl_type 
                             := bom_rtg_pub.g_miss_op_resource_tbl;
							 
   l_sub_resource_tbl     bom_rtg_pub.sub_resource_tbl_type
                             := bom_rtg_pub.g_miss_sub_resource_tbl;
							 
   l_op_network_tbl       bom_rtg_pub.op_network_tbl_type
                             := bom_rtg_pub.g_miss_op_network_tbl;
							 
   l_error_message_list   error_handler.error_tbl_type;
   l_x_return_status      VARCHAR2 (2000);
   l_x_msg_count          NUMBER;
   l_x_rtg_header_rec     bom_rtg_pub.rtg_header_rec_type
                             := bom_rtg_pub.g_miss_rtg_header_rec;
   l_x_rtg_revision_tbl   bom_rtg_pub.rtg_revision_tbl_type
                             := bom_rtg_pub.g_miss_rtg_revision_tbl;
   l_x_operation_tbl      bom_rtg_pub.operation_tbl_type
                             := bom_rtg_pub.g_miss_operation_tbl;
   l_x_op_resource_tbl    bom_rtg_pub.op_resource_tbl_type
                             := bom_rtg_pub.g_miss_op_resource_tbl;
   l_x_sub_resource_tbl   bom_rtg_pub.sub_resource_tbl_type
                             := bom_rtg_pub.g_miss_sub_resource_tbl;
   l_x_op_network_tbl     bom_rtg_pub.op_network_tbl_type
                             := bom_rtg_pub.g_miss_op_network_tbl;
   lv_error_msg           VARCHAR2 (4000);
   lc_org_code            VARCHAR2 (3);
   ln_org_id              NUMBER;
   ln_upload_error        NUMBER;
   ln_upload              NUMBER;
   ----    l_org_name          VARCHAR2(240);
   i                      NUMBER;
   j                      NUMBER;
   k                      NUMBER;
   l                      NUMBER;
   m 					  NUMBER;
   ln_cnt                 NUMBER := 0;
   ln_row_count           NUMBER := 0;
   ln_err_count           NUMBER :=0;
   ln_success_count       NUMBER :=0;
   ln_flag                NUMBER := 1;
   ln_auto_chrg_type      NUMBER;
   ln_schedule_flag       NUMBER;
   lv_dummy_res_code      VARCHAR2(10);
   ln_basis_type 		  NUMBER;
   ln_move_auto_chrg_type NUMBER;

   CURSOR cur_routing_hdr
   IS
      SELECT DISTINCT xbrst.assembly_item_number, ORG_CODE,AT_ROUT_DESIGNATOR,
	                  oracle_sub_inventory, oracle_locator, SER_START_OP_SEQ
        FROM stgusr.XX_BOM_ROUT_CNV_STG_TBL xbrst
       WHERE     xbrst.process_flag = 'V'
	   AND       xbrst.request_id = gn_conc_req_id
																			  
													 
      ;
            

   CURSOR cur_operation_dtl (
      p_i_item VARCHAR2,
	  p_i_org_code VARCHAR2)
   IS
      SELECT DISTINCT
             xbrst.ASSEMBLY_ITEM_NUMBER,
             xbrst.OPERATION_SEQ,
             xbrst.DEPARTMENT_CODE,
			 xbrst.AT_ROUT_DESIGNATOR,
			 xbrst.REFERENCE_FLAG,
			 xbrst.OPTION_DEPENDENT_FLAG,
			 xbrst.BACKFLUSH_FLAG,
			 xbrst.COUNT_POINT_FLAG,
			 xbrst.ROLLUP_FLAG,
			 xbrst.OPERATION_CODE,
			 xbrst.OPERATION_DESC,
			 xbrst.ATTRIBUTE1  ,
			 xbrst.ATTRIBUTE2  ,
			 xbrst.ATTRIBUTE3  ,
			 xbrst.ATTRIBUTE4  ,
			 xbrst.ATTRIBUTE5  ,
			 xbrst.ATTRIBUTE6  ,
			 xbrst.ATTRIBUTE7  ,
			 xbrst.ATTRIBUTE8  ,
			 xbrst.ATTRIBUTE9  ,
			 xbrst.ATTRIBUTE10 ,
			 xbrst.ATTRIBUTE11 ,
			 xbrst.ATTRIBUTE12 ,
			 xbrst.ATTRIBUTE13 ,
			 xbrst.ATTRIBUTE14 ,
			 xbrst.ATTRIBUTE15			 
	  FROM stgusr.XX_BOM_ROUT_CNV_STG_TBL xbrst
			WHERE     xbrst.assembly_item_number = p_i_item
	        AND   xbrst.org_code = p_i_org_code
            AND    xbrst.process_flag = 'V'
			AND       xbrst.request_id = gn_conc_req_id
			 ORDER BY 2
            ;

    CURSOR cur_dept_resource_dtl (p_i_dept_code        VARCHAR2,
                                p_i_item_number      VARCHAR2,
                                p_i_operation_seq    NUMBER)
   IS
        SELECT (ROWNUM*10)DERIVED_REC_SEQ_NUM
		      ,RESOURCE_CODE
		      ,ACTIVITY
			  ,RESOURCE_SEQ_NO
			  ,BASIS_TYPE
			  ,SCHEDULE_FLAG
			  ,AUTOCHARGE_TYPE
			  ,ASSIGNED_UNITS
			  ,USAGE_RATE_OR_AMOUNT
			  ,SETUP_HRS
			  ,MOVE_HRS
			  ,TRANSIT_DAYS
		FROM  stgusr.XX_BOM_ROUT_CNV_STG_TBL
		WHERE assembly_item_number = p_i_item_number
		AND   DEPARTMENT_CODE = p_i_dept_code
		AND   OPERATION_SEQ = p_i_operation_seq
		AND   request_id = gn_conc_req_id
		;
		
	CURSOR CUR_ERR_STG IS
	SELECT 	rowid row_id,
			gn_conc_req_id,
			ASSEMBLY_ITEM_NUMBER,
			ORG_CODE,
            OPERATION_SEQ,
            DEPARTMENT_CODE,
			AT_ROUT_DESIGNATOR,
			REFERENCE_FLAG,
			OPTION_DEPENDENT_FLAG,
			BACKFLUSH_FLAG,
			COUNT_POINT_FLAG,
			ROLLUP_FLAG,
			OPERATION_CODE,
			OPERATION_DESC,
			RESOURCE_CODE,
		    ACTIVITY,
			RESOURCE_SEQ_NO,
			BASIS_TYPE,
			SCHEDULE_FLAG,
			AUTOCHARGE_TYPE,
			ASSIGNED_UNITS,
			USAGE_RATE_OR_AMOUNT,
			SETUP_HRS,
			TRANSIT_DAYS,
      ERROR_MSG
		FROM  stgusr.XX_BOM_ROUT_CNV_STG_TBL
		WHERE 1=1
		AND request_id = gn_conc_req_id
		AND   PROCESS_FLAG in ('E','AE')
		ORDER BY PROCESS_FLAG DESC;
			 

BEGIN
   fnd_file.
   put_line (
      fnd_file.LOG,
      RPAD (
         '***************************************************************************',
         100,
         '*'));
   fnd_file.put_line (fnd_file.LOG, '  Under Upload Process ');
   fnd_file.
   put_line (
      fnd_file.LOG,
      RPAD (
         '***************************************************************************',
         100,
         '*'));

      ln_cnt := 0;
	  UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL 
	    SET request_id = gn_conc_req_id
		WHERE   PROCESS_FLAG = 'V';

      FOR c_rtg_hdr IN cur_routing_hdr
      LOOP
         i := 0;
         j := 0;
		 k := 0;
		 l := 0; -- Added for Move_Hrs value
		 m := 0;
         l_rtg_header_rec := NULL;      -- bom_rtg_pub.g_miss_rtg_header_rec ;
         l_operation_tbl.delete;
         l_op_resource_tbl.delete;
         error_handler.initialize;
         l_error_message_list.delete;
         lv_error_msg := NULL;
		 lv_dummy_res_code := NULL;

         BEGIN
		    ln_org_id := get_org_id (c_rtg_hdr.org_code, lv_error_msg);
			
			lv_dummy_res_code:= GET_MV_HOUR_CODE(c_rtg_hdr.org_code);
			
            APPS.Fnd_Client_Info.set_org_context (ln_org_id);

            ln_cnt := ln_cnt + 1;

            --                l_operation_tbl                     := bom_rtg_pub.g_miss_operation_tbl;
            --                l_op_resource_tbl                   := bom_rtg_pub.g_miss_op_resource_tbl;
			fnd_file.put_line(fnd_file.log , 'step2 : starting header record insert');
			
				l_rtg_header_rec.Assembly_Item_Name     := c_rtg_hdr.assembly_item_number;
				l_rtg_header_rec.Organization_Code      := c_rtg_hdr.org_code;
				l_rtg_header_rec.Alternate_Routing_Code := c_rtg_hdr.AT_ROUT_DESIGNATOR;
				
				IF NVL(c_rtg_hdr.oracle_locator,'X')<>'X'
                   THEN				
						l_rtg_header_rec.Completion_Subinventory := c_rtg_hdr.oracle_sub_inventory;
						l_rtg_header_rec.Completion_Location_Name := c_rtg_hdr.oracle_locator;
				END IF;
				/*IF SUBSTR(c_rtg_hdr.SER_START_OP_SEQ,1,1)='Y' 
				THEN
					l_rtg_header_rec.Ser_Start_Op_Seq         := 1;
				ELSE
				    l_rtg_header_rec.Ser_Start_Op_Seq         := 0;
				END IF;
				*/
				l_rtg_header_rec.Transaction_Type 		:= 'CREATE';
			  
				  fnd_file.put_line(fnd_file.log ,  'Header rec: '||'Assembly_Item_Name | Organization_Code |Alternate_Routing_Code |'||
												l_rtg_header_rec.Assembly_Item_Name ||'|'|| l_rtg_header_rec.Organization_Code||'|'||
												l_rtg_header_rec.Alternate_Routing_Code );
				
				fnd_file.put_line(fnd_file.log , 'step2 : Header record inserted');	

				FOR c_rtg_dtl IN cur_operation_dtl (c_rtg_hdr.assembly_item_number, c_rtg_hdr.org_code)
				LOOP
					ln_row_count := ln_row_count+1;
					fnd_file.put_line(fnd_file.log , 'step3 : Inside operation block');
				   i := i + 1;

				   l_operation_tbl (i).Assembly_Item_Name 			:= c_rtg_hdr.assembly_item_number;
				   l_operation_tbl (i).Organization_Code 			:= c_rtg_hdr.org_code;
				   l_operation_tbl (i).Alternate_Routing_Code 		:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
				   l_operation_tbl (i).Operation_Sequence_Number    := c_rtg_dtl.Operation_seq;
				   l_operation_tbl (i).Transaction_Type 		    := 'CREATE';
				   l_operation_tbl (i).Operation_Type				:= 1; ---Operation_Type:1==>Event,3==>Line Operation
																	
				   l_operation_tbl (i).Standard_Operation_Code      :=  c_rtg_dtl.OPERATION_CODE; -- added on 26-NOV-2020
				   l_operation_tbl (i).Start_Effective_Date 		:= TRUNC(SYSDATE);
				   IF UPPER(c_rtg_dtl.REFERENCE_FLAG) IN ('YES' ,'Y') 
				     THEN
						l_operation_tbl (i).REFERENCE_FLAG := 1;
					ELSE
						l_operation_tbl (i).REFERENCE_FLAG := 2; 
					--END IF; move to end of loop
				   l_operation_tbl (i).Department_Code 				:= c_rtg_dtl.department_code;
				   l_operation_tbl (i).Operation_Description		:= c_rtg_dtl.OPERATION_DESC;
				   l_operation_tbl (i).ATTRIBUTE1					:= c_rtg_dtl.ATTRIBUTE1	;
				   l_operation_tbl (i).ATTRIBUTE2					:= c_rtg_dtl.ATTRIBUTE2	;
				   l_operation_tbl (i).ATTRIBUTE3					:= c_rtg_dtl.ATTRIBUTE3	;
				   l_operation_tbl (i).ATTRIBUTE4					:= c_rtg_dtl.ATTRIBUTE4	;
				   l_operation_tbl (i).ATTRIBUTE5					:= c_rtg_dtl.ATTRIBUTE5	;
				   l_operation_tbl (i).ATTRIBUTE6					:= c_rtg_dtl.ATTRIBUTE6	;
				   l_operation_tbl (i).ATTRIBUTE7					:= c_rtg_dtl.ATTRIBUTE7	;
				   l_operation_tbl (i).ATTRIBUTE8					:= c_rtg_dtl.ATTRIBUTE8	;
				   l_operation_tbl (i).ATTRIBUTE9					:= c_rtg_dtl.ATTRIBUTE9	;
				   l_operation_tbl (i).ATTRIBUTE10					:= c_rtg_dtl.ATTRIBUTE10	;
				   l_operation_tbl (i).ATTRIBUTE11					:= c_rtg_dtl.ATTRIBUTE11	;
				   l_operation_tbl (i).ATTRIBUTE12					:= c_rtg_dtl.ATTRIBUTE12	;
				   l_operation_tbl (i).ATTRIBUTE13					:= c_rtg_dtl.ATTRIBUTE13	;
				   l_operation_tbl (i).ATTRIBUTE14					:= c_rtg_dtl.ATTRIBUTE14	;
				   l_operation_tbl (i).ATTRIBUTE15					:= c_rtg_dtl.ATTRIBUTE15	;
				   
				   IF UPPER(c_rtg_dtl.COUNT_POINT_FLAG) = 'YES'
				     THEN
						l_operation_tbl (i).Count_Point_Type := 1;
					ELSE
						l_operation_tbl (i).Count_Point_Type := 2; 
					END IF;
					
					 IF UPPER(c_rtg_dtl.BACKFLUSH_FLAG) = 'YES'
				     THEN
						l_operation_tbl (i).Backflush_Flag := 1;
					ELSE
						l_operation_tbl (i).Backflush_Flag := 2; 
					END IF;
					
					 IF UPPER(c_rtg_dtl.ROLLUP_FLAG) = 'YES'
				     THEN
						l_operation_tbl (i).Include_In_Rollup := 1;
					ELSE
						l_operation_tbl (i).Include_In_Rollup := 2; 
					END IF;
					
											   
			 
											  
		 
											   
			
					
				  			   
					   fnd_file.put_line(fnd_file.log , 'step4 Operation records inserted seq number '||l_operation_tbl (i).Operation_Sequence_Number);
					  
				

					  FOR cs_res
						 IN cur_dept_resource_dtl (c_rtg_dtl.department_code,
												  c_rtg_hdr.assembly_item_number,
												  c_rtg_dtl.operation_seq)
					  LOOP
							j := j + 1;
							
							-- Added for Basis 
							ln_basis_type:= null;							
							IF UPPER(TRIM(cs_res.BASIS_TYPE)) = 'LOT' THEN
								ln_basis_type := 2;
							END IF;
							-- Deriving Auto Charge Type
							BEGIN
								SELECT LOOKUP_CODE 
								  INTO ln_auto_chrg_type
								FROM fnd_lookup_values 
								WHERE lookup_type='BOM_AUTOCHARGE_TYPE'
								AND   language = USERENV('LANG')
								AND   enabled_flag='Y'
								AND   UPPER(meaning) = UPPER(cs_res.AUTOCHARGE_TYPE);
								
								SELECT LOOKUP_CODE 
								  INTO ln_move_auto_chrg_type
								FROM fnd_lookup_values 
								WHERE lookup_type='BOM_AUTOCHARGE_TYPE'
								AND   language = USERENV('LANG')
								AND   enabled_flag='Y'
								AND   UPPER(meaning) = UPPER('WIP MOVE');
							EXCEPTION 
								WHEN OTHERS THEN
									FND_LOG('Auto Charge Type not defined in Oracle');
									 
										   
											   
													   
																  
			   
							END;
							
						
							
						 IF( (NVL(cs_res.USAGE_RATE_OR_AMOUNT,-1)>=0) AND (NVL(cs_res.SETUP_HRS,-1)>=0) 
							  AND (NVL(cs_res.MOVE_HRS,-1)>=0) -- Added for MOVE_HRS
							)  
							THEN
							--	j := j + 1;
                                FND_LOG('GOING TO 1ST BLOCK');
								FND_LOG('Amount :'||to_number(to_char(cs_res.usage_rate_or_amount,999999.999999)));
								l_op_resource_tbl (j).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
								 l_op_resource_tbl (j).organization_code 		:= c_rtg_hdr.org_code;
								 l_op_resource_tbl (j).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
								 l_op_resource_tbl (j).operation_type 			:= 1;
								 l_op_resource_tbl (j).op_start_effective_date 	:= TRUNC(SYSDATE);
									 --c_rtg_dtl.effectivity_date;
								 l_op_resource_tbl (j).operation_sequence_number :=	c_rtg_dtl.operation_seq;
								 l_op_resource_tbl (j).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM);
								 l_op_resource_tbl (j).transaction_type			 := 'CREATE';
								 l_op_resource_tbl (j).resource_code 			 :=	 cs_res.resource_code;
								 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
								 l_op_resource_tbl (j).activity 				:=  cs_res.ACTIVITY; --'Run';
								 l_op_resource_tbl (j).usage_rate_or_amount     :=	to_number(to_char(cs_res.usage_rate_or_amount,999999.999999));
								 								
			                     l_op_resource_tbl (j).Autocharge_Type          := ln_auto_chrg_type;
								 
								 -- Added for Basis 
								 l_op_resource_tbl (j).Basis_Type          := ln_basis_type;
								 
								 IF cs_res.usage_rate_or_amount=0 
									THEN
									   ln_schedule_flag :=2;
								 ELSE										
									IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
									 THEN
										ln_schedule_flag := 1;
									ELSE
										ln_schedule_flag := 2; 
									END IF;
								 END IF;
								 
								  l_op_resource_tbl (j).Schedule_Flag            := ln_schedule_flag;
																			
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '|| l_op_resource_tbl (j).operation_sequence_number);
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||  l_op_resource_tbl (j).resource_sequence_number);
								
								k := j+1;
								FND_LOG('Amount :'||to_number(to_char(cs_res.SETUP_HRS,999999.999999)));
								l_op_resource_tbl (k).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
								 l_op_resource_tbl (k).organization_code 		:= c_rtg_hdr.org_code;
								 l_op_resource_tbl (k).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
								 l_op_resource_tbl (k).operation_type 			:= 1; -- 2;
								 l_op_resource_tbl (k).op_start_effective_date  := TRUNC(SYSDATE);
								 l_op_resource_tbl (k).operation_sequence_number :=	c_rtg_dtl.operation_seq;
								 l_op_resource_tbl (k).resource_sequence_number :=	10;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 10;
								 l_op_resource_tbl (k).transaction_type		    := 'CREATE';
								 l_op_resource_tbl (k).resource_code 			:=	cs_res.resource_code;
								 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
								 l_op_resource_tbl (k).activity 				:= 'Setup';--'Prerun';
								 l_op_resource_tbl (k).usage_rate_or_amount 	:= to_number(to_char(cs_res.SETUP_HRS,999999.999999));
								
			                     l_op_resource_tbl (k).Autocharge_Type          := ln_auto_chrg_type;
								  -- Added for Basis 
								 l_op_resource_tbl (k).Basis_Type          := ln_basis_type;
								 
								  IF cs_res.SETUP_HRS=0 
									THEN
									   ln_schedule_flag :=2;
								 ELSE										
									IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
									 THEN
										ln_schedule_flag := 1;
									ELSE
										ln_schedule_flag := 2; 
									END IF;
								 END IF;
								 
								  l_op_resource_tbl (k).Schedule_Flag            := ln_schedule_flag;
									
								j:=k;
									
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (k).resource_code);
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (k).operation_sequence_number);
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||  l_op_resource_tbl (k).resource_sequence_number);
									
																					
								l := j+1;
								FND_LOG('Amount :'||to_number(to_char(cs_res.MOVE_HRS,999999.999999)));
								l_op_resource_tbl (l).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
								 l_op_resource_tbl (l).organization_code 		:= c_rtg_hdr.org_code;
								 l_op_resource_tbl (l).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
								 l_op_resource_tbl (l).operation_type 			:= 1; -- 2;
								 l_op_resource_tbl (l).op_start_effective_date  := TRUNC(SYSDATE);
								 l_op_resource_tbl (l).operation_sequence_number :=	c_rtg_dtl.operation_seq;
								 l_op_resource_tbl (l).resource_sequence_number :=	30;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
								 l_op_resource_tbl (l).transaction_type		    := 'CREATE';
								 l_op_resource_tbl (l).resource_code 			:=	lv_dummy_res_code; --cs_res.resource_code;
								 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
								 l_op_resource_tbl (l).activity 				:= 'Move'; --'Prerun';
								 l_op_resource_tbl (l).usage_rate_or_amount 	:= to_number(to_char(cs_res.MOVE_HRS,999999.999999));
								
			                     l_op_resource_tbl (l).Autocharge_Type          := ln_move_auto_chrg_type;
								  -- Added for Basis 
								 l_op_resource_tbl (l).Basis_Type          := ln_basis_type;
								 
								  IF cs_res.MOVE_HRS=0 
									THEN
									   ln_schedule_flag :=2;
								 ELSE										
									IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
									 THEN
										ln_schedule_flag := 1;
									ELSE
										ln_schedule_flag := 2; 
									END IF;
								 END IF;
								 
								  l_op_resource_tbl (l).Schedule_Flag            := ln_schedule_flag;
								
								j:=l;
								IF NVL(cs_res.TRANSIT_DAYS,-1) >= 0 THEN
									 m:= l+1;
									 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
									 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
									 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
									 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
									 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
									 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
									 l_op_resource_tbl (m).resource_sequence_number :=	40;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
									 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
									 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
									 L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
								END IF;
								
								fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (l).resource_code);
								fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '|| l_op_resource_tbl (l).operation_sequence_number);
								fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||  l_op_resource_tbl (l).resource_sequence_number);
																				
							ELSIF  ((NVL(cs_res.USAGE_RATE_OR_AMOUNT,-1)>=0) AND (NVL(cs_res.SETUP_HRS,-1)>=0) 
							        AND (NVL(cs_res.MOVE_HRS,0)=0) )
								THEN
								    FND_LOG('GOING TO 2ND BLOCK');
									FND_LOG('Amount :'||to_number(to_char(cs_res.usage_rate_or_amount,999999.999999)));
								     l_op_resource_tbl (j).assembly_item_name 		:= c_rtg_hdr.assembly_item_number;
									 l_op_resource_tbl (j).organization_code 		:= c_rtg_hdr.org_code;
									 l_op_resource_tbl (j).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
									 l_op_resource_tbl (j).operation_type 			:= 1;
									 l_op_resource_tbl (j).op_start_effective_date 	:= TRUNC(SYSDATE);
										 --c_rtg_dtl.effectivity_date;
									 l_op_resource_tbl (j).operation_sequence_number :=	c_rtg_dtl.operation_seq;
									 l_op_resource_tbl (j).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM);
									 l_op_resource_tbl (j).transaction_type			 := 'CREATE';
									 l_op_resource_tbl (j).resource_code 			 :=	 cs_res.resource_code;
									 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
									 l_op_resource_tbl (j).activity 				:=  cs_res.ACTIVITY; --'Run';
									 l_op_resource_tbl (j).usage_rate_or_amount     :=	to_number(to_char(cs_res.usage_rate_or_amount,999999.999999));
									 
									 l_op_resource_tbl (j).Autocharge_Type          := ln_auto_chrg_type;
									  -- Added for Basis 
									 l_op_resource_tbl (j).Basis_Type          := ln_basis_type;
										
									 IF cs_res.usage_rate_or_amount=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
									 END IF;
									 
									  l_op_resource_tbl (j).Schedule_Flag            := ln_schedule_flag;
													
										fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
									
									k := j+1;
									FND_LOG('Amount :'||to_number(to_char(cs_res.SETUP_HRS,999999.999999)));
									l_op_resource_tbl (k).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
									 l_op_resource_tbl (k).organization_code 		:= c_rtg_hdr.org_code;
									 l_op_resource_tbl (k).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
									 l_op_resource_tbl (k).operation_type 			:= 1; -- 1;
									 l_op_resource_tbl (k).op_start_effective_date  := TRUNC(SYSDATE);
									 l_op_resource_tbl (k).operation_sequence_number :=	c_rtg_dtl.operation_seq;
									 l_op_resource_tbl (k).resource_sequence_number :=	10;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 10;
									 l_op_resource_tbl (k).transaction_type		    := 'CREATE';
									 l_op_resource_tbl (k).resource_code 			:=	cs_res.resource_code;
									 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
									 l_op_resource_tbl (k).activity 				:= 'Setup';--'Prerun';
									 l_op_resource_tbl (k).usage_rate_or_amount 	:= to_number(to_char(cs_res.SETUP_HRS,999999.999999));
									
									 l_op_resource_tbl (k).Autocharge_Type          := ln_auto_chrg_type;
									  -- Added for Basis 
									  l_op_resource_tbl (k).Basis_Type          := ln_basis_type;
									 
									  IF cs_res.SETUP_HRS=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
									 END IF;
									  l_op_resource_tbl (k).Schedule_Flag            := ln_schedule_flag;
		  
									j:=k;
									IF NVL(cs_res.TRANSIT_DAYS,-1) >= 0 THEN
										 m:= k+1;
										 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
										 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
										 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
										 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
										 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
										 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
										 l_op_resource_tbl (m).resource_sequence_number :=	30;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
										 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
										 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
										 L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
									END IF;
									
									
									
							ELSIF  ((NVL(cs_res.USAGE_RATE_OR_AMOUNT,-1)>=0) AND (NVL(cs_res.SETUP_HRS,0)=0) 
							        AND (NVL(cs_res.MOVE_HRS,-1)>=0) )
								THEN
								    FND_LOG('GOING TO 3RD BLOCK');
									FND_LOG('Amount :'||to_number(to_char(cs_res.usage_rate_or_amount,999999.999999)));
								     l_op_resource_tbl (j).assembly_item_name 		:= c_rtg_hdr.assembly_item_number;
									 l_op_resource_tbl (j).organization_code 		:= c_rtg_hdr.org_code;
									 l_op_resource_tbl (j).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
									 l_op_resource_tbl (j).operation_type 			:= 1;
									 l_op_resource_tbl (j).op_start_effective_date 	:= TRUNC(SYSDATE);
										 --c_rtg_dtl.effectivity_date;
									 l_op_resource_tbl (j).operation_sequence_number :=	c_rtg_dtl.operation_seq;
									 l_op_resource_tbl (j).resource_sequence_number :=	10;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM);
									 l_op_resource_tbl (j).transaction_type			 := 'CREATE';
									 l_op_resource_tbl (j).resource_code 			 :=	 cs_res.resource_code;
									 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
									 l_op_resource_tbl (j).activity 				:=  cs_res.ACTIVITY; --'Run';
									 l_op_resource_tbl (j).usage_rate_or_amount     :=	to_number(to_char(cs_res.usage_rate_or_amount,999999.999999));
									 
									l_op_resource_tbl (j).Autocharge_Type          := ln_auto_chrg_type;
									-- Added for Basis 
									  l_op_resource_tbl (j).Basis_Type          := ln_basis_type;
										
									 
									IF cs_res.usage_rate_or_amount=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
									 END IF;
									 
									  l_op_resource_tbl (j).Schedule_Flag            := ln_schedule_flag;
													
										fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
									
									k := j+1;
									FND_LOG('Amount :'||to_number(to_char(cs_res.MOVE_HRS,999999.999999)));
									l_op_resource_tbl (k).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
									 l_op_resource_tbl (k).organization_code 		:= c_rtg_hdr.org_code;
									 l_op_resource_tbl (k).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
									 l_op_resource_tbl (k).operation_type 			:= 1; -- 2;
									 l_op_resource_tbl (k).op_start_effective_date  := TRUNC(SYSDATE);
									 l_op_resource_tbl (k).operation_sequence_number :=	c_rtg_dtl.operation_seq;
									 l_op_resource_tbl (k).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) +10;
									 l_op_resource_tbl (k).transaction_type		    := 'CREATE';
									 l_op_resource_tbl (k).resource_code 			:=	lv_dummy_res_code; --cs_res.resource_code;
									 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
									 l_op_resource_tbl (k).activity 				:= 'Move';
									 l_op_resource_tbl (k).usage_rate_or_amount 	:= to_number(to_char(cs_res.MOVE_HRS,999999.999999));
									
									 l_op_resource_tbl (k).Autocharge_Type          := ln_move_auto_chrg_type;
									 -- Added for Basis 
									  l_op_resource_tbl (k).Basis_Type          := ln_basis_type;
									 
									 IF cs_res.MOVE_HRS=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
									 END IF;
									  l_op_resource_tbl (k).Schedule_Flag            := ln_schedule_flag;
										
									j:=k;
									IF NVL(cs_res.TRANSIT_DAYS,-1) >= 0 THEN
										 m:= k+1;
										 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
										 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
										 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
										 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
										 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
										 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
										 l_op_resource_tbl (m).resource_sequence_number :=	30;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
										 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
										 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
										 L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
									END IF;
									
									
									
							
								ELSIF  ((NVL(cs_res.USAGE_RATE_OR_AMOUNT,0)=0) AND (NVL(cs_res.SETUP_HRS,-1)>=0) 
							        AND (NVL(cs_res.MOVE_HRS,-1)>=0) )
								THEN
								     FND_LOG('GOING TO 4TH BLOCK');
									 FND_LOG('Amount :'||to_number(to_char(cs_res.SETUP_HRS,999999.999999)));
								     l_op_resource_tbl (j).assembly_item_name 		:= c_rtg_hdr.assembly_item_number;
									 l_op_resource_tbl (j).organization_code 		:= c_rtg_hdr.org_code;
									 l_op_resource_tbl (j).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
									 l_op_resource_tbl (j).operation_type 			:= 1;
									 l_op_resource_tbl (j).op_start_effective_date 	:= TRUNC(SYSDATE);
										 --c_rtg_dtl.effectivity_date;
									 l_op_resource_tbl (j).operation_sequence_number :=	c_rtg_dtl.operation_seq;
									 l_op_resource_tbl (j).resource_sequence_number :=	10;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM);
									 l_op_resource_tbl (j).transaction_type			 := 'CREATE';
									 l_op_resource_tbl (j).resource_code 			 :=	 cs_res.resource_code;
									 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
									 l_op_resource_tbl (j).activity 				:=  'Setup'; --'Prerun';--'Run';
									 l_op_resource_tbl (j).usage_rate_or_amount     :=	to_number(to_char(cs_res.SETUP_HRS,999999.999999));
									 
									 l_op_resource_tbl (j).Autocharge_Type          := ln_auto_chrg_type;
									 -- Added for Basis 
									  l_op_resource_tbl (j).Basis_Type          := ln_basis_type;
										
									 IF cs_res.SETUP_HRS=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
									 END IF;
									 l_op_resource_tbl (j).Schedule_Flag            := ln_schedule_flag;
													
										fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
									
									k := j+1;
									 FND_LOG('Amount :'||to_number(to_char(cs_res.MOVE_HRS,999999.999999)));
									l_op_resource_tbl (k).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
									 l_op_resource_tbl (k).organization_code 		:= c_rtg_hdr.org_code;
									 L_OP_RESOURCE_TBL (K).ALTERNATE_ROUTING_CODE	:= C_RTG_HDR.AT_ROUT_DESIGNATOR;
									 l_op_resource_tbl (k).operation_type 			:= 1; -- 2;
									 l_op_resource_tbl (k).op_start_effective_date  := TRUNC(SYSDATE);
									 l_op_resource_tbl (k).operation_sequence_number :=	c_rtg_dtl.operation_seq;
									 l_op_resource_tbl (k).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) +10;
									 l_op_resource_tbl (k).transaction_type		    := 'CREATE';
									 l_op_resource_tbl (k).resource_code 			:=	lv_dummy_res_code; --cs_res.resource_code;
									 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
									 l_op_resource_tbl (k).activity 				:= 'Move';
									 l_op_resource_tbl (k).usage_rate_or_amount 	:= to_number(to_char(cs_res.MOVE_HRS,999999.999999));
									 
									 l_op_resource_tbl (k).Autocharge_Type          := ln_move_auto_chrg_type;
									 -- Added for Basis 
									  l_op_resource_tbl (k).Basis_Type          := ln_basis_type;
									 
									  IF cs_res.MOVE_HRS=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
										l_op_resource_tbl (k).Schedule_Flag            := ln_schedule_flag;
									END IF;
										
									j:=k;
									IF NVL(CS_RES.TRANSIT_DAYS,-1) >= 0 THEN
										 m:= j+1;
                     					 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
										 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
										 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
										 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
										 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
										 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
										 l_op_resource_tbl (m).resource_sequence_number :=	30;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
										 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
										 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
										 L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
									END IF;
												
							ELSIF  ((NVL(cs_res.USAGE_RATE_OR_AMOUNT,-1)>=0) AND (NVL(cs_res.SETUP_HRS,0)=0) 
									AND (NVL(cs_res.MOVE_HRS,0)=0) )
							   THEN
							         FND_LOG('GOING TO 5TH BLOCK');
									  FND_LOG('Amount :'||to_number(to_char(cs_res.usage_rate_or_amount,999999.999999)));
									l_op_resource_tbl (j).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
									l_op_resource_tbl (j).organization_code 		:= c_rtg_hdr.org_code;
									l_op_resource_tbl (j).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
									l_op_resource_tbl (j).operation_type 			:= 1;
									l_op_resource_tbl (j).op_start_effective_date   := TRUNC(SYSDATE);
									l_op_resource_tbl (j).operation_sequence_number := c_rtg_dtl.operation_seq;
									l_op_resource_tbl (j).resource_sequence_number  := 10;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM);
									l_op_resource_tbl (j).transaction_type			:= 'CREATE';
									l_op_resource_tbl (j).resource_code             := cs_res.resource_code;
								 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
									l_op_resource_tbl (j).activity				    :=   cs_res.ACTIVITY; --'Run';
									l_op_resource_tbl (j).usage_rate_or_amount 		:=	to_number(to_char(cs_res.usage_rate_or_amount,999999.999999));
									
			                        l_op_resource_tbl (j).Autocharge_Type          := ln_auto_chrg_type;
									-- Added for Basis 
									  l_op_resource_tbl (j).Basis_Type          := ln_basis_type;
									
										 
									 IF cs_res.usage_rate_or_amount=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
									END IF;
										
									l_op_resource_tbl (j).Schedule_Flag            := ln_schedule_flag;
									
									
									IF NVL(cs_res.TRANSIT_DAYS,-1) >= 0 THEN
										 m:= j+1;
										 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
										 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
										 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
										 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
										 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
										 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
										 l_op_resource_tbl (m).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
										 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
										 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
										L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
									END IF;
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
									
								
									
							ELSIF  ((NVL(cs_res.SETUP_HRS,-1)>=0) AND (NVL(cs_res.USAGE_RATE_OR_AMOUNT,0)=0)  
									AND (NVL(cs_res.MOVE_HRS,0)=0) )
							   THEN
							       FND_LOG('GOING TO 6TH BLOCK');
								     FND_LOG('Amount :'||to_number(to_char(cs_res.SETUP_HRS,999999.999999)));
									l_op_resource_tbl (j).assembly_item_name 			:= c_rtg_hdr.assembly_item_number;
								 l_op_resource_tbl (j).organization_code				:= c_rtg_hdr.org_code;
								 l_op_resource_tbl (j).Alternate_Routing_Code			:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
								 l_op_resource_tbl (j).operation_type 					:= 1;
								 l_op_resource_tbl (j).op_start_effective_date 			:= TRUNC(SYSDATE);
									  --c_rtg_dtl.effectivity_date;
								 l_op_resource_tbl (j).operation_sequence_number 		:= c_rtg_dtl.operation_seq;
								 l_op_resource_tbl (j).resource_sequence_number 		:= 10;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM);
								 l_op_resource_tbl (j).transaction_type 				:= 'CREATE';
								 L_OP_RESOURCE_TBL (J).RESOURCE_CODE 					:= CS_RES.RESOURCE_CODE;
								 l_op_resource_tbl (j).activity 						:= 'Setup';
								 l_op_resource_tbl (j).usage_rate_or_amount 			:=	to_number(to_char(cs_res.SETUP_HRS,999999.999999));
								
			                     l_op_resource_tbl (j).Autocharge_Type          := ln_auto_chrg_type;
								 -- Added for Basis 
									  l_op_resource_tbl (j).Basis_Type          := ln_basis_type;
								 
								  IF cs_res.SETUP_HRS=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
									END IF;
										 l_op_resource_tbl (j).Schedule_Flag            :=ln_schedule_flag;
														
									IF NVL(cs_res.TRANSIT_DAYS,-1) >= 0 THEN
										 m:= j+1;
										 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
										 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
										 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
										 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
										 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
										 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
										 l_op_resource_tbl (m).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
										 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
										 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
										 L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
							END IF;	
									
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
									
												
							ELSIF  ((NVL(cs_res.MOVE_HRS,-1)>=0) AND (NVL(cs_res.USAGE_RATE_OR_AMOUNT,0)=0)  
									AND (NVL(cs_res.SETUP_HRS,0)=0) )
							   THEN
							       FND_LOG('GOING TO 7TH BLOCK');
								    FND_LOG('Amount :'||to_number(to_char(cs_res.MOVE_HRS,999999.999999)));
									l_op_resource_tbl (j).assembly_item_name 			:= c_rtg_hdr.assembly_item_number;
								 l_op_resource_tbl (j).organization_code				:= c_rtg_hdr.org_code;
								 l_op_resource_tbl (j).Alternate_Routing_Code			:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
								 l_op_resource_tbl (j).operation_type 					:= 1;
								 l_op_resource_tbl (j).op_start_effective_date 			:= TRUNC(SYSDATE);
									  --c_rtg_dtl.effectivity_date;
								 l_op_resource_tbl (j).operation_sequence_number 		:= c_rtg_dtl.operation_seq;
								 l_op_resource_tbl (j).resource_sequence_number 		:= 10;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) ;
								 l_op_resource_tbl (j).transaction_type 				:= 'CREATE';
								 l_op_resource_tbl (j).resource_code 					:= lv_dummy_res_code; --cs_res.resource_code;
								 --                    l_op_resource_tbl(j).Alternate_Routing_Code :=  p_alt_rtg_des;
								 l_op_resource_tbl (j).activity 						:= 'Move'; --'Prerun';
								 l_op_resource_tbl (j).usage_rate_or_amount 			:=	to_number(to_char(cs_res.MOVE_HRS,999999.999999));
								
			                     l_op_resource_tbl (j).Autocharge_Type          := ln_move_auto_chrg_type;
								 -- Added for Basis 
									  l_op_resource_tbl (j).Basis_Type          := ln_basis_type;
								 
								  IF cs_res.MOVE_HRS=0 
									THEN
									   ln_schedule_flag :=2;
									 ELSE										
										IF UPPER(cs_res.SCHEDULE_FLAG) = 'YES'
										 THEN
											ln_schedule_flag := 1;
										ELSE
											ln_schedule_flag := 2; 
										END IF;
										  l_op_resource_tbl (j).Schedule_Flag            := ln_schedule_flag;
									  END IF;
														
									IF NVL(cs_res.TRANSIT_DAYS,-1) >= 0 THEN
										 m:= j+1;
										 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
										 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
										 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
										 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
										 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
										 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
										 l_op_resource_tbl (m).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
										 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
										 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
										 L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
									END IF;
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
																				
								ELSE
								    FND_LOG('GOING TO 8TH BLOCK');
									FND_LOG('Amount :'||to_number(to_char(cs_res.usage_rate_or_amount,999999.999999)));
																						
																		   
																						
														
																		   
																					  
																															 
																		  
																					  
																							 
																  
																															   
		 
																								  
							
																	  
													
									IF NVL(cs_res.TRANSIT_DAYS,-1) >= 0 THEN
										 m:= j;--+1;
										 l_op_resource_tbl (m).assembly_item_name 		:=	c_rtg_hdr.assembly_item_number;
										 l_op_resource_tbl (m).organization_code 		:= c_rtg_hdr.org_code;
										 l_op_resource_tbl (m).Alternate_Routing_Code	:= c_rtg_hdr.AT_ROUT_DESIGNATOR;
										 l_op_resource_tbl (m).operation_type 			:= 1; -- 2;
										 l_op_resource_tbl (m).op_start_effective_date  := TRUNC(SYSDATE);
										 l_op_resource_tbl (m).operation_sequence_number :=	c_rtg_dtl.operation_seq;
										 l_op_resource_tbl (m).resource_sequence_number :=	20;--NVL(cs_res.resource_seq_no,cs_res.DERIVED_REC_SEQ_NUM) + 20;
										 l_op_resource_tbl (m).transaction_type		    := 'CREATE';
										 l_op_resource_tbl (m).resource_code 			:=	'TRANSITDAY'; --cs_res.resource_code;
										 L_OP_RESOURCE_TBL (M).USAGE_RATE_OR_AMOUNT 	:= CS_RES.TRANSIT_DAYS;
										 IF cs_res.TRANSIT_DAYS > 0 THEN
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 1;
										 ELSE 
										  L_OP_RESOURCE_TBL (M).SCHEDULE_FLAG            := 2;
										 END IF;
										j:=m;
									END IF;
																						 
			 
									fnd_file.put_line(fnd_file.log , 'step5 Operation records inserted resource code '||l_op_resource_tbl (j).resource_code);
									
								
							END IF;
					
					  END LOOP;
				   END IF;
				END LOOP;

            Error_Handler.Initialize;
			
			fnd_file.put_line(fnd_file.log, 'ln_cnt :'||ln_cnt);

            IF ln_cnt > 0
            THEN
               Bom_Rtg_Pub.
               Process_Rtg (p_bo_identifier        => 'RTG',
                            p_api_version_number   => 1.0,
                            p_init_msg_list        => FALSE,
                            p_rtg_header_rec       => l_rtg_header_rec,
                            p_rtg_revision_tbl     => l_rtg_revision_tbl,
                            p_operation_tbl        => l_operation_tbl,
                            p_op_resource_tbl      => l_op_resource_tbl,
                            p_sub_resource_tbl     => l_sub_resource_tbl,
                            p_op_network_tbl       => l_op_network_tbl,
                            x_rtg_header_rec       => l_x_rtg_header_rec,
                            x_rtg_revision_tbl     => l_x_rtg_revision_tbl,
                            x_operation_tbl        => l_x_operation_tbl,
                            x_op_resource_tbl      => l_x_op_resource_tbl,
                            x_sub_resource_tbl     => l_x_sub_resource_tbl,
                            x_op_network_tbl       => l_x_op_network_tbl,
                            x_return_status        => l_x_return_status,
                            x_msg_count            => l_x_msg_count,
                            p_debug                => 'N',
                            p_output_dir           => NULL,
                            p_debug_filename       => NULL);
              
			  Error_Handler.Get_message_list (l_error_message_list);

																																					   
				 
               IF (l_x_return_status <> FND_API.G_RET_STS_SUCCESS)
               THEN
                  --                    -- Error Processing
                FOR i IN 1 .. l_x_msg_count
                  LOOP
                     lv_error_msg := lv_error_msg||
                        SUBSTR (l_error_message_list (i).MESSAGE_TEXT,
                                1,
                                500);
                    
												   
										   
											
													   
																  
			   
					FND_LOG('BOM Routing API Error: '||c_rtg_hdr.assembly_item_number||' '||c_rtg_hdr.org_code||' '||lv_error_msg);											
                  END LOOP;

                 -- ROLLBACK;
               ELSE
                   COMMIT;
               END IF;
              			   
			   BEGIN
				   UPDATE stgusr.XX_BOM_ROUT_CNV_STG_TBL
					  SET error_msg = lv_error_msg,
						  process_flag = DECODE (lv_error_msg, NULL, 'P', 'E'),
						  last_update_date = SYSDATE,
						  last_updated_by = fnd_global.user_id,
						  request_id = gn_conc_req_id
						WHERE     assembly_item_number = c_rtg_hdr.assembly_item_number
						  AND process_flag = 'V'
						  AND request_id = gn_conc_req_id
					   	  AND ORG_CODE = c_rtg_hdr.ORG_CODE;
				EXCEPTION
					WHEN OTHERS
						THEN
						    lv_error_msg := lv_error_msg || SUBSTR(1,SQLERRM,200);
							
										   
											
													   
																   
				
				END;

               COMMIT;

             
            END IF;
        END;   
        lv_error_msg := NULL;		
      END LOOP;
 
        BEGIN
			xx_bom_routing_attachment;
		EXCEPTION
			WHEN OTHERS THEN
				 lv_error_msg := lv_error_msg || 'Exception in xx_bom_routing_attachment'||SUBSTR(1,SQLERRM,200);
							
										   
													 
													   
																   
				
		END;
   		-----------------------------
		--Get Success and Error Count
		-----------------------------
		SELECT
            SUM(DECODE(
                process_flag,
                'P',
                1,
				'S',
                1,
                0
            ) ),
            SUM(DECODE(
                process_flag,
                'E',
                1,
                0
            ) )
        INTO
            ln_success_count,ln_err_count
        FROM
            STGUSR.XX_BOM_ROUT_CNV_STG_TBL
        WHERE 
			request_id = gn_conc_req_id;
		-----------------------------
   
   

		
				GET_CONC_DETAILS;
	--Print Output
			   FND_OUT('Concurrent Program Name :'||gv_conc_prog_name);
			   FND_OUT('Concurrent Request ID :'||gn_conc_req_id);
			   FND_OUT('User Name :'||gv_user_name);
			   FND_OUT('Requested Date :'||gd_conc_prog_date);
			   FND_OUT('Completion Date :'||SYSDATE);
			   FND_OUT('Total Header Record Count :'||ln_cnt);
			   FND_OUT('Total Line Record Count  :'||ln_row_count);
			   FND_OUT('Success Count for Line records :'||ln_success_count);
			   FND_OUT('Error Count :'||ln_err_count);
	--Print all errors into logCUR_ERR_STG
	FND_OUT('------------------------------------------------------------------------------------------------------------------');
	FND_OUT('Error Details : ');
		FND_OUT('ITEM_NUMBER,ORG_CODE, AT_ROUT_DESIGNATOR,REFERENCE_FLAG,OPTION_DEPENDENT_FLAG,BACKFLUSH_FLAG,COUNT_POINT_FLAG,ROLLUP_FLAG,OPERATION_CODE,OPERATION_DESC,RESOURCE_CODE,RESOURCE_SEQ_NO,BASIS_TYPE,'
					  ||' SCHEDULE_FLAG,AUTOCHARGE_TYPE, ASSIGNED_UNITS,USAGE_RATE_OR_AMOUNT, SETUP_HRS, Error Message');
    FOR I in CUR_ERR_STG LOOP
			
				FND_OUT(I.ASSEMBLY_ITEM_NUMBER||','||I.ORG_CODE||','||I.AT_ROUT_DESIGNATOR
				      ||','||I.REFERENCE_FLAG||','||I.OPTION_DEPENDENT_FLAG||','||I.BACKFLUSH_FLAG
					  ||','||I.COUNT_POINT_FLAG||','||I.ROLLUP_FLAG||','||I.OPERATION_CODE||','||I.OPERATION_DESC
					  ||','||I.RESOURCE_CODE||','||I.RESOURCE_SEQ_NO||','||I.BASIS_TYPE
					  ||','||I.SCHEDULE_FLAG||','||I.AUTOCHARGE_TYPE||','||I.ASSIGNED_UNITS
					   ||','||I.USAGE_RATE_OR_AMOUNT||','||I.SETUP_HRS||','||I.ERROR_MSG);

		END LOOP;

EXCEPTION
   WHEN OTHERS
   THEN
      fnd_file.
      put_line (fnd_file.LOG,
                'Error while uploading data in stage table' || SQLERRM);
END UPLOAD;


PROCEDURE MAIN_PRC(
        errbuf OUT VARCHAR2,
        retcode OUT NUMBER,
        p_run_mode     IN VARCHAR2
         )
AS
    l_to_org_id NUMBER;
	
BEGIN

FND_LOG ('MAIN');
 IF p_run_mode = 'VALIDATE' THEN   
   FND_LOG ('Before Validate');
        VALIDATE ; 
  ELSIF p_run_mode = 'TRANSFER' THEN
        UPLOAD ; 
 END IF;


EXCEPTION

WHEN OTHERS THEN
    fnd_file.put_line (fnd_file.LOG, 'Error while validating/uploading data of stage table'|| sqlerrm);
    retcode :=-1;
    errbuf  := 'Error from main procedure ' || sqlerrm;
	XX_COMN_CONV_DEBUG_PRC ( p_i_level =>NULL,
												p_i_proc_name => 'BOM Routing',
												p_i_phase => 'Upload Procedure',
												p_i_stgtable => 'XX_BOM_ROUT_CNV_STG_TBL' ,
												p_i_message => errbuf
											);  

END MAIN_PRC;

END XX_BOM_ROUTING_CONV_PKG;
/
