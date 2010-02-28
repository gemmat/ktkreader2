(use srfi-1)
(use srfi-19)
(use file.util)
(use rfc.http)
(use rfc.uri)
(use gauche.process)
(use gauche.logger)
(use gauche.parseopt)
(use sxml.sxpath)

;;(use text.html-lite)
;;(use util.match)
;;(use www.cgi)

(add-load-path "./")
(use ktkr2.bbsmenu)
(use ktkr2.util)
(use ktkr2.db)

(log-open (build-path (current-directory) "log" (path-swap-extension (date->string (current-date) "~b_~d_~y") "log"))
          :prefix "~T:")

(define (get-2ch-subject 板URL)
  (log-format "get-2ch-subject ~a" 板URL)
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
                    :if-none-match     板etag)))
    (log-format "get-2ch-subject status: ~a header: ~a" status header)
    (cond
     ((string=? status "200")
      (db-insert-板 板URL) ;;楽観的insertion UNIQUE制約エラーは気にしない
      (and-let* ((板id (db-select-板id 板URL)))
        (db-update-板最終更新日時&板etag 板id (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
        (let* ((utf8-body (if (string=? (acadr (assoc "content-encoding" header)) "gzip")
                            (call-with-input-string-gzip gzip-body sjis-port->utf8-string)
                            (call-with-input-string      gzip-body sjis-port->utf8-string)))
               (subject   (string-split utf8-body "\n")))
          (db-insert-update-スレs-from-subject-text subject 板id 板URL))
        (log-format "get-2ch-subject success.")
        '成功))
     ((string=? status "404")
      (or (and-let* ((板移転URL (get-2ch-板移転 板URL)))
            (get-2ch-subject 板移転URL))
          '板消失))
     (else
      '失敗))))

(define (get-2ch-dat-full スレURL)
  (log-format "get-2ch-dat-full ~a" スレURL)
  (receive (板URL スレキー) (decompose-スレURL スレURL)
    (and 板URL
         スレキー
         (receive (status header gzip-body)
             (receive (_ _ host _ path _ _) (uri-parse スレURL)
               (http-get host
                         path
                         :user-agent "Monazilla/1.00"
                         :accept-encoding "gzip"))
           (log-format "get-2ch-dat-full status: ~a header: ~a" status header)
           (cond
            ((string=? status "200")
             (and-let* ((板id (db-select-板id 板URL)))
               (db-insert-スレ 板id スレURL)
               (and-let* ((スレid (db-select-スレid スレURL))
                          (スレファイル (build-path (current-directory) "dat" (path-swap-extension (x->string スレid) "dat"))))
                 (call-with-output-file スレファイル
                   (lambda (out)
                     (if (string=? (acadr (assoc "content-encoding" header)) "gzip")
                       (call-with-input-string-gzip gzip-body (cut copy-port <> out))
                       (call-with-input-string      gzip-body (cut copy-port <> out)))))
                 (db-update-スレファイル スレid スレファイル)
                 (db-update-スレ最終更新日時&スレetag スレid (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
                 (log-format "get-2ch-dat-full success.")
                 '成功)))
            (else '失敗))))))

(define (get-2ch-dat-diff スレid スレURL スレファイル)
  (log-format "get-2ch-dat-diff ~a ~a ~a" スレid スレURL スレファイル)
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
                        :if-none-match     スレetag
                        :range (format #f "bytes=~a-" (- スレファイルのバイト数 1))
                        :sink out
                        :flusher (lambda _ #t)))))
      (log-format "get-2ch-dat-diff status: ~a header: ~a" status header)
      (cond
       ((string=? status "206")
        (db-update-スレ最終更新日時&スレetag スレid (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
        ;;rangeで-1した分に\nが入っているかどうか
        (if (char=? #\newline (call-with-input-process `(head -c 1 ,スレ差分ファイル)
                                read-char :encoding 'SHIFT_JIS))
          ;;スレ差分ファイルの先頭1行目に、rangeで-1した分の\nが
          ;;入っているので、消してからスレファイルにappendする
          (begin
            (call-with-input-process (format #f "sed '1,1d' >> ~a" スレファイル)
              (lambda _ #t) :input スレ差分ファイル)
            (log-format "get-2ch-dat-diff success.")
            '成功)
          (begin
            (db-update-null-スレ最終更新日時&スレetag スレid)
            (get-2ch-dat-full スレURL)
            'あぼーん)))
       ((string=? status "302")
        '移転)
       ((string=? status "304")
        '更新無し)
       ((string=? status "404")
        '消失)
       ((string=? status "416")
        (db-update-null-スレ最終更新日時&スレetag スレid)
        (get-2ch-dat-full スレURL)
        'あぼーん)
       (else
        (log-format "get-2ch-dat-diff unhandled status: ~a" status)
        '失敗)))))

(define (get-2ch-dat スレURL)
  (log-format "get-2ch-dat ~a" スレURL)
  (or (and-let* ((p (db-select-スレid-スレファイル-is-not-null スレURL))
                 (スレid     (car p))
                 (スレファイル (cdr p)))
        (get-2ch-dat-diff スレid スレURL スレファイル))
      (get-2ch-dat-full スレURL)))

(define (get-2ch-bbsmenu)
  (define sxml (bbsmenu-html-http->sxml "http://menu.2ch.net/bbsmenu.html"))
  (log-format "get-2ch-bbsmenu")
  (db-insert-板URL&板名-transaction
   (filter-map (lambda (x)
                 (and-let* ((板URL ((if-car-sxpath '(@ href *text*)) x))
                            (板名  ((if-car-sxpath '(*text*)) x)))
                   (cons 板URL 板名)))
               ((sxpath '(category board)) sxml))))

(define (get-2ch-板移転 板URL)
  (define (helper 板URL count)
    (log-format "get-2ch-板移転 ~a count: ~a" 板URL count)
    (if (> count 4)
      'たらい回し
      (receive (status header body)
          (receive (_ _ host _ path _ _) (uri-parse 板URL)
            (let1 out (open-output-string)
              (http-get host
                        (build-path path "index.html")
                        :user-agent "Monazilla/1.00"
                        :sink (open-output-conversion-port out 'UTF-8 :from-code 'SHIFT_JIS :owner? #t)
                        :flusher (lambda (sink _)
                                   (flush sink)
                                   (unwind-protect
                                    (get-output-string out)
                                    (close-output-port sink))))))
        (log-format "get-2ch-板移転 status: ~a header ~a" status header)
        (cond
         ((string=? status "200")
          (rxmatch-if (#/<title>2chbbs\.\.<\/title>/ body)
              (#f)
              (rxmatch-if (#/<a href=\"(h[^\">]+)/ body)
                  (#f 板移転後URL)
                  (helper 板移転後URL (+ count 1))
                  '板移転後URL取得失敗)
              板URL))
         (else '失敗)))))
  (let1 result (helper 板URL 0)
    (cond
     ((string? result)
      (log-format "get-2ch-板移転 src: ~a dst: ~a" 板URL result)
      (db-update-板URL 板URL result)
      result)
     (else
      (log-format "get-2ch-板移転 ~a" result)
      (and-let* ((板id (db-select-板id 板URL))
                 (スレファイルs (db-select-板のスレファイル 板id)))
        (delete-files スレファイルs)
        (db-delete-板 板id)
        (db-delete-板のスレ 板id)
        #f)))))

(define (main args)
  (let-args (cdr args)
      ((bbsmenu    "b|bbsmenu")
       (subject    "s|subject=s")
       (dat        "d|dat=s")
       (init       "i|init")
       (#f         "h|help" => usage)
       (else (opt . _) (print "Unknown option : " opt) (usage))
       . restargs)
    (cond
     (bbsmenu
      (get-2ch-bbsmenu))
     (subject
      (get-2ch-subject subject))
     (dat
      (get-2ch-dat dat))
     (init
      (db-drop-table-bbsmenu)
      (db-drop-table-subject)
      (db-create-table-bbsmenu)
      (db-create-table-subject)
      (delete-directory "dat")
      (create-directory "dat" #o775))
     (else
      (usage))))
  0)

(define (usage)
  (format #t "usage: main.scm [OPTIONS]... \n")
  (format #t " -b, --bbsmenu     get 2ch bbsmenu.html.\n")
  (format #t " -s, --subject=URL get 2ch board.\n")
  (format #t " -d, --dat=URL     get 2ch thread.\n")
  (format #t " -d, --dat=URL     get 2ch thread.\n")
  (format #t " -i, --init        initialize.\n")
  (format #t " -h, --help        print this documentation.\n")
  #t)

;;(db-drop-table-bbsmenu)
;;(db-create-table-bbsmenu)

;;(db-drop-table-subject)
;;(db-create-table-subject)

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
;;(reload 'ktkr2.db)

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
