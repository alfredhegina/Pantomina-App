/*
 * PANTOMINA — interactive prototype · synced with APP_SPEC.md v2.2 (2026-08-23)
 *
 * PURPOSE: visual + interaction reference. Cursor builds the real app fresh from
 * docs/SPEC.md; this file demonstrates look, feel, copy voice, and key flows.
 * State is in-memory only (module mutation for rename is prototype-pragmatic;
 * production uses the store + computed labels per SPEC §3).
 *
 * DEMONSTRATED HERE: 5-tab IA · Receipts w/ person filter · Add sheet (category
 * + payment-method searchable pickers w/ recents, scope-driven defaults,
 * Just mine/50·50/Custom mutual-autofill split, recurring + Cookie Jar toggles,
 * Spend/Borrow) · Bills: split panel, Forecast (2 fixture cycles), Love Tab ·
 * Cookie Jar sub-ledger (running balance, unit filter, borrow/return, delete) ·
 * War Chest (fund cards, raid w/ absorb-vs-due, repay, ledger fund_move) ·
 * Empire, YTD, Accounts, Loans, Recurring · Settings (live rename, optional pet
 * names, BYO Gemini key UI, backups card, fixed roles).
 *
 * SPEC-ONLY (not in this file): Checklist view · statement-day reconciliation ·
 * projections engine · funding-plan tranches · Balance Day snapshots · AI parse
 * pipeline + Shortcut inbox · onboarding · CoA manager/migration · backup
 * serialization/restore · persistence (SQLite via Capacitor) · sync (Phase 8).
 */
import { useState, useMemo } from "react";
import {
  LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer,
  BarChart, Bar, Legend, PieChart, Pie, Cell, AreaChart, Area, CartesianGrid,
} from "recharts";

/* ─── tokens ─────────────────────────────────────────────── */
const C = {
  ground: "#FAF8F5", card: "#FDFDFC", ink: "#1D212B", muted: "#6A7181",
  border: "#E9E7E2", sage: "#498D6D", sageDeep: "#3B7157", terra: "#EF8F6C",
  terraDeep: "#D9764F", blush: "#F6DCE1", rose: "#B8405E", frame: "#EFEBE3",
};
const serif = "'Fraunces', Georgia, serif";
const sans = "'DM Sans', -apple-system, sans-serif";
const tnum = { fontVariantNumeric: "tabular-nums slashed-zero" };
const peso = (n, d = 2) =>
  "₱" + Number(n).toLocaleString("en-PH", { minimumFractionDigits: d, maximumFractionDigits: d });
const pesoS = (n) => "₱" + Math.round(n).toLocaleString("en-PH");

/* ─── icons (1.5px stroke, single weight) ────────────────── */
const I = ({ d, size = 20, color = "currentColor", fill = "none" }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color}
    strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    {d}
  </svg>
);
const ic = {
  home: <path d="M3 10.5 12 3l9 7.5V21a1 1 0 0 1-1 1h-5v-7h-6v7H4a1 1 0 0 1-1-1z" />,
  receipt: <><path d="M6 2h12v20l-2-1.5L14 22l-2-1.5L10 22l-2-1.5L6 22z" /><path d="M9.5 8h5M9.5 12h5" /></>,
  plus: <path d="M12 5v14M5 12h14" />,
  bills: <><rect x="3" y="5" width="18" height="14" rx="2" /><path d="M3 10h18M7 15h4" /></>,
  dots: <><circle cx="5" cy="12" r="1.4" /><circle cx="12" cy="12" r="1.4" /><circle cx="19" cy="12" r="1.4" /></>,
  heart: <path d="M12 20.5C7 16.5 3.5 13.3 3.5 9.6 3.5 7 5.5 5 8 5c1.6 0 3.1.8 4 2.1C12.9 5.8 14.4 5 16 5c2.5 0 4.5 2 4.5 4.6 0 3.7-3.5 6.9-8.5 10.9z" />,
  jar: <><path d="M7 6h10M8 6c-2 2.5-3 4.5-3 8a7 7 0 0 0 14 0c0-3.5-1-5.5-3-8" /><path d="M8 3.5h8v2.5H8z" /></>,
  chart: <><path d="M4 20h16" /><path d="M7 20v-6M12 20V9M17 20v-9" /></>,
  bank: <><path d="M3 9.5 12 4l9 5.5" /><path d="M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18" /></>,
  loop: <><path d="M4 12a8 8 0 0 1 14-5l2 2" /><path d="M20 4v5h-5" /><path d="M20 12a8 8 0 0 1-14 5l-2-2" /><path d="M4 20v-5h5" /></>,
  bag: <><path d="M7 8V6a5 5 0 0 1 10 0v2" /><rect x="4" y="8" width="16" height="13" rx="2" /></>,
  gear: <><circle cx="12" cy="12" r="3" /><path d="M12 2v3M12 19v3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M2 12h3M19 12h3M4.9 19.1 7 17M17 7l2.1-2.1" /></>,
  back: <path d="M15 5l-7 7 7 7" />,
  chev: <path d="M9 5l7 7-7 7" />,
  cal: <><rect x="4" y="5" width="16" height="16" rx="2" /><path d="M4 10h16M8 3v4M16 3v4" /></>,
  chest: <><rect x="3.5" y="8" width="17" height="12" rx="2" /><path d="M3.5 12.5h17M12 12.5v2.5" /><path d="M7 8V6a5 5 0 0 1 10 0v2" /></>,
};

/* ─── mock data (yes, the real-ish numbers) ──────────────── */
let YOU = { id: "you", name: "Larr", pet: null, color: C.sage, deep: C.sageDeep };
let PARTNER = { id: "partner", name: "Len", pet: null, color: C.terra, deep: C.terraDeep };
const CYCLE = "Aug 15, 2026";

const seedTxns = [
  { id: 1, date: "Aug 15", amount: 10000, type: "expense", cat: "Rent · House", paidBy: "you", alloc: { you: 5000, partner: 5000 }, fixed: true, note: "Fixed expense" },
  { id: 2, date: "Aug 15", amount: 5097.93, type: "expense", cat: "Utilities · Electricity", paidBy: "you", alloc: { you: 2548.97, partner: 2548.96 }, fixed: true },
  { id: 3, date: "Aug 15", amount: 2099, type: "expense", cat: "Utilities · Internet PLDT", paidBy: "you", alloc: { you: 1049.5, partner: 1049.5 }, fixed: true },
  { id: 4, date: "Aug 15", amount: 1000, type: "expense", cat: "Utilities · Water", paidBy: "you", alloc: { you: 500, partner: 500 }, fixed: true },
  { id: 5, date: "Aug 15", amount: 1000, type: "expense", cat: "Rent · Parking", paidBy: "you", alloc: { you: 1000, partner: 0 }, fixed: true },
  { id: 6, date: "Aug 15", amount: 231.28, type: "expense", cat: "Subscription · Spotify", paidBy: "you", alloc: { you: 115.64, partner: 115.64 }, fixed: true },
  { id: 7, date: "Aug 15", amount: 180.79, type: "expense", cat: "Subscription · iCloud", paidBy: "you", alloc: { you: 90.4, partner: 90.39 }, fixed: true },
  { id: 8, date: "Aug 15", amount: 5000, type: "transfer", cat: "Partner Contribution · Bills", paidBy: "partner", alloc: { you: 0, partner: 5000 }, settle: "contribution", note: "Contribution to 8/15/26 bills" },
  { id: 9, date: "Aug 15", amount: 7813.34, type: "transfer", cat: "Partner Receivable · Remaining", paidBy: "partner", alloc: { you: 0, partner: 7813.34 }, settle: "receivable", note: "Len's remaining balance for 8/15/26 bills" },
  { id: 10, date: "Aug 30", amount: 20000, type: "income", cat: "Salary · Len", paidBy: "partner", alloc: { you: 0, partner: 20000 } },
  { id: 11, date: "Aug 30", amount: 500, type: "savings", cat: "Pag-Ibig MP2", paidBy: "you", alloc: { you: 500, partner: 0 }, note: "Fixed Larr savings" },
  { id: 12, date: "Aug 30", amount: 500, type: "savings", cat: "Pag-Ibig MP2", paidBy: "you", alloc: { you: 0, partner: 500 }, note: "Fixed Len savings" },
  { id: 13, date: "Aug 12", amount: 700, type: "income", cat: "Cookie Jar · Internet Payment", paidBy: "you", alloc: { you: 350, partner: 350 }, jar: true, jarSrc: "404", jarKind: "income" },
  { id: 14, date: "Aug 9", amount: 500, type: "income", cat: "Cookie Jar · Laundry Payment", paidBy: "you", alloc: { you: 250, partner: 250 }, jar: true, jarSrc: "408", jarKind: "income" },
  { id: 15, date: "Aug 6", amount: 700, type: "income", cat: "Cookie Jar · Internet Payment", paidBy: "you", alloc: { you: 350, partner: 350 }, jar: true, jarSrc: "305", jarKind: "income" },
  { id: 16, date: "Jul 30", amount: 1100, type: "expense", cat: "Cookie Jar · Larr No Cash", paidBy: "you", alloc: { you: 1100, partner: 0 }, jar: true, jarSrc: "larr", jarKind: "borrow", returned: false },
  { id: 17, date: "Jul 22", amount: 200, type: "expense", cat: "Cookie Jar · Len No Cash", paidBy: "partner", alloc: { you: 0, partner: 200 }, jar: true, jarSrc: "len", jarKind: "borrow", returned: true },
  { id: 18, date: "Jul 18", amount: 1000, type: "expense", cat: "Cookie Jar · Aircon Cleaning", paidBy: "you", alloc: { you: 500, partner: 500 }, jar: true, jarKind: "spend" },
];

const tabHistory = [
  { d: "5/15", tab: 161446.66 }, { d: "5/30", tab: 165146.77 }, { d: "6/15", tab: 170899.14 },
  { d: "6/30", tab: 169612.55 }, { d: "7/15", tab: 169612.55 }, { d: "8/4", tab: 169884.47 },
  { d: "8/20", tab: 177697.81 },
];
const settleCycles = [
  { c: "Jun 15", due: 17965.78, paid: 12500, note: "partial" },
  { c: "Jun 30", due: 9800.4, paid: 11086.99, note: "overpaid" },
  { c: "Jul 15", due: 12343.36, paid: 12343.36, note: "settled" },
  { c: "Aug 4", due: 6271.92, paid: 6000, note: "partial" },
  { c: "Aug 15", due: 12813.34, paid: 5000, note: "partial" },
];
const ytd = [
  { m: "Jan", inc: 92500, exp: 61401.39 }, { m: "Feb", inc: 88400, exp: 56670.8 },
  { m: "Mar", inc: 91200, exp: 59146.51 }, { m: "Apr", inc: 90100, exp: 58857.6 },
  { m: "May", inc: 93800, exp: 55425.16 }, { m: "Jun", inc: 89700, exp: 57965.78 },
  { m: "Jul", inc: 94200, exp: 52343.36 }, { m: "Aug", inc: 90650, exp: 52813.34 },
];
const catSplit = [
  { name: "Rent", v: 11000, c: C.terra }, { name: "Utilities", v: 8196.93, c: C.terraDeep },
  { name: "Subscriptions", v: 412.07, c: C.blush }, { name: "Groceries", v: 9640.5, c: "#C9A07E" },
  { name: "Transport", v: 3120, c: "#8FA98F" },
];
const snapshots = {
  you: [
    { d: "6/15", assets: 512340.5, liab: 118200 }, { d: "6/30", assets: 517880.2, liab: 116400 },
    { d: "7/15", assets: 521002.75, liab: 114600 }, { d: "8/4", assets: 527419.4, liab: 112800 },
    { d: "8/20", assets: 538914.11, liab: 111000 },
  ],
  partner: [
    { d: "6/15", assets: 96210.3, liab: 214100.14 }, { d: "6/30", assets: 99815.6, liab: 212020.55 },
    { d: "7/15", assets: 101230.9, liab: 211112.55 }, { d: "8/4", assets: 104882.15, liab: 210934.47 },
    { d: "8/20", assets: 106540.4, liab: 217647.81 },
  ],
};
const savingsAssets = { you: 86500, partner: 21400 };
const accounts = [
  { id: 1, owner: "you", kind: "Bank", name: "BPI Debit", bal: 84213.45 },
  { id: 2, owner: "you", kind: "Savings asset", name: "Pag-Ibig MP2 *4092", bal: 2000 },
  { id: 3, owner: "you", kind: "Receivable", name: "The Love Tab (Len)", bal: 177697.81 },
  { id: 4, owner: "partner", kind: "Bank", name: "SB Debit", bal: 12480.66 },
  { id: 5, owner: "partner", kind: "E-wallet", name: "GCash", bal: 3215.2 },
  { id: 6, owner: "both", kind: "Cash", name: "House cash box", bal: 4350 },
];
const loans = [
  { owner: "partner", lender: "SSS Salary Loan", principal: 30000, bal: 18420.5, rate: "10%/yr", due: "Sep 5" },
  { owner: "partner", lender: "The Love Tab → Larr", principal: 228358.3, bal: 177697.81, rate: "0% · no rush", due: "whenever, honestly" },
  { owner: "you", lender: "BPI CC — Larr", principal: 45000, bal: 11230.75, rate: "revolving", due: "Sep 2" },
];
/* funds — personal envelopes on real accounts (§4.10). Raid order: loan_payoff → sinking → emergency */
const seedFunds = [
  { id: "payoff", name: "Loan Payoff", purpose: "loan_payoff", home: "MariBank", owner: "you",
    real: 3432.77, target: null, ious: [] },
  { id: "annulment", name: "Annulment Fund", purpose: "sinking", home: "Maya (Savings)", owner: "you",
    real: 8553.5, target: 40000, ious: [] },
  { id: "emergency", name: "Emergency Fund", purpose: "emergency", home: "SB *8459", owner: "you",
    real: 11723.46, target: 30000,
    ious: [{ date: "Jul 15", amount: 6500, reason: "Covered the Jul 15 bills gap", repaid: 0 }] },
];

/* forecast fixtures — per future cycle: expected in, committed items, typical variable (§4.5) */
const FORECASTS = {
  "Aug 30, 2026": {
    income: [{ l: "Larr payroll", v: 44750 }, { l: "Len salary", v: 20000 }],
    contribution: 5000,
    committed: [
      { l: "Child support", v: 5000, k: "fixed" },
      { l: "UB CC statement (pending swipes)", v: 18231.13, k: "card" },
      { l: "SB CC statement (pending swipes)", v: 658.24, k: "card" },
      { l: "UB Personal Loan · tranche 2/2", v: 8734.96, k: "tranche" },
      { l: "PruLife · tranche 2/2", v: 1500, k: "tranche" },
      { l: "Pag-Ibig MP2 ×2", v: 1010, k: "fixed" },
      { l: "Sinking · Annulment (Maya)", v: 500, k: "fixed" },
      { l: "Emergency Fund (SB)", v: 500, k: "fixed" },
      { l: "GoTyme savings", v: 350, k: "fixed" },
    ],
    variable: 9640, // 3-cycle average
  },
  "Sep 15, 2026": {
    income: [{ l: "Larr payroll", v: 44750 }],
    contribution: 5000,
    committed: [
      { l: "Rent, parking & water (Doc Aliwalas)", v: 11935, k: "fixed" },
      { l: "Meralco", v: 5211.4, k: "est" },
      { l: "PLDT Pasay", v: 2099, k: "fixed" },
      { l: "Child support", v: 6000, k: "fixed" },
      { l: "BPI CC statement (pending swipes)", v: 30040.87, k: "card" },
      { l: "UB Personal Loan · tranche 1/2", v: 8734.96, k: "tranche" },
      { l: "PruLife · tranche 1/2", v: 1500, k: "tranche" },
      { l: "Spotify + iCloud", v: 412.07, k: "fixed" },
    ],
    variable: 10120,
  },
};

const recurring = [
  { name: "Rent · House", amt: 10000, cad: "Monthly", owner: "both", next: "Sep 15" },
  { name: "Internet PLDT", amt: 2099, cad: "Monthly", owner: "both", next: "Sep 15" },
  { name: "Pag-Ibig MP2 ×2", amt: 1000, cad: "Monthly", owner: "both", next: "Sep 30" },
  { name: "Spotify", amt: 231.28, cad: "Monthly", owner: "both", next: "Sep 15" },
  { name: "Len salary", amt: 20000, cad: "Bi-weekly", owner: "partner", next: "Sep 15" },
];

/* ─── primitives ─────────────────────────────────────────── */
const Card = ({ children, style, pad = 16 }) => (
  <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 16,
    padding: pad, boxShadow: "0 1px 2px rgba(60,50,35,.05), 0 4px 14px rgba(60,50,35,.05)", ...style }}>
    {children}
  </div>
);
const Eyebrow = ({ children, color = C.muted }) => (
  <div style={{ fontFamily: sans, fontSize: 11, letterSpacing: "0.12em", textTransform: "uppercase",
    color, fontWeight: 600 }}>{children}</div>
);
const Title = ({ pet, plain }) => (
  <div style={{ marginBottom: 4 }}>
    <div style={{ fontFamily: serif, fontStyle: "italic", fontSize: 27, fontWeight: 550,
      color: C.ink, lineHeight: 1.1, letterSpacing: "-0.01em" }}>{pet}</div>
    <Eyebrow>{plain}</Eyebrow>
  </div>
);
const Amt = ({ v, size = 15, color = C.ink, w = 600, d = 2 }) => (
  <span style={{ ...tnum, fontFamily: sans, fontSize: size, fontWeight: w, color }}>{peso(v, d)}</span>
);
const Chip = ({ children, bg = C.blush, color = C.rose }) => (
  <span style={{ fontFamily: sans, fontSize: 11, fontWeight: 600, background: bg, color,
    borderRadius: 999, padding: "3px 9px", whiteSpace: "nowrap" }}>{children}</span>
);
const Seg = ({ value, onChange, options }) => (
  <div role="tablist" style={{ display: "flex", background: C.frame, borderRadius: 999, padding: 3, gap: 2 }}>
    {options.map((o) => (
      <button key={o.v} role="tab" aria-selected={value === o.v} onClick={() => onChange(o.v)}
        style={{ flex: 1, border: "none", cursor: "pointer", fontFamily: sans, fontSize: 12.5,
          fontWeight: 600, padding: "7px 10px", borderRadius: 999,
          background: value === o.v ? C.card : "transparent",
          color: value === o.v ? (o.c || C.ink) : C.muted,
          boxShadow: value === o.v ? "0 1px 3px rgba(60,50,35,.12)" : "none",
          transition: "background 200ms cubic-bezier(.23,1,.32,1)" }}>
        {o.l}
      </button>
    ))}
  </div>
);
const PersonDot = ({ who, size = 8 }) => (
  <span style={{ width: size, height: size, borderRadius: 99, display: "inline-block", flexShrink: 0,
    background: who === "you" ? C.sage : who === "partner" ? C.terra : `linear-gradient(90deg, ${C.sage} 50%, ${C.terra} 50%)` }} />
);
const Row = ({ children, style }) => (
  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10, ...style }}>{children}</div>
);
const tipStyle = { fontFamily: sans, fontSize: 12, borderRadius: 10, border: `1px solid ${C.border}` };

