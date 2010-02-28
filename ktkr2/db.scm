(define-module ktkr2.db
  (use dbi)
  (use sqlite3)
  (use gauche.collection)
  (use gauche.parameter)
  (use gauche.logger)
  (use util.relation)
  (use ktkr2.util)
  (export db-ktkr2-conn
          call-with-ktkr2-db
          call-with-ktkr2-db-transaction
          db-create-table-bbsmenu
          db-create-table-subject
          db-drop-table-bbsmenu
          db-drop-table-subject
          db-select-板最終更新日時&板etag
          db-select-板id
          db-insert-板
          db-insert-板URL&板名
          db-insert-板URL&板名-transaction
          db-update-板最終更新日時&板etag
          db-update-板URL
          db-delete-板
          db-insert-スレ
          db-insert-update-スレs-from-subject-text
          db-update-スレファイル
          db-update-スレ最終更新日時&スレetag
          db-update-null-スレ最終更新日時&スレetag
          db-select-スレid
          db-select-スレid-スレファイル-is-not-null
          db-select-スレ最終更新日時&スレetag
          db-select-板のスレファイル
          db-delete-板のスレ
          )
  )

;;(use srfi-1)
;;(for-each print (filter-map (lambda (x) (and (eq? 'define (car x)) (caadr x))) (call-with-input-file "./db.scm" port->sexp-list)))

(select-module ktkr2.db)

(define db-ktkr2-conn (make-parameter #f (lambda (x)
                                           (and x (dbi-connect x)))))

(define (call-with-ktkr2-db proc)
  (guard (e ((<dbi-error> e)
             (condition-ref e 'message))
            (else (raise e)))
    (or (and-let* ((conn (db-ktkr2-conn)))
          (proc conn))
        (and-let* ((conn (dbi-connect "dbi:sqlite3:/home/teruaki/ktkreader2/ktkr2.sqlite")))
          (unwind-protect
           (proc conn)
           (dbi-close conn))))))

(define (call-with-ktkr2-db-transaction proc)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "BEGIN TRANSACTION")
     (unwind-protect
      (proc conn)
      (dbi-do conn "END TRANSACTION")))))

(define (db-create-table-bbsmenu)
  (log-format "db-create-table-bbsmenu")
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "CREATE TABLE IF NOT EXISTS bbsmenu (\
                     id INTEGER PRIMARY KEY, \
                     板URL TEXT NOT NULL UNIQUE, \
                     板名 TEXT, \
                     板最終更新日時 TEXT, \
                     板etag TEXT)"))))

(define (db-create-table-subject)
  (log-format "db-create-table-subject")
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "CREATE TABLE IF NOT EXISTS subject (\
                     id INTEGER PRIMARY KEY, \
                     板id INTEGER NOT NULL, \
                     スレURL TEXT NOT NULL UNIQUE, \
                     スレタイ TEXT, \
                     レス数 INTEGER, \
                     スレ最終更新日時 TEXT, \
                     スレetag TEXT, \
                     スレファイル TEXT)"))))

(define (db-drop-table-bbsmenu)
  (log-format "db-drop-table-bbsmenu")
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "DROP TABLE bbsmenu"))))

(define (db-drop-table-subject)
  (log-format "db-drop-table-subject")
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "DROP TABLE subject"))))

(define (db-select-板最終更新日時&板etag 板URL)
  (log-format "db-select-板最終更新日時&板etag ~a" 板URL)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT 板最終更新日時, 板etag FROM bbsmenu WHERE 板URL = ?" '() 板URL))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (cons (getter row "板最終更新日時")
                            (getter row "板etag")))
                    result))
         (dbi-close result))))))

(define (db-select-板id 板URL)
  (log-format "db-select-板id ~a" 板URL)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT id FROM bbsmenu WHERE 板URL = ?" '() 板URL))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (getter row "id"))
                    result))
         (dbi-close result))))))

(define (db-insert-板 板URL)
  (log-format "db-insert-板 ~a" 板URL)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "INSERT INTO bbsmenu (板URL) VALUES (?)" '() 板URL))))

(define (db-insert-板URL&板名 板URL 板名)
  (log-format "db-insert-板URL&板名 ~a ~a" 板URL 板名)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "INSERT INTO bbsmenu (板URL, 板名) VALUES (?, ?)" '() 板URL 板名))))

(define (db-insert-板URL&板名-transaction l)
  (log-format "db-insert-板URL&板名-transaction length: ~a" (length l))
  (call-with-ktkr2-db-transaction
   (lambda (conn)
     (let1 query (dbi-prepare conn "INSERT INTO bbsmenu (板URL, 板名) VALUES (?, ?)")
       (begin0
        (for-each (lambda (x)
                    (let ((板URL (car x))
                          (板名  (cdr x)))
                      ;;楽観的insertion UNIQUE制約エラーは気にしない
                      (guard (e ((<sqlite3-error> e)
                                 (unless (eq? (condition-ref e 'error-code) SQLITE_CONSTRAINT)
                                   (raise e)))
                                (else (raise e)))
                        (dbi-execute query 板URL 板名))))
                  l)
        (dbi-close query))))))

(define (db-update-板URL src板URL dst板URL)
  (log-format "db-update-板URL ~a ~a" src板URL dst板URL)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "UPDATE bbsmenu SET 板URL = ?, 板最終更新日時 = '', 板etag = '' WHERE 板URL = ?" '() dst板URL src板URL))))

(define (db-update-板最終更新日時&板etag 板id 板最終更新日時 板etag)
  (log-format "db-update-板最終更新日時&板etag ~a ~a ~a" 板id 板最終更新日時 板etag)
  (when (and 板id (or 板最終更新日時 板etag))
    (call-with-ktkr2-db
     (lambda (conn)
       (cond
        ((and 板最終更新日時 板etag)
         (dbi-do conn "UPDATE bbsmenu SET 板最終更新日時 = ?, 板etag = ? WHERE id = ?" '() 板最終更新日時 板etag 板id))
        (板最終更新日時
         (dbi-do conn "UPDATE bbsmenu SET 板最終更新日時 = ? WHERE id = ?" '() 板最終更新日時 板id))
        (板etag
         (dbi-do conn "UPDATE bbsmenu SET 板etag = ? WHERE id = ?" '() 板etag 板id)))))))

(define (db-delete-板 板id)
  (log-format "db-delete-板 ~a" 板id)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "DELETE FROM bbsmenu WHERE id = ?" '() 板id))))

(define (db-insert-スレ 板id スレURL)
  (log-format "db-insert-スレ ~a ~a" 板id スレURL)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "INSERT INTO subject (板id, スレURL) VALUES (?, ?)" '() 板id スレURL))))

(define (db-insert-update-スレs-from-subject-text body 板id 板URL)
  (log-format "db-insert-update-スレs-from-subject-text length: ~a ~a ~a" (length body) 板id 板URL)
  (call-with-ktkr2-db-transaction
   (lambda (conn)
     (let* ((query0 (dbi-prepare conn "INSERT INTO subject (板id, スレURL) VALUES (?, ?)"))
            (query1 (dbi-prepare conn "UPDATE subject SET スレタイ = ?, レス数 = ? WHERE スレURL = ?")))
       (begin0
        (for-each (lambda (x)
                    (rxmatch-if (#/^(\d+\.dat)\<\>(.+)\s\((\d+)\)$/ x)
                        (#f スレキー スレタイ レス数)
                        (let1 スレURL (compose-スレURL 板URL スレキー)
                          ;;楽観的insertion UNIQUE制約エラーは気にしない
                          (guard (e ((<sqlite3-error> e)
                                     (unless (eq? (condition-ref e 'error-code) SQLITE_CONSTRAINT)
                                       (raise e)))
                                    (else (raise e)))
                            (dbi-execute query0 板id スレURL))
                          (dbi-execute query1 スレタイ レス数 スレURL))
                        #f))
                  body)
        (begin
          (dbi-close query0)
          (dbi-close query1)))))))

(define (db-update-スレファイル スレid スレファイル)
  (log-format "db-update-スレファイル ~a ~a" スレid スレファイル)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "UPDATE subject SET スレファイル = ? WHERE id = ?" '() スレファイル スレid))))

(define (db-update-スレ最終更新日時&スレetag スレid スレ最終更新日時 スレetag)
  (log-format "db-update-スレ最終更新日時&スレetag ~a ~a ~a" スレid スレ最終更新日時 スレetag)
  (when (and スレid (or スレ最終更新日時 スレetag))
    (call-with-ktkr2-db
     (lambda (conn)
       (cond
        ((and スレ最終更新日時 スレetag)
         (dbi-do conn "UPDATE subject SET スレ最終更新日時 = ?, スレetag = ? WHERE id = ?" '() スレ最終更新日時 スレetag スレid))
        (スレ最終更新日時
         (dbi-do conn "UPDATE subject SET スレ最終更新日時 = ? WHERE id = ?" '() スレ最終更新日時 スレid))
        (スレetag
         (dbi-do conn "UPDATE subject SET スレetag = ? WHERE id = ?" '() スレetag スレid)))))))

(define (db-update-null-スレ最終更新日時&スレetag スレid)
  (log-format "db-update-null-スレ最終更新日時&スレetag ~a" スレid)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "UPDATE subject SET スレ最終更新日時 = NULL, スレetag = NULL WHERE id = ?" '() スレid))))

(define (db-select-スレid スレURL)
  (log-format "db-select-スレid ~a" スレURL)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT id FROM subject WHERE スレURL = ?" '() スレURL))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (getter row "id"))
                    result))
         (dbi-close result))))))

(define (db-select-スレid-スレファイル-is-not-null スレURL)
  (log-format "db-select-スレid-スレファイル-is-not-null ~a" スレURL)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT id, スレファイル FROM subject WHERE スレURL = ? AND スレファイル IS NOT NULL" '() スレURL))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (cons (getter row "id") (getter row "スレファイル")))
                    result))
         (dbi-close result))))))

(define (db-select-スレ最終更新日時&スレetag スレid)
  (log-format "db-select-スレ最終更新日時&スレetag ~a" スレid)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT スレ最終更新日時, スレetag FROM subject WHERE id = ?" '() スレid))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (cons (getter row "スレ最終更新日時")
                            (getter row "スレetag")))
                    result))
         (dbi-close result))))))

(define (db-select-板のスレファイル 板id)
  (log-format "db-select-板のスレファイル ~a" 板id)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT スレファイル FROM subject WHERE 板id = ?" '() 板id))
            (getter (relation-accessor result)))
       (begin0
         (map (lambda (row)
                (getter row "スレファイル"))
              result)
         (dbi-close result))))))

(define (db-delete-板のスレ 板id)
  (log-format "db-delete-all-板のスレ ~a" 板id)
  (call-with-ktkr2-db
   (lambda (conn)
     (dbi-do conn "DELETE FROM subject WHERE 板id = ?" '() 板id))))

(provide "db")
