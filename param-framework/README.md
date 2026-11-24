# ZCA_PARAM - cross-application parameter framework

A generic parameter framework for every SAP team (production support and
implementation) on S/4HANA 2023, SAP_BASIS 7.58, classic ABAP. Teams register an
**area**, define **parameters** in it by transport and read them with one typed API.
A value may differ by business context (source, transaction type, company code, ...):
the most specific maintained context wins, so adding a source or an exception is a
customizing change, not a code change.

The source lives in the repository `jaideep247/bai`, folder `param-framework/`
(this folder is the framework root: every path below is relative to it).

## Why

An older TVARVC-style framework failed a principal-architect review: one parameter
had two identities, reads were not deterministic, conversion errors dumped or fell
back silently to defaults, nothing was audited, the area master was not enforced,
every consumer re-implemented typed and range reads, values were untyped, the buffer
could not be refreshed, names from parameters went unchecked into dynamic SQL, the
test double duplicated the production logic, the documentation did not match the code
and maintenance had no authorization model - and a blank value could not switch a
flag off. This framework makes each of these impossible; `docs/DESIGN.md` section 11
maps every finding to the mechanism that prevents it.

## What you get

| Piece | Objects |
|---|---|
| Tables (customizing, table logging, foreign keys) | `ZCA_PARAM_AREA`, `ZCA_PARAM_DEF` (with context dimensions), `ZCA_PARAM_VAL` (rows per context) |
| Read API | `ZIF_CA_PARAM` from `ZCL_CA_PARAM_FACTORY=>GET( )` (typed getters with optional context, `GET_EFFECTIVE_CONTEXT`, `CHECK_AREA`); exception `ZCX_CA_PARAM` (messages `ZCA_PARAM`); release `ZIF_CA_PARAM_TYPES=>GC_VERSION` (2.0.0) |
| Tests for consumers | `ZCL_CA_PARAM_BUILDER` (incl. `CONTEXT`), `ZCL_CA_PARAM_DAO_MEM`, `ZCL_CA_PARAM_INJECTOR` |
| Maintenance | SM30 / SM34 view cluster `ZCA_PARAM_VC` / SPRO, save checks in `sm30/lzca_param_maintf01.abap` (built in the system, `docs/OPERATIONS.md` section 1) |
| Authorization | `S_TABU_DIS` / `S_TABU_NAM` for the maintenance; object `ZCA_PARAM` (field `ZCA_PARAR` = area) kept for consumers and an optional check per area |

## Consumers

The operations framework ZCA_OPS (its own component, shipped next to this one) is installed after this
framework and needs release 1.1.0 or later: its areas are parameter areas of `ZCA_PARAM_AREA` (one area
register) and its authorisation object `ZCA_OPS` uses the object class `ZCA` and the field `ZCA_PARAR`
defined here. Install order **ZCA_PARAM -> ZCA_OPS -> consumer**. This component needs neither: it
depends on SAP standard only (check `packaging` of `tools/checks.py`).

## Install with abapGit

Package `ZCA_PARAM`, folder logic PREFIX, starting folder `/src/` (see `.abapgit.xml`).

- **Offline ZIP** (today): in a clone of `jaideep247/bai` run
  `git archive HEAD:param-framework --format=zip -o zca_param.zip`, then in abapGit
  *New Offline* -> package `ZCA_PARAM` -> *Import ZIP* -> *Pull*.
- **Online** (later): link a dedicated repository that contains this folder at its
  root (for example a split of `param-framework/` with `git subtree split`).

After the first pull: set up the SM30 / SPRO maintenance (`docs/OPERATIONS.md` section 1),
run ABAP Unit and ATC, and work through `docs/VERIFY.md`. Upgrading from 1.x: the pull
converts the tables (SE14, data kept - existing rows become general rows) and removes the
RAP app objects of `ZCA_PARAM_UI`; delete that package afterwards.

## Quick start

```abap
TRY.
    DATA(lo_param) = zcl_ca_param_factory=>get( ).
    DATA(lv_max)   = lo_param->get_int( iv_area = 'ZPE_OPS' iv_name = 'MAX_ITEMS' ).
    DATA(lv_on)    = lo_param->get_bool( iv_area = 'ZPE_OPS' iv_name = 'SEND_MAIL' ).
    DATA(lt_bukrs) = lo_param->get_range( iv_area = 'ZPE_OPS' iv_name = 'COMPANY_CODES' ).
  CATCH zcx_ca_param INTO DATA(lx_error).
    " configuration error: report it (lx_error->get_text( )), never guess a value
ENDTRY.
```

Per context (the definition declares `DIM1 = SOURCE`; the general row holds `E`, a row with
`CTX1 = SRC_A` holds `S`):

```abap
DATA(lv_level) = lo_param->get_value(
  iv_area    = 'ZPE_OPS'
  iv_name    = 'LOG_LEVEL'
  it_context = VALUE #( ( dim = 'SOURCE' value = lv_source ) ) ).   " SRC_A -> S, others -> E
```

In unit tests, run the real logic over in-memory data:

```abap
DATA(lo_param) = NEW zcl_ca_param_builder( )->area( 'ZPE_OPS'
  )->param( iv_name = 'MAX_ITEMS' iv_value_type = 'INT' iv_default = '10' )->row( '25' )->build( ).

DATA(lo_ctx_param) = NEW zcl_ca_param_builder( )->area( 'ZPE_OPS'
  )->param( iv_name = 'LOG_LEVEL' iv_dim1 = 'SOURCE' )->row( 'E'
  )->context( iv_ctx1 = 'SRC_A' )->row( 'S' )->build( ).
```

## Documentation

| Document | Content |
|---|---|
| `docs/DESIGN.md` | model, semantics table, context and access sequence (3a), validation, buffering, errors, authorization, transport rules, review findings, what belongs in a parameter (13) |
| `docs/ONBOARDING.md` | for a team: register an area, define parameters, maintain values, read, test |
| `docs/OPERATIONS.md` | maintenance, audit (table logging / SCU3), authorizations, troubleshooting by message |
| `docs/VERIFY.md` | what offline checks cannot prove (VERIFY-ADT / VERIFY-SE11) |
| `CHANGELOG.md` | changes |

## Repository layout and quality gates

| Path | Purpose |
|---|---|
| `src/` | abapGit objects (package `ZCA_PARAM`) |
| `sm30/` | event include of the generated SM30 function group (not an abapGit object) |
| `ddic/` | table DDL sources and `dictionary.json` (domains, data elements) |
| `config/` | repository settings, message class texts, authorization objects, `customer_terms.txt` |
| `tools/abapgit_serialize.py` | writes all abapGit XML from `ddic/`, `config/` and the sources |
| `tools/checks.py` | house checks (name lengths, headers, PCRE only, no inline texts, customer wording, packaging, ...) |

The files in `tools/` are thin wrappers of the repository's shared tools (`../tools/abaptools`, tests in
`../tools/tests`); copy that folder along when the component is shipped on its own.
| `ci/abaplint.yml` | CI workflow (to be wired into `.github/workflows` of `jaideep247/bai`) |

Run locally from this folder:

```sh
npx @abaplint/cli@2.120.92 abaplint.json    # syntax and house rules (v758)
python3 tools/abapgit_serialize.py --check  # abapGit metadata up to date
python3 tools/checks.py                     # house checks
python3 -m unittest discover -s tools/tests # tool tests
```

A clean lint proves syntax and typing against the SAP stubs of `abaplint/deps` only -
not activation, DDIC existence or ABAP Unit results (`docs/VERIFY.md`).
