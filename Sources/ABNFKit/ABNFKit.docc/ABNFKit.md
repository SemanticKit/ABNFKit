# ``ABNFKit``

ABNF parsing and validation utilities based on RFC 5234, including matching input strings against rules.

## Overview

ABNFKit targets a complete, standards-aligned implementation of Augmented BNF as specified by RFC 5234. The checklist below tracks the required development work for the ABNFKit target.

### Rule Name Normalization

RFC 5234 rule names are case insensitive. ABNFKit normalizes rule names and rule references to lowercase during parsing so lookups are consistent.

### Usage Example

```swift
let parser = ABNFParser()
let grammar = try parser.parse("digit = %x30-39\r\n")
let digitRule = grammar.rules["digit"]
```

### Matching Example

```swift
let matcher = ABNFMatcher()
let result = try matcher.match("7", grammar: grammar, startRule: "digit")
if result.isFullMatch {
    print("Matched")
}
```

```swift
let isMatch = try matcher.matchFull("7", grammar: grammar, startRule: "digit")
```

```swift
let tree = try matcher.matchTree("7", grammar: grammar, startRule: "digit")
let root = tree.root
```

### Matching Notes

- Matching operates on Unicode scalar values. Numeric terminals compare scalar values directly.
- Prose values default to `ProseValuePolicy.reject` and produce `ABNFMatchError.unsupportedProseValue`.
- Use `ABNFMatcher.Options(maxRecursionDepth:maxSteps:)` to control recursion and backtracking limits.
- `matchTree` returns a best-effort parse tree for the first successful match.
- Set `ABNFMatcher.Options(useUnicodeCaseFolding: true)` to apply Unicode case folding for literals (non-RFC).
- Configure prose matching with `ABNFMatcher.Options(proseValuePolicy:)`.
- Memoization is enabled by default; disable with `ABNFMatcher.Options(enableMemoization: false)`.

### Parser Notes

- The parser enforces RFC 5234 CRLF line endings.
- Rules that continue across lines must use c-wsp (CRLF followed by WSP).
- Quoted string literals are parsed as case-insensitive (RFC 5234 requires case-insensitive matching).
- Angle-bracketed rule references like `<rule>` are accepted for convenience.
- Parsing is independent of external encodings; Appendix B core rules assume 7-bit US-ASCII in an 8-bit field.
- Use `ABNFParser.Options(allowLeadingWhitespaceInRuleDefinitions: true)` to accept leading indentation on rule lines (non-RFC).
- By default, the matcher rejects prose-val and throws `ABNFMatchError.unsupportedProseValue`; configure `proseValuePolicy` to accept specific prose matching.

### Security Considerations

RFC 5234 states that security considerations are not relevant for ABNF itself.

### Supported Operators

- Concatenation: `rule1 rule2`
- Alternation: `rule1 / rule2`
- Incremental alternation: `rule1 =/ rule2`
- Grouping: `(rule1 rule2)`
- Optional: `[rule]`
- Variable repetition: `*rule`, `1*rule`, `1*2rule`
- Specific repetition: `nrule`
- Numeric terminals: `%b`, `%d`, `%x` with `.` concatenation or `-` ranges
- Comments: `;` to end of line

### Examples

```abnf
digit = %x30-39
CRLF  = %d13.10
command = "command"
```

### RFC 3986 Fixture

```swift
let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
let url = Bundle.main.url(forResource: "rfc3986", withExtension: "abnf", subdirectory: "Data/rfc3986")!
let source = try String(contentsOf: url, encoding: .utf8)
let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\n", with: "\r\n")
let grammar = try parser.parse(normalized + "\r\n")
let rule = grammar.rules["uri"]
```

### ABNF Definition Fixture

`ABNFKitTests/Data/ABNF Definition of ABNF/ABNF.abnf` contains the RFC 5234 ABNF definition of ABNF (Section 4) in ASCII format and is used by tests to verify round-trip parsing of the grammar itself.

### Fixture Notes

Some RFC fixture files in `ABNFKitTests/Data` include non-standard ABNF or embedded semantic actions (for example, RFC 2616, RFC 3261, and RFC 4566). Use `ABNFNonStandardSanitizer().sanitize(...)` to strip annotations and non-ABNF extensions and to collect a report of dropped lines.

```swift
let report = ABNFNonStandardSanitizer().sanitize(source)
let grammar = try parser.parse(normalizeCRLF(report.sanitized))
print("Dropped lines: \\(report.droppedLines.count)")
```

### Core Rules

Appendix B core rules are available as `ABNFCoreRules.grammar` for convenience.

### RFC 5234 Definitions

The RFC 5234 ABNF for ABNF is available as `ABNFDefinitions.rfc5234ABNF`.

## RFC 5234 Implementation Checklist (ABNFKit)

- [x] Scope and intent match RFC 5234 introduction (ABNF as meta-language, differences vs. BNF).
- [x] Rule naming: `ALPHA *(ALPHA / DIGIT / "-")`, case-insensitive names, optional angle brackets in prose.
- [x] Rule form: `name = elements CRLF`, `=` separator, CRLF line endings, indented continuation lines.
- [x] Terminal values: `%b`, `%d`, `%x` numeric forms; dotted concatenation; quoted strings (US-ASCII, case-insensitive); numeric form for case-sensitive literals.
- [x] External encodings remain separate from grammar; 7-bit US-ASCII supported via Appendix B.
- [x] Concatenation: ordered sequence of elements; no implicit linear whitespace.
- [x] Alternatives: `/` operator; quoted strings represent case-insensitive alternatives for alphabetics.
- [x] Incremental alternatives: `=/` extends an existing rule definition.
- [x] Value ranges: `%x##-##` allowed; disallow mixing range and concatenation in one numeric value.
- [x] Grouping: `(...)` for explicit sequence grouping with correct precedence.
- [x] Repetition: `*` with optional min/max (default 0..infinity).
- [x] Specific repetition: `nRule` equivalent to `n*nRule`.
- [x] Optional sequences: `[...]` equivalent to `*1(...)`.
- [x] Comments: `;` to end-of-line.
- [x] Operator precedence: rule name/prose/terminal > comment > value range > repetition > grouping/optional > concatenation > alternative.
- [x] Full grammar in Section 4 implemented, including `rulelist`, `rule`, `defined-as`, `elements`, `c-wsp`, `c-nl`, `comment`, `alternation`, `concatenation`, `repetition`, `repeat`, `element`, `group`, `option`, `char-val`, `num-val`, `bin-val`, `dec-val`, `hex-val`, `prose-val`.
- [x] Prose-val `<...>` accepted as last-resort element.
- [x] Core rules (Appendix B.1) implemented for 7-bit ASCII: ALPHA, BIT, CHAR, CR, CRLF, CTL, DIGIT, DQUOTE, HEXDIG, HTAB, LF, LWSP, OCTET, SP, VCHAR, WSP.
- [x] Common encoding (Appendix B.2) documented/handled where applicable (7-bit ASCII in 8-bit field; network byte order).
- [x] Security considerations: document RFC 5234 statement that security is not relevant.

## Matcher Extensions Checklist

- [x] Parse tree and scalar ranges for matched input.
- [x] Unicode-aware literal case folding beyond ASCII.
- [x] Configurable prose-val matching policy.
- [x] Memoization or packrat matching to avoid exponential backtracking.
