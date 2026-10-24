/**
 * 寸进 · CUNJIN —— 纯时间格式化工具
 *
 * 只负责把"已进行的毫秒差"转成显示字符串，**不参与**任何计时、持久化或跨天归属逻辑。
 * 放在 model/ 下是为了能被本地单元测试直接覆盖（不依赖 ArkUI 运行时）。
 */

/** 两位补零。 */
function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

/**
 * 把"已进行的毫秒数"格式化为秒级时钟字符串。
 *
 *  - 小于 1 小时：MM:SS      例：00:05 / 12:34 / 59:59
 *  - 达到 1 小时：H:MM:SS    例：1:00:00 / 12:34:56
 *
 * 负值、NaN、Infinity 一律按 0 处理（防御性，不抛异常）。
 * 秒数向下取整：未满 1 秒不跳字，避免"刚开始就显示 1 秒"。
 */
export function formatElapsedClock(elapsedMs: number): string {
  let totalSeconds: number = 0;
  if (Number.isFinite(elapsedMs) && elapsedMs > 0) {
    totalSeconds = Math.floor(elapsedMs / 1000);
  }
  const hours: number = Math.floor(totalSeconds / 3600);
  const minutes: number = Math.floor((totalSeconds % 3600) / 60);
  const seconds: number = totalSeconds % 60;
  if (hours > 0) {
    return hours.toString() + ':' + pad2(minutes) + ':' + pad2(seconds);
  }
  return pad2(minutes) + ':' + pad2(seconds);
}
