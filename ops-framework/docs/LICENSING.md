# Licensing of ZCA_OPS - which modules a customer may run

> **First principle:** the customer decides what runs (activation of processes, checks, flows, accounts); the vendor
> decides what may be activated (the licence). The licence is a file the vendor signs; the product reads only what the
> vendor's signature covers, and it never refuses the core that keeps a customer's existing exceptions workable.
> **Analogy:** a hotel key card. Reception (the vendor) writes on the card which floors it opens and until when; the
> guest (the customer) decides which rooms to use and when, but cannot write a floor onto the card. When the stay ends
> the card stops opening the gym and the spa - the lobby (CORE) stays open, and what the guest left in the room
> (stored results) can still be collected.

## 1. What it is

Until this release activation was the customer's alone: the process catalogue activation (`ZCA_OPS_CATACT`), the
`ACTIVE` flags of business processes, registered checks, flows, break accounts, controls, and the areas. The licence is
a **second layer above it**:

| Layer | Who decides | Where | Can the customer change it? |
|---|---|---|---|
| Licence | the vendor | a signed file installed with `ZCA_OPS_LICENSE_INSTALL`, verified at every run | no - a changed file fails the signature check |
| Module map | the vendor | generated class `ZCL_CA_OPS_LIC_MAP` from `config/licensing/modules.json` | only by a modification (version history) |
| Activation | the customer | `ZUI_CA_OPS_CFG` (rows with `ACTIVE`), catalogue activation | yes, within the licence |

The **modules** and their entry points are listed in `docs/licensing/modules.md` (generated). In short:

| Module | What it licenses |
|---|---|
| `CORE` (always, never refused) | runs, findings, exceptions app, alert router and channels, run lock / abort, configuration apps, check runner and registry, business process register, parameters, purge, process catalogue model with the baseline `S4CORE`, explainable results, the **customer extension contract** (decision D-L2), the licence itself |
| `CONTROL` | control register and the daily control review (sign-off) |
| `ONBOARD` | no-code aggregate checks, approved tables, onboarding check, outage risk check, process scaffold |
| `JOBS` | SAP job monitor (job checks, scheduler jobs, failures board) |
| `RESPONSE` | runbook links, alert correlation, escalation until acknowledged, downtime windows, metrics, shift handover |
| `LINKS` | a customer's own layer of the link registry, the registry check (the product layers stay content of the other modules) |
| `CATALOGUE_FICA` / `CATALOGUE_FSCD` / `CATALOGUE_FSRI` | the catalogue packages FICA and FSCD and the FS-RI process of FSCD (`license_module` in `config/catalogue`) |
| `PAYMODEL` | the payment model generator (enforced by contract, section 6) |
| `BREAKS` | clearing-account break analysis and the pilot pack |
| `FLOW` | account flow reconciliation |

A catalogue package names its module in its own spec (`license_module`); a process may name its own (`FSCD_FSRI`).
A registered check **inherits** the module of its business process's catalogue process and needs the module of its
class (job checks need `JOBS`, an aggregate check `ONBOARD`, the break check `BREAKS`, the registry check `LINKS`). A
customer's own business process without catalogue process and its own check classes need no module beyond `CORE`.
`modules.json` also names what a module requires (`CATALOGUE_FSCD` requires `CATALOGUE_FICA` and `ONBOARD`); the
vendor's tool refuses a licence that misses a requirement unless forced. Areas are not licensed (D-L3): an area is the
customer's grouping, the modules are what runs in it.

## 2. How it works

```
 vendor                                       customer system (DV1 / QA1 / PS4)
 ------                                       ---------------------------------
 payload.json  --openssl cms -sign-->  licence.pem  --ZCA_OPS_LICENSE_INSTALL-->  ZCA_OPS_LIC (active + history)
 (customer, installations, systems,          |                                         |
  versions, modules + dates, grace)          |                      every run: ZCL_CA_OPS_LICENSE
                                             |                        1 read the active file (ZIF_CA_OPS_LIC_DAO)
 vendor key (never in the repository)        |                        2 SSF_KRN_VERIFY with the PSE LIC_SSF_PROFILE
 vendor certificate --> STRUST of each system                         3 signer = vendor (subject, fingerprint)
                                                                      4 payload (asJSON) -> ZCL_CA_OPS_LIC_POLICY
                                                                      5 installation number, SID, client, version
                                                                      6 state per module today
```

