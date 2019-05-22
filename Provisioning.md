Steady state
=============

It is highly advisable to ensure a storage device reaches steady state prior to
running any performance tests. This is achieved by performing purging and
pre-conditioning. The methods used for pre-conditioning can vary. SNIA provides
guidelines for this, their tests however are very specific. Even if one wishes
to run alternative tests to what SNIA recommends one must still ensure drives
attain steady state prior to collecting performance data. Since SNIA tests are
very specific fio-tests considers SNIA tests as specialized however you can use
them to pre-condition. fio-tests also provides a more generic method for
pre-conditioning as an alternative to pre-condition prior to running tests
collected in fio-tests.

Graphing for reaching steady-state to prove steady state was attained is
pending work. Refer to the [TODO](./TODO) file.

Quick provisioning HOWTO
========================

Below some quick guidelines to let you provision with the different mechanisms
supported. More details of each method and how we provision for steady state
below.

Provisioning with the Santa Clara method
----------------------------------------

We have two defconfigs to help you ramp up with the Santa Clara method,
depending on your target workload.

  * Sequential workloads
  * Random workloads

# Provisioning with Santa Clara method for sequential workloads

```
make mrproper
export DEV="/dev/nvme2n1"
make defconfig-prov_sc_seq
```

# Provisioning with Santa Clara method for random workloads

```
make mrproper
export DEV="/dev/nvme2n1"
make defconfig-prov_sc_random
```

# Streamlining provisioning - contrib/provision_all.sh

You ideally would want to provision drives and keep track of what workload
it was provisioned for. This will depend on the workload requirements
targetted for each drive. An infrastructure for procurement of drives
and provisioning is outside of the scope of fio-tests, however a sample
script is provided to easily provision *all* drives under different
workloads:

  * sequential
  * random
  * mixed

A respective defconfig is used for sequential or mixed, and if mixed is used
then we alternative between sequential and random in a round robbin fashion
per drive.

Sample usage, either of these options can be used:

```
sudo ./contrib/provision_all.sh -f -t nvme -m sc -w seq
sudo ./contrib/provision_all.sh -f -t nvme -m sc -w random
sudo ./contrib/provision_all.sh -f -t nvme -m sc -w mixed
```

With this sample script provisioning is run in parallel, so all drives are
provisioned at the same time. You can monitor progress on the respective
nvme drive directory, for instance:

```
tail -f provisioning/nvme1n1/log
```

Each instance has a master copy of the same repository, exported per nvme
drive. If you just want to track process of the full run only, and don't
care for the details:

```
tail -f provisioning/nvme1n1/logs/runs/nvme1n1
```

Using fio-tests for storage provisioning
========================================

In order to achieve consistent storage results for performance tests you need
to prepare certain storage devices. This begs the question of whether or not
you should be preparing storage devices then before allowing the drives to be
used in production, for provisioning. For cases where this makes sense,
fio-tests's steady state tests can be used for this purpose. You would then
configure fio-tests with a provisioning target configuration.

Using fio-tests for this purpose should be considered in **evaluation mode**
currently, since graphing is not yet completed to allow you to visualize
confirmation of reaching steady state, and since fio-tests's steady state tests
are still being evaluated on different storage devices. Likewise there are two
different methods to achieve steady state for a storage device with fio-tests:

  * fio-tests's interpreation of SNIA tests
  * Generic steady state provisioning

Initial work has been put to evaluate our interpretation of SNIA's method of
achieving steady state. The generic method has yet to be evaluated or tested.

Although visualization to prove one has reached steady state is not yet
completed, the standard output of running a SNIA test gives you a good
idea of the progress of attaining steady state.

We document the two different methods currently supported on fio-tests to
achieve steady state. Before that we document a bit of generic state state
terms.

Disclosure
----------

