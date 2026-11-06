*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_parser_camt.clas.abap
*& Purpose:
*& Parses ISO 20022 camt.053 (Stmt) and camt.054 (Ntfctn) XML with sXML into
*& the format-neutral EBS model and checks TxsSummry (S06, S11, S12, S00).
*& It never posts, never reads the database and uses no XPath/XSLT.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A92-A94: CAMT document gate, booked entries only, details reconciled to their entry; invalid amount / count block.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: INSERT INTO TABLE, CASE.
*& 2026-11-06 | Receiver path pattern is PCRE matched to the complete path (case ignored).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS - camt.053/054 bank statement parser</p>
"! Namespace-agnostic (local names only, any camt.053.001.0x / 054.001.0x).
"! Empty content returns finding S11 EMPTY_FILE (severity B); XML that cannot
"! be parsed raises ZCX_CD_OPS_ERROR 151, another message type raises 152.
CLASS zcl_cd_ebs_parser_camt DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_parser.

  PRIVATE SECTION.
    TYPES ty_amount TYPE zif_cd_ops_types=>ty_amount.
    TYPES ty_name   TYPE string.

    TYPES:
      BEGIN OF ty_btc,
        present      TYPE abap_bool,
        domain       TYPE zif_cd_ebs_types=>ty_line-domain,
        family       TYPE zif_cd_ebs_types=>ty_line-family,
        subfamily    TYPE zif_cd_ebs_types=>ty_line-subfamily,
        prtry_code   TYPE zif_cd_ebs_types=>ty_btc_code,
        prtry_issuer TYPE zif_cd_ebs_types=>ty_text35,
      END OF ty_btc.

    TYPES:
      BEGIN OF ty_tx,
        has_amount    TYPE abap_bool,
        amount        TYPE ty_amount,
        currency      TYPE zif_cd_ops_types=>ty_currency,
        cdi           TYPE zif_cd_ebs_types=>ty_cdi,
        btc           TYPE ty_btc,
        end_to_end_id TYPE zif_cd_ebs_types=>ty_text35,
        instr_id      TYPE zif_cd_ebs_types=>ty_text35,
        check_no      TYPE zif_cd_ebs_types=>ty_text35,
        bank_ref      TYPE zif_cd_ebs_types=>ty_text35,
        cust_ref      TYPE zif_cd_ebs_types=>ty_text35,
        return_reason TYPE zif_cd_ebs_types=>ty_line-return_reason,
        addtl_info    TYPE zif_cd_ebs_types=>ty_line-addtl_info,
      END OF ty_tx.
    TYPES tt_tx TYPE STANDARD TABLE OF ty_tx WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_entry,
        amount       TYPE ty_amount,
        currency     TYPE zif_cd_ops_types=>ty_currency,
        cdi          TYPE zif_cd_ebs_types=>ty_cdi,
        reversal     TYPE abap_bool,
        booking_date TYPE d,
        value_date   TYPE d,
        bank_ref     TYPE zif_cd_ebs_types=>ty_text35,
        addtl_info   TYPE zif_cd_ebs_types=>ty_line-addtl_info,
        btc          TYPE ty_btc,
        txs          TYPE tt_tx,
        "! A93: Sts (v02-v06) or Sts/Cd (v08+)
        status       TYPE zif_cd_ebs_types=>ty_line-entry_status,
      END OF ty_entry.

    TYPES:
      BEGIN OF ty_balance_ctx,
        balance  TYPE zif_cd_ebs_types=>ty_balance,
        is_debit TYPE abap_bool,
      END OF ty_balance_ctx.

    "! Declared (TxsSummry) or parsed count and sum of one entry side
    TYPES:
      BEGIN OF ty_side,
        present   TYPE abap_bool,
        has_count TYPE abap_bool,
        count     TYPE i,
        has_sum   TYPE abap_bool,
        sum       TYPE ty_amount,
      END OF ty_side.

    TYPES:
      BEGIN OF ty_summary,
        total        TYPE ty_side,
        has_net      TYPE abap_bool,
        net_amount   TYPE ty_amount,
        net_is_debit TYPE abap_bool,
        credit       TYPE ty_side,
        debit        TYPE ty_side,
      END OF ty_summary.

    TYPES:
      BEGIN OF ty_stmt_ctx,
        stmt     TYPE zif_cd_ebs_types=>ty_statement,
        lines    TYPE zif_cd_ebs_types=>tt_line,
        to_date  TYPE d,
        entries  TYPE i,
        credit   TYPE ty_side,
        debit    TYPE ty_side,
        declared TYPE ty_summary,
      END OF ty_stmt_ctx.

    "! Target object and wording of a finding
    TYPES:
      BEGIN OF ty_check,
        object_type TYPE zif_cd_ops_types=>ty_object_type,
        object_key  TYPE zif_cd_ops_types=>ty_object_key,
        check_code  TYPE zif_cd_ops_types=>ty_check_code,
        label       TYPE string,
      END OF ty_check.

    "! Element local names
    CONSTANTS:
      BEGIN OF gc_el,
        document     TYPE ty_name VALUE `Document`,
        stmt_message TYPE ty_name VALUE `BkToCstmrStmt`,
        ntfc_message TYPE ty_name VALUE `BkToCstmrDbtCdtNtfctn`,
        grp_hdr      TYPE ty_name VALUE `GrpHdr`,
        stmt         TYPE ty_name VALUE `Stmt`,
        ntfctn       TYPE ty_name VALUE `Ntfctn`,
        bal          TYPE ty_name VALUE `Bal`,
        ntry         TYPE ty_name VALUE `Ntry`,
        tx_dtls      TYPE ty_name VALUE `TxDtls`,
        amt          TYPE ty_name VALUE `Amt`,
        "! camt.052 report element - not accepted (A94)
        rpt          TYPE ty_name VALUE `Rpt`,
      END OF gc_el.

    CONSTANTS gc_attr_ccy TYPE ty_name VALUE `Ccy`.

    "! Element paths relative to their anchor (GrpHdr, Stmt/Ntfctn, Bal, Ntry, TxDtls)
    CONSTANTS:
      BEGIN OF gc_path,
        msg_id          TYPE string VALUE `MsgId`,
        cre_dt_tm       TYPE string VALUE `CreDtTm`,
        ctrl_sum        TYPE string VALUE `CtrlSum`,
        rcpt_name       TYPE string VALUE `MsgRcpt/Nm`,
        "! PCRE, complete path, case ignored: any element below MsgRcpt/Id
        rcpt_id_pattern TYPE string VALUE `MsgRcpt/Id/.*`,
        id              TYPE string VALUE `Id`,
        elctrnc_seq_nb  TYPE string VALUE `ElctrncSeqNb`,
        lgl_seq_nb      TYPE string VALUE `LglSeqNb`,
        to_dt_tm        TYPE string VALUE `FrToDt/ToDtTm`,
        acct_iban       TYPE string VALUE `Acct/Id/IBAN`,
        acct_othr_id    TYPE string VALUE `Acct/Id/Othr/Id`,
        acct_ccy        TYPE string VALUE `Acct/Ccy`,
        svcr_bicfi      TYPE string VALUE `Acct/Svcr/FinInstnId/BICFI`,
        svcr_bic        TYPE string VALUE `Acct/Svcr/FinInstnId/BIC`,
        svcr_othr_id    TYPE string VALUE `Acct/Svcr/FinInstnId/Othr/Id`,
        ttl_count       TYPE string VALUE `TxsSummry/TtlNtries/NbOfNtries`,
        ttl_sum         TYPE string VALUE `TxsSummry/TtlNtries/Sum`,
        ttl_net_amt     TYPE string VALUE `TxsSummry/TtlNtries/TtlNetNtry/Amt`,
        ttl_net_cdi     TYPE string VALUE `TxsSummry/TtlNtries/TtlNetNtry/CdtDbtInd`,
        ttl_net_amt_v02 TYPE string VALUE `TxsSummry/TtlNtries/TtlNetNtryAmt`,
        ttl_net_cdi_v02 TYPE string VALUE `TxsSummry/TtlNtries/TtlNetNtryCdtDbtInd`,
        cdt_count       TYPE string VALUE `TxsSummry/TtlCdtNtries/NbOfNtries`,
        cdt_sum         TYPE string VALUE `TxsSummry/TtlCdtNtries/Sum`,
        dbt_count       TYPE string VALUE `TxsSummry/TtlDbtNtries/NbOfNtries`,
        dbt_sum         TYPE string VALUE `TxsSummry/TtlDbtNtries/Sum`,
        bal_code        TYPE string VALUE `Tp/CdOrPrtry/Cd`,
        bal_prtry       TYPE string VALUE `Tp/CdOrPrtry/Prtry`,
        amt             TYPE string VALUE `Amt`,
        cdt_dbt_ind     TYPE string VALUE `CdtDbtInd`,
        dt              TYPE string VALUE `Dt/Dt`,
        dt_tm           TYPE string VALUE `Dt/DtTm`,
        rvsl_ind        TYPE string VALUE `RvslInd`,
        bookg_dt        TYPE string VALUE `BookgDt/Dt`,
        bookg_dt_tm     TYPE string VALUE `BookgDt/DtTm`,
        val_dt          TYPE string VALUE `ValDt/Dt`,
        val_dt_tm       TYPE string VALUE `ValDt/DtTm`,
        acct_svcr_ref   TYPE string VALUE `AcctSvcrRef`,
        addtl_ntry_inf  TYPE string VALUE `AddtlNtryInf`,
        btc_domain      TYPE string VALUE `BkTxCd/Domn/Cd`,
        btc_family      TYPE string VALUE `BkTxCd/Domn/Fmly/Cd`,
        btc_subfamily   TYPE string VALUE `BkTxCd/Domn/Fmly/SubFmlyCd`,
        btc_prtry_code  TYPE string VALUE `BkTxCd/Prtry/Cd`,
        btc_prtry_issr  TYPE string VALUE `BkTxCd/Prtry/Issr`,
        tx_amt          TYPE string VALUE `AmtDtls/TxAmt/Amt`,
        ref_end_to_end  TYPE string VALUE `Refs/EndToEndId`,
        ref_instr_id    TYPE string VALUE `Refs/InstrId`,
        ref_chq_nb      TYPE string VALUE `Refs/ChqNb`,
        ref_svcr_ref    TYPE string VALUE `Refs/AcctSvcrRef`,
        ref_msg_id      TYPE string VALUE `Refs/MsgId`,
        rtr_reason      TYPE string VALUE `RtrInf/Rsn/Cd`,
        addtl_tx_inf    TYPE string VALUE `AddtlTxInf`,
        "! A93: entry status, both layouts
        sts             TYPE string VALUE `Sts`,
        sts_cd          TYPE string VALUE `Sts/Cd`,
      END OF gc_path.

    "! Element depths: 1 Document, 2 message, 3 GrpHdr / Stmt / Ntfctn
    CONSTANTS:
      BEGIN OF gc_depth,
        root    TYPE i VALUE 1,
        message TYPE i VALUE 2,
        child   TYPE i VALUE 3,
      END OF gc_depth.

    CONSTANTS:
      BEGIN OF gc_indicator,
        credit TYPE string VALUE `CRDT`,
        debit  TYPE string VALUE `DBIT`,
      END OF gc_indicator.

    CONSTANTS:
      BEGIN OF gc_rule,
        structure     TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S00',
        control_total TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S06',
        empty         TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S11',
        count         TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S12',
      END OF gc_rule.

    CONSTANTS:
      BEGIN OF gc_check,
        sum_mismatch    TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_SUM_MISMATCH',
        net_mismatch    TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_NET_MISMATCH',
        cdt_sum         TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_CDT_SUM_MISMATCH',
        dbt_sum         TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_DBT_SUM_MISMATCH',
        entry_count     TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_ENTRY_COUNT',
        cdt_entry_count TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_CDT_ENTRY_COUNT',
        dbt_entry_count TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_DBT_ENTRY_COUNT',
        empty_file      TYPE zif_cd_ops_types=>ty_check_code VALUE 'EMPTY_FILE',
        no_entries      TYPE zif_cd_ops_types=>ty_check_code VALUE 'NO_ENTRIES',
        invalid_amount  TYPE zif_cd_ops_types=>ty_check_code VALUE 'INVALID_AMOUNT',
        invalid_date    TYPE zif_cd_ops_types=>ty_check_code VALUE 'INVALID_DATE',
        "! A94: namespace / version, message body or statement element not accepted
        camt_document   TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_DOCUMENT',
        invalid_count   TYPE zif_cd_ops_types=>ty_check_code VALUE 'INVALID_COUNT',
        "! A93: entry not booked (PDNG / INFO / missing status) - quarantined
        not_booked      TYPE zif_cd_ops_types=>ty_check_code VALUE 'ENTRY_NOT_BOOKED',
        "! A92: transaction details do not reconcile to their entry / a detail has no amount
        batch_mismatch  TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_BATCH_MISMATCH',
        detail_amount   TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_DETAIL_AMOUNT_MISSING',
      END OF gc_check.

    CONSTANTS:
      BEGIN OF gc_object,
        file      TYPE zif_cd_ops_types=>ty_object_type VALUE 'FILE',
        statement TYPE zif_cd_ops_types=>ty_object_type VALUE 'STMT',
        line      TYPE zif_cd_ops_types=>ty_object_type VALUE 'LINE',
      END OF gc_object.

    "! A93: the approved posting profile - only booked entries become postable lines
    CONSTANTS gc_status_booked TYPE zif_cd_ebs_types=>ty_line-entry_status VALUE 'BOOK'.

    "! A94: approved ISO 20022 namespaces = prefix + one of the approved message versions
    CONSTANTS gc_ns_prefix TYPE string VALUE `urn:iso:std:iso:20022:tech:xsd:`.
    "! Message variant and approved versions (camt.053.001.02-08, camt.054.001.02-08)
    CONSTANTS gc_variant TYPE string VALUE `001.`.
    CONSTANTS gc_approved_versions TYPE string VALUE `02,03,04,05,06,07,08`.
    CONSTANTS gc_type_053 TYPE string VALUE `camt.053.`.
    CONSTANTS gc_type_054 TYPE string VALUE `camt.054.`.
    "! A94: what was not accepted (message variable)
    CONSTANTS:
      BEGIN OF gc_doc_reason,
        namespace   TYPE string VALUE `NAMESPACE`,
        second_body TYPE string VALUE `SECOND_MESSAGE_BODY`,
        element     TYPE string VALUE `STATEMENT_ELEMENT`,
      END OF gc_doc_reason.

    CONSTANTS gc_not_provided TYPE string VALUE `NOTPROVIDED`.
    CONSTANTS gc_true TYPE string VALUE `true`.
    CONSTANTS gc_true_digit TYPE string VALUE `1`.
    CONSTANTS gc_path_separator TYPE string VALUE `/`.
    CONSTANTS gc_btc_separator TYPE string VALUE `-`.
    CONSTANTS gc_digits TYPE string VALUE `0123456789`.
    CONSTANTS gc_decimal_chars TYPE string VALUE `0123456789.`.
    CONSTANTS gc_decimal_point TYPE string VALUE `.`.
    CONSTANTS gc_date_dash TYPE string VALUE `-`.
    CONSTANTS gc_time_colon TYPE string VALUE `:`.
    CONSTANTS gc_iso_date_length TYPE i VALUE 10.
    CONSTANTS gc_iso_time_offset TYPE i VALUE 11.
    CONSTANTS gc_date_digits TYPE i VALUE 8.
    CONSTANTS gc_time_digits TYPE i VALUE 6.
    CONSTANTS gc_iso_time_length TYPE i VALUE 8.
    CONSTANTS gc_max_amount_length TYPE i VALUE 22.
    CONSTANTS gc_max_count_digits TYPE i VALUE 9.
    CONSTANTS gc_not_declared TYPE i VALUE -1.

    DATA ms_file TYPE zif_cd_ebs_types=>ty_file.
    DATA mt_path TYPE string_table.
    DATA mv_root_name TYPE ty_name.
    DATA mv_hdr_depth TYPE i.
    DATA mv_stmt_depth TYPE i.
    DATA mv_bal_depth TYPE i.
    DATA mv_ntry_depth TYPE i.
    DATA mv_tx_depth TYPE i.
    DATA mv_stmt_index TYPE i.
    DATA mv_amt_ccy TYPE zif_cd_ops_types=>ty_currency.
    DATA mv_receiver_by_id TYPE abap_bool.
    "! A94: namespace of the Document element
    DATA mv_namespace TYPE string.
    DATA ms_stmt TYPE ty_stmt_ctx.
    DATA ms_bal TYPE ty_balance_ctx.
    DATA ms_entry TYPE ty_entry.
    DATA ms_tx TYPE ty_tx.

    METHODS reset_state
      IMPORTING
        iv_file_name TYPE string.

    METHODS is_blank
      IMPORTING
        iv_content      TYPE string
      RETURNING
        VALUE(rv_blank) TYPE abap_bool.

    METHODS read_document
      IMPORTING
        iv_content TYPE string
      RAISING
        zcx_cd_ops_error.

    METHODS process_node
      IMPORTING
        io_node TYPE REF TO if_sxml_node
      RAISING
        zcx_cd_ops_error.

    METHODS open_element
      IMPORTING
        io_element TYPE REF TO if_sxml_open_element
      RAISING
        zcx_cd_ops_error.

    METHODS check_document
      IMPORTING
        iv_name  TYPE ty_name
        iv_depth TYPE i
      RAISING
        zcx_cd_ops_error.

    METHODS open_anchor
      IMPORTING
        iv_name  TYPE ty_name
        iv_depth TYPE i.

    "! A94: namespace and version against the approved list, matching the message type
    METHODS check_namespace.

    "! A94: blocking CAMT_DOCUMENT finding on the file
    METHODS document_finding
      IMPORTING
        iv_reason TYPE string
        iv_value  TYPE clike.

    "! A92: why the transaction details of the entry cannot be posted as lines (check code)
    METHODS detail_problem
      RETURNING
        VALUE(rv_check_code) TYPE zif_cd_ops_types=>ty_check_code.

    METHODS attribute_value
      IMPORTING
        io_element      TYPE REF TO if_sxml_open_element
        iv_name         TYPE ty_name
      RETURNING
        VALUE(rv_value) TYPE string.

    METHODS close_element.

    METHODS on_value
      IMPORTING
        iv_value TYPE string.

    METHODS relative_path
      IMPORTING
        iv_anchor_depth TYPE i
      RETURNING
        VALUE(rv_path)  TYPE string.

    METHODS on_header_value
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string.

    METHODS open_statement
      IMPORTING
        iv_depth TYPE i.

    METHODS on_statement_value
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string.

    METHODS on_summary_value
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string.

    METHODS close_statement.

    METHODS derive_balances.

    METHODS default_currency.

    METHODS validate_summary.

    METHODS validate_side
      IMPORTING
        is_declared   TYPE ty_side
        is_parsed     TYPE ty_side
        iv_count_code TYPE zif_cd_ops_types=>ty_check_code
        iv_sum_code   TYPE zif_cd_ops_types=>ty_check_code
        iv_label      TYPE string.

    METHODS on_balance_value
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string.

    METHODS close_balance.

    METHODS open_entry
      IMPORTING
        iv_depth TYPE i.

    METHODS on_entry_value
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string.

    METHODS close_entry.

    METHODS on_tx_value
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string.

    METHODS on_tx_reference
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string.

    METHODS apply_btc
      IMPORTING
        iv_path  TYPE string
        iv_value TYPE string
      CHANGING
        cs_btc   TYPE ty_btc.

    "! One line per TxDtls when every TxDtls carries an amount, else one line for the entry
    METHODS split_by_transaction
      RETURNING
        VALUE(rv_split) TYPE abap_bool.

    METHODS append_line
      IMPORTING
        is_tx       TYPE ty_tx
        iv_amount   TYPE ty_amount
        iv_currency TYPE zif_cd_ops_types=>ty_currency.

    METHODS apply_code
      IMPORTING
        is_btc  TYPE ty_btc
      CHANGING
        cs_line TYPE zif_cd_ebs_types=>ty_line.

    METHODS primary_reference
      IMPORTING
        is_line             TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rv_reference) TYPE zif_cd_ebs_types=>ty_text35.

    METHODS check_total
      IMPORTING
        is_check    TYPE ty_check
        iv_expected TYPE ty_amount
        iv_found    TYPE ty_amount.

    METHODS check_count
      IMPORTING
        is_check    TYPE ty_check
        iv_expected TYPE i
        iv_found    TYPE i.

    METHODS add_finding
      IMPORTING
        is_check    TYPE ty_check
        iv_rule_id  TYPE zif_cd_ops_types=>ty_rule_id
        iv_severity TYPE zif_cd_ops_types=>ty_severity
        iv_message  TYPE string
        iv_amount   TYPE ty_amount OPTIONAL.

    METHODS file_check
      IMPORTING
        iv_check_code   TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_check) TYPE ty_check.

    METHODS stmt_check
      IMPORTING
        iv_check_code   TYPE zif_cd_ops_types=>ty_check_code
        iv_label        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_check) TYPE ty_check.

    "! Statement check inside Stmt/Ntfctn, else file check
    METHODS current_check
      IMPORTING
        iv_check_code   TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_check) TYPE ty_check.

    METHODS file_key
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ops_types=>ty_object_key.

    METHODS to_amount
      IMPORTING
        iv_value         TYPE string
      RETURNING
        VALUE(rv_amount) TYPE ty_amount.

    METHODS to_count
      IMPORTING
        iv_value        TYPE string
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS to_date
      IMPORTING
        iv_value       TYPE string
      RETURNING
        VALUE(rv_date) TYPE d.

    METHODS to_time
      IMPORTING
        iv_value       TYPE string
      RETURNING
        VALUE(rv_time) TYPE t.

    METHODS to_cdi
      IMPORTING
        iv_value      TYPE string
      RETURNING
        VALUE(rv_cdi) TYPE zif_cd_ebs_types=>ty_cdi.

    METHODS to_reference
      IMPORTING
        iv_value            TYPE string
      RETURNING
        VALUE(rv_reference) TYPE zif_cd_ebs_types=>ty_text35.

ENDCLASS.



CLASS zcl_cd_ebs_parser_camt IMPLEMENTATION.

  METHOD zif_cd_ebs_parser~parse.
    reset_state( iv_file_name ).
    IF is_blank( iv_content ) = abap_true.
      add_finding( is_check    = file_check( gc_check-empty_file )
                   iv_rule_id  = gc_rule-empty
                   iv_severity = zif_cd_ops_types=>gc_severity-block
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-file_is_empty_expected_camt
                                                        iv_v1    = file_key( ) ) ).
      rs_file = ms_file.
      RETURN.
    ENDIF.
    read_document( iv_content ).
    IF ms_file-statements IS INITIAL.
      add_finding( is_check    = file_check( gc_check-empty_file )
                   iv_rule_id  = gc_rule-empty
                   iv_severity = zif_cd_ops_types=>gc_severity-block
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-file_expected_at_least_on_2
                                                        iv_v1    = file_key( ) ) ).
    ENDIF.
    rs_file = ms_file.
  ENDMETHOD.


  METHOD reset_state.
    CLEAR: mt_path, mv_root_name, mv_hdr_depth, mv_stmt_depth, mv_bal_depth, mv_ntry_depth,
           mv_tx_depth, mv_stmt_index, mv_amt_ccy, mv_receiver_by_id, ms_stmt, ms_bal, ms_entry, ms_tx,
           mv_namespace.
    ms_file = VALUE #( file_name = iv_file_name ).
  ENDMETHOD.


  METHOD is_blank.
    rv_blank = xsdbool( iv_content CO | \t\r\n| ).
  ENDMETHOD.


  METHOD read_document.
    TRY.
        DATA(lo_reader) = cl_sxml_string_reader=>create(
                            input = cl_abap_codepage=>convert_to( source = iv_content ) ).
        DO.
          DATA(lo_node) = lo_reader->read_next_node( ).
          IF lo_node IS NOT BOUND.
            EXIT.
          ENDIF.
          process_node( lo_node ).
        ENDDO.
      CATCH cx_sxml_error INTO DATA(lx_sxml).
        DATA(lv_reason) = lx_sxml->get_text( ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e151(zcd_ops) WITH lv_reason
          EXPORTING
            previous = lx_sxml.
    ENDTRY.
    IF ms_file-format IS INITIAL.
      " no element below Document (or no root at all)
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e152(zcd_ops) WITH mv_root_name space.
    ENDIF.
  ENDMETHOD.


  METHOD process_node.
    CASE io_node->type.
      WHEN if_sxml_node=>co_nt_element_open.
        open_element( CAST if_sxml_open_element( io_node ) ).
      WHEN if_sxml_node=>co_nt_element_close.
        close_element( ).
      WHEN if_sxml_node=>co_nt_value.
        on_value( CAST if_sxml_value_node( io_node )->get_value( ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD open_element.
    DATA(lv_name) = CONV ty_name( io_element->qname-name ).
    INSERT lv_name INTO TABLE mt_path.
    DATA(lv_depth) = lines( mt_path ).
    IF lv_depth = gc_depth-root.
      mv_namespace = io_element->qname-namespace.
    ENDIF.
    check_document( iv_name = lv_name iv_depth = lv_depth ).
    IF lv_name = gc_el-amt.
      mv_amt_ccy = attribute_value( io_element = io_element iv_name = gc_attr_ccy ).
    ENDIF.
    open_anchor( iv_name = lv_name iv_depth = lv_depth ).
  ENDMETHOD.


  METHOD check_document.
    CASE iv_depth.
      WHEN gc_depth-root.
        mv_root_name = iv_name.
        IF iv_name <> gc_el-document.
          RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e152(zcd_ops) WITH iv_name space.
        ENDIF.
      WHEN gc_depth-message.
        IF ms_file-format IS NOT INITIAL.
          " A94: exactly one message body per document
          document_finding( iv_reason = gc_doc_reason-second_body iv_value = iv_name ).
          RETURN.
        ENDIF.
        CASE iv_name.
          WHEN gc_el-stmt_message.
            ms_file-format = zif_cd_ebs_types=>gc_format-camt053.
          WHEN gc_el-ntfc_message.
            ms_file-format = zif_cd_ebs_types=>gc_format-camt054.
          WHEN OTHERS.
            RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e152(zcd_ops) WITH mv_root_name iv_name.
        ENDCASE.
        check_namespace( ).
    ENDCASE.
  ENDMETHOD.


  METHOD check_namespace.
    DATA(lv_namespace) = condense( mv_namespace ).
    DATA(lv_type) = COND string( WHEN ms_file-format = zif_cd_ebs_types=>gc_format-camt053 THEN gc_type_053
                                 ELSE gc_type_054 ).
    DATA(lv_stem) = gc_ns_prefix && lv_type && gc_variant.
    DATA(lv_version) = COND string( WHEN find( val = lv_namespace sub = lv_stem ) = 0
                                    THEN substring( val = lv_namespace off = strlen( lv_stem ) ) ).
    DATA(lt_approved) = zcl_cd_ops_util=>split_list( gc_approved_versions ).
    IF lv_version IS INITIAL OR NOT line_exists( lt_approved[ table_line = lv_version ] ).
      document_finding( iv_reason = gc_doc_reason-namespace iv_value = lv_namespace ).
    ENDIF.
  ENDMETHOD.


  METHOD document_finding.
    add_finding( is_check    = file_check( gc_check-camt_document )
                 iv_rule_id  = gc_rule-structure
                 iv_severity = zif_cd_ops_types=>gc_severity-block
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-camt_document
                                                      iv_v1    = file_key( )
                                                      iv_v2    = iv_reason
                                                      iv_v3    = iv_value ) ).
  ENDMETHOD.


  METHOD open_anchor.
    CASE iv_name.
      WHEN gc_el-grp_hdr.
        IF iv_depth = gc_depth-child.
          mv_hdr_depth = iv_depth.
        ENDIF.
      WHEN gc_el-stmt OR gc_el-ntfctn OR gc_el-rpt.
        IF iv_depth = gc_depth-child.
          " A94: the statement element must match the message type (053 Stmt, 054 Ntfctn)
          IF ( iv_name = gc_el-stmt AND ms_file-format = zif_cd_ebs_types=>gc_format-camt053 )
             OR ( iv_name = gc_el-ntfctn AND ms_file-format = zif_cd_ebs_types=>gc_format-camt054 ).
            open_statement( iv_depth ).
          ELSE.
            document_finding( iv_reason = gc_doc_reason-element iv_value = iv_name ).
          ENDIF.
        ENDIF.
      WHEN gc_el-bal.
        IF mv_stmt_depth > 0 AND iv_depth = mv_stmt_depth + 1.
          CLEAR ms_bal.
          mv_bal_depth = iv_depth.
        ENDIF.
      WHEN gc_el-ntry.
        IF mv_stmt_depth > 0 AND iv_depth = mv_stmt_depth + 1.
          open_entry( iv_depth ).
        ENDIF.
      WHEN gc_el-tx_dtls.
        IF mv_ntry_depth > 0.
          CLEAR ms_tx.
          mv_tx_depth = iv_depth.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD attribute_value.
    DATA(lt_attributes) = io_element->get_attributes( ).
    LOOP AT lt_attributes ASSIGNING FIELD-SYMBOL(<lo_attribute>).
      IF <lo_attribute>->qname-name = iv_name.
        rv_value = <lo_attribute>->get_value( ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD close_element.
    DATA(lv_depth) = lines( mt_path ).
    CASE lv_depth.
      WHEN mv_tx_depth.
        INSERT ms_tx INTO TABLE ms_entry-txs.
        CLEAR: ms_tx, mv_tx_depth.
      WHEN mv_ntry_depth.
        close_entry( ).
      WHEN mv_bal_depth.
        close_balance( ).
      WHEN mv_stmt_depth.
        close_statement( ).
      WHEN mv_hdr_depth.
        CLEAR mv_hdr_depth.
    ENDCASE.
    DELETE mt_path INDEX lv_depth.
  ENDMETHOD.


  METHOD on_value.
    DATA(lv_value) = condense( iv_value ).
    IF mv_tx_depth > 0.
      on_tx_value( iv_path = relative_path( mv_tx_depth ) iv_value = lv_value ).
    ELSEIF mv_ntry_depth > 0.
      on_entry_value( iv_path = relative_path( mv_ntry_depth ) iv_value = lv_value ).
    ELSEIF mv_bal_depth > 0.
      on_balance_value( iv_path = relative_path( mv_bal_depth ) iv_value = lv_value ).
    ELSEIF mv_stmt_depth > 0.
      on_statement_value( iv_path = relative_path( mv_stmt_depth ) iv_value = lv_value ).
    ELSEIF mv_hdr_depth > 0.
      on_header_value( iv_path = relative_path( mv_hdr_depth ) iv_value = lv_value ).
    ENDIF.
  ENDMETHOD.


  METHOD relative_path.
    DATA(lv_from) = iv_anchor_depth + 1.
    LOOP AT mt_path ASSIGNING FIELD-SYMBOL(<lv_name>) FROM lv_from.
      rv_path = COND #( WHEN rv_path IS INITIAL THEN <lv_name> ELSE rv_path && gc_path_separator && <lv_name> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD on_header_value.
    CASE iv_path.
      WHEN gc_path-msg_id.
        ms_file-file_id = iv_value.
      WHEN gc_path-cre_dt_tm.
        ms_file-created_date = to_date( iv_value ).
        ms_file-created_time = to_time( iv_value ).
      WHEN gc_path-ctrl_sum.
        ms_file-control_total = to_amount( iv_value ).
      WHEN gc_path-rcpt_name.
        IF mv_receiver_by_id = abap_false.
          ms_file-receiver_id = iv_value.
        ENDIF.
      WHEN OTHERS.
        " MsgRcpt/Id/...: the first identifier wins over the name
        IF zcl_cd_ops_util=>pcre_match( iv_value = iv_path iv_pattern = gc_path-rcpt_id_pattern ) = abap_true
           AND mv_receiver_by_id = abap_false.
          ms_file-receiver_id = iv_value.
          mv_receiver_by_id = abap_true.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD open_statement.
    mv_stmt_index += 1.
    CLEAR ms_stmt.
    ms_stmt-stmt = VALUE #( stmt_key       = zif_cd_ebs_types=>gc_file_stmt_prefix
                                             && |{ mv_stmt_index WIDTH = 4 ALIGN = RIGHT PAD = '0' }|
                            format         = ms_file-format
                            source         = zif_cd_ebs_types=>gc_source-file
                            declared_count = gc_not_declared ).
    mv_stmt_depth = iv_depth.
  ENDMETHOD.


  METHOD on_statement_value.
    CASE iv_path.
      WHEN gc_path-id.
        ms_stmt-stmt-stmt_id = iv_value.
      WHEN gc_path-elctrnc_seq_nb.
        ms_stmt-stmt-stmt_no = iv_value.
      WHEN gc_path-lgl_seq_nb.
        ms_stmt-stmt-legal_seq_no = iv_value.
      WHEN gc_path-cre_dt_tm.
        ms_stmt-stmt-created_date = to_date( iv_value ).
        ms_stmt-stmt-created_time = to_time( iv_value ).
      WHEN gc_path-to_dt_tm.
        ms_stmt-to_date = to_date( iv_value ).
      WHEN gc_path-acct_iban OR gc_path-acct_othr_id.
        ms_stmt-stmt-account_no = iv_value.
      WHEN gc_path-acct_ccy.
        ms_stmt-stmt-currency = iv_value.
      WHEN gc_path-svcr_bicfi OR gc_path-svcr_bic.
        ms_stmt-stmt-bank_id = iv_value.
      WHEN gc_path-svcr_othr_id.
        IF ms_stmt-stmt-bank_id IS INITIAL.
          ms_stmt-stmt-bank_id = iv_value.
        ENDIF.
      WHEN OTHERS.
        on_summary_value( iv_path = iv_path iv_value = iv_value ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_summary_value.
    CASE iv_path.
      WHEN gc_path-ttl_count.
        ms_stmt-declared-total-has_count = abap_true.
        ms_stmt-declared-total-count     = to_count( iv_value ).
      WHEN gc_path-ttl_sum.
        ms_stmt-declared-total-has_sum = abap_true.
        ms_stmt-declared-total-sum     = to_amount( iv_value ).
      WHEN gc_path-ttl_net_amt OR gc_path-ttl_net_amt_v02.
        ms_stmt-declared-has_net    = abap_true.
        ms_stmt-declared-net_amount = to_amount( iv_value ).
      WHEN gc_path-ttl_net_cdi OR gc_path-ttl_net_cdi_v02.
        ms_stmt-declared-net_is_debit = xsdbool( iv_value = gc_indicator-debit ).
      WHEN gc_path-cdt_count.
        ms_stmt-declared-credit = VALUE #( BASE ms_stmt-declared-credit
                                           present = abap_true has_count = abap_true count = to_count( iv_value ) ).
      WHEN gc_path-cdt_sum.
        ms_stmt-declared-credit = VALUE #( BASE ms_stmt-declared-credit
                                           present = abap_true has_sum = abap_true sum = to_amount( iv_value ) ).
      WHEN gc_path-dbt_count.
        ms_stmt-declared-debit = VALUE #( BASE ms_stmt-declared-debit
                                          present = abap_true has_count = abap_true count = to_count( iv_value ) ).
      WHEN gc_path-dbt_sum.
        ms_stmt-declared-debit = VALUE #( BASE ms_stmt-declared-debit
                                          present = abap_true has_sum = abap_true sum = to_amount( iv_value ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD close_statement.
    ms_stmt-stmt-stmt_date = COND #( WHEN ms_stmt-to_date IS NOT INITIAL THEN ms_stmt-to_date
                                     ELSE ms_stmt-stmt-created_date ).
    derive_balances( ).
    default_currency( ).
    validate_summary( ).
    IF ms_stmt-entries = 0.
      add_finding( is_check    = stmt_check( gc_check-no_entries )
                   iv_rule_id  = gc_rule-empty
                   iv_severity = zif_cd_ops_types=>gc_severity-warning
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-statement_expected_entries
                                                        iv_v1    = ms_stmt-stmt-stmt_id ) ).
    ENDIF.
    INSERT ms_stmt-stmt INTO TABLE ms_file-statements.
    INSERT LINES OF ms_stmt-lines INTO TABLE ms_file-lines.
    CLEAR: ms_stmt, mv_stmt_depth.
  ENDMETHOD.


  METHOD derive_balances.
    " Opening from OPBD, PRCD (previous closing) only when OPBD is absent; closing from CLBD
    DATA lv_has_opbd TYPE abap_bool.
    LOOP AT ms_stmt-stmt-balances ASSIGNING FIELD-SYMBOL(<ls_balance>).
      CASE <ls_balance>-bal_type.
        WHEN zif_cd_ebs_types=>gc_balance-opening_booked.
          lv_has_opbd = abap_true.
          ms_stmt-stmt-has_opening = abap_true.
          ms_stmt-stmt-opening_bal = <ls_balance>-amount.
        WHEN zif_cd_ebs_types=>gc_balance-prev_closing.
          IF lv_has_opbd = abap_false.
            ms_stmt-stmt-has_opening = abap_true.
            ms_stmt-stmt-opening_bal = <ls_balance>-amount.
          ENDIF.
        WHEN zif_cd_ebs_types=>gc_balance-closing_booked.
          ms_stmt-stmt-has_closing = abap_true.
          ms_stmt-stmt-closing_bal = <ls_balance>-amount.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD default_currency.
    IF ms_stmt-stmt-currency IS NOT INITIAL.
      RETURN.
    ENDIF.
    ms_stmt-stmt-currency = VALUE #( ms_stmt-stmt-balances[ 1 ]-currency OPTIONAL ).
    IF ms_stmt-stmt-currency IS INITIAL.
      ms_stmt-stmt-currency = VALUE #( ms_stmt-lines[ 1 ]-currency OPTIONAL ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_summary.
    DATA lv_found TYPE ty_amount.
    DATA lv_expected TYPE ty_amount.
    DATA(ls_declared) = ms_stmt-declared.
    DATA(lv_label) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-statement_txssummry
                                            iv_v1    = ms_stmt-stmt-stmt_id ).
    ms_stmt-stmt-has_totals    = xsdbool( ls_declared-credit-present = abap_true OR ls_declared-debit-present = abap_true ).
    ms_stmt-stmt-total_credits = ls_declared-credit-sum.
    ms_stmt-stmt-credit_count  = ls_declared-credit-count.
    ms_stmt-stmt-total_debits  = ls_declared-debit-sum.
    ms_stmt-stmt-debit_count   = ls_declared-debit-count.
    IF ls_declared-total-has_count = abap_true.
      ms_stmt-stmt-declared_count = ls_declared-total-count.
      check_count( is_check    = stmt_check( iv_check_code = gc_check-entry_count
                                             iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ttlntries_nbofntries
                                                                                    iv_v1    = lv_label ) )
                   iv_expected = ls_declared-total-count
                   iv_found    = ms_stmt-entries ).
    ELSEIF ls_declared-credit-has_count = abap_true AND ls_declared-debit-has_count = abap_true.
      ms_stmt-stmt-declared_count = ls_declared-credit-count + ls_declared-debit-count.
    ENDIF.
    IF ls_declared-total-has_sum = abap_true.
      " TtlNtries/Sum is the sum of the absolute entry amounts
      lv_found = ms_stmt-credit-sum + ms_stmt-debit-sum.
      check_total( is_check    = stmt_check( iv_check_code = gc_check-sum_mismatch
                                             iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ttlntries_sum
                                                                                    iv_v1    = lv_label ) )
                   iv_expected = ls_declared-total-sum
                   iv_found    = lv_found ).
    ENDIF.
    IF ls_declared-has_net = abap_true.
      lv_found    = ms_stmt-credit-sum - ms_stmt-debit-sum.
      lv_expected = COND #( WHEN ls_declared-net_is_debit = abap_true THEN - ls_declared-net_amount
                            ELSE ls_declared-net_amount ).
      check_total( is_check    = stmt_check( iv_check_code = gc_check-net_mismatch
                                             iv_label      =
                                               zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ttlntries_ttlnetntry_signed
                                                                                    iv_v1    = lv_label ) )
                   iv_expected = lv_expected
                   iv_found    = lv_found ).
    ENDIF.
    validate_side( is_declared   = ls_declared-credit
                   is_parsed     = ms_stmt-credit
                   iv_count_code = gc_check-cdt_entry_count
                   iv_sum_code   = gc_check-cdt_sum
                   iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ttlcdtntries iv_v1 = lv_label ) ).
    validate_side( is_declared   = ls_declared-debit
                   is_parsed     = ms_stmt-debit
                   iv_count_code = gc_check-dbt_entry_count
                   iv_sum_code   = gc_check-dbt_sum
                   iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ttldbtntries iv_v1 = lv_label ) ).
  ENDMETHOD.


  METHOD validate_side.
    IF is_declared-has_count = abap_true.
      check_count( is_check    = stmt_check( iv_check_code = iv_count_code iv_label =
        zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-nbofntries
                                                                                                             iv_v1    = iv_label ) )
                   iv_expected = is_declared-count
                   iv_found    = is_parsed-count ).
    ENDIF.
    IF is_declared-has_sum = abap_true.
      check_total( is_check    = stmt_check( iv_check_code = iv_sum_code iv_label =
        zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-sum
                                                                                                           iv_v1    = iv_label ) )
                   iv_expected = is_declared-sum
                   iv_found    = is_parsed-sum ).
    ENDIF.
  ENDMETHOD.


  METHOD on_balance_value.
    CASE iv_path.
      WHEN gc_path-bal_code.
        ms_bal-balance-bal_type = iv_value.
      WHEN gc_path-bal_prtry.
        IF ms_bal-balance-bal_type IS INITIAL.
          ms_bal-balance-bal_type = iv_value.
        ENDIF.
      WHEN gc_path-amt.
        ms_bal-balance-amount   = to_amount( iv_value ).
        ms_bal-balance-currency = mv_amt_ccy.
      WHEN gc_path-cdt_dbt_ind.
        ms_bal-is_debit = xsdbool( iv_value = gc_indicator-debit ).
      WHEN gc_path-dt OR gc_path-dt_tm.
        ms_bal-balance-bal_date = to_date( iv_value ).
    ENDCASE.
  ENDMETHOD.


  METHOD close_balance.
    IF ms_bal-is_debit = abap_true.
      ms_bal-balance-amount = - ms_bal-balance-amount.
    ENDIF.
    INSERT ms_bal-balance INTO TABLE ms_stmt-stmt-balances.
    CLEAR: ms_bal, mv_bal_depth.
  ENDMETHOD.


  METHOD open_entry.
    CLEAR ms_entry.
    mv_ntry_depth = iv_depth.
    ms_stmt-entries += 1.
    ms_file-record_count += 1.
  ENDMETHOD.


  METHOD on_entry_value.
    CASE iv_path.
      WHEN gc_path-amt.
        ms_entry-amount   = to_amount( iv_value ).
        ms_entry-currency = mv_amt_ccy.
      WHEN gc_path-cdt_dbt_ind.
        ms_entry-cdi = to_cdi( iv_value ).
      WHEN gc_path-rvsl_ind.
        ms_entry-reversal = xsdbool( iv_value = gc_true OR iv_value = gc_true_digit ).
      WHEN gc_path-bookg_dt OR gc_path-bookg_dt_tm.
        ms_entry-booking_date = to_date( iv_value ).
      WHEN gc_path-val_dt OR gc_path-val_dt_tm.
        ms_entry-value_date = to_date( iv_value ).
      WHEN gc_path-acct_svcr_ref.
        ms_entry-bank_ref = iv_value.
      WHEN gc_path-addtl_ntry_inf.
        ms_entry-addtl_info = iv_value.
      WHEN gc_path-sts OR gc_path-sts_cd.
        ms_entry-status = to_upper( iv_value ).
      WHEN OTHERS.
        apply_btc( EXPORTING iv_path  = iv_path
                             iv_value = iv_value
                   CHANGING  cs_btc   = ms_entry-btc ).
    ENDCASE.
  ENDMETHOD.


  METHOD close_entry.
    " A93: only booked entries are postable; pending / information entries are quarantined
    IF ms_entry-status <> gc_status_booked.
      ms_stmt-entries -= 1.
      add_finding( is_check    = stmt_check( gc_check-not_booked )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-warning
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-entry_not_booked
                                                        iv_v1    = ms_entry-bank_ref
                                                        iv_v2    = ms_entry-amount
                                                        iv_v3    = ms_entry-cdi
                                                        iv_v4    = ms_entry-status ) ).
      CLEAR: ms_entry, mv_ntry_depth.
      RETURN.
    ENDIF.
    CASE ms_entry-cdi.
      WHEN zif_cd_ebs_types=>gc_cdi-credit.
        ms_stmt-credit-count += 1.
        ms_stmt-credit-sum   += ms_entry-amount.
      WHEN zif_cd_ebs_types=>gc_cdi-debit.
        ms_stmt-debit-count += 1.
        ms_stmt-debit-sum   += ms_entry-amount.
    ENDCASE.
    " A92: details become lines only when they reconcile to the entry
    DATA(lv_problem) = detail_problem( ).
    IF lv_problem IS INITIAL AND split_by_transaction( ) = abap_true.
      LOOP AT ms_entry-txs ASSIGNING FIELD-SYMBOL(<ls_tx>).
        append_line( is_tx = <ls_tx> iv_amount = <ls_tx>-amount iv_currency = <ls_tx>-currency ).
      ENDLOOP.
    ELSEIF lv_problem IS INITIAL.
      DATA(ls_first) = VALUE ty_tx( ms_entry-txs[ 1 ] OPTIONAL ).
      append_line( is_tx = ls_first iv_amount = ms_entry-amount iv_currency = ms_entry-currency ).
    ELSE.
      " One entry-level line: the whole-entry amount never carries one detail's references
      append_line( is_tx = VALUE #( ) iv_amount = ms_entry-amount iv_currency = ms_entry-currency ).
      DATA(ls_entry_line) = ms_stmt-lines[ lines( ms_stmt-lines ) ].
      DATA(lv_details) = REDUCE ty_amount( INIT lv_sum = CONV ty_amount( 0 )
                                           FOR ls_detail IN ms_entry-txs WHERE ( has_amount = abap_true )
                                           NEXT lv_sum = lv_sum + ls_detail-amount ).
      add_finding( is_check    = VALUE #( object_type = gc_object-line
                                          object_key  = zcl_cd_ebs_finding=>line_key( ls_entry_line )
                                          check_code  = lv_problem )
                   iv_rule_id  = gc_rule-control_total
                   iv_severity = COND #( WHEN lv_problem = gc_check-batch_mismatch
                                         THEN zif_cd_ops_types=>gc_severity-block
                                         ELSE zif_cd_ops_types=>gc_severity-error )
                   iv_message  = COND #( WHEN lv_problem = gc_check-batch_mismatch
                                         THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-batch_mismatch
                                                                     iv_v1    = ms_entry-bank_ref
                                                                     iv_v2    = lv_details
                                                                     iv_v3    = ms_entry-amount
                                                                     iv_v4    = ms_entry-currency )
                                         ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-batch_detail_amount
                                                                     iv_v1    = ms_entry-bank_ref ) ) ).
    ENDIF.
    CLEAR: ms_entry, mv_ntry_depth.
  ENDMETHOD.


  METHOD detail_problem.
    IF ms_entry-txs IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( ms_entry-txs ) > 1 AND line_exists( ms_entry-txs[ has_amount = abap_false ] ).
      rv_check_code = gc_check-detail_amount.
      RETURN.
    ENDIF.
    IF NOT line_exists( ms_entry-txs[ has_amount = abap_true ] ).
      RETURN.
    ENDIF.
    DATA(lv_sum) = CONV ty_amount( 0 ).
    LOOP AT ms_entry-txs ASSIGNING FIELD-SYMBOL(<ls_tx>) WHERE has_amount = abap_true.
      lv_sum += <ls_tx>-amount.
      IF <ls_tx>-currency IS NOT INITIAL AND ms_entry-currency IS NOT INITIAL AND <ls_tx>-currency <> ms_entry-currency.
        rv_check_code = gc_check-batch_mismatch.
        RETURN.
      ENDIF.
    ENDLOOP.
    IF lv_sum <> ms_entry-amount.
      rv_check_code = gc_check-batch_mismatch.
    ENDIF.
  ENDMETHOD.


  METHOD split_by_transaction.
    IF lines( ms_entry-txs ) < 2.
      RETURN.
    ENDIF.
    rv_split = xsdbool( NOT line_exists( ms_entry-txs[ has_amount = abap_false ] ) ).
  ENDMETHOD.


  METHOD on_tx_value.
    CASE iv_path.
      WHEN gc_path-amt.
        ms_tx-has_amount = abap_true.
        ms_tx-amount     = to_amount( iv_value ).
        ms_tx-currency   = mv_amt_ccy.
      WHEN gc_path-tx_amt.
        " older versions: amount only in AmtDtls/TxAmt/Amt; TxDtls/Amt wins when present
        IF ms_tx-has_amount = abap_false.
          ms_tx-has_amount = abap_true.
          ms_tx-amount     = to_amount( iv_value ).
          ms_tx-currency   = mv_amt_ccy.
        ENDIF.
      WHEN gc_path-cdt_dbt_ind.
        ms_tx-cdi = to_cdi( iv_value ).
      WHEN gc_path-rtr_reason.
        ms_tx-return_reason = iv_value.
      WHEN gc_path-addtl_tx_inf.
        ms_tx-addtl_info = iv_value.
      WHEN OTHERS.
        on_tx_reference( iv_path = iv_path iv_value = iv_value ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_tx_reference.
    CASE iv_path.
      WHEN gc_path-ref_end_to_end.
        ms_tx-end_to_end_id = to_reference( iv_value ).
      WHEN gc_path-ref_instr_id.
        ms_tx-instr_id = to_reference( iv_value ).
      WHEN gc_path-ref_chq_nb.
        ms_tx-check_no = to_reference( iv_value ).
      WHEN gc_path-ref_svcr_ref.
        ms_tx-bank_ref = to_reference( iv_value ).
      WHEN gc_path-ref_msg_id.
        ms_tx-cust_ref = to_reference( iv_value ).
      WHEN OTHERS.
        apply_btc( EXPORTING iv_path  = iv_path
                             iv_value = iv_value
                   CHANGING  cs_btc   = ms_tx-btc ).
    ENDCASE.
  ENDMETHOD.


  METHOD apply_btc.
    CASE iv_path.
      WHEN gc_path-btc_domain.
        cs_btc-domain = iv_value.
      WHEN gc_path-btc_family.
        cs_btc-family = iv_value.
      WHEN gc_path-btc_subfamily.
        cs_btc-subfamily = iv_value.
      WHEN gc_path-btc_prtry_code.
        cs_btc-prtry_code = iv_value.
      WHEN gc_path-btc_prtry_issr.
        cs_btc-prtry_issuer = iv_value.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    cs_btc-present = abap_true.
  ENDMETHOD.


  METHOD append_line.
    DATA(ls_line) = VALUE zif_cd_ebs_types=>ty_line(
      stmt_key      = ms_stmt-stmt-stmt_key
      line_no       = lines( ms_stmt-lines ) + 1
      cdi           = COND #( WHEN is_tx-cdi IS NOT INITIAL THEN is_tx-cdi ELSE ms_entry-cdi )
      amount        = abs( iv_amount )
      currency      = COND #( WHEN iv_currency IS NOT INITIAL THEN iv_currency ELSE ms_stmt-stmt-currency )
      reversal      = ms_entry-reversal
      entry_status  = ms_entry-status
      booking_date  = ms_entry-booking_date
      value_date    = ms_entry-value_date
      end_to_end_id = is_tx-end_to_end_id
      instr_id      = is_tx-instr_id
      check_no      = is_tx-check_no
      cust_ref      = is_tx-cust_ref
      bank_ref      = COND #( WHEN is_tx-bank_ref IS NOT INITIAL THEN is_tx-bank_ref ELSE ms_entry-bank_ref )
      return_reason = is_tx-return_reason
      addtl_info    = COND #( WHEN is_tx-addtl_info IS NOT INITIAL THEN is_tx-addtl_info ELSE ms_entry-addtl_info ) ).
    apply_code( EXPORTING is_btc  = COND #( WHEN is_tx-btc-present = abap_true THEN is_tx-btc ELSE ms_entry-btc )
                CHANGING  cs_line = ls_line ).
    ls_line-reference = primary_reference( ls_line ).
    INSERT ls_line INTO TABLE ms_stmt-lines.
  ENDMETHOD.


  METHOD apply_code.
    cs_line-domain       = is_btc-domain.
    cs_line-family       = is_btc-family.
    cs_line-subfamily    = is_btc-subfamily.
    cs_line-prtry_code   = is_btc-prtry_code.
    cs_line-prtry_issuer = is_btc-prtry_issuer.
    IF is_btc-domain IS NOT INITIAL.
      cs_line-scheme   = zif_cd_ebs_types=>gc_scheme-iso.
      cs_line-btc_code = |{ is_btc-domain }{ gc_btc_separator }{ is_btc-family }{ gc_btc_separator }{ is_btc-subfamily }|.
    ELSEIF is_btc-prtry_code IS NOT INITIAL.
      cs_line-scheme   = zif_cd_ebs_types=>gc_scheme-prtry.
      cs_line-btc_code = is_btc-prtry_code.
    ENDIF.
  ENDMETHOD.


  METHOD primary_reference.
    " Cheque number (ChqNb, e.g. families ICHQ/RCHQ) -> EndToEndId -> InstrId -> AcctSvcrRef
    rv_reference = COND #( WHEN is_line-check_no IS NOT INITIAL THEN is_line-check_no
                           WHEN is_line-end_to_end_id IS NOT INITIAL THEN is_line-end_to_end_id
                           WHEN is_line-instr_id IS NOT INITIAL THEN is_line-instr_id
                           ELSE is_line-bank_ref ).
  ENDMETHOD.


  METHOD check_total.
    IF iv_expected = iv_found.
      RETURN.
    ENDIF.
    DATA lv_difference TYPE ty_amount.
    lv_difference = iv_found - iv_expected.
    add_finding( is_check    = is_check
                 iv_rule_id  = gc_rule-control_total
                 iv_severity = zif_cd_ops_types=>gc_severity-block
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-expected_found_entries
                                                      iv_v1    = is_check-label
                                                      iv_v2    = iv_expected
                                                      iv_v3    = iv_found )
                 iv_amount   = lv_difference ).
  ENDMETHOD.


  METHOD check_count.
    IF iv_expected = iv_found.
      RETURN.
    ENDIF.
    add_finding( is_check    = is_check
                 iv_rule_id  = gc_rule-count
                 iv_severity = zif_cd_ops_types=>gc_severity-error
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-expected_found_entries_2
                                                      iv_v1    = is_check-label
                                                      iv_v2    = iv_expected
                                                      iv_v3    = iv_found ) ).
  ENDMETHOD.


  METHOD add_finding.
    INSERT VALUE #( object_type = is_check-object_type
                    object_key  = is_check-object_key
                    rule_id     = iv_rule_id
                    check_code  = is_check-check_code
                    severity    = iv_severity
                    amount      = iv_amount
                    currency    = COND #( WHEN iv_amount IS NOT INITIAL THEN ms_stmt-stmt-currency )
                    message     = iv_message ) INTO TABLE ms_file-findings.
  ENDMETHOD.


  METHOD file_check.
    rs_check = VALUE #( object_type = gc_object-file
                        object_key  = file_key( )
                        check_code  = iv_check_code ).
  ENDMETHOD.


  METHOD stmt_check.
    rs_check = VALUE #( object_type = gc_object-statement
                        object_key  = ms_stmt-stmt-stmt_key
                        check_code  = iv_check_code
                        label       = iv_label ).
  ENDMETHOD.


  METHOD current_check.
    rs_check = COND #( WHEN mv_stmt_depth > 0 THEN stmt_check( iv_check_code )
                       ELSE file_check( iv_check_code ) ).
  ENDMETHOD.


  METHOD file_key.
    rv_key = COND #( WHEN ms_file-file_name IS NOT INITIAL THEN ms_file-file_name ELSE ms_file-file_id ).
  ENDMETHOD.


  METHOD to_amount.
    " ISO amount: digits with at most one decimal point, never signed
    IF iv_value IS NOT INITIAL AND iv_value CO gc_decimal_chars AND iv_value CA gc_digits
       AND count( val = iv_value sub = gc_decimal_point ) <= 1 AND strlen( iv_value ) <= gc_max_amount_length.
      rv_amount = CONV decfloat34( iv_value ).
      RETURN.
    ENDIF.
    " A94: an amount that is not a decimal blocks - never a silent zero
    add_finding( is_check    = current_check( gc_check-invalid_amount )
                 iv_rule_id  = gc_rule-structure
                 iv_severity = zif_cd_ops_types=>gc_severity-block
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-element_expected_decimal_am
                                                      iv_v1    = concat_lines_of( table = mt_path sep = gc_path_separator )
                                                      iv_v2    = iv_value ) ).
  ENDMETHOD.


  METHOD to_count.
    IF iv_value IS NOT INITIAL AND iv_value CO gc_digits AND strlen( iv_value ) <= gc_max_count_digits.
      rv_count = iv_value.
      RETURN.
    ENDIF.
    " A94: a count that is not a number blocks - never a silent zero
    IF iv_value IS NOT INITIAL.
      add_finding( is_check    = current_check( gc_check-invalid_count )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-block
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-invalid_count
                                                        iv_v1    = concat_lines_of( table = mt_path sep = gc_path_separator )
                                                        iv_v2    = iv_value ) ).
    ENDIF.
  ENDMETHOD.


  METHOD to_date.
    " ISODate or ISODateTime: the first 10 characters are YYYY-MM-DD
    DATA lv_days TYPE i.
    IF strlen( iv_value ) >= gc_iso_date_length.
      DATA(lv_digits) = replace( val = substring( val = iv_value len = gc_iso_date_length )
                                 sub = gc_date_dash with = `` occ = 0 ).
      IF lv_digits CO gc_digits AND strlen( lv_digits ) = gc_date_digits.
        rv_date = lv_digits.
        lv_days = rv_date.
      ENDIF.
    ENDIF.
    IF lv_days = 0.
      CLEAR rv_date.
      add_finding( is_check    = current_check( gc_check-invalid_date )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-error
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-element_expected_date_yyyy
                                                        iv_v1    = concat_lines_of( table = mt_path sep = gc_path_separator )
                                                        iv_v2    = iv_value ) ).
    ENDIF.
  ENDMETHOD.


  METHOD to_time.
    " ISODateTime: hh:mm:ss after the 'T'; a time zone suffix is ignored (local time as delivered)
    IF strlen( iv_value ) < gc_iso_time_offset + gc_iso_time_length.
      RETURN.
    ENDIF.
    DATA(lv_digits) = replace( val = substring( val = iv_value off = gc_iso_time_offset len = gc_iso_time_length )
                               sub = gc_time_colon with = `` occ = 0 ).
    IF lv_digits CO gc_digits AND strlen( lv_digits ) = gc_time_digits.
      rv_time = lv_digits.
    ENDIF.
  ENDMETHOD.


  METHOD to_cdi.
    rv_cdi = COND #( WHEN iv_value = gc_indicator-credit THEN zif_cd_ebs_types=>gc_cdi-credit
                     WHEN iv_value = gc_indicator-debit  THEN zif_cd_ebs_types=>gc_cdi-debit ).
  ENDMETHOD.


  METHOD to_reference.
    IF iv_value <> gc_not_provided.
      rv_reference = iv_value.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
