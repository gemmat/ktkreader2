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
  (use sxml.tools)
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
  (if (string? sxml)
    (write-tree `(,(cgi-header :status sxml)))
    (begin
      (write-tree `(,(cgi-header :content-type "text/xml; charset=UTF-8")))
      (srl:parameterizable
       sxml
       (current-output-port)
       '(method . xml) ; XML
       '(indent . #f) ; no indent
       '(omit-xml-declaration . #f) ; append the XML declaretion
       '(standalone . yes) ; add "standalone" declaretion
       '(version . "1.0")))))

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
                #/<a>&gt\;&gt\;(\d{1,4})-(\d{1,4})<\/a>/
                (lambda (m)
                  (let ((ref0 (string->number (m 1)))
                        (ref1 (string->number (m 2))))
                    (if (and (< ref0 1050) (< ref1 1050))
                      (begin
                        (push! ref-list ref0)
                        (push! ref-list ref1)
                        (format #f "<a class='res-ref' href='#res-~a'>&gt;&gt;~a</a>-<a class='res-ref' href='#res-~a'>~a</a>" ref0 ref0 ref1 ref1))
                      (m 0))))
                #/(&gt\;|＞＞|＞)(\d{1,4})(-|～|～|=|＝|,|、)(\d{1,4})(?=[^<'\d])/
                (lambda (m)
                  (let ((ref0 (string->number (m 2)))
                        (ref1 (string->number (m 4))))
                    (if (and (< ref0 1050) (< ref1 1050))
                      (begin
                        (push! ref-list ref0)
                        (push! ref-list ref1)
                        (format #f "<a class='res-ref' href='#res-~a'>~a~a</a>~a<a class='res-ref' href='#res-~a'>~a</a>" ref0 (m 1) ref0 (m 3) ref1 ref1))
                      (m 0))))
                #/<a>&gt\;&gt\;(\d{1,4})<\/a>/
                (lambda (m)
                  (let ((ref0 (string->number (m 1))))
                    (if (< ref0 1050)
                      (begin
                        (push! ref-list ref0)
                        (format #f "<span class='res-ref'>&gt;&gt;~a</span>" ref0))
                      (m 0))))
                #/(&gt\;|＞＞|＞)(\d{1,4})(?=[^<'\d])/
                (lambda (m)
                  (let ((ref0 (string->number (m 2))))
                    (if (< ref0 1050)
                      (begin
                        (push! ref-list ref0)
                        (format #f "<span class='res-ref'>~a~a</span>" (m 1) ref0))
                      (m 0))))
                regexp-html
                (lambda (m)
                  (let* ((s (m 0))
                         (t (rxmatch-if (#/^ttps?:\/\// s)
                                (#f)
                                (string-append "h" s)
                                s)))
                    (format #f "<a href='~a'>~a</a>" t s)))))
        (refs ,(string-join (map x->string (reverse ref-list)) ","))
        ,(list 'color "rr"))))
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
  (define sxp-color     (null-or-car-sxpath '(color *text*)))
  `(dat
    ,(tree->string
      (html:div
       :class "main"
       (map (lambda (x)
              (let1 id (sxp-id x)
                (html:div
                 :class "res"
                 :id (string-append "res-" id)
                 (html:div
                  :class "res-header"
                  :onclick "textEdit(this)"
                  id
                  (html:span
                   :class "nm"
                   (sxp-name x))
                  ":"
                  (sxp-date x))
                 (html:div
                  :class "res-edit"
                  (html:span
                   :class "res-edit-del"
                   :onclick (string-append "edit(" id ",'del')")
                   "ボツ")
                  (html:span
                   :class "res-edit-rr"
                   :onclick (string-append "edit(" id ",'rr')")
                   "黒")
                  (html:span
                   :class "res-edit-r1"
                   :onclick (string-append "edit(" id ",'r1')")
                   "赤")
                  (html:span
                   :class "res-edit-r3"
                   :onclick (string-append "edit(" id ",'r3')")
                   "赤")
                  (html:span
                   :class "res-edit-r2"
                   :onclick (string-append "edit(" id ",'r2')")
                   "青")
                  (html:span
                   :class "res-edit-r4"
                   :onclick (string-append "edit(" id ",'r4')")
                   "青")
                  (html:span
                   :class "res-edit-aa"
                   :onclick (string-append "edit(" id ",'aa')")
                   "AA")
                  (html:span
                   :class "res-edit-a1"
                   :onclick (string-append "edit(" id ",'a1')")
                   "AA")
                  (html:span
                   :class "res-edit-a3"
                   :onclick (string-append "edit(" id ",'a3')")
                   "AA")
                  (html:span
                   :class "res-edit-a2"
                   :onclick (string-append "edit(" id ",'a2')")
                   "AA")
                  (html:span
                   :class "res-edit-a4"
                   :onclick (string-append "edit(" id ",'a4')")
                   "AA")
                  )
                 (html:div
                  :class "res-content"
                  (html:div
                   :id (string-append "res-content-body-" id)
                   :class (sxp-color x)
                   :onclick "textEdit(this)"
                   (sxp-body x)
                   (html:br)
                   (html:br))))))
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
  (define (extract res-list)
    (filter-map (lambda (res)
                  (and-let* ((str  ((if-car-sxpath '(id *text*)) res))
                             (id   (string->number str)))
                    (hash-table-put! res-table id res) ;; side-effect for efficiency...
                    (or (and-let* ((str ((if-car-sxpath '(refs *text*)) res))
                                   ((not (string=? str "")))
                                   (refs (delete id (map string->number (string-split str ",")))))
                          (cons id (delete 1 refs)))
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
  `(dat
    ,@(map (cut hash-table-get res-table <> '())
           (append-map (lambda (l)
                         (if (null? (cdr l))
                           l
                           (let ((head (car l))
                                 (rest (flatten (cdr l))))
                             (hash-table-update!
                              res-table head
                              (lambda (res)
                                (sxml:change-content! ((car-sxpath '(color)) res) '("r1"))
                                res))
                             (for-each (lambda (x)
                                         (hash-table-update!
                                          res-table x
                                          (lambda (res)
                                            (sxml:change-content! ((car-sxpath '(color)) res)
                                                                  (or (and-let* ((refs ((if-car-sxpath '(refs *text*)) res))
                                                                                 ((zero? (string-length refs))))
                                                                        '("r1"))
                                                                      '("r2")))
                                            res)))
                                       rest)
                             (cons head rest))))
                       (reverse (tree-merge (remove-multipule-parents (merge (extract ((sxpath '(res)) dat-sxml))))))))))

;;(and-let* ((スレファイル "../dat/4201_4300/4231.dat")
  ;;         (source (call-with-input-file スレファイル port->string :encoding 'SHIFT_JIS)))
  ;;(sort-res (xml-formatter source)))

;; (reverse (tree-merge '((1) (2) (3) (4) (5) (6) (7) (8) (9) (10) (11) (12) (13) (14) (15) (16) (17) (18) (19) (20) (21) (22) (23) (24) (25) (26) (27) (28) (29) (30) (31) (32) (33) (34) (35) (36) (37) (38) (39) (40) (41) (42) (43) (44) (45) (46) (47) (48) (49) (50) (51) (52) (53) (54 55) (56 59) (57) (58 63 64) (60) (61) (62) (64 68) (65 70) (66) (67) (69) (71))))

(provide "util")
