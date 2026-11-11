*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_dao.clas.abap
*& Purpose:
*& SQL of the suite's SAP job monitor plug-ins (read only): payments of
*& payment runs per company code from DPAYH by run date and run ID (the
*& confirmed cumulation key LAUFD + LAUFI), proposals left out; open
*& exceptions of the runs in the payment worklist ZCD_PAY_OUTCOME (current
*& rows with a finding). One grouped read each for all runs of a call.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - SAP job monitor plug-in data access</p>
"! VERIFY-SE11 V68: DPAYH-XVORL (proposal flag) and an index of DPAYH starting with LAUFD / LAUFI.
CLASS zcl_cd_job_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_job_dao.

  PRIVATE SECTION.
    TYPES tt_date_range TYPE RANGE OF d.
    TYPES tt_id_range TYPE RANGE OF zif_cd_job_types=>ty_run_key-laufi.

    "! Ranges of the run dates and IDs (few runs per call); pairs not asked are dropped after the read
    CLASS-METHODS ranges
      IMPORTING
        it_runs  TYPE zif_cd_job_types=>tt_run_key
      EXPORTING
        et_dates TYPE tt_date_range
        et_ids   TYPE tt_id_range.

ENDCLASS.



CLASS zcl_cd_job_dao IMPLEMENTATION.

  METHOD zif_cd_job_dao~run_payments.
    IF it_runs IS INITIAL.
      RETURN.
    ENDIF.
    ranges( EXPORTING it_runs  = it_runs
            IMPORTING et_dates = DATA(lt_dates)
                      et_ids   = DATA(lt_ids) ).
    "VERIFY-SE11 V68: DPAYH-XVORL blank = not a proposal run
    SELECT laufd, laufi, bukrs, COUNT(*) AS payments
      FROM dpayh
      WHERE laufd IN @lt_dates
        AND laufi IN @lt_ids
        AND xvorl = @space
      GROUP BY laufd, laufi, bukrs
      ORDER BY laufd, laufi, bukrs
      INTO CORRESPONDING FIELDS OF TABLE @rt_payments.
    LOOP AT rt_payments ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF NOT line_exists( it_runs[ laufd = <ls_row>-laufd laufi = <ls_row>-laufi ] ).
        DELETE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_job_dao~run_exceptions.
    IF it_runs IS INITIAL.
      RETURN.
    ENDIF.
    ranges( EXPORTING it_runs  = it_runs
            IMPORTING et_dates = DATA(lt_dates)
                      et_ids   = DATA(lt_ids) ).
    SELECT laufd, laufi, COUNT(*) AS exceptions
      FROM zcd_pay_outcome
      WHERE laufd IN @lt_dates
        AND laufi IN @lt_ids
        AND valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
        AND finding <> @space
      GROUP BY laufd, laufi
      ORDER BY laufd, laufi
      INTO CORRESPONDING FIELDS OF TABLE @rt_exceptions.
    LOOP AT rt_exceptions ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF NOT line_exists( it_runs[ laufd = <ls_row>-laufd laufi = <ls_row>-laufi ] ).
        DELETE rt_exceptions.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ranges.
    CLEAR: et_dates, et_ids.
    LOOP AT it_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      IF NOT line_exists( et_dates[ low = <ls_run>-laufd ] ).
        INSERT VALUE #( sign = zif_ca_ops_types=>gc_range-sign_include option = zif_ca_ops_types=>gc_range-option_equal
                        low = <ls_run>-laufd ) INTO TABLE et_dates.
      ENDIF.
      IF NOT line_exists( et_ids[ low = <ls_run>-laufi ] ).
        INSERT VALUE #( sign = zif_ca_ops_types=>gc_range-sign_include option = zif_ca_ops_types=>gc_range-option_equal
                        low = <ls_run>-laufi ) INTO TABLE et_ids.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
