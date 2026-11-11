// Artifact: zi_ca_opscatmon.ddls.asddls
// Purpose: Monitoring of a catalogue process (2026-11-11): the checks in effect today (ZI_CA_OpsChkEff) of the
//          business processes of ZCA_OPS_PROC that name it (CAT_PROCESS), counted - the catalogue list shows an
//          active process without monitoring. Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Catalogue: checks monitoring a process'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCatMon
  as select from zca_ops_proc    as Proc
    inner join   ZI_CA_OpsChkEff as Ce on  Ce.Area      = Proc.area
                                       and Ce.ProcessId = Proc.process_id
{
  key Proc.cat_process                                      as ProcessId,
      cast( count( * ) as abap.int4 )                       as MonitoringChecks
}
where
  Proc.cat_process <> ' '
group by
  Proc.cat_process
