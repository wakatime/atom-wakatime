
History
-------


11.0.12 (2023-06-10)
++++++++++++++++++

- Support forks of Atom, for ex: Pulsar.


11.0.11 (2022-04-29)
++++++++++++++++++

- Remove deprecated HTMLDocument.registerElement usage.
  `#123 <https://github.com/wakatime/atom-wakatime/issues/123>`_
- Create symlink to wakatime-cli for consistency with other wakatime plugins.


11.0.10 (2022-03-14)
++++++++++++++++++

- Fix bug where wrong variable name used when creating resources folder.
  `#121 <https://github.com/wakatime/atom-wakatime/issues/121>`_


11.0.9 (2022-01-30)
++++++++++++++++++

- Use separate config file for internal settings.


11.0.8 (2021-12-18)
++++++++++++++++++

- Remove null chars when reading and writing ini cfg file.
  `jetbrains-wakatime#195 <https://github.com/wakatime/jetbrains-wakatime/issues/195>`_


11.0.7 (2021-12-17)
++++++++++++++++++

- Prevent using undefined response in logging.
  `#119 <https://github.com/wakatime/atom-wakatime/issues/119>`_


11.0.6 (2021-11-02)
++++++++++++++++++

- Fix reporting missing wakatime-cli platform support.
- Add platform support for Windows arm64.


11.0.5 (2021-08-14)
++++++++++++++++++

- Add optional chaining operator to http response.


11.0.4 (2021-05-20)
++++++++++++++++++

- Fix caching GitHub releases API requests with correct cfg key name.


11.0.3 (2021-05-20)
++++++++++++++++++

- Prevent deleting wakatime resources folder when downloading new wakatime-cli.
  `#106 <https://github.com/wakatime/atom-wakatime/issues/106>`_


11.0.2 (2021-05-18)
++++++++++++++++++

- Use plugin name in GitHub API User-Agent header, now that ETag not used.


11.0.1 (2021-05-18)
++++++++++++++++++

- GitHub ETag is not reliable, use Last-Modified-Since timestamp instead.


11.0.0 (2021-05-18)
++++++++++++++++++

- Use new Go wakatime-cli.


10.0.0 (2021-01-11)
++++++++++++++++++

- Decaffeinate CoffeeScript into JavaScript.
  `#104 <https://github.com/wakatime/atom-wakatime/issues/104>`_
- Download wakatime-cli async to prevent blocking main thread.
  `#103 <https://github.com/wakatime/atom-wakatime/issues/103>`_


9.0.4 (2021-01-10)
++++++++++++++++++

- Bugfix for Python version checking needs reading both stderr and stdout.
  `#101 <https://github.com/wakatime/atom-wakatime/issues/101>`_


9.0.2 (2020-02-25)
++++++++++++++++++

- Bugfix for getUserHome is not defined error.
  `#98 <https://github.com/wakatime/atom-wakatime/issues/98>`_


9.0.1 (2020-02-25)
++++++++++++++++++

- Respect $WAKATIME_HOME environment variable for config file location.
  `#94 <https://github.com/wakatime/atom-wakatime/issues/94>`_


9.0.0 (2020-02-23)
++++++++++++++++++

- Download wakatime-cli standalone as zipped folder for improved performance.


8.0.6 (2020-02-22)
++++++++++++++++++

- Fix detecting wakatime-cli install filename.


8.0.5 (2020-02-22)
++++++++++++++++++

- Fix attribute used as function.


8.0.4 (2020-02-22)
++++++++++++++++++

- Use process.platform instead of os.platform to detect operating system.
  `#96 <https://github.com/wakatime/atom-wakatime/issues/96>`_


8.0.3 (2020-02-22)
++++++++++++++++++

- Prevent sending heartbeats before wakatime-cli has finished downloading.
  `#96 <https://github.com/wakatime/atom-wakatime/issues/96>`_


8.0.2 (2020-02-22)
++++++++++++++++++

- Add uuid dependency to force latest version and prevent Buffer warning.


8.0.1 (2020-02-22)
++++++++++++++++++

- Fix filename conflict between wakatime-cli and wakatime.coffee.


8.0.0 (2020-02-22)
++++++++++++++++++

- Use standalone wakatime-cli dependency.


7.2.0 (2020-02-09)
++++++++++++++++++

- Detect python in Windows LocalAppData install locations.
- Upgrade embedded python to v3.8.1.