/* ─── screens ────────────────────────────────────────────── */
function Home({ go, tab }) {
  const dueLeft = 7813.34;
  const netAug = ytd[7].inc - ytd[7].exp;
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <div>
        <div style={{ fontFamily: serif, fontStyle: "italic", fontSize: 24, color: C.ink }}>
          Hi, {YOU.pet || YOU.name} & {PARTNER.pet || PARTNER.name}.
        </div>
        <div style={{ fontFamily: sans, fontSize: 13, color: C.muted }}>Sunday, Aug 23 · cycle of {CYCLE}</div>
      </div>

      <div style={{ background: `linear-gradient(135deg, ${C.sage}, ${C.sageDeep})`, borderRadius: 18,
        padding: 18, color: "#fff", boxShadow: "0 6px 20px rgba(73,141,109,.28)" }}>
        <Eyebrow color="rgba(255,255,255,.75)">Net this month · together</Eyebrow>
        <div style={{ ...tnum, fontFamily: sans, fontSize: 32, fontWeight: 700, margin: "4px 0 10px" }}>{pesoS(netAug)}</div>
        <Row>
          <span style={{ fontFamily: sans, fontSize: 12.5, opacity: 0.9 }}>In {pesoS(ytd[7].inc)} · Out {pesoS(ytd[7].exp)}</span>
          <Chip bg="rgba(255,255,255,.18)" color="#fff">Aug 2026</Chip>
        </Row>
      </div>

      <Card>
        <Row style={{ marginBottom: 8 }}>
          <Eyebrow>The Love Tab</Eyebrow>
          <button onClick={() => go("bills")} style={{ border: "none", background: "none", cursor: "pointer", color: C.rose, fontFamily: sans, fontSize: 12.5, fontWeight: 600 }}>
            settle up →
          </button>
        </Row>
        <Row>
          <div>
            <Amt v={tab} size={24} w={700} />
            <div style={{ fontFamily: sans, fontSize: 12.5, color: C.muted, marginTop: 2 }}>
              {PARTNER.name}'s running balance to {YOU.name}
            </div>
          </div>
          <span style={{ color: C.rose }}><I d={ic.heart} size={26} fill={C.blush} color={C.rose} /></span>
        </Row>
      </Card>

      <Card>
        <Row style={{ marginBottom: 6 }}>
          <Eyebrow>Whose turn is it</Eyebrow>
          <Chip>{peso(dueLeft)} still open</Chip>
        </Row>
        <div style={{ fontFamily: sans, fontSize: 13.5, color: C.ink }}>
          {PARTNER.name} contributed {peso(5000)} of {peso(12813.34)} this cycle. {YOU.name}'s got the rest — say thank you.
        </div>
      </Card>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        {[
          { k: "empire", i: ic.chart, t: "Our Little Empire", s: "Net worth" },
          { k: "jar", i: ic.jar, t: "The Cookie Jar", s: "Petty cash" },
          { k: "ytd", i: ic.cal, t: "Our Year So Far", s: "YTD summary" },
          { k: "loans", i: ic.bag, t: "Baggage", s: "Loans" },
        ].map((x) => (
          <button key={x.k} onClick={() => go("more", x.k)} style={{ textAlign: "left", cursor: "pointer",
            background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, padding: 12,
            display: "flex", gap: 10, alignItems: "center" }}>
            <span style={{ color: C.sageDeep, background: "rgba(73,141,109,.1)", borderRadius: 10, padding: 7, display: "flex" }}>
              <I d={x.i} size={18} />
            </span>
            <span>
              <div style={{ fontFamily: serif, fontStyle: "italic", fontSize: 14.5, color: C.ink }}>{x.t}</div>
              <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>{x.s}</div>
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

function Receipts({ txns }) {
  const [who, setWho] = useState("both");
  const list = txns.filter((t) => who === "both" || t.paidBy === who || t.alloc[who] > 0);
  const dates = [...new Set(list.map((t) => t.date))];
  const typeColor = { income: C.sageDeep, expense: C.terraDeep, transfer: C.rose, savings: C.sageDeep, sinking: C.muted };
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="The Receipts" plain="Ledger · daily + scheduled" />
      <Seg value={who} onChange={setWho} options={[
        { v: "you", l: YOU.name, c: C.sageDeep }, { v: "partner", l: PARTNER.name, c: C.terraDeep }, { v: "both", l: "Both" }]} />
      {dates.map((d) => (
        <div key={d}>
          <Eyebrow>{d} · 2026</Eyebrow>
          <Card pad={0} style={{ marginTop: 6 }}>
            {list.filter((t) => t.date === d).map((t, i, arr) => (
              <div key={t.id} style={{ padding: "11px 14px", borderBottom: i < arr.length - 1 ? `1px solid ${C.border}` : "none" }}>
                <Row>
                  <div style={{ display: "flex", gap: 9, alignItems: "center", flex: 1, minWidth: 0 }}>
                    <PersonDot who={t.paidBy} />
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink, lineHeight: 1.3 }}>{t.cat}</div>
                      <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>
                        {t.type}{t.settle ? ` · ${t.settle}` : ""}{t.jar ? " · cookie jar" : ""}{t.note ? ` · ${t.note}` : ""}
                      </div>
                    </div>
                  </div>
                  <span style={{ flexShrink: 0 }}><Amt v={t.amount} color={typeColor[t.type]} /></span>
                </Row>
              </div>
            ))}
          </Card>
        </div>
      ))}
      {list.length === 0 && (
        <Card><div style={{ fontFamily: sans, fontSize: 13.5, color: C.muted, textAlign: "center" }}>
          Nothing here yet. Rare quiet moment.
        </div></Card>
      )}
    </div>
  );
}

/* category catalog (subset of the real chart of accounts, grouped) */
const CATEGORIES = [
  "Groceries · Household", "Wants · Eat out", "Wants · Food Deliveries", "Wants · Grab Taxi",
  "Wants · Coffee", "Utilities · Electricity", "Utilities · Electricity (Magarao)", "Utilities · Water",
  "Utilities · Internet PLDT", "Utilities · Prepaid Load", "Rent · House", "Rent · Parking",
  "Subscription · Netflix", "Subscription · Spotify", "Subscription · iCloud", "Commute · Commute",
  "Food · Ulam", "Medical · Household", "Supplements · Household", "Fitness · Home Gym",
  "Motorcycle · Gas", "Motorcycle · Maintenance", "Child Support · Allowance", "Child Support · Tuition",
  "Papa · Medicines", "Magarao · Other Needs", "Home · Maintenance", "Insurance · PruLife",
  "Salary · Larr", "Salary · Len", "Funds · Contributions to Bills", "Funds · Petty Cash",
  "Projects · Pag-Ibig MP2", "Savings · Emergency Funds", "Loan · BPI Credit to Cash",
  "Wants · Shopee", "Wants · Lazada", "Wants · Gifts", "Travels · General", "Allowance · Self",
];

/* payment methods (the 26 accounts) — suffix decodes to scope; kind decodes settlement */
const PAYMENT_METHODS = [
  "BPI CC", "BPI CC-Larr", "SB Next CC", "SB Next CC-Len", "SB Next CC-Larr",
  "BDO JCB CC", "BDO JCB CC-Len", "BDO JCB CC-Larr", "UB CC", "UB CC-Larr",
  "SB CC", "SB CC-Larr", "Cash", "Cash-Len", "Cash-Larr", "Gcash", "Gcash-Len",
  "Gcash-Larr", "Maya", "Maya-Len", "Maya-Larr", "BPI Debit", "BPI Debit-Larr",
  "SB Debit", "SB Debit-Larr", "SB Debit-Len",
].map((name) => {
  const scope = /-Larr$/i.test(name) ? "larr" : /-Len$/i.test(name) ? "len" : "household";
  const base = name.replace(/\s*-\s*(Larr|Len)$/i, "");
  const settlement = /CC$/i.test(base) ? "statement" : "instant"; // CC → pending; else anchor-snap
  return { name, scope, settlement, base };
});

function ScopeTag({ scope }) {
  const map = { larr: [YOU.name, C.sageDeep], len: [PARTNER.name, C.terraDeep], household: ["Shared", C.rose] };
  const [label, color] = map[scope];
  return <Chip bg={C.frame} color={color}>{label}</Chip>;
}

function PaymentPicker({ value, onChange, recents, onPick }) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const field = { width: "100%", boxSizing: "border-box", fontFamily: sans, fontSize: 14, padding: "10px 12px",
    borderRadius: 12, border: `1px solid ${C.border}`, background: C.card, color: C.ink, outline: "none" };
  const ql = q.trim().toLowerCase();
  const match = (m) => m.name.toLowerCase().includes(ql);
  const filtered = PAYMENT_METHODS.filter(match);
  const recentHits = recents.map((n) => PAYMENT_METHODS.find((m) => m.name === n)).filter(Boolean).filter(match);
  const groups = { household: [], larr: [], len: [] };
  filtered.forEach((m) => groups[m.scope].push(m));
  const groupLabel = { household: "Shared", larr: `${YOU.name} — personal`, len: `${PARTNER.name} — personal` };
  const pick = (m) => { onChange(m); onPick(m.name); setOpen(false); setQ(""); };
  const Rowb = ({ m, k }) => (
    <button key={k} onClick={() => pick(m)} style={{ width: "100%", textAlign: "left", border: "none",
      background: "none", cursor: "pointer", padding: "9px 10px", borderRadius: 8, display: "flex",
      justifyContent: "space-between", alignItems: "center", gap: 8 }}
      onMouseEnter={(e) => (e.currentTarget.style.background = C.frame)}
      onMouseLeave={(e) => (e.currentTarget.style.background = "none")}>
      <span style={{ fontFamily: sans, fontSize: 13.5, color: C.ink }}>{m.name}</span>
      <span style={{ display: "flex", gap: 5, alignItems: "center" }}>
        {m.settlement === "statement" && <Chip bg={C.blush} color={C.rose}>statement</Chip>}
        <ScopeTag scope={m.scope} />
      </span>
    </button>
  );
  return (
    <div style={{ display: "grid", gap: 4, position: "relative" }}>
      <Eyebrow>Payment method</Eyebrow>
      <button onClick={() => setOpen(!open)} style={{ ...field, textAlign: "left", cursor: "pointer",
        color: value ? C.ink : C.muted, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <span>{value ? value.name : "Choose a card, cash, or wallet…"}</span>
        <span style={{ display: "flex", gap: 6, alignItems: "center" }}>
          {value && <ScopeTag scope={value.scope} />}
          <span style={{ color: C.muted, transform: open ? "rotate(90deg)" : "none", transition: "transform 200ms cubic-bezier(.23,1,.32,1)" }}>
            <I d={ic.chev} size={15} />
          </span>
        </span>
      </button>
      {open && (
        <div className="sheetUp" style={{ position: "absolute", top: "100%", left: 0, right: 0, zIndex: 6, marginTop: 6,
          background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, boxShadow: "0 10px 30px rgba(60,50,35,.16)",
          maxHeight: 300, overflow: "hidden", display: "flex", flexDirection: "column" }}>
          <div style={{ padding: 8, borderBottom: `1px solid ${C.border}` }}>
            <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="Type to filter…"
              style={{ ...field, fontSize: 13.5 }} />
          </div>
          <div style={{ overflowY: "auto", padding: 6 }}>
            {recentHits.length > 0 && (
              <>
                <div style={{ padding: "4px 10px" }}><Eyebrow color={C.rose}>Recent</Eyebrow></div>
                {recentHits.map((m) => <Rowb key={"r" + m.name} m={m} k={"r" + m.name} />)}
                <div style={{ height: 1, background: C.border, margin: "6px 0" }} />
              </>
            )}
            {filtered.length === 0 && (
              <div style={{ padding: "12px 10px", fontFamily: sans, fontSize: 13, color: C.muted }}>No match.</div>
            )}
            {["household", "larr", "len"].map((g) => groups[g].length > 0 && (
              <div key={g}>
                <div style={{ padding: "6px 10px 2px" }}><Eyebrow>{groupLabel[g]}</Eyebrow></div>
                {groups[g].map((m) => <Rowb key={m.name} m={m} k={m.name} />)}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function CategoryPicker({ value, onChange, recents, onPick }) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const field = { width: "100%", boxSizing: "border-box", fontFamily: sans, fontSize: 14, padding: "10px 12px",
    borderRadius: 12, border: `1px solid ${C.border}`, background: C.card, color: C.ink, outline: "none" };
  const ql = q.trim().toLowerCase();
  const match = (c) => c.toLowerCase().includes(ql);
  const filtered = CATEGORIES.filter(match);
  const recentHits = recents.filter(match);
  const groups = {};
  filtered.forEach((c) => { const g = c.split(" · ")[0]; (groups[g] ||= []).push(c); });
  const pick = (c) => { onChange(c); onPick(c); setOpen(false); setQ(""); };
  const rowStyle = { width: "100%", textAlign: "left", border: "none", background: "none", cursor: "pointer",
    fontFamily: sans, fontSize: 13.5, color: C.ink, padding: "9px 10px", borderRadius: 8 };
  return (
    <div style={{ display: "grid", gap: 4, position: "relative" }}>
      <Eyebrow>Category</Eyebrow>
      <button onClick={() => setOpen(!open)} style={{ ...field, textAlign: "left", cursor: "pointer",
        color: value ? C.ink : C.muted, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        {value || "Search a category…"}
        <span style={{ color: C.muted, transform: open ? "rotate(90deg)" : "none", transition: "transform 200ms cubic-bezier(.23,1,.32,1)" }}>
          <I d={ic.chev} size={15} />
        </span>
      </button>
      {open && (
        <div className="sheetUp" style={{ position: "absolute", top: "100%", left: 0, right: 0, zIndex: 5, marginTop: 6,
          background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, boxShadow: "0 10px 30px rgba(60,50,35,.16)",
          maxHeight: 300, overflow: "hidden", display: "flex", flexDirection: "column" }}>
          <div style={{ padding: 8, borderBottom: `1px solid ${C.border}` }}>
            <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="Type to filter…"
              style={{ ...field, fontSize: 13.5 }} />
          </div>
          <div style={{ overflowY: "auto", padding: 6 }}>
            {ql === "" && recents.length > 0 && (
              <>
                <div style={{ padding: "4px 10px" }}><Eyebrow color={C.rose}>Recent</Eyebrow></div>
                {recents.map((c) => (
                  <button key={"r" + c} onClick={() => pick(c)} style={rowStyle}
                    onMouseEnter={(e) => (e.currentTarget.style.background = C.frame)}
                    onMouseLeave={(e) => (e.currentTarget.style.background = "none")}>{c}</button>
                ))}
                <div style={{ height: 1, background: C.border, margin: "6px 0" }} />
              </>
            )}
            {ql !== "" && recentHits.length > 0 && (
              <>
                <div style={{ padding: "4px 10px" }}><Eyebrow color={C.rose}>Recent</Eyebrow></div>
                {recentHits.map((c) => (
                  <button key={"rh" + c} onClick={() => pick(c)} style={rowStyle}
                    onMouseEnter={(e) => (e.currentTarget.style.background = C.frame)}
                    onMouseLeave={(e) => (e.currentTarget.style.background = "none")}>{c}</button>
                ))}
                <div style={{ height: 1, background: C.border, margin: "6px 0" }} />
              </>
            )}
            {Object.keys(groups).length === 0 && (
              <div style={{ padding: "12px 10px", fontFamily: sans, fontSize: 13, color: C.muted }}>
                No match. You can type it in as a new one.
              </div>
            )}
            {Object.entries(groups).map(([g, items]) => (
              <div key={g}>
                <div style={{ padding: "6px 10px 2px" }}><Eyebrow>{g}</Eyebrow></div>
                {items.map((c) => (
                  <button key={c} onClick={() => pick(c)} style={rowStyle}
                    onMouseEnter={(e) => (e.currentTarget.style.background = C.frame)}
                    onMouseLeave={(e) => (e.currentTarget.style.background = "none")}>
                    {c.split(" · ")[1] || c}
                  </button>
                ))}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function AddSheet({ onClose, onSave }) {
  const [amt, setAmt] = useState("");
  const [type, setType] = useState("expense");
  const [cat, setCat] = useState("");
  const [recents, setRecents] = useState(["Groceries · Household", "Wants · Eat out", "Utilities · Electricity"]);
  const bumpRecent = (c) => setRecents((r) => [c, ...r.filter((x) => x !== c)].slice(0, 5));
  const [pm, setPm] = useState(null);
  const [pmRecents, setPmRecents] = useState(["BDO JCB CC", "Cash-Larr", "Gcash"]);
  const bumpPm = (n) => setPmRecents((r) => [n, ...r.filter((x) => x !== n)].slice(0, 5));
  const pickPm = (m) => {
    setPm(m);
    // scope-driven defaults (§4.4): personal → just mine; shared → 50·50
    if (m.scope === "larr") { setPaidBy("you"); setAlloc("mine"); }
    else if (m.scope === "len") { setPaidBy("partner"); setAlloc("mine"); }
    else setAlloc("half");
    bumpPm(m.name);
  };
  const [paidBy, setPaidBy] = useState("you");
  const [alloc, setAlloc] = useState("half");
  const [customYou, setCustomYou] = useState("");
  const [customPartner, setCustomPartner] = useState("");
  const [rec, setRec] = useState(false);
  const [jar, setJar] = useState(false);
  const [borrow, setBorrow] = useState(false);
  const [cad, setCad] = useState("Bi-weekly");
  const a = Number(amt) || 0;
  const cy = Number(customYou) || 0;
  const cp = Number(customPartner) || 0;
  // edit either field; the other auto-fills to the remainder
  const setYou = (v) => { setCustomYou(v);
    const n = Number(v); if (v !== "" && !isNaN(n)) setCustomPartner(String(+Math.max(a - n, 0).toFixed(2))); };
  const setPartner = (v) => { setCustomPartner(v);
    const n = Number(v); if (v !== "" && !isNaN(n)) setCustomYou(String(+Math.max(a - n, 0).toFixed(2))); };
  const customSum = +(cy + cp).toFixed(2);
  const customValid = alloc !== "custom" || (cy >= 0 && cp >= 0 && Math.abs(customSum - a) < 0.005);
  const ok = a > 0 && cat.trim() && pm && customValid;
  const field = { width: "100%", boxSizing: "border-box", fontFamily: sans, fontSize: 14, padding: "10px 12px",
    borderRadius: 12, border: `1px solid ${C.border}`, background: C.card, color: C.ink, outline: "none" };
  return (
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(29,33,43,.35)", zIndex: 30, display: "flex", alignItems: "flex-end" }}>
      <div onClick={(e) => e.stopPropagation()} className="sheetUp" style={{ background: C.ground, width: "100%",
        borderRadius: "22px 22px 0 0", padding: "10px 18px 24px", boxShadow: "0 -8px 30px rgba(60,50,35,.18)" }}>
        <div style={{ width: 38, height: 4, background: C.border, borderRadius: 99, margin: "0 auto 12px" }} />
        <Title pet="Add to the pile" plain="New entry" />
        <div style={{ display: "grid", gap: 10, marginTop: 10 }}>
          <label style={{ display: "grid", gap: 4 }}>
            <Eyebrow>Amount (₱)</Eyebrow>
            <input inputMode="decimal" value={amt} onChange={(e) => setAmt(e.target.value)} placeholder="0.00"
              style={{ ...field, ...tnum, fontSize: 22, fontWeight: 700 }} />
          </label>
          <div style={{ display: "grid", gap: 4 }}>
            <Eyebrow>Type</Eyebrow>
            <Seg value={type} onChange={setType} options={[
              { v: "expense", l: "Expense", c: C.terraDeep }, { v: "income", l: "Income", c: C.sageDeep },
              { v: "transfer", l: "Transfer" }, { v: "savings", l: "Savings" }]} />
          </div>
          <CategoryPicker value={cat} onChange={setCat} recents={recents} onPick={bumpRecent} />
          <PaymentPicker value={pm} onChange={pickPm} recents={pmRecents} onPick={() => {}} />
          {pm && (
            <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, marginTop: -4 }}>
              {pm.settlement === "statement"
                ? "Credit card — counts on the 15th or 30th, once you've confirmed the statement."
                : "Counts right away, on this half-month's 15th or 30th."}
            </div>
          )}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            <div style={{ display: "grid", gap: 4 }}>
              <Eyebrow>Paid by</Eyebrow>
              <Seg value={paidBy} onChange={setPaidBy} options={[
                { v: "you", l: YOU.name, c: C.sageDeep }, { v: "partner", l: PARTNER.name, c: C.terraDeep }]} />
            </div>
            <div style={{ display: "grid", gap: 4 }}>
              <Eyebrow>Whose is it</Eyebrow>
              <Seg value={alloc} onChange={(v) => {
                if (v === "custom" && customYou === "" && customPartner === "" && a > 0) {
                  setCustomYou(String(+(a / 2).toFixed(2)));
                  setCustomPartner(String(+(a - +(a / 2).toFixed(2)).toFixed(2)));
                }
                setAlloc(v);
              }} options={[
                { v: "mine", l: "Just mine" }, { v: "half", l: "50·50", c: C.rose }, { v: "custom", l: "Custom" }]} />
            </div>
          </div>
          {alloc === "custom" && (
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              <label style={{ display: "grid", gap: 4 }}>
                <span style={{ fontFamily: sans, fontSize: 11, color: C.sageDeep, fontWeight: 600 }}>{YOU.name}'s share</span>
                <input inputMode="decimal" value={customYou} onChange={(e) => setYou(e.target.value)}
                  placeholder="0.00" style={{ ...field, ...tnum, borderColor: customValid ? C.border : C.terraDeep }} />
              </label>
              <label style={{ display: "grid", gap: 4 }}>
                <span style={{ fontFamily: sans, fontSize: 11, color: C.terraDeep, fontWeight: 600 }}>{PARTNER.name}'s share</span>
                <input inputMode="decimal" value={customPartner} onChange={(e) => setPartner(e.target.value)}
                  placeholder="0.00" style={{ ...field, ...tnum, borderColor: customValid ? C.border : C.terraDeep }} />
              </label>
              <div style={{ gridColumn: "1 / -1", fontFamily: sans, fontSize: 11,
                color: customValid ? C.muted : C.terraDeep }}>
                {customValid ? `Splits ${peso(cy)} + ${peso(cp)} = ${peso(a)}`
                  : `Shares add to ${peso(customSum)} — needs to equal ${peso(a)}.`}
              </div>
            </div>
          )}
          <Card pad={12}>
            <Row>
              <div>
                <div style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>Make it a habit</div>
                <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>Repeats as a recurring rule</div>
              </div>
              <button aria-pressed={rec} onClick={() => setRec(!rec)} style={{ width: 46, height: 27, borderRadius: 99, border: "none",
                cursor: "pointer", background: rec ? C.sage : C.border, position: "relative",
                transition: "background 200ms cubic-bezier(.23,1,.32,1)" }}>
                <span style={{ position: "absolute", top: 3, left: rec ? 22 : 3, width: 21, height: 21, borderRadius: 99,
                  background: "#fff", boxShadow: "0 1px 3px rgba(0,0,0,.2)", transition: "left 200ms cubic-bezier(.23,1,.32,1)" }} />
              </button>
            </Row>
            {rec && (
              <div style={{ marginTop: 10 }}>
                <Seg value={cad} onChange={setCad} options={[{ v: "Bi-weekly", l: "Bi-weekly" }, { v: "Monthly", l: "Monthly" }]} />
              </div>
            )}
            <Row style={{ marginTop: 12, borderTop: `1px solid ${C.border}`, paddingTop: 12 }}>
              <div>
                <div style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>From the Cookie Jar</div>
                <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>Petty cash — side income & small dips</div>
              </div>
              <button aria-pressed={jar} onClick={() => setJar(!jar)} style={{ width: 46, height: 27, borderRadius: 99, border: "none",
                cursor: "pointer", background: jar ? C.rose : C.border, position: "relative",
                transition: "background 200ms cubic-bezier(.23,1,.32,1)" }}>
                <span style={{ position: "absolute", top: 3, left: jar ? 22 : 3, width: 21, height: 21, borderRadius: 99,
                  background: "#fff", boxShadow: "0 1px 3px rgba(0,0,0,.2)", transition: "left 200ms cubic-bezier(.23,1,.32,1)" }} />
              </button>
            </Row>
            {jar && type === "expense" && (
              <div style={{ marginTop: 8, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <span style={{ fontFamily: sans, fontSize: 12, color: C.muted }}>Expected back? (a borrow, not a spend)</span>
                <Seg value={borrow ? "y" : "n"} onChange={(v) => setBorrow(v === "y")}
                  options={[{ v: "n", l: "Spend" }, { v: "y", l: "Borrow", c: C.rose }]} />
              </div>
            )}
          </Card>
          <button disabled={!ok} onClick={() => {
            onSave({ id: Date.now(), date: "Aug 23", amount: a, type, cat: cat.trim(), paidBy,
              pm: pm.name, scope: pm.scope,
              pending: pm.settlement === "statement", jar,
              jarKind: jar ? (type === "income" ? "income" : borrow ? "borrow" : "spend") : undefined,
              returned: jar && borrow && type === "expense" ? false : undefined,
              alloc: alloc === "half" ? { you: a / 2, partner: a / 2 }
                : alloc === "mine" ? { you: paidBy === "you" ? a : 0, partner: paidBy === "partner" ? a : 0 }
                : { you: cy, partner: cp },
              rec: rec ? cad : null });
          }} style={{ border: "none", cursor: ok ? "pointer" : "default", opacity: ok ? 1 : 0.45,
            background: C.sage, color: "#fff", fontFamily: sans, fontSize: 15, fontWeight: 700,
            padding: "13px", borderRadius: 999, transition: "opacity 200ms" }}>
            Save entry
          </button>
        </div>
      </div>
    </div>
  );
}

function Bills({ tab }) {
  const [view, setView] = useState("split");
  const [fCycle, setFCycle] = useState("Aug 30, 2026");
  const cur = settleCycles[settleCycles.length - 1];
  const remaining = Math.max(cur.due - cur.paid, 0);
  const pct = Math.min(cur.paid / cur.due, 1);
  const status = cur.paid >= cur.due ? (cur.paid > cur.due ? "Overpaid" : "Settled") : "Partial";
  const fixed = seedTxns.filter((t) => t.fixed);
  const perPerson = [
    { name: YOU.name, Fixed: fixed.reduce((s, t) => s + t.alloc.you, 0), Variable: 6420.5 },
    { name: PARTNER.name, Fixed: fixed.reduce((s, t) => s + t.alloc.partner, 0), Variable: 3510.84 },
  ];
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="Whose Turn Is It" plain={`Bills due · cycle of ${CYCLE}`} />
      <Seg value={view} onChange={setView} options={[{ v: "split", l: "The split" }, { v: "forecast", l: "Forecast" }, { v: "tab", l: "The Love Tab", c: C.rose }]} />

      {view === "split" && (
        <>
          <Card style={{ borderColor: C.blush, background: "#FDF7F8" }}>
            <Row style={{ marginBottom: 8 }}>
              <Eyebrow color={C.rose}>Settle up · {PARTNER.name} → {YOU.name}</Eyebrow>
              <Chip bg={status === "Partial" ? C.blush : "rgba(73,141,109,.14)"} color={status === "Partial" ? C.rose : C.sageDeep}>{status}</Chip>
            </Row>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8, marginBottom: 10 }}>
              {[[`${PARTNER.name}'s share`, cur.due], ["Sent over", cur.paid], ["Still open", remaining]].map(([l, v]) => (
                <div key={l}>
                  <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>{l}</div>
                  <Amt v={v} size={14.5} />
                </div>
              ))}
            </div>
            <div aria-hidden="true" style={{ height: 8, borderRadius: 99, background: C.blush, overflow: "hidden" }}>
              <div style={{ width: `${pct * 100}%`, height: "100%", background: C.rose, borderRadius: 99,
                transition: "width 400ms cubic-bezier(.23,1,.32,1)" }} />
            </div>
            <div style={{ fontFamily: sans, fontSize: 12, color: C.muted, marginTop: 8 }}>
              The rest joins the tab. No interest between sweethearts — anything extra just shrinks it.
            </div>
          </Card>

          <Card>
            <Eyebrow>Fixed · this cycle</Eyebrow>
            <div style={{ marginTop: 6 }}>
              {fixed.map((t, i) => (
                <Row key={t.id} style={{ padding: "8px 0", borderBottom: i < fixed.length - 1 ? `1px solid ${C.border}` : "none" }}>
                  <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                    <PersonDot who={t.alloc.you && t.alloc.partner ? "both" : t.alloc.you ? "you" : "partner"} />
                    <span style={{ fontFamily: sans, fontSize: 13.5, color: C.ink }}>{t.cat}</span>
                  </div>
                  <Amt v={t.amount} w={500} />
                </Row>
              ))}
            </div>
          </Card>

          <Card>
            <Eyebrow>Fixed vs variable · per person</Eyebrow>
            <div style={{ height: 170, marginTop: 8 }}>
              <ResponsiveContainer>
                <BarChart data={perPerson} barSize={34}>
                  <CartesianGrid vertical={false} stroke={C.border} />
                  <XAxis dataKey="name" tick={{ fontFamily: sans, fontSize: 12, fill: C.muted }} axisLine={false} tickLine={false} />
                  <YAxis hide />
                  <Tooltip formatter={(v) => peso(v)} contentStyle={tipStyle} />
                  <Legend wrapperStyle={{ fontFamily: sans, fontSize: 12 }} />
                  <Bar dataKey="Fixed" stackId="a" fill={C.sage} radius={[0, 0, 6, 6]} />
                  <Bar dataKey="Variable" stackId="a" fill={C.terra} radius={[6, 6, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>
        </>
      )}

      {view === "forecast" && (() => {
        const cycles = Object.keys(FORECASTS);
        const f = FORECASTS[fCycle] || FORECASTS[cycles[0]];
        const inTotal = f.income.reduce((s, i) => s + i.v, 0) + f.contribution;
        const committed = f.committed.reduce((s, i) => s + i.v, 0);
        const room = inTotal - committed - f.variable;
        const over = room < 0;
        const kChip = { fixed: ["fixed", C.frame, C.muted], est: ["estimate", C.frame, C.muted],
          card: ["card lands here", C.blush, C.rose], tranche: ["tranche", "rgba(73,141,109,.14)", C.sageDeep] };
        return (
          <>
            <Seg value={fCycle} onChange={setFCycle} options={cycles.map((c) => ({ v: c, l: c.replace(", 2026", "") }))} />
            <Card style={{ textAlign: "center", borderColor: over ? "#F3C8C8" : C.border,
              background: over ? "#FDF6F6" : C.card }}>
              <Eyebrow color={over ? C.terraDeep : C.sageDeep}>{fCycle}</Eyebrow>
              <div style={{ marginTop: 2 }}>
                <Amt v={Math.abs(room)} size={28} w={700} color={over ? C.terraDeep : C.sageDeep} d={0} />
              </div>
              <div style={{ fontFamily: sans, fontSize: 12.5, fontWeight: 600, color: over ? C.terraDeep : C.sageDeep }}>
                {over ? "over — cover it from a fund, or trim" : "breathing room"}
              </div>
              <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, marginTop: 2 }}>
                in {peso(inTotal, 0)} − committed {peso(committed, 0)} − typical variable {peso(f.variable, 0)}
              </div>
            </Card>
            <Card pad={0}>
              <div style={{ padding: "12px 14px 4px" }}><Eyebrow>Expected in</Eyebrow></div>
              {[...f.income, { l: `${PARTNER.name}'s contribution`, v: f.contribution }].map((i, idx, arr) => (
                <Row key={i.l} style={{ padding: "9px 14px", borderBottom: idx < arr.length - 1 ? `1px solid ${C.border}` : "none" }}>
                  <span style={{ fontFamily: sans, fontSize: 13.5, color: C.ink }}>{i.l}</span>
                  <Amt v={i.v} color={C.sageDeep} w={500} d={0} />
                </Row>
              ))}
            </Card>
            <Card pad={0}>
              <div style={{ padding: "12px 14px 4px" }}><Eyebrow>Spoken for · nothing booked yet</Eyebrow></div>
              {f.committed.map((i, idx) => (
                <Row key={i.l} style={{ padding: "9px 14px", borderBottom: idx < f.committed.length - 1 ? `1px solid ${C.border}` : "none" }}>
                  <span style={{ display: "flex", gap: 6, alignItems: "center", flexWrap: "wrap", flex: 1, minWidth: 0 }}>
                    <span style={{ fontFamily: sans, fontSize: 13, color: C.ink, lineHeight: 1.3 }}>{i.l}</span>
                    <Chip bg={kChip[i.k][1]} color={kChip[i.k][2]}>{kChip[i.k][0]}</Chip>
                  </span>
                  <span style={{ flexShrink: 0 }}><Amt v={i.v} w={500} /></span>
                </Row>
              ))}
              <Row style={{ padding: "10px 14px", borderTop: `1px solid ${C.border}` }}>
                <span style={{ fontFamily: sans, fontSize: 13, fontWeight: 700, color: C.ink }}>+ typical variable (3-cycle avg)</span>
                <Amt v={f.variable} w={600} d={0} />
              </Row>
            </Card>
            <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, textAlign: "center" }}>
              None of this is spent yet — it becomes real when the cycle arrives.
            </div>
          </>
        );
      })()}

      {view === "tab" && (
        <>
          <Card style={{ textAlign: "center", borderColor: C.blush }}>
            <span style={{ color: C.rose }}><I d={ic.heart} size={22} fill={C.blush} color={C.rose} /></span>
            <div style={{ marginTop: 4 }}><Amt v={tab} size={28} w={700} /></div>
            <div style={{ fontFamily: sans, fontSize: 12.5, color: C.muted }}>
              {PARTNER.name} owes {YOU.name} — it cancels out when you look at the two of you together
            </div>
          </Card>
          <Card>
            <Eyebrow>The tab over time</Eyebrow>
            <div style={{ height: 160, marginTop: 8 }}>
              <ResponsiveContainer>
                <AreaChart data={tabHistory}>
                  <defs>
                    <linearGradient id="tabg" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={C.rose} stopOpacity={0.22} />
                      <stop offset="100%" stopColor={C.rose} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="d" tick={{ fontFamily: sans, fontSize: 11, fill: C.muted }} axisLine={false} tickLine={false} />
                  <YAxis hide domain={["dataMin - 4000", "dataMax + 4000"]} />
                  <Tooltip formatter={(v) => peso(v)} contentStyle={tipStyle} />
                  <Area dataKey="tab" stroke={C.rose} strokeWidth={2} fill="url(#tabg)" name="Tab" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </Card>
          <Card pad={0}>
            <div style={{ padding: "12px 14px 4px" }}><Eyebrow>Cycle history</Eyebrow></div>
            {settleCycles.slice().reverse().map((s, i, arr) => (
              <div key={s.c} style={{ padding: "10px 14px", borderBottom: i < arr.length - 1 ? `1px solid ${C.border}` : "none" }}>
                <Row>
                  <div>
                    <div style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>{s.c}</div>
                    <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>
                      due {peso(s.due)} · sent {peso(s.paid)}
                    </div>
                  </div>
                  <Chip bg={s.note === "partial" ? C.blush : "rgba(73,141,109,.14)"}
                    color={s.note === "partial" ? C.rose : C.sageDeep}>
                    {s.note === "partial" ? `+${peso(s.due - s.paid)}` : s.note === "overpaid" ? `−${peso(s.paid - s.due)}` : "settled"}
                  </Chip>
                </Row>
              </div>
            ))}
          </Card>
        </>
      )}
    </div>
  );
}

function Empire() {
  const [who, setWho] = useState("you");
  const snaps = who === "both"
    ? snapshots.you.map((s, i) => ({ d: s.d, assets: s.assets + snapshots.partner[i].assets - (i === 4 ? 177697.81 : tabHistory[i + 2].tab), liab: s.liab + snapshots.partner[i].liab - (i === 4 ? 177697.81 : tabHistory[i + 2].tab) }))
    : snapshots[who];
  const cur = snaps[snaps.length - 1], prev = snaps[snaps.length - 2];
  const nw = cur.assets - cur.liab, pnw = prev.assets - prev.liab;
  const sav = who === "both" ? savingsAssets.you + savingsAssets.partner : savingsAssets[who];
  const up = nw - pnw >= 0;
  const data = snaps.map((s) => ({ d: s.d, "Net worth": +(s.assets - s.liab).toFixed(2) }));
  const M = ({ l, v, delta }) => (
    <div>
      <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>{l}</div>
      <Amt v={v} size={14} d={0} color={delta === undefined ? C.ink : v >= 0 ? C.sageDeep : C.terraDeep} />
    </div>
  );
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="Our Little Empire" plain="Net worth · bi-weekly snapshots" />
      <Seg value={who} onChange={setWho} options={[
        { v: "you", l: YOU.name, c: C.sageDeep }, { v: "partner", l: PARTNER.name, c: C.terraDeep }, { v: "both", l: "Both" }]} />
      <Card style={{ textAlign: "center" }}>
        <Eyebrow>Net worth · {cur.d}</Eyebrow>
        <div style={{ display: "flex", justifyContent: "center", alignItems: "center", gap: 8, marginTop: 2 }}>
          <Amt v={nw} size={30} w={700} d={0} color={nw >= 0 ? C.ink : C.terraDeep} />
          {up && <span className="pulse" style={{ color: C.rose, display: "flex" }}><I d={ic.heart} size={20} fill={C.blush} color={C.rose} /></span>}
        </div>
        <div style={{ fontFamily: sans, fontSize: 12.5, color: up ? C.sageDeep : C.terraDeep, fontWeight: 600 }}>
          {up ? "+" : "−"}{peso(Math.abs(nw - pnw), 0).slice(1)} since {prev.d}{up ? " · look at you two" : ""}
        </div>
      </Card>
      <Card>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
          <M l="Total assets" v={cur.assets} />
          <M l="Total liabilities" v={cur.liab} />
          <M l="Assets Δ" v={cur.assets - prev.assets} delta />
          <M l="Liabilities Δ" v={-(cur.liab - prev.liab)} delta />
          <M l="Savings assets" v={sav} />
          <div>
            <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>Savings rate</div>
            <span style={{ ...tnum, fontFamily: sans, fontSize: 14, fontWeight: 600, color: C.ink }}>
              {((sav / cur.assets) * 100).toFixed(1)}%
            </span>
          </div>
        </div>
        {who !== "both" && (
          <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, marginTop: 10, borderTop: `1px solid ${C.border}`, paddingTop: 8 }}>
            {who === "you" ? `Includes the Love Tab (${peso(177697.81)}) — money on its way back to you.` : `Includes the Love Tab (${peso(177697.81)}) as a liability. It's fine. ${YOU.name} knows.`}
          </div>
        )}
      </Card>
      <Card>
        <Eyebrow>Trend</Eyebrow>
        <div style={{ height: 170, marginTop: 8 }}>
          <ResponsiveContainer>
            <LineChart data={data}>
              <CartesianGrid vertical={false} stroke={C.border} />
              <XAxis dataKey="d" tick={{ fontFamily: sans, fontSize: 11, fill: C.muted }} axisLine={false} tickLine={false} />
              <YAxis hide domain={["auto", "auto"]} />
              <Tooltip formatter={(v) => peso(v, 0)} contentStyle={tipStyle} />
              <Line dataKey="Net worth" stroke={who === "partner" ? C.terraDeep : C.sageDeep} strokeWidth={2.5}
                dot={{ r: 3, strokeWidth: 0, fill: who === "partner" ? C.terraDeep : C.sageDeep }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </Card>
    </div>
  );
}

function Ytd() {
  const [who, setWho] = useState("both");
  const f = who === "both" ? 1 : who === "you" ? 0.62 : 0.38;
  const data = ytd.map((m) => ({ m: m.m, Income: +(m.inc * f).toFixed(0), Expenses: +(m.exp * f).toFixed(0) }));
  const tot = (k) => data.reduce((s, m) => s + m[k], 0);
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="Our Year So Far" plain="Year to date · 2026" />
      <Seg value={who} onChange={setWho} options={[
        { v: "you", l: YOU.name, c: C.sageDeep }, { v: "partner", l: PARTNER.name, c: C.terraDeep }, { v: "both", l: "Both" }]} />
      <Card>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
          {[["Income", tot("Income"), C.sageDeep], ["Expenses", tot("Expenses"), C.terraDeep],
            ["Savings", tot("Income") * 0.14, C.ink], ["Sinking funds", tot("Income") * 0.06, C.ink]].map(([l, v, c]) => (
            <div key={l}>
              <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>{l}</div>
              <Amt v={v} size={15} d={0} color={c} />
            </div>
          ))}
        </div>
      </Card>
      <Card>
        <Eyebrow>By month</Eyebrow>
        <div style={{ height: 180, marginTop: 8 }}>
          <ResponsiveContainer>
            <BarChart data={data} barGap={2} barSize={9}>
              <CartesianGrid vertical={false} stroke={C.border} />
              <XAxis dataKey="m" tick={{ fontFamily: sans, fontSize: 11, fill: C.muted }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip formatter={(v) => peso(v, 0)} contentStyle={tipStyle} />
              <Legend wrapperStyle={{ fontFamily: sans, fontSize: 12 }} />
              <Bar dataKey="Income" fill={C.sage} radius={[4, 4, 0, 0]} />
              <Bar dataKey="Expenses" fill={C.terra} radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </Card>
      <Card>
        <Eyebrow>Aug expenses by category</Eyebrow>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 130, height: 130 }}>
            <ResponsiveContainer>
              <PieChart>
                <Pie data={catSplit} dataKey="v" nameKey="name" innerRadius={36} outerRadius={56} paddingAngle={2}>
                  {catSplit.map((e) => <Cell key={e.name} fill={e.c} />)}
                </Pie>
                <Tooltip formatter={(v) => peso(v, 0)} contentStyle={tipStyle} />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div style={{ display: "grid", gap: 4, flex: 1 }}>
            {catSplit.map((e) => (
              <Row key={e.name}>
                <span style={{ display: "flex", gap: 6, alignItems: "center", fontFamily: sans, fontSize: 12, color: C.ink }}>
                  <span style={{ width: 8, height: 8, borderRadius: 2, background: e.c }} />{e.name}
                </span>
                <Amt v={e.v} size={12} w={500} d={0} />
              </Row>
            ))}
          </div>
        </div>
      </Card>
    </div>
  );
}

function Jar({ txns, onDelete, onMarkReturned }) {
  const [acting, setActing] = useState(null);
  const [filterSrc, setFilterSrc] = useState(null); // unit id, or null = all
  const OPENING = 8900; // carried float before the entries shown (prototype seed)
  const jarTx = txns.filter((t) => t.jar);
  // oldest → newest for the statement; seed list is newest-first
  const chron = [...jarTx].reverse();
  let run = OPENING;
  const stmtAll = chron.map((t) => {
    const delta = t.jarKind === "income" || t.type === "income" ? t.amount : -t.amount;
    run += delta;
    return { ...t, delta, after: run };
  }).reverse(); // display newest-first with balance-after
  const stmt = filterSrc ? stmtAll.filter((t) => t.jarSrc === filterSrc) : stmtAll;
  const lastPaid = filterSrc ? stmt.find((t) => t.jarKind === "income") : null;
  const balance = run;
  const owed = jarTx.filter((t) => t.jarKind === "borrow" && t.returned === false)
    .reduce((s, t) => s + t.amount, 0);
  const units = ["404", "406", "408", "305"].map((id) => ({
    id, paid: jarTx.some((t) => t.jarSrc === id && t.jarKind === "income"),
  }));
  const kindChip = (t) => t.jarKind === "borrow"
    ? (t.returned
      ? <Chip bg="rgba(73,141,109,.14)" color={C.sageDeep}>returned</Chip>
      : <Chip bg={C.blush} color={C.rose}>owed back</Chip>)
    : t.jarKind === "income" || t.type === "income"
      ? <Chip bg="rgba(73,141,109,.14)" color={C.sageDeep}>in</Chip>
      : <Chip bg={C.frame} color={C.muted}>dip</Chip>;
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="The Cookie Jar" plain="Petty cash · running balance" />
      <Card style={{ textAlign: "center" }}>
        <span style={{ color: C.sageDeep }}><I d={ic.jar} size={24} /></span>
        <div><Amt v={balance} size={28} w={700} /></div>
        <div style={{ fontFamily: sans, fontSize: 12.5, color: C.muted }}>
          {owed > 0 ? <>includes {peso(owed)} borrowed, not yet back</> : "wifi, laundry, and other little wins"}
        </div>
      </Card>
      <Card>
        <Eyebrow>This cycle · who's paid · tap a unit to filter</Eyebrow>
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap", marginTop: 8 }}>
          {units.map((u) => {
            const sel = filterSrc === u.id;
            return (
              <button key={u.id} onClick={() => setFilterSrc(sel ? null : u.id)} aria-pressed={sel}
                style={{ border: sel ? `1.5px solid ${C.sageDeep}` : `1.5px solid transparent`,
                  background: sel ? "rgba(73,141,109,.2)" : u.paid ? "rgba(73,141,109,.14)" : C.frame,
                  color: u.paid || sel ? C.sageDeep : C.muted, cursor: "pointer",
                  fontFamily: sans, fontSize: 11, fontWeight: 600, borderRadius: 999, padding: "3px 9px",
                  transition: "background 200ms cubic-bezier(.23,1,.32,1)" }}>
                {u.id} {u.paid ? "✓" : "—"}
              </button>
            );
          })}
          {filterSrc && (
            <button onClick={() => setFilterSrc(null)} style={{ border: "none", background: "none", cursor: "pointer",
              fontFamily: sans, fontSize: 11, fontWeight: 600, color: C.rose, padding: "3px 6px" }}>
              clear ×
            </button>
          )}
        </div>
        {filterSrc ? (
          <div style={{ fontFamily: sans, fontSize: 11, color: C.muted, marginTop: 6 }}>
            Unit {filterSrc} · {stmt.filter((t) => t.jarKind === "income").length} payment{stmt.filter((t) => t.jarKind === "income").length === 1 ? "" : "s"} on record
            {lastPaid ? ` · last paid ${lastPaid.date} (${peso(lastPaid.amount, 0)})` : " · nothing yet this record"}
          </div>
        ) : (
          <div style={{ fontFamily: sans, fontSize: 11, color: C.muted, marginTop: 6 }}>
            Boarder units — internet ₱700, laundry ₱500. The quiet ones get a nudge, not a bill collector.
          </div>
        )}
      </Card>
      <Card pad={0}>
        <div style={{ padding: "12px 14px 4px" }}>
          <Eyebrow>{filterSrc ? `Statement · Unit ${filterSrc} only` : "Statement · tap a row to edit"}</Eyebrow>
        </div>
        {stmt.length === 0 && (
          <div style={{ padding: "16px 14px", fontFamily: sans, fontSize: 13.5, color: C.muted, textAlign: "center" }}>
            {filterSrc ? `Nothing from Unit ${filterSrc} yet. They're due a friendly knock.` : 'Empty jar. Add an entry and flip on "From the Cookie Jar."'}
          </div>
        )}
        {stmt.map((t, i) => (
          <button key={t.id} onClick={() => setActing(t)} style={{ width: "100%", textAlign: "left", border: "none",
            background: "none", cursor: "pointer", padding: "10px 14px",
            borderBottom: i < stmt.length - 1 ? `1px solid ${C.border}` : "none" }}
            onMouseEnter={(e) => (e.currentTarget.style.background = C.frame)}
            onMouseLeave={(e) => (e.currentTarget.style.background = "none")}>
            <Row>
              <div style={{ minWidth: 0 }}>
                <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                  <span style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>
                    {t.cat.replace("Cookie Jar · ", "")}
                  </span>
                  {kindChip(t)}
                </div>
                <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>
                  {t.date}{t.jarSrc ? ` · ${t.jarSrc === "larr" ? YOU.name : t.jarSrc === "len" ? PARTNER.name : "Unit " + t.jarSrc}` : ""}
                </div>
              </div>
              <div style={{ textAlign: "right" }}>
                <Amt v={t.delta} color={t.delta >= 0 ? C.sageDeep : C.terraDeep} />
                <div style={{ ...tnum, fontFamily: sans, fontSize: 10.5, color: C.muted }}>bal {peso(t.after, 0)}</div>
              </div>
            </Row>
          </button>
        ))}
      </Card>

      {acting && (
        <div onClick={() => setActing(null)} style={{ position: "absolute", inset: 0, background: "rgba(29,33,43,.35)", zIndex: 30, display: "flex", alignItems: "flex-end" }}>
          <div onClick={(e) => e.stopPropagation()} className="sheetUp" style={{ background: C.ground, width: "100%",
            borderRadius: "22px 22px 0 0", padding: "10px 18px 24px", boxShadow: "0 -8px 30px rgba(60,50,35,.18)" }}>
            <div style={{ width: 38, height: 4, background: C.border, borderRadius: 99, margin: "0 auto 12px" }} />
            <div style={{ fontFamily: serif, fontStyle: "italic", fontSize: 20, color: C.ink }}>{acting.cat.replace("Cookie Jar · ", "")}</div>
            <div style={{ fontFamily: sans, fontSize: 12.5, color: C.muted, marginBottom: 14 }}>
              {peso(acting.amount)} · {acting.date}
            </div>
            <div style={{ display: "grid", gap: 8 }}>
              {acting.jarKind === "borrow" && acting.returned === false && (
                <button onClick={() => { onMarkReturned(acting.id); setActing(null); }} style={{ border: "none", background: C.sage,
                  color: "#fff", cursor: "pointer", borderRadius: 12, fontFamily: sans, fontSize: 14, fontWeight: 700, padding: "12px" }}>
                  Mark returned
                </button>
              )}
              <button disabled style={{ border: `1px solid ${C.border}`, background: C.card, color: C.muted,
                borderRadius: 12, fontFamily: sans, fontSize: 14, fontWeight: 600, padding: "12px", opacity: 0.6 }}>
                Edit entry — coming soon
              </button>
              <button onClick={() => { onDelete(acting.id); setActing(null); }} style={{ border: "none", background: "#FBEAEA",
                color: C.terraDeep, cursor: "pointer", borderRadius: 12, fontFamily: sans, fontSize: 14, fontWeight: 700, padding: "12px" }}>
                Remove from jar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function WarChest({ funds, onRaid, onRepay }) {
  const [raiding, setRaiding] = useState(false);
  const [repaying, setRepaying] = useState(null); // fund being repaid
  const [pick, setPick] = useState(funds[0]?.id);
  const [amt, setAmt] = useState("");
  const [who, setWho] = useState("absorb"); // absorb | due
  const [payAmt, setPayAmt] = useState("");
  const field = { width: "100%", boxSizing: "border-box", fontFamily: sans, fontSize: 14, padding: "10px 12px",
    borderRadius: 12, border: `1px solid ${C.border}`, background: C.card, color: C.ink, outline: "none" };
  const owedOf = (f) => f.ious.reduce((s, i) => s + i.amount - i.repaid, 0);
  const totalOwed = funds.reduce((s, f) => s + owedOf(f), 0);
  const a = Number(amt) || 0;
  const pickFund = funds.find((f) => f.id === pick);
  const raidOk = a > 0 && pickFund && a <= pickFund.real;
  const purposeLabel = { loan_payoff: "for killing loans", sinking: "sinking fund", emergency: "for real emergencies" };
  const SheetShell = ({ children, onClose }) => (
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(29,33,43,.35)", zIndex: 30, display: "flex", alignItems: "flex-end" }}>
      <div onClick={(e) => e.stopPropagation()} className="sheetUp" style={{ background: C.ground, width: "100%",
        borderRadius: "22px 22px 0 0", padding: "10px 18px 24px", boxShadow: "0 -8px 30px rgba(60,50,35,.18)" }}>
        <div style={{ width: 38, height: 4, background: C.border, borderRadius: 99, margin: "0 auto 12px" }} />
        {children}
      </div>
    </div>
  );
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="The War Chest" plain="Funds · envelopes on real accounts" />
      {totalOwed > 0 && (
        <Card style={{ borderColor: C.blush, background: "#FDF7F8" }}>
          <Row>
            <div>
              <Eyebrow color={C.rose}>Owed back to the funds</Eyebrow>
              <Amt v={totalOwed} size={20} w={700} />
            </div>
            <span style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, textAlign: "right" }}>
              Bills borrowed this.<br />Surpluses repay it first.
            </span>
          </Row>
        </Card>
      )}
      {funds.map((f) => {
        const owed = owedOf(f);
        const whole = f.real + owed;
        const pct = f.target ? Math.min(f.real / f.target, 1) : null;
        return (
          <Card key={f.id}>
            <Row style={{ marginBottom: 4 }}>
              <div>
                <div style={{ fontFamily: serif, fontStyle: "italic", fontSize: 16, color: C.ink }}>{f.name}</div>
                <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>
                  {YOU.name}'s · lives in {f.home} · {purposeLabel[f.purpose]}
                </div>
              </div>
              {owed > 0 && <Chip bg={C.blush} color={C.rose}>owed {peso(owed, 0)}</Chip>}
            </Row>
            <Row style={{ marginBottom: 8 }}>
              <div>
                <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>In the bank</div>
                <Amt v={f.real} size={18} w={700} />
              </div>
              {owed > 0 && (
                <div style={{ textAlign: "right" }}>
                  <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>Whole again at</div>
                  <Amt v={whole} size={14} w={600} color={C.muted} />
                </div>
              )}
            </Row>
            {pct !== null && (
              <>
                <div aria-hidden="true" style={{ height: 6, borderRadius: 99, background: C.frame, overflow: "hidden", display: "flex" }}>
                  <div style={{ width: `${pct * 100}%`, height: "100%", background: C.sage }} />
                  {owed > 0 && <div style={{ width: `${Math.min(owed / f.target, 1 - pct) * 100}%`, height: "100%", background: C.blush }} />}
                </div>
                <div style={{ fontFamily: sans, fontSize: 11, color: C.muted, marginTop: 5 }}>
                  {Math.round(pct * 100)}% of {peso(f.target, 0)}{owed > 0 ? " — the pink sliver is what's owed back" : ""}
                </div>
              </>
            )}
            {owed > 0 && (
              <div style={{ marginTop: 8, display: "flex", gap: 6, alignItems: "center" }}>
                <button onClick={() => { setRepaying(f); setPayAmt(String(owed)); }} style={{ border: "none", background: C.sage,
                  color: "#fff", cursor: "pointer", borderRadius: 999, fontFamily: sans, fontSize: 12, fontWeight: 600, padding: "7px 13px" }}>
                  Repay
                </button>
                <span style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>made whole by ~Oct 15 at current pace</span>
              </div>
            )}
          </Card>
        );
      })}
      <button onClick={() => { setRaiding(true); setAmt(""); setWho("absorb"); }} style={{ border: "none", background: C.ink,
        color: "#fff", cursor: "pointer", borderRadius: 999, fontFamily: sans, fontSize: 14, fontWeight: 700, padding: "13px" }}>
        Borrow to cover bills
      </button>
      <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, textAlign: "center" }}>
        Borrowing moves real money and writes an IOU — nothing is forgotten, nobody is nagged.
      </div>

      {raiding && (
        <SheetShell onClose={() => setRaiding(false)}>
          <Title pet="Borrow from a fund" plain="Covers this cycle's bills" />
          <div style={{ display: "grid", gap: 10, marginTop: 10 }}>
            <div style={{ display: "grid", gap: 4 }}>
              <Eyebrow>Which fund (in raid order)</Eyebrow>
              <Seg value={pick} onChange={setPick} options={funds.map((f) => ({ v: f.id, l: f.name.replace(" Fund", "") }))} />
              {pickFund && (
                <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>
                  {pickFund.name} has {peso(pickFund.real)} in the bank
                  {pickFund.purpose === "emergency" ? " — last resort, but that's what it's for." : "."}
                </div>
              )}
            </div>
            <label style={{ display: "grid", gap: 4 }}>
              <Eyebrow>How much</Eyebrow>
              <input inputMode="decimal" value={amt} onChange={(e) => setAmt(e.target.value)} placeholder="0.00"
                style={{ ...field, ...tnum, fontSize: 20, fontWeight: 700,
                  borderColor: a > (pickFund?.real || 0) ? C.terraDeep : C.border }} />
              {a > (pickFund?.real || 0) && (
                <span style={{ fontFamily: sans, fontSize: 11, color: C.terraDeep }}>More than the fund holds.</span>
              )}
            </label>
            <div style={{ display: "grid", gap: 4 }}>
              <Eyebrow>Whose shortfall is it</Eyebrow>
              <Seg value={who} onChange={setWho} options={[
                { v: "absorb", l: `${YOU.name} absorbs it`, c: C.sageDeep },
                { v: "due", l: `Add to ${PARTNER.name}'s due`, c: C.terraDeep }]} />
              <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>
                {who === "absorb"
                  ? "The household owes your fund — nothing changes for " + PARTNER.name + "."
                  : "Half joins " + PARTNER.name + "'s due this cycle, half is the household's IOU to your fund."}
              </div>
            </div>
            <button disabled={!raidOk} onClick={() => { onRaid(pick, a, who); setRaiding(false); }}
              style={{ border: "none", cursor: raidOk ? "pointer" : "default", opacity: raidOk ? 1 : 0.45,
                background: C.sage, color: "#fff", fontFamily: sans, fontSize: 15, fontWeight: 700, padding: "13px", borderRadius: 999 }}>
              Borrow {a > 0 ? peso(a, 0) : ""}
            </button>
          </div>
        </SheetShell>
      )}

      {repaying && (
        <SheetShell onClose={() => setRepaying(null)}>
          <Title pet="Make it whole" plain={`Repay ${repaying.name}`} />
          <div style={{ display: "grid", gap: 10, marginTop: 10 }}>
            <label style={{ display: "grid", gap: 4 }}>
              <Eyebrow>Amount (owed: {peso(owedOf(repaying))})</Eyebrow>
              <input inputMode="decimal" value={payAmt} onChange={(e) => setPayAmt(e.target.value)}
                style={{ ...field, ...tnum, fontSize: 20, fontWeight: 700 }} />
            </label>
            <button onClick={() => { onRepay(repaying.id, Math.min(Number(payAmt) || 0, owedOf(repaying))); setRepaying(null); }}
              style={{ border: "none", cursor: "pointer", background: C.sage, color: "#fff",
                fontFamily: sans, fontSize: 15, fontWeight: 700, padding: "13px", borderRadius: 999 }}>
              Repay
            </button>
          </div>
        </SheetShell>
      )}
    </div>
  );
}

function Loans() {
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="Baggage We're Carrying" plain="Loans · per person" />
      {loans.map((l) => {
        const pct = 1 - l.bal / l.principal;
        const isTab = l.lender.includes("Love Tab");
        return (
          <Card key={l.lender} style={isTab ? { borderColor: C.blush } : {}}>
            <Row style={{ marginBottom: 6 }}>
              <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                <PersonDot who={l.owner} />
                <span style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>{l.lender}</span>
              </div>
              {isTab && <span style={{ color: C.rose }}><I d={ic.heart} size={15} fill={C.blush} color={C.rose} /></span>}
            </Row>
            <Row style={{ marginBottom: 8 }}>
              <Amt v={l.bal} size={19} w={700} />
              <span style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>of {peso(l.principal, 0)} · {l.rate}</span>
            </Row>
            <div aria-hidden="true" style={{ height: 6, borderRadius: 99, background: C.frame, overflow: "hidden" }}>
              <div style={{ width: `${pct * 100}%`, height: "100%", borderRadius: 99, background: l.owner === "you" ? C.sage : C.terra }} />
            </div>
            <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, marginTop: 6 }}>
              {(pct * 100).toFixed(0)}% paid down · next due {l.due}
            </div>
          </Card>
        );
      })}
    </div>
  );
}

function Accounts() {
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="Where the Money Sleeps" plain="Accounts · balances" />
      <Card pad={0}>
        {accounts.map((a, i) => (
          <div key={a.id} style={{ padding: "12px 14px", borderBottom: i < accounts.length - 1 ? `1px solid ${C.border}` : "none" }}>
            <Row>
              <div style={{ display: "flex", gap: 9, alignItems: "center" }}>
                <PersonDot who={a.owner} />
                <div>
                  <div style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>{a.name}</div>
                  <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>{a.kind} · updated Aug 20</div>
                </div>
              </div>
              <Amt v={a.bal} />
            </Row>
          </div>
        ))}
      </Card>
      <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted, textAlign: "center" }}>
        The Love Tab lives here too — it's real money, it's just sleeping at her place.
      </div>
    </div>
  );
}

