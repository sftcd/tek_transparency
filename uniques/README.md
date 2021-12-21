
# About this stuff...

These are notes for myself so that I can reproduce this analysis
later, when/if it might show up some more interesting results.
As of 2021-12-20, the bottom line seems to be that the set of 33.85 million
unique TEKs I've looked at so far seem reasonably "random" as one would
expect if good key generation was used.

Note that the raw TEK files and any of the files mentioned below
that are large (``teks.ah`` is 31GB) are not included in this repo.
I'm happy to make those available on request.

I ran ``../tek_uniques.sh`` on 2021-12-16.  That took a few hours.

The inputs are the set of keyfiles in ``data/all-zips``. For each of the
33 services we've been scanning since mid 2020, each hour, we download 
sets of current keyfiles.
For each keyfile if there's no other with that name in the ``all-zips``
directory, we archive a copy there. If there's another zip file with
the same name in ``all-zips``, and if the new file is larger than the
old, then we overwrite the old file with the new file in ``all-zips``.

The outputs of ``tek_uniques.sh`` are:

- ``tek_uniques.log`` is the log from running the script.
- ``teks.ah`` is the set of TEKs taken from all the zip files (in
  country name then file name order) - that contains 1,006,172,001 
  ASCII-hex TEKS with one per line and is 31GB.

Additionally:

- ``teks.ah.uni`` is the above after a ``sort | uniq`` - i.e. the
  de-duped sorted set of TEKs seen - that contains 33,854,269
  TEKs in the same format.
- ``teks.bin`` is the binary version of the above, produced using
    ``cat teks.ah.uni | xxd -r -p >teks.bin``
- ``teks.ah.uni.shuf`` is a randomised version of ``teks.ah.uni`` (made
  using the ``shuf`` command) as 
  the randomness tests below sometimes don't like sorted values
- ``teks1.bin`` is the binary version of the above

We calculate occurrence frequencies using:

            $ cat teks.ah | sort | uniq -c >teks.ah.counts
            $ cat teks.ah.counts | awk '{print $1}' | sort -n | uniq -c | awk '{print $2","$1}' >freqs.csv

And then we use libreoffice to get ``freqs.ods`` with this 
[plot of occurrence frequencies](tek-occurrence-count.png).
More analysis along those lines is probably better later as 
this isn't really realted to key bit randomness, but is more
related to how the GAEN services replicate the same TEKs and
inject fake TEKs..

We can't of course check that our set of 33.85M TEKS are "random"
but we can do some checks for non-randomness. 
Firstly, we can do some home-grown checks...

- [aeskeys.py](aeskeys.py) is a python script that plots sets of TEKs
  on a Hilbert curve to allow one to eyeball potentially 
  visible lacks of randomness, with the option to bin the
  points and generate a [heatmap](heatmap.png), and also with an option
  to replace the TEKs with new random data of the same form
  for visual comparison. No visible non-randomness was seen.

- [bitcounts.py](bitounts.py) counts the number of ones in each
  key and the number of occurrences of ones in each key bit 
  position. A normalised output for our TEKs is [here](bitcounts.png)
  and also has no indication of non-randomness.

We can also use some existing RNG output checkers.
Note that these tools
are really intended to check the output of an RNG, whereas we're
testing the outputs from many phones that have each only contributed
a few (14 or less) TEKs (plus the generation of "fake" TEKs that are 
added by various services totalling a few million).

