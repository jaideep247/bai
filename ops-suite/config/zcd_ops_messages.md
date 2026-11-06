# Message class ZCD_OPS

Number ranges: 001–099 core · 100–199 EBS · 200–299 FMON · 300–399 HCK.
Create in SE91 exactly as listed (short texts ≤ 73 characters).

| No. | Text |
|---|---|
| 000 | &1 &2 &3 &4 |
| 001 | Run ID could not be generated |
| 010 | Insert into table &1 failed |
| 011 | Update of table &1 failed |
| 012 | Read of table &1 failed |
| 020 | Alert for route &1 could not be sent |
| 021 | Alert rule &1 has no recipient |
| 022 | Application log &1/&2 could not be written |
| 023 | HTTP destination &1 could not be reached (&2) |
| 024 | HTTP destination &1 answered &2 &3 |
| 030 | Class &1 does not exist |
| 031 | Class &1 cannot be instantiated as a plug-in |
| 032 | Class &1 does not implement interface &2 |
| 040 | Run for &1 &2 is already active (lock held by &3) |
| 041 | No authorization for &1 activity &2 |
| 042 | Lock service failed for &1 &2 (run not started) |
| 050 | Configuration missing: &1 &2 |
| 051 | Configuration value &1 for &2 is invalid |
| 150 | Content is not a BAI2 file: first record &1 (expected type 01) |
| 151 | XML content could not be parsed: &1 |
| 152 | Unsupported XML message &1/&2; expected camt.053 or camt.054 |
| 200 | Table &1 not found in the DDIC or not a flat DDIC structure |
| 201 | Field &1 does not exist in table &2 |
| 202 | &1 is not a valid DDIC name |
| 203 | Field &1 of table &2 has type &3, expected &4 |
| 204 | Source &1: no field configured for &2 |
| 205 | Read of table &1 failed: &2 |
| 206 | Factory calendar &1: date &2 cannot be converted |
| 208 | Lot configuration &1 &2: field &3 missing |
| 209 | Read of table &1 has no date or key restriction |
| 211 | File ID could not be generated |
| 220 | File monitoring &1: &2 file(s), &3 finding(s), RAG &4 |
| 300 | Check &1: class &2 does not implement ZIF_CD_HCK_CHECK |
| 301 | Check &1 failed: &2 |
| 302 | Table &1 is not on the health check whitelist ZCD_HCK_TABWL |
| 303 | Table &1 does not exist in the ABAP Dictionary |
| 304 | Field &1 does not exist in table &2 |
| 305 | Operator &1 for field &2 is not supported (EQ NE GT LT GE LE IN) |
| 306 | Value &1 is not a valid number for field &2 |
| 307 | Aggregate &1 of check &2: date mode &3 is invalid (AGE, DAY, blank) |
| 308 | Aggregate on table &1 (&2) failed in the database |
| 309 | Date field &1 of table &2 is not of type DATS |
| 310 | Check &1 has no aggregate definition in ZCD_HCK_AGG |
| 311 | Hash of table &1 could not be calculated |
| 312 | (reserved) |
| 313 | Lock table could not be read (ENQUEUE_READ return code &1) |
| 314 | Configuration baseline taken for &1 tables &2 |
| 315 | Morning report exported to &1 |
| 316 | Export file &1 could not be opened for writing |
| 317 | Aggregate function &1 of check &2 is not supported (COUNT, SUM) |
| 318 | SUM field &1 of table &2 is not numeric |
