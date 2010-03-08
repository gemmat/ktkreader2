(define-module ktkr2.util
  (use srfi-1)
  (use srfi-13)
  (use srfi-19)
  (use rfc.http)
  (use rfc.uri)
  (use file.util)
  (use text.html-lite)
  (use text.tree)
  (use sxml.serializer)
  (use www.cgi)
  (use gauche.charconv)
  (use gauche.process)
  (use gauche.logger)
  (use gauche.parameter)
  (export acar
          acadr
          sjis-port->utf8-string
          call-with-input-string-gzip
          http-get-gzip
          decompose-スレURL
          compose-スレURL
          distribute-path
          ktkr2-log-open
          dry?
          href-bbsmenu
          href-subject
          href-dat
          decompose-板URL
          extract-スレキー
          パンくず
          cgi-output-sxml->xml
          cgi-on-error
          xml-formatter
          スレURL->元URL
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

(define dry? (make-parameter #f))

(define (href-bbsmenu)
  (string-append "./bbsmenu.cgi" (if (dry?) "?dry=1" "")))

(define (href-subject 板id)
  (string-append "./subject.cgi?q=" (x->string 板id) (if (dry?) "&dry=1" "")))

(define (href-dat スレid)
  (string-append "./dat.cgi?q=" (x->string スレid) (if (dry?) "&dry=1" "")))

(define (decompose-板URL 板URL)
  (receive (_ _ host _ path _ _) (uri-parse 板URL)
    (if path
      (values host (acar (string-tokenize path #[\w])))
      (values #f #f))))

(define (extract-スレキー スレURL)
  (receive (_ _ host _ path _ _) (uri-parse スレURL)
    (and path
         (receive (_ f _) (decompose-path スレURL)
           f))))

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

;; SXMLをXMLに変換してCGIの出力にする
(define (cgi-output-sxml->xml sxml)
  (write-tree `(,(cgi-header :content-type "text/xml")))
  (srl:parameterizable
   sxml
   (current-output-port)
   '(method . xml) ; XML
   '(indent . #f) ; no indent
   '(omit-xml-declaration . #f) ; append the XML declaretion
   '(standalone . yes) ; add "standalone" declaretion
   '(version . "1.0")))

;; 例外メッセージをSXMLにする
(define (cgi-on-error e)
  `(error ,(html-escape-string (slot-ref e 'message))))

(define regexp-html (string->regexp "(((ht|f|t)tp(s?))\:\/\/){1}((([\\w\-]{2,}\.)+[a-zA-Z]{2,})|((?:(?:25[0-5]|2[0-4]\\d|[01]\\d\\d|\\d?\\d)(?:(\\.?\\d)))){4})(:\\w+)?\/?([\\w\\-\\._\\?\\,\\'\/\\+&%\\$#\\=~]*)?"))

;;(regexp-html "http://www.google.co.jp/")
;;(regexp-html "http://192.168.11.3/")
;;(regexp-html "http://127.0.0.1/") ;;not match
;;(regexp-html "http://localhost/")
;;(regexp-html "https://localhost/")
;;(regexp-html "ttp://localhost/")
;;(regexp-html "ftp://localhost/")
;;(regexp-html "ttps://localhost/")
;;(regexp-html "http://localhost/hoge/fuga/file1.jpg.bz2")

;;(res-formatter "</b> ◆GEMMA <b><>sage<>2000/01/01(土) 12:00:00 ID:kRFPgbVx BE:11111111-###<> <a href='../test/read.cgi/nandemo/1114790198/1' target='_blank'>&gt;&gt;1-100</a>ひゃっはーーー ttp://www.google.co.jp/ <a href='../test/read.cgi/nandemo/1114790198/999' target='_blank'>＞＞999</a> tesuto--- http://192.168.11.3/ http://127.0.0.1/ http://localhost <>")
;;"<div class='res' id='3'><span class='res-id'>3:</span><span class='res-name'><b> ◆GEMMA </b></span><span class='res-mail'>sage</span><span class='res-date'>2000/01/01(土) 12:00:00 <span class='res-id'>ID:kRFPgbVx BE:11111111-###</span></span><div class='res-body'> <a class='res-ref' href='#1'>&gt;&gt;1</a>-<a class='res-ref' href='#100'>100</a>ひゃっはーーー <a href='http://www.google.co.jp/'>ttp://www.google.co.jp/</a> <a class='res-ref' href='#999'>＞＞999</a> tesuto--- <a href='http://192.168.11.3/'>http://192.168.11.3/</a> http://127.0.0.1/ <a href='http://localhost'>http://localhost</a> </div></div>"

(define (xml-formatter source)
  (define c 0)
  (define (res-formatter line)
    (inc! c)
    (and-let* ((c (x->string c))
               (l (string-split line "<>"))
               (name  (list-ref l 0 #f))
               (mail  (list-ref l 1 #f))
               (date  (list-ref l 2 #f))
               (body  (list-ref l 3 #f))
               (title (list-ref l 4 "")))
      `(res
        (id ,c)
        ,(rxmatch-if (#/<\/b>([^<]*)<b>/ name)
             (#f trip)
             `(name (@ (trip ,trip)) ,name)
             `(name ,name))
        (mail ,(html-escape-string mail))
        ,(rxmatch-if (#/\sID:(.+)/ date)
             (#f id)
             `(date (@ (id ,id)) ,date)
             `(date ,date))
        (body ,(regexp-replace-all*
                (regexp-replace-all #/<a[^>]*>/ body "<a>")
                #/<a>(&gt\;&gt\;|&gt\;|＞＞|＞)(\d{1,4})(-|～|～|=|＝)(\d{1,4})<\/a>/
                "<a class='res-ref' href='#\\2'>\\1\\2</a>\\3<a class='res-ref' href='#\\4'>\\4</a>"
                #/<a>(&gt\;&gt\;|&gt\;|＞＞|＞)(\d{1,4})<\/a>/
                "<a class='res-ref' href='#\\2'>\\1\\2</a>"
                regexp-html
                (lambda (m)
                  (let* ((s (m 0))
                         (t (rxmatch-if (#/^ttps?:\/\// s)
                                (#f)
                                (string-append "h" s)
                                s)))
                    (format #f "<a href='~a'>~a</a>" t s))))))))
  (filter-map res-formatter (string-split source "\n")))

(provide "util")
