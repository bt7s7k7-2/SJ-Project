import { arrayRemove, ensureKey } from "kompa"
import { readFile } from "node:fs/promises"
import { inspect } from "node:util"


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

function print(...msgs: any[]) {
    // oxlint-disable-next-line no-console
    console.log(...msgs)
}

void (async () => {
    const grammar = parseGrammar(await readFile(process.argv[2], "utf-8"))
    print(inspect(grammar["_nonTerminals"], false, Infinity, true))

    function symbolToMath(symbol: RuleSymbol) {
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

    const first = new Map<NonTerminal, Set<RuleSymbol>>()
    const solutions = new Map<NonTerminal, string>()
    const pending = [...grammar.nonTerminals()]
    while (true) {
        let prevSize = pending.length

        pendingLoop: for (const nonTerminal of [...pending]) {
            print("Processing " + nonTerminal.name)
            if (nonTerminal.name == "XALPHA") {
                // oxlint-disable-next-line no-debugger
                debugger
            }

            let solution: string[] = []
            const finalResult = new Set<RuleSymbol>()

            let solutionPart = new Set<string>
            for (const part of nonTerminal.rules) {
                print("- Rule:", part)
                let firstSymbol = part.symbols[0]

                if (firstSymbol == EPSILON || typeof firstSymbol == "string" || firstSymbol instanceof SymbolRange) {
                    print("-- Trivial")
                    if (typeof firstSymbol == "string") firstSymbol = firstSymbol[0]
                    finalResult.add(firstSymbol)
                    solutionPart.add(`{${symbolToMath(firstSymbol)}}`)
                    continue
                }

                const compound: RuleSymbol[] = []
                for (const symbol of part.symbols) {
                    print("-- Symbol:", symbolToMath(symbol))

                    if (symbol == nonTerminal) {
                        print("--- SKIP: Circular reference")
                        continue
                    }

                    if (symbol instanceof NonTerminal) {
                        const symbolValue = first.get(symbol)
                        if (symbolValue == null) {
                            print("--- ABORT: Cannot find " + symbol.name)
                            continue pendingLoop
                        }

                        compound.push(symbol)
                        for (const value of symbolValue) finalResult.add(value)

                        if (!symbolValue.has(EPSILON)) {
                            print("--- No epsilon, finish")
                            break
                        }

                        continue
                    }

                    compound.push(symbol)
                    finalResult.add(symbol)
                    break
                }

                for (const v of compound.map((v, i, a) => v instanceof NonTerminal ? `F_1(${symbolToMath(v)})${i < a.length - 1 ? " / {ε}" : ""}` : `${symbolToMath(v)}`)) {
                    solutionPart.add(v)
                }
            }

            solution.push([...solutionPart].join(" union "))
            solution.push(`{${[...finalResult].map(symbolToMath).join(", ")}}`)
            solutions.set(nonTerminal, solution.join(" = "))
            first.set(nonTerminal, finalResult)
            arrayRemove(pending, nonTerminal)
        }

        if (prevSize == pending.length) {
            print("Infinite loop, remaining: " + pending.map(v => v.name).join(", "))
            break
        }

        if (pending.length == 0) {
            break
        }
    }

    for (const nonTerminal of grammar.nonTerminals()) {
        print(`F_1(${JSON.stringify(nonTerminal.name)}) = ${solutions.get(nonTerminal) ?? "???"}`)
    }
})()
