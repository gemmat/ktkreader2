(use srfi-1)
(use file.util)
(use rfc.http)
(use rfc.uri)
(use gauche.process)
(use sxml.sxpath)

;;(use text.html-lite)
;;(use util.match)
;;(use www.cgi)

(add-load-path "./")
(use lib.bbsmenu)
(use lib.util)
(use lib.db)

(define (get-2ch-subject 板URL)
  (receive (status header gzip-body)
      (receive (_ _ host _ path _ _) (uri-parse 板URL)
        (let* ((p (db-select-板最終更新日時&板etag 板URL))
               (板最終更新日時 (and p (car p)))
               (板etag       (and p (cdr p))))
          (http-get host
                    (build-path path "subject.txt")
                    :user-agent "Monazilla/1.00"
                    :accept-encoding "gzip"
                    :if-modified-since 板最終更新日時
                    :etag              板etag)))
    (cond
     ((string=? status "200")
      (db-insert-板 板URL) ;;楽観的insertion UNIQUE制約エラーは気にしない
      (and-let* ((板id (db-select-板id 板URL)))
        (db-update-板最終更新日時&板etag 板id (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
        (or (and-let* ((c (acadr (assoc "content-encoding" header)))
                       ((string=? c "gzip"))
                       (utf8-body (call-with-input-string-gzip gzip-body sjis-port->utf8-string))
                       (subject   (string-split utf8-body "\n")))
              (db-insert-update-スレs-from-subject-text subject 板id 板URL)
              subject)
            gzip-body)))
     (else (list status header gzip-body)))))

(define (get-2ch-dat-full スレURL)
  (receive (板URL スレキー) (decompose-スレURL スレURL)
    (and 板URL
         スレキー
         (receive (status header gzip-body)
             (receive (_ _ host _ path _ _) (uri-parse スレURL)
               (http-get host
                         path
                         :user-agent "Monazilla/1.00"
                         :accept-encoding "gzip"))
           (cond
            ((string=? status "200")
             (and-let* ((板id (db-select-板id 板URL)))
               (db-insert-スレ 板id スレURL)
               (and-let* ((スレid (db-select-スレid スレURL))
                          (スレファイル (build-path (current-directory) "dat" (path-swap-extension (x->string スレid) "dat"))))
                 (or (and-let* ((c (acadr (assoc "content-encoding" header)))
                                ((string=? c "gzip")))
                       (call-with-output-file スレファイル
                         (lambda (out)
                           (call-with-input-string-gzip gzip-body (cut copy-port <> out)))))
                     (call-with-output-file スレファイル
                       (lambda (out)
                         (call-with-input-string gzip-body (cut copy-port <> out)))))
                 (db-update-スレファイル スレid スレファイル)
                 (db-update-スレ最終更新日時&スレetag スレid (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
                 (call-with-input-file スレファイル port->string :encoding 'SHIFT_JIS))))
            (else status))))))

(define (get-2ch-dat-diff スレid スレURL スレファイル)
  (and-let* ((スレファイルのバイト数 (file-size スレファイル))
             (スレ差分ファイル (path-swap-extension スレファイル "dat.diff"))
             (p (db-select-スレ最終更新日時&スレetag スレid))
             (スレ最終更新日時 (car p))
             (スレetag      (cdr p)))
    (receive (status header body)
        (call-with-output-file スレ差分ファイル
          (lambda (out)
            (receive (_ _ host _ path _ _) (uri-parse スレURL)
              (http-get host
                        path
                        :user-agent "Monazilla/1.00"
                        :if-modified-since スレ最終更新日時
                        :etag              スレetag
                        :range (format #f "bytes=~a-" (- スレファイルのバイト数 1))
                        :sink out
                        :flusher (lambda _ #t)))))
      (cond
       ((string=? status "206")
        (db-update-スレ最終更新日時&スレetag スレid (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
        ;;rangeで-1した分に\nが入っているかどうか
        (if (char=? #\newline (call-with-input-process `(head -c 1 ,スレ差分ファイル) read-char :encoding 'SHIFT_JIS))
            ;;先頭1行に、rangeで-1した分の\nが入っているので消す
            (call-with-input-process (format #f "sed '1,1d' >> ~a" スレファイル) (lambda _ #t) :input スレ差分ファイル)
            'あぼーん))
       ((string=? status "304")
        '更新無し)
       ((string=? status "416")
        'あぼーん)))))

(define (get-2ch-dat スレURL)
  (or (and-let* ((p (db-select-スレid-スレファイル-is-not-null スレURL))
                 (スレid     (car p))
                 (スレファイル (cdr p)))
        (get-2ch-dat-diff スレid スレURL スレファイル))
      (get-2ch-dat-full スレURL)))

(define (get-2ch-bbsmenu)
  (define sxml (bbsmenu-html-http->sxml "http://menu.2ch.net/bbsmenu.html"))
  (db-insert-板URL&板名-transaction
   (filter-map (lambda (x)
                 (and-let* ((板URL ((if-car-sxpath '(@ href *text*)) x))
                            (板名  ((if-car-sxpath '(*text*)) x)))
                   (cons 板URL 板名)))
               ((sxpath '(category board)) sxml))))

;;(ces-convert (call-with-input-file "/var/www/subject.txt" port->string) 'SHIFT_JIS)

;;(drop-table-bbsmenu)
;;(create-table-bbsmenu)

;;(drop-table-subject)
;;(create-table-subject)

;;(get-2ch-bbsmenu)

;;(get-2ch-dat-full "http://pc12.2ch.net/sns/dat/1260300967.dat")
;;(get-2ch-dat "http://pc12.2ch.net/sns/dat/1260300967.dat")
;;(get-2ch-subject "http://gimpo.2ch.net/namazuplus/")
;;(get-2ch-subject "http://pc12.2ch.net/sns/")
;;(get-2ch-subject "http://live24.2ch.net/eq/")
;;(get-2ch-subject "http://gimpo.2ch.net/localfoods")
;;(get-2ch-subject "http://localhost/")

;;(use gauche.reload)
;;(reload-modified-modules)
;;(reload 'lib.db)

;;(use gauche.charconv)
;;(use gauche.process)
;; (define (sjis-port->utf8-string in)
;;   (call-with-input-conversion in port->string :encoding 'SHIFT_JIS))
;; (define (call-with-input-string-gzip string proc)
;;   (call-with-input-string string
;;     (lambda (source)
;;       (call-with-process-io
;;        "zcat -"
;;        (lambda (in out)
;;          (copy-port source out)
;;          (close-output-port out)
;;          (unwind-protect
;;           (proc in)
;;           (close-input-port in)))))))
;; (receive (status header gzip-body)
;;     (http-get "localhost"
;;               "/subject.txt"
;;               :accept-encoding "gzip")
;;   (cond
;;    ((string=? status "200")
;;     (or (and-let* ((c (acadr (assoc "content-encoding" header)))
;;                    ((string=? c "gzip"))
;;                    (utf8-body (call-with-input-string-gzip gzip-body sjis-port->utf8-string))
;;                    (subject   (string-split utf8-body "\n")))
;;           subject)
;;         gzip-body))
;;      (else (list status header gzip-body))))

;; Local variables:
;; mode: inferior-gauche
;; end:
