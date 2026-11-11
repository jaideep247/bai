*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_analyzer.clas.abap
*& Purpose:
*& Clearing-account break analysis of an area at a key date (report
*& ZCA_OPS_BRK_RUN): authorisation ZCA_OPS execute (16) for the area; per
*& active account (ZCA_OPS_BRKACC) whose business process is in effect
*& (process catalogue), the bucket rules that apply (validated, ordered),
*& the configuration version (account, buckets, rules, conditions, BRK_
*& parameter values), the groups of the account that do not net to zero
*& (grouped on the database, oldest first, capped), then package by
*& package (BRK_PACKAGE_SIZE assignments) their lines up to the key date and
*& in the forward window, the linked objects the LINK conditions need
*& (link registry) and the classification (ZCL_CA_OPS_BRK_RULES); the
*& snapshot is saved and committed per account. A cap (groups, lines) makes
*& the snapshot partial - never silently complete. Test mode: nothing is
*& written. Read-only towards business data: no posting, no clearing.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - clearing-account break analysis</p>
"! Memory is bounded by BRK_MAX_GROUPS groups and BRK_MAX_ITEMS lines per account; the busiest account is read
"! in packages of assignments, each package one grouped-key read (docs/BREAK_ANALYSIS.md section 6).
CLASS zcl_ca_ops_brk_analyzer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter io_links | Linked objects (default ZCL_CA_OPS_BRK_LINKS; a double in tests)
    METHODS constructor
      IMPORTING
        io_links TYPE REF TO zif_ca_ops_brk_links OPTIONAL.

    "! Analyse the accounts of an area at a key date
    "! @parameter iv_acct_id   | One account (blank = every active account of the area)
    "! @parameter iv_key_date  | Lines posted up to this date are open at it
    "! @parameter iv_test_mode | X = nothing is written
    "! @parameter rt_results   | One result per account (snapshot, groups, lines, problems, skipped)
    "! @raising zcx_ca_ops_error | 041 not authorised, 010 the snapshot could not be saved
    METHODS analyze
      IMPORTING
        iv_area           TYPE zif_ca_ops_types=>ty_area
        iv_acct_id        TYPE zif_ca_ops_brk_types=>ty_acct_id OPTIONAL
        iv_key_date       TYPE d
        iv_test_mode      TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_results) TYPE zif_ca_ops_brk_types=>tt_analysis
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    "! The parameters of one analysis
    TYPES:
      BEGIN OF ty_limits,
        ledger     TYPE zif_ca_ops_brk_types=>ty_ledger,
        lookback   TYPE i,
        forward    TYPE i,
        max_groups TYPE i,
        package    TYPE i,
        max_items  TYPE i,
      END OF ty_limits.

    "! The configuration read once per analysis
    TYPES:
      BEGIN OF ty_config,
        buckets TYPE zif_ca_ops_brk_types=>tt_bucket,
        rules   TYPE zif_ca_ops_brk_types=>tt_rule,
        conds   TYPE zif_ca_ops_brk_types=>tt_cond,
        links   TYPE zif_ca_ops_link_types=>tt_link_id,
        params  TYPE zif_ca_ops_brk_types=>tt_param_list,
        limits  TYPE ty_limits,
      END OF ty_config.

    DATA mo_links TYPE REF TO zif_ca_ops_brk_links.

    METHODS read_config
      IMPORTING
        iv_area          TYPE zif_ca_ops_types=>ty_area
      RETURNING
        VALUE(rs_config) TYPE ty_config.

    METHODS analyze_account
      IMPORTING
        is_account       TYPE zif_ca_ops_brk_types=>ty_account
        is_config        TYPE ty_config
        iv_key_date      TYPE d
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_brk_types=>ty_analysis
      RAISING
        zcx_ca_ops_error.

    "! Version of the account's effective configuration (ZCL_CA_OPS_CFG_VERSION)
    METHODS version
      IMPORTING
        is_account        TYPE zif_ca_ops_brk_types=>ty_account
        is_config         TYPE ty_config
        it_rules          TYPE zif_ca_ops_brk_types=>tt_rule
        it_conds          TYPE zif_ca_ops_brk_types=>tt_cond
      RETURNING
        VALUE(rv_version) TYPE zif_ca_ops_types=>ty_cfg_version.

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

ENDCLASS.



CLASS zcl_ca_ops_brk_analyzer IMPLEMENTATION.

  METHOD constructor.
    mo_links = COND #( WHEN io_links IS BOUND THEN io_links ELSE NEW zcl_ca_ops_brk_links( ) ).
  ENDMETHOD.


  METHOD analyze.
    zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                            iv_area     = iv_area ).
    DATA(lo_dao) = zcl_ca_ops_factory=>get_brk_dao( ).
    DATA(ls_config) = read_config( iv_area ).
    DATA(lt_off) = zcl_ca_ops_factory=>get_catalog( )->inactive_onboarded(
                     iv_area = iv_area
                     iv_date = zcl_ca_ops_factory=>get_clock( )->today( ) ).

    LOOP AT lo_dao->get_accounts( iv_area = iv_area iv_acct_id = iv_acct_id ) ASSIGNING FIELD-SYMBOL(<ls_account>).
      IF <ls_account>-process_id IS NOT INITIAL AND line_exists( lt_off[ table_line = <ls_account>-process_id ] ).
        " the account's business process is not in effect (process catalogue): not analysed, nothing written
        INSERT VALUE #( snapshot = VALUE #( area = iv_area acct_id = <ls_account>-acct_id key_date = iv_key_date )
                        skipped  = abap_true
                        problems = VALUE #( ( msgno = zif_ca_ops_brk_types=>gc_msg-process_off
                                              v1    = <ls_account>-acct_id
                                              v2    = iv_area
                                              v3    = <ls_account>-process_id ) ) ) INTO TABLE rt_results.
        CONTINUE.
      ENDIF.
      DATA(ls_result) = analyze_account( is_account  = <ls_account>
                                         is_config   = ls_config
                                         iv_key_date = iv_key_date ).
      IF iv_test_mode = abap_false.
        lo_dao->save_snapshot( is_snapshot = ls_result-snapshot
                               it_groups   = ls_result-groups
                               it_items    = ls_result-items ).
        " one account, one unit of work: a later account's failure never undoes this snapshot
        lo_dao->commit( ).
      ENDIF.
      INSERT ls_result INTO TABLE rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_config.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_brk_dao( ).
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    rs_config-buckets = lo_dao->get_buckets( ).
    rs_config-rules   = lo_dao->get_rules( iv_area ).
    rs_config-conds   = lo_dao->get_conds( iv_area ).
    rs_config-links   = mo_links->effective_links( ).
    LOOP AT zcl_ca_ops_brk_rules=>param_names( rs_config-conds ) INTO DATA(lv_name).
      DATA(ls_list) = VALUE zif_ca_ops_brk_types=>ty_param_list( name = CONV #( lv_name ) ).
      " a list (comma separated) or a single value (e.g. a number of days) - the definition default when blank
      ls_list-values = zcl_ca_ops_util=>split_list( lo_params->get_param( CONV #( lv_name ) ) ).
      INSERT ls_list INTO TABLE rs_config-params.
    ENDLOOP.
    rs_config-limits-ledger = lo_params->get_param( iv_name    = zif_ca_ops_brk_types=>gc_param-ledger
                                                    iv_default = CONV #( zif_ca_ops_brk_types=>gc_default-ledger ) ).
    rs_config-limits-lookback   = int_param( iv_name    = zif_ca_ops_brk_types=>gc_param-lookback
                                             iv_default = zif_ca_ops_brk_types=>gc_default-lookback ).
    rs_config-limits-forward    = int_param( iv_name    = zif_ca_ops_brk_types=>gc_param-forward
                                             iv_default = zif_ca_ops_brk_types=>gc_default-forward ).
    rs_config-limits-max_groups = int_param( iv_name    = zif_ca_ops_brk_types=>gc_param-max_groups
                                             iv_default = zif_ca_ops_brk_types=>gc_default-max_groups ).
    rs_config-limits-package    = nmax( val1 = int_param( iv_name    = zif_ca_ops_brk_types=>gc_param-package
                                                          iv_default = zif_ca_ops_brk_types=>gc_default-package )
                                        val2 = 1 ).
    rs_config-limits-max_items  = int_param( iv_name    = zif_ca_ops_brk_types=>gc_param-max_items
                                             iv_default = zif_ca_ops_brk_types=>gc_default-max_items ).
  ENDMETHOD.


  METHOD analyze_account.
    DATA lt_rules TYPE zif_ca_ops_brk_types=>tt_rule.
    DATA lt_conds TYPE zif_ca_ops_brk_types=>tt_cond.
    DATA lt_package TYPE zif_ca_ops_brk_types=>tt_group_sum.
    DATA lt_range TYPE zif_ca_ops_brk_dao=>tt_assignment_range.
    DATA lt_fields TYPE zif_ca_ops_brk_links=>tt_link_field.
    DATA lt_hits TYPE zif_ca_ops_brk_types=>tt_hit.
    DATA lv_snap_id TYPE zif_ca_ops_types=>ty_run_id.

    DATA(lo_dao) = zcl_ca_ops_factory=>get_brk_dao( ).
    DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).
    DATA(ls_limits) = is_config-limits.
    DATA(lv_ledger) = COND zif_ca_ops_brk_types=>ty_ledger( WHEN is_account-ledger IS NOT INITIAL THEN is_account-ledger
                                                            ELSE ls_limits-ledger ).
    DATA(lv_lookback) = COND i( WHEN is_account-lookback_days > 0 THEN is_account-lookback_days ELSE ls_limits-lookback ).
    DATA(lv_forward) = COND i( WHEN is_account-forward_days > 0 THEN is_account-forward_days ELSE ls_limits-forward ).
    DATA(lv_max_groups) = COND i( WHEN is_account-max_groups > 0 THEN is_account-max_groups ELSE ls_limits-max_groups ).

    zcl_ca_ops_brk_rules=>effective_rules( EXPORTING it_rules    = is_config-rules
                                                     it_conds    = is_config-conds
                                                     it_buckets  = is_config-buckets
                                                     it_links    = is_config-links
                                                     it_params   = is_config-params
                                                     iv_area     = is_account-area
                                                     iv_acct_id  = is_account-acct_id
                                           IMPORTING et_rules    = lt_rules
                                                     et_conds    = lt_conds
                                                     et_problems = rs_result-problems ).
    LOOP AT lt_conds ASSIGNING FIELD-SYMBOL(<ls_cond>) WHERE cond_kind = zif_ca_ops_brk_types=>gc_kind-link.
      INSERT VALUE #( link_id = <ls_cond>-link_id field = to_upper( condense( <ls_cond>-field ) ) ) INTO TABLE lt_fields.
    ENDLOOP.

    TRY.
        lv_snap_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e001(zca_ops)
          EXPORTING
            previous = lx_uuid.
    ENDTRY.
    rs_result-snapshot = VALUE #( snap_id     = lv_snap_id
                                  area        = is_account-area
                                  acct_id     = is_account-acct_id
                                  bukrs       = is_account-bukrs
                                  hkont       = is_account-hkont
                                  ledger      = lv_ledger
                                  key_date    = iv_key_date
                                  from_date   = iv_key_date - lv_lookback
                                  to_date     = iv_key_date + lv_forward
                                  status      = zif_ca_ops_brk_types=>gc_status-complete
                                  cfg_version = version( is_account = is_account is_config = is_config
                                                         it_rules   = lt_rules   it_conds  = lt_conds )
                                  started_at  = lo_clock->now( )
                                  created_by  = sy-uname ).

    DATA(lt_sums) = lo_dao->open_groups( is_account  = is_account
                                         iv_ledger   = lv_ledger
                                         iv_from     = rs_result-snapshot-from_date
                                         iv_key_date = iv_key_date
                                         iv_max      = lv_max_groups ).
    IF lines( lt_sums ) >= lv_max_groups.
      rs_result-snapshot-status = zif_ca_ops_brk_types=>gc_status-partial.
      rs_result-snapshot-message = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_brk_types=>gc_msg-group_cap
                                                          iv_v1    = is_account-acct_id
                                                          iv_v2    = lv_max_groups ).
    ENDIF.

    DATA(lv_lines_left) = ls_limits-max_items.
    DATA(lv_index) = 0.
    WHILE lv_index < lines( lt_sums ).
      DATA(lv_last) = nmin( val1 = lv_index + ls_limits-package val2 = lines( lt_sums ) ).
      lt_package = VALUE #( FOR i = lv_index + 1 THEN i + 1 UNTIL i > lv_last ( lt_sums[ i ] ) ).
      lt_range = VALUE #( FOR ls_sum IN lt_package ( sign   = zif_ca_ops_types=>gc_range-sign_include
                                                     option = zif_ca_ops_types=>gc_range-option_equal
                                                     low    = ls_sum-assignment ) ).
      SORT lt_range BY low.
      DELETE ADJACENT DUPLICATES FROM lt_range COMPARING low.
      DATA(lt_items) = lo_dao->group_lines( is_account     = is_account
                                            iv_ledger      = lv_ledger
                                            iv_from        = rs_result-snapshot-from_date
                                            iv_to          = rs_result-snapshot-to_date
                                            iv_key_date    = iv_key_date
                                            it_assignments = lt_range
                                            iv_max         = lv_lines_left ).
      IF lines( lt_items ) >= lv_lines_left.
        " the package may be cut: not classified, the snapshot keeps the groups before it
        rs_result-snapshot-status = zif_ca_ops_brk_types=>gc_status-partial.
        rs_result-snapshot-message = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_brk_types=>gc_msg-item_cap
                                                            iv_v1    = is_account-acct_id
                                                            iv_v2    = ls_limits-max_items
                                                            iv_v3    = lv_index ).
        EXIT.
      ENDIF.
      lv_lines_left -= lines( lt_items ).
      lv_index = lv_last.

      CLEAR lt_hits.
      IF lt_fields IS NOT INITIAL.
        mo_links->read( EXPORTING iv_area     = is_account-area
                                  it_fields   = lt_fields
                                  it_items    = lt_items
                        IMPORTING et_hits     = lt_hits
                                  et_problems = DATA(lt_link_problems) ).
        LOOP AT lt_link_problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
          IF NOT line_exists( rs_result-problems[ msgno = <ls_problem>-msgno v1 = <ls_problem>-v1 ] ).
            INSERT <ls_problem> INTO TABLE rs_result-problems.
          ENDIF.
        ENDLOOP.
      ENDIF.
      zcl_ca_ops_brk_rules=>classify( EXPORTING is_context  = VALUE #( acct_id = is_account-acct_id key_date = iv_key_date )
                                                it_sums     = lt_package
                                                it_items    = lt_items
                                                it_rules    = lt_rules
                                                it_conds    = lt_conds
                                                it_hits     = lt_hits
                                                it_params   = is_config-params
                                                it_buckets  = is_config-buckets
                                                iv_group_no = lines( rs_result-groups )
                                      IMPORTING et_groups   = DATA(lt_groups)
                                                et_items    = DATA(lt_classified) ).
      INSERT LINES OF lt_groups INTO TABLE rs_result-groups.
      INSERT LINES OF lt_classified INTO TABLE rs_result-items.
    ENDWHILE.

    rs_result-snapshot-group_count = lines( rs_result-groups ).
    rs_result-snapshot-item_count  = lines( rs_result-items ).
    rs_result-snapshot-other_count = REDUCE i( INIT n = 0 FOR ls_group IN rs_result-groups
                                               WHERE ( bucket = zif_ca_ops_brk_types=>gc_bucket_other ) NEXT n = n + 1 ).
    rs_result-snapshot-ended_at = lo_clock->now( ).
    IF rs_result-snapshot-message IS INITIAL.
      rs_result-snapshot-message = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_brk_types=>gc_msg-summary
                                                          iv_v1    = is_account-acct_id
                                                          iv_v2    = iv_key_date
                                                          iv_v3    = rs_result-snapshot-group_count
                                                          iv_v4    = rs_result-snapshot-other_count ).
    ENDIF.
  ENDMETHOD.


  METHOD version.
    DATA lt_lines TYPE string_table.
    DATA(ls_account) = is_account.
    CLEAR ls_account-description.
    INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_brk_types=>gc_object_type-account is_row = ls_account )
           INTO TABLE lt_lines.
    LOOP AT is_config-buckets INTO DATA(ls_bucket) WHERE active = abap_true.
      CLEAR ls_bucket-description.
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_brk_types=>gc_kind-group is_row = ls_bucket )
             INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT it_rules INTO DATA(ls_rule).
      CLEAR ls_rule-description.
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_brk_types=>gc_object_type-rule is_row = ls_rule )
             INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>).
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_brk_types=>gc_kind-field is_row = <ls_cond> )
             INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT is_config-params ASSIGNING FIELD-SYMBOL(<ls_param>).
      INSERT zcl_ca_ops_cfg_version=>line(
               iv_kind = zif_ca_ops_brk_types=>gc_param_marker
               is_row  = |{ <ls_param>-name }={ concat_lines_of( table = <ls_param>-values
                                                                 sep   = zif_ca_ops_brk_types=>gc_list_separator ) }| )
             INTO TABLE lt_lines.
    ENDLOOP.
    INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_brk_types=>gc_param_marker is_row = is_config-limits )
           INTO TABLE lt_lines.
    rv_version = zcl_ca_ops_cfg_version=>of_lines( lt_lines ).
  ENDMETHOD.


  METHOD int_param.
    rv_value = zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                           iv_name    = iv_name
                                           iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
