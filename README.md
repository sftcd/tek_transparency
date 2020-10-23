
# Collecting TEKs.

TEKs are the keys distributed by the Google/Apple Exposure
Notification system for apps that aim to help with COVID-19
contact tracing.

[``tek_survey.sh``](./tek_survey.sh) is a script that we run as
a cronjob every hour to collect the TEKs being published for
33 regions. We'd hope to improve how
that's done and extend the set as time goes on.

We also collect configuration information for those apps that
helps understand how public health authorities may try to 
vary the sensitivity of proximity detection.

This is part of the [Testing Apps for COVID-19 Tracing (TACT)](https://down.dsg.cs.tcd.ie/tact/)
project. We wrote up the October 2020 state of play with this 
[here](https://down.dsg.cs.tcd.ie/tact/survey10.pdf).

