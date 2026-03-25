#import "@preview/rubber-article:0.5.0": *
#import "@preview/datify:1.0.0"

#let _title = "Návrh a overenie metód spracovania a štrukturovania vedeckých textov z dokumentov vo formáte PDF"

// Options reference: https://github.com/npikall/rubber-article/blob/main/src/styles.typ
#show: article.with(
  lang: "sk",
  par-spacing: 1.5em,
  par-first-line-indent: 0em,
  text-size: 11pt,
  text-font: "Arial",
)

#show heading: it => block({
  let num = if it.numbering == none { none } else { counter(heading).display(it.numbering) + h(0.75em) }
  num + it.body
})

#align(center)[
  #title[Jazyk 7.5 — `simpleURL`]
  Branislav Trstenský
]

#set raw(syntaxes: "bnf.sublime-syntax")

= Gramatika

Jazyk v BNF ako definovaný v zadaní.

```bnf
url := httpaddress | ftpaddress | telnetaddress | mailtoaddress
httpaddress := "http://" hostport ["/" path] ["?" search]
ftpaddress := "ftp://" login "/" path
telnetaddress := "telnet://" login
mailtoaddress := "mailto:" xalphas "@" hostname
login := [user [":" password] "@"] hostport
hostport := hostname [":" port]
hostname := xalphas {"." xalphas}
port := digits
path := segment {"/" segment}
search := xalphas {"+" xalphas}
user := xalphas
password := xalphas
segment := {xalpha}
xalphas := xalpha {xalpha}
xalpha := alpha | digit
digits := digit {digit}
alpha := "A" | .. | "Z" | "a" | .. | "z"
digit := "0" | .. | "9"
```

= Transformácia na LL1

== Prepis na pravidlá gramatiky

```BNF
URL → HTTP_ADDRESS
URL → FTP_ADDRESS
URL → TELNET_ADDRESS
URL → MAILTO_ADDRESS
HTTP_ADDRESS → "http://" HOST_PORT
HTTP_ADDRESS → "http://" HOST_PORT "/" PATH
HTTP_ADDRESS → "http://" HOST_PORT "?" SEARCH
HTTP_ADDRESS → "http://" HOST_PORT "/" PATH "?" SEARCH
FTP_ADDRESS → "ftp://" LOGIN "/" PATH
TELNET_ADDRESS → "telnet://" LOGIN
MAILTO_ADDRESS → "mailto:" XALPHAS "@" HOSTNAME
LOGIN → HOST_PORT
LOGIN → USER "@" HOST_PORT
LOGIN → USER ":" PASSWORD "@" HOST_PORT
HOST_PORT → HOSTNAME
HOST_PORT → HOSTNAME ":" PORT
HOSTNAME → XALPHAS
HOSTNAME → XALPHAS "." HOSTNAME
PORT → DIGITS
PATH → SEGMENT
PATH → SEGMENT "/" PATH
SEARCH → XALPHAS
SEARCH → XALPHAS "+" SEARCH
USER → XALPHAS
PASSWORD → XALPHAS
SEGMENT → XALPHAS SEGMENT
SEGMENT → ε
XALPHAS → XALPHA
XALPHAS → XALPHA XALPHAS
XALPHA → ALPHA
XALPHA → DIGIT
DIGITS → DIGIT
DIGITS → DIGIT DIGITS
ALPHA → "A" | .. | "Z" | "a" | .. | "z"
DIGIT → "0" | .. | "9"
```

== Verifikácia že gramaticka je LL1

=== Nájdenie konfliktov

