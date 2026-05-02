import { readFileSync } from "fs"
import { inspect } from "util"
import { error, print } from "./print.ts"

function formatPointer(input: string, index: number, length = 1) {
    return `\x1b[97m${input}\n\x1b[93m${" ".repeat(index)}${length == 1 ? "^" : "~".repeat(length)}`
}

class ParserAbort extends Error {
    public override name = "ParserAbort"

    constructor(
        message: string,
        public readonly input: string,
        public readonly index: number,
        public readonly length = 1,
    ) { super(message) }
}

type Token = { name: string, value: string, index: number }

function lexicalAnalysis(input: string) {
    const matcher = /(http:\/\/)|(ftp:\/\/)|(telnet:\/\/)|(mailto:)|([.:?@/+])|([0-9]+[a-z][0-9a-z]*)|([0-9]+)|([a-z][a-z0-9]*)/y

    const tokens = [
        "http",
        "ftp",
        "telnet",
        "mailto",
        null,
        "text_number",
        "digits",
        "text",
    ]

    const result: Token[] = []

    while (matcher.lastIndex < input.length) {
        const index = matcher.lastIndex
        const match = matcher.exec(input)

        if (match == null) {
            throw new ParserAbort("Unexpected token", input, index)
        }

        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i]
            const value = match[i + 1]
            if (value) {
                result.push({ name: token ?? value, value, index })
                break
            }
        }
    }

    result.push({ name: "$", value: "", index: input.length })

    return result
}

interface TransitionTable {
    symbols: string[]
    rules: {
        name: string
        production: string[]
    }[]
    states: {
        name: string
        transitions: (number | null)[]
    }[]
}

function syntacticAnalysis(input: string, tokens: Token[]) {
    const stack: string[] = ["$"]
    const table: TransitionTable = JSON.parse(readFileSync("table.json", "utf-8"))

    stack.push(table.states[0].name)

    let i = 0

    while (stack.length > 0) {
        const expect = stack.at(-1)
        const token = tokens[i]

        print(`\x1b[96mInput:\x1b[0m "\x1b[92m${token.name}\x1b[0m"\x1b[2m;\x1b[22m \x1b[96mStack:\x1b[0m [${stack.map((v, i, a) => i == a.length - 1 ? (
            `\x1b[92m${v}\x1b[0m`
        ) : (
            v
        )).join(", ")}]`)

        if (expect == token.name) {
            print(`  Consume token: \x1b[93m${JSON.stringify(token.name)}\x1b[0m`)
            stack.pop()
            i++
            continue
        }

        const state = table.states.find(v => v.name == expect)
        if (state == null) {
            throw new ParserAbort("Expected " + JSON.stringify(expect), input, token.index)
        }

        const symbolIdx = token.name == "$" ? table.symbols.length : table.symbols.indexOf(token.name)
        if (symbolIdx == -1) {
            throw new Error("Cannot find token in table " + JSON.stringify(token.name))
        }

        const transition = state.transitions[symbolIdx]
        if (transition == null) {
            throw new ParserAbort("Unexpected token " + JSON.stringify(token.name), input, token.index, token.value.length)
        }

        const rule = table.rules[transition]
        stack.pop()
        print(`  Using rule: \x1b[95m${rule.name}\x1b[0m`)
        stack.push(...rule.production.toReversed())
    }
}

(() => {
    const input = process.argv[2]

    if (!input) {
        error("Please provide an input as a CLI argument")
        return
    }

    try {
        const tokens = lexicalAnalysis(input)
        print(inspect(tokens, undefined, undefined, true))
        syntacticAnalysis(input, tokens)
    } catch (err) {
        if (err instanceof ParserAbort) {
            error(err.message + "\n" + formatPointer(err.input, err.index, err.length))
            process.exitCode = 1
            return
        }

        throw err
    }
})()