fio-tests provides an *interpretation* of what SNIA puts out in its guidelines
for performance tests. The interpretation should by no means be considered as
an authentic SNIA sponsored test, it is not. We try to interpret the test as
best as possible. That is it. The author is not affiliated with SNIA, nor is he
employed by any of its member / sponsor companies. SNIA doesn't sponsor or
endorse this effort in any way shape or form.

For this reason we purposely name our interpretation of SNIA target test
with something unique. To clearly annotate these are not SNIA tests, but
rather fio-tests's own interpretations.

Attaining steady state mechanisms
---------------------------------

Steady state detection is based on computations over measuring results over
a period of time, and ensuring certain criteria are met. The idea is that
certain performance metrics don't fluctuate that much over a period of time.

You can either log performance data and output it to a file, and compute
performance metrics yourself, or you can let fio figure out if steady-state is
achieved. We opt to use fio's steady state detection mechanism as this
simplifies our work.

You measure steady state for a specific measurable target purpose:

  * IOPS
  * Throughput
  * Latency

fio currently only supports steady state detection or IOPS and throughput.

There are also two different mechansisms to express your requirements for
your criteria for attaining steady in fio:

  * Mean limit
  * Slope

We document both below and go into how we use these to assess whether or not
a test has attained steady state. You would stop an fio test if the steady
state criteria is met for the duration of the time specified, `ss_dur`.

# Mean limit steady state detection

You can tell fio to stop the job if all individual metrics for a performance
metric measurements (IOPS or throughtpu) are within the specified limit of
the respective mean within the steady state target time.

For instance, `ss=iops:20%` means that all individual IOPS values must be
within 20% of the mean IOPS, and once that criteria is met for the duration
required, `ss_dur, the job can terminate. Steady state is considered to be
attained if and only if the steady state criteria was sustained for the
duration of the `ss_dur`.

# Slope steady state detection

You can ask fio to terminate a job when the least squares regression slope
of a measurable metric falls below a specific percentage of the mean measurable
performance metric.

For instance, `ss=iops_slope:10%` will terminate an fio job if 10% of  the
mean  IOPS falls below 10% of the mean IOPS for the duraton of the `ss_dur`
value.

# Using both criteria for determing steady state

You can daisy chain steady state criteria. We daisy chain both mean limit
and slope criteria per performance measurable metric.

fio-tests uses fio json+ output format to check to see if a test has attained
steady state. json+ output records per period performance data per second, and
as part of the results, it will record the steady state results of a job.

fio-tests uses two separate jobs which run in parallel for measuring
both criteria for steady-state. One for the mean limit, another for slope.

For instance, the test below is an interpretation of SNIA worload dependent
test which aims to determine if steady state is attained for IOPS for both mean
limit and slope criteria. The test will only be considered successful if *both*
criteria are met.

```
./tests/0005-snia/0001-iops/0007-randrw_5_95/0001-snia-wd-fio_ss-randrw_5_95-32qd-4j-bs1024k.ini
```

```
[global]
name=SNIA workload dependent pre-conditioning for iops - 1024k random mixed read write MIX 5% read / 95% write with iodepth 32 and 4 threads
threads=1
group_reporting=1
time_based
ioengine=libaio
direct=1
buffered=0
norandommap
refill_buffers

bs=1024k
iodepth=32
numjobs=4
filename=/dev/nvme0n1

exitall_on_error
continue_on_error=none

size=100%

rw=randrw

runtime=60s
[steady-state-iops-mean-limit]
ss=iops:20%
ss_dur=60s

