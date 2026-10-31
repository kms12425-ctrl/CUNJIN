/**
 * 寸进 · CUNJIN —— 共享 UI 小工具
 *
 * 目的：让被拆出去的组件不必再回调页面实例的私有方法。
 * 这里的实现与原 Index.DESIGN_animateParam() **逐字等价**：
 *   { delay: delay, duration: 300, curve: Curve.ExtremeDeceleration }
 * 任何动画参数都不允许在这里被"顺手优化"。
 */

/** 页面统一动效参数：固定 300ms + ExtremeDeceleration，仅延迟可变。 */
export function animateParam(delay: number): AnimateParam {
  const ap: AnimateParam = { delay: delay, duration: 300, curve: Curve.ExtremeDeceleration };
  return ap;
}
