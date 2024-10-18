create or replace PACKAGE BODY       APPS.xx_om_so_hold_conv_pkg
IS
   /* $Header: XX_OM_SO_HOLD_CONV_PKG.pkb 1.0 2020/06/22 17:10:00 Sankalpa Saha $ */
   /*=================================================================================================================================+
   | Package: XX_OM_SO_HOLD_CONV_PKG
   +-----------------------------------------------------------------------------------------------------------------------------------+
   | Description: This is a package for VISUAL to EBS sales order and order hold conversion
   -++--------------------------------------------------------------------------------------------------------------------------------++
   | History
   | Author              | Date           | Version    | Descriptiom
   ++---------------------------------------------------------------------------------------------------------------------------------++
   | Sankalpa Saha       | 06/22/2020     | 1.0        | Initial Version
   | Sankalpa Saha       | 03/01/2021     | 2.0        | Changes in SBC Import program output as suggested by business
   | Sankalpa Saha       | 03/17/2021     | 3.0        | Changes in SBC Import program for currency code issue OSSATSTING-21988
   | Sankalpa Saha       | 03/24/2021     | 4.0        | Changes in SBC Import program for duplicate item issue OSSATSTING-21988
   | Sankalpa Saha       | 06/30/2021     | 5.0        | Changes due to change in fields/columns in data file, fix for OU identification
   +==================================================================================================================================*/
   /*****************************************
   --Declaring Global Variables---
   *****************************************/
   gn_batch_id_num         NUMBER    := 0;
   gn_request_id           NUMBER;
   e_validation_warn       EXCEPTION;
   e_submit_api_error      EXCEPTION;
   e_customer_site_error   EXCEPTION;
   e_operating_unit_error  EXCEPTION;

  /******************************************************
  -- Procedure  to get operating unit of submitted request --
  *******************************************************/
   PROCEDURE get_org_id (
      p_org_id       OUT NUMBER )
   AS   
   BEGIN
     p_org_id := mo_global.get_current_org_id;   -- Changes start by Sankalpa on 30-Jun-2021 for OU identification in Project Revival
     /*SELECT distinct hou.organization_id
       INTO p_org_id
       FROM customusr.xx_om_so_hold_conv_stg_tbl xx,
            hr_operating_units hou
      WHERE 1=1
        AND xx.org_name = hou.name
        AND xx.sold_to_id IS NOT NULL
        AND batch_id = gn_batch_id_num; */        -- Changes end by Sankalpa on 30-Jun-2021 for OU identification in Project Revival

   EXCEPTION
     WHEN OTHERS THEN
        p_org_id := NULL;
   END get_org_id ; 

/******************************************************
-- Procedure  to site as BILL_TO/SHIP_TO --
*******************************************************/
   PROCEDURE create_customer_site_use_code (
      p_customer_acc             IN       VARCHAR2,
      p_address1                 IN       VARCHAR2,
      p_address2                 IN       VARCHAR2,
      p_address3                 IN       VARCHAR2,
      p_address4                 IN       VARCHAR2,
      p_city                     IN       VARCHAR2,
      p_country                  IN       VARCHAR2,
      p_county                   IN       VARCHAR2,
      p_state                    IN       VARCHAR2,
      p_postal_code              IN       VARCHAR2,
      p_site_use_code            IN       VARCHAR2,
      p_site_use_id              OUT      NUMBER)
   AS
      l_location_rec_type           hz_location_v2pub.location_rec_type;
      l_party_site_rec_type         hz_party_site_v2pub.party_site_rec_type;
      l_cust_acct_site_rec_type     hz_cust_account_site_v2pub.cust_acct_site_rec_type;
      l_cust_site_use_rec_type      hz_cust_account_site_v2pub.cust_site_use_rec_type;
      x_site_use_id                 NUMBER;
      x_return_status               VARCHAR2 (2000);
      x_msg_count                   NUMBER;
      x_msg_data                    VARCHAR2 (2000);
      --lv_customer_acc               VARCHAR2 (200);
      ln_location_id                NUMBER;
      ln_party_site_id              NUMBER;
      ln_cust_acct_id               NUMBER;
      ln_site_use_id                NUMBER;
      ln_cust_acct_site_id          NUMBER;
      ln_cust_account_id            NUMBER;
      ln_party_id                   NUMBER;
      lv_party_site_number          VARCHAR2 (2000);
      lv_addr_val_status            VARCHAR2 (10);
      lv_addr_warn_msg              VARCHAR2 (4000);
      lv_loc_api_return_status      VARCHAR2 (10);
      ln_org_id                     NUMBER;
      ln_loc_msg_count              NUMBER;
      lv_loc_msg_data               VARCHAR2 (4000);
      lv_party_site_return_status   VARCHAR2 (10);
      ln_party_site_msg_count       NUMBER;
      lv_party_site_msg_data        VARCHAR2 (4000);
      lv_cust_site_return_status    VARCHAR2 (10);
      ln_cust_site_msg_count        NUMBER;
      lv_cust_site_msg_data         VARCHAR2 (4000);
      lv_site_use_return_status     VARCHAR2 (10);
      ln_site_use_msg_count         NUMBER;
      lv_site_use_msg_data          VARCHAR2 (4000);
   BEGIN
      --ln_org_id := fnd_profile.VALUE ('ORG_ID');      
      get_org_id (p_org_id     => ln_org_id );
      mo_global.set_policy_context ('S', ln_org_id);

      fnd_global.apps_initialize (user_id           => fnd_profile.VALUE ('USER_ID'),
                                  resp_id           => fnd_profile.VALUE ('RESP_ID'),
                                  resp_appl_id      => fnd_profile.VALUE ('RESP_APPL_ID'));      

      /*BEGIN
         SELECT XX_COMN_CONV_UTIL_PKG.XX_COMN_CONV_CUST_NUM_FNC(p_i_legacy_cust_num => lv_customer_acc)
           INTO lv_customer_acc
           FROM DUAL;

      EXCEPTION
        WHEN OTHERS
        THEN           
           lv_customer_acc := 0;
      END;         
      fnd_file.put_line (fnd_file.LOG, 'Customer account for customer_site_use_id creation - '||lv_customer_acc);*/

      BEGIN
         --CREATE CUSTOMER LOCATION
         l_location_rec_type.country := p_country;
         l_location_rec_type.address1 := p_address1;
         l_location_rec_type.address2 := p_address2;
         l_location_rec_type.address3 := p_address3;
         l_location_rec_type.address4 := p_address4;
         l_location_rec_type.city := p_city;
         l_location_rec_type.postal_code := p_postal_code;
		 -- Changes start by Sankalpa on 30-Jun-2021 for Project Revival
         IF UPPER(p_country) = 'CA'
         THEN
           l_location_rec_type.state := NULL;
           l_location_rec_type.county := p_state;
           l_location_rec_type.province := p_state;
         ELSE
           l_location_rec_type.state := p_state;
           l_location_rec_type.county := p_county;
         END IF;
		 -- Changes end by Sankalpa on 30-Jun-2021 for Project Revival
         l_location_rec_type.created_by_module := 'HZ_CPUI';
         --l_location_rec_type.orig_system_reference := NULL;
         fnd_file.put_line (fnd_file.LOG, 'Submitting API to create location....');

         hz_location_v2pub.create_location (p_init_msg_list        => fnd_api.g_false,
                                            p_location_rec         => l_location_rec_type,
                                            p_do_addr_val          => NULL,
                                            x_location_id          => ln_location_id,
                                            x_addr_val_status      => lv_addr_val_status,
                                            x_addr_warn_msg        => lv_addr_warn_msg,
                                            x_return_status        => lv_loc_api_return_status,
                                            x_msg_count            => ln_loc_msg_count,
                                            x_msg_data             => lv_loc_msg_data);
         COMMIT;
         --fnd_file.put_line (fnd_file.LOG, 'ln_location_id: ' || ln_location_id);
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, 'Failed to submit hz_location_v2pub.create_location API');
            RAISE e_customer_site_error;
      END;

      IF (lv_loc_api_return_status = fnd_api.g_ret_sts_error)
      THEN
         FOR i IN 1 .. ln_loc_msg_count
         LOOP
            lv_loc_msg_data := fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            fnd_file.put_line (fnd_file.LOG, i || '|' || lv_loc_msg_data);
         END LOOP;
         RAISE e_customer_site_error;
      ELSE
         fnd_file.put_line (fnd_file.LOG,'Creation of Location is successful with location: '||ln_location_id || ' for customer acc# '||p_customer_acc );
         BEGIN
            SELECT hca.party_id,                  
                   hca.cust_account_id
            INTO   ln_party_id,                   
                   ln_cust_account_id
            FROM   hz_cust_accounts hca/*,
                   hz_parties hp*/
            WHERE  /*hca.party_id = hca.party_id
            AND    */hca.account_number = p_customer_acc;

         EXCEPTION
            WHEN OTHERS
            THEN
               ln_party_id := 0;  
               ln_cust_account_id := 0;
               RAISE e_customer_site_error;
         END;
         --fnd_file.put_line (fnd_file.LOG, 'Party ID before submitting API create_party_site - ' || ln_party_id);
         --fnd_file.put_line (fnd_file.LOG, 'Loction ID before submitting API create_party_site - ' || ln_location_id);
         BEGIN
            l_party_site_rec_type.party_id := ln_party_id;
            l_party_site_rec_type.identifying_address_flag := 'N';  --'Y';
            l_party_site_rec_type.created_by_module := 'HZ_CPUI';
            l_party_site_rec_type.location_id := ln_location_id;
            l_party_site_rec_type.status := 'A';

            hz_party_site_v2pub.create_party_site (p_init_msg_list          => fnd_api.g_false,
                                                   p_party_site_rec         => l_party_site_rec_type,
                                                   x_party_site_id          => ln_party_site_id,
                                                   x_party_site_number      => lv_party_site_number,
                                                   x_return_status          => lv_party_site_return_status,
                                                   x_msg_count              => ln_party_site_msg_count,
                                                   x_msg_data               => lv_party_site_msg_data);
            COMMIT;
            fnd_file.put_line (fnd_file.LOG, 'ln_party_site_id' || ln_party_site_id);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG, 'Failed to submit hz_party_site_v2pub.create_party_site API');
               RAISE e_customer_site_error;
         END;

         IF (lv_party_site_return_status = fnd_api.g_ret_sts_error)
         THEN
            FOR i IN 1 .. ln_party_site_msg_count
            LOOP
               lv_party_site_msg_data := fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
               fnd_file.put_line (fnd_file.LOG, i || '|' || lv_party_site_msg_data);
            END LOOP;

            RAISE e_customer_site_error;
         ELSE
            BEGIN
               fnd_file.put_line (fnd_file.LOG, 'Creation of party site successful with party_site_id: '|| ln_party_site_id);
               -- CREATE CUSTOMER ACCT SITE
               l_cust_acct_site_rec_type.cust_account_id := ln_cust_account_id;
               l_cust_acct_site_rec_type.party_site_id := ln_party_site_id;
               l_cust_acct_site_rec_type.created_by_module := 'HZ_CPUI';
               l_cust_acct_site_rec_type.orig_system_reference := NULL;
               l_cust_acct_site_rec_type.status := 'A';
               l_cust_acct_site_rec_type.org_id := ln_org_id;

               hz_cust_account_site_v2pub.create_cust_acct_site (p_init_msg_list           => fnd_api.g_false,
                                                                 p_cust_acct_site_rec      => l_cust_acct_site_rec_type,
                                                                 x_cust_acct_site_id       => ln_cust_acct_site_id,
                                                                 x_return_status           => lv_cust_site_return_status,
                                                                 x_msg_count               => ln_cust_site_msg_count,
                                                                 x_msg_data                => lv_cust_site_msg_data);
               COMMIT;
               --fnd_file.put_line (fnd_file.LOG, 'ln_cust_acct_site_id: ' || ln_cust_acct_site_id);
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line (fnd_file.LOG, 'Failed to submit hz_cust_account_site_v2pub.create_cust_acct_site API');
                  RAISE e_customer_site_error;
            END;

            IF (lv_cust_site_return_status = fnd_api.g_ret_sts_error)
            THEN
               FOR i IN 1 .. ln_cust_site_msg_count
               LOOP
                  lv_cust_site_msg_data := fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                  fnd_file.put_line (fnd_file.LOG, i || '|' || lv_cust_site_msg_data);
               END LOOP;

               RAISE e_customer_site_error;
            ELSE
               BEGIN
                  fnd_file.put_line (fnd_file.LOG, 'Creation of customer account site site successful with cust_acct_site_id :'|| ln_cust_acct_site_id);
                  -- CREATE CUSTOMER SITE USE
                  l_cust_site_use_rec_type.LOCATION := ln_location_id;
                  l_cust_site_use_rec_type.created_by_module := 'HZ_CPUI';
                  l_cust_site_use_rec_type.status := 'A';
                  l_cust_site_use_rec_type.org_id := ln_org_id;
                  l_cust_site_use_rec_type.primary_salesrep_id := NULL;
                  l_cust_site_use_rec_type.cust_acct_site_id := ln_cust_acct_site_id;
                  l_cust_site_use_rec_type.site_use_code := p_site_use_code;

                  hz_cust_account_site_v2pub.create_cust_site_use (p_init_msg_list             => fnd_api.g_false,
                                                                   p_cust_site_use_rec         => l_cust_site_use_rec_type,
                                                                   p_customer_profile_rec      => NULL,
                                                                   -- Modified by YerraS on 19-Sep-09
                                                                   p_create_profile            => fnd_api.g_true,
                                                                   p_create_profile_amt        => fnd_api.g_true,
                                                                   x_site_use_id               => ln_site_use_id,
                                                                   x_return_status             => lv_site_use_return_status,
                                                                   x_msg_count                 => ln_site_use_msg_count,
                                                                   x_msg_data                  => lv_site_use_msg_data);
                  COMMIT;
                  fnd_file.put_line (fnd_file.LOG, 'site_use_id: ' || ln_site_use_id);
                  p_site_use_id := ln_site_use_id ;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line (fnd_file.LOG,
                                        'Failed to submit hz_cust_account_site_v2pub.create_cust_acct_site API');
                     RAISE e_customer_site_error;                   
               END;

               IF (lv_site_use_return_status = fnd_api.g_ret_sts_error)
               THEN
                  FOR i IN 1 .. ln_site_use_msg_count
                  LOOP
                     lv_site_use_msg_data := fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                     fnd_file.put_line (fnd_file.LOG, i || ') ' || lv_site_use_msg_data);
                  END LOOP;
               END IF;
            END IF;
         END IF;
      END IF;
   EXCEPTION
      WHEN e_customer_site_error
      THEN
         p_site_use_id := NULL;
         fnd_file.put_line (fnd_file.LOG,
                               'Error creating site use code in create_customer_site_use_code. '
                            || SQLCODE
                            || ' SQLERRM :'
                            || SQLERRM);
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'create_customer_site_use_code',
                                 p_i_phase          => 'Create Customer Site Use Code',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Error creating site use code in create_customer_site_use_code.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
      WHEN OTHERS
      THEN
         p_site_use_id := NULL;
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal error in create_customer_site_use_code.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'create_customer_site_use_code',
                                 p_i_phase          => 'Create Customer Site Use Code',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in create_customer_site_use_code.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
   END create_customer_site_use_code;

    /**********************************************
    -- Function to check if order already exists --
    **********************************************/
   FUNCTION validate_duplicate (
      p_order_number             IN       VARCHAR2,
      p_org_name                 IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_order_exists   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
      INTO   ln_order_exists
      FROM   oe_order_headers_all ooh,
             org_organization_definitions ood
      WHERE  ooh.orig_sys_document_ref = p_order_number
        AND  ooh.org_id = ood.organization_id
        AND  ood.organization_code = p_org_name;

      IF (ln_order_exists > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Duplicate order. ');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_duplicate',
                                 p_i_phase          => 'Duplicate Order Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Duplicate order in validate_duplicate.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SQLERRM);
         RETURN ('Y');
   END validate_duplicate;

   /**********************************************
    -- Function to check if order already exists --
    **********************************************/
   FUNCTION validate_sbc_duplicate (
      p_customer_po_number       IN       VARCHAR2,
      p_org_name                 IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_order_exists   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
      INTO   ln_order_exists
      FROM   oe_order_headers_all ooh,
             org_organization_definitions ood
      WHERE  ooh.cust_po_number = p_customer_po_number
        AND  ooh.org_id = ood.organization_id
        AND  ood.organization_code = p_org_name;

      IF (ln_order_exists > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Duplicate SBC order.SQLCODE: ' || SQLCODE || ' SQLERRM :' || SQLERRM);
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_sbc_duplicate',
                                 p_i_phase          => 'Duplicate SBC Order Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Duplicate SBC order in validate_duplicate.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SQLERRM);
         RETURN ('Y');
   END validate_sbc_duplicate;

/**********************************************
-- Function to check valid OU exists --
**********************************************/
   FUNCTION validate_ou (
      p_operating_unit           IN       VARCHAR2)
      RETURN NUMBER
   AS
      ln_org_id   NUMBER := 0;
   BEGIN
      SELECT organization_id
      INTO   ln_org_id
      FROM   hr_operating_units
      WHERE  NAME = p_operating_unit
      AND    SYSDATE BETWEEN date_from AND NVL (date_to, SYSDATE + 1);

      RETURN ln_org_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Invalid operating unit in deriving org_id.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_ou',
                                 p_i_phase          => 'Operating Unit Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Invalid operating unit in validate_ou.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN (ln_org_id);
   END validate_ou;

/**********************************************
-- Procedure to get order transaction type --
**********************************************/
   PROCEDURE get_transaction_type (
      p_org_name                 IN       VARCHAR2,
      p_hdr_trx_type_id          OUT      NUMBER,
      p_ln_trx_type_id           OUT      NUMBER)
   AS
      lc_header_order_type   VARCHAR2 (200) := 'STANDARD_ORDER_';
      lc_line_order_type     VARCHAR2 (200) := 'LINE_STANDARD_';
      lv_ou_name             VARCHAR2 (200) := NULL;
   BEGIN
      BEGIN
         SELECT SUBSTR (p_org_name, 1, INSTR (p_org_name, ' ') - 1)
         INTO   lv_ou_name
         FROM   DUAL;

         lc_header_order_type := lc_header_order_type || lv_ou_name;
         lc_line_order_type := lc_line_order_type || lv_ou_name;
      EXCEPTION
         WHEN OTHERS
         THEN
            lv_ou_name := NULL;
      END;

      BEGIN
         SELECT otta.transaction_type_id
         INTO   p_hdr_trx_type_id
         FROM   oe_transaction_types_tl ottt,
                oe_transaction_types_all otta
         WHERE  NAME = lc_header_order_type
         AND    ottt.LANGUAGE = 'US'
         AND    ottt.transaction_type_id = otta.transaction_type_id
         AND    otta.transaction_type_code = 'ORDER'
         AND    SYSDATE BETWEEN otta.start_date_active AND NVL (otta.end_date_active, SYSDATE + 1);
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in deriving header transaction type.SQLCODE: ' || SQLCODE || ' SQLERRM :' || SQLERRM);
            p_hdr_trx_type_id := 0;
      END;

      BEGIN
         SELECT otta.transaction_type_id
         INTO   p_ln_trx_type_id
         FROM   oe_transaction_types_tl ottt,
                oe_transaction_types_all otta
         WHERE  NAME = lc_line_order_type
         AND    ottt.LANGUAGE = 'US'
         AND    ottt.transaction_type_id = otta.transaction_type_id
         AND    otta.transaction_type_code = 'LINE'
         AND    SYSDATE BETWEEN otta.start_date_active AND NVL (otta.end_date_active, SYSDATE + 1);
      EXCEPTION
         WHEN OTHERS
         THEN
            p_ln_trx_type_id := 0;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in deriving line transaction type.SQLCODE: ' || SQLCODE || ' SQLERRM :' || SQLERRM);
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal Error in transaction type derivation.SQLCODE: ' || SQLCODE || ' SQLERRM :' || SQLERRM);
         p_ln_trx_type_id := 0;
         p_hdr_trx_type_id := 0;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'get_transaction_type',
                                 p_i_phase          => 'Get Order Transaction Type',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in get_transaction_type.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
   END get_transaction_type;

/**********************************************
-- Procedure to validate order source --
**********************************************/
   PROCEDURE validate_order_source (
      p_source                   IN       VARCHAR2,
      p_source_id                OUT      NUMBER)
   AS
   BEGIN
      SELECT order_source_id
      INTO   p_source_id
      FROM   oe_order_sources
      WHERE  NAME = p_source
      AND    enabled_flag = 'Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Invalid order source.');
         p_source_id := 0;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_order_source',
                                 p_i_phase          => 'Order Source Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Invalid order source in validate_order_source.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
   END validate_order_source;

/**********************************************
-- Procedure to validate customer --
**********************************************/
   PROCEDURE validate_customer (
      p_customer_acc           IN       VARCHAR2,
      p_customer_number         OUT      NUMBER)
   AS
      lv_customer_acc VARCHAR2(2000);
   BEGIN
      SELECT XX_COMN_CONV_UTIL_PKG.XX_COMN_CONV_CUST_NUM_FNC(p_i_legacy_cust_num => p_customer_number)
       INTO lv_customer_acc
       FROM DUAL;

      SELECT hp.party_number
        INTO p_customer_number
        FROM HZ_CUST_ACCOUNTS HCA
            ,HZ_PARTIES HP
        WHERE 1=1
        AND HP.PARTY_ID = HCA.PARTY_ID
        AND hca.account_number = lv_customer_acc ;
        --AND HCA.ORIG_SYSTEM_REFERENCE IS NOT NULL;*/
        --p_customer_number := XX_COMN_CONV_UTIL_PKG.XX_COMN_CONV_CUST_NUM_FNC(p_i_legacy_cust_num => p_customer_name);
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Invalid customer in deriving party id.');
         p_customer_number := NULL;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_customer',
                                 p_i_phase          => 'Customer Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Invalid customer in validate_customer.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
   END validate_customer;

    /**********************************************
    -- Procedure to validate customer account --
    **********************************************/
   PROCEDURE validate_customer_account (
      p_customer_number          IN       VARCHAR2,
      p_customer_acc             OUT      NUMBER)
   AS
     lv_customer_acc    NUMBER;
   BEGIN
     SELECT XX_COMN_CONV_UTIL_PKG.XX_COMN_CONV_CUST_NUM_FNC(p_i_legacy_cust_num => p_customer_number)
       INTO lv_customer_acc				-- Changes start by Sankalpa on 30-Jun-2021 for Project Revival
	   --INTO p_customer_acc
       FROM DUAL;

    SELECT cust_account_id
      INTO p_customer_acc
      FROM hz_cust_accounts
     WHERE account_number = lv_customer_acc
       AND status = 'A';				-- Changes end by Sankalpa on 30-Jun-2021 for Project Revival

   EXCEPTION
      WHEN OTHERS
      THEN
         --fnd_file.put_line (fnd_file.LOG, 'Invalid customer account. ');  -- Commented by Sankalpa on 30-Jun-2021 for Project Revival
         p_customer_acc := 0;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_customer_account',
                                 p_i_phase          => 'Customer Account Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Invalid/ Inactive customer account in validate_customer_account.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
   END validate_customer_account;

    /**********************************************
    -- Procedure to validate customer BILL_TO --
    **********************************************/
   PROCEDURE validate_customer_bill_to (
      p_customer_number          IN       VARCHAR2,
      p_address1                 IN       VARCHAR2,
      p_address2                 IN       VARCHAR2,
      p_address3                 IN       VARCHAR2,
      p_address4                 IN       VARCHAR2,
      p_city                     IN       VARCHAR2,
      p_country                  IN       VARCHAR2,
      p_county                   IN       VARCHAR2,
      p_state                    IN       VARCHAR2,
      p_postal_code              IN       VARCHAR2,
      p_bill_to_org_id           OUT      NUMBER)
   AS
      lv_site_use_code      VARCHAR2 (20) := 'BILL_TO';
      lv_customer_acc       VARCHAR2 (200) := NULL;
      ln_org_id             NUMBER := NULL;  
   BEGIN
      get_org_id (p_org_id     => ln_org_id );

      BEGIN
         SELECT XX_COMN_CONV_UTIL_PKG.XX_COMN_CONV_CUST_NUM_FNC(p_i_legacy_cust_num => p_customer_number)
           INTO lv_customer_acc
           FROM DUAL;

      EXCEPTION
        WHEN OTHERS
        THEN           
           lv_customer_acc := 0;
      END;   

      fnd_file.put_line (fnd_file.LOG, 'Customer account for bill_to validation - '||lv_customer_acc);
	  -- Changes start by Sankalpa on 30-Jun-2021 for BILL_TO site in Project Revival
      -- Get site_use_id of customer using customer_bill_to
      /*SELECT DISTINCT (hzs.site_use_id)
      INTO            p_bill_to_org_id
      FROM            hz_cust_accounts hza,
                      hz_cust_site_uses_all hzs,
                      hz_cust_acct_sites_all hzas,
                      hz_parties hp,
                      hz_party_sites hps,
                      hz_locations hl
      WHERE           hl.address1 = p_address1
        AND             NVL (hl.address2, 'xx') = NVL (p_address2, 'xx')
        --AND             NVL (hl.address2, 'xx') = NVL (p_address2, 'xx')
        AND ((hl.address2          =p_address2)
        OR (p_address2           IS NULL
        AND hl.address2           IS NULL))--  NVL(hl.address2,'xx') = NVL (:p_address2, 'xx')
        AND ((hl.address3          =p_address3)
        OR (p_address3           IS NULL
        AND hl.address3           IS NULL))--NVL(hl.address3,'xx') = NVL (:p_address3, 'xx')
        AND ((hl.address4          =p_address4)
        OR (p_address4           IS NULL
        AND hl.address4           IS NULL))--NVL (hl.address4, 'xx') = NVL (:p_address4, 'xx')
        AND ((hl.city              =p_city)
        OR (p_city               IS NULL
        AND hl.city               IS NULL))--NVL (hl.city, 'xx') = NVL (:p_city, 'xx')
        AND ((hl.country           =p_country)
        OR (p_country            IS NULL
        AND hl.country            IS NULL))--NVL(hl.country,'xx') = NVL(:p_country,'xx')
        AND ((hl.county            =p_county)
        OR (p_county             IS NULL
        AND hl.county             IS NULL))--NVL (hl.county, 'xx') = NVL (:p_county, 'xx')
        AND ((hl.state             =p_state)
        OR (p_state              IS NULL
        AND hl.state              IS NULL))--NVL (hl.state, 'xx') = NVL (:p_state, 'xx')
        AND ((hl.postal_code       =p_postal_code)
        OR (p_postal_code        IS NULL
        AND hl.postal_code        IS NULL))--NVL (hl.postal_code, 'xx') = NVL (:p_postal_code, 'xx')
        AND             hl.location_id = hps.location_id
        AND             hzas.party_site_id = hps.party_site_id
        AND             hzas.cust_acct_site_id = hzs.cust_acct_site_id
        AND             hzs.site_use_code = 'BILL_TO'
        AND             hza.cust_account_id = hzas.cust_account_id
        AND             hzas.org_id = ln_org_id
        AND             hzas.org_id = hzs.org_id
        AND             hzs.status = 'A'
        --AND             hzs.primary_flag = 'Y'
        AND             hp.status = 'A'
        AND             hza.party_id = hp.party_id
        AND             hza.account_number = lv_customer_acc;*/

     SELECT DISTINCT (hzs.site_use_id)
      INTO            p_bill_to_org_id
      FROM            apps.hz_cust_accounts hza,
                      apps.hz_cust_site_uses_all hzs,
                      apps.hz_cust_acct_sites_all hzas,
                      apps.hz_parties hp,
                      apps.hz_party_sites hps,
                      apps.hz_locations hl
      WHERE           hl.address1 = p_address1
          --AND            NVL(hl.address2,'xx') = NVL (p_address2, 'xx')
        AND ((UPPER(hl.address2 )         =UPPER(p_address2))
        OR (p_address2           IS NULL
        AND hl.address2           IS NULL))--  NVL(hl.address2,'xx') = NVL (:p_address2, 'xx')
        AND ((UPPER(hl.address3)          =UPPER(p_address3))
        OR (p_address3           IS NULL
        AND hl.address3           IS NULL))--NVL(hl.address3,'xx') = NVL (:p_address3, 'xx')
        AND ((UPPER(hl.address4)          =UPPER(p_address4))
        OR (p_address4           IS NULL
        AND hl.address4           IS NULL))--NVL (hl.address4, 'xx') = NVL (:p_address4, 'xx')
        AND ((UPPER(hl.city)              =UPPER(p_city))
        OR (p_city               IS NULL
        AND hl.city               IS NULL))--NVL (hl.city, 'xx') = NVL (:p_city, 'xx')
        AND ((UPPER(hl.country)           =UPPER(p_country))
        OR (p_country            IS NULL
        AND hl.country            IS NULL))--NVL(hl.country,'xx') = NVL(:p_country,'xx')
        /*AND ((UPPER(hl.state)             =UPPER(p_state))
        OR (p_state              IS NULL
        AND hl.state              IS NULL))--NVL (hl.state, 'xx') = NVL (:p_state, 'xx')*/
        AND ((UPPER(hl.postal_code)       =UPPER(p_postal_code))
        OR (p_postal_code        IS NULL
        AND hl.postal_code        IS NULL))--NVL (hl.postal_code, 'xx') = NVL (:p_postal_code, 'xx')
        AND hl.location_id         = hps.location_id
        AND hps.party_id           = hp.party_id
        AND hza.party_id           = hp.party_id
        AND hza.cust_account_id    = hzas.cust_account_id
        AND hzas.party_site_id     = hps.party_site_id
        AND hzas.cust_acct_site_id = hzs.cust_acct_site_id
        AND hzs.site_use_code      = 'BILL_TO'
        AND hzs.status             = 'A'
        AND hza.status             = 'A'
        AND hza.account_number = lv_customer_acc
        AND hzs.org_id = ln_org_id;   
      -- Changes end by Sankalpa on 30-Jun-2021 for BILL_TO site in Project Revival
   EXCEPTION
      WHEN OTHERS
      THEN
         BEGIN
            create_customer_site_use_code (p_customer_acc         => lv_customer_acc,
                                           p_address1             => p_address1,
                                           p_address2             => p_address2,
                                           p_address3             => p_address3,
                                           p_address4             => p_address4,
                                           p_city                 => p_city,
                                           p_country              => p_country,
                                           p_county               => p_county,
                                           p_state                => p_state,
                                           p_postal_code          => p_postal_code,
                                           p_site_use_code        => lv_site_use_code,
                                           p_site_use_id          => p_bill_to_org_id);

            IF (p_bill_to_org_id IS NULL)
            THEN
               --fnd_file.put_line (fnd_file.LOG,   'Error in creating BILL_TO site.' || SQLERRM);
               RAISE;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                  'Error in deriving customer BILL_TO.');
               p_bill_to_org_id := NULL;
               xx_comn_conv_debug_prc (p_i_level          => NULL,
                                       p_i_proc_name      => 'validate_customer_bill_to',
                                       p_i_phase          => 'Customer BILL-TO Validation',
                                       p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                       p_i_message        =>    'Fatal Error in validate_customer_bill_to.SQLCODE: '
                                                             || SQLCODE
                                                             || ' SQLERRM :'
                                                             || SUBSTR (SQLERRM, 1, 100));
         END;
   END validate_customer_bill_to;

/**********************************************
-- Procedure to validate customer SHIP_TO --
**********************************************/
   PROCEDURE validate_customer_ship_to (
      p_source                   IN       VARCHAR2,
      p_customer_number          IN       VARCHAR2,
      p_address1                 IN       VARCHAR2,
      p_address2                 IN       VARCHAR2,
      p_address3                 IN       VARCHAR2,
      p_address4                 IN       VARCHAR2,
      p_city                     IN       VARCHAR2,
      p_country                  IN       VARCHAR2,
      p_county                   IN       VARCHAR2,
      p_state                    IN       VARCHAR2,
      p_postal_code              IN       VARCHAR2,
      p_ship_to_org_id           OUT      NUMBER)
   AS      
      lv_site_use_code      VARCHAR2 (20) := 'SHIP_TO';
      lv_customer_acc       VARCHAR2 (200) := NULL;
      ln_org_id             NUMBER := NULL;   -- Added by Sankalpa on 30-Jun-2021 for Project Revival
   BEGIN
      IF (p_source = 'OSSA Visual ERP')
      THEN 
        BEGIN
           SELECT XX_COMN_CONV_UTIL_PKG.XX_COMN_CONV_CUST_NUM_FNC(p_i_legacy_cust_num => p_customer_number)
             INTO lv_customer_acc
             FROM DUAL;

        EXCEPTION
          WHEN OTHERS
          THEN           
             lv_customer_acc := 0;
        END; 
      ELSE
        lv_customer_acc := p_customer_number;
      END IF;  
      fnd_file.put_line (fnd_file.LOG, 'Customer account for ship_to validation - '||lv_customer_acc);
	  -- Changes start by Sankalpa on 30-Jun-2021 for SHIP_TO site in Project Revival 
      get_org_id (p_org_id     => ln_org_id );
	  
      -- Get site_use_id of customer using customer_ship_to
      /*SELECT DISTINCT (hzs.site_use_id)
      INTO            p_ship_to_org_id
      FROM            hz_cust_accounts hza,
                      hz_cust_site_uses_all hzs,
                      hz_cust_acct_sites_all hzas,
                      hz_parties hp,
                      hz_party_sites hps,
                      hz_locations hl
      WHERE           hl.address1 = p_address1
      --AND             NVL (hl.address2, 'xx') = NVL (p_address2, 'xx')
        AND ((hl.address2          =p_address2)
        OR (p_address2           IS NULL
        AND hl.address2           IS NULL))--  NVL(hl.address2,'xx') = NVL (:p_address2, 'xx')
        AND ((hl.address3          =p_address3)
        OR (p_address3           IS NULL
        AND hl.address3           IS NULL))--NVL(hl.address3,'xx') = NVL (:p_address3, 'xx')
        AND ((hl.address4          =p_address4)
        OR (p_address4           IS NULL
        AND hl.address4           IS NULL))--NVL (hl.address4, 'xx') = NVL (:p_address4, 'xx')
        AND ((hl.city              =p_city)
        OR (p_city               IS NULL
        AND hl.city               IS NULL))--NVL (hl.city, 'xx') = NVL (:p_city, 'xx')
        AND ((hl.country           =p_country)
        OR (p_country            IS NULL
        AND hl.country            IS NULL))--NVL(hl.country,'xx') = NVL(:p_country,'xx')
        AND ((hl.county            =p_county)
        OR (p_county             IS NULL
        AND hl.county             IS NULL))--NVL (hl.county, 'xx') = NVL (:p_county, 'xx')
        AND ((hl.state             =p_state)
        OR (p_state              IS NULL
        AND hl.state              IS NULL))--NVL (hl.state, 'xx') = NVL (:p_state, 'xx')
        AND ((hl.postal_code       =p_postal_code)
        OR (p_postal_code        IS NULL
        AND hl.postal_code        IS NULL))--NVL (hl.postal_code, 'xx') = NVL (:p_postal_code, 'xx')
        AND             hl.location_id = hps.location_id
        AND             hzas.party_site_id = hps.party_site_id
        AND             hzas.cust_acct_site_id = hzs.cust_acct_site_id
        AND             hzs.site_use_code = 'SHIP_TO'
        AND             hza.cust_account_id = hzas.cust_account_id
        AND             hzs.status = 'A'
        --AND             hzs.primary_flag = 'Y'
        AND             hp.status = 'A'
        AND             hza.party_id = hp.party_id
        AND             hza.account_number = lv_customer_acc;*/
      SELECT DISTINCT (hzs.site_use_id)
      INTO            p_ship_to_org_id
      FROM            apps.hz_cust_accounts hza,
                      apps.hz_cust_site_uses_all hzs,
                      apps.hz_cust_acct_sites_all hzas,
                      apps.hz_parties hp,
                      apps.hz_party_sites hps,
                      apps.hz_locations hl
      WHERE           hl.address1 = p_address1
          --AND            NVL(hl.address2,'xx') = NVL (p_address2, 'xx')
        AND ((UPPER(hl.address2 )         =UPPER(p_address2))
        OR (p_address2           IS NULL
        AND hl.address2           IS NULL))--  NVL(hl.address2,'xx') = NVL (:p_address2, 'xx')
        AND ((UPPER(hl.address3)          =UPPER(p_address3))
        OR (p_address3           IS NULL
        AND hl.address3           IS NULL))--NVL(hl.address3,'xx') = NVL (:p_address3, 'xx')
        AND ((UPPER(hl.address4)          =UPPER(p_address4))
        OR (p_address4           IS NULL
        AND hl.address4           IS NULL))--NVL (hl.address4, 'xx') = NVL (:p_address4, 'xx')
        AND ((UPPER(hl.city)              =UPPER(p_city))
        OR (p_city               IS NULL
        AND hl.city               IS NULL))--NVL (hl.city, 'xx') = NVL (:p_city, 'xx')
        AND ((UPPER(hl.country)           =UPPER(p_country))
        OR (p_country            IS NULL
        AND hl.country            IS NULL))--NVL(hl.country,'xx') = NVL(:p_country,'xx')
        /*AND ((UPPER(hl.state)             =UPPER(p_state))
        OR (p_state              IS NULL
        AND hl.state              IS NULL))--NVL (hl.state, 'xx') = NVL (:p_state, 'xx')*/
        AND ((UPPER(hl.postal_code)       =UPPER(p_postal_code))
        OR (p_postal_code        IS NULL
        AND hl.postal_code        IS NULL))--NVL (hl.postal_code, 'xx') = NVL (:p_postal_code, 'xx')
        AND hl.location_id         = hps.location_id
        AND hps.party_id           = hp.party_id
        AND hza.party_id           = hp.party_id
        AND hza.cust_account_id    = hzas.cust_account_id
        AND hzas.party_site_id     = hps.party_site_id
        AND hzas.cust_acct_site_id = hzs.cust_acct_site_id
        AND hzs.site_use_code      = 'SHIP_TO'
        AND hzs.status             = 'A'
        AND hza.status             = 'A'
        AND hza.account_number = lv_customer_acc
        AND hzs.org_id = ln_org_id;    
	-- Changes end by Sankalpa on 30-Jun-2021 for SHIP_TO site in Project Revival	
   EXCEPTION
      WHEN OTHERS
      THEN
         BEGIN
            create_customer_site_use_code (p_customer_acc         => lv_customer_acc,
                                           p_address1             => p_address1,
                                           p_address2             => p_address2,
                                           p_address3             => p_address3,
                                           p_address4             => p_address4,
                                           p_city                 => p_city,
                                           p_country              => p_country,
                                           p_county               => p_county,
                                           p_state                => p_state,
                                           p_postal_code          => p_postal_code,
                                           p_site_use_code        => lv_site_use_code,
                                           p_site_use_id          => p_ship_to_org_id);

            IF (p_ship_to_org_id IS NULL)
            THEN
               --fnd_file.put_line (fnd_file.LOG, 'Error in creating SHIP_TO site.' || SQLERRM);
               RAISE;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                  'Error in deriving customer SHIP_TO.');
               p_ship_to_org_id := NULL;
               xx_comn_conv_debug_prc (p_i_level          => NULL,
                                       p_i_proc_name      => 'validate_customer_ship_to',
                                       p_i_phase          => 'Customer SHIP-TO Validation',
                                       p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                       p_i_message        =>    'Fatal Error in validate_customer_ship_to.SQLCODE: '
                                                             || SQLCODE
                                                             || ' SQLERRM :'
                                                             || SUBSTR (SQLERRM, 1, 100));
         END;
   END validate_customer_ship_to;

/**********************************************
-- Function to validate UOM --
**********************************************/
   FUNCTION validate_uom (
      p_uom                      IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      -- Changes start by Sankalpa on 30-Jun-2021 for UoM validation in Project Revival
	  lv_uom_code   VARCHAR2(10) := NULL;
	  --ln_uom_cnt   NUMBER := 0;
   BEGIN
      
	  SELECT uom_code
      INTO   lv_uom_code
      FROM   mtl_units_of_measure
      WHERE  UPPER(uom_code) = UPPER(p_uom);

      /*IF (ln_uom_cnt > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;*/
      RETURN lv_uom_code ;
	-- Changes end by Sankalpa on 30-Jun-2021 for UoM validation in Project Revival  
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Fatal Error in validating UoM.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_uom',
                                 p_i_phase          => 'UoM Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_uom.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN NULL;
   END validate_uom;

/**********************************************
-- Function to validate currency --
**********************************************/
   FUNCTION validate_currency (
      p_currency                 IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_curr_cnt   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
      INTO   ln_curr_cnt
      FROM   fnd_currencies
      WHERE  currency_code = p_currency
      AND    enabled_flag = 'Y';

      IF (ln_curr_cnt > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal Error in validating currency.SQLCODE: ' || SQLCODE || ' SQLERRM :' || SQLERRM);
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_currency',
                                 p_i_phase          => 'Currency Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_currency.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN 'N';
   END validate_currency;

/**********************************************
-- Function to validate pricelist --
**********************************************/
   FUNCTION validate_pricelist (
      p_customer_acc          IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      lv_pricelist_name   VARCHAR2 (2000) := NULL;
   BEGIN
      SELECT DISTINCT qlh.NAME
      INTO            lv_pricelist_name
      FROM            qp_list_headers qlh,
                      hz_cust_acct_sites_all hcasa,
                      hz_cust_site_uses_all hcsua,
                      hz_cust_accounts hcaa,
                      hz_parties hp
      WHERE           hcaa.cust_account_id = hcasa.cust_account_id
      AND             hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND             hcsua.price_list_id = qlh.list_header_id
      AND             qlh.list_type_code = 'PRL'
      AND             qlh.active_flag = 'Y'
      AND             hcaa.status = 'A'
      AND             hcaa.account_number = p_customer_acc
      AND             SYSDATE BETWEEN NVL (qlh.start_date_active, SYSDATE) AND NVL (qlh.end_date_active, SYSDATE + 1);

      RETURN lv_pricelist_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal Error in validating pricelist.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_pricelist',
                                 p_i_phase          => 'Pricelist Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_pricelist.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN 'XX';
   END validate_pricelist;

/**********************************************
-- Function to validate payment terms --
**********************************************/
   FUNCTION validate_payment_terms (
      p_payment_terms            IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_payment_terms_cnt   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
      INTO   ln_payment_terms_cnt
      FROM   ra_terms
      WHERE  NAME = p_payment_terms
      AND    SYSDATE BETWEEN NVL (start_date_active, SYSDATE) AND NVL (end_date_active, SYSDATE + 1);

      IF (ln_payment_terms_cnt > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal Error in validating payment terms.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_payment_terms',
                                 p_i_phase          => 'Payment Terms Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_payment_terms.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN 'N';
   END validate_payment_terms;

/**********************************************
-- Function to validate inco terms --
**********************************************/
   FUNCTION validate_inco_terms (
      p_inco_terms               IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_inco_terms_cnt   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
      INTO   ln_inco_terms_cnt
      FROM   fnd_lookup_types flt,
             fnd_lookup_values flv
      WHERE  1 = 1
      AND    flt.lookup_type = 'FOB'
      AND    flt.application_id = 201   -- PO
      AND    flt.lookup_type = flv.lookup_type
      AND    flv.lookup_code = p_inco_terms
      AND    flv.enabled_flag = 'Y'
      AND    flv.LANGUAGE = 'US'
      AND    SYSDATE BETWEEN NVL (start_date_active, SYSDATE) AND NVL (end_date_active, SYSDATE + 1);

      IF (ln_inco_terms_cnt > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal Error in validating inco terms.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_inco_terms',
                                 p_i_phase          => 'Inco Terms Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_inco_terms.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN 'N';
   END validate_inco_terms;

   /**********************************************
   -- Function to validate frieght terms --
   **********************************************/
   -- Commented by Sankalpa on 30-Jun-2021 for Project Revival
   /*FUNCTION validate_freight_terms (
      p_early_shipments          IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_early_shipment_cnt   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
      INTO   ln_early_shipment_cnt
      FROM   fnd_lookup_types flt,
             fnd_lookup_values flv
      WHERE  1 = 1
      AND    flt.lookup_type = 'FREIGHT_TERMS'
      AND    flt.lookup_type = flv.lookup_type
      AND    flv.lookup_code = p_early_shipments
      AND    flv.enabled_flag = 'Y'
      AND    flv.LANGUAGE = 'US'
      AND    SYSDATE BETWEEN NVL (start_date_active, SYSDATE) AND NVL (end_date_active, SYSDATE + 1);

      IF (ln_early_shipment_cnt > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal Error in validating freight terms.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_freight_terms',
                                 p_i_phase          => 'Freight Terms Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_freight_terms.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN 'N';
   END validate_freight_terms;*/

/**********************************************
-- Function to validate shipping method --
**********************************************/
   FUNCTION validate_shipping_method (
      p_shipping_method          IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_ship_method_code   VARCHAR2 (100) := NULL;
   BEGIN
      SELECT flv.lookup_code
      INTO   ln_ship_method_code
      FROM   fnd_lookup_types flt,
             fnd_lookup_values flv
      WHERE  1 = 1
      AND    flt.lookup_type = 'SHIP_METHOD'
      AND    flt.lookup_type = flv.lookup_type
      AND    flv.meaning = p_shipping_method
      AND    flv.enabled_flag = 'Y'
      AND    flv.LANGUAGE = 'US'
      AND    SYSDATE BETWEEN NVL (start_date_active, SYSDATE) AND NVL (end_date_active, SYSDATE + 1);

      RETURN ln_ship_method_code;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Invalid shipping method.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_shipping_method',
                                 p_i_phase          => 'Shipping Method Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Invalid shipping method in validate_shipping_method.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN ln_ship_method_code;
   END validate_shipping_method;

/**********************************************
-- Function to validate ship from org --
**********************************************/
   FUNCTION validate_ship_from_org (
      p_ship_from                IN       VARCHAR2)
      RETURN VARCHAR2
   AS
      ln_ship_from   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
      INTO   ln_ship_from
      FROM   mtl_parameters
      WHERE  1 = 1
      AND    organization_code = p_ship_from;

      IF (ln_ship_from > 0)
      THEN
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal Error in validating ship from org.');
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_ship_from_org',
                                 p_i_phase          => 'SHIP_FROM_ORG Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_ship_from_org.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RETURN 'N';
   END validate_ship_from_org;

/**********************************************
-- Procedure to validate item --
**********************************************/
   PROCEDURE validate_item (
      p_item                     IN       VARCHAR2,
      p_ship_from_org            IN       VARCHAR2,
      --p_pricelist                IN       VARCHAR2,
      p_item_id                  OUT      NUMBER)
   AS
      ln_item_id   NUMBER := 0;
   BEGIN
      SELECT msi.inventory_item_id
      INTO   ln_item_id
      FROM   mtl_system_items_b msi,
             mtl_parameters mp
      WHERE  1 = 1
      AND    msi.organization_id = mp.organization_id
      AND    msi.segment1 = p_item
      AND    mp.organization_code = p_ship_from_org;

      P_ITEM_ID := LN_ITEM_ID;

   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Invalid item.');
         p_item_id := 0;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_item',
                                 p_i_phase          => 'Item Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Invalid item in validate_item.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 100));
   END validate_item;

   -- Added by Sankalpa on 30-Jun-2021 for item cross reference validation in Project Revival
   /**********************************************
	-- Procedure to validate item cross reference --
	**********************************************/
   FUNCTION validate_item_cross_reference (
      p_item_id                  IN       NUMBER)
   RETURN VARCHAR2   
   AS
      ln_cross_ref   NUMBER := 0;
   BEGIN
      SELECT count(*)
      INTO   ln_cross_ref
      FROM   mtl_cross_references 
      WHERE  1 = 1
      AND    cross_reference_type = 'OSSA SALES CODE'
      AND    inventory_item_id = p_item_id ;

      IF ln_cross_ref > 0
      THEN
        RETURN 'Y';
      ELSE  
        RETURN 'N';
      END IF;  
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Invalid item cross reference.');
         RETURN 'N';
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_item_cross_reference',
                                 p_i_phase          => 'Item Cross Reference Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Invalid item cross reference in validate_item_cross_reference.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 100));
   END validate_item_cross_reference;

   /**********************************************
    -- Procedure to validate SBC order header details --
    **********************************************/
   PROCEDURE validate_sbc_order_header (  
      p_source                   IN       VARCHAR2,
      p_org_name                 IN       VARCHAR2,      
      p_customer_acc			 IN		  VARCHAR2,
      p_customer_po_number       IN       VARCHAR2)
   IS
      /*****************************************************
      --Declaring Local Variables ----
      *****************************************************/

      lv_process_flag            VARCHAR2 (1);
      lv_error_message           VARCHAR2 (3000);
      ln_org_id                  NUMBER;
      lc_procedure      CONSTANT VARCHAR2 (2000) := 'validate_sbc_order_header';
      lc_order_source   CONSTANT VARCHAR2 (100)  := p_source; 
      lv_dup_order               VARCHAR2 (1);
      ln_order_source_id         NUMBER          := 0;
      ln_party_number            VARCHAR2(200)   := NULL;
      ln_customer_acc_id         NUMBER          := 0;
      ln_bill_to_org_id          NUMBER          := 0;
      ln_ship_to_org_id          NUMBER          := 0;    
      ln_hdr_trx_type_id         NUMBER;
      ln_line_trx_type_id        NUMBER;

      /*******************************************************************
      -- Cursor to fetch VISUAL sales order details which has not been validated
      ******************************************************************/
      CURSOR cur_order_list
      IS
         SELECT DISTINCT xx.customer_po_number,
                         xx.customer_name,                         
                         xx.customer_ship_to,
                         xx.ship_to_address1,
                         xx.ship_to_address2,
                         xx.ship_to_address3,
                         xx.ship_to_address4,
                         xx.ship_to_city,
                         xx.ship_to_country,
                         xx.ship_to_county,
                         xx.ship_to_state,
                         xx.ship_to_postal_code/*,                                                  
                         xx.header_status*/                                                  
         FROM            customusr.xx_om_so_hold_conv_stg_tbl xx
         WHERE           process_flag = 'N'
         AND             ORG_NAME = P_ORG_NAME
         --AND             customer_number = p_customer_acc
         AND             batch_id = gn_batch_id_num 
         AND             sold_to_id IS NULL
         AND             customer_po_number = p_customer_po_number;
   BEGIN
      FOR rec_order_list IN cur_order_list
      LOOP         
         --FND_FILE.PUT_LINE(FND_FILE.LOG,'Before starting header validation');
         LV_ERROR_MESSAGE := NULL;
         lv_process_flag := 'V';
         --lv_dup_order := NULL;
         ln_org_id := 0;
         ln_order_source_id := 0;
         ln_party_number := NULL;
         ln_customer_acc_id := 0;
         ln_bill_to_org_id := 0;
         ln_ship_to_org_id := 0;
         --lv_currency := NULL;
         --lv_ship_from_org := NULL;
         ln_hdr_trx_type_id := 0;
         ln_line_trx_type_id := 0;         

         /***************************************************
         -- Validate duplicate orders --
         *****************************************************/
         IF rec_order_list.customer_po_number IS NULL
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing SBC order number';
         ELSE
            lv_dup_order := validate_sbc_duplicate (p_customer_po_number => rec_order_list.customer_po_number, 
                                                    p_org_name => p_org_name);

            IF lv_dup_order = 'Y'
            THEN
               lv_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Duplicate SBC sales order exists';
            END IF;
         END IF;
         --fnd_file.put_line(fnd_file.log,'Before validating customer account');
         /***************************************************
         -- Validate operating units --
         ****************************************************/
            ln_org_id := validate_ou (p_operating_unit => p_org_name);

            IF ln_org_id = 0
            THEN
               lv_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid operating unit';
            END IF;

         /***************************************************
         -- Get order transaction type --
         ****************************************************/
         get_transaction_type (p_org_name             => p_org_name,
                               p_hdr_trx_type_id      => ln_hdr_trx_type_id,
                               p_ln_trx_type_id       => ln_line_trx_type_id);

         IF ln_hdr_trx_type_id = 0
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Invalid order transaction type';
         END IF;

         /***************************************************
         -- Validate order source --
         ****************************************************/
         validate_order_source (p_source => lc_order_source, p_source_id => ln_order_source_id);

         IF ln_order_source_id = 0
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Invalid order source';
         END IF;

         /***************************************************
         -- Validate customer account --
         ****************************************************/
         BEGIN
           SELECT cust_account_id
             INTO ln_customer_acc_id
            FROM  hz_cust_accounts
          WHERE account_number = p_customer_acc 
            AND status = 'A';

         EXCEPTION
           WHEN OTHERS THEN
             ln_customer_acc_id := NULL;
             lv_process_flag := fnd_api.g_ret_sts_error;
                 lv_error_message := lv_error_message || '|' || 'Invalid customer account';
         END;
         /***************************************************
         -- Validate customer details --
         ***************************************************/
         IF p_customer_acc IS NULL
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing customer details';
         ELSE
            SELECT hp.party_number
              INTO ln_party_number
              FROM hz_cust_accounts hca
                    ,hz_parties hp
              WHERE 1=1
              AND hp.party_id = hca.party_id
              AND hca.account_number = p_customer_acc ;

            IF ln_party_number IS NULL
            THEN
               lv_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid customer details';
            END IF;
         END IF;
         /***************************************************
         -- Validate customer BILL_TO --
         *****************************************************/         

          IF p_customer_acc IS NULL
          THEN
             lv_process_flag := fnd_api.g_ret_sts_error;
             lv_error_message := lv_error_message || '|' || 'Missing customer BILL_TO details';
          ELSE
             BEGIN
               SELECT hcsu.site_use_id
                INTO ln_bill_to_org_id
                FROM hz_parties hp
                  , hz_party_sites hps
                  , hz_locations hl
                  , hz_cust_accounts_all hca
                  , hz_cust_acct_sites_all hcsa
                  , hz_cust_site_uses_all hcsu
                WHERE hp.party_id = hps.party_id
                AND hps.location_id = hl.location_id
                AND hp.party_id = hca.party_id
                AND hcsa.party_site_id = hps.party_site_id
                AND hcsu.cust_acct_site_id = hcsa.cust_acct_site_id
                AND hca.cust_account_id = hcsa.cust_account_id
                AND hcsu.site_use_code = 'BILL_TO'
                AND NVL(hcsu.primary_flag,'N') = 'Y'
                and hca.account_number = p_customer_acc
                AND ROWNUM = 1;
            EXCEPTION
              WHEN OTHERS THEN
                ln_bill_to_org_id := NULL;
            END;  

            IF ln_bill_to_org_id IS NULL
            THEN
              lv_process_flag := fnd_api.g_ret_sts_error;
              lv_error_message := lv_error_message || '|' || 'Invalid customer BILL_TO details';
            END IF;
          END IF;            

         /***************************************************
         -- Validate customer SHIP_TO --
         *****************************************************/

          --IF rec_order_list.customer_ship_to IS NULL
          IF p_customer_acc IS NULL
          THEN
             lv_process_flag := fnd_api.g_ret_sts_error;
             lv_error_message := lv_error_message || '|' || 'Missing customer SHIP_TO details';
          ELSE
              IF (REC_ORDER_LIST.SHIP_TO_ADDRESS1) IS NOT NULL
              THEN
                fnd_file.put_line (fnd_file.LOG,'postal code for SHIP TO : ' ||rec_order_list.ship_to_postal_code); 
                validate_customer_ship_to (p_source               => p_source,
                                          p_customer_number      => p_customer_acc,
                                          p_address1             => rec_order_list.ship_to_address1,
                                          p_address2             => rec_order_list.ship_to_address2,
                                          p_address3             => rec_order_list.ship_to_address3,
                                          p_address4             => rec_order_list.ship_to_address4,
                                          p_city                 => rec_order_list.ship_to_city,
                                          p_country              => rec_order_list.ship_to_country,
                                          p_county               => rec_order_list.ship_to_county,
                                          p_state                => rec_order_list.ship_to_state,
                                          p_postal_code          => rec_order_list.ship_to_postal_code,
                                          P_SHIP_TO_ORG_ID       => LN_SHIP_TO_ORG_ID);

               ELSE 

                SELECT hcsu.site_use_id
                  INTO ln_ship_to_org_id
                  FROM hz_parties hp
                    , hz_party_sites hps
                    , hz_locations hl
                    , hz_cust_accounts_all hca
                    , hz_cust_acct_sites_all hcsa
                    , hz_cust_site_uses_all hcsu
                  WHERE hp.party_id = hps.party_id
                  AND hps.location_id = hl.location_id
                  AND hp.party_id = hca.party_id
                  AND hcsa.party_site_id = hps.party_site_id
                  AND hcsu.cust_acct_site_id = hcsa.cust_acct_site_id
                  AND hca.cust_account_id = hcsa.cust_account_id
                  AND hcsu.site_use_code = 'SHIP_TO'
                  AND NVL(hcsu.primary_flag,'N') = 'Y'
                  and hca.account_number = p_customer_acc
                  AND ROWNUM = 1;                        
               END IF;

             IF ln_ship_to_org_id IS NULL
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Invalid customer SHIP_TO details';
             END IF;  
           END IF; 

         /*****************************************************************
         -- Update header staging table flag as V or E.
         -- If Error, then update error message --
         *****************************************************************/
         --fnd_file.put_line (fnd_file.log, 'before updating header details for PO number - '||rec_order_list.customer_po_number);
         BEGIN
            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET org_id = ln_org_id,
                   org_name = p_org_name,
                   hdr_trx_type_id = ln_hdr_trx_type_id,                   
                   order_source_id = ln_order_source_id,
                   hdr_sold_to_org_id = ln_customer_acc_id,
                   ship_to_org_id = ln_ship_to_org_id,
                   bill_to_org_id = ln_bill_to_org_id,
                   process_flag = lv_process_flag,
                   header_val_flag = lv_process_flag,
                   header_error_message = lv_error_message,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID'),
                   request_id = fnd_global.conc_request_id
             WHERE 1=1  
            AND    process_flag = 'N'
            AND    ORG_NAME = P_ORG_NAME
            --AND    customer_number = p_customer_acc
            and    sold_to_id is null
            AND    batch_id = gn_batch_id_num
            AND    customer_po_number = rec_order_list.customer_po_number;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Validation Update error in Staging for headers:'
                                  || lc_procedure
                                  || ' SQLCODE: '
                                  || SQLCODE
                                  || ' SQLERRM: '
                                  || SQLERRM);
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_sbc_order_header',
                                 p_i_phase          => 'SBC Sale Order Header Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_sbc_order_header.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RAISE;
   END validate_sbc_order_header;

    /**********************************************
    -- Procedure to validate order header details --
    **********************************************/
   PROCEDURE validate_order_header (
      p_order_number             IN       VARCHAR2,
      p_org_name                 IN       VARCHAR2,
      p_order_source             IN       VARCHAR2)
   IS
      /*****************************************************
      --Declaring Local Variables ----
      *****************************************************/
      lv_customer_acc            VARCHAR2 (200);
      lv_process_flag            VARCHAR2 (1);
      lv_error_message           VARCHAR2 (3000);
      lv_org_id                  NUMBER;
      lc_procedure      CONSTANT VARCHAR2 (2000) := 'validate_order_header';
      lc_order_source   CONSTANT VARCHAR2 (100)  := p_order_source;  --'OSSA Visual ERP';
      lv_dup_order               VARCHAR2 (1);
      ln_order_source_id         NUMBER          := 0;
      ln_party_number            VARCHAR2(200)   := NULL;
      ln_customer_acc_id         NUMBER          := 0;
      ln_bill_to_org_id          NUMBER          := 0;
      ln_ship_to_org_id          NUMBER          := 0;
      lv_currency                VARCHAR2 (1);
      lv_pricelist               VARCHAR2 (1);
      lv_payment_terms           VARCHAR2 (1);
      lv_inco_terms              VARCHAR2 (1);
      lv_shipping_method         VARCHAR2 (100);
      lv_ship_from_org           VARCHAR2 (1);
      ln_org_id                  NUMBER;
      ln_hdr_trx_type_id         NUMBER;
      ln_line_trx_type_id        NUMBER;
      lv_ship_set                VARCHAR2 (10)   := NULL;
      lv_shipments               VARCHAR2 (2)    := NULL;

      /*******************************************************************
      -- Cursor to fetch VISUAL sales order details which has not been validated
      ******************************************************************/
      CURSOR cur_order_list
      IS
         SELECT DISTINCT xx.org_name,
                         xx.order_number,
                         xx.ordered_date,
                         --xx.order_type,
                         xx.price_list,
                         xx.payment_term,
                         xx.shipping_method,
                         xx.customer_po_number,
                         xx.customer_po_received_date,
                         --xx.customer_number,
                         xx.customer_name,
                         xx.customer_bill_to,
                         xx.bill_to_address1,
                         xx.bill_to_address2,
                         xx.bill_to_address3,
                         xx.bill_to_address4,
                         xx.bill_to_city,
                         xx.bill_to_country,
                         xx.bill_to_county,
                         xx.bill_to_state,
                         xx.bill_to_postal_code,
                         xx.customer_ship_to,
                         xx.ship_to_address1,
                         xx.ship_to_address2,
                         xx.ship_to_address3,
                         xx.ship_to_address4,
                         xx.ship_to_city,
                         xx.ship_to_country,
                         xx.ship_to_county,
                         xx.ship_to_state,
                         xx.ship_to_postal_code,
                         xx.ship_to_contact,
                         xx.currency,
                         xx.header_status,
                         xx.header_ship_from_org,
                         xx.hold_status,
                         xx.hdr_shipping_instructions,
                         xx.ship_set,
                         --xx.order_source_reference,
                         --xx.collect_accounts,
                         xx.inco_terms,
                         xx.accept_early_shipments,
                         xx.shipping_terms,
                         sold_to_id
         FROM            customusr.xx_om_so_hold_conv_stg_tbl xx
         WHERE           process_flag = 'N'
         AND             org_name = p_org_name
         AND             order_source = p_order_source
         AND             order_number = p_order_number;
   BEGIN
      FOR rec_order_list IN cur_order_list
      LOOP
         lv_customer_acc  := NULL;
         lv_error_message := NULL;
         lv_process_flag := 'V';
         lv_dup_order := NULL;
         ln_org_id := 0;
         ln_order_source_id := 0;
         ln_party_number := NULL;
         ln_customer_acc_id := 0;
         ln_bill_to_org_id := 0;
         ln_ship_to_org_id := 0;
         lv_currency := NULL;
         lv_pricelist := NULL;
         lv_payment_terms := NULL;
         lv_inco_terms := NULL;
         lv_shipping_method := NULL;
         lv_ship_from_org := NULL;
         ln_hdr_trx_type_id := 0;
         ln_line_trx_type_id := 0;
         lv_ship_set := NULL;

         /***************************************************
         -- Validate duplicate orders --
         *****************************************************/
         IF rec_order_list.order_number IS NULL
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing VISUAL order number';
         ELSE
            lv_dup_order := validate_duplicate (p_order_number => rec_order_list.order_number, p_org_name => rec_order_list.org_name);

            IF lv_dup_order = 'Y'
            THEN
               lv_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Duplicate sales order exists';
            END IF;
         END IF;

         /***************************************************
         -- Validate operating units --
         ****************************************************/
         IF rec_order_list.org_name IS NULL
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing operating unit';
         ELSE
            ln_org_id := validate_ou (p_operating_unit => rec_order_list.org_name);

            IF ln_org_id = 0
            THEN
               lv_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid operating unit';
            END IF;
         END IF;

         /***************************************************
         -- Get order transaction type --
         ****************************************************/
         get_transaction_type (p_org_name             => rec_order_list.org_name,
                               p_hdr_trx_type_id      => ln_hdr_trx_type_id,
                               p_ln_trx_type_id       => ln_line_trx_type_id);

         IF ln_hdr_trx_type_id = 0
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Invalid order transaction type';
         END IF;

         /***************************************************
         -- Validate order source --
         ****************************************************/
         validate_order_source (p_source => lc_order_source, p_source_id => ln_order_source_id);

         IF ln_order_source_id = 0
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Invalid order source';
         END IF;

         /***************************************************
         -- Validate customer account --
         ****************************************************/
         validate_customer_account (p_customer_number      => rec_order_list.sold_to_id,
                                    p_customer_acc         => ln_customer_acc_id);

         IF ln_customer_acc_id = 0
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Invalid/ Inactive customer account';
         END IF;

         /***************************************************
         -- Validate customer details --
         ***************************************************/
         -- Commented by Sankalpa on 30-Jun-2021 for Project Revival
		 /*IF lc_order_source = 'OSSA Visual ERP'
         THEN*/
             /*IF rec_order_list.customer_name IS NULL
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing customer details';
             ELSE
                validate_customer (p_customer_acc => rec_order_list.sold_to_id, p_customer_number => ln_party_number);

                IF ln_party_number IS NULL
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid customer details';
                END IF;
             END IF;*/
          --END IF;
         /***************************************************
         -- Validate customer BILL_TO --
         *****************************************************/         
         -- Commented by Sankalpa on 30-Jun-2021 for BILL_TO validation for Project Revival
		 --IF rec_order_list.customer_bill_to IS NULL
         /*IF lc_order_source = 'OSSA Visual ERP'
         THEN*/
             --IF rec_order_list.customer_name IS NULL
             IF ln_customer_acc_id = 0
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing customer BILL_TO details';
             ELSE
                validate_customer_bill_to (p_customer_number      => rec_order_list.sold_to_id,
                                           p_address1             => rec_order_list.bill_to_address1,
                                           p_address2             => rec_order_list.bill_to_address2,
                                           p_address3             => rec_order_list.bill_to_address3,
                                           p_address4             => rec_order_list.bill_to_address4,
                                           p_city                 => rec_order_list.bill_to_city,
                                           p_country              => rec_order_list.bill_to_country,
                                           p_county               => rec_order_list.bill_to_county,
                                           p_state                => rec_order_list.bill_to_state,
                                           p_postal_code          => rec_order_list.bill_to_postal_code,
                                           p_bill_to_org_id       => ln_bill_to_org_id);

                IF ln_bill_to_org_id IS NULL
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid customer BILL_TO details';
                END IF;
             END IF;
        -- END IF;    

         /***************************************************
         -- Validate customer SHIP_TO --
         *****************************************************/
         -- Commented by Sankalpa on 30-Jun-2021 for SHIP_TO validation for Project Revival
		 /*IF lc_order_source = 'OSSA Visual ERP'
         THEN*/
             --IF rec_order_list.customer_name IS NULL
             IF ln_customer_acc_id = 0
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing customer SHIP_TO details';
             ELSE
                validate_customer_ship_to (p_source               => lc_order_source,
                                           p_customer_number      => rec_order_list.sold_to_id,
                                           p_address1             => rec_order_list.ship_to_address1,
                                           p_address2             => rec_order_list.ship_to_address2,
                                           p_address3             => rec_order_list.ship_to_address3,
                                           p_address4             => rec_order_list.ship_to_address4,
                                           p_city                 => rec_order_list.ship_to_city,
                                           p_country              => rec_order_list.ship_to_country,
                                           p_county               => rec_order_list.ship_to_county,
                                           p_state                => rec_order_list.ship_to_state,
                                           p_postal_code          => rec_order_list.ship_to_postal_code,
                                           p_ship_to_org_id       => ln_ship_to_org_id);

                IF ln_ship_to_org_id IS NULL
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid customer SHIP_TO details';
                END IF;
             END IF;
          --END IF;                   
              /***************************************************
              -- Validate currency --
              *****************************************************/
             IF rec_order_list.currency IS NULL
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing currency details';
             ELSE
                lv_currency := validate_currency (p_currency => rec_order_list.currency);

                IF lv_currency = 'N'
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid currency';
                END IF;
             END IF;
         -- END IF;   

        /***************************************************
        -- Validate pricelist --
        ****************************************************/
         /*IF rec_order_list.price_list IS NULL
         THEN
            lv_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing pricelist details';
         ELSE
            BEGIN
             SELECT XX_COMN_CONV_UTIL_PKG.XX_COMN_CONV_CUST_NUM_FNC(p_i_legacy_cust_num => rec_order_list.sold_to_id)
               INTO lv_customer_acc
               FROM DUAL;

            EXCEPTION
              WHEN OTHERS
              THEN           
                 lv_customer_acc := 0;
            END;                       
            lv_pricelist := validate_pricelist (p_customer_acc => lv_customer_acc);

            IF lv_pricelist = 'XX'
            THEN
               lv_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid pricelist';
            END IF;
         END IF;*/        
         /***************************************************
         -- Validate payment terms --
         *****************************************************/
         /*IF lc_order_source = 'OSSA Visual ERP'
         THEN*/
             IF rec_order_list.payment_term IS NULL
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing payment terms details';
             ELSE
                lv_payment_terms := validate_payment_terms (p_payment_terms => rec_order_list.payment_term);

                IF lv_payment_terms = 'N'
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid payment terms';
                END IF;
             END IF;

             /***************************************************
             -- Validate inco terms --
             *****************************************************/
             -- Commented by Sankalpa on 30-Jun-2021 for inco terms validation for Project Revival
			 /*IF rec_order_list.inco_terms IS NULL
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing inco terms details';
             ELSE*/
             IF rec_order_list.inco_terms IS NOT NULL
             THEN
                lv_inco_terms := validate_inco_terms (p_inco_terms => rec_order_list.inco_terms);

                IF lv_inco_terms = 'N'
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid inco terms';
                END IF;
             END IF;

             /***************************************************
             -- Validate freight terms --
             *****************************************************/
             /*IF rec_order_list.accept_early_shipments IS NOT NULL
             THEN
                lv_shipments := validate_freight_terms (p_early_shipments => rec_order_list.accept_early_shipments);

                IF lv_shipments = 'N'
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid freight terms value';
                END IF;
             END IF;*/

             /***************************************************
             -- Validate shipping method --
             **************************************************************/
             IF rec_order_list.shipping_method IS NOT NULL
             THEN
                lv_shipping_method := validate_shipping_method (p_shipping_method => rec_order_list.shipping_method);

                IF lv_shipping_method IS NULL
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid shipping method';
                END IF;
             END IF;

             /***************************************************
             -- Validate ship from org --
             **************************************************************/
             IF rec_order_list.header_ship_from_org IS NULL
             THEN
                lv_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing shipping org details';
             ELSE
                lv_ship_from_org := validate_ship_from_org (p_ship_from => rec_order_list.header_ship_from_org);

                IF lv_ship_from_org = 'N'
                THEN
                   lv_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid shipping org';
                END IF;
             END IF;

             -- Ship Set Validation
             IF (rec_order_list.ship_set = 'Y')
             THEN
                lv_ship_set := 'Ship';
             ELSE
                lv_ship_set := NULL;
             END IF;
         --END IF;             
         /*****************************************************************
         -- Update header staging table flag as V or E.
         -- If Error, then update error message --
         *****************************************************************/
         BEGIN
            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET org_id = ln_org_id,
                   hdr_trx_type_id = ln_hdr_trx_type_id,
                   --price_list = lv_pricelist,
                   order_source_id = ln_order_source_id,
                   hdr_sold_to_org_id = ln_customer_acc_id,
                   ship_to_org_id = ln_ship_to_org_id,
                   bill_to_org_id = ln_bill_to_org_id,
                   shipping_method_code = lv_shipping_method,
                   ship_set = lv_ship_set,
                   process_flag = lv_process_flag,
                   header_val_flag = lv_process_flag,
                   header_error_message = lv_error_message,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')--,
				   --request_id = fnd_global.conc_request_id			-- Commented by Sankalpa on 30-Jun-2021 for Project Revival
             WHERE order_number = rec_order_list.order_number
            AND    process_flag = 'N'
            AND    batch_id = gn_batch_id_num;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Validation Update error in Staging for headers:'
                                  || lc_procedure
                                  || ' SQLCODE: '
                                  || SQLCODE
                                  || ' SQLERRM: '
                                  || SQLERRM);
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_order_header',
                                 p_i_phase          => 'Sale Order Header Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_order_header.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RAISE;
   END validate_order_header;

   /**********************************************
   -- Procedure to validate sbc order line details --
   **********************************************/
   PROCEDURE validate_sbc_order_line (
      p_org_name                 IN       VARCHAR2,
	    p_customer_acc			       IN		    VARCHAR2,
      p_order_source             IN       VARCHAR2,
      p_customer_po_number       IN       VARCHAR2)
   IS
      /**************h***************************************
      --Declaring Local Variables ----
      *****************************************************/
      lv_line_process_flag    VARCHAR2 (1);
      lv_error_message        VARCHAR2 (3000);
      ln_item_id              NUMBER;
      lc_procedure   CONSTANT VARCHAR2 (2000) := 'validate_sbc_order_line';
      lv_cust_item_name       VARCHAR2 (1000);
      lv_line_status          VARCHAR2 (10);
      ln_line_trx_type_id     NUMBER          := 0;
      ln_hdr_trx_type_id      NUMBER          := 0;
      ln_cust_account_id	    NUMBER		  := 0;
      LV_UOM_CODE			        VARCHAR2(10);
      LV_UOM                  VARCHAR2 (10);
      ln_ship_from_org        NUMBER;

      /*******************************************************************
      -- Cursor to fetch SBC sales order line details which has not been validated
      ******************************************************************/
      CURSOR cur_order_line
      IS
         SELECT *  
         FROM   customusr.xx_om_so_hold_conv_stg_tbl xx
         where  xx.line_val_flag = 'N'
         AND    ORG_NAME = P_ORG_NAME
         --AND    customer_number = p_customer_acc
         and    xx.batch_id = gn_batch_id_num         
         AND    xx.sold_to_id IS NULL
         AND    xx.customer_po_number = p_customer_po_number ;

   BEGIN
      FOR rec_order_line IN cur_order_line
      LOOP
         lv_error_message := NULL;
         lv_line_process_flag := 'V';
         lv_uom_code 		:= NULL;
         lv_cust_item_name := NULL;
         ln_cust_account_id	:= NULL;
         lv_line_status := NULL;
         ln_line_trx_type_id := 0;
         ln_item_id := 0;
         LV_UOM := NULL;
         ln_ship_from_org := NULL;

         /***************************************************
         -- Validate line transaction types --
         *****************************************************/
         get_transaction_type (p_org_name             => rec_order_line.org_name,
                               p_hdr_trx_type_id      => ln_hdr_trx_type_id,
                               p_ln_trx_type_id       => ln_line_trx_type_id);

         if LN_LINE_TRX_TYPE_ID = 0
         THEN
            LV_LINE_PROCESS_FLAG := FND_API.G_RET_STS_ERROR;
            lv_error_message := lv_error_message || '|' || 'Invalid line transaction type';
         end if;

         /***************************************************
         -- Validate line items --
         ****************************************************/
            BEGIN
              SELECT cust_account_id
                INTO ln_cust_account_id
                FROM hz_cust_accounts hca
               WHERE account_number = p_customer_acc ;	
            EXCEPTION 
              WHEN OTHERS THEN  
                ln_cust_account_id := NULL;
            END;

            begin
              select msi.inventory_item_id,
                     msi.primary_uom_code,
                     MSI.DEFAULT_SHIPPING_ORG
                into ln_item_id,
                     LV_UOM_CODE,
                     ln_ship_from_org
                FROM MTL_CROSS_REFERENCES MCR
                    ,mtl_system_items_b msi
                    ,mtl_parameters mp
               WHERE 1=1
                 AND MCR.CROSS_REFERENCE_TYPE  = 'OSSA SALES CODE'
                 and mcr.inventory_item_id     = msi.inventory_item_id
                 AND msi.organization_id = mp.organization_id
                 AND mp.organization_code = 'MAS'
                 and msi.enabled_flag = 'Y'
                 AND MSI.INVENTORY_ITEM_FLAG = 'Y'
                 and mcr.org_independent_flag = 'Y'
                 AND MCR.CROSS_REFERENCE = rec_order_line.customer_item_name;

            EXCEPTION
              WHEN OTHERS THEN
                ln_item_id := NULL;
                LV_UOM_CODE := NULL;
                ln_ship_from_org := NULL;
            END;

            IF ln_item_id = 0
            THEN
               lv_line_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid line item';
            end if;

          /***************************************************
          -- Validate ordered qty
          *****************************************************/
         IF rec_order_line.ordered_quantity IS NULL
         THEN
            lv_line_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing ordered quantity';
         ELSE
            IF rec_order_line.ordered_quantity < 0
            THEN
               lv_line_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid ordered quantity';
            END IF;
         END IF;

        /***************************************************
        -- Validate unit price
        *****************************************************/
         IF rec_order_line.unit_price < 0
         THEN
            LV_LINE_PROCESS_FLAG := FND_API.G_RET_STS_ERROR;
            lv_error_message := lv_error_message || '|' || 'Invalid unit price';
         END IF;      

         /*****************************************************************
         -- Update staging table flag as V or E.
         -- If Error, then update line error message --
         *****************************************************************/
         BEGIN
            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET inventory_item_id = ln_item_id,
                   org_name = p_org_name,
                   line_ship_from_org = ln_ship_from_org,
                   line_trx_type_id = ln_line_trx_type_id,
                   process_flag = lv_line_process_flag,
                   line_val_flag = lv_line_process_flag,
                   line_error_message = lv_error_message,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
             WHERE 1= 1  --order_number = rec_order_line.order_number
            AND    line_val_flag = 'N'
            AND    batch_id = gn_batch_id_num
            AND    customer_item_name = rec_order_line.customer_item_name
            AND    customer_po_number = rec_order_line.customer_po_number;

            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET process_flag = lv_line_process_flag
             WHERE 1=1  
            AND    customer_po_number = rec_order_line.customer_po_number
            AND    customer_item_name = rec_order_line.customer_item_name
            AND    batch_id = gn_batch_id_num
            AND    NOT EXISTS (SELECT '1'
                               FROM   CUSTOMUSR.XX_OM_SO_HOLD_CONV_STG_TBL X2
                               WHERE  1=1  --order_number = x2.order_number
                               AND    HEADER_VAL_FLAG = 'E'
                               AND    customer_po_number = rec_order_line.customer_po_number
                               AND    batch_id = gn_batch_id_num);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Validation Update error in Staging for lines:'
                                  || lc_procedure
                                  || ' SQLCODE: '
                                  || SQLCODE
                                  || ' SQLERRM: '
                                  || SQLERRM);
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'validate_sbc_order_line',
                                 p_i_phase          => 'SBC Sales Order Line Validation',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_sbc_order_line.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RAISE;
   END validate_sbc_order_line;


   /**********************************************
   -- Procedure to validate order line details --
   **********************************************/
   PROCEDURE validate_order_line (
      p_order_number             IN       VARCHAR2,
      p_org_name                 IN       VARCHAR2,
      p_order_source             IN       VARCHAR2)
   IS
      /*****************************************************
      --Declaring Local Variables ----
      *****************************************************/
      lv_line_process_flag    VARCHAR2 (1);
      lv_error_message        VARCHAR2 (3000);
      ln_item_id              NUMBER;
      lc_procedure   CONSTANT VARCHAR2 (2000) := 'validate_order_line';
      lv_cust_item_name       VARCHAR2 (1000);
      lv_line_status          VARCHAR2 (10);
      ln_line_trx_type_id     NUMBER          := 0;
      ln_hdr_trx_type_id      NUMBER          := 0;
      lv_uom                  VARCHAR2 (10);
      lv_ship_from_org        VARCHAR2 (1);
      lv_cross_ref            VARCHAR2(5);

      /*******************************************************************
      -- Cursor to fetch VISUAL sales order line details which has not been validated
      ******************************************************************/
      CURSOR cur_order_line
      IS
         SELECT *  
         FROM   customusr.xx_om_so_hold_conv_stg_tbl xx
         WHERE  xx.line_val_flag = 'N'
         AND    org_name = p_org_name
         AND    xx.batch_id IS NOT NULL
         AND    order_source = p_order_source
         AND    xx.order_number = p_order_number;

   BEGIN
      FOR rec_order_line IN cur_order_line
      LOOP
         lv_error_message := NULL;
         lv_line_process_flag := 'V';
         lv_cust_item_name := NULL;
         lv_line_status := NULL;
         ln_line_trx_type_id := 0;
         ln_item_id := 0;
         lv_uom := NULL;
         lv_ship_from_org := NULL;
         /***************************************************
         -- Validate line transaction types --
         *****************************************************/
         get_transaction_type (p_org_name             => rec_order_line.org_name,
                               p_hdr_trx_type_id      => ln_hdr_trx_type_id,
                               p_ln_trx_type_id       => ln_line_trx_type_id);

         IF ln_line_trx_type_id = 0
         THEN
            lv_line_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Invalid line transaction type';
         END IF;

         /***************************************************
         -- Validate line items --
         ****************************************************/
         IF rec_order_line.inventory_item IS NULL
         THEN
            lv_line_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing line items';
         ELSE
            validate_item (p_item               => rec_order_line.inventory_item,
                           p_ship_from_org      => rec_order_line.line_ship_from_org,
                           --p_pricelist          => rec_order_line.price_list,
                           p_item_id            => ln_item_id);

            IF ln_item_id = 0
            THEN
               lv_line_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid line item';
            END IF;
         END IF;

         /***************************************************
         -- Validate line item cross reference --
         ****************************************************/
         IF rec_order_line.customer_item_name IS NULL
         THEN
            lv_line_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing U8 item reference';
         ELSE
            lv_cross_ref := validate_item_cross_reference (p_item_id  => ln_item_id);

            IF lv_cross_ref = 'N'
            THEN
               lv_line_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Mismtach between item and cross reference';
            END IF;
         END IF;

        /***************************************************
        -- Validate UoM --
        ***************************************************/
         IF p_order_source = 'OSSA Visual ERP'
         THEN
             IF rec_order_line.order_quantity_uom IS NULL
             THEN
                lv_line_process_flag := fnd_api.g_ret_sts_error;
                lv_error_message := lv_error_message || '|' || 'Missing UoM';
             ELSE
                lv_uom := validate_uom (p_uom => rec_order_line.order_quantity_uom);

                IF lv_uom IS NULL  --= 'N'
                THEN
                   lv_line_process_flag := fnd_api.g_ret_sts_error;
                   lv_error_message := lv_error_message || '|' || 'Invalid UoM';
                END IF;
             END IF;
          END IF;   

         /***************************************************
         -- Validate ship from org --
         ****************************************************/
         IF rec_order_line.line_ship_from_org IS NULL
         THEN
            lv_line_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing line shipping org details';
         ELSE
            lv_ship_from_org := validate_ship_from_org (p_ship_from => rec_order_line.line_ship_from_org);

            IF lv_ship_from_org = 'N'
            THEN
               lv_line_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid shipping org';
            END IF;
         END IF;

          /***************************************************
          -- Validate ordered qty
          *****************************************************/
         IF rec_order_line.ordered_quantity IS NULL
         THEN
            lv_line_process_flag := fnd_api.g_ret_sts_error;
            lv_error_message := lv_error_message || '|' || 'Missing ordered quantity';
         ELSE
            IF rec_order_line.ordered_quantity < 0
            THEN
               lv_line_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid ordered quantity';
            END IF;
         END IF;

        /***************************************************
        -- Validate unit price
        *****************************************************/
         IF rec_order_line.unit_price IS NULL
         THEN
            LV_LINE_PROCESS_FLAG := FND_API.G_RET_STS_ERROR;
            lv_error_message := lv_error_message || '|' || 'Missing unit price';
         ELSE
            IF rec_order_line.unit_price < 0
            THEN
               lv_line_process_flag := fnd_api.g_ret_sts_error;
               lv_error_message := lv_error_message || '|' || 'Invalid unit price';
            END IF;
         END IF;

         /*****************************************************************
         -- Update staging table flag as V or E.
         -- If Error, then update line error message --
         *****************************************************************/
         BEGIN
            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET inventory_item_id = ln_item_id,
                   line_ship_from_org = lv_ship_from_org,
                   line_trx_type_id = ln_line_trx_type_id,
                   order_quantity_uom = lv_uom,
                   process_flag = lv_line_process_flag,
                   line_val_flag = lv_line_process_flag,
                   line_error_message = lv_error_message,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
             WHERE order_number = rec_order_line.order_number
            AND    line_val_flag = 'N'
            AND    batch_id = gn_batch_id_num
            AND    NVL(inventory_item,'XX') = NVL(rec_order_line.inventory_item,'XX');

            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET process_flag = 'E'
             WHERE order_number = rec_order_line.order_number
            --AND    inventory_item = rec_order_line.inventory_item
            AND    batch_id = gn_batch_id_num
            --AND    NOT EXISTS (SELECT '1'
            AND    EXISTS (SELECT '1'
                               FROM   customusr.xx_om_so_hold_conv_stg_tbl x2
                               WHERE  ORDER_NUMBER = X2.ORDER_NUMBER
                               --AND    inventory_item = x2.inventory_item
                               AND    header_val_flag = 'E'
                               AND    batch_id = gn_batch_id_num);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Validation Update error in Staging for lines:'
                                  || lc_procedure
                                  || ' SQLCODE: '
                                  || SQLCODE
                                  || ' SQLERRM: '
                                  || SQLERRM);
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 P_I_PROC_NAME      => 'validate_order_line',
                                 p_i_phase          => 'Sales Order Line Validation',
                                 P_I_STGTABLE       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in validate_order_line.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RAISE;
   END validate_order_line;

   /************************************************
    * Procedure - Conversion Summary report
   *************************************************/
   PROCEDURE intf_summary_report (
      p_org_name                 IN       VARCHAR2,
      p_order_source             IN       VARCHAR2,
      p_return_status            OUT      NUMBER)
   AS
      /**********************************
         -- Declaring Local Variable --
       **********************************/
      ln_stg_cnt              NUMBER          := 0;
      ln_stg_err_cnt          NUMBER          := 0;
      ln_intf_err             NUMBER          := 0;
      ln_success_cnt          NUMBER          := 0;
      ln_request_id           NUMBER          := 0;
      lv_order_source         VARCHAR2 (2000) := p_order_source;  --'OSSA Visual ERP';
      lv_procedure   CONSTANT VARCHAR2 (2000) := 'INTF_SUMMARY_REPORT';

      /**********************************************************
        --- Cursor to get error records from Staging table --
       ************************************************************/
      CURSOR cur_error_records (
         p_batch_id                 IN       NUMBER)
      IS
         SELECT DISTINCT order_number source_order,
                         'ORDER HEADER' title,                         
                         NULL oracle_order,
                         SUBSTR (header_error_message, 1, 3000) err_message,
                         import_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'E'
         AND             header_val_flag = 'E'
         AND             line_val_flag = 'V'
         AND             header_error_message IS NOT NULL
         AND             import_status IS NULL
         AND             org_name = p_org_name
         AND             batch_id = NVL (p_batch_id, batch_id)
         UNION
         SELECT DISTINCT order_number source_order,
                         'ORDER LINE' title,                         
                         NULL oracle_order,
                         SUBSTR (line_error_message, 1, 3000) err_message,
                         import_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'E'
         AND             header_val_flag = 'V'
         AND             line_val_flag = 'E'
         AND             org_name = p_org_name
         AND             line_error_message IS NOT NULL
         AND             import_status IS NULL
         AND             batch_id = NVL (p_batch_id, batch_id)
         UNION					-- Added by Sankalpa on 30-Jun-2021 for Project Revival
         SELECT DISTINCT order_number source_order,
                         'ORDER' title,                         
                         NULL oracle_order,
                         SUBSTR (header_error_message || line_error_message, 1, 3000) err_message,
                         import_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'E'
         --AND             header_val_flag = 'V'
         --AND             line_val_flag = 'E'
         AND             org_name = p_org_name
         AND             line_error_message IS NOT NULL
         AND             header_error_message IS NOT NULL
         AND             import_status IS NULL
         AND             batch_id = NVL (p_batch_id, batch_id)
         UNION
         SELECT DISTINCT order_number source_order,
                         'ORDER API' title,                         
                         NULL oracle_order,
                         SUBSTR (line_error_message, 1, 3000) err_message,
                         import_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'E'
         AND             header_val_flag = 'V'
         AND             line_val_flag = 'V'
         AND             org_name = p_org_name
         AND             import_status = 'API_FAILED'
         AND             batch_id = NVL (p_batch_id, batch_id);

      /**********************************************************
       --- Cursor to get Success record --
      ************************************************************/
      CURSOR cur_success_records (
         p_batch_id                 IN       NUMBER,
         p_order_source             IN       VARCHAR2)
      IS
         SELECT DISTINCT xx.order_number source_order,
                         'ORDER' title,                         
                         ooha.order_number,
                         xx.import_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl xx,
                         oe_order_headers_all ooha,
                         oe_order_sources oos
         WHERE           ooha.order_source_id = oos.order_source_id
         AND             oos.NAME = p_order_source
         AND             ooha.orig_sys_document_ref = xx.order_number
         AND             xx.process_flag = 'S'
         AND             org_name = p_org_name
         AND             xx.import_status IN ('IMPORTED', 'HOLD_APPLIED')
         AND             xx.batch_id = NVL (p_batch_id, xx.batch_id);
   BEGIN
      --------Fetching the total no.of records in the staging table---------
      SELECT COUNT (DISTINCT order_number)
      INTO   ln_stg_cnt
      FROM   customusr.xx_om_so_hold_conv_stg_tbl
      WHERE  batch_id = NVL (gn_batch_id_num, batch_id)
      and    org_name = p_org_name;      

      --------Fetching total no.of records that failed validation in staging table---------
      select count (distinct order_number)
      INTO   ln_stg_err_cnt
      FROM   customusr.xx_om_so_hold_conv_stg_tbl
      WHERE  process_flag = 'E'
      and    org_name = p_org_name
      AND    NVL(import_status,'XX') NOT IN ('API_FAILED', 'HOLD_FAILED')
      /*AND    (   (header_error_message IS NOT NULL)
              OR (line_error_message IS NOT NULL))*/
      and    batch_id = nvl (gn_batch_id_num, batch_id);

      --------Fetching total no.of records that error out in API---------
      SELECT COUNT (DISTINCT order_number)
      INTO   ln_intf_err
      FROM   customusr.xx_om_so_hold_conv_stg_tbl xx
      WHERE  1 = 1
      AND    xx.process_flag = 'E'
      AND    xx.org_name = p_org_name
      AND    xx.import_status IN ('API_FAILED', 'HOLD_FAILED')
      and    xx.batch_id = nvl (gn_batch_id_num, xx.batch_id);

      --------Fetching total no.of processed records of sales order---------
      select count (distinct ooha.order_number)
      INTO   ln_success_cnt
      FROM   customusr.xx_om_so_hold_conv_stg_tbl xx,
             oe_order_headers_all ooha,
             oe_order_sources oos
      WHERE  ooha.order_source_id = oos.order_source_id
      AND    oos.NAME = lv_order_source
      AND    ooha.orig_sys_document_ref = xx.order_number
      AND    xx.process_flag = 'S'
      AND    org_name = p_org_name
      AND    xx.import_status IN ('IMPORTED', 'HOLD_APPLIED')
      and    xx.batch_id = nvl (gn_batch_id_num, xx.batch_id);

      --------Get request_id from staging table---------
      -- Commented by Sankalpa on 30-Jun-2021 for Project Revival
	  /*SELECT DISTINCT request_id
      INTO            ln_request_id
      FROM            customusr.xx_om_so_hold_conv_stg_tbl
      WHERE           batch_id = NVL (gn_batch_id_num, batch_id)
      and             org_name = p_org_name; */   

      fnd_file.put_line (fnd_file.output, '-------------------------------------------------------------------------------');
      fnd_file.put_line (fnd_file.output,
                         '                     VISUAL Sales Order Conversion Report                         ');
      fnd_file.put_line (fnd_file.output, '-------------------------------------------------------------------------------');
      fnd_file.put_line (fnd_file.output,
                         'Batch ID                                                                  : ' || gn_batch_id_num);
      fnd_file.put_line (fnd_file.output,
                         'Job Request ID                                                  : ' || fnd_global.conc_request_id);
      fnd_file.put_line (fnd_file.output, 'Total number of records in staging table                   : ' || ln_stg_cnt);
      fnd_file.put_line (fnd_file.output,
                         'No. of records that failed validation in staging table         : ' || ln_stg_err_cnt);
      fnd_file.put_line (fnd_file.output, 'No. of records that error out in interface table            : ' || ln_intf_err);
      fnd_file.put_line (fnd_file.output,
                         'Total records Converted to Oracle EBS                                 : ' || ln_success_cnt);
      fnd_file.put_line (fnd_file.output,
                         '----------------------------------------------------------------------------------------');
      fnd_file.put_line (fnd_file.output, ' ');

      IF ((ln_stg_err_cnt > 0) OR (ln_intf_err > 0))
      THEN
         fnd_file.put_line (fnd_file.output,
                            '----------------------------------------------------------------------------------------');
         fnd_file.put_line
                       (fnd_file.output,
                        '                                Sales Order Conversion Error Details                               ');
         fnd_file.put_line (fnd_file.output,
                            '----------------------------------------------------------------------------------------');
         fnd_file.put_line (fnd_file.output,
                               RPAD ('VISUAL Order#', 20, ' ')
                            || '|'
                            || RPAD ('TITLE', 20)
                            /*|| '|'					-- Changes start by Sankalpa on 30-Jun-2021 for Project Revival
                            || RPAD ('ORACLE ORDER', 20)
                            || '|'
                            || RPAD ('IMPORT STATUS', 20)*/		-- Changes end by Sankalpa on 30-Jun-2021 for Project Revival
                            || '|'
                            || RPAD ('ERROR DESCRIPTION', 500));

         fnd_file.put_line (fnd_file.output,
                            '----------------------------------------------------------------------------------------');

         /***************************************************************
          -------- Print Staging table error message on output ----
          ***************************************************************/
         FOR rec_err_records IN cur_error_records (gn_batch_id_num)
         LOOP
            fnd_file.put_line (fnd_file.output,
                                  RPAD (rec_err_records.source_order, 20, ' ')
                               || RPAD (rec_err_records.title, 20, ' ')                               
                               --|| RPAD (rec_err_records.oracle_order, 20, ' ')		-- Changes start by Sankalpa on 30-Jun-2021 for Project Revival
                               --|| RPAD (rec_err_records.import_status, 20, ' ')		-- Changes end by Sankalpa on 30-Jun-2021 for Project Revival
                               || SUBSTR (rec_err_records.err_message, 1, 500));

         END LOOP;
      END IF;

      /***************************************************************
       -------- Print Staging table imported order on output ----
       ***************************************************************/
      fnd_file.put_line (fnd_file.output,
                         '----------------------------------------------------------------------------------------');
      fnd_file.put_line
         (fnd_file.output,
          '                                Sales Order Conversion Imported/Hold Order Details                               ');
      fnd_file.put_line (fnd_file.output,
                         '----------------------------------------------------------------------------------------');
      fnd_file.put_line (fnd_file.output,
                            RPAD ('VISUAL Order#', 20, ' ')
                         || '|'
                         || RPAD ('TITLE', 20)
                         || '|'
                         || RPAD ('ORACLE ORDER', 20)
                         || '|'
                         || RPAD ('IMPORT STATUS', 20)
                         || '|'
                         || RPAD ('ERROR DESCRIPTION', 200));
      fnd_file.put_line (fnd_file.output,
                         '----------------------------------------------------------------------------------------');

      FOR rec_success_records IN cur_success_records (gn_batch_id_num, lv_order_source)
      LOOP
         fnd_file.put_line (fnd_file.output,
                               RPAD (rec_success_records.source_order, 20, ' ')
                            || RPAD (rec_success_records.title, 20, ' ')                            
                            || RPAD (rec_success_records.order_number, 20, ' ')
                            || RPAD (rec_success_records.import_status, 20, ' '));
      END LOOP;

      /*IF (ln_stg_cnt = (ln_stg_err_cnt + ln_intf_err))
      THEN
         p_return_status := 2;
      ELS*/IF (ln_stg_cnt = ln_success_cnt)
      THEN
         p_return_status := 0;
      ELSE
         p_return_status := 1;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Exception in Interface Summary Report.SQLCODE: ' || SQLCODE || 'SQLERRM - ' || SQLERRM);
   END intf_summary_report;

   /************************************************
    * Procedure - Conversion Summary report
   *************************************************/
   PROCEDURE intf_sbc_summary_report (
      p_org_name                 IN       VARCHAR2,
      p_order_source             IN       VARCHAR2,
      p_return_status            OUT      NUMBER)
   AS
      /**********************************
         -- Declaring Local Variable --
       **********************************/
      ln_stg_cnt              NUMBER          := 0;
      ln_stg_err_cnt          NUMBER          := 0;
      ln_intf_err             NUMBER          := 0;
      ln_success_cnt          NUMBER          := 0;
      LN_REQUEST_ID           NUMBER          := 0;
      LV_LINE_NUMBER          VARCHAR2(2000)  := NULL;
      lv_order_source         varchar2 (2000) := p_order_source;  
      lv_procedure   CONSTANT VARCHAR2 (2000) := 'INTF_SBC_SUMMARY_REPORT';

      /**********************************************************
        --- Cursor to get error records from Staging table --
       ************************************************************/
      CURSOR cur_error_records (
         p_batch_id                 IN       NUMBER)
      IS
         SELECT DISTINCT customer_po_number source_order,
                         'ORDER HEADER' title,                         
                         NULL ORACLE_ORDER,
                         customer_number,
                         SUBSTR (header_error_message, 1, 3000) err_message,
                         import_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'E'
         AND             header_val_flag = 'E'
         AND             line_val_flag = 'V'
         AND             header_error_message IS NOT NULL
         AND             import_status IS NULL
         AND             org_name = p_org_name
         AND             batch_id = NVL (p_batch_id, batch_id)
         UNION
         SELECT DISTINCT customer_po_number source_order,
                         'ORDER LINE' title,                         
                         NULL oracle_order,
                         customer_number,
                         SUBSTR (line_error_message, 1, 3000) err_message,
                         import_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'E'
         AND             header_val_flag = 'V'
         AND             line_val_flag = 'E'
         AND             org_name = p_org_name
         AND             line_error_message IS NOT NULL
         AND             import_status IS NULL
         AND             batch_id = NVL (p_batch_id, batch_id)
         UNION
         SELECT DISTINCT customer_po_number source_order,
                         'ORDER API' title,                         
                         NULL oracle_order,
                         customer_number,
                         SUBSTR (line_error_message, 1, 3000) err_message,
                         IMPORT_STATUS
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'E'
         AND             HEADER_VAL_FLAG = 'V'
         AND             line_val_flag = 'V'
         AND             org_name = p_org_name
         AND             import_status = 'API_FAILED'
         AND             batch_id = NVL (p_batch_id, batch_id);

      /**********************************************************
       --- Cursor to get Success record --
      ************************************************************/
      CURSOR cur_success_records (
         p_batch_id                 IN       NUMBER,
         p_order_source             in       varchar2)
      IS
         select distinct xx.customer_po_number source_order,
                         xx.order_number,
                         xx.customer_number,
                         XX.IMPORT_STATUS,                         
                         XX.CREATION_DATE
         FROM            CUSTOMUSR.XX_OM_SO_HOLD_CONV_STG_TBL XX
         WHERE           1=1
         AND             XX.PROCESS_FLAG = 'S'
         AND             xx.org_name = p_org_name
         AND             xx.import_status IN ('IMPORTED', 'HOLD_APPLIED')
         AND             xx.batch_id = NVL (p_batch_id, xx.batch_id);
   BEGIN
      --------Fetching the total no.of records in the staging table---------
      SELECT COUNT (DISTINCT customer_po_number)
      INTO   LN_STG_CNT
      FROM   customusr.xx_om_so_hold_conv_stg_tbl
      WHERE  batch_id = NVL (gn_batch_id_num, batch_id)
      and    org_name = p_org_name;
      fnd_file.put_line (fnd_file.log, 'ln_stg_cnt - '||ln_stg_cnt);

      --------Fetching total no.of records that failed validation in staging table---------
      select count (distinct customer_po_number)
      INTO   ln_stg_err_cnt
      FROM   customusr.xx_om_so_hold_conv_stg_tbl
      WHERE  process_flag = 'E'
      and    org_name = p_org_name
      AND    import_status NOT IN ('API_FAILED', 'HOLD_FAILED')
      AND    (   (header_error_message IS NOT NULL)
              OR (line_error_message IS NOT NULL))
      and    batch_id = nvl (gn_batch_id_num, batch_id);
      fnd_file.put_line (fnd_file.log, 'ln_stg_err_cnt - '||ln_stg_err_cnt);
      --------Fetching total no.of records that error out in API---------
      SELECT COUNT (DISTINCT customer_po_number)
      INTO   ln_intf_err
      FROM   customusr.xx_om_so_hold_conv_stg_tbl xx
      WHERE  1 = 1
      AND    xx.process_flag = 'E'
      AND    xx.org_name = p_org_name
      AND    xx.import_status IN ('API_FAILED', 'HOLD_FAILED')
      and    xx.batch_id = nvl (gn_batch_id_num, xx.batch_id);
      fnd_file.put_line (fnd_file.log, 'ln_intf_err - '||ln_intf_err);
      --------Fetching total no.of processed records of sales order---------
      select count (distinct xx.order_number)
      INTO   ln_success_cnt
      FROM   customusr.xx_om_so_hold_conv_stg_tbl xx
      WHERE  1=1
      AND    xx.process_flag = 'S'
      AND    org_name = p_org_name
      AND    XX.IMPORT_STATUS IN ('IMPORTED', 'HOLD_APPLIED')
      and    xx.batch_id = nvl (gn_batch_id_num, xx.batch_id);
      fnd_file.put_line (fnd_file.log, 'ln_success_cnt - '||ln_success_cnt);
      --------Get request_id from staging table---------
      SELECT DISTINCT request_id
      INTO            ln_request_id
      FROM            customusr.xx_om_so_hold_conv_stg_tbl
      WHERE           batch_id = NVL (gn_batch_id_num, batch_id)
      and             org_name = p_org_name;
      --fnd_file.put_line (fnd_file.log, 'ln_request_id - '||ln_request_id);

      fnd_file.put_line (fnd_file.output, '-------------------------------------------------------------------------------');
      fnd_file.put_line (fnd_file.output,
                         '                     VISUAL Sales Order Import Report                         ');
      fnd_file.put_line (fnd_file.output, '-------------------------------------------------------------------------------');
      fnd_file.put_line (fnd_file.output,
                         'Batch ID                                                                  : ' || gn_batch_id_num);
      fnd_file.put_line (fnd_file.output,
                         'Job Request ID                                                  : ' || ln_request_id);
      fnd_file.put_line (fnd_file.output, 'Total number of records in staging table                   : ' || ln_stg_cnt);
      fnd_file.put_line (fnd_file.output,
                         'No. of records that failed validation in staging table         : ' || ln_stg_err_cnt);
      fnd_file.put_line (fnd_file.output, 'No. of records that error out in interface table            : ' || ln_intf_err);
      fnd_file.put_line (fnd_file.output,
                         'Total records Converted to Oracle EBS                                 : ' || ln_success_cnt);
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                         '----------------------------------------------------------------------------------------');
      fnd_file.put_line (fnd_file.output, ' ');

      IF ((ln_stg_err_cnt > 0) OR (ln_intf_err > 0))
      THEN
         fnd_file.put_line (fnd_file.output,
                            '----------------------------------------------------------------------------------------');
         fnd_file.put_line
                       (fnd_file.output,
                        '                                Sales Order Conversion Error Details                               ');
         fnd_file.put_line (fnd_file.output,
                            '----------------------------------------------------------------------------------------');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,                               
                            RPAD ('CUSTOMER NUMBER', 20)
                            || RPAD ('CUSTOMER PO', 20)                          
                            || RPAD ('IMPORT STATUS', 20)                          
                            || RPAD ('ERROR DESCRIPTION', 500));
         fnd_file.put_line (fnd_file.output,
                            '----------------------------------------------------------------------------------------');

         /***************************************************************
          -------- Print Staging table error message on output ----
          ***************************************************************/
         FOR rec_err_records IN cur_error_records (gn_batch_id_num)
         LOOP
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                                  RPAD (rec_err_records.customer_number, 20, ' ')
                               || RPAD (NVL(rec_err_records.source_order,' '), 20, ' ')
                               || RPAD (rec_err_records.import_status, 20, ' ')
                               || RPAD (SUBSTR (rec_err_records.err_message, 1, 500), 500, ' '));
         END LOOP;
      END IF;

      /***************************************************************
       -------- Print Staging table imported order on output ----
       ***************************************************************/
      fnd_file.put_line (fnd_file.output,
                         '----------------------------------------------------------------------------------------');
      fnd_file.put_line
         (fnd_file.output,
          '                                Sales Order Conversion Imported/Hold Order Details                               ');
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                         '-----------------------------------------------------------------------------------------');
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                         RPAD ('CUSTOMER NUMBER', 20)
                         || RPAD ('CUSTOMER PO', 20)
                         || RPAD ('ORACLE ORDER', 20)                        
                         || RPAD ('IMPORT STATUS', 20)
                         || RPAD ('CREATION DATE', 20)
                         || 'HOLD DETAILS' );   -- Added by Sankalpa on 01-Mar-2021 for Project Revival
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                         '------------------------------------------------------------------------------------------------------------------------');
      -- Addition start by Sankalpa on 01-Mar-2021 for Project Revival 
      FOR REC_SUCCESS_RECORDS IN CUR_SUCCESS_RECORDS (GN_BATCH_ID_NUM, LV_ORDER_SOURCE)
      LOOP
         lv_line_number := NULL;
         BEGIN
           SELECT LISTAGG (OOLA.LINE_NUMBER,',') WITHIN GROUP (ORDER BY OOLA.LINE_NUMBER ASC) LINE_NUMBER
             INTO lv_line_number
            FROM OE_ORDER_HOLDS_ALL OOHA,
                 OE_ORDER_LINES_ALL OOLA,
                 OE_HOLD_DEFINITIONS HO,
                 oe_order_headers_all ooh,
                 OE_HOLD_SOURCES_ALL HS
            WHERE OOHA.HEADER_ID = OOLA.HEADER_ID
              AND OOH.HEADER_ID = OOLA.HEADER_ID
              AND OOHA.LINE_ID = OOLA.LINE_ID
              AND OOHA.HOLD_SOURCE_ID = HS.HOLD_SOURCE_ID
              AND HS.HOLD_ID = HO.HOLD_ID
              AND HO.NAME = 'PRICE DISCREPANCY HOLD'
              AND OOH.ORDER_NUMBER = rec_success_records.order_number
              GROUP BY ooh.order_number;  

              LV_LINE_NUMBER := 'Line No: '|| LV_LINE_NUMBER || ' - PRICE DISCREPANCY HOLD';
              fnd_file.put_line (fnd_file.log, LV_LINE_NUMBER);
         EXCEPTION
          WHEN OTHERS THEN
            lv_line_number := NULL;
         END;

         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                              RPAD (REC_SUCCESS_RECORDS.customer_number, 20, ' ')
                            || RPAD (REC_SUCCESS_RECORDS.SOURCE_ORDER, 20, ' ')
                            || RPAD (rec_success_records.order_number, 20, ' ')
                            || RPAD (REC_SUCCESS_RECORDS.IMPORT_STATUS, 20, ' ')
                            || RPAD (REC_SUCCESS_RECORDS.CREATION_DATE, 20, ' ')
                            || LV_LINE_NUMBER );
      END LOOP;
      -- Addition end by Sankalpa on 01-Mar-2021 for Project Revival 
      IF (ln_stg_cnt = ln_success_cnt)
      THEN
         p_return_status := 0;
      ELSE
         p_return_status := 1;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.log,
                            'Exception in Interface Summary Report.SQLCODE: ' || sqlcode || 'SQLERRM - ' || sqlerrm);
   end intf_sbc_summary_report;

   /*********************************************************************************
    -- Function to get SBC price --
    *********************************************************************************/
   FUNCTION get_sbc_price (
      P_BILL_TO             IN       NUMBER,
      p_item                IN       VARCHAR2)
      RETURN NUMBER
   AS
      ln_price_list_val   NUMBER := 0;
   BEGIN
      BEGIN
        SELECT qll.operand
        INTO   ln_price_list_val
        FROM   HZ_CUST_SITE_USES_ALL HCSU,
               QP_LIST_LINES_V QLL
        WHERE  HCSU.SITE_USE_ID = P_BILL_TO
          AND  HCSU.SITE_USE_CODE = 'BILL_TO'
          AND  HCSU.price_list_id = QLL.LIST_HEADER_ID
          and  qll.product_attr_value = p_item;

     EXCEPTION
       WHEN OTHERS THEN
         LN_PRICE_LIST_VAL := NULL;
     END;    
     RETURN LN_PRICE_LIST_VAL ; 
   EXCEPTION
      WHEN OTHERS
      THEN
         FND_FILE.PUT_LINE (FND_FILE.LOG, 'SBC Price check issue.SQLCODE: ' || SQLCODE || ' SQLERRM :' || SQLERRM);
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 P_I_PROC_NAME      => 'get_sbc_price',
                                 p_i_phase          => 'SBC Price Validation',
                                 P_I_STGTABLE       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'SBC Price check in get_sbc_price.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SQLERRM);
         RETURN ('Y');
   END get_sbc_price;

  /******************************************************
  -- Procedure  to submit standard order import program --
  *******************************************************/
   PROCEDURE submit_import_program (
      p_batch_id                 IN       NUMBER,
      p_source                   IN       VARCHAR2,
      p_org_name                 IN       VARCHAR2)
   IS
      CURSOR cur_stage_header_data (
         pi_batch_id                IN       NUMBER,
         pi_org_name                IN       VARCHAR2)
      IS
         SELECT DISTINCT order_source_id,
                         batch_id,
                         org_name,
                         order_number,
                         org_id,
                         ordered_date,
                         hdr_trx_type_id,
                         price_list,
                         currency,
                         payment_term,
                         shipping_method_code,
                         inco_terms,
                         customer_po_number,
                         customer_po_received_date,
                         header_ship_from_org,
                         ship_to_org_id,
                         bill_to_org_id,
                         customer_id,
                         hdr_sold_to_org_id,
                         hdr_shipping_instructions,
                         header_status,
                         accept_early_shipments,
                         collect_accounts,
                         customer_currency,
                         sold_to_id,
                         sold_to_name || sold_to_addr || sold_to_city || sold_to_state || sold_to_zip
                         || sold_to_country   visual_cust_details,
                         shipping_terms,
                         header_attribute1,
                         header_attribute2,
                         header_attribute3,
                         header_attribute4,
                         header_attribute5,
                         header_attribute6,
                         header_attribute7,
                         header_attribute8,
                         header_attribute9,
                         header_attribute10
           FROM          customusr.xx_om_so_hold_conv_stg_tbl x1
           WHERE         1 = 1
           AND           x1.org_name = pi_org_name
           AND           x1.batch_id = pi_batch_id
           AND           x1.order_source = p_source
           AND           x1.process_flag = 'V'
           AND           x1.header_val_flag = 'V'
           AND           x1.line_val_flag = 'V'            
           AND           NOT EXISTS (SELECT '1'
                                     FROM   customusr.xx_om_so_hold_conv_stg_tbl x2
                                     WHERE  x1.order_number = x2.order_number
                                     and    X1.ORG_NAME = X2.ORG_NAME 
                                     AND    x2.batch_id = pi_batch_id
                                     AND    x2.process_flag = 'E');

      CURSOR cur_stage_line_data (
         pi_order_number            IN       VARCHAR2,
         pi_org_name                IN       VARCHAR2,
         pi_batch_id                IN       NUMBER)
      IS
         SELECT *
         FROM   customusr.xx_om_so_hold_conv_stg_tbl
         WHERE  1 = 1
         AND    org_name = pi_org_name
         AND    order_number = pi_order_number
         AND    batch_id = pi_batch_id
         AND    order_source = p_source;

      -- // VARIABLE DECLARATIONS
      l_header_rec               oe_order_pub.header_rec_type;
      l_line_tbl                 oe_order_pub.line_tbl_type;
      l_action_request_tbl       oe_order_pub.request_tbl_type;
      l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
      l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
      l_header_scr_tbl           oe_order_pub.header_scredit_tbl_type;
      l_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
      l_request_rec              oe_order_pub.request_rec_type;
      x_header_rec               oe_order_pub.header_rec_type             := oe_order_pub.g_miss_header_rec;
      x_line_tbl                 oe_order_pub.line_tbl_type               := oe_order_pub.g_miss_line_tbl;
      x_header_val_rec           oe_order_pub.header_val_rec_type;
      x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
      x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
      x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
      x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
      x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
      x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
      x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
      x_line_val_tbl             oe_order_pub.line_val_tbl_type;
      x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
      x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
      x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
      x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
      x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
      x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
      x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
      x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
      x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
      x_action_request_tbl       oe_order_pub.request_tbl_type;
      lv_return_status           VARCHAR2 (1000);
      ln_msg_count               NUMBER;
      lv_msg_data                VARCHAR2 (1000);
      p_api_version_number       NUMBER                                   := 1.0;
      p_init_msg_list            VARCHAR2 (10)                            := fnd_api.g_false;
      p_return_values            VARCHAR2 (10)                            := fnd_api.g_false;
      p_action_commit            VARCHAR2 (10)                            := fnd_api.g_false;
      x_return_status            VARCHAR2 (1);
      x_msg_count                NUMBER;
      x_msg_data                 VARCHAR2 (100);
      x_debug_file               VARCHAR2 (100);
      ln_msg_index_out           NUMBER (10);
      ln_line_tbl_index          NUMBER;
      ln_org_id                  NUMBER;
      ln_price_list_id           NUMBER;
      ln_ship_from_org_id        NUMBER;
      ln_payment_term_id         NUMBER;
      lv_org_name                VARCHAR2 (200);
      lv_order_number            VARCHAR2 (200);
      lv_procedure               VARCHAR2 (30)                            := 'submit_import_program';
   BEGIN

      get_org_id ( p_org_id      => ln_org_id );
      --fnd_file.put_line (fnd_file.LOG, 'ln_org_id - '||ln_org_id);
      BEGIN
         SELECT NAME
         INTO   lv_org_name
         FROM   hr_operating_units
         WHERE  organization_id = ln_org_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            lv_org_name := NULL;
            fnd_file.put_line (fnd_file.LOG, 'Derivation issue for operating unit');
            RAISE e_submit_api_error;
      END;

      oe_debug_pub.initialize;
      oe_debug_pub.setdebuglevel (0);
      oe_msg_pub.initialize;
      l_line_tbl := oe_order_pub.g_miss_line_tbl;

      FOR rec_stage_header_data IN cur_stage_header_data (pi_batch_id => gn_batch_id_num, pi_org_name => lv_org_name)
      LOOP
         /*BEGIN
            SELECT list_header_id
            INTO   ln_price_list_id
            FROM   qp_list_headers
            WHERE  NAME = rec_stage_header_data.price_list;
         EXCEPTION
            WHEN OTHERS
            THEN
               ln_price_list_id := 0;
               fnd_file.put_line (fnd_file.LOG, 'Derivation issue for price list id');
               RAISE e_submit_api_error;
         END;*/
        if rec_stage_header_data.sold_to_id is not null
        THEN
           BEGIN
              SELECT organization_id
              INTO   ln_ship_from_org_id
              FROM   mtl_parameters
              WHERE  organization_code = rec_stage_header_data.header_ship_from_org;
           EXCEPTION
              WHEN OTHERS
              THEN
                 ln_ship_from_org_id := 0;
                 fnd_file.put_line (fnd_file.LOG, 'Derivation issue for ship to org');
                 RAISE e_submit_api_error;
           END;

           BEGIN
              SELECT term_id
              INTO   ln_payment_term_id
              FROM   ra_terms
              WHERE  NAME = rec_stage_header_data.payment_term;
           EXCEPTION
              WHEN OTHERS
              THEN
                 ln_payment_term_id := 0;
                 fnd_file.put_line (fnd_file.log, 'Derivation issue for payment term');
                 RAISE e_submit_api_error;
           end;
         END IF;
         fnd_file.put_line (fnd_file.LOG, 'Processing for order source reference : ' || rec_stage_header_data.order_number);

         ln_line_tbl_index := 0;
         l_header_rec := oe_order_pub.g_miss_header_rec;
         l_header_rec.operation := oe_globals.g_opr_create;
         lv_order_number := rec_stage_header_data.order_number;
         l_header_rec.order_source_id := rec_stage_header_data.order_source_id;
         l_header_rec.org_id := rec_stage_header_data.org_id;
         l_header_rec.orig_sys_document_ref := rec_stage_header_data.order_number;
         l_header_rec.ordered_date := rec_stage_header_data.ordered_date;
         l_header_rec.order_type_id := rec_stage_header_data.hdr_trx_type_id;
         --l_header_rec.price_list_id := ln_price_list_id;
         l_header_rec.transactional_curr_code := rec_stage_header_data.currency;
         l_header_rec.payment_term_id := ln_payment_term_id;
         l_header_rec.shipping_method_code := rec_stage_header_data.shipping_method_code;
         l_header_rec.fob_point_code := rec_stage_header_data.inco_terms;
         l_header_rec.cust_po_number := rec_stage_header_data.customer_po_number;
         l_header_rec.ship_from_org_id := ln_ship_from_org_id;
         L_HEADER_REC.SHIP_TO_ORG_ID := REC_STAGE_HEADER_DATA.SHIP_TO_ORG_ID;
         l_header_rec.sold_from_org_id :=rec_stage_header_data.org_id;
         l_header_rec.invoice_to_org_id := rec_stage_header_data.bill_to_org_id;
         l_header_rec.sold_to_org_id := rec_stage_header_data.hdr_sold_to_org_id;
         l_header_rec.shipping_instructions := rec_stage_header_data.hdr_shipping_instructions;
         l_header_rec.status_flag := rec_stage_header_data.header_status;
         l_header_rec.context := 'OSSA Order Conversion';
         l_header_rec.attribute5 := rec_stage_header_data.customer_po_received_date;
         l_header_rec.attribute6 := rec_stage_header_data.collect_accounts;
         l_header_rec.attribute7 := rec_stage_header_data.accept_early_shipments;
         --l_header_rec.attribute8 := rec_stage_header_data.customer_currency;
         l_header_rec.attribute9 := rec_stage_header_data.sold_to_id;
         l_header_rec.attribute4 := rec_stage_header_data.visual_cust_details;
         l_header_rec.attribute13 := rec_stage_header_data.header_attribute1;
         l_header_rec.attribute16 := rec_stage_header_data.header_attribute2;
         l_header_rec.attribute19 := rec_stage_header_data.header_attribute3;
         l_header_rec.attribute20 := rec_stage_header_data.header_attribute4;
         l_header_rec.creation_date := SYSDATE;
         l_header_rec.last_updated_by := fnd_profile.VALUE ('USER_ID');
         l_header_rec.last_update_date := SYSDATE;
         l_header_rec.last_update_login := USERENV ('SESSIONID');         

         FOR rec_stage_line_data IN cur_stage_line_data (pi_order_number      => rec_stage_header_data.order_number,
                                                         pi_org_name          => rec_stage_header_data.org_name,
                                                         pi_batch_id          => gn_batch_id_num)
         LOOP

            ln_line_tbl_index := ln_line_tbl_index + 1;
            l_line_tbl (ln_line_tbl_index) := oe_order_pub.g_miss_line_rec;
            l_line_tbl (ln_line_tbl_index).order_source_id := rec_stage_line_data.order_source_id;
            l_line_tbl (ln_line_tbl_index).operation := oe_globals.g_opr_create;
            l_line_tbl (ln_line_tbl_index).inventory_item_id := rec_stage_line_data.inventory_item_id;
            l_line_tbl (ln_line_tbl_index).ordered_item := rec_stage_line_data.customer_item_name;
            l_line_tbl (ln_line_tbl_index).item_identifier_type := 'OSSA SALES CODE';
            l_line_tbl (ln_line_tbl_index).orig_sys_document_ref := rec_stage_line_data.order_number;
            l_line_tbl (ln_line_tbl_index).orig_sys_shipment_ref := rec_stage_line_data.order_number;
            l_line_tbl (ln_line_tbl_index).orig_sys_document_ref := rec_stage_line_data.order_number;
            l_line_tbl (ln_line_tbl_index).line_id := oe_order_lines_s.NEXTVAL;
            l_line_tbl (ln_line_tbl_index).line_type_id := rec_stage_line_data.line_trx_type_id;
            l_line_tbl (ln_line_tbl_index).ordered_quantity := rec_stage_line_data.ordered_quantity;
            l_line_tbl (ln_line_tbl_index).order_quantity_uom := rec_stage_line_data.order_quantity_uom;
            l_line_tbl (ln_line_tbl_index).ship_from_org_id := ln_ship_from_org_id;
            l_line_tbl (ln_line_tbl_index).ship_to_org_id := rec_stage_line_data.ship_to_org_id;
            l_line_tbl (ln_line_tbl_index).invoice_to_org_id := rec_stage_line_data.bill_to_org_id;
            l_line_tbl (ln_line_tbl_index).price_list_id := ln_price_list_id;
            l_line_tbl (ln_line_tbl_index).unit_list_price := rec_stage_line_data.unit_price;
            l_line_tbl (ln_line_tbl_index).unit_selling_price := rec_stage_line_data.unit_price;
            l_line_tbl (ln_line_tbl_index).payment_term_id := ln_payment_term_id;
            l_line_tbl (ln_line_tbl_index).shipping_method_code := rec_stage_line_data.shipping_method_code;
            l_line_tbl (ln_line_tbl_index).fob_point_code := rec_stage_line_data.inco_terms;
            l_line_tbl (ln_line_tbl_index).cust_po_number := rec_stage_line_data.customer_po_number;
            l_line_tbl (ln_line_tbl_index).schedule_ship_date := NVL(rec_stage_line_data.revised_ship_date,rec_stage_line_data.scheduled_ship_date);
            l_line_tbl (ln_line_tbl_index).promise_date := rec_stage_line_data.promised_date;
            l_line_tbl (ln_line_tbl_index).status_flag := 'R';
            L_LINE_TBL (LN_LINE_TBL_INDEX).LINE_NUMBER := rec_stage_line_data.line_number;
            l_line_tbl (ln_line_tbl_index).request_date := NVL (rec_stage_line_data.request_date, SYSDATE);
            l_line_tbl (ln_line_tbl_index).shipping_instructions := rec_stage_line_data.line_shipping_instructions;
            l_line_tbl (ln_line_tbl_index).packing_instructions := rec_stage_line_data.packing_instructions;
            --l_line_tbl (ln_line_tbl_index).request_id := rec_stage_line_data.request_id;  -- Commented by Sankalpa on 30-Jun-2021 for Project Revival
            l_line_tbl (ln_line_tbl_index).context := 'OSSA Order conversion';
            l_line_tbl (ln_line_tbl_index).attribute1 := rec_stage_line_data.mrp_date;
            l_line_tbl (ln_line_tbl_index).attribute2 := rec_stage_line_data.end_user_price;
            l_line_tbl (ln_line_tbl_index).attribute4 := rec_stage_line_data.late_reason_code;
            l_line_tbl (ln_line_tbl_index).attribute9 := rec_stage_line_data.line_attribute1;
            IF rec_stage_line_data.revised_ship_date IS NOT NULL
            THEN
               l_line_tbl (ln_line_tbl_index).attribute3 := rec_stage_line_data.scheduled_ship_date;
            ELSE
               l_line_tbl (ln_line_tbl_index).attribute3 := NULL;
            END IF;            
            l_line_tbl (ln_line_tbl_index).attribute17 := rec_stage_line_data.customer_currency;
            l_line_tbl (ln_line_tbl_index).created_by := fnd_profile.VALUE ('USER_ID');
            l_line_tbl (ln_line_tbl_index).last_updated_by := fnd_profile.VALUE ('USER_ID');
            l_line_tbl (ln_line_tbl_index).last_update_date := SYSDATE;
            l_line_tbl (ln_line_tbl_index).last_update_login := USERENV ('SESSIONID');
         END LOOP;

         fnd_file.put_line (fnd_file.LOG, 'Calling API for org_id : ' || ln_org_id);
         mo_global.set_policy_context ('S', ln_org_id);
         mo_global.set_org_context (ln_org_id, NULL, 'ONT');
         fnd_global.apps_initialize (user_id           => fnd_profile.VALUE ('USER_ID'),
                                     resp_id           => fnd_profile.VALUE ('RES_ID'),
                                     resp_appl_id      => fnd_profile.VALUE ('RESP_APPL_ID'));

         -- // CALL TO PROCESS ORDER
         --fnd_file.put_line (fnd_file.LOG, 'Before calling oe_order_pub.process_order');
         oe_order_pub.process_order (p_api_version_number          => 1.0,
                                     p_init_msg_list               => fnd_api.g_false,
                                     p_return_values               => fnd_api.g_false,
                                     p_action_commit               => fnd_api.g_false,
                                     x_return_status               => lv_return_status,
                                     x_msg_count                   => ln_msg_count,
                                     x_msg_data                    => lv_msg_data,
                                     p_header_rec                  => l_header_rec,
                                     p_line_tbl                    => l_line_tbl,
                                     p_action_request_tbl          => l_action_request_tbl,
                                     x_header_rec                  => x_header_rec,
                                     x_header_val_rec              => x_header_val_rec,
                                     x_header_adj_tbl              => x_header_adj_tbl,
                                     x_header_adj_val_tbl          => x_header_adj_val_tbl,
                                     x_header_price_att_tbl        => x_header_price_att_tbl,
                                     x_header_adj_att_tbl          => x_header_adj_att_tbl,
                                     x_header_adj_assoc_tbl        => x_header_adj_assoc_tbl,
                                     x_header_scredit_tbl          => x_header_scredit_tbl,
                                     x_header_scredit_val_tbl      => x_header_scredit_val_tbl,
                                     x_line_tbl                    => x_line_tbl,
                                     x_line_val_tbl                => x_line_val_tbl,
                                     x_line_adj_tbl                => x_line_adj_tbl,
                                     x_line_adj_val_tbl            => x_line_adj_val_tbl,
                                     x_line_price_att_tbl          => x_line_price_att_tbl,
                                     x_line_adj_att_tbl            => x_line_adj_att_tbl,
                                     x_line_adj_assoc_tbl          => x_line_adj_assoc_tbl,
                                     x_line_scredit_tbl            => x_line_scredit_tbl,
                                     x_line_scredit_val_tbl        => x_line_scredit_val_tbl,
                                     x_lot_serial_tbl              => x_lot_serial_tbl,
                                     x_lot_serial_val_tbl          => x_lot_serial_val_tbl,
                                     x_action_request_tbl          => x_action_request_tbl);

         FOR i IN 1 .. ln_msg_count
         LOOP
            oe_msg_pub.get (p_msg_index          => i,
                            p_encoded            => fnd_api.g_false,
                            p_data               => lv_msg_data,
                            p_msg_index_out      => ln_msg_index_out);
         END LOOP;

         IF lv_return_status = fnd_api.g_ret_sts_success
         THEN
            fnd_file.put_line (fnd_file.LOG, 'Order created sucessfully: ' || x_header_rec.order_number);
            COMMIT;

            BEGIN
               UPDATE customusr.xx_om_so_hold_conv_stg_tbl
                  SET import_status = 'IMPORTED',
                      process_flag = 'S',
                      last_update_date = SYSDATE,
                      last_updated_by = fnd_profile.VALUE ('USER_ID')
                WHERE batch_id = gn_batch_id_num
               AND    order_number = lv_order_number;

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'Error updating batch status in staging table to IMPORTED: '
                                     || lv_procedure
                                     || '; Error => '
                                     || SQLERRM);
                  xx_comn_conv_debug_prc
                                      (p_i_level          => NULL,
                                       p_i_proc_name      => 'submit_import_program',
                                       p_i_phase          => 'Submit import program',
                                       p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                       p_i_message        =>    'Error updating batch status in staging table to IMPORTED.SQLCODE: '
                                                             || SQLCODE
                                                             || ' SQLERRM :'
                                                             || SUBSTR (SQLERRM, 1, 100));
            END;
         ELSE
            fnd_file.put_line (fnd_file.LOG, 'Order Creation failed');
            COMMIT;

            BEGIN
               UPDATE customusr.xx_om_so_hold_conv_stg_tbl
                  SET import_status = 'API_FAILED',
                      process_flag = 'E',
                      line_error_message = lv_msg_data,
                      last_update_date = SYSDATE,
                      last_updated_by = fnd_profile.VALUE ('USER_ID')
                WHERE batch_id = gn_batch_id_num
               AND    order_number = lv_order_number;

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'Error updating batch status in staging table to API_FAILED: '
                                     || lv_procedure
                                     || '; Error => '
                                     || SQLERRM);
                  xx_comn_conv_debug_prc
                                    (p_i_level          => NULL,
                                     p_i_proc_name      => 'submit_import_program',
                                     p_i_phase          => 'Submit import program',
                                     p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                     p_i_message        =>    'Error updating batch status in staging table to API_FAILED.SQLCODE: '
                                                           || SQLCODE
                                                           || ' SQLERRM :'
                                                           || SUBSTR (SQLERRM, 1, 100));
            END;
         END IF;
      END LOOP;
   exception
      WHEN e_submit_api_error
      THEN
         fnd_file.put_line (fnd_file.log,
                            'Error submitting order import API. ' || lv_procedure || '; Error => ' || SQLERRM);
         x_return_status := fnd_api.g_ret_sts_error;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'submit_import_program',
                                 p_i_phase          => 'Submit import program',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Error in order creation using API.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || substr (sqlerrm, 1, 100));        

      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal error in order creation using API. ' || lv_procedure || '; Error => ' || SQLERRM);
         x_return_status := fnd_api.g_ret_sts_error;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'submit_import_program',
                                 p_i_phase          => 'Submit import program',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Error in order creation using API.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || substr (sqlerrm, 1, 100));
         --RAISE e_submit_api_error;
   END submit_import_program;   

/************************************************************************
-- Procedure  to submit standard order import program for SBC orders--
*************************************************************************/
   PROCEDURE submit_sbc_import_program (
      p_batch_id                 IN       NUMBER,
      p_source                   IN       VARCHAR2,
      p_org_name                 IN       VARCHAR2)
   IS
      CURSOR cur_stage_header_data (
         pi_batch_id                IN       NUMBER,
         pi_org_name                IN       VARCHAR2)
      IS
         SELECT DISTINCT order_source_id,
                         batch_id,
                         org_name,
                         org_id,
                         HDR_TRX_TYPE_ID,
                         customer_po_number,
                         ship_to_org_id,
                         bill_to_org_id,
                         customer_id,
                         HDR_SOLD_TO_ORG_ID,
                         LINE_SHIP_FROM_ORG,
                         currency       -- Added by Sankalpa on 17-mar-2021 for Project Revival defect OSSATSTING-21988
         FROM            customusr.xx_om_so_hold_conv_stg_tbl x1
         WHERE           1 = 1
         AND             org_name = pi_org_name         
         AND             x1.batch_id = pi_batch_id
         AND             x1.order_source = p_source
         AND             x1.process_flag = 'V'
         AND             x1.header_val_flag = 'V'
         AND             x1.line_val_flag = 'V'            
         AND             NOT EXISTS (SELECT '1'
                                     FROM   customusr.xx_om_so_hold_conv_stg_tbl x2
                                     WHERE  x1.customer_po_number = x2.customer_po_number
                                     and    X1.ORG_NAME = X2.ORG_NAME 
                                     AND    X2.BATCH_ID = PI_BATCH_ID
                                     AND    X2.PROCESS_FLAG = 'E');        

      CURSOR cur_stage_line_data (
         pi_cust_po_number          IN       VARCHAR2,
         pi_org_name                IN       VARCHAR2,
         pi_batch_id                IN       NUMBER)
      IS
         SELECT *
         FROM   customusr.xx_om_so_hold_conv_stg_tbl
         WHERE  1 = 1         
         AND    customer_po_number = pi_cust_po_number
         AND    batch_id = pi_batch_id
         AND    order_source = p_source;

      CURSOR cur_stage_apply_hold (
         pi_order_number            IN       VARCHAR2)
      IS
         SELECT OOHA.HEADER_ID,
                OOLA.LINE_ID,
                ooha.cust_po_number,
                oola.ordered_item
         FROM   OE_ORDER_HEADERS_ALL OOHA,
                OE_ORDER_LINES_ALL OOLA
         WHERE  1 = 1         
         AND    OOHA.HEADER_ID = OOLA.HEADER_ID
         AND    oola.unit_selling_price <> NVL(oola.attribute19, oola.unit_selling_price)
         AND    ooha.order_number = pi_order_number ;  

      -- // VARIABLE DECLARATIONS
      l_header_rec               oe_order_pub.header_rec_type;
      l_line_tbl                 oe_order_pub.line_tbl_type;
      l_action_request_tbl       oe_order_pub.request_tbl_type;
      l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
      l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
      l_header_scr_tbl           oe_order_pub.header_scredit_tbl_type;
      l_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
      l_request_rec              oe_order_pub.request_rec_type;
      x_header_rec               oe_order_pub.header_rec_type             := oe_order_pub.g_miss_header_rec;
      x_line_tbl                 oe_order_pub.line_tbl_type               := oe_order_pub.g_miss_line_tbl;
      x_header_val_rec           oe_order_pub.header_val_rec_type;
      x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
      x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
      x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
      x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
      x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
      x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
      x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
      x_line_val_tbl             oe_order_pub.line_val_tbl_type;
      x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
      x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
      x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
      x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
      x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
      x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
      x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
      x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
      x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
      x_action_request_tbl       oe_order_pub.request_tbl_type;
      lv_return_status           VARCHAR2 (1000);
      ln_msg_count               NUMBER;
      lv_msg_data                VARCHAR2 (1000);
      p_api_version_number       NUMBER                                   := 1.0;
      p_init_msg_list            VARCHAR2 (10)                            := fnd_api.g_false;
      p_return_values            VARCHAR2 (10)                            := fnd_api.g_false;
      p_action_commit            VARCHAR2 (10)                            := fnd_api.g_false;
      x_return_status            VARCHAR2 (1);
      x_msg_count                NUMBER;
      x_msg_data                 VARCHAR2 (100);
      x_debug_file               VARCHAR2 (100);
      ln_msg_index_out           NUMBER (10);
      LN_LINE_TBL_INDEX          NUMBER;      
      ln_hold_tbl_index          NUMBER;
      ln_org_id                  NUMBER;
      ln_price_list_id           NUMBER;
      ln_ship_from_org_id        NUMBER;
      ln_payment_term_id         NUMBER;    
      LV_ORG_NAME                VARCHAR2 (200);
      LV_ORDER_NUMBER            VARCHAR2 (200);
      DBG_FILE                   VARCHAR2(1024);  
      LN_SBC_PRICE               NUMBER;
      LN_HOLD_ID                 NUMBER; 
      LN_HEADER_ID               NUMBER;
      ln_line_id                 NUMBER;    
      LV_PROCEDURE               VARCHAR2 (30)          := 'submit_sbc_import_program';      
   BEGIN
      --ln_org_id := fnd_profile.VALUE ('ORG_ID');
      lv_org_name := p_org_name;

      OE_DEBUG_PUB.INITIALIZE;
      OE_DEBUG_PUB.SETDEBUGLEVEL (0);
      oe_msg_pub.initialize;
      l_line_tbl := oe_order_pub.g_miss_line_tbl;

      BEGIN
         SELECT organization_id
         INTO   ln_org_id
         FROM   hr_operating_units
         WHERE  name = lv_org_name;

         fnd_file.put_line (fnd_file.LOG, 'Submitting program for org id in other SBC orders: ' || ln_org_id);
      EXCEPTION
         WHEN OTHERS
         THEN
            ln_org_id := NULL;
            RAISE ;
      END;

      BEGIN
        SELECT hold_id
          INTO ln_hold_id
          FROM apps.oe_hold_definitions ohd
        WHERE name = 'PRICE DISCREPANCY HOLD' ;

      EXCEPTION
        WHEN OTHERS THEN
          LN_HOLD_ID := NULL;
      END;

      FOR rec_stage_header_data IN cur_stage_header_data (pi_batch_id => gn_batch_id_num, pi_org_name => lv_org_name)
      LOOP                                              
         LN_LINE_TBL_INDEX := 0;       
         LN_HOLD_TBL_INDEX := 0;
         ln_header_id := oe_order_headers_s.nextval;
         l_header_rec := oe_order_pub.g_miss_header_rec;
         l_header_rec.operation := oe_globals.g_opr_create;  
         L_HEADER_REC.header_id := ln_header_id;
         L_HEADER_REC.ORDER_SOURCE_ID := REC_STAGE_HEADER_DATA.ORDER_SOURCE_ID;
         l_header_rec.org_id := ln_org_id; 
         l_header_rec.orig_sys_document_ref := rec_stage_header_data.customer_po_number;
         l_header_rec.ordered_date := SYSDATE; 
         L_HEADER_REC.ORDER_TYPE_ID := REC_STAGE_HEADER_DATA.HDR_TRX_TYPE_ID;
         L_HEADER_REC.CUST_PO_NUMBER := REC_STAGE_HEADER_DATA.CUSTOMER_PO_NUMBER;
         --l_header_rec.ship_from_org_id := ln_ship_from_org_id;  --rec_stage_header_data.line_ship_from_org;
         L_HEADER_REC.INVOICE_TO_ORG_ID := REC_STAGE_HEADER_DATA.BILL_TO_ORG_ID;
         L_HEADER_REC.SOLD_TO_ORG_ID := REC_STAGE_HEADER_DATA.HDR_SOLD_TO_ORG_ID;
         L_HEADER_REC.SOLD_FROM_ORG_ID := LN_ORG_ID; 
         IF REC_STAGE_HEADER_DATA.CURRENCY IS NOT NULL        -- Added by Sankalpa on 17-mar-2021 for Project Revival defect OSSATSTING-21988
         THEN
          L_HEADER_REC.TRANSACTIONAL_CURR_CODE := REC_STAGE_HEADER_DATA.CURRENCY;  
         END IF;

         FOR rec_stage_line_data IN cur_stage_line_data (pi_cust_po_number      => rec_stage_header_data.customer_po_number,
                                                         pi_org_name          => rec_stage_header_data.org_name,
                                                         pi_batch_id          => gn_batch_id_num)
         LOOP                        
            fnd_file.put_line (fnd_file.LOG, 'customer po: ' || rec_stage_header_data.customer_po_number ||' customer item: '||rec_stage_line_data.customer_item_name);
            LN_SBC_PRICE := GET_SBC_PRICE(REC_STAGE_HEADER_DATA.BILL_TO_ORG_ID, 
                                          REC_STAGE_LINE_DATA.CUSTOMER_ITEM_NAME);
            --LN_LINE_ID := oe_order_lines_s.nextval;                                    
            LN_LINE_TBL_INDEX := LN_LINE_TBL_INDEX + 1;          
            L_LINE_TBL (LN_LINE_TBL_INDEX) := OE_ORDER_PUB.G_MISS_LINE_REC;
            l_line_tbl (ln_line_tbl_index).operation := oe_globals.g_opr_create;
            l_line_tbl (ln_line_tbl_index).order_source_id := rec_stage_line_data.order_source_id;            
            l_line_tbl (ln_line_tbl_index).inventory_item_id := rec_stage_line_data.inventory_item_id;
            l_line_tbl (ln_line_tbl_index).ordered_item := rec_stage_line_data.customer_item_name;
            L_LINE_TBL (LN_LINE_TBL_INDEX).ITEM_IDENTIFIER_TYPE := 'OSSA SALES CODE';            
            --l_line_tbl (ln_line_tbl_index).line_id := LN_LINE_ID;
            L_LINE_TBL (LN_LINE_TBL_INDEX).LINE_TYPE_ID := REC_STAGE_LINE_DATA.LINE_TRX_TYPE_ID;
            L_LINE_TBL (LN_LINE_TBL_INDEX).ORDERED_QUANTITY := REC_STAGE_LINE_DATA.ORDERED_QUANTITY;   
            L_LINE_TBL (LN_LINE_TBL_INDEX).ORDER_QUANTITY_UOM :='Ea';          
            L_LINE_TBL (LN_LINE_TBL_INDEX).UNIT_LIST_PRICE := LN_SBC_PRICE;  --rec_stage_line_data.unit_price;
            L_LINE_TBL (LN_LINE_TBL_INDEX).UNIT_SELLING_PRICE := LN_SBC_PRICE;  --rec_stage_line_data.unit_price;
            --l_line_tbl (ln_line_tbl_index).cust_po_number := rec_stage_header_data.customer_po_number; -- Commented by Sankalpa on 24-Mar-2021 for defect OSSATSTING-21988 Project Revival
            l_line_tbl (ln_line_tbl_index).schedule_ship_date := SYSDATE; 
            l_line_tbl (ln_line_tbl_index).promise_date := rec_stage_line_data.promised_date;
            L_LINE_TBL (LN_LINE_TBL_INDEX).REQUEST_DATE := NVL (REC_STAGE_LINE_DATA.REQUEST_DATE, sysdate);            
            --l_line_tbl (ln_line_tbl_index).request_id := rec_stage_line_data.request_id;          
            l_line_tbl (ln_line_tbl_index).context := 'OSSA Orders';
            l_line_tbl (ln_line_tbl_index).attribute19 := rec_stage_line_data.unit_price;          

            /*IF (LN_SBC_PRICE <> NVL(REC_STAGE_LINE_DATA.UNIT_PRICE,LN_SBC_PRICE))  -- Added to show hold details in output
            THEN                         
              fnd_file.put_line (fnd_file.LOG, 'Line ID: ' || LN_LINE_ID); 
              fnd_file.put_line (fnd_file.LOG, 'Header ID: ' || ln_header_id); 
              ln_hold_tbl_index := ln_hold_tbl_index + 1;
              l_action_request_tbl (ln_hold_tbl_index)              := oe_order_pub.g_miss_request_rec;
              l_action_request_tbl (ln_hold_tbl_index).entity_id    := LN_LINE_ID;
              l_action_request_tbl (ln_hold_tbl_index).entity_code  := OE_GLOBALS.G_ENTITY_LINE;
              l_action_request_tbl (ln_hold_tbl_index).request_type := OE_GLOBALS.G_APPLY_HOLD;
              l_action_request_tbl (ln_hold_tbl_index).param1       := ln_hold_id;    -- hold_id 
              l_action_request_tbl (ln_hold_tbl_index).PARAM2       := 'O';   -- indicator that it is an order hold
              l_action_request_tbl (ln_hold_tbl_index).param3       := ln_header_id;  -- Header ID of the order
            END IF;*/
         END LOOP;

         mo_global.set_policy_context ('S', ln_org_id);
         mo_global.set_org_context (ln_org_id, NULL, 'ONT');
         FND_GLOBAL.APPS_INITIALIZE (USER_ID           => fnd_profile.VALUE ('USER_ID'),
                                     resp_id           => fnd_profile.VALUE ('RESP_ID'),
                                     resp_appl_id      => fnd_profile.VALUE ('RESP_APPL_ID'));                         
         -- // CALL TO PROCESS ORDER         
         oe_order_pub.process_order (p_api_version_number          => 1.0,
                                     p_init_msg_list               => fnd_api.g_false,
                                     p_return_values               => fnd_api.g_false,
                                     p_action_commit               => fnd_api.g_false,
                                     x_return_status               => lv_return_status,
                                     x_msg_count                   => ln_msg_count,
                                     x_msg_data                    => lv_msg_data,
                                     p_header_rec                  => l_header_rec,
                                     P_LINE_TBL                    => L_LINE_TBL,
                                     p_Line_Adj_tbl                => L_LINE_ADJ_TBL,
                                     p_action_request_tbl          => l_action_request_tbl,
                                     x_header_rec                  => x_header_rec,
                                     x_header_val_rec              => x_header_val_rec,
                                     x_header_adj_tbl              => x_header_adj_tbl,
                                     x_header_adj_val_tbl          => x_header_adj_val_tbl,
                                     x_header_price_att_tbl        => x_header_price_att_tbl,
                                     x_header_adj_att_tbl          => x_header_adj_att_tbl,
                                     x_header_adj_assoc_tbl        => x_header_adj_assoc_tbl,
                                     x_header_scredit_tbl          => x_header_scredit_tbl,
                                     x_header_scredit_val_tbl      => x_header_scredit_val_tbl,
                                     x_line_tbl                    => x_line_tbl,
                                     x_line_val_tbl                => x_line_val_tbl,
                                     x_line_adj_tbl                => x_line_adj_tbl,
                                     x_line_adj_val_tbl            => x_line_adj_val_tbl,
                                     x_line_price_att_tbl          => x_line_price_att_tbl,
                                     x_line_adj_att_tbl            => x_line_adj_att_tbl,
                                     x_line_adj_assoc_tbl          => x_line_adj_assoc_tbl,
                                     x_line_scredit_tbl            => x_line_scredit_tbl,
                                     x_line_scredit_val_tbl        => x_line_scredit_val_tbl,
                                     x_lot_serial_tbl              => x_lot_serial_tbl,
                                     x_lot_serial_val_tbl          => x_lot_serial_val_tbl,
                                     X_ACTION_REQUEST_TBL          => X_ACTION_REQUEST_TBL);

         COMMIT;

         LV_MSG_DATA := NULL;       -- Added by Sankalpa on 24-Mar-2021 for defect OSSATSTING-21988 Project Revival
         ln_msg_index_out:= NULL;   -- Added by Sankalpa on 24-Mar-2021 for defect OSSATSTING-21988 Project Revival

         FOR i IN 1 .. ln_msg_count
          LOOP
             oe_msg_pub.get (p_msg_index          => i,
                             p_encoded            => fnd_api.g_false,
                             P_DATA               => LV_MSG_DATA,
                             p_msg_index_out      => ln_msg_index_out);
             fnd_file.put_line (fnd_file.LOG, '- message is: ' || lv_msg_data);
             FND_FILE.PUT_LINE (FND_FILE.log, '- message index is: ' || LN_MSG_INDEX_OUT);
          END LOOP;

         IF lv_return_status = fnd_api.g_ret_sts_success
         THEN
            fnd_file.put_line (fnd_file.LOG, 'Order created sucessfully: ' || x_header_rec.order_number);
            COMMIT;
            -- Addition start by Sankalpa on 01-Mar-2021 for Project Revival   
            FOR REC_STAGE_APPLY_HOLD IN CUR_STAGE_APPLY_HOLD (PI_ORDER_NUMBER => X_HEADER_REC.ORDER_NUMBER)
            LOOP
               XX_OM_SO_HOLD_CONV_PKG.APPLY_HOLD_API(P_HEADER_ID => REC_STAGE_APPLY_HOLD.header_id,
                                                      P_LINE_ID =>  REC_STAGE_APPLY_HOLD.LINE_ID,
                                                      P_CUST_PO =>  REC_STAGE_APPLY_HOLD.cust_po_number,
                                                      p_ordered_item => REC_STAGE_APPLY_HOLD.ordered_item);

            END LOOP;
            -- Addition end by Sankalpa on 01-Mar-2021 for Project Revival 
            BEGIN
               UPDATE customusr.xx_om_so_hold_conv_stg_tbl
                  SET IMPORT_STATUS = 'IMPORTED',
                      order_number = x_header_rec.order_number,
                      process_flag = 'S',
                      LAST_UPDATE_DATE = sysdate,
                      last_updated_by = fnd_profile.VALUE ('USER_ID')
                WHERE BATCH_ID = GN_BATCH_ID_NUM
                  AND customer_po_number =  rec_stage_header_data.customer_po_number;

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'Error updating batch status in staging table to IMPORTED: '
                                     || lv_procedure
                                     || '; Error => '
                                     || SQLERRM);
                  xx_comn_conv_debug_prc
                                      (p_i_level          => NULL,
                                       p_i_proc_name      => 'submit_sbc_import_program',
                                       p_i_phase          => 'Submit SBC import program',
                                       p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                       p_i_message        =>    'Error updating batch status in staging table to IMPORTED.SQLCODE: '
                                                             || SQLCODE
                                                             || ' SQLERRM :'
                                                             || SUBSTR (SQLERRM, 1, 100));
            END;
         else
            fnd_file.put_line (fnd_file.LOG, 'Order Creation failed for issue: '|| lv_msg_data);
            COMMIT;

            BEGIN
               UPDATE customusr.xx_om_so_hold_conv_stg_tbl
                  SET import_status = 'API_FAILED',
                      process_flag = 'E',
                      line_error_message = lv_msg_data,
                      last_update_date = SYSDATE,
                      last_updated_by = fnd_profile.VALUE ('USER_ID')
                where BATCH_ID = GN_BATCH_ID_NUM
               AND    customer_po_number =  rec_stage_header_data.customer_po_number;

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'Error updating batch status in staging table to API_FAILED: '
                                     || lv_procedure
                                     || '; Error => '
                                     || SQLERRM);
                  xx_comn_conv_debug_prc
                                    (p_i_level          => NULL,
                                     p_i_proc_name      => 'submit_sbc_import_program',
                                     p_i_phase          => 'Submit SBC import program',
                                     p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                     p_i_message        =>    'Error updating batch status in staging table to API_FAILED.SQLCODE: '
                                                           || SQLCODE
                                                           || ' SQLERRM :'
                                                           || SUBSTR (SQLERRM, 1, 100));
            END;
         END IF;          
         l_line_tbl.DELETE ;   -- Added by Sankalpa on 24-Mar-2021 for defect OSSATSTING-21988 Project Revival
      END LOOP;    
   EXCEPTION         
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Fatal error in order creation using API. ' || lv_procedure || '; Error => ' || SQLERRM);
         x_return_status := fnd_api.g_ret_sts_error;
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'submit_sbc_import_program',
                                 p_i_phase          => 'Submit SBC import program',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Error in order creation using API.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         RAISE e_submit_api_error;
   END submit_sbc_import_program;

    /******************************************************
    -- Procedure  to create hold using API --
    *******************************************************/
   PROCEDURE create_hold (
      p_order_number             IN       VARCHAR2)
   IS
      lv_hold_source_rec   oe_holds_pvt.hold_source_rec_type;
      ln_hold_id           NUMBER                            := 0;
      ln_msg_count         NUMBER;
      lv_msg_data          VARCHAR2 (4000);
      ln_header_id         NUMBER;
      lv_order_source      VARCHAR2 (20)                     := 'OSSA Visual ERP';
      lv_return_status     VARCHAR2 (2);
      ln_org_id            NUMBER;
      lv_procedure         VARCHAR2 (100)                    := 'create_hold';
   BEGIN
      -- Initializing APPS envitronment      
      get_org_id ( p_org_id      => ln_org_id );
      mo_global.set_policy_context ('S', ln_org_id);

      -- Get the order imported from order_number
      BEGIN
         SELECT DISTINCT ooha.header_id
         INTO            ln_header_id
         FROM            customusr.xx_om_so_hold_conv_stg_tbl xx,
                         oe_order_headers_all ooha,
                         oe_order_sources oos
         WHERE           ooha.order_source_id = oos.order_source_id
         AND             oos.NAME = lv_order_source
         AND             ooha.orig_sys_document_ref = xx.order_number
         AND             ooha.orig_sys_document_ref = p_order_number
         AND             xx.process_flag = 'S'
         AND             xx.import_status = 'IMPORTED'
         AND             xx.batch_id = NVL (gn_batch_id_num, xx.batch_id);

      EXCEPTION
         WHEN OTHERS
         THEN
            ln_header_id := 0;
            fnd_file.put_line (fnd_file.LOG, 'Too many oracle order obtained for source order: ' || p_order_number);
            xx_comn_conv_debug_prc (p_i_level          => NULL,
                                    p_i_proc_name      => 'create_hold',
                                    p_i_phase          => 'Create Hold',
                                    p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                    p_i_message        =>    'No sales order found to apply hold.SQLCODE: '
                                                          || SQLCODE
                                                          || ' SQLERRM :'
                                                          || SUBSTR (SQLERRM, 1, 100));
            RAISE;
      END;

      -- Get hold definitions
      BEGIN
         SELECT hold_id
         INTO   ln_hold_id
         FROM   oe_hold_definitions
         WHERE  NAME = 'ORDER - GENERIC HOLD'
         AND    TRUNC (SYSDATE) BETWEEN TRUNC (NVL (start_date_active, SYSDATE)) AND TRUNC (NVL (end_date_active,
                                                                                                 SYSDATE + 1));
      EXCEPTION
         WHEN OTHERS
         THEN
            ln_hold_id := 0;
            xx_comn_conv_debug_prc (p_i_level          => NULL,
                                    p_i_proc_name      => 'create_hold',
                                    p_i_phase          => 'Hold Definition Error',
                                    p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                    p_i_message        =>    'No hold definition found in create_hold.SQLCODE: '
                                                          || SQLCODE
                                                          || ' SQLERRM :'
                                                          || SUBSTR (SQLERRM, 1, 100));
            RAISE;
      END;

      fnd_global.apps_initialize (user_id           => fnd_profile.VALUE ('USER_ID'),
                                  resp_id           => fnd_profile.VALUE ('RESP_ID'),
                                  resp_appl_id      => fnd_profile.VALUE ('RESP_APPL_ID'));  

      -- Setting up hold record values
      lv_hold_source_rec := oe_holds_pvt.g_miss_hold_source_rec;
      lv_hold_source_rec.hold_id := ln_hold_id;
      lv_hold_source_rec.hold_entity_code := 'O';
      lv_hold_source_rec.hold_entity_id := ln_header_id;
      lv_hold_source_rec.header_id := ln_header_id;
      lv_hold_source_rec.hold_comment := 'Hold for VISUAL Sales Order';

      oe_holds_pub.apply_holds (p_api_version          => 1.0,
                                p_init_msg_list        => fnd_api.g_true,
                                p_commit               => fnd_api.g_true,
                                p_hold_source_rec      => lv_hold_source_rec,
                                x_return_status        => lv_return_status,
                                x_msg_count            => ln_msg_count,
                                x_msg_data             => lv_msg_data);
      COMMIT;

      IF lv_return_status = fnd_api.g_ret_sts_success
      THEN         
         fnd_file.put_line (fnd_file.LOG, 'Hold applied successfully on header_id : ' || ln_header_id);

         BEGIN
            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET import_status = 'HOLD_APPLIED',
                   process_flag = 'S',
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
             WHERE batch_id = gn_batch_id_num
            AND    order_number = p_order_number;

            COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Error updating batch status in staging table to HOLD_APPLIED: '
                                  || lv_procedure
                                  || '; Error => '
                                  || SQLERRM);
               xx_comn_conv_debug_prc
                                  (p_i_level          => NULL,
                                   p_i_proc_name      => 'create_hold',
                                   p_i_phase          => 'Create Hold Status Update',
                                   p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                   p_i_message        =>    'Error updating batch status in staging table to HOLD_APPLIED.SQLCODE: '
                                                         || SQLCODE
                                                         || ' SQLERRM :'
                                                         || SUBSTR (SQLERRM, 1, 100));
         END;
      ELSE         
         fnd_file.put_line (fnd_file.LOG, 'Hold applied unsuccessfully');

         FOR i IN 1 .. ln_msg_count
         LOOP
            lv_msg_data := fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            fnd_file.put_line (fnd_file.LOG, i || '|' || lv_msg_data);
         END LOOP;

         BEGIN
            UPDATE customusr.xx_om_so_hold_conv_stg_tbl
               SET import_status = 'HOLD_FAILED',
                   process_flag = 'E',
                   line_error_message = lv_msg_data,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
             WHERE batch_id = gn_batch_id_num
            AND    order_number = p_order_number;

            COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Error updating batch status in staging table to HOLD_FAILED: '
                                  || lv_procedure
                                  || '; Error => '
                                  || SQLERRM);
               xx_comn_conv_debug_prc
                                   (p_i_level          => NULL,
                                    p_i_proc_name      => 'create_hold',
                                    p_i_phase          => 'Create Hold Status Update',
                                    p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                    p_i_message        =>    'Error updating batch status in staging table to HOLD_FAILED.SQLCODE: '
                                                          || SQLCODE
                                                          || ' SQLERRM :'
                                                          || SUBSTR (SQLERRM, 1, 100));
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'create_hold',
                                 p_i_phase          => 'Create Hold Error',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Fatal Error in create_hold.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 100));
   --p_ret_status := fnd_api.g_ret_sts_error;
   END create_hold;

   /****************************************************************************
    -- Procedure  to create hold using API for other SBC orders price discrepancy--
    ****************************************************************************/
   PROCEDURE APPLY_HOLD_API (
              P_HEADER_ID     IN NUMBER,
              P_LINE_ID       IN NUMBER,            
              P_CUST_PO       IN VARCHAR2,
              p_ordered_item  IN VARCHAR2  )
  IS
    lv_hold_source_rec             apps.oe_holds_pvt.hold_source_rec_type;
    ln_hold_id                     NUMBER                                   := 0;
    ln_msg_count                   NUMBER;
    lv_msg_data                    VARCHAR2 (4000);
    lv_return_status               VARCHAR2 (2);
  BEGIN

    --Step 1. Get the hold id
    BEGIN
      SELECT hold_id
        INTO ln_hold_id
        FROM apps.oe_hold_definitions ohd
      WHERE name = 'PRICE DISCREPANCY HOLD' ;

    EXCEPTION
      WHEN OTHERS THEN
        ln_hold_id := NULL;
    END;

		--Step 2. Setting up hold record values
    IF ln_hold_id IS NOT NULL THEN
      lv_hold_source_rec                  := apps.oe_holds_pvt.g_miss_hold_source_rec;
      lv_hold_source_rec.hold_id          := ln_hold_id;
      lv_hold_source_rec.hold_entity_code := 'O';
      lv_hold_source_rec.hold_entity_id   := p_header_id;
      lv_hold_source_rec.line_id          := p_line_id;
      lv_hold_source_rec.hold_comment     := 'Hold applied for Price Discrepancy';

      --Step 3. Apply Hold
      apps.oe_holds_pub.apply_holds (p_api_version          => 1.0,
                                    p_init_msg_list        => apps.fnd_api.g_true,
                                    p_commit               => apps.fnd_api.g_true,
                                    p_hold_source_rec      => lv_hold_source_rec,
                                    x_return_status        => lv_return_status,
                                    x_msg_count            => ln_msg_count,
                                    x_msg_data             => lv_msg_data);
      COMMIT;

      IF lv_return_status <> apps.fnd_api.g_ret_sts_success
      THEN
         FOR i IN 1 .. ln_msg_count
         LOOP
          lv_msg_data := lv_msg_data || apps.fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
         END LOOP;

         UPDATE CUSTOMUSR.XX_OM_SO_HOLD_CONV_STG_TBL
            SET LINE_ERROR_MESSAGE = LV_MSG_DATA
           WHERE CUSTOMER_PO_NUMBER = P_CUST_PO
             AND INVENTORY_ITEM = P_ORDERED_ITEM
             AND ORDER_SOURCE = 'OSSA Orders';
        COMMIT;
      END IF;
    END IF;  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error
                            (-20002,
                                'Unable to Apply Price Discrepancy Hold.'
                             || p_header_id
                            );
  END apply_hold_api;

/******************************************************
-- Main procedure  to submit custom conversion program --
*******************************************************/
   PROCEDURE main (
      errbuf                     OUT      VARCHAR2,
      retcode                    OUT      VARCHAR2,
      p_run_mode                 IN       VARCHAR2,
      p_source                   IN       VARCHAR2)
   IS
      lv_return_status          VARCHAR2 (40)   := NULL;
      lv_return_message         VARCHAR2 (4000) := NULL;
      lv_ret_status             VARCHAR2 (4)    := NULL;
      lv_import_eligible_flag   VARCHAR2 (4)    := NULL;
      ln_import_cnt             NUMBER          := 0;
      ln_validation_cnt         NUMBER          := 0;
      ln_org_id                 NUMBER          := 0;
      lv_org_name               VARCHAR2 (200)  := NULL;

      CURSOR cur_stage_data (
         p_org_name                 IN       VARCHAR2)
      IS
         SELECT DISTINCT order_number,
                         hold_status,
                         org_name
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           NVL (process_flag, 'N') = 'N'
         AND             org_name = p_org_name
         AND             NVL(order_source,'OSSA Visual ERP') = p_source    -- Changes start by Sankalpa on 30-Jun-2021 for change in data file
		 --AND             order_source =  p_source						   -- Changes end by Sankalpa on 30-Jun-2021 for change in data file
         AND             sold_to_id IS NOT NULL;

      CURSOR cur_imported_data (
         p_org_name                 IN       VARCHAR2)
      IS
         SELECT DISTINCT order_number,
                         hold_status
         FROM            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           process_flag = 'S'
         AND             import_status = 'IMPORTED'
         AND             org_name = p_org_name
         AND             order_source = p_source
         AND             batch_id = gn_batch_id_num;

   BEGIN
      gn_batch_id_num := customusr.xx_om_conv_batch_seq.NEXTVAL;
      fnd_file.put_line (fnd_file.LOG,
                         'Submitting program with mode : ' || p_run_mode || ' and batch_id - ' || gn_batch_id_num);
      ln_org_id := mo_global.get_current_org_id;
      gn_request_id := fnd_global.conc_request_id ; 

      --fnd_file.put_line (fnd_file.LOG,'organization_id : ' || ln_org_id );

      BEGIN
         SELECT NAME
         INTO   lv_org_name
         FROM   hr_operating_units
         WHERE  organization_id = ln_org_id;

         fnd_file.put_line (fnd_file.LOG, 'Submitting program for OU : ' || lv_org_name);
      EXCEPTION
         WHEN OTHERS
         THEN
            lv_org_name := NULL;
            RAISE e_operating_unit_error;
      END;

      FOR rec_stage_data IN cur_stage_data (p_org_name => lv_org_name)
      LOOP
         -- Update header_val_flag and line_val_flag to 'N'
         UPDATE customusr.xx_om_so_hold_conv_stg_tbl
            SET process_flag = 'N',
                header_val_flag = 'N',
                line_val_flag = 'N',
                batch_id = gn_batch_id_num,
                creation_date = SYSDATE,
                order_source = p_source,
                request_id = fnd_global.conc_request_id,				-- Added by Sankalpa on 30-Jun-2021 for Project Revival
                created_by = fnd_profile.VALUE ('USER_ID'),
                last_updated_by = fnd_profile.VALUE ('USER_ID'),
                last_update_date = SYSDATE
          WHERE NVL (process_flag, 'N') = 'N'
         AND    batch_id IS NULL
         AND    org_name = rec_stage_data.org_name
         AND    order_number = rec_stage_data.order_number;

         fnd_file.put_line (fnd_file.LOG, 'Validating Order header....');
         validate_order_header (p_order_number => rec_stage_data.order_number, 
                                p_org_name => rec_stage_data.org_name, 
                                p_order_source => p_source);
         fnd_file.put_line (fnd_file.LOG, 'Validating Order line....');
         validate_order_line (p_order_number => rec_stage_data.order_number, 
                              p_org_name => rec_stage_data.org_name, 
                              p_order_source => p_source);
      END LOOP;

      IF UPPER (p_run_mode) = 'TRANSFER'   --'IMPORT'
      THEN
         BEGIN
            ln_validation_cnt := 0;

            SELECT COUNT (DISTINCT order_number)
            INTO   ln_validation_cnt
            FROM   customusr.xx_om_so_hold_conv_stg_tbl x1
            WHERE  x1.batch_id = gn_batch_id_num
            AND    x1.process_flag = 'V'
            AND    x1.header_val_flag = 'V'
            AND    x1.line_val_flag = 'V'
            AND    org_name = lv_org_name
            AND    NOT EXISTS (SELECT '1'
                               FROM   customusr.xx_om_so_hold_conv_stg_tbl x2
                               WHERE  x1.order_number = x2.order_number
                               AND    org_name = lv_org_name
                               AND    x2.process_flag = 'E');
         END;

         IF (ln_validation_cnt > 0)
         THEN
            submit_import_program (p_batch_id => gn_batch_id_num, p_source => p_source,p_org_name => lv_org_name);
         ELSE
            fnd_file.put_line (fnd_file.LOG, 'No valid VISUAL order to import');
            --RAISE e_validation_warn;		-- Commented by Sankalpa on 30-Jun-2021 for Project Revival
         END IF;

         IF p_source = 'OSSA Visual ERP'
         THEN
             FOR rec_imported_data IN cur_imported_data (p_org_name => lv_org_name)
             LOOP
                -- Apply hold on sales order hold where hold_status flag = 'Y' using API
                IF (rec_imported_data.hold_status = 'Y')
                THEN
                   fnd_file.put_line (fnd_file.LOG, 'Calling HOLD API for VISUAL order - ' || rec_imported_data.order_number);
                   create_hold (p_order_number => rec_imported_data.order_number);
                END IF;
             END LOOP;
         END IF;    
      END IF;

      fnd_file.put_line (fnd_file.LOG, 'Generating Summary Report.....');
      intf_summary_report (p_org_name => lv_org_name, p_order_source => p_source, p_return_status => retcode);
   EXCEPTION
      WHEN e_operating_unit_error
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Opearting Unit derivation error. SQLERRM: '||SUBSTR(SQLERRM,1,255));
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'Validation Exception Error',
                                 p_i_phase          => 'Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        => 'Validation error in header/line level.');
         retcode := 1;     
      WHEN e_validation_warn
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'Validation Exception Error',
                                 p_i_phase          => 'Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        => 'Validation error in header/line level.');
         retcode := 1;
      WHEN e_submit_api_error
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'Submit Import Program Error',
                                 p_i_phase          => 'Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        => 'oe_order_pub.process_order API submission error.');
         retcode := 2;
      WHEN OTHERS
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'Sales Order Main Program',
                                 p_i_phase          => 'Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Error in Main.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         retcode := 2;
   END main;

   /*************************************************************************
    -- Main procedure  to submit custom conversion program for other SBC's--
    *****************************************************************************/
   PROCEDURE sbc_main (
      errbuf                     OUT      VARCHAR2,
      retcode                    OUT      VARCHAR2,
      p_run_mode                 IN       VARCHAR2,
      p_source                   IN       VARCHAR2,
      p_ou                       IN       VARCHAR2,
      p_customer_acc             IN       VARCHAR2)
   IS
      lv_return_status          VARCHAR2 (40)   := NULL;
      lv_return_message         VARCHAR2 (4000) := NULL;
      lv_ret_status             VARCHAR2 (4)    := NULL;
      lv_import_eligible_flag   VARCHAR2 (4)    := NULL;
      ln_import_cnt             NUMBER          := 0;
      ln_validation_cnt         NUMBER          := 0;
      ln_org_id                 NUMBER          := 0;
      lv_org_name               varchar2 (200)  := null;
      ln_cust_account_id        number;
      lv_party_name             varchar2(240);

      CURSOR cur_stage_data (
         p_org_name                 in       varchar2,
         p_customer_name            in       varchar2)
      IS
         SELECT DISTINCT customer_po_number,
                         --hold_status,
                         org_name
         from            customusr.xx_om_so_hold_conv_stg_tbl
         WHERE           NVL (PROCESS_FLAG, 'N') = 'N'
         and             org_name = p_org_name 
         AND             SOLD_TO_ID IS NULL
         and             batch_id = gn_batch_id_num;       

   BEGIN
      gn_batch_id_num := customusr.xx_om_conv_batch_seq.nextval;
      gn_request_id := fnd_global.conc_request_id ;
      fnd_file.put_line (fnd_file.LOG,
                         'Submitting SBC program with mode : ' || p_run_mode || ' and batch_id - ' || gn_batch_id_num);
      --ln_org_id := fnd_profile.VALUE ('ORG_ID');
      lv_org_name := p_ou;

      BEGIN
         SELECT organization_id
         INTO   ln_org_id
         FROM   hr_operating_units
         WHERE  name = lv_org_name;

         fnd_file.put_line (fnd_file.LOG, 'Submitting import program for org id : ' || ln_org_id);
      EXCEPTION
         WHEN OTHERS
         THEN
            ln_org_id := NULL;
            RAISE e_operating_unit_error;
      end;

      begin
         select hps.party_name,
                hca.cust_account_id
         into   lv_party_name,
                ln_cust_account_id    
         from   hz_cust_accounts hca,
                hz_parties hps
         where  hca.account_number = p_customer_acc
           and  hca.party_id = hps.party_id;

         --fnd_file.put_line (fnd_file.LOG, 'Submitting import program for party : ' || lv_party_name);
      EXCEPTION
         WHEN OTHERS
         THEN
            lv_party_name := null;
            ln_cust_account_id := null;
            raise e_validation_warn;
      END;

      -- Update header_val_flag and line_val_flag to 'N'
         UPDATE customusr.xx_om_so_hold_conv_stg_tbl
            SET process_flag = 'N',
                header_val_flag = 'N',
                LINE_VAL_FLAG = 'N', 
                org_name = p_ou,
                order_source = p_source,
                batch_id = gn_batch_id_num,
                creation_date = SYSDATE,
                created_by = fnd_profile.VALUE ('USER_ID'),
                last_updated_by = fnd_profile.VALUE ('USER_ID'),
                last_update_date = SYSDATE
          WHERE NVL (process_flag, 'N') = 'N'
          AND   BATCH_ID IS NULL
          AND   CUSTOMER_NAME = LV_PARTY_NAME
          --and   customer_number = p_customer_acc
          and   org_name IS NULL
          AND   sold_to_id IS NULL;

      for rec_stage_data in cur_stage_data (p_org_name => p_ou, p_customer_name => lv_party_name)
      LOOP

         --fnd_file.put_line (fnd_file.LOG, 'Validating SBC Order header for customer po: '||rec_stage_data.customer_po_number);
         validate_sbc_order_header (p_source => p_source, 
                                P_ORG_NAME => P_OU, 
                                p_customer_acc => p_customer_acc,
                                P_CUSTOMER_PO_NUMBER => REC_STAGE_DATA.CUSTOMER_PO_NUMBER);
         --fnd_file.put_line (fnd_file.LOG, 'Validating SBC Order line for customer po: '||rec_stage_data.customer_po_number);
         validate_sbc_order_line ( p_org_name => p_ou, 
                                   p_customer_acc => p_customer_acc,
                                   p_order_source => p_source,
                                   p_customer_po_number => rec_stage_data.customer_po_number);
      END LOOP;

      IF UPPER (p_run_mode) = 'TRANSFER' 
      THEN
         BEGIN
            ln_validation_cnt := 0;

            SELECT COUNT (DISTINCT customer_po_number)
            INTO   ln_validation_cnt
            FROM   customusr.xx_om_so_hold_conv_stg_tbl x1
            WHERE  x1.batch_id = gn_batch_id_num
            AND    x1.process_flag = 'V'
            AND    x1.header_val_flag = 'V'
            AND    x1.line_val_flag = 'V'
            AND    org_name = p_ou
            AND    NOT EXISTS (SELECT '1'
                               FROM   customusr.xx_om_so_hold_conv_stg_tbl x2
                               WHERE  x1.customer_po_number = x2.customer_po_number
                               AND    x2.batch_id = gn_batch_id_num
                               AND    org_name = p_ou
                               AND    x2.process_flag = 'E');
         end;
         fnd_file.put_line (fnd_file.log, 'ln_validation_cnt for SBC Order - '||ln_validation_cnt);  
         IF (ln_validation_cnt > 0)
         then
            submit_sbc_import_program (p_batch_id => gn_batch_id_num, p_source => p_source,p_org_name => p_ou);
         ELSE
            fnd_file.put_line (fnd_file.log, 'No valid SBC order to import');
            --RAISE e_validation_warn;
         END IF;
      END IF;

      fnd_file.put_line (fnd_file.log, 'Generating Summary Report.....');
      intf_sbc_summary_report (p_org_name => p_ou, p_order_source => p_source, p_return_status => retcode);
   EXCEPTION
      WHEN e_operating_unit_error
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Opearting Unit derivation error. SQLERRM: '||SUBSTR(SQLERRM,1,255));
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'Validation Exception Error',
                                 p_i_phase          => 'Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        => 'Validation error in header/line level.');
         retcode := 1;         
      WHEN e_validation_warn
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'Validation Exception Error',
                                 p_i_phase          => 'SBC Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        => 'Validation error in SBC Order header/line level.');
         retcode := 1;
      WHEN e_submit_api_error
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'Submit Import Program Error',
                                 p_i_phase          => 'SBC Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        => 'oe_order_pub.process_order API submission error.');
         retcode := 2;
      WHEN OTHERS
      THEN
         xx_comn_conv_debug_prc (p_i_level          => NULL,
                                 p_i_proc_name      => 'SBC Sales Order Main Program',
                                 p_i_phase          => 'SBC Main procedure',
                                 p_i_stgtable       => 'XX_OM_SO_HOLD_CONV_STG_TBL',
                                 p_i_message        =>    'Error in SBC Main.SQLCODE: '
                                                       || SQLCODE
                                                       || ' SQLERRM :'
                                                       || SUBSTR (SQLERRM, 1, 100));
         retcode := 2;
   END SBC_MAIN;
END xx_om_so_hold_conv_pkg;
/