7.1.2 (2019-11-07)
++++++++++++++++++

- Allow python rc versions.
  `#91 <https://github.com/wakatime/atom-wakatime/issues/91>`_
  `#93 <https://github.com/wakatime/atom-wakatime/issues/93>`_


7.1.1 (2019-05-21)
++++++++++++++++++

- Fetch today coding time for status bar when Atom starts.


7.1.0 (2019-05-21)
++++++++++++++++++

- Show today coding time in status bar.


7.0.9 (2019-03-13)
++++++++++++++++++

- Add keywords to package for improved discoverability.


7.0.8 (2019-03-08)
++++++++++++++++++

- Prevent using old Anaconda python distributions because they parse arguments
  containing spaces incorrectly.


7.0.7 (2018-10-03)
++++++++++++++++++

- Improve retry error handling by re-raising original exception.


7.0.6 (2018-10-03)
++++++++++++++++++

- Retry executing wakatime-cli when sending heartbeats up to 5 times.
  `#85 <https://github.com/wakatime/atom-wakatime/issues/85>`_


7.0.5 (2018-08-30)
++++++++++++++++++

- Support for editing remote files.
  `#83 <https://github.com/wakatime/atom-wakatime/issues/83>`_
- Detect Python3 before Python2 on Windows OS.


7.0.4 (2017-11-10)
++++++++++++++++++

- Prefer Python 3 if available.
  `#77 <https://github.com/wakatime/atom-wakatime/issues/77>`_


7.0.3 (2017-05-18)
++++++++++++++++++

- Improve package settings placeholder for api key, when api key in
  ~/.wakatime.cfg is not valid.


7.0.2 (2017-05-05)
++++++++++++++++++

- Propagate disable ssl cert verification config to wakatime-cli.


7.0.1 (2017-05-05)
++++++++++++++++++

- Ability to disable SSL Cert Verification from Atom configs.
  `#73 <https://github.com/wakatime/atom-wakatime/issues/73>`_


7.0.0 (2017-04-25)
++++++++++++++++++

- Activate package in idle callback to improve startup time.
  `#35 <https://github.com/wakatime/atom-wakatime/issues/35>`_


6.0.14 (2017-04-17)
++++++++++++++++++

- Use local file for saving timestamp when last checked for updates to prevent
  modifying Atom's config.
  `#71 <https://github.com/wakatime/atom-wakatime/issues/71>`_


6.0.13 (2017-02-07)
++++++++++++++++++

- Pass config file location to wakatime-cli background process.
  `#65 <https://github.com/wakatime/atom-wakatime/issues/65>`_


6.0.12 (2016-12-26)
++++++++++++++++++

- Remove /var/www/ folder from default ignored folders.
  `#68 <https://github.com/wakatime/atom-wakatime/issues/68>`_


6.0.11 (2016-12-16)
++++++++++++++++++

- Log skipped files in debug mode.
  `#67 <https://github.com/wakatime/atom-wakatime/issues/67>`_
- Use python v3.5.2 on Windows.


6.0.10 (2016-06-30)
++++++++++++++++++

- Require version in output before accepting Python location as valid.
  `#64 <https://github.com/wakatime/atom-wakatime/issues/64>`_


6.0.9 (2016-06-15)
++++++++++++++++++

- Use SVG for status bar icon so icon color changes the inverse of current
  color Theme.
  `#61 <https://github.com/wakatime/atom-wakatime/issues/61>`_


6.0.8 (2016-06-09)
++++++++++++++++++

- Fix bug causing status bar icon to be displayed even when off in settings.
  `#65 <https://github.com/wakatime/atom-wakatime/issues/65>`_


6.0.7 (2016-06-09)
++++++++++++++++++

- Always check if Python and wakatime-cli installed, regardless of last time
  updates to wakatime-cli were checked.


6.0.6 (2016-06-09)
++++++++++++++++++

- Fix bug where wakatime-cli not installed if having to install Python first.
- No need to prompt before installing Python because using embedded version.
- Log the correct level in log messages.
- Use correct warn level name to fix warning log messages.
- Update npm dependencies rimraf to v2.5.2 and request to v2.72.0.


6.0.5 (2016-06-08)
++++++++++++++++++

- Always check for wakatime-cli updates when debug checked.
- Fix formatting when debugging wakatime-cli command arguments.


6.0.4 (2016-06-07)
++++++++++++++++++

