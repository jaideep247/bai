# Extension and release-gate proof (build Q)

> **First principle:** a second customer is proven when it can add its own data by configuration only, every link that
> could find two rows says so and shows both, a pending change can be seen before it takes effect and undone after,
> a missing table is a reason and never a dump, and a user of one company code never sees another's - in the screen,
> the export, the e-mail or the ticket.
> **Analogy:** a new tenant moves into a furnished flat. The proof is not the brochure: it is the tenant hanging its
> own pictures without a drill (configuration), the landlord's key tag that says "two flats on this floor have number
> 4" instead of opening one at random (ambiguous matches), a dry run of the move before the van comes and the old
> furniture kept until the new one fits (preview and rollback), a missing socket reported as missing (missing DDIC
> objects), and every tenant's letters in their own box (isolation).

Status (2026-11-16): written and checked offline (abaplint 0 issues for the framework and the compiled XX sources,
house checks, generator and root tests). **Nothing is activated or run in an SAP system**; the open items are
V310-V321 (section 9). Source: review 2026-11-15 finding 4 and the P0 "Configuration and release gates"
(`docs/release/RELEASE_1_PLAN.md` section 2a, row Q).

## 1. What is proven where

| Claim | Proven offline (this repository) | Needs DV1 / QA1 |
|---|---|---|
| Customer XX adds an intake flow and a payment reference by configuration only | the generators turn XX's registry layer, declarations and payment model spec into XX's own objects in `examples/intake_xx` (root test `tools/tests/test_extension_proof.py`, house check `intake_xx`); abaplint compiles them against the product (0 issues); no product source names them; `customer_terms` green | activation of XX's package after the product, the append `ZZXX_PAYREF` on DFKKOP, the extension in the OData metadata (V320) |
| Identity beyond a document number | registry rule offline (`tools/abaptools/link_registry.py`) and at run time (`ZCL_CA_OPS_LINK_REGISTRY=>NOTES`, check `ZCL_CA_OPS_CHK_LINKS`): ABAP Unit | the registry check on the rows of a system (V311) |
| Ambiguous matches shown, never one picked | walker result (`TY_RESULT-AMBIGUITIES`, node `MATCH` / `CANDIDATES` / `IDENTITY`): ABAP Unit with a data double; drill-down report `ZCA_OPS_LINK_DRILL`; extension columns blank with a marker (generator test); payment model joins (generator test) | the walker on real rows, the candidates view on HANA (V311, V312, V321) |
| Preview and rollback | `ZCL_CA_OPS_CFG_PREVIEW`: ABAP Unit with a catalogue double; report `ZCA_OPS_CFG_PREVIEW` | the report on DV1 rows, the rollback row through the app with its approver, `GATE_LINK_LAYERS_OFF` in QA1 (V314, V315) |
| Missing DDIC objects | save: field lists checked against the runtime DDIC (`FIRST_MISSING_FIELD`, 083); run: walker 634 / 635, aggregate check and registry check with reason `DDIC_MISSING` - ABAP Unit with doubles | a real missing table / field on DV1 (V313) |
| Two-user company-code isolation | house check `dcl_company_code`; DCL tests per new view (access-control double); alert digest split per company code; ticket payload with the file's company code only - ABAP Unit | two users on DV1 / QA1, the list report export, the e-mail of a digest rule, a site's ticket sink (V316-V319) |
| Volume | - | QA1 with the pilot's volume (release plan, P0 gates) |

## 2. Customer XX adds its intake by configuration only

The worked example `ops-framework/examples/intake_xx` is a customer folder (`docs/EXTENDING_WITH_CUSTOMER_DATA.md`
section 5). Everything XX adds is its own:

| What XX adds | Where | Mechanism |
|---|---|---|
| Its intake table `ZXX_INTAKE` (one row per payment request: intake number, feeder logical system, company code, payment reference, received date, status, amount) | `examples/intake_xx/ddic`, `src` | XX's own table in XX's package |
| The registry object `XX_INTAKE` with its **identity** (`LOGSYS`, `BUKRS`, `PAY_REF`: a payment reference is unique per feeder and company code) | `config/links/examples/xx_overlay.json` (XX's layer) | link registry, customer layer |
| Its payment reference on the standard items: field `FICA_OPEN_ITEM-ZZXX_PAYREF` of layer XX (the append on DFKKOP) | the same layer | link registry custom field |
| Links into the FI-CA layer: `XX_INTAKE_TO_ITEMS` (intake -> items), `XX_ITEM_TO_INTAKE` (item -> intake, "to one", ambiguous by design: the item carries no feeder), `XX_GLITEM_TO_INTAKE` (clearing line -> intake, inactive until V110) | the same layer | link registry links |
| The intake on the exceptions list (`XX_EXC_INTAKE`, key anchor `OBJECT`, object type `XXINTK`) and on the break groups (`XX_BRK_GROUP_INTAKE`, link anchor on the ambiguous link: candidates view, marker; pending V110) | `examples/intake_xx/config/extensions` | CDS extension (generated) |
| Its payment model: payments from XX's register, payment -> intake through registry link `XX_ITEM_TO_INTAKE` (rendered from the registry, never join text), requests from the intake | `examples/intake_xx/config/payment_model/mapping.json` | generated from a customer spec |

`python3 tools/intake_xx.py` (framework folder) runs the three generators and the serializer on the XX folder;
`--check` proves every output current; `--abaplint <binary>` compiles the XX sources (`src/**` and the pending
extensions) against the product's `src` and the parameter framework (`examples/intake_xx/abaplint.json`).

**What the product shows of XX's request reference.**

| Product surface | What the user sees | Generated object (XX's package) |
|---|---|---|
| Payment trace (payment object page, its requests) | the intake number as request reference, the feeder system as source, the payment reference as feeder reference | `ZI_XX_PaymReqLink` (DFKKOP joined to `ZXX_INTAKE` by `XX_ITEM_TO_INTAKE`), `ZI_XX_PaymReqFact`, `ZC_XX_PaymRequest`, `ZC_XX_PaymReqLink`, `ZC_XX_Payment` |
| Payment model (cube, trend, service) | the same contract fields as every customer | `ZR/ZC_XX_PaymCube`, `ZUI_XX_PAYM`, DCL `ZC_XX_PAYM` |
| Exceptions list (product view `ZC_CA_OpsException`) | payment reference, feeder system and received date of the intake an exception is about | `ZXX_X_EXC_C` (`extend view entity`) |
| Break groups (product view `ZR_CA_OpsBrkGroup`) - pending V110 | feeder and received date of the intake whose reference is in the assignment, blank with `AMBIGUOUS` when two feeders used it | `ZXX_X_BRKGRP_R`, `_C`, candidates view `ZXX_XC_BRK_GROUP_INTAKE` (pending folder) |

**No product object was edited.** The generators write only inside `examples/intake_xx` (root test
`test_generators_write_into_the_xx_folder_only`); no product source (`src`, `ddic`, `templates`, `config` outside the
examples, the shared engines `tools/abaptools`) names an XX intake object, registry ID or the custom field (house
check `intake_xx`, test `test_no_product_source_names_the_xx_intake`); `customer_terms` stays green. The product
changes of build Q (identity, ambiguity, preview, isolation) are product features every customer gets - none of them
names XX.

## 3. Identity beyond a document number

> **First principle:** a key tells the walker which row it holds; the identity tells the business which row is meant.
> A document number is not enough when the number is unique only per system, client, company code or fiscal year.

| Part | Rule |
|---|---|
| Identity of an object | `ZCA_OPS_LNKOBJ-IDENTITY_FIELDS` (spec key `identity`): the fields that make a row unique in the business sense; blank = the key fields. Fields of the object's own layer, never hidden (632). The client is part of every read (client-dependent SQL); a logical system, a company code or a fiscal year is named where it matters |
| "To one" link (11, N1) | its EQ / CONST conditions cover **every** identity field of the target - else it is **ambiguous by design** |
| Ambiguous by design | offline: refused unless the link names the reason (`ambiguity`, at most 60 characters), and a declared reason on a covered link is refused too; listed in the lineage (section "Ambiguous by design"). Run time: note 630 in `TY_EFFECTIVE-NOTES` (the link stays effective) and a warning `LINK_AMBIGUOUS` of the registry check. Never accepted silently |
| PREFER | narrows the candidates (the accepted attempt), it does not make a link "to one" (the earlier exemption is gone) |
| Payment model | a link ambiguous by design is joined only in the n:m section `payment_request` (every candidate is a row, a comment names the link); in a section with one row per key the generator stops |
| Extension | a link anchor on such a link reads a candidates view (section 4) |

Links ambiguous by design today: the example XX `XX_ITEM_TO_REQ` (attempts), `XX_ITEM_TO_INTAKE`,
`XX_GLITEM_TO_INTAKE` (feeder system); the first consumer's `CD_ITEM_TO_REQUEST` (attempts; inactive, V82). The product
layers have none (every "to one" product link covers its target's keys; no SAP identity beyond the keys is declared
without evidence).

## 4. Ambiguous matches are shown, never hidden

| Where | Behaviour |
|---|---|
| Walker `ZIF_CA_OPS_LINK_WALKER` | a "to one" link that finds several rows for one source row returns **every** candidate as a node with `MATCH = AMBIGUOUS` and `CANDIDATES` = their number; `RS_RESULT-AMBIGUITIES` lists per source row and link the candidates with their evidence: masked key, masked identity values, the layer and the quality of the link, the identity fields the link does not cover; problem 631. One row is `ONE`, a row of a "to many" link `MANY` |
| Drill-down `ZCA_OPS_LINK_DRILL` | the walk as a list: object, key, match, candidates, identity, link, layer, link quality, path; a candidate reached before on another path once more with its evidence; the problems (limits, links not followed) as notes |
| Extension column (`tools/extensions.py`) | the association reads the candidates view `Z<P>_XC_<extension>` (the target grouped by the link's join fields, `count( * ) as Candidates`, the maximum of each field; CONST / PREFER / NOTINIT as its WHERE); every column is `case when Candidates = 1 then ... end` - blank when several rows are candidates - and the declared marker element (`ambiguity_element`) reads `AMBIGUOUS`; the product's rows are never repeated (the association is truly "to one") |
| Payment trace | the n:m link payment -> request lists every candidate request (`ZI_<P>_PaymReqLink`); each request page shows its feeder |

## 5. Configuration preview and rollback

> **First principle:** see the effect before the transport; undo by a new decision, never by rewriting history.

| Configuration | Preview (report `ZCA_OPS_CFG_PREVIEW`, `ZIF_CA_OPS_CFG_PREVIEW`) | Rollback |
|---|---|---|
| Process catalogue activation `ZCA_OPS_CATACT` (effective-dated) | mode *catalogue*: the processes whose state changes between two dates - a planned row taking effect, an end - with the deciding row (source, effective from, reason, approver); the registered checks of those processes start / stop running from that date (one activation rule) | mode *rollback* (`CATALOGUE_ROLLBACK`): a row still planned is **deleted** before it takes effect; an effective row is answered by a **new row** from today or a later date with the state of the day before the change and the reason "Rollback of ..." - the history stays, nothing is back-dated, the approver rule of the app (240, four-eyes) applies |
| Link registry: layers, links, activation overrides `ZCA_OPS_LNKLYR` / `_LINK` / `_LNKACT` | mode *link*: a layer (L) or link (K) switched on or off - the effective links that change, the links that become ambiguous by design (or stop being so) and the registry problems that appear or disappear (`LINKS( current, proposed )`; any proposed row set can be compared, e.g. the seed rows of a pending transport) | the override row of `ZCA_OPS_LNKACT` (switch the link or layer back - the delivered row stays unchanged); for a customer overlay **without a transport**: parameter `GATE_LINK_LAYERS_OFF` (customer layers switched off at run time; a product layer is never switched by it) - build L's pattern of a non-developer-owned parameter maintained in QA1 / PS4 (its version parameters), removed again to undo |
| Break bucket rules `ZCA_OPS_BRKRUL` / flow stage rules `ZCA_OPS_FLWRUL` | mode *rule*: a rule of an area switched off - the configuration lines removed and the configuration version before and after (`ZCL_CA_OPS_CFG_VERSION`: the version every finding of the rule set records, so a sign-off made on the old version reopens) | not effective-dated: the previous rows by transport (the configuration version tells which findings were produced by which rows) |

Read only: the report writes nothing; a change is made in `ZUI_CA_OPS_CFG` on a customizing request.
Authorisation `ZCA_OPS` 03 for `CA_OPS`.

## 6. Missing DDIC objects

> **First principle:** a name the system does not know is a finding with its reason - never a dump, never a silent
> zero.

| Moment | Extension | Link registry | Adapter / check |
|---|---|---|---|
| Offline | `tools/extensions.py --check`: a field that is not a registry field of the target is refused | `tools/link_registry.py --check`: a field not in the repository's DDIC metadata (DDL / CDS sources) is refused | `tools/payfile.py`: the class of every adapter row exists and implements its role |
| On save (`ZUI_CA_OPS_CFG`) | - (generated code, activation) | source table / view (082), a field (083), the key and identity field lists (`FIRST_MISSING_FIELD`, 083 with the first missing name), condition references (225) | adapter class implements its interface; aggregate rows: table (082), fields (083) |
| At run | the product view stays active; a customer extension on a missing field fails its own activation (V156) | walker: link not followed, problem 634 (table / view) or 635 (field), `RS_RESULT-NOT_EVALUATED` - no read is attempted; registry check: `LINK_DDIC` warning and the evaluation partial / not evaluated with reason `DDIC_MISSING` (633) | aggregate check: the row is not evaluated (`TY_RESULT-EVAL`, reason `DDIC_MISSING`, message 636 with the missing table / field); every row missing = not evaluated, never OK; payment file adapters: a missing class is a problem of the adapter and the source's health (build K) |

Tests with doubles: `ZCL_CA_OPS_LINK_WALKER` (`missing_source_not_read`, `missing_field_not_read`),
`ZCL_CA_OPS_CHK_LINKS` (`ddic_missing_evaluation`), `ZCL_CA_OPS_CHK_AGG` (`missing_table_not_evaluated`,
`missing_table_beside_good`), `ZCL_CA_OPS_CFG_CHECKS` (`first_missing_field_named`).

## 7. Two-user company-code isolation (Fiori, exports, alerts, ticket links)

The rule is `docs/auth_zca_ops.md` section 3c: area authorised AND (company code blank OR area and company code
authorised). User A holds `ZCA_OPS` 03 for area `ZT_OPS_A` with `BUKRS ZT01`; user B the same with `ZT02`.

| Surface | Object | Company code | Restriction | Test |
|---|---|---|---|---|
| Fiori: exceptions, history, control review | `ZC_CA_OpsException`, `_OpsExcHist`, `_OpsCtlReview` | yes | DCL rule 3c | `ZCL_CA_OPS_DCL_TEST` (V38) |
| Fiori: payment file worklist (build K) | `ZC_CA_OpsPayFile`, `_OpsPfPayment`, `_OpsPfMilestone`, `_OpsPfEvidence`, `_OpsPfCard` | yes (the file's) | DCL rule 3c | `ZCL_CA_OPS_PF_DCL_TEST` (new) |
| Fiori: payment file days | `ZC_CA_OpsPfDay` | no (area-level) | area 03 | - |
| Fiori: cash findings (build N) | the exceptions list (`ZC_CA_OpsException`) - the cash checks write findings with their company code | yes | DCL rule 3c | `ZCL_CA_OPS_DCL_TEST` |
| Fiori: evaluation (build O) | `ZC_CA_OpsCheckStatus` (evaluation elements on the area dashboard rows) | yes (slice) | DCL rule 3c | existing |
| Fiori: coverage, alert reconciliation (build O) | `ZC_CA_OpsCoverage`, `ZC_CA_OpsAlertRecon` | no (a check of the registry, a run) | area 03 | `ZCL_CA_OPS_DCL_TEST` (`ltc_coverage`, `ltc_alert_recon`, new) - see D-Q2 |
| Analytical queries | `ZC_CA_OpsBrkQry`, `ZC_CA_OpsFlowQry`, `ZC_CA_OpsPilotQry` | yes | no DCL possible on a transient view: the cube it reads carries the rule | house check `dcl_company_code` |
| Export (list report "Export to spreadsheet", OData) | the same projection and service as the list | - | the same DCL: the export reads the entity set through the same OData service | DCL tests (the export issues the same read) - V317 |
| Alerts | rule pattern `BUKRS_PATTERN`; **e-mail content**: a digest never mixes company codes - one message per company code of the selection (the area-level findings in their own), the subject of each part ends with its company code (own intent key, own log row) | - | `ZCL_CA_OPS_ALERT_POLICY` | `bukrs_pattern_keeps_list`, `digest_split_by_company` (new) - V318 |
| Ticket links (build K) | `ZIF_CA_OPS_PF_TICKET_SINK`: one ticket per file; the payload `TY_TICKET` carries the file's own company code (`COMPANY_CODE`) and nothing of its payments | - | `ZCL_CA_OPS_PF_INGEST=>TICKET_OF` | `ticket_has_file_company` (new) - V319 |

**House check `dcl_company_code`** (shared rule `tools/abaptools/checks.py`, framework list `tools/checks.py`): every
consumption view (a `ZC_` view, or a view a service definition exposes) with a `CompanyCode` element has an access
control whose condition restricts `CompanyCode`; an analytical query reads a view that has one. **Result 2026-11-16:
no view of the framework lacked one** (the payment file worklist, coverage and alert reconciliation views of builds K
and O already carried their DCLs; the check now keeps it that way). Run against the first consumer's folders it reports
nothing either (not in its check list: suite changes are limited to its overlay).

## 8. Tests

| Kind | Test | Proves |
|---|---|---|
| Root (offline) | `tools/tests/test_extension_proof.py` | generators on the XX folder, outputs current and inside it, payment trace / product view show the reference, identity and ambiguity rules, blank columns with a marker, n:m-only joins, neutrality, `customer_terms`, XX compile (`ABAPLINT_BIN`) |
| Root (offline) | `tools/tests/test_link_registry.py` (`test_to_one_needs_target_identity`), `test_extensions.py` (`test_ambiguous_link_reads_a_candidates_view`) | engine rules |
| House checks | `intake_xx`, `dcl_company_code` (framework `tools/checks.py`) | section 2, section 7 |
| ABAP Unit | `ZCL_CA_OPS_LINK_WALKER` (6 new methods), `ZCL_CA_OPS_LINK_REGISTRY` (3), `ZCL_CA_OPS_CHK_LINKS` (3), `ZCL_CA_OPS_CHK_AGG` (2), `ZCL_CA_OPS_CFG_CHECKS` (2), `ZCL_CA_OPS_CFG_PREVIEW` (7), `ZCL_CA_OPS_DCL_TEST` (2 new classes), `ZCL_CA_OPS_PF_DCL_TEST` (4 classes), `ZCL_CA_OPS_ALERT_POLICY` (`digest_split_by_company`), `ZCL_CA_OPS_PF_TICKET_LOG` (`ticket_has_file_company`) | sections 3-7 on doubles (V310) |

## 9. What the offline checks cannot prove

V310-V321 (`docs/VERIFY.md`, section "2026-11-16 - extension and release-gate proof").

## 10. Decisions for the user

| ID | Decision |
|---|---|
| D-Q1 | **Ambiguous by design is allowed with a reason** (flagged in the lineage and by the registry check, candidates shown) rather than refused. The alternative - refuse every "to one" link that does not cover the identity - would force XX to add a feeder field to the standard items before any column could show its intake |
| D-Q2 | The alert reconciliation (`ZC_CA_OpsAlertRecon`, build O) counts the exceptions and alerts of a run across company codes - area-level telemetry like the run's item counters, no company-code values. Keep it area-level, or slice it per company code (needs the company code on the alert log row) |
| D-Q3 | A digest alert never mixes company codes (one e-mail per company code, built in): confirm, or make it a rule flag for lists that may see every company code |
| D-Q4 | Rollback of a customer overlay without a transport through `GATE_LINK_LAYERS_OFF` (maintained in QA1 / PS4 like build L's version parameters): confirm that the parameter may be maintained in production by the role that owns the overlay |
| D-Q5 | Break and flow rules are not effective-dated: preview (lines, configuration version) and rollback by transport. Effective-dated rule sets would need a version key on the rule tables (build L's typed-table pattern) - a later product change if wanted |

## Glossary

| Term | Business meaning |
|---|---|
| Identity | the fields that tell the business which row is meant (a reference per feeder and company code), as opposed to the walker's key |
| Ambiguous by design | a link that can find two rows for one, because what it joins on is not the whole identity - declared with its reason |
| Candidate | one of the rows such a link found; every candidate is shown with its evidence |
| Candidates view | a view of the customer's table grouped by what the link joins on, with the number of rows - it lets a column stay one value per product row |
| Preview | what a configuration change will alter, before it takes effect |
| Rollback | undoing a change by a new decision (a new row, an override, a parameter), never by rewriting history |
