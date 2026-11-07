*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_recon_eval.clas.abap
*& Purpose:
*& Pure rules of the three-way reconciliation (no SQL, no parameters):
*& per set and posting day the bank leg (signed by the leg mapping, bank
*& codes by their role), the G/L leg (payment engine transfer and other
*& postings of the clearing account) and the payment engine control total;
*& differences, timing (statement not yet loaded / offsetting days), the
*& variance buckets (cut-off, pending redeposit, cheque, unmapped code,
*& other) and the residual break; Stripe descriptor groups (charges + fees
*& = deposit) and unmatched ACH assignment groups. Group level only: no
*& line is matched to another.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - three-way reconciliation rules (pure)</p>
"! Called by ZCL_CD_HCK_C_RECON3 with the grouped reads of ZIF_CD_HCK_RECON_DAO.
"! A day without any evidence is EMPTY (grey), never BALANCED.
CLASS zcl_cd_hck_recon_eval DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Group days of one THREEWAY / ACH_ZUONR set from the first to the last day of the window
    METHODS evaluate
      IMPORTING
        is_input         TYPE zif_cd_hck_recon_types=>ty_eval_input
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_recon_types=>ty_eval_result.

    "! Stripe descriptor groups of the deposits: charges + fees (G/L lines of the descriptor on the
    "! clearing account without the deposit documents' own lines) against the BAI deposit
    METHODS evaluate_stripe
      IMPORTING
        is_input         TYPE zif_cd_hck_recon_types=>ty_eval_input
        it_deposits      TYPE zif_cd_hck_recon_types=>tt_deposit
        it_doc_assign    TYPE zif_cd_hck_recon_types=>tt_doc_assign
        it_group_sums    TYPE zif_cd_hck_recon_types=>tt_assign_sum
      RETURNING
        VALUE(rt_groups) TYPE zif_cd_hck_recon_types=>tt_stripe_group.

    "! Unmatched ACH assignment groups (one-to-one clearing by ZUONR) per first day in the window:
    "! TIMING while younger than the timing days, BREAK after
    METHODS evaluate_ach
      IMPORTING
        is_input       TYPE zif_cd_hck_recon_types=>ty_eval_input
        it_open        TYPE zif_cd_hck_recon_types=>tt_open_assign
      RETURNING
        VALUE(rt_days) TYPE zif_cd_hck_recon_types=>tt_ach_day.

    "! Signed bank amount: credit positive, debit negative; inverted by the leg mapping
    METHODS signed_bank
      IMPORTING
        is_input         TYPE zif_cd_hck_recon_types=>ty_eval_input
        iv_cdi           TYPE zif_cd_hck_recon_types=>ty_cdi
        iv_amount        TYPE zif_cd_hck_recon_types=>ty_amount
      RETURNING
        VALUE(rv_amount) TYPE zif_cd_hck_recon_types=>ty_amount.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_bucket_amount,
        bucket TYPE zif_cd_hck_recon_types=>ty_bucket,
        amount TYPE zif_cd_hck_recon_types=>ty_amount,
      END OF ty_bucket_amount.
    TYPES tt_bucket_amount TYPE STANDARD TABLE OF ty_bucket_amount WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_day_work,
        day     TYPE d,
        buckets TYPE tt_bucket_amount,
      END OF ty_day_work.
    TYPES tt_day_work TYPE SORTED TABLE OF ty_day_work WITH UNIQUE KEY day.

    METHODS role_of
      IMPORTING
        is_input       TYPE zif_cd_hck_recon_types=>ty_eval_input
        iv_btc         TYPE zif_cd_hck_recon_types=>ty_btc
      RETURNING
        VALUE(rv_role) TYPE zif_cd_hck_recon_types=>ty_role.

    METHODS add_bucket
      IMPORTING
        iv_bucket  TYPE zif_cd_hck_recon_types=>ty_bucket
        iv_amount  TYPE zif_cd_hck_recon_types=>ty_amount
      CHANGING
        ct_buckets TYPE tt_bucket_amount.

    METHODS add_unmapped
      IMPORTING
        iv_btc      TYPE zif_cd_hck_recon_types=>ty_btc
        iv_amount   TYPE zif_cd_hck_recon_types=>ty_amount
        iv_lines    TYPE i
      CHANGING
        ct_unmapped TYPE zif_cd_hck_recon_types=>tt_unmapped.

    "! Bank, G/L and payment engine legs of one day (statuses not yet set)
    METHODS day_legs
      IMPORTING
        is_input    TYPE zif_cd_hck_recon_types=>ty_eval_input
        iv_day      TYPE d
      EXPORTING
        es_day      TYPE zif_cd_hck_recon_types=>ty_group_day
        et_buckets  TYPE tt_bucket_amount
      CHANGING
        ct_unmapped TYPE zif_cd_hck_recon_types=>tt_unmapped.

    "! Differences above the tolerance that offset each other within the timing days are timing
    "! (the statement or the transfer of one day arrived on a later day)
    METHODS mark_offsetting
      IMPORTING
        is_input       TYPE zif_cd_hck_recon_types=>ty_eval_input
        iv_subledger   TYPE abap_bool
      CHANGING
        ct_days        TYPE zif_cd_hck_recon_types=>tt_group_day.

    "! Buckets in allocation order reduce the residual only while they bring it nearer to zero
    METHODS allocate_buckets
      IMPORTING
        is_input   TYPE zif_cd_hck_recon_types=>ty_eval_input
        it_buckets TYPE tt_bucket_amount
      CHANGING
        cs_day     TYPE zif_cd_hck_recon_types=>ty_group_day.

    METHODS within_tolerance
      IMPORTING
        is_input      TYPE zif_cd_hck_recon_types=>ty_eval_input
        iv_amount     TYPE zif_cd_hck_recon_types=>ty_amount
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_hck_recon_eval IMPLEMENTATION.

  METHOD evaluate.
    DATA lt_work TYPE tt_day_work.
    DATA lv_day TYPE d.

    IF is_input-from IS INITIAL OR is_input-to < is_input-from.
      RETURN.
    ENDIF.

    lv_day = is_input-from.
    WHILE lv_day <= is_input-to.
      day_legs( EXPORTING is_input    = is_input
                          iv_day      = lv_day
                IMPORTING es_day      = DATA(ls_day)
                          et_buckets  = DATA(lt_buckets)
                CHANGING  ct_unmapped = rs_result-unmapped ).
      INSERT ls_day INTO TABLE rs_result-days.
      INSERT VALUE #( day = lv_day buckets = lt_buckets ) INTO TABLE lt_work.
      lv_day = lv_day + 1.
    ENDWHILE.

    " 1. Statement not yet loaded for the day and still within the timing days: timing
    LOOP AT rs_result-days ASSIGNING FIELD-SYMBOL(<ls_day>) WHERE status IS INITIAL.
      IF within_tolerance( is_input = is_input iv_amount = <ls_day>-diff_bank_gl ) = abap_true.
        <ls_day>-status = zif_cd_hck_recon_types=>gc_status-balanced.
      ELSEIF <ls_day>-day > is_input-last_bank_day
             AND is_input-report_date - <ls_day>-day <= is_input-timing_days.
        <ls_day>-status = zif_cd_hck_recon_types=>gc_status-timing.
        <ls_day>-residual = <ls_day>-diff_bank_gl.
        INSERT zif_cd_hck_recon_types=>gc_bucket-timing INTO TABLE <ls_day>-buckets.
      ENDIF.
    ENDLOOP.
    " 2. Offsetting differences within the timing days (statement / value date of the next day)
    mark_offsetting( EXPORTING is_input     = is_input
                               iv_subledger = abap_false
                     CHANGING  ct_days      = rs_result-days ).
    " 3. Variance buckets; what they cannot explain is a break
    LOOP AT rs_result-days ASSIGNING <ls_day> WHERE status IS INITIAL.
      allocate_buckets( EXPORTING is_input   = is_input
                                  it_buckets = lt_work[ day = <ls_day>-day ]-buckets
                        CHANGING  cs_day     = <ls_day> ).
    ENDLOOP.

    " G/L <-> payment engine control total: balanced, offsetting, recent (transfer lag) or break
    LOOP AT rs_result-days ASSIGNING <ls_day> WHERE sub_status IS INITIAL.
      IF within_tolerance( is_input = is_input iv_amount = <ls_day>-diff_gl_fica ) = abap_true.
        <ls_day>-sub_status = zif_cd_hck_recon_types=>gc_status-balanced.
      ENDIF.
    ENDLOOP.
    mark_offsetting( EXPORTING is_input     = is_input
                               iv_subledger = abap_true
                     CHANGING  ct_days      = rs_result-days ).
    LOOP AT rs_result-days ASSIGNING <ls_day> WHERE sub_status IS INITIAL.
      <ls_day>-sub_status = COND #( WHEN is_input-report_date - <ls_day>-day <= is_input-timing_days
                                    THEN zif_cd_hck_recon_types=>gc_status-timing
                                    ELSE zif_cd_hck_recon_types=>gc_status-break ).
    ENDLOOP.
  ENDMETHOD.


  METHOD day_legs.
    DATA lv_redeposit TYPE zif_cd_hck_recon_types=>ty_amount.

    CLEAR: es_day, et_buckets.
    es_day-day = iv_day.

    LOOP AT is_input-bank_days ASSIGNING FIELD-SYMBOL(<ls_bank>) WHERE day = iv_day.
      DATA(lv_signed) = signed_bank( is_input = is_input iv_cdi = <ls_bank>-cdi iv_amount = <ls_bank>-amount ).
      DATA(lv_role) = role_of( is_input = is_input iv_btc = <ls_bank>-btc ).
      IF lv_role = zif_cd_hck_recon_types=>gc_role-ignore.
        CONTINUE.
      ENDIF.
      es_day-bank       = es_day-bank + lv_signed.
      es_day-bank_lines = es_day-bank_lines + <ls_bank>-line_count.
      CASE lv_role.
        WHEN zif_cd_hck_recon_types=>gc_role-cutoff.
          add_bucket( EXPORTING iv_bucket  = zif_cd_hck_recon_types=>gc_bucket-cutoff
                                iv_amount  = lv_signed
                      CHANGING  ct_buckets = et_buckets ).
        WHEN zif_cd_hck_recon_types=>gc_role-cheque.
          add_bucket( EXPORTING iv_bucket  = zif_cd_hck_recon_types=>gc_bucket-cheque
                                iv_amount  = lv_signed
                      CHANGING  ct_buckets = et_buckets ).
        WHEN zif_cd_hck_recon_types=>gc_role-other.
          add_bucket( EXPORTING iv_bucket  = zif_cd_hck_recon_types=>gc_bucket-other
                                iv_amount  = lv_signed
                      CHANGING  ct_buckets = et_buckets ).
        WHEN space.
          add_bucket( EXPORTING iv_bucket  = zif_cd_hck_recon_types=>gc_bucket-unmapped
                                iv_amount  = lv_signed
                      CHANGING  ct_buckets = et_buckets ).
          add_unmapped( EXPORTING iv_btc      = <ls_bank>-btc
                                  iv_amount   = lv_signed
                                  iv_lines    = <ls_bank>-line_count
                        CHANGING  ct_unmapped = ct_unmapped ).
      ENDCASE.
    ENDLOOP.

    " A failure with delayed redeposit (468) without a returns lot is pending for the redeposit
    " days; a lot means the payment engine has posted the return (it is part of the leg then)
    IF is_input-report_date - iv_day <= is_input-redeposit_days.
      LOOP AT is_input-bank_no_lot ASSIGNING FIELD-SYMBOL(<ls_no_lot>) WHERE day = iv_day.
        IF role_of( is_input = is_input iv_btc = <ls_no_lot>-btc ) = zif_cd_hck_recon_types=>gc_role-redeposit.
          lv_redeposit = lv_redeposit + signed_bank( is_input  = is_input
                                                     iv_cdi    = <ls_no_lot>-cdi
                                                     iv_amount = <ls_no_lot>-amount ).
        ENDIF.
      ENDLOOP.
      add_bucket( EXPORTING iv_bucket  = zif_cd_hck_recon_types=>gc_bucket-redeposit
                            iv_amount  = lv_redeposit
                  CHANGING  ct_buckets = et_buckets ).
    ENDIF.

    LOOP AT is_input-gl_days ASSIGNING FIELD-SYMBOL(<ls_gl>) WHERE day = iv_day.
      IF <ls_gl>-awtyp = is_input-fica_awtyp.
        es_day-gl_fica = es_day-gl_fica + <ls_gl>-amount.
      ELSE.
        es_day-gl_other = es_day-gl_other + <ls_gl>-amount.
      ENDIF.
      es_day-gl_lines = es_day-gl_lines + <ls_gl>-line_count.
    ENDLOOP.
    LOOP AT is_input-fica_days ASSIGNING FIELD-SYMBOL(<ls_fica>) WHERE day = iv_day.
      es_day-fica       = es_day-fica + <ls_fica>-amount.
      es_day-fica_lines = es_day-fica_lines + <ls_fica>-line_count.
    ENDLOOP.
    LOOP AT is_input-pay_days ASSIGNING FIELD-SYMBOL(<ls_pay>) WHERE day = iv_day.
      es_day-payments = es_day-payments + <ls_pay>-amount.
    ENDLOOP.

    IF es_day-bank_lines = 0 AND es_day-gl_lines = 0 AND es_day-fica_lines = 0.
      es_day-status     = zif_cd_hck_recon_types=>gc_status-empty.
      es_day-sub_status = zif_cd_hck_recon_types=>gc_status-empty.
      RETURN.
    ENDIF.
    IF is_input-set-leg_bank = abap_true.
      es_day-diff_bank_gl = es_day-bank - es_day-gl_fica.
    ELSE.
      es_day-status = zif_cd_hck_recon_types=>gc_status-none.
    ENDIF.
    IF is_input-set-leg_fica = abap_true.
      es_day-diff_gl_fica = es_day-gl_fica - es_day-fica.
    ELSE.
      es_day-sub_status = zif_cd_hck_recon_types=>gc_status-none.
    ENDIF.
  ENDMETHOD.


  METHOD mark_offsetting.
    DATA lv_sum TYPE zif_cd_hck_recon_types=>ty_amount.

    LOOP AT ct_days ASSIGNING FIELD-SYMBOL(<ls_day>).
      DATA(lv_index) = sy-tabix.
      DATA(lv_status) = COND zif_cd_hck_recon_types=>ty_status( WHEN iv_subledger = abap_true THEN <ls_day>-sub_status
                                                                ELSE <ls_day>-status ).
      IF lv_status IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      lv_sum = COND #( WHEN iv_subledger = abap_true THEN <ls_day>-diff_gl_fica ELSE <ls_day>-diff_bank_gl ).
      DATA(lv_last) = 0.
      DATA(lv_next) = lv_index + 1.
      WHILE lv_next <= lv_index + is_input-timing_days AND lv_next <= lines( ct_days ).
        DATA(ls_next) = ct_days[ lv_next ].
        lv_sum = lv_sum + COND #( WHEN iv_subledger = abap_true THEN ls_next-diff_gl_fica ELSE ls_next-diff_bank_gl ).
        IF within_tolerance( is_input = is_input iv_amount = lv_sum ) = abap_true.
          lv_last = lv_next.
          EXIT.
        ENDIF.
        lv_next = lv_next + 1.
      ENDWHILE.
      IF lv_last = 0.
        CONTINUE.
      ENDIF.
      LOOP AT ct_days ASSIGNING FIELD-SYMBOL(<ls_offset>) FROM lv_index TO lv_last.
        IF iv_subledger = abap_true.
          IF <ls_offset>-sub_status IS INITIAL.
            <ls_offset>-sub_status = zif_cd_hck_recon_types=>gc_status-timing.
          ENDIF.
        ELSEIF <ls_offset>-status IS INITIAL.
          <ls_offset>-status   = zif_cd_hck_recon_types=>gc_status-timing.
          <ls_offset>-residual = <ls_offset>-diff_bank_gl.
          INSERT zif_cd_hck_recon_types=>gc_bucket-timing INTO TABLE <ls_offset>-buckets.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD allocate_buckets.
    DATA lv_only_timing TYPE abap_bool VALUE abap_true.

    cs_day-residual = cs_day-diff_bank_gl.
    " Allocation order: cut-off, pending redeposit, cheque, unmapped code, other
    DATA(lt_order) = VALUE zif_cd_hck_recon_types=>tt_bucket( ( zif_cd_hck_recon_types=>gc_bucket-cutoff )
                                                              ( zif_cd_hck_recon_types=>gc_bucket-redeposit )
                                                              ( zif_cd_hck_recon_types=>gc_bucket-cheque )
                                                              ( zif_cd_hck_recon_types=>gc_bucket-unmapped )
                                                              ( zif_cd_hck_recon_types=>gc_bucket-other ) ).
    LOOP AT lt_order INTO DATA(lv_bucket).
      DATA(lv_amount) = VALUE #( it_buckets[ bucket = lv_bucket ]-amount OPTIONAL ).
      IF lv_amount = 0 OR abs( cs_day-residual - lv_amount ) >= abs( cs_day-residual ).
        CONTINUE.
      ENDIF.
      cs_day-residual = cs_day-residual - lv_amount.
      INSERT lv_bucket INTO TABLE cs_day-buckets.
      IF lv_bucket <> zif_cd_hck_recon_types=>gc_bucket-cutoff
         AND lv_bucket <> zif_cd_hck_recon_types=>gc_bucket-redeposit.
        lv_only_timing = abap_false.
      ENDIF.
      IF within_tolerance( is_input = is_input iv_amount = cs_day-residual ) = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF within_tolerance( is_input = is_input iv_amount = cs_day-residual ) = abap_false.
      cs_day-status = zif_cd_hck_recon_types=>gc_status-break.
    ELSEIF lv_only_timing = abap_true.
      cs_day-status = zif_cd_hck_recon_types=>gc_status-timing.
    ELSE.
      cs_day-status = zif_cd_hck_recon_types=>gc_status-variance.
    ENDIF.
  ENDMETHOD.


  METHOD evaluate_stripe.
    TYPES:
      BEGIN OF ty_dep_doc,
        bukrs  TYPE zif_cd_hck_recon_types=>ty_bukrs,
        belnr  TYPE zif_cd_hck_recon_types=>ty_belnr,
        gjahr  TYPE zif_cd_hck_recon_types=>ty_gjahr,
        day    TYPE d,
        amount TYPE zif_cd_hck_recon_types=>ty_amount,
      END OF ty_dep_doc.
    DATA lt_docs TYPE SORTED TABLE OF ty_dep_doc WITH UNIQUE KEY bukrs belnr gjahr.

    " Deposits of the set currency per posting document; a deposit not yet posted is its own group
    LOOP AT it_deposits ASSIGNING FIELD-SYMBOL(<ls_deposit>) WHERE currency = is_input-set-waers.
      DATA(lv_signed) = signed_bank( is_input = is_input iv_cdi = <ls_deposit>-cdi iv_amount = <ls_deposit>-amount ).
      IF <ls_deposit>-belnr IS INITIAL.
        INSERT VALUE #( day        = <ls_deposit>-day
                        deposit    = lv_signed
                        difference = - lv_signed
                        status     = COND #( WHEN is_input-report_date - <ls_deposit>-day <= is_input-timing_days
                                             THEN zif_cd_hck_recon_types=>gc_status-timing
                                             ELSE zif_cd_hck_recon_types=>gc_status-break ) ) INTO TABLE rt_groups.
        CONTINUE.
      ENDIF.
      READ TABLE lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>)
           WITH TABLE KEY bukrs = <ls_deposit>-bukrs belnr = <ls_deposit>-belnr gjahr = <ls_deposit>-gjahr.
      IF sy-subrc = 0.
        <ls_doc>-amount = <ls_doc>-amount + lv_signed.
      ELSE.
        INSERT VALUE #( bukrs  = <ls_deposit>-bukrs
                        belnr  = <ls_deposit>-belnr
                        gjahr  = <ls_deposit>-gjahr
                        day    = <ls_deposit>-day
                        amount = lv_signed ) INTO TABLE lt_docs.
      ENDIF.
    ENDLOOP.

    " Each posted deposit belongs to the descriptor(s) of its own clearing-account lines
    LOOP AT lt_docs ASSIGNING <ls_doc>.
      DATA(lt_doc_lines) = VALUE zif_cd_hck_recon_types=>tt_doc_assign(
        FOR ls_line IN it_doc_assign WHERE ( bukrs = <ls_doc>-bukrs AND belnr = <ls_doc>-belnr
                                             AND gjahr = <ls_doc>-gjahr )
        ( ls_line ) ).
      IF lt_doc_lines IS INITIAL.
        " Posted, but not on the clearing account with a descriptor: F.13 can never clear it
        INSERT VALUE #( belnr      = <ls_doc>-belnr
                        day        = <ls_doc>-day
                        deposit    = <ls_doc>-amount
                        difference = - <ls_doc>-amount
                        status     = zif_cd_hck_recon_types=>gc_status-break ) INTO TABLE rt_groups.
        CONTINUE.
      ENDIF.
      DATA(lt_descriptors) = VALUE zif_cd_hck_recon_types=>tt_zuonr( ).
      LOOP AT lt_doc_lines ASSIGNING FIELD-SYMBOL(<ls_doc_line>).
        IF NOT line_exists( lt_descriptors[ table_line = <ls_doc_line>-zuonr ] ).
          INSERT <ls_doc_line>-zuonr INTO TABLE lt_descriptors.
        ENDIF.
        READ TABLE rt_groups ASSIGNING FIELD-SYMBOL(<ls_group>) WITH KEY zuonr = <ls_doc_line>-zuonr.
        IF sy-subrc <> 0.
          INSERT VALUE #( zuonr = <ls_doc_line>-zuonr
                          day   = <ls_doc>-day ) INTO TABLE rt_groups ASSIGNING <ls_group>.
        ENDIF.
        " The deposit document's own lines are not part of the group (they are what F.13 clears)
        IF <ls_doc_line>-amount > 0.
          <ls_group>-charges = <ls_group>-charges - <ls_doc_line>-amount.
        ELSE.
          <ls_group>-fees = <ls_group>-fees - <ls_doc_line>-amount.
        ENDIF.
      ENDLOOP.
      " One descriptor: the bank amount; several: each its share as posted on the clearing account
      LOOP AT lt_descriptors INTO DATA(lv_zuonr).
        READ TABLE rt_groups ASSIGNING <ls_group> WITH KEY zuonr = lv_zuonr.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        IF lines( lt_descriptors ) = 1.
          <ls_group>-deposit = <ls_group>-deposit + <ls_doc>-amount.
        ELSE.
          LOOP AT lt_doc_lines ASSIGNING <ls_doc_line> WHERE zuonr = lv_zuonr.
            <ls_group>-deposit = <ls_group>-deposit - <ls_doc_line>-amount.
          ENDLOOP.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " Charges (debits) and fees (credits) of every line of the descriptor on the clearing account
    LOOP AT rt_groups ASSIGNING <ls_group> WHERE zuonr IS NOT INITIAL.
      LOOP AT it_group_sums ASSIGNING FIELD-SYMBOL(<ls_sum>) WHERE zuonr = <ls_group>-zuonr.
        IF <ls_sum>-amount > 0.
          <ls_group>-charges = <ls_group>-charges + <ls_sum>-amount.
        ELSE.
          <ls_group>-fees = <ls_group>-fees + <ls_sum>-amount.
        ENDIF.
      ENDLOOP.
      <ls_group>-difference = <ls_group>-charges + <ls_group>-fees - <ls_group>-deposit.
      <ls_group>-status = COND #( WHEN within_tolerance( is_input = is_input iv_amount = <ls_group>-difference ) = abap_true
                                  THEN zif_cd_hck_recon_types=>gc_status-balanced
                                  ELSE zif_cd_hck_recon_types=>gc_status-break ).
    ENDLOOP.
  ENDMETHOD.


  METHOD evaluate_ach.
    LOOP AT it_open ASSIGNING FIELD-SYMBOL(<ls_open>) WHERE first_day >= is_input-from
                                                        AND first_day <= is_input-to.
      DATA(lv_status) = COND zif_cd_hck_recon_types=>ty_status(
        WHEN is_input-report_date - <ls_open>-first_day <= is_input-timing_days
        THEN zif_cd_hck_recon_types=>gc_status-timing
        ELSE zif_cd_hck_recon_types=>gc_status-break ).
      READ TABLE rt_days ASSIGNING FIELD-SYMBOL(<ls_day>) WITH KEY day = <ls_open>-first_day status = lv_status.
      IF sy-subrc <> 0.
        INSERT VALUE #( day         = <ls_open>-first_day
                        status      = lv_status
                        first_zuonr = <ls_open>-zuonr ) INTO TABLE rt_days ASSIGNING <ls_day>.
      ENDIF.
      <ls_day>-group_count = <ls_day>-group_count + 1.
      <ls_day>-amount      = <ls_day>-amount + <ls_open>-amount.
    ENDLOOP.
    SORT rt_days BY day status.
  ENDMETHOD.


  METHOD signed_bank.
    rv_amount = COND #( WHEN iv_cdi = is_input-debit_ind THEN - abs( iv_amount ) ELSE abs( iv_amount ) ).
    IF iv_cdi <> is_input-debit_ind AND iv_cdi <> is_input-credit_ind.
      " Unknown indicator: the amount as delivered (a signed amount keeps its sign)
      rv_amount = iv_amount.
    ENDIF.
    IF is_input-set-invert_bank = abap_true.
      rv_amount = - rv_amount.
    ENDIF.
  ENDMETHOD.


  METHOD role_of.
    DATA(lv_btc) = CONV zif_cd_hck_recon_types=>ty_btc( condense( iv_btc ) ).
    rv_role = VALUE #( is_input-roles[ KEY by_set set_id = is_input-set-set_id btc = lv_btc ]-role OPTIONAL ).
  ENDMETHOD.


  METHOD add_bucket.
    IF iv_amount = 0.
      RETURN.
    ENDIF.
    READ TABLE ct_buckets ASSIGNING FIELD-SYMBOL(<ls_bucket>) WITH KEY bucket = iv_bucket.
    IF sy-subrc = 0.
      <ls_bucket>-amount = <ls_bucket>-amount + iv_amount.
    ELSE.
      INSERT VALUE #( bucket = iv_bucket amount = iv_amount ) INTO TABLE ct_buckets.
    ENDIF.
  ENDMETHOD.


  METHOD add_unmapped.
    DATA(lv_btc) = CONV zif_cd_hck_recon_types=>ty_btc( condense( iv_btc ) ).
    READ TABLE ct_unmapped ASSIGNING FIELD-SYMBOL(<ls_unmapped>) WITH KEY btc = lv_btc.
    IF sy-subrc <> 0.
      INSERT VALUE #( btc = lv_btc ) INTO TABLE ct_unmapped ASSIGNING <ls_unmapped>.
    ENDIF.
    <ls_unmapped>-amount     = <ls_unmapped>-amount + iv_amount.
    <ls_unmapped>-line_count = <ls_unmapped>-line_count + iv_lines.
  ENDMETHOD.


  METHOD within_tolerance.
    rv_yes = xsdbool( abs( iv_amount ) <= is_input-tolerance ).
  ENDMETHOD.

ENDCLASS.
