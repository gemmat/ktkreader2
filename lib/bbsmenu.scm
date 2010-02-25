(define-module lib.bbsmenu
  (use srfi-1)
  (use gauche.charconv)
  (use rfc.uri)
  (use rfc.http)
  (use sxml.ssax)
  (use sxml.sxpath)
  (use sxml.tools)
  (use sxml.serializer)
  (export bbsmenu-html-file->sxml
          bbsmenu-html-http->sxml
          )
)

(select-module lib.bbsmenu)

(define (inner-body source-string)
  ;;bタグ(カテゴリ)とaタグ(板)のみ取り出す。
  ;;カテゴリ名、板名、板URLを取り出す。
  ;;タグ名をcategory,boardにする。
  (define (extracter source-string)
    (filter-map (lambda (line)
                  (rxmatch-cond
                    ((#/<(?:b|B)>([^<]+)<\/(?:b|B)>/ line)
                     (#f category)
                     `(category ,category))
                    ((#/^<(?:a|A) (?:href|HREF)=(h[^> ]+)/ line)
                     (#f href)
                     (rxmatch-if (#/>([^<]+)<\// line)
                         (#f title)
                         `(board (@ (href ,href)) ,title)
                         #f))
                    (else
                     #f)))
                (string-split source-string "\n")))
  ;;先頭にどのカテゴリにも属さない板があるので取り除く。
  (define (trim-head nodes)
    (drop-while (lambda (x)
                  (eq? 'board (car x)))
                nodes))
  ;;bbsmenu.htmlは、<b>カテゴリ名</b><a href="...">板名</a><a>...となっている。
  ;;つまり、カテゴリと板の親子構造になっていない。親子構造にする。
  (define (structer nodes)
    (let loop ((l nodes)
               (r '()))
      (if (null? l)
        (reverse r)
        (receive (t d) (span (lambda (x)
                               (eq? 'board (car x)))
                             (cdr l))
          (loop d (cons (append (car l) t) r))))))
  
  ;; 公式の板一覧には、板以外のリンクもいくつか含まれているので、除外する必要があります。
  ;;
  ;;     * 板の無いカテゴリ
  ;;       「チャット」「ツール類」「他のサイト」
  ;;       「運営案内」も、板が含まれているものの、他のカテゴリにも配置されている板しかないので、除外しても構いません。
  ;;       「特別企画」は、現在は板は含まれていないものの、板のように読み込めるページもあり、また、過去には通常の板が普通に置かれており、これからもその可能性が無いとは言えないので、除外しない方が良いかもしれません。
  ;;     * ディレクトリの無いURL
  ;;     * http://info.2ch.net/、http://find.2ch.net/
  ;;       板用のサーバではないので、今後も板が作られる可能性はかなり低いでしょう。
  ;;     * 最初のカテゴリが現れる前
  ;;       案内や広告が付いています。
  ;;     * その他、板ではないもの
  ;;       今のところこれまでに挙げたもので対応できますが、新たなリンクの追加に常に対応していかなければなりません。
  ;;
  ;; 非公式の板一覧も利用可能にする場合は、独自に追加された2ch外の板が除外される事のないように注意しましょう。
  (define (filter-bbsmenu sxml)
    (define (proper-board? boards)
      (filter (lambda (board)
                (and-let* ((href  ((if-car-sxpath '(@ href *text*)) board))
                           (title ((if-car-sxpath '(*text*)) board)))
                  (receive (_ _ host _ path _ _) (uri-parse href)
                    (and path
                         (let1 l (string-split path "/")
                           (and (> (length l) 2)
                                (not (string=? "" (list-ref l 1)))))
                         (not (string=? host "info.2ch.net"))
                         (not (string=? host "find.2ch.net"))))))
              boards))
    (define (fix-category category)
      (and-let* ((title  ((if-car-sxpath '(*text*)) category))
                 (boards ((if-sxpath '(board)) category)))
        (and (not (any (cut string=? <> title) '("チャット" "ツール類" "他のサイト" "運営案内" "特別企画" "まちＢＢＳ")))
             (let1 bs (filter proper-board? boards)
               (and (positive? (length bs))
                    `(category ,title ,@bs))))))
    (filter-map fix-category sxml))

  (cons 'bbsmenu (filter-bbsmenu (structer (trim-head (extracter source-string))))))


(define (bbsmenu-html-file->sxml file)
  (inner-body (call-with-input-file file port->string :encoding 'SHIFT_JIS)))

(define (bbsmenu-html-http->sxml url)
  (receive (_ _ host _ path _ _) (uri-parse url)
    (receive (status header body) (let1 out (open-output-string)
                                    (http-get host
                                              path
                                              :user-agent "Monazilla/1.00"
                                              :sink (open-output-conversion-port out 'UTF-8 :from-code 'SHIFT_JIS :owner? #t)
                                              :flusher (lambda (sink _)
                                                         (flush sink)
                                                         (begin0
                                                           (get-output-string out)
                                                           (close-output-port sink)))))
      (cond
       ((string=? status "200") (inner-body body))
       (else `(error ,status))))))

;;(define sxml (bbsmenu-html-file->sxml "../bbsmenu.html"))
;;(define sxml (bbsmenu-html-http->sxml "http://menu.2ch.net/bbsmenu.html"))
;;(call-with-output-file "./bbsmenu.xml" (cut srl:sxml->xml sxml <>))

(provide "bbsmenu")