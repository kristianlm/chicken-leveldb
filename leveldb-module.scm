(module leveldb (leveldb-open leveldb-close

                              leveldb-t           leveldb-t?

                              leveldb-get leveldb-put leveldb-delete

                              leveldb-iterator-t  leveldb-iterator-t?
                              leveldb-iterator
                              leveldb-iter-valid?
                              leveldb-iter-seek
                              leveldb-iter-next             leveldb-iter-prev
                              leveldb-iter-key              leveldb-iter-value
                              leveldb-iter-destroy

                              leveldb-writebatch-t?
                              leveldb-writebatch
                              leveldb-writebatch-put
                              leveldb-writebatch-delete
                              leveldb-writebatch-clear
                              leveldb-writebatch-destroy
                              leveldb-write

                              leveldb-compact-range

                              ;; ========== unofficial, in case I've got all this wrong:
                              leveldb-iter-next*            leveldb-iter-prev*
                              leveldb-iter-key*             leveldb-iter-value*
                              leveldb-iter-seek*)
(import scheme chicken.base)
(include "leveldb.scm")
)
