fio-tests
=========

About
-----

fio-tests is a framework to allow you to easily build and run tests dynamically.
It allows you to configure a DUT, pre-condition for steady-state, maintain
profiles, build and run tests, and graphs them by just using make targets.

fio is very flexible, but writing configuration files can often be an error
prone process. When you design a test you may also decide that you'd like
to tests different read/write target profiles, using different parameters.
Editing fio files to account for different profiles can also be error prone.

fio-tests aims towards helping with these complexities by letting you
configure a DUT using a variability modeling language (kconfig), and
using a set of basic core templates which are used to generate target
tests.

With this model we are able to generate hundreds of tests using only
4 basic core template input files for fio as base.

fio-tests scope
---------------

fio-tests can be configured to either run specially crafted tests or to
provision a DUT. As such fio-tests' scope is to both house different specially
crafted fio tests and provisioning solutions with fio.

Refer to the [Provisioning](./Provisioning.md) for more information on how to
use fio-tests for provisioning.

A typical full run
------------------

Below is what you typically would do to use fio-tests for a full run test and
generating graphs:

```
make menuconfig
make -j$(nproc --all)

make check # optional

make run

make ssv -j$(nproc --all)
make graph

find ./ -name \*.svg
```

A demo run
----------

The demo untars a collection or a previously run set of all tests and
lets you toy with the output. We'll update the demo tarball as we add
new features or tests.

If you just want to demo what we have:

```
make allyesconfig
make -j 8
make demo
make ssv -j 8
make graph
```

Go and look at the svg files generated. Or if you are lazy just look the
example demo graph generated below.

Steady state
------------

Steady state is a state where performance is considered stable, and there
are mechanisms to ensure a storage device attains steady state for a series
of criteria prior to testing. For more details about this please read the
[provisioning documentation](Provisioning.md).

Make targets
------------

In this section we document each of the make targets in more detail.

# Test configuration - make menuconfig

First you want to configure the test. This will let you tune certain parameters
for the test:

```
make menuconfig
```

You'll be able to configure:

  * SNIA interpretation tests
  * Generic steady state provisioning
  * Device Under Test configuration
  * Performance evaluation
  * Debugging

Note that some tests targets are only available if you enable certain advanced
DUT configuration options.

# Generate fio ini files - default make and make ini

After configuration you would generate the fio ini files with:

```
make -j$(nproc --all)
```

This is equivalent to:

```
make -j$(getconf _NPROCESSORS_ONLN)
```

You can also be more specific, this is functionally equivalent:

```
make ini -j$(nproc --all)
```

You should now see fio ini files generated:

```
find ./ -name \*.ini
```

# Defconfig collections

There are a series of default configurations already ready to be used.
Other than the typical `allyesconfig`, `allnoconfig` as found in the
Linux kernel (see make help for all supported ones), we support a series
of default configurations. These are configurations stored in the directory
defconfigs/. If you add a default configuration there, `make help` will
automatically display it as an option.

For instance this will use /dev/nvme2n1 and enable all options:

```
make defconfig-nvme2n1-all
```

# Checking if fio files make sense - make check

If you are adding new tests or using a custom configuration you may first
want to check that all files make sense and parse correctly. You can do this
with:

```
make check
```

# Run fio tests - make run

To run all tests you have enabled:

```
make run
```
Sit back and wait for a good while. This may take *days*.

# Tracking progress - logs

Monitoring standard output of a `make run` can be cumbersome and not easy for
machines to follow. For this reason atomic test operations are tracked on
fio-tests on the logs directory. This section documents that directory.

Each file implements its own tracking solution, but all files use a common
theme for splitting data:

```
Action description|$CONFIG_DUT_FILENAME|epoc time|other details
```

The `Action description` describes what is being logged. It will be terse
but human readable. The `$CONFIG_DUT_FILENAME` is always in the second column.
The seconds since epoch time will always be on the third column. Subsequent
columns are action dependent, there may be none or more.

## logs/runs/${DEVNAME}

If CONFIG_DUT_FILENAME="/dev/nvme0n1" then ${DEVNAME} is nvme0n1, this file
tracks the progress of scripts/run-all-fio.sh.

## logs/runs/START

Start time since epoch of a full `make run`.

## logs/runs/END

