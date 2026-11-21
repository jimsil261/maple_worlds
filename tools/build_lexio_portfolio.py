from pathlib import Path
import argparse
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader
from reportlab.lib.pagesizes import A4
from pypdf import PdfReader, PdfWriter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/pdf'
OUT.mkdir(parents=True,exist_ok=True)
pdfmetrics.registerFont(TTFont('K','C:/Windows/Fonts/malgun.ttf'))
pdfmetrics.registerFont(TTFont('KB','C:/Windows/Fonts/malgunbd.ttf'))
W,H=A4
M=42
INK=colors.HexColor('#292442'); ACC=colors.HexColor('#7854A2'); MUT=colors.HexColor('#686679'); LIGHT=colors.HexColor('#F4F0F8')
FILE=OUT/'김재렬_메이플렉시오_포트폴리오.pdf'
c=canvas.Canvas(str(FILE),pagesize=A4)
c.setTitle('김재렬 | 메이플 렉시오 공개 베타 포트폴리오')
c.setAuthor('김재렬')
def p(t,y,size=10.2,bold=False,width=W-2*M,x=M):
 s=ParagraphStyle('p',fontName='KB' if bold else 'K',fontSize=size,leading=size*1.55,textColor=INK,wordWrap='CJK')
 z=Paragraph(t,s); _,h=z.wrap(width,1000); z.drawOn(c,x,y-h)
 if y>=58 and y-h<58: raise ValueError('Content below footer: '+t[:35])
 return y-h

def header(n,title,sub):
 c.setFillColor(ACC);c.rect(M,H-43,W-2*M,3,fill=1,stroke=0)
 p('김재렬  |  개인 프로젝트  |  2026.10-11',H-22,8)
 p(title,H-70,24,True);p(sub,H-111,9)
 c.setStrokeColor(colors.HexColor('#DDD5E7'));c.line(M,45,W-M,45)
 p('메이플 렉시오 · 공개 베타 2026.11.21',33,7.5)
 c.setFont('K',8);c.setFillColor(MUT);c.drawRightString(W-M,25,str(n)+' / 4')

def section(title,text,y):
 y=p(title,y,13,True)-8
 return p(text,y)-20

def image(path,y,width):
 im=ImageReader(str(path));iw,ih=im.getSize();h=width*ih/iw
 c.drawImage(im,M,y-h,width,h,mask='auto');return y-h

header(1,'메이플 렉시오','MapleStory Worlds · mLua · PC 멀티플레이 카드 보드게임')
y=image(ROOT/'Docs/assets/lexio-beta-thumbnail.png',H-145,W-2*M)-18
y=p('3·4·5인 보드게임을 공개 베타로 출시',y,17,True)-12
y=p('2026년 11월 21일 공개 출시와 후속 UI·음량 수정본 반영을 완료했습니다. 이동형 카페 시제품에서 정적 UI 중심 게임으로 방향을 전환하고, 방 생성부터 정산·재경기·연결 복구까지 구현했습니다.',y)-18
y=section('플레이 경험','공개방·비밀번호방·기존 방 우선 매칭 → 준비와 3·2·1 → 각 12장, 15초 턴 → 점수 정산 → 전원 동의 재경기. 아바타·채팅·말풍선·족보·개별 음량 설정을 제공합니다.',y)
y=section('담당 역할과 AI 활용','게임 방향, 기능 우선순위, UI 피드백, 실제 플레이 확인과 출시는 제작자가 담당했습니다. AI 도구는 설계 정리, 코드 작성·수정, 검사·프로브, 문서화와 일부 이미지에 활용했습니다.',y)
p('GitHub  github.com/jimsil261/maple_worlds',y,9)
c.linkURL('https://github.com/jimsil261/maple_worlds',(M,y-18,W-M,y+3))
c.showPage()

header(2,'서버 권한과 방 독립성','표시·요청 경계·한 판의 상태·규칙을 나누어 변경 영향 제한')
y=H-150
y=p('클라이언트는 행동을 요청하고 서버가 사용자, 좌석 소유권, 요청 ID와 상태 버전을 확인합니다. 공개 상태와 개인 손패는 구분해 전달하며, 같은 인원의 방도 동적으로 생성합니다.',y)-22
rows=[('UI / PlayerBridge','입력·요청 검증 경계 / 공개·개인 스냅샷'),('TableRegistry','방·좌석 소유권·매칭 대기열·빈 방 회수'),('SessionCoordinator','준비·카운트다운·타이머·AI·투표·재경기'),('GameSession / Rules','손패·턴·트릭·정산 / 조합 유효성·강도·점수')]
for title,desc in rows:
 c.setFillColor(LIGHT);c.roundRect(M,y-64,W-2*M,64,6,fill=1,stroke=0)
 p(title,y-10,12,True,x=M+13,width=W-2*M-26)
 p(desc,y-34,9.5,x=M+13,width=W-2*M-26)
 y-=70
y-=8
y=section('매칭 정책','기존 공개 대기방의 빈자리를 먼저 채우고, 남은 대기자로 새 방을 구성합니다. 방 생성·설정 변경·퇴장·재생성 시 이전 방의 정리가 새 좌석을 해제하지 않는지 검사했습니다.',y)
y=section('점수의 수명','새 방은 64점으로 시작합니다. 같은 방에서 만장일치로 재경기하면 직전 점수를 이월합니다. 경기 점수를 동·은·금 메소로 표시하며 영구 보상·코디 상점은 현재 출시 범위에서 제외했습니다.',y)
p('위 구성은 책임 관계를 단순화했습니다. 모든 요청이 동일한 순서로 호출되는 것은 아닙니다.',y,8.5)
c.showPage()

header(3,'이탈·AI 대행과 출시 후 수정','정책을 코드와 테스트로 연결하고, 실제 환경에서 놓친 부분을 수정')
y=H-150
y=section('01  이탈과 복귀를 구분','이탈하면 턴을 멈추고 남은 사람에게 30초 투표를 표시합니다. 찬성은 절반 초과, 미투표는 반대입니다. 통과하면 AI가 대행하되 원래 소유자의 복귀를 허용합니다. 로비로 직접 이동한 사람은 복귀를 포기합니다.',y)
y=section('02  종료 시점의 주체로 재경기 결정','종료 시 AI가 남아 있으면 정산 후 방을 닫습니다. 사람이 종료 전에 복귀했다면 만장일치 재경기가 가능합니다. AI 대행 투표의 과반 규칙과 한 판 더의 전원 동의를 분리했습니다.',y)
y=image(ROOT/'Docs/assets/lexio-5p-maker-preview.png',y,W-2*M)-8
y=p('Maker 5인 UI 검증 화면. 개발용 말풍선 위치 확인 문구 포함.',y,8)-18
y=section('03  직접 호출과 실제 클릭의 차이','Enable 값만 확인한 검사는 소리 팝업의 실제 가림을 놓쳤습니다. 출시본 마우스 클릭으로 재현한 뒤 공통 UI로 팝업을 분리하고 실제 표시를 확인했습니다. 효과음 100%에 낮은 내부 배율이 곱해지던 문제도 수정했습니다.',y)
p('종료를 KickUser로 처리하면 추방 문구가 발생했습니다. 임시 처리를 제거하고 사용자 요청에 따라 종료 버튼을 없앴습니다.',y,9.5)
c.showPage()

header(4,'검증 결과와 남은 한계','검사 수보다 무엇을 검증했는지, 어떤 환경이 남았는지 구분')
y=H-150
y=section('3,625개 단언 통과','독립 Lua 회귀 검사: 규칙 50 + 세션 108 + 추가 시나리오 3,467. 실제 mLua 메서드 본문을 Fengari로 실행합니다. 3,625개 기능이 아니라 반복 시나리오를 포함한 단언 수입니다.',y)
y=section('Maker 검증','3·4·5인 각각 두 판, 총 270회 타이머 행동과 점수 합 유지 확인. 동적 방 생성·격리와 방 생성 → 설정 변경 → 퇴장 → 재생성을 프로브로 확인했습니다. 최신 수정 후 빌드·실행 오류와 경고는 0이었습니다.',y)
y=section('출시 클라이언트 확인','접속, 메인/방 목록, 소리 설정 실제 클릭과 창 표시, 공식 로비 이동을 확인했습니다. 효과음 최대값 수정은 Maker에서 100%=1.0, 50%=0.5 재생 인자까지 검증했습니다.',y)
y=section('검증의 경계','독립 검사는 엔진·RPC·렌더링을 대역으로 처리합니다. Maker 가상 플레이어·서버 프로브는 독립 실계정 동시 접속 검증의 대체물이 아닙니다. 실계정 다인 전체 경기, 실제 웹 실행, 장시간 부하 검증은 남아 있습니다. 다른 서버 인스턴스 복구와 통합 매칭은 미지원입니다.',y)
y=section('다음 단계','실계정 3인 전체 흐름 → 4/5인 확대 → 두 방 동시 격리 → 실제 웹 실행 → 짧은 시연 영상과 확인된 공유 링크 추가. 현재는 메이플스토리 월드에서 “메이플 렉시오”를 검색해 접속합니다.',y)
y=p('소스 및 검증 재현',y,12,True)-10
y=p('github.com/jimsil261/maple_worlds<br/>Docs/Portfolio.md · Docs/Verification.md<br/>npm ci --prefix tests/lexio-validation<br/>node tests/lexio-validation/run.cjs',y,9.5)-20
c.linkURL('https://github.com/jimsil261/maple_worlds',(M,y+20,W-M,y+100))
p('메이플스토리·MSW 공식 리소스 권리는 각 권리자에게 있습니다. 저장소 공개는 별도 재배포·외부 사용 허가를 의미하지 않습니다.',y,8.5)
c.showPage();c.save()
args=argparse.ArgumentParser();args.add_argument('--base');a=args.parse_args()
if a.base:
 writer=PdfWriter()
 for file in [Path(a.base),FILE]:
  for page in PdfReader(str(file)).pages: writer.add_page(page)
 writer.add_metadata({'/Title':'김재렬 서버 개발 포트폴리오 - 메이플 렉시오 베타 출시','/Author':'김재렬'})
 with (OUT/'김재렬_서버개발_포트폴리오_베타출시본.pdf').open('wb') as f: writer.write(f)
print(FILE)