Množiny $"FIRST"_1$:
- $F_1("URL") = F_1("HTTP_ADDRESS") union F_1("FTP_ADDRESS") union F_1("TELNET_ADDRESS") union F_1("MAILTO_ADDRESS") = {"h", "f", "t", "m"}$
- $F_1("HTTP_ADDRESS") = {"h"}$
- $F_1("FTP_ADDRESS") = {"f"}$
- $F_1("TELNET_ADDRESS") = {"t"}$
- $F_1("MAILTO_ADDRESS") = {"m"}$
- $F_1("HOST_PORT") = F_1("HOSTNAME") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("PATH") = F_1("SEGMENT") "/" {ε} union {"/"} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε, "/"}$
- $F_1("SEARCH") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("LOGIN") = F_1("HOST_PORT") union F_1("USER") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("XALPHAS") = F_1("XALPHA") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HOSTNAME") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("USER") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("PASSWORD") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("PORT") = F_1("DIGITS") = {"0", dots, "9"}$
- $F_1("DIGITS") = F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("SEGMENT") = F_1("XALPHAS") union {ε} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε}$
- $F_1("XALPHA") = F_1("ALPHA") union F_1("DIGIT") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("ALPHA") = {"A", dots, "Z"} union {"a", dots, "z"} = {"A", dots, "Z", "a", dots, "z"}$

