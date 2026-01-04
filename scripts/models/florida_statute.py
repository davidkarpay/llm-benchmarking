#!/usr/bin/env python3
"""
Florida Statute data models for structure-aware RAG chunking.

Preserves the hierarchical structure of Florida Statutes:
Title (I-XLIX) → Chapter (1-999) → Section (XXX.XXX) → Subsection ((1), (2)) → Paragraph ((a), (b))
"""

from dataclasses import dataclass, field, asdict
from typing import List, Optional
import hashlib
import json
import re


@dataclass
class Subsection:
    """Represents a subsection within a Florida Statute section."""
    number: str                     # "(1)", "(2)(a)", "(2)(a)1."
    text: str                       # Content at this level
    parent: Optional[str] = None    # Parent subsection if nested

    def to_dict(self) -> dict:
        return {k: v for k, v in asdict(self).items() if v is not None}


@dataclass
class FloridaStatute:
    """
    Represents a complete Florida Statute section with full hierarchy and metadata.

    Example citation: Fla. Stat. § 718.112 (2025)
    """
    # Hierarchy
    title_number: str = ""          # Roman numeral (e.g., "XXVIII")
    title_name: str = ""            # e.g., "NATURAL RESOURCES; CONSERVATION"
    chapter_number: str = ""        # e.g., "718"
    chapter_name: str = ""          # e.g., "Condominiums"
    section_number: str = ""        # e.g., "718.112"
    section_title: str = ""         # e.g., "Bylaws"

    # Content
    full_text: str = ""             # Complete section text
    subsections: List[Subsection] = field(default_factory=list)

    # Metadata
    source_url: str = ""            # leg.state.fl.us link
    effective_date: Optional[str] = None
    year: str = "2025"              # Statute year

    # Cross-references (extracted from text)
    statute_refs: List[str] = field(default_factory=list)
    rule_refs: List[str] = field(default_factory=list)
    constitutional_refs: List[str] = field(default_factory=list)

    @property
    def standard_citation(self) -> str:
        """Generate standard Florida Bluebook citation."""
        if self.section_number:
            return f"Fla. Stat. § {self.section_number} ({self.year})"
        elif self.chapter_number:
            return f"Fla. Stat. ch. {self.chapter_number} ({self.year})"
        return ""

    @property
    def content_hash(self) -> str:
        """SHA1 hash of full_text for version tracking."""
        return hashlib.sha1(self.full_text.encode('utf-8')).hexdigest()

    @property
    def id(self) -> str:
        """Generate unique identifier for this statute."""
        section = self.section_number.replace(".", "-") if self.section_number else self.chapter_number
        return f"fla-stat-{section}"

    def to_chunk(self) -> dict:
        """Convert to JSONL chunk format for RAG."""
        return {
            "id": self.id,
            "type": "statute_section",
            "citation": self.standard_citation,
            "hierarchy": {
                "title": {"number": self.title_number, "name": self.title_name},
                "chapter": {"number": self.chapter_number, "name": self.chapter_name},
                "section": {"number": self.section_number, "title": self.section_title}
            },
            "content": self.full_text,
            "subsections": [s.to_dict() for s in self.subsections],
            "cross_refs": {
                "statutes": self.statute_refs,
                "rules": self.rule_refs,
                "constitution": self.constitutional_refs
            },
            "content_hash": self.content_hash,
            "tokens": len(self.full_text.split())  # Approximate token count
        }

    def to_json(self) -> str:
        """Serialize to JSON string."""
        return json.dumps(self.to_chunk(), ensure_ascii=False)


# Cross-reference extraction patterns
CROSS_REF_PATTERNS = {
    'statute': re.compile(
        r'(?:§|s\.|section|ss\.)\s*(\d{1,3}\.\d{2,5}(?:\(\d+\)(?:\([a-z]\))?)?)',
        re.IGNORECASE
    ),
    'chapter': re.compile(
        r'(?:chapter|ch\.)\s*(\d{1,3})',
        re.IGNORECASE
    ),
    'rule_civil': re.compile(
        r'(?:Fla\.?\s*R\.?\s*Civ\.?\s*P\.?|Florida\s+Rules?\s+of\s+Civil\s+Procedure)\s*(\d+\.\d+)',
        re.IGNORECASE
    ),
    'rule_criminal': re.compile(
        r'(?:Fla\.?\s*R\.?\s*Crim\.?\s*P\.?|Florida\s+Rules?\s+of\s+Criminal\s+Procedure)\s*(\d+\.\d+)',
        re.IGNORECASE
    ),
    'rule_appellate': re.compile(
        r'(?:Fla\.?\s*R\.?\s*App\.?\s*P\.?)\s*(\d+\.\d+)',
        re.IGNORECASE
    ),
    'rule_evidence': re.compile(
        r'(?:§\s*90\.\d+|section\s+90\.\d+)',
        re.IGNORECASE
    ),
    'constitution_fla': re.compile(
        r'(?:Fla\.?\s*Const\.?|Florida\s+Constitution)\s*,?\s*art\.?\s*([IVXLC]+),?\s*§?\s*(\d+)',
        re.IGNORECASE
    ),
    'constitution_us': re.compile(
        r'(?:U\.?S\.?\s*Const\.?|United\s+States\s+Constitution)',
        re.IGNORECASE
    ),
}

# Subsection parsing patterns
SUBSECTION_PATTERNS = {
    'level1': re.compile(r'^\s*\((\d+)\)\s*', re.MULTILINE),           # (1), (2), etc.
    'level2': re.compile(r'^\s*\(([a-z])\)\s*', re.MULTILINE),         # (a), (b), etc.
    'level3': re.compile(r'^\s*(\d+)\.\s*', re.MULTILINE),             # 1., 2., etc.
    'level4': re.compile(r'^\s*([a-z])\.\s*', re.MULTILINE),           # a., b., etc.
}


def extract_cross_references(text: str) -> dict:
    """
    Extract all cross-references from statute text.

    Returns:
        dict with keys 'statutes', 'rules', 'constitution'
    """
    refs = {
        'statutes': [],
        'rules': [],
        'constitution': []
    }

    # Extract statute references
    for match in CROSS_REF_PATTERNS['statute'].finditer(text):
        ref = f"§ {match.group(1)}"
        if ref not in refs['statutes']:
            refs['statutes'].append(ref)

    # Extract chapter references
    for match in CROSS_REF_PATTERNS['chapter'].finditer(text):
        ref = f"ch. {match.group(1)}"
        if ref not in refs['statutes']:
            refs['statutes'].append(ref)

    # Extract rule references
    for pattern_name in ['rule_civil', 'rule_criminal', 'rule_appellate']:
        for match in CROSS_REF_PATTERNS[pattern_name].finditer(text):
            rule_type = pattern_name.replace('rule_', '').title()
            ref = f"Fla. R. {rule_type}. P. {match.group(1)}"
            if ref not in refs['rules']:
                refs['rules'].append(ref)

    # Extract constitutional references
    for match in CROSS_REF_PATTERNS['constitution_fla'].finditer(text):
        ref = f"Fla. Const. art. {match.group(1)}, § {match.group(2)}"
        if ref not in refs['constitution']:
            refs['constitution'].append(ref)

    if CROSS_REF_PATTERNS['constitution_us'].search(text):
        if "U.S. Const." not in refs['constitution']:
            refs['constitution'].append("U.S. Const.")

    return refs


def parse_subsections(text: str) -> List[Subsection]:
    """
    Parse subsections from statute text.

    Identifies (1), (2), (a), (b), 1., 2. patterns.
    """
    subsections = []

    # Find level 1 subsections (1), (2), etc.
    level1_matches = list(SUBSECTION_PATTERNS['level1'].finditer(text))

    for i, match in enumerate(level1_matches):
        start = match.end()
        end = level1_matches[i + 1].start() if i + 1 < len(level1_matches) else len(text)

        subsection_text = text[start:end].strip()
        # Truncate at reasonable length for subsection
        if len(subsection_text) > 2000:
            subsection_text = subsection_text[:2000] + "..."

        subsections.append(Subsection(
            number=f"({match.group(1)})",
            text=subsection_text[:500],  # First 500 chars for quick reference
            parent=None
        ))

    return subsections


def clean_text(text: str) -> str:
    """Clean extracted text of HTML artifacts and normalize whitespace."""
    # Remove HTML entities
    text = re.sub(r'&#x[0-9a-fA-F]+;', ' ', text)
    text = re.sub(r'&[a-z]+;', ' ', text)

    # Remove common NXT extraction artifacts
    text = re.sub(r'7[%&\'(#!]', '', text)
    text = re.sub(r'\s*[Â¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿]\s*', ' ', text)

    # Normalize whitespace
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)

    return text.strip()


# Florida Statute Title mapping (Roman numeral to name)
FLORIDA_TITLES = {
    "I": "CONSTRUCTION OF STATUTES",
    "II": "STATE ORGANIZATION",
    "III": "LEGISLATIVE BRANCH; COMMISSIONS",
    "IV": "EXECUTIVE BRANCH",
    "V": "JUDICIAL BRANCH",
    "VI": "CIVIL PRACTICE AND PROCEDURE",
    "VII": "EVIDENCE",
    "VIII": "LIMITATIONS",
    "IX": "ELECTORS AND ELECTIONS",
    "X": "PUBLIC OFFICERS, EMPLOYEES, AND RECORDS",
    "XI": "COUNTY ORGANIZATION AND INTERGOVERNMENTAL RELATIONS",
    "XII": "MUNICIPALITIES",
    "XIII": "PLANNING AND DEVELOPMENT",
    "XIV": "TAXATION AND FINANCE",
    "XV": "HOMESTEAD AND EXEMPTIONS",
    "XVI": "WATERS AND WATER SUPPLY",
    "XVII": "MILITARY AFFAIRS AND RELATED MATTERS",
    "XVIII": "PUBLIC LANDS AND PROPERTY",
    "XIX": "PUBLIC BUSINESS",
    "XX": "PUBLIC TRUSTS",
    "XXI": "PUBLIC HEALTH",
    "XXII": "PUBLIC WELFARE",
    "XXIII": "MOTOR VEHICLES",
    "XXIV": "VESSELS",
    "XXV": "AVIATION",
    "XXVI": "PUBLIC TRANSPORTATION",
    "XXVII": "RAILROADS AND OTHER REGULATED UTILITIES",
    "XXVIII": "NATURAL RESOURCES; CONSERVATION, RECLAMATION, AND USE",
    "XXIX": "PUBLIC HEALTH",
    "XXX": "SOCIAL WELFARE",
    "XXXI": "LABOR",
    "XXXII": "REGULATION OF PROFESSIONS AND OCCUPATIONS",
    "XXXIII": "REGULATION OF TRADE, COMMERCE, INVESTMENTS, AND SOLICITATIONS",
    "XXXIV": "ALCOHOLIC BEVERAGES AND TOBACCO",
    "XXXV": "AGRICULTURE, HORTICULTURE, AND ANIMAL INDUSTRY",
    "XXXVI": "BUSINESS ORGANIZATIONS",
    "XXXVII": "INSURANCE",
    "XXXVIII": "BANKS AND BANKING",
    "XXXIX": "COMMERCIAL RELATIONS",
    "XL": "REAL AND PERSONAL PROPERTY",
    "XLI": "STATUTE OF FRAUDS, FRAUDULENT TRANSFERS, AND GENERAL ASSIGNMENTS",
    "XLII": "ESTATES AND TRUSTS",
    "XLIII": "DOMESTIC RELATIONS",
    "XLIV": "CIVIL RIGHTS",
    "XLV": "TORTS",
    "XLVI": "CRIMES",
    "XLVII": "CRIMINAL PROCEDURE AND CORRECTIONS",
    "XLVIII": "K-20 EDUCATION CODE",
    "XLIX": "POSTSECONDARY EDUCATION",
}


def get_title_for_chapter(chapter_num: int) -> tuple:
    """
    Get the Title number and name for a given chapter.

    Florida Statutes chapters are organized under Titles.
    This is a simplified mapping based on common ranges.
    """
    # Simplified chapter-to-title mapping
    # Full mapping would require parsing the actual statute index
    chapter_ranges = [
        (1, 14, "I"),
        (15, 24, "II"),
        (25, 44, "III"),
        (45, 89, "IV"),
        (90, 92, "VII"),  # Evidence
        (93, 99, "VIII"),  # Limitations
        (100, 109, "IX"),
        (110, 129, "X"),
        (130, 149, "XI"),
        (150, 169, "XII"),
        (170, 199, "XIII"),
        (200, 299, "XIV"),
        (300, 399, "XVIII"),
        (400, 499, "XXIX"),
        (500, 599, "XXXIII"),
        (600, 699, "XXXVI"),
        (700, 739, "XL"),
        (740, 769, "XLII"),
        (770, 799, "XLIV"),
        (800, 899, "XLVI"),
        (900, 999, "XLVII"),
    ]

    for start, end, title_num in chapter_ranges:
        if start <= chapter_num <= end:
            return title_num, FLORIDA_TITLES.get(title_num, "")

    return "", ""
