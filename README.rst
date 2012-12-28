========
 fssync
========

--------------------------------------------------
File system synchronization tool (1-way, over SSH)
--------------------------------------------------

:Author: Julien Muchembled <jm@jmuchemb.eu>
:Manual section: 1

SYNOPSIS
========

``fssync`` ``-d`` `db` ``-r`` `root` [`option`...] `host`

DESCRIPTION
===========

fssync is a 1-way file-synchronization tool that tracks inodes and maintains a
local database of files that are on the remote side, making it able to:

- handle efficiently a huge number of dirs/files
- detect renames/moves and hard-links

It aims at minimizing network traffic and synchronizing every detail of a file
system:

- all types of inode: file, dir, block/character/fifo, socket, symlink
- preserve hard links
- modification time, ownership/permission/ACL, extended attributes
- sparse files

Other features:

- it can be configured to exclude files from synchronization
- fssync can be interrupted and resumed at any time, making it tolerant to
  random failures (e.g. network error)
- algorithm to synchronize file content is designed to handle big files
  like VM images efficiently, by updating fixed-size modified blocks in-place

Main usage of fssync is to prevent data loss in case of hardware failure,
where RAID1 is not possible (e.g. in laptops).

USAGE
=====

Use ``fssync --help`` to get the complete list of options.

The most important thing to remember is that the local database must match
exactly what's on the destination host:

- Files that are copied on the destination host must not be modified.
  And nothing should be manually created inside destination directories.
  If you still want to access data on remote host, you should do it through
  a read-only bind mounts (requires Linux >= 2.6.26).
- You must have 1 database per destination, if you plan to have several copies
  of the same source directory.

Look at ``-c`` option if you wonder whether your database matches the
destination directory.

First run of fssync:

- The easiest way is to let fssync do everything. Specify a non-existing file
  path to ``-d`` option and a empty or non-existing destination directory
  (see ``-R`` option). fssync will automatically creates the database and copy
  all dirs/files to remote host.
- A faster way may be to do the initial copy by other means, like a raw copy of
  a partition. If you're absolutely sure the source and destination are exactly
  the same, you can initialize the database by specifying ``-`` as host.

An example of wrapper around fssync, with a filter, can be found at
`examples/fssync_home`

See also the `NONE cipher switching`_ patch if you don't need encryption and
you want to speed up your SSH connection.


HOW IT WORKS
============

fssync maintains a single SQLite table of all dirs/files that are on the remote
side. Each row matches a path, with its inode (on local side), other metadata
(on remote side) and a `checked` flag.

When running, fssync iterates recursively through all local dirs/files and for
each path that is not ignored (see ``-f`` option), it queries the DB to decide
what to do. If already `checked`, path is skipped immediately. When a path is
synchronized, it is marked as `checked`. At the end, all rows that are not
`checked` corresponds to paths that don't exist anymore. Once they are deleted
on the remote side, all `checked` flags are reset.

Failure tolerance
-----------------

In fact, fssync doesn't require that the database matches perfectly the
destination. It tolerates some differences in order to recover any interrupted
synchronization caused by a network failure, a file operation error, or anything
other than an operating system crash of the local host (or something similar
like a power failure).

In most cases, this is done by the remote host, which automatically create
(or overwrite) an inode of the expected type if necessary. The only exception
is that the remote will never delete a non-empty directory on its own.
For most complex cases, fssync journalizes the operation in the database:
in case of failure, fssync will be able to recover on next sync.

Race conditions
---------------

A race condition means that other processes on the local host are modifying
inodes that fssync is synchronizing. fssync handles any kind of race condition.
In fact, fssync has nothing to do for most cases.

When a race condition happens, fssync does not guarantee that the remote data
is in a consistent state. Each sync always fixes existing inconsistencies but
may introduces others, so fssync is not suitable for hot backuping of databases.


SIMILAR PROJECTS
================

The idea of maintaining a local database actually comes from csync2_.
I was about to adopt it when I realized that I really needed a tool that always
detects renames/moves of big files. That's why I see fssync as a partial rewrite
of csync2, with inode tracking and without bidirectional synchronization.
The local database really makes fssync & csync2 faster than the well-known
rsync_.

Another solution I considered to secure my laptop data was DRBD_ in
`disconnected/asynchronous mode`_.


SEE ALSO
========

``sqlite3``\ (1), ``ssh``\ (1)


BUGS/LIMITATIONS/TODO
=====================

1. For performance reasons, the SQLite database is never flushed to disk while
   fssync is running. Which means that if the operating system crashes, the DB
   might become corrupted, and even if it isn't, it may not reflect anymore the
   status of the remote host and later runs may fail (for example, fssync
   refuses to replace a non-empty folder it doesn't know by a non-folder).
   So in any case, it is adviced to rebuild the DB.

   If the DB is not corrupted and you don't want to rebuild it, you can try
   to update it by running fssync again as soon as possible, so that the same
   changes are replayed. fssync should be able to detect that all remote
   operations are already performed. See also ``-c`` option, with does some
   partial checking.

2. fssync should not trash the page cache by using ``posix_fadvise``\ (2).
   Unfortunately, Linux does not implement ``POSIX_FADV_NOREUSE`` yet (see
   https://lkml.org/lkml/2011/6/24/136 for more information).

3. fssync process on remote side might leave parent directories with wrong
   permissions or modification times if it is terminated during specific
   operation like recovery (at the very beginning), cleanup (at the end),
   rename (if a directory is moved). That is, all operations that need to
   temporarily alter a directory that is not being checked.
   "Wontfix" for now, because it is unlikely to happen and any solution would
   be quite heavy, for little benefit.

4. Add option not to delete files immediately. fssync can be easily modified
   to actually remove a file on the remote host after an arbitrary number of
   runs. This would add partial backup functionality and would also speed up
   the case of a file that is temporarily moved out of the tracked folders.


NOTES
=====

.. target-notes::

.. _NONE cipher switching: http://www.psc.edu/networking/projects/hpn-ssh/
.. _csync2: http://oss.linbit.com/csync2/
.. _rsync: http://rsync.samba.org/
.. _DRBD: http://www.drbd.org/
.. _disconnected/asynchronous mode:
   http://lists.linbit.com/pipermail/drbd-user/2009-January/011210.html
