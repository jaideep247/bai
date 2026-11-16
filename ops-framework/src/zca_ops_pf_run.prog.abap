*&---------------------------------------------------------------------*
*& Artifact: zca_ops_pf_run.prog.abap
*& Purpose:
*& Payment file lifecycle (docs/PAYMENT_FILE_LIFECYCLE.md): reads the
*& adapters of the active file types of an area (or one file type) from
*& their watermarks - files and payments of the payment runs, transfer
*& records, bank acknowledgements, scheduler jobs, statement evidence -
*& stores every observation once, evaluates every file under watch and
*& every business day (expected versus observed) and commits per file
*& type. The registered check ZCL_CA_OPS_CHK_PAYFILE turns the result into
*& findings. Test mode (default) writes nothing. Authorisation ZCA_OPS 16
*& for the area; module CASH_OPS of the licence. Read-only towards
*& business data: no posting, no restart or retransmission of a file, no
*& IDoc, no incident in SAP. One job log line per file type (370) and
*& per note of the run; in background an error ends the job cancelled.
*& Schedule it before the check's schedule group (e.g. every 15 minutes).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
REPORT zca_ops_pf_run.

PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area OBLIGATORY.
PARAMETERS p_ftype TYPE zif_ca_ops_pf_types=>ty_file_type.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        DATA(lt_results) = NEW zcl_ca_ops_pf_ingest( )->run( iv_area      = p_area
                                                            iv_file_type = p_ftype
                                                            iv_test_mode = p_test ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    IF lt_results IS INITIAL.
      MESSAGE s387(zca_ops) WITH p_ftype p_area.
      RETURN.
    ENDIF.
    LOOP AT lt_results ASSIGNING FIELD-SYMBOL(<ls_result>).
      LOOP AT <ls_result>-messages ASSIGNING FIELD-SYMBOL(<lv_message>).
        MESSAGE <lv_message> TYPE 'S'.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
