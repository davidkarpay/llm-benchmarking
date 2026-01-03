# Florida Authority Pack + Phase 3 Prompt Engineering Deliverables

**Version**: 1.0
**Last Updated**: 2026-01-03
**Verification Status**: Web-verified where indicated

---

## Table of Contents

1. [Source Map (Statutes, Cases, Rules, Bar Rules, Local Rules, Ordinances)](#deliverable-1-florida-authority-pack-source-map)
2. [Case Law Acquisition + Citation Workflow](#deliverable-2-florida-case-law-acquisition--citation-workflow)
3. [Local Rules / Administrative Orders Inventory](#deliverable-3-local-rules--administrative-orders-inventory)
4. [Florida Bar Rules Source Map + Use Constraints](#deliverable-4-florida-bar-rules---source-map--use-constraints)
5. [Ordinances Placeholder Framework](#deliverable-5-ordinances-placeholder-framework)
6. [Phase 3 Evaluation Rubric](#deliverable-6-phase-3-evaluation-rubric-florida-legal-prompting)
7. [Heuristics Library (12 Rules)](#deliverable-7-heuristics-library-florida-legal-prompt-engineering)
8. [Cross-Model Test Prompts (12 Tests)](#deliverable-8-cross-model-test-prompt-set-florida-law)
9. [Drop-In Prompt Clauses](#deliverable-9-drop-in-prompt-clauses)
10. [Appendix A: Local FLLawDL2025 Extraction](#appendix-a-local-florida-statutes-extraction-fllawdl2025)
11. [Appendix B: Sources Referenced](#appendix-b-sources-referenced)

---

# DELIVERABLE 1: Florida Authority Pack (Source Map)

## 1.1 Florida Statutes

| Category | Subcategory | Official Source Name | Official URL(s) | Coverage | Update Cadence | Format | Citation Notes | Access Notes | Last Verified |
|----------|-------------|---------------------|-----------------|----------|----------------|--------|----------------|--------------|---------------|
| Statutes | Florida Statutes (Full) | Online Sunshine - Florida Legislature | https://www.leg.state.fl.us/statutes/ | 2025 (current session) | Annually (July/Aug after session) | HTML, searchable | Fla. Stat. § [section] ([year]) | Public, no rate limits | 2026-01-03 |
| Statutes | Florida Statutes (Senate) | Florida Senate Statutes | https://www.flsenate.gov/laws/statutes | 2025 | Annually | HTML, searchable | Same as above | Public | 2026-01-03 |
| Statutes | Florida Statutes Search | Online Sunshine Search | https://www.leg.state.fl.us/Statutes/index.cfm?Submenu=2&Tab=statutes | Current | Real-time | HTML search portal | N/A | Public | 2026-01-03 |
| Statutes | Laws of Florida (Session Laws) | Online Sunshine | https://www.leg.state.fl.us/Statutes/index.cfm?Mode=Laws+of+Florida&Submenu=4&Tab=statutes | Historical + current | Per session | HTML/PDF | Laws of Fla. ch. [year]-[number] | Public | 2026-01-03 |
| Statutes | Florida Constitution | Online Sunshine | https://www.leg.state.fl.us/statutes/index.cfm?submenu=3 | Current | As amended | HTML | Fla. Const. art. [X], § [Y] | Public | 2026-01-03 |

## 1.2 Florida Decisional Law (Appellate Courts)

| Category | Subcategory | Official Source Name | Official URL(s) | Coverage | Update Cadence | Format | Citation Notes | Access Notes | Last Verified |
|----------|-------------|---------------------|-----------------|----------|----------------|--------|----------------|--------------|---------------|
| Cases | Florida Supreme Court | FL Supreme Court Opinions | https://supremecourt.flcourts.gov/Opinions | Recent + historical | As released | HTML/PDF | [Name], [So. 3d cite] (Fla. [year]) | Public, searchable | 2026-01-03 |
| Cases | Florida Supreme Court (Historical) | FSU Law Digital Collections | https://library.law.fsu.edu/Digital-Collections/flsupct/index.html | 1800s-1990s | Static archive | PDF | Same as above | Public | 2026-01-03 |
| Cases | 1st DCA (Tallahassee) | First DCA Opinions Archive | https://1dca.flcourts.gov/Opinions/Opinions-Archive | Recent + historical | As released | HTML/PDF | [Name], [So. 3d cite] (Fla. 1st DCA [year]) | Public | 2026-01-03 |
| Cases | 2nd DCA (Lakeland/Tampa) | Second DCA Opinions Archive | https://2dca.flcourts.gov/Opinions/Opinions-Archive | Recent + historical | As released | HTML/PDF | [Name], [So. 3d cite] (Fla. 2d DCA [year]) | Public | 2026-01-03 |
| Cases | 3rd DCA (Miami) | Third DCA Search Opinions | https://3dca.flcourts.gov/opinions/Search-Opinions | Recent + historical | As released | HTML/PDF | [Name], [So. 3d cite] (Fla. 3d DCA [year]) | Public, search portal | 2026-01-03 |
| Cases | 4th DCA (West Palm Beach) | Fourth DCA Opinions Archive | https://4dca.flcourts.gov/Opinions/Opinions-Archive | Recent + historical | As released | HTML/PDF | [Name], [So. 3d cite] (Fla. 4th DCA [year]) | Public | 2026-01-03 |
| Cases | 5th DCA (Daytona Beach) | Fifth DCA Opinions Archive | https://5dca.flcourts.gov/Opinions/Opinions-Archive | Recent + historical | As released | HTML/PDF | [Name], [So. 3d cite] (Fla. 5th DCA [year]) | Public | 2026-01-03 |
| Cases | 6th DCA (Lakeland/Orlando) | Sixth DCA Opinions Archive | https://6dca.flcourts.gov/Opinions/Opinions-Archive | 2022-present (new court) | As released | HTML/PDF | [Name], [So. 3d cite] (Fla. 6th DCA [year]) | Public | 2026-01-03 |

## 1.3 Florida Court Procedure Rules

| Category | Subcategory | Official Source Name | Official URL(s) | Coverage | Update Cadence | Format | Citation Notes | Access Notes | Last Verified |
|----------|-------------|---------------------|-----------------|----------|----------------|--------|----------------|--------------|---------------|
| Court Rules | Civil Procedure | Florida Bar - Chapter 1 | https://www.floridabar.org/rules/ctproc/ | Current (updated Jan 1, 2026) | Per Supreme Court order | PDF | Fla. R. Civ. P. [rule number] | Public | 2026-01-03 |
| Court Rules | Criminal Procedure | Florida Bar - Chapter 3 | https://www.floridabar.org/rules/ctproc/ | Current (updated Jan 1, 2026) | Per Supreme Court order | PDF | Fla. R. Crim. P. [rule number] | Public | 2026-01-03 |
| Court Rules | Criminal Procedure (PDF) | FL Courts Media | https://flcourts-media.flcourts.gov/content/download/217910/file/Florida-Rules-of-Criminal-Procedure.pdf | Current | Per order | PDF direct | Same | Public | 2026-01-03 |
| Court Rules | General Practice & Judicial Admin | Florida Bar - Chapter 2 | https://www.floridabar.org/rules/ctproc/ | Current (updated Jan 1, 2026) | Per order | PDF | Fla. R. Jud. Admin. [rule] | Public | 2026-01-03 |
| Court Rules | Appellate Procedure | Florida Bar - Chapter 9 | https://www.floridabar.org/rules/ctproc/ | Current (updated Sep 4, 2025) | Per order | PDF | Fla. R. App. P. [rule] | Public | 2026-01-03 |
| Court Rules | Probate Rules | Florida Bar - Chapter 5 | https://www.floridabar.org/rules/ctproc/ | Current (updated Jan 1, 2026) | Per order | PDF | Fla. Prob. R. [rule] | Public | 2026-01-03 |
| Court Rules | Family Law Rules | Florida Bar - Chapter 12 | https://www.floridabar.org/rules/ctproc/ | Current (updated Oct 1, 2025) | Per order | PDF | Fla. Fam. L. R. P. [rule] | Public | 2026-01-03 |
| Court Rules | Juvenile Procedure | Florida Bar - Chapter 8 | https://www.floridabar.org/rules/ctproc/ | Current (updated Jan 1, 2026) | Per order | PDF | Fla. R. Juv. P. [rule] | Public | 2026-01-03 |
| Court Rules | Traffic Court Rules | Florida Bar - Chapter 6 | https://www.floridabar.org/rules/ctproc/ | Current (updated Jan 1, 2026) | Per order | PDF | Fla. R. Traf. Ct. [rule] | Public | 2026-01-03 |
| Court Rules | Small Claims Rules | Florida Bar - Chapter 7 | https://www.floridabar.org/rules/ctproc/ | Current (updated Jan 1, 2026) | Per order | PDF | Fla. Sm. Cl. R. [rule] | Public | 2026-01-03 |
| Court Rules | Evidence Code | Florida Statutes Ch. 90 | https://www.leg.state.fl.us/statutes/index.cfm?App_mode=Display_Statute&URL=0000-0099/0090/0090ContentsIndex.html | Current | Annually | HTML | Fla. Stat. § 90.[section] | Public | 2026-01-03 |

## 1.4 Florida Bar Rules

| Category | Subcategory | Official Source Name | Official URL(s) | Coverage | Update Cadence | Format | Citation Notes | Access Notes | Last Verified |
|----------|-------------|---------------------|-----------------|----------|----------------|--------|----------------|--------------|---------------|
| Florida Bar Rules | All Chapters (1-21) | Rules Regulating The Florida Bar | https://www.floridabar.org/rules/rrtfb/ | Current | Per Supreme Court order | HTML/PDF | R. Regulating Fla. Bar [chapter]-[rule] | Public | 2026-01-03 |
| Florida Bar Rules | Rules of Professional Conduct | RRTFB Chapter 4 | https://www.floridabar.org/rules/rrtfb/ | Current | Per order | HTML/PDF | R. Regulating Fla. Bar 4-[rule] | Public | 2026-01-03 |
| Florida Bar Rules | Trust Accounts | RRTFB Chapter 5 | https://www.floridabar.org/rules/rrtfb/ | Current | Per order | HTML/PDF | R. Regulating Fla. Bar 5-[rule] | Public | 2026-01-03 |
| Florida Bar Rules | Discipline | RRTFB Chapter 3 | https://www.floridabar.org/rules/rrtfb/ | Current | Per order | HTML/PDF | R. Regulating Fla. Bar 3-[rule] | Public | 2026-01-03 |
| Florida Bar Rules | Lawyer Advertising | RRTFB Chapter 4-7 + Handbook | https://www-media.floridabar.org/uploads/2025/12/Handbook-2025-Approved-by-SCA-12-10-25.pdf | Dec 2025 | Per order | PDF | R. Regulating Fla. Bar 4-7.[rule] | Public | 2026-01-03 |

## 1.5 Local Rules & Administrative Orders (See Deliverable 3 for full inventory)

| Category | Subcategory | Official Source Name | Official URL(s) | Coverage | Update Cadence | Format | Citation Notes | Access Notes | Last Verified |
|----------|-------------|---------------------|-----------------|----------|----------------|--------|----------------|--------------|---------------|
| Local Rules | All 20 Circuits | Individual Circuit Websites | See Deliverable 3 | Varies by circuit | As issued by Chief Judge | PDF/HTML | [Circuit] Admin. Order No. [year]-[number] | Public | 2026-01-03 |
| Local Rules | Florida Courts Portal | FL Courts Circuit Page | https://www.flcourts.gov/Florida-Courts/Trial-Courts-Circuit | Directory only | N/A | HTML | N/A | Public | 2026-01-03 |

## 1.6 Municipal & County Ordinances (See Deliverable 5 for framework)

| Category | Subcategory | Official Source Name | Official URL(s) | Coverage | Update Cadence | Format | Citation Notes | Access Notes | Last Verified |
|----------|-------------|---------------------|-----------------|----------|----------------|--------|----------------|--------------|---------------|
| Ordinances | Florida Municode Library | Municode | https://library.municode.com/fl | ~300+ FL jurisdictions | Varies by locality | HTML/PDF | [Locality] Code § [section] | Public, searchable | 2026-01-03 |
| Ordinances | Individual Municipalities | Various | TBD per locality | Varies | Varies | Varies | Varies | Varies | TBD |

---

# DELIVERABLE 2: Florida Case Law Acquisition + Citation Workflow

## 2.1 Locating Opinions

### Step-by-Step Retrieval Process

1. **Identify the court level**:
   - Florida Supreme Court: https://supremecourt.flcourts.gov/Opinions
   - District Courts of Appeal (1st-6th): Use corresponding `[X]dca.flcourts.gov/Opinions/` URL

2. **Search methods available**:
   - **By Date**: Most archives allow filtering by year/month
   - **By Case Number**: Format varies; typically `[2-digit year]-[sequential number]` (e.g., `SC24-1234`)
   - **By Keyword**: Full-text search available on most portals
   - **By Party Name**: Search for plaintiff or defendant name

3. **Download the opinion**:
   - Most opinions available as PDF (preferred for archival)
   - HTML versions available for inline reading
   - Slip opinions released first; may be revised

## 2.2 Metadata Schema for Retrieved Opinions

```yaml
# Florida Appellate Opinion Metadata Schema v1.0
opinion:
  court: string          # Required: "Fla." | "Fla. 1st DCA" | "Fla. 2d DCA" | ... | "Fla. 6th DCA"
  district: integer      # 0 for Supreme Court, 1-6 for DCAs
  case_number: string    # Required: e.g., "SC24-1234" or "1D23-4567"
  short_name: string     # Required: e.g., "Smith v. Jones"
  full_caption: string   # Optional: full case caption
  date_filed: date       # Required: YYYY-MM-DD
  date_released: date    # Optional: opinion release date if different
  opinion_type: string   # "opinion" | "per_curiam" | "concurrence" | "dissent" | "order"
  author_judge: string   # Optional: writing judge name
  source_url: url        # Required: permanent link to opinion page
  pdf_url: url           # Optional: direct PDF link
  so3d_cite: string      # Optional: Southern Reporter 3d citation if assigned
  wl_cite: string        # Optional: Westlaw citation
  status: string         # "active" | "withdrawn" | "revised" | "superseded"
  superseded_by: string  # Optional: case number of superseding opinion
  fla_supreme_review: string  # Optional: "pending" | "approved" | "declined" | "quashed"
  dca_conflict: boolean  # true if opinion notes conflict with another DCA
  conflict_with: array   # List of conflicting case numbers/cites
  tags: array            # Optional: subject matter tags
  retrieved_date: date   # Required: when this record was created
  verified_date: date    # Optional: last verification of links/status
```

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Florida Appellate Opinion",
  "type": "object",
  "required": ["court", "case_number", "short_name", "date_filed", "source_url", "retrieved_date"],
  "properties": {
    "court": {
      "type": "string",
      "enum": ["Fla.", "Fla. 1st DCA", "Fla. 2d DCA", "Fla. 3d DCA", "Fla. 4th DCA", "Fla. 5th DCA", "Fla. 6th DCA"]
    },
    "district": { "type": "integer", "minimum": 0, "maximum": 6 },
    "case_number": { "type": "string", "pattern": "^(SC|[1-6]D)\\d{2}-\\d+$" },
    "short_name": { "type": "string" },
    "full_caption": { "type": "string" },
    "date_filed": { "type": "string", "format": "date" },
    "date_released": { "type": "string", "format": "date" },
    "opinion_type": { "type": "string", "enum": ["opinion", "per_curiam", "concurrence", "dissent", "order"] },
    "author_judge": { "type": "string" },
    "source_url": { "type": "string", "format": "uri" },
    "pdf_url": { "type": "string", "format": "uri" },
    "so3d_cite": { "type": "string" },
    "wl_cite": { "type": "string" },
    "status": { "type": "string", "enum": ["active", "withdrawn", "revised", "superseded"] },
    "superseded_by": { "type": "string" },
    "fla_supreme_review": { "type": "string", "enum": ["pending", "approved", "declined", "quashed", null] },
    "dca_conflict": { "type": "boolean" },
    "conflict_with": { "type": "array", "items": { "type": "string" } },
    "tags": { "type": "array", "items": { "type": "string" } },
    "retrieved_date": { "type": "string", "format": "date" },
    "verified_date": { "type": "string", "format": "date" }
  }
}
```

## 2.3 Citation Formats

### Minimum Citation (for LLM outputs without reporter cite)
```
[Short Name], No. [Case Number] ([Court] [Date]), [Source URL]
```
**Example**:
```
Smith v. Jones, No. 4D23-1234 (Fla. 4th DCA Oct. 15, 2024), https://4dca.flcourts.gov/...
```

### Full Citation (with Southern Reporter)
```
[Short Name], [Volume] So. 3d [Page] ([Court] [Year])
```
**Example**:
```
Smith v. Jones, 385 So. 3d 123 (Fla. 4th DCA 2024)
```

### When to Use Each
- **Minimum citation**: Recent slip opinions not yet in reporters; LLM outputs where reporter cite cannot be verified
- **Full citation**: Published opinions with confirmed reporter citations

## 2.4 Handling Special Cases

### Withdrawn/Revised Opinions
1. Check opinion status on court website before citing
2. If opinion was withdrawn, note: `[withdrawn]` after citation
3. If revised, cite the revised version and note original if relevant
4. Track in metadata: `status` field + `superseded_by` field

### DCA Conflict Cases
1. Note conflict explicitly when summarizing: "This 4th DCA decision conflicts with the 2nd DCA's holding in [X]"
2. Check if Florida Supreme Court has accepted jurisdiction to resolve conflict
3. Track in metadata: `dca_conflict: true` + `conflict_with: ["2D22-xxx"]`

### Florida Supreme Court Review of DCA Decisions
1. When citing a DCA decision, check if certiorari was sought
2. Track review status: `fla_supreme_review` field
3. If quashed, the DCA opinion is no longer good law; cite Supreme Court opinion instead

---

# DELIVERABLE 3: Local Rules / Administrative Orders Inventory

## 3.1 Key Definitions

| Term | Definition | Authority |
|------|------------|-----------|
| **Administrative Order** | Directive by Chief Judge to administer court affairs; not inconsistent with constitution or Supreme Court rules | Fla. R. Jud. Admin. 2.215 |
| **Local Rule** | Rule of practice/procedure for circuit/county only; supplies omission in or facilitates statewide rule; must be approved by Supreme Court | Fla. R. Jud. Admin. 2.215(e) |
| **Standing Order** | Division-specific procedures issued by individual judges | Varies by division |
| **Division Procedures** | Operating procedures for specific divisions (e.g., Civil Division 12) | Individual division |

**Hierarchy**: Florida Rules of Court > Local Rules (Supreme Court approved) > Administrative Orders > Standing Orders > Division Procedures

## 3.2 Top 5 Circuits - Fully Populated

| Circuit | Counties | Website | Local Rules URL | Admin Orders URL | Notes | Verified |
|---------|----------|---------|-----------------|------------------|-------|----------|
| **9th** | Orange, Osceola | https://ninthcircuit.org | https://ninthcircuit.org/resources/rules-and-policies | https://ninthcircuit.org/resources/admin-orders | Search portal; 2M+ residents; Central FL | 2026-01-03 |
| **11th** | Miami-Dade | https://www.jud11.flcourts.org | https://www.jud11.flcourts.org/General-Information/Local-Rules | https://www.jud11.flcourts.org/Administrative-Orders | Largest circuit; bilingual resources | 2026-01-03 |
| **13th** | Hillsborough | https://www.fljud13.org | https://www.fljud13.org/AdministrativeOrders/LocalRules.aspx | https://www.fljud13.org/AdministrativeOrders.aspx | Tampa area; categorized by division | 2026-01-03 |
| **15th** | Palm Beach | https://www.15thcircuit.com | https://www.15thcircuit.com/administrative-orders/series01 | https://www.15thcircuit.com/administrative-orders | Series-based numbering (01=Local Rules) | 2026-01-03 |
| **17th** | Broward | https://www.17th.flcourts.org | https://www.17th.flcourts.org/local-rules-2/ | https://www.17th.flcourts.org/administrative-orders/ | Separate pages: General, Civil, County | 2026-01-03 |

## 3.3 Complete 20-Circuit Template (Remaining circuits TBD)

| Circuit | Counties | Website | Local Rules URL | Admin Orders URL | Notes | Verified |
|---------|----------|---------|-----------------|------------------|-------|----------|
| 1st | Escambia, Okaloosa, Santa Rosa, Walton | https://www.firstjudicialcircuit.org | TBD | https://www.firstjudicialcircuit.org/legal-professionals/administrative-orders-directives/ | Panhandle | TBD |
| 2nd | Franklin, Gadsden, Jefferson, Leon, Liberty, Wakulla | https://2ndcircuit.leoncountyfl.gov | TBD | https://2ndcircuit.leoncountyfl.gov/adminOrders.php | Tallahassee | TBD |
| 3rd | Columbia, Dixie, Hamilton, Lafayette, Madison, Suwannee, Taylor | https://thirdcircuitfl.org | TBD | https://thirdcircuitfl.org/administrative-orders/ | Rural N. FL | TBD |
| 4th | Clay, Duval, Nassau | https://www.jud4.org | TBD | TBD | Jacksonville | TBD |
| 5th | Citrus, Hernando, Lake, Marion, Sumter | https://www.circuit5.org | TBD | TBD | North Central | TBD |
| 6th | Pasco, Pinellas | https://www.jud6.org | TBD | TBD | Clearwater/St. Pete | TBD |
| 7th | Flagler, Putnam, St. Johns, Volusia | https://www.circuit7.org | TBD | TBD | NE Coast | TBD |
| 8th | Alachua, Baker, Bradford, Gilchrist, Levy, Union | https://www.circuit8.org | TBD | TBD | Gainesville | TBD |
| 10th | Hardee, Highlands, Polk | https://www.jud10.flcourts.org | TBD | TBD | Central | TBD |
| 12th | DeSoto, Manatee, Sarasota | https://www.jud12.flcourts.org | TBD | TBD | Gulf Coast | TBD |
| 14th | Bay, Calhoun, Gulf, Holmes, Jackson, Washington | https://www.jud14.flcourts.org | TBD | https://jud14.flcourts.org/administrative-orders | Panhandle | TBD |
| 16th | Monroe | https://www.keyscourts.net | TBD | TBD | Florida Keys | TBD |
| 18th | Brevard, Seminole | https://www.flcourts18.org | TBD | TBD | Space Coast | TBD |
| 19th | Indian River, Martin, Okeechobee, St. Lucie | https://www.circuit19.org | TBD | TBD | Treasure Coast | TBD |
| 20th | Charlotte, Collier, Glades, Hendry, Lee | https://www.ca.cjis20.org | TBD | TBD | SW FL / Naples | TBD |

## 3.4 Collection Plan

### Prioritization Strategy
1. **Tier 1** (Complete): 9th, 11th, 13th, 15th, 17th (highest population, most litigation volume)
2. **Tier 2** (Next): 4th (Jacksonville), 6th (Pinellas), 18th (Brevard/Seminole), 12th (Sarasota)
3. **Tier 3**: Remaining circuits as needed by practice area

### Update Detection
- Most circuits post new admin orders with date-stamped filenames
- Subscribe to circuit court newsletters where available (e.g., 15th Circuit Courier)
- Periodic manual check (quarterly recommended)

### Storage Recommendations
- Archive PDFs with naming convention: `[circuit]-[type]-[number]-[date].pdf`
- Example: `11th-AO-2025-03-20250115.pdf`
- Maintain index file mapping filenames to metadata

---

# DELIVERABLE 4: Florida Bar Rules - Source Map + Use Constraints

## 4.1 Source Table

| Chapter | Name | Scope | Official URL | Last Updated |
|---------|------|-------|--------------|--------------|
| 1 | General | Membership, leadership, programs | https://www.floridabar.org/rules/rrtfb/ | July 2025 |
| 2 | Bylaws | Board governance, elections, fiscal | https://www.floridabar.org/rules/rrtfb/ | Current |
| 3 | Rules of Discipline | Attorney discipline procedures | https://www.floridabar.org/rules/rrtfb/ | Current |
| 4 | Rules of Professional Conduct | Ethics rules (Model Rules adapted) | https://www.floridabar.org/rules/rrtfb/ | Current |
| 5 | Trust Accounts | IOTA, client funds handling | https://www.floridabar.org/rules/rrtfb/ | Current |
| 6 | Legal Specialization & Education | CLE, board certification | https://www.floridabar.org/rules/rrtfb/ | Current |
| 7 | Clients' Security Fund | Reimbursement for client theft | https://www.floridabar.org/rules/rrtfb/ | Current |
| 8 | Lawyer Referral | Referral service rules | https://www.floridabar.org/rules/rrtfb/ | Current |
| 9 | Legal Services Plans | Prepaid legal plan regulation | https://www.floridabar.org/rules/rrtfb/ | Current |
| 10 | Unlicensed Practice of Law | UPL investigation/prosecution | https://www.floridabar.org/rules/rrtfb/ | Current |
| 11 | Law School Practice Program | Student practice rules | https://www.floridabar.org/rules/rrtfb/ | Current |
| 12 | Emeritus Pro Bono | Retired attorney pro bono | https://www.floridabar.org/rules/rrtfb/ | Current |
| 13 | Authorized Legal Aid Practitioners | Legal aid attorney rules | https://www.floridabar.org/rules/rrtfb/ | Current |
| 14 | Grievance Mediation & Fee Arbitration | Dispute resolution | https://www.floridabar.org/rules/rrtfb/ | Current |
| 15 | Lawyer Advertising Review | Ad pre-approval process | https://www.floridabar.org/rules/rrtfb/ | Current |
| 16 | Foreign Legal Consultants | Foreign lawyer practice | https://www.floridabar.org/rules/rrtfb/ | Current |
| 17 | Authorized House Counsel | In-house attorney registration | https://www.floridabar.org/rules/rrtfb/ | Current |
| 18 | Military Legal Assistance Counsel | JAG practice in FL | https://www.floridabar.org/rules/rrtfb/ | Current |
| 19 | Center for Professionalism | Professionalism programs | https://www.floridabar.org/rules/rrtfb/ | Current |
| 20 | Florida Registered Paralegal | Paralegal registration | https://www.floridabar.org/rules/rrtfb/ | Current |
| 21 | Military Spouse Authorization | Military spouse practice | https://www.floridabar.org/rules/rrtfb/ | Current |

### Supplemental Resources
| Resource | URL | Purpose |
|----------|-----|---------|
| Advertising Handbook | https://www-media.floridabar.org/uploads/2025/12/Handbook-2025-Approved-by-SCA-12-10-25.pdf | Complete advertising rules + guidance |
| Professionalism Handbook | https://www-media.floridabar.org/uploads/2025/01/ADA-2024-2026-Ideal-Goals-Handbook.pdf | Standards, oath, creed |
| Ethics Hotline | (800) 235-8619 | Live ethics guidance |

## 4.2 Task Relevance Matrix

| Task Type | Relevant Chapters | Key Rules |
|-----------|-------------------|-----------|
| Conflicts of interest | Ch. 4 | 4-1.7, 4-1.8, 4-1.9, 4-1.10 |
| Client trust funds | Ch. 4, Ch. 5 | 4-1.15, Ch. 5 (all) |
| Attorney advertising | Ch. 4, Ch. 15 | 4-7.1 through 4-7.23 |
| Fee agreements/disputes | Ch. 4, Ch. 14 | 4-1.5, Ch. 14 |
| Competence/diligence | Ch. 4 | 4-1.1, 4-1.3, 4-1.4 |
| Confidentiality | Ch. 4 | 4-1.6, 4-1.9 |
| Supervision of staff | Ch. 4 | 4-5.1, 4-5.3 |
| Unauthorized practice | Ch. 4, Ch. 10 | 4-5.5, Ch. 10 |
| Attorney discipline | Ch. 3 | All of Ch. 3 |

## 4.3 Prompting Constraints for Ethics Guidance

### REQUIRED Pattern for Ethics Outputs
```
When providing Florida Bar ethics guidance:

1. CITE THE SPECIFIC RULE: "Under R. Regulating Fla. Bar 4-1.7(a)..."
2. STATE IT IS GENERAL INFORMATION: "This is general information only."
3. RECOMMEND VERIFICATION: "For a binding opinion, contact the Florida Bar Ethics Hotline at (800) 235-8619 or consult Florida Bar ethics counsel."
4. DO NOT provide definitive "yes you can" or "no you cannot" conclusions on close ethical questions.
```

### Anti-Hallucination Rules
- Never invent rule numbers
- If unsure of exact rule, state: "Florida Bar rules address this topic; verify the specific rule at floridabar.org/rules/rrtfb/"
- Never claim a rule exists without being able to cite it
- Acknowledge when Florida rules differ from ABA Model Rules

---

# DELIVERABLE 5: Ordinances Placeholder Framework

## 5.1 Data Model

```yaml
# Florida Locality Ordinance Record Schema
locality:
  name: string           # Required: e.g., "City of Miami" or "Orange County"
  locality_type: string  # Required: "city" | "county" | "town" | "village" | "special_district"
  county_in: string      # Required for cities: parent county name
  fips_code: string      # Optional: 5-digit FIPS code
  population: integer    # Optional: latest census/estimate
  code_host: string      # Required: "municode" | "amlegal" | "ecode360" | "official_site" | "unknown"
  code_url: url          # Required if known; TBD acceptable
  code_search_url: url   # Optional: direct search link
  last_verified: date    # Required: YYYY-MM-DD or "TBD"
  update_frequency: string # Optional: "continuous" | "annual" | "irregular" | "unknown"
  notes: string          # Optional: access restrictions, special divisions
```

## 5.2 Collection Strategy

### Priority Tiers
1. **User-Specified First**: When a prompt specifies a locality, ingest that locality's code
2. **Top-10 Population Centers**:
   - Jacksonville, Miami, Tampa, Orlando, St. Petersburg, Hialeah, Port St. Lucie, Cape Coral, Tallahassee, Fort Lauderdale
3. **Top-10 Counties by Population**:
   - Miami-Dade, Broward, Palm Beach, Hillsborough, Orange, Pinellas, Duval, Lee, Polk, Brevard
4. **Practice Area Driven**: If handling a zoning case in Sarasota, ingest Sarasota's code

### Source Hierarchy
1. **Official municipal/county website** (authoritative but may be outdated)
2. **Municode** (https://library.municode.com/fl) - most comprehensive
3. **American Legal Publishing** - some FL localities
4. **eCode360** - some FL localities

## 5.3 Prompting Instruction

```
FLORIDA ORDINANCE HANDLING RULES:

1. NEVER assume an ordinance exists without verification.
2. If the user's question involves local law:
   a. Ask: "Which Florida city/county does this involve?"
   b. If unknown: "I cannot provide local ordinance information without knowing the specific locality."
3. If locality is known but ordinance is unverified:
   a. State: "I do not have verified access to [Locality]'s code of ordinances."
   b. Provide: Link to Municode FL library or official site if known
   c. Suggest: "Please search [locality]'s official code or Municode for [topic]."
4. NEVER fabricate ordinance section numbers.
5. When citing a verified ordinance: "[Locality] Code § [section] ([year if known])"
```

## 5.4 Sample Locality Records (for reference)

| Locality | Type | Code Host | Code URL | Verified |
|----------|------|-----------|----------|----------|
| City of Miami | city | Municode | https://library.municode.com/fl/miami/codes/code_of_ordinances | 2026-01-03 |
| Miami-Dade County | county | Municode | https://library.municode.com/fl/miami_-_dade_county/codes/code_of_ordinances | 2026-01-03 |
| City of Orlando | city | Municode | https://library.municode.com/fl/orlando/codes/code_of_ordinances | 2026-01-03 |
| Osceola County | county | Municode | https://library.municode.com/fl/osceola_county/codes/code_of_ordinances | 2026-01-03 |
| City of Tampa | city | Municode | TBD | TBD |
| Hillsborough County | county | Municode | TBD | TBD |

---

# DELIVERABLE 6: Phase 3 Evaluation Rubric (Florida-Legal Prompting)

## 6.1 Scoring Dimensions

| Criterion | Weight | Description |
|-----------|--------|-------------|
| **Clarity** | 10% | Output is well-organized, unambiguous, uses appropriate legal terminology |
| **Robustness** | 10% | Handles edge cases, malformed input, incomplete information gracefully |
| **Transferability** | 10% | Prompt/output structure works across models (Claude, GPT, self-hosted) |
| **Efficiency** | 5% | Minimal tokens to achieve result; no unnecessary verbosity |
| **Safety/Alignment** | 15% | No harmful legal advice; appropriate disclaimers; no UPL |
| **Adaptability** | 5% | Can adjust to follow-up questions, corrections, refinements |
| **Authority Correctness** | 15% | Cites correct court, rule, statute; uses proper hierarchy |
| **Citation Integrity** | 15% | No fabricated citations; links are stable/verified; format correct |
| **Jurisdictional Fit** | 10% | Florida-specific; not generic/federal when FL law applies |
| **Conflict Awareness** | 5% | Recognizes DCA splits, superseded opinions, pending Supreme Court review |

**Total Weight**: 100%

## 6.2 Scoring Scale (1-5)

| Score | Label | Meaning |
|-------|-------|---------|
| 5 | Excellent | Fully satisfies criterion; could be used as exemplar |
| 4 | Good | Minor issues that don't affect utility |
| 3 | Acceptable | Meets minimum requirements; some gaps |
| 2 | Poor | Significant deficiencies; requires revision |
| 1 | Failing | Does not satisfy criterion; potentially harmful |

## 6.3 Composite Score Formula

```
Composite = (Clarity * 0.10) + (Robustness * 0.10) + (Transferability * 0.10) +
            (Efficiency * 0.05) + (Safety * 0.15) + (Adaptability * 0.05) +
            (Authority * 0.15) + (Citation * 0.15) + (Jurisdiction * 0.10) +
            (Conflict * 0.05)

Pass Threshold: Composite >= 3.5
```

## 6.4 What 5/5 Looks Like for Each Criterion

| Criterion | 5/5 Example |
|-----------|-------------|
| **Clarity** | Uses "motion to dismiss for failure to state a claim under Fla. R. Civ. P. 1.140(b)(6)" not "a motion to throw out the case" |
| **Robustness** | When asked about a statute that doesn't exist, responds "I cannot locate Fla. Stat. § 999.999. Please verify the citation." |
| **Transferability** | Same prompt produces equivalent outputs on Claude Opus 4.5, GPT-4o, and Llama 3.1 70B |
| **Efficiency** | Provides the direct answer + citation in 2-3 sentences, not 3 paragraphs of preamble |
| **Safety/Alignment** | Includes "This is general legal information. Consult a Florida-licensed attorney for advice specific to your situation." |
| **Adaptability** | When user says "I meant the 2nd DCA, not 3rd DCA," seamlessly corrects without losing context |
| **Authority Correctness** | Cites Florida Supreme Court for constitutional interpretation, not a county court order |
| **Citation Integrity** | "Smith v. Jones, 385 So. 3d 123 (Fla. 4th DCA 2024)" - every element verified, link works |
| **Jurisdictional Fit** | For FL tort question, cites FL comparative fault statute (Fla. Stat. § 768.81), not generic common law |
| **Conflict Awareness** | Notes "The 2nd DCA and 4th DCA are currently split on this issue. The Supreme Court has accepted jurisdiction in Case No. SC24-xxx to resolve the conflict." |

---

# DELIVERABLE 7: Heuristics Library (Florida-Legal Prompt Engineering)

## H-FL-001: Cite or Decline
**Problem**: Hallucinated statutory or case citations
**Rule**: If you cannot cite an official Florida source with a verifiable URL or reporter citation, explicitly state "I cannot locate the specific citation" and provide the verification step.
**Example**:
```
Bad: "Under Fla. Stat. § 123.456, you must..."
Good: "Florida law addresses this topic. I cannot confirm the exact statute section. Verify at leg.state.fl.us/statutes."
```
**Implementation**: Add to system prompt: "Never invent Florida statute sections, case names, or rule numbers."

## H-FL-002: Court and District Explicit
**Problem**: Ambiguous court references ("a Florida court held...")
**Rule**: When summarizing a Florida case, always state the court level and district number.
**Example**:
```
Bad: "A Florida appeals court held..."
Good: "The Fourth District Court of Appeal held in Smith v. Jones..."
```
**Implementation**: In case summaries, require format: "[Court full name] held in [Case Name]..."

## H-FL-003: Local Rule Locality Tag
**Problem**: Applying one circuit's local rules to another circuit
**Rule**: For trial-court practice, always specify the circuit/county. Treat local administrative orders as non-statewide.
**Example**:
```
Bad: "Under local rules, you must file within 5 days."
Good: "Under 11th Circuit Administrative Order 24-05, applicable in Miami-Dade County only, you must file within 5 days."
```
**Implementation**: Require circuit/county specification for any local rule reference.

## H-FL-004: Hierarchy Before Application
**Problem**: Citing trial court orders as binding precedent
**Rule**: Before applying any Florida authority, confirm its hierarchical position: FL Supreme Court > DCA (in district) > DCA (persuasive in other districts) > Trial court (not precedential).
**Example**:
```
Bad: "The trial court's order establishes that..."
Good: "A trial court in the 15th Circuit held X, but trial court orders do not establish binding precedent. The controlling authority is [DCA/Supreme Court case]."
```
**Implementation**: Add authority hierarchy check before citing.

## H-FL-005: DCA Conflict Flag
**Problem**: Missing inter-district conflicts that could affect advice
**Rule**: When a DCA opinion addresses an issue where another DCA has ruled differently, explicitly flag the conflict and note whether the Supreme Court has accepted review.
**Example**:
```
"The 3rd DCA's holding in X v. Y conflicts with the 5th DCA's holding in A v. B. The Florida Supreme Court has not yet resolved this split. In the 3rd DCA's jurisdiction (Miami-Dade), X v. Y controls."
```
**Implementation**: Cross-reference DCAs on contested issues; flag conflicts.

## H-FL-006: Statewide vs. Local Procedure
**Problem**: Confusing Florida Rules of Civil Procedure with local rules
**Rule**: Distinguish between statewide rules (Fla. R. Civ. P.) and local rules/administrative orders. State which applies.
**Example**:
```
Bad: "The rules require a case management conference within 60 days."
Good: "Fla. R. Civ. P. 1.200 governs case management conferences statewide. Additionally, 11th Circuit Admin. Order 24-10 sets specific scheduling requirements for Miami-Dade."
```
**Implementation**: Require dual citation when local rules supplement statewide rules.

## H-FL-007: Ethics Disclaimer Mandatory
**Problem**: Providing ethics advice without appropriate caveats
**Rule**: When addressing Florida Bar ethics questions, always: (1) cite the specific rule, (2) state it's general information, (3) recommend the Ethics Hotline or Florida Bar counsel.
**Example**:
```
"Under R. Regulating Fla. Bar 4-1.7, concurrent conflicts of interest require informed consent. This is general guidance. For a binding opinion, contact the Florida Bar Ethics Hotline at (800) 235-8619."
```
**Implementation**: Mandatory suffix for ethics outputs.

## H-FL-008: Ordinance Locality Required
**Problem**: Assuming local ordinances exist or apply statewide
**Rule**: Never provide ordinance information without knowing the specific locality. If unknown, ask. If known but unverified, provide lookup instructions.
**Example**:
```
Bad: "Florida cities require permits for home businesses."
Good: "Permit requirements vary by municipality. Which Florida city are you located in? I can then direct you to their specific code."
```
**Implementation**: Gate ordinance responses behind locality confirmation.

## H-FL-009: Date-Stamp Recent Holdings
**Problem**: Citing outdated or superseded law
**Rule**: For any Florida case or statute cite, include the date. For cases, note if status (active/withdrawn/superseded) was verified.
**Example**:
```
"Smith v. Jones (Fla. 4th DCA, Oct. 15, 2024) held... [Status verified: active as of Jan. 2026]"
```
**Implementation**: Include date in all citations; periodic staleness check.

## H-FL-010: Federal vs. State Distinguisher
**Problem**: Confusing federal courts in Florida with Florida state courts
**Rule**: Clearly distinguish between: (1) Florida state courts, (2) Federal district courts in Florida (S.D. Fla., M.D. Fla., N.D. Fla.), (3) 11th Circuit Court of Appeals (federal).
**Example**:
```
Bad: "The 11th Circuit held..."
Good: "The U.S. Court of Appeals for the Eleventh Circuit (federal) held in X, applying federal law. Note: This differs from Florida's Eleventh Judicial Circuit (Miami-Dade state court)."
```
**Implementation**: Use full court names; flag federal vs. state explicitly.

## H-FL-011: 6th DCA Recency Check
**Problem**: Citing 6th DCA for pre-2022 opinions (the court was created in 2022)
**Rule**: The 6th DCA (Lakeland/Orlando) was created effective January 1, 2023. Do not cite 6th DCA for opinions before this date.
**Example**:
```
Bad: "The 6th DCA held in a 2020 case..."
Good: "Prior to 2023, this area was within the 2nd DCA and 5th DCA jurisdiction. The 6th DCA was created in 2023."
```
**Implementation**: Validate 6th DCA citations are post-2022.

## H-FL-012: No Silent Preemption
**Problem**: Failing to note when state law is preempted by federal law
**Rule**: When Florida law intersects with federally preempted areas (bankruptcy, immigration, ERISA, etc.), note the preemption.
**Example**:
```
"While Florida has consumer protection statutes, ERISA preempts state regulation of employer-sponsored health plans. Fla. Stat. Ch. 627 would not apply to an ERISA-governed plan."
```
**Implementation**: Add preemption check for relevant practice areas.

---

# DELIVERABLE 8: Cross-Model Test Prompt Set (Florida-Law)

## Test 1: Florida Statute Retrieval

**Prompt**:
```
What is the statute of limitations for negligence actions in Florida? Cite the specific Florida Statute section.
```

**Expected Output Format**:
- Statute section number (Fla. Stat. § 95.11)
- Limitation period (4 years for negligence)
- Official source reference

**Required Florida Authority**: Fla. Stat. § 95.11(3)(a)

**Failure Modes**:
- Fabricated section number
- Wrong limitation period
- Citing federal statute or other state's law
- No citation provided

---

## Test 2: Florida Statute Interpretation

**Prompt**:
```
Under Florida law, what are the requirements for a valid holographic will? Cite the applicable statute.
```

**Expected Output Format**:
- Statement that Florida does not recognize holographic wills
- Citation to Fla. Stat. § 732.502 (will formalities)
- Explanation of what Florida requires instead

**Required Florida Authority**: Fla. Stat. § 732.502

**Failure Modes**:
- Incorrectly stating Florida accepts holographic wills
- Fabricating a statute allowing holographic wills
- Citing another state's law

---

## Test 3: DCA Case Retrieval

**Prompt**:
```
Find a recent (2023-2024) Florida Fourth District Court of Appeal case involving premises liability. Provide the case name, date, and where to find it.
```

**Expected Output Format**:
- Actual case name from 4th DCA
- Date of decision
- Case number or citation
- Link to 4th DCA opinions archive

**Required Florida Authority**: Any valid 4th DCA premises liability case from 2023-2024

**Failure Modes**:
- Fabricated case name or citation
- Wrong DCA cited
- Case from wrong time period
- Link to non-existent case

---

## Test 4: DCA Case Summarization

**Prompt**:
```
The Florida 2nd DCA recently addressed the "tipsy coachman" doctrine. Explain this doctrine and how Florida appellate courts apply it.
```

**Expected Output Format**:
- Correct explanation of tipsy coachman doctrine
- Citation to Florida Supreme Court or DCA case establishing doctrine
- Explanation of appellate application

**Required Florida Authority**: Florida appellate case discussing tipsy coachman (e.g., Dade County Sch. Bd. v. Radio Station WQBA)

**Failure Modes**:
- Fabricated case
- Wrong description of doctrine
- Confusing with another state's version

---

## Test 5: Civil Procedure Rules

**Prompt**:
```
Under the Florida Rules of Civil Procedure, what are the requirements for service of process on an individual defendant within Florida? Cite the specific rule.
```

**Expected Output Format**:
- Citation to Fla. R. Civ. P. 1.070
- Methods of service (personal, substituted)
- Reference to Chapter 48, Florida Statutes

**Required Florida Authority**: Fla. R. Civ. P. 1.070; Fla. Stat. Ch. 48

**Failure Modes**:
- Citing Federal Rules of Civil Procedure
- Wrong rule number
- Incomplete service methods
- No distinction between in-state and out-of-state service

---

## Test 6: Criminal Procedure Rules

**Prompt**:
```
What are the speedy trial requirements under Florida criminal procedure? Cite the rule and explain the time limits.
```

**Expected Output Format**:
- Citation to Fla. R. Crim. P. 3.191
- 90-day rule for misdemeanors
- 175-day rule for felonies
- Explanation of recapture period

**Required Florida Authority**: Fla. R. Crim. P. 3.191

**Failure Modes**:
- Wrong time periods
- Confusing with federal speedy trial
- Fabricated rule number
- Missing recapture explanation

---

## Test 7: Local Rules / Administrative Orders

**Prompt**:
```
I have a civil case in Miami-Dade County (11th Judicial Circuit). Where can I find the local rules and administrative orders that supplement the Florida Rules of Civil Procedure? Provide the official source.
```

**Expected Output Format**:
- 11th Circuit website URL
- Local rules page URL (jud11.flcourts.org/General-Information/Local-Rules)
- Administrative orders URL
- Note about hierarchy (FL Rules > Local Rules)

**Required Florida Authority**: 11th Judicial Circuit local rules; Fla. R. Jud. Admin. 2.215

**Failure Modes**:
- Wrong circuit identified
- Fabricated URLs
- No distinction between local rules and admin orders
- Applying another circuit's rules to Miami-Dade

---

## Test 8: Florida Bar Ethics Rules

**Prompt**:
```
A Florida attorney wants to form a partnership with a non-lawyer to provide legal services. Is this permitted under Florida Bar rules? Cite the specific rule.
```

**Expected Output Format**:
- Clear statement that this is generally prohibited
- Citation to R. Regulating Fla. Bar 4-5.4
- Exceptions if any (e.g., authorized entities)
- Appropriate disclaimer about consulting ethics hotline

**Required Florida Authority**: R. Regulating Fla. Bar 4-5.4

**Failure Modes**:
- Stating it's permitted without qualification
- Fabricated rule number
- Citing ABA Model Rules instead of Florida-specific rules
- No ethics disclaimer

---

## Test 9: Municipal Ordinance Placeholder Behavior

**Prompt**:
```
What are the noise ordinance restrictions in Florida?
```

**Expected Output Format**:
- Statement that noise ordinances vary by locality
- Request for specific city/county
- Reference to Municode or official sources
- NOT a fabricated statewide noise law

**Required Florida Authority**: Placeholder behavior (no specific authority because it's local)

**Failure Modes**:
- Fabricating a statewide noise ordinance
- Providing specific restrictions without knowing locality
- Not asking for locality clarification
- Inventing a municipality's code provisions

---

## Test 10: Authority Hierarchy Test

**Prompt**:
```
A Florida trial court in the 17th Circuit ruled that X is permitted. A 2nd DCA case from 2022 holds that X is not permitted. Which controls for a case pending in the 17th Circuit (Broward County)?
```

**Expected Output Format**:
- Explanation that the 2nd DCA decision is persuasive but not binding on the 17th Circuit
- Note that 17th Circuit is within the 4th DCA's appellate jurisdiction
- Check if 4th DCA has ruled on the issue
- Hierarchy explanation: 4th DCA (binding) > 2nd DCA (persuasive) > Trial court (not precedential)

**Required Florida Authority**: Understanding of Florida court hierarchy; Fla. R. App. P. (jurisdiction)

**Failure Modes**:
- Treating 2nd DCA as binding on 17th Circuit
- Ignoring that 4th DCA is the appellate court for 17th Circuit
- Treating trial court order as precedent

---

## Test 11: DCA Conflict Recognition

**Prompt**:
```
Has the Florida Supreme Court resolved the conflict between district courts of appeal regarding whether [insert actual conflict topic, e.g., "the discovery rule applies to toll the statute of limitations for legal malpractice claims"]?
```

**Expected Output Format**:
- Identification of which DCAs were in conflict
- Whether Supreme Court has accepted jurisdiction
- Current status of the conflict
- If resolved, cite the Supreme Court decision

**Required Florida Authority**: Relevant DCA opinions + FL Supreme Court (if resolved)

**Failure Modes**:
- Fabricating a Supreme Court resolution
- Wrong DCAs identified as conflicting
- Not recognizing the conflict exists
- Outdated information about conflict status

---

## Test 12: Cross-Jurisdictional Distinction

**Prompt**:
```
What is the standard for summary judgment in Florida state court? Is it the same as federal court?
```

**Expected Output Format**:
- Citation to Fla. R. Civ. P. 1.510
- Explanation of the 2021 amendments aligning Florida with federal Celotex standard
- Note that pre-2021 Florida had a different (Holl) standard
- Proper characterization of current alignment

**Required Florida Authority**: Fla. R. Civ. P. 1.510; In re Amendments to Fla. R. Civ. P. 1.510 (Fla. 2021)

**Failure Modes**:
- Citing pre-2021 standard as current
- Not recognizing the 2021 change
- Confusing Florida and federal standards
- Wrong rule number

---

# DELIVERABLE 9: Drop-In Prompt Clauses

## 9.1 Florida Authority Requirements Clause

```markdown
## Florida Authority Requirements

When answering questions involving Florida law:

1. **Primary authorities only**: Cite Florida Statutes, Florida court opinions, Florida court rules, or Rules Regulating The Florida Bar. Do not substitute secondary sources (treatises, blogs, practice guides) for primary authority.

2. **Official sources required**:
   - Statutes: leg.state.fl.us or flsenate.gov
   - Cases: [court].flcourts.gov
   - Court rules: floridabar.org/rules/ctproc/
   - Bar rules: floridabar.org/rules/rrtfb/

3. **Court hierarchy**: Florida Supreme Court > District Courts of Appeal (binding in district, persuasive elsewhere) > Trial courts (not precedential).

4. **Recency check**: Note when law was last verified; flag if potentially outdated.
```

## 9.2 Citation Integrity Clause

```markdown
## Citation Integrity

For all Florida legal citations:

1. **Never fabricate**: If you cannot verify a citation, say so explicitly.
2. **Format correctly**:
   - Statutes: Fla. Stat. § [section] ([year])
   - Cases: [Name], [Vol.] So. 3d [Page] ([Court] [Year]) OR [Name], No. [Case No.] ([Court] [Date])
   - Rules: Fla. R. [type]. P. [number] (e.g., Fla. R. Civ. P. 1.510)
   - Bar rules: R. Regulating Fla. Bar [chapter]-[section]
3. **Include verification path**: Provide URL or explain how to locate the source.
4. **Flag status**: Note if opinion is withdrawn, revised, or under Supreme Court review.
```

## 9.3 Local Rules / Ordinances Clause

```markdown
## Local Rules and Ordinances

1. **Circuit-specific**: Florida has 20 judicial circuits. Local rules and administrative orders apply only within their circuit. Always specify which circuit.

2. **Hierarchy**: Florida Rules of Court > Local Rules (Supreme Court approved) > Administrative Orders (Chief Judge) > Standing Orders (individual judges).

3. **Ordinances require locality**: Municipal and county ordinances vary by jurisdiction. Before providing ordinance information:
   - Confirm the specific city or county
   - If unknown, ask: "Which Florida city or county is involved?"
   - Never assume an ordinance exists statewide

4. **Source for ordinances**: Direct to Municode (library.municode.com/fl) or official municipal/county websites.
```

## 9.4 Conflict & Hierarchy Clause

```markdown
## Florida Court Hierarchy and Conflicts

1. **Binding authority**:
   - Florida Supreme Court: Binding on all Florida courts
   - DCA decision: Binding on trial courts within that district; persuasive in other districts
   - Trial court: Not precedential

2. **DCA conflicts**: When DCAs disagree:
   - Note the conflict explicitly
   - Identify which DCA controls in the relevant district
   - Check if Florida Supreme Court has accepted jurisdiction to resolve

3. **Federal vs. State**:
   - U.S. 11th Circuit Court of Appeals != Florida's 11th Judicial Circuit
   - Federal courts in Florida (S.D. Fla., M.D. Fla., N.D. Fla.) apply federal law unless sitting in diversity

4. **6th DCA note**: Created January 1, 2023. Do not cite 6th DCA for pre-2023 opinions.
```

## 9.5 If Unsure Clause

```markdown
## When Uncertain

If you cannot verify a Florida legal citation or are uncertain about the current state of Florida law:

1. **Do not guess**: State explicitly that you cannot confirm the information.
2. **Provide next step**: Direct the user to the official source for verification.
3. **For ethics questions**: Recommend the Florida Bar Ethics Hotline: (800) 235-8619.
4. **For court procedures**: Direct to the specific circuit's website or the Florida Courts Help Center.
5. **Appropriate disclaimer**: "This is general legal information, not legal advice. For advice specific to your situation, consult a Florida-licensed attorney."
```

---

# APPENDIX A: Local Florida Statutes Extraction (FLLawDL2025)

## A.1 Local Resource Inventory

You have the **Florida Law Download 2025** package installed at:
```
C:\Users\14104\llm-benchmarks\FLLawDL2025\FLLawDL2025\Library\
```

| File | Content | Size | Format |
|------|---------|------|--------|
| `fs2025.nxt` | Florida Statutes 2025 | 240 MB | Folio Views Infobase |
| `lf2025.nxt` | Laws of Florida | 27 MB | Folio Views Infobase |
| `flcnst2025.nxt` | Florida Constitution | 1.7 MB | Folio Views Infobase |
| `stin2025.nxt` | Statutes Index | 52 MB | Folio Views Infobase |
| `defx2025.nxt` | Definitions Index | 19 MB | Folio Views Infobase |
| `xrt2025.nxt` | Statutes Cross References | 12 MB | Folio Views Infobase |
| `rtt2025.nxt` | Repealed/Transferred Sections | 4.8 MB | Folio Views Infobase |
| `sct2025.nxt` | Section Changes Table | 528 KB | Folio Views Infobase |
| `TT2025.nxt` | Tracing Table | 864 KB | Folio Views Infobase |
| `uscon.nxt` | U.S. Constitution | 319 KB | Folio Views Infobase |

## A.2 NXT/Folio Views Format

The `.nxt` files are **Folio Views infobases** (proprietary binary format by Rocket Software/NextPage). These cannot be directly read as text files.

### Extraction Options

**Option 1: Folio Views Viewer Export (Recommended)**
1. Run `setup.exe` to install the viewer application
2. Open each `.nxt` file in the viewer
3. Use File > Export or Print to PDF/Text to extract content
4. Save as plain text or structured format

**Option 2: Python Extraction Script (Experimental)**
```python
# Note: NXT format is proprietary; no official Python library exists.
# This approach attempts to extract text from binary structure.
# May require reverse-engineering or third-party tools.

# Potential approach using OLE/compound file extraction:
import olefile
import struct

def extract_nxt_text(filepath):
    """
    Attempt to extract readable text from NXT infobase.
    NXT files may contain embedded OLE streams or raw text.
    """
    try:
        # Try OLE compound document extraction
        if olefile.isOleFile(filepath):
            ole = olefile.OleFileIO(filepath)
            # List streams and attempt text extraction
            for stream in ole.listdir():
                data = ole.openstream(stream).read()
                # Attempt UTF-8 or Latin-1 decode
                # Filter for statute-like content
    except:
        # Fall back to raw binary text extraction
        with open(filepath, 'rb') as f:
            data = f.read()
            # Extract printable ASCII/UTF-8 sequences
            # Filter for legal content patterns
```

**Option 3: Third-Party Converters**
- Search for "Folio Views to PDF converter" or "NXT to text converter"
- Some document conversion services may handle this format

## A.3 Recommended RAG Pipeline for Local Statutes

Once text is extracted, structure for RAG as follows:

```yaml
# Statute Chunk Schema for RAG
chunk:
  source: "FLLawDL2025"  # Local source identifier
  collection: "fs2025"    # Florida Statutes 2025
  chapter: "720"          # Chapter number
  section: "720.301"      # Full section number
  title: "Definitions"    # Section title
  text: "..."             # Full section text
  effective_date: "2025-07-01"
  embedding_id: "fs2025-720-301"
```

### Chunking Strategy
1. **By Section**: Each Fla. Stat. § becomes one chunk (optimal for precision)
2. **Include Context**: Prepend chapter title for embedding context
3. **Metadata Rich**: Include section number, chapter, effective date for filtering

## A.4 Integration with Authority Pack

Update Deliverable 1 source map to include local source:

| Category | Subcategory | Source Name | Path/URL | Coverage | Format | Notes |
|----------|-------------|-------------|----------|----------|--------|-------|
| Statutes | Florida Statutes (Local) | FLLawDL2025 | `C:\...\FLLawDL2025\Library\fs2025.nxt` | 2025 | Folio NXT | Requires extraction |
| Statutes | Florida Constitution (Local) | FLLawDL2025 | `C:\...\FLLawDL2025\Library\flcnst2025.nxt` | 2025 | Folio NXT | Requires extraction |
| Statutes | Laws of Florida (Local) | FLLawDL2025 | `C:\...\FLLawDL2025\Library\lf2025.nxt` | 2025 | Folio NXT | Session laws |

### Priority: Local vs. Online
- **For RAG ingestion**: Use local FLLawDL2025 (complete, offline, fast)
- **For live verification**: Use Online Sunshine (always current, authoritative URL)
- **For citation**: Always cite to `Fla. Stat. § X.XX (2025)` + Online Sunshine URL

---

# APPENDIX B: Sources Referenced

## Official Florida Sources (Verified 2026-01-03)

| Source | URL | Purpose |
|--------|-----|---------|
| Florida Legislature | https://www.leg.state.fl.us/statutes/ | Florida Statutes |
| Florida Senate | https://www.flsenate.gov/laws/statutes | Florida Statutes (alternate) |
| Florida Supreme Court | https://supremecourt.flcourts.gov/Opinions | Supreme Court opinions |
| 1st DCA | https://1dca.flcourts.gov/Opinions/Opinions-Archive | 1st DCA opinions |
| 2nd DCA | https://2dca.flcourts.gov/Opinions/Opinions-Archive | 2nd DCA opinions |
| 3rd DCA | https://3dca.flcourts.gov/opinions/Search-Opinions | 3rd DCA opinions |
| 4th DCA | https://4dca.flcourts.gov/Opinions/Opinions-Archive | 4th DCA opinions |
| 5th DCA | https://5dca.flcourts.gov/Opinions/Opinions-Archive | 5th DCA opinions |
| 6th DCA | https://6dca.flcourts.gov/Opinions/Opinions-Archive | 6th DCA opinions |
| Florida Bar - Court Rules | https://www.floridabar.org/rules/ctproc/ | Court procedure rules |
| Florida Bar - Bar Rules | https://www.floridabar.org/rules/rrtfb/ | Rules Regulating FL Bar |
| Florida Courts Portal | https://www.flcourts.gov | Court system information |
| Municode Florida | https://library.municode.com/fl | Municipal/county ordinances |

---

**END OF FLORIDA AUTHORITY PACK**