function Recurring() {
  const [paused, setPaused] = useState({});
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="Things We Keep Doing" plain="Recurring · bi-weekly + monthly" />
      <Card pad={0}>
        {recurring.map((r, i) => (
          <div key={r.name} style={{ padding: "12px 14px", borderBottom: i < recurring.length - 1 ? `1px solid ${C.border}` : "none", opacity: paused[r.name] ? 0.5 : 1 }}>
            <Row>
              <div style={{ display: "flex", gap: 9, alignItems: "center" }}>
                <PersonDot who={r.owner} />
                <div>
                  <div style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>{r.name}</div>
                  <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>{r.cad} · next {r.next}</div>
                </div>
              </div>
              <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                <Amt v={r.amt} w={500} />
                <button onClick={() => setPaused({ ...paused, [r.name]: !paused[r.name] })}
                  style={{ border: `1px solid ${C.border}`, background: C.card, borderRadius: 8, cursor: "pointer",
                    fontFamily: sans, fontSize: 11, fontWeight: 600, color: C.muted, padding: "4px 8px" }}>
                  {paused[r.name] ? "Resume" : "Pause"}
                </button>
              </div>
            </Row>
          </div>
        ))}
      </Card>
    </div>
  );
}

function Settings({ onRename }) {
  const [real, setReal] = useState({ you: YOU.name, partner: PARTNER.name });
  const [names, setNames] = useState({ you: YOU.pet || "", partner: PARTNER.pet || "" });
  const [showPets, setShowPets] = useState(!!(YOU.pet || PARTNER.pet));
  const [showAI, setShowAI] = useState(false);
  const [key, setKey] = useState("");
  const [showKey, setShowKey] = useState(false);
  const [backupCad, setBackupCad] = useState("biweekly");
  const dirty = real.you !== YOU.name || real.partner !== PARTNER.name || (names.you || null) !== YOU.pet || (names.partner || null) !== PARTNER.pet;
  const field = { width: "100%", boxSizing: "border-box", fontFamily: sans, fontSize: 14, padding: "10px 12px",
    borderRadius: 12, border: `1px solid ${C.border}`, background: C.card, color: C.ink, outline: "none" };
  const save = () => {
    YOU.name = real.you.trim() || YOU.name; PARTNER.name = real.partner.trim() || PARTNER.name;
    YOU.pet = names.you.trim() || null; PARTNER.pet = names.partner.trim() || null;
    onRename();  // force app-wide re-render; every computed label updates, zero stored rows touched
  };
  const Disclosure = ({ open, onToggle, label, sub }) => (
    <button onClick={onToggle} style={{ width: "100%", border: "none", background: "none", cursor: "pointer",
      padding: 0, display: "flex", justifyContent: "space-between", alignItems: "center", textAlign: "left" }}>
      <span>
        <div style={{ fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink }}>{label}</div>
        <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>{sub}</div>
      </span>
      <span style={{ color: C.muted, transform: open ? "rotate(90deg)" : "none", transition: "transform 200ms cubic-bezier(.23,1,.32,1)" }}>
        <I d={ic.chev} size={16} />
      </span>
    </button>
  );
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <Title pet="The Fine Print" plain="Settings" />
      <Card>
        <Eyebrow>Names (used everywhere — chips, headers, splits)</Eyebrow>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 8 }}>
          <label style={{ display: "grid", gap: 4 }}>
            <span style={{ fontFamily: sans, fontSize: 12, color: C.sageDeep, fontWeight: 600 }}>Payer</span>
            <input value={real.you} onChange={(e) => setReal({ ...real, you: e.target.value })} style={field} />
          </label>
          <label style={{ display: "grid", gap: 4 }}>
            <span style={{ fontFamily: sans, fontSize: 12, color: C.terraDeep, fontWeight: 600 }}>Contributor</span>
            <input value={real.partner} onChange={(e) => setReal({ ...real, partner: e.target.value })} style={field} />
          </label>
        </div>
        <div style={{ fontFamily: sans, fontSize: 11, color: C.muted, marginTop: 8 }}>
          Change a name and it updates everywhere, instantly — every label, chip, and split.
        </div>
      </Card>
      <Card>
        <Disclosure open={showPets} onToggle={() => setShowPets(!showPets)}
          label="Add pet names" sub="Optional — used only in greetings, never on data" />
        {showPets && (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 10 }}>
            <label style={{ display: "grid", gap: 4 }}>
              <span style={{ fontFamily: sans, fontSize: 12, color: C.sageDeep, fontWeight: 600 }}>{real.you || "Payer"} goes by</span>
              <input value={names.you} onChange={(e) => setNames({ ...names, you: e.target.value })} placeholder="—" style={field} />
            </label>
            <label style={{ display: "grid", gap: 4 }}>
              <span style={{ fontFamily: sans, fontSize: 12, color: C.terraDeep, fontWeight: 600 }}>{real.partner || "Contributor"} goes by</span>
              <input value={names.partner} onChange={(e) => setNames({ ...names, partner: e.target.value })} placeholder="—" style={field} />
            </label>
            <div style={{ gridColumn: "1 / -1", fontFamily: sans, fontSize: 11, color: C.muted }}>
              Leave blank to just use names. Greetings fall back to names — never a repeated nickname.
            </div>
          </div>
        )}
      </Card>
      <button disabled={!dirty} onClick={save} style={{ border: "none", cursor: dirty ? "pointer" : "default",
        opacity: dirty ? 1 : 0.45, background: C.sage, color: "#fff", fontFamily: sans, fontSize: 14, fontWeight: 700,
        padding: "12px", borderRadius: 999 }}>
        Save
      </button>
      <Card>
        <Disclosure open={showAI} onToggle={() => setShowAI(!showAI)}
          label="AI entry (advanced)" sub="Bring your own Gemini key, or leave off" />
        {showAI && (
          <div style={{ marginTop: 10, display: "grid", gap: 8 }}>
            <label style={{ display: "grid", gap: 4 }}>
              <Eyebrow>Gemini API key</Eyebrow>
              <div style={{ display: "flex", gap: 6 }}>
                <input type={showKey ? "text" : "password"} value={key} onChange={(e) => setKey(e.target.value)}
                  placeholder="AIza…" style={{ ...field, flex: 1, letterSpacing: showKey ? "normal" : "2px" }} />
                <button onClick={() => setShowKey(!showKey)} style={{ border: `1px solid ${C.border}`, background: C.card,
                  borderRadius: 10, cursor: "pointer", fontFamily: sans, fontSize: 12, fontWeight: 600, color: C.muted, padding: "0 12px" }}>
                  {showKey ? "Hide" : "Show"}
                </button>
              </div>
            </label>
            <div style={{ display: "flex", gap: 6 }}>
              <button disabled={!key} style={{ border: "none", background: C.sage, color: "#fff", opacity: key ? 1 : 0.45,
                cursor: key ? "pointer" : "default", borderRadius: 999, fontFamily: sans, fontSize: 12.5, fontWeight: 600, padding: "8px 14px" }}>
                Test key
              </button>
              {key && (
                <button onClick={() => setKey("")} style={{ border: `1px solid ${C.border}`, background: C.card, color: C.muted,
                  cursor: "pointer", borderRadius: 999, fontFamily: sans, fontSize: 12.5, fontWeight: 600, padding: "8px 14px" }}>
                  Clear
                </button>
              )}
            </div>
            <div style={{ fontFamily: sans, fontSize: 11, color: C.muted }}>
              Stored encrypted on this device only — never synced, never logged. It bills your own Google account.
              Leave empty and entry still works — the app uses its built-in shortcuts instead.
            </div>
          </div>
        )}
      </Card>
      <Card>
        <Eyebrow>Roles</Eyebrow>
        <Row style={{ marginTop: 6 }}>
          <span style={{ fontFamily: sans, fontSize: 13.5, color: C.ink }}>One payer, one contributor</span>
          <Chip bg={C.frame} color={C.muted}>fixed</Chip>
        </Row>
        <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>Chosen once at the start — the whole split system is built around it.</div>
      </Card>
      <Card>
        <Eyebrow>Cycle anchor</Eyebrow>
        <div style={{ fontFamily: sans, fontSize: 13.5, color: C.ink, marginTop: 6 }}>15th & 30th of each month</div>
        <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>Bills, settlements, and snapshots follow this beat.</div>
      </Card>
      <Card>
        <Eyebrow>Currency</Eyebrow>
        <Row style={{ marginTop: 6 }}>
          <span style={{ fontFamily: sans, fontSize: 13.5, color: C.ink }}>Philippine Peso (₱)</span>
          <Chip bg={C.frame} color={C.muted}>locked</Chip>
        </Row>
      </Card>
      <Card>
        <Eyebrow>Backups</Eyebrow>
        <div style={{ marginTop: 8 }}>
          <Seg value={backupCad} onChange={setBackupCad} options={[
            { v: "off", l: "Off" }, { v: "daily", l: "Daily" }, { v: "weekly", l: "Weekly" }, { v: "biweekly", l: "Bi-weekly" }]} />
        </div>
        <div style={{ fontFamily: sans, fontSize: 11, color: C.muted, marginTop: 8 }}>
          Keeps a copy of everything — one the app can bring back if you ever need it, plus a spreadsheet version. Saves happen when you open the app, and the last 5 are kept.
          {backupCad === "biweekly" && " Bi-weekly saves land on the 15th & 30th — same beat as your bills."}
        </div>
        <div style={{ display: "flex", gap: 6, marginTop: 10 }}>
          <button style={{ border: "none", background: C.sage, color: "#fff", cursor: "pointer",
            borderRadius: 999, fontFamily: sans, fontSize: 12.5, fontWeight: 600, padding: "8px 14px" }}>
            Back up now
          </button>
          <button style={{ border: `1px solid ${C.border}`, background: C.card, color: C.ink, cursor: "pointer",
            borderRadius: 999, fontFamily: sans, fontSize: 12.5, fontWeight: 600, padding: "8px 14px" }}>
            Restore from backup…
          </button>
        </div>
      </Card>
      <button style={{ border: `1px solid ${C.border}`, background: C.card, borderRadius: 999, cursor: "pointer",
        fontFamily: sans, fontSize: 13.5, fontWeight: 600, color: C.ink, padding: "12px" }}>
        Export everything (CSV)
      </button>
    </div>
  );
}

