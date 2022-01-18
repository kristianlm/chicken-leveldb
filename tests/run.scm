(import test leveldb chicken.file chicken.port)

(if (directory-exists? "test.ldb")
    (delete-directory "test.ldb" #t))

(test-group
 "leveldb-open"

 (test-error (leveldb-open "test.ldb" create-if-missing: #f))

 (define db (leveldb-open "test.ldb"))
 (test #t (leveldb-t? db))
 (test "leveldb-close is idempotent" (void) (leveldb-close db))
 (test "leveldb-close is idempotent" (void) (leveldb-close db))

 (define db (leveldb-open "test.ldb"))

 (test-group
  "leveldb-put / get"

  (leveldb-put db "a" "1")
  (leveldb-put db "b" "2")
  (leveldb-put db "c" "3")
  (leveldb-put db "d" "4")
  (test "1" (leveldb-get db "a"))
  (test "2" (leveldb-get db "b"))
  (test "3" (leveldb-get db "c"))
  (test "4" (leveldb-get db "d"))
  (test #f  (leveldb-get db "< missing key >"))

  (leveldb-delete db "d")
  (leveldb-delete db "< missing key >")
  (test "d gone after delete" #f (leveldb-get db "d")))

 (test-group
  "leveldb-iterator"

  (define it (leveldb-iterator db))
  (test #t (leveldb-iterator-t? it))
  (test #f (leveldb-iter-valid? it))

  (leveldb-iter-seek it 'first)
  (test "a" (leveldb-iter-key it)) (test "1" (leveldb-iter-value it))

  (leveldb-iter-next it)       (test "next" "b" (leveldb-iter-key it))
  (leveldb-iter-seek it "c")   (test "seek" "c" (leveldb-iter-key it))
  (leveldb-iter-prev it)       (test "prev" "b" (leveldb-iter-key it))
  (leveldb-iter-seek it 'last) (test "last" "c" (leveldb-iter-key it))

  (test "#<leveldb-iterator-t \"c\">" (with-output-to-string (lambda () (display it))))
  (leveldb-iter-next it)
  (test "invalid it after \"c\"" #f (leveldb-iter-valid? it))
  (test "no key"   #f (leveldb-iter-key it))
  (test "no value" #f (leveldb-iter-value it))

  (test-group
   "leveldb-iterator args"
   (define it (leveldb-iterator db seek: "b"))
   (test "b" (leveldb-iter-key it))
   (test "explicitly destroyable" (begin) (leveldb-iter-destroy it))))

 (test-group
  "leveldb writebatch"

  (define wb (leveldb-writebatch))
  (define (put k v) (leveldb-writebatch-put wb k v))
  (test #t (leveldb-writebatch-t? wb))

  (put "a" "A wb")
  (put "b" "B wb")
  (leveldb-writebatch-delete wb "c")
  (leveldb-write db wb)

  (test "wb put" "A wb" (leveldb-get db "a"))
  (test "wb deleted" #f (leveldb-get db "c"))
  (test "explicit call to leveldb-writebatch-destroy" (begin) (leveldb-writebatch-destroy wb)))

 (test-group
  "compaction range"
  (leveldb-compact-range db "a" "b")
  (leveldb-compact-range db #f #f)))


(test-exit)