Finished time since epoch of a full `make run`. This file's precense indicates
the full run has completed. Scripts can monitor for this file to detect if
we are done.

## logs/energized/${DEVNAME}

Tracks the energized steady state start / end time.

## logs/skip-precon/${DEVNAME}

Tracks if preconditioning was skipped. This file should only exist if it was
determined that preconditioning could be skipped.

## logs/purge/${DEVNAME}

Tracks all purge events for the device. Note that a purge may be issued
multiple times for a full set of tests.

XXX: track reason for purge

## logs/snia/

Each directory here tracks one specialized SNIA test.

## logs/snia/iops/${DEVNAME}

Tracks progress of the SNIA IOPS test. This file tracks the purge request, and
the start / end of the full set of rounds of tests.

## Data format collected

Currently fio terse output version 3 is used for the results **if** a test is
not attrying to achieve steady state. If a test aims to achieve steady state,
data is collected in json format and contains data for each second. As such
the json format output files can be much larger. Steady state test files only
collect data for a limited period of time, however. When data is collected
in fio terse output version 3 format we only collect the average data set
for a full run, so one line entry, nothing more.

Collecting more data for non steady-state  tests is possible however if one is
introspecting a specific test, it would make more sense to use a proper client
to allow us to collect *periodic data*, as fio terse output only collects
*average* performance data, not per period results. For more details on this
refer to [an architectural review of graphing with
fio](https://gitlab.com/mcgrof/graphing-with-fio). Using fio's gfio then is
recommended to be used against a target host to visualize specific ongoing
performance data if one is debugging performance for a specific tests. This
is outside the scope of fio-tests.

We only collect one line of output for non steady-state tests purposely
to reduce the size of the amount of data collected considerably.

## Future data format collection

Since a variability modeling language is used (kconfig), it should be relatively
easy to allow configuration of the output preferred and to collect a different
output format instead.

For instance, to collect *per period* results, fio's log file data is much more
appropriate, and allows one to specify the average values logged over a
specified period of time, with `log_avg_msec`.

It doesn't make sense to yet support this unless per period data is required.

# Using fio-tests for storage provisioning

Refer to the [Provisioning](./Provisioning.md) documentation.

# Debugging

Running all the tests can take a long time. The debugging menu lets you enable
a set of options so that you reduce all the defaults to minimal values so you
can quickly tests run time of the entire framework. Currently enable all of
the debugging options alone suffices to force the test time to be reduced as
much as possiblel.

Reducing default test time as much as possible may be useful if you are working
on expanding on tests and just want to see if the run at least will kick off,
and what the output may look like.

# Dry run

You may opt to simply *not* run any tests and pretend you will, you can do that
with:

```
make dryrun
```

# Generating space separated values - make ssv

To generate ssv files:

```
make ssv
```

Once your tests are done you want to gather them into some more meaninful
form. It turns out that to graph what we want we actually want to expand on
the data provided by fio, as it is not enough. For instance we want to actually
convey certain tests paramters / tunables, such as the number jobs / threads,
and the iodepth value. This information is *not* conveyed currently by fio
terse output.

We use gnuplot currenlty for graphing. It requires as input data with values
separated by spaces and with no top column description. We scrape only what
we need from the resulting files (.res) files and amend it with inferred data
about the test configuration. This inference is done by extracting it from
the fio test file name.

# Generating graphs - make graph

To generate graphs:

```
make graph
```

We already have fio's `fio_generate_plots` to generate graphs from output
log files. Generating realtime visualization is possible with fio's gfio.
We have different goals though. We want to graph performance results over
a range of paramters, and inclusive of tunables in fio, which typically fio
does not provide on output data.

Often one does not want to just get an idea for what performance may be like
only under certain situations, but rather a spectrum of situations or under a
different parameters. For instance, you may realize that you are not yet sure
how many jobs / pthreads threads your application may need yet to accomplish
certain throughput. You may be in this position if for instance you are not yet
sure if an application may end up being being low on CPU resources on a system
or not. Or perhaps you want to know ahead of time under what type of conditions
might you get the best IOPS. Other times you may want to just want to aim for
great latency, and you wonder under what circumnstances could you accomplish
this and you want to know what your constraints are. The answer to these
questions may vary. To answer these questions we need to run *one* test
against a spectrum of configurations. The initial graphs generated by this
project then, provide visualization of performance through a *range* of a
application tunable parameters. This approach is aimed at allowing system
engineers to get a better idea of what type of tuning parameters they may need
to reach certain performance objectives.

## Graph files supported - svg

Currently only svg files are generated. However adding support to output files
in other formats should be relatively simple task with our variability modeling
language (kconfig).

## Demo graphs - Using the 70 % read / 30 % write profile

Below are example output graphs collected with the current framework for the
profile which aims at achieving 70% reads, 30 % writes for two test cases.

### 70/30 demo for 0003-maxiobatch-single-job test

As the Kconfig entry for 0003-maxiobatch-single-job will tell, you this test
uses a specific fio max batch submit, that is fio's iodepth_batch_submit value.
You configure via the `CONFIG_DUT_FOCUS_IODEPTH_BATCH_SUBMIT` kconfig entry.
There are other iodepth values configured which are relevant here, this test
used all of the following parameters for just *one* test:

```
[global]
name=4k  MIX 70% read / 30% write with iodepth 1 and 1 thread
threads=1
group_reporting=1
time_based
ioengine=libaio
direct=1
buffered=0
norandommap
refill_buffers

bs=4k
size=4G
iodepth=1
numjobs=1
filename=/dev/nvme0n1

iodepth_batch_submit=4096
iodepth_batch_complete_min=1
iodepth_batch_complete_max=4096

exitall_on_error
continue_on_error=none


[randrw]
rw=randrw
rwmixread=70
runtime=4m
```

The above fio test file represent *one* dot on the graph.

The iodepth_batch_complete_min and iodepth_batch_complete_max value are
configurable, with `CONFIG_DUT_IODEPTH_BATCH_COMPLETE_MIN` and
`CONFIG_DUT_IODEPTH_BATCH_COMPLETE_MAX` respectively.

The test uses only *one* thread, and we benchmark results for a series of
different IO depths, with the goal to see at which IO depth we get the best
performance, whatever it is that our priorities are.

#### Write bandwidth

For these example results, we can tell that at IO depth of 512 we've already
maximized the bandwidth. The labels around 512 IO depth tell us the bandwidth
obtained, but there is also a second label which tells us that is *also* where
the tests achieved the best IOPS. The best latency, however, was achieved
an IO depth of 4, and we know the compromise then would be to accept we'd get
only about ~47 MiB/s.

The graph also tells us that using IO depth beyond 512 yielded in worse
performance, so there is no point to use an IO depth greater than 512
with one job under these types of parameters. In fact the test might as well
have stopped collecting data after IO depth IO depth 1024 as we know that at
IO depth 1024 we already hit worse performance. A TODO item is to implement
a guard to understand when this happens, therefore saving us test time.

![Write bandwidth](images/20181019/0003-maxiobatch-single-job/0005-maxiobatch-randwrite-70-30-bww.svg)

#### Read bandwidth

This graph reveals that we achieved the best mean read bandwidth at IOPS 512 as
well. The best latency point however was at IO depth 1. This is different than
the above write reesults for this mixed profile. And at IO depth 1 the graph
tells us we achieved on average about 30 MiB/s.

![Write bandwidth](images/20181019/0003-maxiobatch-single-job/0005-maxiobatch-randwrite-70-30-bwr.svg)

#### IOPS write

This graphs tell us we also got the best IOPS at an IO depth of 512. It also
happens to be where we got the best bandwith, so that fact is highlighted with
a label. The best latency was achieved when we were at IO depth of 1, but we
must understand we only got about ~ 3k IOPS.

![IOPS write](images/20181019/0003-maxiobatch-single-job/0005-maxiobatch-randwrite-70-30-iopsw.svg)

#### IOPS read

Slightly better IOPS for read at IO depth of 1, and that makes sense as this is
a 70% read profile.

![IOPS read](images/20181019/0003-maxiobatch-single-job/0005-maxiobatch-randwrite-70-30-iopsr.svg)

#### Completion latency write

This graph tells us at what IO depth we achieved the best completion latency
for writes, but it also illustrates what the latency was when we also got hte
best bandwidth: 0.1720 ms at 512 IO depth, which also happns to be when we know
we achieved the best IOPS.

The graph also tells us there is an exponential negative effect between
increasing IO depth and latency. Keep in mind the X axis is always logarithmic
when the X axis measures IO depth.

![Completion latency write](images/20181019/0003-maxiobatch-single-job/0005-maxiobatch-randwrite-70-30-clatw.svg)

#### Completion latency read

Slightly similar results, with the only difference being that we achieved better
read completion latency with an IO depth of 1.

![Completion latency read](images/20181019/0003-maxiobatch-single-job/0005-maxiobatch-randwrite-70-30-clatr.svg)

### 70/30 demo for 0004-maxiobatch-jobs test

Since 0003-maxiobatch-single-job was focused on single threaded work, this
test is similar but enables multiple threads, using a range. It also does this
for a range of threads:

  * `CONFIG_DUT_NUMJOBS_MIN` up to
  * `CONFIG_DUT_NUMJOBS_MAX`

Each test multiplies the numbe of jobs by 2. Likewise we have a range of
IO depth we are interested in, and this is also specified with a min and max:

  * `CONFIG_DUT_TEST_MIN_FOCUS_IODEPTH`
  * `CONFIG_DUT_TEST_MAX_FOCUS_IODEPTH`

And likwise each new set of tests multiplies the number of IO depth by 2.

These test results use number of threads on the X axis.

Each thread is a pthread thread.

####  IO depth at 256

At IO depth of 256 we can see the results of fio against a range of number
of threads. Each plot represents *one* fio test average results. So for
instance this graph computed and plotted *one* dot on the graph for numjobs=1:

```
[global]
name=4k  MIX 70% read / 30% write with iodepth 256 and 1 thread
threads=1
group_reporting=1
time_based
ioengine=libaio
direct=1
buffered=0
norandommap
refill_buffers

bs=4k
size=4G
iodepth=256
numjobs=1
filename=/dev/nvme0n1

iodepth_batch_submit=4096
iodepth_batch_complete_min=4096
iodepth_batch_complete_max=4096

exitall_on_error
continue_on_error=none


[randrw]
rw=randrw
rwmixread=70
runtime=4m
```

The graph below tell us that after about 8 threads we don't really achieve
much better bandwidth. This can be a useful determination. It also gives us
an idea of how much bandwidth is accomplished with fewer threads.

Although the write best bandwidth was definitely achieved at ~64 threads, it
wasn't that significant over the results when using abou ~8 threads.

![Write bandwidth](images/20181019/0004-maxiobatch-randread/0001-256qd-randrw-bww.svg)

Similarly at about ~8 threads we are already maximizing bandwidth.
When we achieved best latency, we know our bandwidth was 333 MiB/s.
If we are fine with that compromise and prefer better latency, using 1
thread would be sufficient.

![Read bandwidth](images/20181019/0004-maxiobatch-randread/0001-256qd-randrw-bwr.svg)
![IOPS write](images/20181019/0004-maxiobatch-randread/0001-256qd-randrw-iopsw.svg)
![IOPS read](images/20181019/0004-maxiobatch-randread/0001-256qd-randrw-iopsr.svg)

The graph below reveals we have a linear relationship between number of threads
and achieved completion latency for IO depth of 256.

![Completion latency write](images/20181019/0004-maxiobatch-randread/0001-256qd-randrw-clatw.svg)

The linear relationship applies to reads as well for this profile.

![Completion latency read](images/20181019/0004-maxiobatch-randread/0001-256qd-randrw-clatr.svg)

####  IO depth at 512

At IO depth 512 we can see we achieve quite faster the best bandwidth for
writes as the best bandidth is much more on the left side on the X axis as
it was for IO depth 256. At just 16 threads we reached peak possible bandwidth
under this configuration. But we know that about 8 threads we achieved just
about the same bandwidth as well.

The best latency was achieved at 1 threads, and if we can live with 204 MiB/s
we can live with a single threadead application under these parameters.

![Write bandwidth](images/20181019/0004-maxiobatch-randread/0002-512qd-randrw-bww.svg)
![Read bandwidth](images/20181019/0004-maxiobatch-randread/0002-512qd-randrw-bwr.svg)
![IOPS write](images/20181019/0004-maxiobatch-randread/0002-512qd-randrw-iopsw.svg)
![IOPS read](images/20181019/0004-maxiobatch-randread/0002-512qd-randrw-iopsr.svg)

The linear relationship maintains.

![Completion latency write](images/20181019/0004-maxiobatch-randread/0002-512qd-randrw-clatw.svg)
![Completion latency read](images/20181019/0004-maxiobatch-randread/0002-512qd-randrw-clatr.svg)

####  IO depth at 1024

At 1024 IO depth we see we now achieve peak bandwidth with half the number of
threads than as we did with an IO depth of 512. Only 8 threads are required, and
we achieve a max write bandwidth of 529 MiB/s for this profile.

![Write bandwidth](images/20181019/0004-maxiobatch-randread/0003-1024qd-randrw-bww.svg)

Likewise for read, but we achieve 1235 MiB/s. If working with a single threaded
appliacation we'd get the best latency, and achieve about ~519 MiB/s.

![Read bandwidth](images/20181019/0004-maxiobatch-randread/0003-1024qd-randrw-bwr.svg)
![IOPS write](images/20181019/0004-maxiobatch-randread/0003-1024qd-randrw-iopsw.svg)
![IOPS read](images/20181019/0004-maxiobatch-randread/0003-1024qd-randrw-iopsr.svg)

The linear relationship is broken at IO depth 1024.

At 8 threads we can see we get about 15.4151 ms for writes, which is where we
achieved both the best bandwidth for reads/writes and best IOPS for both.

![Completion latency write](images/20181019/0004-maxiobatch-randread/0003-1024qd-randrw-clatw.svg)
![Completion latency read](images/20181019/0004-maxiobatch-randread/0003-1024qd-randrw-clatr.svg)

####  IO depth at 2048

Perhaps unexpectedly, at IO depth of 2048 the best bandwidth requires a bit
more threads. We need now 32 threads, and our bandwidth actually got slightly
worse. At IO depth of 1024 we were able to achieve 529 MiB/s write bandwidth,
and this graphs tells us that IO depth 2048 we achieve 526 MiB/s... using
*twice* the amount of threads!

![Write bandwidth](images/20181019/0004-maxiobatch-randread/0004-2048qd-randrw-bww.svg)
![Read bandwidth](images/20181019/0004-maxiobatch-randread/0004-2048qd-randrw-bwr.svg)
![IOPS write](images/20181019/0004-maxiobatch-randread/0004-2048qd-randrw-iopsw.svg)
![IOPS read](images/20181019/0004-maxiobatch-randread/0004-2048qd-randrw-iopsr.svg)

Latency is at 80.3949 ms using an IO depth of 2048. Tha tis pretty terrible
considering at IO depth of 1024 we got better write bandwidth and latency
was about 5 times less.

![Completion latency write](images/20181019/0004-maxiobatch-randread/0004-2048qd-randrw-clatw.svg)
![Completion latency read](images/20181019/0004-maxiobatch-randread/0004-2048qd-randrw-clatr.svg)

####  IO depth at 4096

523 MiB/s for writes.. Things just get worse and worse after 1024 IO depth.

![Write bandwidth](images/20181019/0004-maxiobatch-randread/0005-4096qd-randrw-bww.svg)
![Read bandwidth](images/20181019/0004-maxiobatch-randread/0005-4096qd-randrw-bwr.svg)
![IOPS write](images/20181019/0004-maxiobatch-randread/0005-4096qd-randrw-iopsw.svg)
![IOPS read](images/20181019/0004-maxiobatch-randread/0005-4096qd-randrw-iopsr.svg)
![Completion latency write](images/20181019/0004-maxiobatch-randread/0005-4096qd-randrw-clatw.svg)
![Completion latency read](images/20181019/0004-maxiobatch-randread/0005-4096qd-randrw-clatr.svg)

License
-------

GPLv2, refer to the [LICENSE](./LICENSE) file for details. Please stick
to SPDX annotations for file license annotations.

TODO
----

Read the [TODO](./TODO) file.

Submitting patches
------------------

We embrace the Developer Certificate of Origin (DCO), read [CONTRIBUTING](./CONTRIBUTING)
prior to submitting patches.

Send patches to:

```
mcgrof@kernel.org
```
