/**
 * 寸进 · CUNJIN —— 全局统计纯函数
 *
 * 输入完全是页面已有的投影数组（`DATA_cards_punch_card` / `DATA_cards_start`），
 * 不读页面状态、不碰存储、不 import 任何 UI。
 *
 * ── 关键约定：日期如何对齐 ────────────────────────────────
 * 每张卡的 `punchCard[i]` 表示「从这张卡自己的 startAt 算起第 i 天」的记录。
 * 不同卡片的 startAt 不同，所以要把它们对齐到**绝对日**才能跨卡相加：
 *     绝对日 = floor(startAt / 86400000) + i
 * 这与 CardMapper.relativeDaysPassed 用的是同一套 UTC 整日口径
 * （floor(to/86400000) - floor(from/86400000)），因此"第 i 天"的判定
 * 与页面里 `CARD_get_today_block_index()` 完全一致。
 *
 * ── 连续天数的定义（本轮新增，明确写死，避免歧义）────────────
 * `currentStreak` = 从**今天**往前数，连续「有记录（>0 小时）」的天数。
 * 今天没有任何记录时为 0（不把昨天当作仍在连续中）。
 * 这是刻意的产品选择；若要改成「今天还没打卡也算连续」，改这一处即可。
 *
 * 所有函数对空数组、缺失行、越界下标、负下标、NaN 均返回 0，不抛异常。
 */

/** 一天对应的毫秒数（与 CardQueries.dateOfChosen 使用的口径一致）。 */
const MS_PER_DAY: number = 24 * 3600 * 1000;

/** 把「某张卡的开始时间 + 第 index 天」换算成绝对日序号。 */
function absoluteDayOf(startAt: number, index: number): number {
  return Math.floor(startAt / MS_PER_DAY) + index;
}

/**
 * 判断第 index 张卡是否应被排除（用于"归档卡片不计入统计"）。
 *
 * 规则：同时给出 cardIds 与 skipIds 时，若该卡的 id 出现在 skipIds 中则排除。
 * 任一参数缺失、或 id 取不到（数组长度不一致）时一律**不排除**，
 * 保证不带这两个参数的既有调用行为完全不变。
 */
function isExcluded(cardIds: string[] | undefined, skipIds: string[] | undefined,
  index: number): boolean {
  if (cardIds === undefined || skipIds === undefined) {
    return false;
  }
  const id = cardIds[index];
  if (id === undefined) {
    return false;
  }
  return skipIds.indexOf(id) >= 0;
}

/** 某张卡第 dayIndex 天的记录时长；越界或数据缺失返回 0。 */
export function cardHoursOnDay(punchRow: number[] | undefined, dayIndex: number): number {
  if (punchRow == undefined) {
    return 0;
  }
  if (!Number.isFinite(dayIndex) || dayIndex < 0 || dayIndex >= punchRow.length) {
    return 0;
  }
  const value = punchRow[dayIndex];
  if (!Number.isFinite(value)) {
    return 0;
  }
  return value;
}

/**
 * 指定时间戳那一天，所有卡片的提交总时长。
 * cardIds/skipIds 同时给出时，skipIds 里的卡片不计入（用于"归档卡片不计入统计"）。
 */
export function hoursOnDay(punchCards: number[][], startAts: number[], timestamp: number,
  cardIds?: string[], skipIds?: string[]): number {
  const dayAbs = Math.floor(timestamp / MS_PER_DAY);
  let sum = 0;
  for (let c = 0; c < punchCards.length; c++) {
    if (isExcluded(cardIds, skipIds, c)) {
      continue;
    }
    const start = startAts[c];
    if (start == undefined) {
      continue;
    }
    sum += cardHoursOnDay(punchCards[c], dayAbs - Math.floor(start / MS_PER_DAY));
  }
  return sum;
}

/**
 * 最近 days 天（含今天，即 [today-days+1, today]）的提交总时长。
 * days <= 0 时返回 0。
 */
