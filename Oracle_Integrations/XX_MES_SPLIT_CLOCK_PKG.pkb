create or replace 
PACKAGE BODY customusr.XX_MES_SPLIT_CLOCK_PKG 
	AS
/******************************************************************************
 NAME: customusr.XX_MES_SPLIT_CLOCK_PKG
   PURPOSE: Mes split clocking to post negative transaction
   REVISIONS:
   Ver        Date        Author           		Description
   ---------  ----------  ---------------  		------------------------------------
   1.0        12/08/2020   Manoj Arava (CTS)    1.Initial Version,
  ******************************************************************************/
		PROCEDURE mes_clocking(p_organization_id IN NUMBER,
							   p_resource_id IN NUMBER,
							   p_employee_id IN NUMBER,
							   p_operation_seq 	IN VARCHAR2,
							   p_wip_entity_id IN NUMBER,
							   p_time_entry_id	IN NUMBER,	
							   p_end_date IN DATE,
							   p_updated_by IN OUT NUMBER,
							   p_actual_duration  OUT NUMBER,
							   p_error_msg OUT VARCHAR2)
		IS
		lv_flag 				VARCHAR2(3);
		ln_count 				NUMBER ;
		ld_temp_start_time	 	DATE;
		ln_time_count 			NUMBER;
		ln_start_count 			NUMBER;
		ln_end_count			NUMBER;
		ln_duration  			NUMBER;
		ln_actual_duration 		NUMBER;
		ln_job_duration 		NUMBER:=0;
		ln_accurate_duration	NUMBER;
		ld_end_date				DATE;
		l_error_message 		VARCHAR2(2000):=NULL;
		lv_overlap_jobs			VARCHAR2(240);	
		PRAGMA AUTONOMOUS_TRANSACTION;	
		BEGIN 
		
		--NEED TO DELETE THESE TABLES AT THE END OF THE API CALLING OR AT THE END OF THIS PACKAGE AFTER UPDATING VALUES INTO BASE TABLE
		FOR i IN (SELECT start_date,resource_id,operation_seq_num,employee_id,wip_entity_id,time_entry_id 
				  FROM apps.wip_resource_actual_times 
				  WHERE resource_id = p_resource_id 
				  AND employee_id = p_employee_id
				  AND operation_seq_num = p_operation_seq
				  AND wip_entity_id = p_wip_entity_id
				  AND time_entry_id = p_time_entry_id
				  AND organization_id = p_organization_id
				  AND time_entry_mode <> 8)
		LOOP
		ld_temp_start_time := NULL;
		lv_flag := NULL;
		ln_time_count := 0;
		ln_count := 0;
	BEGIN
		INSERT INTO customusr.xx_mes_temp_times_tbl((SELECT start_date,'S',i.time_entry_id 
									FROM apps.wip_resource_actual_times WHERE start_date >= i.start_date 
									AND (end_date IS NULL OR end_date > i.start_date) AND start_date < p_end_date 
									AND employee_id = p_employee_id
									AND organization_id = p_organization_id
									AND time_entry_mode <> 8)
							UNION (SELECT end_date,'E',i.time_entry_id 
									FROM apps.wip_resource_actual_times WHERE end_date > i.start_date 
									AND end_date <= p_end_date
									AND employee_id = p_employee_id
									AND organization_id = p_organization_id
									AND time_entry_mode <> 8));
		COMMIT;
		INSERT INTO customusr.xx_mes_temp_times_tbl values(p_end_date,'E',i.time_entry_id);
	COMMIT;

	EXCEPTION
	WHEN OTHERS THEN
	l_error_message := 'insertion xx_mes_temp_times_tbl'||SQLERRM ;
	END;
		
		ln_job_duration := (p_end_date-i.start_date)*24;
		ld_temp_start_time := i.start_date;
		
		BEGIN 
			SELECT COUNT(*)
			INTO ln_count 
			FROM apps.wip_resource_actual_times 
			WHERE start_date < i.start_date 
			AND (end_date is null or end_date > i.start_date)
			AND employee_id = p_employee_id
			AND organization_id = p_organization_id
			AND time_entry_mode <> 8;
		EXCEPTION
		WHEN OTHERS THEN 
		l_error_message := l_error_message||'ln_count '||SQLERRM ;
		END;
			  
		
			FOR j IN (SELECT time_stamp,status 
						FROM customusr.xx_mes_temp_times_tbl 
						WHERE time_stamp>i.start_date
						AND time_entry_id = i.time_entry_id 
						ORDER BY time_stamp)
			LOOP
				BEGIN
				SELECT COUNT(1)
				INTO ln_time_count 
				FROM 	customusr.xx_mes_temp_times_tbl
				WHERE 	time_stamp=ld_temp_start_time
				AND time_entry_id = i.time_entry_id;
				EXCEPTION
				WHEN OTHERS THEN 
				l_error_message := l_error_message||' '||'ln_time_count '||SQLERRM ;
				END;
				
				IF (ln_time_count < 2) THEN
						BEGIN
						SELECT 	status 
						INTO 	lv_flag 
						FROM 	customusr.xx_mes_temp_times_tbl
						WHERE 	time_stamp=ld_temp_start_time
						AND time_entry_id = i.time_entry_id ;
						EXCEPTION
						WHEN OTHERS THEN 
						l_error_message := l_error_message||' '||'lv_flag '||SQLERRM ;
						END;
						
					IF (lv_flag='S') THEN
						BEGIN
						SELECT COUNT(1) 
						INTO ln_start_count 
						FROM apps.wip_resource_actual_times 
						WHERE start_date=ld_temp_start_time
						AND employee_id = p_employee_id
						AND organization_id = p_organization_id
						AND time_entry_mode <> 8;
						EXCEPTION
						WHEN OTHERS THEN 
						l_error_message := l_error_message||' '||'ln_start_count '||SQLERRM ;
						END;
						ln_count := ln_count+ln_start_count;
						
					ELSIF(lv_flag='E') THEN
						BEGIN
						SELECT COUNT(1) 
						INTO ln_end_count 
						FROM apps.wip_resource_actual_times 
						WHERE end_date=ld_temp_start_time
						AND employee_id = p_employee_id
						AND organization_id = p_organization_id
						AND time_entry_mode <> 8;
						EXCEPTION
						WHEN OTHERS THEN 
						l_error_message := l_error_message||' '||'ln_end_count '||SQLERRM ;
						END;
						ln_count:=ln_count-ln_end_count;
					ELSE 
						NULL;
					END IF;
					END IF;
				
				ln_duration := (j.time_stamp - ld_temp_start_time)*24;
				ln_actual_duration := ln_duration/ln_count;
				BEGIN
				INSERT INTO customusr.xx_wip_mes_times_tbl VALUES(ld_temp_start_time,j.time_stamp,ln_count,ln_duration,ln_actual_duration,i.time_entry_id);
				commit;
				EXCEPTION
				WHEN OTHERS THEN
				l_error_message := l_error_message||' '||'Data not inserted into xx_wip_mes_times_tbl '||SQLERRM ;
				END;
				
				ld_temp_start_time := j.time_stamp;
				COMMIT;
			END LOOP;
			  COMMIT;
			  
			lv_overlap_jobs := jobs_overlap(i.start_date, p_end_date, p_employee_id, p_organization_id);
		END LOOP;
		
			BEGIN
				SELECT SUM(actual_duration) 
				INTO ln_accurate_duration 
				FROM customusr.xx_wip_mes_times_tbl 
				WHERE time_entry_id = p_time_entry_id 
				GROUP BY time_entry_id;
				EXCEPTION
				WHEN OTHERS THEN
				l_error_message := l_error_message||' '||'ln_accurate_duration '||SQLERRM ;
			END;	
			p_actual_duration := ln_accurate_duration - ln_job_duration;
			p_actual_duration := ROUND(p_actual_duration,6);
			p_error_msg := l_error_message;
			--data deletion is not required
			--DELETE customusr.xx_mes_temp_times_tbl WHERE time_entry_id = p_time_entry_id; 
			--DELETE customusr.xx_wip_mes_times_tbl WHERE time_entry_id = p_time_entry_id;
			IF p_error_msg is null THEN
														  
			 -------------------RESOURCE TRANSACTION INTERFACE-------------------
	  
			IF p_actual_duration <> 0  THEN
				mes_resource_interface(p_organization_id ,
											p_wip_entity_id ,
											p_operation_seq,
											p_resource_id,
											p_employee_id,
											p_updated_by,
											lv_overlap_jobs,
											p_actual_duration,
											p_error_msg);
			END IF;
		END IF;
		EXCEPTION
		WHEN OTHERS THEN
			p_error_msg := l_error_message||' '||'Main Exception Mes_clocking '||SQLERRM ;
	  END mes_clocking;
	  ---function overlap jobs
	  FUNCTION jobs_overlap(p_start_date IN DATE,
					  p_end_date IN DATE,
					  p_employee_id IN NUMBER,
					  p_organization_id IN NUMBER)
	RETURN VARCHAR2
	 AS
	lv_job_name varchar2(30);
	lv_jobs VARCHAR2(240):= NULL;
	BEGIN
		FOR i IN ((SELECT wip_entity_id 
					FROM apps.wip_resource_actual_times WHERE start_date >= p_start_date 
					AND (end_date IS NULL OR end_date > p_start_date) AND start_date < p_end_date 
					AND employee_id = p_employee_id
					AND organization_id = p_organization_id
					AND time_entry_mode <> 8)
					UNION
					(SELECT wip_entity_id 
					FROM apps.wip_resource_actual_times WHERE start_date < p_start_date 
					AND (end_date > p_start_date OR end_date IS NULL)
					AND employee_id = p_employee_id
					AND organization_id = p_organization_id
					AND time_entry_mode <> 8))
		LOOP
		
		SELECT we.wip_entity_name 
		INTO lv_job_name
		FROM apps.wip_entities we
		WHERE we.wip_entity_id = i.wip_entity_id;
		
		IF lv_jobs IS NULL THEN
		lv_jobs := lv_job_name;
		ELSE
		lv_jobs := lv_jobs||' '||'|'||' '||lv_job_name;
		END IF;		
		
		END LOOP;
	RETURN lv_jobs;
	EXCEPTION
	WHEN OTHERS THEN
	lv_jobs := 'Problem in deriving wip overlapping jobs';
	RETURN lv_jobs;
