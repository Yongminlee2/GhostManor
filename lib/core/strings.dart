const strHintTitle = '힌트';
const strHintFree = '힌트 보기';
String strHintLockedIn(int sec) {
  final m = sec ~/ 60;
  final ss = (sec % 60).toString().padLeft(2, '0');
  return '🔒 $m:$ss 후 열림';
}

// ── 현관 (room1_foyer) ──
const strFoyerIntro =
    '어이쿠, 살아있는 사람이잖아?! …아, 아니, 어흠. 나는 이 저택의 집사 유령 "고스포"다. '
    '상속자라면 자격을 증명해야지. 이 현관을 빠져나와 보시게. 무, 무섭지? 응?';
const strFoyerGhostChat = '"시험 중엔 말 걸지 말아줄래? …사실 나도 정답이 잘 기억 안 나."';
const strFoyerFrontDoor = '나가는 문은 안 열어줌. 밖은 깜깜하고… 솔직히 나도 밖은 좀 무서워. — 고스포';
const strFoyerUmbrella = '우산꽂이. 우산은 없고 거미줄만 잔뜩이다.';
const strFoyerCandleFound = '신발 속에 양초가?! 삼촌의 수납 센스는 알 수가 없다.';
const strFoyerDoorLocked = '단단히 잠겨 있다. 오래된 열쇠 구멍이 보인다.';
const strFoyerDrawerDark = '서랍 속이 너무 어두워서 아무것도 안 보인다.';
const strFoyerKeyFound = '낡은 열쇠를 얻었다! 고스포가 아쉬운 표정을 짓는다.';
const strFoyerDoorOpened = '철컥! 문이 열렸다. 저택 안쪽으로 들어가자.';
const strFoyerClockSet = '똑딱… 철컥! 어디선가 잠금이 풀리는 소리가 났다.';

// ── 현관 리마스터 신규 (room1_foyer, foyer_r_ 플래그) ──
const strFoyerRCoatMatch =
    '먼지를 털어내니 안주머니에서 성냥 한 개비가 나왔다! 고스포: "거봐, 내가 저기 있다고 했잖아. …안 했나? 아무튼 있었다."';
const strFoyerRShoe1 = '낡은 부츠 한 짝, 진흙이 300년째 말라붙어 있다. 고스포: "삼촌이 정원 일을 좋아하셨지. 유령이 되고 나서도 말이야."';
const strFoyerRShoe2 =
    '반짝이는 무도화, 발끝이 다 헤졌다. 고스포: "밤새 왈츠를 추셨다는 소문이 있는데… 나도 자세힌 모른다. 소문이란 게 원래 그렇지."';
const strFoyerRPortrait1 = '근엄한 표정의 초상화. 고스포: "이분이 이 저택의 초대 주인님이시다. 눈매가 매섭지? 나도 300년째 적응이 안 된다."';
const strFoyerRPortrait2 =
    '화사한 드레스 차림의 귀부인 초상화. 고스포: "사모님이시지. 그림 속에서도 나를 흘겨보시는 것 같단 말이야… 기분 탓이겠지?"';
const strFoyerRMirror = '먼지 낀 거울. 고스포가 무심코 들여다보다 화들짝 놀란다. "으악, 내가 없어! …아, 맞다. 유령이었지. 이거 매번 놀란다니까."';
const strFoyerRRug = '낡은 양탄자. 밟을 때마다 먼지가 풀썩인다. 고스포: "그 밑에 뭐 있나 궁금하지? 없다, 진짜 없어. 왜 자꾸 들춰보려고 그러나."';
const strFoyerRLandingDoor =
    '해골 장식이 달린 육중한 문. 밀어도 두드려도 꿈쩍 않는다. 고스포: "그 문 말인가. …300년째 나도 어디로 이어지는지 모른다네."';
const strFoyerRCandlestick = '벽에 붙은 장식용 촛대. 초는 꽂혀 있지만 불붙은 흔적은 없다. 고스포: "장식이다, 장식. …뭐, 만져본다고 뭐라 안 한다."';
const strFoyerRLetter1 = '저녁 식사는 셋째 시계의 시각에 — E.G.';
const strFoyerRDrawerLocked = '서랍이 꿈쩍도 안 한다. 어디선가 시계 초침 소리만 크게 들린다…';

// ── 거실 (room2_living) ──
const strLivingIntro = '"드, 들어오지 마! 여긴 겁주기 담당 부우 님의 구역이다!" …문 앞의 작은 유령이 이불을 뒤집어쓰고 떨고 있다.';
const strLivingBooScare = '"부우~! 무, 무섭지?! …안 무서워? 하아, 오늘 드라마 재방송도 놓쳤는데."';
const strLivingBooBlocks = '부우가 문 앞을 막고 있다. 뭔가 몹시 시무룩해 보인다. TV 이야기를 중얼거리는데…';
const strLivingBooHappy = '"오오, 3화부터구나!! 넌 좋은 인간이야. 문? 마음대로 해." 부우가 소파에 파묻혀 TV에 빠져 있다.';
const strLivingCushion = '쿠션 밑에서 리모컨을 찾았다! 유령도 리모컨은 숨기는구나.';
const strLivingCushionEmpty = '쿠션 밑엔 이제 과자 부스러기뿐이다.';
const strLivingTvOff = '낡은 TV. 전원이 꺼져 있다. 리모컨이 있어야겠는데.';
const strLivingTvOn = '지지직… TV가 켜졌다! 기묘한 방송이 나온다. 화면을 자세히 봐 두자.';
const strLivingMantel = '벽난로 위 선반. 벽돌 하나가 헐거워 보이는데, 지금은 꿈쩍도 안 한다. 벽난로에 불이 붙으면 어떨까?';
const strLivingFireplaceCold = '차갑게 식은 벽난로. 촛대들과 뭔가 연결되어 있는 것 같다.';
const strLivingFireplaceLit = '벽난로가 활활 타오른다. 훈훈하다 못해 조금 으스스하게 따뜻하다.';
const strLivingFireLit = '화르륵! 촛불의 배열에 맞춰 벽난로에 불이 붙었다! 위쪽 벽돌이 덜컹 열렸다.';
const strLivingSecretFound = '비밀칸에서 거실 열쇠, 달 그림 음표 카드, 기름병을 찾았다!';
const strLivingSecretEmpty = '비밀칸은 이제 비어 있다.';
const strLivingDoorLocked = '잠겨 있다. 열쇠 구멍이 반짝인다.';
const strLivingDoorOpened = '철컥! 다음 방으로 가는 문이 열렸다.';

// ── 거실 리마스터 신규 (room2_living, living_r_ 플래그) ──
const strLivingRNookKnob = '비밀칸에서 낡은 다이얼 손잡이를 찾았다! 부우: "그거 원래 저기 있었나? …몰랐다."';
const strLivingRPortraitBaby =
    '포동포동한 아기 초상화. 그림 구석, 아기 곁 협탁에 줄무늬 갓 램프가 함께 그려져 있다. 부우: "얘도 나만큼 이 집에 오래 있었을걸. …계속 아기인 채로 말이야."';
const strLivingRPortraitYouth =
    '형형한 눈빛의 청년 초상화. 등 뒤로 길쭉한 괘종시계가 그려져 있다. 부우: "저 눈빛, 좀 무섭지 않냐? …나만 그런가."';
const strLivingRPortraitMiddle =
    '그윽한 눈매의 중년 초상화. 팔꿈치 옆 탁자에 꽃병이 놓여 있다. 부우: "근엄하지? 근데 콧수염이 좀 웃기지 않아?"';
const strLivingRPortraitOld =
    '주름진 눈가의 노인 초상화. 무릎 위에 책 몇 권이 포개져 있다. 부우: "이분이 제일 오래 보셨을 텐데… 뭘 읽으셨는진 나도 모른다."';
const strLivingRLamp = '갓의 줄무늬를 세어본다… 셋.';
const strLivingRPendulum = '추가 둘.';
const strLivingRVase = '꽃이 일곱 송이.';
const strLivingRBooks = '네 권.';
const strLivingRSafeNoKnob = '손잡이 꽂을 자리만 휑하다.';
const strLivingRSafeKnobAttached = '끼릭, 손잡이가 딱 맞게 들어간다. 부우: "오, 거기 자리가 있었네? …몰랐다."';
const strLivingRSafeWrong = '"우와, 그것도 아니야? 나 드라마 보다가 다 들리는데…" 부우가 킥킥댄다.';
const strLivingRSafeOpen = '철컹, 철컹, 철컹! 묵직한 소리와 함께 금고 문이 열렸다. 거실 열쇠와 기름병, 달 그림 음표 카드가 들어 있었다!';
const strLivingRSafeEmpty = '금고 안은 이제 비어 있다.';

// ── 서재 (room3_study) ──
const strStudyIntro = '책 무더기 속에서 안경 쓴 유령이 고개를 내민다. "쉿. 여긴 서재야. …책 제목? 다 까먹었어."';
const strStudyNed = '"이 방의 비밀? 음… 잉크를 쏟았던 기억은 나. 어디에 쏟았더라." 너덜이 책장을 뒤적인다.';
const strStudyDesk = '오래된 책상. 잉크병이 쓰러져 있고, 얼룩진 종이 한 장이 눈에 띈다.';
const strStudyBookReset = '덜컥. 책들이 원래대로 튕겨 돌아왔다. 순서가 틀린 모양이다.';
const strStudyNookOpen = '드르륵! 책장 한 칸이 안으로 밀리며 숨은 공간이 드러났다!';
const strStudyNookLoot = '숨은 공간에서 놋쇠 크랭크와 별 그림 음표 카드를 찾았다!';
const strStudyGlobe = '낡은 지구본. 옆면에 크랭크를 꽂는 구멍이 있다.';
const strStudyGlobeOpen = '끼릭끼릭… 지구본이 반으로 갈라졌다!';
const strStudyGlobeKey = '지구본 안에서 서재 열쇠를 꺼냈다.';
const strStudyDoorLocked = '잠겨 있다. 열쇠 구멍이 오래됐다.';
const strStudyDoorUnlocked = '철컥. 잠금은 풀렸는데… 문이 꿈쩍도 안 한다. 경첩이 시뻘겋게 녹슬었다.';
const strStudyDoorSqueak = '끼이이익… 경첩이 녹슬어 열리지 않는다. 기름칠이 필요하다.';
const strStudyDoorOiled = '기름을 듬뿍 발랐다. 경첩이 부드럽게 움직인다.';

// ── 서재 리마스터 신규 (room3_study, study_r_ 플래그) ──
const strStudyRNookLoot = '숨은 공간에서 놋쇠 렌즈와 별 그림 음표 카드를 찾았다!';
const strStudyRTelescopeNoLens = '렌즈가 빠져 있다. 동그란 유리알이 필요하다.';
const strStudyRTelescopeLensIn = '망원경에 렌즈를 끼우자 흐릿하던 시야가 또렷해진다.';
const strStudyRGlobeReset = '지구본이 삐걱대며 제자리로 돌아간다. 뭔가 규칙이 있는 듯하다.';
const strStudyRGlobeQuiet = '지구본은 이제 조용히 받침대 위에 놓여 있다.';
const strStudyRWindow = '창밖은 온통 캄캄한 밤. 유리에 서린 입김 자국이 남는다.';
const strStudyRGlobeReplica = '책상 구석의 작은 지구의 모형. 대륙 모양이 다 닳아 없어졌다.';
const strStudyRLowerShelf = '아래 칸엔 곰팡내 나는 책들이 가득하다. 제목은 알아볼 수 없다.';
const strStudyRShelfTop = '천장 가까이 닿은 책장 꼭대기엔 먼지만 소복하다.';

// ── 주방 (room4_kitchen) ──
const strKitchenIntro = '커다란 국자를 든 유령이 텅 빈 냄비를 젓고 있다. "300년째 맛을 못 봤어… 유령 수프만 있다면."';
const strKitchenGukjaHappy = '"완벽한 간이야…!" 국자가 감격에 젖어 수프를 젓고 있다.';
const strKitchenBottle = '조리대에서 빈 병을 챙겼다.';
const strKitchenCounterEmpty = '조리대엔 이제 먼지뿐이다.';
const strKitchenStove = '오래된 화덕. 불씨가 유령불처럼 파랗게 일렁인다.';
const strKitchenJar = '항아리 속에서 말린 버섯을 찾았다. 몇백 년 묵은 향이 난다.';
const strKitchenJarEmpty = '항아리는 비었다.';
const strKitchenSink = '싱크대에 이끼 낀 물이 고여 있다. 담을 것이 필요하다.';
const strKitchenFill = '병에 이끼 낀 물을 가득 담았다. 초록빛이 은은하다.';
const strKitchenKnockDull = '퉁, 퉁. 꽉 찬 둔탁한 소리다.';
const strKitchenKnockHollow = '통통! 속이 빈 울림이다! 문이 스르륵 열렸다.';
const strKitchenKettle = '찬장 안에서 노래하는 주전자를 꺼냈다. 흥얼거림이 멈추지 않는다.';
const strKitchenCupboardEmpty = '주전자가 있던 자리만 휑하다.';
const strKitchenDoorLocked = '뒷문은 잠겨 있다.';
const strKitchenDoorOpened = '철컥! 뒷문이 열렸다. 지하로 내려가는 계단이 보인다.';

// ── 주방 리마스터 신규 (room4_kitchen, kitchen_r_ 플래그) ──
const strKitchenRGukjaAsk =
    '국자가 둥둥 떠서 빈 냄비를 하염없이 젓는다. "300년 만에 처음으로 뭔가 끓여볼 수 있으려나… 기대되는군. 근데 맛없으면 바로 뱉을 거다. 미리 말해두는데, 나 입맛 되게 까다롭다."';
const strKitchenRPotWrong = '국자가 국물을 맛보더니 전부 뱉는다. "순서! 순서가 생명이야!!"';
const strKitchenRFed = '국자가 수프를 한 모금 넘긴다(어떻게?). "바로 이 맛이야…!!" 감격한 국자가 뒷문 열쇠를 건넸다!';
const strKitchenRPotWater = '맑은 물이 냄비 안에서 찰랑인다.';
const strKitchenRPotMushroom = '버섯이 퐁당! 물이 걸쭉하게 흐려진다.';
const strKitchenRPotHerb = '마른 약초 향이 확 퍼지며 냄비 속이 짙은 초록으로 물든다.';
const strKitchenRPotDone = '노래하는 주전자를 기울이자 흥얼거림이 김과 함께 스며든다. 국물이 순식간에 황금빛으로 빛난다!';
const strKitchenRPokerRack = '벽 걸이에서 낡은 부지깽이를 챙겼다.';
const strKitchenRPokerRackEmpty = '걸이는 이제 비어 있다.';
const strKitchenRPokerHeated = '부지깽이 끝을 화덕 속에 푹 찔러 넣었다. 벌겋게 달아올랐다!';
const strKitchenRPokerSlotEmpty = '화덕 옆에 쇠 걸이가 붙어 있다. 뭔가 달굴 게 있다면 여기 대보면 어떨까.';
const strKitchenRIceFrozen = '함 전체에 두꺼운 서리가 껴 자물쇠 윤곽조차 안 보인다.';
const strKitchenRIceColdPoker = '부지깽이 끝을 자물쇠에 대봤지만 아무 반응이 없다. 이걸로는 역부족인 모양이다.';
const strKitchenRIceCrack1 = '쩍! 서리에 금이 갔다. 자물쇠 윤곽이 살짝 드러난다.';
const strKitchenRIceCrack2 = '서리가 절반 넘게 녹아내렸다. 물이 뚝뚝 떨어진다.';
const strKitchenRIceMelted = '서리가 완전히 녹았다! 자물쇠가 스르르 풀리며 함이 열린다.';
const strKitchenRIceLoot = '함 속에서 마른 약초와 해 그림 음표 카드를 찾았다!';
const strKitchenRIceEmpty = '함 속은 이제 비어 있다.';
const strKitchenRSausages =
    '천장에 매달린 훈제 소시지 한 줄. 국자가 지날 때마다 아쉬운 눈으로 쳐다본다지만, 손(?)이 안 닿아 300년째 그대로다.';
const strKitchenRJarPickles = '장아찌가 든 항아리. 뚜껑을 여니 시큼한 냄새가 훅 끼친다. 유령도 코가 있으면 도망갈 냄새다.';
const strKitchenRJarFlour = '밀가루 항아리. 손을 넣었다 빼니 하얗게 변했다. 어디선가 국자의 재채기 소리가 들린 것 같다.';

// ── 지하실 (room5_cellar) ──
const strCellarIntro = '"꺄악! 누, 누구야! …사람? 다행이다아. 난 덜덜. 여기 너무 어두워서 300년째 무서워." 어둠 속 어딘가에서 이가 딱딱 부딪히는 소리가 난다.';
const strCellarDeoldeolDark = '"저기, 저기 빛나는 거 보여? 나는 무서워서 못 만져. 네가 좀…" 덜덜이 구석에서 떨고 있다.';
const strCellarDeoldeolLight = '"불 켜니까 살 것 같다! …참, 선반 위에 열쇠 있는 거 알아? 저긴 아무도 못 닿아. 온 집이 흔들리지 않는 한!"';
const strCellarBoxPlain = '평범한 상자다. 불을 켜니 다 똑같아 보인다.';
const strCellarBoxEmpty = '빈 상자다. 거미가 항의하듯 쳐다본다.';
const strCellarSwitchDead = '딸깍. 딸깍. 아무 일도 일어나지 않는다. 배전반이 죽어 있다.';
const strCellarLightOn = '팟! 지하실에 불이 들어왔다. 덜덜의 환호성이 들린다.';
const strCellarTooDark = '너무 어두워서 손잡이를 찾을 수 없다.';
const strCellarBarrelDone = '드드득…! 와인통이 밀려나며 작은 쪽문이 드러났다!';
const strCellarKeyDrop = '와장창! 선반이 흔들리며 열쇠가 바닥으로 떨어졌다! 덜덜: "지, 지진이야?!"';
const strCellarKeyTaken = '바닥에 떨어진 녹슨 열쇠를 주웠다.';
const strCellarDoorLocked = '쪽문은 잠겨 있다. 녹슨 열쇠 구멍.';
const strCellarDoorOpened = '끼익… 쪽문이 열렸다. 좁은 계단이 위로 이어진다.';