export function hoursInRecentDays(punchCards: number[][], startAts: number[], now: number,
  days: number, cardIds?: string[], skipIds?: string[]): number {
  if (!Number.isFinite(days) || days <= 0) {
    return 0;
  }
  const todayAbs = Math.floor(now / MS_PER_DAY);
  let sum = 0;
  for (let back = 0; back < days; back++) {
    const dayAbs = todayAbs - back;
    for (let c = 0; c < punchCards.length; c++) {
      if (isExcluded(cardIds, skipIds, c)) {
        continue;
      }
      const start = startAts[c];
      if (start == undefined) {
        continue;
      }
      sum += cardHoursOnDay(punchCards[c], dayAbs - Math.floor(start / MS_PER_DAY));
    }
  }
  return sum;
}

/** 所有卡片的累计提交时长。cardIds/skipIds 规则同 hoursOnDay。 */
export function totalHours(punchCards: number[][], cardIds?: string[],
  skipIds?: string[]): number {
  let sum = 0;
  for (let c = 0; c < punchCards.length; c++) {
    if (isExcluded(cardIds, skipIds, c)) {
      continue;
    }
    const row = punchCards[c];
    if (row == undefined) {
      continue;
    }
    for (let i = 0; i < row.length; i++) {
      const value = row[i];
      if (Number.isFinite(value)) {
        sum += value;
      }
    }
  }
  return sum;
}

/** 所有卡片的记录长度最大值（用于把连续天数的回溯范围限制在有限步内）。 */
function maxPunchRowLength(punchCards: number[][]): number {
  let maxLen = 0;
  for (let c = 0; c < punchCards.length; c++) {
    const row = punchCards[c];
    if (row != undefined && row.length > maxLen) {
      maxLen = row.length;
    }
  }
  return maxLen;
}

/** 从今天往前连续「有记录」的天数；今天没有记录则为 0。 */
export function currentStreak(punchCards: number[][], startAts: number[], now: number,
  cardIds?: string[], skipIds?: string[]): number {
  const maxLen = maxPunchRowLength(punchCards);
  if (maxLen == 0) {
    return 0;
  }
  const todayAbs = Math.floor(now / MS_PER_DAY);
  let streak = 0;
  for (let back = 0; back < maxLen; back++) {
    const dayAbs = todayAbs - back;
    let hours = 0;
    for (let c = 0; c < punchCards.length; c++) {
      if (isExcluded(cardIds, skipIds, c)) {
        continue;
      }
      const start = startAts[c];
      if (start == undefined) {
        continue;
      }
      hours += cardHoursOnDay(punchCards[c], dayAbs - Math.floor(start / MS_PER_DAY));
    }
    if (hours > 0) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

/** 有记录的绝对天数（跨卡去重）——用于「累计打卡天数」。 */
export function activeDayCount(punchCards: number[][], startAts: number[], cardIds?: string[],
  skipIds?: string[]): number {
  const days: number[] = [];
  for (let c = 0; c < punchCards.length; c++) {
    if (isExcluded(cardIds, skipIds, c)) {
      continue;
    }
    const row = punchCards[c];
    const start = startAts[c];
    if (row == undefined || start == undefined) {
      continue;
    }
    for (let i = 0; i < row.length; i++) {
      const value = row[i];
      if (Number.isFinite(value) && value > 0) {
        const dayAbs = absoluteDayOf(start, i);
        if (days.indexOf(dayAbs) < 0) {
          days.push(dayAbs);
        }
      }
    }
  }
  return days.length;
}

// ─────────────────────────────────────────────────────────────
// 进度预测（按"最近的 actual 速度"估计还要多久）
//
// 与已有的 EstimatingBlock 的区别：
//   已有的是**理想值**「每天仅需 X 小时即可完成」（(目标-已完成)/剩余天数）；
//   这里的预测基于**最近的实际记录**，回答"照我现在这个速度，来不来得及"。
// 全部是纯计算，不读页面状态。
// ─────────────────────────────────────────────────────────────

/** 单张卡片的进度预测结果。 */
export interface CardForecast {
  /** none（无限目标/期限，不做预测）/ done / no-pace / on-track / late */
  status: string;
  remainingHours: number;
  /** 观察窗口内的日均投入（小时/天） */
  dailyPace: number;
  /** 按当前速度还需多少天（已完成或无法预测时为 0） */
  daysNeeded: number;
  /** 预计超出期限的天数；0 表示来得及 */
  daysLate: number;
  /** 实际参与平均的天数（卡片太新时小于请求窗口） */
  observedDays: number;
}

function makeForecast(status: string, remainingHours: number, dailyPace: number,
  daysNeeded: number, daysLate: number, observedDays: number): CardForecast {
  const result: CardForecast = {
    status: status, remainingHours: remainingHours, dailyPace: dailyPace,
    daysNeeded: daysNeeded, daysLate: daysLate, observedDays: observedDays
  };
  return result;
}

/** 这张卡"今天是第几天"（与页面 relativeDaysPassed 的口径一致）。 */
function dayIndexOf(startAt: number, now: number): number {
  return Math.floor(now / MS_PER_DAY) - Math.floor(startAt / MS_PER_DAY);
}

/**
 * 按最近 recentDays 天的实际投入预测完成时间。
 *
 * 规则（都是刻意选的，保证可解释）：
 *   · 目标 1001（无限）或期限 367（无限）-> status 'none'，不做预测；
 *   · 已完成（doneHours >= targetHours）-> 'done'；
 *   · 观察窗口 = min(最近 N 天, 卡片已存在的天数)：新卡片不会被前几天"拉低"；
 *   · 窗口内总投入为 0 -> 'no-pace'（没有速度可推算，不瞎猜）；
 *   · 否则 日均 = 窗口总投入 / 观察天数，还需天数 = ceil(剩余 / 日均)；
 *   · 预计完成日晚于期限 -> 'late'，并给出超出的整天数。
 */
export function forecastCard(punchRow: number[] | undefined, startAt: number, doneHours: number,
  targetHours: number, timeLimitDays: number, endAt: number, now: number,
  recentDays: number): CardForecast {
  // 无限目标 / 无限期限：没有"完成"这个概念，不预测
  if (targetHours == 1001 || timeLimitDays == 367) {
    return makeForecast('none', 0, 0, 0, 0, 0);
  }
  const done = Number.isFinite(doneHours) ? doneHours : 0;
  const remaining = targetHours - done;
  if (!Number.isFinite(targetHours) || remaining <= 0) {
    return makeForecast('done', 0, 0, 0, 0, 0);
  }

  const todayIndex = dayIndexOf(startAt, now);
  const elapsed = todayIndex + 1;
  const windowSize = Math.max(1, Math.floor(Number.isFinite(recentDays) ? recentDays : 7));
  const observed = Math.max(1, Math.min(windowSize, elapsed));

  let observedHours = 0;
  for (let back = 0; back < observed; back++) {
    observedHours += cardHoursOnDay(punchRow, todayIndex - back);
  }
  const pace = observedHours / observed;
  if (!Number.isFinite(pace) || pace <= 0) {
    return makeForecast('no-pace', remaining, 0, 0, 0, observed);
  }

  const daysNeeded = Math.max(1, Math.ceil(remaining / pace));
  const forecastEndAt = now + daysNeeded * MS_PER_DAY;
  const lateDaysRaw = Math.ceil((forecastEndAt - endAt) / MS_PER_DAY);
  const daysLate = lateDaysRaw > 0 && Number.isFinite(lateDaysRaw) ? lateDaysRaw : 0;
  return makeForecast(daysLate > 0 ? 'late' : 'on-track', remaining, pace, daysNeeded, daysLate,
    observed);
}
