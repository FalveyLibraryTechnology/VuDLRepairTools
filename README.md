# VuDL Repair Tools

## Background

In September, 2019, two thousand objects were accidentally purged from Villanova's
Digital Library. This repository contains the tools that were used to restore the
lost data using backups and existing Solr index entries.

## Prerequisite

This fix relies on the fact that ONLY the top-level ResourceCollection objects were
deleted, and all of their children remained in both Fedora and Solr. The child
objects made it possible to infer a lot of data and begin to rebuild. A more complete
purge would require a significantly different approach to repair.

## Usage

### 1. Identifying problem PIDs

When objects were discovered to be missing, the Fedora logs were searched for
references to the known-missing IDs. This revealed `delete` commands in the gsearch
logs. With a bit of grepping and file manipulation, a list of lost PIDs was
constructed and saved as bad-pids.txt for future reference.

### 2. Find titles of problem PIDs

The `getTitles.php` uses the Solr server configured in `config.php` to locate titles
of deleted items, creating a bad-pids-with-titles.csv output file that can be used
to create placeholder objects to begin restoring the missing PIDs. As of this
writing, there are some escaping issues that should be cleaned up when reading the
title data; these were adjusted by hand rather than fixing the code, and no time
has been taken to go back and improve this.

### 3. Create placeholder objects

The `fedora3_fixer.rb` file needs to be added to the `app/models` directory of the
VuDLPrep tool. Then, by using the Rails console, it is possible to run some commands
to ingest data back into the repository. The first action is to run:

`Fedora3Fixer.restore_titles_from_csv "/path/to/bad-pids-with-titles.csv"`

This will create stub objects from which other data can be hung.

### 4. Fix parents

The objects created by `restore_titles_from_csv` will have incorrect parent details.
The `getParents.php` script will generate a `parents.csv` file containing correct parent
details. Then, in the Rails console, running:

`Fedora3Fixer.restore_parents_from_csv "/path/to/parents.csv"`

will load the correct data into Fedora.

### 5. Restore thumbnails

Objects using non-default thumbnails will need the data restored by copying the
thumbnails from their first image children. The `getThumbs.php` will generate two
CSV files: `thumbs.csv`, containing affected PIDs and the associated child PIDs from
which to recover thumbnails, and `thumbs-missing.csv`, containing a list of PIDs for
which thumbnails could not be found (in case there is a desire to double-check them
manually). After running this script, use this Rails console command to load data:

`Fedora3Fixer.restore_thumbs_from_csv "/path/to/thumbs.csv"`

### 6. Restore inline datastreams

After recovering your object store from a backup and adjusting `config.php` so
that `OBJECT_STORE_PATH` points to the correct location, you can run `getObjects.php`
to copy the affected objects into an `objects` directory (which you should create
prior to running the script). You should then copy this directory to `/tmp/objects`
(or modify the `fedora3_fixer.rb` code to return a different value from the `self.xmldir`
method). Then, from the Rails console, run:

`Fedora3Fixer.restore_xml_from_pid_list "/path/to/bad-pids.txt"`

### 7. Restore stored datastreams

Some older objects have PROCESS-MD as a stored datastream rather than an inline
datastream, which means that the data is missing from the object XML and needs to
be loaded separately. The affected files can be identified by running this grep
command in the objects directory populated in step 6:

`grep +PROCESS-MD * | grep contentLocation > storedProcess.txt`

Now make sure that `DATASTREAM_STORE_PATH` is set correctly in `config.php`
(pointing to the datastream store recovered from your backup). You can now run
`getStoredProcessStreams.php` to copy the files containing datastream content
into a `process-md` directory (which you should create before running the script).
This directory will also contain a `pidlist.txt` file containing all impacted IDs.

Copy the `process-md` directory to `/tmp` (or adjust the `fedora3_fixer.rb` file's
`self.restore_processmd_from_file` method to point to a different path. Then go to
the Rails console and run:

`Fedora3Fixer.restore_processmd_from_pid_list "/tmp/process-md/pidlist.txt"`

### 8. Verify the result

It may take a significant amount of time for Solr indexing to catch up; when this is
done, ensure that objects are behaving as expected.