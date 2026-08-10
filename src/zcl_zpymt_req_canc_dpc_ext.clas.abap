  METHOD check_open_items.
    DATA:
      go_appl_log      TYPE REF TO zcl_appln_log_hndlr,
      go_pymt_req_canc TYPE REF TO zcl_pymt_req_canc,
      lv_msgv1         TYPE symsgv,
      lv_msgv2         TYPE symsgv,
      lv_msgv3         TYPE symsgv,
      lv_msgv4         TYPE symsgv,
      ls_msg           TYPE bus0msg1,
      lt_msg           TYPE STANDARD TABLE OF bus0msg1,
      lt_msg1          TYPE STANDARD TABLE OF bus0msg1,
      lv_payt_ref      TYPE zz_payt_ref,
      lv_augst         TYPE augst,
      lv_opbel         TYPE opbel_kk,
      lv_blart         TYPE blart,
      lv_gpart         TYPE gpart_kk,
      lv_vtref         TYPE vtref_kk,
      lt_dfkkop        TYPE TABLE OF zst_open_items,
      lt_but000        TYPE TABLE OF ty_but000,
      lv_ext_no        TYPE balnrext,
      go_pay_req_post  TYPE REF TO zcl_payment_request_post,
      er_deep_entity1  TYPE zcl_zpymt_req_canc_mpc_ext=>ty_paymt_cancel,
      lt_request       TYPE tt_request,
      ls_request       TYPE ty_request.

    DATA: e_opbel TYPE opbel_kk,
          e_stodt TYPE budat_kk,
          e_budat TYPE budat_kk,
          e_bldat TYPE bldat.

    DATA: lv_fikey   TYPE fikey_kk,
          lv_augrd   TYPE augrd_kk,
          lv_callr   TYPE callr_kk,
          lv_budat   TYPE budat,
          wa_tfk033d TYPE tfk033d,
          lv_herkf   TYPE fkkko-herkf.

    DATA: lt_scpos               TYPE STANDARD TABLE OF svvscpos_b,
          ls_scpos               LIKE LINE OF lt_scpos,
          ls_td_post_detrm       TYPE zcd_s_tran_map,
          ls_td_post_pymet_detrm TYPE zcd_s_pay_method_map,
          ls_open_items          TYPE zst_open_items,
          lv_error               TYPE flag,
          ls_tfk033d             TYPE tfk033d,
          lt_message             TYPE bus0msg1_t,
          e_vvscpos              TYPE TABLE OF vvscpos,
          e_vvscitem             TYPE TABLE OF  vvscitem,
          ls_message             TYPE bus0msg1,
          lv_counter             TYPE zcd_int_cnt_de,
          lv_subcounter          TYPE zcd_item_no_de,
          lv_guid                TYPE guid_16.

    DATA: lv_rev_flag     TYPE flag,
          lv_canc_flag    TYPE flag,
          lv_cler_flag    TYPE flag,
          lv_arch_flag    TYPE flag,
          lv_orci_flag    TYPE flag,
          lv_vvscpos_flg  TYPE flag,
          lv_invalid_flag TYPE flag,
          lv_status       TYPE char20, "PL4N363 IEPA-13962
          lv_msgcode      TYPE char12, "char4, "PL4N363 IEPA-13962
          lv_msg_text     TYPE bu_natxtlng. "PL4N363 IEPA-13962.

    CONSTANTS: lc_u        TYPE char1 VALUE 'U',
               lc_msgid    TYPE symsgid VALUE 'ZCD_PAYC',
               lc_s        TYPE char1 VALUE 'S',
               lc_x        TYPE char1 VALUE 'X',
               lc_space    TYPE c VALUE ' ',  "Open Item
               lc_9        TYPE c VALUE '9',  "Cleared Item
               lc_obj      TYPE balobj_d VALUE 'ZPAYC',
               lc_subobj   TYPE balsubobj VALUE 'ZPAYC_SUB',
               lc_orci     TYPE char4 VALUE 'ORCI',
               lc_error    TYPE zz_status VALUE 'ERROR',
               lc_success  TYPE zz_status VALUE 'SUCCESS',
               lc_201(3)   TYPE c VALUE '201',
               lc_500(3)   TYPE c VALUE '500',
               lc_wire(3)  TYPE c VALUE 'WIR',
               lc_ewire(1) TYPE c VALUE 'E',
               lc_chk(3)   TYPE c VALUE 'CHK',
               lc_cchk(1)  TYPE  c VALUE 'C',
               lc_c(1)     TYPE c VALUE 'C', "PL4N363 IEPA-13962
               lc_pclm(4)  TYPE c VALUE 'PCLM',
               lc_arl(3)   TYPE c VALUE 'ARL',
               lc_prc(3)   TYPE c VALUE 'PRC',
               lc_csv(3)   TYPE c VALUE 'CSV',
               lc_049      TYPE symsgno VALUE '049',
               lc_021      TYPE symsgno VALUE '021'.

    DATA: r_source        TYPE RANGE OF zz_source,
          gs_source       LIKE LINE OF r_source,
          r_bukrs         TYPE RANGE OF bukrs,
          gs_bukrs        LIKE LINE OF r_bukrs,
          r_refno         TYPE RANGE OF doc1r_pay,
          gs_refno        LIKE LINE OF r_refno,
          r_pymet         TYPE RANGE OF pymet_kk,
          gs_pymet        LIKE LINE OF r_pymet,
          r_finid         TYPE RANGE OF zzfin_tran_num,
          gs_finid        LIKE LINE OF r_finid,
          r_extid         TYPE RANGE OF zzextrl_ref_id,
          gs_extid        LIKE LINE OF r_extid,
          r_invnum        TYPE RANGE OF zzinvoice_num,
          r_partner       TYPE RANGE OF bu_partner,       " Added by PL6U195 - 09/17/2025 ORCI Canc API
          gs_invnum       LIKE LINE OF r_invnum,
          r_lifeco        TYPE RANGE OF zz_source,
          gs_lifco        LIKE LINE OF r_lifeco,
          lv_sec_procid   TYPE zzproc_id,         "by PL5L317 on 12032024
          lv_subsq_procid TYPE zzproc_id.

    TRY.
        CALL METHOD io_data_provider->read_entry_data
          IMPORTING
            es_data = er_deep_entity1.

      CATCH /iwbep/cx_mgw_busi_exception.
      CATCH /iwbep/cx_mgw_tech_exception . "ATC check issue fix
    ENDTRY.

    READ TABLE er_deep_entity1-paymentcancelitem INTO DATA(ls_lock_request) INDEX 1.
    IF sy-subrc EQ 0.
