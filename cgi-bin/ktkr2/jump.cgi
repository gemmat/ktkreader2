#!/usr/local/bin/gosh
(use srfi-1)
(use rfc.http)
(use rfc.uri)
(use file.util)
(use gauche.logger)
(use util.match)
(use text.html-lite)
(use www.cgi)

(add-load-path "./")
(use ktkr2.util)
(use ktkr2.db)
(ktkr2-log-open)

(define memoize (make-hash-table 'eq?))

(define (get-info 板id)
  (if (hash-table-exists? memoize 板id)
    (hash-table-get memoize 板id)
    (and-let* ((p (db-select-板URL&板名 板id)))
      (hash-table-put! memoize 板id p)
      p)))

(define (readcgi-url word)
  (receive (_ _ host _ path _ _) (uri-parse word)
    (rxmatch-if (#/read\.cgi\/(\w+)\/(\d+)/ path)
        (#f board key)
        (uri-compose :scheme "http" :host host :path (build-path "/" board "dat" (path-swap-extension key "dat")))
        word)))

(define (main args)
  (cgi-main
   (lambda (params)
     (or (and-let* ((word (cgi-get-parameter "q" params :default #f :convert (cut uri-decode-string <> :cgi-decode #t))))
           (log-format "jump ~a" word)
           `(ktkreader2
             (@ (type "result") (q ,word))
             ,@(filter-map (match-lambda
                            ((スレid 板id スレURL スレタイ レス数 スレファイル)
                             (and-let* ((p (get-info 板id))
                                        (板URL (car p))
                                        (板名  (cdr p)))
                               `(result
                                 (board
                                  (id ,板id)
                                  (title ,板名)
                                  ,@(receive (host path) (decompose-板URL 板URL)
                                      (if (and host path)
                                        `((host ,host)
                                          (path ,path))
                                        '()))
                                  (url ,板URL)
                                  (subject
                                   (id ,スレid)
                                   (title ,スレタイ)
                                   (rescount ,レス数)
                                   (key ,(extract-スレキー スレURL))
                                   (cache ,(or (and スレファイル 1) 0))))))))
                    (rxmatch-if (#/^http:\/\// word)
                        (#f)
                        (db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレURL-glob (readcgi-url word))
                        (db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレタイ-glob word)))))
         "502"))
   :output-proc cgi-output-sxml->xml
   :on-error cgi-on-error
   ))

;; Local variables:
;; mode: inferior-gauche
;; end:


