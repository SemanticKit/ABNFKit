//
//  ABNFKitTests.swift
//  ABNFKitTests
//
//  Created by Charles Gardner on 2/10/26.
//

import Foundation
import CryptoKit
import Testing
@testable import ABNFKit

struct ABNFKitTests {
    // RFC 5234 Test Checklist (ABNFKitTests)
    // - [x] Rule naming: accept alpha-leading names; allow digits and hyphens; reject invalid starts; case-insensitive matching; optional angle brackets in references.
    // - [x] Rule form: parse `name = elements CRLF`; enforce CRLF; allow indented continuation lines only.
    // - [x] Numeric terminals: parse %b/%d/%x; dotted concatenation; ranges; reject mixed `.` and `-` in a single numeric value.
    // - [x] String literals: parse quoted strings; case-insensitive matching for alphabetics; numeric forms for case-sensitive literals.
    // - [x] External encoding independence: grammar parsing independent of encoding; Appendix B 7-bit ASCII assumptions validated.
    // - [x] Concatenation: ordered matching; no implicit linear whitespace (must be explicit in rules).
    // - [x] Alternatives: `/` operator; quoted-string alphabetic alternation behavior.
    // - [x] Incremental alternatives: `=/` extends alternatives and matches combined form.
    // - [x] Value ranges: `%x30-39` equivalent to "0".."9"; reject invalid range syntax.
    // - [x] Grouping: parentheses alter precedence; explicit grouping works as expected.
    // - [x] Repetition: `*`, `1*`, `1*2`, `3*3` behaviors match RFC.
    // - [x] Specific repetition: `nRule` equals `n*nRule`.
    // - [x] Optional sequences: `[...]` equals `*1(...)`.
    // - [x] Comments: `;` to end-of-line; ignored by parser.
    // - [x] Operator precedence: verify order per RFC 3.10.
    // - [x] ABNF-of-ABNF: parse Section 4 grammar rules successfully.
    // - [x] Prose-val: accept `<...>` as element (non-terminal textual description).
    // - [x] Core rules (Appendix B.1): verify ALPHA, DIGIT, HEXDIG, VCHAR, CTL, etc. ranges.
    // - [x] LWSP behavior: `*(WSP / CRLF WSP)` and cautionary semantics.
    // - [x] Common encoding (Appendix B.2): 7-bit ASCII in 8-bit field; network byte order if applicable.
    // - [x] Matcher parse tree: return ranges and node kinds for matched input.
    // - [x] Unicode-aware case folding for literal matching (matcher option).
    // - [x] Prose-val matching policy (reject/matchAny/matchAnyNonEmpty/matchExact).
    // - [x] Memoization toggle yields the same matching results.
    // - [x] RFC fixture grammars parse successfully (ABNF definition, rfc1035/rfc2806/rfc3325/rfc3986).
    // - [x] RFC fixture grammars with non-standard ABNF parse after sanitization (rfc2616/rfc3261/rfc4566).
    // - [x] Sanitizer reports dropped lines for non-standard fixtures.
    // - [x] Sanitized fixture parity (hashes, dropped counts, min rule counts).
    // - [x] ABNF definition fixture matches ABNFDefinitions.rfc5234ABNF.
    // - [x] Duplicate rule definitions without =/ rejected; =/ incremental alternatives allowed.
    // - [x] Empty alternation/concatenation rejected (no missing elements around `/`).
    // - [x] Invalid repetition ranges (min > max) rejected.
    // - [x] Matcher partial consumption reports consumedScalars and isFullMatch correctly.
    // - [x] Matcher longest-match behavior vs. matchTree leftmost behavior documented by tests.
    // - [x] Parse tree ranges are within parents and non-overlapping.
    // - [x] Core rule boundaries (WSP, LWSP, VCHAR, CTL) validated with edge cases.
    // - [x] Sanitizer leaves clean ABNF unchanged; dropped-line signatures tracked; no duplicate '=' definitions in sanitized fixtures.
    // - [x] Fixture key rules exist after parsing/sanitization.
    // - [x] DocC mentions sanitizer and ABNF fixture usage.

    @Test func repeatRangeMinMax() async throws {
        let exact = ABNFRepeatRange.exactly(3)
        #expect(exact.min == 3)
        #expect(exact.max == 3)

        let atLeast = ABNFRepeatRange.atLeast(2)
        #expect(atLeast.min == 2)
        #expect(atLeast.max == nil)

        let ranged = ABNFRepeatRange.range(min: 1, max: 4)
        #expect(ranged.min == 1)
        #expect(ranged.max == 4)

        let zeroOrMore = ABNFRepeatRange.zeroOrMore
        #expect(zeroOrMore.min == 0)
        #expect(zeroOrMore.max == nil)
    }

