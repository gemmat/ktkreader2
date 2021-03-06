(use srfi-1)
(use file.util)
(use rfc.http)
(use rfc.uri)
(use gauche.process)
(use gauche.logger)
(use gauche.parseopt)
(use gauche.parameter)
(use gauche.charconv)
(use sxml.sxpath)
(use util.match)
(use dbi)

(add-load-path "./")
(use config)
(use ktkr2.bbsmenu)
(use ktkr2.util)
(use ktkr2.db)

(ktkr2-log-open)

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
        '成功))
     ((string=? status "304")
      '更新無し)
     ((string=? status "404")
      (if (get-2ch-板移転 板URL)
        '板移転
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
                          (dir (build-path path-dat (distribute-path スレid 100)))
                          ((create-directory* dir #o775))
                          (スレファイル (build-path dir (path-swap-extension (x->string スレid) "dat"))))
                 (call-with-output-file スレファイル
                   (lambda (out)
                     (if (string=? (acadr (assoc "content-encoding" header)) "gzip")
                       (call-with-input-string-gzip gzip-body (cut copy-port <> out))
                       (call-with-input-string      gzip-body (cut copy-port <> out)))))
                 (rxmatch-if (#/^<html>/ (call-with-input-file スレファイル read-line :encoding 'SHIFT_JIS))
                     (#f)
                     '人大杉
                     (begin
                       (db-update-スレファイル スレid スレファイル)
                       (db-update-スレ最終更新日時&スレetag スレid (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
                       '成功)))))
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
            (call-with-input-process (format #f "sed '1,1d' >> ~a && rm ~a" スレファイル スレ差分ファイル)
              (lambda _ #t) :input スレ差分ファイル)
            '成功)
          (begin
            ;;あぼーん
            (db-update-null-スレ最終更新日時&スレetag スレid)
            (get-2ch-dat-full スレURL))))
       ((string=? status "302")
        'スレ移転)
       ((string=? status "304")
        '更新無し)
       ((string=? status "404")
        'スレ消失)
       ((string=? status "416")
        ;;あぼーん
        (db-update-null-スレ最終更新日時&スレetag スレid)
        (get-2ch-dat-full スレURL))
       (else
        '失敗)))))

(define (get-2ch-dat スレURL)
  (log-format "get-2ch-dat ~a" スレURL)
  (or (and-let* ((p (db-select-スレid&スレファイル-is-not-null スレURL))
                 (スレid     (car p))
                 (スレファイル (cdr p)))
        (get-2ch-dat-diff スレid スレURL スレファイル))
      (get-2ch-dat-full スレURL)))

(define (get-2ch-bbsmenu)
  (log-format "get-2ch-bbsmenu")
  (or (and-let* ((sxml (bbsmenu-html-http->sxml "http://menu.2ch.net/bbsmenu.html")))
        (db-insert-板URL&板名-transaction
         (filter-map (lambda (x)
                       (and-let* ((板URL ((if-car-sxpath '(@ href *text*)) x))
                                  (板名  ((if-car-sxpath '(*text*)) x)))
                         (cons 板URL 板名)))
                     ((sxpath '(category board)) sxml)))
        '成功)
      '失敗))

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
      (if (string=? 板URL result)
        (begin
          (log-format "get-2ch-板移転 src==dst: ~a" result)
          #f)
        (begin
          (log-format "get-2ch-板移転 src: ~a dst: ~a" 板URL result)
          (db-update-板URL 板URL result)
          #t)))
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
       (cron       "c|cron")
       (#f         "h|help" => usage)
       (else (opt . _) (print "Unknown option : " opt) (usage))
       . restargs)
   (parameterize ((db-ktkr2-conn (string-append "dbi:sqlite3:" path-db)))
     (unwind-protect
      (cond
       (bbsmenu
        (let1 r (get-2ch-bbsmenu)
          (log-format "get-2ch-bbsmenu ~a" r)
          (exit-code r)))
       (subject
        (let1 r (get-2ch-subject subject)
          (log-format "get-2ch-subject ~a" r)
          (exit-code r)))
       (dat
        (let1 r (get-2ch-dat dat)
          (log-format "get-2ch-dat ~a" r)
          (exit-code r)))
       (init
        (create-directory* path-dat #o755)
        (create-directory* path-log #o755)
        (db-drop-table-bbsmenu)
        (db-drop-table-subject)
        (db-create-table-bbsmenu)
        (db-create-table-subject)
        (log-format "initialized.")
        0)
       (cron
        ;; */1 * * * * /usr/local/bin/gosh -I/home/teruaki/public_html/cgi-bin/ktkr2/ /home/teruaki/public_html/cgi-bin/ktkr2/main.scm --cron >/dev/null 2>&1
        (let1 cron-板id (call-with-input-file path-cron read)
          (log-format "cron ~a" cron-板id)
          (call-with-output-file path-cron (cut write (+ cron-板id 1) <>))
          (and-let* ((板URL (db-select-板URL (modulo cron-板id 830))))
            (get-2ch-subject 板URL)))
        0)
       (else
        (usage)
        0))
      (dbi-close (db-ktkr2-conn))))))

(define (usage)
  (format #t "usage: gosh main.scm [OPTIONS]... \n")
  (format #t " -b, --bbsmenu     get 2ch bbsmenu.html.\n")
  (format #t " -s, --subject=URL get 2ch board.\n")
  (format #t " -d, --dat=URL     get 2ch thread.\n")
  (format #t " -i, --init        initialize.\n")
  (format #t " -c, --cron        get 2ch board cron.\n")
  (format #t " -h, --help        print this documentation.\n")
  #t)

;; Local variables:
;; mode: inferior-gauche
;; end:
