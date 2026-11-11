// Artifact: zc_ca_opsjobbo.ddls.asddls
// Purpose: Business objects a consumer's enricher linked to a kept job (ZCA_OPS_JOBBO: object type and key, label,
//          company code, count, evidence quality) for the object page of the SAP job failures board (service
//          ZUI_CA_OPS_JOBS), with the area and company code of the job for the read authorisation (DCL
//          ZC_CA_OPSJOBFAILURE). Read-only.
// Modification log: 2026-11-11 | Initial version (SAP job monitor).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'SAP job failures: business objects'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZC_CA_OpsJobBo
  as select from zca_ops_jobbo as Bo
    inner join   zca_ops_job   as Job on  Job.jobname  = Bo.jobname
                                      and Job.jobcount = Bo.jobcount
{
  key Bo.jobname     as JobName,
  key Bo.jobcount    as JobCount,
  key Bo.object_no   as ObjectNo,
      Bo.enricher    as Enricher,
      Bo.object_type as ObjectType,
      Bo.object_key  as ObjectKey,
      Bo.label       as Label,
      Bo.bukrs       as ObjectCompanyCode,
      Bo.item_count  as ItemCount,
      Bo.quality     as Quality,
      Job.area       as Area,
      Job.bukrs      as CompanyCode
}
