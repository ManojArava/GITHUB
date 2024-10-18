Create or replace
 package BODY customusr.XX_MFG_SHELL_WO_IB_UPDATE_PKG
As

/*
/****************************************************************************************************
 * Procedure APPS.XX_UPDATE_ITEM_INSTANCE_PRC                                          							    *
 *                                                                                               					   *
 * Description:                                                                                   				  *
 * This PROCEDURE is used to change the ownership of existing and expired item instances  for given project          *
 * Change History                                                                                   *
 * Version          Date                     Name                      Description of Change        *
 * -------          -------              ------------------------      -----------------------------*
 * 1.0              4/12/2020            (Cognizant)                   Initial Creation...         *
 *                                                                                                  *
 ****************************************************************************************************/
procedure main(	p_o_err_buff	  OUT VARCHAR2,
				p_o_ret_code 	  OUT NUMBER,
				p_project_number  IN VARCHAR2,
				p_warranty_start_date IN varchar2)
AS
l_location_id 					NUMBER;
l_instance_party_id 			NUMBER;
l_inst_object_version_number	NUMBER;
l_ip_object_version_number 		NUMBER;
l_instance_id 					NUMBER;
l_warranty_period				NUMBER;
p_warranty_end_date			varchar2(30);
	  ln_msg_count             NUMBER;
      lv_return_status 	        VARCHAR2(2);            
      ln_error_count           NUMBER :=0;
      ln_api_version           NUMBER := 1.0;
  	  x_msg_data VARCHAR2(2000);
      lv_commit VARCHAR2(2)           := apps.FND_API.G_FALSE;--CHECK
      lv_init_msg_list VARCHAR2(2)    := apps.FND_API.G_TRUE;	  
      l_con_request_id number         := apps.FND_GLOBAL.conc_request_id;
      X_INSTANCE_REC apps.CSI_DATASTRUCTURES_PUB.INSTANCE_REC;
      X_EXT_ATTRIB_VALUES apps.CSI_DATASTRUCTURES_PUB.EXTEND_ATTRIB_VALUES_TBL;
      X_PARTY_TBL apps.CSI_DATASTRUCTURES_PUB.PARTY_TBL;
      X_ACCOUNT_TBL apps.CSI_DATASTRUCTURES_PUB.PARTY_ACCOUNT_TBL;
      X_PRICING_ATTRIB_TBL apps.CSI_DATASTRUCTURES_PUB.PRICING_ATTRIBS_TBL;
      X_ORG_ASSIGNMENTS_TBL apps.CSI_DATASTRUCTURES_PUB.ORGANIZATION_UNITS_TBL;
      X_ASSET_ASSIGNMENT_TBL apps.CSI_DATASTRUCTURES_PUB.INSTANCE_ASSET_TBL;
      X_TXN_REC apps.CSI_DATASTRUCTURES_PUB.TRANSACTION_REC;
	  x_instance_id_lst apps.CSI_DATASTRUCTURES_PUB.ID_TBL;
	  P_VALIDATION_LEVEL NUMBER;
	  V_SUCCESS VARCHAR2(1) := 'T';
CURSOR instance_cur is 
					SELECT 	ppc.customer_id,
					hca.party_id,
					csi.instance_id,
					csi.inventory_item_id,
					wdj.organization_id
			FROM 	apps.pa_projects_all ppa,
					apps.pa_project_customers ppc, 
					apps.pa_tasks pt,
					apps.wip_discrete_jobs wdj,
					apps.wip_entities we,
					apps.hz_cust_accounts hca,
					apps.csi_item_instances csi
			WHERE 	1=1
					AND ppa.project_id = p_project_number
					AND ppa.project_id = ppc.project_id
					AND ppa.project_id = pt.project_id
					AND ppa.project_id = wdj.project_id
					AND pt.task_id = wdj.task_id
					AND wdj.wip_entity_id = we.wip_entity_id
					AND hca.cust_account_id=ppc.customer_id
					AND csi.wip_job_id=wdj.wip_entity_id;
BEGIN
for i in instance_cur
loop
l_warranty_period := 0;
l_instance_id :=NULL;


BEGIN
SELECT instance_id, object_version_number 
INTO l_instance_id,
l_inst_object_version_number
FROM apps.csi_item_instances
WHERE instance_number = i.instance_id ;

EXCEPTION

when others then

apps.xx_comn_pers_util_pkg.FND_LOG('Error while fetching instance number'||sqlerrm);

END;

BEGIN

SELECT MAX(party_site_id)
INTO l_location_id
FROM apps.hz_party_sites
WHERE party_id = i.party_id;

EXCEPTION

when others then

apps.xx_comn_pers_util_pkg.FND_LOG('Error while fetching location'||sqlerrm);

END;

BEGIN
SELECT instance_party_id, object_version_number
INTO l_instance_party_id,
l_ip_object_version_number
FROM apps.csi_I_parties
WHERE instance_id = l_instance_id
AND relationship_type_code = 'OWNER';

EXCEPTION

when others then

apps.xx_comn_pers_util_pkg.FND_LOG('Error while fetching party instance number'||sqlerrm);

END;

BEGIN

SELECT attribute2
INTO l_warranty_period
FROM apps.mtl_system_items_b msi
WHERE msi.inventory_item_id = i.inventory_item_id
AND msi.organization_id = i.organization_id;

EXCEPTION
when others then
apps.xx_comn_pers_util_pkg.FND_LOG('Error while fetching location'||sqlerrm);
END;