Množiny $"FOLLOW"_1$:
- $"FO"_1("URL") = {"$"}$
- $"FO"_1("HTTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("FTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("TELNET_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("MAILTO_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("HOST_PORT") = "FO"_1("HTTP_ADDRESS") union {"/"} union {"?"} union "FO"_1("LOGIN") = {"$", "/", "?"}$
- $"FO"_1("PATH") = "FO"_1("HTTP_ADDRESS") union {"?"} union "FO"_1("FTP_ADDRESS") union cancel("FO"_1("PATH")) = {"$", "?"}$
- $"FO"_1("SEARCH") = "FO"_1("HTTP_ADDRESS") union cancel("FO"_1("SEARCH")) = {"$"}$
- $"FO"_1("LOGIN") = {"/"} union "FO"_1("TELNET_ADDRESS") = {"/", "$"}$
- $"FO"_1("XALPHAS") = {"@"} union "FO"_1("SEARCH") union {"+"} union cancel("FO"_1("XALPHAS")) union "FO"_1("HOSTNAME") union {"."} union "FO"_1("USER") union "FO"_1("PASSWORD") union F_1("SEGMENT") "/" {ε} /* XALPHAS . SEGMENT */ union "FO"_1("SEGMENT") = {"@", "$", "+", "/", "?", ":", ".", "A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $"FO"_1("HOSTNAME") = "FO"_1("MAILTO_ADDRESS") union "FO"_1("HOST_PORT") union {":"} union cancel("FO"_1("HOSTNAME")) = {"$", "/", "?", ":"}$
- $"FO"_1("USER") = {"@"} union {":"} = {"@", ":"}$
- $"FO"_1("PASSWORD") = {"@"}$
- $"FO"_1("PORT") = "FO"_1("HOST_PORT") = {"$", "/", "?"}$
- $"FO"_1("DIGITS") = "FO"_1("PORT") union cancel("FO"_1("DIGITS")) = {"$", "/", "?"}$
- $"FO"_1("SEGMENT") = "FO"_1("PATH") union {"/"} union cancel("FO"_1("SEGMENT")) = {"$", "?", "/"}$
- $"FO"_1("XALPHA") = "FO"_1("XALPHAS") union F_1("XALPHAS") /* XALPHA . XALPHAS */ = {"@", "$", "+", "/", "?", ":", ".", "A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $"FO"_1("DIGIT") = "FO"_1("DIGITS") union F_1("DIGITS") /* DIGIT . DIGITS */ union "FO"_1("XALPHA") = {"$", "/", "?", "0", dots, "9", "@", "+", ":", ".", "A", dots, "Z", "a", dots, "z"}$
- $"FO"_1("ALPHA") = "FO"_1("XALPHA") = {"@", "$", "+", "/", "?", ":", ".", "A", dots, "Z", "a", dots, "z", "0", dots, "9"}$

*Pre $"URL"$*:
- $F_1("HTTP_ADDRESS") = {"h"}$
- $F_1("FTP_ADDRESS") = {"f"}$
- $F_1("TELNET_ADDRESS") = {"t"}$
- $F_1("MAILTO_ADDRESS") = {"m"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS"$*:
- $F_1("http:// HOST_PORT") = {"h"}$
- $F_1("http:// HOST_PORT / PATH") = {"h"}$
- $F_1("http:// HOST_PORT ? SEARCH") = {"h"}$
- $F_1("http:// HOST_PORT / PATH ? SEARCH") = {"h"}$
- #text(red)[$"FIRST"_1$ $"FIRST"_1$ konflikt]

*Pre $"FTP_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"TELNET_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"MAILTO_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"LOGIN"$*:
- $F_1("HOST_PORT") = {0, dots, 9, a, dots, z, A, dots, Z}$
- $F_1("USER @ HOST_PORT") = F_1("USER") = {0, dots, 9, a, dots, z, A, dots, Z}$
- $F_1("USER : PASSWORD @ HOST_PORT") = F_1("USER") = {0, dots, 9, a, dots, z, A, dots, Z}$
- #text(red)[$"FIRST"_1$ $"FIRST"_1$ konflikt]

= Lexikálna analýza

== Jednoduché

Protokoly:
- ```bnf http → "http://"```
- ```bnf ftp → "ftp://"```
- ```bnf telnet → "telnet://"```
- ```bnf mailto → "mailto:"```

Rozdelovacie symboly:
- ```bnf ":"```
- ```bnf "?"```
- ```bnf "."```
- ```bnf "@"```
- ```bnf "/"```
- ```bnf "+"```

Relevantné regexy sú triviálne, takže tu nebudú uvedené.

== Identifikátory

Keďže sa ```bnf alpha```, ```bnf digit``` a ```bnf xalpha``` nikdy nevyskytujú osamotene, budú definované tokeny pre ```bnf digits``` (pre definíciu ```bnf port```) a ```bnf xalphas``` pre ostatné výskyty. Definícia pre ```bnf segment``` síce obsahuje ```bnf {xalpha}```, ale toto je ekvivalentné ```bnf [xalphas]```. Budú teda definované tokeny ```bnf TEXT``` a ```bnf NUMBER```


Takže gramatika pre identifikátory je následovná:

```bnf
text → {"A" | .. | "Z" | "a" | .. | "z" | "0" | .. | "9"}
number → {"0" | .. | "9"}
```

A regex je teda:

```js
text = /[A-Za-z0-9]+/
number = /[0-9]+/
```

= Syntaktická analýza

Základná gramatika priamo odvodená z BNF s použitím definovaných tokenov. Keďže niektoré pravidlá obsahujú symbol pre nula alebo jeden výskyt aj popri inom obsahu, boli duplikované  pre všetky možné variácie.

```bnf
URL → HTTP_ADDRESS | FTP_ADDRESS | TELNET_ADDRESS | MAILTO_ADDRESS

HTTP_ADDRESS → http HOST_PORT
HTTP_ADDRESS → http HOST_PORT "/" PATH
HTTP_ADDRESS → http HOST_PORT "?" SEARCH
HTTP_ADDRESS → http HOST_PORT "/" PATH "?" SEARCH

FTP_ADDRESS → ftp LOGIN "/" PATH
TELNET_ADDRESS → telnet LOGIN
MAILTO_ADDRESS → mailto text "@" HOSTNAME

LOGIN → HOST_PORT
LOGIN → USER "@" HOST_PORT
LOGIN → USER ":" PASSWORD "@" HOST_PORT

HOST_PORT → HOSTNAME | HOSTNAME ":" PORT
HOSTNAME → text | text "." HOSTNAME
PORT → DIGITS
PATH → SEGMENT | SEGMENT "/" PATH
SEARCH → text | text "+" SEARCH
USER → text
PASSWORD → text
SEGMENT → text | ε
```

== Konverzia na LL1

