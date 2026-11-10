*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_overdue_exc.clas.abap
*& Purpose:
*& Exception queues: owned exceptions of every suite payment engine area (ZCA_OPS_FINDING)
*& that are still open or assigned after their SLA due date.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Oldest overdue age is a level metric (MAX / AVG, audit A88).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-10 | Company-code isolation: metrics per area (DIM1) and company code of the exceptions (DIM2, metric company
*&            | code) - an overdue count never mixes two company codes.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - overdue exceptions per payment engine area</p>
"! Metrics per payment engine area (DIM1): OVERDUE (items past due date, disposition O
"! or A) and OLDEST_OVERDUE_DAYS. Thresholds in ZCD_HCK_THRESH.
CLASS zcl_cd_hck_c_overdue_exc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        overdue     TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVERDUE',
        oldest_days TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OLDEST_OVERDUE_DAYS',
      END OF gc_metric.

ENDCLASS.



CLASS zcl_cd_hck_c_overdue_exc IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lt_overdue) = zcl_cd_hck_factory=>get_dao( )->get_overdue_exceptions( is_context-now_date ).
    IF lt_overdue IS INITIAL.
      INSERT VALUE #( metric = gc_metric-overdue dim1 = zif_cd_hck_types=>gc_default_key value = 0 )
        INTO TABLE rs_result-metrics.
      RETURN.
    ENDIF.
    LOOP AT lt_overdue ASSIGNING FIELD-SYMBOL(<ls_overdue>).
      " company-code isolation: DIM2 and the metric's company code = company code of the exceptions
      INSERT VALUE #( metric       = gc_metric-overdue
                      dim1         = <ls_overdue>-pe_area
                      dim2         = <ls_overdue>-bukrs
                      value        = <ls_overdue>-item_count
                      company_code = <ls_overdue>-bukrs ) INTO TABLE rs_result-metrics.
      INSERT VALUE #( metric       = gc_metric-oldest_days
                      dim1         = <ls_overdue>-pe_area
                      dim2         = <ls_overdue>-bukrs
                      value        = is_context-now_date - <ls_overdue>-oldest_due
                      kind         = zif_cd_hck_types=>gc_metric_kind-level
                      company_code = <ls_overdue>-bukrs ) INTO TABLE rs_result-metrics.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
