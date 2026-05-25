//
//  ABNFKit.swift
//  ABNFKit
//
//  Created by Charles Gardner on 2/10/26.
//

import Foundation

public struct ABNFGrammar: Sendable, Equatable {
    public var rules: [String: ABNFRule]

    public init(rules: [String: ABNFRule] = [:]) {
        self.rules = rules
    }
}

public struct ABNFRule: Sendable, Equatable {
    public var name: String
    public var elements: ABNFAlternation
    public var isIncremental: Bool

    public init(name: String, elements: ABNFAlternation, isIncremental: Bool = false) {
        self.name = name
        self.elements = elements
        self.isIncremental = isIncremental
    }
}

public struct ABNFAlternation: Sendable, Equatable {
    public var options: [ABNFConcatenation]

    public init(options: [ABNFConcatenation]) {
        self.options = options
    }
}

public struct ABNFConcatenation: Sendable, Equatable {
    public var elements: [ABNFRepetition]

    public init(elements: [ABNFRepetition]) {
        self.elements = elements
    }
}

public struct ABNFRepetition: Sendable, Equatable {
    public var range: ABNFRepeatRange
    public var element: ABNFElement

    public init(range: ABNFRepeatRange = .zeroOrMore, element: ABNFElement) {
        self.range = range
        self.element = element
    }
}

public enum ABNFRepeatRange: Sendable, Equatable {
    case exactly(Int)
    case atLeast(Int)
    case range(min: Int?, max: Int?)

    public static let zeroOrMore = ABNFRepeatRange.range(min: nil, max: nil)

    public var min: Int {
        switch self {
        case .exactly(let value):
            return value
        case .atLeast(let value):
            return value
        case .range(let min, _):
            return min ?? 0
        }
    }

    public var max: Int? {
        switch self {
        case .exactly(let value):
            return value
        case .atLeast:
            return nil
        case .range(_, let max):
            return max
        }
    }
}

public enum ABNFElement: Sendable, Equatable {
    case ruleReference(String)
    case group(ABNFAlternation)
    case option(ABNFAlternation)
    case literal(ABNFLiteral)
    case numeric(ABNFNumericValue)
    case prose(String)
}

public struct ABNFLiteral: Sendable, Equatable {
    public var text: String
    public var isCaseSensitive: Bool

    public init(text: String, isCaseSensitive: Bool = false) {
        self.text = text
        self.isCaseSensitive = isCaseSensitive
    }
}

public enum ABNFNumericValue: Sendable, Equatable {
    case binary(ABNFNumericSequence)
    case decimal(ABNFNumericSequence)
    case hexadecimal(ABNFNumericSequence)
}

public enum ABNFNumericSequence: Sendable, Equatable {
    case values([UInt32])
    case range(min: UInt32, max: UInt32)
}

public enum ABNFParsingError: Error, Sendable, Equatable {
    case emptyInput
    case invalidRuleName(String)
    case invalidDefinedAs
    case duplicateRule(String)
    case invalidNumericValue
    case invalidRepetition
    case invalidStringLiteral
    case invalidProseValue
    case unexpectedToken
    case unexpectedEndOfInput
    case unsupportedProseValue
}

public struct ABNFMatchResult: Sendable, Equatable {
    public var consumedScalars: Int
    public var isFullMatch: Bool

    public init(consumedScalars: Int, isFullMatch: Bool) {
        self.consumedScalars = consumedScalars
        self.isFullMatch = isFullMatch
    }
}

public struct ABNFMatchNode: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case rule(String)
        case group
        case option
        case repetition(ABNFRepeatRange)
        case literal(ABNFLiteral)
        case numeric(ABNFNumericValue)
        case prose(String)
    }

    public var kind: Kind
    public var range: Range<Int>
    public var children: [ABNFMatchNode]

    public init(kind: Kind, range: Range<Int>, children: [ABNFMatchNode] = []) {
        self.kind = kind
        self.range = range
        self.children = children
    }
}

public struct ABNFMatchTreeResult: Sendable, Equatable {
    public var consumedScalars: Int
    public var isFullMatch: Bool
    public var root: ABNFMatchNode?

    public init(consumedScalars: Int, isFullMatch: Bool, root: ABNFMatchNode?) {
        self.consumedScalars = consumedScalars
        self.isFullMatch = isFullMatch
        self.root = root
    }
}

public enum ABNFMatchError: Error, Sendable, Equatable {
    case unknownRule(String)
    case unsupportedProseValue
    case exceededRecursionDepth
    case exceededStepLimit
}

public struct ABNFSanitizationReport: Sendable, Equatable {
    public struct DroppedLine: Sendable, Equatable {
        public var lineNumber: Int
        public var content: String

        public init(lineNumber: Int, content: String) {
            self.lineNumber = lineNumber
            self.content = content
        }
    }

    public var sanitized: String
    public var droppedLines: [DroppedLine]

    public init(sanitized: String, droppedLines: [DroppedLine]) {
        self.sanitized = sanitized
        self.droppedLines = droppedLines
    }
}

public struct ABNFNonStandardSanitizer: Sendable {
    public init() {}

