*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_pay_ageing.clas.abap
*& Purpose:
*& The one ageing rule of a payment in flight, shared by the morning report
*& check A_INFLIGHT and the payment worklist (ZCL_CD_OPS_PAY_SNAPSHOT marks a
*& late payment as an exception): VALUE_DATE classes (wire, ACH, card) are
*& aged in business days after the value date (the run date when it is
*& missing) in the calendar of the house bank (posting area ZPMC entry with
*& HBKID), else of the method class, else the default calendar (A_INFLIGHT
*& PARAM1); ISSUE_DATE classes (cheques) in calendar days since the run date.
*& The RAG of an age is the AGE_OLDEST threshold of the flow + class
*& (ZCD_HCK_THRESH: AMBER = late, RED = critical; not maintained = never
*& late). Each calendar is read once per run into a day table (working days
*& in ( date, today ], at most the last 400 days, built downwards as far as
*& the oldest payment needs it) - never one calendar read per payment. Also
*& the business-day test of a single date (due date of a payment request).
*& Reads only through ZIF_CD_HCK_DAO=>IS_WORKING_DAY (factory).
*& Modification log:
*& 2026-11-08 | Initial version: ageing extracted unchanged from ZCL_CD_HCK_C_INFLIGHT (exceptions-only
*&            | worklist: the snapshot judges lateness with the same rule).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - age of a payment in flight (shared rule)</p>
"! One instance per run (day tables per calendar). Configuration from the canonical evaluator
"! (ZIF_CD_OPS_PAY_OUTCOME=>LOAD: classes, house-bank rows, watched keys), thresholds of A_INFLIGHT.
CLASS zcl_cd_hck_pay_ageing DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Age of a payment in flight
    TYPES:
      BEGIN OF ty_age,
        "! Date the age counts from: value date (VALUE_DATE classes) or run date
        ref_date TYPE d,
        "! A VALUE_DATE class without value date: aged from the run date (VALUE_DATE_MISSING)
        no_valut TYPE abap_bool,
        "! Business days (VALUE_DATE) or calendar days (ISSUE_DATE)
        age      TYPE i,
        "! AMBER = late, RED = critical, initial = within the limits or no limits maintained
        rag      TYPE zif_cd_ops_types=>ty_rag,
      END OF ty_age.

    METHODS constructor
      IMPORTING
        it_classes    TYPE zif_cd_hck_runtime_types=>tt_pm_class
        it_banks      TYPE zif_cd_hck_runtime_types=>tt_pm_class
        it_watched    TYPE zif_cd_ops_payout_types=>tt_flow_class
        iv_calendar   TYPE zif_cd_hck_types=>ty_calendar
        it_thresholds TYPE zif_cd_hck_types=>tt_threshold
        iv_today      TYPE d.

    "! Age and RAG of a payment of the flow + class (run date, value date, house bank)
    METHODS age_of
      IMPORTING
        iv_key        TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_laufd      TYPE d
        iv_valut      TYPE d
        iv_hbkid      TYPE zif_cd_hck_runtime_types=>ty_hbkid
      RETURNING
        VALUE(rs_age) TYPE ty_age.

    "! ISSUE_DATE class: calendar days after the run date
    METHODS is_issue_basis
      IMPORTING
        iv_key        TYPE zif_cd_hck_runtime_types=>ty_flow_class
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! Calendar of the payment: house bank row, method class, default (A_INFLIGHT PARAM1)
    METHODS calendar_of
      IMPORTING
        iv_key             TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_hbkid           TYPE zif_cd_hck_runtime_types=>ty_hbkid
      RETURNING
        VALUE(rv_calendar) TYPE zif_cd_hck_types=>ty_calendar.

    "! Working days in ( max( iv_after, today - 400 ), today ] of the calendar (blank calendar: days)
    METHODS business_days
      IMPORTING
        iv_after       TYPE d
        iv_calendar    TYPE zif_cd_hck_types=>ty_calendar
      RETURNING
        VALUE(rv_days) TYPE i.

    "! RAG of an age against AGE_OLDEST of the flow + class (initial: limits not maintained)
    METHODS rag_of
      IMPORTING
        iv_key        TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_age        TYPE i
      RETURNING
        VALUE(rv_rag) TYPE zif_cd_ops_types=>ty_rag.

    "! AMBER or RED of AGE_OLDEST is maintained for the watched flow + class
    METHODS limits_set
      IMPORTING
        iv_key        TYPE zif_cd_hck_runtime_types=>ty_flow_class
      RETURNING
        VALUE(rv_set) TYPE abap_bool.

    "! The date is a business day of the calendar (blank calendar: every day); one read per date
    METHODS is_business_day
      IMPORTING
        iv_calendar   TYPE zif_cd_hck_types=>ty_calendar
        iv_date       TYPE d
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

  PRIVATE SECTION.
    "! AGE_OLDEST limits of a watched flow + class (SET = amber or red maintained)
    TYPES:
      BEGIN OF ty_limit,
        key   TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        limit TYPE zif_cd_hck_types=>ty_threshold,
        set   TYPE abap_bool,
      END OF ty_limit.
    TYPES tt_limit TYPE HASHED TABLE OF ty_limit WITH UNIQUE KEY key.

    "! Business days per calendar: working days in ( DATE, today ], built once per run downwards
    TYPES:
      BEGIN OF ty_cum,
        calendar TYPE zif_cd_hck_types=>ty_calendar,
        date     TYPE d,
        days     TYPE i,
      END OF ty_cum.
    TYPES tt_cum TYPE HASHED TABLE OF ty_cum WITH UNIQUE KEY calendar date.
    TYPES:
      BEGIN OF ty_cal_low,
        calendar TYPE zif_cd_hck_types=>ty_calendar,
        low      TYPE d,
      END OF ty_cal_low.
    TYPES tt_cal_low TYPE HASHED TABLE OF ty_cal_low WITH UNIQUE KEY calendar.
    "! A single date of a calendar (business-day test of a due date)
    TYPES:
      BEGIN OF ty_day,
        calendar TYPE zif_cd_hck_types=>ty_calendar,
        date     TYPE d,
        working  TYPE abap_bool,
      END OF ty_day.
    TYPES tt_day TYPE HASHED TABLE OF ty_day WITH UNIQUE KEY calendar date.

    DATA mt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_banks TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_limits TYPE tt_limit.
    DATA mt_cum TYPE tt_cum.
    DATA mt_cal_low TYPE tt_cal_low.
    DATA mt_days TYPE tt_day.
    DATA mv_calendar TYPE zif_cd_hck_types=>ty_calendar.
    DATA mv_today TYPE d.
    DATA mo_dao TYPE REF TO zif_cd_hck_dao.

ENDCLASS.



CLASS zcl_cd_hck_pay_ageing IMPLEMENTATION.

  METHOD constructor.
    mt_classes  = it_classes.
    mt_banks    = it_banks.
    mv_calendar = to_upper( condense( iv_calendar ) ).
    mv_today    = iv_today.
    " AGE_OLDEST limits once per watched flow + class; a key without limits is never late
    LOOP AT it_watched ASSIGNING FIELD-SYMBOL(<lv_key>).
      DATA(ls_limit) = VALUE ty_limit( key   = <lv_key>
                                       limit = zcl_cd_hck_threshold=>resolve( it_thresholds = it_thresholds
                                                                              iv_metric     = zcl_cd_hck_c_inflight=>gc_metric-age_oldest
                                                                              iv_key        = <lv_key> ) ).
      ls_limit-limit-baseline_mode = zif_cd_hck_types=>gc_baseline-none.
      ls_limit-set = xsdbool( ls_limit-limit-amber <> 0 OR ls_limit-limit-red <> 0 ).
      INSERT ls_limit INTO TABLE mt_limits.
    ENDLOOP.
  ENDMETHOD.


  METHOD age_of.
    DATA(lv_issue) = is_issue_basis( iv_key ).
    rs_age-no_valut = xsdbool( lv_issue = abap_false AND iv_valut IS INITIAL ).
    rs_age-ref_date = COND #( WHEN lv_issue = abap_true OR iv_valut IS INITIAL THEN iv_laufd ELSE iv_valut ).
    rs_age-age = COND #( WHEN lv_issue = abap_true
                           " Issue date basis (e.g. cheques): calendar days since issue (run date)
                           THEN nmax( val1 = 0 val2 = mv_today - rs_age-ref_date )
                         " Value date basis (wire / ACH / card): business days after the value date
                         ELSE business_days( iv_after    = rs_age-ref_date
                                             iv_calendar = calendar_of( iv_key = iv_key iv_hbkid = iv_hbkid ) ) ).
    rs_age-rag = rag_of( iv_key = iv_key iv_age = rs_age-age ).
  ENDMETHOD.


  METHOD is_issue_basis.
    rv_yes = xsdbool( VALUE #( mt_classes[ flow = iv_key(1) method_class = iv_key+1(3) hbkid = space ]-age_basis OPTIONAL )
                      = zif_cd_hck_runtime_types=>gc_age_basis-issue_date ).
  ENDMETHOD.


  METHOD calendar_of.
    rv_calendar = VALUE #( mt_banks[ flow = iv_key(1) method_class = iv_key+1(3) hbkid = iv_hbkid ]-calendar OPTIONAL ).
    IF rv_calendar IS INITIAL.
      rv_calendar = VALUE #( mt_classes[ flow = iv_key(1) method_class = iv_key+1(3) hbkid = space ]-calendar
                             OPTIONAL ).
    ENDIF.
    IF rv_calendar IS INITIAL.
      rv_calendar = mv_calendar.
    ENDIF.
    rv_calendar = to_upper( rv_calendar ).
  ENDMETHOD.


  METHOD business_days.
    IF mv_today <= iv_after.
      RETURN.
    ENDIF.
    IF iv_calendar IS INITIAL.
      rv_days = mv_today - iv_after.
      RETURN.
    ENDIF.
    " Bounded as before: at most the last 400 days are counted
    DATA(lv_from) = CONV d( nmax( val1 = iv_after
                                  val2 = mv_today - zif_cd_hck_runtime_types=>gc_check_default-max_calendar ) ).
    " The day table of the calendar grows downwards only as far as a payment needs it (one calendar
    " read per calendar and date per run - never per payment)
    READ TABLE mt_cal_low ASSIGNING FIELD-SYMBOL(<ls_low>) WITH TABLE KEY calendar = iv_calendar.
    IF sy-subrc <> 0.
      INSERT VALUE #( calendar = iv_calendar low = mv_today ) INTO TABLE mt_cal_low ASSIGNING <ls_low>.
      INSERT VALUE #( calendar = iv_calendar date = mv_today days = 0 ) INTO TABLE mt_cum.
    ENDIF.
    IF <ls_low>-low > lv_from.
      DATA(lv_days) = mt_cum[ calendar = iv_calendar date = <ls_low>-low ]-days.
      WHILE <ls_low>-low > lv_from.
        IF is_business_day( iv_calendar = iv_calendar iv_date = <ls_low>-low ) = abap_true.
          lv_days = lv_days + 1.
        ENDIF.
        <ls_low>-low = <ls_low>-low - 1.
        INSERT VALUE #( calendar = iv_calendar date = <ls_low>-low days = lv_days ) INTO TABLE mt_cum.
      ENDWHILE.
    ENDIF.
    rv_days = mt_cum[ calendar = iv_calendar date = lv_from ]-days.
  ENDMETHOD.


  METHOD rag_of.
    READ TABLE mt_limits ASSIGNING FIELD-SYMBOL(<ls_limit>) WITH TABLE KEY key = iv_key.
    IF sy-subrc <> 0 OR <ls_limit>-set = abap_false.
      RETURN.
    ENDIF.
    rv_rag = zcl_cd_hck_threshold=>evaluate( iv_value     = iv_age
                                             is_threshold = <ls_limit>-limit
                                             it_history   = VALUE #( ) )-rag.
  ENDMETHOD.


  METHOD limits_set.
    rv_set = VALUE #( mt_limits[ key = iv_key ]-set OPTIONAL ).
  ENDMETHOD.


  METHOD is_business_day.
    IF iv_calendar IS INITIAL.
      rv_yes = abap_true.
      RETURN.
    ENDIF.
    READ TABLE mt_days ASSIGNING FIELD-SYMBOL(<ls_day>) WITH TABLE KEY calendar = iv_calendar date = iv_date.
    IF sy-subrc <> 0.
      IF mo_dao IS NOT BOUND.
        mo_dao = zcl_cd_hck_factory=>get_dao( ).
      ENDIF.
      INSERT VALUE #( calendar = iv_calendar
                      date     = iv_date
                      working  = mo_dao->is_working_day( iv_calendar = iv_calendar iv_date = iv_date ) )
        INTO TABLE mt_days ASSIGNING <ls_day>.
    ENDIF.
    rv_yes = <ls_day>-working.
  ENDMETHOD.

ENDCLASS.
