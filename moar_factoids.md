
This is just some notes that might help later.

When we see 1448 - the 144 means a day (144 x 10 mins)
and I guess the 8 is a risk level.

According to those can be: https://github.com/xamarin/ExposureNotification.Sample/blob/main/Functions/Proto/TemporaryExposureKey.cs

public enum RiskLevel
	{
		Invalid = 0,
		Lowest = 1,
		Low = 2,
		MediumLow = 3,
		Medium = 4,
		MediumHigh = 5,
		High = 6,
		VeryHigh = 7,
		Highest = 8
	}

Also: the list of country codes being used seems to be these:
https://en.wikipedia.org/wiki/Mobile_country_code

List of countries/apps: https://www.xda-developers.com/google-apple-covid-19-contact-tracing-exposure-notifications-api-app-list-countries/

A mail wrt .de figures:
> have nice dashboards
> 
> this guy also has old keys (not sure you have them):
> https://github.com/janpf/ctt
> 
> 
> https://github.com/micb25/dka
> 
> this guy also explains how the Germans do it:
> https://github.com/mh-/diagnosis-keys/blob/master/doc/algorithm.md
> 
> Paul
