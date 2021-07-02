# Campsite Openings Notifier

This project is meant to scrape the rec.gov api for openings in select campgrounds between certain dates and email you to let you know whats open when it finds openings.

## Features

- Parses rec.gov API for multiple campsites
- Emails you if spots are found and for what dates.
- Won't email unless spots are open

## How to run

The script is written in [dart](https://dart.dev/) so you'll want to have dart installed if you want to test locally. It's also set up to be used in an AWS lambda function so if you want to run locally, just remove the event handlers meant for lambda.

If you want to work on this script locally and test it, I recommend getting dart installed and running a "pub get" to download all the dependencies. That said, to be run in lambda, AWS recommends compiling in a docker container so it matches the runtime of lambda functions. So if you want to install this in lambda and just want to change the settings, you should only need docker installed.

Once docker is installed and the to_email, from_email, and sendgrid_api_key is assigned as well as the other settings, we can compile for the runtime using the following commands in order. This will generate a lambda.zip file to be uploaded into your lambda function.

```
$ docker run -v $PWD:/app -w /app -it google/dart /bin/bash
$ pub get
$ dart2native main.dart -o bootstrap
$ exit
$ zip -j lambda.zip bootstrap
```

Once you have a lambda function configured, make sure to set the handler to "hello.ACE" and increse the maximum runtime. After uploading the lambda.zip, the function should work with any test event or Cloudwatch Event! Cloudwatch Events is how I set the schedule the function to go off every X minutes and is easy to configure.
# campground_search