    public func sanitize(_ text: String) -> ABNFSanitizationReport {
        let lines = text.split(whereSeparator: \.isNewline)
        var sanitized: [String] = []
        var dropped: [ABNFSanitizationReport.DroppedLine] = []

        for (offset, rawLine) in lines.enumerated() {
            let lineNumber = offset + 1
            var line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(";") {
                sanitized.append(line)
                continue
            }
            if trimmed.hasPrefix("case ") || trimmed.hasPrefix("end.") || trimmed.hasPrefix("end;") {
                dropped.append(.init(lineNumber: lineNumber, content: line))
                continue
            }
            if trimmed.contains("_YY") || trimmed.contains("{") || trimmed.contains("}") {
                if let equalsRange = line.range(of: "="),
                   let colonRange = line.range(of: ":", range: equalsRange.upperBound..<line.endIndex) {
                    line = String(line[..<colonRange.lowerBound])
                } else {
                    dropped.append(.init(lineNumber: lineNumber, content: line))
                    continue
                }
            }
            if let equalsRange = line.range(of: "="),
               let colonRange = line.range(of: ":", range: equalsRange.upperBound..<line.endIndex) {
                line = String(line[..<colonRange.lowerBound])
            }
            line = replaceAngleBracketedProse(in: line)
            line = replacePipesWithSlashes(in: line)
            line = replaceNonAsciiInQuotes(in: line)
            line = normalizeQuotedStrings(in: line)
            line = trimTrailingPeriods(in: line)

            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if cleaned.hasPrefix("/") {
                dropped.append(.init(lineNumber: lineNumber, content: line))
                continue
            }
            guard let equalsRange = cleaned.range(of: "=") else {
                dropped.append(.init(lineNumber: lineNumber, content: line))
                continue
            }
            let rhs = cleaned[equalsRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if rhs.isEmpty {
                dropped.append(.init(lineNumber: lineNumber, content: line))
                continue
            }
            if !isParsableRuleLine(line) {
                dropped.append(.init(lineNumber: lineNumber, content: line))
                continue
            }
            sanitized.append(line)
        }

        return ABNFSanitizationReport(sanitized: sanitized.joined(separator: "\n"), droppedLines: dropped)
    }
}

public struct ABNFMatcher: Sendable {
    public enum ProseValuePolicy: Sendable, Equatable {
        case reject
        case matchAny
        case matchAnyNonEmpty
        case matchExact(String)
    }

    public struct Options: Sendable, Equatable {
        public var maxRecursionDepth: Int
        public var maxSteps: Int
        public var useUnicodeCaseFolding: Bool
        public var proseValuePolicy: ProseValuePolicy
        public var enableMemoization: Bool

        public init(maxRecursionDepth: Int = 128, maxSteps: Int = 100_000, useUnicodeCaseFolding: Bool = false, proseValuePolicy: ProseValuePolicy = .reject, enableMemoization: Bool = true) {
            self.maxRecursionDepth = maxRecursionDepth
            self.maxSteps = maxSteps
            self.useUnicodeCaseFolding = useUnicodeCaseFolding
            self.proseValuePolicy = proseValuePolicy
            self.enableMemoization = enableMemoization
        }
    }

    public var options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    public func match(_ input: String, grammar: ABNFGrammar, startRule: String) throws -> ABNFMatchResult {
        guard let rule = grammar.rules[startRule.lowercased()] else {
            throw ABNFMatchError.unknownRule(startRule)
        }

        var matcher = Matcher(
            scalars: Array(input.unicodeScalars),
            grammar: grammar,
            options: options
        )
        let ends = try matcher.matchAlternation(rule.elements, from: 0, depth: 0)
        guard let best = ends.max() else {
            return ABNFMatchResult(consumedScalars: 0, isFullMatch: false)
        }
        return ABNFMatchResult(consumedScalars: best, isFullMatch: best == matcher.scalars.count)
    }

    public func matchFull(_ input: String, grammar: ABNFGrammar, startRule: String) throws -> Bool {
        let result = try match(input, grammar: grammar, startRule: startRule)
        return result.isFullMatch
    }

    public func matchTree(_ input: String, grammar: ABNFGrammar, startRule: String) throws -> ABNFMatchTreeResult {
        guard let rule = grammar.rules[startRule.lowercased()] else {
            throw ABNFMatchError.unknownRule(startRule)
        }

        var matcher = TreeMatcher(
            scalars: Array(input.unicodeScalars),
            grammar: grammar,
            options: options
        )
        if let (end, node) = try matcher.matchRule(rule, from: 0, depth: 0) {
            let isFull = end == matcher.scalars.count
            return ABNFMatchTreeResult(consumedScalars: end, isFullMatch: isFull, root: node)
        }

        return ABNFMatchTreeResult(consumedScalars: 0, isFullMatch: false, root: nil)
    }
}

public struct ABNFParser: Sendable {
    public struct Options: Sendable, Equatable {
        public var allowLeadingWhitespaceInRuleDefinitions: Bool

        public var rejectDuplicateRuleDefinitions: Bool

        public init(allowLeadingWhitespaceInRuleDefinitions: Bool = false, rejectDuplicateRuleDefinitions: Bool = false) {
            self.allowLeadingWhitespaceInRuleDefinitions = allowLeadingWhitespaceInRuleDefinitions
            self.rejectDuplicateRuleDefinitions = rejectDuplicateRuleDefinitions
        }
    }

    public var options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    public func parse(_ source: String) throws -> ABNFGrammar {
        guard !source.isEmpty else {
            throw ABNFParsingError.emptyInput
        }

        var parser = Parser(source: source, options: options)
        return try parser.parseGrammar()
    }
}

private struct Parser {
    private let scalars: [UnicodeScalar]
    private let options: ABNFParser.Options
    private var index: Int
    private var atLineStart: Bool

    init(source: String, options: ABNFParser.Options) {
        self.scalars = Array(source.unicodeScalars)
        self.options = options
        self.index = 0
        self.atLineStart = true
    }

    mutating func parseGrammar() throws -> ABNFGrammar {
        var grammar = ABNFGrammar()

        while true {
            if options.allowLeadingWhitespaceInRuleDefinitions, atLineStart {
                consumeLeadingWSP()
            }
            consumeOptionalCWSP()

            if consumeCNL() {
                continue
            }

            if isAtEnd {
                break
            }

            let rule = try parseRule()
            let normalizedName = rule.name.lowercased()

            if rule.isIncremental, var existing = grammar.rules[normalizedName] {
                existing.elements.options.append(contentsOf: rule.elements.options)
                grammar.rules[normalizedName] = existing
            } else if options.rejectDuplicateRuleDefinitions, !rule.isIncremental, grammar.rules[normalizedName] != nil {
                throw ABNFParsingError.duplicateRule(normalizedName)
            } else {
                grammar.rules[normalizedName] = ABNFRule(name: normalizedName, elements: rule.elements, isIncremental: rule.isIncremental)
            }
        }

        return grammar
    }

    private mutating func parseRule() throws -> ABNFRule {
        let name = try parseRulename()
        consumeOptionalCWSP()

        let isIncremental = try parseDefinedAs()
        consumeOptionalCWSP()

        let elements = try parseElements()
        try consumeCNLOrThrow()

        return ABNFRule(name: name, elements: elements, isIncremental: isIncremental)
    }

