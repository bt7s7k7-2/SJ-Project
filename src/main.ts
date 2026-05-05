import { readFileSync } from "fs"
import { inspect } from "util"
import { error, print, warn } from "./print.ts"

function formatPointer(input: string, index: number, length = 1) {
    return `\x1b[97m${input}\n\x1b[93m${" ".repeat(index)}${length == 1 ? "^" : "~".repeat(length)}\x1b[0m`
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
    let skippedSymbol = false

    readInput: while (matcher.lastIndex < input.length) {
        const index = matcher.lastIndex

        if (config["lex-skip-symbol"] || config["lex-insert-symbol"]) {
            tryTokens: for (const [token, tokenString] of [
                ["http", "http://"],
                ["ftp", "ftp://"],
                ["telnet", "telnet://"],
                ["mailto", "mailto:"],
            ]) {
                let i = index
                let tokenIndex = 0
                let skippedSymbol = false
                const errors: [string, string, number][] = []

                for (; tokenIndex < tokenString.length && i < input.length; i++, tokenIndex++) {
                    if (config["lex-insert-symbol"] && tokenString[tokenIndex] != input[i]) {
                        errors.push([`Recovering error by inserting symbol ` + JSON.stringify(tokenString[tokenIndex]), input, i])
                        tokenIndex++
                    }

                    if (tokenString[tokenIndex] == input[i]) {
                        skippedSymbol = false
                        continue
                    }

                    if (config["lex-skip-symbol"]) {
                        if (skippedSymbol) {
                            continue tryTokens
                        }

                        skippedSymbol = true
                        tokenIndex--
                        errors.push([`Recovering error by skipping symbol`, input, i])
                        continue
                    }

                    continue tryTokens
                }

                if (tokenIndex + 1 < tokenString.length) {
                    continue tryTokens
                }

                for (const error of errors) logErrorRecovery(...error)
                result.push({ name: token, value: input.slice(index, i), index })
                matcher.lastIndex = i
                continue readInput
            }
        }

        const match = matcher.exec(input)

        if (match == null) {
            if (config["lex-skip-symbol"]) {
                logErrorRecovery(`Attempting to recover error by skipping symbol`, input, index)
                matcher.lastIndex = index + 1
                skippedSymbol = true
                continue
            }
            throw new ParserAbort("Unexpected token", input, index)
        }

        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i]
            const value = match[i + 1]
            if (value) {
                if (skippedSymbol && token != null && result.at(-1)!.name == token) {
                    result.at(-1)!.value += value
                    break
                }

                result.push({ name: token ?? value, value, index })
                skippedSymbol = false
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

function logErrorRecovery(message: string, input: string, index: number, length = 1) {
    warn(message)
    print(formatPointer(input, index, length))
}

function syntacticAnalysis(document: string, table: TransitionTable, tokens: Iterator<Token>) {
    const stack: string[] = ["$"]

    stack.push(table.states[0].name)

    let input = tokens.next()
    const ast: (string | number)[] = []

    let insertedToken: Token | null = null

    readTokens: while (stack.length > 0) {
        const expect = stack.at(-1)!

        if (input.done) {
            throw new ParserAbort("Reached end of input without finishing parsing", document, document.length)
        }

        const token: Token = insertedToken ?? input.value

        print(`\x1b[96mInput:\x1b[0m "\x1b[92m${token.name}\x1b[0m"\x1b[2m;\x1b[22m \x1b[96mStack:\x1b[0m [${stack.map((v, i, a) => i == a.length - 1 ? (
            `\x1b[92m${v}\x1b[0m`
        ) : (
            v
        )).join(", ")}]`)

        if (expect == token.name) {
            print(`  Consume token: \x1b[93m${JSON.stringify(token.name)}\x1b[0m`)
            stack.pop()
            ast.push(token.name == token.value ? token.name : `${token.name}${JSON.stringify(token.value)}`)

            if (insertedToken != null) {
                insertedToken = null
            } else {
                input = tokens.next()
            }

            continue
        }

        const state = table.states.find(v => v.name == expect)
        if (state == null) {
            if (config["syn-insert-token"]) {
                insertedToken = { name: expect, value: "", index: token.index }
                logErrorRecovery("(!) Attempting to recover error by inserting token " + JSON.stringify(expect), document, token.index)
                continue
            }

            if (config["syn-skip-token"] && expect == "$") {
                logErrorRecovery("(!) Attempting to recover error by skipping token", document, token.index, token.value.length || token.name.length)
                input = tokens.next()
                continue
            }

            throw new ParserAbort("Expected " + JSON.stringify(expect), document, token.index)
        }

        const symbolIdx = token.name == "$" ? table.symbols.length : table.symbols.indexOf(token.name)
        if (symbolIdx == -1) {
            throw new Error("Cannot find token in table " + JSON.stringify(token.name))
        }

        const ruleIdx = state.transitions[symbolIdx]
        if (ruleIdx == null) {
            if (config["syn-skip-token"]) {
                logErrorRecovery("(!) Attempting to recover error by skipping token", document, token.index, token.value.length || token.name.length)
                input = tokens.next()
                continue
            }

            const expectedTokens = state.transitions.map((v, i) => v == null ? null : i == table.symbols.length ? "$" : table.symbols[i]).filter(v => v != null)

            if (config["syn-insert-token"]) {
                findTokenToInsert: do {
                    let tokenToInsert: string

                    if (expectedTokens.length == 1) {
                        tokenToInsert = expectedTokens[0]
                    } else if (expectedTokens.length == 3
                        && expectedTokens.includes("digits")
                        && expectedTokens.includes("text")
                        && expectedTokens.includes("text_number")
                    ) {
                        tokenToInsert = "text"
                    } else {
                        break findTokenToInsert
                    }

                    insertedToken = { name: tokenToInsert, value: "", index: token.index }
                    logErrorRecovery("(!) Attempting to recover error by inserting token " + JSON.stringify(tokenToInsert), document, token.index)
                    continue readTokens
                } while (false)
            }

            throw new ParserAbort(`Unexpected token ${JSON.stringify(token.name)}, valid possibilities: ${expectedTokens.join(", ")}`, document, token.index, token.value.length || token.name.length)
        }

        const rule = table.rules[ruleIdx]
        stack.pop()
        print(`  Using rule: \x1b[95m${rule.name}\x1b[0m`)
        ast.push(ruleIdx)
        stack.push(...rule.production.toReversed())
    }

    return ast
}

function printAst(ast: ReturnType<typeof syntacticAnalysis>, table: TransitionTable) {
    let index = 0
    function visit(indent: number, count: number) {
        for (; count > 0 && index <= ast.length; count--) {
            const instruction = ast[index++]

            if (typeof instruction == "number") {
                const rule = table.rules[instruction]

                print(`${"\x1b[2m| \x1b[22m".repeat(indent)}\x1b[95m${rule.name.split(" ")[0]}\x1b[0m`)
                if (rule.production.length == 0) {
                    print(`${"\x1b[2m| \x1b[22m".repeat(indent + 1)}ε`)
                }
                visit(indent + 1, rule.production.length)
            } else {
                print(`${"\x1b[2m| \x1b[22m".repeat(indent)}${instruction}`)
            }
        }
    }

    visit(0, 1)
}

const config = {
    "lex-skip-symbol": false,
    "lex-insert-symbol": false,
    "syn-skip-token": false,
    "syn-insert-token": false,
    "ast": false,
};

(() => {

    const args = process.argv.slice(2)
    while (args.length > 0 && args[0].startsWith("--")) {
        const key = args[0].slice(2)

        if (key in config) {
            config[key as keyof typeof config] = true
        } else {
            error("Invalid argument " + args[0])
            process.exit(1)
        }

        args.shift()
    }
    const input = args[0]

    if (!input) {
        error("Please provide an input as a CLI argument")
        return
    }

    try {
        const tokens = lexicalAnalysis(input)
        print(inspect(tokens, undefined, undefined, true))
        const table: TransitionTable = JSON.parse(readFileSync("table.json", "utf-8"))
        const ast = syntacticAnalysis(input, table, tokens[Symbol.iterator]())
        if (config.ast) printAst(ast, table)
    } catch (err) {
        if (err instanceof ParserAbort) {
            error(err.message + "\n" + formatPointer(err.input, err.index, err.length))
            process.exitCode = 1
            return
        }

        throw err
    }
})()
