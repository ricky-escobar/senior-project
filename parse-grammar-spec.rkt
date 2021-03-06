#lang racket

(require "generator.rkt")

(provide parse-grammar-spec)

;; Parses a grammar specification like the one above into the form expected by
;; generate-testcase. `s` should be a list with three elements. The first is a
;; list of identifiers to explicitly add to the testcase. The second is forbidden
;; identifiers. The third is the actual grammar. The first element of
;; the actual grammar is the name of the recursive rule, e.g., `expr`.
;; The rest are the rules of the grammar.
;; The forms [id ids ...], [number nums ...], [string strings ...] are special
;; and denote an identifier/number/string with explicit examples to use.
;; The form [U literals ...] is also special and denotes a literal with
;; mutliple examples.
;; Placing a literal ... after a term denotes a variadic list.
;; Any other literal which doesn't match the name of the recursive rule
;; is treated as a literal in the grammar.
(define (parse-grammar-spec s)
  (match s
    [(list ids bad-ids (list (? symbol? expr) rules ...))
     (map (parse-rule expr ids bad-ids) (map desugar-... rules))]))

;; Moves a variadic pair `term ...` into a list (... term) to make parsing easier
(define (desugar-... rule)
  (match rule
    [(cons '... rest)
     (error "... not after term in ~s" rule)]
    [(list term '... rest ...)
     (cons (list '... (desugar-... term)) (desugar-... rest))]
    [(cons term rest)
     (cons (desugar-... term) (desugar-... rest))]
    [else rule]))

;; Parses a rule into the Rule<%> form of generator.rkt
(define ((parse-rule expr ids bad-ids) rule)
  (match rule
    [(? (λ (s) (equal? s expr)))
     (new Recursive%)]
    [(list '... term)
     (new Variadic% [repeated-term ((parse-rule expr ids bad-ids) term)])]
    [(list 'U terms ...)
     (new Literal% [the-examples terms] [bad-examples (dedupe bad-ids terms)] [predicate (λ (x) (member x terms))])]
    [(list 'id other-ids ...)
     (new Identifier% [ids (append other-ids ids)] [bad-ids bad-ids])]
    [(list 'number terms ...)
     (new Literal% [the-examples terms] [bad-examples bad-ids] [predicate real?])]
    [(list 'string terms ...)
     (new Literal% [the-examples terms] [bad-examples bad-ids] [predicate string?])]
    [(list subterms ...)
     (new List% [subterms (map (parse-rule expr ids bad-ids) subterms)])]
    [sym
     (new Literal% [the-examples (list sym)] [bad-examples (remove sym bad-ids)] [predicate (λ (x) (equal? x sym))])]))
