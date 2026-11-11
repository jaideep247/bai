*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_purge_dao.intf.abap
*& Purpose:
*& SQL of the retention purge for the framework's own targets (RUN: runs
*& with their findings and exception history; ALERT_LOG: alert log) and the
*& registry of the consumers' targets (ZCA_OPS_PURGE). Runs are never
*& purgeable while they hold an open, assigned or validly waived exception.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-10 | RUN purges the exception history of its findings (EV_HISTORY).
*& 2026-11-10 | Moved from ZIF_CD_OPS_PURGE_DAO to the reusable framework ZCA_OPS: the framework's targets
*&            | RUN and ALERT_LOG (ZIF_CA_OPS_PURGE_TARGET) and the registry of consumer targets
*&            | (GET_TARGETS, table ZCA_OPS_PURGE); the consumer targets left with their owner.
*& 2026-11-10 | Target REVIEW: sign-offs of the daily control review (ZCA_OPS_REVIEW) by sign-off time.
*& 2026-11-11 | Target DOWNTIME (planned downtime windows, operations response features).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - retention purge repository</p>
INTERFACE zif_ca_ops_purge_dao
  PUBLIC.

  INTERFACES zif_ca_ops_purge_target.
  ALIASES count_purgeable FOR zif_ca_ops_purge_target~count_purgeable.
  ALIASES delete_package FOR zif_ca_ops_purge_target~delete_package.

  CONSTANTS:
    BEGIN OF gc_target,
      "! ZCA_OPS_RUN with its ZCA_OPS_FINDING and ZCA_OPS_EXC_HIST rows
      run       TYPE zif_ca_ops_purge_target=>ty_target VALUE 'RUN',
      "! ZCA_OPS_ALLOG by send time
      alert_log TYPE zif_ca_ops_purge_target=>ty_target VALUE 'ALERT_LOG',
      "! ZCA_OPS_REVIEW by sign-off time (daily control review)
      review    TYPE zif_ca_ops_purge_target=>ty_target VALUE 'REVIEW',
      "! ZCA_OPS_DTWIN by the end of the window (planned downtime, 2026-11-11; DOWNTIME_RETENTION_DAYS)
      downtime  TYPE zif_ca_ops_purge_target=>ty_target VALUE 'DOWNTIME',
    END OF gc_target.

  "! A consumer's purge target (ZCA_OPS_PURGE)
  TYPES:
    BEGIN OF ty_registry,
      target     TYPE zif_ca_ops_purge_target=>ty_target,
      class_name TYPE zif_ca_ops_types=>ty_class_name,
      param_area TYPE zif_ca_ops_types=>ty_area,
      param_name TYPE zif_ca_ops_types=>ty_param_name,
    END OF ty_registry.
  TYPES tt_registry TYPE STANDARD TABLE OF ty_registry WITH EMPTY KEY.

  "! Active consumer targets of ZCA_OPS_PURGE, by target
  METHODS get_targets
    RETURNING
      VALUE(rt_targets) TYPE tt_registry.

ENDINTERFACE.
