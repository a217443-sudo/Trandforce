const fundMap = {
  allianzData: "安聯台灣科技",
  uniData: "統一奔騰"
};

const riskBias = {
  conservative: -1,
  balanced: 0,
  aggressive: 1
};

const horizonBias = {
  short: -1,
  mid: 0,
  long: 1
};

const sample = {
  allianzData: `2026-04-15,73.8
2026-04-16,74.4
2026-04-17,75.1
2026-04-18,74.9
2026-04-19,75.8
2026-04-20,76.2
2026-04-21,76.6
2026-04-22,76.1
2026-04-23,76.8
2026-04-24,77.2
2026-04-25,77.5
2026-04-26,77.1
2026-04-27,77.9
2026-04-28,78.3`,
  uniData: `2026-04-15,51.2
2026-04-16,51.5
2026-04-17,51.7
2026-04-18,51.4
2026-04-19,51.9
2026-04-20,52.3
2026-04-21,52.8
2026-04-22,52.1
2026-04-23,52.4
2026-04-24,52.0
2026-04-25,52.6
2026-04-26,52.4
2026-04-27,52.9
2026-04-28,53.1`
};

function parseCsv(text) {
  const rows = text
    .trim()
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [date, nav] = line.split(",");
      return { date, nav: Number(nav) };
    })
    .filter((r) => r.date && !Number.isNaN(r.nav));

  rows.sort((a, b) => a.date.localeCompare(b.date));
  return rows;
}

function pct(curr, prev) {
  if (!prev) return 0;
  return ((curr - prev) / prev) * 100;
}

function sma(values, period) {
  if (values.length < period) return null;
  const subset = values.slice(-period);
  return subset.reduce((sum, v) => sum + v, 0) / period;
}

function calcVolatility(values) {
  if (values.length < 6) return null;
  const returns = [];
  for (let i = 1; i < values.length; i += 1) {
    returns.push(pct(values[i], values[i - 1]));
  }
  const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
  const variance = returns.reduce((acc, r) => acc + (r - mean) ** 2, 0) / returns.length;
  return Math.sqrt(variance);
}

function calcMaxDrawdown(values) {
  let peak = values[0];
  let maxDrawdown = 0;

  values.forEach((v) => {
    if (v > peak) peak = v;
    const drawdown = ((v - peak) / peak) * 100;
    if (drawdown < maxDrawdown) maxDrawdown = drawdown;
  });

  return maxDrawdown;
}

function evaluateFund(records, risk, horizon) {
  const values = records.map((r) => r.nav);
  const latest = values.at(-1);
  const prev = values.at(-2);

  const oneDay = pct(latest, prev);
  const fiveDay = values.length > 5 ? pct(latest, values.at(-6)) : 0;
  const twentyDay = values.length > 20 ? pct(latest, values.at(-21)) : 0;

  const ma5 = sma(values, 5);
  const ma20 = sma(values, 20);
  const volatility = calcVolatility(values);
  const drawdown = calcMaxDrawdown(values);

  let score = 0;

  if (ma5 && latest > ma5) score += 1;
  if (ma20 && latest > ma20) score += 1;
  if (fiveDay > 0) score += 1;
  if (twentyDay > 0) score += 1;
  if (volatility && volatility > 1.8) score -= 1;
  if (drawdown < -10) score -= 1;

  score += riskBias[risk] + horizonBias[horizon];

  let decision = "觀望";
  let cls = "hold";

  if (score >= 3) {
    decision = "可分批投入";
    cls = "buy";
  } else if (score <= 0) {
    decision = "考慮分批贖回";
    cls = "sell";
  }

  return {
    latestDate: records.at(-1)?.date,
    latest,
    oneDay,
    fiveDay,
    twentyDay,
    ma5,
    ma20,
    volatility,
    drawdown,
    decision,
    cls,
    score
  };
}

function formatPct(value) {
  const n = Number(value || 0);
  const sign = n > 0 ? "+" : "";
  return `${sign}${n.toFixed(2)}%`;
}

function formatNum(value) {
  return Number(value || 0).toFixed(2);
}

function render(results) {
  const cards = document.getElementById("summaryCards");
  cards.innerHTML = "";

  results.forEach(({ name, data }) => {
    const oneDayClass = data.oneDay >= 0 ? "up" : "down";
    const fiveDayClass = data.fiveDay >= 0 ? "up" : "down";
    const twentyDayClass = data.twentyDay >= 0 ? "up" : "down";

    const card = document.createElement("article");
    card.className = "card";
    card.innerHTML = `
      <h3>${name}</h3>
      <p>最新日期：${data.latestDate || "N/A"}</p>
      <p><strong>最新淨值：</strong>${formatNum(data.latest)}</p>
      <p><span class="tag ${data.cls}">${data.decision}</span></p>
      <div class="metric"><span>單日漲跌</span><span class="${oneDayClass}">${formatPct(data.oneDay)}</span></div>
      <div class="metric"><span>5日漲跌</span><span class="${fiveDayClass}">${formatPct(data.fiveDay)}</span></div>
      <div class="metric"><span>20日漲跌</span><span class="${twentyDayClass}">${formatPct(data.twentyDay)}</span></div>
      <div class="metric"><span>5日均線</span><span>${formatNum(data.ma5)}</span></div>
      <div class="metric"><span>20日均線</span><span>${data.ma20 ? formatNum(data.ma20) : "資料不足"}</span></div>
      <div class="metric"><span>波動度</span><span>${data.volatility ? data.volatility.toFixed(2) : "資料不足"}</span></div>
      <div class="metric"><span>最大回撤</span><span class="${data.drawdown < 0 ? "down" : ""}">${formatPct(data.drawdown)}</span></div>
    `;

    cards.appendChild(card);
  });

  const advice = document.getElementById("globalAdvice");
  const buyCount = results.filter((r) => r.data.cls === "buy").length;
  const sellCount = results.filter((r) => r.data.cls === "sell").length;

  if (buyCount === results.length) {
    advice.textContent = "整體趨勢偏多，可採定期定額或分批加碼。仍須設定停利停損。";
  } else if (sellCount === results.length) {
    advice.textContent = "整體趨勢偏弱，建議先控管部位、分批贖回並保留現金彈性。";
  } else {
    advice.textContent = "兩檔訊號分歧，建議採中性配置：強勢基金維持定投，弱勢基金降低部位。";
  }

  document.getElementById("resultPanel").hidden = false;
}

function analyze() {
  const risk = document.getElementById("riskProfile").value;
  const horizon = document.getElementById("horizon").value;

  const results = Object.entries(fundMap).map(([id, name]) => {
    const csv = document.getElementById(id).value;
    const parsed = parseCsv(csv);

    if (parsed.length < 6) {
      throw new Error(`「${name}」資料不足，至少需要 6 筆。`);
    }

    const data = evaluateFund(parsed, risk, horizon);
    return { name, data };
  });

  render(results);
}

document.getElementById("sampleBtn").addEventListener("click", () => {
  Object.entries(sample).forEach(([id, value]) => {
    document.getElementById(id).value = value;
  });
});

document.getElementById("analyzeBtn").addEventListener("click", () => {
  try {
    analyze();
  } catch (error) {
    alert(error.message);
  }
});
