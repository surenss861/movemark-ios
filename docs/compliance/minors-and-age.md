# MoveMark Consumer: minors and age

Prepared 2026-11-07. Not a legal opinion. Owner's goal: all ages over time, teens at launch where supportable, guardian-authorized under-13 later. Today there's no age step and no parental consent mechanism in either app or the schema.

## What the rules say

**The OPC Children's Privacy Code is real.** Verified on priv.gc.ca: the OPC launched it on October 20, 2026, and takes comments until January 20, 2027, after which it may be updated ([news release](https://www.priv.gc.ca/en/opc-news/news-and-announcements/2026/nr-c_261020/)). It "reflects the OPC's views on organizations' obligations under PIPEDA", so it reads as the regulator's interpretation, not new statute ([Code](https://www.priv.gc.ca/en/privacy-topics/privacy-for-businesses/protection-of-children-for-businesses/childrens-privacy-code/children-code-final-report-2026/)). Everything below on the Code comes from that page, read through a summarizing fetch, so check exact wording before quoting it publicly.

- **Scope:** everyone under 18, for services directed at children or "likely to be accessed" by them, meaning "a reasonable probability of child access". It applies even if children aren't the intended audience. If you conclude they're unlikely, document that and why.
- **Under 13:** "In all but exceptional circumstances, organizations must obtain consent from a parent or guardian."
- **13 to 17:** the child can consent, but organizations should assess capacity, especially for sensitive information. Consent built for adults "will generally not meet" the standard.
- **Also:** location off by default, opt-in for non-essential uses, withdrawal at any time, deletion on request at majority of data collected in childhood, and no deceptive design. A privacy impact assessment is strongly encouraged.

**Age assurance:** the OPC says it's only for a legitimate need to tell users apart by age, must be proportionate, and shouldn't be used if only a trivial number of users are children. An unenforced policy line barring minors "would not be a meaningful factor" in showing who your users are ([OPC](https://www.priv.gc.ca/en/privacy-topics/age-assurance/aa-gd-web/)). The Code says that where sufficient certainty about age can't be achieved, protections should apply to all users by default.

**Quebec:** under 14 needs a parent or tutor unless the collection is clearly for the child's benefit; 14 to 17 can consent ([CAI](https://cai.gouv.qc.ca/espace-evolutif-modernisation-lois/thematiques/mineurs), excerpt).

**Stores:** Apple's Kids Category isn't relevant, and apps collecting personal information from a minor must follow children's privacy laws ([5.1.4](https://developer.apple.com/app-store/review/guidelines/)). Answer age ratings honestly (2.3.6). On Play, any target age group that includes children brings in the Families policy ([Google](https://support.google.com/googleplay/android-developer/answer/9859455)).

**Why MoveMark isn't trivially "adults only":** students and short-stay guests may be under 18, the app is free to start, and leases aren't a technical barrier. Whether that makes child access reasonably probable is a judgment the owner should write down. MoveMark's data is sensitive: photos of a home, an address, and possibly GPS.

## Minimum honest position for launch

**Everyone sees a neutral age step at sign-up, inside the acceptance screen already being built (P0-5).** Ask for a band, no birth date, without suggesting the "right" answer, and store only the band. A self-declared band is weak. It's still proportionate here, because the app has no ads, tracking, public profiles or messaging, but the lawyer should confirm that.

| Age | Launch position |
|---|---|
| Under 13 (under 14 for Quebec) | **Not allowed.** Stop sign-up, collect nothing else, and don't suggest changing the answer. If told later that a child has an account, delete it. |
| 13 (14 in Quebec) to 17 | **Allowed only if the three teen items below ship.** If they don't, this band is told "not yet", and launch is 18+ for now. |
| 18+ | Allowed. |

**Three teen items (all small):**

1. A short plain-language notice for teens: what's stored, that it's in the US, who could see a shared report, how to delete. This is for capacity, not legal boilerplate.
2. No GPS retained for this band, or for everyone (P0-7). Applying it to everyone is simpler and avoids relying on a weak age answer.
3. A written note assessing likely child access and teen capacity, plus lawyer sign-off on contract terms. Minors' contract capacity in Ontario wasn't checked (**unverified**), and purchases by a teen run through Apple or Google.

**Wording to use:** "MoveMark isn't for children under 13 (under 14 in Quebec)." State the teen rule that actually applies. **Remove** the site's "or have a parent's or guardian's permission" unless a mechanism exists, because today nothing checks or records it. Don't claim "we don't knowingly collect" without the age step behind it. Terms section 4, Privacy section 15, and the store declarations must all match.

Good news already in the product: no advertising, no analytics SDK, no public profiles, no chat, and self-serve deletion. Those would need to stay true.

## What under-13 would need (later)

Build this only after teens work, and keep it out of launch.

- **Guardian-owned account:** the adult is the account holder and payer, and the child adds to it. This is the simplest fit, since the guardian agrees to the Terms.
- **Parental consent flow:** a check that the person is the guardian, and a stored record. Consultation respondents favoured linked accounts and in-app confirmation over documents ([OPC report](https://www.priv.gc.ca/en/about-the-opc/what-we-do/consultations/completed-consultations/consultation-children-code/report_children-code_2026/), excerpt). That's feedback, not a rule. Check Apple's and Google's parental tools first.
- **Age-appropriate notices** for the OPC's age groups (0-5, 6-9, 10-12), and a child-readable policy.
- **Withdrawal and deletion** by guardian or child, and deletion on request at majority.
- **Data review:** no GPS, no non-essential use, retention limits, and a privacy impact assessment.
- **Sentry and RevenueCat review** under Apple 5.1.4 and Play's Families policy, which may restrict SDKs.
- **Store changes:** Play target audience, Data safety and rating updates.
- **Outside Canada:** COPPA verifiable parental consent, plus national ages, before any US or EU launch.
