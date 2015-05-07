
History
-------


4.0.9 (2015-05-06)
++++++++++++++++++

- send current line number of cursor in heartbeat


4.0.8 (2015-05-06)
++++++++++++++++++

- fix bug to prevent using undefined file path


4.0.7 (2015-05-05)
++++++++++++++++++

- correctly get current file in onDidSave event handler


4.0.6 (2015-05-01)
++++++++++++++++++

- fix syntax error


4.0.5 (2015-05-01)
++++++++++++++++++

- don't log time to COMMIT_EDITMSG files


4.0.4 (2015-04-23)
++++++++++++++++++

- verify SSL cert when downloading wakatime cli


4.0.3 (2015-04-23)
++++++++++++++++++

- don't verify SSL cert when downloading wakatime cli for corporate proxies


4.0.2 (2015-04-09)
++++++++++++++++++

- use new buffer events from current atom api


4.0.1 (2015-03-10)
++++++++++++++++++

- upgrade wakatime cli to v4.0.4
- new options for excluding and including directories
- use requests library instead of urllib2, so api SSL cert is verified


4.0.0 (2015-01-21)
++++++++++++++++++

- remove depreciated atom.workspaceView


3.0.2 (2015-01-07)
++++++++++++++++++

- pass api key to wakatime-cli, to fix issue #6


3.0.1 (2015-01-06)
++++++++++++++++++

- bug fix


3.0.0 (2015-01-06)
++++++++++++++++++

- use wakatime-cli python script to send heartbeats
- install python on Windows if not already available


2.2.2 (2015-01-06)
++++++++++++++++++

- prevent exception when opening non-text buffer window


2.2.0 (2015-01-05)
++++++++++++++++++

- use highlight.js v8.4.0 or greater because installing from github causing problems


2.1.0 (2015-01-02)
++++++++++++++++++

- install highlight.js from github repo to use latest dev version


2.0.1 (2014-11-08)
++++++++++++++++++

- wrap call to external highlight.js library in try catch block


2.0.0 (2014-09-16)
++++++++++++++++++

- remove jquery dependency
- speed up plugin load time by loading dependencies after plugin has loaded


1.1.1 (2014-09-07)
++++++++++++++++++

- shorten package description


1.1.0 (2014-09-06)
++++++++++++++++++

- improve installation instructions in readme file


1.0.0 (2014-09-06)
++++++++++++++++++

- Birth

