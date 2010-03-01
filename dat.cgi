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

(define (update-dat スレURL)
  (or 'debug
      (and-let* ((process (run-process `(gosh main.scm ,(string-append "--dat=" スレURL))))
                 ((process-wait process)))
        (zero? (process-exit-status process)))))

(define (main args)
  (cgi-main
   (lambda (params)
     `(,(cgi-header)
       ,(html-doctype)
       ,(html:html
         (html:head
          (html:meta :http-equiv "Content-Type" :content "text/html; charset=UTF-8")
          (html:meta :http-equiv "Content-Script-Type" :content "text/html; charset=UTF-8")
          (html:title "スレ"))
         (html:body
          (or (and-let* ((スレid (cgi-get-parameter "q" params :default #f :convert x->integer))
                         (p (db-select-板id&スレURL&スレタイ&レス数 スレid))
                         (板id (car p))
                         (スレURL (cadr p))
                         (スレタイ (caddr p))
                         (レス数 (cadddr p))
                         (p (db-select-板URL&板名 板id))
                         (板URL (car p))
                         (板名  (cdr p)))
                (or (and-let* (((update-dat スレURL))
                               (スレファイル (db-select-スレファイル-is-not-null スレid)))
                      `(,(パンくず 板id 板名 スレid スレタイ レス数)
                        ,(html:pre
                          (call-with-input-file スレファイル port->string :encoding 'SHIFT_JIS))))
                    "error"))
              "fail")))
       ))))

;; Local variables:
;; mode: inferior-gauche
;; end:
