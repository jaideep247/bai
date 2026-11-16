# Facts recorded in the test tool repository (zcd-test-tool) that matter to bai

Harvested 2026-11-16 from the test tool repository, branch `main` (commit 3cad6ea) unless a branch is named. All paths
are relative to the test tool repository root. Other branches were fetched and compared: `codex/*`,
`review/sap-security-qualification`, `feat/portable-pack`, `fix/rap-metadata-zcd-tt`, `docs/v2-architecture-review` and
`claude/loving-albattani-qexsjc` are older than `main` or subsets of it for the recorded knowledge; the only extra
material (a threat model and a security hand-off on `review/sap-security-qualification`, a smoke-test script on
`codex/scenario-automation`) adds no SAP fact beyond those below.

**Confidence**
- **A4H**: seen on the reference system A4H (S/4HANA 2025 with FI-CA, client 100) in a recorded qualification run, a
  read-only SQL probe, the API check report or the owner's own session, as the repository records it.
- **USER**: stated by the user, including the "confirmed landscape reference of the current customer (production
  work 2026)" that the test tool's `docs/VERIFY.md` marks *confirmed* (not re-checked on A4H).
- **DOC**: taken from SAP documentation or help, not seen on a system.
- **DESIGN**: the test tool's own assumption or an open VERIFY item - not a fact; listed only where bai might
  otherwise take it as one.

**Scope**: G = product-generic (SAP standard or platform behaviour); C = first customer / landscape-specific; T = only a
lesson from the test tool's own objects.

Identifiers, user names, passwords, host names and personal data are left out (`<redacted>`).

---

## 1. SAP standard FI-CA / FS-CD

### 1.1 Documents, items, clearing, reversal

