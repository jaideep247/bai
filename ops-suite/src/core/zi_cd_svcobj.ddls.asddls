// Artifact: zi_cd_svcobj.ddls.asddls
// Purpose: Service health - one problem per service, business date, company code, area, check code and object key:
//          a problem raised again by several runs of the date (superseded + open) or caught by two rules of the
//          service counts ONCE, with its highest points. Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service health - problems per service'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_SvcObj
  as select from ZI_CD_SvcFind
{
  key Service,
  key BusinessDate,
  key CompanyCode,
  key Area,
  key CheckCode,
  key ObjectKey,
      max( Points )                                         as Points
}
group by
  Service,
  BusinessDate,
  CompanyCode,
  Area,
  CheckCode,
  ObjectKey
