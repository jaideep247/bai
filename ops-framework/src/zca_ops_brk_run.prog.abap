*&---------------------------------------------------------------------*
*& Artifact: zca_ops_brk_run.prog.abap
*& Purpose:
*& Clearing-account break analysis (docs/BREAK_ANALYSIS.md): analyses the
*& active clearing accounts of an area (or one account) at a key date -
*& groups of open journal lines by assignment and currency that do not net
*& to zero, each line and group classified into a variance bucket by the
*& ordered bucket rules - and saves one snapshot per account (committed per
*& account). Key date blank = today minus BRK_KEY_DATE_LAG days. Test mode
*& (default) writes nothing. Authorisation ZCA_OPS 16 for the area. Read
*& only towards business data: no posting, no clearing, no matching. One
*& line per account in the job log (message 280, 283 or 290); in background
*& an error ends the job cancelled. Schedule after the G/L transfer of the
*& day, before the check ZCL_CA_OPS_CHK_BREAK runs.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
REPORT zca_ops_brk_run.

PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area OBLIGATORY.
PARAMETERS p_acct TYPE zif_ca_ops_brk_types=>ty_acct_id.
PARAMETERS p_kdate TYPE d.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    "! The key date: entered, else today minus BRK_KEY_DATE_LAG
    METHODS key_date
      RETURNING
        VALUE(rv_date) TYPE d.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        DATA(lt_results) = NEW zcl_ca_ops_brk_analyzer( )->analyze( iv_area      = p_area
                                                                    iv_acct_id   = p_acct
                                                                    iv_key_date  = key_date( )
                                                                    iv_test_mode = p_test ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    LOOP AT lt_results ASSIGNING FIELD-SYMBOL(<ls_result>).
      IF <ls_result>-skipped = abap_true.
        MESSAGE s290(zca_ops) WITH <ls_result>-snapshot-acct_id p_area <ls_result>-problems[ 1 ]-v3.
      ELSE.
        MESSAGE <ls_result>-snapshot-message TYPE 'S'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD key_date.
    rv_date = p_kdate.
    IF rv_date IS INITIAL.
      rv_date = zcl_ca_ops_factory=>get_clock( )->today( )
              - zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                            iv_name    = zif_ca_ops_brk_types=>gc_param-key_lag
                                            iv_default = zif_ca_ops_brk_types=>gc_default-key_lag ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
