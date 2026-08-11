@echo off
rem ASCII-path env vars for Korean-username machine; TEMP override is required for flutter test
set PUB_CACHE=C:\flutter\.pub-cache
set GRADLE_USER_HOME=C:\workAndroid\gradle-home-ascii
set TEMP=C:\workAndroid\tmp-ascii
set TMP=C:\workAndroid\tmp-ascii
C:\flutter\bin\flutter.bat %*
