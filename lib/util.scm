(define-module lib.util
  (use srfi-1)
  (use rfc.http)
  (use rfc.uri)
  (use file.util)
  (use gauche.process)
  (export acar
          acadr
          http-get-gzip
          decompose-スレURL
          compose-スレURL
  )
)

(select-module lib.util)

(define (acar l)
  (and l (list-ref l 0 #f)))

(define (acadr l)
  (and l (list-ref l 1 #f)))

(define (delete-keywords! key-list kv-list)
  (fold delete-keyword! kv-list key-list))

(define (http-get-gzip server request-uri . args)
  (call-with-process-io
   ;; why 'cat'? I dunno.
   "tee hoga | zcat -"
   (lambda (in out)
     (let ((sink    (get-keyword :sink    args (open-output-string)))
           (flusher (get-keyword :flusher args (lambda (x _) (get-output-string x)))))
       (let ((s out)
             (f (lambda _ (close-output-port out)))
             (rest (delete-keywords! '(:sink :flusher) args)))
         (receive (status header _) (apply http-get `(,server ,request-uri :sink ,s :flusher ,f ,@rest))
           (copy-port in sink)
           (values status header (flusher sink header))))))))

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

(provide "util")