*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the account flow reconciliation on cl_cds_test_environment
*& doubles of the direct dependencies of each view: the journal signatures
*& (lines of the window, the flow's ledger, the account and currency
*& range, grouped per signature), the positions (closing = opening +
*& journal movement, Unexplained = closing - accounted for, an unsigned
*& amount takes the sign of the balance, not evaluated and no control
*& point without an amount) and the control tags (none, open, pending,
*& reconciled). Does not prove live SAP runtime behavior. VERIFY-ADT:
*& doubles of CDS view dependencies with parameters and of the released
*& view I_JournalEntryItem (7.58) - V149.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! ZI_CA_OPSFLOWGLSIG: journal lines of the flow accounts in the window, per signature
CLASS ltc_gl_sig DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS window_ledger_and_range FOR TESTING.
ENDCLASS.


CLASS ltc_gl_sig IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSFLOWGLSIG' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_accounts TYPE STANDARD TABLE OF zi_ca_opsflowacct WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF i_journalentryitem WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " cash account 113100 of ZT01 in USD only, leading ledger
    lt_accounts = VALUE #( ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'CASH' accountrole = 'CASH'
                             companycode = 'ZT01' glaccountfrom = '0000113100' glaccountto = '0000113100'
                             currencylow = 'USD' currencyhigh = 'USD' linesource = 'G' ledger = '0L' ) ).
    " two bank statement credits in the window (one signature), one before the window, one in another ledger, one
    " in EUR, one on another account
    lt_lines = VALUE #(
      ( ledger = '0L' companycode = 'ZT01' fiscalyear = '2026' accountingdocument = '0100000001' ledgergllineitem = '000001'
        glaccount = '0000113100' transactioncurrency = 'USD' postingdate = '20261105' referencedocumenttype = 'BKPF'
        accountingdocumenttype = 'ZB' debitcreditcode = 'H' amountintransactioncurrency = '-1000.00' )
      ( ledger = '0L' companycode = 'ZT01' fiscalyear = '2026' accountingdocument = '0100000002' ledgergllineitem = '000001'
        glaccount = '0000113100' transactioncurrency = 'USD' postingdate = '20261106' referencedocumenttype = 'BKPF'
        accountingdocumenttype = 'ZB' debitcreditcode = 'H' amountintransactioncurrency = '-1100.00' )
      ( ledger = '0L' companycode = 'ZT01' fiscalyear = '2026' accountingdocument = '0100000003' ledgergllineitem = '000001'
        glaccount = '0000113100' transactioncurrency = 'USD' postingdate = '20261031' referencedocumenttype = 'BKPF'
        accountingdocumenttype = 'ZB' debitcreditcode = 'H' amountintransactioncurrency = '-5.00' )
      ( ledger = '2L' companycode = 'ZT01' fiscalyear = '2026' accountingdocument = '0100000001' ledgergllineitem = '000001'
        glaccount = '0000113100' transactioncurrency = 'USD' postingdate = '20261105' referencedocumenttype = 'BKPF'
        accountingdocumenttype = 'ZB' debitcreditcode = 'H' amountintransactioncurrency = '-1000.00' )
      ( ledger = '0L' companycode = 'ZT01' fiscalyear = '2026' accountingdocument = '0100000004' ledgergllineitem = '000001'
        glaccount = '0000113100' transactioncurrency = 'EUR' postingdate = '20261105' referencedocumenttype = 'BKPF'
        accountingdocumenttype = 'ZB' debitcreditcode = 'S' amountintransactioncurrency = '7.00' )
      ( ledger = '0L' companycode = 'ZT01' fiscalyear = '2026' accountingdocument = '0100000005' ledgergllineitem = '000001'
        glaccount = '0000113200' transactioncurrency = 'USD' postingdate = '20261105' referencedocumenttype = 'BKPF'
        accountingdocumenttype = 'ZB' debitcreditcode = 'S' amountintransactioncurrency = '9.00' ) ).
    go_env->insert_test_data( lt_accounts ).
    go_env->insert_test_data( lt_lines ).
  ENDMETHOD.


  " Rule: only lines of the window, the flow's ledger, the account range and currency count - grouped per signature
  METHOD window_ledger_and_range.
    SELECT flowaccount, currency, debitcredit, amount, linecount
      FROM zi_ca_opsflowglsig( p_datefrom = '20261101', p_dateto = '20261115' )
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One signature' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-amount exp = '-2100.00' msg = 'Two credits of the window' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-linecount exp = 2 msg = 'Two lines' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSFLOWPOS: closing, accounted for, Unexplained and the evaluation status
CLASS ltc_pos DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS closing_and_unexplained   FOR TESTING.
    METHODS unsigned_takes_sign       FOR TESTING.
    METHODS not_evaluated_no_amount   FOR TESTING.
    METHODS outside_no_control_point  FOR TESTING.
ENDCLASS.


CLASS ltc_pos IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSFLOWPOS' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_sums TYPE STANDARD TABLE OF zi_ca_opsflowpossum WITH EMPTY KEY.
    DATA lt_accounts TYPE STANDARD TABLE OF zi_ca_opsflowacct WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_accounts = VALUE #(
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'CLEARING' accountrole = 'CLEARING' companycode = 'ZT01' )
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'RETURNS' accountrole = 'CLARIFICATION' companycode = 'ZT01' )
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'CASH' accountrole = 'CASH' companycode = 'ZT01' )
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'EXPENSE' accountrole = 'OUTSIDE' companycode = 'ZT01' ) ).
    " clearing: opening 0, movement -40, breaks explain -30 (signed) -> unexplained -10
    " returns clearing: movement -300, one open returns lot finding of 300 (unsigned) -> unexplained 0
    " cash: movement -1800, no evaluation -> not evaluated; expense: outside the control chain
    lt_sums = VALUE #(
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'CLEARING' currency = 'USD' openingamount = 0
        glmovement = '-40.00' signedamount = '-30.00' evaluatedcount = 1 itemcount = 2 )
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'RETURNS' currency = 'USD' glmovement = '-300.00'
        unsignedamount = '300.00' evaluatedcount = 1 itemcount = 1 )
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'CASH' currency = 'USD' openingamount = '5000.00'
        glmovement = '-1800.00' )
      ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'EXPENSE' currency = 'USD' glmovement = '2100.00' ) ).
    go_env->insert_test_data( i_data             = lt_sums
                              i_parameter_values = VALUE #( ( parameter_name = 'P_DATEFROM' parameter_value = '20261101' )
                                                            ( parameter_name = 'P_DATETO' parameter_value = '20261115' ) ) ).
    " ZI_CA_OpsFlowEvlAll stays empty: no evaluation row without a currency
    go_env->insert_test_data( lt_accounts ).
  ENDMETHOD.


  " Rule: closing = opening + journal movement; Unexplained = closing - what the checks account for
  METHOD closing_and_unexplained.
    SELECT SINGLE closingamount, accountedamount, unexplainedamount, evalstatus
      FROM zi_ca_opsflowpos( p_datefrom = '20261101', p_dateto = '20261115' )
      WHERE flowaccount = 'CLEARING'
      INTO @DATA(ls_row).
    cl_abap_unit_assert=>assert_equals( act = ls_row-closingamount exp = '-40.00' msg = 'Closing' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-unexplainedamount exp = '-10.00' msg = 'Unexplained' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-evalstatus exp = 'E' msg = 'Evaluated' ).
  ENDMETHOD.


  " Rule: an unsigned amount (open exceptions) takes the sign of the closing position
  METHOD unsigned_takes_sign.
    SELECT SINGLE accountedamount, unexplainedamount
      FROM zi_ca_opsflowpos( p_datefrom = '20261101', p_dateto = '20261115' )
      WHERE flowaccount = 'RETURNS'
      INTO @DATA(ls_row).
    cl_abap_unit_assert=>assert_equals( act = ls_row-accountedamount exp = '-300.00' msg = 'Credit like the balance' ).
    cl_abap_unit_assert=>assert_initial( act = ls_row-unexplainedamount msg = 'Fully explained' ).
  ENDMETHOD.


  " Rule: no evaluation at "to" - not evaluated, no Unexplained amount (grey, never zero by mistake)
  METHOD not_evaluated_no_amount.
    SELECT SINGLE closingamount, unexplainedamount, evalstatus
      FROM zi_ca_opsflowpos( p_datefrom = '20261101', p_dateto = '20261115' )
      WHERE flowaccount = 'CASH'
      INTO @DATA(ls_row).
    cl_abap_unit_assert=>assert_equals( act = ls_row-closingamount exp = '3200.00' msg = 'Closing still shown' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-evalstatus exp = 'N' msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_initial( act = ls_row-unexplainedamount msg = 'No amount' ).
  ENDMETHOD.


  " Rule: an account outside the control chain is shown with "no control point"
  METHOD outside_no_control_point.
    SELECT SINGLE closingamount, evalstatus
      FROM zi_ca_opsflowpos( p_datefrom = '20261101', p_dateto = '20261115' )
      WHERE flowaccount = 'EXPENSE'
      INTO @DATA(ls_row).
    cl_abap_unit_assert=>assert_equals( act = ls_row-closingamount exp = '2100.00' msg = 'Shown' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-evalstatus exp = 'X' msg = 'No control point' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSFLOWSTGTAG: control tag of every stage per company code
CLASS ltc_tag DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS none_open_pending_reconciled FOR TESTING.
ENDCLASS.


CLASS ltc_tag IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSFLOWSTGTAG' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_stages TYPE STANDARD TABLE OF zca_ops_flwstg WITH EMPTY KEY.
    DATA lt_accounts TYPE STANDARD TABLE OF zi_ca_opsflowacct WITH EMPTY KEY.
    DATA lt_tags TYPE STANDARD TABLE OF zi_ca_opsflowtag WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_stages = VALUE #( ( area = 'ZT_OPS_A' flow_id = 'DISB' stage_id = 'REQUEST' seq = 10 active = abap_true )
                         ( area = 'ZT_OPS_A' flow_id = 'DISB' stage_id = 'PAYRUN' seq = 20 active = abap_true )
                         ( area = 'ZT_OPS_A' flow_id = 'DISB' stage_id = 'BANK_PAID' seq = 30 active = abap_true )
                         ( area = 'ZT_OPS_A' flow_id = 'DISB' stage_id = 'GL_TRANSFER' seq = 60 active = abap_true )
                         ( area = 'ZT_OPS_A' flow_id = 'DISB' stage_id = 'RETIRED' seq = 70 active = abap_false ) ).
    " two accounts of one company code: one row per stage, not per account
    lt_accounts = VALUE #( ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'CASH' companycode = 'ZT01' )
                           ( area = 'ZT_OPS_A' flowid = 'DISB' flowaccount = 'CLEARING' companycode = 'ZT01' ) ).
    lt_tags = VALUE #( ( area = 'ZT_OPS_A' flowid = 'DISB' stageid = 'PAYRUN' companycode = 'ZT01'
                         openexceptions = 3 pendingchecks = 0 checkcount = 1 )
                       ( area = 'ZT_OPS_A' flowid = 'DISB' stageid = 'BANK_PAID' companycode = 'ZT01'
                         openexceptions = 0 pendingchecks = 1 checkcount = 2 )
                       ( area = 'ZT_OPS_A' flowid = 'DISB' stageid = 'GL_TRANSFER' companycode = 'ZT01'
                         openexceptions = 0 pendingchecks = 0 checkcount = 1 ) ).
    go_env->insert_test_data( lt_stages ).
    go_env->insert_test_data( lt_accounts ).
    go_env->insert_test_data( lt_tags ).
  ENDMETHOD.


  " Rule: no check = N (never reconciled), open exceptions = O, a check without a current result = P, else R
  METHOD none_open_pending_reconciled.
    SELECT stageid, controlstatus, openexceptions FROM zi_ca_opsflowstgtag ORDER BY stageorder INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 4 msg = 'Active stages, one per company code' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-controlstatus exp = 'N' msg = 'Request: no control' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-controlstatus exp = 'O' msg = 'Payment run: open' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-openexceptions exp = 3 msg = 'Three open' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-controlstatus exp = 'P' msg = 'Bank: pending' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 4 ]-controlstatus exp = 'R' msg = 'G/L transfer: reconciled' ).
  ENDMETHOD.

ENDCLASS.
