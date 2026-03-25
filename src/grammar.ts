import { arrayRemove, EMPTY_SET, ensureKey, iPairs, iteratorNth, unreachable } from "kompa"
import { readFile } from "node:fs/promises"
import { inspect } from "node:util"
import { debug, error, info, print } from "./print"


export class Parser {
    public index = 0
    public match: RegExpMatchArray = null!

    public matches(pattern: RegExp) {
        pattern.lastIndex = this.index
        const match = pattern.exec(this.input)

        if (match) {
            this.match = match
            this.index = pattern.lastIndex
            return true
        }

        return false
    }

    public isEOF() {
        return this.index >= this.input.length
    }

    constructor(
        public readonly input: string,
    ) { }
}

export const EPSILON = Symbol("EPSILON")

export class SymbolRange {
    protected static _flyCache = new Map<string, SymbolRange>()

    public *getValues() {
        const a = this.from.charCodeAt(0)
        const b = this.to.charCodeAt(0)

        for (let i = a; i <= b; i++) {
            yield String.fromCharCode(i)
        }
    }

    constructor(
        public readonly from: string,
        public readonly to: string,
    ) {
        return ensureKey(SymbolRange._flyCache, from + "\0" + to, () => this)
    }
}

export type RuleSymbol = NonTerminal | string | SymbolRange | typeof EPSILON

export class Rule {
    public readonly symbols: RuleSymbol[] = []

    protected _first: Set<RuleSymbol> | null = null

    public toString() {
        return this.symbols.map(v => v == EPSILON ? (
            "ε"
        ) : typeof v == "string" ? (
            v[0] == "\x1b" ? (
                v.slice(1)
            ) : (
                JSON.stringify(v)
            )
        ) : v instanceof SymbolRange ? (
            JSON.stringify(v.from) + ".." + JSON.stringify(v.to)
        ) : v.name).join(" . ")
    }

    public [inspect.custom]() {
        return this.toString()
    }

    constructor(
        public readonly owner: NonTerminal,
    ) { }
}

export class NonTerminal {
    public readonly rules: Rule[] = []

    public createRule() {
        const rule = new Rule(this)
        this.rules.push(rule)
        return rule
    }

    constructor(
        public readonly name: string,
    ) { }
}

export class Grammar {
    protected readonly _nonTerminals = new Map<string, NonTerminal>()

    public get size() { return this._nonTerminals.size }
    public nonTerminals() { return this._nonTerminals.values() }

    public getNonTerminal(name: string) {
        return ensureKey(this._nonTerminals, name, () => new NonTerminal(name))
    }
}

export function parseGrammar(input: string) {
    const parser = new Parser(input)

    const grammar = new Grammar()
    let nonTerminal: NonTerminal | null = null
    let rule: Rule | null = null

    while (!parser.isEOF()) {
        if (parser.matches(/[\s\n]+/y)) {
            continue
        }

        if (parser.matches(/#[^\n]*/y)) {
            continue
        }

        if (parser.matches(/([A-Z_']+) (:=|→)/y)) {
            nonTerminal = grammar.getNonTerminal(parser.match[1])
            if (rule) rule = null
            continue
        }

        if (parser.matches(/"(.)" *\| *\.+ *\| *"(.)"/y)) {
            if (rule != null) throw new Error(`Unexpected range construct at ${parser.index}`)
            if (nonTerminal == null) throw new Error(`Unexpected symbol at ${parser.index}`)
            nonTerminal.createRule().symbols.push(new SymbolRange(parser.match[1], parser.match[2]))
            continue
        }

        if (parser.matches(/"(.*?)"/y)) {
            if (nonTerminal == null) throw new Error(`Unexpected symbol at ${parser.index}`)
            rule ??= nonTerminal.createRule()
            rule.symbols.push(parser.match[1])
            continue
        }

        if (parser.matches(/[a-z]+/y)) {
            if (nonTerminal == null) throw new Error(`Unexpected symbol at ${parser.index}`)
            rule ??= nonTerminal.createRule()
            rule.symbols.push("\x1b" + parser.match[0])
            continue
        }

        if (parser.matches(/ε/y)) {
            if (nonTerminal == null) throw new Error(`Unexpected symbol at ${parser.index}`)
            rule ??= nonTerminal.createRule()
            rule.symbols.push(EPSILON)
            continue
        }

        if (parser.matches(/[A-Z_']+/y)) {
            if (nonTerminal == null) throw new Error(`Unexpected symbol at ${parser.index}`)
            rule ??= nonTerminal.createRule()
            rule.symbols.push(grammar.getNonTerminal(parser.match[0]))
            continue
        }

        if (parser.matches(/\|/y)) {
            rule = null
            continue
        }

        // oxlint-disable-next-line no-debugger
        debugger
        throw new Error(`Unexpected "${parser.input[parser.index]}" at ${parser.index}`)
    }

    return grammar
}

function formatSymbolAsMath(symbol: RuleSymbol) {
    if (typeof symbol == "string") {
        if (symbol[0] == "\x1b") {
            return JSON.stringify(symbol.slice(1))
        }
        return JSON.stringify(symbol)
    } else if (symbol == EPSILON) {
        return "ε"
    } else if (symbol instanceof NonTerminal) {
        return JSON.stringify(symbol.name)
    } else {
        return JSON.stringify(symbol.from) + ", dots, " + JSON.stringify(symbol.to)
    }
}

function getFirstSets(grammar: Grammar) {
    const firstSets = new Map<NonTerminal, Set<RuleSymbol>>()
    const derivationEquations = new Map<NonTerminal, string>()
    const workList = [...grammar.nonTerminals()]

    while (workList.length > 0) {
        let previousWorkListLength = workList.length

        nonTerminalLoop: for (const currentNT of [...workList]) {
            debug("Processing " + currentNT.name)

            const discoveredSymbols = new Set<RuleSymbol>()
            const derivationExpressions = new Set<string>()

            for (const rule of currentNT.rules) {
                debug("- Rule:", rule)
                let firstSymbol = rule.symbols[0]

                if (firstSymbol == EPSILON || typeof firstSymbol == "string" || firstSymbol instanceof SymbolRange) {
                    debug("-- Trivial")
                    if (typeof firstSymbol == "string" && firstSymbol[0] != "\x1b") firstSymbol = firstSymbol[0]
                    discoveredSymbols.add(firstSymbol)
                    derivationExpressions.add(`{${formatSymbolAsMath(firstSymbol)}}`)
                    continue
                }

                for (const [symbol, i] of iPairs(rule.symbols)) {
                    debug("-- Symbol:", formatSymbolAsMath(symbol))

                    if (symbol == currentNT) {
                        debug("--- SKIP: Circular reference")
                        derivationExpressions.add(`cancel(F_1(${formatSymbolAsMath(symbol)}))`)
                        break
                    }


                    if (symbol instanceof NonTerminal) {
                        const existingFirstSet = firstSets.get(symbol)
                        if (existingFirstSet == null) {
                            debug("--- ABORT: Cannot find " + symbol.name)
                            continue nonTerminalLoop
                        }

                        const isLast = i == rule.symbols.length - 1
                        for (const value of existingFirstSet) if (isLast || value != EPSILON) discoveredSymbols.add(value)

                        if (isLast || !existingFirstSet.has(EPSILON)) {
                            debug("--- No epsilon or last, finish")
                            derivationExpressions.add(`F_1(${formatSymbolAsMath(symbol)})`)
                            break
                        }

                        derivationExpressions.add(`F_1(${formatSymbolAsMath(symbol)}) "/" {ε}`)

                        continue
                    }

                    derivationExpressions.add(`{${formatSymbolAsMath(symbol)}}`)
                    discoveredSymbols.add(symbol)
                    break
                }
            }

            const derivation = [...derivationExpressions].join(" union ")
            const result = `{${[...discoveredSymbols].map(formatSymbolAsMath).join(", ")}}`
            if (result == derivation) {
                derivationEquations.set(currentNT, `${result}`)
            } else {
                derivationEquations.set(currentNT, `${derivation} = ${result}`)
            }

            firstSets.set(currentNT, discoveredSymbols)
            arrayRemove(workList, currentNT)
        }

        if (previousWorkListLength == workList.length) {
            error("Infinite loop, remaining: " + workList.map(v => v.name).join(", "))
            break
        }
    }

    for (const nonTerminal of grammar.nonTerminals()) {
        print(`F_1(${JSON.stringify(nonTerminal.name)}) = ${derivationEquations.get(nonTerminal) ?? "???"}`)
    }

    return firstSets
}


function getFollowSets(grammar: Grammar, firstSets: Map<NonTerminal, Set<RuleSymbol>>) {
    const ntReverseIndex = new Map<NonTerminal, Set<Rule>>()
    for (const nonTerminal of grammar.nonTerminals()) {
        for (const rule of nonTerminal.rules) {
            for (const symbol of rule.symbols) {
                if (symbol instanceof NonTerminal) {
                    ensureKey(ntReverseIndex, symbol, () => new Set()).add(rule)
                }
            }
        }
    }

    const startingSymbol = iteratorNth(grammar.nonTerminals())
    info("Starting symbol: " + startingSymbol.name)

    if (startingSymbol == null) {
        throw new Error("No starting symbols")
    }

    const followSets = new Map<NonTerminal, Set<RuleSymbol>>()
    const derivationEquations = new Map<NonTerminal, string>()
    const workList = [...grammar.nonTerminals()]

    while (workList.length > 0) {
        let previousWorkListLength = workList.length

        nonTerminalLoop: for (const currentNT of [...workList]) {
            const rulesThatProduceThisNT = ntReverseIndex.get(currentNT) ?? EMPTY_SET

            const discoveredSymbols = new Set<RuleSymbol>()
            const derivationExpressions = new Set<string>()

            if (currentNT == startingSymbol) {
                discoveredSymbols.add("$")
                derivationExpressions.add(`{"$"}`)
            }

            debug("Processing: " + currentNT.name)

            for (const rule of rulesThatProduceThisNT) {
                debug("- Rule: " + rule)
                ruleSymbolsLoop: for (let i = 0; i < rule.symbols.length; i++) {
                    const symbol = rule.symbols[i]
                    if (symbol != currentNT) continue
                    debug(`-- At: ${i}`)

                    i++
                    for (; i < rule.symbols.length; i++) {
                        const symbol = rule.symbols[i]

                        if (typeof symbol == "string" || symbol instanceof SymbolRange) {
                            debug("--- Trivial: " + formatSymbolAsMath(symbol))
                            discoveredSymbols.add(symbol)
                            derivationExpressions.add(`{${formatSymbolAsMath(symbol)}}`)
                            continue ruleSymbolsLoop
                        }

                        if (!(symbol instanceof NonTerminal)) unreachable()

                        debug("--- NT: " + formatSymbolAsMath(symbol))

                        const existingFirstSet = firstSets.get(symbol) ?? unreachable()
                        for (const v of existingFirstSet) if (v != EPSILON) discoveredSymbols.add(v)

                        if (existingFirstSet.has(EPSILON)) {
                            debug("---- Has epsilon")
                            derivationExpressions.add(`F_1(${formatSymbolAsMath(symbol)}) "/" {ε} /* ${rule.toString()} */`)
                        } else {
                            debug("---- No epsilon, done")
                            derivationExpressions.add(`F_1(${formatSymbolAsMath(symbol)}) /* ${rule.toString()} */`)
                            continue ruleSymbolsLoop
                        }
                    }

                    // Reached end of rule, but there is still a possibility of following, so take follow of the rule owner
                    const ruleOwner = rule.owner
                    debug("--- Fallback to owner: " + ruleOwner.name)
                    if (ruleOwner == currentNT) {
                        debug("---- Recursion")
                        derivationExpressions.add(`cancel("FO"_1(${formatSymbolAsMath(ruleOwner)}))`)
                        break
                    }
                    const ruleOwnerFollowSet = followSets.get(ruleOwner)
                    if (ruleOwnerFollowSet == null) {
                        debug("---- Cannot find, abort")
                        // Wait for the owner's set to be resolved
                        continue nonTerminalLoop
                    }

                    derivationExpressions.add(`"FO"_1(${formatSymbolAsMath(ruleOwner)})`)
                    for (const v of ruleOwnerFollowSet) discoveredSymbols.add(v)
                    debug("---- Added")

                    break
                }
            }

            const derivation = [...derivationExpressions].join(" union ")
            const result = `{${[...discoveredSymbols].map(formatSymbolAsMath).join(", ")}}`
            if (result == derivation) {
                derivationEquations.set(currentNT, `${result}`)
            } else {
                derivationEquations.set(currentNT, `${derivation} = ${result}`)
            }

            followSets.set(currentNT, discoveredSymbols)
            arrayRemove(workList, currentNT)
        }

        if (previousWorkListLength == workList.length) {
            error("Infinite loop, remaining: " + workList.map(v => v.name).join(", "))
            break
        }
    }

    for (const nonTerminal of grammar.nonTerminals()) {
        print(`"FO"_1(${JSON.stringify(nonTerminal.name)}) = ${derivationEquations.get(nonTerminal) ?? "???"}`)
    }

    return followSets
}


void (async () => {
    const grammar = parseGrammar(await readFile(process.argv[2], "utf-8"))
    print(inspect(grammar["_nonTerminals"], false, Infinity, true))

    const firstSets = getFirstSets(grammar)

    if (firstSets.size != grammar.size) {
        error("Because FIRST_1 didn't finish, the process cannot continue")
        return
    }

    const followSets = getFollowSets(grammar, firstSets)

    if (followSets.size != grammar.size) {
        error("Because FOLLOW_1 didn't finish, the process cannot continue")
        return
    }
})()