BEGIN
SELECT TO_TIMESTAMP(p_warranty_start_date,'YYYY/MM/DD HH24:MI:SS') + nvl(l_warranty_period,0) 
INTO p_warranty_end_date 
from dual;
EXCEPTION
when others then
apps.xx_comn_pers_util_pkg.FND_LOG('Error while Calculating warranty end_date '||sqlerrm);
END;

x_instance_rec.instance_id := l_instance_id;
x_instance_rec.object_version_number := l_inst_object_version_number;
x_instance_rec.location_id :=l_location_id;
x_instance_rec.location_type_code :='HZ_PARTY_SITES';
x_instance_rec.accounting_class_code :='CUST_PROD';
apps.xx_comn_pers_util_pkg.FND_LOG('p_warranty_start_date'||p_warranty_start_date);

x_instance_rec.attribute29 :=nvl(p_warranty_start_date,sysdate);
IF p_warranty_start_date IS NOT NULL THEN
apps.xx_comn_pers_util_pkg.FND_LOG('p_warranty_end_date'||p_warranty_end_date);

x_instance_rec.attribute30 := p_warranty_end_date;
ELSE
x_instance_rec.attribute30 :=to_char(sysdate+l_warranty_period,'yyyy/mm/dd hh24:mi:ss');
END IF;

x_instance_rec.active_end_date:= NULL;
x_instance_rec.instance_status_id :=510;


x_party_tbl(1).instance_party_id := l_instance_party_id;
x_party_tbl(1).instance_id := l_instance_id;
x_party_tbl(1).party_source_table := 'HZ_PARTIES';
x_party_tbl(1).party_id := i.party_id; --n
x_party_tbl(1).relationship_type_code := 'OWNER';
x_party_tbl(1).contact_flag := 'N';
x_party_tbl(1).contact_ip_id := NULL;
x_party_tbl(1).object_version_number := l_ip_object_version_number;


x_account_tbl(1).parent_tbl_index := 1;
x_account_tbl(1).instance_party_id := l_instance_party_id;
x_account_tbl(1).party_account_id := i.customer_id;
x_account_tbl(1).relationship_type_code := 'OWNER';
x_account_tbl(1).bill_to_address := NULL;
x_account_tbl(1).ship_to_address := NULL;



x_txn_rec.transaction_id := NULL;
x_txn_rec.transaction_date := SYSDATE; --TO_DATE('');
x_txn_rec.source_transaction_date := SYSDATE; --TO_DATE('');
x_txn_rec.transaction_type_id := 1; --NULL;
x_txn_rec.txn_sub_type_id := NULL;




			apps.xx_comn_pers_util_pkg.FND_LOG( 'BEFORE CREATE ITEM INSTANCE');
			apps.xx_comn_pers_util_pkg.FND_LOG('BEFORE CREATE ITEM INSTANCE');
			apps.xx_comn_pers_util_pkg.XX_ITEM_INSTANCE_UPDATE_PRC(ln_api_version           
											,   lv_commit		    
											,   lv_init_msg_list                
											,	p_validation_level 		
											,   x_instance_rec          
											,   x_ext_attrib_values     
											,   x_party_tbl             
											,   x_account_tbl           
											,   x_pricing_attrib_tbl    
											,   x_org_assignments_tbl   
											,   x_asset_assignment_tbl  
											,   x_txn_rec
											,	x_instance_id_lst										
											,   lv_return_status         
											,   ln_msg_count             
											,   x_msg_data);
			
apps.xx_comn_pers_util_pkg.FND_LOG( 'AFTER updating ITEM INSTANCE'||i.instance_id); -- follow are new if clauses instead of following commented code
if lv_return_status = apps.FND_API.G_RET_STS_SUCCESS then
			apps.xx_comn_pers_util_pkg.FND_LOG( 'Success');
			apps.xx_comn_pers_util_pkg.FND_LOG( APPS.FND_MSG_PUB.Get(
			p_msg_index => APPS.FND_MSG_PUB.G_LAST,
			p_encoded => apps.FND_API.G_FALSE));
			V_SUCCESS := 'T';
END IF;			
	if lv_return_status != apps.FND_API.G_RET_STS_SUCCESS then
			apps.xx_comn_pers_util_pkg.FND_LOG( 'failed. printing error msg...');
			apps.xx_comn_pers_util_pkg.FND_LOG( APPS.FND_MSG_PUB.Get(
			p_msg_index => APPS.FND_MSG_PUB.G_LAST,
			p_encoded => apps.FND_API.G_FALSE));
			V_SUCCESS := 'F';
END IF;				
END LOOP;
/*		
IF x_msg_count > 0
THEN
FOR j IN 1 .. x_msg_count LOOP
fnd_msg_pub.get
( j
, apps.FND_API.G_FALSE
, x_msg_data
, t_msg_dummy
);
t_output := ( 'Msg'
|| TO_CHAR
( j
)
|| ': '
|| x_msg_data
);
apps.xx_comn_pers_util_pkg.FND_LOG(SUBSTR
( t_output
, 1
, 255
)
);
END LOOP;
END IF;*/
apps.xx_comn_pers_util_pkg.FND_LOG('x_return_status = '||lv_return_status);
apps.xx_comn_pers_util_pkg.FND_LOG('x_msg_count = '||TO_CHAR(ln_msg_count));
apps.xx_comn_pers_util_pkg.FND_LOG('x_msg_data = '||x_msg_data);
COMMIT;
EXCEPTION 
  WHEN OTHERS THEN
     p_o_ret_code := 2;
		apps.xx_comn_pers_util_pkg.FND_LOG('Error while calling main program: '||SQLERRM);
END MAIN;
END XX_MFG_SHELL_WO_IB_UPDATE_PKG;
/