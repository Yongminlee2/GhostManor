"""시뮬레이터에서 여러 화면을 차례로 띄워 찍는다(디버그 빌드, 실행 인자 -SHOT).
  python3 tool/art_check/shots.py <UDID> <출력 폴더> 'living/0' 'attic/2/chest' ...
이름은 SHOT 값의 / 를 _ 로 바꾼 것. 앱은 build/ios/iphonesimulator/Runner.app 을 덮어 설치한다.
"""
import os, subprocess, sys, time
udid, out, shots = sys.argv[1], sys.argv[2], sys.argv[3:]
os.makedirs(out, exist_ok=True)
app = 'build/ios/iphonesimulator/Runner.app'
bid = 'com.yongmin.ghostmanor'
subprocess.run(['xcrun', 'simctl', 'install', udid, app], check=True)
for shot in shots:
    subprocess.run(['xcrun', 'simctl', 'terminate', udid, bid], capture_output=True)
    subprocess.run(['xcrun', 'simctl', 'launch', udid, bid, '-SHOT', shot or 'title'], check=True, capture_output=True)
    time.sleep(float(os.environ.get('WAIT', '7')))
    name = shot.replace('/', '_').replace(',', '+').replace('=', '-')[:120] or 'title'
    subprocess.run(['xcrun', 'simctl', 'io', udid, 'screenshot', f'{out}/{name}.png'], check=True, capture_output=True)
    print('찍음', name)
