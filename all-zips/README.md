
# Collecting TEKs.

TEKs are the keys distributed by the Google/Apple Exposure
Notification system for apps that aim to help with COVID-19
contact tracing.

[``tek_survey.sh``](./tek_survey.sh) is a script that we run as
a cronjob every 6 hours to collect the TEKs being published for
the Swiss, Italian and German apps. We'd hope to improve how
that's done and extend the set as time goes on.

We also collect configuration information for those apps that
helps understand how public health authorities may try to 
vary the sensitivity of proximity detection.

