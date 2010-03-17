#!/usr/local/bin/gosh
(use rfc.uri)
(use util.match)
(use text.html-lite)
(use gauche.charconv)
(use gauche.logger)
(use www.cgi)

(add-load-path "./")
(use ktkr2.db)
(use ktkr2.util)

(ktkr2-log-open)

(define (main args)
  (cgi-main
   (lambda (params)
     (cache? (cgi-get-parameter "cache" params :default #f :convert (compose positive? x->integer)))
     `(ktkreader2
       (bbsmenu
        ,@(map (match-lambda
                 ((板id 板URL 板名 板最終更新日時)
                  `(board
                    (id ,板id)
                    (title ,板名)
                    ,@(receive (host path) (decompose-板URL 板URL)
                        (if (and host path)
                          `((host ,host)
                            (path ,path))
                          '()))
                    (url ,板URL)
                    (cache ,(or (and 板最終更新日時 1) 0)))))
               (or (and-let* ((word (cgi-get-parameter "bs" params :default #f :convert (cut uri-decode-string <> :cgi-decode #t))))
                     (log-format "bbsmenu.cgi ~a" word)
                     (db-select-板id&板URL&板名&板最終更新日時-where-板名-glob word))
                   (begin
                     (log-format "bbsmenu.cgi")
                     (db-select-板id&板URL&板名&板最終更新日時)))))))
   :output-proc cgi-output-sxml->xml
   :on-error cgi-on-error
   ))

;; Local variables:
;; mode: inferior-gauche
;; end:
