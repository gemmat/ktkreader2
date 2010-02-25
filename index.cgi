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
  (receive (_ _ host _ path _ _) (uri-parse 板URL)
    (receive (status header body) (let1 out (open-output-string)
                                    (http-get-gzip host
                                                   (build-path path "subject.txt")
                                                   :user-agent "Monazilla/1.00"
                                                   :accept-encoding "gzip"
                                                   :if-modified-since (db-select-板最終更新日時 板URL)
                                                   :sink (open-output-conversion-port out 'UTF-8 :from-code 'SHIFT_JIS :owner? #t)
                                                   :flusher (lambda (sink _)
                                                              (begin0
                                                                (string-split (get-output-string out) "\n")
                                                                (close-output-port sink)))))
      (print "status:: " status "\n header:: " header "\n")
      (cond
       ((string=? status "200")
        (db-insert-板 板URL) ;;optimistic insertion
        (and-let* ((板id (db-select-板id 板URL)))
          (db-update-板最終更新日時&板etag 板id (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
          (db-delete-all-板のスレ 板id)
          (call-with-ktkr2-sqlite-transaction
           (lambda (conn)
             (map (lambda (x)
                    (rxmatch-if (#/^(\d+\.dat)\<\>(.+)\s\((\d+)\)$/ x)
                        (#f スレキー スレタイ レス数)
                        (let* ((query (dbi-prepare conn "INSERT INTO subject (板id, スレキー, スレタイ, レス数) VALUES (?, ?, ?, ?)"))
                               (result (dbi-execute query 板id スレキー スレタイ レス数)))
                          (list 板id スレキー スレタイ レス数 result))
                        #f))
                  body)))))))))

(define (get-2ch-dat-full 板URL スレキー)
  (receive (_ _ host _ path _ _) (uri-parse 板URL)
    (let1 dat-file (build-path (current-directory) "tmp" スレキー)
      (receive (status header body)
          (call-with-output-file dat-file
            (lambda (out)
              (http-get-gzip host
                             (build-path path "dat" スレキー)
                             :user-agent "Monazilla/1.00"
                             :accept-encoding "gzip"
                             :sink out
                             :flusher (lambda _ #t))))
        (cond
         ((string=? status "200")
          (db-insert-板 板URL)
          (and-let* ((板id #?=(db-select-板id 板URL)))
            (db-insert-スレ 板id スレキー)
            (db-update-スレファイル 板id スレキー dat-file)
            (call-with-input-file dat-file port->string :encoding 'SHIFT_JIS))))))))

(define (get-2ch-dat-diff 板URL スレキー 板id スレid スレファイル)
  (receive (_ _ host _ path _ _) (uri-parse 板URL)
    (and-let* ((スレファイルのバイト数 (file-size スレファイル)))
      (let1 dat-diff-file (build-path (current-directory) "tmp" (string-append スレキー ".diff"))
        (receive (status header body)
            (let* ((p (db-select-スレ最終更新日時&スレetag スレid))
                   (スレ最終更新日時 (and p (car p)))
                   (スレetag       (and p (cdr p))))
              (call-with-output-file dat-diff-file
                (lambda (out)
                  (http-get host
                            (build-path path "dat" スレキー)
                            :user-agent "Monazilla/1.00"
                            :if-modified-since スレ最終更新日時
                            :etag              スレetag
                            :range (format #f "bytes=~a-" (- スレファイルのバイト数 1))
                            :sink out
                            :flusher (lambda _ #t)))))
          (print (list status header body))
          (cond
           ((string=? #?=status "206")
            (db-update-スレ最終更新日時&スレetag スレid (acadr (assoc "last-modified" header)) (acadr (assoc "etag" header)))
            ;;rangeで-1した分に\nが入っているかどうか
            (if #?=(char=? #\newline (call-with-input-process `(head -c 1 ,dat-diff-file) read-char :encoding 'SHIFT_JIS))
                ;;先頭1行に、rangeで-1した分の\nが入っているので消す
                #?=(call-with-input-process (format #f "sed '1,1d' >> ~a" スレファイル) (lambda _ #t) :input dat-diff-file)
                'あぼーん))
           ((string=? status "304")
            '更新無し)
           ((string=? status "416")
            'あぼーん)))))))

(define (get-2ch-dat 板URL スレキー)
  (and-let* ((板id (db-select-板id 板URL)))
    (or
     (and-let* ((p (db-select-スレid-スレファイル-is-not-null 板id スレキー))
                (スレid     (car p))
                (スレファイル (cdr p)))
       (get-2ch-dat-diff 板URL スレキー 板id スレid スレファイル))
     (get-2ch-dat-full 板URL スレキー))))

(define (get-2ch-bbsmenu)
  (define sxml (bbsmenu-html-http->sxml "http://menu.2ch.net/bbsmenu.html"))
  (for-each (lambda (x)
              (and-let* ((板URL ((if-car-sxpath '(@ href *text*)) x))
                         (板名  ((if-car-sxpath '(*text*)) x)))
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

;;(get-2ch-dat-full "http://pc12.2ch.net/sns/" "1260300967.dat")
;;(get-2ch-dat "http://pc12.2ch.net/sns/" "1260300967.dat")
;;(get-2ch-dat-full "http://localhost/" "a.dat")
;;(get-2ch-dat-full "http://namidame.2ch.net/venture/" "1262292574.dat")
;;(get-2ch-subject "http://localhost/")
;;(get-2ch-subject "http://namidame.2ch.net/venture/")

;; Local variables:
;; mode: inferior-gauche
;; end:
