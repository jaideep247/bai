BAI Validators - ABAP 7.50 Refactor Pack
Generated: 2025-12-29

Contents:
- zif_bai_validator.intf.abap  : Interface + FEBEP projection fields (includes XBLNR, BSTAT)
- zcl_bai_base.clas.abap       : Base class with shared helpers:
    * add_failed_check
    * derive_primary_failure
    * mark_failed / mark_warning
    * ABAP 7.50-safe conversion helpers
- 8 disbursement validators + 1 collection validator updated to use shared helpers

Notes:
- ZCL_BAI_168_DISB implements:
    DFKKRP exists for OPBEL (CHECT)
    DFKKRK-STARS = '5' for OPBEL
    DPAYH-ZZPAYMENT_STATUS = 'RETURNED' by DOC1R derived from CHECT
- Icons used: '@5B@' (pending/yellow), '@5C@' (red). Change in base if needed.

UPDATE v2: zcl_bai_168_disb now also validates ZCD_ACH_RTRV_LOG-ZZ_RTRV_STATUS = 'AF' (by AUGBL derived from CHECT).

UPDATE v3 (2025-12-29):
- All validators filter input by VORGC = respective BAI code.
- ZCL_BAI_581_DISB validates: SUM(DFKKCR-RWBTR) = SUM(FEBEP-KWBTR) and record count match for VORGC=581. Produces failed rows for missing/mismatching ZTNUMs and extra DFKKCR entries.
- Interface adds FEBEP-KWBTR.

UPDATE v4: zcl_bai_195_disb now converts CHECT -> DOC1R and selects DPAYH by DOC1R (not LAUFD/LAUFI substrings).
