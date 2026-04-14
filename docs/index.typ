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

#show heading: it => block({
  let num = if it.numbering == none { none } else { counter(heading).display(it.numbering) + h(0.75em) }
  num + it.body
})

#align(center)[
  #title[Jazyk 7.5 — `simpleURL`]
  Branislav Trstenský
]

#set raw(syntaxes: "bnf.sublime-syntax")

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
LOGIN → XALPHAS
LOGIN → XALPHAS ":" XALPHAS
LOGIN → XALPHAS "@" HOST_PORT
LOGIN → XALPHAS ":" XALPHAS "@" HOST_PORT
```

*Pre neterminál* $"LOGIN"$ *je spoločný prefix* $"XALPHAS"$
- $"LOGIN" → "XALPHAS" "LOGIN'"$
- $"LOGIN'" → ε | ":" "XALPHAS" | "@" "HOST_PORT" | ":" "XALPHAS" "@" "HOST_PORT"$

*Pre neterminál* $"LOGIN'"$ *je spoločný prefix* $":" "XALPHAS"$
- $"LOGIN'" → ε | "@" "HOST_PORT" | ":" "XALPHAS" "LOGIN''"$
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
PATH → SEGMENT PATH'
SEARCH → XALPHAS SEARCH'
LOGIN → XALPHAS LOGIN'
XALPHAS → XALPHA XALPHAS'
HOSTNAME → XALPHAS HOSTNAME'
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
LOGIN' → ε
LOGIN' → "@" HOST_PORT
LOGIN' → ":" XALPHAS LOGIN''
HTTP_ADDRESS'' → ε
HTTP_ADDRESS'' → "?" SEARCH
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
- $F_1("SEGMENT") = F_1("XALPHAS") union {ε} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε}$
- $F_1("PATH'") = {"/"} union {ε} = {"/", ε}$
- $F_1("SEARCH") = F_1("XALPHAS") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("SEARCH'") = {"+"} union {ε} = {"+", ε}$
- $F_1("LOGIN'") = {ε} union {"@"} union {":"} = {ε, "@", ":"}$
- $F_1("XALPHA") = F_1("ALPHA") union F_1("DIGIT") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1("XALPHAS'") = F_1("XALPHA") union {ε} = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", ε}$
- $F_1("HOSTNAME'") = {"."} union {ε} = {".", ε}$
- $F_1("PORT") = F_1("DIGITS") = {"0", dots, "9"}$
- $F_1("DIGITS") = F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("DIGIT") = {"0", dots, "9"}$
- $F_1("DIGITS'") = F_1("DIGIT") union {ε} = {"0", dots, "9", ε}$
- $F_1("ALPHA") = {"A", dots, "Z"} union {"a", dots, "z"} = {"A", dots, "Z", "a", dots, "z"}$
- $F_1("HTTP_ADDRESS''") = {ε} union {"?"} = {ε, "?"}$
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
- $"FO"_1("XALPHAS") = {"@"} union F_1("LOGIN'") "/" {ε} /* XALPHAS LOGIN' */ union "FO"_1("LOGIN") union F_1("HOSTNAME'") "/" {ε} /* XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME") union "FO"_1("SEGMENT") union F_1("SEARCH'") "/" {ε} /* XALPHAS SEARCH' */ union "FO"_1("SEARCH") union F_1("SEARCH'") "/" {ε} /* "+" XALPHAS SEARCH' */ union "FO"_1("SEARCH'") union F_1("LOGIN''") "/" {ε} /* ":" XALPHAS LOGIN'' */ union "FO"_1("LOGIN'") union F_1("HOSTNAME'") "/" {ε} /* "." XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME'") union "FO"_1("USER") union "FO"_1("PASSWORD") = {"@", ":", "/", "$", ".", "?", "+"}$
- $"FO"_1("HOSTNAME") = "FO"_1("MAILTO_ADDRESS") union F_1("HOST_PORT'") "/" {ε} /* HOSTNAME HOST_PORT' */ union "FO"_1("HOST_PORT") = {"$", ":", "?", "/"}$
- $"FO"_1("HOST_PORT'") = "FO"_1("HOST_PORT") = {"?", "/", "$"}$
- $"FO"_1("SEGMENT") = F_1("PATH'") "/" {ε} /* SEGMENT PATH' */ union "FO"_1("PATH") union F_1("PATH'") "/" {ε} /* "/" SEGMENT PATH' */ union "FO"_1("PATH'") = {"/", "$", "?"}$
- $"FO"_1("PATH'") = "FO"_1("PATH") union cancel("FO"_1("PATH'")) = {"$", "?"}$
- $"FO"_1("SEARCH") = "FO"_1("HTTP_ADDRESS'") union "FO"_1("HTTP_ADDRESS''") = {"$"}$
- $"FO"_1("SEARCH'") = "FO"_1("SEARCH") union cancel("FO"_1("SEARCH'")) = {"$"}$
- $"FO"_1("LOGIN'") = "FO"_1("LOGIN") = {"/", "$"}$
- $"FO"_1("XALPHA") = F_1("XALPHAS'") "/" {ε} /* XALPHA XALPHAS' */ union "FO"_1("XALPHAS") union "FO"_1("XALPHAS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ":", "/", "$", ".", "?", "+"}$
- $"FO"_1("XALPHAS'") = "FO"_1("XALPHAS") union cancel("FO"_1("XALPHAS'")) = {"@", ":", "/", "$", ".", "?", "+"}$
- $"FO"_1("HOSTNAME'") = "FO"_1("HOSTNAME") union cancel("FO"_1("HOSTNAME'")) = {"$", ":", "?", "/"}$
- $"FO"_1("PORT") = "FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- $"FO"_1("DIGITS") = "FO"_1("PORT") = {"?", "/", "$"}$
- $"FO"_1("DIGIT") = "FO"_1("XALPHA") union F_1("DIGITS'") "/" {ε} /* DIGIT DIGITS' */ union "FO"_1("DIGITS") union "FO"_1("DIGITS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ":", "/", "$", ".", "?", "+"}$
- $"FO"_1("DIGITS'") = "FO"_1("DIGITS") union cancel("FO"_1("DIGITS'")) = {"?", "/", "$"}$
- $"FO"_1("ALPHA") = "FO"_1("XALPHA") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9", "@", ":", "/", "$", ".", "?", "+"}$
- $"FO"_1("HTTP_ADDRESS''") = "FO"_1("HTTP_ADDRESS'") = {"$"}$
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

*Pre $"LOGIN'"$*:
- $F_1(ε) = {ε}$
- $F_1("@" "HOST_PORT") = {"@"}$
- $F_1(":" "XALPHAS" "LOGIN''") = {":"}$
- $"FO"_1("LOGIN'") = {"/", "$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"XALPHA"$*:
- $F_1("ALPHA") = {"A", dots, "Z", "a", dots, "z"}$
- $F_1("DIGIT") = {"0", dots, "9"}$
- #text(olive)[Žiadny konflikt]

*Pre $"XALPHAS'"$*:
- $F_1("XALPHA" "XALPHAS'") = {"A", dots, "Z", "a", dots, "z", "0", dots, "9"}$
- $F_1(ε) = {ε}$
- $"FO"_1("XALPHAS'") = {"@", ":", "/", "$", ".", "?", "+"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME'"$*:
- $F_1("." "XALPHAS" "HOSTNAME'") = {"."}$
- $F_1(ε) = {ε}$
- $"FO"_1("HOSTNAME'") = {"$", ":", "?", "/"}$
- #text(olive)[Žiadny konflikt]

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

*Pre $"LOGIN''"$*:
- $F_1(ε) = {ε}$
- $F_1("@" "HOST_PORT") = {"@"}$
- $"FO"_1("LOGIN''") = {"/", "$"}$
- #text(olive)[Žiadny konflikt]

== Lexikálna analýza

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
PATH → SEGMENT PATH'
SEARCH → XALPHAS SEARCH'
LOGIN → XALPHAS LOGIN'
XALPHAS → text_number | digits | text
HOSTNAME → XALPHAS HOSTNAME'
PORT → digits
SEGMENT → XALPHAS | ε
PATH' → "/" SEGMENT PATH'
PATH' → ε
SEARCH' → "+" XALPHAS SEARCH'
SEARCH' → ε
HOSTNAME' → "." XALPHAS HOSTNAME'
HOSTNAME' → ε
HTTP_ADDRESS' → ε
HTTP_ADDRESS' → "?" SEARCH
HTTP_ADDRESS' → "/" PATH HTTP_ADDRESS''
HOST_PORT' → ε
HOST_PORT' → ":" PORT
LOGIN' → ε
LOGIN' → "@" HOST_PORT
LOGIN' → ":" XALPHAS LOGIN''
HTTP_ADDRESS'' → ε
HTTP_ADDRESS'' → "?" SEARCH
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
- $F_1("SEGMENT") = F_1("XALPHAS") union {ε} = {"text_number", "digits", "text", ε}$
- $F_1("PATH'") = {"/"} union {ε} = {"/", ε}$
- $F_1("SEARCH") = F_1("XALPHAS") = {"text_number", "digits", "text"}$
- $F_1("SEARCH'") = {"+"} union {ε} = {"+", ε}$
- $F_1("LOGIN'") = {ε} union {"@"} union {":"} = {ε, "@", ":"}$
- $F_1("HOSTNAME'") = {"."} union {ε} = {".", ε}$
- $F_1("PORT") = {"digits"}$
- $F_1("HTTP_ADDRESS''") = {ε} union {"?"} = {ε, "?"}$
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
- $"FO"_1("XALPHAS") = {"@"} union F_1("LOGIN'") "/" {ε} /* XALPHAS LOGIN' */ union "FO"_1("LOGIN") union F_1("HOSTNAME'") "/" {ε} /* XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME") union "FO"_1("SEGMENT") union F_1("SEARCH'") "/" {ε} /* XALPHAS SEARCH' */ union "FO"_1("SEARCH") union F_1("SEARCH'") "/" {ε} /* "+" XALPHAS SEARCH' */ union "FO"_1("SEARCH'") union F_1("LOGIN''") "/" {ε} /* ":" XALPHAS LOGIN'' */ union "FO"_1("LOGIN'") union F_1("HOSTNAME'") "/" {ε} /* "." XALPHAS HOSTNAME' */ union "FO"_1("HOSTNAME'") = {"@", ":", "/", "$", ".", "?", "+"}$
- $"FO"_1("HOSTNAME") = "FO"_1("MAILTO_ADDRESS") union F_1("HOST_PORT'") "/" {ε} /* HOSTNAME HOST_PORT' */ union "FO"_1("HOST_PORT") = {"$", ":", "?", "/"}$
- $"FO"_1("HOST_PORT'") = "FO"_1("HOST_PORT") = {"?", "/", "$"}$
- $"FO"_1("SEGMENT") = F_1("PATH'") "/" {ε} /* SEGMENT PATH' */ union "FO"_1("PATH") union F_1("PATH'") "/" {ε} /* "/" SEGMENT PATH' */ union "FO"_1("PATH'") = {"/", "$", "?"}$
- $"FO"_1("PATH'") = "FO"_1("PATH") union cancel("FO"_1("PATH'")) = {"$", "?"}$
- $"FO"_1("SEARCH") = "FO"_1("HTTP_ADDRESS'") union "FO"_1("HTTP_ADDRESS''") = {"$"}$
- $"FO"_1("SEARCH'") = "FO"_1("SEARCH") union cancel("FO"_1("SEARCH'")) = {"$"}$
- $"FO"_1("LOGIN'") = "FO"_1("LOGIN") = {"/", "$"}$
- $"FO"_1("HOSTNAME'") = "FO"_1("HOSTNAME") union cancel("FO"_1("HOSTNAME'")) = {"$", ":", "?", "/"}$
- $"FO"_1("PORT") = "FO"_1("HOST_PORT'") = {"?", "/", "$"}$
- $"FO"_1("HTTP_ADDRESS''") = "FO"_1("HTTP_ADDRESS'") = {"$"}$
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

*Pre $"SEARCH"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"SEARCH'"$*:
- $F_1("+" "XALPHAS" "SEARCH'") = {"+"}$
- $F_1(ε) = {ε}$
- $"FO"_1("SEARCH'") = {"$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"LOGIN'"$*:
- $F_1(ε) = {ε}$
- $F_1("@" "HOST_PORT") = {"@"}$
- $F_1(":" "XALPHAS" "LOGIN''") = {":"}$
- $"FO"_1("LOGIN'") = {"/", "$"}$
- #text(olive)[Žiadny konflikt]

*Pre $"HOSTNAME'"$*:
- $F_1("." "XALPHAS" "HOSTNAME'") = {"."}$
- $F_1(ε) = {ε}$
- $"FO"_1("HOSTNAME'") = {"$", ":", "?", "/"}$
- #text(olive)[Žiadny konflikt]

*Pre $"PORT"$*: Len jedno pravidlo — #text(olive)[Žiadny konflikt]

*Pre $"HTTP_ADDRESS''"$*:
- $F_1(ε) = {ε}$
- $F_1("?" "SEARCH") = {"?"}$
- $"FO"_1("HTTP_ADDRESS''") = {"$"}$
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
21. $"SEGMENT" → "XALPHAS"$
22. $"SEGMENT" → ε$
23. $"PATH'" → "/" "SEGMENT" "PATH'"$
24. $"PATH'" → ε$
25. $"SEARCH" → "XALPHAS" "SEARCH'"$
26. $"SEARCH'" → "+" "XALPHAS" "SEARCH'"$
27. $"SEARCH'" → ε$
28. $"LOGIN'" → ε$
29. $"LOGIN'" → "@" "HOST_PORT"$
30. $"LOGIN'" → ":" "XALPHAS" "LOGIN''"$
31. $"HOSTNAME'" → "." "XALPHAS" "HOSTNAME'"$
32. $"HOSTNAME'" → ε$
33. $"PORT" → "digits"$
34. $"HTTP_ADDRESS''" → ε$
35. $"HTTP_ADDRESS''" → "?" "SEARCH"$
36. $"LOGIN''" → ε$
37. $"LOGIN''" → "@" "HOST_PORT"$

Aby sa tabuľka zmestila na papier, boli použité následovné skratky:
- $i_n$ ⇒ $"text_number"$
- $d$ ⇒ $"digit"$
- $i_t$ ⇒ $"text"$

#table(
  columns: 15,
  stroke: gray,
  table.header(
    [],
    [$"http"$],
    [$"ftp"$],
    [$"/"$],
    [$"telnet"$],
    [$"mailto"$],
    [$"@"$],
    [$"?"$],
    [$i_n$],
    [$d$],
    [$i_t$],
    [$":"$],
    [$"+"$],
    [$"."$],
    [$"$"$],
  ),
  [$"URL"$], [$0$], [$1$], [], [$2$], [$3$], [], [], [], [], [], [], [], [], [],
  [$"HTTP_ADDRESS"$], [$4$], [], [], [], [], [], [], [], [], [], [], [], [], [],
  [$"FTP_ADDRESS"$], [], [$5$], [], [], [], [], [], [], [], [], [], [], [], [],
  [$"TELNET_ADDRESS"$], [], [], [], [$6$], [], [], [], [], [], [], [], [], [], [],
  [$"MAILTO_ADDRESS"$], [], [], [], [], [$7$], [], [], [], [], [], [], [], [], [],
  [$"HOST_PORT"$], [], [], [], [], [], [], [], [$8$], [$8$], [$8$], [], [], [], [],
  [$"HTTP_ADDRESS'"$], [], [], [$11$], [], [], [], [$10$], [], [], [], [], [], [], [$9$],
  [$"LOGIN"$], [], [], [], [], [], [], [], [$12$], [$12$], [$12$], [], [], [], [],
  [$"PATH"$], [], [], [$13$], [], [], [], [$13$], [$13$], [$13$], [$13$], [], [], [], [$13$],
  [$"XALPHAS"$], [], [], [], [], [], [], [], [$14$], [$15$], [$16$], [], [], [], [],
  [$"HOSTNAME"$], [], [], [], [], [], [], [], [$17$], [$17$], [$17$], [], [], [], [],
  [$"HOST_PORT'"$], [], [], [$18$], [], [], [], [$18$], [], [], [], [$19$], [], [], [$18$],
  [$"SEGMENT"$], [], [], [$21$], [], [], [], [$21$], [$20$], [$20$], [$20$], [], [], [], [$21$],
  [$"PATH'"$], [], [], [$22$], [], [], [], [$23$], [], [], [], [], [], [], [$23$],
  [$"SEARCH"$], [], [], [], [], [], [], [], [$24$], [$24$], [$24$], [], [], [], [],
  [$"SEARCH'"$], [], [], [], [], [], [], [], [], [], [], [], [$25$], [], [$26$],
  [$"LOGIN'"$], [], [], [$27$], [], [], [$28$], [], [], [], [], [$29$], [], [], [$27$],
  [$"HOSTNAME'"$], [], [], [$31$], [], [], [], [$31$], [], [], [], [$31$], [], [$30$], [$31$],
  [$"PORT"$], [], [], [], [], [], [], [], [], [$32$], [], [], [], [], [],
  [$"HTTP_ADDRESS''"$], [], [], [], [], [], [], [$34$], [], [], [], [], [], [], [$33$],
  [$"LOGIN''"$], [], [], [$35$], [], [], [$36$], [], [], [], [], [], [], [], [$35$],
)

= Implementácia

Parser bude implementovaný v jazyku JavaScript v prostredí Node.js.

== Lexikálna analýza

Lexikálna analýza bude vykonaná cez regex, špecificky jeden sticky regex, ktorý bude opätovne aplikovaný na vstup. Regex je následovný:

```js
/(http:\/\/)|(ftp:\/\/)|(telnet:\/\/)|(mailto:)|([.:?@/+])|([0-9]+[a-z][0-9a-z]*)|([0-9]+)|([a-z][a-z0-9]*)/y
```
