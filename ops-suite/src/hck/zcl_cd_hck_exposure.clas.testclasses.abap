*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_exposure.clas.testclasses.abap
*& Purpose:
*& Unit tests of the exposure per currency: items of two currencies give two
*& totals with count, amount, oldest age and earliest deadline, never one
*& sum; the summary finding is information with count, amount, currency and
*& the control; a placeholder or blank value is not configured. Pure, no
*& doubles needed; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
CLASS ltc_exposure DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        usd      TYPE zif_ca_ops_types=>ty_currency VALUE 'USD',
        cad      TYPE zif_ca_ops_types=>ty_currency VALUE 'CAD',
        early    TYPE d VALUE '20261117',
        late     TYPE d VALUE '20261120',
        control  TYPE string VALUE `ECT_PENDING`,
        unset    TYPE string VALUE `PENDING=‹values›`,
        set      TYPE string VALUE `PENDING=1`,
        key_old  TYPE zif_ca_ops_types=>ty_object_key VALUE 'CHQ_OLD',
        key_new  TYPE zif_ca_ops_types=>ty_object_key VALUE 'CHQ_NEW',
        key_cad  TYPE zif_ca_ops_types=>ty_object_key VALUE 'CHQ_CAD',
        amount_a TYPE zif_ca_ops_types=>ty_amount VALUE '100.00',
        amount_b TYPE zif_ca_ops_types=>ty_amount VALUE '50.25',
        sum_usd  TYPE zif_ca_ops_types=>ty_amount VALUE '150.25',
      END OF gc.

    METHODS totals_per_currency FOR TESTING.
    METHODS summary_is_information FOR TESTING.
    METHODS placeholder_is_unset FOR TESTING.

    METHODS items
      RETURNING
        VALUE(rt_items) TYPE zif_cd_hck_cheque_types=>tt_item.
ENDCLASS.


CLASS ltc_exposure IMPLEMENTATION.

  METHOD items.
    rt_items = VALUE #( ( object_key = gc-key_new amount = gc-amount_a currency = gc-usd age = 3 deadline = gc-late )
                        ( object_key = gc-key_old amount = gc-amount_b currency = gc-usd age = 9 deadline = gc-early )
                        ( object_key = gc-key_cad amount = gc-amount_a currency = gc-cad age = 1 ) ).
  ENDMETHOD.


  " Rule: one total per currency - count, sum, the oldest item and the earliest deadline
  METHOD totals_per_currency.
    DATA(lt_totals) = zcl_cd_hck_exposure=>totals( items( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_totals ) exp = 2 msg = 'Two currencies, two totals' ).
    DATA(ls_usd) = lt_totals[ currency = gc-usd ].
    cl_abap_unit_assert=>assert_equals( act = ls_usd-item_count exp = 2 msg = 'Two USD items' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-amount exp = gc-sum_usd msg = 'USD amount summed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-oldest exp = 9 msg = 'Oldest age' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-oldest_key exp = gc-key_old msg = 'Oldest item' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-deadline exp = gc-early msg = 'Earliest deadline' ).
    cl_abap_unit_assert=>assert_equals( act = lt_totals[ currency = gc-cad ]-amount exp = gc-amount_a
                                        msg = 'CAD never added to USD' ).
  ENDMETHOD.


  " Rule: the summary per currency is an information finding (no exception) with count and amount
  METHOD summary_is_information.
    DATA(lt_findings) = zcl_cd_hck_exposure=>total_findings( it_totals  = zcl_cd_hck_exposure=>totals( items( ) )
                                                             iv_control = gc-control ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_findings ) exp = 2 msg = 'One finding per currency' ).
    LOOP AT lt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>) WHERE currency = gc-usd.
      cl_abap_unit_assert=>assert_equals( act = <ls_finding>-severity exp = zif_ca_ops_types=>gc_severity-info
                                          msg = 'Information' ).
      cl_abap_unit_assert=>assert_equals( act = <ls_finding>-item_count exp = 2 msg = 'Count' ).
      cl_abap_unit_assert=>assert_equals( act = <ls_finding>-amount exp = gc-sum_usd msg = 'Amount' ).
      cl_abap_unit_assert=>assert_equals( act = <ls_finding>-check_code
                                          exp = zif_cd_hck_cheque_types=>gc_code-exposure msg = 'Exposure code' ).
      cl_abap_unit_assert=>assert_true( act = xsdbool( <ls_finding>-object_key CS gc-control ) msg = 'Control key' ).
    ENDLOOP.
  ENDMETHOD.


  " Rule: a blank value or one with a placeholder is not configured
  METHOD placeholder_is_unset.
    cl_abap_unit_assert=>assert_true( act = zcl_cd_hck_exposure=>is_unset( gc-unset ) msg = 'Placeholder' ).
    cl_abap_unit_assert=>assert_true( act = zcl_cd_hck_exposure=>is_unset( `` ) msg = 'Blank' ).
    cl_abap_unit_assert=>assert_false( act = zcl_cd_hck_exposure=>is_unset( gc-set ) msg = 'Configured' ).
  ENDMETHOD.

ENDCLASS.