1. **Licence file.** JSON payload `{"LICENSE": {FORMAT, LICENSE_ID, PRODUCT, CUSTOMER, INSTALLATIONS[], SYSTEMS[{SID,
   CLIENT}], VERSION_FROM, VERSION_TO, MODULES[{CODE, VALID_FROM, VALID_TO}], GRACE_DAYS, ISSUED_AT}}` - exactly the
   asJSON form of `ZIF_CA_OPS_LIC_TYPES=>TY_PAYLOAD`, so the runtime reads it with the identity transformation - signed
   as PKCS#7 / CMS signed data with the content **enveloped** (one blob: SSF returns the content it verified; nothing
   can be swapped beside the signature), PEM armoured (`-----BEGIN CMS-----`).
2. **Verification** (`ZCL_CA_OPS_LICENSE`, once per instance - the factory gives one instance per run): the stored file
   is verified again at every run, never trusted as stored. The SSF call is isolated in the adapter
   `ZCL_CA_OPS_LIC_PLATFORM` (`ZIF_CA_OPS_LIC_PLATFORM`), the decision in the pure class `ZCL_CA_OPS_LIC_POLICY`
   (no database, no SSF; tests for every state) and its Python twin `tools/abaptools/licensing.py` (the vendor's tools).
3. **Trust anchor.** SSF accepts a signature whose certificate is in the PSE; the product additionally requires the
   signer's subject `ZIF_CA_OPS_LIC_TYPES=>GC_VENDOR-SUBJECT` (and, once the vendor sets `CERT_SHA256`, its SHA-256
   fingerprint when SSF returns the certificate - V162). A certificate a customer creates itself with the same subject
   passes SSF but not the fingerprint - set `CERT_SHA256` in the release build (decision D-L4).
4. **Binding.** One of the system's installation numbers (`SLIC_GET_LICENCE_NUMBER`, V163) in `INSTALLATIONS`, the
   system ID in `SYSTEMS` and, when the row names a client, that client; the framework's release
   (`ZIF_CA_OPS_TYPES=>GC_VERSION`) between `VERSION_FROM` and `VERSION_TO` (`VERSION_TO` = `1` covers every 1.x.y).
5. **States.** Licence: `VALID`, `MISSING` (none installed), `SIGNATURE` (invalid, not the vendor's, not readable),
   `BINDING`, `VERSION`. Module today: `INCLUDED` (CORE), `LICENSED`, `EXPIRING` (fewer days left than
   `LIC_WARN_DAYS`), `GRACE` (ended, at most `GRACE_DAYS` of the licence ago), `EXPIRED`, `UNLICENSED` (not granted,
   not yet valid, or the licence not `VALID`).
6. **Enforcement** `LIC_ENFORCE`: **`W` (default of this release) - warn only**: every module runs, the states are
   reported; **`X` - refuse**: a module that is neither included, licensed, expiring nor in grace is refused. CORE is
   never refused. Switch to `X` per system only after the licence is installed and the dashboard shows the expected
   modules (INSTALL 6h).

## 3. What is refused (LIC_ENFORCE = X) and what is reported

| Entry point | Object | Under X | Under W |
|---|---|---|---|
| Registered check of a module (runner `ZCA_OPS_CHECK_RUN`) | `ZCL_CA_OPS_CHECK_RUNNER` | not run: finding `LICENSE_REFUSED` (351, error, notify) in the run; its open exceptions stay open (not reconciled) | runs; one warning `LICENSE_UNLICENSED` (353) per run naming the modules an installed licence does not cover |
| Break analysis `ZCA_OPS_BRK_RUN`, pilot export `ZCA_OPS_PILOT_EXPORT` | `ZCL_CA_OPS_BRK_ANALYZER`, the report | refused: message 352 (job cancelled) and a recorded refused run of the area (variant `BREAKS`, aborted, red, finding `LICENSE_REFUSED`, alerted - `ZCL_CA_OPS_RUN_GUARD=>REFUSE_LICENSE`) | runs |
| Account flow evaluation `ZCA_OPS_FLOW_RUN` | `ZCL_CA_OPS_FLOW_EVAL` | as above (variant `FLOW`) | runs |
| Escalation `ZCA_OPS_ESCALATE` | the report | as above (variant `RESPONSE`) | runs |
| Sign-off of the daily control review | `ZBP_R_CA_OPSCTLREVIEW` (action *Mark reviewed*) | refused with 352 | allowed |
| Activation in `ZUI_CA_OPS_CFG` (save with `ACTIVE` = X) | generated validations, `ZCL_CA_OPS_CFG_CHECKS=>MODULE_LICENSED` / `CAT_PROCESS_LICENSED` / `CLASS_LICENSED` / `PACKAGE_LICENSED` | refused (350) for controls, aggregate rows, approved tables, scheduler jobs, runbook links, correlation rules, customer link layers, break accounts, flows; business processes by their catalogue process, registered checks by their class, catalogue activations by their process, packages by their module | saved |
| Deactivation, any read app, the exceptions app, dashboards, the licence dashboard | - | **never refused** | - |

**Licence check** `ZCL_CA_OPS_CHK_LICENSE` (module CORE; registry row `CA_OPS / LICENSE`, schedule group `MORNING`,
delivered active - it only reports): owned exceptions with an SLA (alerted by the existing alert router, resolved by
themselves once the licence is installed or renewed): `LICENSE_MISSING` (354), `LICENSE_INVALID` (358-360),
`LICENSE_EXPIRING` from `LIC_WARN_DAYS` days before a module ends (355), `LICENSE_GRACE` during the grace period (356),
`LICENSE_EXPIRED` (357); severity W, E for what is refused under X. A recommended alert rule (inactive, destination a
placeholder) is `config/licensing/alert_rules_license.csv` (area `*`, check pattern `LICENSE_.*`, throttle one day).

**Stored data stays readable.** A licence that ends never deletes, hides or locks anything: runs, findings, exceptions,
snapshots, evaluations and reviews stay in their tables and every read app keeps showing them; exceptions can still
be assigned, resolved and waived (CORE). Only new runs and new activations of the module stop (under X).

**Dashboard** `ZUI_CA_OPS_LIC` (binding `ZUI_CA_OPS_LIC_O4`): `ZC_CA_OpsLicModule` - one row per module of this release
with valid to, grace until, days left, state and criticality (overview list card) - and `ZC_CA_OpsLicense` - the active
licence and its history; DCLs on `ZCA_OPS` 03 for area `CA_OPS`. The dashboard computes the states with the same rules
in CDS from the display copies `ZCA_OPS_LICM` / `ZCA_OPS_LICMOD`; what runs is always decided from the verified file.

## 4. The vendor's process to issue a licence

1. Once: create the vendor's key pair and certificate **outside the repository** (vendor key store / HSM), subject
   `CN=ZCA_OPS LICENSING` (the product constant), e.g. for a test key
   `openssl req -x509 -newkey rsa:3072 -sha256 -days 3650 -nodes -subj "/CN=ZCA_OPS LICENSING" -keyout vendor.key -out vendor.crt`.
   Record the SHA-256 fingerprint (`verify_license.py` prints it as `signer_sha256`) and set
   `ZIF_CA_OPS_LIC_TYPES=>GC_VENDOR-CERT_SHA256` in the release build (D-L4). Give customers the certificate (public).
2. Per customer and contract: collect the installation number(s) and the SIDs (and clients, if the contract binds a
   client) of DV1 / QA1 / PS4 and the release range; choose the modules and their dates.
3. Issue: `python3 tools/licensing/issue_license.py --key <vendor.key> --cert <vendor.crt> --license-id <ID>
   --customer "<name>" --installation <number> --system DV1 --system QA1 --system PS4/100 --version-from 1.0
   --version-to 1 --module JOBS:20261115:20271114 --module BREAKS:20261115:20271114 --grace-days 30
   --out <customer>.pem --payload-out <customer>.json` (or `--payload <file>.json`). The tool validates the payload
   against `modules.json`, refuses a key inside the repository and a module whose requirement is missing (`--force`).
4. Check: `python3 tools/licensing/verify_license.py --cert <vendor.crt> --licence <customer>.pem --installation
   <number> --sid PS4 --client 100` - signature, signer, payload and the state of every module as the system will see
   it. Keep the payload in the vendor's register; send the `.pem` file.
5. Renewal = a new file with a new licence ID; the customer installs it, the previous one becomes history.

## 5. The customer's installation (per system: DV1, QA1, PS4)

1. **Basis - SSF application and PSE (VERIFY V166).** Define an SSF application for the licence (transaction SSFA /
   view `SSFAPPLIC`, e.g. `ZCAOPS`, profile name of the PSE as `LIC_SSF_PROFILE`, default `SAPZCAOPS.pse`), create its
   PSE in STRUST (node *SSF ZCAOPS*), import the vendor's certificate into the PSE's **certificate list** and save.
   No private key of the vendor is ever needed on the system.
2. **Parameters** (area `CA_OPS`): `LIC_SSF_PROFILE` (the PSE), `LIC_WARN_DAYS` (default 30), `LIC_ENFORCE` stays `W`;
   for files on the application server `LIC_FILE_PATH` / `LIC_FILE_NAME` (transaction FILE).
3. **Install** with `ZCA_OPS_LICENSE_INSTALL`: first in test mode (03 for `CA_OPS`) - the list shows the licence state
   and every module; then without test mode (01 for `CA_OPS`): a `VALID` licence is stored and committed, anything else
   is refused (364). The licence is stored per system (not transported).
4. **Check** the dashboard `ZUI_CA_OPS_LIC` and the morning run of `CA_OPS` (exception `LICENSE_MISSING` resolved).
5. **Switch** `LIC_ENFORCE` to `X` only when the contract and the go-live plan say so; until then nothing stops working.

## 6. Honest limit - what the signature does and does not protect

The product is delivered as source. Anyone with developer rights in the customer's system can change the gate, the
module map or the trust anchor, exactly as they could change any other delivered code. Enforcement therefore rests on
three things together: **the signature** (a licence file cannot be forged or edited without the vendor's private key;
an edited file is refused), **the contract** (the licence terms the customer signed) and **the audit trail** (a changed
gate, map or anchor is a modification of the vendor's objects - visible in the version history, in the transport
requests and in the SE95 / modification browser; the offline house check `licensing` fails on a gate that no longer
names its module). `PAYMODEL` has no runtime gate at all: its output is generated into the customer's package, so it is
contractual only (D-L1). The licence never touches business data: it reads only its own tables, the catalogue rows
and the system's identity, and writes only `ZCA_OPS_LIC` / `_LICM` / `_LICMOD` and the store's run of a refusal.

## 7. Decisions

| ID | Decision | Proposal |
|---|---|---|
| D-L1 | `PAYMODEL` enforced by contract only (generated into the customer's package, no runtime entry point) | accepted for this release; a runtime gate would need a product CDS gate view the generated model reads |
| D-L2 | Customer extensions (`EXTENSIONS`) part of `CORE`, not a module | refusing them would break the customer's own objects that sit on the product views |
| D-L3 | Areas are not licensed | an area is the customer's grouping; modules decide what runs in it |
| D-L4 | Fingerprint of the vendor's certificate in the product constant `GC_VENDOR-CERT_SHA256` | set it in the release build once the vendor's certificate exists (blank = subject check only) |
| D-L5 | Licence installation = `ZCA_OPS` 01 (check 03) for area `CA_OPS`, no new activity, **no new role: the existing configuration role `Z_CA_OPS_CONFIG` (decided 2026-11-15)** | the role is assigned in each system where the licence is installed (DV1, QA1, PS4); outside DV1 its other activities create or change no configuration (the apps refuse it) |
| D-L6 | `LIC_ENFORCE` delivered `W` | switch to `X` per system after the installation (INSTALL 6h) |
| D-L7 | A running module that ends keeps its stored data readable and its exceptions workable | not negotiable: no licence state hides data |
| D-L8 | Planned downtime windows app, metrics and handover (`RESPONSE`) are not gated (read apps / planning); escalation, runbook links and correlation rules are | revisit if the downtime app should be refused under X |

## 8. Objects

`ZIF_CA_OPS_LIC_TYPES`, `ZIF_CA_OPS_LICENSE` / `ZCL_CA_OPS_LICENSE` (factory `GET_LICENSE`, injector
`INJECT_LICENSE`), `ZCL_CA_OPS_LIC_POLICY`, `ZCL_CA_OPS_LIC_FILE`, `ZIF_CA_OPS_LIC_PLATFORM` /
`ZCL_CA_OPS_LIC_PLATFORM`, `ZIF_CA_OPS_LIC_DAO` / `ZCL_CA_OPS_LIC_DAO`, `ZCL_CA_OPS_LIC_MAP` (generated),
`ZCL_CA_OPS_CHK_LICENSE`, `ZCL_CA_OPS_RUN_GUARD=>REFUSE_LICENSE`; tables `ZCA_OPS_LIC`, `ZCA_OPS_LICM`,
`ZCA_OPS_LICMOD`; report `ZCA_OPS_LICENSE_INSTALL`; CDS `ZI_CA_OpsLicCfg`, `ZC_CA_OpsLicModule`, `ZC_CA_OpsLicense`,
DCLs, service `ZUI_CA_OPS_LIC`; messages 350-366; parameters `LIC_*`; offline `config/licensing/modules.json`,
`tools/licensing.py` (house check `licensing`), `../tools/abaptools/licensing.py`, vendor tools
`../tools/licensing/issue_license.py` / `verify_license.py`, tests `../tools/tests/test_licensing.py`. VERIFY V162-V168.
