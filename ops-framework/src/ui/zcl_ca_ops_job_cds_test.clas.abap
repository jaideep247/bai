*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the SAP job failures board
*& (ZR_CA_OpsJobFailure): failure flag, counters of the "Job failures
*& today" cards, the open exception joined to the kept job, the live job
*& status (blank after the job reorganisation). No production logic and no
*& methods: the board is CDS only; the tests live in the test include.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">SAP job failures board - CDS unit test holder</p>
"! It only carries the ABAP Unit tests of the board's CDS (test include). It is never instantiated.
CLASS zcl_ca_ops_job_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_job_cds_test IMPLEMENTATION.

ENDCLASS.
