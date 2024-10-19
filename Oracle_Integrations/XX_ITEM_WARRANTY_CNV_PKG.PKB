	create or replace 
	PACKAGE BODY    XX_ITEM_WARRANTY_CNV_PKG
	AS
		  gn_request_id NUMBER := fnd_global.CONC_REQUEST_ID;
	  gn_user_id NUMBER := FND_GLOBAL.USER_ID;
	  PROCEDURE get_conc_details (p_req_id IN NUMBER
								 ,x_con_prog_date OUT DATE
								 ,x_conc_prog_name OUT VARCHAR2
								 ,x_user_name OUT VARCHAR2
								 )
	  AS
	  BEGIN
		SELECT fcr.request_date
			  ,fcp.user_concurrent_program_name --manoj
		INTO  	x_con_prog_date,x_conc_prog_name
		FROM 	fnd_concurrent_requests fcr,
				fnd_concurrent_programs_tl fcp
		WHERE 	fcr.request_id = gn_request_id
				AND fcp.concurrent_program_id = fcr.concurrent_program_id
				AND fcp.language = USERENV('LANG');
		
		SELECT 	user_name 
		INTO 	x_user_name
		FROM 	fnd_user
		WHERE 	user_id = gn_user_id;
	  
		EXCEPTION 
		WHEN OTHERS THEN
		  xx_comn_conv_debug_prc ( p_i_level =>NULL,
								p_i_proc_name => 'xx_item_warranty_cnv_pkg',
								p_i_phase => 'get_conc_details',
								p_i_stgtable => 'stgusr.XX_ITEM_WARRANTY_STG' ,
								p_i_message => 'Error :'||SQLCODE||SQLERRM);
		END get_conc_details;
		
	 --/****************************************************************************************************************
	-- * procedure  : validate_org_code                                                                         *
	-- * Purpose   : This procedure will check if the org code is setup in oracle.                          *
	-- ****************************************************************************************************************/
	PROCEDURE validate_org_code(p_org_code IN VARCHAR2,p_org_id OUT NUMBER,p_valid_org OUT VARCHAR2,p_error_msg IN OUT VARCHAR2)
	 AS
	  ln_cnt NUMBER;
	   BEGIN
		 SELECT COUNT(1)
		 INTO ln_cnt
		 FROM mtl_parameters mp
		 WHERE mp.organization_code = p_org_code;
		 IF ln_cnt > 0 THEN
		   p_valid_org := 'T';
		   SELECT organization_id
		   INTO p_org_id
		   FROM mtl_parameters mp
		   WHERE mp.organization_code = p_org_code;
		 ELSE
		   p_valid_org := 'F';
		   p_error_msg := p_error_msg||'The Organization Code is Invalid';
		 END IF;
	 EXCEPTION
		WHEN OTHERS THEN
		  p_error_msg := p_error_msg||'Problem in determining organization code validity due to: '||SQLERRM;
		  p_valid_org := 'F';
	END validate_org_code;

	--/****************************************************************************************************************
	-- * Function  : validate_item_number                                                                         *
	-- * Purpose   : This Function will check if the item number is setup in oracle.                          *
	-- ****************************************************************************************************************/
	  
	 FUNCTION validate_item_number(p_org_id IN NUMBER,
								   p_item_number IN VARCHAR2,
								   p_u8_number OUT NUMBER,
								   p_error_msg IN OUT VARCHAR2)
	  RETURN VARCHAR2
	  AS
	   ln_cnt NUMBER;
	   BEGIN
			 SELECT COUNT(1)
			 INTO ln_cnt
			 FROM mtl_system_items_b
			 WHERE inventory_item_status_code = 'Active'
			 AND organization_id = p_org_id
			 AND segment1 = p_item_number
			 AND NVL(start_date_active,(SYSDATE-1)) < SYSDATE
			 AND NVL(end_date_active,(SYSDATE+1)) > SYSDATE;
			 
				 SELECT COUNT(1)
				 INTO p_u8_number
				 FROM mtl_cross_references
				 WHERE cross_reference = p_item_number
				 AND cross_reference_type = 'OSSA SALES CODE';
				 
			 IF ln_cnt > 0 or p_u8_number > 0 THEN
			  RETURN 'T';
			 ELSE
			  p_error_msg := p_error_msg||'The item number is Invalid';
			  RETURN 'F';
			 END IF;
	  
	EXCEPTION
		WHEN OTHERS THEN
		  p_error_msg := p_error_msg||'Problem in determining Item Number validity due to: '||SQLERRM;
		  RETURN 'F';
	END validate_item_number;

	--/****************************************************************************************************************
	-- * PROCEDURE  : validate_u8_item                                                                         *
	-- * Purpose   : This procedure will derive the oracle inventory item id in oracle.                          *
	-- ****************************************************************************************************************/	 

	  PROCEDURE validate_u8_item(p_item_number IN VARCHAR2,p_organization_id IN NUMBER,p_inventory_item OUT NUMBER,p_valid_u8_item OUT VARCHAR2,p_error_msg IN OUT VARCHAR2)
	  AS
	  ln_cnt NUMBER;
	   BEGIN
		SELECT inventory_item_id
		INTO p_inventory_item
		FROM mtl_cross_references
		WHERE cross_reference = p_item_number
		AND cross_reference_type = 'OSSA SALES CODE';
		
		if p_inventory_item is not null then
		SELECT COUNT(1)
			 INTO ln_cnt
			 FROM mtl_system_items_b
			 WHERE inventory_item_status_code = 'Active'
			 AND organization_id = p_organization_id
			 AND inventory_item_id = p_inventory_item
			 AND NVL(start_date_active,(SYSDATE-1)) < SYSDATE
			 AND NVL(end_date_active,(SYSDATE+1)) > SYSDATE;
		IF ln_cnt >0 THEN
		
		p_valid_u8_item := 'T';
		ELSE 
		p_error_msg := p_error_msg||'u8 item not defined for the given organization ';
		p_valid_u8_item := 'F';
		END IF;
		else
		p_valid_u8_item := 'F';
		END IF;
		EXCEPTION
		
		WHEN too_many_rows	THEN
	   BEGIN
		SELECT  msi.inventory_item_id
		INTO   p_inventory_item
		FROM   mtl_cross_references mcr, 
				mtl_system_items msi
		WHERE  1=1
			   AND MCR.INVENTORY_ITEM_ID = MSI.INVENTORY_ITEM_ID
			   AND MSI.ORGANIZATION_ID = p_organization_id
			   AND MSI.BOM_ITEM_TYPE = 1
			   AND MCR.cross_reference = p_item_number
			   AND MCR.cross_reference_type = 'OSSA SALES CODE';

		EXCEPTION	   
		WHEN OTHERS THEN
			  p_error_msg := p_error_msg||'Problem in determining U8 Inventory Item Id validity due to: '||SQLERRM;
		  p_valid_u8_item := 'F';
		END;
		if p_inventory_item is not null then
		SELECT COUNT(1)
			 INTO ln_cnt
			 FROM mtl_system_items_b
			 WHERE inventory_item_status_code = 'Active'
			 AND organization_id = p_organization_id
			 AND inventory_item_id = p_inventory_item
			 AND NVL(start_date_active,(SYSDATE-1)) < SYSDATE
			 AND NVL(end_date_active,(SYSDATE+1)) > SYSDATE;
		IF ln_cnt >0 THEN
		
		p_valid_u8_item := 'T';
		ELSE 
		p_error_msg := p_error_msg||'u8 item not defined for the given organization ';
		p_valid_u8_item := 'F';
		END IF;
		else
		p_valid_u8_item := 'F';
		END IF;
		WHEN OTHERS THEN
		  p_error_msg := p_error_msg||'Problem in determining U8 Inventory Item Id validity due to: '||SQLERRM;
		  p_valid_u8_item := 'F';
	  END validate_u8_item;



	--/****************************************************************************************************************
	-- * PROCEDURE  : validate_inv_item                                                                         *
	-- * Purpose   : This procedure will derive the oracle inventory item id in oracle.                          *
	-- ****************************************************************************************************************/	 

	  PROCEDURE validate_inv_item(p_item_number IN VARCHAR2,p_organization_id IN NUMBER,p_inventory_item OUT NUMBER,p_valid_inv_item OUT VARCHAR2,p_error_msg IN OUT VARCHAR2)
	  AS
	   BEGIN
		SELECT inventory_item_id
		INTO p_inventory_item
		FROM mtl_system_items_b
		WHERE organization_id = p_organization_id
		  AND segment1 = p_item_number
		AND NVL(start_date_active,(SYSDATE-1)) < SYSDATE
		AND NVL(end_date_active,(SYSDATE+1)) > SYSDATE;
		if p_inventory_item is not null then
		p_valid_inv_item := 'T';
		else
		p_valid_inv_item := 'F';
		END IF;
		EXCEPTION
		WHEN OTHERS THEN
		  p_error_msg := p_error_msg||'Problem in determining Inventory Item Id validity due to: '||SQLERRM;
		  p_valid_inv_item := 'F';
	  END validate_inv_item;

	--/****************************************************************************************************************
	-- * Function  : validate_item_category                                                                         *
	-- * Purpose   : This Function will check if the item category is setup in oracle.                          *
	-- ****************************************************************************************************************/
	  
	 FUNCTION validate_item_category(p_org_id IN NUMBER,
								   p_item_category IN VARCHAR2,
								   p_error_msg IN OUT VARCHAR2)
	  RETURN VARCHAR2
	  AS
	   ln_cnt NUMBER;
	   BEGIN
			 SELECT COUNT(1)
			 INTO ln_cnt
			 FROM mtl_categories_kfv mck,
				  mtl_item_categories mic
			 WHERE concatenated_segments = p_item_category
					AND organization_id = p_org_id
					and mck.category_id = mic.category_id;
			 IF ln_cnt > 0 THEN
			  RETURN 'T';
			 ELSE
			  p_error_msg := p_error_msg||'The item number is Invalid';
			  RETURN 'F';
			 END IF;
	  
	EXCEPTION
		WHEN OTHERS THEN
		  p_error_msg := p_error_msg||'Problem in determining Item category validity due to: '||SQLERRM;
		  RETURN 'F';
	END validate_item_category;

	--/****************************************************************************************************************
	-- * PROCEDURE  : validate                                                                         *
	-- * Purpose   : This procedure will Validate the data of the visual with respective to oracle.                    *
	-- ****************************************************************************************************************/

	PROCEDURE validate (x_status_return OUT VARCHAR2)
	AS
	  CURSOR cur_item_warranty IS 
		SELECT xiixst.rowid,
			   xiixst.*
		FROM stgusr.XX_ITEM_WARRANTY_STG xiixst
		WHERE process_flag = 'N';
		
	  CURSOR cur_err_rec IS
		SELECT xiixst.* 
		FROM stgusr.XX_ITEM_WARRANTY_STG xiixst
		WHERE xiixst.process_flag = 'VE' 
		AND xiixst.request_id = gn_request_id;
		  
		ln_organization_id			 NUMBER;
		ln_inventory_item 			 NUMBER;
		ln_account_id				NUMBER;
		ln_location_id				NUMBER;
			ln_u8_number				NUMBER;
		ln_rec_count 				number := 0;
		ln_error_count 				number := 0;
		lv_error_msg 				VARCHAR2(4000):=NULL;
		lv_valid_inv_item 			VARCHAR2(2) := NULL;
		lv_valid_category			VARCHAR2(2) := NULL;
		ln_validate_count 			NUMBER := 0;
		lv_valid_org 				VARCHAR2(2):= NULL;
		lv_valid_item 				varchar(2):= null;
		ld_sysdate 					DATE := SYSDATE;
		ld_con_prog_date 			DATE;
		lc_conc_prog_name 			VARCHAR2(200);
		lc_user_name 				VARCHAR2(100);
		lv_valid_u8_item			varchar(2) :=NULL;

	BEGIN
	-- Duplicate update
		UPDATE stgusr.XX_ITEM_WARRANTY_STG
		SET request_id = gn_request_id,
			CREATION_DATE=SYSDATE
		where process_flag='N';
		commit;
	BEGIN
			UPDATE stgusr.XX_ITEM_WARRANTY_STG
				SET process_flag = 'VE',
					error_msg = 'Duplicate value',
					last_update_date = ld_sysdate,
					last_updated_by = -1
			WHERE ROWID IN (SELECT ROWID
						FROM (SELECT organization,item_number,request_id, ROW_NUMBER () 
						OVER (PARTITION BY organization,item_number,request_id 
								  ORDER BY organization,item_number,request_id) 
								  AS ROW_NUMBER  
						FROM stgusr.XX_ITEM_WARRANTY_STG
						WHERE request_id=gn_request_id)
						WHERE ROW_NUMBER > 1)
			AND request_id=gn_request_id; 
			  COMMIT;
	  END;

	 FOR l_inst_rec IN cur_item_warranty
	  LOOP  
	   lv_error_msg			:= null;
	   ln_organization_id	:= null;		
	   ln_inventory_item 	:= null;	
		  ln_u8_number			:= null;


	   
		if l_inst_rec.organization is not null then --validate organization code
			   validate_org_code(l_inst_rec.organization,ln_organization_id,lv_valid_org,lv_error_msg);
			IF lv_valid_org = 'T' THEN
			   UPDATE stgusr.XX_ITEM_WARRANTY_STG SET INV_ORGANIZATION_ID = ln_organization_id WHERE ROWID = l_inst_rec.rowid;
			   COMMIT;
			 IF l_inst_rec.item_number IS NOT NULL THEN --validate Item Number
			   lv_valid_item := validate_item_number(ln_organization_id,l_inst_rec.item_number,ln_u8_number,lv_error_msg);
				IF lv_valid_item = 'T' THEN --get item id
					IF ln_u8_number > 0 then
					validate_u8_item(l_inst_rec.item_number,ln_organization_id,ln_inventory_item,lv_valid_u8_item,lv_error_msg);
					IF lv_valid_u8_item = 'T' THEN
						UPDATE stgusr.XX_ITEM_WARRANTY_STG SET item_id = ln_inventory_item WHERE ROWID=l_inst_rec.rowid;
						COMMIT;
						END IF;
					else
				 validate_inv_item(l_inst_rec.item_number,ln_organization_id,ln_inventory_item,lv_valid_inv_item,lv_error_msg);
				IF lv_valid_inv_item = 'T' THEN
				 UPDATE stgusr.XX_ITEM_WARRANTY_STG SET item_id = ln_inventory_item WHERE ROWID=l_inst_rec.rowid;
				 COMMIT;
				 end if;
				 end if;
				 END IF;
				elsif l_inst_rec.product_category is not null then--need to update the code
				 lv_valid_category :=validate_item_category(ln_organization_id,l_inst_rec.product_category,lv_error_msg);
				else 
					lv_error_msg :=lv_error_msg|| 'Both Item Number and category cannot be NULL';
			
			   END IF;
			  
			  END IF;

		  
		ELSE
		 lv_error_msg := lv_error_msg||'organization is null';
		END IF;

	 IF lv_error_msg IS NOT NULL THEN
		 UPDATE stgusr.XX_ITEM_WARRANTY_STG
		 SET error_msg = lv_error_msg,
			process_flag = 'VE',
			last_update_date = ld_sysdate,
			last_updated_by = -1
		 WHERE rowid = l_inst_rec.rowid;

		 x_status_return := 'W';
	   ELSE
		 UPDATE stgusr.XX_ITEM_WARRANTY_STG
		 SET error_msg = NULL,
			process_flag = 'V',
			last_update_date = ld_sysdate,
			last_updated_by = -1
		 WHERE rowid = l_inst_rec.rowid;

	   END IF;
	  END LOOP;
	  COMMIT;
	  SELECT COUNT(*)
	  INTO ln_validate_count
	  FROM stgusr.XX_ITEM_WARRANTY_STG
	  WHERE process_flag = 'V'
	  AND request_id = gn_request_id;

	  SELECT COUNT(*)
	  INTO ln_error_count
	   FROM stgusr.XX_ITEM_WARRANTY_STG
		WHERE process_flag = 'VE'
	  AND request_id = gn_request_id;
	  
	  SELECT COUNT(*)
	  INTO ln_rec_count
	   FROM stgusr.XX_ITEM_WARRANTY_STG
		WHERE request_id = gn_request_id;
	  
	  get_conc_details (gn_request_id,
						ld_con_prog_date,
						lc_conc_prog_name,
						lc_user_name
						  );
						
	  fnd_file.put_line (fnd_file.OUTPUT, '****************************************************************');
	  fnd_file.put_line (fnd_file.OUTPUT, '                 Item Warranty Validation Summary                          ');
	  fnd_file.put_line (fnd_file.OUTPUT, '================================================================');
	  fnd_file.put_line (fnd_file.OUTPUT,'  ');
	  fnd_file.put_line (fnd_file.OUTPUT,'  ');
	  fnd_file.put_line (fnd_file.OUTPUT,RPAD('Concurrent Program Name ',55)||': '||lc_conc_prog_name);
	  fnd_file.put_line (fnd_file.OUTPUT,RPAD('Concurrent Request ID ',55)||':'||gn_request_id);
	  fnd_file.put_line (fnd_file.OUTPUT,RPAD('User Name ',55)||': '||lc_user_name);
	  fnd_file.put_line (fnd_file.OUTPUT,RPAD('Requested Date ',55)||': '||ld_con_prog_date);
	  fnd_file.put_line (fnd_file.OUTPUT,RPAD('Completion Date ',55)||': '||SYSDATE);
	  fnd_file.put_line (fnd_file.OUTPUT,RPAD('Total no of record validated ',55)||': '||ln_rec_count);
	  fnd_file.put_line (fnd_file.OUTPUT,RPAD('Total no records validated successfuly ',55)||': '||ln_validate_count);
	  fnd_file.put_line (fnd_file.output,RPAD('Total no records errored validation ',55)||': '||ln_error_count );
	  IF ln_error_count > 0 THEN
		   fnd_file.put_line (fnd_file.LOG,'For error details please refer to the log file');
		   fnd_file.put_line (fnd_file.LOG,'****************************************************************');
		 fnd_file.put_line (fnd_file.LOG,'               Validation Error Details                         ');
		 fnd_file.put_line (fnd_file.LOG,'****************************************************************');
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,RPAD('Concurrent program name ', 55)||': '||lc_conc_prog_name);
		 fnd_file.put_line (fnd_file.LOG,RPAD('Concurrent Request ID ',55)||':'||gn_request_id);
		 fnd_file.put_line (fnd_file.LOG,RPAD('User Name ',55)||': '||lc_user_name);
		   fnd_file.put_line (fnd_file.LOG,RPAD('Requested Date ',55)||': '||ld_con_prog_date);
		 fnd_file.put_line (fnd_file.LOG,RPAD('Completion Date ',55)||': '||SYSDATE);
		   fnd_file.put_line (fnd_file.LOG,RPAD('Table Name ', 55)||': '||  'STGUSR.XX_ITEM_WARRANTY_STG'    );
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,'Org Code,Item Number,Product Category,Error Message ');
		   FOR l_rec_err IN cur_err_rec LOOP
			 fnd_file.put_line (fnd_file.LOG,l_rec_err.organization||','||l_rec_err.item_number||','||l_rec_err.product_category||','||l_rec_err.error_msg );
			 END LOOP;
		 END IF;
	EXCEPTION
	WHEN OTHERS THEN
	  x_status_return := 'E'; 
	  fnd_file.put_line (fnd_file.LOG, 'Error while validating data in stage table due to: '||SQLERRM);
		xx_comn_conv_debug_prc ( p_i_level =>NULL,
							p_i_proc_name => 'xx_item_warranty_cnv_pkg',
							p_i_phase => 'validate',
							p_i_stgtable => 'STGUSR.XX_ITEM_WARRANTY_STG' ,
							p_i_message => 'Error :'||SQLERRM);
	END validate;



	PROCEDURE import (x_status_return OUT VARCHAR2)
	AS
	   CURSOR cur_imp IS                
		select  STG.*, stg.rowid
		 from 
		 stgusr.xx_item_warranty_stg STG
		  where 
			STG.process_flag = 'V';

		  
	   CURSOR cur_err_rec IS
		SELECT xiixst.*        
		FROM stgusr.XX_ITEM_WARRANTY_STG xiixst
		WHERE xiixst.process_flag = 'E' 
		AND xiixst.request_id = gn_request_id;
		  
		  ln_created_by            NUMBER := fnd_global.user_id;
		  lv_errbuf                varchar2(4000);
		  lv_return_status 	        VARCHAR2(2);            
		  ln_error_count           NUMBER :=0;
		   x_msg_count       NUMBER (10);
		   l_con_request_id number         := fnd_global.conc_request_id;	  
		  ld_con_prog_date DATE;
		  ln_index NUMBER := 0;
		  lc_conc_prog_name VARCHAR2(200);
		  lc_user_name VARCHAR2(100);
		  ln_cnt NUMBER := 0;
		  ln_validate_count NUMBER := 0;
			lv_phase           VARCHAR2 (30);
		  lv_status          VARCHAR2 (30);
		  lv_request_flag    BOOLEAN;
		  lv_dev_phase       VARCHAR2 (30);
		  lv_dev_status      VARCHAR2 (30);
		  lv_message         VARCHAR2 (1000);
		  ln_request_id          NUMBER          := 0;
		  l_user_id              NUMBER :=null;
		  l_resp_id              NUMBER :=null;
		  l_resp_appl_id         NUMBER :=null;
		  ln_process_cnt      number;
		lv_error_msg 				VARCHAR2(4000):=NULL;
		  lv_msg_separator       varchar2 (10)   := '|';

		  
		  BEGIN 
	   UPDATE STGUSR.xx_item_warranty_stg
		SET   request_id  = l_con_request_id
	  where   process_flag = 'V';
	  commit;
	  l_user_id := fnd_global.user_id;
		  l_resp_id := fnd_global.resp_id;
		  l_resp_appl_id := fnd_global.resp_appl_id;
			FOR l_rec_imp IN cur_imp
			  LOOP
			   ln_cnt := ln_cnt+1; 
				lv_errbuf := NULL;
			   BEGIN
					insert into mtl_system_items_interface
					(
					inventory_item_id,
					process_flag,
					transaction_type,
					organization_id,
					set_process_id,
					ATTRIBUTE2,
					ATTRIBUTE3
					)
					values
					(l_rec_imp.ITEM_ID,
					1,
					'UPDATE',
					l_rec_imp.INV_ORGANIZATION_ID,
					l_con_request_id,
					l_rec_imp.ATTRIBUTE2,
					l_rec_imp.ATTRIBUTE3
					);
					
					EXCEPTION
						WHEN OTHERS THEN
						fnd_file.put_line (fnd_file.LOG, 'Error while INSERTING data in base table due to: '||SQLERRM);
						END;
			 END LOOP;			
			commit;
				
	BEGIN
		  fnd_global.apps_initialize (user_id => l_user_id, 
									  resp_id => l_resp_id, 
									  resp_appl_id => l_resp_appl_id);
		--1072, 1, 1, 1, 1, 53464907, 2, 1
		--fnd_file.put_line (fnd_file.LOG, 'Starting Import Items Program for irg_id: '||p_org_id);
		  ln_request_id := fnd_request.submit_request (application      => 'INV',
															program          => 'INCOIN',
															description      => 'Item Open Interface',
															start_time       => NULL,
															sub_request      => FALSE,
															argument1 	=> 104,
															argument2 	=> '1',
															argument3 	=> '1',
															argument4 	=> '1',
															argument5 	=> '1',
															argument6 	=> l_con_request_id,
															argument7 	=> '2',
															argument8 	=> '1');
		  COMMIT;
		  fnd_file.put_line (fnd_file.LOG, 'Import Items Program Complete. Request ID: ' || ln_request_id);

		  IF ln_request_id = 0
		  THEN
			 lv_return_status := 'E';
			 lv_error_msg := SUBSTR (lv_error_msg || 'Import Items Request submission failed.' || lv_msg_separator, 1, 2000);
		  ELSE
			 --test_debug ('Import Program Submitted');
			 BEGIN
				LOOP
				   lv_request_flag := fnd_concurrent.wait_for_request (request_id      => ln_request_id,
																	   INTERVAL        => 5,
																	   max_wait        => 60,
																	   phase           => lv_phase,
																	   status          => lv_status,
																	   dev_phase       => lv_dev_phase,
																	   dev_status      => lv_dev_status,
																	   MESSAGE         => lv_message);
				   EXIT WHEN UPPER (lv_phase) = 'COMPLETED'
						 OR UPPER (lv_status) IN ('CANCELLED', 'ERROR', 'TERMINATED','WARNING');
				END LOOP;
			 EXCEPTION
				WHEN OTHERS
				THEN
				   --DBMS_OUTPUT.put_line ('Error submitting wait_for_request. Error: ' || SQLERRM);
				   xx_comn_conv_debug_prc (p_i_level          => NULL,
										   p_i_proc_name      => 'process_inv_interface_warranty',
										   p_i_phase          => 'Process Inventory warranty Interface',
										   p_i_stgtable       => 'xx_item_warranty_cnv_pkg',
										   p_i_message        =>    'Error submitting wait_for_request. ');
				   
			 END;
		  END IF;
		  --test_debug('Import Program Completed');
		  BEGIN
			 IF  UPPER (lv_phase) = 'COMPLETED'
				AND UPPER (lv_status) = 'NORMAL'
			 THEN
				--test_debug('Success');
				update stgusr.xx_item_warranty_stg xiws
					SET process_flag = 'P'
				WHERE not exists(select 1
							from mtl_system_items_interface msib
							where msib.inventory_item_id = xiws.item_id
								  and msib.organization_id=xiws.inv_organization_id
								  and NVL(msib.attribute2,-1)=NVL(xiws.attribute2,-1)
								  and NVL(msib.attribute3,-1)=NVL(xiws.attribute3,-1)
							)
						AND REQUEST_ID = l_con_request_id
						and process_flag = 'V' ;
				  commit;             
			 ELSE
				--test_debug('failed');
				SELECT COUNT(*)
				 INTO ln_process_cnt
				 FROM stgusr.xx_item_warranty_stg xiws
				 WHERE not exists(select 1
							from mtl_system_items_interface msib
							where msib.inventory_item_id = xiws.item_id
								  and msib.organization_id=xiws.inv_organization_id
								  and NVL(msib.attribute2,-1)=NVL(xiws.attribute2,-1)
								  and NVL(msib.attribute3,-1)=NVL(xiws.attribute3,-1)
							)
						AND REQUEST_ID = l_con_request_id
						and process_flag = 'V' ;
				
				IF ln_process_cnt > 0
				THEN
					update stgusr.xx_item_warranty_stg xiws
					SET process_flag = 'P'
					WHERE not exists(select 1
							from mtl_system_items_interface msib
							where msib.inventory_item_id = xiws.item_id
								  and msib.organization_id=xiws.inv_organization_id
								  and NVL(msib.attribute2,-1)=NVL(xiws.attribute2,-1)
								  and NVL(msib.attribute3,-1)=NVL(xiws.attribute3,-1)
							)
						AND REQUEST_ID = l_con_request_id
						and process_flag = 'V' ;
						
					update stgusr.xx_item_warranty_stg xiws
					set process_flag = 'E',
					error_msg ='Interface Error' /*(select error_message from mtl_interface_errors where transaction_id in (select transaction_id from
																		  mtl_system_items_interface msie,
																		  STGUSR.xx_inv_item_conv_stg stg
																		  where msie.organization_code='MAS'
																		  and   stg.segment1=msie.segment1
																		  and stg.batch_id=p_batch_id))*/
					WHERE exists(select 1
							from mtl_system_items_interface msib
							where msib.inventory_item_id = xiws.item_id
								  and msib.organization_id=xiws.inv_organization_id
								  and NVL(msib.attribute2,-1)=NVL(xiws.attribute2,-1)
								  and NVL(msib.attribute3,-1)=NVL(xiws.attribute3,-1)
							)
						AND REQUEST_ID = l_con_request_id
						AND PROCESS_FLAG = 'V' ;
					COMMIT;
					
				END IF;
			 END IF;
		  EXCEPTION
			 WHEN OTHERS
			 then
				fnd_file.put_line (fnd_file.LOG, 'Issue while updating Error status from Interface: ' || SQLERRM);
		  END;
		  EXCEPTION
			 WHEN OTHERS
			 THEN
				fnd_file.put_line (fnd_file.LOG, 'Issue while importing the data to base table: ' || SQLERRM);
		  END;
	  SELECT COUNT(*)
	  INTO ln_validate_count
	  FROM stgusr.XX_ITEM_WARRANTY_STG
	  WHERE process_flag = 'P'
	  AND request_id = l_con_request_id;

	  SELECT COUNT(*)
	  INTO ln_error_count
	   FROM stgusr.XX_ITEM_WARRANTY_STG
		WHERE process_flag = 'E'
	  AND request_id = l_con_request_id;
	  
	  IF ln_error_count > 0 
	  THEN
	  x_status_return := 'W';
	  END IF;
	   
	   get_conc_details (l_con_request_id,
						 ld_con_prog_date,
						 lc_conc_prog_name,
						 lc_user_name
						  );
	   fnd_file.put_line (fnd_file.OUTPUT, '****************************************************************');
	   fnd_file.put_line (fnd_file.OUTPUT, '                 Item Warranty Import Summary                           ');
	   fnd_file.put_line (fnd_file.OUTPUT, '================================================================');
	   fnd_file.put_line (fnd_file.LOG,' ');
	   fnd_file.put_line (fnd_file.LOG,' ');
	   fnd_file.put_line (fnd_file.OUTPUT,RPAD('Concurrent Program Name ',55)||': '||lc_conc_prog_name);
	   fnd_file.put_line (fnd_file.OUTPUT,RPAD('Concurrent Request ID ',55)||': '||l_con_request_id);
	   fnd_file.put_line (fnd_file.OUTPUT,RPAD('User Name ',55)||': '||lc_user_name);
		 fnd_file.put_line (fnd_file.OUTPUT,RPAD('Requested Date ',55)||': '||ld_con_prog_date);
	   fnd_file.put_line (fnd_file.OUTPUT,RPAD('Completion Date ',55)||': '||SYSDATE);
	   fnd_file.put_line (fnd_file.LOG,' ');
	   fnd_file.put_line (fnd_file.LOG,' ');
	   fnd_file.put_line (fnd_file.OUTPUT,RPAD('No. of records processed for import ',55)||': '||ln_cnt);
	   fnd_file.put_line (fnd_file.OUTPUT,RPAD('No. of records imported successfully ',55)||': '||ln_validate_count);
	   fnd_file.put_line (fnd_file.OUTPUT,RPAD('No. of records failed import ',55)||' :'||ln_error_count );
	   IF ln_error_count > 0 THEN
		   fnd_file.put_line (fnd_file.LOG,'For error details please refer to the log file');
		   fnd_file.put_line (fnd_file.LOG,'****************************************************************');
		 fnd_file.put_line (fnd_file.LOG,'               Import Error Details                         ');
		 fnd_file.put_line (fnd_file.LOG,'****************************************************************');
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,RPAD('Concurrent program name ', 55)||': '||lc_conc_prog_name);
		 fnd_file.put_line (fnd_file.LOG,RPAD('Concurrent Request ID ',55)||':'||gn_request_id);
		 fnd_file.put_line (fnd_file.LOG,RPAD('User Name ',55)||': '||lc_user_name);
		   fnd_file.put_line (fnd_file.LOG,RPAD('Requested Date ',55)||': '||ld_con_prog_date);
		 fnd_file.put_line (fnd_file.LOG,RPAD('Completion Date ',55)||': '||SYSDATE);
		   fnd_file.put_line (fnd_file.LOG,RPAD('Table Name ', 55)||': '||  'STGUSR.XX_ITEM_WARRANTY_STG'    );
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,' ');
		   fnd_file.put_line (fnd_file.LOG,'Org Code,Item Number,Product Category,Error Message ');
		   for l_rec_err in cur_err_rec loop
			 fnd_file.put_line (fnd_file.LOG,l_rec_err.organization||','||l_rec_err.item_number||','||l_rec_err.product_category||','||l_rec_err.error_msg );
			 END LOOP;
		 END IF;
	 EXCEPTION
	WHEN OTHERS THEN
	  x_status_return := 'E';
	  fnd_file.put_line (fnd_file.LOG, 'Error while importing data in base table due to: '||SQLERRM);
		xx_comn_conv_debug_prc ( p_i_level =>NULL,
							p_i_proc_name => 'xx_inv_item_xref_cnv_pkg',
							p_i_phase => 'Import',
							p_i_stgtable => 'STGUSR.XX_ITEM_WARRANTY_STG' ,
							p_i_message => 'Error :'||SQLERRM);  
	END import;
				
	PROCEDURE main(
			p_o_err_buff OUT VARCHAR2,
			p_o_ret_code OUT NUMBER,
			p_i_run_mode IN VARCHAR2
			)
	AS
	lv_err_flag VARCHAR2(5) := NULL;
	BEGIN
	  --Calling the Procedure for Validation or Import

	  IF p_i_run_mode = 'VALIDATE' THEN 
		validate (lv_err_flag);    
	  ELSIF p_i_run_mode = 'TRANSFER' THEN
		import (lv_err_flag);    
	  END IF;
	  IF lv_err_flag = 'W' THEN
			  p_o_ret_code := 1;
	  ELSIF lv_err_flag = 'E' THEN
		  p_o_ret_code := 2;
	  ELSE
		 p_o_ret_code := 0;
	  END IF;
	EXCEPTION 
	  WHEN OTHERS THEN
		 p_o_ret_code := 2;
			fnd_file.put_line(fnd_file.LOG,'Error while calling main program: '||SQLERRM);
		xx_comn_conv_debug_prc ( p_i_level =>NULL,
								p_i_proc_name => 'xx_item_warranty_cnv_pkg',
								p_i_phase => 'Main',
								p_i_stgtable => 'STGUSR.XX_ITEM_WARRANTY_STG' ,
								p_i_message => 'Error in Main'||SQLERRM);
	END main;
END xx_item_warranty_cnv_pkg;	
/