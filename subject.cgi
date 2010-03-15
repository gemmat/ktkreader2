#!/usr/local/bin/gosh
(use srfi-1)
(use rfc.http)
(use rfc.uri)
(use gauche.process)
(use gauche.logger)
(use util.match)
(use text.html-lite)
(use www.cgi)

(add-load-path "./")
(use ktkr2.util)
(use ktkr2.db)

(define (update-subject 板URL)
  (or (cache?)
      (and-let* ((process (run-process `(gosh main.scm ,(string-append "--subject=" 板URL))))
                 ((process-wait process)))
        (zero? (process-exit-status process)))))

(define (main args)
  (cgi-main
   (lambda (params)
     (cache? (cgi-get-parameter "cache" params :default #f :convert (compose positive? x->integer)))
     (or (and-let* ((板id (cgi-get-parameter "sq" params :default #f :convert x->integer))
                    (p (db-select-板URL&板名 板id))
                    (板URL (car p))
                    (板名  (cdr p)))
           (if (update-subject 板URL)
             `(ktkreader2
               (@ (type "result"))
               (board
                (id ,板id)
                (title ,板名)
                ,@(receive (host path) (decompose-板URL 板URL)
                    (if (and host path)
                      `((host ,host)
                        (path ,path))
                      '()))
                (url ,板URL)
                (subjects
                 ,@(map (match-lambda
                         ((スレid スレURL スレタイ レス数 スレファイル)
                          `(subject
                            (id ,スレid)
                            (title ,スレタイ)
                            (rescount ,レス数)
                            (key ,(extract-スレキー スレURL))
                            (cache ,(or (and スレファイル 1) 0)))))
                        (or (and-let* ((word (cgi-get-parameter "ss" params :default #f)))
                              (db-select-スレid&スレURL&スレタイ&レス数&スレファイル-where-スレタイ-glob 板id word))
                            (db-select-スレid&スレURL&スレタイ&レス数&スレファイル 板id))))))
             "502"))
         "503"))
   :output-proc cgi-output-sxml->xml
   :on-error cgi-on-error
   ))

;; Local variables:
;; mode: inferior-gauche
;; end:
