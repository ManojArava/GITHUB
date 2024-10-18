CREATE OR REPLACE
PACKAGE BODY customusr.xx_item_instance_cnv_pkg
AS
  
  gn_request_id NUMBER := apps.fnd_global.CONC_REQUEST_ID;
  gn_user_id    NUMBER := apps.FND_GLOBAL.USER_ID;
PROCEDURE get_conc_details(
    p_req_id IN NUMBER ,
    x_con_prog_date OUT DATE ,
    x_conc_prog_name OUT VARCHAR2 ,
    x_user_name OUT VARCHAR2 )
AS
BEGIN
  SELECT fcr.request_date ,
    fcp.user_concurrent_program_name
  INTO x_con_prog_date,
    x_conc_prog_name
  FROM apps.fnd_concurrent_requests fcr,
    apps.fnd_concurrent_programs_tl fcp
  WHERE fcr.request_id          = gn_request_id
  AND fcp.concurrent_program_id = fcr.concurrent_program_id
  AND fcp.language              = USERENV('LANG');
  SELECT user_name
  INTO x_user_name
  FROM apps.fnd_user
  WHERE user_id = gn_user_id;
EXCEPTION
WHEN OTHERS THEN
  apps.xx_comn_conv_debug_prc ( p_i_level =>NULL, p_i_proc_name => 'xx_item_instance_cnv_pkg', p_i_phase => 'get_conc_details', p_i_stgtable => 'stgusr.XX_CSI_ITEM_INSTANCE_STAGE' , p_i_message => 'Error :'||SQLCODE||SQLERRM);