- ``ent`` from [http://www.fourmilab.ch/random/](http://www.fourmilab.ch/random/)
  does 5 tests, with seemingly ok results (the chi-squared one might be 
  possibly borderline say some docs.):

            $ $HOME/code/ent/ent teks1.bin
            Entropy = 8.000000 bits per byte.

            Optimum compression would reduce the size
            of this 541668306 byte file by 0 percent.

            Chi square distribution for 541668306 samples is 285.64, and randomly
            would exceed this value 9.09 percent of the times.

            Arithmetic mean value of data bytes is 127.5039 (127.5 = random).
            Monte Carlo value for Pi is 3.141179820 (error 0.01 percent).
            Serial correlation coefficient is 0.000014 (totally uncorrelated = 0.0).

- rngtest (``sudo apt install rng-tools5``) is also seemingly relatively happy

            $ cat teks1.bin | rngtest 
            rngtest 5
            Copyright (c) 2004 by Henrique de Moraes Holschuh
            This is free software; see the source for copying conditions.  There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

            rngtest: starting FIPS tests...
            rngtest: entropy source drained
            rngtest: bits received from input: 4333346448
            rngtest: FIPS 140-2 successes: 216482
            rngtest: FIPS 140-2 failures: 185
            rngtest: FIPS 140-2(2001-10-10) Monobit: 26
            rngtest: FIPS 140-2(2001-10-10) Poker: 13
            rngtest: FIPS 140-2(2001-10-10) Runs: 80
            rngtest: FIPS 140-2(2001-10-10) Long run: 66
            rngtest: FIPS 140-2(2001-10-10) Continuous run: 3
            rngtest: input channel speed: (min=476.837; avg=14736.637; max=19073.486)Mibits/s
            rngtest: FIPS tests speed: (min=45.305; avg=183.029; max=200.774)Mibits/s
            rngtest: Program run time: 22872026 microseconds

- dieharder (``sudo apt install dieharder``) is less happy but apparently 
  really needs much more input (about 12GB I've read, whereas we have about
  0.5GB), but in any case:

            $ dieharder -a -g 201 -k 2 -Y 1 -f teks1.bin
			#=============================================================================#
			#            dieharder version 3.31.1 Copyright 2003 Robert G. Brown          #
			#=============================================================================#
			   rng_name    |           filename             |rands/second|
			 file_input_raw|                       teks1.bin|  3.75e+07  |
			#=============================================================================#
			        test_name   |ntup| tsamples |psamples|  p-value |Assessment
			#=============================================================================#
			   diehard_birthdays|   0|       100|     100|0.67914646|  PASSED  
			      diehard_operm5|   0|   1000000|     100|0.44096831|  PASSED  
			# The file file_input_raw was rewound 1 times
			  diehard_rank_32x32|   0|     40000|     100|0.34013333|  PASSED  
			# The file file_input_raw was rewound 2 times
			    diehard_rank_6x8|   0|    100000|     100|0.37508093|  PASSED  
			# The file file_input_raw was rewound 2 times
			   diehard_bitstream|   0|   2097152|     100|0.21794718|  PASSED  
			# The file file_input_raw was rewound 3 times
			        diehard_opso|   0|   2097152|     100|0.75971995|  PASSED  
			# The file file_input_raw was rewound 5 times
			        diehard_oqso|   0|   2097152|     100|0.95466292|  PASSED  
			# The file file_input_raw was rewound 5 times
			         diehard_dna|   0|   2097152|     100|0.25119245|  PASSED  
			# The file file_input_raw was rewound 5 times
			diehard_count_1s_str|   0|    256000|     100|0.07530178|  PASSED  
			# The file file_input_raw was rewound 6 times
			diehard_count_1s_byt|   0|    256000|     100|0.86015217|  PASSED  
			# The file file_input_raw was rewound 6 times
			 diehard_parking_lot|   0|     12000|     100|0.92463763|  PASSED  
			# The file file_input_raw was rewound 6 times
			    diehard_2dsphere|   2|      8000|     100|0.21637533|  PASSED  
			# The file file_input_raw was rewound 6 times
			    diehard_3dsphere|   3|      4000|     100|0.28536566|  PASSED  
			# The file file_input_raw was rewound 8 times
			     diehard_squeeze|   0|    100000|     100|0.17603844|  PASSED  
			# The file file_input_raw was rewound 8 times
			        diehard_sums|   0|       100|     100|0.00530951|  PASSED  
			# The file file_input_raw was rewound 8 times
			        diehard_runs|   0|    100000|     100|0.53853965|  PASSED  
			        diehard_runs|   0|    100000|     100|0.71624714|  PASSED  
			# The file file_input_raw was rewound 9 times
			       diehard_craps|   0|    200000|     100|0.65701008|  PASSED  
			       diehard_craps|   0|    200000|     100|0.91566175|  PASSED  
			# The file file_input_raw was rewound 24 times
			 marsaglia_tsang_gcd|   0|  10000000|     100|0.00002955|   WEAK   
			 marsaglia_tsang_gcd|   0|  10000000|     100|0.00000001|  FAILED  
			# The file file_input_raw was rewound 24 times
			         sts_monobit|   1|    100000|     100|0.55864399|  PASSED  
			# The file file_input_raw was rewound 24 times
			            sts_runs|   2|    100000|     100|0.42308882|  PASSED  
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 24 times
			# The file file_input_raw was rewound 25 times
			# The file file_input_raw was rewound 25 times
			# The file file_input_raw was rewound 25 times
			# The file file_input_raw was rewound 26 times
			# The file file_input_raw was rewound 27 times
			# The file file_input_raw was rewound 28 times
			# The file file_input_raw was rewound 29 times
			# The file file_input_raw was rewound 30 times
			# The file file_input_raw was rewound 31 times
			# The file file_input_raw was rewound 33 times
			# The file file_input_raw was rewound 34 times
			# The file file_input_raw was rewound 36 times
			# The file file_input_raw was rewound 36 times
			# The file file_input_raw was rewound 36 times
			# The file file_input_raw was rewound 37 times
			# The file file_input_raw was rewound 37 times
			# The file file_input_raw was rewound 37 times
			# The file file_input_raw was rewound 37 times
			# The file file_input_raw was rewound 38 times
			# The file file_input_raw was rewound 38 times
			# The file file_input_raw was rewound 39 times
			# The file file_input_raw was rewound 40 times
			# The file file_input_raw was rewound 42 times
			# The file file_input_raw was rewound 45 times
			# The file file_input_raw was rewound 49 times
			# The file file_input_raw was rewound 54 times
			# The file file_input_raw was rewound 59 times
			# The file file_input_raw was rewound 65 times
			# The file file_input_raw was rewound 71 times
			# The file file_input_raw was rewound 79 times
			# The file file_input_raw was rewound 87 times
			# The file file_input_raw was rewound 96 times
			# The file file_input_raw was rewound 105 times
			# The file file_input_raw was rewound 116 times
			# The file file_input_raw was rewound 127 times
			# The file file_input_raw was rewound 138 times
			# The file file_input_raw was rewound 151 times
			# The file file_input_raw was rewound 164 times
			# The file file_input_raw was rewound 178 times
			# The file file_input_raw was rewound 193 times
			# The file file_input_raw was rewound 209 times
			# The file file_input_raw was rewound 225 times
			# The file file_input_raw was rewound 242 times
			# The file file_input_raw was rewound 260 times
			# The file file_input_raw was rewound 278 times
			# The file file_input_raw was rewound 296 times
			# The file file_input_raw was rewound 316 times
			# The file file_input_raw was rewound 336 times
			# The file file_input_raw was rewound 356 times
			# The file file_input_raw was rewound 378 times
			# The file file_input_raw was rewound 400 times
			# The file file_input_raw was rewound 423 times
			# The file file_input_raw was rewound 446 times
			# The file file_input_raw was rewound 471 times
			# The file file_input_raw was rewound 471 times
			# The file file_input_raw was rewound 472 times
			# The file file_input_raw was rewound 472 times
			# The file file_input_raw was rewound 473 times
			Preparing to run test 207.  ntuple = 0
			# The file file_input_raw was rewound 473 times
			Preparing to run test 208.  ntuple = 0
			# The file file_input_raw was rewound 474 times
			Preparing to run test 209.  ntuple = 0