END;
	 ---- INTERFACE----
	procedure mes_resource_interface(p_organization_id IN number,
	p_wip_entity_id IN NUMBER,
	p_operation_seq_num IN NUMBER,
	p_resource_id IN NUMBER,
	p_employee_id IN NUMBER,
	p_updated_by IN NUMBER,
	p_overlap_jobs IN VARCHAR2,
	p_actual_duration IN NUMBER,
	p_error_msg IN OUT VARCHAR2) 
	as
	----Variable Declarations
  ln_reason_id NUMBER;
	l_wip_entity_name apps.wip_entities.wip_entity_name%type;
	l_entity_type apps.wip_entities.entity_type%type;
	l_primary_item_id apps.wip_entities.primary_item_id%type;
	l_organization_code apps.org_organization_definitions.organization_code%type;

	l_department_id apps.bom_departments.department_id%type;
	l_department_code apps.bom_departments.department_code%type;

	l_resource_seq_num apps.bom_operation_resources.resource_seq_num%type;
	l_standard_rate_flag apps.bom_operation_resources.standard_rate_flag%type;
	l_basis_type apps.bom_operation_resources.basis_type%type;
	l_autocharge_type apps.bom_operation_resources.autocharge_type%type;
	l_resource_code apps.bom_resources.resource_code%type;
	l_resource_type apps.bom_resources.resource_type%type;
	l_source_code varchar2(240);
	l_employee_num varchar2(240);
	l_verify_flag char(1) :='Y';
	l_error_message varchar2(2000);
	l_acct_period_id NUMBER;
	lv_user_name varchar2(100);	

	BEGIN


	l_verify_flag := 'Y' ;

	BEGIN
	SELECT 
	wip.wip_entity_name,
	wip.entity_type,
	wip.primary_item_id ,
	ood.organization_code
	into 
	l_wip_entity_name,
	l_entity_type,
	l_primary_item_id,
	l_organization_code
	from apps.wip_entities wip,
	apps.org_organization_definitions ood
	where wip.organization_id = ood.organization_id
	and wip.wip_entity_id = p_wip_entity_id
	and wip.organization_id = p_organization_id;

	EXCEPTION
	WHEN NO_DATA_FOUND THEN
	l_verify_flag := 'N';
	l_error_message := l_error_message||'Job Name Not Found...';
	WHEN TOO_MANY_ROWS THEN
	l_verify_flag := 'N';
	l_error_message := l_error_message||' Job Name Is More than One...';
	WHEN OTHERS THEN
	l_verify_flag := 'N';
	l_error_message:= l_error_message||' Job has some unidentified errors...';
	END;
-- reason code
	SELECT reason_id
	INTO ln_reason_id 
	FROM 
	apps.mtl_transaction_reasons 
	WHERE reason_name='Multiclock-In';
	--user name
	SELECT user_name
	INTO lv_user_name
	FROM apps.fnd_user
	WHERE user_id = p_updated_by;
	
	BEGIN

	SELECT DISTINCT 
			wrat.resource_seq_num,
			wor.basis_type,
			br.resource_code,
			br.resource_type,
			wor.standard_rate_flag,
			wor.autocharge_type
		   
	INTO 
	l_resource_seq_num,
	l_basis_type,
	l_resource_code,
	l_resource_type,
	l_standard_rate_flag,
	l_autocharge_type
	FROM  apps.wip_resource_actual_times wrat,
		  apps.wip_operation_resources wor,
		  apps.bom_resources br
	WHERE wrat.wip_entity_id = wor.wip_entity_id
	AND wrat.organization_id = wor.organization_id
	AND wor.resource_id = br.resource_id
	AND wrat.wip_entity_id = p_wip_entity_id
	AND wrat.organization_id = p_organization_id
	AND wor.operation_seq_num = wrat.operation_seq_num
	AND wrat.operation_seq_num = p_operation_seq_num
	AND br.resource_id = p_resource_id
	AND wrat.resource_seq_num = wor.resource_seq_num;

	EXCEPTION
	WHEN NO_DATA_FOUND THEN
	l_verify_flag := 'N';
	l_error_message := l_error_message||' Operation Sequence Not Found...';
	WHEN TOO_MANY_ROWS THEN
	l_verify_flag := 'N';
	l_error_message := l_error_message ||' Operation Sequence Is More than One...';
	WHEN OTHERS THEN
	l_verify_flag := 'N';
	l_error_message:= l_error_message||' Operation Sequence has some unidentified errors...';

	END;

	BEGIN

	select distinct department_id 
	INTO l_department_id
	from apps.wip_operations 
	where wip_entity_id =p_wip_entity_id
	AND organization_id = p_organization_id
	AND operation_seq_num = p_operation_seq_num;
	EXCEPTION
	WHEN OTHERS THEN
	l_verify_flag := 'N';
	l_error_message:= l_error_message||' Department unidentified errors...';
	END;

	IF l_department_id IS NOT NULL THEN
	BEGIN

	SELECT bd.department_code
	INTO l_department_code
	FROM apps.bom_departments bd
	WHERE bd.department_id = l_department_id
	AND bd.organization_id = p_organization_id;
	EXCEPTION
	WHEN OTHERS THEN
	l_verify_flag := 'N';
	l_error_message:= l_error_message||' Department has some unidentified errors...';
	END;
	END IF;


	BEGIN

	SELECT acct_period_id
	INTO l_acct_period_id
	FROM apps.org_acct_periods
	WHERE SYSDATE BETWEEN period_start_date AND schedule_close_date
	AND organization_id = p_organization_id ;

	EXCEPTION
	WHEN NO_DATA_FOUND THEN
	l_verify_flag := 'N';
	l_error_message := l_error_message||' Account Period Id Not Found...';
	WHEN TOO_MANY_ROWS THEN
	l_verify_flag := 'N';
	l_error_message := l_error_message||' Account Period Is More than One...';
	WHEN OTHERS THEN
	l_verify_flag := 'N';
	l_error_message:= l_error_message||' Account Period has some unidentified errors...';

	END;

	BEGIN
	SELECT employee_number
	INTO l_employee_num
	FROM apps.per_all_people_f
	WHERE person_id = p_employee_id
	AND TRUNC(SYSDATE) BETWEEN effective_start_date AND NVL(effective_end_date,sysdate+1);
	EXCEPTION
	WHEN OTHERS THEN
	l_error_message:= l_error_message||' Employee num is unidentified ...';
	END;



	IF l_verify_flag <> 'N' then

	BEGIN

	INSERT INTO apps.wip_cost_txn_interface
	(last_update_date, last_updated_by, last_updated_by_name, creation_date, created_by, created_by_name,
	process_phase, process_status, transaction_type,
	organization_id, organization_code, wip_entity_id,
	wip_entity_name, entity_type, primary_item_id, transaction_date,
	ACCT_PERIOD_ID, operation_seq_num, resource_seq_num,
	department_id, department_code, resource_id,resource_code,
	resource_type, basis_type,
	autocharge_type, standard_rate_flag, TRANSACTION_QUANTITY,
	TRANSACTION_UOM, PRIMARY_QUANTITY, PRIMARY_UOM,
	activity_id, activity_name, reference,--source_code,
	reason_id,reason_name)
	VALUES (SYSDATE, p_updated_by, lv_user_name,SYSDATE, p_updated_by, lv_user_name,
	2, 1, 1,
	p_organization_id, l_organization_code, p_wip_entity_id,
	l_wip_entity_name, l_entity_type, l_primary_item_id, SYSDATE,
	l_acct_period_id, p_operation_seq_num, l_resource_seq_num,
	l_department_id,l_department_code, p_resource_id, l_resource_code,
	l_resource_type, l_basis_type,
	l_autocharge_type, l_standard_rate_flag, p_actual_duration, 'Hr',
	p_actual_duration, 'Hr',
	1, 'Run', p_overlap_jobs,--'OA Transaction',
	ln_reason_id,'Multiclock-In'
	);



	COMMIT;

	EXCEPTION
	WHEN OTHERS THEN
	l_error_message := l_error_message||' '||'Data not inserted into wip_cost_txn_interface '||SQLERRM ;
	END;

	else
	p_error_msg:=p_error_msg||l_error_message;
	end if;

	end mes_resource_interface ;
	END XX_MES_SPLIT_CLOCK_PKG;
	/