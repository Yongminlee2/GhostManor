@echo off
rem ASCII 경로 강제 (한글 사용자명 머신) — TEMP은 flutter test 필수
set PUB_CACHE=C:\flutter\.pub-cache
set GRADLE_USER_HOME=C:\workAndroid\gradle-home-ascii
set TEMP=C:\workAndroid\tmp-ascii
set TMP=C:\workAndroid\tmp-ascii
C:\flutter\bin\flutter.bat %*
