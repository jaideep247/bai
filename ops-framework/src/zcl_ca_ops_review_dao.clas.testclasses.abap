*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_review_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the daily control review repository: a first sign-off is
*& inserted, a second sign-off of the same control and date replaces it
*& (one row per control and date), other dates are untouched; the lock
*& refuses a control and date another user holds (message 079) through the
*& ENQUEUE seam. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
CLASS ltc_review_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area    TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        control TYPE zif_ca_ops_ctl_types=>ty_control_id VALUE 'ZT_PAYFILES',
        day     TYPE d VALUE '20261110',
        before  TYPE d VALUE '20261109',
        first   TYPE timestampl VALUE '20261110130000.0000000',
        second  TYPE timestampl VALUE '20261110140000.0000000',
        holder  TYPE syuname VALUE 'ZT_OTHER',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_review_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS first_sign_off_inserted     FOR TESTING.
    METHODS second_sign_off_replaces    FOR TESTING.
    METHODS foreign_lock_refused        FOR TESTING.
ENDCLASS.


CLASS ltc_review_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_REVIEW' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_review_dao( ).
  ENDMETHOD.


  METHOD first_sign_off_inserted.
    mo_cut->save( VALUE #( ( area = gc-area control_id = gc-control business_date = gc-day
                             status_at_review = zif_ca_ops_ctl_types=>gc_status-healthy
                             review_result = zif_ca_ops_ctl_types=>gc_status-healthy
                             reviewed_by = sy-uname reviewed_at = gc-first last_changed_at = gc-first ) ) ).
    SELECT area, control_id, business_date, status_at_review FROM zca_ops_review INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One sign-off row' ).
  ENDMETHOD.


  METHOD second_sign_off_replaces.
    DATA lt_existing TYPE STANDARD TABLE OF zca_ops_review WITH EMPTY KEY.
    lt_existing = VALUE #( ( area = gc-area control_id = gc-control business_date = gc-day
                             status_at_review = zif_ca_ops_ctl_types=>gc_status-watch reviewed_at = gc-first
                             last_changed_at = gc-first )
                           ( area = gc-area control_id = gc-control business_date = gc-before
                             status_at_review = zif_ca_ops_ctl_types=>gc_status-healthy reviewed_at = gc-first
                             last_changed_at = gc-first ) ).
    go_env->insert_test_data( lt_existing ).

    mo_cut->save( VALUE #( ( area = gc-area control_id = gc-control business_date = gc-day
                             status_at_review = zif_ca_ops_ctl_types=>gc_status-action
                             review_result = zif_ca_ops_ctl_types=>gc_status-action
                             reviewed_by = sy-uname reviewed_at = gc-second last_changed_at = gc-second ) ) ).

    SELECT business_date, status_at_review, last_changed_at FROM zca_ops_review
      ORDER BY business_date INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Still one row per control and date' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-status_at_review exp = zif_ca_ops_ctl_types=>gc_status-action
                                        msg = 'The later sign-off replaced the row of the date' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-last_changed_at exp = gc-second msg = 'New ETag stamp' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status_at_review exp = zif_ca_ops_ctl_types=>gc_status-healthy
                                        msg = 'The other date is untouched' ).
  ENDMETHOD.


  METHOD foreign_lock_refused.
    TEST-INJECTION enqueue.
      lv_subrc  = 1.
      lv_holder = gc-holder.
    END-TEST-INJECTION.
    TRY.
        mo_cut->lock( iv_area = gc-area iv_control_id = gc-control iv_business_date = gc-day ).
        cl_abap_unit_assert=>fail( msg = 'A control and date locked by another user is refused' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_locked).
        cl_abap_unit_assert=>assert_equals( act = lx_locked->if_t100_message~t100key-msgno
                                            exp = zif_ca_ops_ctl_types=>gc_msg-review_locked msg = 'Message 079' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
