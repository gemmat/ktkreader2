(define-module config
  (export path-db
          path-log
          path-dat
  )
)

(select-module config)

(define path-db  "/home/teruaki/public_html/cgi-bin/ktkr2/db/ktkr2.sqlite")
(define path-log "/home/teruaki/public_html/cgi-bin/ktkr2/log/")
(define path-dat "/home/teruaki/public_html/cgi-bin/ktkr2/dat/")

(provide "config")
