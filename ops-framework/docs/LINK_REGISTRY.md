# Link registry — business objects, fields and the links between them

> **First principle:** the framework knows how SAP standard objects link; a customer adds only what is its own — its
> tables, its custom fields on standard tables, its links — as configuration on top, and may switch a standard link
> off or replace it. Nothing customer-specific is code of the framework.
> **Analogy:** a city map in layers. The base map (streets every city has) is printed by the publisher; a transport
> sheet (tram lines of a kind of city) is laid over it; each city draws its own bus routes on a transparent sheet on
> top. A route may close a street of the sheet below (switch-off) or detour around it (replacement) — the printed
> map is never redrawn.

Status (2026-11-11): tables, configuration app, walker, registry check, offline engine, product layers and the
worked example are written and checked offline (abaplint, house checks, generator and engine unit tests). **Nothing
is activated or run in an SAP system**; the open items are V116-V120 (§10).

## 1. What it answers

"How does a field of one table reach another table, and which of those paths are ours?" For example: a customer's
payment request table carries a request number; the same number sits in a custom field the customer appended to the
standard subledger items; the items are cleared by a payment document; the payment document appears on a bank
statement line. The registry holds each of those steps once, with its evidence, and every consumer of the
framework (a drill-down, a generated CDS view, an impact report) uses the same definition.

| Who | Uses the registry for |
|---|---|
| Operations (drill-down) | `ZIF_CA_OPS_LINK_WALKER`: from one object and key, every linked object with its key, the path and the evidence quality (§5) |
| Developers (generated CDS) | the payment model generator renders a join from a registry link instead of a hand-written join text (§6.2) |
| Change management (impact) | `docs/links/impact.md` of a component: if a field changes, which links, object keys, payment model sections and aggregate checks depend on it (§6.1) |
| Auditors (lineage) | `docs/links/lineage.md`: the layers, objects and links as a diagram, with the custom field flows (§6.1) |

## 2. Layers

> **First principle:** a higher layer may extend and reference a lower one, never the reverse.
> **Analogy:** a tenant may hang pictures on the landlord's wall; the landlord's plan never mentions the pictures.

| Rank | Layer | Kind | Prefix | Holds | Delivered by |
|---|---|---|---|---|---|
| 10 | `S4CORE` | S product baseline | `S4_` | SAP standard objects of the S/4HANA core: journal entry, journal entry item, company code (released CDS views `I_JournalEntry`, `I_JournalEntryItem`, `I_CompanyCode`), bank statement header / line (`FEBKO`, `FEBEP`), business partner (`BUT000`) | the framework, `config/links/s4core.json` |
| 20 | `CONTRACT` | I industry package | `CA_` | SAP standard tables of contract accounting (contract accounts receivable and payable and its collections / disbursements extension): document header and items (`DFKKKO`, `DFKKOP`), reconciliation-key summary records (`DFKKSUMC`), payment run (`DPAYH`), cheque register (`DFKKCR`), returns lot items (`DFKKRP`), notification-of-change lot items (`DFKKNRP`), payment methods per country (`TFK042Z`) | the framework, `config/links/packages/contract_accounting.json` |
| 30+ | the customer's | C customer overlay | its own, e.g. `XX_` | the customer's tables and CDS views, its custom fields on standard objects, its links, its activation overrides and replacements | the consumer, e.g. `<consumer>/config/links/overlay.json` |

Rules (offline and at run time):
1. Every object and link ID of a layer starts with the layer's prefix — a customer row can never be mistaken for a
   product row, and an upgrade of the product never collides with a customer ID.
2. An object, field or link references only its own or a lower layer. The product layers name only SAP standard
   objects (test `test_product_layers_are_standard_only`); the house check `customer_terms` keeps every customer
   word out of them.
3. A customer adds a **custom field to a standard object** with a field row of its own layer (`fields` of its spec,
   `ZCA_OPS_LNKFLD-LAYER_ID` = its layer). The standard object stays the product's.

## 3. Model — six tables (package `ZCA_OPS`, customizing, maintained in `ZUI_CA_OPS_CFG`)

| Table | Key | Fields | Meaning |
|---|---|---|---|
| `ZCA_OPS_LNKLYR` | `LAYER_ID` | `LAYER_KIND` (S / I / C), `LAYER_RANK`, `ID_PREFIX`, `DESCRIPTION`, `OWNER`, `ACTIVE` | the layers |
| `ZCA_OPS_LNKOBJ` | `OBJECT_ID` | `LAYER_ID`, `SOURCE_NAME` (table or CDS view entity), `SOURCE_KIND` (T / V), `KEY_FIELDS` (comma list), `DESCRIPTION`, `ACTIVE` | business objects; the key fields identify a row for the walker (a business identity, e.g. "the items of a document" - not necessarily the full DDIC key) |
| `ZCA_OPS_LNKFLD` | `OBJECT_ID`, `FIELD_NAME` | `LAYER_ID`, `SOURCE_NAME`, `DATA_ELEMENT`, `SENSITIVITY` (blank / M masked / H hidden), `EVIDENCE` (C confirmed / V VERIFY), `VERIFY_REF`, `DESCRIPTION` | the fields an object exposes to links; partner and member numbers are M (the walker shows the last four characters) |
| `ZCA_OPS_LINK` | `LINK_ID` | `LAYER_ID`, `FROM_OBJECT`, `TO_OBJECT`, `CARDINALITY` (11 / 1N / N1 / NM), `QUALITY` (C confirmed / P probable), `FALLBACK_OF`, `REPLACES`, `ACTIVE`, `OWNER`, `VERIFY_REF`, `DESCRIPTION` | directed links |
| `ZCA_OPS_LNKCND` | `LINK_ID`, `COND_NO` | `COND_KIND`, `FROM_REF`, `TO_REF` (TABLE-FIELD), `COND_VALUE`, `TRANSFORM`, `TRANSFORM_ARG` | the conditions of a link, in order |
| `ZCA_OPS_LNKACT` | `TARGET_KIND` (L / K), `TARGET_ID` | `LAYER_ID`, `ACTIVE`, `REASON`, `OWNER` | a customer layer switches a layer (L) or a link (K) of a lower layer on or off - the delivered row stays unchanged |

**Conditions.**

| Kind | Meaning | Example |
|---|---|---|
| `EQ` | to field = from field, after the transform | `DFKKSUMC-FIKEY = DFKKKO-FIKEY` |
| `CONST` | to field = value (comma list = IN) | `I_JournalEntry-ReferenceDocumentType = 'FKKSU'` |
| `NOTINIT` | to field is filled | a payment document that is not blank |
| `PREFER` | of several rows of one source row, keep those with to field = value — when one exists; otherwise all stay visible | the accepted attempt of a request is the row with status `SUCCESS`, never "the highest counter" |

Transforms (EQ only, applied to the from value): `ALPHA` (leading zeros to length *n*), `NOZERO` (leading zeros
removed), `UPPER`, `LEFT` / `RIGHT` (first / last *n* characters, e.g. the cheque number of the cheque register to the
13 characters of the bank line), `PREFIX` / `SUFFIX` (text added — e.g. a reference key built from a reconciliation
key). A blank from value never joins: a blank key would match every blank row.

**Fallback chains.** A link with `FALLBACK_OF` = *L* is tried only for the source rows *L* found nothing for, and only
when *L* itself ran (a fallback alone would change what the chain means — e.g. a partner found by number *without* its
source). Same objects, one successor per link, no cycle. Example: request → partner by member number **and** source;
fallback: by member number only (partners that pre-date the source field).

**Activation.** A link runs when (a) its layer is active (`ZCA_OPS_LNKLYR-ACTIVE`, overridden by an L row of
`ZCA_OPS_LNKACT`), (b) its own `ACTIVE` flag is set (overridden by a K row), (c) no link of an active layer replaces it
(`REPLACES`), (d) both objects and their layers are active and (e) it is valid (§4). A customer therefore
- **switches a standard link off**: K row in `ZCA_OPS_LNKACT` with a reason;
- **replaces a standard link**: its own link with `REPLACES` = the standard ID (same objects; the payment model
  generator renders the replacement wherever the standard link is named);
- **adds its own**: objects, fields and links of its layer.

**Evidence.** Field evidence V (VERIFY) names its item; a link that uses a VERIFY field — in a condition or as a key of
its target — is delivered inactive (rule of `verify-before-acting`: no guessed SAP field is ever followed). A field
still unnamed (the SE11 check is open) is a placeholder in angle quotes in the spec: its object / link is **pending**,
never seeded, and appears as pending in the lineage.

## 4. Validation — three places, one rule set

| Rule | On save (`ZUI_CA_OPS_CFG`) | Offline (`tools/link_registry.py --check`) | Run time (`ZCL_CA_OPS_LINK_REGISTRY`, registry check `ZCL_CA_OPS_CHK_LINKS`) |
|---|---|---|---|
| Source is a DDIC table / CDS view entity; a field is a field of it | 082 / 083 | DDL and CDS sources of the repository where available | runtime DDIC of every active object (`LINK_DDIC` finding, 213) |
| Condition reference is TABLE-FIELD of the DDIC | 225 | the field is a declared field of the link's object | 234 (another source), 213 (not declared) |
| Kind / cardinality / quality / sensitivity / evidence / transform values | 413 | yes | 214 / 215 / 217 |
| Kind-dependent fields (EQ needs from; CONST / PREFER need a value; NOTINIT takes none); VERIFY field names its item; activation row names its reason | 235 / 236 | yes | 214 |
| ID prefix of the layer; references only to the own or a lower layer | — | yes | 231 / 226 / 233 |
| Active link on confirmed fields only (conditions and target keys) | — | yes | 218 |
| "To one" (11, N1) covers the target's keys with EQ / CONST or prefers one row; 11 / 1N cover the source's keys | — | yes | 217 (to side) |
| Fallback: target exists, same objects, one successor, no cycle | — | yes | 229 / 230 / 216 |
| Replacement only of a link of a lower layer, same objects | — | yes | 224 / 230 |
| Sensitive field never a constant or preferred value; a key never hidden | — | yes | 223 / 232 |
| Values without quotes or statement characters; texts ≤ 60 | (DDIC lengths) | yes | values quoted by `CL_ABAP_DYN_PRG` in every read |

A problem takes its link (or every link of its object) out of the effective registry — the walker never follows an
invalid row; the registry check reports it as a warning finding (`LINK_REGISTRY`, `LINK_DDIC`) plus one information
finding with the counts (228).

## 5. Walker — `ZIF_CA_OPS_LINK_WALKER` / `ZCL_CA_OPS_LINK_WALKER`

> **First principle:** follow only effective links, one database read per link and level, and never more than the
> limits allow.
> **Analogy:** a librarian answering "what else belongs to this file?" walks the shelves row by row with one list per
> shelf, not one trip per sheet, and stops at the closing bell.

```abap
DATA(lo_walker) = NEW zcl_ca_ops_link_walker( ).
DATA(ls_result) = lo_walker->walk( VALUE #( area      = 'XX_OPS'
                                            object_id = 'CA_DOC_HEADER'
                                            keys      = VALUE #( ( fieldname = 'OPBEL' value = lv_document ) ) ) ).
" ls_result-nodes: node_id, parent_id, depth, object_id, keys (masked), link_id, step, quality, path
" ls_result-truncated / ls_result-problems: limits reached, links skipped
```

1. **Authorisation**: `ZCA_OPS` display (03) of the request's area, else 041 — before anything is read.
2. **Registry**: read once per instance (`ZIF_CA_OPS_LINK_DAO=>READ_REGISTRY`), made effective
   (`ZCL_CA_OPS_LINK_REGISTRY=>EFFECTIVE`): chains of effective links per head; the request may name the heads it
   wants (`links`).
3. **Start**: the start object must be active (210) and every key field must have a value (211). When the links
   leaving it read fields beyond its key, the start row is read once by its key.
