(define-module lib.util
  (use srfi-1)
  (use rfc.http)
  (use rfc.uri)
  (use file.util)
  (use gauche.charconv)
  (use gauche.process)
  (export acar
          acadr
          sjis-port->utf8-string
          call-with-input-string-gzip
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

(provide "util")