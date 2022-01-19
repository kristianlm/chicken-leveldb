(import chicken.foreign
        (only chicken.blob blob?)
        (only chicken.string conc)
        (only chicken.condition abort make-composite-condition make-property-condition)
        (only chicken.gc set-finalizer!)
        (only chicken.memory move-memory! free)
        (only chicken.memory.representation number-of-bytes))

(foreign-declare "#include <leveldb/c.h>")

(define-record leveldb-t pointer)
(define-foreign-type leveldb (c-pointer "leveldb_t")
  (lambda (leveldb) (leveldb-t-pointer leveldb))
  (lambda (pointer) (make-leveldb-t pointer)))
(define-record-printer leveldb-t
  (lambda (db port)
    (display "#<leveldb-t " port)
    (display (leveldb-t-pointer db) port)
    (display ">" port)))

(define-record leveldb-iterator-t pointer)
(define-foreign-type leveldb-iterator (c-pointer "leveldb_iterator_t")
  (lambda (it) (leveldb-iterator-t-pointer it))
  (lambda (pointer) (make-leveldb-iterator-t pointer)))
(define-record-printer leveldb-iterator-t
  (lambda (it port)
    (display "#<leveldb-iterator-t" port)
    (if (leveldb-iter-valid? it)
        (let* ((key (leveldb-iter-key* it))
               (len (string-length key))
               (key (if (> len 32)
                        (conc (substring key 0 32) "…")
                        key)))
          (display " " port)
          (write key port)))
    (display ">" port)))

(define-record leveldb-writebatch-t pointer)
(define-foreign-type leveldb-writebatch (c-pointer "leveldb_writebatch_t")
  (lambda (it) (leveldb-writebatch-t-pointer it))
  (lambda (pointer) (make-leveldb-writebatch-t pointer)))
(define-record-printer leveldb-writebatch-t
  (lambda (db port)
    (display "#<leveldb-writebatch-t " port)
    (display (leveldb-writebatch-t-pointer db) port)
    (display ">" port)))

