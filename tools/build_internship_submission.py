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
FILE=OUT/'김재렬_AI크리에이터_인턴십_포트폴리오.pdf'
c=canvas.Canvas(str(FILE),pagesize=A4)
c.setTitle('김재렬 | 넷마블네오 AI Game Maker 인턴십 포트폴리오')
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
 p('김재렬 · AI 활용 개인 프로젝트 · 작성 2026.11.22',33,7.5)
 c.setFont('K',8);c.setFillColor(MUT);c.drawRightString(W-M,25,str(n)+' / 4')

def section(title,text,y):
 y=p(title,y,13,True)-8
 return p(text,y)-20

def image(path,y,width):
 im=ImageReader(str(path));iw,ih=im.getSize();h=width*ih/iw
 c.drawImage(im,M,y-h,width,h,mask='auto');return y-h


header(1,'AI로 구현하고, 직접 검증하다','넷마블네오 AI Game Maker 인턴십 포트폴리오 | 김재렬')
y=H-156
y=p('메이플 렉시오',y,27,True)-12
y=p('멀티플레이 보드게임을 기획하고 Codex와 함께 구현해 공개 베타로 출시한 개인 프로젝트',y,13)-24
c.setFillColor(LIGHT);c.roundRect(M,y-91,W-2*M,91,7,fill=1,stroke=0)
p('2026.10-11  /  MapleStory Worlds · mLua',y-13,11,True,x=M+15,width=W-2*M-30)
p('3·4·5인 카드 게임  /  공개 베타 출시 2026.11.21<br/>방·매칭·채팅·점수·재경기·이탈 복구를 하나의 흐름으로 연결',y-39,10,x=M+15,width=W-2*M-30)
y-=117
y=section('내가 해결하려던 문제','아이디어와 기능 목록만 있는 상태에서 실제로 접속해 플레이할 수 있는 게임으로 완성하는 것이 목표였습니다. 이동형 카페 시제품의 범위를 줄여 정적 UI 게임에 집중하고, 플레이 중 발견한 문제를 요구사항과 검증 항목으로 바꾸며 출시했습니다.',y)
y=section('본인 기여 - 기획과 판단, 테스트, 출시','개인 프로젝트입니다. 저는 게임 방향·기능 우선순위·상세 규칙을 결정하고, UI 피드백·실제 플레이 테스트·출시 결정을 담당했습니다. AI가 구현을 보조했으며, 저는 요구사항·정책 결정과 실행 결과 검증·출시를 주도했습니다.',y)
y=section('AI 활용 - 구현과 검사 보조','Codex를 코드 작성·수정, 설계 정리, 회귀 테스트와 Maker 프로브, 오류 분석, 문서 초안에 활용했습니다. AI가 제시한 구현과 완료 보고를 실제 화면·로그·플레이 결과와 비교하며 수정했습니다.',y)
p('이 자료는 요구사항 정의, AI와의 반복 작업, 검증의 경계를 중심으로 새로 작성했습니다. 외부 캐릭터 이미지·음원·실행 파일과 타인의 코드 원문은 수록하지 않았습니다.',y,9)
c.showPage()

header(2,'요구사항을 실행 정책으로','사례 1 | 막연한 주문을 예외 상황과 판정 기준까지 구체화')
y=H-151
y=section('매칭: 대기열만 묶으면 충분하지 않았다','기존 3인 방에 1명이 있고 5명이 빠른 매칭을 누르면, 2명은 기존 방에 들어가고 남은 3명은 새 방을 만들도록 요구했습니다. AI의 초기 구현이 대기열 사용자끼리만 묶는다는 점을 확인하고 기존 방 우선 배정으로 변경했습니다.',y)
for a,b in [('기존 공개방 1/3','대기자 2명 배정 → 기존 방 3/3'),('대기열 5명','남은 3명 → 새 3인 방 생성')]:
 c.setFillColor(LIGHT);c.roundRect(M,y-53,W-2*M,53,5,fill=1,stroke=0)
 p(a,y-9,11,True,x=M+12,width=140)
 p(b,y-11,10,x=M+164,width=W-2*M-178)
 y-=64
y-=8
y=section('AI 대행: 대체와 영구 이탈을 분리','이탈자의 화면에는 재접속·로비 이동을 남겨 둡니다. 남은 사람이 AI 대행에 찬성해도 원래 사용자는 복귀할 수 있어야 한다고 정했습니다. 반면 직접 로비로 이동하면 해당 좌석 복귀를 포기합니다.',y)
y=section('투표: 과반과 만장일치를 구분','AI 대행은 남은 사람의 절반을 초과하는 찬성, 30초 제한, 미투표 반대로 정의했습니다. 2명은 2명 모두, 3명은 2명, 4명은 3명이 필요합니다. 한 판 더는 별도 정책으로 전원 만장일치를 요구했습니다.',y)
y=section('내 판단이 만든 구현 기준','종료 시 AI가 남아 있으면 정산 후 방을 닫고, 사람이 종료 전에 복귀하면 재경기를 허용하도록 결정했습니다. Codex가 이 정책을 상태 전이와 회귀 검사로 구현하도록 요청했습니다.',y)
p('설명은 실제 대화의 요구를 요약·재구성했습니다. 제시된 숫자는 정책 예시이며 사용자 지표나 성능 측정치가 아닙니다.',y,8.5)
c.showPage()

header(3,'AI의 완료 보고를 검증하다','사례 2 | 코드 상태 확인에서 실제 사용자 행동 확인으로')
y=H-151
y=section('문제: 테스트에서는 열렸지만 출시본에서는 보이지 않음','소리 설정 버튼이 동작한다는 보고를 받았지만 출시 클라이언트에서 눌러도 창이 나타나지 않았습니다. 초기 검사는 버튼 이벤트를 직접 보내 팝업 Enable 값만 확인해, 실제 화면에서의 표시 문제를 놓쳤습니다.',y)
steps=[('재현','출시본에서 실제 마우스로 버튼 클릭'),('수정','게임 HUD에 있던 팝업을 공통 UI로 분리'),('재확인','Maker 실제 클릭·슬라이더 조절, 출시본 창 표시 확인')]
for a,b in steps:
 c.setFillColor(LIGHT);c.roundRect(M,y-51,W-2*M,51,5,fill=1,stroke=0)
 p(a,y-10,11,True,x=M+12,width=75)
 p(b,y-11,10,x=M+95,width=W-2*M-109)
 y-=61
y-=10
y=section('음량: 100%의 의미부터 다시 확인','출시 환경에서 효과음이 작다고 느껴 확인을 요청했습니다. 게임의 100%가 클릭음 0.18, 일반 효과음 0.3의 기본 배율에 곱해지는 구조였습니다. 최대 기준을 1.0으로 바꾸고 50%가 0.5로 전달되는지 검사했습니다. 플랫폼 자체 음량은 별도 설정으로 구분했습니다.',y)
y=section('불필요한 우회 구현은 제거','게임 종료를 KickUser로 연결하자 추방 문구가 떴습니다. 알림 없는 직접 종료 API를 확인하지 못한 상태에서 안내 버튼만 남기는 것도 원치 않아, 종료 버튼 자체를 제거하도록 결정했습니다.',y)
p('배운 점: AI가 작성한 코드의 내부 상태만 확인해서는 충분하지 않았습니다. 사용자 관점의 클릭·표시·소리를 별도의 검증 대상으로 삼아야 했습니다.',y,10,True)
c.showPage()

header(4,'결과와 검증의 경계','공개 베타 출시 이후에도 확인한 것과 남은 것을 분리')
y=H-151
y=section('결과','2026년 11월 21일 공개 베타 출시. 이후 소리 팝업, 효과음 최대 음량, 종료 버튼 제거를 반영했고, 11월 22일에는 새 턴의 이전 안내 초기화와 패스 중복음 수정을 재출시했습니다.',y)
y=section('재현 가능한 검사','규칙 50 + 세션 108 + 추가 시나리오 3,467 = 3,625개 단언 통과. 실제 mLua 메서드 본문을 Fengari로 실행합니다. 반복 시나리오를 포함한 단언 수이며 3,625개 기능이나 독립 사용자 테스트 수가 아닙니다.',y)
y=section('실행 환경에서 확인한 범위','Maker에서 3·4·5인 각각 두 판의 타이머·점수 합 유지, 방 격리와 생성·변경·정리를 프로브로 확인했습니다. 출시 클라이언트에서는 접속과 소리 설정 실제 클릭·표시, 공식 로비 이동을 확인했습니다.',y)
y=section('아직 보장하지 않는 범위','독립된 실제 계정 여러 명의 전체 경기, 실제 웹브라우저 실행, 장시간 부하는 최종 검증하지 않았습니다. 다른 서버 인스턴스로의 세션 복구는 미지원입니다. 테스트 통과와 전체 서비스 안정성을 동일하게 표현하지 않습니다.',y)
y=section('AI를 활용하며 갖춘 방식','요구를 예시와 판정 기준으로 구체화하고, AI의 구현을 실제 결과로 확인하며, 오류가 나면 재현 조건을 남겨 다음 검사에 반영했습니다. 완성된 코드의 양보다 기획·검증·수정·출시를 이어 간 과정을 이 프로젝트의 성과로 제시합니다.',y)
y=p('추가 확인 자료',y,12,True)-9
y=p('GitHub 공개 저장소: github.com/jimsil261/maple_worlds<br/>README · Docs/Verification.md · tests/lexio-validation<br/>실행 파일은 첨부하지 않습니다. 게임은 MSW 계정 로그인이 필요하므로 비로그인 열람용 시연 링크를 대신한다고 주장하지 않습니다.',y,9.4)-18
c.linkURL('https://github.com/jimsil261/maple_worlds',(M,y+18,W-M,y+75))
p('본 문서는 이미지·음원을 제외한 제출 전용 요약본입니다. 프로젝트 소스에는 플랫폼 의존성이 있으며, AI 활용 범위와 본인 기여는 1쪽에 명시했습니다.',y,8.5)
c.showPage();c.save()
print(FILE)