4. **Levels** (breadth first, at most `LINK_MAX_DEPTH`, default 4): for every object of the level and every chain
   leaving it, one read of the target per link for all source rows of that object (chunks of `LINK_READ_CHUNK`, default
   100: an IN list for one EQ condition, OR groups for several), at most `LINK_MAX_ROWS` rows (default 100, else 221);
   rows are attributed to their source rows, `PREFER` applied; the next link of a chain is read only for the source rows
   without a match (`step` = position in the chain).
5. **Nodes**: a row reached once (object + key; the first parent wins — the result is a tree); `quality` P as soon as
   one link of the path is probable; `path` = `START -LINK-> OBJECT ...`; keys masked by their field's sensitivity.
   At `LINK_MAX_NODES` (default 500) the walk stops (220); a depth limit with links still to follow is reported (219).
6. **Reads** go through `ZIF_CA_OPS_LINK_DAO=>READ_LINKED`, which trusts no caller-built string: the target must be
   approved for the area (`ZCA_OPS_TABWL`, 212) and displayable (`S_TABU_NAM` 03, 087); every field name is checked
   against the runtime DDIC (213); literals are quoted (`CL_ABAP_DYN_PRG`); numeric fields take numbers only (227); a
   read error skips the link with a problem (222) and the walk goes on. Read only; nothing is stored.

The registry check `ZCL_CA_OPS_CHK_LINKS` (contract `ZIF_CA_OPS_CHECK`) is registered by a consumer in
`ZCA_OPS_CHECK` of its area like any registered check; the generic runner stores its findings.

## 6. Generator outputs

### 6.1 `tools/link_registry.py` (shared engine `tools/abaptools/link_registry.py`)

| Output | Framework (`ops-framework/`) | Consumer |
|---|---|---|
| Seed rows of the six tables (CSV, columns = DDIC fields; pending rows left out) | `config/links/seed/` (S4CORE, CONTRACT) | `config/links/seed/` (its overlay only) |
| Lineage: Mermaid diagram per layer, link table with status, custom field flows | `docs/links/lineage.md` | `docs/links/lineage.md` (all layers) |
| CDS join and association snippet per link | `docs/links/cds_snippets.md` | `docs/links/cds_snippets.md` (its links) |
| Impact: per field the object keys, links (role, status), payment model sections, aggregate checks | `docs/links/impact.md` | `docs/links/impact.md` |

`--check` fails on an invalid registry or an out-of-date output (framework house check `link_registry`; the
consumer runs it in its own check set). Generated files are never edited.

### 6.2 Payment model joins from the registry

A join of a payment model section (`ADDING_A_CUSTOMER_PAYMENT_MODEL.md`) is either CDS text or a registry reference:

```json
"joins": [
  {"link": "CA_ITEM_TO_CLEARING_HDR", "join": "inner join", "alias": "Clr", "from_alias": "Op"}
],
"join_layout": {"source": 18, "alias": 3, "left": 15}
```

The generator loads the product layers and the consumer's overlay (model key `links`), resolves the effective link
(a replacement of an active customer layer wins) and renders `inner join dfkkko as Clr on Clr.opbel = Op.augbl`.
Table names and fields render in lower case, CDS views and elements as declared. `join_layout` (optional, cosmetic)
sets column widths; without it, `and` aligns under `on` and left operands are padded per join. A pending link cannot
be rendered (the generator stops); a join over two source objects at once (e.g. a configuration table keyed by the
country of one object and the method of another) stays CDS text.

## 7. Worked example — customer XX adds a custom field flow

`config/links/examples/xx_overlay.json` (validated with the product layers by `--check`, never seeded):

1. **Its table**: object `XX_PAY_REQUEST` (`ZXX_PAY_REQ`, keys `REQ_ID`, `ATTEMPT`; `MEMBER_ID` masked).
2. **Its custom field on a standard table**: field row `CA_OPEN_ITEM-ZZXX_REQ_ID` of layer XX (the append on
   `DFKKOP`), and `S4_BUSINESS_PARTNER-ZZXX_FEEDER`.
3. **The flow**: `XX_REQ_TO_ITEMS` (`DFKKOP-ZZXX_REQ_ID = ZXX_PAY_REQ-REQ_ID`); back `XX_ITEM_TO_REQ` (N1 with
   `PREFER STATUS = 'OK'`: the accepted attempt); from the items on, the product's links continue the flow without a
   line of the customer: `CA_ITEM_TO_CLEARING_HDR`, `CA_CLEARING_TO_RUN`, `CA_PAYMENT_TO_CHEQUE`, ... to the bank line.
4. **A fallback chain**: `XX_REQ_TO_PARTNER_FDR` (member number + feeder), fallback `XX_REQ_TO_PARTNER` (member number
   only, quality P).
5. **Switch-off**: activation K `CA_PAYMENT_TO_NOC` off (no notification-of-change lots at XX).
6. **Replacement**: `XX_PAYMENT_TO_STMT_LINE` replaces `CA_PAYMENT_TO_STMT_LINE` (the customer's bank drops leading
   zeros: transform `NOZERO`) — the payment model renders `... on Ln.chect = ltrim( Op.augbl, '0' )` wherever the
   standard link is named.
7. `python3 tools/link_registry.py --check` in the customer's folder; load its seed rows in DV1 (`ZUI_CA_OPS_CFG`,
   customizing request); approve the sources the walker reads for its area in `ZCA_OPS_TABWL`; register
   `ZCL_CA_OPS_CHK_LINKS` in its area; walk from `XX_PAY_REQUEST` with the request number.

## 8. What the product layers hold (2026-11-11)

| Layer | Objects | Fields | Links | Active | Inactive (VERIFY) |
|---|---|---|---|---|---|
| S4CORE | 6 | 32 | 7 | 2 (bank statement line <-> header) | 5 (released view elements V110, bank statement header fields V117) |
| CONTRACT | 8 | 30 | 20 | 16 | 4 (V110 / V117) |

Every link, its conditions and status: `docs/links/lineage.md`. Join facts are confirmed in a reference landscape
(S/4HANA 2023) unless the link is quality P; field names still to be confirmed in SE11 are evidence V (V117), the
element names of the released views V110.

## 9. Installation and operation

1. After the pull: the configuration app `ZUI_CA_OPS_CFG` comes regenerated with the six link registry entities.
2. DV1, customizing request: create the rows of `config/links/seed/*.csv` (product layers) and the consumer's own seed
   rows in the app (in the order layers, objects, fields, links, conditions, activations); no row is created in a
   production client.
3. Approve the sources the walker reads for the consumer's area in `ZCA_OPS_TABWL` (security sign-off per table).
4. Roles (`docs/auth_zca_ops.md` §2): maintenance `ZCA_OPS` area `CA_OPS` 01 / 02 / 06 (DV1 only); the walker's users
   `ZCA_OPS` 03 of their area plus `S_TABU_NAM` 03 of the approved tables.
5. Register `ZCL_CA_OPS_CHK_LINKS` in `ZCA_OPS_CHECK` of the consumer's area (optional; its findings show invalid rows).
6. Parameters `LINK_MAX_DEPTH`, `LINK_MAX_ROWS`, `LINK_MAX_NODES`, `LINK_READ_CHUNK` (`docs/PARAMETERS.md`).

## 10. What the offline checks cannot prove

V116-V120 (`docs/VERIFY.md`): activation of the tables and the app (checks on save on CDS view entities), the field
names marked V in the product layers, the walker's reads on approved tables and CDS view entities, the ABAP Unit
tests, the registry check and the authorisation.

## Glossary

| Term | Business meaning |
|---|---|
| Business object | a kind of record the business talks about (a payment, a request, a bank line) and the table or view that holds it |
| Link | "this record leads to that record": the fields that must be equal, with how sure we are (C confirmed, P probable) |
| Layer | who owns a definition: the product (standard), an industry package (standard), the customer |
| Custom field flow | the path a customer's own field takes from its table into standard tables and onwards |
| Fallback | the second way to find a record, used only when the first finds nothing |
| Pending | a link waiting for a field name to be confirmed in the system; never used until then |
