#import "@preview/rubber-article:0.5.0": *
#import "@preview/datify:1.0.0"

// Options reference: https://github.com/npikall/rubber-article/blob/main/src/styles.typ
#show: article.with(
  lang: "sk",
  par-spacing: 1.5em,
  par-first-line-indent: 0em,
  text-size: 11pt,
  text-font: "Arial",
)

#show raw.where(block: false, lang: none): it => highlight(
  fill: rgb("#e9e9e9"),
  bottom-edge: -0.3em,
  top-edge: 1em,
  extent: 1.5pt,
  radius: 2pt,
  it,
)

#show heading: it => block({
  let num = if it.numbering == none { none } else { counter(heading).display(it.numbering) + h(0.75em) }
  num + it.body
})

#set raw(syntaxes: "bnf.sublime-syntax")

#align(center)[
  #title[Jazyk 7.5 — `simpleURL`]
  Branislav Trstenský
]


#outline()

= Úvod

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

= Návrh

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
HOSTNAME → HOSTNAME "." XALPHAS
PORT → DIGITS
PATH → SEGMENT
PATH → PATH "/" SEGMENT
SEARCH → XALPHAS
SEARCH → SEARCH "+" XALPHAS
USER → XALPHAS
PASSWORD → XALPHAS
SEGMENT → SEGMENT XALPHA
SEGMENT → ε
XALPHAS → XALPHA
XALPHAS → XALPHAS XALPHA
DIGITS → DIGIT
DIGITS → DIGITS DIGIT
XALPHA → ALPHA
XALPHA → DIGIT
ALPHA → "A" | .. | "Z" | "a" | .. | "z"
DIGIT → "0" | .. | "9"
```

== Transformácie gramatiky do LL1

=== Odstránenie ľavej rekurzie

Existuje ľavá rekurzia v pre tieto neterminály:
- ```bnf SEGMENT```
- ```bnf PATH```
- ```bnf DIGITS```
- ```bnf XALPHAS```
- ```bnf HOSTNAME```
- ```bnf SEARCH```

*Pre* $"PATH" → "SEGMENT" | "PATH" "/" "SEGMENT"$:
- $β_1$: $"SEGMENT"$
- $α_1$: $"/" "SEGMENT"$
- $"PATH" → "SEGMENT" "PATH'"$
- $"PATH'" → "/" "SEGMENT" "PATH'" | ε$

*Pre* $"SEARCH" → "XALPHAS" | "SEARCH" "+" "XALPHAS"$:
- $β_1$: $"XALPHAS"$
- $α_1$: $"+" "XALPHAS"$
- $"SEARCH" → "XALPHAS" "SEARCH'"$
- $"SEARCH'" → "+" "XALPHAS" "SEARCH'" | ε$

*Pre* $"XALPHAS" → "XALPHA" | "XALPHAS" "XALPHA"$:
- $β_1$: $"XALPHA"$
- $α_1$: $"XALPHA"$
- $"XALPHAS" → "XALPHA" "XALPHAS'"$
- $"XALPHAS'" → "XALPHA" "XALPHAS'" | ε$

*Pre* $"HOSTNAME" → "XALPHAS" | "HOSTNAME" "." "XALPHAS"$:
- $β_1$: $"XALPHAS"$
- $α_1$: $"." "XALPHAS"$
- $"HOSTNAME" → "XALPHAS" "HOSTNAME'"$
- $"HOSTNAME'" → "." "XALPHAS" "HOSTNAME'" | ε$

*Pre* $"DIGITS" → "DIGIT" | "DIGITS" "DIGIT"$:
- $β_1$: $"DIGIT"$
- $α_1$: $"DIGIT"$
- $"DIGITS" → "DIGIT" "DIGITS'"$
- $"DIGITS'" → "DIGIT" "DIGITS'" | ε$

*Pre* $"SEGMENT" → "SEGMENT" "XALPHAS" | ε$:
- $β_1$: Žiadne
- $α_1$: $"XALPHAS"$
- $"SEGMENT" → "SEGMENT'"$
- $"SEGMENT'" → "XALPHAS" "SEGMENT'" | ε$

Neterminál $"SEGMENT"$ má teda nové pravidlo, ktoré generuje v každom prípade, equivalentné $"XALPHAS" | ε$, čiže by bolo najjednoduchšie proste definovať $"SEGMENT" → "XALPHAS" | ε$.

=== Odstránenie spoločných prefixov

*Pre neterminál* $"HTTP_ADDRESS"$ *je spoločný prefix* $"http://" "HOST_PORT"$
- $"HTTP_ADDRESS" → "http://" "HOST_PORT" "HTTP_ADDRESS'"$
- $"HTTP_ADDRESS'" → ε | "/" "PATH" | "?" "SEARCH" | "/" "PATH" "?" "SEARCH"$

*Pre neterminál* $"HOST_PORT"$ *je spoločný prefix* $"HOSTNAME"$
- $"HOST_PORT" → "HOSTNAME" "HOST_PORT'"$
- $"HOST_PORT'" → ε | ":" "PORT"$

*Pre neterminál* $"LOGIN"$ *je spoločný prefix* $"USER"$
- $"LOGIN" → "HOST_PORT" | "USER" "LOGIN'"$
- $"LOGIN'" → "@" "HOST_PORT" | ":" "PASSWORD" "@" "HOST_PORT"$

*Pre neterminál* $"HTTP_ADDRESS'"$ *je spoločný prefix* $"/" "PATH"$
- $"HTTP_ADDRESS'" → ε | "?" "SEARCH" | "/" "PATH" "HTTP_ADDRESS''"$
- $"HTTP_ADDRESS''" → ε | "?" "SEARCH"$

=== Nové pravidlá

```bnf
URL → HTTP_ADDRESS
URL → FTP_ADDRESS
URL → TELNET_ADDRESS
URL → MAILTO_ADDRESS
HTTP_ADDRESS → "http://" HOST_PORT HTTP_ADDRESS'
FTP_ADDRESS → "ftp://" LOGIN "/" PATH
TELNET_ADDRESS → "telnet://" LOGIN
MAILTO_ADDRESS → "mailto:" XALPHAS "@" HOSTNAME
HOST_PORT → HOSTNAME HOST_PORT'
PATH → SEGMENT PATH'
SEARCH → XALPHAS SEARCH'
LOGIN → HOST_PORT
LOGIN → USER LOGIN'
XALPHAS → XALPHA XALPHAS'
HOSTNAME → XALPHAS HOSTNAME'
USER → XALPHAS
PASSWORD → XALPHAS
PORT → DIGITS
DIGITS → DIGIT DIGITS'
SEGMENT → XALPHAS | ε
XALPHA → ALPHA
XALPHA → DIGIT
DIGIT → "0" | .. | "9"
ALPHA → "A" | .. | "Z"
ALPHA → "a" | .. | "z"
PATH' → "/" SEGMENT PATH'
PATH' → ε
SEARCH' → "+" XALPHAS SEARCH'
SEARCH' → ε
XALPHAS' → XALPHA XALPHAS'
XALPHAS' → ε
HOSTNAME' → "." XALPHAS HOSTNAME'
HOSTNAME' → ε
DIGITS' → DIGIT DIGITS'
DIGITS' → ε
HTTP_ADDRESS' → ε
HTTP_ADDRESS' → "?" SEARCH
HTTP_ADDRESS' → "/" PATH HTTP_ADDRESS''
HOST_PORT' → ε
HOST_PORT' → ":" PORT
LOGIN' → "@" HOST_PORT
LOGIN' → ":" PASSWORD "@" HOST_PORT
HTTP_ADDRESS'' → ε
HTTP_ADDRESS'' → "?" SEARCH
```

=== Overenie FIRST FOLLOW

$"FIRST"$ sety:
- $F_1("URL") = F_1("HTTP_ADDRESS") union F_1("FTP_ADDRESS") union F_1("TELNET_ADDRESS") union F_1("MAILTO_ADDRESS") = {"h", "f", "t", "m"}$
- $F_1("HTTP_ADDRESS") = {"h"}$
- $F_1("FTP_ADDRESS") = {"f"}$
- $F_1("TELNET_ADDRESS") = {"t"}$
- $F_1("MAILTO_ADDRESS") = {"m"}$
- $F_1("HOST_PORT") = F_1("HOSTNAME") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HTTP_ADDRESS'") = {ε} union {"?"} union {"/"} = {ε, "?", "/"}$
- $F_1("LOGIN") = F_1("HOST_PORT") union F_1("USER") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("PATH") = F_1("SEGMENT") "/" {ε} union F_1("PATH'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "/", ε}$
- $F_1("XALPHAS") = F_1("XALPHA") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HOSTNAME") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HOST_PORT'") = {ε} union {":"} = {ε, ":"}$
- $F_1("SEGMENT") = F_1("XALPHAS") union {ε} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε}$
- $F_1("PATH'") = {"/"} union {ε} = {"/", ε}$
- $F_1("SEARCH") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("SEARCH'") = {"+"} union {ε} = {"+", ε}$
- $F_1("USER") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("LOGIN'") = {"@"} union {":"} = {"@", ":"}$
- $F_1("XALPHA") = F_1("ALPHA") union F_1("DIGIT") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("XALPHAS'") = F_1("XALPHA") union {ε} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε}$
- $F_1("HOSTNAME'") = {"."} union {ε} = {".", ε}$
- $F_1("PASSWORD") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("PORT") = F_1("DIGITS") = {"0", dots, "9"}$
- $F_1("DIGITS") = F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("DIGITS'") = F_1("DIGIT") union {ε} = {"0", dots, "9", ε}$
- $F_1("ALPHA") = {"A", dots, "Z"} union {"a", dots, "z"} = {"A", dots, "Z", "a", dots, "z"}$
- $F_1("HTTP_ADDRESS''") = {ε} union {"?"} = {ε, "?"}$

$"FOLLOW"$ sety:
- $"FO"_1("URL") = {"$"}$
- $"FO"_1("HTTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("FTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("TELNET_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("MAILTO_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("HOST_PORT") = F_1("HTTP_ADDRESS'") "/" {ε} /* "http://" HOST_PORT HTTP_ADDRESS' */ union "FO"_1("HTTP_ADDRESS") union "FO"_1("LOGIN") union "FO"_1("LOGIN'") = {"?", "/", "$"}$
- $"FO"_1("HTTP_ADDRESS'") = "FO"_1("HTTP_ADDRESS") = {"$"}$
- $"FO"_1("LOGIN") = {"/"} union "FO"_1("TELNET_ADDRESS") = {"/", "$"}$
- $"FO"_1("PATH") = "FO"_1("FTP_ADDRESS") union F_1("HTTP_ADDRESS''") "/" {ε} /* "/" PATH HTTP_ADDRESS'' */ union "FO"_1("HTTP_ADDRESS'") = {"$", "?"}$
- $"FO"_1("XALPHAS") = {"@"} union F_1("HOSTNAME'") "/" {ε} /* XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME") union "FO"_1("SEGMENT") union F_1("SEARCH'") "/" {ε} /* XALPHAS SEARCH' */ union "FO"_1("SEARCH") union F_1("SEARCH'") "/" {ε} /* "+" XALPHAS SEARCH' */ union "FO"_1("SEARCH'") union "FO"_1("USER") union F_1("HOSTNAME'") "/" {ε} /* "." XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME'") union "FO"_1("PASSWORD") = {"@", ".", "$", ":", "?", "/", "+"}$
- $"FO"_1("HOSTNAME") = "FO"_1("MAILTO_ADDRESS") union F_1("HOST_PORT'") "/" {ε} /* HOSTNAME HOST_PORT' */ union "FO"_1("HOST_PORT") = {"$", ":", "?", "/"}$
- $"FO"_1("HOST_PORT'") = "FO"_1("HOST_PORT") = {"?", "/", "$"}$
- $"FO"_1("SEGMENT") = F_1("PATH'") "/" {ε} /* SEGMENT PATH' */ union "FO"_1("PATH") union F_1("PATH'") "/" {ε} /* "/" SEGMENT PATH' */ union "FO"_1("PATH'") = {"/", "$", "?"}$
- $"FO"_1("PATH'") = "FO"_1("PATH") union cancel("FO"_1("PATH'")) = {"$", "?"}$
- $"FO"_1("SEARCH") = "FO"_1("HTTP_ADDRESS'") union "FO"_1("HTTP_ADDRESS''") = {"$"}$
- $"FO"_1("SEARCH'") = "FO"_1("SEARCH") union cancel("FO"_1("SEARCH'")) = {"$"}$
- $"FO"_1("USER") = F_1("LOGIN'") /* USER LOGIN' */ = {"@", ":"}$
- $"FO"_1("LOGIN'") = "FO"_1("LOGIN") = {"/", "$"}$
- $"FO"_1("XALPHA") = F_1("XALPHAS'") "/" {ε} /* XALPHA XALPHAS' */ union "FO"_1("XALPHAS") union "FO"_1("XALPHAS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ".", "$", ":", "?", "/", "+"}$
- $"FO"_1("XALPHAS'") = "FO"_1("XALPHAS") union cancel("FO"_1("XALPHAS'")) = {"@", ".", "$", ":", "?", "/", "+"}$
- $"FO"_1("HOSTNAME'") = "FO"_1("HOSTNAME") union cancel("FO"_1("HOSTNAME'")) = {"$", ":", "?", "/"}$
- $"FO"_1("PASSWORD") = {"@"}$
- $"FO"_1("PORT") = "FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- $"FO"_1("DIGITS") = "FO"_1("PORT") = {"?", "/", "$"}$
- $"FO"_1("DIGIT") = "FO"_1("XALPHA") union F_1("DIGITS'") "/" {ε} /* DIGIT DIGITS' */ union "FO"_1("DIGITS") union "FO"_1("DIGITS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ".", "$", ":", "?", "/", "+"}$
- $"FO"_1("DIGITS'") = "FO"_1("DIGITS") union cancel("FO"_1("DIGITS'")) = {"?", "/", "$"}$
- $"FO"_1("ALPHA") = "FO"_1("XALPHA") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ".", "$", ":", "?", "/", "+"}$
- $"FO"_1("HTTP_ADDRESS''") = "FO"_1("HTTP_ADDRESS'") = {"$"}$

*Pre $"URL"$*:
- $F_1("HTTP_ADDRESS") = {"h"}$
- $F_1("FTP_ADDRESS") = {"f"}$
- $F_1("TELNET_ADDRESS") = {"t"}$
- $F_1("MAILTO_ADDRESS") = {"m"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"FTP_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"TELNET_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"MAILTO_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOST_PORT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS'"$*:
- $F_1(ε) = {ε}$
- $F_1("?" "SEARCH") = {"?"}$
- $F_1("/" "PATH" "HTTP_ADDRESS''") = {"/"}$
- $"FO"_1("HTTP_ADDRESS'") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN"$*:
- $F_1("HOST_PORT") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("USER" "LOGIN'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- #text(red)[Konfliktné symboly:] ${"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$

*Pre $"PATH"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"XALPHAS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOST_PORT'"$*:
- $F_1(ε) = {ε}$
- $F_1(":" "PORT") = {":"}$
- $"FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"SEGMENT"$*:
- $F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1(ε) = {ε}$
- $"FO"_1("SEGMENT") = {"/", "$", "?"}$
- #text(olive)[Žiadny konflikt]

*Pre $"PATH'"$*:
- $F_1("/" "SEGMENT" "PATH'") = {"/"}$
- $F_1(ε) = {ε}$
- $"FO"_1("PATH'") = {"$", "?"}$
- #text(olive)[Žiadny konflikt]

*Pre $"SEARCH"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"SEARCH'"$*:
- $F_1("+" "XALPHAS" "SEARCH'") = {"+"}$
- $F_1(ε) = {ε}$
- $"FO"_1("SEARCH'") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"USER"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"LOGIN'"$*:
- $F_1("@" "HOST_PORT") = {"@"}$
- $F_1(":" "PASSWORD" "@" "HOST_PORT") = {":"}$
- #text(olive)[Žiadny konflikt]

*Pre $"XALPHA"$*:
- $F_1("ALPHA") = {"A", dots, "Z", "a", dots, "z"}$
- $F_1("DIGIT") = {"0", dots, "9"}$
- #text(olive)[Žiadny konflikt]

*Pre $"XALPHAS'"$*:
- $F_1("XALPHA" "XALPHAS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1(ε) = {ε}$
- $"FO"_1("XALPHAS'") = {"@", ".", "$", ":", "?", "/", "+"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME'"$*:
- $F_1("." "XALPHAS" "HOSTNAME'") = {"."}$
- $F_1(ε) = {ε}$
- $"FO"_1("HOSTNAME'") = {"$", ":", "?", "/"}$
- #text(olive)[Žiadny konflikt]

*Pre $"PASSWORD"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"PORT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"DIGITS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"DIGIT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"DIGITS'"$*:
- $F_1("DIGIT" "DIGITS'") = {"0", dots, "9"}$
- $F_1(ε) = {ε}$
- $"FO"_1("DIGITS'") = {"?", "/", "$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"ALPHA"$*:
- $F_1("A"dots"Z") = {"A", dots, "Z"}$
- $F_1("a"dots"z") = {"a", dots, "z"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS''"$*:
- $F_1(ε) = {ε}$
- $F_1("?" "SEARCH") = {"?"}$
- $"FO"_1("HTTP_ADDRESS''") = {"$"}$
- #text(olive)[Žiadny konflikt]

=== Oprava pre $"LOGIN"$

Je tu problém z pravidlami pre neterminál $"LOGIN"$. Tento neterminál generuje neterminály $"HOST_PORT"$ a $"USER"$, ktoré generujú $"XALPHAS"$ ako prvú (v pripade $"HOSTPORT"$, ten generuje $"HOSTNAME"$, ktorý nasledne generuje $"XALPHAS"$). Toto je v podstate prípad spoločného prefixu, ktorý však nebol opravený z dôvodu medzistavov.

Aby bolo možné opraviť, musia byť tieto medzistavy inline-nuté priamo do $"LOGIN"$, aby bolo možné správne urobiť ľavú faktorizáciu a získať platnú LL1 gramatiku. Kvôli tejto zmene je tiež možné eliminovať neterminály $"USER"$ a $"PASSWORD"$, keďže sa už nikde inde nepoužívajú.

*Nové pravidlá pre* $"LOGIN"$*:*
```bnf
LOGIN → XALPHAS "." XALPHAS HOSTNAME' HOST_PORT'
LOGIN → XALPHAS ":" XALPHAS
LOGIN → XALPHAS "@" HOST_PORT
LOGIN → XALPHAS ":" XALPHAS "@" HOST_PORT
```

*Pre neterminál* $"LOGIN"$ *je spoločný prefix* $"XALPHAS"$
- $"LOGIN" → "XALPHAS" "LOGIN'"$
- $"LOGIN'" → "." "XALPHAS" "HOSTNAME'" "HOST_PORT'" | ":" "XALPHAS" | "@" "HOST_PORT" | ":" "XALPHAS" "@" "HOST_PORT"$

*Pre neterminál* $"LOGIN'"$ *je spoločný prefix* $":" "XALPHAS"$
- $"LOGIN'" → "." "XALPHAS" "HOSTNAME'" "HOST_PORT'" | "@" "HOST_PORT" | ":" "XALPHAS" "LOGIN''"$
- $"LOGIN''" → ε | "@" "HOST_PORT"$

*Výsledok:*
```bnf
URL → HTTP_ADDRESS
URL → FTP_ADDRESS
URL → TELNET_ADDRESS
URL → MAILTO_ADDRESS
HTTP_ADDRESS → "http://" HOST_PORT HTTP_ADDRESS'
FTP_ADDRESS → "ftp://" LOGIN "/" PATH
TELNET_ADDRESS → "telnet://" LOGIN
MAILTO_ADDRESS → "mailto:" XALPHAS "@" HOSTNAME
HOST_PORT → HOSTNAME HOST_PORT'
HTTP_ADDRESS' → ε
HTTP_ADDRESS' → "?" SEARCH
HTTP_ADDRESS' → "/" PATH HTTP_ADDRESS''
LOGIN → XALPHAS LOGIN'
PATH → SEGMENT PATH'
XALPHAS → XALPHA XALPHAS'
HOSTNAME → XALPHAS HOSTNAME'
HOST_PORT' → ε
HOST_PORT' → ":" PORT
SEGMENT → XALPHAS
SEGMENT → ε
PATH' → "/" SEGMENT PATH'
PATH' → ε
SEARCH → XALPHAS SEARCH'
SEARCH' → "+" XALPHAS SEARCH'
SEARCH' → ε
HOSTNAME' → "." XALPHAS HOSTNAME'
HOSTNAME' → ε
XALPHA → ALPHA
XALPHA → DIGIT
XALPHAS' → XALPHA XALPHAS'
XALPHAS' → ε
PORT → DIGITS
DIGITS → DIGIT DIGITS'
DIGIT → "0" | .. | "9"
DIGITS' → DIGIT DIGITS'
DIGITS' → ε
ALPHA → "A" | .. | "Z"
ALPHA → "a" | .. | "z"
HTTP_ADDRESS'' → ε
HTTP_ADDRESS'' → "?" SEARCH
LOGIN' → "." XALPHAS HOSTNAME' HOST_PORT'
LOGIN' → "@" HOST_PORT
LOGIN' → ":" XALPHAS LOGIN''
LOGIN'' → ε
LOGIN'' → "@" HOST_PORT
```

=== Overenie FIRST FOLLOW

$"FIRST"$ sety:
- $F_1("URL") = F_1("HTTP_ADDRESS") union F_1("FTP_ADDRESS") union F_1("TELNET_ADDRESS") union F_1("MAILTO_ADDRESS") = {"h", "f", "t", "m"}$
- $F_1("HTTP_ADDRESS") = {"h"}$
- $F_1("FTP_ADDRESS") = {"f"}$
- $F_1("TELNET_ADDRESS") = {"t"}$
- $F_1("MAILTO_ADDRESS") = {"m"}$
- $F_1("HOST_PORT") = F_1("HOSTNAME") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HTTP_ADDRESS'") = {ε} union {"?"} union {"/"} = {ε, "?", "/"}$
- $F_1("LOGIN") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("PATH") = F_1("SEGMENT") "/" {ε} union F_1("PATH'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "/", ε}$
- $F_1("XALPHAS") = F_1("XALPHA") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HOSTNAME") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HOST_PORT'") = {ε} union {":"} = {ε, ":"}$
- $F_1("SEARCH") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("HTTP_ADDRESS''") = {ε} union {"?"} = {ε, "?"}$
- $F_1("LOGIN'") = {"."} union {"@"} union {":"} = {".", "@", ":"}$
- $F_1("SEGMENT") = F_1("XALPHAS") union {ε} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε}$
- $F_1("PATH'") = {"/"} union {ε} = {"/", ε}$
- $F_1("XALPHA") = F_1("ALPHA") union F_1("DIGIT") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("XALPHAS'") = F_1("XALPHA") union {ε} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε}$
- $F_1("HOSTNAME'") = {"."} union {ε} = {".", ε}$
- $F_1("PORT") = F_1("DIGITS") = {"0", dots, "9"}$
- $F_1("SEARCH'") = {"+"} union {ε} = {"+", ε}$
- $F_1("ALPHA") = {"A", dots, "Z"} union {"a", dots, "z"} = {"A", dots, "Z", "a", dots, "z"}$
- $F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("DIGITS") = F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("DIGITS'") = F_1("DIGIT") union {ε} = {"0", dots, "9", ε}$
- $F_1("LOGIN''") = {ε} union {"@"} = {ε, "@"}$

$"FOLLOW"$ sety:
- $"FO"_1("URL") = {"$"}$
- $"FO"_1("HTTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("FTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("TELNET_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("MAILTO_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("HOST_PORT") = F_1("HTTP_ADDRESS'") "/" {ε} /* "http://" HOST_PORT HTTP_ADDRESS' */ union "FO"_1("HTTP_ADDRESS") union "FO"_1("LOGIN'") union "FO"_1("LOGIN''") = {"?", "/", "$"}$
- $"FO"_1("HTTP_ADDRESS'") = "FO"_1("HTTP_ADDRESS") = {"$"}$
- $"FO"_1("LOGIN") = {"/"} union "FO"_1("TELNET_ADDRESS") = {"/", "$"}$
- $"FO"_1("PATH") = "FO"_1("FTP_ADDRESS") union F_1("HTTP_ADDRESS''") "/" {ε} /* "/" PATH HTTP_ADDRESS'' */ union "FO"_1("HTTP_ADDRESS'") = {"$", "?"}$
- $"FO"_1("XALPHAS") = {"@"} union F_1("LOGIN'") /* XALPHAS LOGIN' */ union F_1("HOSTNAME'") "/" {ε} /* XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME") union F_1("SEARCH'") "/" {ε} /* XALPHAS SEARCH' */ union "FO"_1("SEARCH") union F_1("HOSTNAME'") "/" {ε} /* "." XALPHAS HOSTNAME' HOST_PORT' */ union F_1("HOST_PORT'") "/" {ε} /* "." XALPHAS HOSTNAME' HOST_PORT' */ union "FO"_1("LOGIN'") union F_1("LOGIN''") "/" {ε} /* ":" XALPHAS LOGIN'' */ union "FO"_1("SEGMENT") union F_1("HOSTNAME'") "/" {ε} /* "." XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME'") union F_1("SEARCH'") "/" {ε} /* "+" XALPHAS SEARCH' */ union "FO"_1("SEARCH'") = {"@", ".", ":", "$", "?", "/", "+"}$
- $"FO"_1("HOSTNAME") = "FO"_1("MAILTO_ADDRESS") union F_1("HOST_PORT'") "/" {ε} /* HOSTNAME HOST_PORT' */ union "FO"_1("HOST_PORT") = {"$", ":", "?", "/"}$
- $"FO"_1("HOST_PORT'") = "FO"_1("HOST_PORT") union "FO"_1("LOGIN'") = {"?", "/", "$"}$
- $"FO"_1("SEARCH") = "FO"_1("HTTP_ADDRESS'") union "FO"_1("HTTP_ADDRESS''") = {"$"}$
- $"FO"_1("HTTP_ADDRESS''") = "FO"_1("HTTP_ADDRESS'") = {"$"}$
- $"FO"_1("LOGIN'") = "FO"_1("LOGIN") = {"/", "$"}$
- $"FO"_1("SEGMENT") = F_1("PATH'") "/" {ε} /* SEGMENT PATH' */ union "FO"_1("PATH") union F_1("PATH'") "/" {ε} /* "/" SEGMENT PATH' */ union "FO"_1("PATH'") = {"/", "$", "?"}$
- $"FO"_1("PATH'") = "FO"_1("PATH") union cancel("FO"_1("PATH'")) = {"$", "?"}$
- $"FO"_1("XALPHA") = F_1("XALPHAS'") "/" {ε} /* XALPHA XALPHAS' */ union "FO"_1("XALPHAS") union "FO"_1("XALPHAS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ".", ":", "$", "?", "/", "+"}$
- $"FO"_1("XALPHAS'") = "FO"_1("XALPHAS") union cancel("FO"_1("XALPHAS'")) = {"@", ".", ":", "$", "?", "/", "+"}$
- $"FO"_1("HOSTNAME'") = "FO"_1("HOSTNAME") union F_1("HOST_PORT'") "/" {ε} /* "." XALPHAS HOSTNAME' HOST_PORT' */ union "FO"_1("LOGIN'") union cancel("FO"_1("HOSTNAME'")) = {"$", ":", "?", "/"}$
- $"FO"_1("PORT") = "FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- $"FO"_1("SEARCH'") = "FO"_1("SEARCH") union cancel("FO"_1("SEARCH'")) = {"$"}$
- $"FO"_1("ALPHA") = "FO"_1("XALPHA") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ".", ":", "$", "?", "/", "+"}$
- $"FO"_1("DIGIT") = "FO"_1("XALPHA") union F_1("DIGITS'") "/" {ε} /* DIGIT DIGITS' */ union "FO"_1("DIGITS") union "FO"_1("DIGITS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ".", ":", "$", "?", "/", "+"}$
- $"FO"_1("DIGITS") = "FO"_1("PORT") = {"?", "/", "$"}$
- $"FO"_1("DIGITS'") = "FO"_1("DIGITS") union cancel("FO"_1("DIGITS'")) = {"?", "/", "$"}$
- $"FO"_1("LOGIN''") = "FO"_1("LOGIN'") = {"/", "$"}$

*Pre $"URL"$*:
- $F_1("HTTP_ADDRESS") = {"h"}$
- $F_1("FTP_ADDRESS") = {"f"}$
- $F_1("TELNET_ADDRESS") = {"t"}$
- $F_1("MAILTO_ADDRESS") = {"m"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"FTP_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"TELNET_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"MAILTO_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOST_PORT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS'"$*:
- $F_1(ε) = {ε}$
- $F_1("?" "SEARCH") = {"?"}$
- $F_1("/" "PATH" "HTTP_ADDRESS''") = {"/"}$
- $"FO"_1("HTTP_ADDRESS'") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"PATH"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"XALPHAS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOST_PORT'"$*:
- $F_1(ε) = {ε}$
- $F_1(":" "PORT") = {":"}$
- $"FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"SEARCH"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS''"$*:
- $F_1(ε) = {ε}$
- $F_1("?" "SEARCH") = {"?"}$
- $"FO"_1("HTTP_ADDRESS''") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN'"$*:
- $F_1("." "XALPHAS" "HOSTNAME'" "HOST_PORT'") = {"."}$
- $F_1("@" "HOST_PORT") = {"@"}$
- $F_1(":" "XALPHAS" "LOGIN''") = {":"}$
- #text(olive)[Žiadny konflikt]

*Pre $"SEGMENT"$*:
- $F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1(ε) = {ε}$
- $"FO"_1("SEGMENT") = {"/", "$", "?"}$
- #text(olive)[Žiadny konflikt]

*Pre $"PATH'"$*:
- $F_1("/" "SEGMENT" "PATH'") = {"/"}$
- $F_1(ε) = {ε}$
- $"FO"_1("PATH'") = {"$", "?"}$
- #text(olive)[Žiadny konflikt]

*Pre $"XALPHA"$*:
- $F_1("ALPHA") = {"A", dots, "Z", "a", dots, "z"}$
- $F_1("DIGIT") = {"0", dots, "9"}$
- #text(olive)[Žiadny konflikt]

*Pre $"XALPHAS'"$*:
- $F_1("XALPHA" "XALPHAS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1(ε) = {ε}$
- $"FO"_1("XALPHAS'") = {"@", ".", ":", "$", "?", "/", "+"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME'"$*:
- $F_1("." "XALPHAS" "HOSTNAME'") = {"."}$
- $F_1(ε) = {ε}$
- $"FO"_1("HOSTNAME'") = {"$", ":", "?", "/"}$
- #text(olive)[Žiadny konflikt]

*Pre $"PORT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"SEARCH'"$*:
- $F_1("+" "XALPHAS" "SEARCH'") = {"+"}$
- $F_1(ε) = {ε}$
- $"FO"_1("SEARCH'") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"ALPHA"$*:
- $F_1("A"dots"Z") = {"A", dots, "Z"}$
- $F_1("a"dots"z") = {"a", dots, "z"}$
- #text(olive)[Žiadny konflikt]

*Pre $"DIGIT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"DIGITS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"DIGITS'"$*:
- $F_1("DIGIT" "DIGITS'") = {"0", dots, "9"}$
- $F_1(ε) = {ε}$
- $"FO"_1("DIGITS'") = {"?", "/", "$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN''"$*:
- $F_1(ε) = {ε}$
- $F_1("@" "HOST_PORT") = {"@"}$
- $"FO"_1("LOGIN''") = {"/", "$"}$
- #text(olive)[Žiadny konflikt]

=== Jednoduché

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

=== Identifikátory

Keďže sa $"ALPHA"$, $"DIGIT"$ a $"XALPHA"$ nikdy nevyskytujú osamotene, budú definované tokeny pre $"DIGITS"$ (pre definíciu $"PORT"$) a $"XALPHAS"$ pre ostatné výskyty.

Takže pravidlá pre identifikátory môže byť následovná:

```bnf
xalphas → ("A" | .. | "Z" | "a" | .. | "z" | "0" | .. | "9")+
digits → ("0" | .. | "9")+
```

Tieto identifikátory sa však nedajú rozoznať, pretože každý ```bnf digits``` je aj platný ```bnf xalphas``` ­— doteraz to bolo možné vďaka tomu že lexikálne a syntaktická analýze prebehla súčasne, ale bez informácie, kde v syntaktickom strome sme, tieto pravidlá nestačia.

Keďže jediné využitie ```bnf digits``` je v $"PORT"$, existujú následovné možnosti:
- Iba číslo (akceptované všade)
- Čísla aj písmena (akceptované všade okrem $"PORT"$):
  - Identifikátor, ktorý začína s číslom ale obsahuje aj písmená
  - Identifikátor, ktorý začína s písmenom

Pravidla budú teda upravené následovne:

```bnf
digits → ("0" | .. | "9")+
text_number → ("0" | .. | "9")+ ("a" | .. | "z") ("A" | .. | "Z" | "a" | .. | "z" | "0" | .. | "9")*
text_normal → ("a" | .. | "z") ("A" | .. | "Z" | "a" | .. | "z" | "0" | .. | "9")*
```
Potom redefinujeme syntaktické pravidlo takto:
```bnf
xalphas → text_number | digits | text
```

Pre lexikálnu analýzu potom môžme použiť greedy prístup pre vyriešenie nedeterminizmu —  regexy sú teda následovné, aplikované v tomto poradí kým jeden nebude akceptovaný:

```js
text_number = /[0-9]+[a-z][0-9a-z]*/
digits = /[0-9]+/
text = /[a-z][a-z0-9]*/
```

== Syntaktická analýza

=== Syntaktické pravidlá

```bnf
URL → HTTP_ADDRESS
URL → FTP_ADDRESS
URL → TELNET_ADDRESS
URL → MAILTO_ADDRESS
HTTP_ADDRESS → http HOST_PORT HTTP_ADDRESS'
FTP_ADDRESS → ftp LOGIN "/" PATH
TELNET_ADDRESS → telnet LOGIN
MAILTO_ADDRESS → mailto XALPHAS "@" HOSTNAME
HOST_PORT → HOSTNAME HOST_PORT'
HTTP_ADDRESS' → ε
HTTP_ADDRESS' → "?" SEARCH
HTTP_ADDRESS' → "/" PATH HTTP_ADDRESS''
LOGIN → XALPHAS LOGIN'
PATH → SEGMENT PATH'
XALPHAS → text_number | digits | text
HOSTNAME → XALPHAS HOSTNAME'
HOST_PORT' → ε
HOST_PORT' → ":" PORT
SEGMENT → XALPHAS
SEGMENT → ε
PATH' → "/" SEGMENT PATH'
PATH' → ε
SEARCH → XALPHAS SEARCH'
SEARCH' → "+" XALPHAS SEARCH'
SEARCH' → ε
HOSTNAME' → "." XALPHAS HOSTNAME'
HOSTNAME' → ε
PORT → digits
HTTP_ADDRESS'' → ε
HTTP_ADDRESS'' → "?" SEARCH
LOGIN' → "." XALPHAS HOSTNAME' HOST_PORT'
LOGIN' → "@" HOST_PORT
LOGIN' → ":" XALPHAS LOGIN''
LOGIN'' → ε
LOGIN'' → "@" HOST_PORT
```

=== FIRST a FOLLOW

$"FIRST"$ sety:
- $F_1("URL") = F_1("HTTP_ADDRESS") union F_1("FTP_ADDRESS") union F_1("TELNET_ADDRESS") union F_1("MAILTO_ADDRESS") = {"http", "ftp", "telnet", "mailto"}$
- $F_1("HTTP_ADDRESS") = {"http"}$
- $F_1("FTP_ADDRESS") = {"ftp"}$
- $F_1("TELNET_ADDRESS") = {"telnet"}$
- $F_1("MAILTO_ADDRESS") = {"mailto"}$
- $F_1("HOST_PORT") = F_1("HOSTNAME") = {"text_number", "digits", "text"}$
- $F_1("HTTP_ADDRESS'") = {ε} union {"?"} union {"/"} = {ε, "?", "/"}$
- $F_1("LOGIN") = F_1("XALPHAS") = {"text_number", "digits", "text"}$
- $F_1("PATH") = F_1("SEGMENT") "/" {ε} union F_1("PATH'") = {"text_number", "digits", "text", "/", ε}$
- $F_1("XALPHAS") = {"text_number"} union {"digits"} union {"text"} = {"text_number", "digits", "text"}$
- $F_1("HOSTNAME") = F_1("XALPHAS") = {"text_number", "digits", "text"}$
- $F_1("HOST_PORT'") = {ε} union {":"} = {ε, ":"}$
- $F_1("SEARCH") = F_1("XALPHAS") = {"text_number", "digits", "text"}$
- $F_1("HTTP_ADDRESS''") = {ε} union {"?"} = {ε, "?"}$
- $F_1("LOGIN'") = {"."} union {"@"} union {":"} = {".", "@", ":"}$
- $F_1("SEGMENT") = F_1("XALPHAS") union {ε} = {"text_number", "digits", "text", ε}$
- $F_1("PATH'") = {"/"} union {ε} = {"/", ε}$
- $F_1("HOSTNAME'") = {"."} union {ε} = {".", ε}$
- $F_1("PORT") = {"digits"}$
- $F_1("SEARCH'") = {"+"} union {ε} = {"+", ε}$
- $F_1("LOGIN''") = {ε} union {"@"} = {ε, "@"}$

$"FOLLOW"$ sety:
- $"FO"_1("URL") = {"$"}$
- $"FO"_1("HTTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("FTP_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("TELNET_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("MAILTO_ADDRESS") = "FO"_1("URL") = {"$"}$
- $"FO"_1("HOST_PORT") = F_1("HTTP_ADDRESS'") "/" {ε} /* http HOST_PORT HTTP_ADDRESS' */ union "FO"_1("HTTP_ADDRESS") union "FO"_1("LOGIN'") union "FO"_1("LOGIN''") = {"?", "/", "$"}$
- $"FO"_1("HTTP_ADDRESS'") = "FO"_1("HTTP_ADDRESS") = {"$"}$
- $"FO"_1("LOGIN") = {"/"} union "FO"_1("TELNET_ADDRESS") = {"/", "$"}$
- $"FO"_1("PATH") = "FO"_1("FTP_ADDRESS") union F_1("HTTP_ADDRESS''") "/" {ε} /* "/" PATH HTTP_ADDRESS'' */ union "FO"_1("HTTP_ADDRESS'") = {"$", "?"}$
- $"FO"_1("XALPHAS") = {"@"} union F_1("LOGIN'") /* XALPHAS LOGIN' */ union F_1("HOSTNAME'") "/" {ε} /* XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME") union F_1("SEARCH'") "/" {ε} /* XALPHAS SEARCH' */ union "FO"_1("SEARCH") union F_1("HOSTNAME'") "/" {ε} /* "." XALPHAS HOSTNAME' HOST_PORT' */ union F_1("HOST_PORT'") "/" {ε} /* "." XALPHAS HOSTNAME' HOST_PORT' */ union "FO"_1("LOGIN'") union F_1("LOGIN''") "/" {ε} /* ":" XALPHAS LOGIN'' */ union "FO"_1("SEGMENT") union F_1("HOSTNAME'") "/" {ε} /* "." XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME'") union F_1("SEARCH'") "/" {ε} /* "+" XALPHAS SEARCH' */ union "FO"_1("SEARCH'") = {"@", ".", ":", "$", "?", "/", "+"}$
- $"FO"_1("HOSTNAME") = "FO"_1("MAILTO_ADDRESS") union F_1("HOST_PORT'") "/" {ε} /* HOSTNAME HOST_PORT' */ union "FO"_1("HOST_PORT") = {"$", ":", "?", "/"}$
- $"FO"_1("HOST_PORT'") = "FO"_1("HOST_PORT") union "FO"_1("LOGIN'") = {"?", "/", "$"}$
- $"FO"_1("SEARCH") = "FO"_1("HTTP_ADDRESS'") union "FO"_1("HTTP_ADDRESS''") = {"$"}$
- $"FO"_1("HTTP_ADDRESS''") = "FO"_1("HTTP_ADDRESS'") = {"$"}$
- $"FO"_1("LOGIN'") = "FO"_1("LOGIN") = {"/", "$"}$
- $"FO"_1("SEGMENT") = F_1("PATH'") "/" {ε} /* SEGMENT PATH' */ union "FO"_1("PATH") union F_1("PATH'") "/" {ε} /* "/" SEGMENT PATH' */ union "FO"_1("PATH'") = {"/", "$", "?"}$
- $"FO"_1("PATH'") = "FO"_1("PATH") union cancel("FO"_1("PATH'")) = {"$", "?"}$
- $"FO"_1("HOSTNAME'") = "FO"_1("HOSTNAME") union F_1("HOST_PORT'") "/" {ε} /* "." XALPHAS HOSTNAME' HOST_PORT' */ union "FO"_1("LOGIN'") union cancel("FO"_1("HOSTNAME'")) = {"$", ":", "?", "/"}$
- $"FO"_1("PORT") = "FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- $"FO"_1("SEARCH'") = "FO"_1("SEARCH") union cancel("FO"_1("SEARCH'")) = {"$"}$
- $"FO"_1("LOGIN''") = "FO"_1("LOGIN'") = {"/", "$"}$

*Pre $"URL"$*:
- $F_1("HTTP_ADDRESS") = {"http"}$
- $F_1("FTP_ADDRESS") = {"ftp"}$
- $F_1("TELNET_ADDRESS") = {"telnet"}$
- $F_1("MAILTO_ADDRESS") = {"mailto"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"FTP_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"TELNET_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"MAILTO_ADDRESS"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOST_PORT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS'"$*:
- $F_1(ε) = {ε}$
- $F_1("?" "SEARCH") = {"?"}$
- $F_1("/" "PATH" "HTTP_ADDRESS''") = {"/"}$
- $"FO"_1("HTTP_ADDRESS'") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"PATH"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"XALPHAS"$*:
- $F_1("text_number") = {"text_number"}$
- $F_1("digits") = {"digits"}$
- $F_1("text") = {"text"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HOST_PORT'"$*:
- $F_1(ε) = {ε}$
- $F_1(":" "PORT") = {":"}$
- $"FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"SEARCH"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS''"$*:
- $F_1(ε) = {ε}$
- $F_1("?" "SEARCH") = {"?"}$
- $"FO"_1("HTTP_ADDRESS''") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN'"$*:
- $F_1("." "XALPHAS" "HOSTNAME'" "HOST_PORT'") = {"."}$
- $F_1("@" "HOST_PORT") = {"@"}$
- $F_1(":" "XALPHAS" "LOGIN''") = {":"}$
- #text(olive)[Žiadny konflikt]

*Pre $"SEGMENT"$*:
- $F_1("XALPHAS") = {"text_number", "digits", "text"}$
- $F_1(ε) = {ε}$
- $"FO"_1("SEGMENT") = {"/", "$", "?"}$
- #text(olive)[Žiadny konflikt]

*Pre $"PATH'"$*:
- $F_1("/" "SEGMENT" "PATH'") = {"/"}$
- $F_1(ε) = {ε}$
- $"FO"_1("PATH'") = {"$", "?"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME'"$*:
- $F_1("." "XALPHAS" "HOSTNAME'") = {"."}$
- $F_1(ε) = {ε}$
- $"FO"_1("HOSTNAME'") = {"$", ":", "?", "/"}$
- #text(olive)[Žiadny konflikt]

*Pre $"PORT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"SEARCH'"$*:
- $F_1("+" "XALPHAS" "SEARCH'") = {"+"}$
- $F_1(ε) = {ε}$
- $"FO"_1("SEARCH'") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN''"$*:
- $F_1(ε) = {ε}$
- $F_1("@" "HOST_PORT") = {"@"}$
- $"FO"_1("LOGIN''") = {"/", "$"}$
- #text(olive)[Žiadny konflikt]

=== Tabuľka prechodov

Pravidlá:
1. $"URL" → "HTTP_ADDRESS"$
2. $"URL" → "FTP_ADDRESS"$
3. $"URL" → "TELNET_ADDRESS"$
4. $"URL" → "MAILTO_ADDRESS"$
5. $"HTTP_ADDRESS" → "http" "HOST_PORT" "HTTP_ADDRESS'"$
6. $"FTP_ADDRESS" → "ftp" "LOGIN" "/" "PATH"$
7. $"TELNET_ADDRESS" → "telnet" "LOGIN"$
8. $"MAILTO_ADDRESS" → "mailto" "XALPHAS" "@" "HOSTNAME"$
9. $"HOST_PORT" → "HOSTNAME" "HOST_PORT'"$
10. $"HTTP_ADDRESS'" → ε$
11. $"HTTP_ADDRESS'" → "?" "SEARCH"$
12. $"HTTP_ADDRESS'" → "/" "PATH" "HTTP_ADDRESS''"$
13. $"LOGIN" → "XALPHAS" "LOGIN'"$
14. $"PATH" → "SEGMENT" "PATH'"$
15. $"XALPHAS" → "text_number"$
16. $"XALPHAS" → "digits"$
17. $"XALPHAS" → "text"$
18. $"HOSTNAME" → "XALPHAS" "HOSTNAME'"$
19. $"HOST_PORT'" → ε$
20. $"HOST_PORT'" → ":" "PORT"$
21. $"SEARCH" → "XALPHAS" "SEARCH'"$
22. $"HTTP_ADDRESS''" → ε$
23. $"HTTP_ADDRESS''" → "?" "SEARCH"$
24. $"LOGIN'" → "." "XALPHAS" "HOSTNAME'" "HOST_PORT'"$
25. $"LOGIN'" → "@" "HOST_PORT"$
26. $"LOGIN'" → ":" "XALPHAS" "LOGIN''"$
27. $"SEGMENT" → "XALPHAS"$
28. $"SEGMENT" → ε$
29. $"PATH'" → "/" "SEGMENT" "PATH'"$
30. $"PATH'" → ε$
31. $"HOSTNAME'" → "." "XALPHAS" "HOSTNAME'"$
32. $"HOSTNAME'" → ε$
33. $"PORT" → "digits"$
34. $"SEARCH'" → "+" "XALPHAS" "SEARCH'"$
35. $"SEARCH'" → ε$
36. $"LOGIN''" → ε$
37. $"LOGIN''" → "@" "HOST_PORT"$

#pagebreak()

Aby sa tabuľka zmestila na papier, boli použité následovné skratky:
- $i_n$ ⇒ $"text_number"$
- $d$ ⇒ $"digit"$
- $i_t$ ⇒ $"text"$

#show table.cell.where(y: 0): set text(weight: "bold")

#let table-dark = rgb("#717171")
#let table-light = rgb("#e9e9e9")

#set table(
  stroke: (x, y) => (
    bottom: if y == 0 { 0.5pt + table-dark } else { none },
    top: none,
    left: if x != 0 { 0.5pt + table-dark } else { none },
  ),
  fill: (x, y) => if y > 0 and calc.rem(y, 2) == 1 { table-light } else { none },
)

#table(
  columns: 15,
  table.header[][$":"$][$"?"$][$"."$][$"@"$][$"/"$][$"+"$][$d$][$"ftp"$][$"http"$][$"mailto"$][$"telnet"$][$i_t$][$i_n$][$"$"$],
  [$"URL"$], [], [], [], [], [], [], [], [$1$], [$0$], [$3$], [$2$], [], [], [],
  [$"HTTP_ADDRESS"$], [], [], [], [], [], [], [], [], [$4$], [], [], [], [], [],
  [$"FTP_ADDRESS"$], [], [], [], [], [], [], [], [$5$], [], [], [], [], [], [],
  [$"TELNET_ADDRESS"$], [], [], [], [], [], [], [], [], [], [], [$6$], [], [], [],
  [$"MAILTO_ADDRESS"$], [], [], [], [], [], [], [], [], [], [$7$], [], [], [], [],
  [$"HOST_PORT"$], [], [], [], [], [], [], [$8$], [], [], [], [], [$8$], [$8$], [],
  [$"HTTP_ADDRESS'"$], [], [$10$], [], [], [$11$], [], [], [], [], [], [], [], [], [$9$],
  [$"LOGIN"$], [], [], [], [], [], [], [$12$], [], [], [], [], [$12$], [$12$], [],
  [$"PATH"$], [], [$13$], [], [], [$13$], [], [$13$], [], [], [], [], [$13$], [$13$], [$13$],
  [$"XALPHAS"$], [], [], [], [], [], [], [$15$], [], [], [], [], [$16$], [$14$], [],
  [$"HOSTNAME"$], [], [], [], [], [], [], [$17$], [], [], [], [], [$17$], [$17$], [],
  [$"HOST_PORT'"$], [$19$], [$18$], [], [], [$18$], [], [], [], [], [], [], [], [], [$18$],
  [$"SEARCH"$], [], [], [], [], [], [], [$20$], [], [], [], [], [$20$], [$20$], [],
  [$"HTTP_ADDRESS''"$], [], [$22$], [], [], [], [], [], [], [], [], [], [], [], [$21$],
  [$"LOGIN'"$], [$25$], [], [$23$], [$24$], [], [], [], [], [], [], [], [], [], [],
  [$"SEGMENT"$], [], [$27$], [], [], [$27$], [], [$26$], [], [], [], [], [$26$], [$26$], [$27$],
  [$"PATH'"$], [], [$29$], [], [], [$28$], [], [], [], [], [], [], [], [], [$29$],
  [$"HOSTNAME'"$], [$31$], [$31$], [$30$], [], [$31$], [], [], [], [], [], [], [], [], [$31$],
  [$"PORT"$], [], [], [], [], [], [], [$32$], [], [], [], [], [], [], [],
  [$"SEARCH'"$], [], [], [], [], [], [$33$], [], [], [], [], [], [], [], [$34$],
  [$"LOGIN''"$], [], [], [], [$36$], [$35$], [], [], [], [], [], [], [], [], [$35$],
)

#pagebreak()

= Implementácia

Parser je implementovaný v jazyku TypeScript pre prostredie Node.js. Program dostane vstup na analýzu ako konzolový argument.

Výstupom programu je log tokenov, operácií pri syntaktickej analýze a ak je to zvolené, tak aj vizualizácia syntaktického stromu.

== Lexikálna analýza

Lexikálna analýza bude vykonaná cez regex, ktorý bude opätovne aplikovaný na vstup. Regex je následovný:

```js
/(http:\/\/)|(ftp:\/\/)|(telnet:\/\/)|(mailto:)|([.:?@/+])|([0-9]+[a-z][0-9a-z]*)|([0-9]+)|([a-z][a-z0-9]*)/y
```

Regex je typu sticky — ten udáva limitáciu, že nájdený reťazec musí byť na zvolenom indexe vo vstupnom reťazci. Pozícia sa ukladá v premennej $i$. Začína na hodnote $0$ a pri každom úspešnom použití regexu sa aktualizuje na pozíciu kde končí nájdený podreťazec vo vstupnom reťazci.

Jazyk JavaScript umožňuje prístup k obsahu, ktorý bol nájdený v každej skupine regexu cez pole; keďže sa skupiny v regexe navzájom vylučujú, vždy má hodnotu iba jedna položka zoznamu. Podľa toho, ktorá skupina bude nájdená, taký token sa vygeneruje.

#figure(
  [
    #image("fig-lexical-analysis.pdf", height: 300pt)
  ],
  caption: [
    Diagram procesu lexikálnej analýzy
  ],
)

Po skončení analýzy je symbol `$` automaticky pridaný na koniec prúdu tokenov.

=== Oprava chýb

*Ignorovanie nesprávnych znakov:* V prípade tokenov, ktoré pozostávajú z viacerých symbolov (```bnf http```, ```bnf ftp```, ```bnf telnet```, ```bnf mailto```), je tu ešte pred aplikovaním regexu pokus manuálne nájsť tieto tokeny. Proces je ilustrovaný v @lex-recovery.

Pre ostatné tokeny sa iba premenná $i$ inkrementuje a slučka začína od posunutého začiatku, efektívne sa takto preskočí neplatný symbol.

*Vkladanie chýbajúcich znakov:* Táto metóda sa uplatnuje iba pri tokenoch, ktoré pozostávajú z viacerých symbolov (```bnf http```, ```bnf ftp```, ```bnf telnet```, ```bnf mailto```). Tu je ešte pred aplikovaním regexu pokus manuálne nájsť tieto tokeny. Proces je ilustrovaný v @lex-recovery.

#figure(
  image("fig-lexical-recovery.pdf", height: 450pt),
  caption: [Diagram procesu opravy chýb pre tokeny, ktoré pozostávajú z viacerých symbolov],
) <lex-recovery>

== Syntaktická analýza

Kód si načíta prechodovú tabuľku so súboru `table.json`. V tomto súbore sú definované tri hodnoty:
- `symbols` $→$ Pole platných symbolov jazyka; v tomto prípade teda zoznam tokenov. Podľa poradia symbolov v poli sú symboly priradené k stĺpcom tabuľky prechodov.
- `rules` $→$ Pole pravidiel gramatiky. Každé pravidlo má atribút `name`, ktorý sa používa pri logovaní a pole `production`, ktoré obsahuje zoznam prvkov, ktoré budú pridaná na zásobník.
- `states` $→$ Pole, kde každý prvok definuje riadok tabuľky prechodov. Prvok má atribút `name`, čo je názov ne-terminálu a pole `transitions`, ktoré pre každý symbol + pre koniec vstupu `$` definuje, ktoré pravidlo bude aplikované, alebo `null` ak tu nie je prechod.

Program prechádza zoznam tokenov jeden po druhom a pozerá sa na vrchol zásobníka. Na začiatku na na zásobník hodí znak konca vstupu a následne neterminál vstupného stavu (určený ako prvý riadok tabuľky prechodov).

#figure(
  [
    #image("fig-syntactic-analysis.pdf", height: 420pt)
  ],
  caption: [
    Diagram procesu syntaktickej analýzy
  ],
)

=== Vizualizácia syntaktického stromu

Keďže program pracuje v konzole, vizualizácia je realizovaná prostredníctvom formátovaného textu. Pre každý vrchol stromu je na jednom riadku a to, že vrchol je dieťaťom iného vrcholu je indikované zvýšenou indentáciou a čiarov, ktorá je tiahnuta po ľavej strane detských vrcholov. Neterminály sú zvýraznené fialovým textom a terminály bielym.

Počas syntaktickej analýzy sú zapisované do pola všetky aplikované pravidlá a konzumované tokeny. Pre vizualizáciu je toto pole prečítané. Keďže sú prvky poľa zapísané v poradí ako sú v prúde tokenov, reprezentuje toto pole vrcholy stromu v pre-order poradí. Pre rekonštrukciu stromu z plochého pola je použitý počet produkovaných prvkov z každého pravidla, kde tento počet prvkov je priradených ako detské vrcholy.

=== Oprava chýb

*Panic mode:* Jednou z možností opravy chýb je preskočenie neočakávaných tokenov. V tom prípade že neexistuje pre daný neterminál pravidlo pre token na vstupe, bude načítaný ďalší token. V prípade že je na vrchu zásobníka `$` a na vstupe je ešte normálny token, tak tento token bude tiež preskočený.

*Phrase-level recovery:* Ďalšou možnosťou opravy chýb je vloženie chýbajúcich tokenov. V tomto prípade, ak je na vrchu zásobníka terminál a tento terminál nie je na vstupe, je tento terminál zo zásobníka vytiahnutý aj tak. Taktiež, ak je na vrchu zásobníka neterminál, ale v tabuľke nie je pre token na vstupe pravidlo, program sa pozrie na platné vstupy — ak je iba jeden platný vstup, bude tento vložený alebo, ak sú platné vstupy tokeny presne: ```bnf digits```, ```bnf text``` a ```bnf text_number```, bude vložený token ```bnf text```.

== Použitie programu

Pre použitie programu je potrebný Node.js verzie minimálne `v24.13.0`. Pre preklad programu je potrebný Yarn verzie minimálne `1.22.22`. Po inštalácií knižníc je možné program preložiť prostredníctvom príkazu `yarn build`. Preklad nie je potrebný, keďže preložený program je súčasťou odovzdania.

Skompilovaný program je možné spustiť príkazom `node build/main.js <prepínače*> <vstup>`. To je zoznam prepínačov:

- `--ast` $→$ Aktivuje vizualizáciu syntaktického stromu
- `--lex-skip-symbol` $→$ Aktivuje opravu chýb počas lexikálnej analýzy preskočením neplatných znakov
- `--lex-insert-symbol` $→$ Aktivuje opravu chýb počas lexikálnej analýzy vložením chýbajúcich symbolov
- `--syn-skip-token` $→$ Aktivuje opravu chýb počas syntaktickej analýzy preskočením neplatných tokenov
- `--syn-insert-token` $→$ Aktivuje opravu chýb počas lexikálnej analýzy vložením chýbajúcich tokenov

Príklad spustenia:
- `node build/main.js --ast --lex-skip-symbol --syn-skip-token 'http://^google..com'`

=== Príklady platných a neplatných vstupov

Príklady platných a neplatných vstupov sú v súbore `cases.txt`, spolu s odôvodním neplatnosti alebo s prepínačmi pre opravu chýb potrebných pre platnosť.

Test programu na všetkých týchto vstupoch je možný prostredníctvom skriptu `testall.sh`.

Obsah súboru je replikovaný nižšie.

#raw(read("../cases.txt"), block: true, lang: "sh")