| # | Fact | Source | Conf. | Scope |
|---|---|---|---|---|
| F01 | `BAPI_CTRACDOCUMENT_GETDETAIL` on S/4HANA 2025: header structure `BAPIDFKKKO` has **no** `REVERSAL_DOC`; it has only `REVERSED_DOC` (= `DFKKKO-STBEL`), which is **filled on the reversal document** (it names the document that was reversed), **not on the original**. The original's pointer to its reversal, `DFKKKO-STORB`, is not in the BAPI. | qualification/FINDINGS.md:21 (QF-020); packages/fica_standard/seed_spec.py:603-604; CHANGELOG.md (2.24.8 Fixed, QF-020) | A4H | G |
| F02 | A reversal clears the items of the reversed original with clearing reason **`AUGRD` = 05** and `AUGBL` = the reversal document. The read-back of a reversal therefore checks `PARTNERPOSITIONS-CLEAR_REAS = 05` and takes the reversal number from `PARTNERPOSITIONS-CLEARDOCNO`. | FINDINGS.md:21; seed_spec.py:603-607 | A4H | G |
| F03 | `BAPI_CTRACDOCUMENT_REVERSE` on S/4HANA 2025 has mandatory imports `DOCUMENTNUMBER`, `DOC_TYPE`, `CLEAR_REAS`, `DOC_SOURCE_KEY` (interface read from `FUPARAREF`); reason 05 = reversal. Reversal document type and origin are client-specific (no default). | seed_spec.py:585-593; CHANGELOG.md:67 | A4H (interface) | G |
| F04 | `BAPI_CTRACDOCUMENT_CREATE` on S/4HANA 2025: `TESTRUN` is a mandatory import without default (blank = real posting). | seed_spec.py:550; CHANGELOG.md:66 | A4H (interface) | G |
| F05 | `BAPI_CTRACDOCUMENT_CREATE` does not determine a reconciliation key: header `FIKEY` must be supplied ("Document header does not have a reconciliation key"); `BAPI_CTRACRECKEY_CREATE` opens one (`NEWRECONCILIATIONKEY` in, `RECONCILIATIONKEY` out). | seed_spec.py:203, 534-538, 571; CHANGELOG.md:11 | A4H | G |
| F06 | Same BAPI: partner and G/L lines need item numbers ("Formal error in table FKKOP: Item numbering is inconsistent"); the partner item needs its own `POST_DATE` / `DOC_DATE` ("Make an entry in field Posting Date"). | CHANGELOG.md:12, 14; seed_spec.py:567-575 | A4H | G |
| F07 | The document type is checked per **application area of the document header** (`FKK_BLART_CHECK`: `TFK003` `APPLK` + `BLART`); a blank header area gives `>0 034` "Document type IN not defined". | CHANGELOG.md:20; seed_spec.py:560-563 | A4H | G |
| F08 | Where the account determination of the contract account category has no receivables entry, the posting is refused with `>0 204` "G/L account <company code> does not exist" (A4H: category CC in company code NOSH); passing the reconciliation account on the partner item (`PARTNERPOSITIONS-G_L_ACCT`) avoids it. | CHANGELOG.md:15; seed_spec.py:564-566 | A4H | C (values) / G (behaviour) |
| F09 | A tax-relevant reconciliation account needs a tax code on the partner item ("requires a valid tax code"); a segment-relevant account needs `SEGMENT` ("Segment missing in item 0001"). | CHANGELOG.md:13; seed_spec.py:427-430 | A4H | G |
| F10 | `BAPI_CTRACCONTRACTACCOUNT_CR1` interface on S/4HANA 2025: create info, detail and partner detail table; **no field for account determination ID or terms of payment** - they come from the contract account category's defaults. | seed_spec.py:509-511; packages/fica_standard/README.md:52 | A4H (interface) | G |
| F11 | Interfaces of `BAPI_BUPA_CREATE_FROM_DATA`, `BAPI_BUPA_ROLE_ADD_2`, `BAPI_CTRACCONTRACTACCOUNT_CR1`, `BAPI_CTRACDOCUMENT_CREATE`, `BAPI_CTRACDOCUMENT_REVERSE`, `BAPI_BUPA_CENTRAL_CHANGE` match the mapped parameters on S/4HANA 2025 (52 mapping rows OK); `BAPI_CTRACDOCUMENT_GETDETAIL` returns `DOCUMENTHEADER-REF_DOC_NO`, `BAPI_BUPA_CENTRAL_GETDETAIL` returns `CENTRALDATA-SEARCHTERM1`. Organisation partner: category 2, name in `CENTRALDATAORGANIZATION-NAME1`. | docs/VERIFY.md:70, 75 (C28, C32); seed_spec.py:491-492 | A4H (interface, not a run) | G |
| F12 | `BAPI_BUPA_*` after a plain `COMMIT WORK` in the same job: the next BAPI_BUPA call reports success and saves nothing (buffers not reset). Commit with `BAPI_TRANSACTION_COMMIT` (WAIT) / roll back with `BAPI_TRANSACTION_ROLLBACK`. | CHANGELOG.md:7 | A4H | G |
| F13 | Contract partner role for FI-CA is `MKK`. | seed_spec.py:500-503; README (fica) :69 | A4H (used in the owner's session) | G |
| F14 | A partial clearing splits the item into a cleared sub-item (`AUGST` 9, `AUGBL` = payment) and an open sub-item; `DFKKOP` fields `OPBEL OPUPW OPUPK OPUPZ GPART VKONT HVORG TVORG BETRW WAERS AUGST AUGBL`. | docs/VERIFY.md:55 (C25) | DESIGN (VERIFY-RUN) | G |
| F15 | Return with reset clearing: the return document clears the payment items (`AUGBL` = return document), the receivables lose `AUGST` / `AUGBL`, return charges are open items of the return document. | docs/VERIFY.md:68 (C27); packages/fica_standard/src/zcl_ca_tt_fica_return_rules.clas.abap:1-15 | DESIGN (VERIFY-RUN) | G |
| F16 | Data aging moves a document only when all its items were cleared at least 400 days ago with the key closed and transferred; a reader of historical documents calls `FKK_DAAG_SET_COLD`. | docs/ROADMAP.md (13.1, PORT-001) | DOC | G |

### 1.2 Payment run, mass activities, cheques

| # | Fact | Source | Conf. | Scope |
|---|---|---|---|---|
| F17 | `DPAYH`: payments of a payment run are read by `LAUFD` + `LAUFI` with `DOC1R` filled. | docs/VERIFY.md:42 (C1) | USER | G |
| F18 | `RFKK_MA_SCHEDULER` has **no** `P_LAUFD` / `P_LAUFI`. It names the run **today** + `P_COPYI` (FORM `new_laufi`: the template's ID, or its first 3 characters and a counter when a run of that key exists today) and shifts every date of the template by *today − `P_COPYD`*. Its selection screen has `P_AKTYP` (activity type). | CHANGELOG.md:9; packages/fica_standard/src/zcl_ca_tt_fica_ma_scope.clas.abap:1-17, 50-55 | A4H | G |
| F19 | Mass activity run parameters are read, copied and written with `FKK_AKTIV2_PARA_BASICS_FROM_DB`, `FKK_AKTIV2_COPY`, `FKK_AKTIV2_PARA_BASICS_TO_DB` (function group `FKKAKTIV2`, used by FPY1 and siblings). | zcl_ca_tt_fica_ma_params.clas.abap:1-60 | A4H (in use) | G |
| F20 | A payment run template (`ZTTCK` on A4H) issued a day before posting did not pay today's item; the issue date must equal the posting date for items due today. A template that selects only by company code pays **everyone's** open items of that company code. | CHANGELOG.md:9, 25; zcl_ca_tt_fica_ma_scope.clas.abap:133-138 | A4H | G (behaviour) |
| F21 | The payment run pays only items that carry a payment method on the item (`PYMET`, BAPI `PARTNERPOSITIONS-PMNT_METH`); the account's outgoing method alone did not select the item. | CHANGELOG.md:8; seed_spec.py:576-578 | A4H | G |
| F22 | Mass activity entry screen 1000 of `SAPLFKKAKTIV2` has `FKKAKTIV2_DYNP_1000-LAUFD` / `-LAUFI` and is used by FPY1, FPVA, FPVB, FPVC, FPCOPARA, FP04M, VYSPA, VPVA, VPVB, VPVC, VYCOV004. | CHANGELOG.md:120 | A4H | G |
| F23 | `TFK090A` (`AKTYP`, `TCODE`, `HERKF`) / `TFK090AT` register **216** mass activity types on S/4HANA 2025; `TFK090A-TCODE` gives the transaction per type. FS-CD types VYSPA (payment plan posting), VPVA, VPVB, VPVC (dunning), VYCOV004 (insurance invoicing) have **no** `TFK090A` transaction. Customer types start with Y or Z. | CHANGELOG.md:113-114, 120; seed_spec.py:629-650; docs/VERIFY.md:63 (C21) | A4H (count, screen fields, TCODE) / DESIGN (Y/Z rule) | G |
| F24 | `F_KKMA` with the activity type (`AKTYP_KK`) and activity 16 authorises running a mass activity; object and fields checked in `TOBJ` / `TACTZ`. | zcl_ca_tt_fica_auth_resolver.clas.abap:1-6; CHANGELOG.md:86 | A4H | G |
| F25 | The payment run activity type is `PAYP` (FPY1, origin 05). | zcl_ca_tt_fica_q_catalog.clas.testclasses.abap:15; README (fica):60, 71 | DESIGN (test fixture and instructions; not recorded from TFK090A) | G |
| F26 | `RFKK_MA_SCHEDULER` runs the mass activities with a variant naming type and selection; `RFKKFIKEYCLOSE` closes reconciliation keys. | docs/VERIFY.md:51, 54 (C10, C13) | USER | G |
| F27 | FI-CA check register `DFKKCR` (fields checked on A4H): `LAUFD`, `LAUFI` (the issuing payment run), `DOC1R` (payment document), `ZTNUM` (cheque number; for a replaced cheque take the newest), `BNKDT` (encashment date, written by the statement import), `DOC2T` = 01 after encashment. | seed_spec.py:96-103, 349-354; zcl_ca_tt_fica_paysrc_checks.clas.abap:1-11 | A4H | G |
| F28 | End-to-end cheque path proven on A4H: payment run **ZVTPL of 23.10.2026** (company code NOSH, method C, house bank NOSH / account ID CIBC) issued cheques into `DFKKCR`; bank statements 4 and 5 (FF_5, BAI2) reported them with type code **475** "Check paid", posting rule **FC07**, cheque number in **`FEBEP-CHECT`**; `DFKKCR` received `DOC2T` 01 and `BNKDT`. | seed_spec.py:349-354; README (fica):65-77; CHANGELOG.md (2.25.0) | A4H (existing documents; the tool's own run of the flow is still open, VERIFY C42) | G (behaviour) / C (values) |
| F29 | FF_5 reads the cheque number of a BAI2 475 line from the customer reference (field 6 of the 16 record; the bank reference carries it too) and finds the house bank from the bank key and account in records 02 and 03. | seed_spec.py:707-709; README (fica):82 | DESIGN (VERIFY C42) | G |
| F30 | A cashed cheque is proven by `DFKKCR-BNKDT` (encashment date set by the statement import), not by a green job. | README (fica):77 | A4H (path) | G |
| F31 | Positive pay = standard cheque extract FPCHX (`RFKKCHK01`): selection `LAUFD` / `LAUFI`, output file `P_FILE` is `CHKFL_KK` = 44 characters at most; options *Only new/changed*, *Create output file*, *Flag extracted*. | CHANGELOG.md:42; README (fica):81 | A4H (field length) | G |
| F32 | `RFEBKA00` (FF_5) statement file parameter `AUSZFILE` takes paths over 45 characters when passed through `RSPARAMSL_255`. | docs/VERIFY.md:85 (C43); CHANGELOG.md (2.25.1) | DESIGN (VERIFY-RUN) | G |
| F33 | A bank can report a cheque in camt.053 / camt.054 as a debit with bank transaction code PMNT / ICHQ / CCHQ, cheque number in the entry references. | README (fica):84 | DOC | G |
| F34 | Check management life cycle: printed, voided, replaced (the replacement number carries a replacement-count prefix), cashed or locked (FPCHX). | docs/ROADMAP.md (13.4) | DOC | G |
| F35 | Payment orders: when a payment method creates payment orders, the payment run posts **no payment document**; the items are treated as cleared by document change until the bank-confirmed order lot is posted. | docs/ROADMAP.md (13.4) | DOC | G |
| F36 | Payment exceptions 66, 68, 69 (payment specification) and 80 (direct-debit limit); payment specification approval event 5514; direct-debit limit partial collection event 0613. | docs/ROADMAP.md (13.4, 13.5) | DOC | G |
| F37 | `DPAYH` has proposal rows (key field `XVORL`); which rows a check must exclude is still open in the test tool (its checks read `LAUFD`/`LAUFI`/`DOC1R` only). | docs/ROADMAP.md:281, 476 | DESIGN (open) | G |

### 1.3 Lots, statements, reconciliation keys, G/L transfer

| # | Fact | Source | Conf. | Scope |
|---|---|---|---|---|
| F38 | `DFKKKO-FIKEY` and `DFKKSUMC-FIKEY` exist; join `DFKKKO-FIKEY = DFKKSUMC-FIKEY = BKPF-AWKEY` (G/L transfer document's reference key = reconciliation key). | docs/VERIFY.md:44, 56 (C3, C26); packages/fica_standard/src/zif_ca_tt_fica_recon_reader.intf.abap:5 | USER (join) | G |
| F39 | Reference transaction of the FI-CA G/L transfer `BKPF-AWTYP` = `FKKSU`. | seed_spec.py:611-614 (setting RECON_AWTYP); zcl_ca_tt_fica_recon_reader.clas.abap:5-8 | DESIGN (VERIFY: BKPF of a known FPG1 transfer) | G |
| F40 | `DFKKSUMC` holds totals with `FIKEY BUKRS HKONT WAERS BETRW` (setting `RECON_SUMC_FIELDS`). | seed_spec.py:613-616; docs/VERIFY.md:78 (C35) | DESIGN - **wrong** (see contradictions) | G |
| F41 | The G/L receives consolidated amounts: tiers "key" and "journal" are proven per key and account, never per document; tier 3 joins the journal on `AWKEY = FIKEY`. | docs/design/SPEC_2.26_dates_accounting_evidence.md:64, 94 | USER (stated as payment-engine fact) | G |
| F42 | `FEBEP-BUDAT` exists. | docs/VERIFY.md:46 (C5) | USER | G |
| F43 | `RFKKGL00` = transfer to G/L (FPG1); `RFKKKA00` = bank statement to payment lot; `RFEBKA00` imports BAI2, camt.053, MT940 with the client's posting rules. | docs/VERIFY.md:57-58 (C14, C15) | DESIGN | G |
| F44 | Payment lot items `DFKKZP-KEYZ1`; returns lot items `DFKKRP-KEYR1`; NOC change code in `DFKKRP-RLGRD`; dunning header `FKKMAKO-AUSDT`; statement header `FEBKO-AZDAT`; `DFKKKO-BLART` / `-CPUDT` / `-HERKF`. | docs/VERIFY.md:45-50, 66 (C4-C9, C24) | DESIGN (VERIFY-SE11; all fields exist in bai's A4H export) | G |
| F45 | The test tool models NOC as a **returns lot** posting (COR batch, entry code 21 zero amount, addenda 98 change code `C01`) whose lot item carries the change code in `DFKKRP-RLGRD`. | docs/VERIFY.md:76 (C33); README (fica):168 | DESIGN (VERIFY-RUN) | G |
| F46 | Reconciliation key closed and transferred (FPT4), G/L transfer reversal FPG8. | docs/ROADMAP.md (13.4) | DOC | G |
| F47 | Business partner end of purpose: FPDPR1, `BUPA_PRE_EOP`; BP planned changes no longer supported (`FKK_BUPA_MAINTAIN_SINGLE` valid from today). Navigation targets FPAY2, FP09, FP05/FPCPL, FPCH*/FPCHX, FPT5/FPT7, FPO4P, FPLOCK_SNAP, FPCJ. | docs/ROADMAP.md (13.3, 13.6) | DOC | G |

### 1.4 FS-CD

| # | Fact | Source | Conf. | Scope |
|---|---|---|---|---|
| F48 | FS-CD mass activities without a `TFK090A` transaction: VYSPA (payment plan posting / debit entry), VPVA (dunning proposal), VPVB (dunning activities), VPVC (activities at end of dunning), VYCOV004 (insurance invoices); all open on entry screen `SAPLFKKAKTIV2` 1000. | seed_spec.py:629-650; CHANGELOG.md:114 | A4H | G |
| F49 | Whether VYSPA and FPB7 can run as reports (TCOD steps) is open. Function module that creates an instalment plan (FPR1) or an FS-CD payment plan item differs by release and installation. | docs/VERIFY.md:59, 71 (C16, C29); README (fica):59 | DESIGN | G |
| F50 | FS-CD processes need business function `INS_FSCD`; paid-to date `FSCD_PAID_UNTIL` with oldest-first clearing; item transfer FP40; insurance object through `BAPI_INSOBJECT_*`. | docs/ROADMAP.md (13.3, 13.4, 13.6) | DOC | G |

## 2. ADT, installation and qualification on A4H

| # | Fact | Source | Conf. | Scope |
|---|---|---|---|---|
| A01 | ADT session: logon with basic authentication and `sap-client`; CSRF token fetched with `X-CSRF-Token: Fetch` on `GET /sap/bc/adt/discovery`; the token expires with the session - a write answered 403 "CSRF" is retried once after a new fetch. | ci/qualify/qualify.py:82-86, 94-113 | A4H | G |
| A02 | Lock / write / unlock run in a **stateful** session (`X-sap-adt-sessiontype: stateful`); lock `POST <uri>?_action=LOCK&accessMode=MODIFY` returns `LOCK_HANDLE`; write `PUT <uri>/source/main?lockHandle=…&corrNr=<request>`; `POST <uri>?_action=UNLOCK&lockHandle=…`. | qualify.py:104, 419-423, 495-514 | A4H | G |
| A03 | Transport request discovery: `POST /sap/bc/adt/cts/transportchecks` (`com.sap.adt.transport.service.checkData`); a local package answers with empty RECORDING / DLVUNIT LOCAL. On A4H all runs used request **A4HK900751**. | qualify.py:397-416; every results summary since 2.24.3 | A4H | C (request) / G (endpoint) |
| A04 | Objects of a transportable package that are not recorded in a request block the **whole** mass activation ("not locked in a transport request"); fix: lock and write back the object's own inactive source with `corrNr`. | FINDINGS.md:24 (QF-003); qualify.py:273-288 | A4H | G |
| A05 | Mass activation `POST /sap/bc/adt/activation?method=activate&preauditRequested=true` is all-or-nothing; activate what compiles first, then the failed set (ordering errors). An object locked by another session makes the request answer 403: drop that URI and retry. | qualify.py:194-266 | A4H | G |
| A06 | A CDS view whose earlier activation failed keeps an "active" source without a generated entity and is **not** in `/activation/inactiveobjects`; it must be added to the activation explicitly. | FINDINGS.md:25 (QF-004); qualify.py:235-247 | A4H | G |
| A07 | ADT **grants a lock on a CDS source that does not exist**; `PUT` on it then fails with 405 "Resource controller does not support method PUT". Test existence (`GET <uri>` ≠ 404) before locking, then create (POST with `ddlSource`, `ddlxSource`, `abapProgram`, class v4, interface v5 media types). | FINDINGS.md:19 (QF-018); results/2.24.7/20261115T094120Z/summary.md; qualify.py:485-491, 358-395 | A4H | G |
| A08 | A new class has no test include: `PUT includes/testclasses` answers 404 or 500 "does not have any inactive version" (ED 170) - create it first with `POST <class>/includes` (`classincludes` media type). | qualify.py:500-507; results/2.24.7/20261115T094120Z/summary.md | A4H | G |
| A09 | An activation of service and run views against a missing entity took two Fiori apps down for about 10 minutes (SADL "No data retrieved from ABAP dictionary for entity …"); restored by putting back the previous view and service versions. | FINDINGS.md:19 (QF-018) | A4H | G (lesson) |
| A10 | A diagnostic lock call that is not released leaves an edit lock (EU510) on the name. EU510 "User <redacted> is currently editing" with nothing in SM12 = lock held by another ADT / abapGit session; workaround: exclude by name pattern and retry later. | FINDINGS.md:19, 22 (QF-010, still open) | A4H | G |
| A11 | abapGit import created classes and interfaces as **empty shells** (no source written; e.g. an exception class not derived from `CX_ROOT`); writing every source through ADT then activating fixed it (841 objects). | FINDINGS.md:23 (QF-002) | A4H | G |
| A12 | The abapGit version on A4H does not support object type **SVIM** (maintenance view). | FINDINGS.md:26 (QF-005, open) | A4H | G |
| A13 | The ADT install path cannot create **transactions** (SE93 by hand). | CHANGELOG.md:123 | A4H | G |
| A14 | Programs created through ADT have **no text pool**; selection texts are written with `PUT /sap/bc/adt/textelements/programs/<p>/source/selections` (media type `application/vnd.sap.adt.textelements.selections.v1`), without the 8 leading characters SAP keeps; a text over **30 characters is refused with 406** (SEDX_ADT 110). | CHANGELOG.md:80; results/2.24.8/20261115T121201Z/results.json; qualify.py:521-597 | A4H | G |
| A15 | Message classes: `GET` / `PUT /sap/bc/adt/messageclass/<name>` (whole XML, with lock). | qualify.py:756-806 | A4H | G |
| A16 | Table technical settings (data class, logging) are not carried by the source: `GET`/`PUT /sap/bc/adt/ddic/db/settings/<table>` (`ts:dataClassCategory`, `ts:loggingEnabled`). | CHANGELOG.md:161; qualify.py:810-858 | A4H | G |
| A17 | New transparent tables: `POST /sap/bc/adt/ddic/tables` (`application/vnd.sap.adt.tables.v2+xml`, `blue:blueSource`) then `PUT source/main` with the DDL; the harness never changes an existing table (field changes by abapGit or by hand). | CHANGELOG.md:116; qualify.py:708-753 | A4H | G |
| A18 | UI5 apps deploy through `/sap/opu/odata/UI5/ABAP_REPOSITORY_SRV` (Atom entry with the zip, `TransportRequest`). First failure: service not active, then `/IWFND/CM_COS/226` "No default virus profile active or found"; deployed after the owner activated the service and switched the Gateway virus scan **off in the sandbox** (a pilot client keeps a profile). | CHANGELOG.md:81; results/2.24.8/20261115T121758Z/results.json; docs/07-administration/go-live-checklist.md:42 | A4H | G |
| A19 | ABAP Unit: `POST /sap/bc/adt/abapunit/testruns` over packages; alerts sit at program, class **and** method level - counting only method alerts reported a false "0 alerts" (class_setup failure). | FINDINGS.md:18 (QF-017); qualify.py:880-962 | A4H | G |
| A20 | ATC: `POST /atc/worklists?checkVariant=<v>` → worklist ID; `POST /atc/runs?worklistId=`; `GET /atc/worklists/<id>?includeExemptedFindings=false` (accept `application/atc.worklist.v1+xml`); priorities from `priority="n"`. Variant `DEFAULT` and `ABAP_CLOUD_READINESS` both exist on A4H. | qualify.py:964-985; FINDINGS.md:30-35 | A4H | G |
| A21 | Read-only SQL through ADT data preview: `POST /sap/bc/adt/datapreview/freestyle?rowNumber=n` (body = SELECT, accept `application/vnd.sap.adt.datapreview.table.v1+xml`). | ci/qualify/probe.py:14-28 | A4H | G |
| A22 | `GET /sap/bc/adt/system/information` gave no usable system data (every result records `"system": "unavailable"`); release must come from elsewhere (e.g. `CVERS`). | all results.json, stage connect | A4H | G |
| A23 | Self-signed TLS certificate on A4H: the harness pins its SHA-256 fingerprint. Full qualification (Windows harness) takes about 16 minutes. | qualify.py:39-52, 63-70; review-2026-11-15-multi-perspective.md:118 | A4H | C |
| A24 | RAP on S/4HANA 2025: validation `on save { update; }` alone is refused ("trigger update is only allowed in combination with create"); entity alias in a behaviour pool type needs a **double** backslash; a managed BO with additional save may not redefine `cleanup` (use `cleanup_finalize`); `GET PERMISSIONS` returns 02 for a refused action (feature control and authorisation combined), not 01. | FINDINGS.md:7, 12, 13, 16 (QF-001, -011, -012, -015) | A4H | G |
| A25 | ABAP on S/4HANA 2025, accepted by abaplint but refused by the compiler: inline `DATA(...)` in `IMPORTING` of a **functional** method call on the right side of an assignment; a table expression on a `CAST …( )->…` result. | FINDINGS.md:8-9 (QF-006, QF-007) | A4H | G |
| A26 | A RAP handler must not `SUBMIT`: `RS_VARIANT_CONTENTS_255` submits a helper report → dump `BEHAVIOR_ILLEGAL_STATEMENT`; read variants through `RS_VARIANT_CONTENTS_255_RFC` with destination NONE. | CHANGELOG.md:17; review-2026-11-15-multi-perspective.md:52, 163 | A4H | G |
| A27 | `RS_VARIANT_CONTENTS*` default `MOVE_OR_WRITE = 'W'` returns display format (a date `15.11.2026` reached a job as `15.11.20`); use `'M'` (internal format). | CHANGELOG.md:16 | A4H | G |
| A28 | `DDCDS_CUSTOMER_DOMAIN_VALUE_T` returns only domains of **ABAP Cloud** packages; on a classic package the fixed values are empty - read `DD07L` / `DD07T` instead. | CHANGELOG.md:18 | A4H | G |
| A29 | `$metadata` dump `CX_SADL_GW_VOCAN_EXPOSURE` after install = stale activation state; fixed by re-activating the metadata extension. | FINDINGS.md:20 (QF-019) | A4H (user report) | G |
| A30 | A projection reading a value-help element that does not exist (`_StatusText.Criticality`) blocks the projection, its service, DCL and DDLX. | FINDINGS.md:11 (QF-009) | A4H | G |
| A31 | ATC `DEFAULT` findings on A4H that needed pseudo-comments or fixes: possible sequential read on sorted tables (`#EC CI_SORTSEQ`), change log on APPL0/APPL1 tables, SELECT without WHERE (`#EC CI_NOWHERE`), buffer bypass on TADIR / O2APPL (`#EC CI_GENBUFF`, `#EC CI_BUFFJOIN`), FOR ALL ENTRIES that could be a join, SLIN "exception not caught or declared". `ABAP_CLOUD_READINESS` gave 736 findings (classification, not defects). | FINDINGS.md:28-47 | A4H | G |
| A32 | The OData V4 cockpit failed with "403 CSRF token is invalid" until its models used the generated Fiori Elements settings (`earlyRequests`, `preload`). | CHANGELOG.md:515 | A4H | G |
| A33 | Last green state: release 2.25.1, run 20261115T134842Z - 11 activated, ABAP Unit 1023 methods 0 alerts, ATC 0 at priority 1-2. 2.25.2 (RFC variant read fix) not yet confirmed on A4H. | results/2.25.1/20261115T134842Z/summary.md; review-2026-11-15-multi-perspective.md:46, 52 | A4H | T |

## 3. A4H system

| # | Fact | Source | Conf. | Scope |
|---|---|---|---|---|
| S01 | A4H = S/4HANA 2025 with FI-CA, client 100; one user (sandbox); four-eyes off; Gateway virus scan off; temporary approvals (bootstrap) in use. | FINDINGS.md:3; go-live-checklist.md:35-46 | A4H | C |
| S02 | Server time runs **UTC+5:30** ahead of the owner's local date; the test tool chose the system date (`sy-datum`) as base date. | docs/design/SPEC_2.26_dates_accounting_evidence.md:182 | USER | C |
| S03 | Company code **NOSH**, currency USD, house bank NOSH / account ID **CIBC** (bank key and account number <redacted>), payment methods C (cheque) and V (ACH incoming), contract account category **CC**, account relationship Z1, tolerance group SY01, document type IN, origin 01, application area S, main/sub transaction 0060/0020, offset G/L 0000430000, reconciliation account 0000121030 (needs tax code 01 and a segment, SEG_A), payment run ZVTPL 23.10.2026 (documents 1363-1373), statements 4 and 5, EBS posting rule FC07 for 475, working posting document 1843. | seed_spec.py:349-354, 435-444; CHANGELOG.md:13; README (fica):65-82 | A4H | C (sandbox data) |
| S04 | Existing payment run templates PCC01 / PCA01 of 01.01.2000 (assumed cheque / ACH, not confirmed) and ZTTCK. | README (fica):60; CHANGELOG.md:9 | A4H (exist) / DESIGN (meaning) | C |
| S05 | Packages present: `ZCA_TT`, `ZCA_TT_FICA`; abapGit programs `ZABAPGIT`, `ZABAPGIT_STANDALONE` installed. | results/2.24.8/20261115T121201Z/results.json (inventory) | A4H | C |
| S06 | S/4HANA 2023 has **not** been qualified (test tool README targets 2023 / SAP_BASIS 7.58; UI5 1.120 base, 1.136 on 2025 is a planning assumption). | review-2026-11-15-multi-perspective.md:21; docs/design/ui-next.md:9-13 | USER | G |

## 4. First customer (the test tool's USAA overlay)

| # | Fact | Source | Conf. | Scope |
|---|---|---|---|---|
| U01 | Lines of business / sources: PCLM (P&C claims), DIS (distributions), BASE; further source names ORCI, ALPA, ALPL, HAL, USRB, Guidewire. | customers/usaa/seed_spec.py:22-27; build/house_terms.txt:13-23 | USER (owner's list) | C |
| U02 | Middleware PRISM and IRIS; screening Bridger / LexisNexis; aggregator Stripe; reconciliation BlackLine; banks JPMC, BOA, PNC; scheduler Control-M; also "Kestrel". | build/house_terms.txt:24-35 | USER (names only) | C |
| U03 | Customer programs `ZCD_R_CR_UPD_MASTER_DATA` (master data, variant MT_POST_PCLM), `ZCD_ACH_RETURN_LOT_PROCESS` (variants PNC_ACH_RL, PNC_DA_RL), `ZCD_R_STRP_PYOUT_CHBK_FEE_POST` (Stripe payout and chargeback fees). | customers/usaa/seed_spec.py:31-73; docs/VERIFY.md:92 (D1) | DESIGN (VERIFY-SE38) | C |
| U04 | OS-command wrapper `ZICD_CALL_SM69_COMMAND_NEW` exists; variants ENC_ACH_PC, ENC_ACH_USRB (encrypt the ACH file, effect FILE) and SEND_ACH_PC (send to bank, effect SEND). The same program encrypts or sends depending on the variant. | docs/VERIFY.md:93 (D2: program confirmed, variants VERIFY); customers/usaa/seed_spec.py:83-88 | USER (program) / DESIGN (variants) | C |
| U05 | Pay cycle: master data → payment run ACH via `RFKK_MA_SCHEDULER` (variants PAYP_ACH_PC, PAYP_ACH_USRB) → SAP writes the ACH file → encrypt → send → bank acknowledgement → returns lot → close keys (`RFKKFIKEYCLOSE` / FIKEYCLOSE) → payment status update to the source via `RFKK_MA_SCHEDULER` (variants PSU_PCLM, PSU_DIS). | customers/usaa/seed_spec.py:31-63 | DESIGN (variants VERIFY D3) | C |
| U06 | Bank acknowledgement file of a pay cycle: test tool layout CSV `RUN_ID,PAYMENT_REF,STATUS,AMOUNT,CURRENCY,ACK_DATE`, statuses ACCEPTED / REJECTED, trailer per currency. | customers/usaa/seed_spec.py:106-121 | DESIGN (synthetic, not the bank's layout) | C |
| U07 | PRISM payment request JSON (test tool layout "align to API"): `source`, `finTranNum`, `memberNo`, `payeeName`, `amount`, `currency`, `paymentMethod`, `valueDate`; PRISM answers 202 `accepted`/`trackingId`. | customers/usaa/seed_spec.py:132-148 | DESIGN | C |
| U08 | Screening stub (Bridger): POTENTIAL_MATCH, NO_MATCH, PENDING then cleared on the second call, timeout 504. | customers/usaa/seed_spec.py:140-164 | DESIGN | C |
| U09 | ACH return file NACHA with return code R01; NOC as COR batch with change code C01. | packages/fica_standard/seed_spec.py:684-707 | DESIGN | G |
| U10 | Simulated file prefix `ZCATT_` (was `ZCDTT_`); SM59 destinations of screening, middleware and aggregator in DV1 / QA1 to point at `/sap/bc/zca_tt_stub/<ENDPOINT>`. | docs/VERIFY.md:95-96 (D4, D5) | DESIGN | C |
| U11 | No test tool record mentions `ZCD_CHECK_HIST`, ECT, the BlackLine extract, TFK033D or posting area ZBTM; the test tool has **no fact** on posting areas beyond "posting area derives the reconciliation account from determination ID + main/sub transaction" (design). | repository-wide search; SPEC_2.26:101 | - | - |

## 5. Decisions of the user recorded in the test tool

| # | Decision | Source | Scope |
|---|---|---|---|
| D01 | 2026-11-11: the test tool and the operations framework share **one** process catalogue (with activation) and **one** link registry, each in three layers (baseline, industry, customer); the tool prepares adapters (`ZIF_CA_TT_CATALOG_SOURCE`, `ZIF_CA_TT_LINK_SOURCE`) without depending on `ZCA_OPS`. Open: one activation per process or per consumer; where test-only step attributes live; area ↔ package mapping; whether the registry renders or stores WHERE templates. | docs/SHARED_CATALOG.md:3, 63-68 | G |
| D02 | Process ID CHAR 20 and description CHAR 60 in both tools; package layer `S` = baseline, `I` industry, `C` customer. | docs/SHARED_CATALOG.md:33-41 | G |
| D03 | Public repository: `customers/usaa` contains customer configuration - owner's decision. | docs/ROADMAP.md:620 | C |
| D04 | Qualification order: installation → technical (ABAP Unit, ATC, transaction contract, fencing, HTTP recovery) → security → financial → business. | docs/ROADMAP.md:622 | G |
| D05 | Tool never runs in production; refuses client role production (020). Base date = system date; working days by the company code's factory calendar; tier 3 G/L shows "Pending G/L transfer" (no FPG1 by the tool in v1) - recommended, awaiting approval. | review :214; SPEC_2.26:178-187 | G |
| D06 | Extensions never end the LUW (no `COMMIT WORK`, no implicit commit); API modules qualified by an SQL trace of one call. | docs/TRANSACTION_CONTRACT.md:5-27 | G |
| D07 | 05 is the only reversal clearing reason in use (the test tool hard-codes it in its mappings). | seed_spec.py:590 | C (consistent with bai's user decision 2026-11-07) |

## 6. Limits the test tool records

| # | Limit | Source |
|---|---|---|
| L01 | A job without error messages proves transport, not business correctness; every posting or sending scenario needs an assertion on its own documents. | docs/LIMITS.md:9-12 |
| L02 | Payment run keys (`ID@date`) are single use; the scheduler's naming can reuse the template's ID on a later day. | docs/LIMITS.md:28-30; F18 |
| L03 | Nothing is verified by the offline build beyond syntax: activation, ABAP Unit, ATC, authorisations and real data only in the target system. abaplint (2.120.99) accepted code the 2025 compiler refused (A25). | docs/LIMITS.md:41-43; FINDINGS.md:8-9 |
| L04 | Not done on A4H: second user (four eyes, segregation of duties), interruption and concurrency tests, penetration test, S/4HANA 2023, load, accessibility; `FICA_E2E_CHECK` not yet run end to end by the tool. | review-2026-11-15-multi-perspective.md:17-23, 257 |
| L05 | Stub body storage masks digit runs (and per the second review also JSON/XML fields, e-mail, IBAN-like patterns - to be re-read in code); names and tax IDs not masked. | docs/LIMITS.md:39; review :336 |
| L06 | Field types in the test tool's own readers are not all from the system: `DOC1R` is typed CHAR 12 in its payment source, while the A4H dictionary has `DPAYH-DOC1R` and `DFKKCR-DOC1R` CHAR 24. | zcl_ca_tt_fica_paysrc_dpayh.clas.abap:25-35, zcl_ca_tt_fica_paysrc_checks.clas.abap:23-26; bai ops-suite/ddic/a4h/DPAYH.fields.csv, DFKKCR.fields.csv |

Counts: SAP standard 50 (F01-F50), ADT / install / qualification 33 (A01-A33), A4H system 6, first customer 11,
decisions 7, limits 6 - **113 entries**: 62 confirmed on A4H, 10 confirmed by the user, 8 from SAP documentation, 20 design
assumptions / open items / notes, 7 user decisions, 6 limits.
