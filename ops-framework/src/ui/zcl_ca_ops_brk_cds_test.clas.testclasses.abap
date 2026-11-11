*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the break analysis on cl_cds_test_environment doubles of the
*& direct dependencies of each view: the snapshots shown (the last run of a
*& key date, the latest key date of an account flagged) and the breaks by
*& bucket (latest snapshots only, one row per bucket and currency, amounts
*& per currency). Does not prove live SAP runtime behavior. VERIFY-ADT:
*& doubles of CDS view dependencies (7.58).
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*& 2026-11-11 | Pilot pack: episodes (false positive, time to detect, baseline) and breaks explained.
*&---------------------------------------------------------------------*
"! ZI_CA_OPSBRKSNAP: one snapshot per account and key date, the latest key date flagged
CLASS ltc_snap DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        acct TYPE zif_ca_ops_brk_types=>ty_acct_id VALUE 'ZT_CLEARING',
        s1   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000A1',
        s2   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000A2',
        s3   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000A3',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS last_run_and_latest_flag FOR TESTING.
ENDCLASS.


CLASS ltc_snap IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSBRKSNAP' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_brkrun WITH EMPTY KEY.
    DATA lt_last TYPE STANDARD TABLE OF zi_ca_opsbrkrunmax WITH EMPTY KEY.
    DATA lt_keys TYPE STANDARD TABLE OF zi_ca_opsbrkkeymax WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " key date 30 October analysed twice (S1 then S2), 31 October once (S3, the latest key date)
    lt_runs = VALUE #( ( snap_id = gc-s1 area = gc-area acct_id = gc-acct key_date = '20261030'
                         started_at = '20261031060000.0000000' )
                       ( snap_id = gc-s2 area = gc-area acct_id = gc-acct key_date = '20261030'
                         started_at = '20261031070000.0000000' )
                       ( snap_id = gc-s3 area = gc-area acct_id = gc-acct key_date = '20261031'
                         started_at = '20261101060000.0000000' ) ).
    lt_last = VALUE #( ( area = gc-area accountid = gc-acct keydate = '20261030' laststart = '20261031070000.0000000' )
                       ( area = gc-area accountid = gc-acct keydate = '20261031' laststart = '20261101060000.0000000' ) ).
    lt_keys = VALUE #( ( area = gc-area accountid = gc-acct lastkeydate = '20261031' ) ).
    go_env->insert_test_data( lt_runs ).
    go_env->insert_test_data( lt_last ).
    go_env->insert_test_data( lt_keys ).
  ENDMETHOD.


  " Rule: a key date analysed twice shows its last run; the latest key date of the account is flagged
  METHOD last_run_and_latest_flag.
    SELECT snapshotid, islatest FROM zi_ca_opsbrksnap ORDER BY snapshotid INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One per key date' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-snapshotid exp = gc-s2 msg = 'Last run of 30 October' ).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 1 ]-islatest msg = 'Not the latest key date' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-islatest exp = abap_true msg = 'Latest key date' ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CA_OPSBRKBUCKET: breaks of the latest snapshots per bucket and currency
CLASS ltc_bucket DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS per_bucket_and_currency FOR TESTING.
ENDCLASS.


CLASS ltc_bucket IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CA_OPSBRKBUCKET' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_groups TYPE STANDARD TABLE OF zr_ca_opsbrkgroup WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " latest snapshot: two OTHER groups in USD, one TIMING in USD, one TIMING in EUR; an older snapshot's group
    lt_groups = VALUE #( ( snapshotid = '000000000000000000000000000000A1' groupno = 1 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' islatest = abap_true bucket = 'OTHER' currency = 'USD'
                           amount = 10 groupcount = 1 linecount = 2 agedays = 9 )
                         ( snapshotid = '000000000000000000000000000000A1' groupno = 2 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' islatest = abap_true bucket = 'OTHER' currency = 'USD'
                           amount = 5 groupcount = 1 linecount = 1 agedays = 3 )
                         ( snapshotid = '000000000000000000000000000000A1' groupno = 3 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' islatest = abap_true bucket = 'TIMING' isexplained = abap_true
                           currency = 'USD' amount = 7 groupcount = 1 linecount = 1 agedays = 1 )
                         ( snapshotid = '000000000000000000000000000000A1' groupno = 4 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' islatest = abap_true bucket = 'TIMING' isexplained = abap_true
                           currency = 'EUR' amount = 8 groupcount = 1 linecount = 1 agedays = 1 )
                         ( snapshotid = '000000000000000000000000000000A0' groupno = 1 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' islatest = abap_false bucket = 'OTHER' currency = 'USD'
                           amount = 99 groupcount = 1 linecount = 1 agedays = 30 ) ).
    go_env->insert_test_data( lt_groups ).
  ENDMETHOD.


  " Rule: latest snapshots only; one row per bucket and currency; amounts never summed across currencies
  METHOD per_bucket_and_currency.
    SELECT bucket, currency, groupcount, amount, oldestagedays, bucketcriticality FROM zr_ca_opsbrkbucket
      ORDER BY bucket, currency INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 msg = 'OTHER/USD, TIMING/EUR, TIMING/USD' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-groupcount exp = 2 msg = 'Two unexplained groups' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-amount exp = 15 msg = 'USD only, older snapshot left out' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-oldestagedays exp = 9 msg = 'Oldest age' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-bucketcriticality exp = 1 msg = 'Unexplained is red' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-currency exp = 'EUR' msg = 'EUR on its own row' ).
  ENDMETHOD.

ENDCLASS.

"! ZI_CA_OPSPILOTEP: false positive, time to detect and the baseline of an episode
CLASS ltc_pilot_ep DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        run  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D1',
        area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS false_positive_and_detect FOR TESTING.
ENDCLASS.


CLASS ltc_pilot_ep IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSPILOTEP' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_times TYPE STANDARD TABLE OF zi_ca_opsexctimes WITH EMPTY KEY.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA lt_cfg TYPE STANDARD TABLE OF zi_ca_opspilotcfg WITH EMPTY KEY.
    DATA lt_baselines TYPE STANDARD TABLE OF zca_ops_pilotbl WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " 1 resolved as not an issue, event one hour before the first seen; 2 resolved as timing, no event time
    lt_times = VALUE #( ( runid = gc-run findingno = 1 area = gc-area isresolved = abap_true
                          firstseenat = '20261102070000.0000000' )
                        ( runid = gc-run findingno = 2 area = gc-area isresolved = abap_true
                          firstseenat = '20261102070000.0000000' ) ).
    lt_findings = VALUE #( ( run_id = gc-run finding_no = 1 area = gc-area group2 = 'ZT_CHECK'
                             reason_code = 'NOT_AN_ISSUE' event_at = '20261102060000.0000000' )
                           ( run_id = gc-run finding_no = 2 area = gc-area group2 = 'ZT_OTHER' reason_code = 'TIMING' ) ).
    lt_cfg = VALUE #( ( language = sy-langu falsepositivereason = 'NOT_AN_ISSUE' ) ).
    lt_baselines = VALUE #( ( area = gc-area check_id = 'ZT_CHECK' baseline_min = 1440 ) ).
    go_env->insert_test_data( lt_times ).
    go_env->insert_test_data( lt_findings ).
    go_env->insert_test_data( lt_cfg ).
    go_env->insert_test_data( lt_baselines ).
  ENDMETHOD.


  " Rule: resolved with the false-positive reason counts as a false positive; time to detect from the event time;
  " the baseline of the check joins by area and check (GROUP2)
  METHOD false_positive_and_detect.
    SELECT findingno, isfalsepositive, isdetectknown, detectseconds, hasbaseline, baselineminutes
      FROM zi_ca_opspilotep ORDER BY findingno INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Two episodes' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isfalsepositive exp = abap_true msg = 'False positive' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-detectseconds exp = 3600 msg = 'One hour to detect' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-hasbaseline exp = abap_true msg = 'Baseline of the check' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-baselineminutes exp = 1440 msg = 'Previous detection' ).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 2 ]-isfalsepositive msg = 'Timing is not a false positive' ).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 2 ]-isdetectknown msg = 'No event time, no business date' ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CA_OPSPILOTBRK: share of breaks explained per account and key date
CLASS ltc_pilot_brk DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS share_explained FOR TESTING.
ENDCLASS.


CLASS ltc_pilot_brk IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CA_OPSPILOTBRK' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_groups TYPE STANDARD TABLE OF zr_ca_opsbrkgroup WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " three explained groups (two currencies) and one unexplained of one account and key date
    lt_groups = VALUE #( ( snapshotid = '000000000000000000000000000000E1' groupno = 1 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' keydate = '20261031' currency = 'USD'
                           groupcount = 1 explainedcount = 1 )
                         ( snapshotid = '000000000000000000000000000000E1' groupno = 2 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' keydate = '20261031' currency = 'EUR'
                           groupcount = 1 explainedcount = 1 )
                         ( snapshotid = '000000000000000000000000000000E1' groupno = 3 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' keydate = '20261031' currency = 'USD'
                           groupcount = 1 explainedcount = 1 )
                         ( snapshotid = '000000000000000000000000000000E1' groupno = 4 area = 'ZT_OPS_A'
                           accountid = 'ZT_CLEARING' keydate = '20261031' currency = 'USD'
                           groupcount = 1 unexplainedcount = 1 ) ).
    go_env->insert_test_data( lt_groups ).
  ENDMETHOD.


  " Rule: explained share = explained groups / groups (a count share across currencies)
  METHOD share_explained.
    SELECT groupcount, explainedcount, unexplainedcount, explainedpercent FROM zr_ca_opspilotbrk
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One account and key date' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-groupcount exp = 4 msg = 'Four breaks' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-unexplainedcount exp = 1 msg = 'One unexplained' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-explainedpercent exp = '75.0' msg = 'Share explained' ).
  ENDMETHOD.

ENDCLASS.
