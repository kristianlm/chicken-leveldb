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

 (leveldb-put db "a" "1")
 (leveldb-put db "b" "2")
 (leveldb-put db "c" "3")

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
   (test "explicitly destroyable" (begin) (leveldb-iter-destroy it)))

  (test-group
   "leveldb writebatch"

   (define put leveldb-writebatch-put)
   (define wb (leveldb-writebatch))
   (test #t (leveldb-writebatch-t? wb))

   (put wb "a" "A wb")
   (put wb "b" "B wb")
   (put wb "c" "C wb")
   (leveldb-write db wb)

   (test "wb write" "A wb" (leveldb-iter-value (leveldb-iterator db seek: 'first)))
   (test "explicit call to leveldb-writebatch-destroy" (begin) (leveldb-writebatch-destroy wb))))

 (test-group
  "compaction range"
  (leveldb-compact-range db "a" "b")
  (leveldb-compact-range db #f #f)))


(test-exit)