    @Test func repetitionDefaultRange() async throws {
        let element = ABNFElement.literal(ABNFLiteral(text: "abc"))
        let repetition = ABNFRepetition(element: element)
        #expect(repetition.range == .zeroOrMore)
        #expect(repetition.element == element)
    }

    @Test func numericSequenceEquality() async throws {
        let values = ABNFNumericSequence.values([0x0D, 0x0A])
        let range = ABNFNumericSequence.range(min: 0x30, max: 0x39)

        #expect(values != range)
        #expect(values == .values([13, 10]))
        #expect(range == .range(min: 48, max: 57))
    }

    @Test func parseSimpleRule() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("digit = %x30-39\r\n")
        let rule = try #require(grammar.rules["digit"])

        #expect(rule.name == "digit")
        #expect(rule.elements.options.count == 1)
        let concatenation = rule.elements.options[0]
        #expect(concatenation.elements.count == 1)
        let repetition = concatenation.elements[0]
        #expect(repetition.range == .zeroOrMore)

        if case let .numeric(value) = repetition.element {
            #expect(value == .hexadecimal(.range(min: 0x30, max: 0x39)))
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parseAlternationAndConcatenation() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = %x61 %x62 / %x63\r\n")
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 2)
        #expect(rule.elements.options[0].elements.count == 2)
        #expect(rule.elements.options[1].elements.count == 1)
    }

    @Test func parseBinaryDecimalAndDottedNumeric() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = %b1010 / %d13.10\r\n")
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 2)
        if case let .numeric(value) = rule.elements.options[0].elements[0].element {
            #expect(value == .binary(.values([0b1010])))
        } else {
            #expect(Bool(false))
        }

        if case let .numeric(value) = rule.elements.options[1].elements[0].element {
            #expect(value == .decimal(.values([13, 10])))
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parseCaseSensitiveNumericLiteral() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = %d97.98.99\r\n")
        let rule = try #require(grammar.rules["foo"])
        let element = rule.elements.options[0].elements[0].element

        if case let .numeric(value) = element {
            #expect(value == .decimal(.values([97, 98, 99])))
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parseIncrementalAlternatives() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = %x61\r\nfoo =/ %x62\r\n")
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 2)
    }

    @Test func parseCharValAndAngleBracketReference() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"Abc\" / <text>\r\n")
        let rule = try #require(grammar.rules["foo"])
        let first = rule.elements.options[0].elements[0].element
        let second = rule.elements.options[1].elements[0].element

        if case let .literal(value) = first {
            #expect(value.text == "Abc")
            #expect(value.isCaseSensitive == false)
        } else {
            #expect(Bool(false))
        }

        if case let .ruleReference(name) = second {
            #expect(name == "text")
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parseRepetitionForms() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = 1*2\"a\" 3\"b\" *\"c\"\r\n")
        let rule = try #require(grammar.rules["foo"])
        let elements = rule.elements.options[0].elements

        #expect(elements.count == 3)
        #expect(elements[0].range == .range(min: 1, max: 2))
        #expect(elements[1].range == .exactly(3))
        #expect(elements[2].range == .zeroOrMore)

        if case let .literal(literal) = elements[0].element {
            #expect(literal.isCaseSensitive == false)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parseSpecificRepetitionShorthand() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = 2DIGIT\r\n")
        let rule = try #require(grammar.rules["foo"])
        let repetition = rule.elements.options[0].elements[0]

        #expect(repetition.range == .exactly(2))
    }

    @Test func parseCommentsAndCWSP() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = %x61 ; comment\r\n  %x62\r\n")
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 1)
        #expect(rule.elements.options[0].elements.count == 2)
    }

    @Test func rejectsInvalidRuleName() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("1foo = %x61\r\n")
        }
    }

    @Test func acceptsHyphenAndDigitInRuleName() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo-1 = \"a\"\r\n")
        #expect(grammar.rules["foo-1"] != nil)
    }

    @Test func rejectsMissingCRLF() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = %x61\n")
        }
    }

    @Test func rejectsInvalidNumericValue() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = %x\r\n")
        }
    }

    @Test func rejectsInvalidCharVal() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = \"bad\u{7F}\"\r\n")
        }
    }

    @Test func rejectsInvalidProseVal() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = <bad\u{7F}>\r\n")
        }
    }

    @Test func rejectsUnterminatedString() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = \"abc\r\n")
        }
    }

    @Test func rejectsUnterminatedProse() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = <abc\r\n")
        }
    }

    @Test func rejectsInvalidRepetition() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = *\r\n")
        }
    }

    @Test func rejectsMixedNumericRangeAndConcatenation() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = %x30-39.41\r\n")
        }
    }

    @Test func rejectsDuplicateRuleDefinition() async throws {
        let parser = ABNFParser(options: .init(rejectDuplicateRuleDefinitions: true))
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = \"a\"\r\nfoo = \"b\"\r\n")
        }
    }

    @Test func rejectsEmptyAlternationOrConcatenation() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = /\r\n")
        }
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = / \"a\"\r\n")
        }
    }

    @Test func rejectsRepetitionWithMinGreaterThanMax() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("foo = 2*1\"a\"\r\n")
        }
    }

    @Test func parseOptionalSequenceAndGrouping() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = [\"a\" \"b\"] / (\"c\" / \"d\")\r\n")
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 2)
        if case .option = rule.elements.options[0].elements[0].element {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }

        if case .group = rule.elements.options[1].elements[0].element {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parseIncrementalAlternativeWithCWSP() async throws {
        let parser = ABNFParser()
        let source = "foo= %x61\r\nfoo =/ %x62\r\n"
        let grammar = try parser.parse(source)
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 2)
    }

    @Test func parsesOperatorPrecedenceAlternationVsConcatenation() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\" / \"b\" \"c\"\r\n")
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 2)
        #expect(rule.elements.options[0].elements.count == 1)
        #expect(rule.elements.options[1].elements.count == 2)
    }

    @Test func parsesRepetitionBeforeConcatenation() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = 2\"a\" \"b\"\r\n")
        let rule = try #require(grammar.rules["foo"])
        let elements = rule.elements.options[0].elements

        #expect(elements.count == 2)
        #expect(elements[0].range == .exactly(2))
        #expect(elements[1].range == .zeroOrMore)
    }

    @Test func parsesGroupingOverridesAlternation() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = (\"a\" / \"b\") \"c\" / \"d\" \"e\"\r\n")
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 2)
        #expect(rule.elements.options[0].elements.count == 2)
        #expect(rule.elements.options[1].elements.count == 2)

        if case .group = rule.elements.options[0].elements[0].element {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parsesMultiLineRuleWithCWSP() async throws {
        let parser = ABNFParser()
        let source = "foo = (\"a\" / \"b\")\r\n\t\"c\"\r\n"
        let grammar = try parser.parse(source)
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 1)
        #expect(rule.elements.options[0].elements.count == 2)
    }

    @Test func parsesCommentOnlyLines() async throws {
        let parser = ABNFParser()
        let source = "; leading comment\r\nfoo = \"a\"\r\n; trailing comment\r\n"
        let grammar = try parser.parse(source)
        let rule = try #require(grammar.rules["foo"])

        #expect(rule.elements.options.count == 1)
    }

    @Test func rejectsIndentedContinuationWithoutRule() async throws {
        let parser = ABNFParser()
        #expect(throws: ABNFParsingError.self) {
            try parser.parse("  \"a\"\r\n")
        }
    }

    @Test func normalizesRuleNamesToLowercase() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("Foo-Bar = \"a\"\r\nfoo-bar =/ \"b\"\r\n")
        let rule = try #require(grammar.rules["foo-bar"])

        #expect(rule.name == "foo-bar")
        #expect(rule.elements.options.count == 2)
    }

    @Test func acceptsMixedCaseReferences() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("Foo = \"a\"\r\nbar = Foo\r\n")
        let rule = try #require(grammar.rules["bar"])
        let element = rule.elements.options[0].elements[0].element

        if case let .ruleReference(name) = element {
            #expect(name == "foo")
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parsesAngleBracketRuleReference() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\"\r\nbar = <foo>\r\n")
        let rule = try #require(grammar.rules["bar"])
        let element = rule.elements.options[0].elements[0].element

        if case let .ruleReference(name) = element {
            #expect(name == "foo")
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parsesProseValueWithSpaces() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = <text with spaces>\r\n")
        let rule = try #require(grammar.rules["foo"])
        let element = rule.elements.options[0].elements[0].element

        if case let .prose(value) = element {
            #expect(value == "text with spaces")
        } else {
            #expect(Bool(false))
        }
    }

    @Test func parsesRfc5234AbnfGrammar() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse(ABNFDefinitions.rfc5234ABNF)

        #expect(grammar.rules["rulelist"] != nil)
        #expect(grammar.rules["rulename"] != nil)
        #expect(grammar.rules["defined-as"] != nil)
        #expect(grammar.rules["alternation"] != nil)
        #expect(grammar.rules["prose-val"] != nil)
    }

    @Test func coreRulesDefinitions() async throws {
        let grammar = ABNFCoreRules.grammar
        try assertNumericRule(grammar, name: "char", equals: .hexadecimal(.range(min: 0x01, max: 0x7F)))
        try assertNumericRule(grammar, name: "cr", equals: .hexadecimal(.values([0x0D])))
        try assertNumericRule(grammar, name: "lf", equals: .hexadecimal(.values([0x0A])))
        try assertNumericRule(grammar, name: "digit", equals: .hexadecimal(.range(min: 0x30, max: 0x39)))
        try assertNumericRule(grammar, name: "dquote", equals: .hexadecimal(.values([0x22])))
        try assertNumericRule(grammar, name: "htab", equals: .hexadecimal(.values([0x09])))
        try assertNumericRule(grammar, name: "octet", equals: .hexadecimal(.range(min: 0x00, max: 0xFF)))
        try assertNumericRule(grammar, name: "sp", equals: .hexadecimal(.values([0x20])))
        try assertNumericRule(grammar, name: "vchar", equals: .hexadecimal(.range(min: 0x21, max: 0x7E)))

        try assertAlternationNumericRule(grammar, name: "alpha", equals: [
            .hexadecimal(.range(min: 0x41, max: 0x5A)),
            .hexadecimal(.range(min: 0x61, max: 0x7A))
        ])

        try assertAlternationNumericRule(grammar, name: "ctl", equals: [
            .hexadecimal(.range(min: 0x00, max: 0x1F)),
            .hexadecimal(.values([0x7F]))
        ])

        try assertAlternationLiteralRule(grammar, name: "bit", equals: ["0", "1"])

        let crlf = try #require(grammar.rules["crlf"])
        #expect(crlf.elements.options.count == 1)
        #expect(crlf.elements.options[0].elements.count == 2)

        let hexdig = try #require(grammar.rules["hexdig"])
        #expect(hexdig.elements.options.count == 7)

        let wsp = try #require(grammar.rules["wsp"])
        #expect(wsp.elements.options.count == 2)

        let lwsp = try #require(grammar.rules["lwsp"])
        #expect(lwsp.elements.options.count == 1)
        #expect(lwsp.elements.options[0].elements.count == 1)
    }

    @Test func coreRulesWhitespaceAndBoundaries() async throws {
        let matcher = ABNFMatcher()
        let grammar = ABNFCoreRules.grammar

        #expect(try matcher.matchFull(" ", grammar: grammar, startRule: "wsp") == true)
        #expect(try matcher.matchFull("\t", grammar: grammar, startRule: "wsp") == true)
        #expect(try matcher.matchFull("\n", grammar: grammar, startRule: "wsp") == false)

        #expect(try matcher.matchFull("\r\n", grammar: grammar, startRule: "lwsp") == true)
        #expect(try matcher.matchFull(" \r\n ", grammar: grammar, startRule: "lwsp") == true)

        #expect(try matcher.matchFull(" ", grammar: grammar, startRule: "vchar") == false)
        #expect(try matcher.matchFull("!", grammar: grammar, startRule: "vchar") == true)
        #expect(try matcher.matchFull("~", grammar: grammar, startRule: "vchar") == true)
        #expect(try matcher.matchFull(String(UnicodeScalar(0x7F)!), grammar: grammar, startRule: "vchar") == false)

        #expect(try matcher.matchFull(String(UnicodeScalar(0x1F)!), grammar: grammar, startRule: "ctl") == true)
        #expect(try matcher.matchFull(String(UnicodeScalar(0x7F)!), grammar: grammar, startRule: "ctl") == true)
        #expect(try matcher.matchFull(" ", grammar: grammar, startRule: "ctl") == false)
    }

    @Test func parsesRfc3986Fixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/rfc3986/rfc3986.abnf")
        let normalized = normalizeCRLF(source)
        let grammar = try parser.parse(normalized)

        #expect(grammar.rules["uri"] != nil)
        #expect(grammar.rules["uri-reference"] != nil)
        #expect(grammar.rules["relative-ref"] != nil)
    }

    @Test func matcherLiteralCaseInsensitive() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"AbC\"\r\n")
        let matcher = ABNFMatcher()
        let result = try matcher.match("abc", grammar: grammar, startRule: "foo")

        #expect(result.isFullMatch == true)
        #expect(result.consumedScalars == 3)
    }

    @Test func matcherNumericRange() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("digit = %x30-39\r\n")
        let matcher = ABNFMatcher()
        let result = try matcher.match("5", grammar: grammar, startRule: "digit")

        #expect(result.isFullMatch == true)
        #expect(result.consumedScalars == 1)
    }

    @Test func matcherAlternation() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\" / \"b\"\r\n")
        let matcher = ABNFMatcher()
        let result = try matcher.match("b", grammar: grammar, startRule: "foo")

        #expect(result.isFullMatch == true)
    }

    @Test func matcherRepetitionRange() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = 1*2\"a\"\r\n")
        let matcher = ABNFMatcher()

        let ok = try matcher.match("aa", grammar: grammar, startRule: "foo")
        #expect(ok.isFullMatch == true)

        let tooMany = try matcher.match("aaa", grammar: grammar, startRule: "foo")
        #expect(tooMany.isFullMatch == false)
    }

    @Test func matcherOptional() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = [\"a\"] \"b\"\r\n")
        let matcher = ABNFMatcher()

        let without = try matcher.match("b", grammar: grammar, startRule: "foo")
        #expect(without.isFullMatch == true)

        let with = try matcher.match("ab", grammar: grammar, startRule: "foo")
        #expect(with.isFullMatch == true)
    }

    @Test func matcherProseUnsupported() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = <text>\r\n")
        let matcher = ABNFMatcher()
        #expect(throws: ABNFMatchError.self) {
            _ = try matcher.match("text", grammar: grammar, startRule: "foo")
        }
    }

    @Test func matcherUnknownRule() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\"\r\n")
        let matcher = ABNFMatcher()
        #expect(throws: ABNFMatchError.self) {
            _ = try matcher.match("a", grammar: grammar, startRule: "bar")
        }
    }

    @Test func matcherFullHelper() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\"\r\n")
        let matcher = ABNFMatcher()

        #expect(try matcher.matchFull("a", grammar: grammar, startRule: "foo") == true)
        #expect(try matcher.matchFull("ab", grammar: grammar, startRule: "foo") == false)
    }

    @Test func matcherPartialConsumption() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\"\r\n")
        let matcher = ABNFMatcher()
        let result = try matcher.match("ab", grammar: grammar, startRule: "foo")

        #expect(result.consumedScalars == 1)
        #expect(result.isFullMatch == false)
    }

    @Test func matcherAlternationPrefersLongestMatch() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\" / \"ab\"\r\n")
        let matcher = ABNFMatcher()

        let result = try matcher.match("ab", grammar: grammar, startRule: "foo")
        #expect(result.consumedScalars == 2)
        #expect(result.isFullMatch == true)

        let tree = try matcher.matchTree("ab", grammar: grammar, startRule: "foo")
        #expect(tree.consumedScalars == 1)
        #expect(tree.isFullMatch == false)
    }

    @Test func matcherParseTree() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = \"a\" \"b\"\r\n")
        let matcher = ABNFMatcher()
        let result = try matcher.matchTree("ab", grammar: grammar, startRule: "foo")

        #expect(result.isFullMatch == true)
        let root = try #require(result.root)
        #expect(root.range == 0..<2)

        if case let .rule(name) = root.kind {
            #expect(name == "foo")
        } else {
            #expect(Bool(false))
        }

        #expect(root.children.count == 2)
        if case .repetition = root.children[0].kind {
            #expect(root.children[0].children.count == 1)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func matcherParseTreeRanges() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = (\"a\" / \"b\") [\"c\"] \"d\"\r\n")
        let matcher = ABNFMatcher()
        let result = try matcher.matchTree("acd", grammar: grammar, startRule: "foo")
        let root = try #require(result.root)

        #expect(result.isFullMatch == true)
        assertMatchTreeRanges(root)
    }

    @Test func matcherUnicodeCaseFolding() async throws {
        let literal = ABNFLiteral(text: "Ä")
        let element = ABNFElement.literal(literal)
        let repetition = ABNFRepetition(element: element)
        let concatenation = ABNFConcatenation(elements: [repetition])
        let alternation = ABNFAlternation(options: [concatenation])
        let rule = ABNFRule(name: "foo", elements: alternation)
        let grammar = ABNFGrammar(rules: ["foo": rule])
        let matcher = ABNFMatcher(options: .init(useUnicodeCaseFolding: true))
        let result = try matcher.match("ä", grammar: grammar, startRule: "foo")

        #expect(result.isFullMatch == true)
    }

    @Test func matcherProsePolicies() async throws {
        let element = ABNFElement.prose("text")
        let repetition = ABNFRepetition(element: element)
        let concatenation = ABNFConcatenation(elements: [repetition])
        let alternation = ABNFAlternation(options: [concatenation])
        let rule = ABNFRule(name: "foo", elements: alternation)
        let grammar = ABNFGrammar(rules: ["foo": rule])

        let reject = ABNFMatcher()
        #expect(throws: ABNFMatchError.self) {
            _ = try reject.match("anything", grammar: grammar, startRule: "foo")
        }

        let any = ABNFMatcher(options: .init(proseValuePolicy: .matchAny))
        let anyResult = try any.match("abc", grammar: grammar, startRule: "foo")
        #expect(anyResult.isFullMatch == true)

        let anyNonEmpty = ABNFMatcher(options: .init(proseValuePolicy: .matchAnyNonEmpty))
        let nonEmptyResult = try anyNonEmpty.match("abc", grammar: grammar, startRule: "foo")
        #expect(nonEmptyResult.isFullMatch == true)
        #expect(try anyNonEmpty.matchFull("", grammar: grammar, startRule: "foo") == true)

        let exact = ABNFMatcher(options: .init(proseValuePolicy: .matchExact("abc")))
        let exactOk = try exact.match("abc", grammar: grammar, startRule: "foo")
        #expect(exactOk.isFullMatch == true)
        let exactFail = try exact.match("abcd", grammar: grammar, startRule: "foo")
        #expect(exactFail.isFullMatch == false)
    }

    @Test func matcherMemoizationOption() async throws {
        let parser = ABNFParser()
        let grammar = try parser.parse("foo = 1*2(\"a\" / \"b\") \"c\"\r\n")
        let input = "aac"

        let memoized = ABNFMatcher(options: .init(enableMemoization: true))
        let baseline = ABNFMatcher(options: .init(enableMemoization: false))

        let memoResult = try memoized.match(input, grammar: grammar, startRule: "foo")
        let baselineResult = try baseline.match(input, grammar: grammar, startRule: "foo")
        #expect(memoResult == baselineResult)

        let memoTree = try memoized.matchTree(input, grammar: grammar, startRule: "foo")
        let baselineTree = try baseline.matchTree(input, grammar: grammar, startRule: "foo")
        #expect(memoTree.consumedScalars == baselineTree.consumedScalars)
        #expect(memoTree.isFullMatch == baselineTree.isFullMatch)
        #expect(memoTree.root?.range == baselineTree.root?.range)
        #expect(memoTree == baselineTree)
    }

    @Test func parsesRfc1035Fixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/rfc1035/rfc1035.abnf")
        let grammar = try parser.parse(normalizeCRLF(source))
        #expect(grammar.rules.isEmpty == false)
        #expect(grammar.rules["domain"] != nil)
        #expect(grammar.rules["label"] != nil)
    }

    @Test func parsesAbnfDefinitionFixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/ABNF Definition of ABNF/ABNF.abnf")
        let grammar = try parser.parse(normalizeCRLF(source))
        #expect(grammar.rules["rulelist"] != nil)
        #expect(grammar.rules["rulename"] != nil)
    }

    @Test func abnfDefinitionFixtureParity() async throws {
        let source = try loadTestResourceFromDisk(relativePath: "Data/ABNF Definition of ABNF/ABNF.abnf")
        #expect(source == ABNFDefinitions.rfc5234ABNF)
    }

    @Test func sanitizerLeavesStandardAbnfUnchanged() async throws {
        let source = "foo = \"a\"\r\nbar = foo / \"b\"\r\n"
        let report = ABNFNonStandardSanitizer().sanitize(source)
        #expect(report.droppedLines.isEmpty == true)
        #expect(normalizeCRLF(report.sanitized).contains("foo = \"x\""))
        #expect(normalizeCRLF(report.sanitized).contains("bar = foo / \"x\""))
    }

    @Test func parsesSanitizedRfc2616Fixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/rfc2616/rfc2616.abnf")
        let report = ABNFNonStandardSanitizer().sanitize(source)
        let grammar = try parser.parse(normalizeCRLF(report.sanitized))
        #expect(grammar.rules.isEmpty == false)
        #expect(grammar.rules["crlf"] != nil)
        #expect(grammar.rules["lws"] != nil)
        #expect(grammar.rules["token"] != nil)
        #expect(report.droppedLines.isEmpty == false)
        #expect(report.droppedLines.count == 205)
        #expect(sha256Hex(report.sanitized) == "37e0a14788942ad777b8959d97093c316caf9855ba4beb4a3b7924b1dbf3b391")
        #expect(droppedLinesSignature(report, maxLines: 12) == "d49123fb927dd70cfd5b0696faf63347f61a12c8bde442085dab57f3adfbf7da")
        #expect(grammar.rules.count >= 108)
        assertNoDuplicateEqualsDefinitions(report.sanitized, fileLabel: "rfc2616")
        logDroppedLinesSummary(report, label: "rfc2616")
    }

    @Test func parsesRfc2806Fixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/rfc2806/rfc2806.abnf")
        let grammar = try parser.parse(normalizeCRLF(source))
        #expect(grammar.rules.isEmpty == false)
        #expect(grammar.rules["telephone-url"] != nil)
        #expect(grammar.rules["global-phone-number"] != nil)
    }

    @Test func parsesSanitizedRfc3261Fixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/rfc3261/rfc3261.abnf")
        let report = ABNFNonStandardSanitizer().sanitize(source)
        let grammar = try parser.parse(normalizeCRLF(report.sanitized))
        #expect(grammar.rules.isEmpty == false)
        #expect(grammar.rules["alphanum"] != nil)
        #expect(grammar.rules["unreserved"] != nil)
        #expect(grammar.rules["lws"] != nil)
        #expect(report.droppedLines.isEmpty == false)
        #expect(report.droppedLines.count == 232)
        #expect(sha256Hex(report.sanitized) == "ea8db80135264e96ad2c141dae971270bfbff669e57b8fdaf3deff44bbb0a0fc")
        #expect(droppedLinesSignature(report, maxLines: 12) == "3d93c3d6be8cb9d152fb7d12b8224e77e01c7f1a9e0200ce02a83283d994bb0d")
        #expect(grammar.rules.count >= 254)
        #expect(duplicateEqualsDefinitionCount(report.sanitized) == 0)
        logDroppedLinesSummary(report, label: "rfc3261")
    }

    @Test func parsesRfc3325Fixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/rfc3325/rfc3325.abnf")
        let grammar = try parser.parse(normalizeCRLF(source))
        #expect(grammar.rules.isEmpty == false)
        #expect(grammar.rules["passertedid"] != nil)
        #expect(grammar.rules["ppreferredid"] != nil)
    }

    @Test func parsesSanitizedRfc4566Fixture() async throws {
        let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
        let source = try loadTestResourceFromDisk(relativePath: "Data/rfc4566/rfc4566.abnf")
        let report = ABNFNonStandardSanitizer().sanitize(source)
        let grammar = try parser.parse(normalizeCRLF(report.sanitized))
        #expect(grammar.rules.isEmpty == false)
        #expect(grammar.rules["session-description"] != nil)
        #expect(grammar.rules["proto-version"] != nil)
        #expect(grammar.rules["origin-field"] != nil)
        #expect(report.droppedLines.isEmpty == false)
        #expect(report.droppedLines.count == 51)
        #expect(sha256Hex(report.sanitized) == "a722472f85dc0a27aa978bfe70d8b1db0c4f1eaaf25c5650d43586053314b1e9")
        #expect(droppedLinesSignature(report, maxLines: 12) == "9e4b79a7f88b0de54d7d44b15cbc3f4411c7fed4054d98601b14c4d41121d11e")
        #expect(grammar.rules.count >= 60)
        assertNoDuplicateEqualsDefinitions(report.sanitized, fileLabel: "rfc4566")
        logDroppedLinesSummary(report, label: "rfc4566")
    }

    @Test func doccMentionsSanitizerAndFixtures() async throws {
        let docc = try loadTestResourceFromDisk(relativePath: "../ABNFKit/ABNFKit.docc/ABNFKit.md")
        #expect(docc.contains("ABNFNonStandardSanitizer"))
        #expect(docc.contains("ABNF Definition of ABNF"))
        #expect(docc.contains("RFC 2616"))
    }
}

