* Lint stub only (not pulled by abapGit, not an SAP object): the bgPF interface is missing
* in abaplint/deps. VERIFY-ADT: the real IF_BGMC_OP_SINGLE_TX_UNCONTR (SAP_BASIS 7.58) is
* serializable and its EXECUTE may raise CX_BGMC_OPERATION.
INTERFACE if_bgmc_op_single_tx_uncontr PUBLIC.
  METHODS execute.
ENDINTERFACE.
