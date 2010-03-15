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
  (or (cache?)
      (and-let* ((process (run-process `(gosh main.scm ,(string-append "--dat=" スレURL))))
                 ((process-wait process)))
        (zero? (process-exit-status process)))))

(define (main args)
  (cgi-main
   (lambda (params)
     (cache? (cgi-get-parameter "cache" params :default #f :convert (compose positive? x->integer)))
     (or (and-let* ((スレid (cgi-get-parameter "dq" params :default #f :convert x->integer))
                    (p (db-select-板id&スレURL&スレタイ&レス数 スレid))
                    (板id (car p))
                    (スレURL (cadr p))
                    (スレタイ (caddr p))
                    (レス数 (cadddr p))
                    (p (db-select-板URL&板名 板id))
                    (板URL (car p))
                    (板名  (cdr p)))
           `(ktkreader2
             (@ (type "result"))
             (board
              (id ,板id)
              (title ,板名)
              (url ,板URL)
              (subject
               (id ,スレid)
               (title ,スレタイ)
               (rescount ,レス数)
               (url ,スレURL)
               ,(if (update-dat スレURL)
                  (or (and-let* ((スレファイル (db-select-スレファイル-is-not-null スレid))
                                 (source (call-with-input-file スレファイル port->string :encoding 'SHIFT_JIS))
                                 (fmt    (cgi-get-parameter "format" params :default 'html :convert string->symbol))
                                 (srt    (cgi-get-parameter "sort"   params :default 0     :convert x->integer)))
                        (case fmt
                          ((xml)
                           (if (positive? srt)
                             (sort-res (xml-formatter source))
                             (xml-formatter source)))
                          ((html)
                           (html-formatter
                            (if (positive? srt)
                              (sort-res (xml-formatter source))
                              (xml-formatter source))))
                          ((dat)
                           `(dat ,source))
                          (else
                           `(dat ,source))
                          ))
                      `(dat "cache-miss"))
                  `(dat "error"))))))
         "503"))
   :output-proc cgi-output-sxml->xml
   :on-error cgi-on-error
   ))

;; Local variables:
;; mode: inferior-gauche
;; end:
