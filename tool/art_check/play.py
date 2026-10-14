"""디버그 재생: build/play.json 을 시뮬레이터 앱에 넣고 SHOT=play 로 띄워, 앱이 찍은 단계별 화면을
<출력 폴더>로 가져온다. 먼저 flutter test tool/art_check/play_record_test.dart, flutter build ios --simulator --debug.
  python3 tool/art_check/play.py <UDID> <출력 폴더>
"""
import os, shutil, subprocess, sys, time
udid, out = sys.argv[1], sys.argv[2]
bid = 'com.yongmin.ghostmanor'
subprocess.run(['xcrun', 'simctl', 'install', udid, 'build/ios/iphonesimulator/Runner.app'], check=True)
data = subprocess.run(['xcrun', 'simctl', 'get_app_container', udid, bid, 'data'],
                      capture_output=True, text=True, check=True).stdout.strip()
docs = f'{data}/Documents'
os.makedirs(docs, exist_ok=True)
shutil.rmtree(f'{docs}/play', ignore_errors=True)
shutil.copy('build/play.json', f'{docs}/play.json')
subprocess.run(['xcrun', 'simctl', 'terminate', udid, bid], capture_output=True)
subprocess.run(['xcrun', 'simctl', 'launch', udid, bid, '-SHOT', 'play'], check=True, capture_output=True)
t0 = time.time()
while not os.path.exists(f'{docs}/play/done'):
    if time.time() - t0 > 900:
        sys.exit('시간 초과')
    time.sleep(3)
shutil.rmtree(out, ignore_errors=True)
shutil.copytree(f'{docs}/play', out)
print('가져옴', len(os.listdir(out)) - 1, '장 →', out)
