#!/usr/local/bin/gosh
(use rfc.uri)
(use util.match)
(use text.html-lite)
(use www.cgi)

(add-load-path "./")
(use ktkr2.db)
(use ktkr2.util)

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
          (html:title "メニュー"))
         (html:body
          (パンくず)
          (html:ul
           (map (match-lambda
                 ((板id 板URL 板名)
                  (html:li
                   (html:dl
                    (html:a
                     :href (href-subject 板id)
                     (html:dt (html-escape-string 板名)))
                    (html:dd (html-escape-string 板URL))))))
                (db-select-板id&板URL&板名)))))
       ))))

;; Local variables:
;; mode: inferior-gauche
;; end:
