/**
 * 寸进 · CUNJIN —— 卡片查询/计算纯函数
 *
 * 这些函数原本是 pages/Index.ets 里的 CARD_get_* / UTIL_get_connected_date 方法：
 * 它们都只是「从 @State 数组里取出几个值 -> 做算术/格式化」，没有任何副作用，
 * 也不需要 UI 生命周期。把它们搬到这里之后：
 *   · 所需数据全部通过参数传入，函数内部不读任何页面状态；
 *   · 不 import ArkUI 组件、Storage、TaskRepository；
 *   · 可以在本地单测里直接验证边界条件（逾期、无限目标、除零、下标越界等）。
 *
 * 页面里的同名方法保留为「取状态 -> 调用纯函数」的一行委托，
 * 调用点、调用时机与语义均未改变。
 *
 * ⚠ 实现逐字照抄原方法，包括看似奇怪的常量（时间进度用 864000 而非 86400000）
 *   与特殊返回值（"50 %"、"0 %"、" ∞ "、"( •̀ ω •́ )✧"、"1"、"500"）。
 *   这些是既有产品行为，不得"顺手修正"。
 */

import { relativeDaysPassed } from './CardMapper';

/**
 * 把时间戳格式化为 ["YYYY／M／D", "星期几(0-6)"]。
 * 注意：分隔符是全角「／」，且月/日不补零 —— 与旧版显示完全一致。
 */
export function connectedDate(timestamp: number): string[] {
  const date = new Date(timestamp);
  const connected: string[] = ['date', 'day'];
  connected[0] = date.getFullYear() + '／' + (date.getMonth() + 1) + '／' + date.getDate();
  connected[1] = date.getDay().toString();
  return connected;
}

/**
 * 进度环当前值。
 * 目标为 1001（无限）时固定取半程 500；超额完成时封顶到目标值。
 */
export function doneValue(target: number, done: number): number {
  if (target == 1001) {
    return 500;
  }
  if (done > target) {
    // if over kill
    return target;
  } else {
    // if not done
    return done;
  }
}

/**
 * 进度百分比文本（两位小数 + " %"）。
 * 无限目标固定 "50 %"。目标为 0 时按原实现会得到 "Infinity %"，属既有行为。
 */
export function donePercentage(target: number, done: number): string {
  if (target == 1001) {
    // Unlimited Target
    return '50 %';
  }
  // Normal Cases
  return (done / target * 100).toFixed(2) + ' %';
}

/**
 * 剩余时间百分比文本。
 * 无限期限(367) 固定 "50 %"；已逾期(<0) 返回 "0 %"；否则两位小数 + " %"。
 * 注意除数与原实现一致，是 864000（原代码如此）。
 */
export function timeLeftPercentage(timeLimit: number, endAt: number, now: number): string {
  if (timeLimit == 367) {
    // Unlimited time
    return '50 %';
  }
  if ((endAt - now) / 864000 / timeLimit < 0) {
    // Already finished
    return '0 %';
  }
  // Normal cases
  return ((endAt - now) / 864000 / timeLimit).toFixed(2) + ' %';
}

/**
 * 预计日均剩余工时（用于"开始计时"面板的大号数字）。
 * 已完成 -> 颜文字；剩余 0 天 -> "1"；无限目标/无限期限 -> " ∞ "；
 * 否则 (目标-已完成)/剩余天数，保留 4 位小数。
 */
export function averageDailyWorkLeftForDisplay(target: number, done: number, timeLimit: number,
  remainingDays: number): string {
  if (done > target) { // Already finished
    return '( •̀ ω •́ )✧';
  }
  if (remainingDays == 0) {
    // Already over due
    return '1';
  }
  if (timeLimit == 367 || target == 1001) {
    // Infinite goal
    return ' ∞ ';
  }
  // Normal Cases
  return ((target - done) / remainingDays).toFixed(4);
}

/** 日均目标工时；无限目标/无限期限时按 1 处理。 */
export function averageDailyWork(target: number, timeLimit: number): number {
  if (timeLimit == 367 || target == 1001) { // Infinite goal
    return 1;
  }
  return target / timeLimit;
  // Regular situations
}

/**
 * 今天对应打卡数组的哪一格。
 * 打卡数据缺失时返回 0；否则取 min(距开始天数, 最后一格下标)，
 * 保证超出记录长度时仍落在最后一格上。
 */
export function todayBlockIndex(punchCardRow: number[] | undefined, startAt: number, now: number): number {
  if (punchCardRow == undefined) {
    return 0;
  }
  const lastOfPunchCard = punchCardRow.length - 1;
  const timePassedFromCardStart = relativeDaysPassed(startAt, now);
  return Math.min(timePassedFromCardStart, lastOfPunchCard);
}

/**
 * 数据看板中被选中那一格的日期文本。
 * 起始时间 + 选中下标 * 一天（24*3600*1000 毫秒）。
 */
export function dateOfChosen(startAt: number, chosenIndex: number): string[] {
  const dateChosenStamp = startAt + chosenIndex * 24 * 3600 * 1000;
  return connectedDate(dateChosenStamp);
}
