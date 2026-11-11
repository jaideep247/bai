*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_enr_payrun.clas.abap
*& Purpose:
*& Enricher of the framework's SAP job monitor (ZIF_CA_OPS_JOB_ENRICHER)
*& for payment run jobs (FPY1): a mass activity run of a payment run type
*& (JOB_PAYRUN_ACTIVITIES, VERIFY-SE11 V68) found by the mass activity
*& enricher before it is the payment run LAUFD / LAUFI - its payments per
*& company code (DPAYH, confirmed key) and its open exceptions in the
*& payment worklist (ZCD_PAY_OUTCOME; payment trace from the board). The
*& company code of the run becomes the company code of the job when the
*& run has exactly one. Quality = the quality of the mass activity run
*& (P: the run is read from the job name). Blank activity list = adds
*& nothing; delivered outside JOB_ENRICHERS until confirmed.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - job enricher: payment run</p>
"! Runs after ZCL_CD_JOB_ENR_MASSACT in JOB_ENRICHERS (it reads that enricher's objects).
CLASS zcl_cd_job_enr_payrun DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_enricher.

    "! @parameter io_dao | Data access (default ZCL_CD_JOB_DAO; a double in tests)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_cd_job_dao OPTIONAL.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO zif_cd_job_dao.

    "! Payment run objects of the mass activity runs of a payment run type
    METHODS payment_runs
      IMPORTING
        it_objects     TYPE zif_ca_ops_job_types=>tt_bus_object
        it_activities  TYPE string_table
      RETURNING
        VALUE(rt_runs) TYPE zif_ca_ops_job_types=>tt_bus_object.

ENDCLASS.



CLASS zcl_cd_job_enr_payrun IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_cd_job_dao( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_job_enricher~enrich.
    DATA lt_keys TYPE zif_cd_job_types=>tt_run_key.
    DATA lt_activities TYPE string_table.

    LOOP AT zcl_ca_ops_util=>split_list( zcl_cd_ops_factory=>get_params( )->get_param(
                                           iv_name = zif_cd_job_types=>gc_param-payrun_activities
                                           iv_area = zif_ca_ops_types=>gc_param_area ) ) ASSIGNING FIELD-SYMBOL(<lv_activity>).
      INSERT to_upper( <lv_activity> ) INTO TABLE lt_activities.
    ENDLOOP.
    IF lt_activities IS INITIAL OR it_jobs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_runs) = payment_runs( it_objects = ct_objects it_activities = lt_activities ).
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      SPLIT <ls_run>-object_key AT zif_cd_job_types=>gc_key_separator INTO DATA(lv_laufd) DATA(lv_laufi).
      INSERT VALUE #( laufd = lv_laufd laufi = lv_laufi ) INTO TABLE lt_keys.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_payments) = mo_dao->run_payments( lt_keys ).
    DATA(lt_exceptions) = mo_dao->run_exceptions( lt_keys ).

    LOOP AT lt_runs ASSIGNING <ls_run>.
      SPLIT <ls_run>-object_key AT zif_cd_job_types=>gc_key_separator INTO lv_laufd lv_laufi.
      DATA(ls_key) = VALUE zif_cd_job_types=>ty_run_key( laufd = lv_laufd laufi = lv_laufi ).
      DATA(lv_payments) = 0.
      DATA(lv_bukrs) = VALUE bukrs( ).
      DATA(lv_company_codes) = 0.
      LOOP AT lt_payments ASSIGNING FIELD-SYMBOL(<ls_payments>) WHERE laufd = ls_key-laufd AND laufi = ls_key-laufi.
        lv_payments += <ls_payments>-payments.
        lv_bukrs = <ls_payments>-bukrs.
        lv_company_codes += 1.
      ENDLOOP.
      IF lv_company_codes <> 1.
        CLEAR lv_bukrs.
      ENDIF.
      DATA(ls_object) = <ls_run>.
      ls_object-enricher    = cl_abap_classdescr=>get_class_name( me ).
      ls_object-bukrs       = lv_bukrs.
      ls_object-item_count  = lv_payments.
      ls_object-label       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_job_types=>gc_msg-payment_run
                                                     iv_v1    = |{ ls_key-laufd DATE = ISO }|
                                                     iv_v2    = ls_key-laufi
                                                     iv_v3    = lv_payments
                                                     iv_v4    = lv_bukrs ).
      INSERT ls_object INTO TABLE ct_objects.
      DATA(lv_open) = VALUE #( lt_exceptions[ laufd = ls_key-laufd laufi = ls_key-laufi ]-exceptions OPTIONAL ).
      IF lv_open > 0.
        ls_object-object_type = zif_cd_job_types=>gc_object_type-worklist.
        ls_object-item_count  = lv_open.
        ls_object-label       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_job_types=>gc_msg-worklist
                                                       iv_v1    = lv_open
                                                       iv_v2    = |{ ls_key-laufd DATE = ISO }|
                                                       iv_v3    = ls_key-laufi ).
        INSERT ls_object INTO TABLE ct_objects.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD payment_runs.
    LOOP AT it_objects ASSIGNING FIELD-SYMBOL(<ls_object>)
         WHERE object_type = zif_cd_job_types=>gc_object_type-mass_run.
      SPLIT <ls_object>-object_key AT zif_cd_job_types=>gc_key_separator
            INTO DATA(lv_activity) DATA(lv_date) DATA(lv_id).
      IF NOT line_exists( it_activities[ table_line = lv_activity ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_run) = <ls_object>.
      ls_run-object_type = zif_cd_job_types=>gc_object_type-payment_run.
      ls_run-object_key  = |{ lv_date }{ zif_cd_job_types=>gc_key_separator }{ lv_id }|.
      INSERT ls_run INTO TABLE rt_runs.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
