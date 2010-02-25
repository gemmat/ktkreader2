(define-module lib.db
  (use dbi)
  (use sqlite3)
  (use gauche.collection)
  (use util.relation)
  (use lib.util)
  (export call-with-ktkr2-sqlite
          call-with-ktkr2-sqlite-transaction
          create-table-bbsmenu
          create-table-subject
          drop-table-bbsmenu
          db-select-板最終更新日時
          db-select-板id
          db-insert-板
          db-insert-板URL&板名
          db-update-板最終更新日時&板etag
          drop-table-subject
          db-insert-スレ
          db-update-スレファイル
          db-update-スレ最終更新日時&スレetag
          db-delete-all-板のスレ
          db-select-スレid-スレファイル-is-not-null
          db-select-スレ最終更新日時
          test
          )
  )

;;(use srfi-1)
;;(for-each print (filter-map (lambda (x) (and (eq? 'define (car x)) (caadr x))) (call-with-input-file "./ktkr2db.scm" port->sexp-list)))

(select-module lib.db)

(define (call-with-ktkr2-sqlite proc)
  (guard (e ((<dbi-error> e)
             (print (condition-ref e 'message))))
    (let1 conn (dbi-connect "dbi:sqlite3:/home/teruaki/ktkr2/ktkr2.sqlite")
      (begin0
        (proc conn)
        (dbi-close conn)))))

(define (call-with-ktkr2-sqlite-transaction proc)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (dbi-do conn "BEGIN TRANSACTION")
     (let1 r (proc conn)
       (dbi-do conn "END TRANSACTION")
       r))))

(define (create-table-bbsmenu)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "CREATE TABLE IF NOT EXISTS bbsmenu (\
                                      id INTEGER PRIMARY KEY, \
                                      板URL TEXT NOT NULL UNIQUE, \
                                      板名 TEXT, \
                                      板最終更新日時 TEXT, \
                                      板etag TEXT)"))
            (result (dbi-execute query)))
       result))))

(define (create-table-subject)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "CREATE TABLE IF NOT EXISTS subject (\
                                      id INTEGER PRIMARY KEY, \
                                      板id INTEGER NOT NULL, \
                                      スレキー TEXT NOT NULL, \
                                      スレタイ TEXT, \
                                      レス数 INTEGER, \
                                      スレ最終更新日時 TEXT, \
                                      スレetag TEXT, \
                                      スレファイル TEXT)"))
            (result (dbi-execute query)))
       result))))

(define (drop-table-bbsmenu)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "DROP TABLE bbsmenu"))
            (result (dbi-execute query)))
       result))))

(define (db-select-板最終更新日時&板etag 板URL)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "SELECT 板最終更新日時, 板etag FROM bbsmenu WHERE 板URL = ?"))
            (result (dbi-execute query 板URL))
            (getter (relation-accessor result)))
       (acar (map (lambda (row)
                    (cons (getter row "板最終更新日時")
                          (getter row "板etag")))
                  result))))))

(define (db-select-板id 板URL)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "SELECT id FROM bbsmenu WHERE 板URL = ?"))
            (result (dbi-execute query 板URL))
            (getter (relation-accessor result)))
       (acar (map (lambda (row)
                    (getter row "id"))
                  result))))))

(define (db-insert-板 板URL)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "INSERT INTO bbsmenu (板URL) VALUES (?)"))
            (result (dbi-execute query 板URL)))
         result))))

(define (db-insert-板URL&板名 板URL 板名)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "INSERT INTO bbsmenu (板URL, 板名) VALUES (?, ?)"))
            (result (dbi-execute query 板URL 板名)))
         result))))

(define (db-update-板最終更新日時&板etag id 板最終更新日時 板etag)
  (when (and id (or 板最終更新日時 板etag))
    (call-with-ktkr2-sqlite
     (lambda (conn)
       (cond
        ((and 板最終更新日時 板etag)
         (let* ((query (dbi-prepare conn "UPDATE bbsmenu SET 板最終更新日時 = ?, 板etag = ? WHERE id = ?"))
                (result (dbi-execute query 板最終更新日時 板etag id)))
           result))
        (板最終更新日時
         (let* ((query (dbi-prepare conn "UPDATE bbsmenu SET 板最終更新日時 = ? WHERE id = ?"))
                (result (dbi-execute query 板最終更新日時 id)))
           result))
        (板etag
         (let* ((query (dbi-prepare conn "UPDATE bbsmenu SET 板etag = ? WHERE id = ?"))
                (result (dbi-execute query 板etag id)))
           result)))))))