END get_conc_details;
--/****************************************************************************************************************
-- * procedure  : validate_org_code                                                                         *
-- * Purpose   : This procedure will check if the org code is setup in oracle.                          *
-- ****************************************************************************************************************/
PROCEDURE validate_org_code(
    p_org_code IN VARCHAR2,
    p_org_id OUT NUMBER,
    p_valid_org OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
AS
  ln_cnt NUMBER;
BEGIN
  SELECT COUNT(1)
  INTO ln_cnt
  FROM apps.mtl_parameters mp
  WHERE mp.organization_code = p_org_code;
  IF ln_cnt                  > 0 THEN
    p_valid_org             := 'T';
    SELECT organization_id
    INTO p_org_id
    FROM apps.mtl_parameters mp
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
FUNCTION validate_item_number(
    p_org_id      IN NUMBER,
    p_item_number IN VARCHAR2,
    p_u8_number OUT NUMBER,
    p_error_msg IN OUT VARCHAR2)
  RETURN VARCHAR2
AS
  ln_cnt NUMBER;
BEGIN
  SELECT COUNT(1)
  INTO ln_cnt
  FROM apps.mtl_system_items_b
  WHERE inventory_item_status_code       = 'Active'
  AND organization_id                    = p_org_id
  AND segment1                           = p_item_number
  AND NVL(start_date_active,(SYSDATE-1)) < SYSDATE
  AND NVL(end_date_active,(SYSDATE  +1)) > SYSDATE;
  SELECT COUNT(1)
  INTO p_u8_number
  FROM apps.mtl_cross_references
  WHERE cross_reference = p_item_number;
  IF ln_cnt             > 0 OR p_u8_number > 0 THEN
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
PROCEDURE validate_u8_item(
    p_item_number     IN VARCHAR2,
    p_organization_id IN NUMBER,
    p_inventory_item OUT NUMBER,
    p_valid_u8_item OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
AS
BEGIN
  SELECT inventory_item_id
  INTO p_inventory_item
  FROM apps.mtl_cross_references
  WHERE cross_reference = p_item_number;
  IF p_inventory_item  IS NOT NULL THEN
    p_valid_u8_item    := 'T';
  ELSE
    p_valid_u8_item := 'F';
  END IF;
EXCEPTION
WHEN TOO_MANY_ROWS THEN
  SELECT msi.inventory_item_id
  INTO p_inventory_item
  FROM apps.mtl_cross_references mcr,
    apps.mtl_system_items_b msi
  WHERE 1                   =1
  AND MCR.INVENTORY_ITEM_ID = MSI.INVENTORY_ITEM_ID
  AND MSI.ORGANIZATION_ID   = p_organization_id
  AND MSI.BOM_ITEM_TYPE     = 1
  AND MCR.cross_reference   = p_item_number;
  IF p_inventory_item      IS NOT NULL THEN
    p_valid_u8_item        := 'T';
  ELSE
    p_valid_u8_item := 'F';
  END IF;
WHEN OTHERS THEN
  p_error_msg     := p_error_msg||'Problem in determining U8 Inventory Item Id validity due to: '||SQLERRM;
  p_valid_u8_item := 'F';
END validate_u8_item;
--/****************************************************************************************************************
-- * PROCEDURE  : validate_inv_item                                                                         *
-- * Purpose   : This procedure will derive the oracle inventory item id in oracle.                          *
-- ****************************************************************************************************************/
PROCEDURE validate_inv_item(
    p_item_number     IN VARCHAR2,
    p_organization_id IN NUMBER,
    p_inventory_item OUT NUMBER,
    p_valid_inv_item OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
AS
BEGIN
  SELECT inventory_item_id
  INTO p_inventory_item
  FROM apps.mtl_system_items_b
  WHERE organization_id                  = p_organization_id
  AND segment1                           = p_item_number
  AND NVL(start_date_active,(SYSDATE-1)) < SYSDATE
  AND NVL(end_date_active,(SYSDATE  +1)) > SYSDATE;
  IF p_inventory_item                   IS NOT NULL THEN
    p_valid_inv_item                    := 'T';
  ELSE
    p_valid_inv_item := 'F';
  END IF;
EXCEPTION
WHEN OTHERS THEN
  p_error_msg      := p_error_msg||'Problem in determining Inventory Item Id validity due to: '||SQLERRM;
  p_valid_inv_item := 'F';
END validate_inv_item;
--/****************************************************************************************************************
-- * PROCEDURE  : validate_UOM                                                                         *
-- * Purpose   : This Function will check if the UOM is setup in oracle.                          *
-- ****************************************************************************************************************/
PROCEDURE validate_uom(
    p_inventory_item  IN NUMBER,
    p_organization_id IN NUMBER,
    p_unit_of_measure OUT VARCHAR2,
    p_valid_uom OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
AS
BEGIN
  SELECT primary_uom_code
  INTO p_unit_of_measure
  FROM apps.mtl_system_items_b
  WHERE organization_id = p_organization_id
  AND inventory_item_id = p_inventory_item;
  IF p_unit_of_measure IS NOT NULL THEN
    p_valid_uom        :='T';
  ELSE
    P_VALID_UOM:='F';
  END IF;
EXCEPTION
WHEN OTHERS THEN
  p_error_msg := p_error_msg||'Problem in determining Unit of measure validity due to: '||SQLERRM;
  p_valid_uom := 'F';
END validate_uom;
--/****************************************************************************************************************
-- * Function  : validate_serial_number                                                                         *
-- * Purpose   : This Function will check if the item serial code is setup in oracle.                          *
-- ****************************************************************************************************************/
FUNCTION validate_serial_lot_code(
    p_org_id  IN NUMBER,
    p_item_id IN NUMBER,
    p_serial_code OUT VARCHAR2,
    p_lot_code OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
  RETURN VARCHAR2
AS
BEGIN
  SELECT serial_number_control_code,
    lot_control_code
  INTO p_serial_code,
    p_lot_code
  FROM apps.mtl_system_items_b
  WHERE inventory_item_status_code       = 'Active'
  AND organization_id                    = p_org_id
  AND inventory_item_id                  = p_item_id
  AND NVL(start_date_active,(sysdate-1)) < sysdate
  AND NVL(end_date_active,(SYSDATE  +1)) > SYSDATE;
  RETURN 'T';
EXCEPTION
WHEN OTHERS THEN
  p_error_msg := p_error_msg||'Problem in determining serial and lot number validity due to: '||SQLERRM;
  RETURN 'F';
END validate_serial_lot_code;
--/****************************************************************************************************************
-- * Function  : get_cust_details                                                                                 *
-- * Purpose   : This Function will get the cust details if the item customer is setup in oracle.                 *
-- ****************************************************************************************************************/
FUNCTION get_cust_details(
    p_cust_num IN VARCHAR2,
    p_party_id OUT NUMBER,
    p_account_id OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
  RETURN VARCHAR2
AS
BEGIN
  SELECT party_id,
    cust_account_id
  INTO p_party_id ,
    p_account_id
  FROM apps.hz_cust_accounts
  WHERE account_number = p_cust_num;
  IF p_party_id       IS NOT NULL AND p_account_id IS NOT NULL THEN
    RETURN 'T';
  ELSE
    p_error_msg := p_error_msg||'The party id and account id is not found for cust_num: '||p_cust_num;
    RETURN 'F';
  END IF;
EXCEPTION
WHEN OTHERS THEN
  p_error_msg := p_error_msg||'Problem in determining party id and acct id validity due to: '||SQLERRM;
  RETURN 'F';
END get_cust_details;
--/****************************************************************************************************************
-- * Function  : get_location_details                                                                         *
-- * Purpose   : This Function will get the primary location of the visual customer in oracle.                          *
-- ****************************************************************************************************************/
FUNCTION get_location_details(
    p_cust_id IN VARCHAR2,
    p_org_id  IN VARCHAR2,
    p_location_id OUT NUMBER,
    p_error_msg IN OUT VARCHAR2)
  RETURN VARCHAR2
AS
BEGIN
  SELECT hps.location_id
  INTO p_location_id
  FROM apps.hz_cust_accounts cust,
    apps.hz_cust_acct_sites_all sites,
    apps.hz_cust_site_uses_all uses,
    apps.hz_party_sites hps,
    apps.org_organization_definitions org
  WHERE org.organization_id   =p_org_id
  AND cust.cust_account_id    =p_cust_id
  AND cust.cust_account_id    = sites.cust_account_id
  AND cust.status             = 'A'
  AND sites.cust_acct_site_id = uses.cust_acct_site_id
  AND sites.status            ='A'
  AND uses.site_use_code      = 'SHIP_TO'
  AND uses.primary_flag       = 'Y'
  AND uses.status             = 'A'
  AND sites.party_site_id     =hps.party_site_id
  AND uses.org_id             =org.operating_unit;
  IF p_location_id           IS NOT NULL THEN
    RETURN 'T';
  ELSE
    p_error_msg := p_error_msg||'The location id is not found for cust_num: '||p_cust_id;
    RETURN 'F';
  END IF;
EXCEPTION
WHEN OTHERS THEN
  p_error_msg := p_error_msg||'Problem in determining location id validity due to: '||SQLERRM;
  RETURN 'F';
END get_location_details;
--/****************************************************************************************************************
-- * procedure  : validate_org_code                                                                         *
-- * Purpose   : This procedure will check if the org code is setup in oracle.                          *
-- ****************************************************************************************************************/
PROCEDURE update_attributes(
    l_attribute27   IN VARCHAR2,
    l_attribute28   IN VARCHAR2,
    l_attribute29   IN VARCHAR2,
    l_attribute30   IN VARCHAR2,
    l_serial_number IN VARCHAR2,
    p_valid_att OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
AS
BEGIN
  IF l_attribute27 IS NOT NULL THEN
    UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
    SET ATTRIBUTE27    =TO_CHAR(to_date(l_attribute27,'DD-MON-YYYY'),'yyyy/mm/dd hh24:mi:ss')
    WHERE SERIAL_NUMBER=l_serial_number;
    UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
    SET ATTRIBUTE28    =TO_CHAR(to_date(l_attribute28,'DD-MON-YYYY'),'yyyy/mm/dd hh24:mi:ss')
    WHERE SERIAL_NUMBER=l_serial_number;
  END IF;
  IF l_attribute29 IS NOT NULL THEN
    UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
    SET ATTRIBUTE29    =TO_CHAR(to_date(l_attribute29,'DD-MON-YYYY'),'yyyy/mm/dd hh24:mi:ss')
    WHERE SERIAL_NUMBER=l_serial_number;
    UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
    SET ATTRIBUTE30    =TO_CHAR(to_date(l_attribute30,'DD-MON-YYYY'),'yyyy/mm/dd hh24:mi:ss')
    WHERE SERIAL_NUMBER=l_serial_number;
  END IF;
  COMMIT;
  p_valid_att := 'T';
EXCEPTION
WHEN OTHERS THEN
  p_error_msg := p_error_msg||'Problem in updating attributes validity due to: '||l_serial_number||' '||SQLERRM ;
  p_valid_att := 'F';
END update_attributes;
--/****************************************************************************************************************
-- * procedure  : item_revision                                                                         *
-- * Purpose   : This procedure will check if the org code is setup in oracle.                          *
-- ****************************************************************************************************************/
PROCEDURE item_revision(
    p_org_id  IN NUMBER,
    p_item_id IN NUMBER,
    p_item_rev OUT VARCHAR2,
    p_valid_rev OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2 )
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
  p_valid_rev := 'T';
EXCEPTION
WHEN OTHERS THEN
  p_error_msg := p_error_msg||'Problem in deriving item revision for:'||p_item_id ;
  p_valid_rev := 'F';
END item_revision;
--/****************************************************************************************************************
-- * Function  : validate_revison_code                                                                         *
-- * Purpose   : This Function will check if the item serial code is setup in oracle.                          *
-- ****************************************************************************************************************/
FUNCTION validate_revison_code(
    p_org_id  IN NUMBER,
    p_item_id IN NUMBER,
    p_revision_code OUT VARCHAR2,
    p_error_msg IN OUT VARCHAR2)
  RETURN VARCHAR2
AS
BEGIN
  SELECT revision_qty_control_code
  INTO p_revision_code
  FROM apps.mtl_system_items_b
  WHERE inventory_item_status_code       = 'Active'
  AND organization_id                    = p_org_id
  AND inventory_item_id                  = p_item_id
  AND NVL(start_date_active,(sysdate-1)) < sysdate
  AND NVL(end_date_active,(SYSDATE  +1)) > SYSDATE;
  RETURN 'T';
EXCEPTION
WHEN OTHERS THEN
  RETURN 'F';
END validate_revison_code;
--/****************************************************************************************************************
-- * PROCEDURE  : validate                                                                         *
-- * Purpose   : This procedure will Validate the data of the visual with respective to oracle.                    *
-- ****************************************************************************************************************/
PROCEDURE VALIDATE(
    x_status_return OUT VARCHAR2)
AS
  CURSOR cur_item_instance
  IS
    SELECT xiixst.rowid,
      xiixst.*
    FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE xiixst
    WHERE process_flag = 'N';
  CURSOR cur_err_rec
  IS
    SELECT xiixst.*
    FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE xiixst
    WHERE xiixst.process_flag = 'VE'
    AND xiixst.request_id     = gn_request_id;
  ln_organization_id  NUMBER;
  ln_inventory_item   NUMBER;
  ln_party_id         NUMBER;
  ln_account_id       NUMBER;
  ln_location_id      NUMBER;
  ln_u8_number        NUMBER;
  lv_serial_code      VARCHAR2(5);
  lv_lot_code         VARCHAR2(5);
  lv_customer_num     VARCHAR2(20);
  ln_unit_of_measure  VARCHAR2(20);
  ln_rec_count        NUMBER        := 0;
  ln_error_count      NUMBER        := 0;
  lv_error_msg        VARCHAR2(4000):=NULL;
  lv_valid_inv_item   VARCHAR2(2)   := NULL;
  ln_validate_count   NUMBER        := 0;
  lv_valid_org_flag   VARCHAR2(2)   := NULL;
  lv_valid_acct       VARCHAR2(2)   := NULL;
  lv_valid_org        VARCHAR2(2)   := NULL;
  lv_valid_loc        VARCHAR2(2)   := NULL;
  lv_valid_item       VARCHAR(2)    := NULL;
  lv_item_rev         VARCHAR(2)    := NULL;
  lv_valid_uom        VARCHAR(2)    :=NULL;
  lv_valid_serial_lot VARCHAR(2)    :=NULL;
  ld_sysdate          DATE          := SYSDATE;
  ld_con_prog_date    DATE;
  lc_conc_prog_name   VARCHAR2(200);
  lc_user_name        VARCHAR2(100);
  lv_valid_u8_item    VARCHAR(2) :=NULL;
  lv_valid_att        VARCHAR(2) :=NULL;
  lv_valid_rev        VARCHAR2(2):=NULL;
  lv_rev_code         VARCHAR2(2):=NULL;
  lv_valid_rev_code   VARCHAR2(2):=NULL;
BEGIN
  UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
  SET request_id    = gn_request_id,
    creation_date   = sysdate
  WHERE process_flag='N';
  -- Duplicate update
  COMMIT;
  BEGIN
    UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
    SET process_flag   = 'VE',
      error_msg        = 'Duplicate value',
      last_update_date = ld_sysdate,
      last_updated_by  = -1,
      request_id       = gn_request_id
    WHERE ROWID       IN
      (SELECT ROWID
      FROM
        (SELECT organization,
          item_number,
          serial_number,
          lot_number,
          request_id,
          ROW_NUMBER () OVER (PARTITION BY organization,item_number,serial_number,lot_number,request_id ORDER BY organization,item_number,serial_number,lot_number,request_id) AS ROW_NUMBER
        FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE
        WHERE request_id=gn_request_id
        )
      WHERE ROW_NUMBER > 1
      )
    AND request_id=gn_request_id ;
    COMMIT;
  END;
  FOR l_inst_rec IN cur_item_instance
  LOOP
    ln_rec_count               := ln_rec_count + 1 ;
    lv_error_msg               := NULL;
    ln_organization_id         := NULL;
    ln_inventory_item          := NULL;
    ln_party_id                := NULL;
    ln_account_id              := NULL;
    ln_location_id             := NULL;
    lv_serial_code             := NULL;
    lv_lot_code                := NULL;
    lv_customer_num            := NULL;
    ln_unit_of_measure         := NULL;
    ln_u8_number               := NULL;
    lv_item_rev                := NULL;
    lv_valid_rev_code          := NULL;
    lv_rev_code                :=NULL;
    IF l_inst_rec.organization IS NOT NULL THEN --validate organization code
      validate_org_code(l_inst_rec.organization,ln_organization_id,lv_valid_org,lv_error_msg);
      IF lv_valid_org = 'T' THEN
        UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
        SET INV_ORGANIZATION_ID = ln_organization_id
        WHERE ROWID             = l_inst_rec.rowid;
        COMMIT;
        IF l_inst_rec.item_number IS NOT NULL THEN --validate Item Number
          lv_valid_item           := validate_item_number(ln_organization_id,l_inst_rec.item_number,ln_u8_number,lv_error_msg);
          IF lv_valid_item         = 'T' THEN --get item id
            IF ln_u8_number        > 0 THEN
              validate_u8_item(l_inst_rec.item_number,ln_organization_id,ln_inventory_item,lv_valid_u8_item,lv_error_msg);
              IF lv_valid_u8_item = 'T' THEN
                UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
                SET item_id = ln_inventory_item
                WHERE ROWID =l_inst_rec.rowid;
                COMMIT;
              END IF;
            ELSE
              validate_inv_item(l_inst_rec.item_number,ln_organization_id,ln_inventory_item,lv_valid_inv_item,lv_error_msg);
              IF lv_valid_inv_item = 'T' THEN
                UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
                SET item_id = ln_inventory_item
                WHERE ROWID =l_inst_rec.rowid;
                COMMIT;
              END IF;
            END IF;
            lv_valid_rev_code   := validate_revison_code( ln_organization_id, ln_inventory_item ,lv_rev_code , lv_error_msg);
            IF lv_valid_rev_code = 'T' AND lv_rev_code = '2' THEN
              item_revision(ln_organization_id, ln_inventory_item, lv_item_rev, lv_valid_rev, lv_error_msg);
              IF lv_valid_rev = 'T' THEN
                UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
                SET item_rev = lv_item_rev
                WHERE ROWID  =l_inst_rec.rowid;
                COMMIT;
              END IF;
            END IF;
            validate_uom(ln_inventory_item,ln_organization_id,ln_unit_of_measure,lv_valid_uom,lv_error_msg);
            IF lv_valid_uom = 'T' THEN --uom
              UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
              SET uom    = ln_unit_of_measure
              WHERE ROWID=l_inst_rec.rowid;
              COMMIT;
              IF l_inst_rec.quantity IS NULL OR l_inst_rec.quantity < 1 THEN
                lv_error_msg         := lv_error_msg||'Quantity cannot be null or less than 1 ';
              END IF;
              lv_valid_serial_lot   := validate_serial_lot_code(ln_organization_id, ln_inventory_item, lv_serial_code,lv_lot_code,lv_error_msg);
              IF lv_valid_serial_lot = 'T' THEN --validate serial and lot code
                UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
                SET serial_number_control_code = lv_serial_code,
                  lot_control_code             = lv_lot_code
                WHERE ROWID                    =l_inst_rec.rowid;
                COMMIT;
                IF lv_serial_code     = 5 AND l_inst_rec.serial_number IS NULL THEN
                  lv_error_msg       := lv_error_msg||'serial number is mandatory ';
                elsif lv_serial_code <> 5 AND l_inst_rec.serial_number IS NOT NULL THEN
                  lv_error_msg       := lv_error_msg||'item instance should not have serial number ';
                ELSE
                  NULL;
                END IF;
                IF lv_lot_code        = 2 AND l_inst_rec.lot_number IS NULL THEN
                  lv_error_msg       := lv_error_msg||'lot number is mandatory ';
                elsif lv_serial_code <> 2 AND l_inst_rec.lot_number IS NOT NULL THEN
                  lv_error_msg       := lv_error_msg||'item instance should not have lot number ';
                ELSE
                  NULL;
                END IF;
              END IF;
              IF l_inst_rec.visual_cust_num IS NOT NULL THEN --validate customer info
                lv_customer_num             := apps.XX_COMN_CONV_UTIL_PKG.xx_comn_conv_cust_num_fnc(l_inst_rec.visual_cust_num);
                IF lv_customer_num          IS NOT NULL THEN
                  UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
                  SET owner_account_number = lv_customer_num
                  WHERE ROWID              =l_inst_rec.rowid;-- check
                  COMMIT;
                  lv_valid_acct   := get_cust_details(lv_customer_num, ln_party_id, ln_account_id,lv_error_msg);
                  IF lv_valid_acct ='T' THEN
                    UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
                    SET owner_party_num = ln_party_id,
                      owner_account_id  = ln_account_id
                    WHERE ROWID         =l_inst_rec.rowid;
                    COMMIT;
                    lv_valid_loc   := get_location_details(ln_account_id, ln_organization_id, ln_location_id,lv_error_msg);
                    IF lv_valid_loc = 'T' THEN
                      UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
                      SET location_id = ln_location_id
                      WHERE ROWID     =l_inst_rec.rowid;-- check
                      COMMIT;
                    END IF;
                  END IF;
                ELSE
                  lv_error_msg :=lv_error_msg|| 'Customer_number is not derived ';
                END IF;
              ELSE
                lv_error_msg :=lv_error_msg|| 'Customer_number cannot be null ';
              END IF;
              IF l_inst_rec.attribute29 IS NOT NULL OR l_inst_rec.attribute27 IS NOT NULL THEN
                update_attributes(l_inst_rec.attribute27, l_inst_rec.attribute28, l_inst_rec.attribute29, l_inst_rec.attribute30,l_inst_rec.serial_number, lv_valid_att, lv_error_msg);
              END IF;
            END IF;
          END IF;
        ELSE
          lv_error_msg :=lv_error_msg|| 'Item Number cannot be NULL ';
        END IF;
      END IF;
    ELSE
      lv_error_msg := lv_error_msg||'ORGANIZATION CANNOT BE NULL ';
    END IF;
    IF lv_error_msg IS NOT NULL THEN
      UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
      SET error_msg      = lv_error_msg,
        process_flag     = 'VE',
        last_update_date = ld_sysdate,
        last_updated_by  = -1
      WHERE rowid        = l_inst_rec.rowid
      AND request_id     = gn_request_id;
      x_status_return   := 'W';
    ELSE
      UPDATE stgusr.XX_CSI_ITEM_INSTANCE_STAGE
      SET error_msg      = NULL,
        process_flag     = 'V',
        last_update_date = ld_sysdate,
        last_updated_by  = -1
      WHERE rowid        = l_inst_rec.rowid
      AND request_id     = gn_request_id;
    END IF;
  END LOOP;
  COMMIT;
  SELECT COUNT(1)
  INTO ln_rec_count
  FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE
  WHERE request_id = gn_request_id;
  SELECT COUNT(1)
  INTO ln_validate_count
  FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE
  WHERE process_flag = 'V'
  AND request_id     = gn_request_id;
  SELECT COUNT(1)
  INTO ln_error_count
  FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE
  WHERE process_flag = 'VE'
  AND request_id     = gn_request_id;
  get_conc_details (gn_request_id, ld_con_prog_date, lc_conc_prog_name, lc_user_name );
  apps.xx_comn_pers_util_pkg.FND_OUT('****************************************************************');
  apps.xx_comn_pers_util_pkg.FND_OUT('                 Item Instance Summary                          ');
  apps.xx_comn_pers_util_pkg.FND_OUT('================================================================');
  apps.xx_comn_pers_util_pkg.FND_OUT('  ');
  apps.xx_comn_pers_util_pkg.FND_OUT('  ');
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Program Name ',55)||': '||lc_conc_prog_name);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Request ID ',55)||':'||gn_request_id);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('User Name ',55)||': '||lc_user_name);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Requested Date ',55)||': '||ld_con_prog_date);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Completion Date ',55)||': '||SYSDATE);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no of record validated ',55)||': '||ln_rec_count);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no records validated successfuly ',55)||': '||ln_validate_count);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Total no records errored validation ',55)||': '||ln_error_count );
  IF ln_error_count > 0 THEN
    apps.xx_comn_pers_util_pkg.FND_LOG('For error details please refer to the log file');
    apps.xx_comn_pers_util_pkg.FND_LOG('****************************************************************');
    apps.xx_comn_pers_util_pkg.FND_LOG('               Validation Error Details                         ');
    apps.xx_comn_pers_util_pkg.FND_LOG('****************************************************************');
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent program name ', 55)||': '||lc_conc_prog_name);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent Program Name ',55)||': '||lc_conc_prog_name);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent Request ID ',55)||':'||gn_request_id);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('User Name ',55)||': '||lc_user_name);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Requested Date ',55)||': '||ld_con_prog_date);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Completion Date ',55)||': '||SYSDATE);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Table Name ', 55)||': '|| 'STGUSR.XX_CSI_ITEM_INSTANCE_STAGE' );
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG('Org Code,Item Number,quantity,serial number,lot number,customer number,Error Message ');
    FOR l_rec_err IN cur_err_rec
    LOOP
      apps.xx_comn_pers_util_pkg.FND_LOG(l_rec_err.organization||','||l_rec_err.item_number||','||l_rec_err.quantity||','||l_rec_err.serial_number||','||l_rec_err.lot_number||','||l_rec_err.visual_cust_num||','||l_rec_err.error_msg );
    END LOOP;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  x_status_return := 'E';
  apps.xx_comn_pers_util_pkg.FND_LOG( 'Error while validating data in stage table due to: '||SQLERRM);
  apps.xx_comn_conv_debug_prc ( p_i_level =>NULL, p_i_proc_name => 'xx_item_instance_cnv_pkg', p_i_phase => 'validate', p_i_stgtable => 'STGUSR.XX_CSI_ITEM_INSTANCE_STAGE' , p_i_message => 'Error :'||SQLERRM);
END VALIDATE;
-- import
PROCEDURE import(
    x_status_return OUT VARCHAR2)
AS
  CURSOR cur_imp
  IS
    SELECT xiixst.ROWID,
      xiixst.*
    FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE xiixst
    WHERE xiixst.process_flag ='V';
  CURSOR cur_err_rec
  IS
    SELECT xiixst.*
    FROM stgusr.XX_CSI_ITEM_INSTANCE_STAGE xiixst
    WHERE xiixst.process_flag = 'E'
    AND xiixst.request_id     = gn_request_id;
  ln_created_by    NUMBER       := apps.fnd_global.user_id;
  lv_errbuf        VARCHAR2(4000);
  ln_msg_count     NUMBER;
  lv_return_status VARCHAR2(2);
  ln_error_count   NUMBER      :=0;
  ln_api_version   NUMBER      := 1.0;
  lv_commit        VARCHAR2(2) := apps.FND_API.G_FALSE;--CHECK
  lv_init_msg_list VARCHAR2(2) := apps.FND_API.G_TRUE;
  l_con_request_id NUMBER      := apps.fnd_global.conc_request_id;
  X_INSTANCE_REC apps.CSI_DATASTRUCTURES_PUB.INSTANCE_REC;
  X_EXT_ATTRIB_VALUES apps.CSI_DATASTRUCTURES_PUB.EXTEND_ATTRIB_VALUES_TBL;
  X_PARTY_TBL apps.CSI_DATASTRUCTURES_PUB.PARTY_TBL;
  X_ACCOUNT_TBL apps.CSI_DATASTRUCTURES_PUB.PARTY_ACCOUNT_TBL;
  X_PRICING_ATTRIB_TBL apps.CSI_DATASTRUCTURES_PUB.PRICING_ATTRIBS_TBL;
  X_ORG_ASSIGNMENTS_TBL apps.CSI_DATASTRUCTURES_PUB.ORGANIZATION_UNITS_TBL;
  X_ASSET_ASSIGNMENT_TBL apps.CSI_DATASTRUCTURES_PUB.INSTANCE_ASSET_TBL;
  X_TXN_REC apps.CSI_DATASTRUCTURES_PUB.TRANSACTION_REC;
  P_VALIDATION_LEVEL  NUMBER;
  V_INSTANCE_PARTY_ID NUMBER;
  V_IP_ACCOUNT_ID     NUMBER;
  V_SUCCESS           VARCHAR2(1) := 'T';
  p_master_org        NUMBER;
  V_INSTANCE_ID       NUMBER;
  x_msg_data          VARCHAR2(2000);
  ld_con_prog_date    DATE;
  ln_index            NUMBER := 0;
  lc_conc_prog_name   VARCHAR2(200);
  lc_user_name        VARCHAR2(100);
  ln_cnt              NUMBER := 0;
  ln_validate_count   NUMBER := 0;
