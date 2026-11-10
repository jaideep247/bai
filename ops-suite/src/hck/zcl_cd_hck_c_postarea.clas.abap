*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_postarea.clas.abap
*& Purpose:
*& Configuration check POSTAREA_INVALID: the entries of the customer posting
*& areas ZRSN, ZPMC, ZBTM and ZBTR (FQC0) that their readers cannot use -
*& FQC0 checks only the domains of the values, the suite's own rules are
*& checked here every morning (ZCL_CD_OPS_CFG_CHECKS=>CHECK_POSTING_AREAS:
*& generic keys, lengths, allowed values, roles per usage, LIFECYCLE scope,
*& method classes and their payment methods, rule groups, RECON scheme). One
*& finding per message; an empty posting area is a warning. Reads nothing
*& itself (posting area reader, EBS rule assignments).
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas replace four customizing tables).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - invalid posting area entries (FQC0)</p>
"! One POSTAREA_INVALID finding per message, object key posting area/entry key, group 1 the
"! posting area; severity E (an entry the reader cannot use), W (an empty posting area).
"! Metric POSTAREA_INVALID '*' = number of findings.
CLASS zcl_cd_hck_c_postarea DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'POSTAREA_INVALID'.

ENDCLASS.



CLASS zcl_cd_hck_c_postarea IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    LOOP AT zcl_cd_ops_cfg_checks=>check_posting_areas( ) ASSIGNING FIELD-SYMBOL(<ls_message>).
      INSERT VALUE #( object_key = COND #( WHEN <ls_message>-entry IS INITIAL THEN CONV #( <ls_message>-area )
                                           ELSE |{ <ls_message>-area }{ zif_cd_ops_postarea_types=>gc_key_separator }| &&
                                                |{ <ls_message>-entry }| )
                      group1     = <ls_message>-area
                      check_code = zif_cd_hck_types=>gc_code-postarea_invalid
                      severity   = <ls_message>-severity
                      action     = zif_ca_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = CONV #( <ls_message>-number )
                                                          iv_v1    = <ls_message>-v1
                                                          iv_v2    = <ls_message>-v2
                                                          iv_v3    = <ls_message>-v3 ) )
        INTO TABLE rs_result-findings.
    ENDLOOP.
    INSERT VALUE #( metric = gc_metric
                    dim1   = zif_cd_hck_types=>gc_default_key
                    value  = lines( rs_result-findings ) ) INTO TABLE rs_result-metrics.
  ENDMETHOD.

ENDCLASS.