    private mutating func parseDefinedAs() throws -> Bool {
        guard matchScalar("=") else {
            throw ABNFParsingError.invalidDefinedAs
        }

        if matchScalar("/") {
            return true
        }

        return false
    }

    private mutating func parseElements() throws -> ABNFAlternation {
        let alternation = try parseAlternation()
        consumeOptionalCWSP()
        return alternation
    }

    private mutating func parseAlternation() throws -> ABNFAlternation {
        var options = [try parseConcatenation()]

        while true {
            consumeOptionalCWSP()
            guard matchScalar("/") else {
                break
            }
            consumeOptionalCWSP()
            options.append(try parseConcatenation())
        }

        return ABNFAlternation(options: options)
    }

    private mutating func parseConcatenation() throws -> ABNFConcatenation {
        var elements = [try parseRepetition()]

        while true {
            let hadWhitespace = consumeRequiredCWSP()
            if !hadWhitespace {
                break
            }

            if isConcatenationTerminator() {
                break
            }

            elements.append(try parseRepetition())
        }

        return ABNFConcatenation(elements: elements)
    }

    private mutating func parseRepetition() throws -> ABNFRepetition {
        if let range = try parseRepeatRange() {
            let element = try parseElement()
            return ABNFRepetition(range: range, element: element)
        }

        let element = try parseElement()
        return ABNFRepetition(element: element)
    }

    private mutating func parseRepeatRange() throws -> ABNFRepeatRange? {
        let startIndex = index

        var digitsBefore = ""
        while let scalar = peekScalar(), isDigit(scalar) {
            digitsBefore.append(Character(scalar))
            advance()
        }

        if matchScalar("*") {
            var digitsAfter = ""
            while let scalar = peekScalar(), isDigit(scalar) {
                digitsAfter.append(Character(scalar))
                advance()
            }

            let minValue = digitsBefore.isEmpty ? 0 : Int(digitsBefore)
            let maxValue = digitsAfter.isEmpty ? nil : Int(digitsAfter)

            guard let min = minValue else {
                throw ABNFParsingError.invalidRepetition
            }

            if let max = maxValue, max < min {
                throw ABNFParsingError.invalidRepetition
            }

            if let max = maxValue, min == max {
                return .exactly(min)
            }
            if maxValue == nil && min > 0 {
                return .atLeast(min)
            }
            return .range(min: digitsBefore.isEmpty ? nil : min, max: maxValue)
        }

        if !digitsBefore.isEmpty {
            guard let exact = Int(digitsBefore) else {
                throw ABNFParsingError.invalidRepetition
            }
            return .exactly(exact)
        }

        index = startIndex
        return nil
    }

    private mutating func parseElement() throws -> ABNFElement {
        guard let scalar = peekScalar() else {
            throw ABNFParsingError.unexpectedEndOfInput
        }

        if isAlpha(scalar) {
            let name = try parseRulename()
            return .ruleReference(name.lowercased())
        }

        if matchScalar("(") {
            consumeOptionalCWSP()
            let alternation = try parseAlternation()
            consumeOptionalCWSP()
            guard matchScalar(")") else {
                throw ABNFParsingError.unexpectedToken
            }
            return .group(alternation)
        }

        if matchScalar("[") {
            consumeOptionalCWSP()
            let alternation = try parseAlternation()
            consumeOptionalCWSP()
            guard matchScalar("]") else {
                throw ABNFParsingError.unexpectedToken
            }
            return .option(alternation)
        }

        if matchScalar("\"") {
            let literal = try parseCharVal()
            return .literal(literal)
        }

        if matchScalar("%") {
            let numeric = try parseNumVal()
            return .numeric(numeric)
        }

        if matchScalar("<") {
            if let ruleReference = try parseAngleBracketRuleReference() {
                return .ruleReference(ruleReference)
            }
            let prose = try parseProseVal()
            return .prose(prose)
        }

        throw ABNFParsingError.unexpectedToken
    }

    private mutating func parseRulename() throws -> String {
        guard let scalar = peekScalar(), isAlpha(scalar) else {
            throw ABNFParsingError.invalidRuleName(String(peekScalar().map(Character.init) ?? Character("?")))
        }

        var name = ""
        name.append(Character(advance()))

        while let next = peekScalar() {
            if isAlpha(next) || isDigit(next) || next == "-" {
                name.append(Character(advance()))
            } else {
                break
            }
        }

        return name
    }

    private mutating func parseCharVal() throws -> ABNFLiteral {
        var value = ""

        while let scalar = peekScalar() {
            if scalar == "\"" {
                advance()
                return ABNFLiteral(text: value, isCaseSensitive: false)
            }

            let codePoint = scalar.value
            let isAllowed = (0x20...0x21).contains(codePoint) || (0x23...0x7E).contains(codePoint)
            guard isAllowed else {
                throw ABNFParsingError.invalidStringLiteral
            }

            value.append(Character(advance()))
        }

        throw ABNFParsingError.unexpectedEndOfInput
    }

    private mutating func parseNumVal() throws -> ABNFNumericValue {
        guard let scalar = peekScalar() else {
            throw ABNFParsingError.unexpectedEndOfInput
        }

        switch scalar {
        case "b":
            advance()
            let sequence = try parseNumericSequence(radix: 2, allowed: { $0 == "0" || $0 == "1" })
            return .binary(sequence)
        case "d":
            advance()
            let sequence = try parseNumericSequence(radix: 10, allowed: isDigit)
            return .decimal(sequence)
        case "x":
            advance()
            let sequence = try parseNumericSequence(radix: 16, allowed: isHexDigit)
            return .hexadecimal(sequence)
        default:
            throw ABNFParsingError.invalidNumericValue
        }
    }

    private mutating func parseNumericSequence(radix: Int, allowed: (UnicodeScalar) -> Bool) throws -> ABNFNumericSequence {
        let first = try parseNumericValue(radix: radix, allowed: allowed)

        if matchScalar(".") {
            var values = [first]
            repeat {
                let value = try parseNumericValue(radix: radix, allowed: allowed)
                values.append(value)
            } while matchScalar(".")
            return .values(values)
        }

        if matchScalar("-") {
            let upper = try parseNumericValue(radix: radix, allowed: allowed)
            return .range(min: first, max: upper)
        }

        return .values([first])
    }

    private mutating func parseNumericValue(radix: Int, allowed: (UnicodeScalar) -> Bool) throws -> UInt32 {
        var digits = ""

        while let scalar = peekScalar(), allowed(scalar) {
            digits.append(Character(advance()))
        }

        guard !digits.isEmpty, let value = UInt32(digits, radix: radix) else {
            throw ABNFParsingError.invalidNumericValue
        }

        return value
    }

    private mutating func parseProseVal() throws -> String {
        var value = ""

        while let scalar = peekScalar() {
            if scalar == ">" {
                advance()
                return value
            }

            let codePoint = scalar.value
            let isAllowed = (0x20...0x3D).contains(codePoint) || (0x3F...0x7E).contains(codePoint)
            guard isAllowed else {
                throw ABNFParsingError.invalidProseValue
            }

            value.append(Character(advance()))
        }

        throw ABNFParsingError.unexpectedEndOfInput
    }

    private mutating func parseAngleBracketRuleReference() throws -> String? {
        let startIndex = index
        do {
            let name = try parseRulename()
            if matchScalar(">") {
                return name.lowercased()
            }
        } catch {
            index = startIndex
            return nil
        }

        index = startIndex
        return nil
    }

    private mutating func consumeOptionalCWSP() {
        while consumeCWSP() {}
    }

    private mutating func consumeRequiredCWSP() -> Bool {
        if consumeCWSP() {
            consumeOptionalCWSP()
            return true
        }
        return false
    }

    private mutating func consumeCWSP() -> Bool {
        if consumeWSP() {
            return true
        }

        let startIndex = index
        if consumeCNL() {
            if consumeWSP() {
                if options.allowLeadingWhitespaceInRuleDefinitions, looksLikeRuleDefinition(at: index) {
                    index = startIndex
                    return false
                }
                return true
            }
        }

        index = startIndex
        return false
    }

    private mutating func consumeCNLOrThrow() throws {
        if !consumeCNL() {
            throw ABNFParsingError.unexpectedToken
        }
    }

    private mutating func consumeCNL() -> Bool {
        if consumeComment() {
            return true
        }

        return consumeCRLF()
    }

    private mutating func consumeComment() -> Bool {
        guard matchScalar(";") else {
            return false
        }

        while let scalar = peekScalar() {
            if scalar == "\r" {
                break
            }

            if !isWSP(scalar) && !isVChar(scalar) {
                return false
            }
            advance()
        }

        return consumeCRLF()
    }

    private mutating func consumeCRLF() -> Bool {
        guard peekScalar() == "\r" else {
            return false
        }
        guard peekScalar(offset: 1) == "\n" else {
            return false
        }
        advance()
        advance()
        atLineStart = true
        return true
    }

    private mutating func consumeWSP() -> Bool {
        guard let scalar = peekScalar(), isWSP(scalar) else {
            return false
        }
        advance()
        return true
    }

    private var isAtEnd: Bool {
        index >= scalars.count
    }

    private func peekScalar(offset: Int = 0) -> UnicodeScalar? {
        let position = index + offset
        guard position < scalars.count else { return nil }
        return scalars[position]
    }

    @discardableResult
    private mutating func advance() -> UnicodeScalar {
        let scalar = scalars[index]
        index += 1
        atLineStart = false
        return scalar
    }

    private mutating func matchScalar(_ value: UnicodeScalar) -> Bool {
        guard let scalar = peekScalar(), scalar == value else {
            return false
        }
        advance()
        return true
    }

    private func isAlpha(_ scalar: UnicodeScalar) -> Bool {
        return ("A"..."Z").contains(scalar) || ("a"..."z").contains(scalar)
    }

    private func isDigit(_ scalar: UnicodeScalar) -> Bool {
        return ("0"..."9").contains(scalar)
    }

    private func isHexDigit(_ scalar: UnicodeScalar) -> Bool {
        return isDigit(scalar) || ("A"..."F").contains(scalar) || ("a"..."f").contains(scalar)
    }

    private func isWSP(_ scalar: UnicodeScalar) -> Bool {
        return scalar == " " || scalar == "\t"
    }

    private func isVChar(_ scalar: UnicodeScalar) -> Bool {
        return (0x21...0x7E).contains(scalar.value)
    }

    private func looksLikeRuleDefinition(at position: Int) -> Bool {
        var pos = position
        while pos < scalars.count, isWSP(scalars[pos]) {
            pos += 1
        }

        guard pos < scalars.count, isAlpha(scalars[pos]) else {
            return false
        }
        pos += 1

        while pos < scalars.count {
            let scalar = scalars[pos]
            if isAlpha(scalar) || isDigit(scalar) || scalar == "-" {
                pos += 1
            } else {
                break
            }
        }

        while pos < scalars.count, isWSP(scalars[pos]) {
            pos += 1
        }

        guard pos < scalars.count, scalars[pos] == "=" else {
            return false
        }

        return true
    }

    private mutating func consumeLeadingWSP() {
        while atLineStart, let scalar = peekScalar(), isWSP(scalar) {
            advance()
        }
    }

