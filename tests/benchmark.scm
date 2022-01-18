;;; inserts a lot of tiny entries into benchmark.level as quickly as
;;; possible.
;;;
;;; csi -s tests/benchmark.scm | pv -l >/dev/null
;;;
;;; I'm getting ~500k/s, you? #:wal seems to have little effect, bug?
;;;
(import leveldb chicken.string)

(define db (leveldb-open "benchmark.ldb" max-file-size: (* 32 1024 1024)))
(define wb (leveldb-writebatch))

(define commit!
  (let ((count 0))
    (lambda (force?)
      (set! count (+ 1 count))
      (when (or force? (>= count 1000))
        (set! count 0)
        (leveldb-write db wb sync: #f)
        (leveldb-writebatch-clear wb)))))

(let loop ((n 10000000))
  (when (> n 0)
    (leveldb-writebatch-put wb (conc "k" n) (conc "v" n))
    (commit! #f)
    (print n)
    (loop (- n 1))))

(commit! #t)
