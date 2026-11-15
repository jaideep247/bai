*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_lic_platform.intf.abap
*& Purpose:
*& Adapter of the licence to the SAP platform: the signature check of a
*& licence file through SSF (PKCS#7 signed data, enveloped content, vendor
*& certificate in the PSE of an SSF application - STRUST) and the identity
*& of this system (installation number(s), system ID, client). The one
*& place that calls SSF and the licence function of the kernel, so every
*& test doubles it (ZCL_CA_OPS_LIC_PLATFORM is VERIFY V162 / V163).
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence platform adapter</p>
INTERFACE zif_ca_ops_lic_platform
  PUBLIC.

  "! Verify PKCS#7 signed data with the certificates of the PSE iv_profile; the signed content and the signer
  "! @parameter iv_signed  | DER of the PKCS#7 / CMS signed data (content enveloped)
  "! @parameter iv_profile | PSE of the SSF application (parameter LIC_SSF_PROFILE)
  "! @raising zcx_ca_ops_error | 365 SSF could not run (the result of a run - also a bad signature - is in rs_verified)
  METHODS verify
    IMPORTING
      iv_signed          TYPE xstring
      iv_profile         TYPE clike
    RETURNING
      VALUE(rs_verified) TYPE zif_ca_ops_lic_types=>ty_verified
    RAISING
      zcx_ca_ops_error.

  "! Installation number(s), system ID and client of this system, and the release of the framework
  METHODS system
    RETURNING
      VALUE(rs_system) TYPE zif_ca_ops_lic_types=>ty_system_id.

ENDINTERFACE.