    private func isConcatenationTerminator() -> Bool {
        guard let scalar = peekScalar() else {
            return true
        }

        if scalar == "/" || scalar == ")" || scalar == "]" || scalar == ";" {
            return true
        }

        if scalar == "\r" {
            return true
        }

        return false
    }
}

private func replacePipesWithSlashes(in line: String) -> String {
    var result = ""
    var inQuotes = false
    for scalar in line.unicodeScalars {
        if scalar == "\"" {
            inQuotes.toggle()
            result.append(Character(scalar))
            continue
        }
        if scalar == "|" && !inQuotes {
            result.append("/")
        } else {
            result.append(Character(scalar))
        }
    }
    return result
}

private func replaceAngleBracketedProse(in line: String) -> String {
    var result = ""
    var inQuotes = false
    var skipping = false
    for scalar in line.unicodeScalars {
        if scalar == "\"" && !skipping {
            inQuotes.toggle()
            result.append(Character(scalar))
            continue
        }
        if scalar == "<" && !inQuotes {
            skipping = true
            result.append("<prose>")
            continue
        }
        if scalar == ">" && skipping && !inQuotes {
            skipping = false
            continue
        }
        if !skipping {
            result.append(Character(scalar))
        }
    }
    return result
}

private func replaceNonAsciiInQuotes(in line: String) -> String {
    var result = ""
    var inQuotes = false
    for scalar in line.unicodeScalars {
        if scalar == "\"" {
            inQuotes.toggle()
            result.append(Character(scalar))
            continue
        }
        if inQuotes && (scalar.value < 0x20 || scalar.value > 0x7E) {
            result.append("x")
        } else {
            result.append(Character(scalar))
        }
    }
    return result
}

private func normalizeQuotedStrings(in line: String) -> String {
    var result = ""
    var inQuotes = false
    var wrotePlaceholder = false
    for scalar in line.unicodeScalars {
        if scalar == "\"" {
            inQuotes.toggle()
            wrotePlaceholder = false
            result.append(Character(scalar))
            continue
        }
        if inQuotes {
            if !wrotePlaceholder {
                result.append("x")
                wrotePlaceholder = true
            }
            continue
        }
        result.append(Character(scalar))
    }
    return result
}

private func trimTrailingPeriods(in line: String) -> String {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    while trimmed.hasSuffix(".") {
        trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
    }
    return trimmed
}

private func isParsableRuleLine(_ line: String) -> Bool {
    let parser = ABNFParser(options: .init(allowLeadingWhitespaceInRuleDefinitions: true))
    let candidate = line.trimmingCharacters(in: .whitespaces) + "\r\n"
    do {
        _ = try parser.parse(candidate)
        return true
    } catch {
        return false
    }
}

private struct Matcher {
    let scalars: [UnicodeScalar]
    let grammar: ABNFGrammar
    let options: ABNFMatcher.Options
    var steps: Int = 0
    var ruleMemo: [RuleMemoKey: RuleMemoEntry] = [:]

    mutating func matchAlternation(_ alternation: ABNFAlternation, from start: Int, depth: Int) throws -> [Int] {
        try checkLimits(depth: depth)
        var results: [Int] = []
        for option in alternation.options {
            let ends = try matchConcatenation(option, from: start, depth: depth + 1)
            results.append(contentsOf: ends)
        }
        return Array(Set(results)).sorted()
    }

    mutating func matchConcatenation(_ concatenation: ABNFConcatenation, from start: Int, depth: Int) throws -> [Int] {
        try checkLimits(depth: depth)
        var positions: [Int] = [start]
        for repetition in concatenation.elements {
            var newPositions: [Int] = []
            for position in positions {
                let ends = try matchRepetition(repetition, from: position, depth: depth + 1)
                newPositions.append(contentsOf: ends)
            }
            if newPositions.isEmpty {
                return []
            }
            positions = Array(Set(newPositions)).sorted()
        }
        return positions
    }

    mutating func matchRepetition(_ repetition: ABNFRepetition, from start: Int, depth: Int) throws -> [Int] {
        try checkLimits(depth: depth)
        let min = repetition.range.min
        let max = repetition.range.max ?? Int.max

        var currentPositions: [Int] = [start]
        var count = 0
        var allEnds: [Int] = []

        while count < max {
            let nextPositions = try expandPositions(currentPositions, element: repetition.element, depth: depth + 1)
            if nextPositions.isEmpty {
                break
            }

            // Avoid infinite loops when element matches empty.
            if nextPositions == currentPositions {
                break
            }

            count += 1
            currentPositions = Array(Set(nextPositions)).sorted()
            if count >= min {
                allEnds.append(contentsOf: currentPositions)
            }
        }

        if min == 0 {
            allEnds.append(start)
        }

        return Array(Set(allEnds)).sorted()
    }

    mutating func expandPositions(_ positions: [Int], element: ABNFElement, depth: Int) throws -> [Int] {
        try checkLimits(depth: depth)
        var results: [Int] = []
        for position in positions {
            let ends = try matchElement(element, from: position, depth: depth + 1)
            results.append(contentsOf: ends)
        }
        return Array(Set(results)).sorted()
    }

    mutating func matchElement(_ element: ABNFElement, from start: Int, depth: Int) throws -> [Int] {
        try checkLimits(depth: depth)
        steps += 1

        switch element {
        case .ruleReference(let name):
            guard let rule = grammar.rules[name.lowercased()] else {
                throw ABNFMatchError.unknownRule(name)
            }
            return try matchRule(rule, from: start, depth: depth + 1)
        case .group(let alternation):
            return try matchAlternation(alternation, from: start, depth: depth + 1)
        case .option(let alternation):
            var ends = try matchAlternation(alternation, from: start, depth: depth + 1)
            ends.append(start)
            return Array(Set(ends)).sorted()
        case .literal(let literal):
            return matchLiteral(literal, from: start)
        case .numeric(let numeric):
            return matchNumeric(numeric, from: start)
        case .prose:
            return try matchProse(from: start)
        }
    }

    mutating func matchRule(_ rule: ABNFRule, from start: Int, depth: Int) throws -> [Int] {
        if options.enableMemoization {
            let key = RuleMemoKey(name: rule.name, position: start)
            if let entry = ruleMemo[key] {
                switch entry {
                case .inProgress:
                    return []
                case .result(let ends):
                    return ends
                }
            }
            ruleMemo[key] = .inProgress
            let ends = try matchAlternation(rule.elements, from: start, depth: depth + 1)
            ruleMemo[key] = .result(ends)
            return ends
        }

        return try matchAlternation(rule.elements, from: start, depth: depth + 1)
    }

    mutating func matchProse(from start: Int) throws -> [Int] {
        switch options.proseValuePolicy {
        case .reject:
            throw ABNFMatchError.unsupportedProseValue
        case .matchAny:
            return [start, scalars.count]
        case .matchAnyNonEmpty:
            if start < scalars.count {
                return [scalars.count]
            }
            return []
        case .matchExact(let expected):
            let expectedScalars = Array(expected.unicodeScalars)
            guard start + expectedScalars.count <= scalars.count else {
                return []
            }
            for (offset, scalar) in expectedScalars.enumerated() {
                if scalars[start + offset] != scalar {
                    return []
                }
            }
            return [start + expectedScalars.count]
        }
    }

    mutating func matchLiteral(_ literal: ABNFLiteral, from start: Int) -> [Int] {
        let literalScalars = Array(literal.text.unicodeScalars)
        guard start + literalScalars.count <= scalars.count else {
            return []
        }

        if literal.isCaseSensitive {
            for (offset, scalar) in literalScalars.enumerated() {
                let inputScalar = scalars[start + offset]
                if scalar != inputScalar {
                    return []
                }
            }
        } else if options.useUnicodeCaseFolding {
            let input = String(String.UnicodeScalarView(scalars[start..<start + literalScalars.count]))
            if input.lowercased() != literal.text.lowercased() {
                return []
            }
        } else {
            for (offset, scalar) in literalScalars.enumerated() {
                let inputScalar = scalars[start + offset]
                if !equalsIgnoringASCIICase(scalar, inputScalar) {
                    return []
                }
            }
        }

        return [start + literalScalars.count]
    }

    mutating func matchNumeric(_ numeric: ABNFNumericValue, from start: Int) -> [Int] {
        switch numeric {
        case .binary(let sequence),
             .decimal(let sequence),
             .hexadecimal(let sequence):
            return matchNumericSequence(sequence, from: start)
        }
    }

    mutating func matchNumericSequence(_ sequence: ABNFNumericSequence, from start: Int) -> [Int] {
        switch sequence {
        case .values(let values):
            guard start + values.count <= scalars.count else {
                return []
            }
            for (offset, value) in values.enumerated() {
                if scalars[start + offset].value != value {
                    return []
                }
            }
            return [start + values.count]
        case .range(let min, let max):
            guard start < scalars.count else {
                return []
            }
            let value = scalars[start].value
            guard value >= min && value <= max else {
                return []
            }
            return [start + 1]
        }
    }

    mutating func checkLimits(depth: Int) throws {
        if depth > options.maxRecursionDepth {
            throw ABNFMatchError.exceededRecursionDepth
        }
        if steps > options.maxSteps {
            throw ABNFMatchError.exceededStepLimit
        }
    }

    func equalsIgnoringASCIICase(_ lhs: UnicodeScalar, _ rhs: UnicodeScalar) -> Bool {
        let a = asciiLowercased(lhs)
        let b = asciiLowercased(rhs)
        return a == b
    }

    func asciiLowercased(_ scalar: UnicodeScalar) -> UnicodeScalar {
        if scalar.value >= 0x41 && scalar.value <= 0x5A {
            return UnicodeScalar(scalar.value + 0x20) ?? scalar
        }
        return scalar
    }
}

private struct RuleMemoKey: Hashable {
    let name: String
    let position: Int
}

private enum RuleMemoEntry {
    case inProgress
    case result([Int])
}

private struct TreeMatcher {
    let scalars: [UnicodeScalar]
    let grammar: ABNFGrammar
    let options: ABNFMatcher.Options
    var steps: Int = 0
    var ruleMemo: [RuleMemoKey: TreeMemoEntry] = [:]

    mutating func matchRule(_ rule: ABNFRule, from start: Int, depth: Int) throws -> (Int, ABNFMatchNode)? {
        try checkLimits(depth: depth)
        if options.enableMemoization {
            let key = RuleMemoKey(name: rule.name, position: start)
            if let entry = ruleMemo[key] {
                switch entry {
                case .inProgress:
                    return nil
                case .result(let value):
                    return value
                }
            }
            ruleMemo[key] = .inProgress
            let value = try matchRuleInternal(rule, from: start, depth: depth + 1)
            ruleMemo[key] = .result(value)
            return value
        }

        return try matchRuleInternal(rule, from: start, depth: depth + 1)
    }

    private mutating func matchRuleInternal(_ rule: ABNFRule, from start: Int, depth: Int) throws -> (Int, ABNFMatchNode)? {
        guard let (end, children) = try matchAlternation(rule.elements, from: start, depth: depth + 1) else {
            return nil
        }
        let node = ABNFMatchNode(kind: .rule(rule.name), range: start..<end, children: children)
        return (end, node)
    }

    mutating func matchAlternation(_ alternation: ABNFAlternation, from start: Int, depth: Int) throws -> (Int, [ABNFMatchNode])? {
        try checkLimits(depth: depth)
        for option in alternation.options {
            if let (end, nodes) = try matchConcatenation(option, from: start, depth: depth + 1) {
                return (end, nodes)
            }
        }
        return nil
    }

    mutating func matchConcatenation(_ concatenation: ABNFConcatenation, from start: Int, depth: Int) throws -> (Int, [ABNFMatchNode])? {
        try checkLimits(depth: depth)
        return try matchConcatenationElements(concatenation.elements, index: 0, position: start, depth: depth + 1)
    }

    private mutating func matchConcatenationElements(_ elements: [ABNFRepetition], index: Int, position: Int, depth: Int) throws -> (Int, [ABNFMatchNode])? {
        try checkLimits(depth: depth)
        if index >= elements.count {
            return (position, [])
        }

        let repetition = elements[index]
        let variants = try matchRepetitionVariants(repetition, from: position, depth: depth + 1)
        for (end, node) in variants {
            if let (finalEnd, rest) = try matchConcatenationElements(elements, index: index + 1, position: end, depth: depth + 1) {
                return (finalEnd, [node] + rest)
            }
        }

        return nil
    }

    private mutating func matchRepetitionVariants(_ repetition: ABNFRepetition, from start: Int, depth: Int) throws -> [(Int, ABNFMatchNode)] {
        try checkLimits(depth: depth)
        let min = repetition.range.min
        let max = repetition.range.max ?? (scalars.count - start)

        var variants: [(Int, ABNFMatchNode)] = []
        var visited: Set<String> = []

        func key(_ count: Int, _ pos: Int) -> String {
            return "\(count):\(pos)"
        }

        func explore(count: Int, pos: Int, nodes: [ABNFMatchNode]) throws {
            try checkLimits(depth: depth)

            if count >= min {
                let node = ABNFMatchNode(kind: .repetition(repetition.range), range: start..<pos, children: nodes)
                variants.append((pos, node))
            }
            if count >= max {
                return
            }

            let cacheKey = key(count, pos)
            if visited.contains(cacheKey) {
                return
            }
            visited.insert(cacheKey)

            let elementVariants = try matchElementVariants(repetition.element, from: pos, depth: depth + 1)
            for (end, elementNode) in elementVariants {
                if end == pos {
                    continue
                }
                try explore(count: count + 1, pos: end, nodes: nodes + [elementNode])
            }
        }

        try explore(count: 0, pos: start, nodes: [])

        // Greedy preference: sort by longest end first.
        return variants.sorted { $0.0 > $1.0 }
    }

