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
  (use sxml.sxpath)
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
          cache?
          href-bbsmenu
          href-subject
          href-dat
          decompose-板URL
          extract-スレキー
          cgi-output-sxml->xml
          cgi-on-error
          xml-formatter
          html-formatter
          sort-res
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

(define cache? (make-parameter #f))

(define (href-bbsmenu)
  (string-append "./bbsmenu.cgi" (if (cache?) "?cache=1" "")))

(define (href-subject 板id)
  (string-append "./subject.cgi?q=" (x->string 板id) (if (cache?) "&cache=1" "")))

(define (href-dat スレid)
  (string-append "./dat.cgi?q=" (x->string スレid) (if (cache?) "&cache=1" "")))

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
    (define ref-list '()) ;;quasi-quoteの評価順序は決まってるんだっけ?
    (inc! c)
    (and-let* ((l (string-split line "<>"))
               (name  (list-ref l 0 #f))
               (mail  (list-ref l 1 #f))
               (date  (list-ref l 2 #f))
               (body  (list-ref l 3 #f))
               (title (list-ref l 4 "")))
      `(res
        (id ,(x->string c))
        ,(rxmatch-if (#/<\/b>([^<]*)<b>/ name)
             (#f trip)
             `(name (@ (trip ,trip)) ,(regexp-replace-all #/<\/b>|<b>/ name ""))
             `(name ,name))
        (mail ,(html-escape-string mail))
        ,(rxmatch-if (#/\sID:(.+)/ date)
             (#f id)
             `(date (@ (id ,id)) ,date)
             `(date ,date))
        (body ,(regexp-replace-all*
                (regexp-replace-all #/<a[^>]*>/ body "<a>")
                #/<a>(&gt\;&gt\;|&gt\;|＞＞|＞)(\d{1,4})(-|～|～|=|＝)(\d{1,4})<\/a>/
                (lambda (m)
                  (push! ref-list (m 2))
                  (push! ref-list (m 4))
                  (format #f "<a class='res-ref' href='#res-~a'>~a~a</a>~a<a class='res-ref' href='#res-~a'>~a</a>" (m 2) (m 1) (m 2) (m 3) (m 4) (m 4)))
                #/<a>(&gt\;&gt\;|&gt\;|＞＞|＞)(\d{1,4})<\/a>/
                (lambda (m)
                  (push! ref-list (m 2))
                  (format #f "<a class='res-ref' href='#res-~a'>~a~a</a>" (m 2) (m 1) (m 2)))
                regexp-html
                (lambda (m)
                  (let* ((s (m 0))
                         (t (rxmatch-if (#/^ttps?:\/\// s)
                                (#f)
                                (string-append "h" s)
                                s)))
                    (format #f "<a href='~a'>~a</a>" t s)))))
        (ref ,(string-join (reverse ref-list) ",")))))
  `(dat ,@(filter-map res-formatter (string-split source "\n"))))

(define (html-formatter dat-sxml)
  (define (null-or-car-sxpath p)
    (lambda (x)
      (or ((if-car-sxpath p) x) "")))
  (define sxp-id        (null-or-car-sxpath '(id *text*)))
  (define sxp-name      (null-or-car-sxpath '(name *text*)))
  (define sxp-name-trip (null-or-car-sxpath '(name @ trip *text*)))
  (define sxp-mail      (null-or-car-sxpath '(mail *text*)))
  (define sxp-date      (null-or-car-sxpath '(date *text*)))
  (define sxp-date-id   (null-or-car-sxpath '(date @ id *text*)))
  (define sxp-body      (null-or-car-sxpath '(body *text*)))
  `(dat
    ,(tree->string
      (html:div
       :class "main"
       (map (lambda (x)
              (html:div
               :class "res"
               :id (string-append "res-" (sxp-id x))
               (html:div
                :class "res-header"
                (html:span
                 :class "res-number"
                 (sxp-id x))
                (html:span
                 :class "res-name nm"
                 (sxp-name x))
                (html:span
                 :class "res-date"
                 ":" (sxp-date x)))
               (html:div
                :class "res-content"
                (html:p
                 :class "rr"
                 (sxp-body x)))))
            ((sxpath '(res)) dat-sxml))))))

;;木の統合
;;http://practical-scheme.net/wiliki/wiliki.cgi?Scheme%3aリスト処理
(define (tree-merge relations)
  (define (pick node trees relations)
    (receive (picked rest)
        (partition (lambda (r) (eq? node (car r))) relations)
      (if (null? picked)
        (receive (subtree other-trees)
            (partition (lambda (t) (eq? node (car t))) trees)
          (if (null? subtree)
            (values (list node) trees relations)
            (values (car subtree) other-trees relations)))
        (receive (subtrees trees relations)
            (merge-fold (cdar picked) '() trees rest)
          (values (cons node subtrees) trees relations)))))

  (define (merge-fold kids subtrees trees relations)
    (if (null? kids)
      (values (reverse subtrees) trees relations)
      (receive (subtree trees relations) (pick (car kids) trees relations)
        (merge-fold (cdr kids) (cons subtree subtrees) trees relations))))

  (define (merge trees relations)
    (if (null? relations)
      trees
      (receive (subtree trees relations)
          (pick (caar relations) trees relations)
        (merge (cons subtree trees) relations))))
  (merge '() relations))

(define (flatten xs)
  (if (pair? xs)
    (append-map flatten xs)
    (list xs)))

(define (sort-res dat-sxml)
  (define res-table (make-hash-table 'eq?))
  (define (extract-relations res-list)
    (define (extract res-list)
      (filter-map (lambda (res)
                    (and-let* ((str  ((if-car-sxpath '(id *text*)) res))
                               (id   (string->number str)))
                      (hash-table-put! res-table id res)
                      (or (and-let* ((str ((if-car-sxpath '(ref *text*)) res))
                                     ((not (string=? str "")))
                                     (refs (map string->number (string-split str ","))))
                            (cons id (delete id refs)))
                          (list id))))
                  res-list))
    (define (merge refs)
      (define ht (make-hash-table 'eq?))
      (for-each (lambda (l)
                  (hash-table-update! ht (apply min l) (cut append <> l) '()))
                refs)
      (sort-by
       (hash-table-map ht (lambda (key value)
                            (cons key (sort (delete-duplicates (delete key value) eq?)))))
       car))
    (define (remove-multipule-parents refs)
      (define ht (make-hash-table 'eq?))
      (map (lambda (l)
             (cons (car l)
                   (remove (lambda (x)
                             (if (hash-table-exists? ht x)
                               #t
                               (begin
                                 (hash-table-put! ht x #t)
                                 #f)))
                           (cdr l))))
           refs))
    (remove-multipule-parents (merge (extract res-list))))
  `(dat
    ,@(map (cut hash-table-get res-table <>)
           (flatten (reverse (tree-merge (extract-relations ((sxpath '(res)) dat-sxml))))))))

;; (and-let* ((スレファイル "../aaaa")
;;            (source (call-with-input-file スレファイル port->string :encoding 'SHIFT_JIS)))
;;   (sort-res (xml-formatter source)))

;; (merge '((56 59) (57) (58 63 64) (60) (61) (62) (64 68) (65 68 70) (66) (67) (69) (71)))

;; (tree-merge '((56 59)
;;               (57)
;;               (58 63 64)
;;               (60)
;;               (61)
;;               (62)
;;               (64 68)
;;               (65 70)
;;               (66)
;;               (67)
;;               (69)
;;               (71)))



(provide "util")