*Begin of changes - IEPA-29368 TR DV1K902673
      CALL FUNCTION 'ENQUEUE_EZ_FINID'
        EXPORTING
          origin          = ls_lock_request-zz_source
          zz_fin_tran_num = ls_lock_request-zz_fin_tran_num
        EXCEPTIONS
          foreign_lock    = 1
          system_failure  = 2
          OTHERS          = 3.
      IF sy-subrc <> 0.
        go_appl_log = zcl_appln_log_hndlr=>get_instance( ).
        go_pymt_req_canc = zcl_pymt_req_canc=>get_instance( ).
        go_appl_log->log_create( iv_object    = lc_obj
                                 iv_subobject = lc_subobj
                                 iv_extno     = lv_ext_no
                                          ).
        go_appl_log->message_add( VALUE bal_t_msg( ( msgid = |{ lc_msgid }|
                                                     msgno = |000|
                                                     msgv1 = |User:{ sy-uname }|
                                                     msgv2 = |Date:{ sy-datlo }|
                                                     msgv3 = |Time:{ sy-timlo }| ) ) ).
        go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                      msgno  = '008'
                                                      msgv1  = lv_msgv1
                                            IMPORTING es_msg = ls_msg ).

        go_appl_log->message_add( VALUE bal_t_msg( (  msgty = |{ 'E' }| msgid = |{ lc_msgid }| msgno = |207| msgv1 = |{ ls_lock_request-zz_fin_tran_num }| ) ) ).
        go_appl_log->log_save( ).
        er_deep_entity-response = VALUE #( BASE er_deep_entity-response
                                   (
                                   zz_source       = ls_lock_request-zz_source
                                   zz_fin_tran_num = ls_lock_request-zz_fin_tran_num
                                   zz_req_stat     = 'FAILED'
                                   msg_type        = 'E'
                                   msg_code        = 'ZCD_COLL_PAYR'
                                   msg_desc        = |Payment Request { ls_lock_request-zz_fin_tran_num } is currently processing, retry cancellation after sometime.| ) ).
        RETURN.
      ELSE.
*End of changes - IEPA-29368 TR DV1K902673

*       BUG 3 FIX: Removed redundant READ TABLE INDEX 1 into ls_pymnt — ls_lock_request
*       already holds INDEX 1 data from the read above. All ls_pymnt references below
*       replaced with ls_lock_request.

        " Get entries from Maintenance Table for Payment Request Cancellation
        SELECT zzsource,
               zz_retrl_ind,
               bukrs,
               zz_fin_tran_num,
               zz_invoice_num,
               zz_pymet,
               zz_extrl_ref_id,
               doc1r,
               zz_init_procid,
               zz_sec_procid,
               zz_subsq_procid
          FROM zcd_py_canc_parm
           INTO TABLE @DATA(lt_param)
          WHERE zzsource = @ls_lock_request-zz_source.
        " AND zz_retrl_ind NE @space. - Commented on 09/23/2025 PL6U195
        IF sy-subrc = 0.
          SORT lt_param BY zzsource zz_retrl_ind.

          SELECT SINGLE @abap_true
           FROM zcd_paym_req_log
           INTO @DATA(lv_req_log1)
           WHERE origin = @ls_lock_request-zz_source
             AND zz_fin_tran_num = @ls_lock_request-zz_fin_tran_num
             AND zz_status = @gc_succ. "@gc_success. " added by Pl6U195 on 11/10/2025
             " gc_succ = 'SUCCESS' confirmed — matches DB values

*         BUG 1 FIX: lv_req_log1 was selected but never checked, silently disabling
*         the duplicate guard. Now properly used to reject already-processed requests.
          IF lv_req_log1 = abap_true.
            go_appl_log = zcl_appln_log_hndlr=>get_instance( ).
            go_appl_log->log_create( iv_object    = lc_obj
                                     iv_subobject = lc_subobj
                                     iv_extno     = ls_lock_request-zz_fin_tran_num ).
            go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |E|
                                                         msgid = |{ lc_msgid }|
                                                         msgno = |207|
                                                         msgv1 = |{ ls_lock_request-zz_fin_tran_num }| ) ) ).
            go_appl_log->log_save( ).
            er_deep_entity-response = VALUE #( BASE er_deep_entity-response
                                       ( zz_source       = ls_lock_request-zz_source
                                         zz_fin_tran_num = ls_lock_request-zz_fin_tran_num
                                         zz_req_stat     = 'FAILED'
                                         msg_type        = 'E'
                                         msg_code        = 'ZCD_COLL_PAYR'
                                         msg_desc        = |Payment Request { ls_lock_request-zz_fin_tran_num } was already successfully processed, duplicate request.| ) ).
            CALL FUNCTION 'DEQUEUE_EZ_FINID'
              EXPORTING
                origin          = ls_lock_request-zz_source
                zz_fin_tran_num = ls_lock_request-zz_fin_tran_num.
            RETURN.
          ENDIF.

        ENDIF.

        "Application log create
        go_appl_log = zcl_appln_log_hndlr=>get_instance( ).
        go_pymt_req_canc = zcl_pymt_req_canc=>get_instance( ).

        DATA(lv_crdat) = sy-datlo.
        DATA(lv_crtime) = sy-timlo.

        LOOP AT er_deep_entity1-paymentcancelitem INTO DATA(ls_pymt_canc).

          DATA(lv_index) = sy-tabix.
          lv_payt_ref = ls_pymt_canc-doc1r.
          lv_ext_no = ls_pymt_canc-zz_fin_tran_num.
          ls_msg-msgty = gc_e.
          go_appl_log->log_create( iv_object    = lc_obj
                                   iv_subobject = lc_subobj
                                   iv_extno     = lv_ext_no
                                   ).
          go_appl_log->message_add( VALUE bal_t_msg( ( msgid = |{ lc_msgid }|
                                                       msgno = |000|
                                                       msgv1 = |User:{ sy-uname }|
                                                       msgv2 = |Date:{ sy-datlo }|
                                                       msgv3 = |Time:{ sy-timlo }| ) ) ).

          READ TABLE lt_param INTO DATA(ls_param) WITH KEY zzsource = ls_pymt_canc-zz_source
                                                           zz_retrl_ind = ls_pymt_canc-zz_retrl_ind
                                                           BINARY SEARCH.
**IF ARL fails then go with MRL subsqprocid.
          IF sy-subrc EQ 0.
            lv_sec_procid = ls_param-zz_sec_procid.
            lv_subsq_procid = ls_param-zz_subsq_procid.

          ELSE. "Invalid req
            ls_msg-msgty = gc_e.
            lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.

            go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                          msgno  = '008'
                                                          msgv1  = lv_msgv1
                                                IMPORTING es_msg = ls_msg ).

            go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |008| msgv1  = |{ lv_msgv1 }| ) ) ).
            APPEND ls_msg TO lt_msg.
            go_appl_log->log_save( ).
            lv_invalid_flag = gc_x.
          ENDIF.

          IF lt_msg[] IS INITIAL.

            IF ls_pymt_canc-zz_fin_tran_num IS NOT INITIAL.

              SELECT SINGLE pymet,
                            augbl,
                            augst
                       FROM dfkkop
              INTO @DATA(ls_dfkkop_chk)
                   WHERE zzsource = @ls_pymt_canc-zz_source
                     AND zz_fin_tran_num = @ls_pymt_canc-zz_fin_tran_num. "#EC CI_NOFIELD

              IF sy-subrc EQ 0.

                DATA(lv_dfkkop_exist_flag) = abap_true. " Added by Pl6U195 #TR-DS4K904264 09/19/2025
                DATA(lv_doc1r) = ls_dfkkop_chk-augbl.

                IF ls_dfkkop_chk-pymet = lc_c. "Check Stop
                  DATA(lv_chkstop) = gc_x.
                ELSE.
                  DATA(lv_ach_ret) = gc_x.
                ENDIF.

              ELSEIF ( ls_param-zz_fin_tran_num = gc_x AND ls_param-zz_retrl_ind = gc_y ).
                lv_ach_ret = gc_x.

              ENDIF.
            ENDIF.


            IF ls_pymt_canc-zz_source IS INITIAL.

              ls_msg-msgty = gc_e.
              go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                            msgty  = ls_msg-msgty
                                                            msgno  = '009'
                                                  IMPORTING es_msg = ls_msg ).

              APPEND ls_msg TO lt_msg.
              go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                           msgno = |009| ) ) ).
              go_appl_log->log_save( ).
              gc_mandt_flag  = gc_x.
            ELSE.

              "Check source system already exists
              SELECT SINGLE source
                    FROM zcd_source
                INTO @DATA(lv_source)
                WHERE source = @ls_pymt_canc-zz_source.
              IF sy-subrc NE 0.
                lv_msgv1 = ls_pymt_canc-zz_source.
                ls_msg-msgty = gc_e.

                go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                              msgno  = '012'
                                                              msgv1  = lv_msgv1
                                                    IMPORTING es_msg = ls_msg ).


                APPEND ls_msg TO lt_msg.
                go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |012| ) ) ).
                go_appl_log->log_save( ).
                lv_invalid_flag = gc_x.
              ENDIF.
            ENDIF.
          ENDIF. "IEPA-24999

* Fin Trans Id entered with space
          IF lt_msg[] IS INITIAL.

            IF lv_source NE gc_source_orci AND   "lv_source IN r_lifeco AND  " Added by PL6U195 on 07/17/2025
              ls_pymt_canc-zz_fin_tran_num IS INITIAL AND
              ls_param-zz_fin_tran_num = gc_x.

              ls_msg-msgty = gc_e.
              go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                            msgno  = '001'
                                                  IMPORTING es_msg = ls_msg ).
              APPEND ls_msg TO lt_msg.
              go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |001|  ) ) ).
              go_appl_log->log_save( ).
              gc_mandt_flag  = gc_x.

            ELSEIF ls_pymt_canc-zz_fin_tran_num IS INITIAL AND
              ls_param-bukrs = space AND
              ls_param-zz_fin_tran_num = gc_x.

              ls_msg-msgty = gc_e.

              go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                            msgno  = '001'
                                                  IMPORTING es_msg = ls_msg ).


              APPEND ls_msg TO lt_msg.
              go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |001|  ) ) ).
              go_appl_log->log_save( ).
              gc_mandt_flag  = gc_x.
            ENDIF.
          ENDIF.




          IF lt_msg[] IS INITIAL.
*        AND lv_source NE gc_source_orci                                  - commented by Pl6U195 #TR-DS4K904264 09/19/2025
*        AND ls_param-zz_fin_tran_num = gc_x.   "IEPA-14342 by PL5L317    - commented by Pl6U195 #TR-DS4K904264 09/19/2025

* Fin Trans Id Validation.
            IF NOT ls_pymt_canc-zz_fin_tran_num IS INITIAL.

** Update payment request log table
              SELECT SINGLE *
              FROM zcd_paym_req_log
              INTO @DATA(ls_paym_req_log)
              WHERE origin = @ls_pymt_canc-zz_source
              AND zz_fin_tran_num = @ls_pymt_canc-zz_fin_tran_num
              AND zz_status = @gc_succ. "@gc_success.  added by Pl6u195 on 11/10/2025

              IF sy-subrc EQ 0 AND ls_paym_req_log-zz_sap_stage NE gc_s
                AND ls_paym_req_log-zz_payment_request_status NE gc_cancld.
                "Begin of changes by PL7S927 for IEPA-27024
                IF lv_source = gc_pclm AND  ls_paym_req_log-zz_payee_type = 'S'.
                  IF ls_paym_req_log-apil_id IS NOT INITIAL.
                    lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                    lv_msgv2 = ls_paym_req_log-apil_id.
                    go_pymt_req_canc->get_message_text( EXPORTING msgty  = gc_e
                                                                  msgid  = lc_msgid
                                                                  msgno  = '057'
                                                                  msgv1  = lv_msgv1
                                                                  msgv2  = lv_msgv2
                                                        IMPORTING es_msg = ls_msg ).
                    APPEND ls_msg TO lt_msg.

                    go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                                 msgno = |057|      msgv1 = |{ lv_msgv1 }| msgv2 = |{ lv_msgv2 }| ) ) ).

                    DATA(lv_paym_req_cncl) = gc_x.
                  ELSE.
                    IF ( ls_paym_req_log-zzpymet = 'ACH' OR ls_paym_req_log-zzpymet = 'WIR' )
                    AND ls_dfkkop_chk-augst = '9'.
                      lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                      go_pymt_req_canc->get_message_text( EXPORTING msgty  = gc_e
                                                                    msgid  = lc_msgid
                                                                    msgno  = '056'
                                                                    msgv1  = lv_msgv1
                                                          IMPORTING es_msg = ls_msg ).
                      APPEND ls_msg TO lt_msg.

                      go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                                   msgno = |0056|     msgv1 = |{ lv_msgv1 }| ) ) ).

                      lv_paym_req_cncl = gc_x.
                    ENDIF.
                  ENDIF.
                ELSE.
                  "End of changes by PL7S927 for IEPA-27024
                  ls_paym_req_log-zz_payment_request_status = gc_cancld.
                  ls_paym_req_log-zz_sap_stage = gc_x.
                  UPDATE zcd_paym_req_log FROM ls_paym_req_log.

                  lv_paym_req_cncl = gc_x.

                  lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                  go_pymt_req_canc->get_message_text( EXPORTING msgty  = lc_s
                                                                msgid  = lc_msgid
                                                                msgno  = '002'
                                                                msgv1  = lv_msgv1
                                                      IMPORTING es_msg = ls_msg ).
                  APPEND ls_msg TO lt_msg.
                  gc_canc_flag = gc_x.

                  IF lv_source = gc_source_orci. "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                    lv_orci_flag = gc_x.
                  ENDIF.
                ENDIF.        "Changes by PL7S927 for IEPA-27024
              ELSEIF ls_paym_req_log-zz_payment_request_status = gc_cancld.
                lv_status = gc_cancld. " IEPA-26247
                lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                go_pymt_req_canc->get_message_text( EXPORTING msgty  = gc_e
                                                              msgid  = lc_msgid
                                                              msgno  = '004'
                                                              msgv1  = lv_msgv1
                                                    IMPORTING es_msg = ls_msg ).
                APPEND ls_msg TO lt_msg.

                go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                             msgno = |004|      msgv1 = |{ lv_msgv1 }| ) ) ).

                lv_paym_req_cncl = gc_x.

              ELSEIF lv_source = gc_source_orci AND lv_dfkkop_exist_flag = abap_true. "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                " do nothing - as ORCI data sits in dfkkop and no need to check in vvscpos
*Begin of changes by PL7S927 for IEPA-27024 Cancellation API restriction for Domestic Vendor
              ELSEIF lv_source = gc_pclm AND  ls_paym_req_log-zz_payee_type = 'S'.
                IF ls_paym_req_log-apil_id IS NOT INITIAL.
                  lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                  lv_msgv2 = ls_paym_req_log-apil_id.
                  go_pymt_req_canc->get_message_text( EXPORTING msgty  = gc_e
                                                                msgid  = lc_msgid
                                                                msgno  = '057'
                                                                msgv1  = lv_msgv1
                                                                msgv2  = lv_msgv2
                                                      IMPORTING es_msg = ls_msg ).
                  APPEND ls_msg TO lt_msg.

                  go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                               msgno = |057|      msgv1 = |{ lv_msgv1 }| msgv2 = |{ lv_msgv2 }| ) ) ).

                  lv_paym_req_cncl = gc_x.
                ELSE.
                  IF ( ls_paym_req_log-zzpymet = 'ACH' OR ls_paym_req_log-zzpymet = 'WIR' )
                      AND ls_dfkkop_chk-augst = '9'.
                    lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                    go_pymt_req_canc->get_message_text( EXPORTING msgty  = gc_e
                                                                  msgid  = lc_msgid
                                                                  msgno  = '056'
                                                                  msgv1  = lv_msgv1
                                                        IMPORTING es_msg = ls_msg ).
                    APPEND ls_msg TO lt_msg.

                    go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                                 msgno = |056|      msgv1 = |{ lv_msgv1 }| ) ) ).

                    lv_paym_req_cncl = gc_x.
                  ENDIF.
                ENDIF.
*End of changes by PL7S927 for IEPA-27024 Cancellation API restriction for Domestic Vendor

              ELSE.

                SELECT SINGLE zz_fin_tran_num INTO @DATA(lv_fin_trans_no)
                  FROM vvscpos WHERE origin = @lv_source
                                 AND zz_fin_tran_num = @ls_pymt_canc-zz_fin_tran_num.
                IF NOT sy-subrc IS INITIAL.

                  ls_msg-msgty = gc_e.
                  lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.

                  go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                msgno  = '014'
                                                                msgv1  = lv_msgv1
                                                      IMPORTING es_msg = ls_msg ).

                  APPEND ls_msg TO lt_msg.
                  go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |014| msgv1  = |{ lv_msgv1 }| ) ) ).
                  go_appl_log->log_save( ).
                  lv_invalid_flag = gc_x.

                ENDIF.

              ENDIF.
            ENDIF.
          ENDIF.


* Company Code Validation
          IF lt_msg[] IS INITIAL.

            IF NOT ls_pymt_canc-bukrs IS INITIAL.
              SELECT SINGLE bukrs INTO @DATA(lv_bukrs) FROM t001 WHERE bukrs = @ls_pymt_canc-bukrs.
              IF NOT sy-subrc IS INITIAL.
                ls_msg-msgty = gc_e.
                lv_msgv1 = ls_pymt_canc-bukrs.
                go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                              msgno  = '010'
                                                              msgv1  = lv_msgv1
                                                    IMPORTING es_msg = ls_msg ).

                APPEND ls_msg TO lt_msg.
                go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |010| msgv1  = |{ lv_msgv1 }| ) ) ).
                go_appl_log->log_save( ).
                lv_invalid_flag = gc_x.
              ENDIF.
            ELSEIF ls_pymt_canc-bukrs IS INITIAL AND
                   ls_param-bukrs = gc_x.   "IEPA-14342 by PL5L317

              ls_msg-msgty = gc_e.

              go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                            msgty  = ls_msg-msgty
                                                            msgno  = '019'
                                                  IMPORTING es_msg = ls_msg ).

              APPEND ls_msg TO lt_msg.
              go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |019|  ) ) ).
              go_appl_log->log_save( ).
              gc_mandt_flag  = gc_x.
            ENDIF.
          ENDIF.

          IF ls_param-zz_init_procid = lc_prc AND lv_paym_req_cncl EQ space."PL4N363  "Payment request canc.

            IF lt_msg[] IS INITIAL AND lv_source = gc_source_orci.

              " External Ref Id validation
              IF ls_pymt_canc-zz_extrl_ref_id IS INITIAL AND
                 ls_param-zz_extrl_ref_id = gc_x.

                ls_msg-msgty = gc_e.

                go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                              msgty  = ls_msg-msgty
                                                              msgno  = '011'
                                                    IMPORTING es_msg = ls_msg ).
                APPEND ls_msg TO lt_msg.
                go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |011|  ) ) ).
                go_appl_log->log_save( ).
                gc_mandt_flag  = gc_x.

              ELSE.
                "Check External Ref Id already exists
                SELECT SINGLE partner FROM but000
                  INTO @DATA(lv_partner)
                  WHERE bpext  = @ls_pymt_canc-zz_extrl_ref_id
                    AND source = @lv_source.
                IF sy-subrc = 0.
                  r_partner = VALUE #( ( sign = 'I' option = 'EQ' low = lv_partner ) ). "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                ELSE.

                  lv_msgv1 = ls_pymt_canc-zz_extrl_ref_id.
                  ls_msg-msgty = gc_e.

                  go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                msgno  = '016'
                                                                msgv1  = lv_msgv1
                                                      IMPORTING es_msg = ls_msg ).
                  go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |016| msgv1  = |{ lv_msgv1 }| ) ) ).

                  APPEND ls_msg TO lt_msg.
                  go_appl_log->log_save( ).
                  lv_invalid_flag = gc_x.
                ENDIF.

              ENDIF.

* Invoice Number validation
              IF ls_pymt_canc-zz_invoice_num IS INITIAL AND
                 ls_param-zz_invoice_num = gc_x. " IEPA 14342 by PL5L317
                ls_msg-msgty = gc_e.

                go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                              msgty  = ls_msg-msgty
                                                              msgno  = '015'
                                                    IMPORTING es_msg = ls_msg ).
                go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |015| ) ) ).
                APPEND ls_msg TO lt_msg.
                go_appl_log->log_save( ).
                gc_mandt_flag  = gc_x.
              ELSE.
                "Check External Ref Id already exists
                IF lv_dfkkop_exist_flag = abap_true. "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                  SELECT SINGLE zz_invoice_num FROM dfkkop
                    INTO @DATA(lv_invoice_num)
                    WHERE zzsource = @lv_source
                      AND zz_invoice_num = @ls_pymt_canc-zz_invoice_num. "#EC CI_NOFIELD
                  IF sy-subrc NE 0.
                    lv_msgv1 = ls_pymt_canc-zz_invoice_num.
                    ls_msg-msgty = gc_e.

                    go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                  msgno  = '017'
                                                                  msgv1  = lv_msgv1
                                                        IMPORTING es_msg = ls_msg ).
                    go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |017| msgv1  = |{ lv_msgv1 }| ) ) ).
                    APPEND ls_msg TO lt_msg.
                    go_appl_log->log_save( ).
                    lv_invalid_flag = gc_x.
                  ENDIF.
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.

* For Oracle
*      Source system, CoCode, Ext Ref id, Inv Number

          IF lt_msg[] IS INITIAL.

            IF NOT ls_pymt_canc-zz_source IS INITIAL.
              gs_source-sign = gc_sign_i.
              gs_source-option = gc_option_eq.
              gs_source-low = ls_pymt_canc-zz_source.
              APPEND gs_source TO r_source.
            ENDIF.

            IF NOT ls_pymt_canc-bukrs IS INITIAL.
              gs_bukrs-sign = gc_sign_i.
              gs_bukrs-option = gc_option_eq.
              gs_bukrs-low = ls_pymt_canc-bukrs.
              APPEND gs_bukrs TO r_bukrs.
            ENDIF.

            IF NOT ls_pymt_canc-zz_fin_tran_num IS INITIAL.
              gs_finid-sign = gc_sign_i.
              gs_finid-option = gc_option_eq.
              gs_finid-low = ls_pymt_canc-zz_fin_tran_num.
              APPEND gs_finid TO r_finid.
            ENDIF.

            IF NOT ls_pymt_canc-zz_extrl_ref_id IS INITIAL.
              gs_extid-sign = gc_sign_i.
              gs_extid-option = gc_option_eq.
              gs_extid-low = ls_pymt_canc-zz_extrl_ref_id.
              APPEND gs_extid TO r_extid.
            ENDIF.

            IF NOT ls_pymt_canc-doc1r IS INITIAL.
              gs_refno-sign = gc_sign_i.
              gs_refno-option = gc_option_eq.
              gs_refno-low = ls_pymt_canc-doc1r.
              APPEND gs_refno TO r_refno.
            ENDIF.

            IF NOT ls_pymt_canc-zz_pymet IS INITIAL.
              gs_pymet-sign = gc_sign_i.
              gs_pymet-option = gc_option_eq.
              IF ls_pymt_canc-zz_pymet = lc_wire.
                gs_pymet-low = lc_ewire.
              ELSEIF ls_pymt_canc-zz_pymet = lc_chk.
                gs_pymet-low = lc_cchk.
              ENDIF.
*          gs_pymet-low = ls_pymt_canc-zz_pymet.
              APPEND gs_pymet TO r_pymet.
            ENDIF.

            IF NOT ls_pymt_canc-zz_invoice_num IS INITIAL.
              gs_invnum-sign = gc_sign_i.
              gs_invnum-option = gc_option_eq.
              gs_invnum-low = ls_pymt_canc-zz_invoice_num.
              APPEND gs_invnum TO r_invnum.
            ENDIF.


            IF ls_param-zz_init_procid = lc_prc AND lv_paym_req_cncl EQ space."Payment request canc. " PL4N363

              "Check financial transaction id already exists ?
              SELECT SINGLE *
                FROM vvscpos
                INTO @DATA(ls_vvscpos)
                     WHERE archi = @space
                       AND origin = @lv_source
                       AND zz_fin_tran_num = @ls_pymt_canc-zz_fin_tran_num.

              IF sy-subrc NE 0 AND lv_payt_ref IS INITIAL AND
                 ls_pymt_canc-zz_fin_tran_num IS NOT INITIAL AND ls_vvscpos IS INITIAL.

                SELECT
                      opbel,
                      opupw,
                      opupk,
                      opupz,
                      bukrs,
                      augst,
                      gpart,
                      vtref,
                      budat,
                      augbl,
                      augrd,
                      zz_claim_no,
                      zz_ext_ref_id,
                      zz_fin_tran_num
                 FROM dfkkop INTO TABLE @lt_dfkkop
                 WHERE zzsource IN @r_source
                   AND zz_fin_tran_num IN @r_finid      "#EC CI_NOFIELD
                   AND bukrs IN @r_bukrs                   "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                   AND gpart IN @r_partner                 "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                   AND zz_invoice_num IN @r_invnum.        "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                IF sy-subrc = 0.
                  IF lv_source = gc_source_orci. "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                    lv_orci_flag = gc_x.
                  ENDIF.

                  DESCRIBE TABLE lt_dfkkop LINES DATA(lv_lines).
                  IF lv_lines > 1.
                    lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                    ls_msg-msgty = gc_e.

                    go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                  msgno  = '013'
                                                                  msgv1  = lv_msgv1
                                                        IMPORTING es_msg = ls_msg ).

                    APPEND ls_msg TO lt_msg.
                    go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }| msgno = |013| ) ) ).
                    go_appl_log->log_save( ).
                  ENDIF.
                ELSE.
                  lv_status = gc_cancld. " IEPA-26247
                  lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                  ls_msg-msgty = gc_e.
                  CONCATENATE 'Payment Request for the FIN Trans ID:'(006) ls_pymt_canc-zz_fin_tran_num
                  ', does not have an Open Item/Pay Plan Item to reverse'(007) INTO ls_msg-text_ext SEPARATED BY space."was Cancelled-Duplicate Request


                  go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                msgty  = ls_msg-msgty
                                                                msgno  = '004'
                                                                msgv1  = lv_msgv1
                                                      IMPORTING es_msg = ls_msg ).

                  APPEND ls_msg TO lt_msg.
                  go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                               msgno = |004|      msgv1 = |{ lv_msgv1 }| ) ) ).
                  go_appl_log->log_save( ).
                  lv_cler_flag  = gc_x.
                ENDIF.
              ELSE.
                lv_vvscpos_flg = gc_x.
                IF lv_source = gc_source_orci. "  Added by Pl6U195 #TR-DS4K904264 09/19/2025
                  lv_orci_flag = gc_x.
                ENDIF.

              ENDIF.

              IF lt_msg IS INITIAL.
                LOOP AT lt_dfkkop INTO DATA(ls_dfkkop).
* Checking for OPEN Scenario
                  IF ls_dfkkop-augst = space.
                    ls_open_items-opbel = ls_dfkkop-opbel.
                    ls_open_items-opupw = ls_dfkkop-opupw.
                    ls_open_items-opupk = ls_dfkkop-opupk.
                    ls_open_items-opupz = ls_dfkkop-opupz.
                    ls_open_items-bukrs = ls_dfkkop-bukrs.
                    ls_open_items-augst = ls_dfkkop-augst.
                    ls_open_items-gpart = ls_dfkkop-gpart.
                    ls_open_items-vtref = ls_dfkkop-vtref.
                    ls_open_items-budat = ls_dfkkop-budat.
                    ls_open_items-augbl = ls_dfkkop-augbl.
                    ls_open_items-zz_fin_tran_num = ls_dfkkop-zz_fin_tran_num.

                    CALL METHOD me->payment_request_cancelled
                      EXPORTING
                        ls_open_items    = ls_open_items
                        ls_vvscpos       = ls_vvscpos
                        go_appl_log      = go_appl_log
                        go_pymt_req_canc = go_pymt_req_canc
                        iv_orci_flag     = lv_orci_flag
                      IMPORTING
                        et_msg           = lt_msg.
                    lv_rev_flag = gc_x.

* Checking for CLEARED Scenario
                  ELSEIF ls_dfkkop-augst = gc_9     "'9'
                     AND ls_dfkkop-augrd = gc_02.   "'02'.

                    ls_msg-msgty = gc_e.
                    IF lv_orci_flag = gc_x.
                      lv_msgv1 = ls_pymt_canc-zz_invoice_num.
                      go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                    msgno  = '023'
                                                                    msgv1  = lv_msgv1 "'Source System'(001)
                                                          IMPORTING es_msg = ls_msg ).
                      APPEND ls_msg TO lt_msg.
                      go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                                   msgno = |023|      msgv1 = |{ lv_msgv1 }| ) ) ).
                    ELSE.

** Checking the Clearing Document Processed or not
                      SELECT SINGLE zzsource,
                                    zzproc_id,
                                    bukrs,
                                    augbl
                          FROM zcd_ach_rtrv_log
                          INTO @DATA(ls_zcd_ach_rtrv_log)
                          WHERE zzsource IN @r_source
                            AND bukrs IN @r_bukrs
                            AND augbl = @ls_dfkkop-augbl.
                      IF sy-subrc EQ 0.
                        ls_msg-msgty = gc_e.
                        DATA:lv_msg         TYPE symsgv.
                        lv_status = gc_success. " IEPA-26247
                        lv_msg = ls_pymt_canc-zz_fin_tran_num."ls_zcd_ach_rtrv_log-augbl.
                        go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                      msgno  = '033'
                                                                      msgv1  = lv_msg
                                                            IMPORTING es_msg = ls_msg ).
                        go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                                     msgno = |033|      msgv1 = |{ lv_msg }| ) ) ).
                        APPEND ls_msg TO lt_msg.

                      ELSEIF lv_chkstop EQ space. " skip for Checks
                        lv_ach_ret = gc_x.

                      ENDIF.
                    ENDIF.

                    go_appl_log->log_save( ).
                    lv_canc_flag = gc_x.
* Checking for CANCELLED Scenario
                  ELSEIF ls_dfkkop-augst = gc_9     "'9'
                     AND ( ls_dfkkop-augrd = gc_05 OR ls_dfkkop-augrd = gc_45 ).   "'05'.


                    ls_msg-msgty = gc_e.
                    IF lv_orci_flag NE gc_x.
                      lv_status = gc_cancld. " IEPA-26247
                      lv_msgv1 = ls_pymt_canc-zz_fin_tran_num.
                      go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                    msgno  = '004'
                                                                    msgv1  = lv_msgv1
                                                          IMPORTING es_msg = ls_msg ).
                      go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                                   msgno = |004|      msgv1 = |{ lv_msgv1 }| ) ) ).

                    ELSE.
                      lv_status = gc_success. " IEPA-26247
                      lv_msgv1 = ls_pymt_canc-zz_invoice_num.
                      go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                    msgno  = '024'
                                                                    msgv1  = lv_msgv1
                                                          IMPORTING es_msg = ls_msg ).
                      go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }| msgid = |{ lc_msgid }|
                                                                   msgno = |024|      msgv1 = |{ lv_msgv1 }| ) ) ).
                    ENDIF.

                    APPEND ls_msg TO lt_msg.


                    go_appl_log->log_save( ).
                    lv_cler_flag = gc_x.
                  ENDIF.
                  CLEAR: ls_dfkkop, ls_open_items.
                ENDLOOP.


                IF lv_vvscpos_flg = gc_x.
                  CALL METHOD me->payment_request_cancelled
                    EXPORTING
                      ls_open_items    = ls_open_items
                      ls_vvscpos       = ls_vvscpos
                      go_appl_log      = go_appl_log
                      go_pymt_req_canc = go_pymt_req_canc
                    IMPORTING
                      et_msg           = lt_msg.
                  lv_arch_flag = gc_x.

**              Update payment status as cancelled in payment request log table
                  READ TABLE lt_msg INTO DATA(ls_mg1) WITH KEY msgty = gc_e.
                  IF sy-subrc NE 0.

                    IF ls_paym_req_log IS NOT INITIAL.
                      ls_paym_req_log-zz_payment_request_status = gc_cancld.

                      UPDATE zcd_paym_req_log FROM ls_paym_req_log.
                    ENDIF.
                  ENDIF.
                ENDIF.
              ENDIF.
            ENDIF. "PL4N363
          ENDIF. "PL4N363
