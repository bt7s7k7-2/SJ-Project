import { arrayRemove, ensureKey } from "kompa"
import { readFile } from "node:fs/promises"
import { inspect } from "node:util"
import { debug, error, print } from "./print"


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

    public [inspect.custom]() {
        return this.symbols.map(v => v == EPSILON ? (
            "ε"
        ) : typeof v == "string" ? (
            JSON.stringify(v)
        ) : v instanceof SymbolRange ? (
            JSON.stringify(v.from) + ".." + JSON.stringify(v.to)
        ) : v.name).join(" . ")
    }
}

export class NonTerminal {
    public readonly rules: Rule[] = []

    public createRule() {
        const rule = new Rule()
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

        if (parser.matches(/\b([a-zA-Z_']+)\b (:=|→)/y)) {
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

        if (parser.matches(/ε/y)) {
            if (nonTerminal == null) throw new Error(`Unexpected symbol at ${parser.index}`)
            rule ??= nonTerminal.createRule()
            rule.symbols.push(EPSILON)
            continue
        }

        if (parser.matches(/\b([A-Za-z_']+)\b/y)) {
            if (nonTerminal == null) throw new Error(`Unexpected symbol at ${parser.index}`)
            rule ??= nonTerminal.createRule()
            rule.symbols.push(grammar.getNonTerminal(parser.match[1]))
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

void (async () => {
    const grammar = parseGrammar(await readFile(process.argv[2], "utf-8"))
    print(inspect(grammar["_nonTerminals"], false, Infinity, true))

    function formatSymbolAsMath(symbol: RuleSymbol) {
        if (typeof symbol == "string") {
            return JSON.stringify(symbol)
        } else if (symbol == EPSILON) {
            return "ε"
        } else if (symbol instanceof NonTerminal) {
            return JSON.stringify(symbol.name)
        } else {
            return JSON.stringify(symbol.from) + ", dots, " + JSON.stringify(symbol.to)
        }
    }

    const firstSets = new Map<NonTerminal, Set<RuleSymbol>>()
    const derivationEquations = new Map<NonTerminal, string>()
    const workList = [...grammar.nonTerminals()]

    while (workList.length > 0) {
        let previousWorkListLength = workList.length

        nonTerminalLoop: for (const currentNT of [...workList]) {
            debug("Processing " + currentNT.name)

            const discoveredSymbols = new Set<RuleSymbol>()

            let derivationExpressions = new Set<string>()
            for (const rule of currentNT.rules) {
                debug("- Rule:", rule)
                let firstSymbol = rule.symbols[0]

                if (firstSymbol == EPSILON || typeof firstSymbol == "string" || firstSymbol instanceof SymbolRange) {
                    debug("-- Trivial")
                    if (typeof firstSymbol == "string") firstSymbol = firstSymbol[0]
                    discoveredSymbols.add(firstSymbol)
                    derivationExpressions.add(`{${formatSymbolAsMath(firstSymbol)}}`)
                    continue
                }

                const prefixScan: RuleSymbol[] = []
                for (const symbol of rule.symbols) {
                    debug("-- Symbol:", formatSymbolAsMath(symbol))

                    if (symbol == currentNT) {
                        debug("--- SKIP: Circular reference")
                        continue
                    }

                    if (symbol instanceof NonTerminal) {
                        const existingFirstSet = firstSets.get(symbol)
                        if (existingFirstSet == null) {
                            debug("--- ABORT: Cannot find " + symbol.name)
                            continue nonTerminalLoop
                        }

                        prefixScan.push(symbol)
                        for (const value of existingFirstSet) discoveredSymbols.add(value)

                        if (!existingFirstSet.has(EPSILON)) {
                            debug("--- No epsilon, finish")
                            break
                        }

                        continue
                    }

                    prefixScan.push(symbol)
                    discoveredSymbols.add(symbol)
                    break
                }

                prefixScan
                    .map((v, i, a) => v instanceof NonTerminal ? (
                        `F_1(${formatSymbolAsMath(v)})${i < a.length - 1 ? " / {ε}" : ""}`
                    ) : (
                        `${formatSymbolAsMath(v)}`
                    ))
                    .forEach(v => derivationExpressions.add(v))
            }

            derivationEquations.set(currentNT, (
                [...derivationExpressions].join(" union ") + " = " + `{${[...discoveredSymbols].map(formatSymbolAsMath).join(", ")}}`
            ))

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

    if (derivationEquations.size != grammar.size) {
        error("Because FIRST_1 didn't finish, the process cannot continue")
        return
    }
})()
