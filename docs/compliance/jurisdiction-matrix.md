# MoveMark Consumer: jurisdiction matrix

Prepared 2026-11-07. Not a legal opinion. "Readiness" describes the work below; it doesn't say MoveMark meets any law. "(excerpt)" means the official page was read through a search excerpt, not in full. Other official pages were fetched through a summarizing tool, so check exact wording before quoting. P0 and P1 numbers refer to `launch-checklist.md`.

## Recommendation

**Enable Canada only.** In App Store Connect choose "Specific Countries or Regions" and leave the future-storefronts box unticked ([Apple](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/), excerpt). In Play Console add Canada only; targeting follows the Play account's country, not physical location ([Google](https://support.google.com/googleplay/android-developer/answer/7550024?hl=en), excerpt). Don't enable worldwide. In-app purchases have their own availability settings, so set those too.

| Jurisdiction | Readiness | Enable now? |
|---|---|---|
| Canada outside Quebec | Not ready; P0 list is the path | **Yes, once P0s close** |
| Quebec | Not ready; can't be separated by storefront | Comes with Canada, so **decide first** (P0-15) |
| United States | Not ready | **No** |
| EU/EEA | Not ready | **No** |
| UK | Not ready | **No** |

The product is built around Ontario renters, so the other markets add legal work with little product fit.

## Canada

**When it applies.** PIPEDA covers private-sector organizations handling personal information in commercial activity. Alberta, BC and Quebec have substantially similar laws, but information crossing provincial or national borders in commercial activity stays under PIPEDA ([OPC](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/pipeda_brief/)). An Ontario operator storing data in the US fits that description. Ontario's consumer rules apply when either the business or the consumer is in Ontario ([Ontario](https://www.ontario.ca/document/business-guide-consumer-protection/types-agreements)).

**Obligations.**

