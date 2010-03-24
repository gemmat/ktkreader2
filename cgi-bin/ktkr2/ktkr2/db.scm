(define-module ktkr2.db
  (use dbi)
  (use sqlite3)
  (use gauche.collection)
  (use gauche.parameter)
  (use gauche.logger)
  (use util.relation)
  (use ktkr2.util)
  (use file.util)
  (use config)
  (export db-ktkr2-conn
          call-with-ktkr2-db
          call-with-ktkr2-db-transaction
          db-create-table-bbsmenu
          db-create-table-subject
          db-drop-table-bbsmenu
          db-drop-table-subject
          db-select-板id&板URL&板名&板最終更新日時
          db-select-板id&板URL&板名&板最終更新日時-where-板名-glob
          db-select-板最終更新日時&板etag
          db-select-板id
          db-select-板URL
          db-select-板URL&板名
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
          db-select-板id&スレURL&スレタイ&レス数
          db-select-スレid&スレファイル-is-not-null
          db-select-スレファイル-is-not-null
          db-select-スレid&スレURL&スレタイ&レス数&スレファイル
          db-select-スレid&スレURL&スレタイ&レス数&スレファイル-where-板id-スレタイ-glob
          db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレタイ-glob
          db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレURL-glob
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
        (and-let* ((conn (dbi-connect (string-append "dbi:sqlite3:" path-db))))
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

(define (db-select-板id&板URL&板名&板最終更新日時)
  (log-format "db-select-板id&板URL&板名&板最終更新日時")
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT id, 板URL, 板名, 板最終更新日時 FROM bbsmenu"))
            (getter (relation-accessor result)))
       (begin0
         (map (lambda (row)
                (list (getter row "id")
                      (getter row "板URL")
                      (getter row "板名")
                      (getter row "板最終更新日時")))
              result)
         (dbi-close result))))))

(define (db-select-板id&板URL&板名&板最終更新日時-where-板名-glob word)
  (log-format "db-select-板id&板URL&板名&板最終更新日時-where-板名-glob ~a" word)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((glob (string-append "*" word "*"))
            (result (dbi-do conn "SELECT id, 板URL, 板名, 板最終更新日時 FROM bbsmenu WHERE 板名 GLOB ?" '() glob))
            (getter (relation-accessor result)))
       (begin0
         (map (lambda (row)
                (list (getter row "id")
                      (getter row "板URL")
                      (getter row "板名")
                      (getter row "板最終更新日時")))
              result)
         (dbi-close result))))))

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

(define (db-select-板URL 板id)
  (log-format "db-select-板URL ~a" 板id)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT 板URL FROM bbsmenu WHERE id = ?" '() 板id))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (getter row "板URL"))
                    result))
         (dbi-close result))))))

(define (db-select-板URL&板名 板id)
  (log-format "db-select-板URL&板名 ~a" 板id)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT 板URL, 板名 FROM bbsmenu WHERE id = ?" '() 板id))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (cons (getter row "板URL")
                            (getter row "板名")))
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
     (let1 query (dbi-prepare conn "INSERT OR IGNORE INTO bbsmenu (板URL, 板名) VALUES (?, ?)")
       (begin0
        (for-each (lambda (x)
                    (let ((板URL (car x))
                          (板名  (cdr x)))
                      (dbi-execute query 板URL 板名)))
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
     (dbi-do conn "CREATE TEMP TABLE subject_new (id INTEGER PRIMARY KEY, 板id, スレURL, スレタイ, レス数)")
     (let1 query (dbi-prepare conn "INSERT INTO subject_new (板id, スレURL, スレタイ, レス数) VALUES (?, ?, ?, ?)")
       (for-each (lambda (x)
                   (rxmatch-if (#/^(\d+\.dat)\<\>(.+)\s\((\d+)\)$/ x)
                       (#f スレキー スレタイ レス数)
                       (let1 スレURL (compose-スレURL 板URL スレキー)
                         (dbi-execute query 板id スレURL スレタイ レス数))
                       #f))
                 body)
       (dbi-close query))
     (dbi-do conn "DELETE FROM subject WHERE スレURL IN (SELECT スレURL from subject WHERE 板id = ? AND スレファイル IS NULL EXCEPT SELECT スレURL from subject_new)" '() 板id)
     (dbi-do conn "UPDATE subject SET レス数 = (SELECT レス数 FROM subject_new WHERE subject.板id = ? AND subject.スレURL = subject_new.スレURL) WHERE スレURL IN (SELECT スレURL FROM subject WHERE 板id = ? INTERSECT SELECT スレURL FROM subject_new)" '() 板id 板id)
     (dbi-do conn "INSERT OR IGNORE INTO subject (板id, スレURL, スレタイ, レス数) SELECT 板id, スレURL, スレタイ, レス数 FROM subject_new"))))

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

(define (db-select-板id&スレURL&スレタイ&レス数 スレid)
  (log-format "db-select-板id&スレURL&スレタイ&レス数 ~a" スレid)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT 板id,スレURL,スレタイ,レス数 FROM subject WHERE id = ?" '() スレid))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (list (getter row "板id")
                            (getter row "スレURL")
                            (getter row "スレタイ")
                            (getter row "レス数")))
                    result))
         (dbi-close result))))))

(define (db-select-スレid&スレファイル-is-not-null スレURL)
  (log-format "db-select-スレid&スレファイル-is-not-null ~a" スレURL)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT id, スレファイル FROM subject WHERE スレURL = ? AND スレファイル IS NOT NULL" '() スレURL))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (cons (getter row "id") (getter row "スレファイル")))
                    result))
         (dbi-close result))))))

(define (db-select-スレファイル-is-not-null スレid)
  (log-format "db-select-スレファイル-is-not-null ~a" スレid)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT スレファイル FROM subject WHERE id = ? AND スレファイル IS NOT NULL" '() スレid))
            (getter (relation-accessor result)))
       (begin0
         (acar (map (lambda (row)
                      (getter row "スレファイル"))
                    result))
         (dbi-close result))))))

(define (db-select-スレid&スレURL&スレタイ&レス数&スレファイル 板id)
  (log-format "db-select-スレid&スレURL&スレタイ&レス数&スレファイル ~a" 板id)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((result (dbi-do conn "SELECT id, スレURL, スレタイ, レス数, スレファイル FROM subject WHERE 板id = ?" '() 板id))
            (getter (relation-accessor result)))
       (begin0
         (map (lambda (row)
                (list (getter row "id")
                      (getter row "スレURL")
                      (getter row "スレタイ")
                      (getter row "レス数")
                      (getter row "スレファイル")))
              result)
         (dbi-close result))))))

(define (db-select-スレid&スレURL&スレタイ&レス数&スレファイル-where-板id-スレタイ-glob 板id word)
  (log-format "db-select-スレid&スレURL&スレタイ&レス数&スレファイル-where-板id-スレタイ-glob ~a ~a" 板id word)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((glob (string-append "*" word "*"))
            (result (dbi-do conn "SELECT id, スレURL, スレタイ, レス数, スレファイル FROM subject WHERE 板id = ? AND スレタイ GLOB ?" '() 板id glob))
            (getter (relation-accessor result)))
       (begin0
         (map (lambda (row)
                (list (getter row "id")
                      (getter row "スレURL")
                      (getter row "スレタイ")
                      (getter row "レス数")
                      (getter row "スレファイル")))
              result)
         (dbi-close result))))))

(define (db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレタイ-glob word)
  (log-format "db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレタイ-glob ~a" word)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((glob (string-append "*" word "*"))
            (result (dbi-do conn "SELECT id, 板id, スレURL, スレタイ, レス数, スレファイル FROM subject WHERE スレタイ GLOB ?" '() glob))
            (getter (relation-accessor result)))
       (begin0
         (map (lambda (row)
                (list (getter row "id")
                      (getter row "板id")
                      (getter row "スレURL")
                      (getter row "スレタイ")
                      (getter row "レス数")
                      (getter row "スレファイル")))
              result)
         (dbi-close result))))))

(define (db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレURL-glob word)
  (log-format "db-select-スレid&板id&スレURL&スレタイ&レス数&スレファイル-where-スレURL-glob ~a" word)
  (call-with-ktkr2-db
   (lambda (conn)
     (let* ((glob (string-append "*" word "*"))
            (result (dbi-do conn "SELECT id, 板id, スレURL, スレタイ, レス数, スレファイル FROM subject WHERE スレURL GLOB ?" '() glob))
            (getter (relation-accessor result)))
       (begin0
         (map (lambda (row)
                (list (getter row "id")
                      (getter row "板id")
                      (getter row "スレURL")
                      (getter row "スレタイ")
                      (getter row "レス数")
                      (getter row "スレファイル")))
              result)
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