[steady-state-iops-slope]
new_group
group_reporting
ss=iops_slope:10%
ss_dur=60s
```

An example respective json output, trimmed with a highlight on the
steady state observables follows.

```
./tests/0005-snia/0001-iops/0007-randrw_5_95/0001-snia-wd-fio_ss-randrw_5_95-32qd-4j-bs1024k.ini.json
```

```
{
  "fio version" : "fio-3.1",
  "timestamp" : 1544119376,
  "timestamp_ms" : 1544119376917,
  "time" : "Thu Dec  6 18:02:56 2018",
  "global options" : {
    "name" : "SNIA workload dependent pre-conditioning for iops - 1024k random mixed read write MIX 5% read / 95% write with iodepth 32 and 4 threads",
    "threads" : "1",
    "group_reporting" : "1",
    "ioengine" : "libaio",
    "direct" : "1",
    "buffered" : "0",
    "bs" : "1024k",
    "iodepth" : "32",
    "continue_on_error" : "none",
    "size" : "100%",
    "rw" : "randrw",
    "runtime" : "60s",
    "filename" : "/dev/nvme0n1"
  },
  "jobs" : [
    {
      "jobname" : "steady-state-iops-mean-limit",
	...
      "steadystate" : {
        "ss" : "iops:20.000000%",
        "duration" : 60,
        "attained" : 0,
        "criterion" : "39.368103%",
        "max_deviation" : 329.366667,
        "slope" : 0.000000,
        "data" : {
          "bw_mean" : 877821454,
          "iops_mean" : 836,
          "iops" : [
            684,
            829,
	    ...
    {
      "jobname" : "steady-state-iops-slope",
	...
      "steadystate" : {
        "ss" : "iops_slope:10.000000%",
        "duration" : 60,
        "attained" : 1,
        "criterion" : "0.231578%",
        "max_deviation" : 0.000000,
        "slope" : 1.905891,
        "data" : {
          "bw_mean" : 864406809,
          "iops_mean" : 823,
          "iops" : [
            678,
            830,
            676,
            987,
            792,
	...
```

On the above example we can determine that steady state was only attained for
the iops slope measurement job but not for the mean limit job. fio-tests
post-processes these files with a json interpreter, scripts/json2res. If this
script is passed the `--steady-state` argument it will try to look for the
steady state criteria and output results found as follows.

```
cat ./tests/0005-snia/0001-iops/0007-randrw_5_95/0001-snia-wd-fio_ss-randrw_5_95-32qd-4j-bs1024k.ini.ss
0,1
```

This means the first job was found to not have attained steady state, while the
second job did attain steady state. fio-tests will only assume a test attains
steady state if this file output is:

```
1,1
```

That would mean both steady state criteria are met.

As in the example above, the same is possible for throughpout, we'd measure
steady state for mean linit and slope.

fio-tests interpretation of SNIA tests
--------------------------------------

fio-tests uses artist names for each of our interpretation of SNIA tests to
make it clear these tests are not vetted by SNIA, but are simply
interpretations.

SNIA puts out a set of recommended tests and along with these tests
a series of precise pre-conditioning methods to use for each test.
The SNIA's Solid State Storage (SSS) Performance Tests Specification (PTS)
is intended to be used to obtain reliable and comparative measurement of NAND
Flash based solid state storage devices (SSDs). fio-tests supports allowing
developers to add different interpretations of PTS specifications and from each
PTS, each different possible test within it.

The first version we are working to provide interpretation for is the [SSS PTS
Version 2.0.1 specification](https://www.snia.org/sites/default/files/technical_work/PTS/SSS_PTS_2.0.1.pdf).
The author's (Luis Chamberlain) interpretation of the evolution of PTS 2.0.1 is
that it was fine tuned to addressed checking for steady-state at different base
sizes since it was found that certain FTLs were optimizing performance for
specific base sizes. Addressing coverage of tests using a full range of bases
sizes provides a more in depth assessment of when a drive truly reaches steady
state in a generic form.

SNIA tests are also very target specific. For instance, there is one SNIA
test for reaching steady state with a focus on you testing IOPS, given its
steady state criteria focus is on measuring steady state only for IOPS.

There is another SNIA test with a focus of testing throughput, and so on.
The fio-test's *interpreation* of SNIA tests are still under development. Only
one target test is currently interpreted:

  * The Buddy Holly tets - fio-tests iterpretation of SNIA IOPS test

# The Buddy Holly test - fio-tests's interpration of SNIA IOPS test

The Buddy Holly test is fio-test's interpretation of SNIA's IOPS test.

This tests is used to help you test for IOPS. We first purge the device.  Then
we prefill the drive twice, this is known as the workload indepenent test, as
per SNIA terms. By default we then proceed to a set of 56 workload dependent
tests, these are a battery of tests, each running for a minute each, with
different base sizes.  Steady state is checked for 1 minute for IOPS for both
its mean limit and slope. We only report success of attaining steady state
**iff** both we have attained steady state for IOPS for both its IOPS steady
state mean limit criteria and its IOPS steady state slope criteria.

Running all 56 tests where we check if steady-state is attained is considered
one round of tests. SSS PTS Version 2.0.1 indicates your test is only
successful if you manage to complete 5 full rounds of tests where steady state
is maintained for all tests, so `56*5 = 280` tests. By default then,
fio-tests's SNIA IOPS test then is considered only successful if you manage to
attain steady state for both IOPS mean limit and IOPS slope for 280 consecutive
tests.

By default also, only 25 rounds are allowed (`CONFIG_SNIA_IOPS_WD_ROUND_LIMIT`).
You can either increase this limit if you are observing your tests are not
achieving steady state in 25 rounds, or you can make that limit a soft limit
(`CONFIG_SNIA_IOPS_WD_ROUND_LIMIT_SOFT=y`), and have the test run **forever**
until 5 consecutive rounds are completed successfully. By default the limit is
made hard (`CONFIG_SNIA_IOPS_WD_ROUND_LIMIT_SOFT=n`), given that running this
test forever until succesful is considered *dangerous* since in theory steady
state *may never be attainable* for certain drives.

If and only if someone is monitoring the test daily should someone make the
limit a soft limit. Leaving this test run forever unattended will wear and tear
your drives.

The Santa Clara test - Generic steady state provisioning
--------------------------------------------------------

The Santa Clara test is an attempt to generalize the Buddy Holly test
and the future Elvis Presley test into a smaller, simpler, faster generic test.

SNIA tests are **very** target specific, and at least the [SSS PTS Version 2.0.1
specification](https://www.snia.org/sites/default/files/technical_work/PTS/SSS_PTS_2.0.1.pdf)
addresses ensuring you test across a different set of base sizes, and you attain
steady state across **all** of these different base sizes. If you know your
focus use is restricted to only a set of base sizes you have a few options. You
can either **modify** the defaults from the SNIA test and reduce the base sizes
(for example `CONFIG_SNIA_IOPS_WD_BS_STEP`) to only the set you interested in,
or you can use the Santa Clara test which focuses on only one base
size.

An advantage of the Santa Clara method is that steady state is tested for
both IOPS and throughput, while the Buddy Holly test only focuses on IOPS, and
the Elvis Presely test only focuses on throughput.

A clear intentional limit behind the Santa Clara test is only one base size is
used.

Similar to the Buddy Holly test, we first preflll the drive twice, and then
we proceed to run two separate fio tests. One test which seeks to attain steady
state for IOPS for both its mean limit, and slope criteria. Another test which
seeks to attain steady state for throughput for both its mean limit and slope
criteria. Contrary to the Buddy Holly test which runs 56 tests in a round to
attain steady state, one minute per test, the Santa Clara test runs each steady
state test for 15 minutes each by default.

You can run the Santa Clara test for either random writes, or for sequential
writes. fio-tests allows configuration of a series of other tests to get an
idea of what performance my be under certain criteria.  Each of the these tests
performs workloads under sequential, random, or mixed profiles.  fio-tests will
run the sequential steady state test prior to running all allowed sequential
tests. fio-tests will then run the random steady state test prior to running
all allowed random / mixed profile tests.

If the build configuration `CONFIG_PRECONDITION_STRICT_ORDER` is enabled it
will ensure that even if sequential tests are not enabled we will pre-condition
for sequential workloads prior to pre-conditioning for random workloads.
