// Offline Lua regression harness. This does not emulate Maker RPC, rendering, or networking.
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const root = path.resolve(__dirname, '../..');
function transpile(name, relative = name) {
  const file = path.join(root, 'RootDesk/MyDesk', relative + '.mlua');
  const source = fs.readFileSync(file, 'utf8');
  const props = [];
  let lines = source.trimEnd().split(/\r?\n/);
  if (lines.pop().trim() !== 'end') throw new Error('Missing class end: ' + name);
  const body = lines.map(line => {
    if (/^\s*@/.test(line)) return '';
    if (/^script /.test(line)) return name + ' = {}';
    const p = line.match(/^\s*property\s+\w+\s+(\w+)\s*=\s*(.*)$/);
    if (p) { props.push(`self.${p[1]} = ${p[2]}`); return ''; }
    const m = line.match(/^\s*method\s+\w+\s+(\w+)\((.*)\)\s*$/);
    if (m) return `function ${name}:${m[1]}(${m[2].replace(/\b\w+\s+(\w+)/g, '$1')})`;
    const h = line.match(/^\s*handler\s+(\w+)\((.*)\)\s*$/);
    if (h) return `function ${name}:${h[1]}(${h[2].replace(/\b\w+\s+(\w+)/g, '$1')})`;
    return line;
  }).join('\n');
  return body + `\nfunction ${name}.new()\nlocal self = setmetatable({_T = {}}, {__index = ${name}})\n${props.join('\n')}\nreturn self\nend\n`;
}
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
let failedLogs = 0;
lua.lua_pushjsfunction(L, state => {
  const msg = to_jsstring(lua.lua_tolstring(state, 1));
  if (/\[FAIL\]|SUITE FAILED/.test(msg)) failedLogs++;
  if (/COMPLETE|SUITE|\[FAIL\]|OFFLINE/.test(msg)) console.log(msg);
  return 0;
}); lua.lua_setglobal(L, to_luastring('host_log'));
function run(text, name) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(text), null, to_luastring(name)) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
    throw new Error(name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
  }
}
run(`log=host_log; log_error=host_log
function isvalid(x) return x ~= nil and x.valid ~= false end
_UtilLogic={RandomIntegerRange=function(self,a,b) return math.random(a,b) end}
_LexioRewardService={GrantMatchRewards=function() end}
math.randomseed(20261120)
`, 'stubs');
for (const n of ['LexioRules','LexioGameSession','LexioSessionCoordinator','LexioTableRegistry','LexioPlayerBridge','LexioPlayUIController','LexioManualTestControls','LexioRuleTests','LexioGameSessionTests']) run(transpile(n), n);
run(transpile('LexioMainMenuController','UI/LexioMainMenuController'), 'main menu');
run(`
_LexioRules=LexioRules.new()
local main=LexioGameSession.new()
local other=LexioGameSession.new()
local entity={GetComponent=function(self,n) if n=='script.LexioGameSession' then return main end end}
local otherEntity={GetComponent=function() return other end}
_EntityService={GetEntityByPath=function(self,p) if p=='/maps/lexio_session_tests/LexioIsolationSessionB' then return otherEntity end end}
local rules=LexioRuleTests.new(); rules:OnBeginPlay()
local suite=LexioGameSessionTests.new(); suite.Entity=entity; suite:OnBeginPlay()
assert(rules.failedCount==0 and suite.failedCount==0, 'existing regression suite failed')
`, 'existing suites');
const additional = path.join(__dirname, 'scenarios.lua');
if (fs.existsSync(additional)) run(fs.readFileSync(additional, 'utf8'), 'beta scenarios');
if (failedLogs) process.exitCode=1;
else console.log('OFFLINE regression passed (Maker/runtime verification remains separate).');
