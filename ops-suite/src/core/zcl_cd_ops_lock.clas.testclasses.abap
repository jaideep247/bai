*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_lock.clas.testclasses.abap
*& Purpose:
*& Unit tests of the run lock wrapper through its test seams: lock granted,
*& lock held by another user (holder returned), lock service failure raises
*& message 042, release. ENQUEUE / DEQUEUE are replaced by TEST-INJECTION;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltc_lock DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_variant TYPE zif_cd_ops_types=>ty_variant VALUE 'DAILY'.
    CONSTANTS gc_holder TYPE syuname VALUE 'BATCH_OTHER'.
    CONSTANTS gc_msgno_failure TYPE symsgno VALUE '042'.

    TYPES:
      BEGIN OF ty_flags,
        granted        TYPE abap_bool,
        foreign        TYPE abap_bool,
        system_failure TYPE abap_bool,
      END OF ty_flags.

    DATA mo_cut TYPE REF TO zif_cd_ops_lock.

    METHODS setup.
    METHODS teardown.
    METHODS free_lock_is_acquired FOR TESTING.
    METHODS held_lock_names_holder FOR TESTING.
    METHODS lock_failure_raises_042 FOR TESTING.
    METHODS release_returns FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      EXPORTING
        ev_holder          TYPE syuname
      RETURNING
        VALUE(rv_acquired) TYPE abap_bool
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_lock IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_ops_lock( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-granted = abap_true.
      TEST-INJECTION enqueue.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-foreign = abap_true.
      TEST-INJECTION enqueue.
        lv_holder = 'BATCH_OTHER'.
        lv_subrc  = 1.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-system_failure = abap_true.
      TEST-INJECTION enqueue.
        lv_subrc = 2.
      END-TEST-INJECTION.
    ENDIF.
    TEST-INJECTION dequeue.
    END-TEST-INJECTION.
  ENDMETHOD.


  METHOD act.
    rv_acquired = mo_cut->acquire( EXPORTING iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs
                                             iv_variant = gc_variant
                                   IMPORTING ev_holder  = ev_holder ).
  ENDMETHOD.


  " Rule: a free lock is taken and nobody is named as holder
  METHOD free_lock_is_acquired.
    DATA lv_holder TYPE syuname.
    TRY.
        configure_scenario( VALUE #( granted = abap_true ) ).
        DATA(lv_acquired) = act( IMPORTING ev_holder = lv_holder ).
        cl_abap_unit_assert=>assert_true( act = lv_acquired msg = 'Free lock is acquired' ).
        cl_abap_unit_assert=>assert_initial( act = lv_holder msg = 'No holder for a free lock' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a lock held by another run is refused and the holder is named (RUN_LOCKED finding)
  METHOD held_lock_names_holder.
    DATA lv_holder TYPE syuname.
    TRY.
        configure_scenario( VALUE #( foreign = abap_true ) ).
        DATA(lv_acquired) = act( IMPORTING ev_holder = lv_holder ).
        cl_abap_unit_assert=>assert_false( act = lv_acquired msg = 'Held lock is not acquired' ).
        cl_abap_unit_assert=>assert_equals( act = lv_holder exp = gc_holder msg = 'Holder is named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a lock service failure raises message 042 - a run never starts unlocked
  METHOD lock_failure_raises_042.
    configure_scenario( VALUE #( system_failure = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Lock service failure must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_failure
                                            msg = 'Failure is message 042' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: release never raises (it is called in cleanup paths)
  METHOD release_returns.
    TRY.
        configure_scenario( VALUE #( ) ).
        mo_cut->release( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs
                         iv_variant = gc_variant ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Release returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