(define (drop-table-subject)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "DROP TABLE subject"))
            (result (dbi-execute query)))
       result))))

(define (db-insert-スレ 板id スレキー)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "INSERT INTO subject (板id, スレキー) VALUES (?, ?)"))
            (result (dbi-execute query 板id スレキー)))
       result))))

(define (db-update-スレファイル 板id スレキー スレファイル)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "UPDATE subject SET スレファイル = ? WHERE 板id = ? AND スレキー = ?"))
            (result (dbi-execute query スレファイル 板id スレキー)))
         result))))

(define (db-update-スレ最終更新日時&スレetag id スレ最終更新日時 スレetag)
  (when (and id (or スレ最終更新日時 スレetag))
    (call-with-ktkr2-sqlite
     (lambda (conn)
       (cond
        ((and スレ最終更新日時 スレetag)
         (let* ((query (dbi-prepare conn "UPDATE subject SET スレ最終更新日時 = ?, スレetag = ? WHERE id = ?"))
                (result (dbi-execute query スレ最終更新日時 スレetag id)))
           result))
        (スレ最終更新日時
         (let* ((query (dbi-prepare conn "UPDATE subject SET スレ最終更新日時 = ? WHERE id = ?"))
                (result (dbi-execute query スレ最終更新日時 id)))
           result))
        (スレetag
         (let* ((query (dbi-prepare conn "UPDATE subject SET スレetag = ? WHERE id = ?"))
                (result (dbi-execute query スレetag id)))
           result)))))))

(define (db-delete-all-板のスレ 板id)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "DELETE FROM subject WHERE 板id = ?"))
            (result (dbi-execute query 板id)))
       result))))

(define (db-select-スレid-スレファイル-is-not-null 板id スレキー)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "SELECT id, スレファイル FROM subject WHERE 板id = ? AND スレキー = ? AND スレファイル IS NOT NULL LIMIT 1"))
            (result (dbi-execute query 板id スレキー))
            (getter (relation-accessor result)))
       (acar (map (lambda (row)
                    (cons (getter row "id") (getter row "スレファイル")))
                  result))))))

(define (db-select-スレ最終更新日時&スレetag id)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (let* ((query (dbi-prepare conn "SELECT スレ最終更新日時, スレetag FROM subject WHERE id = ?"))
            (result (dbi-execute query id))
            (getter (relation-accessor result)))
       (acar (map (lambda (row)
                    (cons (getter row "スレ最終更新日時")
                          (getter row "スレetag")))
                  result))))))

(define (test n)
  (call-with-ktkr2-sqlite
   (lambda (conn)
     (case n
       ((i0)
        (let* ((query (dbi-prepare conn "INSERT INTO bbsmenu (板URL, 板名, 板最終更新日時) VALUES ('http://test.2ch.net', 'テスト板', '2009/1/1')"))
               (result (dbi-execute query)))
          result))
       ((i1)
        (let* ((query (dbi-prepare conn "INSERT INTO subject (板id, スレキー, スレタイ, レス数, スレファイル) VALUES (1, 0912312312, 'すごい', 100, '/home/test')"))
               (result (dbi-execute query)))
          result))
       ((i2)
        (let* ((query (dbi-prepare conn "INSERT INTO bbsmenu (板URL, 板名) VALUES ('http://test2.2ch.net', 'テスト板')"))
               (result (dbi-execute query)))
          result))
       ((s0)
        (let* ((query (dbi-prepare conn "SELECT 板最終更新日時 FROM bbsmenu"))
               (result (dbi-execute query))
               (getter (relation-accessor result)))
          (map (lambda (row)
                 (getter row "板最終更新日時"))
               result)))
       ((s1)
        (let* ((query (dbi-prepare conn "SELECT 板id, スレキー, スレタイ, レス数 FROM subject"))
               (result (dbi-execute query))
               (getter (relation-accessor result)))
          (map (lambda (row)
                 (list (getter row "スレキー")
                       (getter row "スレタイ")))
               result)))))))

;;(test 'i0)
;;(test 'i1)
;;(test 'i2)
;;(test 's0)
;;(test 's1)

(provide "db")