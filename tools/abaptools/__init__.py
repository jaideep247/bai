"""Shared tooling of the ABAP components of this repository (offline, no SAP system needed).

One implementation per tool; each component folder (param-framework/, ops-framework/, ops-suite/)
keeps a thin wrapper of the same name under its tools/ folder that holds the folder's settings
(profile) and calls the engine here, so `python3 tools/<name>.py [--check]` run from the folder
works unchanged.

  abapgit_serialize   abapGit XML from the DDL sources, the dictionary, the message class source,
                      the authorisation objects, the text elements and the ABAP / RAP sources
  param_definitions   seed class of the delivered ZCA_PARAM areas / definitions and the
                      completeness check of the parameter names the code reads
  rap_generate        RAP configuration apps (draft tables, CDS, BDEF, service, behaviour pool)
  modernize           idempotent mechanical modernisation (table renames, exception names,
                      local test helper names, abaplint quick fixes)
  literal_scan        inventory and classification of the literals of production ABAP
  class_purpose       object table of a class purpose document from the artefact headers
  checks              house checks shared by the component check runners (per-folder lists)
  onboarding          offline completeness of the registered business processes of a component
                      (process onboarding of ZCA_OPS: checks, control, alert rule, owner, purge, role)
  new_process         scaffold of a new business process: configuration rows (seed files), process
                      document, check class skeleton with its test class
  payment_model       a consumer's payment model from the product templates of the operations framework
                      (ops-framework/templates/payment_model) and the consumer's mapping spec: adapter views,
                      cube, trend, payment / request object pages, DCL, service, CDS test holder (--check)
  link_registry       the layered link registry (product baseline, industry package, customer overlay): validation,
                      seed rows of the registry tables, lineage, CDS snippets, field impact; the payment model
                      renders its joins from it (--check)
  process_catalogue   the layered process catalogue (product baseline, industry packages, customer layer with its
                      activation): validation, seed rows of the catalogue tables, monitoring rows of the standard
                      processes (inactive), catalogue document and activation proposal (--check)

Wrappers find this package two levels above their own file (<repository>/tools). A component
shipped on its own takes this folder along (tooling only - nothing of it is imported into SAP).

Modification log:
2026-11-10 | Initial version (shared tools: one serializer, generator and check set for the
           | parameter framework, the operations framework and its consumers).
2026-11-10 | onboarding, new_process (process onboarding framework).
2026-11-11 | link_registry (link registry of the operations framework).
2026-11-11 | process_catalogue (process catalogue of the operations framework).
"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def fresh(name, profile):
    """A private instance of the engine module `name` for one profile.

    Engines with module-level settings (configure( )) are loaded once per profile, so two
    profiles in one process (e.g. a framework and its consumer) never share settings."""
    spec = importlib.util.spec_from_file_location(f'abaptools_{name}_{profile}', os.path.join(HERE, name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
