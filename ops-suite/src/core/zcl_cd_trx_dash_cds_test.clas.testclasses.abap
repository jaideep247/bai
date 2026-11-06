*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_trx_dash_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the transactions dashboard on cl_cds_test_environment
*& doubles of the base tables (DFKKOP, T001, TFK042Z, DPAYH, DFKKCR, FEBEP,
*& DFKKRP, DFKKRK, DFKKNRP): flow bucket of every evidence combination
*& (posted, cleared, paid, settled, cheque encashed, returned, reversed),
*& proposal runs ignored, the 31-day window and the FIN filter, direction from
*& TFK042Z-XEINZ, KPI counts incl. distinct FIN numbers, the errored / stuck
*& list, returns by DFKKRP-RLGRD and NOCs by DFKKNRP-FLGRD via INFOF without
*& leading zeros, and that no partner or member element is exposed; does not
*& prove live SAP runtime behavior.
*& VERIFY-ADT: create( i_select_base_dependencies = abap_true ) doubles the
*& standard tables behind the view stack on 7.58; $session.system_date is not
*& doubled (test data is built relative to today).
*& Modification log:
*& 2026-11-06 | Initial version (transactions dashboard).
*& 2026-11-06 | Modern-syntax sweep: test helper LTD_ROWS.
*&---------------------------------------------------------------------*
"! Test data builders: one row per call, filled field by field (house rule)
CLASS ltd_rows DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS gc_company TYPE c LENGTH 4 VALUE 'US01'.
    CONSTANTS gc_country TYPE c LENGTH 3 VALUE 'US'.
    CONSTANTS gc_currency TYPE c LENGTH 5 VALUE 'USD'.
    CONSTANTS gc_method_disb TYPE c LENGTH 1 VALUE 'K'.
    CONSTANTS gc_method_coll TYPE c LENGTH 1 VALUE 'D'.
    CONSTANTS gc_method_chq TYPE c LENGTH 1 VALUE 'C'.

    CLASS-METHODS days_ago
      IMPORTING
        iv_days        TYPE i
      RETURNING
        VALUE(rv_date) TYPE d.

    CLASS-METHODS item
      IMPORTING
        iv_opbel       TYPE clike
        iv_fin         TYPE clike
        iv_augbl       TYPE clike OPTIONAL
        iv_method      TYPE clike DEFAULT gc_method_disb
        iv_days_ago    TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_item) TYPE dfkkop.

    "! Company code, payment methods (K disbursement, C cheque, D collection)
    CLASS-METHODS insert_config
      IMPORTING
        io_env TYPE REF TO if_cds_test_environment.
ENDCLASS.


CLASS ltd_rows IMPLEMENTATION.

  METHOD days_ago.
    rv_date = cl_abap_context_info=>get_system_date( ) - iv_days.
  ENDMETHOD.


  METHOD item.
    rs_item-opbel            = iv_opbel.
    rs_item-bukrs            = gc_company.
    rs_item-budat            = days_ago( iv_days_ago ).
    rs_item-waers            = gc_currency.
    rs_item-pymet            = iv_method.
    rs_item-augbl            = iv_augbl.
    rs_item-zz_fin_trans_num = iv_fin.
  ENDMETHOD.


  METHOD insert_config.
    DATA lt_t001 TYPE STANDARD TABLE OF t001 WITH EMPTY KEY.
    DATA lt_methods TYPE STANDARD TABLE OF tfk042z WITH EMPTY KEY.
    DATA ls_t001 TYPE t001.
    DATA ls_method TYPE tfk042z.

    ls_t001-bukrs = gc_company.
    ls_t001-land1 = gc_country.
    ls_t001-waers = gc_currency.
    INSERT ls_t001 INTO TABLE lt_t001.
    ls_method-land1 = gc_country.
    ls_method-zlsch = gc_method_disb.
    INSERT ls_method INTO TABLE lt_methods.
    ls_method-zlsch = gc_method_chq.
    INSERT ls_method INTO TABLE lt_methods.
    ls_method-zlsch = gc_method_coll.
    ls_method-xeinz = abap_true.
    INSERT ls_method INTO TABLE lt_methods.
    io_env->insert_test_data( i_data = lt_t001 ).
    io_env->insert_test_data( i_data = lt_methods ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_TRXFLOW / ZR_CD_TRXKPI / ZR_CD_TRXPROBLEM / ZR_CD_TRXRETNOC
CLASS ltc_flow DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_doc,
        posted    TYPE c LENGTH 12 VALUE '100000000001',
        cleared   TYPE c LENGTH 12 VALUE '100000000002',
        paid      TYPE c LENGTH 12 VALUE '100000000003',
        settled   TYPE c LENGTH 12 VALUE '100000000004',
        cheque    TYPE c LENGTH 12 VALUE '100000000005',
        returned  TYPE c LENGTH 12 VALUE '100000000006',
        reversed  TYPE c LENGTH 12 VALUE '100000000007',
        proposal  TYPE c LENGTH 12 VALUE '100000000008',
        no_fin    TYPE c LENGTH 12 VALUE '100000000009',
        too_old   TYPE c LENGTH 12 VALUE '100000000010',
        collect   TYPE c LENGTH 12 VALUE '100000000011',
        noc       TYPE c LENGTH 12 VALUE '100000000012',
        overdue   TYPE c LENGTH 12 VALUE '100000000013',
      END OF gc_doc.
    CONSTANTS:
      BEGIN OF gc_pay,
        cleared  TYPE c LENGTH 12 VALUE '200000000002',
        paid     TYPE c LENGTH 12 VALUE '200000000003',
        settled  TYPE c LENGTH 12 VALUE '200000000004',
        cheque   TYPE c LENGTH 12 VALUE '200000000005',
        returned TYPE c LENGTH 12 VALUE '200000000006',
        reversed TYPE c LENGTH 12 VALUE '200000000007',
        proposal TYPE c LENGTH 12 VALUE '200000000008',
        noc      TYPE c LENGTH 12 VALUE '200000000012',
      END OF gc_pay.
    CONSTANTS gc_fin TYPE c LENGTH 20 VALUE 'FIN0000000100'.
    CONSTANTS gc_fin_shared TYPE c LENGTH 20 VALUE 'FIN0000000200'.
    CONSTANTS gc_cheque_no TYPE c LENGTH 13 VALUE 'CHK0000000005'.
    CONSTANTS gc_run_id TYPE c LENGTH 6 VALUE 'DISB01'.
    CONSTANTS gc_status TYPE c LENGTH 10 VALUE 'SENT'.
    CONSTANTS gc_reversal TYPE c LENGTH 2 VALUE '05'.
    CONSTANTS gc_return_doc TYPE c LENGTH 12 VALUE '600000000006'.
    CONSTANTS gc_return_reason TYPE c LENGTH 3 VALUE 'R01'.
    CONSTANTS gc_noc_lot TYPE c LENGTH 12 VALUE 'NOC000000012'.
    CONSTANTS gc_noc_item TYPE n LENGTH 6 VALUE '000001'.
    CONSTANTS gc_noc_infof TYPE c LENGTH 50 VALUE '00200000000012'.
    CONSTANTS gc_noc_reason TYPE c LENGTH 3 VALUE 'C01'.
    CONSTANTS gc_esnum TYPE n LENGTH 5 VALUE '00001'.
    CONSTANTS gc_kukey TYPE n LENGTH 8 VALUE '00009001'.
    CONSTANTS gc_days_old TYPE i VALUE 40.
    CONSTANTS gc_days_overdue TYPE i VALUE 3.
    CONSTANTS:
      BEGIN OF gc_bucket,
        posted   TYPE c LENGTH 10 VALUE 'POSTED',
        cleared  TYPE c LENGTH 10 VALUE 'CLEARED',
        paid     TYPE c LENGTH 10 VALUE 'PAID',
        settled  TYPE c LENGTH 10 VALUE 'SETTLED',
        returned TYPE c LENGTH 10 VALUE 'RETURNED',
        reversed TYPE c LENGTH 10 VALUE 'REVERSED',
      END OF gc_bucket.
    CONSTANTS:
      BEGIN OF gc_direction,
        disbursement TYPE c LENGTH 12 VALUE 'DISBURSEMENT',
        collection   TYPE c LENGTH 12 VALUE 'COLLECTION',
      END OF gc_direction.
    CONSTANTS:
      BEGIN OF gc_problem,
        returned TYPE c LENGTH 12 VALUE 'RETURNED',
        reversed TYPE c LENGTH 12 VALUE 'REVERSED',
        overdue  TYPE c LENGTH 12 VALUE 'OPEN_OVERDUE',
      END OF gc_problem.
    CONSTANTS:
      BEGIN OF gc_kind,
        return TYPE c LENGTH 6 VALUE 'RETURN',
        noc    TYPE c LENGTH 6 VALUE 'NOC',
      END OF gc_kind.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS bucket_follows_evidence FOR TESTING.
    METHODS proposal_run_is_not_payment FOR TESTING.
    METHODS window_and_fin_bound_rows FOR TESTING.
    METHODS direction_from_tfk042z FOR TESTING.
    METHODS kpi_counts_distinct_fin FOR TESTING.
    METHODS problems_list_errored_stuck FOR TESTING.
    METHODS reasons_from_lot_items FOR TESTING.
    METHODS no_partner_or_member_exposed FOR TESTING.

    METHODS bucket_of
      IMPORTING
        iv_opbel         TYPE clike
      RETURNING
        VALUE(rv_bucket) TYPE string.
ENDCLASS.


CLASS ltc_flow IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_CD_TRXFLOW' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_TRXKPI' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_TRXPROBLEM' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_TRXRETNOC' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA lt_cheques TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA lt_returns TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA lt_nocs TYPE STANDARD TABLE OF dfkknrp WITH EMPTY KEY.
    DATA ls_run TYPE dpayh.
    DATA ls_cheque TYPE dfkkcr.
    DATA ls_line TYPE febep.
    DATA ls_return TYPE dfkkrp.
    DATA ls_noc TYPE dfkknrp.

    go_env->clear_doubles( ).
    ltd_rows=>insert_config( go_env ).

    INSERT ltd_rows=>item( iv_opbel = gc_doc-posted iv_fin = gc_fin ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-cleared iv_fin = gc_fin iv_augbl = gc_pay-cleared ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-paid iv_fin = gc_fin_shared iv_augbl = gc_pay-paid ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-settled iv_fin = gc_fin_shared iv_augbl = gc_pay-settled ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel  = gc_doc-cheque iv_fin = gc_fin iv_augbl = gc_pay-cheque
                           iv_method = ltd_rows=>gc_method_chq ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-returned iv_fin = gc_fin iv_augbl = gc_pay-returned ) INTO TABLE lt_items.
    DATA(ls_reversed) = ltd_rows=>item( iv_opbel = gc_doc-reversed iv_fin = gc_fin iv_augbl = gc_pay-reversed ).
    ls_reversed-augrd = gc_reversal.
    INSERT ls_reversed INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-proposal iv_fin = gc_fin iv_augbl = gc_pay-proposal ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-no_fin iv_fin = space ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-too_old iv_fin = gc_fin iv_days_ago = gc_days_old ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-collect iv_fin = gc_fin iv_method = ltd_rows=>gc_method_coll
                           iv_days_ago = gc_days_overdue ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-noc iv_fin = gc_fin iv_augbl = gc_pay-noc ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-overdue iv_fin = gc_fin iv_days_ago = gc_days_overdue ) INTO TABLE lt_items.

    ls_run-laufd = ltd_rows=>days_ago( 0 ).
    ls_run-laufi = gc_run_id.
    ls_run-zz_payment_status = gc_status.
    ls_run-doc1r = gc_pay-paid.
    INSERT ls_run INTO TABLE lt_runs.
    ls_run-doc1r = gc_pay-settled.
    INSERT ls_run INTO TABLE lt_runs.
    ls_run-doc1r = gc_pay-proposal.
    ls_run-xvorl = abap_true.
    INSERT ls_run INTO TABLE lt_runs.

    ls_cheque-doc1r = gc_pay-cheque.
    ls_cheque-ztnum = gc_cheque_no.
    INSERT ls_cheque INTO TABLE lt_cheques.

    ls_line-kukey = gc_kukey.
    ls_line-esnum = gc_esnum.
    ls_line-budat = ltd_rows=>days_ago( 0 ).
    ls_line-chect = gc_pay-settled.
    INSERT ls_line INTO TABLE lt_lines.
    ls_line-esnum = gc_esnum + 1.
    ls_line-chect = gc_cheque_no.
    INSERT ls_line INTO TABLE lt_lines.

    ls_return-selw1 = gc_pay-returned.
    ls_return-opbel = gc_return_doc.
    ls_return-rlgrd = gc_return_reason.
    INSERT ls_return INTO TABLE lt_returns.
    ls_noc-keyn1 = gc_noc_lot.
    ls_noc-posna = gc_noc_item.
    ls_noc-infof = gc_noc_infof.
    ls_noc-flgrd = gc_noc_reason.
    INSERT ls_noc INTO TABLE lt_nocs.

    go_env->insert_test_data( i_data = lt_items ).
    go_env->insert_test_data( i_data = lt_runs ).
    go_env->insert_test_data( i_data = lt_cheques ).
    go_env->insert_test_data( i_data = lt_lines ).
    go_env->insert_test_data( i_data = lt_returns ).
    go_env->insert_test_data( i_data = lt_nocs ).
  ENDMETHOD.


  METHOD bucket_of.
    SELECT SINGLE flowbucket FROM zr_cd_trxflow WHERE documentno = @iv_opbel INTO @DATA(lv_bucket).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |Item { iv_opbel } must be on the dashboard| ).
    rv_bucket = condense( lv_bucket ).
  ENDMETHOD.


  METHOD bucket_follows_evidence.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-posted ) exp = gc_bucket-posted
                                            msg = 'No clearing document: POSTED (open)' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-cleared ) exp = gc_bucket-cleared
                                            msg = 'Cleared without payment evidence: CLEARED' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-paid ) exp = gc_bucket-paid
                                            msg = 'DPAYH row with DOC1R = AUGBL: PAID' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-settled ) exp = gc_bucket-settled
                                            msg = 'Bank line with CHECT = AUGBL: SETTLED' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-cheque ) exp = gc_bucket-settled
                                            msg = 'Cheque (DFKKCR) encashed (CHECT = ZTNUM): SETTLED' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-returned ) exp = gc_bucket-returned
                                            msg = 'Returns lot item with SELW1 = AUGBL: RETURNED' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-reversed ) exp = gc_bucket-reversed
                                            msg = 'Clearing reason 05: REVERSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD proposal_run_is_not_payment.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-proposal ) exp = gc_bucket-cleared
                                            msg = 'A proposal run (XVORL) is never payment evidence' ).
        SELECT SINGLE paymentstatus, lastrunid FROM zr_cd_trxflow WHERE documentno = @gc_doc-paid
          INTO @DATA(ls_paid).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The paid item must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_paid-paymentstatus exp = gc_status
                                            msg = 'The live status comes from DPAYH-ZZ_PAYMENT_STATUS' ).
        cl_abap_unit_assert=>assert_equals( act = ls_paid-lastrunid exp = gc_run_id msg = 'The run ID is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD window_and_fin_bound_rows.
    TRY.
        SELECT COUNT(*) FROM zr_cd_trxflow WHERE documentno = @gc_doc-no_fin INTO @DATA(lv_no_fin).
        SELECT COUNT(*) FROM zr_cd_trxflow WHERE documentno = @gc_doc-too_old INTO @DATA(lv_old).

        cl_abap_unit_assert=>assert_equals( act = lv_no_fin exp = 0 msg = 'Items without FIN are not transactions' ).
        cl_abap_unit_assert=>assert_equals( act = lv_old exp = 0 msg = 'Items posted 40 days ago are outside' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD direction_from_tfk042z.
    TRY.
        SELECT SINGLE direction FROM zr_cd_trxflow WHERE documentno = @gc_doc-collect INTO @DATA(lv_coll).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The collection item must be listed' ).
        SELECT SINGLE direction FROM zr_cd_trxflow WHERE documentno = @gc_doc-posted INTO @DATA(lv_disb).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The disbursement item must be listed' ).

        cl_abap_unit_assert=>assert_equals( act = lv_coll exp = gc_direction-collection
                                            msg = 'TFK042Z-XEINZ = X is a collection' ).
        cl_abap_unit_assert=>assert_equals( act = lv_disb exp = gc_direction-disbursement
                                            msg = 'XEINZ blank is a disbursement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD kpi_counts_distinct_fin.
    TRY.
        SELECT SINGLE itemcount, fincount, paidreachedcount, settledreachedcount, returnedcount, reversedcount
          FROM zr_cd_trxkpi
          WHERE postingdate = @( ltd_rows=>days_ago( 0 ) )
            AND companycode = @ltd_rows=>gc_company
            AND direction   = @gc_direction-disbursement
          INTO @DATA(ls_kpi).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'A KPI row for today, US01, disbursements' ).
        " Today, disbursement: posted, cleared, paid, settled, cheque, returned, reversed, proposal, noc
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-itemcount exp = 9 msg = 'Nine transactions today' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-fincount exp = 2
                                            msg = 'Two FIN numbers - the shared FIN counts once' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-paidreachedcount exp = 4
                                            msg = 'Paid reached: paid, settled, cheque, returned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-settledreachedcount exp = 2
                                            msg = 'Settled reached: bank line and cheque encashment' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-returnedcount exp = 1 msg = 'One returned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-reversedcount exp = 1 msg = 'One reversed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD problems_list_errored_stuck.
    TRY.
        SELECT documentno, problemtype FROM zr_cd_trxproblem ORDER BY documentno INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3
                                            msg = 'Returned, reversed and the overdue open disbursement' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_rows[ documentno = gc_doc-returned ]-problemtype OPTIONAL ) exp = gc_problem-returned
          msg = 'The returned item is listed' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_rows[ documentno = gc_doc-overdue ]-problemtype OPTIONAL ) exp = gc_problem-overdue
          msg = 'An open disbursement posted 3 days ago is overdue' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ documentno = gc_doc-collect ] ) )
                                           msg = 'An open collection is not overdue' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ documentno = gc_doc-posted ] ) )
                                           msg = 'An item posted today is not overdue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD reasons_from_lot_items.
    TRY.
        SELECT documentno, lotkind, reason FROM zr_cd_trxretnoc ORDER BY documentno INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One return, one NOC' ).
        DATA(ls_return) = VALUE #( lt_rows[ lotkind = gc_kind-return ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_return-documentno exp = gc_doc-returned
                                            msg = 'Return linked by DFKKRP-SELW1 = AUGBL' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_return-reason ) exp = gc_return_reason
                                            msg = 'Return reason from DFKKRP-RLGRD' ).
        DATA(ls_noc) = VALUE #( lt_rows[ lotkind = gc_kind-noc ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_noc-documentno exp = gc_doc-noc
                                            msg = 'NOC linked by INFOF (leading zeros) = AUGBL' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_noc-reason ) exp = gc_noc_reason
                                            msg = 'NOC reason from DFKKNRP-FLGRD' ).
        SELECT SINGLE returnreason FROM zr_cd_trxflow WHERE documentno = @gc_doc-returned INTO @DATA(lv_reason).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The returned item must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = condense( lv_reason ) exp = gc_return_reason
                                            msg = 'The transaction row carries the return reason' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_partner_or_member_exposed.
    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( 'ZR_CD_TRXFLOW' ) ).
        DATA(lt_names) = VALUE string_table( FOR ls_comp IN lo_struct->components ( CONV #( ls_comp-name ) ) ).
        LOOP AT VALUE string_table( ( `GPART` ) ( `VKONT` ) ( `ZZ_MEMBER_NO` ) ( `BANKN` ) ( `IBAN` ) )
             INTO DATA(lv_forbidden).
          cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_names[ table_line = lv_forbidden ] ) )
                                             msg = |{ lv_forbidden } must never be an element of the dashboard| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
