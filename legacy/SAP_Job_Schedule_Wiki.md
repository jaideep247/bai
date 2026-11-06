
# 🧾 SAP Job Schedule – Collections, Disbursements & Reconciliation

_Last updated: October 2025_  
**Owner:** SAP IT & Control-M Team  
**Purpose:** To document all SAP background jobs related to payment cycles, file integrations, and reconciliation processes for Insurance business operations.  

---

## 📘 1. Overview

This Wiki provides a consolidated view of:
- **Collections Jobs** – inbound files, chargebacks, BAI imports.  
- **Disbursements Jobs** – payment requests, wire, check, ACH, acknowledgment, and evening cycles.  
- **Reconciliation Jobs** – BlackLine expense and GL OFSAA close.  

Each job includes:
- Schedule / frequency  
- Job purpose  
- Control-M dummy start job name  
- Control-M folder location  
- SAP Job Name placeholder (for future reference)

---

## 🟦 2. Collections Jobs

| Schedule | Job Description | SAP Job Name (Placeholder) | Control-M Dummy Start Job | Control-M Folder | Remarks |
|-----------|----------------|----------------------------|----------------------------|------------------|----------|
| 6.00 am | STRIPE payout / chargeback | ZSTRP_PAYOUT | `#Q4SAP_ZSTART_STRP_PYOUT_MORN` | jq4-cfo-sap-cloud | Loads Stripe chargeback files into SAP |
| 8.20 am | BAI (JPMC and BOA) | ZBAI_FILE_LOAD | `#Q4SAP_BAI_JPMC_START`, `#Q4SAP_BAI_BOFA_START` | jq4-cfo-sap-cloud-checks | Imports BAI bank files for reconciliation |
| 9.15 pm, 10.15 pm, 11.15 pm | ACH PNC & PUB (Evening cycle) | ZCOLL_PAY_EVE | `#Q4SAP_ZSTART_PNC_POST_EVE` | jq4-cfo-sap-cloud | Evening inbound payment cycle |

---

## 🟩 3. Disbursements Jobs

| Schedule | Job Description | SAP Job Name (Placeholder) | Control-M Dummy Start Job | Control-M Folder | Remarks |
|-----------|----------------|----------------------------|----------------------------|------------------|----------|
| 4am, 5am, 6am | ACH PNC and PUB Payment Request Cycle (Morning) | ZPAYM_REQ_MORN | `#Q4SAP_ZSTART_PNC_POST_PAY_MORN` | jq4-cfo-sap-cloud | Initiates morning outbound payments |
| 7am–3.59pm (every 5 min) | Auto Express Checks | ZPAYM_CHECK_AUTO | `#Q4SAP_PAY_CORP_AE_START` | jq4-cfo-sap-cloud-checks | Triggers express check processing |
| 7.15am, 8.15am | LifeCo Wire / ACH PNC / PUB (Morning) | ZPAYM_REQ_LIFE | `#Q4SAP_ZSTART_POST_MORN` | jq4-cfo-sap-cloud | Executes AM payment runs |
| 10am–4pm (every hour) | Regular Payment Cycle | ZPAYM_REQ_REG | `#Q4SAP_ZSTART_LIFE_PNC_PAY` | jq4-cfo-sap-cloud | Standard day cycle for wire/ACH |
| 10.15am–7.15pm (every 30 min) | LifeCo Wire / ACH PNC & PUB | ZPAYM_REQ_REG2 | `#Q4SAP_ZSTART_POST` | jq4-cfo-sap-cloud | Continuous cycle during business hours |
| 1.30 pm | WIRE CORP Payment | ZPAYM_WIRE_CORP | `#Q4SAP_PAY_WIRE_START` | jq4-cfo-sap-cloud | Corporate wire disbursement |
| dependent on IL job `#Q4PEN1_CHASE_TO_SAP_ACK_WIRES_END` | Wire Acknowledgment | ZPAYM_WIRE_ACK | `#Q4SAP_ACK_WIRE_START` | jq4-cfo-sap-cloud | Confirms wire acknowledgment |
| 5pm, 6pm, 7pm | ACH PNC and PUB (Evening) | ZPAYM_REQ_EVE | `#Q4SAP_ZSTART_PNC_PUB_PAY_EVE` | jq4-cfo-sap-cloud | Initiates evening disbursements |
| 7.30 pm | ECT Check Payment | ZPAYM_CHECK_ECT | `#Q4SAP_PAY_POSPAY_START` | jq4-cfo-sap-cloud-checks | Executes ECT check processing |
| 8pm | ACH CORP Payment | ZPAYM_ACH_CORP | `#Q4SAP_PAY_ACH_START` | jq4-cfo-sap-cloud | Corporate ACH disbursement |
| dependent on IL job `#Q4PEN1_CHASE_TO_SAP_ACK_END` | ACH Acknowledgment | ZPAYM_ACH_ACK | `#Q4SAP_ACK_ACH_START` | jq4-cfo-sap-cloud | Processes ACH acknowledgment |

---

## 🟨 4. Reconciliation Jobs

| Schedule | Job Description | SAP Job Name | Control-M Dummy Start Job | Control-M Folder | Remarks |
|-----------|----------------|--------------|----------------------------|------------------|----------|
| 11.30 pm | Recon Key Close / Transfer / GL OFSAA Job | ZPOST_GL | `#Q4SAP_POSTGL_START` | jq4-cfo-sap-cloud | End-of-day GL close |
| 2.00 am | BlackLine Expense Jobs for LifeCo Wire, ACH PNC, and PUB | ZEXPENSE_GL | `#Q4SAP_ZSTART_LIFE_GL_EXPENSE` | jq4-cfo-sap-cloud | BlackLine expense and reconciliation feed |

---

## 🧭 5. End-to-End Flow

```mermaid
flowchart TD
A[Stripe / Bank File Arrival] --> B[Collections Load Jobs]
B --> C[Payment Request Cycles (AM/PM)]
C --> D[Disbursement Jobs (Wires, Checks, ACH)]
D --> E[Acknowledgement Processing]
E --> F[Reconciliation & GL Close]
F --> G[BlackLine Expense Feed]
```

---

## 🧑‍💼 6. Contacts

| Area | Team | Primary Contact | DL / Email | Escalation |
|-------|------|-----------------|-------------|-------------|
| Collections | SAP Collections | TBD | collections@company.com | Manager |
| Disbursements | SAP Disbursements | TBD | disbursements@company.com | Lead |
| Reconciliation | SAP Finance | TBD | finance@company.com | Finance Lead |
| Scheduling | Control-M | TBD | controlm@company.com | Scheduling Lead |
| Support | RTB / Production | TBD | support@company.com | Support Manager |