- *PIPEDA:* the ten fair information principles, including accountability, consent, limiting collection, retention limits, safeguards, and openness. Set minimum and maximum retention ([OPC](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/principles/p_use/)). Answer access requests within 30 days ([OPC](https://www.priv.gc.ca/en/privacy-topics/accessing-personal-information/obligations-for-organizations/02_05_d_54_ati_02/), excerpt). Generally get express consent for sensitive information ([OPC](https://www.priv.gc.ca/en/privacy-topics/collecting-personal-information/consent/gl_omc_201805/)). Stay accountable for processors and make foreign processing plain ([OPC](https://www.priv.gc.ca/en/privacy-topics/airports-and-borders/gl_dab_090127/)).
- *Breach:* see `breach-response-outline.md`.
- *Children:* see `minors-and-age.md`.
- *Alberta:* notify the Commissioner without unreasonable delay where a reasonable person would see a real risk of significant harm ([OIPC](https://oipc.ab.ca/breach-notification/), excerpt). How this interacts with PIPEDA for an Ontario operator is open. BC: **unverified, not read**.
- *Ontario consumer:* the CPA 2002 rules for online transactions over $50: disclosure, chance to accept, decline or correct, copy within 15 days ([Ontario](https://www.ontario.ca/page/safe-online-shopping)). The Consumer Protection Act, 2023 appears **not yet in force**: e-Laws text said it starts on a day to be named by proclamation, and the registry says the current Act stays until the first regulations are done ([e-Laws](https://www.ontario.ca/laws/statute/23c23), [registry](https://www.ontariocanada.com/registry/view.do?language=en&postingId=49574), excerpts). The live e-Laws page returned no text, so **current status is unverified**. Its Phase 1 proposals would generally require express consent to continue a contract, so renewal rules may change.
- *CASL:* consent, identification and unsubscribe for commercial messages ([ISED](https://ised-isde.canada.ca/site/canada-anti-spam-legislation/en/getting-consent-send-email), [Act s. 6](https://laws-lois.justice.gc.ca/eng/acts/E-1.6/page-1.html)). Rule in `launch-checklist.md`.
- *Coming:* Bill C-36 would replace PIPEDA's private-sector part. It had completed first reading as of the sources read, and PIPEDA stays in force until then ([LEGISinfo](https://www.parl.ca/legisinfo/en/bill/45-1/c-36), [Library of Parliament](https://lop.parl.ca/sites/PublicWebsite/default/en_CA/ResearchPublications/LegislativeSummaries/451C36E), excerpts). Nothing to build for it now.

**Product changes genuinely needed.** Every P0 except the Quebec-specific P0-15. Nothing beyond the launch list.

**Open questions.** Is MoveMark or the store the supplier for Ontario CPA purposes, and do store receipts meet the copy rule (L9)? How far do the CPA's limits on waivers affect Terms sections 16 to 19 (L2)? Is consent by adding material good enough for sensitive information (L6)? Which rules apply to landlords and roommates shown in photos (L8)?

**Readiness:** Not ready. Terms and Privacy drafts are honest about most gaps; several gaps need building.

**Store:** Enable after P0s close.

## Quebec

**When it applies.** The CAI's materials address businesses holding personal information; whether an out-of-province app with no Quebec establishment is caught simply by Quebec downloads wasn't confirmed from an official page. **Unverified: ask the lawyer.** Plan as if it applies, because the Canada storefront reaches Quebec.

**Obligations** ([CAI overview](https://www.cai.gouv.qc.ca/protection-renseignements-personnels/sujets-et-domaines-dinteret/principaux-changements-loi-25)).

- Publish the title and contact details of the person in charge on the website.
- Keep a register of confidentiality incidents, and notify the CAI and affected people where there's a risk of serious harm.
- Publish a plain-language privacy policy. Default settings must give the highest level of privacy with no action needed. Ask consent separately for each purpose.
- Provide computerized information in a structured, commonly used format on request.
- Penalties can reach 2% of worldwide revenue or $10 million.
- **Under 14:** information can't be collected from the child without a parent's or tutor's consent, unless clearly for the child's benefit. **Ages 14 to 17** may consent themselves ([CAI](https://cai.gouv.qc.ca/espace-evolutif-modernisation-lois/thematiques/mineurs), excerpt).
- **Transfers outside Quebec:** a privacy impact assessment comes first, weighing sensitivity, purpose, safeguards and the destination's legal regime. Cloud storage outside Quebec is a named example. Proceed only if protection is adequate, under a written agreement. People must be told ([CAI](https://cai.gouv.qc.ca/evaluation-facteurs-relatifs-vie-privee/communication-renseignements-personnels-exterieur-quebec), [EFVP guide](https://www.cai.gouv.qc.ca/uploads/pdfs/CAI_GU_EFVP.pdf), excerpts). All MoveMark data sits in the US, so this assessment is required for every Quebec user.
- **French:** subscription contracts are adhesion contracts and must be supplied in French first, and an app can be the medium if the French version is available on it. Without a French version, a business can't bind the customer to a non-French adhesion contract ([OQLF](https://www.oqlf.gouv.qc.ca/francisation/entreprises/contrats-adhesion.html), [OQLF consumers](https://www.oqlf.gouv.qc.ca/francisation/droits_linguistiques/droits/langue-du-commerce-et-des-affaires.html), excerpts).
- **Consumer:** a website button to end subscriptions entered into online ([OPC Québec](https://www.opc.gouv.qc.ca/en/consumer/new-protections); date not given). A copy of an online contract within 15 days ([OPC Québec](https://www.opc.gouv.qc.ca/en/consumer/topic/purchase/online-purchase/contract), excerpt).

**Product changes genuinely needed (the Quebec minimum set).**

1. French Terms and Privacy, shown before acceptance, and French paywall text. Translate the whole app if the lawyer says so.
2. Written transfer assessment covering Neon, Railway, B2, RevenueCat, Sentry and Vercel, with the P0-13 agreements.
3. Published person in charge, and an incident register (the P0-11 log can serve).
4. Under-14 stop in the age step (`minors-and-age.md`).
5. Originals: GPS needs a decision before relying on "highest level of privacy" defaults (P0-7).
6. Structured export on request (the manual procedure can cover launch).

**Open questions.** Does Law 25 reach MoveMark at all? Does a link to Apple's or Google's cancel page meet the button rule when billing is by the store? Is the app interface itself required in French? Does Option B in P0-15 limit exposure?

**Readiness:** Not ready. Items 2, 3 and 4 overlap Canadian work; French is the real extra.

**Store:** Can't be enabled or disabled separately. Do the minimum set, or use the P0-15 fallback.

## United States

**When it applies.** *COPPA:* services directed to children under 13, or general-audience services with actual knowledge of a child. Foreign services directed to US children must comply ([FTC FAQ](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions)). *CCPA:* a business with over $26,625,000 annual gross revenue ([CPPA](https://cppa.ca.gov/regulations/cpi_adjustment.html)), or buying, selling or sharing data of 100,000+ consumers or households, or deriving 50%+ of revenue from selling or sharing ([CPPA FAQ](https://cppa.ca.gov/faq.html), excerpt). MoveMark is likely below these today; owner to confirm. *Other state privacy laws:* **not checked**; no official source read.

**Obligations.**

- *Texas SB 2420 (the near-term blocker).* Apple said new Texas accounts became subject to it from June 4, 2026, after a court lifted an injunction, and pointed developers to the Declared Age Range and Significant Change APIs ([Apple, June 2026](https://developer.apple.com/news/?id=100002398)). It covers parental consent for minors' downloads and purchases, and revocation ([Apple](https://developer.apple.com/news/?id=2ezb6jhj)). Apple says that where legally required, even 18+ apps must check age with the API ([Apple Q&A](https://developer.apple.com/support/age-assurance/)). Google says the law is in effect and leaves applicability to the developer; SKUs may need age ratings ([Google](https://support.google.com/googleplay/android-developer/answer/16569691?hl=en)). Neither app has these APIs. The statute wasn't read. Utah and Louisiana are flagged by Apple; dates are **unverified**.
- *COPPA:* notice and verifiable parental consent. Amended rule published April 22, 2025; about a year to comply, exact dates **unverified** ([FTC](https://www.ftc.gov/legal-library/browse/federal-register-notices/16-cfr-part-312-coppa-final-rule-amendments), excerpt). No age question is needed for a general-audience service, but a parent's message creates actual knowledge.
- *Subscriptions:* the Eighth Circuit vacated the FTC's click-to-cancel rule in July 2025, and the FTC opened new rulemaking in 2026; it still uses ROSCA and Section 5 ([FTC](https://www.ftc.gov/legal-library/browse/rules/negative-option-rule), [testimony](https://www.ftc.gov/system/files/ftc_gov/pdf/p994811-ftc-oversight-testimony-senate-commerce-committee-2026.pdf), excerpts). State auto-renewal laws: **not checked**.

**Product changes genuinely needed.** Age APIs on both platforms and parental-revocation handling, a US-specific policy section, and a process for a child's account reported by a parent.

**Open questions.** Does SB 2420 reach MoveMark in practice? Which state privacy and auto-renewal laws apply? How do US rental rules affect the product's content?

**Readiness:** Not ready.

**Store:** **Do not enable.**

## EU/EEA

**When it applies.** GDPR reaches a non-EU business offering services to people in the EU ([Art. 3(2)](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679)). Mere availability isn't enough; language, currency or mentioning EU customers can show intent (Recital 23). Enabling EU storefronts with local pricing risks showing that intent.

**Obligations** ([GDPR](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679)). Art. 27 representative, subject to exemptions. Art. 33 breach notice within 72 hours where feasible. Art. 44 conditions on transfers. Art. 8: child consent from 16, or a lower national age down to 13. Apple requires EU trader status, and traders' address, phone and email are displayed; apps without it are removed ([Apple](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/), excerpt). This matters if the operator is an individual using a home address. Consumers get 14 days to withdraw from distance contracts, with an exception for digital content, and in July 2026 the CJEU treated a streaming subscription as a digital service where withdrawal can't be excluded ([C-234/25](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX%3A62025CJ0234), excerpt).

**Product changes genuinely needed.** Lawful-basis mapping, transfer mechanism for US processors, rights handling within GDPR timelines, local languages, withdrawal wording.

**Open questions.** Do the store's own terms handle withdrawal? Would a per-country age gate be needed? Does evidence-style storage of third parties' images fit a legitimate-interest basis?

**Readiness:** Not ready.

**Store:** **Do not enable.**

## United Kingdom

**When it applies.** UK GDPR reaches a non-UK organization offering services to people in the UK. ICO guidance says such an organization must appoint a UK representative unless processing is occasional and low-risk (seen in search excerpts only; the ICO site refused direct fetches, so the exact page and wording are **unconfirmed**). The Children's code covers online services likely to be accessed by under-18s in the UK, including services from outside the UK offered to UK users ([ICO](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/age-appropriate-design-a-code-of-practice-for-online-services/services-covered-by-this-code/), excerpt).

**Obligations.** UK GDPR duties, the Children's code assessment, and transfer rules. The UK digital consent age (understood to be 13) is **unverified**: ICO pages refused the fetch. UK subscription rules: **not checked**, no listed official source read.

**Product changes genuinely needed.** Representative, assessment, UK policy section, and a rights process.

**Open questions.** Applicable UK subscription rules; whether UK tenancy deposit schemes change the product's value and copy.

**Readiness:** Not ready.

**Store:** **Do not enable.**