*      IF ls_param-zz_init_procid = lc_prc." AND lv_paym_req_cncl EQ space. "Payment Canc. "PL4N363
*      Populate Error log table
          IF lt_dfkkop[] IS NOT INITIAL.
            READ TABLE lt_dfkkop INTO ls_dfkkop INDEX 1.
            DATA(lv_claim_no) = ls_dfkkop-zz_claim_no.        " by PL5L317 on 12202024
          ELSEIF ls_vvscpos IS NOT INITIAL.
            lv_claim_no = ls_vvscpos-zz_claim_no.
          ELSEIF ls_paym_req_log IS NOT INITIAL.
            lv_claim_no = ls_paym_req_log-zz_claim_no.        " by PL6U195 on 04042025
          ENDIF.

          READ TABLE lt_msg INTO DATA(ls_msg1) INDEX 1.

          CONCATENATE ls_msg1-arbgb '_' ls_msg1-txtnr
                           INTO lv_msgcode. "by PL5L317
          IF ls_msg1-msgty = gc_e.
            IF lv_status IS INITIAL. " IEPA-26247
              lv_status = gc_invalid.
            ENDIF.
            er_deep_entity-response = VALUE #( BASE er_deep_entity-response
                                               (
                                               zz_source       = ls_pymt_canc-zz_source
                                               zz_fin_tran_num = ls_pymt_canc-zz_fin_tran_num
                                               zz_extrl_ref_id = ls_pymt_canc-zz_extrl_ref_id
                                               zz_invoice_num  = ls_pymt_canc-zz_invoice_num
                                               doc1r           = ls_pymt_canc-doc1r
                                               zz_claim_no     = lv_claim_no
                                               zz_pymet        = ls_pymt_canc-zz_pymet
                                               zz_req_stat     = lv_status   " IEPA-26247  gc_invalid
                                               zz_pros_date    = sy-datlo
                                               msg_type        = ls_msg1-msgty
                                               msg_code        = lv_msgcode "lc_500
                                               msg_desc        = ls_msg1-text_ext ) ).

          ELSEIF ls_msg1-msgty = lc_s.   "Update response sturcture with message and Payment Request Status
            ls_pymt_canc-msg_type = lc_s.
            IF lv_orci_flag = gc_x.
              lv_msgv1 = ls_pymt_canc-zz_invoice_num.
              go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                            msgty  = ls_msg-msgty
                                                            msgno  = '025'
                                                            msgv1  = lv_msgv1
                                                  IMPORTING es_msg = ls_msg ).


              go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_s }| msgid = |{ lc_msgid }|
                                                           msgno = |025|      msgv1 = |{ lv_msgv1 }| ) ) ).
              lv_msg_text = ls_msg-text_ext. "PL4N363 IEPA-13962


            ELSEIF ls_dfkkop-zz_fin_tran_num IS NOT INITIAL AND ls_dfkkop-augst = gc_9.
              lv_msgv1 = ls_dfkkop-zz_fin_tran_num.
              ls_msg-msgty = gc_s.

              go_pymt_req_canc->get_message_text( EXPORTING msgid  = gc_msgid
                                                            msgty  = ls_msg-msgty
                                                            msgno  = '002'
                                                            msgv1  = lv_msgv1 "msgv2 = lv_msgv2
                                                  IMPORTING es_msg = ls_msg ).

              go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_e }|     msgid = |{ gc_msgid }|
                                                           msgv1 = |{ lv_msgv1 }| msgv2 = |{ lv_msgv2 }|
                                                           msgno = |002| ) ) ).
              lv_msg_text = ls_msg-text_ext."ls_pymt_canc-msg_desc.
              gc_canc_flag = gc_x.

            ELSE.
              IF ls_dfkkop-zz_fin_tran_num IS NOT INITIAL.
                lv_msgv1 = ls_dfkkop-zz_fin_tran_num..
              ELSEIF ls_vvscpos-zz_fin_tran_num IS NOT INITIAL.
                lv_msgv1 = ls_vvscpos-zz_fin_tran_num.
              ELSEIF ls_paym_req_log-zz_fin_tran_num  IS NOT INITIAL.
                lv_msgv1 = ls_paym_req_log-zz_fin_tran_num.
              ENDIF.

              go_pymt_req_canc->get_message_text( EXPORTING msgid  = gc_msgid
                                                            msgty  = gc_s
                                                            msgno  = '002'
                                                            msgv1  = lv_msgv1
                                                  IMPORTING es_msg = ls_msg ).


              go_appl_log->message_add( VALUE bal_t_msg( ( msgty = |{ gc_s }| msgid = |{ lc_msgid }|
                                                           msgno = |002|      msgv1 = |{ lv_msgv1 }| ) ) ).

              lv_msg_text = ls_msg-text_ext."ls_pymt_canc-msg_desc. "PL4N363 IEPA-13962
              gc_canc_flag = gc_x.

            ENDIF.

            CONCATENATE ls_msg-arbgb '_' ls_msg-txtnr
                        INTO lv_msgcode. "by PL5L317

            IF gc_canc_flag = gc_x.
              lv_status = gc_cancld.
            ELSE.
              lv_status = gc_cancld.  "gc_success.  " for ORCI in repsonse "requestStatus" should be CANCELED instead ACCEPTED by PL6U195 - 17-02-2025
            ENDIF.
            er_deep_entity-response = VALUE #( BASE er_deep_entity-response
                                               (
                                               zz_source         = ls_pymt_canc-zz_source
                                               zz_fin_tran_num   = ls_pymt_canc-zz_fin_tran_num
                                               zz_extrl_ref_id   = ls_pymt_canc-zz_extrl_ref_id
                                               zz_invoice_num    = ls_pymt_canc-zz_invoice_num
                                               doc1r             = ls_pymt_canc-doc1r
                                               zz_claim_no       = lv_claim_no
                                               zz_pymet          = ls_pymt_canc-zz_pymet
                                               zz_req_stat       = lv_status
                                               zz_pros_date      = sy-datlo
                                               zz_pymntcncl_date = sy-datlo       "PL4N363 IEPA-13962
                                               msg_type          = ls_pymt_canc-msg_type
                                               msg_code          = lv_msgcode "lc_201
                                               msg_desc          = ls_msg-text_ext ) ). "lv_msg_text ) ).

          ENDIF.

***   Begin of changes by pl4n363 under iepa-13962
          IF lt_msg[] IS INITIAL."IEPA-24999
            IF lv_chkstop = gc_x OR lv_ach_ret = gc_x.
*Begin of changes :IEPA-24999
              IF ls_pymt_canc-doc1r = space.
                ls_pymt_canc-doc1r = lv_doc1r.
              ENDIF.
*End of changes:IEPA-24999
              SELECT  zzsource,
                      zzproc_id,
                      bukrs,
                      pymet,
                      zzpymnt_status,
                      zz_chk_status,
                      voidrs,
                      zz_bulk_clr_ind,
                      zz_chk_stop_void_req,
                      zz_to_be_voidrs,
                      zz_err_msg,
                      zz_ach_auto_cutoff_days,
                      zz_ach_rtrvl_log_val,
                      zz_rtrvl_status
             FROM zcd_py_canc_req
             INTO TABLE @DATA(lt_chk_ach_map)
             WHERE zzsource IN @r_source
             AND bukrs IN @r_bukrs
             AND pymet IN @r_pymet.
              IF sy-subrc EQ 0.
                SORT lt_chk_ach_map BY zzsource zzproc_id bukrs pymet zzpymnt_status.
              ENDIF.

              IF lv_chkstop = gc_x AND
                 lv_source NE gc_source_orci.
                CALL METHOD me->check_stop
                  EXPORTING
                    ir_source       = r_source
                    ir_bukrs        = r_bukrs
                    ir_pymet        = r_pymet
                    ir_fin_tran_num = r_finid
                    ir_doc1r        = r_refno
                    it_chk_ach_map  = lt_chk_ach_map
                    iv_sec_procid   = lv_subsq_procid "lv_sec_procid        "by PL5L317 on 12/03/2024
                  IMPORTING
                    et_msg_chkstp   = DATA(lt_msg_chkstop).
                READ TABLE lt_msg_chkstop INTO DATA(ls_chkstop) WITH KEY msgty = gc_e. "IEPA-26247- begin
                IF sy-subrc = 0.
                  IF ls_chkstop-txtnr = lc_021 OR ls_chkstop-txtnr = lc_049.
                    lv_status = gc_success.
                  ENDIF.
                ENDIF. " IEPA-26247 -end
                APPEND LINES OF lt_msg_chkstop TO lt_msg1.

              ELSEIF lv_ach_ret = gc_x. "ACH Retrieval

                CALL METHOD me->ach_retrieval
                  EXPORTING
                    ir_source       = r_source
                    ir_bukrs        = r_bukrs
                    ir_pymet        = r_pymet
                    ir_fin_tran_num = r_finid
                    ir_doc1r        = r_refno
                    it_chk_ach_map  = lt_chk_ach_map
                    iv_sec_procid   = lv_sec_procid "ls_param-zz_sec_procid  by PL5L317 on 12/24/2024
                    iv_subsq_procid = lv_subsq_procid
                  IMPORTING
                    et_msg_achret   = DATA(lt_msg_achret)
                    et_achrtrv_log  = DATA(lt_achrtrv_log).

                APPEND LINES OF lt_msg_achret TO lt_msg1.

*    ***Begin of changes by PL4N363 Check Stop IEPA-13962
**    Update ACH retrieval log table
                IF lt_achrtrv_log IS  NOT INITIAL.
                  CALL METHOD me->update_achretlog
                    EXPORTING
                      it_achrtrv_log = lt_achrtrv_log
                    IMPORTING
                      ev_error       = DATA(lv_err).

                  IF lv_err IS NOT INITIAL.
                    lv_status = gc_success. " IEPA-26247
                    lv_msg = ls_pymt_canc-zz_fin_tran_num.
                    go_pymt_req_canc->get_message_text( EXPORTING msgid  = lc_msgid
                                                                  msgno  = '033'
                                                                  msgv1  = lv_msg
                                                        IMPORTING es_msg = ls_msg ).
                    APPEND ls_msg TO lt_msg1.
                  ENDIF.
                ENDIF.
*    ***End of changes by PL4N363 Check Stop IEPA-13962

              ENDIF.


**Update the response structure
              IF lt_msg1 IS NOT INITIAL.
                READ TABLE lt_msg1 INTO DATA(ls_msg_chkstop) INDEX 1.
                IF sy-subrc EQ 0.
                  IF ls_msg_chkstop-msgty = gc_e.
                    IF lv_status IS INITIAL.  " IEPA-26247
                      lv_status = gc_invalid.
                    ENDIF.
* Begin of changes by PL5L317
                    CONCATENATE ls_msg_chkstop-arbgb '_' ls_msg_chkstop-txtnr
                                INTO lv_msgcode.
* End of changes by PL5L317
                  ELSEIF ls_msg_chkstop-msgty = gc_s.
                    lv_status = gc_success.

* Begin of changes by PL5L317
                    CONCATENATE ls_msg_chkstop-arbgb '_' ls_msg_chkstop-txtnr
                                INTO lv_msgcode.
* End of changes by PL5L317
                  ENDIF.
                  er_deep_entity-response = VALUE #( BASE er_deep_entity-response
                                                     (
                                                     zz_source         = ls_pymt_canc-zz_source
                                                     zz_fin_tran_num   = ls_pymt_canc-zz_fin_tran_num
                                                     zz_extrl_ref_id   = ls_pymt_canc-zz_extrl_ref_id
                                                     zz_invoice_num    = ls_pymt_canc-zz_invoice_num
                                                     doc1r             = ls_pymt_canc-doc1r
                                                     zz_claim_no       = lv_claim_no
                                                     zz_pymet          = ls_pymt_canc-zz_pymet
                                                     zz_req_stat       = lv_status "gc_success
                                                     zz_pros_date      = sy-datlo
                                                     zz_pymntcncl_date = sy-datlo
                                                     msg_type          = ls_msg_chkstop-msgty
                                                     msg_code          = lv_msgcode
                                                     msg_desc          = ls_msg_chkstop-text_ext ) ).
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF. "IEPA-24999

*Begin of changes - IEPA-28689 TR DS4K906318
          READ TABLE lt_msg[] TRANSPORTING NO FIELDS WITH KEY msgty = gc_error_status.
          IF sy-subrc <> 0.
            IF ls_paym_req_log-origin = lc_pclm.
              SELECT SINGLE @abap_true
                       FROM vvscpos
                      WHERE zz_fin_tran_num = @ls_paym_req_log-zz_fin_tran_num
                       INTO @DATA(lv_vvscpos_exists).  "#EC CI_NOFIRST

              IF lv_vvscpos_exists = abap_false.
                update_exception_log( ls_paym_req_log ).
              ELSE.
                SELECT SINGLE @abap_true
                         FROM dfkkop
                        WHERE zz_fin_tran_num = @ls_paym_req_log-zz_fin_tran_num
                         INTO @DATA(lv_dfkkop_exists). "#EC CI_NOFIELD
                IF lv_dfkkop_exists = abap_false.
                  update_exception_log( is_paym_req_log = ls_paym_req_log ).
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.
*End of changes - IEPA-28689 TR DS4K906318


***End of changes by PL4N363 Check Stop IEPA-13962
          go_appl_log->log_save( ).

*         BUG 2 FIX: Added lv_paym_req_cncl, ls_paym_req_log, ls_dfkkop_chk,
*         lv_dfkkop_exist_flag, lv_chkstop, lv_ach_ret, lv_status, lv_msgcode,
*         lv_doc1r to CLEAR. These were leaking across loop iterations, causing
*         subsequent items to skip validation or use stale data from prior items.
          CLEAR: ls_pymt_canc, lv_ext_no, lv_payt_ref, lv_source, ls_vvscpos, lv_claim_no,
                lv_orci_flag, lv_vvscpos_flg, lv_arch_flag, lv_cler_flag, lv_canc_flag,
                lv_rev_flag, lv_guid, lv_msgv1, ls_msg, lt_msg[], lt_dfkkop[], ls_dfkkop,
                lv_paym_req_cncl, ls_paym_req_log, ls_dfkkop_chk, lv_dfkkop_exist_flag,
                lv_chkstop, lv_ach_ret, lv_status, lv_msgcode, lv_doc1r.

        ENDLOOP.
*Begin of changes - IEPA-29368 TR DV1K902673
        CALL FUNCTION 'DEQUEUE_EZ_FINID'
          EXPORTING
            origin          = ls_lock_request-zz_source
            zz_fin_tran_num = ls_lock_request-zz_fin_tran_num.
*End of changes - IEPA-29368 TR DV1K902673
      ENDIF.
    ENDIF.

  ENDMETHOD.
