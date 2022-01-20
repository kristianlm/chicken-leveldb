
  [LevelDB]: https://github.com/google/leveldb "BLABLALevelDB"
  [CHICKEN Scheme]: http://call-cc.org "CHICKEN Scheme"
  [Keyword arguments]:#keyword-arguments

# [LevelDB] bindings for [CHICKEN Scheme] 5

This egg has been tested on [LevelDB] 1.23, but should probably work
on older versions too.

An aim of this project is to expose the [LevelDB] C API directly with
no dependencies except the native LevelDB library. Errors are raised
where the (hidden) `errptr` argument set to a string pointer on
return.

## Dependencies

No eggs, but the LevelDB shared library must be installed before
installing this egg.

## Source Code

Hosted [here](https://github.com/kristianlm/chicken-leveldb).

## API

    [procedure] (leveldb-version)

 Returns the native LevelDB library version as a list with two
 elements: `(major minor)`.

    [procedure] (leveldb-open name #!key (create-if-missing #t) (error-if-exists #f) (paranoid-checks #f) (write-buffer-size (* 4 1024 1024)) (max-open-files 1000) (block-size (* 4 1024)) (restart-interval 16) (max-file-size (* 2 1024 1024)) (compression 'snappy) finalizer)

Opens database at path `name`, returning a `leveldb-t` object. Use
this object as the `db` argument in procedures below. See [Keyword
arguments] for options.

    [procedure] (leveldb-close db)

Closes `db`. Calling this on a `db` which is already closed has no
effect. This does not normally need to be called explicitly as it is
the default finalizer specified in `leveldb-open`.

    [procedure] (leveldb-get db key #!key (verify-checksums #f) (fill-cache #t))

Lookup database entry `key` in `db`. `key` must be a string or a
chicken.blob. Returns a string. See [Keyword arguments] page for
options.

Note that if you want to scan for a large number of entries, you
should probably use an `leveldb-iterator`.

    [procedure] (leveldb-put db key value #!key (sync #f))

Inserts an entry into `db`. `key` and `value` must both be strings or
chicken.blobs. See [Keyword arguments] for the `sync` option.

Note that if you want to insert a large number of entries, using a
`leveldb-writebatch` may be faster.

    [procedure] (leveldb-delete db key #!key (sync #f))

Deletes a single entry in `db` on `key`. If the `key` entry does not
exist, this is a no-op. `key` must be a string or chicken.blob. See
[Keyword arguments] for usage of `sync`.

Note that if you want to delete a larger number of entries, it is
probably better to use a `leveldb-writebatch`.

### Iterators

    [procedure] (leveldb-iterator db #!key (finalizer ...) (seek #f) (verify-checksums #t) (fill-cache #t))

Create a `leveldb-iterator-t` instance which you can use to seek, and
read keys and values from `db`. It is very efficient at moving through
keys sequentially using `leveldb-iter-next`.

`seek`, if present and not `#f`, will be passed to a call to
`leveldb-iter-seek`. As with `leveldb-iter-seek`, you can specify
`'first` to initialize the iterator to the first entry, for example.

See [Keyword arguments] for the other options.

    [procedure] (leveldb-iter-valid? it)

Returns `#t` if `it` is in a valid position (where you can read keys
and move it back or forwards) and `#f` otherwise. A newly created
iterator starts before the first entry in the database where
`leveldb-iter-valid?`, `leveldb-iter-key` and `leveldb-iter-value`
will return `#f`.

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

### Writebatch

A `leveldb-writebatch-t` can be used to apply changes atomically. See
[write_batch.h](https://github.com/google/leveldb/blob/main/include/leveldb/write_batch.h)
for details.

    [procedure] (leveldb-writebatch #!key (finalizer leveldb-writebatch-destroy))

Create a new `leveldb-writebatch` object. A writebatch can hold
key-value pairs temporarily, for later to be atomically applied to a
database with `leveldb-write`.

    [procedure] (leveldb-writebatch-put wb key value)

Inserts an entry into `wb`. `key` and `value` must be strings or
chicken.blobs.

    [procedure] (leveldb-writebatch-delete writebatch key)

Mark `key` as deleted. This works like `leveldb-delete`. Note that if
you call `put` and `delete` for the same `key`, order is significant.

    [procedure] (leveldb-writebatch-clear wb)

Remove all entries in `wb` previously inserted by
`leveldb-writebatch-put`, making it available for re-use.

    [procedure] (leveldb-writebatch-destroy wb)

Free the `wb` object and its foreign memory. Calling it if `wb` is
already destroy has no effect. This does not normally need to be
called explicitly as it's the default finalizer specified in
`leveldb-writebatch`.

    [procedure] (leveldb-write db wb #!key (sync #f))

Write all the entries of `wb` into `db`, persisting them on disk. This
is an atomic operation. See [Keyword arguments] for the `sync` option.

### Compactions

    [procedure] (leveldb-compact-range db start limit)

Run a database compaction, hopefully reducing the consumed disk
space. `start` and `limit` are keys that specify the range of keys to
run the compaction for. Both may be `#f` to specify all keys in the
database.

### Keyword arguments

With the exception of the `finalizer` options, these options are
mostly a copy-paste from the [C
API](https://github.com/google/leveldb/blob/master/include/leveldb/options.h). They
apply to all procedures accepting them.

#### `(finalizer (lambda (x) (set-finalizer! x (some-destroy-proc x))))`

Procedures accepting a `finalizer` keyword argument allow manual
memory control. It is a procedure of 1 argument, the object
potentially needing a finalizer. The defaults call `set-finalizer!`
with the corresponding `leveldb-*-destroy` or `leveldb-*-close`
procedure. This does not normally need to be specified, but can
sometimes be used to tweak performance.

#### `(sync #f)`

If true, the write will be flushed from the operating system buffer
cache (by calling WritableFile::Sync()) before the write is considered
complete.  If this flag is true, writes will be slower.

If this flag is false, and the machine crashes, some recent writes may
be lost.  Note that if it is just the process that crashes (i.e., the
machine does not reboot), no writes will be lost even if sync==false.

In other words, a DB write with sync==false has similar crash
semantics as the "write()" system call.  A DB write with sync==true
has similar crash semantics to a "write()" system call followed by
"fsync()".

#### `(verify-checksums #f)`

If true, all data read from underlying storage will be verified
against corresponding checksums.

#### `(fill-cache #t)`

Should the data read for this iteration be cached in memory? Callers
may wish to set this field to false for bulk scans.

#### `(create-if-missing #t)`

If true, the database will be created if it is missing.

#### `(error-if-exists #f)`

If true, an error is raised if the database already exists.

#### `(paranoid-checks #f)`

If true, the implementation will do aggressive checking of the data it
is processing and will stop early if it detects any errors.  This may
have unforeseen ramifications: for example, a corruption of one DB
entry may cause a large number of entries to become unreadable or for
the entire DB to become unopenable.

#### `(write-buffer-size (* 4 1024 1024))`

Amount of data to build up in memory (backed by an unsorted log on
disk) before converting to a sorted on-disk file.

Larger values increase performance, especially during bulk loads.  Up
to two write buffers may be held in memory at the same time, so you
may wish to adjust this parameter to control memory usage.  Also, a
larger write buffer will result in a longer recovery time the next
time the database is opened.

#### `(max-open-files 1000)`

Number of open files that can be used by the DB.  You may need to
increase this if your database has a large working set (budget one
open file per 2MB of working set).

#### `(block-size (* 4 1024))`

Approximate size of user data packed per block.  Note that the block
size specified here corresponds to uncompressed data.  The actual size
of the unit read from disk may be smaller if compression is enabled.
This parameter can be changed dynamically.

#### `(restart-interval 16)`

Number of keys between restart points for delta encoding of keys.
This parameter can be changed dynamically.  Most clients should leave
this parameter alone.

#### `(max-file-size (* 2 1024 1024))`

Leveldb will write up to this amount of bytes to a file before
switching to a new one.

Most clients should leave this parameter alone.  However if your
filesystem is more efficient with larger files, you could consider
increasing the value.  The downside will be longer compactions and
hence longer latency/performance hiccups.  Another reason to increase
this parameter might be when you are initially populating a large
database.

#### `(compression 'snappy)`

Compression must be either `'snappy` (the default), or `#f`. `'snappy`
gives lightweight but fast compression. Typical speeds on an Intel(R)
Core(TM)2 2.4GHz:

- ~200-500MB/s compression
- ~400-800MB/s decompression

Note that these speeds are significantly faster than most persistent
storage speeds, and therefore it is typically never worth switching it
off. Even if the input data is incompressible, the `'snappy`
compression implementation will efficiently detect that and will
switch to uncompressed mode.

## Example

```scheme
(import leveldb)
(define db (leveldb-open "testing.ldb"))

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

## Background

There is a [leveldb egg for CHICKEN
4](https://wiki.call-cc.org/eggref/4/leveldb). This egg, however, is a
port of the CHICKEN 5 [rocksdb
egg](https://wiki.call-cc.org/eggref/5/rocksdb), replacing the CHICKEN
4 egg with the permission of the author. This egg remains closer to
the C API than the CHICKEN 4 egg.

Rocksdb is a fork of LevelDB by Facebook, which with almost identical
C APIs.

For CHICKEN 5, there is also the [lmdb
egg](https://wiki.call-cc.org/eggref/5/lmdb). My informal tests
indicate that lmdb is faster for smaller databases (< 100k entries),
whereas leveldb's performance is relatively stable across all database
sizes.

## TODO

- support snapshots
- add support for custom comparators (hard, probably needs callbacks)
