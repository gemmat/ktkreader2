#!/usr/local/bin/gosh
(use srfi-1)
(use rfc.http)
(use rfc.uri)
(use gauche.process)
(use gauche.logger)
(use util.match)
(use text.html-lite)
(use www.cgi)

(add-load-path "./")
(use ktkr2.util)
(use ktkr2.db)
(ktkr2-log-open)

(define (update-subject 板URL)
  (or (cache?)
      (and-let* ((process (run-process `(gosh main.scm ,(string-append "--subject=" 板URL))))
                 ((process-wait process)))
        (exit-code (process-exit-status process)))))

(define (response type 板id 板名 板URL data)
  `(ktkreader2
    (@ (type ,type))
    (board
     (id ,板id)
     (title ,板名)
     ,@(receive (host path) (decompose-板URL 板URL)
         (if (and host path)
           `((host ,host)
             (path ,path))
           '()))
     (url ,板URL)
     ,data)))

(define (main args)
  (cgi-main
   (lambda (params)
     (cache? (cgi-get-parameter "cache" params :default #f :convert (compose positive? x->integer)))
     (or (and-let* ((板id (cgi-get-parameter "sq" params :default #f :convert x->integer))
                    (p (db-select-板URL&板名 板id))
                    (板URL (car p))
                    (板名  (cdr p)))
           (case (update-subject 板URL)
             ((成功 更新無し #t)
              (response
               "result" 板id 板名 板URL
               `(subjects
                 ,@(map (match-lambda
                         ((スレid スレURL スレタイ レス数 スレファイル)
                          (let1 スレキー (extract-スレキー スレURL)
                            `(subject
                              (id ,スレid)
                              (title ,スレタイ)
                              (rescount ,レス数)
                              (key ,スレキー)
                              (speed ,(スレの勢い レス数 スレキー))
                              (cache ,(or (and スレファイル 1) 0))))))
                        (or (and-let* ((word (cgi-get-parameter "ss" params :default #f :convert (cut uri-decode-string <> :cgi-decode #t))))
                              (db-select-スレid&スレURL&スレタイ&レス数&スレファイル-where-板id-スレタイ-glob 板id word))
                            (db-select-スレid&スレURL&スレタイ&レス数&スレファイル 板id))))))
             ((板移転)
              (response
               "error" 板id 板名 板URL
               `(subjects
                 (subject
                  (title "板が移転しました。F5リロードすると直るかも。")))))
             ((板消失)
              (response
               "error" 板id 板名 板URL
               `(subjects
                 (subject
                  (title "板が消えたようです。")))))
             (else
              (response
               "error" 板id 板名 板URL
               `(subjects
                 (subject
                  (title "エラー。ご迷惑をおかけして申し訳ありません。")))))))
         "503"))
   :output-proc cgi-output-sxml->xml
   :on-error cgi-on-error
   ))

;; Local variables:
;; mode: inferior-gauche
;; end:
