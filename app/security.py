import re
from dataclasses import dataclass, field


@dataclass
class DetectionResult:
    is_injection: bool
    matched_patterns: list[str] = field(default_factory=list)


class PromptInjectionDetector:
    """Heuristic, pattern-based detector for common prompt injection attempts."""

    # Role-manipulation patterns only fire when paired with one of these -
    # plain "act as a teacher" / "you are now a doctor" is legitimate roleplay,
    # not injection. Only malicious/unrestricted personas should trip it.
    EVIL_ROLES = [
        "hacker",
        "criminal",
        "villain",
        "evil( ai)?",
        "malicious",
        "unfiltered",
        "unrestricted",
        "uncensored",
        "amoral",
        "immoral",
        "unethical",
        r"without (any )?(restrictions|rules|limits|filters|morals|ethics)",
        r"with no (restrictions|rules|limits|filters|morals|ethics)",
    ]

    DEFAULT_PATTERNS = [
        #1. System Overrides
        r"ignore (all )?(previous|prior|above) instructions",
        r"disregard (all )?(previous|prior|above)",

        #2. Earsing Content in system memory
        r"forget (all )?(previous|prior|your) instructions",

        #3. Role Manipulation
        r"you are now (a |an )?(\w+\s+){0,2}(%(evil)s)" % {"evil": "|".join(EVIL_ROLES)},
        r"act as (if you (are|were) )?(a |an )?(\w+\s+){0,2}(%(evil)s)" % {"evil": "|".join(EVIL_ROLES)},
        r"pretend (you are|to be) (a |an )?(\w+\s+){0,2}(%(evil)s)" % {"evil": "|".join(EVIL_ROLES)},
        r"reveal (your|the) (system prompt|instructions)",
        r"what (is|are) your (system prompt|instructions)",
        r"jailbreak",
        r"dan mode",
        r"developer mode",
        r"do anything now",
        r"override (your|the) (rules|guidelines|instructions)",
        r"new instructions?:",
        r"system\s*:",
        r"</?system>",
        r"</?\|.*?\|>",
    ]

    def __init__(self, patterns: list[str] | None = None):
        patterns = patterns or self.DEFAULT_PATTERNS
        self._compiled = [re.compile(p, re.IGNORECASE) for p in patterns]

    def scan(self, text: str) -> DetectionResult:
        matched = [p.pattern for p in self._compiled if p.search(text)]
        return DetectionResult(is_injection=bool(matched), matched_patterns=matched)

    def is_injection(self, text: str) -> bool:
        return self.scan(text).is_injection
