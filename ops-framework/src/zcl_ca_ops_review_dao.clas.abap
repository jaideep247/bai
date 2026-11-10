*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_review_dao.clas.abap
*& Purpose:
*& SQL and lock of the daily control review (ZIF_CA_OPS_REVIEW_DAO): one
*& MODIFY of ZCA_OPS_REVIEW for all sign-offs of a save (no SELECT in a
*& loop, no commit) and the exclusive lock of one control and business date
*& through ENQUEUE_E_TABLE (generic table lock, released with the LUW).
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - daily control review SQL</p>
CLASS zcl_ca_ops_review_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_review_dao.

  PRIVATE SECTION.
    CONSTANTS gc_lock_table TYPE tabname VALUE 'ZCA_OPS_REVIEW'.
    CONSTANTS gc_exclusive  TYPE enqmode VALUE 'E'.
    "! Lock of the update task / end of the LUW (RAP save sequence)
    CONSTANTS gc_scope      TYPE ddenqscope VALUE '2'.

    METHODS varkey
      IMPORTING
        iv_area          TYPE zif_ca_ops_types=>ty_area
        iv_control_id    TYPE zif_ca_ops_ctl_types=>ty_control_id
        iv_business_date TYPE d
      RETURNING
        VALUE(rv_varkey) TYPE rstable-varkey.

ENDCLASS.



CLASS zcl_ca_ops_review_dao IMPLEMENTATION.

  METHOD zif_ca_ops_review_dao~lock.
    DATA lv_subrc TYPE sysubrc.
    DATA lv_holder TYPE syuname.
    DATA(lv_varkey) = varkey( iv_area = iv_area iv_control_id = iv_control_id iv_business_date = iv_business_date ).

    " VERIFY-SE37: ENQUEUE_E_TABLE parameters MODE_RSTABLE, TABNAME, VARKEY, _SCOPE (as ZCL_CA_OPS_LOCK)
    TEST-SEAM enqueue.
      CALL FUNCTION 'ENQUEUE_E_TABLE'
        EXPORTING
          mode_rstable   = gc_exclusive
          tabname        = gc_lock_table
          varkey         = lv_varkey
          _scope         = gc_scope
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.
      lv_subrc  = sy-subrc.
      lv_holder = sy-msgv1.
    END-TEST-SEAM.
    CASE lv_subrc.
      WHEN 0.
        RETURN.
      WHEN 1.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e079(zca_ops) WITH iv_control_id |{ iv_business_date DATE = ISO }| lv_holder.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e080(zca_ops) WITH iv_control_id |{ iv_business_date DATE = ISO }|.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_ca_ops_review_dao~save.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_review WITH EMPTY KEY.
    CHECK it_reviews IS NOT INITIAL.
    lt_rows = CORRESPONDING #( it_reviews ).
    MODIFY zca_ops_review FROM TABLE @lt_rows.
  ENDMETHOD.


  METHOD varkey.
    " Fixed positions of the ZCA_OPS_REVIEW key: MANDT (3), AREA (16), CONTROL_ID (20), BUSINESS_DATE (8)
    DATA lv_area TYPE zif_ca_ops_types=>ty_area.
    DATA lv_control_id TYPE zif_ca_ops_ctl_types=>ty_control_id.
    DATA lv_date TYPE d.
    lv_area       = iv_area.
    lv_control_id = iv_control_id.
    lv_date       = iv_business_date.
    CONCATENATE sy-mandt lv_area lv_control_id lv_date INTO rv_varkey RESPECTING BLANKS.
  ENDMETHOD.

ENDCLASS.