(define (call-with-errptr proc)
  (let-location ((err* (c-pointer c-string)))
    ;; workaround for type check warning
    ((foreign-lambda* void (((c-pointer (c-pointer c-string)) err))
                      "*err = 0;") (location err*))
    (let ((result (proc (location err*))))
      (if err*
          ;;                               ,-- copy error message & free
          (let* ((err ((foreign-lambda* c-string (((c-pointer c-string) err)) "return(err);") err*))
                 (_   (free err*)))
            (abort
             (make-composite-condition
              (make-property-condition 'exn 'message err)
              (make-property-condition 'leveldb))))
          result))))

(define (leveldb-close db)
  ;; (print "» leveldb-close " db)
  (when (leveldb-t-pointer db)
    ((foreign-lambda void "leveldb_close" leveldb) db)
    (leveldb-t-pointer-set! db #f)))

(define (leveldb-open name #!key
                      (create-if-missing #t)
                      (error-if-exists #f)
                      (paranoid-checks #f)
                      (write-buffer-size (* 4 1024 1024))
                      (max-open-files 1000)
                      (block-size (* 4 1024))
                      (restart-interval 16)
                      (max-file-size (* 2 1024 1024))
                      (compression 'snappy)
                      (finalizer (lambda (db) (set-finalizer! db leveldb-close))))

  (define (compression->int compression)
    (cond ((eq? compression      #f) (foreign-value "leveldb_no_compression" int))
          ((eq? compression 'snappy) (foreign-value "leveldb_snappy_compression" int))
          (else (error "compression must be either 'snappy or #f" compression))))

  (let* ((open* (foreign-lambda* leveldb ((c-string name)
                                          (bool create_if_missing)
                                          (bool error_if_exists)
                                          (bool paranoid_checks)
                                          (size_t write_buffer_size)
                                          (int max_open_files)
                                          (size_t block_size)
                                          (int restart_interval)
                                          (size_t max_file_size)
                                          (int compression)
                                          ((c-pointer c-string) errptr))
                                 "
leveldb_options_t *op = leveldb_options_create();
// leveldb_options_set_comparator(op, leveldb_comparator_t*);
// leveldb_options_set_filter_policy(op, leveldb_filterpolicy_t*);
leveldb_options_set_create_if_missing(op, create_if_missing);
leveldb_options_set_error_if_exists(op, error_if_exists);
leveldb_options_set_paranoid_checks(op, paranoid_checks);
// leveldb_options_set_env(op,  leveldb_env_t*);
// leveldb_options_set_info_log(op, leveldb_logger_t*);
leveldb_options_set_write_buffer_size(op, write_buffer_size);
leveldb_options_set_max_open_files(op,  max_open_files);
// leveldb_options_set_cache(op, leveldb_cache_t*);
leveldb_options_set_block_size(op,  block_size);
leveldb_options_set_block_restart_interval(op,  restart_interval);
leveldb_options_set_max_file_size(op, max_file_size);
leveldb_options_set_compression(op, compression);

leveldb_t *db = leveldb_open(op, name, errptr);
leveldb_options_destroy(op);
return(db);
"))
         (db (call-with-errptr
              (cut open*
                   name
                   create-if-missing
                   error-if-exists
                   paranoid-checks
                   write-buffer-size
                   max-open-files
                   block-size
                   restart-interval
                   max-file-size
                   (compression->int compression)
                   <>))))
    (finalizer db)
    db))

(define (leveldb-get db key #!key
                     (verify-checksums #f)
                     (fill-cache #t))
  (let-location ((vallen size_t))
    (let* ((get (foreign-lambda* (c-pointer char)
                                 ((leveldb db)
                                  (scheme-pointer key)
                                  (size_t keylen)
                                  ((c-pointer size_t) vallen)
                                  (bool verify_checksums)
                                  (bool fill_cache)
                                  ((c-pointer c-string) errptr)) "
leveldb_readoptions_t *o = leveldb_readoptions_create();
leveldb_readoptions_set_verify_checksums(o, verify_checksums);
leveldb_readoptions_set_fill_cache(o, fill_cache);
// leveldb_readoptions_set_snapshot(o, snapshot);

char *val = leveldb_get(db, o, key, keylen, vallen, errptr);

leveldb_readoptions_destroy(o);
return(val);
"))
           (str* (call-with-errptr
                  (cut get
                       db key (number-of-bytes key)
                       (location vallen)
                       verify-checksums
                       fill-cache <>)))
           (str (and str* (make-string vallen))))
      (if str*
          (begin
            (move-memory! str* str vallen)
            (free str*)
            str)
          #f))))

(define (leveldb-put db key value #!key
                     (sync #f))
  (let* ((put* (foreign-lambda* void ((leveldb db)
                                      (scheme-pointer key)
                                      (size_t keylen)
                                      (scheme-pointer value)
                                      (size_t vallen)
                                      (bool sync)
                                      ((c-pointer c-string) errptr)) "
leveldb_writeoptions_t *o = leveldb_writeoptions_create();
leveldb_writeoptions_set_sync(o, sync);
leveldb_put(db, o, key, keylen, value, vallen, errptr);
leveldb_writeoptions_destroy(o);
")))
    (call-with-errptr
     (cut put*
          db
          key   (number-of-bytes key)
          value (number-of-bytes value)
          sync
          <>))))

(define (leveldb-delete db key #!key (sync #f))
  (let ((delete (foreign-lambda* void ((leveldb db)
                                       (scheme-pointer key)
                                       (size_t keylen)
                                       (bool sync)
                                       ((c-pointer c-string) errptr))
                                 "
leveldb_writeoptions_t *o = leveldb_writeoptions_create();
leveldb_writeoptions_set_sync(o, sync);
leveldb_delete(db, o, key, keylen, errptr);
leveldb_writeoptions_destroy(o);
")))
    (call-with-errptr (cut delete
                           db key (number-of-bytes key)
                           sync <>))))

(define (leveldb-iter-destroy it)
  (when (leveldb-iterator-t-pointer it)
    ((foreign-lambda void "leveldb_iter_destroy" leveldb-iterator) it)
    (leveldb-iterator-t-pointer-set! it #f)))

(define (leveldb-iterator db #!key
                          (finalizer (lambda (iter) (set-finalizer! iter leveldb-iter-destroy)))
                          (seek #f)
                          ;; ==================== options ====================
                          (verify-checksums #t)
                          (fill-cache #t)
                          ;; snapshot
                          )
  (let* ((iterator*
          (foreign-lambda* leveldb-iterator ((leveldb db)
                                             (bool verify_checksums)
                                             (bool fill_cache)
                                             ;;(leveldb_snapshot_t* snapshot())
                                             ((c-pointer c-string) errptr))
                           "
leveldb_readoptions_t *o = leveldb_readoptions_create();
leveldb_readoptions_set_verify_checksums(o, verify_checksums);
leveldb_readoptions_set_fill_cache(o, fill_cache);
// leveldb_readoptions_set_snapshot(o, snapshot);

leveldb_iterator_t *it = leveldb_create_iterator(db, o);

leveldb_readoptions_destroy(o);
return(it);
"))
         (it
          (call-with-errptr
           (cut iterator*
                db
                verify-checksums
                fill-cache
                ;; snapshot
                <>))))
    (finalizer it)
    (when seek (leveldb-iter-seek it seek))
    it))


(define leveldb-iter-valid?        (foreign-lambda bool "leveldb_iter_valid" leveldb-iterator))
(define leveldb-iter-seek-to-first (foreign-lambda void "leveldb_iter_seek_to_first" leveldb-iterator))
(define leveldb-iter-seek-to-last  (foreign-lambda void "leveldb_iter_seek_to_last" leveldb-iterator))
(define leveldb-iter-next*         (foreign-lambda void "leveldb_iter_next" leveldb-iterator))
(define leveldb-iter-prev*         (foreign-lambda void "leveldb_iter_prev" leveldb-iterator))
(define (leveldb-iter-seek* it key)
  ((foreign-lambda void "leveldb_iter_seek" leveldb-iterator scheme-pointer size_t)
   it key (number-of-bytes key)))

(define (leveldb-iter-seek it key)
  (cond ((string? key)       (leveldb-iter-seek* it key))
        ((blob? key)         (leveldb-iter-seek* it key))
        ((equal? key 'first) (leveldb-iter-seek-to-first it))
        ((equal? key 'last)  (leveldb-iter-seek-to-last it))
        (else (error "unknown seek value (expecting 'first/'last or string/blob), got: " key))))

(define (leveldb-iter-key* it)
  (let-location ((len size_t))
    (let ((str* ((foreign-lambda (c-pointer char) "leveldb_iter_key" leveldb-iterator (c-pointer size_t))
                 it (location len)))
          (str (make-string len)))
      (move-memory! str* str len)
      str)))

(define (leveldb-iter-value* it)
  (let-location ((len size_t))
    (let ((str* ((foreign-lambda (c-pointer char) "leveldb_iter_value" leveldb-iterator (c-pointer size_t))
                 it (location len)))
          (str (make-string len)))
      (move-memory! str* str len)
      str)))

;; safe variants of the above. you'll get segfaults when you do
;; leveldb-iter-key* when leveldb-iter-valid? is #f
(define (leveldb-iter-next it)
  (and (leveldb-iter-valid? it)
       (leveldb-iter-next* it)))

(define (leveldb-iter-prev it)
  (and (leveldb-iter-valid? it)
       (leveldb-iter-prev* it)))

(define (leveldb-iter-key it)
  (and (leveldb-iter-valid? it)
       (leveldb-iter-key* it)))

(define (leveldb-iter-value it)
  (and (leveldb-iter-valid? it)
       (leveldb-iter-value* it)))

;; TODO  leveldb_iter_get_error (const leveldb_iterator_t*,char** errptr)                   ;

;; TODO LEVELDB_EXPORT int leveldb_major_version(void);
;; TODO LEVELDB_EXPORT int leveldb_minor_version(void)
                                        ;
;; ==================== writebatch ====================

(define (leveldb-writebatch-destroy writebatch)
  (when (leveldb-writebatch-t-pointer writebatch)
    ((foreign-lambda void "leveldb_writebatch_destroy" leveldb-writebatch)
     writebatch)
    (leveldb-writebatch-t-pointer-set! writebatch #f)))

(define leveldb-writebatch-clear   (foreign-lambda void "leveldb_writebatch_clear" leveldb-writebatch))

(define (leveldb-writebatch #!key (finalizer leveldb-writebatch-destroy))
  (let ((wb ((foreign-lambda leveldb-writebatch "leveldb_writebatch_create"))))
    (when finalizer (set-finalizer! wb finalizer))
    wb))

(define (leveldb-writebatch-put writebatch key value) ;;                            key       keylen      value     vallen
  ((foreign-lambda void "leveldb_writebatch_put" leveldb-writebatch scheme-pointer size_t scheme-pointer size_t)
   writebatch
   key   (number-of-bytes key)
   value (number-of-bytes value)))

(define (leveldb-writebatch-delete writebatch key)
  ((foreign-lambda void "leveldb_writebatch_delete"
                   leveldb-writebatch scheme-pointer size_t)
   writebatch key (number-of-bytes key)))

(define (leveldb-write db writebatch #!key
                       (sync #f))
  (let* ((write* (foreign-lambda* void ((leveldb db)
                                        (leveldb-writebatch writebatch)
                                        (bool sync)
                                        ((c-pointer c-string) errptr)) "
leveldb_writeoptions_t *o = leveldb_writeoptions_create();
leveldb_writeoptions_set_sync(o, sync);
leveldb_write(db, o, writebatch, errptr);
leveldb_writeoptions_destroy(o);
")))
    (call-with-errptr
     (cut write* db writebatch sync <>))))

;; ==================== compaction_range ====================

(define (leveldb-compact-range db start limit)
   ((foreign-lambda* void ((leveldb db)
                          (scheme-pointer start)
                          (size_t start_len)
                          (scheme-pointer limit)
                          (size_t limit_len))
                     "
leveldb_compact_range(db, start, start_len, limit, limit_len);
")
   db
   start (if start (number-of-bytes start) 0)
   limit (if limit (number-of-bytes limit) 0)))