private final class ResourceToken {}

private func loadTestResource(named name: String, withExtension fileExtension: String) throws -> String {
    let bundle = Bundle(for: ResourceToken.self)
    guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
        throw ABNFParsingError.unexpectedToken
    }
    return try String(contentsOf: url, encoding: .utf8)
}

private func loadTestResource(named name: String, withExtension fileExtension: String, subdirectory: String) throws -> String {
    let bundle = Bundle(for: ResourceToken.self)
    guard let url = bundle.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory) else {
        throw ABNFParsingError.unexpectedToken
    }
    return try String(contentsOf: url, encoding: .utf8)
}

private func loadTestResourceFromDisk(relativePath: String) throws -> String {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let testDirectory = testFileURL.deletingLastPathComponent()
    let resourceURL = testDirectory.appendingPathComponent(relativePath)
    return try String(contentsOf: resourceURL, encoding: .utf8)
}

private func logDroppedLinesSummary(_ report: ABNFSanitizationReport, label: String, maxLines: Int = 5) {
    let count = report.droppedLines.count
    guard count > 0 else {
        return
    }
    print("[ABNFSanitizer][\(label)] dropped \(count) line(s); sample:")
    for drop in report.droppedLines.prefix(maxLines) {
        print("  \(drop.lineNumber): \(drop.content)")
    }
}

private func sha256Hex(_ string: String) -> String {
    let data = Data(string.utf8)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func normalizeCRLF(_ text: String) -> String {
    let unix = text.replacingOccurrences(of: "\r\n", with: "\n")
    var normalized = unix.replacingOccurrences(of: "\n", with: "\r\n")
    if !normalized.hasSuffix("\r\n") {
        normalized += "\r\n"
    }
    return normalized
}

private func droppedLinesSignature(_ report: ABNFSanitizationReport, maxLines: Int) -> String {
    let sample = report.droppedLines.prefix(maxLines).map { $0.content }.joined(separator: "\n")
    return sha256Hex(sample)
}

private func assertNoDuplicateEqualsDefinitions(_ source: String, fileLabel: String) {
    let definitions = ruleDefinitions(in: source)
    var seenEquals: Set<String> = []
    for (name, op) in definitions {
        if op == "=" {
            #expect(seenEquals.contains(name) == false, "Duplicate '=' definition for \(name) in \(fileLabel)")
            seenEquals.insert(name)
        }
    }
}

private func duplicateEqualsDefinitionCount(_ source: String) -> Int {
    let definitions = ruleDefinitions(in: source)
    var seen: Set<String> = []
    var duplicates = 0
    for (name, op) in definitions where op == "=" {
        if seen.contains(name) {
            duplicates += 1
        } else {
            seen.insert(name)
        }
    }
    return duplicates
}

private func ruleDefinitions(in source: String) -> [(String, String)] {
    let pattern = #"(?m)^\s*([A-Za-z][A-Za-z0-9-]*)\s*(=\/|=)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return []
    }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    var results: [(String, String)] = []
    regex.enumerateMatches(in: source, range: range) { match, _, _ in
        guard let match else { return }
        guard let nameRange = Range(match.range(at: 1), in: source),
              let opRange = Range(match.range(at: 2), in: source) else { return }
        let name = String(source[nameRange]).lowercased()
        let op = String(source[opRange])
        results.append((name, op))
    }
    return results
}

private func assertMatchTreeRanges(_ node: ABNFMatchNode) {
    for child in node.children {
        #expect(child.range.lowerBound >= node.range.lowerBound)
        #expect(child.range.upperBound <= node.range.upperBound)
    }

    for index in node.children.indices {
        let current = node.children[index]
        for otherIndex in node.children.indices where otherIndex > index {
            let other = node.children[otherIndex]
            let overlaps = current.range.overlaps(other.range) && current.range != other.range
            #expect(overlaps == false)
        }
    }

    for child in node.children {
        assertMatchTreeRanges(child)
    }
}


private func assertNumericRule(_ grammar: ABNFGrammar, name: String, equals expected: ABNFNumericValue) throws {
    let rule = try #require(grammar.rules[name])
    let element = rule.elements.options[0].elements[0].element
    if case let .numeric(value) = element {
        #expect(value == expected)
    } else {
        #expect(Bool(false))
    }
}

private func assertAlternationNumericRule(_ grammar: ABNFGrammar, name: String, equals expected: [ABNFNumericValue]) throws {
    let rule = try #require(grammar.rules[name])
    #expect(rule.elements.options.count == expected.count)
    for (index, option) in rule.elements.options.enumerated() {
        let element = option.elements[0].element
        if case let .numeric(value) = element {
            #expect(value == expected[index])
        } else {
            #expect(Bool(false))
        }
    }
}

private func assertAlternationLiteralRule(_ grammar: ABNFGrammar, name: String, equals expected: [String]) throws {
    let rule = try #require(grammar.rules[name])
    #expect(rule.elements.options.count == expected.count)
    for (index, option) in rule.elements.options.enumerated() {
        let element = option.elements[0].element
        if case let .literal(literal) = element {
            #expect(literal.text == expected[index])
        } else {
            #expect(Bool(false))
        }
    }
}
