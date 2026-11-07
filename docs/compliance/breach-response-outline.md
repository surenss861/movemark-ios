# MoveMark: breach response outline

Starting process, prepared 2026-11-07 from PIPEDA reporting and record-keeping rules. Not a legal opinion; have the lawyer review it. Sources: [OPC breach guidance](https://www.priv.gc.ca/en/privacy-topics/business-privacy/safeguards-and-breaches/privacy-breaches/respond-to-a-privacy-breach-at-your-business/gd_pb_201810/), [Breach of Security Safeguards Regulations](https://laws-lois.justice.gc.ca/eng/regulations/SOR-2018-64/FullText.html).

**Roles (fill in).** Incident lead and final decision: `[OWNER: name]`. Backup: `[OWNER: name]`. Outside counsel: `[OWNER: name]`. Log location: a private, access-limited file outside this repository.

**What counts.** Loss of, unauthorized access to, or unauthorized disclosure of personal information held by MoveMark, or a processor's failure affecting it. Examples for MoveMark: backup key or B2 keys exposed; a Neon, Railway or storage credential exposed; a signed link or report reaching the wrong person; one user seeing another's data; a social sign-in takeover; deleted accounts returning after a restore; GPS or addresses in Sentry; reset emails going to the wrong person.

## Steps

1. **Log it (same day).** Open a log entry for anything suspected, even if it turns out to be minor.
2. **Contain (immediately).** Rotate keys, disable the affected route or account, preserve logs. Signed links can't be revoked: they expire within an hour, or sooner if the object is removed. Don't destroy evidence.
3. **Assess.** What information, whose, how many, when, cause, and is it still happening? Ask processors for facts in writing.
4. **Decide on real risk of significant harm (RROSH).** Weigh the sensitivity of the information and the probability of misuse. Significant harm includes bodily harm, humiliation, damage to reputation or relationships, loss of employment, financial loss and identity theft. Home photos, addresses and leases should be treated as sensitive. Use the [OPC RROSH tool](https://www.priv.gc.ca/en/privacy-topics/privacy-for-businesses/privacy-breaches-at-your-business/rrosh-tool/). Write down the reasoning, including a "no" decision. Involve counsel.
5. **If RROSH: report to the OPC and notify individuals, as soon as feasible.** There's no fixed number of days.
   - **OPC report** ([form](https://www.priv.gc.ca/en/report-a-concern/report-a-privacy-breach-at-your-organization/report-a-privacy-breach-at-your-business/)), in writing: circumstances and cause if known; date or period; information involved; number affected; steps to reduce harm; steps to notify; a contact person.
   - **Notice to individuals:** circumstances; date or period; information involved; steps MoveMark took; steps they can take; a contact. Send directly where possible. Remember emails aren't verified today (C14).
   - **Other organizations** that could reduce harm (for example a provider): the Act is understood to require notice here too. **Unverified from the pages read; confirm with counsel.**
6. **Fix and review.** Record the root cause, the fix, and any policy or wording change.

## Breach log: every breach, kept 24 months

The rule covers every breach, not only reportable ones, and the record must let the Commissioner verify compliance. Keep it longer if the lawyer advises. Knowingly failing to report, notify or keep records is an offence that can lead to fines. Suggested fields:

| Field | Note |
|---|---|
| ID, date found, who found it | |
| Date or period of breach | Approximate is fine |
| What happened, cause | |
| Information and people affected | Counts and categories; avoid copying the data itself |
| Processor involved | |
| Containment steps and dates | |
| RROSH decision, reasoning, decider, date | Required even for "no" |
| OPC report date; individual notice date and method | |
| Other authorities told | See below |
| Root cause fix, date closed | |

## Other regimes to check at step 5

- **Quebec:** notify the CAI and affected people where there's a risk of serious harm; keep an incident register for the CAI on request ([CAI](https://www.cai.gouv.qc.ca/protection-renseignements-personnels/sujets-et-domaines-dinteret/principaux-changements-loi-25), [form](https://www.cai.gouv.qc.ca/uploads/pdfs/CAI_FO_Incident_Conf.pdf)).
- **Alberta:** notify the Commissioner without unreasonable delay where a reasonable person would see RROSH ([OIPC](https://oipc.ab.ca/breach-notification/), read through an excerpt).
- **Processors:** MoveMark generally stays responsible for reporting. Contracts should require prompt notice to MoveMark (`launch-checklist.md` P0-13).

**Before launch:** fill in roles, create the log, record a conclusion on the 2026-10-22 production SQL event as the first entry, and run one tabletop (for example, "the backup key was exposed").
