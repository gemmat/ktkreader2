(use srfi-1)
(use file.util)
(use rfc.http)
(use rfc.uri)
(use gauche.charconv)
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
  (let* ((p (db-select-板最終更新日時&板etag 板URL))
         (板最終更新日時 (car p))
         (板etag       (cdr p)))
    (receive (status header body)
        (receive (_ _ host _ path _ _) (uri-parse 板URL)
          (let1 out (open-output-string)
            (http-get-gzip host
                           (build-path path "subject.txt")
                           :user-agent "Monazilla/1.00"
                           :accept-encoding "gzip"
                           :if-modified-since 板最終更新日時
                           :etag              板etag
                           :sink (open-output-conversion-port out 'UTF-8 :from-code 'SHIFT_JIS :owner? #t)
                           :flusher (lambda (sink _)
                                      (begin0
                                        (string-split (get-output-string out) "\n")
                                        (close-output-port sink))))))
      (print "status:: " status "\n header:: " header "\n")
      (cond
       ((string=? status "200")
        (db-insert-板 板URL) ;;optimistic insertion
        (and-let* ((板id (db-select-板id 板URL)))
          (db-update-板最終更新日時&板etag 板id (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
          (db-insert-update-スレs-from-subject-text body 板id 板URL)))))))

(define (get-2ch-dat-full スレURL)
  (receive (板URL スレキー) (decompose-スレURL スレURL)
    (and 板URL
         スレキー
         (let1 スレファイル (build-path (current-directory) "tmp" スレキー)
           (receive (status header body)
               (call-with-output-file スレファイル
                 (lambda (out)
                   (receive (_ _ host _ path _ _) (uri-parse スレURL)
                     (http-get-gzip host
                                    path
                                    :user-agent "Monazilla/1.00"
                                    :accept-encoding "gzip"
                                    :sink out
                                    :flusher (lambda _ #t)))))
             (cond
              ((string=? status "200")
               (and-let* ((板id (db-select-板id 板URL)))
                 (db-insert-スレ 板id スレURL)
                 (and-let* ((スレid (db-select-スレid スレURL)))
                   (db-update-スレファイル スレid スレファイル)
                   (db-update-スレ最終更新日時&スレetag スレid (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
                   (call-with-input-file スレファイル port->string :encoding 'SHIFT_JIS))))))))))

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
  (for-each (lambda (x)
              (and-let* ((板URL ((if-car-sxpath '(@ href *text*)) x))
                         (板名  ((if-car-sxpath '(*text*)) x)))
                ;;transaction
                (print 板URL ":::" 板名)
                (db-insert-板URL&板名 板URL 板名)))
            ((sxpath '(category board)) sxml)))

;;(use gauche.reload)
;;(reload-modified-modules)
;;(reload 'lib.db)

;;(drop-table-bbsmenu)
;;(create-table-bbsmenu)

;;(drop-table-subject)
;;(create-table-subject)

;;(get-2ch-bbsmenu)
;;(get-2ch-dat-full "http://pc12.2ch.net/sns/dat/1260300967.dat")
;;(get-2ch-dat "http://pc12.2ch.net/sns/dat/1260300967.dat")
;;(get-2ch-dat-full "http://localhost/" "a.dat")
;;(get-2ch-dat-full "http://namidame.2ch.net/venture/" "1262292574.dat")
;;(get-2ch-subject "http://localhost/")
;;(get-2ch-subject "http://pc12.2ch.net/sns/")
;;(db-insert-update-スレs-from-subject-text `("9241002010.dat<>ほげほげ  (4)") 1 "http://pc12.2ch.net/sns/")
;;(use gauche.reload)
;;(reload-modified-modules)
;;(define l (call-with-input-file "./t" port->string-list :encoding 'SHIFT_JIS))
;;(define y (db-insert-update-スレs-from-subject-text l 1 "http://pc12.2ch.net/sns/"))

;; Local variables:
;; mode: inferior-gauche
;; end:
