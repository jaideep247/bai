*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lic_platform.clas.abap
*& Purpose:
*& Platform adapter of the licence (ZIF_CA_OPS_LIC_PLATFORM): the signature
*& check of the signed data through SSF_KRN_VERIFY (format PKCS7, content
*& enveloped, the certificates of the PSE named by LIC_SSF_PROFILE trusted
*& - the vendor's certificate imported in STRUST) and this system's
*& identity: installation number (SLIC_GET_LICENCE_NUMBER), system ID,
*& client and the framework's release. The parameters of both function
*& modules are VERIFY-SE37 (V162 / V163): nothing else of the framework
*& calls them, so a correction stays here. Reads nothing else, writes
*& nothing.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence SSF / system adapter</p>
CLASS zcl_ca_ops_lic_platform DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_lic_platform.

  PRIVATE SECTION.
    "! SSF toolkit of the kernel (CommonCryptoLib) and the format of the signed data
    CONSTANTS gc_toolkit TYPE string VALUE `SAPSECULIB`.
    CONSTANTS gc_format TYPE string VALUE `PKCS7`.
    "! Input / output given as tables (SSF_KRN_*: I/O specification T)
    CONSTANTS gc_io_tables TYPE c LENGTH 1 VALUE 'T'.
    "! Line length of the binary tables of SSF (SSFBIN-BINDATA)
    CONSTANTS gc_line TYPE i VALUE 255.
    "! SSF return code and signer result of a valid signature
    CONSTANTS gc_ssf_ok TYPE i VALUE 0.

    TYPES tt_bin TYPE STANDARD TABLE OF ssfbin WITH EMPTY KEY.

    CLASS-METHODS to_lines
      IMPORTING
        iv_data         TYPE xstring
      RETURNING
        VALUE(rt_lines) TYPE tt_bin.

    CLASS-METHODS from_lines
      IMPORTING
        it_lines       TYPE tt_bin
        iv_length      TYPE i
      RETURNING
        VALUE(rv_data) TYPE xstring.

ENDCLASS.



CLASS zcl_ca_ops_lic_platform IMPLEMENTATION.

  METHOD zif_ca_ops_lic_platform~verify.
    DATA lt_output TYPE tt_bin.
    DATA lt_signers TYPE STANDARD TABLE OF ssfinfo WITH EMPTY KEY.
    DATA lv_output_length TYPE i.
    DATA lv_crc TYPE i.

    DATA(lt_signed) = to_lines( iv_signed ).
    DATA(lv_signed_length) = xstrlen( iv_signed ).
    " VERIFY-SE37 (V162): parameters of SSF_KRN_VERIFY on SAP_BASIS 7.58 (enveloped PKCS#7, PSE of the SSF
    " application in STR_PAB, no password - the PSE is read with the system's credentials)
    CALL FUNCTION 'SSF_KRN_VERIFY'
      EXPORTING
        ssftoolkit                   = gc_toolkit
        str_format                   = gc_format
        b_inc_certs                  = abap_false
        io_spec                      = gc_io_tables
        ostr_signed_data_l           = lv_signed_length
        str_pab                      = iv_profile
      IMPORTING
        ostr_output_data_l           = lv_output_length
        crc                          = lv_crc
      TABLES
        ostr_signed_data             = lt_signed
        ostr_output_data             = lt_output
        signer_result_list           = lt_signers
      EXCEPTIONS
        ssf_krn_error                = 1
        ssf_krn_noop                 = 2
        ssf_krn_nomemory             = 3
        ssf_krn_opinv                = 4
        ssf_krn_nossflib             = 5
        ssf_krn_input_data_error     = 6
        ssf_krn_invalid_par          = 7
        ssf_krn_invalid_parlen       = 8
        ssf_fb_input_parameter_error = 9
        OTHERS                       = 10.
    IF sy-subrc = 1 OR sy-subrc = 6.
      " the call ran and refused the data: a signature that is not valid (or no signed data at all)
      rs_verified-return_code = |{ sy-subrc }/{ lv_crc }|.
      RETURN.
    ELSEIF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e365(zca_ops) WITH sy-subrc iv_profile.
    ENDIF.
    rs_verified-return_code = |{ lv_crc }|.
    rs_verified-payload = from_lines( it_lines = lt_output iv_length = lv_output_length ).
    " exactly one signer, whose own result is valid
    IF lines( lt_signers ) = 1.
      rs_verified-signer = condense( CONV string( lt_signers[ 1 ]-id ) ).
      rs_verified-ok = xsdbool( lv_crc = gc_ssf_ok AND lt_signers[ 1 ]-result = gc_ssf_ok ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_lic_platform~system.
    DATA lv_installation TYPE c LENGTH 10.

    " VERIFY-SE37 (V163): the installation number of the system's licence key; a system with several installations
    " (SLIC_GET_INSTALLATIONS) lists each - the licence names every installation it may run on
    CALL FUNCTION 'SLIC_GET_LICENCE_NUMBER'
      IMPORTING
        license_number = lv_installation
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc = 0 AND lv_installation IS NOT INITIAL.
      INSERT CONV string( lv_installation ) INTO TABLE rs_system-installations.
    ENDIF.
    rs_system-sysid   = sy-sysid.
    rs_system-client  = sy-mandt.
    rs_system-version = zif_ca_ops_types=>gc_version.
  ENDMETHOD.


  METHOD to_lines.
    DATA lv_offset TYPE i.
    DATA(lv_length) = xstrlen( iv_data ).
    WHILE lv_offset < lv_length.
      DATA(lv_chunk) = nmin( val1 = gc_line val2 = lv_length - lv_offset ).
      INSERT VALUE #( bindata = iv_data+lv_offset(lv_chunk) ) INTO TABLE rt_lines.
      lv_offset += lv_chunk.
    ENDWHILE.
  ENDMETHOD.


  METHOD from_lines.
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      CONCATENATE rv_data <ls_line>-bindata INTO rv_data IN BYTE MODE.
    ENDLOOP.
    IF xstrlen( rv_data ) > iv_length AND iv_length >= 0.
      rv_data = rv_data(iv_length).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
