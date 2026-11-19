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

## Launch implementation, release 1.4 RC2 (2026-11-08)

Owner decision D1: a simple, mandatory age-eligibility confirmation, no date of birth. The minimum was first set at 13 (14 in Quebec); **superseded the same day by 18+ (see the next section)**. The code below supports both; the server's `age_requirement` picks one.

**What shipped in code (local, not deployed):**
- App (build 20261108.1): a second, unticked box on "One last thing.": "I'm 13 or older (14 or older if I live in Quebec).", with a short plain-language note for under-18s under it (what's stored, stored in the US, nobody sees it unless a report is shared, delete from Account). Continue stays disabled until both boxes are ticked. Someone who can't confirm stops there, with Sign out and Delete account below; nothing suggests changing the answer.
- Server (migration 1055): `accept_legal_documents(method, terms, notice, p_age_attestation)` records the confirmed statement code and time, and refuses anything other than the current `legal_gate_settings.age_requirement`. Once enforcement is on, an acceptance without the current attestation doesn't count, for RLS and the API alike.
- The statement is server-chosen: `age_13_qc_14` now; `age_18` is a ready fallback (switch the setting by migration, publish matching documents; build 20261108.1 already has the 18+ wording).

**Old clients.** Build 20261107.1 calls the three-argument function. While enforcement is off nobody is gated, so its users use the app without any age confirmation; that is the honest state of the soft phase. Once enforcement is on, its acceptances stop counting and it can't record new ones (`LEGAL_AGE_ATTESTATION_REQUIRED`), so those users are blocked until they update. Minimum client that carries the attestation: **1.4 (20261108.1)**. Detection is the RPC signature inside the database, never a header. No compatibility window is built in; one would need the owner's explicit acceptance (for example, delay enforcement until 20261107.1 usage is negligible).

**What the server enforcement does and doesn't cover.**
- Covered: every Data API read and write on rental tables (restrictive RLS, `legal_gate_passes`) and every protected MoveMark API route (`require_legal_acceptance`), once `enforced = true`.
- Not covered: account creation itself. Neon Auth creates the account (email or Apple/Google) before MoveMark sees it, so an under-age person can still create an account; they just can't reach rental data under enforcement without the confirmation. `profiles` isn't gated, so the profile row (email, name) exists. `DELETE /api/account` stays open by design.
- The confirmation is self-declared. Nothing verifies it, and the texts say so.
- Before enforcement, nothing is enforced for anyone.
- Android has no age step yet. It must ship the 4-argument call before enforcement, or Android users are locked out at enforcement.

**Teens (13 to 17, 14 to 17 in Quebec): flagged for the owner, not silently decided.** Of the three teen items above:
1. Teen notice: done (shown to everyone, since the app can't tell teens apart).
2. No GPS retained for teens: **not met**. D2 keeps original photo metadata, GPS included, in private storage for everyone, and a yes/no confirmation can't identify teens. Shared PDFs and shared copies of image documents are stripped.
3. Written likely-child-access and teen-capacity assessment plus lawyer sign-off: **not done** (owner and lawyer).

So by this document's own bar, teens aren't fully supported yet. **Proposed fallback for the owner:** launch 18+ (`age_requirement = 'age_18'`, the Terms and Privacy minimum changed to 18, new document versions). That needs no new build. Or keep 13+ and accept item 2 explicitly (or strip GPS from originals for everyone, which reverses D2), with item 3 done before launch.

**Quebec basis, checked 2026-11-08 (for any later move below 18):** the CAI's page on minors (cai.gouv.qc.ca, "Mineurs") states that personal information about a minor under 14 can no longer be collected from them without the consent of the person with parental authority or the tutor, unless the collection is clearly for the minor's benefit. That is the basis for "14 in Quebec". **Not verified:** the exact statutory section (understood to be s. 4.1 of the Act respecting the protection of personal information in the private sector, CQLR c P-39.1, added by Law 25). legisquebec.gouv.qc.ca refused automated fetches, and the CAI page cites no section numbers. Also not verified: that 14 to 17 year olds may consent on their own under the private-sector act (the CAI page doesn't address it), Ontario minors' contract capacity, and whether "clearly for the minor's benefit" could apply. All of this needs legal review.

## Owner decision, 2026-11-08: the initial release is 18+

**Decision.** MoveMark Consumer launches **18+ everywhere it is offered, Quebec included**. This is MoveMark's product eligibility policy for the initial release. It is **not** a claim that Canadian or Quebec law requires 18.

**Why:**
- The teen safeguards this document requires aren't complete. "No GPS retained for teens" can't be met, because D2 keeps original photos and image documents with their metadata, GPS included, in private storage for everyone, and a yes/no confirmation can't single out teens.
- The written assessment of likely child access and teen capacity, and the lawyer's sign-off on minors' contracts and consent, haven't been done.
- Originals may keep GPS, which the OPC Children's Privacy Code treats as sensitive for under-18s (location off by default).

**How it is implemented (no app rebuild):**
- Migration 1055 defaults `legal_gate_settings.age_requirement` to `'age_18'`, so production starts at 18+. `'age_13_qc_14'` stays allowed for a later change.
- Build 1.4 (20261108.1) already maps `age_18` to "I'm 18 or older." and an adult-oriented note.
- The Terms (section 1) and Privacy (section 10) say 18+, including Quebec, and say the confirmation is a self-declaration.

**What the confirmation is and isn't.** It is the user's own declaration, recorded with the time and the document versions. **It is not age verification:** no date of birth, no document, no check. The legal texts, the review notes and this document must never describe it as verified. If MoveMark learns an account belongs to someone under 18, it deletes the account.

**Still under review:**
- Quebec requirements (the under-14 parental-consent rule, consent at 14 to 17, French-language obligations), which matter if eligibility ever goes below 18.
- Whether 18+ makes child access unlikely enough under the OPC Code. Write the conclusion down; an unenforced policy line alone carries little weight with the OPC.
- Lowering the age later would need, before switching `age_requirement`:
  - teen safeguards, including GPS handling for originals;
  - the written assessment and the lawyer's sign-off;
  - new document versions;
  - Android support for the age step.

## Owner decision, 2026-11-08 (final for Phase 1): 13+ (14+ in Quebec), age range, teen photo privacy

**This supersedes the 18+ section above, which was never deployed.** Consumer is meant for all ages over time, with consent protections. Phase 1 serves 13+ (14+ in Quebec). Phase 2 (a later binary, after legal review) adds under-13 and 13-in-Quebec with parental or guardian consent.

**Age flow (build 20261108.2, migration 1055 `bands_v1`).** The agreement screen asks "How old are you?" with four answers: Under 13, 13, 14 to 17, 18 or older. "13" also asks "Do you live in Quebec?".
- Under 13, and 13 in Quebec: "MoveMark isn't available for you yet". Continue stays disabled, with Sign out and Delete account below. Nothing is recorded.
- 13 (outside Quebec) or 14 to 17: the range `13_17` is recorded, the account category becomes `teen`, and the teen notice is shown.
- 18 or older: `18_plus` is recorded, and the category becomes `adult`.
- No date of birth is asked. The answer is self-declared, **not verified**.

**Teen safeguards (minors doc items 1 to 3):**
1. **Teen notice:** shown on selection, and in Privacy section 10.
2. **No GPS for teens:** **met by Option B.**
   - **Device:** for `teen` accounts, every photo (camera and library) and every JPEG/PNG document is stripped before it is saved to the pending queue or uploaded (`MMEvidenceImport.source(..., privacy: .teen)`, re-checked in `prepareForUpload`). The strip removes GPS, make, model, software, serials, owner, lens, maker notes, IPTC and XMP. The capture date and offset and the orientation stay. HEIC becomes a full-resolution JPEG.
   - **Server:** for teen accounts, the API checks the stored bytes at finalize, because uploads go straight to object storage on presigned URLs. Migration 1056 refuses any teen row that isn't from a checked ticket. Legacy evidence uploads without a source, HEIC sources, unchecked tickets and file swaps are refused. A PDF carrying photo location is refused.
   - **Receipt and report:** the receipt says "Location and camera details removed for privacy". The report adds a privacy note that never mentions age.
   - **The in-app camera** has no location permission and adds no GPS (verified: `CameraCaptureView` sets no location metadata, and the app has no `NSLocationWhenInUseUsageDescription`).
3. **Written child-access and capacity assessment, and lawyer sign-off:** being drafted separately by another agent. **[LEGAL]**

**What "enforced" covers, and what it doesn't:**
- Before enforcement, accounts that never answered the range (old builds; documents not yet published) have no category, so they keep adult behaviour. A teen using 20261107.1 or 20261108.1 is not protected until they update and answer.
- Once enforcement is on, every account with access has answered through the 5-argument call, so every teen account is covered. Builds 20261107.1 (3-argument) and 20261108.1 (4-argument) can't accept under `bands_v1` and fail closed.
- The trusted backend (no JWT) isn't restricted.
- Categories can change on re-declaration (a teen turning 18). It's self-declared.

**Android** must ship the same flow and protection before Android launch. The spec is in `_scratch/consumer-1.4-rc2.md`.