BEGIN
  FOR l_rec_imp IN cur_imp
  LOOP
    ln_cnt       := ln_cnt+1;
    p_master_org := NULL;
    lv_errbuf    := NULL;
    apps.xx_comn_pers_util_pkg.FND_LOG( 'AFTER BEGIN');
    --
    --
    SELECT apps.CSI_ITEM_INSTANCES_S.NEXTVAL
    INTO V_INSTANCE_ID
    FROM sys.dual;
    SELECT master_organization_id
    INTO p_master_org
    FROM apps.mtl_parameters
    WHERE organization_id                      =l_rec_imp.INV_ORGANIZATION_ID;
    X_INSTANCE_REC.INSTANCE_ID                :=V_INSTANCE_ID;
    X_INSTANCE_REC.INSTANCE_NUMBER            :=V_INSTANCE_ID;
    X_INSTANCE_REC.INVENTORY_ITEM_ID          :=l_rec_imp.ITEM_ID;
    X_INSTANCE_REC.INV_MASTER_ORGANIZATION_ID :=p_master_org;
    X_INSTANCE_REC.SERIAL_NUMBER              :=l_rec_imp.SERIAL_NUMBER;
    X_INSTANCE_REC.MFG_SERIAL_NUMBER_FLAG     :='N';
    X_INSTANCE_REC.QUANTITY                   :=l_rec_imp.QUANTITY;
    X_INSTANCE_REC.UNIT_OF_MEASURE            :=l_rec_imp.UOM;
    X_INSTANCE_REC.ACCOUNTING_CLASS_CODE      :='CUST_PROD';
    X_INSTANCE_REC.INSTANCE_STATUS_ID         :=3;    -- ASK 510
    X_INSTANCE_REC.CUSTOMER_VIEW_FLAG         :=NULL; --N ask
    X_INSTANCE_REC.MERCHANT_VIEW_FLAG         :=NULL; --Y ask
    X_INSTANCE_REC.SELLABLE_FLAG              :=NULL; --N ask
    X_INSTANCE_REC.ACTIVE_START_DATE          :=TRUNC(SYSDATE);
    X_INSTANCE_REC.LOCATION_TYPE_CODE         :='HZ_LOCATIONS';       -- HZ_PARTY_SITES
    X_INSTANCE_REC.LOCATION_ID                :=l_rec_imp.LOCATION_ID;-- LOCATION NEED TO WRITE
    X_INSTANCE_REC.INSTALL_DATE               :=l_rec_imp.INSTALL_DATE;
    X_INSTANCE_REC.CREATION_COMPLETE_FLAG     :='Y';
    X_INSTANCE_REC.VERSION_LABEL              :='AS_CREATED';
    X_INSTANCE_REC.ATTRIBUTE27                :=l_rec_imp.ATTRIBUTE27;
    X_INSTANCE_REC.ATTRIBUTE28                :=l_rec_imp.ATTRIBUTE28;
    X_INSTANCE_REC.ATTRIBUTE29                :=l_rec_imp.ATTRIBUTE29;
    X_INSTANCE_REC.ATTRIBUTE30                :=l_rec_imp.ATTRIBUTE30;
    -- X_INSTANCE_REC.LAST_OE_PO_NUMBER     :='SO100'; -- ASK
    X_INSTANCE_REC.OBJECT_VERSION_NUMBER :=1;                            -- ASK IS IT NULL
    X_INSTANCE_REC.VLD_ORGANIZATION_ID   :=l_rec_imp.INV_ORGANIZATION_ID;--ADDED
    --  X_INSTANCE_REC.OWNER_PARTY_ID      :=l_rec_imp.owner_party_num;--optional
    X_INSTANCE_REC.inventory_revision :=l_rec_imp.item_rev;
    -- ************* FOR PARTIES **********************************************************
    --
    SELECT apps.CSI_I_PARTIES_S.NEXTVAL
    INTO V_INSTANCE_PARTY_ID
    FROM sys.dual;
    X_PARTY_TBL(1).INSTANCE_PARTY_ID      :=V_INSTANCE_PARTY_ID;
    X_PARTY_TBL(1).INSTANCE_ID            :=V_INSTANCE_ID;
    X_PARTY_TBL(1).PARTY_SOURCE_TABLE     :='HZ_PARTIES';
    X_PARTY_TBL(1).PARTY_ID               := l_rec_imp.owner_party_num;
    X_PARTY_TBL(1).RELATIONSHIP_TYPE_CODE := 'OWNER';
    X_PARTY_TBL(1).CONTACT_FLAG           := 'N';
    X_PARTY_TBL(1).ACTIVE_START_DATE      := SYSDATE;
    X_PARTY_TBL(1).OBJECT_VERSION_NUMBER  := 1;
    --
    --
    -- *********** FOR PARTY ACCOUNT *****************************************************
    SELECT apps.CSI_IP_ACCOUNTS_S.NEXTVAL
    INTO V_IP_ACCOUNT_ID
    FROM sys.dual;
    X_ACCOUNT_TBL(1).IP_ACCOUNT_ID          := V_IP_ACCOUNT_ID ;
    X_ACCOUNT_TBL(1).INSTANCE_PARTY_ID      := V_INSTANCE_PARTY_ID;
    X_ACCOUNT_TBL(1).PARTY_ACCOUNT_ID       := l_rec_imp.OWNER_ACCOUNT_ID;
    X_ACCOUNT_TBL(1).RELATIONSHIP_TYPE_CODE := 'OWNER';
    X_ACCOUNT_TBL(1).BILL_TO_ADDRESS        := NULL;--l_rec_imp.BILL_TO_ADDRESS;--ask
    X_ACCOUNT_TBL(1).SHIP_TO_ADDRESS        := NULL;--l_rec_imp.SHIP_TO_ADDRESS;--ask
    X_ACCOUNT_TBL(1).ACTIVE_START_DATE      := SYSDATE;
    X_ACCOUNT_TBL(1).OBJECT_VERSION_NUMBER  := 1;
    X_ACCOUNT_TBL(1).PARENT_TBL_INDEX       := 1;
    X_ACCOUNT_TBL(1).CALL_CONTRACTS         := 'Y';
    --
    -- ************************** TRANSACTION REC *****************************************
    X_TXN_REC.TRANSACTION_DATE        := TRUNC(SYSDATE);
    X_TXN_REC.SOURCE_TRANSACTION_DATE := TRUNC(SYSDATE);
    X_TXN_REC.TRANSACTION_TYPE_ID     := 1;
    X_TXN_REC.OBJECT_VERSION_NUMBER   := 1;
    --
    --
    --
    -- *************** API CALL *******************************************************
    --
    apps.xx_comn_pers_util_pkg.FND_LOG( 'BEFORE CREATE ITEM INSTANCE');
    apps.xx_comn_pers_util_pkg.FND_LOG('BEFORE CREATE ITEM INSTANCE');
    apps.xx_comn_pers_util_pkg.XX_ITEM_INSTANCE_PRC ( ln_api_version , lv_commit , lv_init_msg_list , p_validation_level , x_instance_rec , x_ext_attrib_values , x_party_tbl , x_account_tbl , x_pricing_attrib_tbl , x_org_assignments_tbl , x_asset_assignment_tbl , x_txn_rec , lv_return_status , ln_msg_count , x_msg_data);
    COMMIT;
    apps.xx_comn_pers_util_pkg.FND_LOG( 'AFTER CREATE ITEM INSTANCE');
    IF lv_return_status != APPS.FND_API.G_RET_STS_SUCCESS THEN
      apps.xx_comn_pers_util_pkg.FND_LOG( 'failed. printing error msg...');
      apps.xx_comn_pers_util_pkg.FND_LOG( APPS.FND_MSG_PUB.Get( p_msg_index => APPS.FND_MSG_PUB.G_LAST, p_encoded => APPS.FND_API.G_FALSE));
      V_SUCCESS := 'F';
      UPDATE STGUSR.XX_CSI_ITEM_INSTANCE_STAGE
      SET PROCESS_FLAG   = 'E',
        error_msg        = lv_errbuf,
        last_update_date = SYSDATE,
        last_updated_by  = ln_created_by,
        request_id       = l_con_request_id
      WHERE ROWID        = l_rec_imp.rowid;
      ln_error_count    := ln_error_count + 1;
      x_status_return   := 'W';
    ELSE
      apps.xx_comn_pers_util_pkg.FND_LOG( 'Inserted Install base data');
      apps.xx_comn_pers_util_pkg.FND_LOG( ' The instance Id is#: ' || v_instance_id);
      UPDATE STGUSR.XX_CSI_ITEM_INSTANCE_STAGE
      SET process_flag   = 'P' ,
        last_update_date = SYSDATE ,
        last_updated_by  = ln_created_by,
        request_id       = l_con_request_id
      WHERE ROWID        = l_rec_imp.rowid;
      ln_validate_count := ln_validate_count +1 ;
      COMMIT;
    END IF;
  END LOOP;
  COMMIT;
  get_conc_details (l_con_request_id, ld_con_prog_date, lc_conc_prog_name, lc_user_name );
  apps.xx_comn_pers_util_pkg.FND_OUT('****************************************************************');
  apps.xx_comn_pers_util_pkg.FND_OUT('                 Item Instance Summary                           ');
  apps.xx_comn_pers_util_pkg.FND_OUT('================================================================');
  apps.xx_comn_pers_util_pkg.FND_LOG(' ');
  apps.xx_comn_pers_util_pkg.FND_LOG(' ');
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Program Name ',55)||': '||lc_conc_prog_name);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Concurrent Request ID ',55)||': '||l_con_request_id);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('User Name ',55)||': '||lc_user_name);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Requested Date ',55)||': '||ld_con_prog_date);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('Completion Date ',55)||': '||SYSDATE);
  apps.xx_comn_pers_util_pkg.FND_LOG(' ');
  apps.xx_comn_pers_util_pkg.FND_LOG(' ');
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('No. of records processed for import ',55)||': '||ln_cnt);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('No. of records imported successfully ',55)||': '||ln_validate_count);
  apps.xx_comn_pers_util_pkg.FND_OUT(RPAD('No. of records failed import ',55)||' :'||ln_error_count );
  IF ln_error_count > 0 THEN
    apps.xx_comn_pers_util_pkg.FND_LOG('For error details please refer to the log file');
    apps.xx_comn_pers_util_pkg.FND_LOG('****************************************************************');
    apps.xx_comn_pers_util_pkg.FND_LOG('               Import Error Details                         ');
    apps.xx_comn_pers_util_pkg.FND_LOG('****************************************************************');
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent program name ', 55)||': '||lc_conc_prog_name);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent Program Name ',55)||': '||lc_conc_prog_name);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Concurrent Request ID ',55)||':'||gn_request_id);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('User Name ',55)||': '||lc_user_name);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Requested Date ',55)||': '||ld_con_prog_date);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Completion Date ',55)||': '||SYSDATE);
    apps.xx_comn_pers_util_pkg.FND_LOG(RPAD('Table Name ', 55)||': '|| 'STGUSR.XX_CSI_ITEM_INSTANCE_STAGE' );
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG(' ');
    apps.xx_comn_pers_util_pkg.FND_LOG('Org Code,Item Number,quantity,serial number,lot number,customer number,Error Message ');
    FOR l_rec_err IN cur_err_rec
    LOOP
      apps.xx_comn_pers_util_pkg.FND_LOG(l_rec_err.organization||','||l_rec_err.item_number||','||l_rec_err.quantity||','||l_rec_err.serial_number||','||l_rec_err.lot_number||','||l_rec_err.visual_cust_num||','||l_rec_err.error_msg );
    END LOOP;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  x_status_return := 'E';
  apps.xx_comn_pers_util_pkg.FND_LOG( 'Error while importing data in base table due to: '||SQLERRM);
  apps.xx_comn_conv_debug_prc ( p_i_level =>NULL, p_i_proc_name => 'xx_inv_item_xref_cnv_pkg', p_i_phase => 'Import', p_i_stgtable => 'STGUSR.XX_CSI_ITEM_INSTANCE_STAGE' , p_i_message => 'Error :'||SQLERRM);
END import;
PROCEDURE main(
    p_o_err_buff OUT VARCHAR2,
    p_o_ret_code OUT NUMBER,
    p_i_run_mode IN VARCHAR2 )
AS
  lv_err_flag VARCHAR2(5) := NULL;
BEGIN
  --Calling the Procedure for Validation or Import
  IF p_i_run_mode = 'VALIDATE' THEN
    VALIDATE (lv_err_flag);
  ELSIF p_i_run_mode = 'TRANSFER' THEN
    import (lv_err_flag);
  END IF;
  IF lv_err_flag    = 'W' THEN
    p_o_ret_code   := 1;
  ELSIF lv_err_flag = 'E' THEN
    p_o_ret_code   := 2;
  ELSE
    p_o_ret_code := 0;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  p_o_ret_code := 2;
  apps.fnd_file.put_line(apps.fnd_file.LOG,'Error while calling main program: '||SQLERRM);
  apps.xx_comn_conv_debug_prc ( p_i_level =>NULL, p_i_proc_name => 'xx_item_instance_cnv_pkg', p_i_phase => 'Main', p_i_stgtable => 'STGUSR.XX_CSI_ITEM_INSTANCE_STAGE' , p_i_message => 'Error in Main'||SQLERRM);
END main;
END xx_item_instance_cnv_pkg;
/