// ── 지하실 리마스터 신규 (room5_cellar, cellar_r_ 플래그) ──
const strCellarRGlowBox = '야광 표시가 빛나는 상자를 열었다. 낡은 퓨즈가 하나 들어 있었다!';
const strCellarRFusebox = '배전반. 소켓 두 개가 텅 비어 있다.';
const strCellarRFuseboxOneMore = '소켓 하나가 아직 비어 있다. 퓨즈가 하나 더 필요해 보인다.';
const strCellarRFuse1In = '퓨즈를 끼웠다. 배전반 한쪽이 웅 하고 깨어난다. 소켓이 하나 더 비어 있다.';
const strCellarRFuse2In = '두 번째 퓨즈까지 끼우자 배전반 전체가 부르르 떨린다. 안쪽에서 뭔가 달칵거리는 소리가 난다.';
const strCellarRSwitchWrong = '파지직! 스위치들이 튕겨 나가듯 아래로 툭 떨어진다. 순서가 잘못된 모양이다.';
const strCellarRWineBottle1 = '라벨을 자세히 본다. 가느다란 촛불 네 개가 그려져 있다.';
const strCellarRWineBottle2 = '라벨엔 촛불이 딱 하나. 외로워 보인다.';
const strCellarRWineBottle3 = '라벨 가득 촛불 다섯 개가 빼곡하다.';
const strCellarRWineBottle4 = '촛불 두 개가 나란히 그려져 있다.';
const strCellarRWineBottle5 = '라벨에 촛불 세 개가 나란히 타오르고 있다.';
const strCellarRWineWrong =
    '병들이 달그락거리며 제자리로. 덜덜: "그, 그거 순서 있댔어… 누가 그랬는지는 기억 안 나."';
const strCellarRWineDark = '어두워서 라벨이 하나도 안 보인다. 불부터 켜야겠다.';
const strCellarRWineUnlocked = '달그락! 상자 자물쇠가 스르르 풀리는 소리가 난다.';
const strCellarRBoxbLocked = '잠긴 작은 상자다. 자물쇠가 꿈쩍도 않는다.';
const strCellarRBoxbOpen = '상자가 열리며 낡은 퓨즈와 구름 그림 음표 카드가 나왔다!';
const strCellarRBoxbEmpty = '상자 안은 이제 비어 있다.';
const strCellarRExitNeedsPower = '쪽문 너머 계단이 칠흑같이 어둡다. 전력부터 확실히 복구해야 안심하고 오를 수 있겠다.';
const strCellarRSconce = '벽에 걸린 촛대. 조그만 불꽃이 조용히 흔들린다.';
const strCellarRCrate = '빈 병들이 쌓인 나무 상자. 와인 창고답게 여기저기 빈 병 천지다.';
const strCellarRDeoldeolC = '덜덜이 와인 랙 옆에서도 웅크리고 있다. "여, 여기도 뭔가 있는 것 같은데… 무서워서 자세힌 못 보겠어."';

// ── 다락방 (room6_attic) ──
const strAtticIntro = '"드디어 여기까지 왔군." 고스포가 트렁크 앞을 지키고 서 있다. "마지막 시험이다. 삼촌의 오르간은… 올바른 노래에만 답하지."';
const strAtticGhospoHint = '"카드는 보면대에, 순서는… 저 낡은 자수가 알고 있다. 나? 난 음치라서 모른다."';
const strAtticGhospoProud = '"그 노래… 주인님이 생전에 흥얼거리던 곡이야." 고스포가 눈시울(?)을 훔친다.';
const strAtticStandEmpty = '오르간 보면대. 음표 카드를 놓는 홈이 네 개 파여 있다.';
const strAtticCardPlaced = '카드를 보면대에 놓았다.';
const strAtticCardsAll = '네 장이 모두 모였다! 악보가 완성됐다 — 달, 별, 해, 구름이 각각 도·레·미·파로 빛난다.';
const strAtticStandFull = '악보 완성. 이제 연주만 남았다.';
const strAtticOrganNoCards = '건반을 눌러도 먹먹한 소리뿐이다. 보면대에 악보(음표 카드)가 있어야 할 것 같다.';
const strAtticOrganWrong = '삐끗! 오르간이 불쾌한 화음을 낸다. 처음부터 다시.';
const strAtticOrganPlayed = '웅장한 화음이 다락을 가득 채운다…! 트렁크의 자물쇠가 저절로 풀렸다.';
const strAtticTrunkLocked = '삼촌의 트렁크. 자물쇠에 열쇠 구멍이 없다. 음표 문양만 새겨져 있다.';
const strAtticWill = '유언장을 찾았다! "축하한다, 조카야. 시험을 통과했으니 저택은 네 것이다. 참, 말 안 했던가? 나도 300년 전부터 유령이란다. 앞으로 잘 부탁한다 — 2층에서 만나자꾸나. ― 삼촌" …잠깐, 뭐라고요?';
const strAtticWindow =
    '둥근 창으로 달빛이 쏟아진다. 마당의 허수아비가 손을 흔든… 기분 탓이겠지. 창틀을 세어본다… 넷.';

// ── 다락방 리마스터 신규 (room6_attic, attic_r_ 플래그) ──
const strAtticRChestWrong = '"주인님은 숫자를 셋만 기억하셨지. 나는… 하나도 기억 못 하네."';
const strAtticRChestOpen = '경첩이 삐걱, 궤짝이 열린다. 빛바랜 천 조각이 들어 있다 — 무언가의 나머지 반쪽 같다.';
const strAtticRChestEmpty = '궤짝 속은 이제 비어 있다.';
const strAtticREmbroideryFull = '조각을 자수에 가만히 대어본다. 꼭 맞는다. 찢겼던 그림이 다시 이어진다 — 달, 해, 별, 구름.';
const strAtticRCandleHolder = '촛대에 꽂힌 초를 세어본다… 셋.';
const strAtticRBooksPile = '쌓인 책을 세어본다… 둘.';
const strAtticRWindowMoon =
    '둥근 창 너머로 보름달이 떠 있다. 들판의 허수아비가… 방금 손을 흔들었나? 고스포: "…모른 척하게. 서로 그게 편하다네."';
const strAtticRStitchFrame =
    '나무 한 그루를 수놓은 자수틀. 한 땀 한 땀 정성이다. 고스포: "마님의 솜씨라네. 저택보다 오래된 솜씨지."';
const strAtticRRoundTable = '레이스가 덮인 둥근 탁자. 먼지가 도톰하게 쌓였다. 고스포: "티타임이 멈춘 지도 오래됐군."';
const strAtticRRug = '해진 깔개. 밟을 때마다 먼지가 폴싹 인다.';
const strAtticRDoll = '단추 눈이 한쪽 떨어진 낡은 인형. 어쩐지 이쪽을 보는 것 같다.';
const strAtticRGhospoC =
    '고스포가 잡동사니 사이에서 서성인다. "이것도 저것도… 다 주인님 손때가 묻은 것들이지. 나는 그저 먼지나 털었을 뿐인데." 옅은 한숨을 쉰다.';

// ── 앱 셸 ──
const strAppTitle = '기묘한 유령 저택';
const strTitleTagline = '삼촌이 남긴 저택, 유령들의 상속 자격 시험';
const strContinue = '이어하기';
const strNewGame = '처음부터';
const strNewGameConfirm = '저장된 진행이 삭제됩니다. 처음부터 시작할까요?';
const strSettings = '설정';
const strMute = '소리 끄기';
const strResetProgress = '진행 초기화';
const strResetConfirm = '정말 모든 진행을 삭제할까요?';
const strRoomClear = '방 탈출 성공!';
const strNextRoom = '다음 방으로';
const strChapterEnd = '챕터 1 클리어!\n삼촌(유령)의 저택은 이제 당신 것.\n…2층의 이야기는 다음 챕터에서.';
const strBackToTitle = '처음으로';
const strCancel = '취소';
const strOk = '확인';
