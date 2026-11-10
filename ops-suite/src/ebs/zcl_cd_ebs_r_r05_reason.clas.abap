*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r05_reason.clas.abap
*& Purpose:
*& R05: return / NOC reason. Bank file (before import): the NACHA return reason
*& (R01-R85) or NOC code (C01-C07) of the file must be mapped to a payment
*& engine reason in the posting area ZRSN (PARAM1 = REQUIRED also fails entries
*& without a reason; without any mapping only the format is checked). Imported
*& statement (FEB source, FEBEP carries no reason): the reason of the returns
*& lot item (DFKKRP-RLGRD by SELW1 = payment document) or of the NOC lot item
*& (DFKKNRP-FLGRD by INFOF = payment document or reference) must be filled, one
*& and the same per payment, and a configured payment engine reason; a payment
*& without lot item is not evaluated (R07R / S13 own that). NEEDS_POSTING.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A28: placeholder mapping incomplete, NOC vs return (PARAM2), required without mapping.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Return / NOC reason correction: FEB source checks the lot reasons DFKKRP-RLGRD and
*&            | DFKKNRP-FLGRD (FEBEP carries no reason); the bank-file check is unchanged.
*& 2026-11-08 | Customer posting area ZRSN: the reason of a bank file line is the entry that applies (get_reason:
*&            | exact beats *), was a key read of ZCD_EBS_RSN_MAP.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R05 - valid return / NOC reason</p>
CLASS zcl_cd_ebs_r_r05_reason DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS gc_reason_pattern TYPE string VALUE `^(R(0[1-9]|[1-7][0-9]|8[0-5])|C0[1-7])\s*$`.

    TYPES tt_lot_reason TYPE SORTED TABLE OF zif_cd_ebs_sap_dao=>ty_lot_reason WITH UNIQUE KEY table_line.

    "! Reasons and lot keys of the lot items of one payment
    TYPES:
      BEGIN OF ty_lot,
        lot     TYPE string,
        reasons TYPE tt_lot_reason,
      END OF ty_lot.

    "! NOC lot item with the canonical form of its INFOF (matched to the line in ABAP)
    TYPES:
      BEGIN OF ty_noc_index,
        canonical TYPE string,
        keyn1     TYPE zif_cd_ebs_sap_dao=>ty_noc_item-keyn1,
        flgrd     TYPE zif_cd_ebs_sap_dao=>ty_lot_reason,
      END OF ty_noc_index.
    TYPES tt_noc_index TYPE SORTED TABLE OF ty_noc_index WITH NON-UNIQUE KEY canonical.

    "! Bank file (before import): the reason delivered in the file - unchanged since A28
    METHODS check_file_line
      IMPORTING
        is_rule     TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_line     TYPE zif_cd_ebs_types=>ty_line
        it_reasons  TYPE zif_cd_ebs_types=>tt_reason_map
        iv_required TYPE abap_bool
        iv_kind     TYPE string
      CHANGING
        ct_findings TYPE zif_ca_ops_types=>tt_finding.

    "! FEB source: the reason of the payment's lot items (return or NOC); none = not evaluated
    METHODS check_lot_reason
      IMPORTING
        is_rule     TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_line     TYPE zif_cd_ebs_types=>ty_line
        iv_kind     TYPE string
        iv_payment  TYPE string
        is_lot      TYPE ty_lot
        it_valid    TYPE tt_lot_reason
      CHANGING
        ct_findings TYPE zif_ca_ops_types=>tt_finding.

    "! Configured payment engine reasons of one kind (ZRSN result FICA_REASON of the
    "! return rows or of the NOC rows); placeholders and blank values are no reason
    METHODS valid_reasons
      IMPORTING
        it_reasons      TYPE zif_cd_ebs_types=>tt_reason_map
        iv_noc          TYPE abap_bool
      RETURNING
        VALUE(rt_valid) TYPE tt_lot_reason.

    "! Forms of a line's payment document / reference that DFKKNRP-INFOF may hold: the
    "! document key (EBS_KEYLEN_DOCNO), the reference as delivered and without leading zeros
    METHODS infof_forms
      IMPORTING
        is_line         TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rt_forms) TYPE zif_cd_ebs_sap_dao=>tt_infof.

ENDCLASS.



CLASS zcl_cd_ebs_r_r05_reason IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_feb_lines TYPE zif_cd_ebs_types=>tt_line.
    DATA lt_infof TYPE zif_cd_ebs_sap_dao=>tt_infof.
    DATA lt_return_items TYPE zif_cd_ebs_sap_dao=>tt_return_item.
    DATA lt_noc_index TYPE tt_noc_index.
    DATA ls_lot TYPE ty_lot.

    DATA(lt_reasons) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_reason_map( ).
    DATA(lv_required) = xsdbool( to_upper( condense( CONV string( is_rule-param1 ) ) )
                                 = zif_cd_ebs_types=>gc_rule_keyword-required ).
    DATA(lv_kind) = to_upper( condense( CONV string( is_rule-param2 ) ) ).

    " The bank file carries the reason; an imported statement does not (FEBEP has no reason field)
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF VALUE #( it_statements[ stmt_key = <ls_line>-stmt_key ]-source OPTIONAL ) = zif_cd_ebs_types=>gc_source-feb.
        INSERT <ls_line> INTO TABLE lt_feb_lines.
      ELSE.
        check_file_line( EXPORTING is_rule     = is_rule
                                   is_line     = <ls_line>
                                   it_reasons  = lt_reasons
                                   iv_required = lv_required
                                   iv_kind     = lv_kind
                         CHANGING  ct_findings = rt_findings ).
      ENDIF.
    ENDLOOP.
    IF lt_feb_lines IS INITIAL.
      RETURN.
    ENDIF.

    " FEB source: returns lot items (DFKKRP by SELW1, same read as R07R) and NOC lot items
    " (DFKKNRP by INFOF) - only for the kinds the assignment covers (PARAM2 RETURN / NOC / blank)
    DATA(lv_returns) = xsdbool( lv_kind <> zif_cd_ebs_types=>gc_rule_keyword-noc ).
    DATA(lv_nocs) = xsdbool( lv_kind <> zif_cd_ebs_types=>gc_rule_keyword-return ).
    DATA(lv_ignore_zeros) = ztnum_ignore_zeros( ).
    IF lv_returns = abap_true.
      lt_return_items = sap_dao( )->get_return_items( docno_keys( lt_feb_lines ) ).
    ENDIF.
    IF lv_nocs = abap_true.
      LOOP AT lt_feb_lines ASSIGNING FIELD-SYMBOL(<ls_feb>).
        INSERT LINES OF infof_forms( <ls_feb> ) INTO TABLE lt_infof.
      ENDLOOP.
      DATA(lt_noc_items) = sap_dao( )->get_noc_items( lt_infof ).
      LOOP AT lt_noc_items ASSIGNING FIELD-SYMBOL(<ls_noc>).
        INSERT VALUE #( canonical = ztnum_canonical( iv_value = <ls_noc>-infof iv_ignore_zeros = lv_ignore_zeros )
                        keyn1     = <ls_noc>-keyn1
                        flgrd     = <ls_noc>-flgrd ) INTO TABLE lt_noc_index.
      ENDLOOP.
    ENDIF.
    DATA(lt_valid_returns) = valid_reasons( it_reasons = lt_reasons iv_noc = abap_false ).
    DATA(lt_valid_nocs) = valid_reasons( it_reasons = lt_reasons iv_noc = abap_true ).

    LOOP AT lt_feb_lines ASSIGNING FIELD-SYMBOL(<ls_line_feb>).
      DATA(lv_reference) = line_reference( <ls_line_feb> ).
      DATA(lv_key) = docno_key( lv_reference ).
      IF lv_returns = abap_true AND lv_key IS NOT INITIAL.
        CLEAR ls_lot.
        LOOP AT lt_return_items ASSIGNING FIELD-SYMBOL(<ls_item>) USING KEY by_selw1 WHERE selw1 = lv_key.
          ls_lot-lot = condense( |{ ls_lot-lot } { <ls_item>-opbel }| ).
          INSERT <ls_item>-rlgrd INTO TABLE ls_lot-reasons.
        ENDLOOP.
        check_lot_reason( EXPORTING is_rule     = is_rule
                                    is_line     = <ls_line_feb>
                                    iv_kind     = zif_cd_ebs_types=>gc_rule_keyword-return
                                    iv_payment  = CONV #( lv_key )
                                    is_lot      = ls_lot
                                    it_valid    = lt_valid_returns
                          CHANGING  ct_findings = rt_findings ).
      ENDIF.
      IF lv_nocs = abap_true.
        CLEAR ls_lot.
        DATA(lv_canonical) = ztnum_canonical( iv_value = lv_reference iv_ignore_zeros = lv_ignore_zeros ).
        IF lv_canonical IS NOT INITIAL.
          LOOP AT lt_noc_index ASSIGNING FIELD-SYMBOL(<ls_noc_item>) WHERE canonical = lv_canonical.
            ls_lot-lot = condense( |{ ls_lot-lot } { <ls_noc_item>-keyn1 }| ).
            INSERT <ls_noc_item>-flgrd INTO TABLE ls_lot-reasons.
          ENDLOOP.
        ENDIF.
        check_lot_reason( EXPORTING is_rule     = is_rule
                                    is_line     = <ls_line_feb>
                                    iv_kind     = zif_cd_ebs_types=>gc_rule_keyword-noc
                                    iv_payment  = condense( CONV string( lv_reference ) )
                                    is_lot      = ls_lot
                                    it_valid    = lt_valid_nocs
                          CHANGING  ct_findings = rt_findings ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_lot_reason.
    " No lot item: the return / NOC processing is not complete or the payment is no return /
    " NOC - R07R and S13 report that, R05 does not evaluate the line (no duplicate failure)
    IF is_lot-reasons IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( is_lot-reasons ) > 1.
      DATA(lv_reasons) = REDUCE string( INIT lv_list = ``
                                        FOR lv_reason IN is_lot-reasons
                                        NEXT lv_list = condense( |{ lv_list } { lv_reason }| ) ).
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_ambiguous
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-lot_reason_ambiguous
                                                   iv_v1    = iv_payment
                                                   iv_v2    = iv_kind
                                                   iv_v3    = lv_reasons ) ) INTO TABLE ct_findings.
      RETURN.
    ENDIF.
    DATA(lv_lot_reason) = is_lot-reasons[ 1 ].
    IF lv_lot_reason IS INITIAL.
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_missing
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-lot_reason_missing
                                                   iv_v1    = iv_kind
                                                   iv_v2    = is_lot-lot
                                                   iv_v3    = iv_payment ) ) INTO TABLE ct_findings.
    ELSEIF NOT line_exists( it_valid[ table_line = lv_lot_reason ] ).
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-lot_reason_unmapped
                                                   iv_v1    = iv_kind
                                                   iv_v2    = lv_lot_reason
                                                   iv_v3    = iv_payment ) ) INTO TABLE ct_findings.
    ENDIF.
  ENDMETHOD.


  METHOD valid_reasons.
    LOOP AT it_reasons ASSIGNING FIELD-SYMBOL(<ls_map>) WHERE is_noc = iv_noc.
      IF <ls_map>-fica_reason IS NOT INITIAL AND <ls_map>-fica_reason(1) <> zif_cd_ebs_types=>gc_placeholder_prefix.
        INSERT <ls_map>-fica_reason INTO TABLE rt_valid.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD infof_forms.
    DATA(lv_reference) = condense( CONV string( line_reference( is_line ) ) ).
    IF lv_reference IS INITIAL.
      RETURN.
    ENDIF.
    " VERIFY-SE11: INFOF holds AUGBL (with leading zeros as stored) or the payment reference
    INSERT CONV zif_cd_ebs_sap_dao=>ty_infof( lv_reference ) INTO TABLE rt_forms.
    INSERT CONV zif_cd_ebs_sap_dao=>ty_infof( ztnum_canonical( iv_value = lv_reference iv_ignore_zeros = abap_true ) )
      INTO TABLE rt_forms.
    DATA(lv_key) = docno_key( lv_reference ).
    IF lv_key IS NOT INITIAL.
      INSERT CONV zif_cd_ebs_sap_dao=>ty_infof( lv_key ) INTO TABLE rt_forms.
    ENDIF.
  ENDMETHOD.


  METHOD check_file_line.
    IF is_line-return_reason IS INITIAL.
      IF iv_required = abap_true.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_missing
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_missing
                                                     iv_v1    = is_line-btc_code ) ) INTO TABLE ct_findings.
      ENDIF.
      RETURN.
    ENDIF.
    IF it_reasons IS NOT INITIAL.
      " The entry that applies (FQC0: the exact reason beats a '*' entry of ZRSN)
      DATA(ls_map) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_reason( is_line-return_reason ).
      IF ls_map IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_unmapped
                                                     iv_v1    = is_line-return_reason ) )
          INTO TABLE ct_findings.
      ELSEIF ls_map-fica_reason IS INITIAL OR ls_map-fica_reason(1) = zif_cd_ebs_types=>gc_placeholder_prefix.
        " A28: a seeded placeholder is no mapping
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_map_incomplete
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_map_incomplete
                                                     iv_v1    = is_line-return_reason
                                                     iv_v2    = ls_map-fica_reason ) ) INTO TABLE ct_findings.
      ELSEIF ( iv_kind = zif_cd_ebs_types=>gc_rule_keyword-return AND ls_map-is_noc = abap_true )
          OR ( iv_kind = zif_cd_ebs_types=>gc_rule_keyword-noc    AND ls_map-is_noc = abap_false ).
        " A28: a NOC is never a return and a return never a NOC
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_kind
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_kind
                                                     iv_v1    = is_line-return_reason
                                                     iv_v2    = iv_kind ) ) INTO TABLE ct_findings.
      ENDIF.
    ELSEIF iv_required = abap_true.
      " A28: a required reason cannot be validated without mapping - incomplete configuration
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_map_incomplete
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_map_incomplete
                                                   iv_v1    = is_line-return_reason
                                                   iv_v2    = zif_cd_ebs_types=>gc_rule_keyword-required ) )
        INTO TABLE ct_findings.
    ELSEIF NOT matches( val = is_line-return_reason pcre = gc_reason_pattern ).
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = is_line iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_invalid
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_invalid
                                                   iv_v1    = is_line-return_reason ) ) INTO TABLE ct_findings.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
