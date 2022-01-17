
  [Leveldb]: http://leveldb.org "Leveldb"
  [CHICKEN Scheme]: http://call-cc.org "CHICKEN Scheme"

# [Leveldb] bindings for [CHICKEN Scheme] 5

Only a portion of the comprehensive Leveldb API is currently
exposed. However, the API covered by this egg should hopefully get
most projects started.

This egg has been tested on [Leveldb] 6.15 and 5.8.

An aim of this project is to expose the [Leveldb] API directly as much
as possible. Some exceptions include `leveldb_open_for_read_only`
being embedded in `leveldb-open`, `leveldb_iter_seek_to_first`/`last`
are available through `leveldb-iter-seek` with symbol arguments, and
naming conventions turning `leveldb_writebatch_create` into
`leveldb-writebatch`.

## Source Code

Hosted [here](https://github.com/kristianlm/chicken-leveldb).

## API

    [procedure] (leveldb-open name #!key read-only (compression 'lz4) (create-if-missing #t) paranoid-checks (finalizer leveldb-close)) => leveldb-t

Opens database at path `name`, returning a `leveldb-t` object. Setting
`read-only` to a non-false value, will call
`leveldb_open_for_read_only` instead of `leveldb_open`. This is useful
as multiple OS processes may open a database in read-only mode, but
only one may open for read-write.

`finalizer` can be specified here and in some other procedures
below. It can be set to `#f` to allow for manual memory management,
which can be faster in cases where there many objects are created. If
`finalizer` is `#f`, you must remember to call the associated
`close`/`destroy` procedure explicitly.

`compression` must be one of `(#f snappy zlib bz2 lz4 lz4hc xpress
zstd)`. Please see the [C
API](https://github.com/facebook/leveldb/blob/v6.15.5/include/leveldb/options.h#L354)
for the remaining arguments.

    [procedure] (leveldb-close db)

Closes `db`. Calling this on a `db` which is already closed has no
effect. This does not normally need to be called explicitly as it is
the default finalizer specified in `leveldb-open`.

    [procedure] (leveldb-put db key value #!key (sync #f) (wal #t))

Inserts an entry into `db`. `key` and `value` must both be strings or
chicken.blobs.

For the remainding keyword arguments, please see the original [C
documentation](https://github.com/facebook/leveldb/blob/v6.15.5/include/leveldb/options.h#L1434).

Note that if you want to insert a large number of entries, using a
`leveldb-writebatch` may be faster.

    [procedure] (leveldb-iterator db #!key seek verify-checksums fill-cache read-tier tailing readahead-size pin-data total-order-seek (finalizer leveldb-iter-destroy)) => leveldb-iterator-t

Create a `leveldb-iterator-t` instance which you can use to seek, and
read keys and values from `db`.

`seek`, if present and not `#f`, will be passed to a call to
`leveldb-iter-seek`. You can specify `'first` to initialize the
iterator to the first entry, for example.

The `finalizer` argument works as in `leveldb-open`, where you must
call `leveldb-iter-destroy` appropriately.

Plase see the `ReadOptions` in the [C API
documentation](https://github.com/facebook/leveldb/blob/v6.15.5/include/leveldb/options.h#L1253)
for the remaining arguments.

    [procedure] (leveldb-iter-valid? it)

Returns `#t` if `it` is in a valid position (where you can read keys
and move it back or forwards) and `#f` otherwise. A newly created
iterator starts before the first entry in the database where
`leveldb-iter-valid?` will return `#f`.

    [procedure] (leveldb-iter-seek it key)

Move `it` to the absolute position specified. If `key` is a string or
chicken.blob, the iterator will be placed on the first entry equal to
or after `key`. `key` may also be the symbols `first` and `last` to
seek to the start and the end of the database respectively.

    [procedure] (leveldb-iter-next it)
    [procedure] (leveldb-iter-prev it)

Move `it` forward or backward one entry. Calling this when `it` is
invalid has no effect.

    [procedure] (leveldb-iter-key it)
    [procedure] (leveldb-iter-value it)

Get the current `key` or `value` for `it` at its current position.
These procedures will return `#f` if `(leveldb-iter-valid? it)`
returns `#f`, or strings otherwise.

The current implementation copies the foreign memory into a CHICKEN
string may not be ideal for large values.

    [procedure] (leveldb-iter-destroy it)

Free the `leveldb_t` structure held by this record. Calling this on an
iterator that is already closed has no effect. It does normally not
need to be called as it's the default finalizer specified in
`leveldb-iterator`.

    [procedure] (leveldb-writebatch #!key (finalizer leveldb-writebatch-destroy)) => leveldb-writebatch-t

Create a new `leveldb-writebatch` object. A writebatch can hold
key-value pairs temporarily, for later to be written to a database
with `leveldb-write`.

    [procedure] (leveldb-writebatch-put wb key value)

Inserts an entry into `wb`. `key` and `value` must be strings or
chicken.blobs.

    [procedure] (leveldb-writebatch-clear wb)

Remove all entries in `wb` previously inserted by
`leveldb-writebatch-put`, making it available for re-use.

    [procedure] (leveldb-writebatch-destroy wb)

Free the `wb` object and its foreign memory. Calling it if `wb` is
already destroy has no effect. This does not normally need to be
called explicitly as it's the default finalizer specified in
`leveldb-writebatch`.

    [procedure] (leveldb-write db wb #!key (sync #f) (wal #t))

Write all the entries of `wb` into `db`, persisting them on disk. 

For the keyword arguments, please see the [C API
documentation](https://github.com/facebook/leveldb/blob/v6.15.5/include/leveldb/options.h#L1434).

    [procedure] (leveldb-compact-range db start limit #!key exclusive change-level (target-level 0))

Run a database compaction, hopefully reducing the consumed disk
space. `start` and `limit` are keys that specify the range of keys to
run the compaction for. Both may be `#f` to specify all keys in the
database.

Please see the original [C API
documentation](https://github.com/facebook/leveldb/blob/v6.15.5/include/leveldb/options.h#L1566)
for usages of the remainding keyword arguments.

## Example

```scheme
(import leveldb)
(define db (leveldb-open "testing.rocks"))

(leveldb-put db "key1" "value1")
(leveldb-put db "key2" "value2")

(define it (leveldb-iterator db seek: 'first))
(let loop ()
  (when (leveldb-iter-valid? it)
    (print (leveldb-iter-key it) "\t" (leveldb-iter-value it))
    (leveldb-iter-next it)
    (loop)))
```

Please see the [`tests`](./tests/) folder for more usage.

## TODO

- support snapshot in `leveldb-iterator`
- add the column family API
- add the backup API
- add the transaction API
- add the merge API (hard, probably needs callbacks)
- add support for custom comparators (hard, probably needs callbacks)
- add the sstfilewriter API
