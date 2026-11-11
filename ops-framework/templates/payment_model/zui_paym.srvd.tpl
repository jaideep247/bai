@EndUserText.label: 'Payment model - persona overview pages'
@ObjectModel.leadingEntity.name: 'ZC_{{P}}_PAYMCUBE'
// Artifact: {{SERVICE_LOWER}}.srvd.srvdsrv (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: One OData V4 service (binding {{SERVICE}}_O4) for the three persona overview pages of the payment
//          model (business users, managers, IT support - one app descriptor each, docs of the consumer) and the
//          drill-down to the individual payment, its requests and the feeder timeline. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
define service {{SERVICE}} {
#for EXPOSE
  expose {{ENTITY}} as {{ALIAS}};
#endfor
}
