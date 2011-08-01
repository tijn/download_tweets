Download Tweets
===============

A Ruby script to make a backup of your tweets in JSON format.


How to use
----------

From within the project directory run

    ./bin/download_tweets --user <your twitter name>  --directory <your tweet backup directory>

...and then it will run for a looooooong time because of twitter rate limiting.

If you start it later again it will only fetch tweets that are newer than the tweets it finds in your backup directory. The idea is that you can run this weekly, using the same parameters, to back up your latest tweets, with a cron-job.
