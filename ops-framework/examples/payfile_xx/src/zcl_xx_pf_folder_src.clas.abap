*&---------------------------------------------------------------------*
*& Artifact: zcl_xx_pf_folder_src.clas.abap
*& Purpose:
*& Worked example of a fictitious second customer XX (never seeded, not
*& part of the product): its transfer source of the payment file
*& lifecycle (role TRANSFER). XX has no middleware - its own transfer job
*& writes the payment file to an outbound folder and uploads it to the
*& bank's server, logging every attempt in its table ZXX_PF_FOLDER. One
*& event per row changed in the window: native status = the row's status
*& (WRITTEN, UPLOADED, UPLOAD_ERR - XX's status mapping says which
*& milestone and outcome), record ID = file name / attempt, version 1,
*& the file it is about by name. Wired only through the product's
*& interfaces and XX's configuration rows (ZCA_OPS_PFADP, ZCA_OPS_PFMAP).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle, example XX).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Example XX - payment file transfer source (folder log)</p>
CLASS zcl_xx_pf_folder_src DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_transfer_src.

ENDCLASS.



CLASS zcl_xx_pf_folder_src IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting: the folder log is XX's own table
  ENDMETHOD.


  METHOD zif_ca_ops_pf_event_src~read_events.
    DATA(lv_max) = COND i( WHEN is_request-max > 0 THEN is_request-max ELSE 10000 ).
    SELECT file_name, attempt, run_date, run_id, bukrs, status, changed_at
      FROM zxx_pf_folder
      WHERE changed_at >= @is_request-from_ts
        AND changed_at <= @is_request-to_ts
      ORDER BY changed_at, file_name, attempt
      INTO TABLE @DATA(lt_rows)
      UP TO @lv_max ROWS.
    rs_batch-partial = xsdbool( lines( lt_rows ) >= lv_max ).
    rs_batch-as_of = is_request-to_ts.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( source_event_id = |{ <ls_row>-file_name }/{ <ls_row>-attempt }|
                      event_version   = 1
                      native_status   = <ls_row>-status
                      native_key      = <ls_row>-file_name
                      run_date        = <ls_row>-run_date
                      run_id          = <ls_row>-run_id
                      bukrs           = <ls_row>-bukrs
                      occurred_at     = <ls_row>-changed_at
                      bus_date        = <ls_row>-run_date ) INTO TABLE rs_batch-events.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
