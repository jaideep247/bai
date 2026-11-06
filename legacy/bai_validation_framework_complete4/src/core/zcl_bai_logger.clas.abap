CLASS zcl_bai_logger DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING
          iv_object    TYPE balobj_d DEFAULT 'ZBAI'
          iv_subobject TYPE balsubobj DEFAULT 'VAL'
          iv_extnumber TYPE balnrext OPTIONAL,

      " Message methods
      info
        IMPORTING
          iv_msgid TYPE symsgid
          iv_msgno TYPE symsgno
          iv_msgv1 TYPE symsgv OPTIONAL
          iv_msgv2 TYPE symsgv OPTIONAL
          iv_msgv3 TYPE symsgv OPTIONAL
          iv_msgv4 TYPE symsgv OPTIONAL,

      warning
        IMPORTING
          iv_msgid TYPE symsgid
          iv_msgno TYPE symsgno
          iv_msgv1 TYPE symsgv OPTIONAL
          iv_msgv2 TYPE symsgv OPTIONAL
          iv_msgv3 TYPE symsgv OPTIONAL
          iv_msgv4 TYPE symsgv OPTIONAL,

      error
        IMPORTING
          iv_msgid TYPE symsgid
          iv_msgno TYPE symsgno
          iv_msgv1 TYPE symsgv OPTIONAL
          iv_msgv2 TYPE symsgv OPTIONAL
          iv_msgv3 TYPE symsgv OPTIONAL
          iv_msgv4 TYPE symsgv OPTIONAL,

      " Additional message method with free text
      add_message
        IMPORTING
          iv_msgty TYPE symsgty DEFAULT 'I'
          iv_text  TYPE string,

      " Save and display
      save
        RETURNING VALUE(rv_lognumber) TYPE balognr,

      display,

      " Get log handle
      get_log_handle
        RETURNING VALUE(rv_handle) TYPE balloghndl.

  PRIVATE SECTION.
    DATA:
      mv_log_handle TYPE balloghndl,
      mv_object     TYPE balobj_d,
      mv_subobject  TYPE balsubobj,
      mv_extnumber  TYPE balnrext,
      mv_saved      TYPE abap_bool.

    METHODS:
      create_log,

      add_msg
        IMPORTING
          iv_msgty TYPE symsgty
          iv_msgid TYPE symsgid
          iv_msgno TYPE symsgno
          iv_msgv1 TYPE symsgv OPTIONAL
          iv_msgv2 TYPE symsgv OPTIONAL
          iv_msgv3 TYPE symsgv OPTIONAL
          iv_msgv4 TYPE symsgv OPTIONAL.

ENDCLASS.



CLASS zcl_bai_logger IMPLEMENTATION.


  METHOD constructor.

    mv_object = iv_object.
    mv_subobject = iv_subobject.
    mv_extnumber = iv_extnumber.
    mv_saved = abap_false.

    " Create log immediately
    create_log( ).

  ENDMETHOD.


  METHOD create_log.

    DATA: ls_log TYPE bal_s_log.

    " Build log header
    ls_log-object     = mv_object.
    ls_log-subobject  = mv_subobject.
    ls_log-extnumber  = mv_extnumber.
    ls_log-aluser     = sy-uname.
    ls_log-alprog     = sy-repid.

    " Create log in memory
    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = ls_log
      IMPORTING
        e_log_handle = mv_log_handle
      EXCEPTIONS
        OTHERS       = 1.

    IF sy-subrc <> 0.
      " Fallback: create without handle
      CLEAR mv_log_handle.
    ENDIF.

  ENDMETHOD.


  METHOD info.
    add_msg(
      iv_msgty = 'I'
      iv_msgid = iv_msgid
      iv_msgno = iv_msgno
      iv_msgv1 = iv_msgv1
      iv_msgv2 = iv_msgv2
      iv_msgv3 = iv_msgv3
      iv_msgv4 = iv_msgv4
    ).
  ENDMETHOD.


  METHOD warning.
    add_msg(
      iv_msgty = 'W'
      iv_msgid = iv_msgid
      iv_msgno = iv_msgno
      iv_msgv1 = iv_msgv1
      iv_msgv2 = iv_msgv2
      iv_msgv3 = iv_msgv3
      iv_msgv4 = iv_msgv4
    ).
  ENDMETHOD.


  METHOD error.
    add_msg(
      iv_msgty = 'E'
      iv_msgid = iv_msgid
      iv_msgno = iv_msgno
      iv_msgv1 = iv_msgv1
      iv_msgv2 = iv_msgv2
      iv_msgv3 = iv_msgv3
      iv_msgv4 = iv_msgv4
    ).
  ENDMETHOD.


  METHOD add_message.

    DATA: ls_msg TYPE bal_s_msg.

    CHECK mv_log_handle IS NOT INITIAL.

    " Build message structure with free text
    ls_msg-msgty = iv_msgty.
    ls_msg-msgid = '00'.
    ls_msg-msgno = '001'.
    ls_msg-msgv1 = iv_text.

    " Add to log
    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = mv_log_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.

  ENDMETHOD.


  METHOD add_msg.

    DATA: ls_msg TYPE bal_s_msg.

    CHECK mv_log_handle IS NOT INITIAL.

    " Build message structure
    ls_msg-msgty = iv_msgty.
    ls_msg-msgid = iv_msgid.
    ls_msg-msgno = iv_msgno.
    ls_msg-msgv1 = iv_msgv1.
    ls_msg-msgv2 = iv_msgv2.
    ls_msg-msgv3 = iv_msgv3.
    ls_msg-msgv4 = iv_msgv4.

    " Add to log
    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = mv_log_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.

  ENDMETHOD.


  METHOD save.

    DATA: lt_log_handle TYPE bal_t_logh,
          ls_new_lognumber TYPE bal_s_lgnm.

    CHECK mv_log_handle IS NOT INITIAL.
    CHECK mv_saved = abap_false.

    " Prepare log handle table
    APPEND mv_log_handle TO lt_log_handle.

    " Save to database
    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle       = lt_log_handle
        i_2th_connection     = space
        i_2th_connect_commit = abap_true
      IMPORTING
        e_new_lognumber      = ls_new_lognumber
      EXCEPTIONS
        OTHERS               = 1.

    IF sy-subrc = 0.
      rv_lognumber = ls_new_lognumber-lognumber.
      mv_saved = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD display.

    DATA: lt_log_handle TYPE bal_t_logh,
          ls_profile    TYPE bal_s_prof.

    CHECK mv_log_handle IS NOT INITIAL.

    " Prepare log handle
    APPEND mv_log_handle TO lt_log_handle.

    " Get display profile
    CALL FUNCTION 'BAL_DSP_PROFILE_SINGLE_LOG_GET'
      IMPORTING
        e_s_display_profile = ls_profile
      EXCEPTIONS
        OTHERS              = 1.

    " Display log
    CALL FUNCTION 'BAL_DSP_LOG_DISPLAY'
      EXPORTING
        i_s_display_profile = ls_profile
        i_t_log_handle      = lt_log_handle
      EXCEPTIONS
        OTHERS              = 1.

  ENDMETHOD.


  METHOD get_log_handle.
    rv_handle = mv_log_handle.
  ENDMETHOD.


ENDCLASS.
