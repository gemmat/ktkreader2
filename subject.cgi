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
  (or (dry?)
      (and-let* ((process (run-process `(gosh main.scm ,(string-append "--subject=" 板URL))))
                 ((process-wait process)))
        (zero? (process-exit-status process)))))

(define (main args)
  (cgi-main
   (lambda (params)
     (dry? (cgi-get-parameter "dry" params :default #f :convert (compose positive? x->integer)))
     `(,(cgi-header)
       ,(html-doctype)
       ,(html:html
         (html:head
          (html:meta :http-equiv "Content-Type" :content "text/html; charset=UTF-8")
          (html:meta :http-equiv "Content-Script-Type" :content "text/html; charset=UTF-8")
          (html:title "板"))
         (html:body
          (or (and-let* ((板id (cgi-get-parameter "q" params :default #f :convert x->integer))
                         (p (db-select-板URL&板名 板id))
                         (板URL (car p))
                         (板名  (cdr p)))
                (if (update-subject 板URL)
                  `(,(パンくず 板id 板名)
                    ,(html:ul
                      (map (match-lambda
                            ((スレid スレURL スレタイ レス数)
                             (html:li
                              (html:dl
                               (html:dt
                                (html:a
                                 :href (href-dat スレid)
                                 (html:span :class "thread-title" (html-escape-string スレタイ))
                                 (html:span :class "thread-res" "(" レス数 ")") ))
                               (html:dd (html-escape-string スレURL))))))
                           (db-select-スレid&スレURL&スレタイ&レス数 板id))))
                  "error"))
              "fail")))
       ))))

;; Local variables:
;; mode: inferior-gauche
;; end:
