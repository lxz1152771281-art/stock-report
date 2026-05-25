#!/usr/bin/env python3
"""小海看盘助手 🐚📊 - 每日复盘报告 (GitHub Actions版)"""
import json, urllib.request, os, sys
from datetime import datetime

NOW = datetime.now().strftime("%Y-%m-%d %H:%M")
TODAY = datetime.now().strftime("%Y-%m-%d")

# ============================================================
# 配置 - 从环境变量读取
# ============================================================
DEEPSEEK_KEY = os.environ.get("DEEPSEEK_KEY", "")
FEISHU_APP_ID = os.environ.get("FEISHU_APP_ID", "")
FEISHU_APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")
FEISHU_CHAT_ID = os.environ.get("FEISHU_CHAT_ID", "")

def http_get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.read()
    except Exception as e:
        print(f"  ⚠️ HTTP GET error: {e}", file=sys.stderr)
        return b""

def http_post(url, data, headers):
    req = urllib.request.Request(url, data=json.dumps(data).encode("utf-8"), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read()
    except Exception as e:
        print(f"  ⚠️ HTTP POST error: {e}", file=sys.stderr)
        return b""

def parse_sina(data):
    import re
    result = {}
    try:
        text = data.decode("gbk")
    except:
        return result
    for line in text.strip().split("\n"):
        m = re.search(r'hq_str_\w+_(\w+)', line)
        if not m:
            m = re.search(r'hq_str_(\w+)', line)
        if not m: continue
        code = m.group(1)
        if '"' not in line: continue
        parts = line.split('"')[1].split(",")
        result[code] = parts
    return result

# ============================================================
# 1. 大盘指数
# ============================================================
print("📊 拉取大盘数据...", flush=True)
idx_raw = http_get(
    "https://hq.sinajs.cn/list=s_sh000001,s_sz399001,s_sz399006,s_sh000688",
    {"Referer": "https://finance.sina.com.cn", "User-Agent": "Mozilla/5.0"}
)
idx = parse_sina(idx_raw)

INDEX_DATA = {
    "sh000001": "上证指数", "sz399001": "深证成指",
    "sz399006": "创业板指", "sh000688": "科创50"
}

# ============================================================
# 2. 热门板块
# ============================================================
print("📊 拉取板块数据...", flush=True)
sectors_raw = http_get(
    "https://push2.eastmoney.com/api/qt/clist/get?cb=&pn=1&pz=5&po=1&np=1"
    "&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3"
    "&fs=m:90+t:2&fields=f2,f3,f4,f12,f14"
)
sectors = []
try:
    sd = json.loads(sectors_raw)
    sectors = sd.get("data", {}).get("diff", [])
except: pass

# ============================================================
# 3. 持仓股票
# ============================================================
print("📊 拉取自选股数据...", flush=True)
stk_raw = http_get(
    "https://hq.sinajs.cn/list=sh600089,sh600584,sh601288,sz002077",
    {"Referer": "https://finance.sina.com.cn", "User-Agent": "Mozilla/5.0"}
)
stk = parse_sina(stk_raw)

STOCK_NAMES = {
    "sh600089": "特变电工", "sh600584": "长电科技",
    "sh601288": "农业银行", "sz002077": "大港股份"
}

# ============================================================
# 4. 生成报告
# ============================================================
report = f"📈 小海看盘助手 · 收盘报告\n📅 {NOW}\n"
report += "━" * 30 + "\n\n🏛️ 大盘指数\n"

for code, name in INDEX_DATA.items():
    parts = idx.get(code, [])
    if len(parts) >= 5:
        price = parts[1]
        chg = float(parts[2])
        pct = parts[3]
        arrow = "📈" if chg > 0 else "📉" if chg < 0 else "➖"
        report += f"{arrow} {name}: {price}  ({chg:+.2f} / {pct}%)\n"

report += "\n🔥 今日热门板块 Top 5\n"
for i, s in enumerate(sectors[:5]):
    report += f"{i+1}. {s.get('f14','?')} {s.get('f2','?')} ({s.get('f3',0):+.2f}%)\n"

report += "\n📦 你的持仓表现\n"
for code, name in STOCK_NAMES.items():
    parts = stk.get(code, [])
    if len(parts) >= 10:
        try:
            prev_close = float(parts[2])
            current = float(parts[3])
            high = float(parts[4])
            low = float(parts[5])
            vol = float(parts[8]) / 10000
            amt = float(parts[9]) / 100000000
            chg = current - prev_close
            pct = chg / prev_close * 100
            arrow = "📈" if chg > 0 else "📉" if chg < 0 else "➖"
            report += f"{arrow} {name}: {current:.2f}  ({chg:+.2f} / {pct:+.2f}%)\n"
            report += f"    高:{high:.2f} 低:{low:.2f}  量:{vol:.0f}万手  额:{amt:.2f}亿\n"
        except: pass

# ============================================================
# 5. DeepSeek AI 解读
# ============================================================
print("🤖 生成AI解读...", flush=True)
ai_text = "(AI解读暂不可用)"

if DEEPSEEK_KEY:
    sector_names = ", ".join([s.get("f14","") for s in sectors[:5]])
    stock_perf = ""
    for code, name in STOCK_NAMES.items():
        parts = stk.get(code, [])
        if len(parts) >= 4:
            try:
                pp = (float(parts[3]) - float(parts[2])) / float(parts[2]) * 100
                stock_perf += f"{name}: {parts[3]} ({pp:+.2f}%)\n"
            except: pass
    idx_summary = ""
    for code, name in INDEX_DATA.items():
        parts = idx.get(code, [])
        if len(parts) >= 4:
            idx_summary += f"{name}: {parts[2]} ({parts[4]}%)\n"

    prompt = f"你是一个A股复盘分析师。今天是{TODAY}。\n\n大盘概况：\n{idx_summary}\n热门板块：{sector_names}\n\n持仓表现：\n{stock_perf}\n\n请给出：\n1. 当日市场整体判断\n2. 持仓个股点评（涨跌原因、后续走势判断）\n3. 明日关注方向与操作建议\n4. 风险提示\n\n回答控制在300字以内，用中文。"

    payload = {
        "model": "deepseek-v4-flash",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 800
    }
    resp = http_post(
        "https://api.deepseek.com/v1/chat/completions",
        payload,
        {"Content-Type": "application/json", "Authorization": f"Bearer {DEEPSEEK_KEY}"}
    )
    try:
        ai_text = json.loads(resp)["choices"][0]["message"]["content"]
    except: pass

report += f"\n🤖 小海AI解读\n{ai_text}\n"

# ============================================================
# 6. 保存
# ============================================================
os.makedirs("reports", exist_ok=True)
with open(f"reports/report_{TODAY}.txt", "w", encoding="utf-8") as f:
    f.write(report)
print(f"💾 报告已保存: reports/report_{TODAY}.txt")

# ============================================================
# 7. 发送到飞书
# ============================================================
print("📲 发送到飞书...", flush=True)
if FEISHU_APP_ID and FEISHU_APP_SECRET and FEISHU_CHAT_ID:
    # 获取 token
    token_resp = http_post(
        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
        {"app_id": FEISHU_APP_ID, "app_secret": FEISHU_APP_SECRET},
        {"Content-Type": "application/json"}
    )
    try:
        token_data = json.loads(token_resp)
        access_token = token_data.get("tenant_access_token", "")
    except: access_token = ""

    if access_token:
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        # 分两段发送
        lines = report.split("\n")
        mid = len(lines) // 2
        for part_num, part in enumerate(["\n".join(lines[:mid]), "\n".join(lines[mid:])], 1):
            msg = {
                "receive_id": FEISHU_CHAT_ID,
                "msg_type": "text",
                "content": json.dumps({"text": part})
            }
            http_post(
                "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id",
                msg, headers
            )
            print(f"  ✅ 第{part_num}段已发送", flush=True)
    else:
        print("  ❌ 飞书 token 获取失败", flush=True)
else:
    print("  ⏭️ 飞书未配置，跳过发送", flush=True)

print("✅ 完成!", flush=True)
