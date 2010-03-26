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

(define (update-dat スレURL)
  (or (cache?)
      (and-let* ((process (run-process `(gosh main.scm ,(string-append "--dat=" スレURL))))
                 ((process-wait process)))
        (exit-code (process-exit-status process)))))

(define (load-data スレid format sort?)
  (and-let* ((スレファイル (db-select-スレファイル-is-not-null スレid))
             (source (call-with-input-file スレファイル port->string :encoding 'SHIFT_JIS)))
    (case format
      ((xml)
       (if sort?
         (sort-res (xml-formatter source))
         (xml-formatter source)))
      ((html)
       (html-formatter
        (if sort?
          (sort-res (xml-formatter source))
          (xml-formatter source))))
      (else
       `(dat ,source))
      )))

(define (response type 板id 板名 板URL スレid スレタイ レス数 スレURL data)
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
     (subject
      (id ,スレid)
      (title ,スレタイ)
      (rescount ,レス数)
      (url ,スレURL)
      (key ,(extract-スレキー スレURL))
      ,data))))

(define (main args)
  (cgi-main
   (lambda (params)
     (cache? (cgi-get-parameter "cache" params :default #f :convert (compose positive? x->integer)))
     (or (and-let* ((スレid (cgi-get-parameter "dq" params :default #f :convert x->integer))
                    (p (db-select-板id&スレURL&スレタイ&レス数 スレid))
                    (板id (car p))
                    (スレURL (cadr p))
                    (スレタイ (caddr p))
                    (レス数 (cadddr p))
                    (p (db-select-板URL&板名 板id))
                    (板URL (car p))
                    (板名  (cdr p)))
           (case (update-dat スレURL)
             ((成功 更新無し #t)
              (let ((format (cgi-get-parameter "format" params :default 'html :convert string->symbol))
                    (sort?  (cgi-get-parameter "sort"   params :default #f     :convert (compose positive? x->integer))))
                (or (and-let* ((data (load-data スレid format sort?)))
                      (response "result" 板id 板名 板URL スレid スレタイ レス数 スレURL data))
                    (response "error" 板id 板名 板URL スレid スレタイ レス数 スレURL `(dat "ｷｬｯｼｭがありませんでした。")))))
             ((人大杉)
              (response "error" 板id 板名 板URL スレid スレタイ レス数 スレURL `(dat "人大杉")))
             ((スレ移転)
              (response "error" 板id 板名 板URL スレid スレタイ レス数 スレURL `(dat "スレが移転しました。")))
             ((スレ消失)
              (response "error" 板id 板名 板URL スレid スレタイ レス数 スレURL `(dat "スレが消えたようです。")))
             (else
              (response "error" 板id 板名 板URL スレid スレタイ レス数 スレURL `(dat "dat落ち")))))
         "501"))
   :output-proc cgi-output-sxml->xml
   :on-error cgi-on-error
   ))

;; Local variables:
;; mode: inferior-gauche
;; end:
