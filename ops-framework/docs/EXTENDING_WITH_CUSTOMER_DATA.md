# Extending the product with customer data - one contract

> **First principle:** the product reads SAP standard data - released CDS views first, the FI-CA tables as the
> documented clean-core exception. A customer adds its own data **on top**, only through the extension points the
> product declares, and never by changing a product object.
> **Analogy:** a rented flat. The landlord builds the walls, the wiring and the hooks on the walls (the product and
> its extension points). The tenant brings its own furniture and pictures and hangs them on the hooks (the
> customer's tables, links and extensions). The tenant never moves a wall, and when the landlord renovates, the
> pictures go back on the same hooks.

Status (2026-11-15, build H): inventory, extensible product views, generator, the worked example and the first
consumer's pack are written and checked offline (abaplint, house checks, generator unit tests). **Nothing is
activated in an SAP system**; the open items are V153-V157 (section 10). **2026-11-16 (build Q,
`docs/EXTENSION_AND_GATE_PROOF.md`):** the proof that a customer adds its data by configuration only - the example XX
adds an intake flow and its payment reference in its own folder `examples/intake_xx` (section 8a); an extension on a
"to one" link that is ambiguous by design reads a candidates view and stays blank with a marker (section 4.3).

## 1. The rule

| Who | Owns | Changes |
|---|---|---|
| Product (`ZCA_OPS`) | the screens, cubes, queries, checks and their reads of SAP standard data; the list of extension points (`config/extension_points.json`) | only in a product release |
| Customer (its own folder and package) | its tables and views, its custom fields on standard tables, its links, its configuration rows, its plug-in classes, its CDS extensions | at any time, by its own transport |

Every extension point is one of five mechanisms, in this order of preference:

1. **Configuration row** - a row in a product table (a check, an alert rule, a flow, a bucket rule). No code.
2. **Link registry** - the customer layer of the link registry: its objects, its custom fields, its links between
   standard objects and its own (`docs/LINK_REGISTRY.md`). Data, not code.
3. **Generated from a spec** - the customer writes a spec in its folder; a product tool generates the code into the
   customer package (the payment model, the CDS extensions).
4. **CDS extension** - `extend view entity` of a product view, generated from a declaration (section 4).
5. **Plug-in class** - a customer class of a product interface, only where none of the above can express the need.

## 2. Where a customer adds its data (matrix)

The tables below are generated from the inventory `config/extension_points.json` by `tools/extensions.py`; the
house check `extensions` fails when the inventory, the views and this document disagree.

<!-- generated: extension points (tools/extensions.py; never edit this block) -->

Inventory `config/extension_points.json` (release 2026-11-15): 30 extension points, 9 of them CDS extension points.

| Module | Standard data source | Extension point | Mechanism | Product object | Example |
|---|---|---|---|---|---|
| Account flow | Released I_JournalEntryItem, I_CompanyCode, I_FiscalCalendarDate; FI-CA documents (DFKKOP, DFKKOPK, DFKKKO) | `FLOW` - Account flow cube and query (rows by stage, columns by account) | CDS extension (generated) | `ZI_CA_OpsFlowCube` | The customer's owner team of a stage or its own name of an account |
| Account flow | Stage configuration and the latest results of the stage checks | `FLOW_STAGE` - Stage card with control tags | CDS extension (generated) | `ZC_CA_OpsFlowStage` | The customer's service level of a stage |
| Account flow | Released I_JournalEntryItem, I_CompanyCode; FI-CA documents | `FLOW_CONFIG` - Flows, accounts by role, stages, tiles, stage controls and stage rules of the customer | configuration row | `ZCA_OPS_FLOW` | The customer's disbursement flow with its clearing accounts |
| Account flow | Open items the product cannot see | `FLOW_SOURCE` - A customer source of what explains an account's balance | plug-in class | `ZIF_CA_OPS_FLOW_SOURCE` | Requests in flight in the customer's request table |
| Alerts | Findings of every check | `ALERT_CHANNEL` - A delivery channel of the customer | plug-in class | `ZIF_CA_OPS_ALERT_CHANNEL` | The customer's ticket queue |
| Alerts | Findings of every check | `ALERT_RULE` - Alert rules and channels of the customer's area | configuration row | `ZCA_OPS_ALRULE` | Mail to the customer's payment team on a new break |
| Alerts | Findings of every check | `ALERT_SECTION` - A section of the alert mail with the customer's own content | plug-in class | `ZIF_CA_OPS_ALERT_SECTION` | The open requests of the customer's feeder in the morning mail |
| Area dashboard | Latest run and open findings of every registered check | `CHECK_STATUS` - Status per check (list and object page) | CDS extension (generated) | `ZR_CA_OpsCheckStatus` | The customer's support group of a check |
| Break analysis | Journal lines (ACDOCA) of the clearing accounts, grouped by assignment and currency (snapshot ZCA_OPS_BRKGRP) | `BRK_GROUP` - Break list, cube and query | CDS extension (generated) | `ZR_CA_OpsBrkGroup` | The worklist state and source system of the payment document in the assignment |
| Break analysis | Journal lines (ACDOCA) of a break group (snapshot ZCA_OPS_BRKITM), the released I_JournalEntryItem by its key | `BRK_LINE` - Lines of a break (object page table) | CDS extension (generated) | `ZR_CA_OpsBrkItem` | The customer's reference of the journal line from its own table |
| Break analysis | Journal lines (ACDOCA) of the clearing accounts | `BREAK_CONFIG` - Accounts, buckets and ordered bucket rules of the customer's area | configuration row | `ZCA_OPS_BRKACC` | A bucket for the customer's bank cumulation |
| Break analysis | Journal lines (ACDOCA) of the clearing accounts | `BREAK_LINK_RULE` - A LINK condition follows a registry link from the line to a customer object to explain the break | link registry (customer layer) | `ZCA_OPS_BRKCND` | The line's assignment leads to the bank line and its transaction code |
| Business process checks | Any approved table: FI-CA tables or the customer's own tables | `AGG_CHECK` - Count / sum / age over a table approved for the area (ZCA_OPS_TABWL), without code | configuration row | `ZCA_OPS_AGG` | Requests in status PENDING older than one day in the customer's request table |
| Business process checks | Whatever the check reads (read-only) | `CHECK_CLASS` - A customer check class where a configuration row cannot express the rule | plug-in class | `ZIF_CA_OPS_CHECK` | A check that compares the customer's request log with the FI-CA items |
| Business process checks | Delivered checks of the product (SAP standard tables, released views) | `CHECK_ROW` - Register a delivered check for the customer's area with its thresholds | configuration row | `ZCA_OPS_CHECK` | The break check ZCL_CA_OPS_CHK_BREAK registered in the customer's area |
| Control review | Controls and the stored results of the checks they cover | `CTL_REVIEW` - Daily control review (list and object page) | CDS extension (generated) | `ZC_CA_OpsCtlReview` | The customer's audit reference and tester of a control |
| Control review | Stored results of the checks a control covers | `CONTROL` - The customer's controls, their checks and cut-off times | configuration row | `ZCA_OPS_CONTROL` | The customer's daily reconciliation control |
| Every module | Delivered parameter definitions with defaults | `PARAMETERS` - Values of the customer's area; the customer's own parameter definitions | configuration row | `ZCA_PARAM` | BRK_UNEXPLAINED_DAYS for the customer's area |
| Exceptions | Findings of the product's checks (ZCA_OPS_FINDING), which read SAP standard and approved tables | `EXC` - Exceptions list and object page | CDS extension (generated) | `ZC_CA_OpsException` | The feeder and received date of the customer's request an exception is about |
| Job monitoring | SAP background jobs and their logs | `JOB_ENRICHER` - Business context of a failed job from the customer's tables | plug-in class | `ZIF_CA_OPS_JOB_ENRICHER` | The payment run and company code of a failed payment job |
| Job monitoring | SAP background jobs and their logs | `JOB_RESOLVER` - Which jobs belong to one run of an application | plug-in class | `ZIF_CA_OPS_JOB_RESOLVER` | The worker jobs of a parallel processing run |
| Link registry (every module) | SAP standard objects of the layers S4CORE (released views, bank statement, partner) and FICA (FI-CA tables) | `LINK_OVERLAY` - Customer layer: its tables and views, custom fields on standard tables, its links, switch-off and replacement of a standard link | link registry (customer layer) | `ZCA_OPS_LNKLYR` | Custom field ZZXX_REQ_ID on DFKKOP and the link item -> request (config/links/examples/xx_overlay.json) |
| Operations response | Findings of every check | `RESPONSE` - Runbook links and correlation rules of the customer's checks | configuration row | `ZCA_OPS_RUNBOOK` | The customer's runbook page of a check |
| Payment file lifecycle | Payment file register of the product (ZCA_OPS_PFFILE), fed from FI-CA payment runs and the adapters | `PAYFILE` - Payment file worklist (list report and object page) | CDS extension (generated) | `ZC_CA_OpsPayFile` | The customer's own file name or business line of a file |
| Payment file lifecycle | Middleware, bank acknowledgements, schedulers and ticketing the product cannot see | `PAYFILE_ADAPTER` - A customer source of files, transfers, bank answers, jobs or statements, a ticket sink, a calendar | plug-in class | `ZIF_CA_OPS_PF_ADAPTER` | The bank acknowledgement table of the customer |
| Payment file lifecycle | FI-CA payment runs (DPAYH), SAP background jobs (TBTCO) | `PAYFILE_CONFIG` - File types, milestones and deadlines, status mappings and adapters of the customer | configuration row | `ZCA_OPS_PFTYP` | The customer's acceptance deadline of 10:00 on the next business day |
| Payment model | The product contract; the G/L side on released journal views | `PAYMENT_MODEL` - Mapping spec: which customer table holds a payment, a request, an attempt; adapter views generated into the customer package; feeder systems and texts as rows of ZCA_OPS_FEEDER / ZCA_OPS_PMDIM | generated from a customer spec | `mapping.json` | Customer XX with requests from a claims and a billing system (section 3 of the document) |
| Process catalogue | SAP standard processes of the catalogue packages with their activation | `CATALOGUE` - Process catalogue (list and object page) | CDS extension (generated) | `ZR_CA_OpsCatalogue` | The customer's process owner and its own process reference |
| Process catalogue | SAP standard processes of the packages S4CORE and FI-CA | `CATALOGUE_LAYER` - Customer layer of the catalogue: activation of standard processes, its own processes | configuration row | `ZCA_OPS_CATACT` | config/catalogue/examples of the framework |
| Retention | The product's stored results | `PURGE_TARGET` - Retention of the customer's own stored results under the product's purge | plug-in class | `ZIF_CA_OPS_PURGE_TARGET` | The customer's daily snapshot table |

**CDS extension points** (the customer extends the base view; the generator passes the new elements on to the other views; an optional view only when the extension asks for it):

| Point | Views (the base view first) | Anchors | VERIFY |
|---|---|---|---|
| `EXC` | `ZC_CA_OpsException` (projection) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `OBJECT` key (ObjectKey), discriminator ObjectType; `CHECK` key (Area, Group2) | V153, V154, V157 |
| `BRK_GROUP` | `ZR_CA_OpsBrkGroup` (select); `ZC_CA_OpsBrkGroup` (projection, reads `ZR_CA_OpsBrkGroup`); `ZI_CA_OpsBrkCube` (select, reads `ZR_CA_OpsBrkGroup`, optional); `ZC_CA_OpsBrkQry` (query, copied as `ZC_{P}_BrkQry`, reads `ZI_CA_OpsBrkCube`, optional) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `JOURNAL_GROUP` link from `S4_JOURNAL_ITEM` (Ledger = Ledger, CompanyCode = CompanyCode, GLAccount = GLAccount, AssignmentReference = Assignment); `ASSIGNMENT` key (Assignment, CompanyCode) | V153, V154, V155, V157 |
| `BRK_LINE` | `ZR_CA_OpsBrkItem` (select); `ZC_CA_OpsBrkItem` (projection, reads `ZR_CA_OpsBrkItem`) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `JOURNAL_ITEM` link from `S4_JOURNAL_ITEM` (Ledger = Ledger, CompanyCode = CompanyCode, FiscalYear = FiscalYear, AccountingDocument = AccountingDocument, LedgerGLLineItem = LedgerGLLineItem) | V153, V154, V157 |
| `FLOW` | `ZI_CA_OpsFlowCube` (select); `ZC_CA_OpsFlowQry` (query, copied as `ZC_{P}_FlowQry`, reads `ZI_CA_OpsFlowCube`, optional) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `STAGE` key (Area, FlowId, StageId); `ACCOUNT` key (Area, FlowId, FlowAccount) | V153, V154, V155, V157 |
| `FLOW_STAGE` | `ZC_CA_OpsFlowStage` (select) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `STAGE` key (Area, FlowId, StageId) | V153, V154, V157 |
| `CHECK_STATUS` | `ZR_CA_OpsCheckStatus` (select); `ZC_CA_OpsCheckStatus` (projection, reads `ZR_CA_OpsCheckStatus`) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `CHECK` key (Area, CheckId) | V153, V154, V157 |
| `CATALOGUE` | `ZR_CA_OpsCatalogue` (select); `ZC_CA_OpsCatalogue` (projection, reads `ZR_CA_OpsCatalogue`) | `PROCESS` key (ProcessId) | V153, V154, V157 |
| `CTL_REVIEW` | `ZC_CA_OpsCtlReview` (projection) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `CONTROL` key (Area, ControlId) | V153, V154, V157 |
| `PAYFILE` | `ZR_CA_OpsPayFile` (select); `ZC_CA_OpsPayFile` (projection, reads `ZR_CA_OpsPayFile`) | `COMPANY` link from `S4_COMPANY_CODE` (CompanyCode = CompanyCode); `FILE` key (Area, FileId, Currency) | V153, V154, V157 |

Annotations of every extensible view: `extensible: true`, `elementSuffix: 'ZOP'`, `allowNewDatasources` true on the base view (false on a view the elements are passed on to), `dataSources` the alias of a select view's main source, `quota.maximumFields: 50`, `quota.maximumBytes: 2000` (V153).

<!-- end of generated block -->

## 3. Which mechanism for which need

```text
What do you want to add?
|
+-- a column next to what a product list, object page, card, cube or query shows
|     |
|     +-- one value of your data per product row?
|     |     +-- your data hangs off a standard object the row is (a journal line, a company code)
|     |     |       -> CDS extension, link anchor: name a "to one" registry link of your layer   (section 4)
|     |     +-- your table is keyed by what the row carries (process, check, control, stage, account, object key)
|     |             -> CDS extension, key anchor: name an object of your layer and map its keys (section 4)
|     +-- several rows of your data per product row (one break line, many requests)
|             -> not a column: drill down with the link walker (LINK_REGISTRY.md section 5), raise it as a
|                check, or build your own view; declare the wish "blocked" with its reason so it stays visible
|
+-- a new rule that raises exceptions
|     +-- a count / sum / age over one approved table -> AGG_CHECK (configuration row)
|     +-- anything else                               -> CHECK_CLASS (plug-in of ZIF_CA_OPS_CHECK)
|
+-- how SAP standard objects reach your tables      -> LINK_OVERLAY (registry layer)
+-- why a clearing-account break exists            -> BREAK_CONFIG rows, BREAK_LINK_RULE (registry link)
+-- what explains an account's balance             -> FLOW_CONFIG rows, FLOW_SOURCE (plug-in)
+-- your own payment / request tables              -> PAYMENT_MODEL (mapping spec, generated adapters)
+-- your jobs, alerts, retention, thresholds       -> JOB_RESOLVER / JOB_ENRICHER, ALERT_RULE / _SECTION /
                                                      _CHANNEL, PURGE_TARGET, PARAMETERS
```

A need that fits none of them is a request for a new extension point - a product change, decided and delivered by
the product, then listed in the inventory. A customer never works around a missing point by changing a product
object.

## 4. CDS extensions of the product views

### 4.1 The pattern

> **First principle:** a product view promises a small set of stable elements (its anchors); a customer joins its
> data on them and adds columns, and the product passes the columns on to the views above.
> **Analogy:** a socket strip fixed to the wall: the product guarantees where the sockets are; what the customer
> plugs in is its own business.

An extension point names:

| Part | Meaning |
|---|---|
| **Base view** | the view the customer extends: it gets the customer's association and its elements |
| **Views it passes them on to** | a projection (list / object page), a cube; an analytical query is **copied** (4.6) |
| **Anchors** | the elements the customer may join on. **link**: the row of the view is a row of a standard object of the link registry (element map field -> element), and the customer names a registry link leaving that object. **key**: the customer names an object of its own registry layer and maps every key field of it to anchor elements (with the value of a discriminator element, e.g. the object type of a finding) |

The product marks every view of a point with SAP's CDS extensibility annotations (VERIFY V153):

```cds
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true      // base view only; false on a view the elements pass to
@AbapCatalog.extensibility.dataSources: [ 'Grp' ]         // select views: the alias of the main source
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
```

The views of a RAP business object (exceptions, control review) are extended at their **projection**: the
behaviour definition, its field list and its mapping stay untouched (decision D-H5).

### 4.2 What the generator renders

For the declaration of section 7 (customer XX, the audit register of its controls next to the daily control review):

```cds
extend view entity ZC_CA_OpsCtlReview with
  association [0..1] to zxx_ctl_reg as _ZZXXCtlReg on  _ZZXXCtlReg.area = $projection.Area
                                                   and _ZZXXCtlReg.control_id = $projection.ControlId
{
  @EndUserText.label: 'Audit reference'
  @UI.lineItem: [ { position: 900, importance: #LOW } ]
  @UI.identification: [ { position: 900 } ]
  _ZZXXCtlReg.audit_ref as ZZXX_AuditRef,
  @EndUserText.label: 'Tester'
  @UI.lineItem: [ { position: 910, importance: #LOW } ]
  @UI.identification: [ { position: 910 } ]
  concat( '****', right( _ZZXXCtlReg.tester, 4 ) ) as ZZXX_Tester
}
```

All extensions of one point form one object per view, `Z<P>_X_<code>` (e.g. `ZXX_X_CTLREV_C`); a view the elements
are passed on to gets only the element names (`ZZXX_AuditRef`, or `Grp.ZZXX_AuditRef` in a cube); a query copy is
`ZC_<P>_<name>`. The labels are repeated at every level (the product views ignore propagated annotations).

### 4.3 Rules (refused offline by `tools/extensions.py --check`)

| Rule | Why |
|---|---|
| The point is a CDS extension point of the inventory and the anchor one of its anchors | only declared extension points |
| Extension IDs start with the customer prefix (`XX_`), elements with `ZZ<P>_` or `YY<P>_`, associations with `_ZZ<P>`; the pack's registry layer is a customer layer with the same prefix | no collision with the product or another customer |
| A link anchor: the link leaves the anchor's object, is **"to one"** (11 / N1) and reads only fields the anchor provides; a replacement of an active customer layer wins | a "to many" link would repeat the product's rows and break every total |
| A key anchor: the object is of the customer's own layer and **every** key field is mapped to an anchor element | one row of the customer per product row |
| Every field is a registry field of the target object | the registry is the one place that knows a field |
| A hidden field (H) is never added; a masked field (M) is rendered `concat( '****', right( field, 4 ) )` and cannot be declared weaker | the extension shows its columns to every user who sees the product row (4.5) |
| Element names unique per point; at most `maximumFields` elements per point | the view's quota |
| An optional view (cube, query copy) only with the view it reads from | the cube needs the base element, the query the cube element |
| A `PREFER` condition of a link renders as a filter on the preferred value | an association adds one column: the preferred row only, blank when there is none |
| A link **ambiguous by design** (its conditions do not cover the identity of its target, `docs/LINK_REGISTRY.md` §3a) needs a marker element (`ambiguity_element`); the association reads the generated candidates view `Z<P>_XC_<extension>` (the target grouped by the link's join fields with `count( * ) as Candidates`, the maximum of each field, CONST / PREFER / NOTINIT as its WHERE); every column is the value only when one row is a candidate, else blank, and the marker reads `AMBIGUOUS` (build Q, VERIFY V312) | several rows per product row would repeat the product's rows; picking one silently would show a wrong value |

### 4.4 Status of an extension

| Status | When | Where it goes |
|---|---|---|
| **active** | the registry link is active (as the walker would follow it), the object and its source are named, no field is VERIFY or a placeholder, the declaration names no open VERIFY item | the customer package (`src/ext`), imported by abapGit |
| **pending** | any of the above is open | the pending folder (`config/extensions/pending`), never imported; the file shows the code as it will be once everything pending is active |
| **blocked** | declared so, with its reason: the wish has no "to one" path (section 3) | nowhere; listed in the report so the gap stays visible |

### 4.5 Security

The product view's access control governs the extended row; the access control of the customer's table is not
evaluated for the elements of an association path (V157). The customer therefore decides, field by field, what
every user of the product view may see: the sensitivity of the registry is the floor (M masked, H never shown).
Extensions read only; nothing is written.

### 4.6 Analytical queries - the fallback

Whether an analytical query (transient view entity) can be extended on 7.58 is VERIFY (V155). Until it is
confirmed, the generator **copies** the product query into the customer package (`ZC_<P>_BrkQry`,
`ZC_<P>_FlowQry`) with the customer's elements as free dimensions; the copy reads the product cube with its
extension. `--check` fails when the product query changes and the copy is not regenerated. Once V155 is closed,
the inventory switches the query views from `query` (copy) to `projection` (extension) - no declaration changes.

### 4.7 Fallbacks if SAP refuses an extension (V153, V154)

| Finding in DV1 | Fallback |
|---|---|
| An annotation name or value is refused | the inventory's `annotation` block changes; `--check` names every view to adjust |
| Extension element names must carry the element suffix | inventory switch `suffix_in_names`: the generator appends `ZOP` (`ZZXX_AuditRefZOP`) |
| A new association in the extension of a RAP projection is refused | the point's base moves to the root view (a new inventory row), or the customer keeps its data in its own read-only view over the product projection with its own app |
| `extend view entity` from a customer package is refused for a view | that point is closed in the inventory; the customer builds a read-only view over the product view (the anchor elements plus its association) and its own service - the product app stays unchanged |

## 5. The customer plug-in pack

Everything a customer adds lives in its own folder and package:

```text
<customer>/
  config/links/overlay.json            registry layer: its objects, custom fields, links, switch-offs
  config/extensions/pack.json          prefix, registry layer, folders, date of the pack
  config/extensions/*.json             extension declarations ({"extensions": [...]})
  config/extensions/pending/           generated, waiting for VERIFY items - never imported
  config/payment_model/mapping.json    payment model spec (generated adapter views)
  config/catalogue/overlay.json        catalogue layer: activation, own processes
  config/breaks/, config/flows/        configuration rows of its area
  config/processes/*.json              its business processes (scaffold tools/abaptools/new_process.py)
  src/ext/                             generated CDS extensions and query copies (its package)
  src/...                              its plug-in classes (ZIF_CA_OPS_* implementations), helper views
  tools/<tool>.py                      wrappers of the shared engines (a few lines of settings each)
  docs/extensions/extensions.md        generated report of the pack
```

## 6. Steps for a customer

| # | Step | Effort |
|---|---|---|
| 1 | List the wishes: which product screen, which column, from which table. Mark every field not seen in SE11 as VERIFY | 0.5 day |
| 2 | Registry: the customer's objects and fields (and, for a link anchor, its link) in `config/links/overlay.json`; `python3 tools/link_registry.py --check` | 0.5 day |
| 3 | Declarations `config/extensions/*.json` (section 7) and `pack.json`; wrapper `tools/extensions.py` (copy of the ops suite's, two settings) | 0.5 day |
| 4 | `python3 tools/extensions.py`, then the serializer; add `--check` to the customer's check list | 1 hour |
| 5 | DV1: activate the product first, then the customer package (extensions after the views they extend), republish the service bindings (`ZUI_CA_OPS_*_O4`) so the metadata carries the new elements; the query copies in *Multidimensional Reports* | 0.5 day |
| 6 | Close the VERIFY items of the pack; each closed item turns its extensions active on the next run | per item |

A product upgrade: pull the product, run `tools/extensions.py --check` in the customer folder. A changed anchor
element fails the framework's own check before release; a changed product query makes the customer's copy out of
date - regenerate it.

## 7. Declaration

`config/extensions/<name>.json`:

```json
{"extensions": [
  {"id": "XX_CTL_AUDIT_REF", "point": "CTL_REVIEW", "anchor": "CONTROL",
   "description": "Audit reference and tester of the control",
   "object": "XX_CTL_REGISTER", "keys": {"AREA": "Area", "CONTROL_ID": "ControlId"},
   "association": "_ZZXXCtlReg",
   "fields": [
     {"field": "AUDIT_REF", "element": "ZZXX_AuditRef", "label": "Audit reference"},
     {"field": "TESTER", "element": "ZZXX_Tester", "label": "Tester", "sensitivity": "M"}]}
]}
```

| Key | Meaning |
|---|---|
| `id`, `description` | ID with the customer prefix; text up to 60 characters |
| `point`, `anchor` | from the inventory (section 2) |
| `link` | link anchor: a registry link leaving the anchor's object (any layer; a replacement wins) |
| `object`, `keys`, `discriminator` | key anchor: an object of the customer layer, each key field -> an anchor element; the discriminator value where the anchor has one |
| `association` | name of the association (`_ZZ<P>...`) |
| `also` | optional views of the point (cube, query copy) |
| `fields` | `field` (registry field of the target), `element` (`ZZ<P>_...`), `label`, `sensitivity` (blank, M) |
| `status`, `reason`, `verify` | `pending` / `blocked` with the reason; open VERIFY items of the customer that keep it pending |
| `ambiguity_element`, `ambiguity_label` | a link anchor on a link ambiguous by design: the marker element (`ZZ<P>_...`, reads `AMBIGUOUS` when several rows are candidates) and its label (default "Match") - build Q |

`pack.json`: `prefix`, `layer` (the customer registry layer), `links` (its layer specs), `since` (date written into
the generated files), `package_folder`, `pending_folder`, `package_text`, `report`.

## 8. Worked example - customer XX (fictitious)

`config/extensions/examples/xx` (registry: `config/links/examples/xx_overlay.json`), validated and rendered by the
framework's `--check` into `docs/extensions/example_xx.md`, never into a product package. **No framework file
changed for it** (test `test_example_needs_no_framework_change`).

| Extension | Point / anchor | What the user sees | Status |
|---|---|---|---|
| `XX_EXC_REQUEST` | `EXC` / `OBJECT` (object type `XXREQ`, key `ObjectKey`) | feeder, received date and masked member of the request an exception is about | active |
| `XX_CTL_AUDIT_REF` | `CTL_REVIEW` / `CONTROL` | audit reference and masked tester of a control | active |
| `XX_FLOW_STAGE_SLA` | `FLOW_STAGE` / `STAGE` (flow and stage only) | service level and owner team on the stage card | active |
| `XX_FLOW_STAGE_TEAM` | `FLOW` / `STAGE`, with the query copy `ZC_XX_FlowQry` | owner team of a stage as a free dimension of the account flow query | active |
| `XX_BRK_GROUP_REQ` | `BRK_GROUP` / `JOURNAL_GROUP`, cube and query copy | feeder of the request in the assignment | pending: its link waits for the element names of the released journal view (V110) |
| `XX_BRK_LINE_CASE` | `BRK_LINE` / `JOURNAL_ITEM` | the investigation case of a line | blocked: the case table is keyed by group |

## 8a. Worked example - the intake flow of customer XX (build Q, 2026-11-16)

`examples/intake_xx` is a complete customer folder of XX: its intake table `ZXX_INTAKE` and payment register
`ZXX_PAYMENT`, the declarations `config/extensions/intake.json` (`XX_EXC_INTAKE` on the exceptions list, active;
`XX_BRK_GROUP_INTAKE` on the break groups through the ambiguous link `XX_GLITEM_TO_INTAKE`, pending V110), its payment
model spec (payment -> intake through registry link `XX_ITEM_TO_INTAKE`) and its registry layer (the framework's
example overlay). `python3 tools/intake_xx.py` (framework folder) generates XX's package `src/ext`, `src/paym`, its
seed rows, lineage and reports into that folder only; `--check --abaplint <binary>` proves them current and compiled
against the product, and that no product source names them (house check `intake_xx`, root test
`tools/tests/test_extension_proof.py`). Details: `docs/EXTENSION_AND_GATE_PROOF.md` section 2.

## 9. A consumer's pack

The first consumer keeps its pack in its own folder (`config/extensions`, its overlay document and its own VERIFY
items); the framework's check list never reads it. Its check set runs the same engine with its own profile.

## 10. What the offline checks cannot prove

| ID | Kind | Item |
|---|---|---|
| V153 | VERIFY-ADT | The `@AbapCatalog.extensibility` annotations on 7.58 standard ABAP (names, `elementSuffix` three characters, `allowNewDatasources`, `dataSources` with a select alias, `quota.maximumFields` / `maximumBytes`) on a root view entity with joins, a view entity with parameters, a cube, a select view and a transactional projection; the views still activate and their DCLs, services and tests are unchanged; whether extension element names must end with the element suffix (inventory switch `suffix_in_names`) |
| V154 | VERIFY-ADT | `extend view entity` from a customer package: a new `association [0..1]` with `$projection` elements and literals (`ObjectType = 'XXREQ'`) in the ON condition, CHAR fields of different length compared, path elements with element annotations; in a projection the element of the base extension by name, in a cube `Grp.<element>`; a new association in the extension of a RAP projection (`ZC_CA_OpsException`, `ZC_CA_OpsCtlReview`) with the behaviour unchanged; the elements in the OData V4 metadata after republishing the binding and on the list / object page |
| V155 | VERIFY-ADT | Extension of an analytical query (transient view entity) on 7.58 - if allowed, the query views switch from copy to extension; until then the copies `ZC_<P>_BrkQry` / `ZC_<P>_FlowQry` over the extended cube in *Multidimensional Reports*; `concat( '****', right( x, 4 ) )` on the type of a masked field |
| V156 | VERIFY-ADT / abapGit | The DDLS source type abapGit writes for an `extend view entity` (the serializer writes `E`, constant `EXTEND_SOURCE_TYPE`) and its description; activation order of a customer package with extensions after the product |
| V157 | VERIFY-ADT / security | The access control of an association target is not evaluated for the path elements of an extension (the product view's DCL governs); masked fields masked in the UI, the export and the query; `quota.maximumBytes` against the field lengths of a pack (offline only the number of fields is checked) |
| V312 | VERIFY-ADT | The candidates view of an extension on a link ambiguous by design and the CASE over its path elements in `extend view entity` (build Q) |
| V320 | Sandbox | The XX intake package activates after the product; the append `ZZXX_PAYREF` on DFKKOP; the intake columns on the exceptions list (build Q) |

## 11. Decisions for the user

| ID | Decision |
|---|---|
| D-H1 | One contract: the inventory lists every extension point; what is not in it is not extensible. A new point is a product change |
| D-H2 | Columns only through "to one" joins; data with many rows per product row is a drill-down, a check or the customer's own view |
| D-H4 | Analytical queries are copied into the customer package until V155 confirms that they can be extended |
| D-H5 | The views of a RAP business object (exceptions, control review) are extended at the projection; the root views stay untouched |
| D-H6 | An extension column is visible to every user of the product row; the registry's sensitivity is the floor, hidden fields never become columns |
| D-H7 | Element suffix `ZOP`, quota 50 fields and 2,000 bytes per view; IDs and names with the customer prefix |
| D-Q1 | A "to one" link that does not cover the identity of its target is allowed with a reason and rendered through a candidates view with a marker, rather than refused (`docs/EXTENSION_AND_GATE_PROOF.md` section 10) |

(D-H3 is the first consumer's decision, kept in its own overlay document.)

## Glossary

| Term | Business meaning |
|---|---|
| Extension point | a place where the product lets a customer add its own data or logic, listed in the inventory |
| Anchor | the stable columns of a product view a customer's data is joined on |
| Base view | the product view the customer extends; the product passes the new columns on to the screens and cubes above |
| "To one" | each product row finds at most one row of the customer's data - the product's totals stay right |
| Pack | everything one customer adds: its registry layer, declarations, configuration rows and classes |
| Pending | written and checked, waiting for a fact to be confirmed in the system; never installed until then |
| Blocked | wanted, but there is no "to one" path - kept visible with its reason |
