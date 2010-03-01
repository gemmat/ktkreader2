(define-module ktkr2.util
  (use srfi-1)
  (use srfi-19)
  (use rfc.http)
  (use rfc.uri)
  (use file.util)
  (use text.html-lite)
  (use gauche.charconv)
  (use gauche.process)
  (use gauche.logger)
  (export acar
          acadr
          sjis-port->utf8-string
          call-with-input-string-gzip
          http-get-gzip
          decompose-スレURL
          compose-スレURL
          distribute-path
          ktkr2-log-open
          href-bbsmenu
          href-subject
          href-dat
          パンくず
  )
)

(select-module ktkr2.util)

(define (acar l)
  (and l (list-ref l 0 #f)))

(define (acadr l)
  (and l (list-ref l 1 #f)))

(define (sjis-port->utf8-string in)
  (call-with-input-conversion in port->string :encoding 'SHIFT_JIS))

(define (call-with-input-string-gzip string proc)
  (call-with-input-string string
    (lambda (source)
      (call-with-process-io
       "zcat -"
       (lambda (in out)
         (copy-port source out)
         (close-output-port out)
         (unwind-protect
          (proc in)
          (close-input-port in)))))))

(define (decompose-スレURL スレURL)
  (receive (_ _ host _ path _ _) (uri-parse スレURL)
    (if path
      (receive (p0 f e) (decompose-path path)
        (receive (p1 _ _) (decompose-path p0)
          (values (uri-compose :scheme "http" :host host :path (string-append p1 "/"))
                  (path-swap-extension f e))))
      (values #f #f))))

(define (compose-スレURL 板URL スレキー)
  (receive (_ _ host _ path _ _) (uri-parse 板URL)
    (and path
         (uri-compose  :scheme "http" :host host :path (build-path path "dat" スレキー)))))

(define (distribute-path n m)
  (let1 x (* m (quotient n m))
    (string-join (map number->string (list (+ x 1) (+ x m))) "_")))

(define (ktkr2-log-open)
  (log-open (build-path (current-directory) "log" (path-swap-extension (date->string (current-date) "~b_~d_~y") "log"))
            :prefix "~T:"))

(define (href-bbsmenu)
  "./bbsmenu.cgi")

(define (href-subject 板id)
  (string-append "./subject.cgi?q=" (x->string 板id)))

(define (href-dat スレid)
  (string-append "./dat.cgi?q=" (x->string スレid)))

(define (パンくず . args)
  (let-optionals* args ((板id #f)
                        (板名 #f)
                        (スレid #f)
                        (スレタイ #f)
                        (レス数 #f))
    (html:h2
     (html:a :href (href-bbsmenu) "メニュー")
     (if (and 板id 板名)
       `(" >> "
         ,(html:a
           :href (href-subject 板id)
           (html:span :class "board-title" (html-escape-string 板名)))
         ,(if (and スレid スレタイ レス数)
            `(" >> "
              ,(html:a
                :href (href-dat スレid)
                (html:span :class "thread-title" (html-escape-string スレタイ))
                (html:span :class "thread-res"   "(" レス数 ")")))
            '()))
       '()))))

(provide "util")