    private mutating func matchElementVariants(_ element: ABNFElement, from start: Int, depth: Int) throws -> [(Int, ABNFMatchNode)] {
        try checkLimits(depth: depth)
        steps += 1

        switch element {
        case .ruleReference(let name):
            guard let rule = grammar.rules[name.lowercased()] else {
                throw ABNFMatchError.unknownRule(name)
            }
            if let value = try matchRule(rule, from: start, depth: depth + 1) {
                return [value]
            }
            return []
        case .group(let alternation):
            if let (end, children) = try matchAlternation(alternation, from: start, depth: depth + 1) {
                let node = ABNFMatchNode(kind: .group, range: start..<end, children: children)
                return [(end, node)]
            }
            return []
        case .option(let alternation):
            var results: [(Int, ABNFMatchNode)] = []
            if let (end, children) = try matchAlternation(alternation, from: start, depth: depth + 1) {
                let node = ABNFMatchNode(kind: .option, range: start..<end, children: children)
                results.append((end, node))
            }
            let empty = ABNFMatchNode(kind: .option, range: start..<start, children: [])
            results.append((start, empty))
            return results
        case .literal(let literal):
            if let end = matchLiteral(literal, from: start) {
                let node = ABNFMatchNode(kind: .literal(literal), range: start..<end, children: [])
                return [(end, node)]
            }
            return []
        case .numeric(let numeric):
            if let end = matchNumeric(numeric, from: start) {
                let node = ABNFMatchNode(kind: .numeric(numeric), range: start..<end, children: [])
                return [(end, node)]
            }
            return []
        case .prose:
            return try matchProseVariants(from: start)
        }
    }

    private mutating func matchProseVariants(from start: Int) throws -> [(Int, ABNFMatchNode)] {
        switch options.proseValuePolicy {
        case .reject:
            throw ABNFMatchError.unsupportedProseValue
        case .matchAny:
            let end = scalars.count
            return [
                (start, ABNFMatchNode(kind: .prose(""), range: start..<start, children: [])),
                (end, ABNFMatchNode(kind: .prose(""), range: start..<end, children: []))
            ]
        case .matchAnyNonEmpty:
            guard start < scalars.count else {
                return []
            }
            let end = scalars.count
            return [(end, ABNFMatchNode(kind: .prose(""), range: start..<end, children: []))]
        case .matchExact(let expected):
            let expectedScalars = Array(expected.unicodeScalars)
            guard start + expectedScalars.count <= scalars.count else {
                return []
            }
            for (offset, scalar) in expectedScalars.enumerated() {
                if scalars[start + offset] != scalar {
                    return []
                }
            }
            let end = start + expectedScalars.count
            return [(end, ABNFMatchNode(kind: .prose(expected), range: start..<end, children: []))]
        }
    }

    private func matchLiteral(_ literal: ABNFLiteral, from start: Int) -> Int? {
        let literalScalars = Array(literal.text.unicodeScalars)
        guard start + literalScalars.count <= scalars.count else {
            return nil
        }

        if literal.isCaseSensitive {
            for (offset, scalar) in literalScalars.enumerated() {
                let inputScalar = scalars[start + offset]
                if scalar != inputScalar {
                    return nil
                }
            }
        } else if options.useUnicodeCaseFolding {
            let input = String(String.UnicodeScalarView(scalars[start..<start + literalScalars.count]))
            if input.lowercased() != literal.text.lowercased() {
                return nil
            }
        } else {
            for (offset, scalar) in literalScalars.enumerated() {
                let inputScalar = scalars[start + offset]
                if !equalsIgnoringASCIICase(scalar, inputScalar) {
                    return nil
                }
            }
        }

        return start + literalScalars.count
    }

    private func matchNumeric(_ numeric: ABNFNumericValue, from start: Int) -> Int? {
        switch numeric {
        case .binary(let sequence),
             .decimal(let sequence),
             .hexadecimal(let sequence):
            return matchNumericSequence(sequence, from: start)
        }
    }

    private func matchNumericSequence(_ sequence: ABNFNumericSequence, from start: Int) -> Int? {
        switch sequence {
        case .values(let values):
            guard start + values.count <= scalars.count else {
                return nil
            }
            for (offset, value) in values.enumerated() {
                if scalars[start + offset].value != value {
                    return nil
                }
            }
            return start + values.count
        case .range(let min, let max):
            guard start < scalars.count else {
                return nil
            }
            let value = scalars[start].value
            guard value >= min && value <= max else {
                return nil
            }
            return start + 1
        }
    }

    mutating func checkLimits(depth: Int) throws {
        if depth > options.maxRecursionDepth {
            throw ABNFMatchError.exceededRecursionDepth
        }
        if steps > options.maxSteps {
            throw ABNFMatchError.exceededStepLimit
        }
    }

    private func equalsIgnoringASCIICase(_ lhs: UnicodeScalar, _ rhs: UnicodeScalar) -> Bool {
        let a = asciiLowercased(lhs)
        let b = asciiLowercased(rhs)
        return a == b
    }

    private func asciiLowercased(_ scalar: UnicodeScalar) -> UnicodeScalar {
        if scalar.value >= 0x41 && scalar.value <= 0x5A {
            return UnicodeScalar(scalar.value + 0x20) ?? scalar
        }
        return scalar
    }
}

private enum TreeMemoEntry {
    case inProgress
    case result((Int, ABNFMatchNode)?)
}

public enum ABNFDefinitions {
    public static let rfc5234ABNF: String = {
        let lines = [
            "rulelist       =  1*( rule / (*c-wsp c-nl) )",
            "rule           =  rulename defined-as elements c-nl",
            "                     ; continues if next line starts",
            "                     ;  with white space",
            "rulename       =  ALPHA *(ALPHA / DIGIT / \"-\")",
            "defined-as     =  *c-wsp (\"=\" / \"=/\") *c-wsp",
            "                     ; basic rules definition and",
            "                     ;  incremental alternatives",
            "elements       =  alternation *c-wsp",
            "c-wsp          =  WSP / (c-nl WSP)",
            "c-nl           =  comment / CRLF",
            "                     ; comment or newline",
            "comment        =  \";\" *(WSP / VCHAR) CRLF",
            "alternation    =  concatenation",
            "                     *(*c-wsp \"/\" *c-wsp concatenation)",
            "concatenation  =  repetition *(1*c-wsp repetition)",
            "repetition     =  [repeat] element",
            "repeat         =  1*DIGIT / (*DIGIT \"*\" *DIGIT)",
            "element        =  rulename / group / option /",
            "                  char-val / num-val / prose-val",
            "group          =  \"(\" *c-wsp alternation *c-wsp \")\"",
            "option         =  \"[\" *c-wsp alternation *c-wsp \"]\"",
            "char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE",
            "                     ; quoted string of SP and VCHAR",
            "                     ;  without DQUOTE",
            "num-val        =  \"%\" (bin-val / dec-val / hex-val)",
            "bin-val        =  \"b\" 1*BIT",
            "                  [ 1*(\".\" 1*BIT) / (\"-\" 1*BIT) ]",
            "                     ; series of concatenated bit values",
            "                     ;  or single ONEOF range",
            "dec-val        =  \"d\" 1*DIGIT",
            "                  [ 1*(\".\" 1*DIGIT) / (\"-\" 1*DIGIT) ]",
            "hex-val        =  \"x\" 1*HEXDIG",
            "                  [ 1*(\".\" 1*HEXDIG) / (\"-\" 1*HEXDIG) ]",
            "prose-val      =  \"<\" *(%x20-3D / %x3F-7E) \">\"",
            "                     ; bracketed string of SP and VCHAR",
            "                     ;  without angles",
            "                     ; prose description, to be used as",
            "                     ;  last resort"
        ]
        return lines.joined(separator: "\r\n") + "\r\n"
    }()
}

public enum ABNFCoreRules {
    public static let grammar: ABNFGrammar = {
        func numericRule(name: String, value: ABNFNumericValue) -> ABNFRule {
            let element = ABNFElement.numeric(value)
            let repetition = ABNFRepetition(element: element)
            let concatenation = ABNFConcatenation(elements: [repetition])
            let alternation = ABNFAlternation(options: [concatenation])
            return ABNFRule(name: name, elements: alternation)
        }

        func literalRule(name: String, text: String) -> ABNFRule {
            let literal = ABNFLiteral(text: text, isCaseSensitive: false)
            let element = ABNFElement.literal(literal)
            let repetition = ABNFRepetition(element: element)
            let concatenation = ABNFConcatenation(elements: [repetition])
            let alternation = ABNFAlternation(options: [concatenation])
            return ABNFRule(name: name, elements: alternation)
        }

        func reference(_ name: String) -> ABNFRepetition {
            return ABNFRepetition(element: .ruleReference(name))
        }

        var rules: [String: ABNFRule] = [:]

        rules["alpha"] = ABNFRule(
            name: "alpha",
            elements: ABNFAlternation(options: [
                ABNFConcatenation(elements: [ABNFRepetition(element: .numeric(.hexadecimal(.range(min: 0x41, max: 0x5A))))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .numeric(.hexadecimal(.range(min: 0x61, max: 0x7A))))])
            ])
        )
        rules["bit"] = ABNFRule(
            name: "bit",
            elements: ABNFAlternation(options: [
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "0")))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "1")))])
            ])
        )
        rules["char"] = numericRule(name: "char", value: .hexadecimal(.range(min: 0x01, max: 0x7F)))
        rules["cr"] = numericRule(name: "cr", value: .hexadecimal(.values([0x0D])))
        rules["lf"] = numericRule(name: "lf", value: .hexadecimal(.values([0x0A])))
        rules["crlf"] = ABNFRule(
            name: "crlf",
            elements: ABNFAlternation(options: [
                ABNFConcatenation(elements: [reference("cr"), reference("lf")])
            ])
        )
        rules["ctl"] = ABNFRule(
            name: "ctl",
            elements: ABNFAlternation(options: [
                ABNFConcatenation(elements: [ABNFRepetition(element: .numeric(.hexadecimal(.range(min: 0x00, max: 0x1F))))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .numeric(.hexadecimal(.values([0x7F]))))])
            ])
        )
        rules["digit"] = numericRule(name: "digit", value: .hexadecimal(.range(min: 0x30, max: 0x39)))
        rules["dquote"] = numericRule(name: "dquote", value: .hexadecimal(.values([0x22])))
        rules["hexdig"] = ABNFRule(
            name: "hexdig",
            elements: ABNFAlternation(options: [
                ABNFConcatenation(elements: [reference("digit")]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "A")))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "B")))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "C")))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "D")))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "E")))]),
                ABNFConcatenation(elements: [ABNFRepetition(element: .literal(ABNFLiteral(text: "F")))])
            ])
        )
        rules["htab"] = numericRule(name: "htab", value: .hexadecimal(.values([0x09])))
        rules["lwsp"] = ABNFRule(
            name: "lwsp",
            elements: ABNFAlternation(options: [
                ABNFConcatenation(elements: [
                    ABNFRepetition(
                        range: .zeroOrMore,
                        element: .group(
                            ABNFAlternation(options: [
                                ABNFConcatenation(elements: [reference("wsp")]),
                                ABNFConcatenation(elements: [reference("crlf"), reference("wsp")])
                            ])
                        )
                    )
                ])
            ])
        )
        rules["octet"] = numericRule(name: "octet", value: .hexadecimal(.range(min: 0x00, max: 0xFF)))
        rules["sp"] = numericRule(name: "sp", value: .hexadecimal(.values([0x20])))
        rules["vchar"] = numericRule(name: "vchar", value: .hexadecimal(.range(min: 0x21, max: 0x7E)))
        rules["wsp"] = ABNFRule(
            name: "wsp",
            elements: ABNFAlternation(options: [
                ABNFConcatenation(elements: [reference("sp")]),
                ABNFConcatenation(elements: [reference("htab")])
            ])
        )

        return ABNFGrammar(rules: rules)
    }()
}