/* ─── shell ──────────────────────────────────────────────── */
const moreItems = [
  { k: "ytd", i: ic.cal, t: "Our Year So Far", s: "YTD summary" },
  { k: "empire", i: ic.chart, t: "Our Little Empire", s: "Net worth" },
  { k: "loans", i: ic.bag, t: "Baggage We're Carrying", s: "Loans" },
  { k: "chest", i: ic.chest, t: "The War Chest", s: "Funds & envelopes" },
  { k: "jar", i: ic.jar, t: "The Cookie Jar", s: "Petty cash" },
  { k: "accounts", i: ic.bank, t: "Where the Money Sleeps", s: "Accounts" },
  { k: "recurring", i: ic.loop, t: "Things We Keep Doing", s: "Recurring" },
  { k: "settings", i: ic.gear, t: "The Fine Print", s: "Settings" },
];

export default function App() {
  const [tab, setTab] = useState("home");
  const [sub, setSub] = useState(null);
  const [sheet, setSheet] = useState(false);
  const [txns, setTxns] = useState(seedTxns);
  const [funds, setFunds] = useState(seedFunds);
  const [toast, setToast] = useState(null);
  const [renameTick, setRenameTick] = useState(0);
  const loveTab = 177697.81;

  const go = (t, s = null) => { setTab(t); setSub(s); };
  const save = (t) => {
    setTxns([{ ...t }, ...txns]);
    setSheet(false);
    setToast(t.jar ? "Added to the jar." : "Saved. Team effort.");
    setTimeout(() => setToast(null), 2200);
    setTab(t.jar ? "more" : "receipts"); setSub(t.jar ? "jar" : null);
  };
  const removeTxn = (id) => {
    setTxns((list) => list.filter((x) => x.id !== id));
    setToast("Removed.");
    setTimeout(() => setToast(null), 1800);
  };
  const markReturned = (id) => {
    setTxns((list) => list.map((x) => (x.id === id ? { ...x, returned: true } : x)));
    setToast("Back in the jar. All square.");
    setTimeout(() => setToast(null), 2000);
  };
  const raidFund = (fundId, amount, whose) => {
    const f = funds.find((x) => x.id === fundId);
    setFunds((list) => list.map((x) => x.id === fundId
      ? { ...x, real: +(x.real - amount).toFixed(2),
          ious: [...x.ious, { date: "Aug 23", amount, reason: "Covered the Aug 30 bills gap", repaid: 0 }] }
      : x));
    setTxns((list) => [{ id: Date.now(), date: "Aug 23", amount, type: "transfer",
      cat: `Fund Move · ${f.name} → Bills`, paidBy: "you",
      alloc: whose === "due" ? { you: amount / 2, partner: amount / 2 } : { you: amount, partner: 0 },
      note: whose === "due" ? `half added to ${PARTNER.name}'s due` : "household owes the fund" }, ...list]);
    setToast(`Borrowed ${peso(amount, 0)}. The fund remembers.`);
    setTimeout(() => setToast(null), 2200);
  };
  const repayFund = (fundId, amount) => {
    if (amount <= 0) return;
    setFunds((list) => list.map((x) => {
      if (x.id !== fundId) return x;
      let left = amount;
      const ious = x.ious.map((i) => {
        const open = i.amount - i.repaid;
        const pay = Math.min(open, left); left -= pay;
        return { ...i, repaid: i.repaid + pay };
      });
      return { ...x, real: +(x.real + amount).toFixed(2), ious };
    }));
    setToast("Made whole. That felt good.");
    setTimeout(() => setToast(null), 2200);
  };

  const screen = useMemo(() => {
    if (tab === "home") return <Home go={go} tab={loveTab} />;
    if (tab === "receipts") return <Receipts txns={txns} />;
    if (tab === "bills") return <Bills tab={loveTab} />;
    if (tab === "more") {
      if (sub === "ytd") return <Ytd />;
      if (sub === "empire") return <Empire />;
      if (sub === "loans") return <Loans />;
      if (sub === "chest") return <WarChest funds={funds} onRaid={raidFund} onRepay={repayFund} />;
      if (sub === "jar") return <Jar txns={txns} onDelete={removeTxn} onMarkReturned={markReturned} />;
      if (sub === "accounts") return <Accounts />;
      if (sub === "recurring") return <Recurring />;
      if (sub === "settings") return <Settings onRename={() => { setRenameTick((n) => n + 1); setToast("Names updated everywhere."); setTimeout(() => setToast(null), 2000); }} />;
      return (
        <div style={{ display: "grid", gap: 14 }}>
          <Title pet="Everything else" plain="More" />
          <div style={{ display: "grid", gap: 10 }}>
            {moreItems.map((x) => (
              <button key={x.k} onClick={() => setSub(x.k)} style={{ textAlign: "left", cursor: "pointer",
                background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, padding: "12px 14px",
                display: "flex", gap: 12, alignItems: "center" }}>
                <span style={{ color: C.sageDeep, background: "rgba(73,141,109,.1)", borderRadius: 10, padding: 8, display: "flex" }}>
                  <I d={x.i} size={19} />
                </span>
                <span style={{ flex: 1 }}>
                  <div style={{ fontFamily: serif, fontStyle: "italic", fontSize: 15.5, color: C.ink }}>{x.t}</div>
                  <div style={{ fontFamily: sans, fontSize: 11.5, color: C.muted }}>{x.s}</div>
                </span>
                <span style={{ color: C.muted }}><I d={ic.chev} size={16} /></span>
              </button>
            ))}
          </div>
        </div>
      );
    }
    return null;
  }, [tab, sub, txns, funds, renameTick]);

  const NavBtn = ({ k, icon, label }) => {
    const active = tab === k;
    return (
      <button onClick={() => go(k)} aria-label={label} aria-current={active ? "page" : undefined}
        style={{ border: "none", background: "none", cursor: "pointer", display: "grid", justifyItems: "center",
          gap: 2, padding: "6px 4px", minWidth: 52, color: active ? C.sageDeep : C.muted,
          transition: "color 200ms cubic-bezier(.23,1,.32,1)" }}>
        <I d={icon} size={21} />
        <span style={{ fontFamily: sans, fontSize: 10, fontWeight: active ? 700 : 500 }}>{label}</span>
      </button>
    );
  };

  return (
    <div style={{ minHeight: "100vh", background: C.frame, display: "flex", justifyContent: "center",
      padding: "18px 0", fontFamily: sans }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400..700;1,9..144,400..700&family=DM+Sans:opsz,wght@9..40,400..700&display=swap');
        * { -webkit-font-smoothing: antialiased; }
        button:focus-visible, input:focus-visible { outline: 2px solid ${C.sage}; outline-offset: 2px; }
        .pulse { animation: beat 700ms cubic-bezier(.23,1,.32,1) 1; }
        @keyframes beat { 0%{transform:scale(1)} 35%{transform:scale(1.35)} 100%{transform:scale(1)} }
        .sheetUp { animation: rise 380ms cubic-bezier(.32,.72,0,1) 1; }
        @keyframes rise { from{transform:translateY(28px);opacity:.4} to{transform:translateY(0);opacity:1} }
        .toastIn { animation: rise 300ms cubic-bezier(.23,1,.32,1) 1; }
        .scrollArea { scrollbar-width: none; -ms-overflow-style: none; }
        .scrollArea::-webkit-scrollbar { display: none; }
        @media (prefers-reduced-motion: reduce) { .pulse,.sheetUp,.toastIn{animation:none} *{transition:none!important} }
      `}</style>

      <div style={{ width: "100%", maxWidth: 400, background: C.ground, borderRadius: 26, overflow: "hidden",
        border: `1px solid ${C.border}`, boxShadow: "0 20px 50px rgba(60,50,35,.14)", position: "relative",
        display: "flex", flexDirection: "column", height: "calc(100vh - 36px)", minHeight: 560 }}>

        <div style={{ padding: "14px 18px 10px", borderBottom: `1px solid ${C.border}`, background: "rgba(250,248,245,.9)",
          display: "flex", alignItems: "center", gap: 8 }}>
          {tab === "more" && sub && (
            <button onClick={() => setSub(null)} aria-label="Back" style={{ border: "none", background: "none", cursor: "pointer", color: C.ink, padding: 0, display: "flex" }}>
              <I d={ic.back} size={20} />
            </button>
          )}
          <span style={{ fontFamily: serif, fontWeight: 650, fontSize: 16, color: C.ink }}>Pantomina</span>
          <span style={{ color: C.rose, display: "flex" }}><I d={ic.heart} size={13} fill={C.blush} color={C.rose} /></span>
          <span style={{ marginLeft: "auto", fontFamily: sans, fontSize: 11, color: C.muted }}>two of us, one ledger</span>
        </div>

        <div className="scrollArea" style={{ flex: 1, overflowY: "auto", overflowX: "hidden", padding: "16px 18px 20px" }}>{screen}</div>

        {toast && (
          <div className="toastIn" style={{ position: "absolute", bottom: 86, left: 0, right: 0, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
            <span style={{ background: C.ink, color: "#fff", fontFamily: sans, fontSize: 12.5, fontWeight: 600,
              borderRadius: 999, padding: "8px 16px", boxShadow: "0 6px 18px rgba(29,33,43,.3)" }}>{toast}</span>
          </div>
        )}

        <div style={{ borderTop: `1px solid ${C.border}`, background: "rgba(253,253,252,.96)",
          display: "flex", alignItems: "center", justifyContent: "space-around", padding: "6px 8px 10px", position: "relative" }}>
          <NavBtn k="home" icon={ic.home} label="Home" />
          <NavBtn k="receipts" icon={ic.receipt} label="Receipts" />
          <button onClick={() => setSheet(true)} aria-label="Add entry" style={{ border: "none", cursor: "pointer",
            width: 52, height: 52, borderRadius: 999, background: C.sage, color: "#fff", display: "flex",
            alignItems: "center", justifyContent: "center", marginTop: -22,
            boxShadow: "0 6px 16px rgba(73,141,109,.4)", transition: "transform 150ms cubic-bezier(.23,1,.32,1)" }}
            onMouseDown={(e) => (e.currentTarget.style.transform = "scale(.94)")}
            onMouseUp={(e) => (e.currentTarget.style.transform = "scale(1)")}
            onMouseLeave={(e) => (e.currentTarget.style.transform = "scale(1)")}>
            <I d={ic.plus} size={24} />
          </button>
          <NavBtn k="bills" icon={ic.bills} label="Bills" />
          <NavBtn k="more" icon={ic.dots} label="More" />
        </div>

        {sheet && <AddSheet onClose={() => setSheet(false)} onSave={save} />}
      </div>
    </div>
  );
}