- Prevent checking for wakatime-cli updates when offline.
- Only check for wakatime-cli updates once every 24 hours.
  `#37 <https://github.com/wakatime/atom-wakatime/issues/37>`_


6.0.3 (2016-06-07)
++++++++++++++++++

- Hide console.log messages unless Debug setting is checked.


6.0.2 (2016-06-02)
++++++++++++++++++

- Prevent cleaning up after uninstall because there is nothing left to delete
  after Atom deletes the package folder.


6.0.1 (2016-06-02)
++++++++++++++++++

- Fix debug setting.
- Improve messaging in status bar while plugin initializing.


6.0.0 (2016-05-29)
++++++++++++++++++

- For backwards compatibility when upgrading, save api key from Atom to config
  file on startup.


5.0.11 (2016-05-29)
++++++++++++++++++

- Fix bug causing api key to be loaded from common config into Atom's config
  when starting up.


5.0.10 (2016-05-29)
++++++++++++++++++

- Update embedded python to version 3.5.1.


5.0.9 (2016-05-29)
++++++++++++++++++

- Store api key in common ~/.wakatime.cfg config file to prevent leaking it
  when reporting errors to GitHub issues.


5.0.8 (2016-02-24)
++++++++++++++++++

- fix bug in status bar element registration


5.0.7 (2016-02-24)
++++++++++++++++++

- only update status bar if it exists


5.0.6 (2016-02-24)
++++++++++++++++++

- randomize status bar element name to prevent conflicts if package reloaded


5.0.5 (2016-02-24)
++++++++++++++++++

- shorten status bar text unless there was an error to display


5.0.4 (2016-02-23)
++++++++++++++++++

- new status bar menu item


5.0.3 (2016-02-23)
++++++++++++++++++

- detect project name from open project folders


5.0.2 (2015-11-29)
++++++++++++++++++

- lazy load package dependencies to speed up Atom startup time


5.0.1 (2015-11-20)
++++++++++++++++++

- use embedded python on windows


5.0.0 (2015-10-10)
++++++++++++++++++

- get latest wakatime cli version from GitHub instead of hard coding


4.1.1 (2015-09-29)
++++++++++++++++++

- upgrade wakatime cli to v4.1.8
- fix bug in guess_language function
- improve dependency detection
- default request timeout of 30 seconds
- new --timeout command line argument to change request timeout in seconds


4.1.0 (2015-09-14)
++++++++++++++++++

- add settings button to wakatime package in plugins menu list


4.0.17 (2015-09-10)
++++++++++++++++++

- prevent errors from corrupted wakatime cli zip file download
- upgrade wakatime cli to v4.1.6
- new --entity and --entitytype command line arguments
- fix entry point for pypi distribution
- allow passing command line arguments using sys.argv


4.0.16 (2015-08-28)
++++++++++++++++++

- upgrade wakatime cli to v4.1.3
- fix local session caching


4.0.15 (2015-08-25)
++++++++++++++++++

- upgrade wakatime cli to v4.1.2
- fix bug in offline caching which prevented heartbeats from being cleaned up


4.0.14 (2015-08-25)
++++++++++++++++++

- upgrade wakatime cli to v4.1.1
- send hostname in X-Machine-Name header
- catch exceptions from pygments.modeline.get_filetype_from_buffer
- upgrade requests package to v2.7.0
- handle non-ASCII characters in import path on Windows, won't fix for Python2
- upgrade argparse to v1.3.0
- move language translations to api server
- move extension rules to api server
- detect correct header file language based on presence of .cpp or .c files
  named the same as the .h file.


4.0.13 (2015-08-20)
++++++++++++++++++

- prompt the user before installing python
- remove wakatime cli directory when package is uninstalled
- use python v3.4.3


4.0.12 (2015-07-05)
++++++++++++++++++

- catch exceptions from rimraf when removing old wakatime cli directory
- catch exceptions from adm-zip when wakatime cli zip corrupted
- correct priority for project detection
- upgrade wakatime cli to v4.1.0


4.0.11 (2015-06-25)
++++++++++++++++++

- when installing wakatime cli, always extract zip file


4.0.10 (2015-06-23)
++++++++++++++++++

- update wakatime cli from github repo if there is a new version


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

- remove deprecated atom.workspaceView


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

- use highlight.js v8.4.0 or greater because installing from github causing
  problems.


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
